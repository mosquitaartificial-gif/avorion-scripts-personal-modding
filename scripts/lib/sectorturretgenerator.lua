package.path = package.path .. ";data/scripts/lib/?.lua"

include("galaxy")
include("randomext")
local TurretGenerator = include("turretgenerator")

local SectorTurretGenerator =  {}
SectorTurretGenerator.__index = SectorTurretGenerator

local function new(seed)
    local obj = setmetatable({}, SectorTurretGenerator)
    obj:initialize(seed)
    return obj
end

function SectorTurretGenerator:initialize(seed)
    self.seed = seed or random():createSeed()
    if type(self.seed) == "number" or type(self.seed) == "string" then
        self.seed = Seed(self.seed)
    end

    self.random = Random(self.seed)
    self.rarities = nil -- initialize this with custom rarities to get custom rarity rates
    self.minRarity = nil
    self.maxRarity = nil
    self.coaxialAllowed = nil
end

function SectorTurretGenerator:getTurretSeed(x, y, weaponType, rarity)
    -- reduce randomness:
    -- for every 15x15 quadrant, every weapon type and every rarity, create a server-dependent selection of 5 seeds
    -- add an offset of 7 so the 0:0 quadrant is centered around 0:0
    local qx = math.floor(x + 7 / 15)
    local qy = math.floor(y + 7 / 15)

    if rarity.type >= RarityType.Exotic and self.random:test(0.5) then
        return self.random:createSeed(), qx, qy
    end

    local maxVariations = self.maxVariations or 4
    local seedString = tostring(GameSeed().int32) .. tostring(qx) .. tostring(qy) .. tostring(weaponType) .. tostring(rarity.type) .. tostring(self.random:getInt(1, maxVariations))

    return Seed(seedString), qx, qy
end

function SectorTurretGenerator:getDefaultRarityDistribution()
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

function SectorTurretGenerator:getSectorRarityDistribution(x, y)
    local rarities = self:getDefaultRarityDistribution()

    local f = length(vec2(x, y)) / (Balancing_GetDimensions() / 2) -- 0 (center) to 1 (edge) to ~1.5 (corner)

    rarities[-1] = math.max(0, -10 + f * 32) -- 22 at edge, 0 beyond the barrier
    rarities[0] = math.max(0, 1 + f * 63)    -- 64 at edge, 1 in center
    rarities[1] = math.max(0, 10 + f * 22)   -- 32 at edge, 10 in center

    return rarities
end

function SectorTurretGenerator:generate(x, y, offset_in, rarity_in, type_in, material_in)

    local offset = offset_in or 0
    local dps = 0

    local rarities = self.rarities or self:getSectorRarityDistribution(x, y)
    local rarity = rarity_in or Rarity(getValueFromDistribution(rarities, self.random))
    if self.minRarity then
        if rarity < self.minRarity then rarity = self.minRarity end
    end
    if self.maxRarity then
        if rarity > self.maxRarity then rarity = self.maxRarity end
    end

    local seed, qx, qy = self:getTurretSeed(x, y, weaponType, rarity)

    local sector = math.max(0, math.floor(length(vec2(qx, qy))) + offset)

    local weaponDPS, weaponTech = Balancing_GetSectorWeaponDPS(sector, 0)
    local miningDPS, miningTech = Balancing_GetSectorMiningDPS(sector, 0)
    local materialProbabilities = Balancing_GetTechnologyMaterialProbability(sector, 0)
    local material = material_in or Material(getValueFromDistribution(materialProbabilities, self.random))
    local weaponType = type_in or getValueFromDistribution(Balancing_GetWeaponProbability(sector, 0), self.random)

    local tech = 0
    if weaponType == WeaponType.MiningLaser then
        dps = miningDPS
        tech = miningTech
    elseif weaponType == WeaponType.RawMiningLaser then
        dps = miningDPS * 1.6
        tech = miningTech
    elseif weaponType == WeaponType.ForceGun then
        dps = 0 -- force guns are balanced in weapongenerator.lua
        tech = weaponTech
    else
        dps = weaponDPS
        tech = weaponTech
    end

    return TurretGenerator.generateSeeded(seed, weaponType, dps, tech, rarity, material, self.coaxialAllowed)
end

function SectorTurretGenerator:generateArmed(x, y, offset_in, rarity_in, material_in)

    local offset = offset_in or 0
    local sector = math.max(0, math.floor(length(vec2(x, y))) + offset)
    local types = Balancing_GetWeaponProbability(sector, 0)

    types[WeaponType.RepairBeam] = nil
    types[WeaponType.MiningLaser] = nil
    types[WeaponType.SalvagingLaser] = nil
    types[WeaponType.RawSalvagingLaser] = nil
    types[WeaponType.RawMiningLaser] = nil
    types[WeaponType.ForceGun] = nil

    local weaponType = getValueFromDistribution(types, self.random)

    return self:generate(x, y, offset_in, rarity_in, weaponType, material_in, self.coaxialAllowed)
end


return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
