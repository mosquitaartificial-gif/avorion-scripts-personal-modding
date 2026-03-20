package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("galaxy")
include ("utility")
include ("defaultscripts")
include ("goods")
include("randomext")
local PlanGenerator = include ("plangenerator")
local FighterGenerator = include ("fightergenerator")
local ShipUtility = include ("shiputility")

local ShipGenerator = {}

-- since this local variable can be used in multiple scripts in the same lua_State, a single callback function isn't enough
-- we use a table that has a unique id per generator
local generators = {}
local AsyncShipGenerator = {}
AsyncShipGenerator.__index = AsyncShipGenerator

local function onShipCreated(generatorId, ship)
    local self = generators[generatorId]
    if not self then return end

    if self.expected > 0 then
        table.insert(self.generated, ship)
        self:tryBatchCallback()
    elseif not self.batching then -- don't callback single creations batching
        if self.callback then
            self.callback(ship)
        end

        generators[generatorId] = nil -- clean up
    end

end

local function finalizeShip(ship)
    ship.crew = ship.idealCrew
    ship.shieldDurability = ship.shieldMaxDurability

    AddDefaultShipScripts(ship)
    SetBoardingDefenseLevel(ship)
end


local function carriersPossible()
    local x, y = Sector():getCoordinates()
    return x * x + y * y < 290 * 290
end

local function disruptorsPossible()
    local x, y = Sector():getCoordinates()
    return x * x + y * y < 370 * 370
end




function AsyncShipGenerator:createShip(faction, position, volume)
    position = position or Matrix()
    volume = volume or Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation()

    PlanGenerator.makeAsyncShipPlan("_ship_generator_on_ship_plan_generated", {self.generatorId, position, faction.index}, faction, volume)
    self:shipCreationStarted()
end

local function onShipPlanFinished(plan, generatorId, position, factionIndex)
    local self = generators[generatorId] or {}

    if self.scaling then
        plan:scale(vec3(self.scaling))
    end

    local faction = Faction(self.factionIndex or factionIndex)
    local ship = Sector():createShip(faction, "", plan, position, self.arrivalType)

    finalizeShip(ship)
    onShipCreated(generatorId, ship)
end



function AsyncShipGenerator:createDefender(faction, position)
    position = position or Matrix()

    -- defenders should be a lot beefier than the normal ships
    local volume = Balancing_GetSectorShipVolume(faction:getHomeSectorCoordinates()) * 7.5

    PlanGenerator.makeAsyncShipPlan("_ship_generator_on_defender_plan_generated", {self.generatorId, position, faction.index}, faction, volume)
    self:shipCreationStarted()
end

local function onDefenderPlanFinished(plan, generatorId, position, factionIndex)
    local self = generators[generatorId] or {}

    local faction = Faction(self.factionIndex or factionIndex)
    local ship = Sector():createShip(faction, "", plan, position, self.arrivalType)

    local turrets = Balancing_GetEnemySectorTurrets(Sector():getCoordinates()) * 2 + 3
    turrets = turrets + turrets * math.max(0, faction:getTrait("careful") or 0) * 0.5

    ShipUtility.addArmedTurretsToCraft(ship, turrets)
    ship.title = ShipUtility.getMilitaryNameByVolume(ship.volume)
    ship.damageMultiplier = ship.damageMultiplier * 4

    ship:addScript("ai/patrol.lua")
    ship:addScript("antismuggle.lua")
    ship:setValue("is_armed", true)
    ship:setValue("is_defender", true)
    ship:setValue("npc_chatter", true)

    ship:addScript("icon.lua", "data/textures/icons/pixel/defender.png")

    finalizeShip(ship)
    onShipCreated(generatorId, ship)
end



function AsyncShipGenerator:createCarrier(faction, position, fighters)
    if not carriersPossible() then
        self:createMilitaryShip(faction, position)
        return
    end

    position = position or Matrix()
    fighters = fighters or 10

    -- carriers should be even beefier than the defenders
    local volume = volume or Balancing_GetSectorShipVolume(Sector():getCoordinates()) * 15.0

    PlanGenerator.makeAsyncCarrierPlan("_ship_generator_on_carrier_plan_generated", {self.generatorId, position, faction.index, fighters}, faction, volume)
    self:shipCreationStarted()
end

local function onCarrierPlanFinished(plan, generatorId, position, factionIndex, fighters)
    local self = generators[generatorId] or {}

    local faction = Faction(self.factionIndex or factionIndex)
    local ship = Sector():createShip(faction, "", plan, position, self.arrivalType)

    ShipUtility.addCarrierEquipment(ship, fighters)
    ship:addScript("ai/patrol.lua")

    finalizeShip(ship)
    onShipCreated(generatorId, ship)
