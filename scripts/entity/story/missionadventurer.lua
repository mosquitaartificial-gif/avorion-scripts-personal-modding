package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("callable")
include ("utility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace MissionAdventurer
MissionAdventurer = {}

local data = {}
data.script = nil
data.dialog = nil
data.currentOnEnd = nil
data.allowGreet = true
data.immediateDialog = true
data.synced = onServer() -- on startup, we simply want this to be true on server, false on client

function MissionAdventurer.initialize(allowInteraction, immediateDialog)
    if onClient() then MissionAdventurer.sync() end
    data.allowGreet = allowInteraction
    data.immediateDialog = immediateDialog
end

function MissionAdventurer.getUpdateInterval()
    return 1.0
end

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function MissionAdventurer.interactionPossible(playerIndex, option)
    return data.allowGreet
end

function MissionAdventurer.initUI()
    if data.allowGreet and data.dialog then
        ScriptUI():registerInteraction("Greet"%_t, "onGreet")
    end
end

function MissionAdventurer.updateClient(timestep)
    if not data.synced then return end
    if MissionAdventurer.hailRejected or data.hailAccepted then return end
    if not data.dialog or not data.dialog.text then return end
    if data.hail then
        ScriptUI():startHailing("onHailAccepted", "onHailRejected")
    else
        if data.immediateDialog then
            MissionAdventurer.onHailAccepted()
        end
    end
end

-- use this to relay onEnd function of dialog back to player script
-- This can be called more than once because onGreet shows the same dialog!
function MissionAdventurer.onEnd()
    Player(callingPlayer):invokeFunction(data.script, data.currentOnEnd)
end

function MissionAdventurer.onHailAccepted()
    data.hailAccepted = true
    Player(callingPlayer):invokeFunction(data.script, "onHailAccepted")
    ScriptUI():interactShowDialog(data.dialog or {})
end

function MissionAdventurer.onHailRejected()
    MissionAdventurer.hailRejected = true
    Player(callingPlayer):invokeFunction(data.script, "onHailRejected")
end

function MissionAdventurer.generateCallbackFunctions(dialog, callee, script)
    if not dialog then return end
    if type(dialog.onEnd) == "string" then
        local callbackName = dialog.onEnd

        if not MissionAdventurer[callbackName] then
            MissionAdventurer[callbackName] = function()
                Player(callingPlayer):invokeFunction(script, callbackName)
            end
        end
    end

    if dialog.answers then
        for _, answer in pairs(dialog.answers) do
            MissionAdventurer.generateCallbackFunctions(answer.followUp, callee, script)
        end
    end
end

function MissionAdventurer.onGreet()
    ScriptUI():interactShowDialog(data.dialog or {})
end

function MissionAdventurer.setData(reset, hail, dialog)

    if reset then MissionAdventurer.resetHailBehavior() end
    MissionAdventurer.setHail(hail)
    MissionAdventurer.setDialog(dialog)

    -- make sure script is set sometime before with setInteractingScript, otherwise dialog callbacks wont work
    MissionAdventurer.generateCallbackFunctions(dialog, Player(calllingPlayer), data.script)

    if onClient() then invokeServerFunction("setData", reset, hail, dialog) end
end
callable(MissionAdventurer, "setData")

function MissionAdventurer.setHail(value)
    data.hail = value
end

function MissionAdventurer.setDialog(dialog_in)
    data.dialog = dialog_in
end

function MissionAdventurer.setInteractingScript(script_in)
    data.script = script_in
end

function MissionAdventurer.resetHailBehavior()
    MissionAdventurer.hailRejected = false
    data.hailAccepted = false
end

function MissionAdventurer.sync(data_in)
    if onServer() then
        local player
        if not callingPlayer then
            broadcastInvokeClientFunction("sync", data)
        else
            invokeClientFunction(Player(callingPlayer), "sync", data)
        end
    else
        if data_in then
            data = data_in
        else
            invokeServerFunction("sync")
        end
    end
end
callable(MissionAdventurer, "sync")

function MissionAdventurer.secure()
    return data
end

function MissionAdventurer.restore(data_in)
    data = data_in
    MissionAdventurer.sync()
end
