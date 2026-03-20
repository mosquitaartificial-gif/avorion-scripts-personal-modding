
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
include("galaxy")
include("player")
include("randomext")
local Xsotan = include("story/xsotan")
local SpawnUtility = include ("spawnutility")
local EventUT = include ("eventutility")
local AsyncXsotanGenerator = include ("asyncxsotangenerator")

local minute = 0
local attackType = 1

if onServer() then

function initialize(attackType_in)
    attackType = attackType_in or 1
    deferredCallback(1.0, "update", 1.0)

    if not EventUT.attackEventAllowed() then
        terminate()
        return
    end

    local xsotanPresent = Sector():getNumEntitiesByScriptValue("is_xsotan")
    if xsotanPresent > 0 then
        terminate()
        return
    end
end

function getUpdateInterval()
    return 60
end

function update(timeStep)

    if not EventUT.attackEventAllowed() then
        terminate()
        return
    end

    minute = minute + 1

    if attackType == 0 then

        if minute == 1 then
            Player():sendChatMessage("", 3, "Your sensors picked up a short burst of subspace signals."%_t)
        elseif minute == 4 then
            Player():sendChatMessage("", 3, "More strange subspace signals. They're getting stronger."%_t)
        elseif minute == 5 then
            createEnemies({
                  {size=1, title="Xsotan Scout"%_t},
                  {size=1, title="Xsotan Scout"%_t},
                  {size=1, title="Xsotan Scout"%_t},
                  }, attackType)

            Player():sendChatMessage("", 2, "A small group of alien ships has appeared!"%_t)
        end

    elseif attackType == 1 then

        if minute == 1 then
            Player():sendChatMessage("", 3, "Your sensors picked up short bursts of subspace signals."%_t)
        elseif minute == 4 then
            Player():sendChatMessage("", 3, "The signals are growing stronger."%_t)
        elseif minute == 5 then
            createEnemies({
                  {size=1, title="Xsotan Scout"%_t},
                  {size=3, title="Xsotan Ship"%_t},
                  {size=3, title="Xsotan Ship"%_t},
                  {size=1, title="Xsotan Scout"%_t},
                  }, attackType)

            Player():sendChatMessage("", 2, "A group of alien ships have warped in!"%_t)
        end

    elseif attackType == 2 then

        if minute == 1 then
            Player():sendChatMessage("", 3, "Your sensors picked up short bursts of subspace signals."%_t)
        elseif minute == 4 then
            Player():sendChatMessage("", 3, "There are lots and lots of subspace signals! Careful!"%_t)
        elseif minute == 5 then

            createEnemies({
                  {size=1, title="Xsotan Scout"%_t},
                  {size=2, title="Xsotan Scout"%_t},
                  {size=3, title="Xsotan Ship"%_t},
                  {size=5, title="Big Xsotan Ship"%_t},
                  {size=3, title="Xsotan Ship"%_t},
                  {size=2, title="Xsotan Scout"%_t},
                  {size=1, title="Xsotan Scout"%_t},
                  }, attackType)

            Player():sendChatMessage("", 2, "A large group of alien ships has appeared!"%_t)
        end

    elseif attackType == 3 then

        if minute == 1 then
            Player():sendChatMessage("", 3, "Your sensors picked up short bursts of subspace signals."%_t)
        elseif minute == 4 then
            Player():sendChatMessage("", 3, "The subspace signals are getting too strong for your scanners. Brace yourself!"%_t)
        elseif minute == 5 then

            createEnemies({
                  {size=1, title="Xsotan Scout"%_t},
                  {size=1, title="Xsotan Scout"%_t},
                  {size=2, title="Xsotan Scout"%_t},
                  {size=3, title="Xsotan Ship"%_t},
                  {size=3, title="Xsotan Ship"%_t},
                  {size=5, title="Big Xsotan Ship"%_t},
                  {size=3, title="Xsotan Ship"%_t},
                  {size=3, title="Xsotan Ship"%_t},
                  {size=2, title="Xsotan Scout"%_t},
                  {size=1, title="Xsotan Scout"%_t},
                  {size=1, title="Xsotan Scout"%_t},
                  }, attackType)

            Player():sendChatMessage("", 2, "Danger! A large fleet of alien ships has appeared!"%_t)
        end

    end

end


function createEnemies(volumes, attackType, message)
    local sector = Sector()
    local xsotanFaction = Xsotan.getFaction()

    local xsotanPresent = Sector():getNumEntitiesByScriptValue("is_xsotan")
    if xsotanPresent > 0 then
        terminate()
        return
    end

    local galaxy = Galaxy()

    -- worsen relations to all present players and alliances
    local factions = {sector:getPresentFactions()}
    for _, factionIndex in pairs(factions) do
        local faction = Faction(factionIndex)
        if faction then
            if faction.isAIFaction then
                galaxy:setFactionRelations(xsotanFaction, faction, -100000)
                galaxy:setFactionRelationStatus(xsotanFaction, faction, RelationStatus.War)
            else
                galaxy:setFactionRelations(xsotanFaction, faction, 0, false, false)
                galaxy:setFactionRelationStatus(xsotanFaction, faction, RelationStatus.Neutral, false, false)
            end
        end
    end

    -- create the enemies
    local generator = AsyncXsotanGenerator(nil, function(generated)
        -- patrol.lua takes care of setting aggressive

        -- add enemy buffs
        SpawnUtility.addEnemyBuffs(generated)

        AlertAbsentPlayers(ChatMessageType.Warning, "A group of alien ships has appeared in sector \\s(%1%:%2%)!"%_t, sector:getCoordinates())
        terminate()
    end)

    local dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
    local up = vec3(0, 1, 0)
    local right = normalize(cross(dir, up))
    local pos = dir * 1500
    -- spawn special xsotan
    -- don't spawn carrier, as the xsotan fighters are too much here
    -- don't spawn rift DLC xsotan outside of rifts
    local spawnedSummoner = false
    local spawnedQuantum = false
    generator:startBatch()
    for _, p in pairs(volumes) do
        if attackType > 1 and not spawnedSummoner and random():test(0.1) then
            generator:createSummoner(MatrixLookUpPosition(-dir, up, pos), p.size)
            spawnedSummoner = true
        elseif attackType > 1 and not spawnedQuantum and random():test(0.1) then
            generator:createQuantum(MatrixLookUpPosition(-dir, up, pos), p.size)
            spawnedQuantum = true
        else
            generator:createShip(MatrixLookUpPosition(-dir, up, pos), p.size)
        end

        pos = pos + right * 100
    end
    generator:endBatch()
end



end
