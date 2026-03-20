
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("galaxy")
include ("randomext")
include ("stringutility")
include ("player")
include ("faction")

local Placer = include ("placer")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local AsyncShipGenerator = include ("asyncshipgenerator")
local SpawnUtility = include ("spawnutility")

if onServer() then

function initialize(playerIndex, entityName)
    local entry = ShipDatabaseEntry(playerIndex, entityName)
    local sector = Sector()
    local controllingFaction = Galaxy():getControllingFaction(sector:getCoordinates())

    if controllingFaction and controllingFaction.isAIFaction then
        -- check if owner has beef with controlling faction
        local relation = controllingFaction:getRelation(playerIndex)
        if relation.status == RelationStatus.War then
            spawnFaction(controllingFaction, entry)
            return
        end
    end

    spawnPirates(entry)
end

function spawnPirates(entry)
    local sector = Sector()
    local generator = AsyncPirateGenerator(nil, onPiratesGenerated)

    local dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
    local up = vec3(0, 1, 0)
    local right = normalize(cross(dir, up))
    local pos = dir * 1000
    local distance = 150 --distance between ships

    generator:startBatch()

    generator:createScaledRaider(MatrixLookUpPosition(-dir, up, pos))
    generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos + right * distance))
    generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos - right * distance))

    generator:endBatch()

    if entry:getEntityType() == EntityType.Station then
        Player(entry.faction):sendChatMessage(entry.name, ChatMessageType.Warning, "Your station in sector \\s(%1%:%2%) is under attack!"%_T, sector:getCoordinates())
    else
        Player(entry.faction):sendChatMessage(entry.name, ChatMessageType.Warning, "Your ship in sector \\s(%1%:%2%) is under attack!"%_T, sector:getCoordinates())
    end
end

function spawnFaction(faction, entry)
    local faction = faction
    local sector = Sector()
    local dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
    local up = vec3(0, 1, 0)
    local right = normalize(cross(dir, up))
    local pos = dir * 1000
    local distance = 150 --distance between ships

    local x, y = sector:getCoordinates()
    local volume = Balancing_GetSectorShipVolume(x, y)

    local generator = AsyncShipGenerator(nil, onFactionGenerated)

    generator:startBatch()

    generator:createMilitaryShip(faction, MatrixLookUpPosition(dir, up, pos), volume)
    generator:createMilitaryShip(faction, MatrixLookUpPosition(dir, up, pos + right * distance), volume)
    generator:createMilitaryShip(faction, MatrixLookUpPosition(dir, up, pos - right * distance), volume)

    generator:endBatch()

    if entry:getEntityType() == EntityType.Station then
        Player(entry.faction):sendChatMessage(entry.name, ChatMessageType.Warning, "Your station in sector \\s(%1%:%2%) is under attack!"%_T, sector:getCoordinates())
    else
        Player(entry.faction):sendChatMessage(entry.name, ChatMessageType.Warning, "Your ship in sector \\s(%1%:%2%) is under attack!"%_T, sector:getCoordinates())
    end
end

function onPiratesGenerated(ships)
    -- add enemy buffs
    SpawnUtility.addEnemyBuffs(ships)

    for _, ship in pairs(ships) do
        ship:setValue("is_passive_attack", true)
    end

    -- resolve intersections between generated ships
    Placer.resolveIntersections(ships)

    terminate()
end

function onFactionGenerated(ships)
    -- add enemy buffs
    SpawnUtility.addEnemyBuffs(ships)

    for _, ship in pairs(ships) do
        ship:setValue("is_passive_attack", true)
    end

    -- resolve intersections between generated ships
    Placer.resolveIntersections(ships)

    terminate()
end

end