end



function AsyncShipGenerator:createMilitaryShip(faction, position, volume)
    position = position or Matrix()
    volume = volume or Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation()

    PlanGenerator.makeAsyncShipPlan("_ship_generator_on_military_plan_generated", {self.generatorId, position, faction.index}, faction, volume)
    self:shipCreationStarted()
end

local function onMilitaryPlanFinished(plan, generatorId, position, factionIndex)
    local self = generators[generatorId] or {}

    local faction = Faction(self.factionIndex or factionIndex)
    local ship = Sector():createShip(faction, "", plan, position, self.arrivalType)

    ShipUtility.addMilitaryEquipment(ship, 1, 0)

    finalizeShip(ship)
    onShipCreated(generatorId, ship)
end



function AsyncShipGenerator:createTorpedoShip(faction, position, volume)
    position = position or Matrix()
    volume = volume or Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation()

    PlanGenerator.makeAsyncShipPlan("_ship_generator_on_torpedo_plan_generated", {self.generatorId, position, faction.index}, faction, volume)
    self:shipCreationStarted()
end

local function onTorpedoShipPlanFinished(plan, generatorId, position, factionIndex)
    local self = generators[generatorId] or {}

    local faction = Faction(self.factionIndex or factionIndex)
    local ship = Sector():createShip(faction, "", plan, position, self.arrivalType)

    ShipUtility.addTorpedoBoatEquipment(ship)

    finalizeShip(ship)
    onShipCreated(generatorId, ship)
end



function AsyncShipGenerator:createDisruptorShip(faction, position, volume)
    if not disruptorsPossible() then
        self:createMilitaryShip(faction, position)
        return
    end

    position = position or Matrix()
    volume = volume or Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation()

    PlanGenerator.makeAsyncShipPlan("_ship_generator_on_disruptor_plan_generated", {self.generatorId, position, faction.index}, faction, volume)
    self:shipCreationStarted()
end

local function onDisruptorShipPlanFinished(plan, generatorId, position, factionIndex)
    local self = generators[generatorId] or {}

    local faction = Faction(self.factionIndex or factionIndex)
    local ship = Sector():createShip(faction, "", plan, position, self.arrivalType)

    ShipUtility.addDisruptorEquipment(ship)

    finalizeShip(ship)
    onShipCreated(generatorId, ship)
end



function AsyncShipGenerator:createCIWSShip(faction, position, volume)
    if not carriersPossible() then
        self:createMilitaryShip(faction, position)
        return
    end

    position = position or Matrix()
    volume = volume or Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation()

    PlanGenerator.makeAsyncShipPlan("_ship_generator_on_ciws_plan_generated", {self.generatorId, position, faction.index}, faction, volume)
    self:shipCreationStarted()
end

local function onCIWSShipPlanFinished(plan, generatorId, position, factionIndex)
    local self = generators[generatorId] or {}

    local faction = Faction(self.factionIndex or factionIndex)
    local ship = Sector():createShip(faction, "", plan, position, self.arrivalType)

    ShipUtility.addCIWSEquipment(ship)

    finalizeShip(ship)
    onShipCreated(generatorId, ship)
end



function AsyncShipGenerator:createPersecutorShip(faction, position, volume)
    position = position or Matrix()
    volume = volume or Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation()

    PlanGenerator.makeAsyncShipPlan("_ship_generator_on_persecutor_plan_generated", {self.generatorId, position, faction.index}, faction, volume)
    self:shipCreationStarted()
end

local function onPersecutorShipPlanFinished(plan, generatorId, position, factionIndex)
    local self = generators[generatorId] or {}

    local faction = Faction(self.factionIndex or factionIndex)
    local ship = Sector():createShip(faction, "", plan, position, self.arrivalType)

    ShipUtility.addPersecutorEquipment(ship)

    finalizeShip(ship)
    onShipCreated(generatorId, ship)
end



function AsyncShipGenerator:createBlockerShip(faction, position, volume)
    position = position or Matrix()
    volume = volume or Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation()

    PlanGenerator.makeAsyncShipPlan("_ship_generator_on_blocker_plan_generated", {self.generatorId, position, faction.index}, faction, volume)
    self:shipCreationStarted()
end

