package.path = package.path .. ";data/scripts/lib/?.lua"

include ("galaxy")
include ("randomext")
local PlanGenerator = include ("plangenerator")
local FighterGenerator = include ("fightergenerator")
include("weapontype")

local SectorFighterGenerator =  {}
SectorFighterGenerator.__index = SectorFighterGenerator

local function new(seed)
    local obj = setmetatable({}, SectorFighterGenerator)
    obj:initialize(seed)
    return obj
end

function SectorFighterGenerator:initialize(seed)
    self.seed = seed or random():createSeed()
    if type(self.seed) == "number" or type(self.seed) == "string" then
        self.seed = Seed(self.seed)
    end

    self.random = Random(self.seed)
    self.rarities = nil -- initialize this with custom rarities to get custom rarity rates
end

function SectorFighterGenerator:getDefaultRarityDistribution()
    local rarities = {}
    rarities[5] = 0.1 -- legendary
    rarities[4] = 1 -- exotic
    rarities[3] = 8 -- exceptional
    rarities[2] = 16 -- rare
    rarities[1] = 32 -- uncommon
    rarities[0] = 64 -- common
    rarities[-1] = 32 -- petty

    local difficulty = GameSettings().difficulty
    if difficulty >= 0 then
        rarities[5] = rarities[5] + (difficulty + 1) * 0.05 -- legendary: 0.15 at Veteran, 0.3 at Insane
        rarities[4] = rarities[4] + (difficulty + 1) * 0.5 -- exotic: 1.5 at Veteran, 3 at Insane
        rarities[3] = rarities[3] + (difficulty + 1) * 2 -- exceptional: 10 at Veteran, 16 at Insane
        rarities[2] = rarities[2] + (difficulty + 1) * 4 -- rare: 20 at Veteran, 32 at Insane
    end

    return rarities
end

function SectorFighterGenerator:getSectorRarityDistribution(x, y)
    local rarities = self:getDefaultRarityDistribution()

    local f = length(vec2(x, y)) / (Balancing_GetDimensions() / 2) -- 0 (center) to 1 (edge) to ~1.5 (corner)

    rarities[-1] = math.max(0, -10 + f * 32) -- 22 at edge, 0 beyond the barrier
    rarities[0] = math.max(0, 1 + f * 63)    -- 64 at edge, 1 in center
    rarities[1] = math.max(0, 10 + f * 22)   -- 32 at edge, 10 in center

    return rarities
end

function SectorFighterGenerator:generate(x, y, offset_in, rarity_in, type_in, material_in) -- server

    local offset = offset_in or 0
    local seed = self.random:createSeed()
    local dps = 0
    local sector = math.max(0, math.floor(length(vec2(x, y))) + offset)

    local rarities = self.rarities or self:getSectorRarityDistribution(x, y)
    local rarity = rarity_in or Rarity(getValueFromDistribution(rarities, self.random))

    local weaponDPS, weaponTech = Balancing_GetSectorWeaponDPS(sector, 0)
    local miningDPS, miningTech = Balancing_GetSectorMiningDPS(sector, 0)
    local materialProbabilities = Balancing_GetTechnologyMaterialProbability(sector, 0)
    local material = material_in or Material(getValueFromDistribution(materialProbabilities, self.random))

    local weaponTypes = Balancing_GetWeaponProbability(sector, 0)
    weaponTypes[WeaponType.AntiFighter] = nil

    local weaponType = type_in or getValueFromDistribution(weaponTypes, self.random)

    miningDPS = miningDPS * 0.4
    weaponDPS = weaponDPS * 0.4

    local tech = 0
    if weaponType == WeaponType.MiningLaser then
        dps = miningDPS
        tech = miningTech
    elseif weaponType == WeaponType.RawMiningLaser then
        dps = miningDPS * 2
        tech = miningTech
    elseif weaponType == WeaponType.ForceGun then
        dps = 1200
        tech = weaponTech
    else
        dps = weaponDPS
        tech = weaponTech
    end

    return FighterGenerator.generateFighter(Random(seed), weaponType, dps, tech, material, rarity, self.factionIndex, self.emptyPlan)
end

function SectorFighterGenerator:generateArmed(x, y, offset_in, rarity_in, material_in) -- server

    local offset = offset_in or 0
    local sector = math.max(0, math.floor(length(vec2(x, y))) + offset)
    local types = Balancing_GetWeaponProbability(sector, 0)

    types[WeaponType.RawMiningLaser] = 0
    types[WeaponType.MiningLaser] = 0
    types[WeaponType.SalvagingLaser] = 0
    types[WeaponType.RawSalvagingLaser] = 0
    types[WeaponType.PointDefenseLaser] = 0
    types[WeaponType.PointDefenseChainGun] = 0
    types[WeaponType.ForceGun] = 0
    types[WeaponType.RepairBeam] = 0

    local weaponType = getValueFromDistribution(types, self.random)

    return self:generate(x, y, offset_in, rarity_in, weaponType, material_in)
end

function SectorFighterGenerator:generateCrewShuttle(x, y, material_in)
    local seed = self.random:createSeed()

    local materialProbabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = material_in or Material(getValueFromDistribution(materialProbabilities, self.random))

    local rarity = Rarity(RarityType.Uncommon)
    local tech = Balancing_GetTechLevel(x, y)
    local fighter = FighterGenerator.generateUnarmedFighter(Random(seed), tech, material, rarity, self.factionIndex, self.emptyPlan)

    local random = Random(seed)
    fighter.plan = PlanGenerator.makeCrewShuttlePlan(self.factionIndex, random:createSeed(), material)
    fighter.type = FighterType.CrewShuttle

    return fighter
end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
