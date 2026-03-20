package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("stringutility")
include("randomext")
include ("defaultscripts")

local Xsotan = include ("story/xsotan")
local PlanGenerator = include ("plangenerator")
local ShipUtility = include ("shiputility")
local SectorTurretGenerator = include ("sectorturretgenerator")

-- since this local variable can be used in multiple scripts in the same lua_State, a single callback function isn't enough
-- we use a table that has a unique id per generator
local generators = {}
local AsyncXsotanGenerator = {}

AsyncXsotanGenerator.__index = AsyncXsotanGenerator

local finalizationFunctions = {}
local XsotanType =
{
    Ship = 1,
    Carrier = 2,
    Quantum = 3,
    Dasher = 4,
    Summoner = 5,
    Shielded = 6,
    LongRange = 7,
    ShortRange = 8,
    LootGoon = 9,
    Buffer = 10,
    MasterSummoner = 11,
}

local function onPlanGenerated(plan, generatorId, position, type, numFighters, material)
    local self = generators[generatorId]

    if type == XsotanType.Shielded
            or type == XsotanType.LootGoon
            or type == XsotanType.MasterSummoner
            or type == XsotanType.Buffer then

        -- shielded Xsotan needs shield generator -> add it here
        plan:addBlock(vec3(), vec3(1, 1, 1), plan.rootIndex, -1, ColorRGB(1, 1, 1), material, Matrix(), BlockType.ShieldGenerator, ColorNone())
    end

    local faction = Xsotan.getFaction()
    local ship = Sector():createShip(faction, "", plan, position, EntityArrivalType.Jump)

    self.finalizationFunctions[type](ship, numFighters)

    if self.expected > 0 then
        table.insert(self.generated, ship)
        self:tryBatchCallback()
    elseif not self.batching then -- don't callback single creations batching
        if self.callback then
            self.callback(ship)
        end
    end
end

local function new(namespace, onGeneratedCallback)
    local instance = {}
    instance.generatorId = random():getInt()
    instance.expected = 0
    instance.batching = false
    instance.generated = {}
    instance.callback = onGeneratedCallback
    instance.finalizationFunctions = finalizationFunctions

    while generators[instance.generatorId] do
        instance.generatorId = random():getInt()
    end

    generators[instance.generatorId] = instance

    if namespace then
        assert(type(namespace) == "table")
    end

    if onGeneratedCallback then
        assert(type(onGeneratedCallback) == "function")
    end

    -- use a completely different naming scheme with underscores to increase probability that this is never used by anything else
    if namespace then
        namespace._xsotan_generator_on_plan_generated = onPlanGenerated
    else
        -- assign a global variable
        _xsotan_generator_on_plan_generated = onPlanGenerated
    end

    return setmetatable(instance, AsyncXsotanGenerator)
end

function AsyncXsotanGenerator:startBatch()
    self.batching = true
    self.generated = {}
    self.expected = 0
end

function AsyncXsotanGenerator:endBatch()
    self.batching = false

    -- it's possible all callbacks happened already before endBatch() is called
    self:tryBatchCallback()
end

function AsyncXsotanGenerator:tryBatchCallback()

    -- don't callback while batching or when no ships were generated (yet)
    if not self.batching and self.expected > 0 and #self.generated == self.expected then
        if self.callback then
            self.callback(self.generated)
        end
    end

end

function AsyncXsotanGenerator:create(type, position, volumeFactor, classification, numFighters)
    if self.batching then
        self.expected = self.expected + 1
    end

    position = position or Matrix()
    local volume = Xsotan.getShipVolume()
    volume = volume * (volumeFactor or 1)

    if classification then
        -- classification is used to scale vanilla Xsotan in rift missions with difficulty modifier
        volume = volume * classification.volume
    end

    local x, y = Sector():getCoordinates()
    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))

    if type == XsotanType.Shielded
            or type == XsotanType.LootGoon
            or type == XsotanType.LootBuffer
            or type == XsotanType.MasterSummoner then

        -- these should always spawn with shields -> the material must be at least Naonite, otherwise shield generators are not available
        if material.value < MaterialType.Naonite then
            material = Material(MaterialType.Naonite)
        end
    end

    PlanGenerator.makeAsyncXsotanShipPlan("_xsotan_generator_on_plan_generated", {self.generatorId, position, type, numFighters, material}, volume, material, type == XsotanType.Carrier)