local function onBlockerShipPlanFinished(plan, generatorId, position, factionIndex)
    local self = generators[generatorId] or {}

    local faction = Faction(self.factionIndex or factionIndex)
    local ship = Sector():createShip(faction, "", plan, position, self.arrivalType)

    ShipUtility.addBlockerEquipment(ship)

    finalizeShip(ship)
    onShipCreated(generatorId, ship)
end



function AsyncShipGenerator:createFlagShip(faction, position, volume)
    position = position or Matrix()
    volume = volume or Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation() * 40

    PlanGenerator.makeAsyncShipPlan("_ship_generator_on_flagship_plan_generated", {self.generatorId, position, faction.index}, faction, volume)
    self:shipCreationStarted()
end

local function onFlagShipPlanFinished(plan, generatorId, position, factionIndex)
    local self = generators[generatorId] or {}

    local faction = Faction(self.factionIndex or factionIndex)
    local ship = Sector():createShip(faction, "", plan, position, self.arrivalType)

    ShipUtility.addFlagShipEquipment(ship)

    finalizeShip(ship)
    onShipCreated(generatorId, ship)
end



function AsyncShipGenerator:createTradingShip(faction, position, volume)
    position = position or Matrix()
    volume = volume or Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation()

    PlanGenerator.makeAsyncShipPlan("_ship_generator_on_trader_plan_generated", {self.generatorId, position, faction.index}, faction, volume)
    self:shipCreationStarted()
end

local function onTraderPlanFinished(plan, generatorId, position, factionIndex)
    local self = generators[generatorId] or {}

    local faction = Faction(self.factionIndex or factionIndex)
    local ship = Sector():createShip(faction, "", plan, position, self.arrivalType)

    if math.random() < 0.5 then
        local turrets = Balancing_GetEnemySectorTurrets(Sector():getCoordinates())
        ShipUtility.addArmedTurretsToCraft(ship, turrets)
    end

    ship.title = ShipUtility.getTraderNameByVolume(ship.volume)

    ship:addScript("civilship.lua")
    ship:addScript("dialogs/storyhints.lua")
    ship:setValue("is_civil", true)
    ship:setValue("is_trader", true)
    ship:setValue("npc_chatter", true)

    ship:addScript("icon.lua", "data/textures/icons/pixel/civil-ship.png")

    finalizeShip(ship)
    onShipCreated(generatorId, ship)
end



function AsyncShipGenerator:createFreighterShip(faction, position, volume)
    position = position or Matrix()
    volume = volume or Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation()

    PlanGenerator.makeAsyncFreighterPlan("_ship_generator_on_freighter_plan_generated", {self.generatorId, position, faction.index}, faction, volume)
    self:shipCreationStarted()
end

local function onFreighterPlanFinished(plan, generatorId, position, factionIndex)
    local self = generators[generatorId] or {}

    local faction = Faction(self.factionIndex or factionIndex)
    local ship = Sector():createShip(faction, "", plan, position, self.arrivalType)

    if math.random() < 0.5 then
        local turrets = Balancing_GetEnemySectorTurrets(Sector():getCoordinates())

        ShipUtility.addArmedTurretsToCraft(ship, turrets)
    end

    ship.title = ShipUtility.getFreighterNameByVolume(ship.volume)

    ship:addScript("civilship.lua")
    ship:addScript("dialogs/storyhints.lua")
    ship:setValue("is_civil", true)
    ship:setValue("is_freighter", true)
    ship:setValue("npc_chatter", true)

    ship:addScript("icon.lua", "data/textures/icons/pixel/civil-ship.png")

    finalizeShip(ship)
    onShipCreated(generatorId, ship)
end



function AsyncShipGenerator:createMiningShip(faction, position, volume)
    position = position or Matrix()
    volume = volume or Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation()

    PlanGenerator.makeAsyncMinerPlan("_ship_generator_on_mining_plan_generated", {self.generatorId, position, faction.index}, faction, volume)
    self:shipCreationStarted()
end

local function onMiningPlanFinished(plan, generatorId, position, factionIndex)
    local self = generators[generatorId] or {}

    local faction = Faction(self.factionIndex or factionIndex)
    local ship = Sector():createShip(faction, "", plan, position, self.arrivalType)

    local turrets = Balancing_GetEnemySectorTurrets(Sector():getCoordinates())

    ShipUtility.addUnarmedTurretsToCraft(ship, turrets)
    ship.title = ShipUtility.getMinerNameByVolume(ship.volume)

    ship:addScript("civilship.lua")
    ship:addScript("dialogs/storyhints.lua")
    ship:setValue("is_civil", true)
    ship:setValue("is_miner", true)
    ship:setValue("npc_chatter", true)

    ship:addScript("icon.lua", "data/textures/icons/pixel/civil-ship.png")

    finalizeShip(ship)
    onShipCreated(generatorId, ship)
