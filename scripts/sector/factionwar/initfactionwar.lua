
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/sector/factionwar/?.lua"
include("factionwarutility")
include("randomext")

local searchTries = 0
local retryScheduled = false

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace InitFactionWar
InitFactionWar = {}
InitFactionWar.maxSearchTries = 5

if onServer() then

function InitFactionWar.initialize()
    Sector():registerCallback("onPlayerEntered", "onPlayerEntered")
end

function InitFactionWar.onPlayerEntered(playerIndex, sectorChangeType)
    if sectorChangeType == SectorChangeType.Forced then
        InitFactionWar.scheduleRetry(60 * 10)
        return
    end

    InitFactionWar.tryStartBattle()
end

function InitFactionWar.retry()
    retryScheduled = false
    InitFactionWar.tryStartBattle()
end

function InitFactionWar.scheduleRetry(time)
    DebugInfo():log("InitFactionWar.scheduleRetry()")

    if not retryScheduled then
        deferredCallback(time, "retry") -- try again later
        retryScheduled = true
    end

    DebugInfo():log("~InitFactionWar.scheduleRetry()")
end

function InitFactionWar.tryStartBattle()
    DebugInfo():log("InitFactionWar.tryStartBattle()")

--     print ("try starting faction battle")

    local faction, enemyFaction = InitFactionWar.getLocalEnemies()
    if not faction or not enemyFaction then        
        DebugInfo():log("InitFactionWar: No faction")

        InitFactionWar.scheduleRetry(60 * 10)
--         print ("no faction or no enemy faction")
        return
    end

    -- check if there are players who don't participate in the war
    local unwitnessedPlayers, players = InitFactionWar.hasUnwitnessedPlayers(faction)

    -- don't schedule retries if there are no players in the sector
    -- don't use resources when we don't have to
    if players == 0 then
        DebugInfo():log("InitFactionWar: No players")
--         print ("no players")
        return
    end

    local startEvent = false
    -- definitely schedule a battle if there are players who don't know about the war yet
    if unwitnessedPlayers then startEvent = true end

    -- otherwise, try starting the event with a certain chance
    if random():test(0.15) then startEvent = true end

    if startEvent then
        DebugInfo():log("InitFactionWar: Start battle")

--         print ("starting event: battle between factions " .. faction.name .. " and " .. enemyFaction.name)
        deferredCallback(30.0, "startBattle", faction.index, enemyFaction.index)
        Galaxy():setFactionRelations(faction, enemyFaction, -100000)
        Galaxy():setFactionRelationStatus(faction, enemyFaction, RelationStatus.War)

        -- no retry callback here on purpose
        -- don't reattack the same sector over and over
        -- battles will still be scheduled again when the sector gets unloaded and reloaded
    else
        DebugInfo():log("InitFactionWar: Not starting battle")

--         print ("unwitnessed players: " .. tostring(unwitnessedPlayers))
--         print ("randomly not successful or no players")
--         print ("players: %i", players)

        -- didn't work out, try again in a few minutes
        InitFactionWar.scheduleRetry(60 * 10)
    end

    DebugInfo():log("~InitFactionWar.tryStartBattle()")
end

function InitFactionWar.hasUnwitnessedPlayers(faction)
    DebugInfo():log("InitFactionWar.hasUnwitnessedPlayers")

    local key = getFactionWarSideVariableName(faction)
    local players = {Sector():getPlayers()}
    for _, player in pairs(players) do
        if not player:getValue(key) then
            DebugInfo():log("~InitFactionWar.hasUnwitnessedPlayers true")
            return true, #players
        end
    end

    DebugInfo():log("~InitFactionWar.hasUnwitnessedPlayers false")

    return false, #players
end

function InitFactionWar.getLocalEnemies()
    DebugInfo():log("InitFactionWar.getLocalEnemies")

    local sector = Sector()
    local x, y = sector:getCoordinates()

    local galaxy = Galaxy()
    local faction = galaxy:getControllingFaction(x, y)
    if not faction or not faction.isAIFaction then
--         print ("no local AI faction found")
        DebugInfo():log("~InitFactionWar.getLocalEnemies: No local AI faction")
        return
    end

    -- if the faction doesn't have an enemy yet, find one at random
    local enemyFaction
    local enemyFactionIndex = faction:getValue("enemy_faction")
    if enemyFactionIndex and enemyFactionIndex == -1 then
