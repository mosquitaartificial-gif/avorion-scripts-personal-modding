package.path = package.path .. ";data/scripts/lib/*.lua"
package.path = package.path .. ";data/scripts/*.lua"

include ("randomext")
include ("stringutility")
local ShipGenerator = include("shipgenerator")
local Placer = include("placer")

local AdventurerGuide = {}

function AdventurerGuide.spawn1(player)

    -- don't double-spawn
    if Sector():getEntitiesByScript("data/scripts/entity/story/adventurer1.lua") then return end

    local faction = Galaxy():getNearestFaction(player:getHomeSectorCoordinates())
    local volume = Balancing_GetSectorShipVolume(faction:getHomeSectorCoordinates())

    local pos = random():getVector(-1000, 1000)
    local matrix = MatrixLookUpPosition(-pos, vec3(0, 1, 0), pos)

    local ship = ShipGenerator.createMilitaryShip(faction, matrix, volume)

    local language = faction:getLanguage()
    language.seed = Server().seed

    local name = language:getName()

    ship:setTitle("${name} The Adventurer"%_t, {name = name})
    ship:addScript("story/adventurer1.lua")
    ship:setValue("no_attack_events", true)

    ship.invincible = true

    Placer.resolveIntersections({ship})

    Boarding(ship).boardable = false
    ship.dockable = false

    return ship
end

function AdventurerGuide.canSpawn()
    if onServer() then
        local entities = {Sector():getEntities()}
        for _, entity in pairs(entities) do
            if entity:hasScript("data/scripts/entity/story/swoks.lua") then return false end
            if entity:hasScript("data/scripts/entity/story/aibehaviour.lua") then return false end
        end

        return true
    end
end

function AdventurerGuide.spawnOrFindMissionAdventurer(player, dontAllowInteraction, dontImmediatelyStartDialog)

    -- don't double-spawn
    local present = Sector():getEntitiesByScript("data/scripts/entity/story/missionadventurer.lua")
    if present then return present end

    -- don't spawn if bosses are in sector
    if not AdventurerGuide.canSpawn() then return end

    local allowGreet -- show greet option
    if not dontAllowInteraction then
        allowGreet = true
    else
        allowGreet = false
    end

    local allowImmediateDialog -- show dialog at first opportunity
    if not dontImmediatelyStartDialog then
        allowImmediateDialog = true
    else
        allowImmediateDialog = false
    end

    local galaxy = Galaxy()
    local faction = galaxy:getNearestFaction(player:getHomeSectorCoordinates())
    local volume = Balancing_GetSectorShipVolume(faction:getHomeSectorCoordinates())

    local pos = random():getVector(-1000, 1000)
    local matrix = MatrixLookUpPosition(-pos, vec3(0, 1, 0), pos)

    local ship = ShipGenerator.createMilitaryShip(faction, matrix, volume)

    local language = faction:getLanguage()
    language.seed = Server().seed

    local name = language:getName()

    ship:setTitle("${name} The Adventurer"%_t, {name = name})
    ship:addScript("story/missionadventurer.lua", allowGreet, allowImmediateDialog)
    ship:setValue("no_attack_events", true)

    Placer.resolveIntersections({ship})

    Boarding(ship).boardable = false
    ship.dockable = false

    return ship
end

function AdventurerGuide.spawnProgressionWarningAdventurer(player)

    -- don't double-spawn
    local sector = Sector()
    if sector:getEntitiesByScript("data/scripts/entity/story/progressionwarningadventurer.lua") then return end

    -- don't spawn if bosses are in sector
    if not AdventurerGuide.canSpawn() then return end

    -- don't spawn if within barrier
    local x, y = sector:getCoordinates()
    if (x * x + y * y) < Balancing_GetBlockRingMax() then return end
    if Galaxy():sectorInRift(x, y) then return end

    local faction = Galaxy():getNearestFaction(player:getHomeSectorCoordinates())
    local volume = Balancing_GetSectorShipVolume(faction:getHomeSectorCoordinates())

    local pos = random():getVector(-1000, 1000)
    local matrix = MatrixLookUpPosition(-pos, vec3(0, 1, 0), pos)

    local ship = ShipGenerator.createMilitaryShip(faction, matrix, volume)

    local language = faction:getLanguage()
    language.seed = Server().seed

    local name = language:getName()

    ship:setTitle("${name} The Adventurer"%_t, {name = name})
    ship:addScript("story/progressionwarningadventurer.lua")
    ship:setValue("no_attack_events", true)

    ship.invincible = true

    Placer.resolveIntersections({ship})

    Boarding(ship).boardable = false
    ship.dockable = false

    return ship
end

return AdventurerGuide
