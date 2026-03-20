package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("galaxy")
include ("stringutility")
include("randomext")
local PlanGenerator = include ("plangenerator")
local ShipUtility = include ("shiputility")
local PirateGenerator = include("pirategenerator")
local SectorFighterGenerator = include("sectorfightergenerator")

-- since this local variable can be used in multiple scripts in the same lua_State, a single callback function isn't enough
-- we use a table that has a unique id per generator
local generators = {}
local AsyncPirateGenerator = {}
AsyncPirateGenerator.__index = AsyncPirateGenerator

local function onPlanGenerated(plan, generatorId, position, factionIndex, title)

    local self = generators[generatorId]

    local faction = Faction(factionIndex)
    local ship = Sector():createShip(faction, "", plan, position, self.arrivalType)

    PirateGenerator.addPirateEquipment(ship, title)

    ship.crew = ship.idealCrew
    ship.shieldDurability = ship.shieldMaxDurability

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
    instance.arrivalType = EntityArrivalType.Jump

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
        namespace._pirate_generator_on_plan_generated = onPlanGenerated
    else
        -- assign a global variable
        _pirate_generator_on_plan_generated = onPlanGenerated
    end

    return setmetatable(instance, AsyncPirateGenerator)
end

function AsyncPirateGenerator:create(position, volumeFactor, title, material)

    if self.batching then
        self.expected = self.expected + 1
    end

    position = position or Matrix()
    local x, y = Sector():getCoordinates()
    self.pirateLevel = self.pirateLevel or Balancing_GetPirateLevel(x, y)

    local faction = Galaxy():getPirateFaction(self.pirateLevel)
    local volume = Balancing_GetSectorShipVolume(x, y) * volumeFactor;

    if title == "Pirate Carrier" then
        PlanGenerator.makeAsyncCarrierPlan("_pirate_generator_on_plan_generated", {self.generatorId, position, faction.index, title}, faction, volume, _, material)
    else
        PlanGenerator.makeAsyncShipPlan("_pirate_generator_on_plan_generated", {self.generatorId, position, faction.index, title}, faction, volume)
    end
end

function AsyncPirateGenerator:startBatch()
    self.batching = true
    self.generated = {}
    self.expected = 0
end

function AsyncPirateGenerator:endBatch()
    self.batching = false

    -- it's possible all callbacks happened already before endBatch() is called
    self:tryBatchCallback()
end

function AsyncPirateGenerator:tryBatchCallback()

    -- don't callback while batching or when no ships were generated (yet)
    if not self.batching and self.expected > 0 and #self.generated == self.expected then
        if self.callback then
            self.callback(self.generated)
        end
    end

end

function AsyncPirateGenerator:createScaledOutlaw(position)
    local scaling = self:getScaling()
    return self:create(position, 0.6 * scaling, "Outlaw"%_T)
end

function AsyncPirateGenerator:createScaledBandit(position)
    local scaling = self:getScaling()
    return self:create(position, 0.8 * scaling, "Bandit"%_T)
end

function AsyncPirateGenerator:createScaledPirate(position)
    local scaling = self:getScaling()
    return self:create(position, 1.2 * scaling, "Pirate"%_T)
end

function AsyncPirateGenerator:createScaledMarauder(position)
    local scaling = self:getScaling()
    return self:create(position, 1.5 * scaling, "Marauder"%_T)
end

function AsyncPirateGenerator:createScaledDisruptor(position)
    local scaling = self:getScaling()
    return self:create(position, 1.5 * scaling, "Disruptor"%_T)
end

function AsyncPirateGenerator:createScaledRaider(position)
    local scaling = self:getScaling()
    return self:create(position, 3.0 * scaling, "Raider"%_T)
end

function AsyncPirateGenerator:createScaledCarrier(position)
    local scaling = PirateGenerator.getScaling()
    return self:create(position, 6.0 * scaling, "Pirate Carrier"%_T)
end

function AsyncPirateGenerator:createScaledRavager(position)
    if random():test(0.2) then
        return self:createScaledCarrier(position)
    end

    local scaling = self:getScaling()
    return self:create(position, 6.0 * scaling, "Ravager"%_T)
end

function AsyncPirateGenerator:createScaledBoss(position)
    local scaling = self:getScaling()
    return self:create(position, 25.0 * scaling, "Pirate Mothership"%_T)
end

function AsyncPirateGenerator:createScaledLootGoon(position)
    local scaling = self:getScaling()
    return self:create(position, 2.0 * scaling, "Pirate Loot Transporter"%_T)
end


function AsyncPirateGenerator:createOutlaw(position)
    return self:create(position, 0.6, "Outlaw"%_T)
end

function AsyncPirateGenerator:createBandit(position)
    return self:create(position, 0.8, "Bandit"%_T)
end

function AsyncPirateGenerator:createPirate(position)
    return self:create(position, 1.2, "Pirate"%_T)
end

function AsyncPirateGenerator:createMarauder(position)
    return self:create(position, 1.5, "Marauder"%_T)
end

function AsyncPirateGenerator:createDisruptor(position)
    return self:create(position, 1.5, "Disruptor"%_T)
end

function AsyncPirateGenerator:createRaider(position)
    return self:create(position, 3.0, "Raider"%_T)
end

function AsyncPirateGenerator:createCarrier(position, material)
    return self:create(position, 6.0, "Pirate Carrier"%_T, material)
end

function AsyncPirateGenerator:createRavager(position)
    if random():test(0.2) then
        return self:createCarrier(position)
    end
    return self:create(position, 6.0, "Ravager"%_T)
end

function AsyncPirateGenerator:createBoss(position)
    return self:create(position, 25.0, "Pirate Mothership"%_T)
end

function AsyncPirateGenerator:createLootGoon(position)
    return self:create(position, 2.0, "Pirate Loot Transporter"%_T)
end

function AsyncPirateGenerator:getScaling()
    local scaling = Sector().numPlayers

    if scaling == 0 then scaling = 1 end
    return scaling
end

function AsyncPirateGenerator:getPirateFaction()
    local x, y = Sector():getCoordinates()
    self.pirateLevel = self.pirateLevel or Balancing_GetPirateLevel(x, y)
    return Galaxy():getPirateFaction(self.pirateLevel)
end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
