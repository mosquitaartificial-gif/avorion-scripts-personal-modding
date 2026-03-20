
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace SpawnPersecutors
SpawnPersecutors = {}

include("randomext")
include("stringutility")
include("persecutorutility")
local AsyncShipGenerator = include ("asyncshipgenerator")
local Placer = include ("placer")
local SpawnUtility = include ("spawnutility")

if onServer() then

function SpawnPersecutors.getUpdateInterval()
    local time = 300
    if GameSettings().difficulty < Difficulty.Veteran then
        time = time + (Difficulty.Veteran - GameSettings().difficulty) * 60
    end

    -- randomize the time a litte to reduce likelihood of race conditions in code below
    -- ... which, even if they happened, wouldn't be game breaking or anything
    return time + random():getInt(0, 60)
end

function SpawnPersecutors.initialize()
end

function SpawnPersecutors.update()

    local persecutedShip = sectorGetPersecutedCraft()
    if not persecutedShip then
        return
    end

    local sector = Sector()

    -- reduce amount of attacks in sectors without players
    if sector.numPlayers == 0 then
        local player = Faction(persecutedShip.factionIndex)
        if player.isPlayer or player.isAlliance then
            local now = Server().runtime

            -- don't be an ass to players and only attack their lone & weak crafts every 35 minutes
            local minutes = 35
            local seconds = minutes * 60

            -- this is a potential race condition, but the worst case would be a very low probability double attack on 2 sectors
            local lastattack = player:getValue("last_oos_persecutor_attack") or -seconds -- minus to allow spawning from the start on
            if now - lastattack < seconds then
                return
            end

            player:setValue("last_oos_persecutor_attack", now)
        end
    end

    local faction = Galaxy():getPirateFaction(Balancing_GetPirateLevel(sector:getCoordinates()))

    local resolveIntersections = function(ships)
        Placer.resolveIntersections(ships)

        for i, ship in pairs(ships) do
            ship:addScript("entity/ai/persecutor.lua")
            ship:setValue("is_persecutor", true)
            if i == 1 then ship:addScript("entity/dialogs/encounters/persecutor.lua") end
        end

        -- add enemy buffs
        SpawnUtility.addEnemyBuffs(ships)
    end

    local generator = AsyncShipGenerator(SpawnPersecutors, resolveIntersections)

    local dir = random():getDirection()
    local matrix = MatrixLookUpPosition(-dir, vec3(0,1,0), persecutedShip.translationf + dir * 2000)

    generator:startBatch()
    generator:createPersecutorShip(faction, matrix)
    generator:createPersecutorShip(faction, matrix)
    generator:createDisruptorShip(faction, matrix)
    generator:createDisruptorShip(faction, matrix)
    generator:endBatch()

    local faction = Faction(persecutedShip.factionIndex)
    if faction.isPlayer then
        faction = Player(faction.index)

        local x, y = sector:getCoordinates()
        local px, py = faction:getSectorCoordinates()
        if x == px and y == py then
            faction = nil
        end

    elseif faction.isAlliance then
        faction = Alliance(faction.index)
    end

    if faction then
        faction:sendChatMessage("", 2, [[A craft is under attack in sector \s(%1%:%2%)!]]%_T, sector:getCoordinates())
    end

end

end
