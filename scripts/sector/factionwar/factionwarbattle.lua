
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/sector/factionwar/?.lua"

local AsyncShipGenerator = include("asyncshipgenerator")
local Placer = include("placer")
local SpawnUtility = include ("spawnutility")

include ("randomext")
include ("stringutility")
include ("factionwarutility")
local FactionEradicationUtility = include ("factioneradicationutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace FactionWarBattle
FactionWarBattle = {}

local data = {}
local defenderTimer = 0
local wavesSpawned = 0

if onServer() then

function FactionWarBattle.getUpdateInterval()
    return 5
end

function FactionWarBattle.initialize(defenders, attackers)
    data.defenders = defenders
    data.attackers = attackers
    data.defendersSpawned = false

    if not defenders or not attackers then
        terminate()
        return
    end

    if FactionEradicationUtility.isFactionEradicated(defenders) or FactionEradicationUtility.isFactionEradicated(attackers) then
        terminate()
        return
    end

    local defendingFaction = Faction(defenders)
    local attackingFaction = Faction(attackers)
    Galaxy():setFactionRelations(attackingFaction, defendingFaction, -100000)
    Galaxy():setFactionRelationStatus(attackingFaction, defendingFaction, RelationStatus.War)

    -- mark players as witnesses if not already witnessed
    local key = getFactionWarSideVariableName(defendingFaction)
    local players = {Sector():getPlayers()}
    for _, player in pairs(players) do
        if not player:getValue(key) then
            player:setValue(key, 0) -- 0 is meant for 'witnessed, but didn't choose a side yet'
            print("player witnessed the battle the first time, but didn't choose a side yet")
        end
    end

    -- spawn enemy ships
    FactionWarBattle.spawnShips(Faction(data.attackers))

    deferredCallback(5.0, "defendersReaction");

    -- spawn defenders shortly after
    deferredCallback(20.0, "trySpawnDefenders")
end

function FactionWarBattle.spawnShips(faction)
    local x, y = Sector():getCoordinates()

    local position = random():getDirection() * 1500
    local dir = normalize(-position)
    local up = vec3(0, 1, 0)
    local right = normalize(cross(up, dir))
    up = normalize(cross(right, dir))

    local onFinished = function(ships)
        for _, ship in pairs(ships) do
            ship:removeScript("entity/antismuggle.lua")
            ship:addScriptOnce("data/scripts/sector/factionwar/temporarydefender.lua")
        end

        Placer.resolveIntersections(ships)

        -- add enemy buffs
        SpawnUtility.addEnemyBuffs(ships)

        wavesSpawned = wavesSpawned + 1
    end

    local generator = AsyncShipGenerator(FactionWarBattle, onFinished)
    generator:startBatch()

    for i = -4, 4 do
        local pos = position + right * i * 100

        if i >= -1 and i <= 1 and random():test(0.75) then
            generator:createCarrier(faction, MatrixLookUpPosition(dir, up, pos))
        else
            generator:createDefender(faction, MatrixLookUpPosition(dir, up, pos))
        end
    end

    generator:endBatch()
end

function FactionWarBattle.defendersReaction()
    local defendingFaction = Faction(data.defenders)
    Sector():broadcastChatMessage(defendingFaction.name, ChatMessageType.Normal, "We're under attack! Call in reinforcements, NOW!"%_T)
    Sector():broadcastChatMessage(defendingFaction.name, ChatMessageType.Warning, "This sector is under attack by another faction!"%_T)
end

function FactionWarBattle.trySpawnDefenders()
    FactionWarBattle.spawnShips(Faction(data.defenders))
end

function FactionWarBattle.updateServer()

    if wavesSpawned == 0 then return end

    local temporaryDefenders = {Sector():getEntitiesByScript("factionwar/temporarydefender")}

    if #temporaryDefenders == 0 then
        terminate()
    end
end

function FactionWarBattle.secure()
    return data
end

function FactionWarBattle.restore(data_in)
    data = data_in
end

end