end



function AsyncShipGenerator:startBatch()
    self.batching = true
    self.generated = {}
    self.expected = 0
end

function AsyncShipGenerator:endBatch()
    self.batching = false

    -- it's possible all callbacks happened already before endBatch() is called
    self:tryBatchCallback()
end

function AsyncShipGenerator:shipCreationStarted()
    if self.batching then
        self.expected = self.expected + 1
    end

    generators[self.generatorId] = self
end

function AsyncShipGenerator:tryBatchCallback()

    -- don't callback while batching or when no ships were generated (yet)
    if not self.batching and self.expected > 0 and #self.generated == self.expected then
        if self.callback then
            -- Problem: Since this is all asynchronous, a generated ship might have been destroyed when the callback is executed
            -- There are 2 options here:
            -- 1. pass on all generated entity references, some might be invalid
            -- 2. pass on only valid entity references, might be strange because user ordered eg. 4 ships but only gets 3
            -- BUT: in both cases the user has to do some kind of check in the callback
            -- in case #1 a valid() check HAS to be done for every ship
            -- in case #2 a check for the correct amount of ships MIGHT have to be done
            -- since case 2 is less common and will lead to less code written in general, I (koonschi) opted for case #2

            -- find all valid ships and only pass those on
            local validGenerated = {}
            for _, entity in pairs(self.generated) do
                if valid(entity) then
                    table.insert(validGenerated, entity)
                end
            end

            self.callback(validGenerated)
        end

        generators[self.generatorId] = nil -- clean up
    end

end


local function new(namespace, onGeneratedCallback)
    local instance = {}
    instance.generatorId = random():getInt()
    instance.expected = 0
    instance.batching = false
    instance.generated = {}
    instance.callback = onGeneratedCallback
    instance.arrivalType = EntityArrivalType.Jump
    instance.scaling = 1.0
    instance.factionIndex = nil

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

    -- use a completely different naming schedule with underscores to increase probability that this is never used by anything else
    if namespace then
        namespace._ship_generator_on_ship_plan_generated = onShipPlanFinished
        namespace._ship_generator_on_defender_plan_generated = onDefenderPlanFinished
        namespace._ship_generator_on_carrier_plan_generated = onCarrierPlanFinished
        namespace._ship_generator_on_freighter_plan_generated = onFreighterPlanFinished
        namespace._ship_generator_on_military_plan_generated = onMilitaryPlanFinished
        namespace._ship_generator_on_torpedo_plan_generated = onTorpedoShipPlanFinished
        namespace._ship_generator_on_disruptor_plan_generated = onDisruptorShipPlanFinished
        namespace._ship_generator_on_persecutor_plan_generated = onPersecutorShipPlanFinished
        namespace._ship_generator_on_blocker_plan_generated = onBlockerShipPlanFinished
        namespace._ship_generator_on_ciws_plan_generated = onCIWSShipPlanFinished
        namespace._ship_generator_on_flagship_plan_generated = onFlagShipPlanFinished
        namespace._ship_generator_on_trader_plan_generated = onTraderPlanFinished
        namespace._ship_generator_on_mining_plan_generated = onMiningPlanFinished
    else
        -- use global variables
        _ship_generator_on_ship_plan_generated = onShipPlanFinished
        _ship_generator_on_defender_plan_generated = onDefenderPlanFinished
        _ship_generator_on_carrier_plan_generated = onCarrierPlanFinished
        _ship_generator_on_freighter_plan_generated = onFreighterPlanFinished
        _ship_generator_on_military_plan_generated = onMilitaryPlanFinished
        _ship_generator_on_torpedo_plan_generated = onTorpedoShipPlanFinished
        _ship_generator_on_disruptor_plan_generated = onDisruptorShipPlanFinished
        _ship_generator_on_persecutor_plan_generated = onPersecutorShipPlanFinished
        _ship_generator_on_blocker_plan_generated = onBlockerShipPlanFinished
        _ship_generator_on_ciws_plan_generated = onCIWSShipPlanFinished
        _ship_generator_on_flagship_plan_generated = onFlagShipPlanFinished
        _ship_generator_on_trader_plan_generated = onTraderPlanFinished
        _ship_generator_on_mining_plan_generated = onMiningPlanFinished
    end

    return setmetatable(instance, AsyncShipGenerator)
end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