end


-- the standard Xsotan
function AsyncXsotanGenerator:createShip(position, volumeFactor)
    position = position or Matrix()
    volumeFactor = (volumeFactor or 1) * 0.5 -- these are supposed to be small

    local classification = Xsotan.getClassification()
    return self:create(XsotanType.Ship, position, volumeFactor, classification)
end

function AsyncXsotanGenerator.finalizeShip(ship)
    local x, y = Sector():getCoordinates()
    local classification = Xsotan.getClassification()

    local weaponType = classification.weapon
    if random():test(0.1) then
        weaponType = nil -- some have random weapon type
    end

    Xsotan.addTurrets(ship, weaponType, RarityType.Common)

    -- finalize
    ship:setTitle("${toughness}Xsotan ${ship}"%_T, {toughness = "", ship = classification.name})
    ship.damageMultiplier = ship.damageMultiplier * classification.damage

    Xsotan.updateCrewAndBuffs(ship, true, true)
    Xsotan.addDefaultScriptsAndValues(ship)
end

-- carrier Xsotan
function AsyncXsotanGenerator:createCarrier(position, volumeFactor, numFighters)
    position = position or Matrix()
    numFighters = numFighters or 30
    volumeFactor = (volumeFactor or 1) * 1.5

    return self:create(XsotanType.Carrier, position, volumeFactor, nil, numFighters)
end

function AsyncXsotanGenerator.finalizeCarrier(ship, numFightersToAdd)
    -- add fighters
    Xsotan.addFighters(ship, numFightersToAdd)

    -- add turrets
    local numTurrets = math.max(1, Balancing_GetEnemySectorTurrets(x, y) * 0.5)
    Xsotan.addTurrets(ship, nil, RarityType.Rare, numTurret)

    ship.title = "Xsotan Cultivator"%_T
    Xsotan.updateCrewAndBuffs(ship, true, true)
    Xsotan.addDefaultScriptsAndValues(ship)
end

-- Quantum
function AsyncXsotanGenerator:createQuantum(position, volumeFactor)
    position = position or Matrix()
    volumeFactor = (volumeFactor or 1) * 0.5 -- these are supposed to be small

    return self:create(XsotanType.Quantum, position, volumeFactor)
end

function AsyncXsotanGenerator.finalizeQuantum(ship)
    Xsotan.addTurrets(ship, nil, RarityType.Rare)

    local name, type = ShipUtility.getMilitaryNameByVolume(ship.volume)
    ship:setTitle("${toughness}Quantum Xsotan ${ship}"%_T, {toughness = "", ship = name})
    Xsotan.updateCrewAndBuffs(ship, true, true)
    Xsotan.addDefaultScriptsAndValues(ship)

    ship:addScriptOnce("enemies/blinker.lua")
    ship.dockable = false
end

-- Dasher
function AsyncXsotanGenerator:createDasher(position, volumeFactor)
    position = position or Matrix()
    volumeFactor = (volumeFactor or 5) * 0.5

    return self:create(XsotanType.Dasher, position, volumeFactor)
end

function AsyncXsotanGenerator.finalizeDasher(ship)
    Xsotan.addTurrets(ship, nil, RarityType.Rare)

    local name, type = ShipUtility.getMilitaryNameByVolume(ship.volume)
    ship:setTitle("${toughness}Quantum Xsotan ${ship}"%_T, {toughness = "", ship = name})
    Xsotan.updateCrewAndBuffs(ship, true, false)
    Xsotan.addDefaultScriptsAndValues(ship)

    ship:addScriptOnce("internal/dlc/rift/entity/dasherxsotan.lua")
    ship.dockable = false
