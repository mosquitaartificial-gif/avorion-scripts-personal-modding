package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local MissionUT = include("missionutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace PirateRaidMissionStarter
PirateRaidMissionStarter = {}

if onServer() then

local data = {}
data.piratesSeen = false

function PirateRaidMissionStarter.getUpdateInterval()
    return 5
end


function PirateRaidMissionStarter.updateServer()
    if data.piratesSeen and MissionUT.countPirates() == 0 then
        PirateRaidMissionStarter.startMission()
    end

    if not data.piratesSeen and MissionUT.countPirates() > 0 then
        data.piratesSeen = true
    end
end

function PirateRaidMissionStarter.startMission()
    Player():addScriptOnce("data/scripts/player/missions/tutorials/pirateraidmission.lua")
    terminate()
end

function PirateRaidMissionStarter.secure()
    return data
end

function PirateRaidMissionStarter.restore(data_in)
    data = data_in
end

end
