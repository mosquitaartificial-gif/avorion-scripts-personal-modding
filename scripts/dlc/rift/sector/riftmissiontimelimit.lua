package.path = package.path .. ";data/scripts/lib/?.lua"

local Xsotan = include("story/xsotan")
local WaveUtility = include("waveutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace RiftMissionTimeLimit
RiftMissionTimeLimit = {}

local timeRemaining = 0
local largeWaveCountdown = 0
local waveOffset = -2
local overstayUnlocked = false

local TimeThresholds = {}
table.insert(TimeThresholds, {
    timeRemaining = 20 * 60,
    behavior = function()
        Sector():broadcastChatMessage("Rift Research Center"%_T, ChatMessageType.Normal, "You have about 20 more minutes until the swarm should find you."%_t)
    end
})

table.insert(TimeThresholds, {
    timeRemaining = 10 * 60,
    behavior = function()
        Sector():broadcastChatMessage("Rift Research Center"%_T, ChatMessageType.Normal, "About 10 more minutes until the swarm arrives."%_t)
    end
})

table.insert(TimeThresholds, {
    timeRemaining = 7 * 60,
    behavior = function()
        Sector():broadcastChatMessage("", ChatMessageType.Information, "Your sensors picked up a short burst of subspace signals."%_t)
        Sector():broadcastChatMessage("Rift Research Center"%_T, ChatMessageType.Normal, "You should start finishing up. The swarm has detected you and is moving towards your position."%_t)
    end
})

table.insert(TimeThresholds, {
    timeRemaining = 5 * 60,
    behavior = function()
        Sector():broadcastChatMessage("", ChatMessageType.Information, "Your sensors picked up another short burst of subspace signals."%_t)
        Sector():broadcastChatMessage("Rift Research Center"%_T, ChatMessageType.Normal, "We're picking up signs that the swarm is approaching. 5 more minutes until it arrives."%_t)

        broadcastInvokeClientFunction("displaySwarmWarning", 5.0 * 60)
    end
})

table.insert(TimeThresholds, {
    timeRemaining = 2.5 * 60,
    behavior = function()
        Sector():broadcastChatMessage("", ChatMessageType.Information, "Your sensors are picking more subspace signals."%_t)
        Sector():broadcastChatMessage("Rift Research Center"%_T, ChatMessageType.Normal, "The swarm is closing in. You have 2 more minutes until it arrives."%_t)

        broadcastInvokeClientFunction("displaySwarmWarning", 2.0 * 60)
    end
})

table.insert(TimeThresholds, {
    timeRemaining = 1.0 * 60,
    behavior = function()
        Sector():broadcastChatMessage("", ChatMessageType.Information, "Your sensors are picking more subspace signals. They're getting stronger."%_t)
        Sector():broadcastChatMessage("Rift Research Center"%_T, ChatMessageType.Normal, "The swarm is coming closer! The first scouts are already showing up."%_t)

        RiftMissionTimeLimit.spawnWave(2)

        broadcastInvokeClientFunction("displaySwarmWarning", 1.0 * 60)
    end
})

table.insert(TimeThresholds, {
    timeRemaining = 0.5 * 60,
    behavior = function()
        Sector():broadcastChatMessage("", ChatMessageType.Information, "Your sensors picked up large bursts of subspace signals."%_t)
        Sector():broadcastChatMessage("Rift Research Center"%_T, ChatMessageType.Normal, "The swarm is almost there. Get out of there immediately!"%_t)

        RiftMissionTimeLimit.spawnWave(4)
        broadcastInvokeClientFunction("displaySwarmWarning", 0.5 * 60)
    end
})

table.insert(TimeThresholds, {
    timeRemaining = 0.1 * 60,
    behavior = function()
        Sector():broadcastChatMessage("", ChatMessageType.Information, "Your sensors are picking up extreme amounts of subspace signals."%_t)
        Sector():broadcastChatMessage("Rift Research Center"%_T, ChatMessageType.Normal, "The swarm has arrived! Good luck and we hope you'll get out in time!"%_t)
    end
})



if onServer() then

function RiftMissionTimeLimit.initialize(timeLimit)
    timeRemaining = timeLimit or 30 * 60

    Sector():registerCallback("onPlayerArrivalConfirmed", "onPlayerArrivalConfirmed")
end

function RiftMissionTimeLimit.getUpdateInterval()
    return 10
end

function RiftMissionTimeLimit.updateServer(timeStep)
    if Sector().numPlayers == 0 then return end

    for _, threshold in pairs(TimeThresholds) do
        if timeRemaining > threshold.timeRemaining
                and timeRemaining - timeStep <= threshold.timeRemaining then

            threshold.behavior()
        end
    end

    timeRemaining = timeRemaining - timeStep

    if timeRemaining <= 0 then
        -- spawn large waves every 60 seconds after the remaining time is over
        largeWaveCountdown = largeWaveCountdown - timeStep
        if largeWaveCountdown <= 0 then
            largeWaveCountdown = 60

            local numXsotan = Sector():getNumEntitiesByScriptValue("is_xsotan")
            if numXsotan < 20 then
                RiftMissionTimeLimit.spawnWave()
            end
        end
    end

    if timeRemaining <= -15 * 60 and not overstayUnlocked then
        for _, player in pairs({Sector():getPlayers()}) do
            player:invokeFunction("riftmission.lua", "unlockOverstayAfterTime")
        end
        overstayUnlocked = true
    end
end

function RiftMissionTimeLimit.spawnWave(numXsotan)
    -- spawn it on top of the first player in the sector
    -- this might be slightly unfair but it puts pressure on the group
    local location = vec3()

    for _, player in pairs({Sector():getPlayers()}) do
        local craft = player.craft
        if craft then
            location = craft.translationf
            break
        end
    end

    local waves = WaveUtility.getWaves(math.min(5 + waveOffset, 19), 1, 1, numXsotan or 6, 1)
    local position = MatrixLookUpPosition(random():getDirection(), random():getDirection(), location)
    local lootGoonChance = 0
    local spacing = nil
    WaveUtility.createXsotanWaveAsync(waveNumber, waves[1], position, lootGoonChance, spacing, RiftMissionTimeLimit, function(generated)
        -- no loot from enemies from this script
        for _, ship in pairs(generated) do
            ship:setValue("is_wave", true)
            ship:setDropsLoot(false)
            ship:setValue("xsotan_no_research_data", true)

        end

        RiftMissionTimeLimit.spawnSpecialXsotan(location + random():getDirection() * 200)
        Xsotan.aggroAll()
    end)

    waveOffset = waveOffset + 1
end

function RiftMissionTimeLimit.spawnSpecialXsotan(location)
    local candidates =
    {
        Xsotan.createQuantum,
        Xsotan.createCarrier,
        Xsotan.createShielded,
        Xsotan.createBuffer,
        Xsotan.createSummoner,
    }

    local spawnFunction = randomEntry(random(), candidates)
    local ship = spawnFunction(translate(Matrix(), location), 6)

    -- no loot from enemies from this script
    ship:setDropsLoot(false)
    ship:setValue("xsotan_no_research_data", true)

    return ship
end

function RiftMissionTimeLimit.onPlayerArrivalConfirmed(playerIndex)
    local minutes = math.ceil(timeRemaining / 60)
    Sector():broadcastChatMessage("Rift Research Center"%_T, ChatMessageType.Normal, "You have ca %1% minutes until the swarm arrives."%_t, minutes)
end

end

function RiftMissionTimeLimit.displaySwarmWarning(seconds)
    displayMissionAccomplishedText("SWARM WARNING"%_t, "ETA ${time}"%_t % {time = createDigitalTimeString(seconds)})
end

-- for testing
function RiftMissionTimeLimit.getLargeWaveCountdown()
    return largeWaveCountdown
end

function RiftMissionTimeLimit.getTimeRemaining()
    return timeRemaining
end
