package.path = package.path .. ";data/scripts/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"

include ("structuredmission")
local MissionUT = include ("missionutility")

-- mission.tracing = true

-- This mission is extra information for the player to explain what happens during the Xsotan Swarm Event and what he has to do

-- mission data
mission.data.brief = "Fight off the Xsotan Invasion!"%_T
mission.data.title = "Xsotan Invasion"%_T
mission.data.autoTrackMission = true

mission.data.targets = {}
mission.data.description = {}
mission.data.description[1] = "Masses of Xsotan are invading the center of the galaxy! Help and defeat as many as you can!"%_T
mission.data.description[2] = {text = "Defeat the first wave"%_T, bulletPoint = true, visible = false}
mission.data.description[3] = {text = "Defeat the second wave"%_T, bulletPoint = true, visible = false}
mission.data.description[4] = {text = "Defeat the third wave"%_T, bulletPoint = true, visible = false}
mission.data.description[5] = {text = "Defeat the fourth wave"%_T, bulletPoint = true, visible = false}
mission.data.description[6] = {text = "Defeat the Xsotan Invasion Overseer before he can mark the sector as a passage point!"%_T, bulletPoint = true, visible = false}
mission.data.description[7] = {text = "Go to sector (${x}:${y}) to help!"%_T, bulletPoint = true, visible = false}

-- custom messages as we treat this as event
mission.data.silent = true
local accomplishMessage = "SWARM DEFEATED"%_T
local failMessage = "EVENT FAILED"%_T
local missionStartedMessage = "NEW EVENT"%_T

mission.globalPhase.updateServer = function()
    local server = Server()
    if server:getValue("xsotan_swarm_success") == true then
        showMissionMessage(accomplishMessage)
        terminate()
    elseif server:getValue("xsotan_swarm_success") == false then
        showMissionMessage(failMessage)
        terminate()
    end

    if not server:getValue("xsotan_swarm_active") then
        terminate()
    end
end
mission.globalPhase.onSectorEntered = function(x, y)
    if not MissionUT.checkSectorInsideBarrier(x, y) then
        terminate()
    end
end

mission.phases[1] = {}
mission.phases[1].onBeginServer = function()
    local server = Server()
    server:registerCallback("onXsotanSwarmEndBossSpawned", "onXsotanSwarmEndBossSpawned")
    Player():registerCallback("onSectorArrivalConfirmed", "onSectorArrivalConfirmed")

    if server:getValue("xsotan_swarm_end_boss_fight") then
        -- a sector was already played until end boss -> quick jump to phase that shows where to find that boss
        local x = server:getValue("xsotan_swarm_end_boss_fight_x", x)
        local y = server:getValue("xsotan_swarm_end_boss_fight_y", y)

        local cx, cy = Sector():getCoordinates()
        if cx ~= x or cy ~= y then
            mission.data.description[7].visible = true
        end

        mission.data.description[7].arguments = {x = x, y = y}
        mission.data.location = {x = x, y = y}

        setPhase(2)
    end
end
mission.phases[1].onBeginClient = function()
    displayMissionAccomplishedText(missionStartedMessage, mission.data.title)
end
mission.phases[1].updateServer = function()
    local ok, level = Sector():invokeFunction("data/scripts/sector/xsotanswarm.lua", "getActiveLevel")
    if not ok then return end

    if level == 1 and not mission.data.description[2].visible then
        mission.data.description[2].visible = true
        sync()
    elseif level == 2 and not mission.data.description[2].fulfilled then
        mission.data.description[2].fulfilled = true
        mission.data.description[3].visible = true
        sync()
    elseif level == 3 and not mission.data.description[3].fulfilled then
        mission.data.description[3].fulfilled = true
        mission.data.description[4].visible = true
        sync()
    elseif level == 4 and not mission.data.description[4].fulfilled then
        mission.data.description[4].fulfilled = true
        mission.data.description[5].visible = true
        sync()
    elseif level == 5 and not mission.data.description[5].fulfilled then
        mission.data.description[5].fulfilled = true
        nextPhase()
    end
end

mission.phases[2] = {}
mission.phases[2].showUpdateOnStart = true
mission.phases[2].onBegin = function()
    for i = 2, 5 do
        mission.data.description[i].fulfilled = true
    end

    mission.data.description[6].visible = true

    local prototype = Sector():getEntitiesByScriptValue("xsotan_swarm_end_boss")
    if not prototype then return end

    table.insert(mission.data.targets, prototype.id.string)
end

function onXsotanSwarmEndBossSpawned(x, y)
    local cx, cy = Sector():getCoordinates()
    if cx ~= x or cy ~= y then
        mission.data.description[7].visible = true
    end

    mission.data.description[7].arguments = {x = x, y = y}
    mission.data.location = {x = x, y = y}
    setPhase(2)
end

function onSectorArrivalConfirmed(playerIndex, x, y)
    -- player moved to end boss fight
    if mission.data.location.x == x and mission.data.location.y == y then
        mission.data.description[7].fulfilled = true
        setPhase(2)
    else
        if mission.data.location and mission.data.location.x and mission.data.location.y then
            mission.data.description[7].visible = true
            mission.data.description[7].fulfilled = false
            mission.data.description[7].arguments = mission.data.location
            sync()
        end
    end
end

function showMissionMessage(message)
    if onServer() then
        invokeClientFunction(Player(), "showMissionMessage", message)
        return
    end

    displayMissionAccomplishedText(message, mission.data.title)
end
