
-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace ReactionChatterMemory
ReactionChatterMemory = {}

local sent = {}

function ReactionChatterMemory.trySendChatter(chatteringEntity, changeType, message)
    local now = appTime()
    local factionIndex = chatteringEntity.factionIndex
    local key = tostring(factionIndex) .. "_" .. tostring(changeType)

    local lastSent = sent[key]
    if lastSent and now - lastSent < 15 * 60 then
        return
    end

    sent[key] = now

    Player():sendChatMessage(chatteringEntity, ChatMessageType.Chatter, message)
end
