package.path = package.path .. ";data/scripts/lib/?.lua"

include("stringutility")
include("randomext")
local SectorTurretGenerator = include ("sectorturretgenerator")
local ShipGenerator = include("shipgenerator")
local ShipUtility = include("shiputility")
local Balancing = include("galaxy")

local Smuggler = {}

function Smuggler.getFaction()
    local name = "Bottan's Smugglers"%_T
    local faction = Galaxy():findFaction(name)

    if not faction then
        faction = Galaxy():createFaction(name, 240, 0)
    end

    faction.initialRelationsToPlayer = 0
    faction.staticRelationsToPlayers = true
    faction.homeSectorUnknown = true

    return faction
end


function Smuggler.spawn(x, y)
    if not x or not y then
        x, y = Sector():getCoordinates()
    end

    -- only spawn him once
    if Sector():getEntitiesByScript("data/scripts/entity/story/smuggler.lua") then return end

    -- spawn
    local faction = Smuggler.getFaction()
    local volume = Balancing_GetSectorShipVolume(faction:getHomeSectorCoordinates()) * 15

    local translation = random():getDirection() * 500
    local position = MatrixLookUpPosition(-translation, vec3(0, 1, 0), translation)


    local boss = ShipGenerator.createShip(faction, position, volume)
    ShipUtility.addArmedTurretsToCraft(boss, 15)
    boss.title = "Bottan"

    -- adds legendary turret drop
    boss:addScriptOnce("internal/common/entity/background/legendaryloot.lua")
    boss:addScriptOnce("utility/buildingknowledgeloot.lua", Material(MaterialType.Trinium))

    Loot(boss.index):insert(InventoryTurret(SectorTurretGenerator():generate(x, y, 0, Rarity(RarityType.Exotic))))
    Loot(boss.index):insert(SystemUpgradeTemplate("data/scripts/systems/teleporterkey8.lua", Rarity(RarityType.Legendary), Seed(1)))

    boss:addScript("story/smuggler.lua")
    boss:setValue("no_attack_events", true)

    Boarding(boss).boardable = false
    boss.dockable = false

    return boss
end

function Smuggler.spawnEngineer(x, y)

    if not x or not y then
        x, y = Sector():getCoordinates()
    end

    -- only spawn him once
    if Sector():getEntitiesByScript("data/scripts/entity/story/smugglerengineer.lua") then return end

    -- spawn
    local faction = Smuggler.getFaction()
    local volume = Balancing_GetSectorShipVolume(faction:getHomeSectorCoordinates()) * 2

    local translation = random():getDirection() * 500
    local position = MatrixLookUpPosition(-translation, vec3(0, 1, 0), translation)


    local entity = ShipGenerator.createShip(faction, position, volume)
    ShipUtility.addArmedTurretsToCraft(entity, 15)
    entity.title = "A Friend"%_T

    entity:addScript("story/smugglerengineer.lua")
    entity:setValue("no_attack_events", true)

    local player = Player()
    if player then
        ShipAI(entity.index):registerFriendFaction(player)
    end

    Boarding(entity).boardable = false
    entity.dockable = false

    return entity
end

function Smuggler.spawnRepresentative(station)

    -- don't spawn him in the center
    local x, y = Sector():getCoordinates()
    local coords = vec2(x, y)
    if length2(coords) < Balancing.BlockRingMin2 then return end

    -- only spawn him once
    local representatives = {Sector():getEntitiesByScript("story/smugglerrepresentative.lua")}
    if #representatives > 0 then
        representatives[1] = nil

        for _, entity in pairs(representatives) do
            Sector():deleteEntity(entity)
        end

        return
    end

    -- spawn
    local faction = Smuggler.getFaction()
    local volume = Balancing_GetSectorShipVolume(faction:getHomeSectorCoordinates()) * 2

    local translation = random():getDirection() * 500
    local position = MatrixLookUpPosition(-translation, vec3(0, 1, 0), translation)

    local entity = ShipGenerator.createShip(faction, Matrix(), volume)
    ShipUtility.addArmedTurretsToCraft(entity, 15)
    entity:addScript("story/smugglerrepresentative.lua")
    entity:addScript("utility/deleteonhitbyshots.lua")

    entity.invincible = true

    local plan = entity:getMovePlan()
    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))
    plan:setMaterialTier(material)
    entity:setMovePlan(plan)

    local distance = station:getBoundingSphere().radius + entity:getBoundingSphere().radius + 10
    local position = station.position
    position.pos = position.pos + position.up * distance
    entity.position = position

    ShipAI(entity):setPassive()
    Boarding(entity).boardable = false
    entity.dockable = false

    local galaxy = Galaxy()
    galaxy:setFactionRelations(Faction(station.factionIndex), faction, 0)
    galaxy:setFactionRelationStatus(Faction(station.factionIndex), faction, RelationStatus.Neutral)

    return entity
end

return Smuggler
