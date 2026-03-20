package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace RiftBackgroundThunder
RiftBackgroundThunder = {}

local soundTimer = 0
local soundInterval = 10
function RiftBackgroundThunder.updateClient(timeStep)
    soundTimer = soundTimer + timeStep

    if soundTimer > soundInterval  then
        RiftBackgroundThunder.playSound()

        soundInterval = random():getFloat(10, 30)
        soundTimer = 0
    end
end

function RiftBackgroundThunder.playSound()
    local craft = Player().craft
    if not craft then return end

    local playerPosition = craft.translationf
    local position = playerPosition + random():getDirection() * 10000

    local sounds =
    {
        "distant-thunder1",
        "distant-thunder2",
        "distant-thunder3",
        "distant-thunder4"
    }
    play3DSound(randomEntry(sounds), SoundType.Other, position, 200000, 1)
end
