package.path = package.path .. ";data/scripts/lib/?.lua"
include("callable")

-- this API provides code for npcs that will speak to the player by themselves, a single time.
-- Dynamic Namespace SingleInteraction

local SingleInteraction = {}
SingleInteraction.getDialog = nil -- function SingleInteraction.getDialog() must be defined in the script, which should return the dialog that is to be displayed.

SingleInteraction.data = {}
local data = SingleInteraction.data

data.hail = false -- set to true if the NPC should hail the player instead of just forcing the dialog open (recommended)
-- Set to a unique string, if this specific interaction shall happen only once per server.
-- useful when spawning multiple NPCs with the same interaction script
data.globalInteractionKey = nil
data.closeableDialog = true

-- Internals
data.interacted = {}
data.synced = onServer() -- on startup, we simply want this to be true on server, false on client

-- client only
-- is set to true on client after the player rejects the hail, so no more hails are done.
-- This variable is client-only and thus reset on re-entering the sector, re-enabling hailing
SingleInteraction.hailRejected = nil

function SingleInteraction.interactionPossible(player, option)
    return true
end

function SingleInteraction.initialize()
    if onClient() then SingleInteraction.sync() end
end

function SingleInteraction.getUpdateInterval()
    return 1.0
end

function SingleInteraction.updateClient(timeStep)
    if not data.synced then return end
    if SingleInteraction.getInteractedWithPlayer() then return end
    if SingleInteraction.hailRejected then return end

    if data.hail then
        ScriptUI():startHailing("onHailAccepted", "onHailRejected")
    else
        SingleInteraction.onHailAccepted()
    end
end

function SingleInteraction.onHailAccepted()
    SingleInteraction.rememberSuccessfulInteractionWithPlayer()

    ScriptUI():interactShowDialog(SingleInteraction.getDialog(), data.closeableDialog)
end

function SingleInteraction.onHailRejected()
    SingleInteraction.rememberUnsuccessfulInteractionWithPlayer()
end

function SingleInteraction.getInteractedWithPlayer()
    if data.globalInteractionKey then
        return Player():getValue("single_interaction_interacted_" .. data.globalInteractionKey) or false
    end

    return data.interacted[Player().index] or false
end

function SingleInteraction.rememberSuccessfulInteractionWithPlayer()
    local player = nil

    if onClient() then
        -- remember that we interacted with the player
        player = Player()

        invokeServerFunction("rememberSuccessfulInteractionWithPlayer")
    else
        player = Player(callingPlayer)
    end

    data.interacted[player.index] = true

    if onServer() then
        if data.globalInteractionKey then
            player:setValue("single_interaction_interacted_" .. data.globalInteractionKey, true)
        end

        SingleInteraction.sync()
    end
end
callable(SingleInteraction, "rememberSuccessfulInteractionWithPlayer")

function SingleInteraction.rememberUnsuccessfulInteractionWithPlayer()
    SingleInteraction.hailRejected = true
end

function SingleInteraction.sync(data_in)
    if onServer() then
        invokeClientFunction(Player(callingPlayer), "sync", data)
    else
        if data_in then
            data = data_in
        else
            invokeServerFunction("sync")
        end
    end
end
callable(SingleInteraction, "sync")

function SingleInteraction.secure()
    return data
end

function SingleInteraction.restore(data_in)
    data = data_in
end

return SingleInteraction
