package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
include("utility")
include("stringutility")
include("structuredmission")
local MissionUT = include("missionutility")

--mission.tracing = true

mission.data.silent = true

mission.data.custom.missions = {
    -- artifacts and the corresponding mission in order of appearance
    {artifactNr = 4, path = "player/story/buymission.lua", active = false, fulfilled = false},
    {artifactNr = 8, path = "player/story/bottanmission.lua", active = false, fulfilled = false},
    {artifactNr = 6, path = "player/story/aimission.lua", active = false, fulfilled = false},
    {artifactNr = 2, path = "player/story/researchmission.lua", active = false, fulfilled = false},
    {artifactNr = 7, path = "player/story/scientistmission.lua", active = false, fulfilled = false},
    {artifactNr = 1, path = "player/story/exodusmission.lua", active = false, fulfilled = false},
    {artifactNr = 5, path = "player/story/the4mission.lua", active = false, fulfilled = false},
}
mission.data.custom.HermitLocation = {}

local startTwoMissionsAtOnce = true

mission.globalPhase.onRestore = function()
    local phaseId = Player():getValue("story_advance")
    -- upon relog we let phase run again and add any mission that is active and not fulfilled again in case it got lost
    setPhase(phaseId)
end

-- extra init here, because we need to be able to rebound from a complete loss of data
-- and have the luxury of not needing any data besides the mission table above
function initialize()
    setPhase(1)

    if Player():getValue("story_completed") then
        terminate()
        return
    end
end


mission.phases[1] = {}
mission.phases[1].onBeginServer = function()
    local player = Player()
    local value = player:getValue("story_advance")
    if value and value ~= 1 then
        setPhase(value)
        return
    else
        player:setValue("story_advance", 1)
    end

    -- Swoks
    local upgradesCollected = MissionUT.detectFoundArtifacts(player)
    if not upgradesCollected[3] then
        player:addScriptOnce("player/story/swoksmission.lua")
    else
        setPhase(2)
    end
end

mission.phases[2] = {}
mission.phases[2].onBeginServer = function()
    local player = Player()
    player:setValue("story_advance", 2)
    -- explanation for artifacts -> player has to play this in every case
    player:addScriptOnce("player/story/hermitmission.lua")
end

mission.phases[3] = {}
mission.phases[3].onBeginServer = function()
    local player = Player()
    player:setValue("story_advance", 3)

    local foundUnfulfilled = false
    local foundActive = false
    local countNotFinished = 0
    for _, script in pairs(mission.data.custom.missions) do
        if checkArtifactAlreadyFound(script.artifactNr) then
            script.fulfilled = true
        else
            countNotFinished = countNotFinished + 1
            foundUnfulfilled = true
        end

        if script.active and not script.fulfilled then
            -- add mission again in case something goes wrong
            player:addScriptOnce(script.path)
            foundActive = true
        end

        if not script.active and not script.fulfilled then

            if countNotFinished > 2 then break end
            player:addScriptOnce(script.path)
            script.active = true
            foundActive = true
            if not startTwoMissionsAtOnce then
                break -- add two only once
            else
                startTwoMissionsAtOnce = false
            end
        end
    end

    if not foundUnfulfilled and not foundActive then
        setPhase(4)
    end
end

mission.phases[4] = {}
mission.phases[4].onBeginServer = function()
    local player = Player()
    player:setValue("story_advance", 4)
    -- explanation of how to cross barrier -> player has to play this
    player:addScriptOnce("player/story/crossthebarriermission.lua")
end

-- wait before going on, so that player feels the accomplishment of crossing the barrier
mission.phases[5] = {}
mission.phases[5].onBeginServer = function()
    local player = Player()
    player:setValue("story_advance", 5)
    mission.data.custom.waitTimer = 15 * 60
end
mission.phases[5].updateServer = function(timestep)
    mission.data.custom.waitTimer = mission.data.custom.waitTimer - timestep
    if mission.data.custom.waitTimer <= 0 then
        nextPhase()
    end
end
mission.phases[5].updateInterval = 5 * 60 -- every 5 min is enough

-- one last mission - kill the guardian
mission.phases[6] = {}
mission.phases[6].onBeginServer = function()
    local player = Player()
    player:setValue("story_advance", 6)
    -- big hint towards guardian -> player has to play this
    player:addScriptOnce("player/story/killguardianmission.lua")
end


-- helper
function checkArtifactAlreadyFound(artifactNr)
    local player = Player()
    local artifactsFound = MissionUT.detectFoundArtifacts(player)
    if artifactsFound[artifactNr] then
        return true
    else
        return false
    end
end

function onSwoksAccomplished()
    -- only call on server!
    setPhase(2)
end

function onHermitAccomplished()
    -- only call on server!
    setPhase(3)
end

function onHermitLocationCalculated(hermitLocationX, hermitLocationY)
    mission.data.custom.HermitLocation[1] = hermitLocationX
    mission.data.custom.HermitLocation[2] = hermitLocationY
end

function getHermitLocation()
    return mission.data.custom.HermitLocation[1], mission.data.custom.HermitLocation[2]
end

function onFollowUpQuestAccomplished()
    -- only call on server!
    setPhase(3)
end

function onCrossBarrierAccomplished()
    -- only call on server!
    setPhase(5)
end

function onKillGuardianAccomplished()
    -- only call on server!    
    local player = Player()
    player:setValue("story_completed", true)
    -- Roll credits
    player:addScriptOnce("data/scripts/player/background/playerrollcredits.lua")
    terminate()
end
