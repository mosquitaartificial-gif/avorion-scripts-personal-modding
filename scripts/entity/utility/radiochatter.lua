package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace EntityRadioChatter
EntityRadioChatter = {}

local data = {}
data.lines = {} -- selection of lines that will be used at random
data.minFrequency = 45
data.maxFrequency = 65
data.timeToFirst = random():getInt(5, data.minFrequency)
data.speechBubbleOnly = false

local frequencyQueried

if onServer() then

function EntityRadioChatter.getUpdateInterval()
    if not frequencyQueried then
        frequencyQueried = true;
        return data.timeToFirst or data.minFrequency
    end

    return random():getInt(data.minFrequency, data.maxFrequency)
end

function EntityRadioChatter.initialize(lines, minFrequency, maxFrequency, timeToFirst, speechBubbleOnly)
    if not _restoring then
        data.lines = lines
        data.minFrequency = minFrequency or data.minFrequency
        data.maxFrequency = maxFrequency or data.maxFrequency
        data.timeToFirst = timeToFirst or random():getInt(5, data.minFrequency)
        data.speechBubbleOnly = speechBubbleOnly or false
    end
end

function EntityRadioChatter.update(timeStep)
    data.lines = data.lines or {}
    if #data.lines == 0 then return end

    local message = randomEntry(random(), data.lines)
    local sector = Sector()

    if data.speechBubbleOnly then
        broadcastInvokeClientFunction("showChatterClient", message)
    else
        sector:broadcastChatMessage(Entity(), ChatMessageType.Chatter, message)
    end
end

function EntityRadioChatter.secure()
    return data
end

function EntityRadioChatter.restore(data_in)
    data = data_in
end

end

if onClient() then

function EntityRadioChatter.showChatterClient(message)
    displaySpeechBubble(Entity(), GetLocalizedString(message))
end

end

