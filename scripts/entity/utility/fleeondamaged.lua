package.path = package.path .. ";data/scripts/lib/?.lua"

include("stringutility")
include("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace FleeOnDamaged
FleeOnDamaged = {}

FleeOnDamaged.data = {}
local data = FleeOnDamaged.data

local messages =
{
    "That was a mistake, we're out!"%_T,
    "Too dangerous, we're out!"%_T,
    "Too dangerous, let's run!"%_T,
    "Too dangerous, let's get out of here!"%_T,
    "Taking too much damage, let's get out!"%_T,
    "Too much damage, we're out of here!"%_T,
}

local chattered

if onServer() then

function FleeOnDamaged.getUpdateInterval()
    return 1
end

function FleeOnDamaged.initialize(percentage)
    if _restoring then return end

    percentage = percentage or 0.30
    -- we only take damage until a certain percentage of our health
    data.percentage = percentage

end

function FleeOnDamaged.updateServer(timeStep)

    local self = Entity()

    -- once we reached critical damage, run away
    if self.durability / self.maxDurability <= data.percentage + 0.01 then
        if self.aiOwned then
            if not chattered then
                chattered = true

                local sector = Sector()
                local message = randomEntry(messages)
                sector:broadcastChatMessage(self, ChatMessageType.Chatter, message)
            end

            self:addScriptOnce("deletejumped.lua", 6.5)
        end
    end

end

function FleeOnDamaged.secure()
    return data
end

function FleeOnDamaged.restore(data_in)
    data = data_in
end

end