--         print ("faction does not participate in faction wars")
        DebugInfo():log("~InitFactionWar.getLocalEnemies: Faction doesn't participate")
        return
    end

    if enemyFactionIndex then
        DebugInfo():log("InitFactionWar.getLocalEnemies: Found Enemy")

        -- make sure to only "find" enemy factions when we're actually near enemy territory
        for i = 1, 20 do
            local dir = random():get2DDirection() * 15
            local ox, oy = x + dir.x, y + dir.y

            local other = galaxy:getControllingFaction(ox, oy)

            if not other then other = galaxy:getLocalFaction(ox, oy) end

            if other and other.index == enemyFactionIndex then
                enemyFaction = Faction(enemyFactionIndex)
                DebugInfo():log("InitFactionWar.getLocalEnemies: Found nearby enemy")
                return faction, enemyFaction
            end
        end

        DebugInfo():log("InitFactionWar.getLocalEnemies: Enemy not nearby")
--        print ("enemy faction is not nearby")

    else
        searchTries = searchTries + 1

        if searchTries > InitFactionWar.maxSearchTries then
            -- if there have already been too many tries, just stop
--            print ("too many tries of finding an enemy, stopping")
            DebugInfo():log("~InitFactionWar.getLocalEnemies: No enemy found, stopping")
            return
        end

        DebugInfo():log("InitFactionWar.getLocalEnemies: Search nearby factions")

        -- check if there's a controlling AI faction nearby
        for i = 1, 20 do
            local dir = random():get2DDirection() * random():getFloat(15, 25)
            local ox, oy = x + dir.x, y + dir.y

            local enemy = galaxy:getControllingFaction(ox, oy)
            if enemy
                and enemy.index ~= faction.index
                and not enemy.isPlayer
                and not enemy:getValue("enemy_faction") then

                enemyFactionIndex = enemy.index
                break
            end
        end

        DebugInfo():log("InitFactionWar.getLocalEnemies: Search nearby factions 2")
        -- check if there's a AI faction living nearby
        if not enemyFactionIndex then
            for i = 1, 20 do
                local dir = random():get2DDirection() * random():getFloat(15, 25)
                local ox, oy = x + dir.x, y + dir.y

                local enemy = galaxy:getLocalFaction(ox, oy)
                if enemy
                    and enemy.index ~= faction.index
                    and not enemy.isPlayer
                    and not enemy:getValue("enemy_faction") then

                    enemyFactionIndex = enemy.index
                    break
                end
            end
        end

        if not enemyFactionIndex then
            DebugInfo():log("~InitFactionWar.getLocalEnemies: No enemy faction found")
--             print ("no enemy faction found")
            return
        end

        enemyFaction = Faction(enemyFactionIndex)
        if not enemyFaction then
            DebugInfo():log("~InitFactionWar.getLocalEnemies: Potential enemy is not a faction")
--             print ("enemy not a faction?")
            return
        end

        -- at least one of the factions must be aggressive
        if faction:getTrait("aggressive") < 0.85 and enemyFaction:getTrait("aggressive") < 0.85 then
            DebugInfo():log("~InitFactionWar.getLocalEnemies: No aggressors")
--             print ("none of the factions are aggressive")
            return
        end

        local enemy1 = faction:getValue("enemy_faction")
        local enemy2 = enemyFaction:getValue("enemy_faction")

        if not enemy1 and not enemy2 then
            enemyFaction:setValue("enemy_faction", faction.index)
            faction:setValue("enemy_faction", enemyFaction.index)
        else
            return
        end

        DebugInfo():log("~InitFactionWar.getLocalEnemies: Found enemies")
        return faction, enemyFaction
    end

    DebugInfo():log("~InitFactionWar.getLocalEnemies: Found no enemies")
end

function InitFactionWar.startBattle(defenders, attackers)
    DebugInfo():log("InitFactionWar.startBattle()")

    Sector():addScriptOnce("factionwar/factionwarbattle.lua", defenders, attackers)

    DebugInfo():log("~InitFactionWar.startBattle()")
end















end