end

-- Summoner
function AsyncXsotanGenerator:createSummoner(position, volumeFactor)
    position = position or Matrix()
    volumeFactor = (volumeFactor or 5) * 0.5

    return self:create(XsotanType.Summoner, position, volumeFactor)
end

function AsyncXsotanGenerator.finalizeSummoner(ship)
    Xsotan.addTurrets(ship, nil, RarityType.Rare)

    ship:setTitle("${toughness}Xsotan Summoner"%_T, {toughness = ""})

    Xsotan.updateCrewAndBuffs(ship, true, true)
    Xsotan.addDefaultScriptsAndValues(ship)

    ship:addScriptOnce("enemies/summoner.lua")
    ship.dockable = false
end

-- Shielded
function AsyncXsotanGenerator:createShielded(position, volumeFactor)
    position = position or Matrix()
    volumeFactor = (volumeFactor or 5) * 0.5

    return self:create(XsotanType.Shielded, position, volumeFactor)
end

function AsyncXsotanGenerator.finalizeShielded(ship)
    Xsotan.addTurrets(ship, nil, RarityType.Rare)

    local name, type = ShipUtility.getMilitaryNameByVolume(ship.volume)
    ship:setTitle("${toughness}Shielded Xsotan ${ship}"%_T, {toughness = "", ship = name})

    Xsotan.updateCrewAndBuffs(ship, true, true)
    Xsotan.addDefaultScriptsAndValues(ship)

    ship:addScriptOnce("internal/dlc/rift/entity/shieldedxsotan.lua")
    ship.dockable = false
end

-- LongRange
function AsyncXsotanGenerator:createLongRange(position, volumeFactor)
    position = position or Matrix()
    volumeFactor = (volumeFactor or 1) * 0.5

    return self:create(XsotanType.LongRange, position, volumeFactor)
end

function AsyncXsotanGenerator.finalizeLongRange(ship)
    -- Long Range Xsotan need turrets with high maximum range
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false

    local x, y = Sector():getCoordinates()
    local turret = generator:generate(x, y, 0, Rarity(), WeaponType.Cannon)
    local weapons = {turret:getWeapons()}
    turret:clearWeapons()
    for _, weapon in pairs(weapons) do
        weapon.reach = 1800
        turret:addWeapon(weapon)
    end

    turret.turningSpeed = 2.0
    turret.crew = Crew()

    local numTurrets = math.max(2, Balancing_GetEnemySectorTurrets(x, y) * 0.75)
    ShipUtility.addTurretsToCraft(ship, turret, numTurrets)
    ship:setDropsAttachedTurrets(false)

    local name, type = ShipUtility.getMilitaryNameByVolume(ship.volume)
    ship:setTitle("${toughness}Xsotan Bombardier ${ship}"%_T, {toughness = "", ship = name})

    -- make them into glass-cannons
    Durability(ship).maxDurabilityFactor = 0.3

    Xsotan.updateCrewAndBuffs(ship, true, true)
    Xsotan.addDefaultScriptsAndValues(ship)

    ship.dockable = false
end

-- ShortRange
function AsyncXsotanGenerator:createShortRange(position, volumeFactor)
    position = position or Matrix()
    volumeFactor = (volumeFactor or 1) * 0.5

    return self:create(XsotanType.ShortRange, position, volumeFactor)
end

function AsyncXsotanGenerator.finalizeShortRange(ship)
    -- Short Range Xsotan need turrets with short maximum range
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false

    local x, y = Sector():getCoordinates()
    local turret = generator:generate(x, y, 0, Rarity(), WeaponType.TeslaGun)
    local weapons = {turret:getWeapons()}
    turret:clearWeapons()
    for _, weapon in pairs(weapons) do
        weapon.reach = 250
        turret:addWeapon(weapon)
    end

    turret.turningSpeed = 2.0
    turret.crew = Crew()

    local numTurrets = math.max(2, Balancing_GetEnemySectorTurrets(x, y) * 0.75)
    ShipUtility.addTurretsToCraft(ship, turret, numTurrets)
    ship:setDropsAttachedTurrets(false)

    local name, type = ShipUtility.getMilitaryNameByVolume(ship.volume)
    ship:setTitle("${toughness}Xsotan Jostler ${ship}"%_T, {toughness = "", ship = name})

    Xsotan.updateCrewAndBuffs(ship, true, true)
    Xsotan.addDefaultScriptsAndValues(ship)

    ship.dockable = false
