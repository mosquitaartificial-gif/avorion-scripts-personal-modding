package.path = package.path .. ";data/scripts/lib/?.lua"

include("stringutility")
include("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace KOBehavior
KOBehavior = {}


-- NOTE:
-- Use the Sector callback "onReviveKOShips" to revive KO'ed ships.
-- KO'ed ships get a revive ID that must match the revive ID sent in the callback


KOBehavior.data = {}
local data = KOBehavior.data
local chatterThreshold = 120.0
local chatterTimer = chatterThreshold

local koCallbackSent = nil

local messages =
{
    "We're stranded!"%_T,
    "Generators are down, we can't move!"%_T,
    "Critical damage, we can't move!"%_T,
    "We've taken critical damage, ship isn't flying anymore!"%_T,
    "Mayday, Mayday! Critical Damage!"%_T,
    "Generator is damaged, we can't move!"%_T,
    "We've taken critical damage, we're not flying anywhere!"%_T,
}

if onServer() then

function KOBehavior.getUpdateInterval()
    return 1
end

function KOBehavior.initialize(percentage, reviveId)

    if onServer() then
        Sector():registerCallback("onReviveKOShips", "onRevive")
    end

    if _restoring then return end

    percentage = percentage or 0.10

    data.percentage = percentage -- we only take damage until a certain percentage of our health
    data.reviveId = reviveId -- id that must match in order to revive successfully

    Durability().invincibility = percentage
end

function KOBehavior.updateServer(timeStep)

    local self = Entity()

    -- make sure that entites with koscript can't escape if they happen to get the fleeondamaged script
    if self:hasScript("data/scripts/entity/utility/fleeondamaged.lua") then
        self:removeScript("data/scripts/entity/utility/fleeondamaged.lua")
    end

    -- once we reached critical damage, we're "KO"
    if self.durability / self.maxDurability <= data.percentage + 0.01 then

        -- set AI to passive
        local ai = ShipAI()
        ai:setPassive()
        ai:setPassiveShooting(false)

        -- remove special AI orders
        for index, name in pairs(self:getScripts()) do
            if string.match(name, "data/scripts/entity/ai/") then
                self:removeScript(index)
            end
        end

        -- chater about critical damage
        chatterTimer = chatterTimer + timeStep
        if chatterTimer > chatterThreshold then
            chatterTimer = 0
            chatterThreshold = 90 + random():getInt(0, 30)

            local message = randomEntry(messages)
            Sector():broadcastChatMessage(self, ChatMessageType.Chatter, message)
        end

        if not koCallbackSent then
            koCallbackSent = true
            Entity():sendCallback("onEntityKOed", self.id.string, data.reviveId)
            Sector():sendCallback("onEntityKOed", self.id.string, data.reviveId)
        end
    end
end

-- reviveId is a string containing a key that must match in order to revive the entity of this script
function KOBehavior.onRevive(reviveId)
    if not reviveId then
        local entity = Entity()
        local str = entity.type
        eprint("%s %s %s Error: Received a revive callback without a revive ID", entity.typename or "", entity.translatedTitle or "", entity.name or "")
        return
    end

    if data.reviveId and reviveId == data.reviveId then
        KOBehavior.revive()
    end
end

function KOBehavior.revive()
    local entity = Entity()

    entity.durability = entity.maxDurability
end

function KOBehavior.secure()
    return data
end

function KOBehavior.restore(data_in)
    data = data_in

    Durability().invincibility = data.percentage
end

end
