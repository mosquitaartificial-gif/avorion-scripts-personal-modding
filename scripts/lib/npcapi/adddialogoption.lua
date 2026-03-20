package.path = package.path .. ";data/scripts/lib/?.lua"

include ("stringutility")
include ("callable")


-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace AddDialogOption
AddDialogOption = {}
AddDialogOption.data = {}

function AddDialogOption.secure()
    return AddDialogOption.data
end

function AddDialogOption.restore(data)
    AddDialogOption.data = data
end

function AddDialogOption.initialize(playerIndex, interactionText, playerDialog, wrongPlayerDialog, arguments)
    AddDialogOption.data.playerIndex = playerIndex
    AddDialogOption.data.interactionText = interactionText
    AddDialogOption.data.playerDialog = playerDialog
    AddDialogOption.data.wrongPlayerDialog = wrongPlayerDialog
    AddDialogOption.data.arguments = arguments

    if onClient() then
        Entity():registerCallback("onStartDialog", "onStartDialog")

        AddDialogOption.sync()
    end
end

function AddDialogOption.sync(data)
    if onClient() then
        if data == nil then
            invokeServerFunction("sync")
        else
            AddDialogOption.data = data
        end

        return
    else

        invokeClientFunction(Player(callingPlayer), "sync", AddDialogOption.data)
    end
end
callable(AddDialogOption, "sync")

function AddDialogOption.onStartDialog(entityId)
    local scriptUI = ScriptUI()
    if not scriptUI then return end

    scriptUI:addDialogOption(AddDialogOption.data.interactionText%_t, "onShowDialog")
end

function AddDialogOption.onShowDialog()
    local playerIndex = 0
    local player = Player()
    if player then playerIndex = player.index end

    local dialog = {}
    if AddDialogOption.data.playerIndex == playerIndex then
        dialog.text = AddDialogOption.data.playerDialog%_t % AddDialogOption.data.arguments
    else
        dialog.text = AddDialogOption.data.wrongPlayerDialog%_t % AddDialogOption.data.arguments
    end

    ScriptUI():interactShowDialog(dialog, true)
end