end

-- Loot Goon
function AsyncXsotanGenerator:createLootGoon(position, volumeFactor)
    position = position or Matrix()
    volumeFactor = (volumeFactor or 2) * 0.5 -- slightly beefier than normal Xsotan, it should be a bullet sponge

    return self:create(XsotanType.LootGoon, position, volumeFactor)
end

function AsyncXsotanGenerator.finalizeLootGoon(ship)
    Xsotan.addTurrets(ship, nil, RarityType.Rare)

    ship:setTitle("Xsotan Aggregator"%_T, {})

    Xsotan.updateCrewAndBuffs(ship, true, true)
    Xsotan.addDefaultScriptsAndValues(ship)

    ship:addScriptOnce("internal/dlc/rift/entity/xsotanlootgoon.lua")
    ship.dockable = false
end

-- Buffer
function AsyncXsotanGenerator:createBuffer(position, volumeFactor)
    position = position or Matrix()
    volumeFactor = (volumeFactor or 2) * 0.5

    return self:create(XsotanType.Buffer, position, volumeFactor)
end

function AsyncXsotanGenerator.finalizeBuffer(ship)
    Xsotan.addTurrets(ship, nil, RarityType.Rare)

    ship:setTitle("Xsotan Amplifier"%_T, {})

    Xsotan.updateCrewAndBuffs(ship, true, true)
    Xsotan.addDefaultScriptsAndValues(ship)

    ship:addScriptOnce("internal/dlc/rift/entity/xsotanbuffer.lua")
    ship.dockable = false
end

-- MasterSummoner
function AsyncXsotanGenerator:createMasterSummoner(position, volumeFactor)
    position = position or Matrix()
    volumeFactor = (volumeFactor or 5) * 0.5

    return self:create(XsotanType.MasterSummoner, position, volumeFactor)
end

function AsyncXsotanGenerator.finalizeMasterSummoner(ship)
    Xsotan.addTurrets(ship, nil, RarityType.Rare)

    ship:setTitle("Xsotan Master Summoner"%_T, {})

    Xsotan.updateCrewAndBuffs(ship, true, true)
    Xsotan.addDefaultScriptsAndValues(ship)

    ship:addScriptOnce("internal/dlc/rift/entity/shieldedxsotansummoner.lua")
    ship.dockable = false
end


finalizationFunctions[XsotanType.Ship]              = AsyncXsotanGenerator.finalizeShip
finalizationFunctions[XsotanType.Carrier]           = AsyncXsotanGenerator.finalizeCarrier
finalizationFunctions[XsotanType.Quantum]           = AsyncXsotanGenerator.finalizeQuantum
finalizationFunctions[XsotanType.Dasher]            = AsyncXsotanGenerator.finalizeDasher
finalizationFunctions[XsotanType.Summoner]          = AsyncXsotanGenerator.finalizeSummoner
finalizationFunctions[XsotanType.Shielded]          = AsyncXsotanGenerator.finalizeShielded
finalizationFunctions[XsotanType.LongRange]         = AsyncXsotanGenerator.finalizeLongRange
finalizationFunctions[XsotanType.ShortRange]        = AsyncXsotanGenerator.finalizeShortRange
finalizationFunctions[XsotanType.LootGoon]          = AsyncXsotanGenerator.finalizeLootGoon
finalizationFunctions[XsotanType.Buffer]            = AsyncXsotanGenerator.finalizeBuffer
finalizationFunctions[XsotanType.MasterSummoner]    = AsyncXsotanGenerator.finalizeMasterSummoner

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
