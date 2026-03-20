package.path = package.path .. ";data/scripts/lib/?.lua"
include("stringutility")
include("callable")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace EmptyInteract
EmptyInteract = {}
local data = {}

function EmptyInteract.initialize(maxDistance)
    if onServer() then
        data.maxDistance = maxDistance

    else
        EmptyInteract.sync()
    end
end

if onClient() then
function EmptyInteract.interactionPossible()
    if not data.maxDistance then
        return true
    end

    local craft = Player().craft
    if craft then
        return Entity():getNearestDistance(craft) <= data.maxDistance
    end

    return false
end
end

function EmptyInteract.sync(dataIn)
    if onClient() then
        if not dataIn then
            invokeServerFunction("sync")
        else
            data = dataIn
        end

    else
        if callingPlayer then
            local player = Player(callingPlayer)
            invokeClientFunction(player, "sync", data)
        else
            broadcastInvokeClientFunction("sync", data)
        end
    end
end
callable(EmptyInteract, "sync")

function EmptyInteract.secure()
    return data
end

function EmptyInteract.restore(dataIn)
    data = dataIn
end
