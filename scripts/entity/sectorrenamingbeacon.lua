package.path = package.path .. ";data/scripts/lib/?.lua"

include("callable")
include("stringutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace SectorRenamingBeacon
SectorRenamingBeacon = {}

local window
local nameField
local oldNameLabel

function SectorRenamingBeacon.interactionPossible(playerIndex, option)
    return true
end

-- create all required UI elements for the client side
function SectorRenamingBeacon.initUI()
    local res = getResolution()
    local size = vec2(400, 160)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))

    window.caption = "Rename Sector"%_t
    window.showCloseButton = 1
    window.moveable = 1

    menu:registerWindow(window, "Enter new name"%_t, 4);

    local size = window.size

    local hsplit = UIHorizontalSplitter(Rect(vec2(10, 10), size - vec2(10, 10)), 0, 0, 0.5)
    hsplit.bottomSize = 45
    local hsplitTop = UIHorizontalSplitter(hsplit.top, 5, 5, 0.3)
    local vsplit = UIVerticalSplitter(hsplit.top, 5, 5, 0.4)
    local vsplitLeft = UIVerticalSplitter(vsplit.left, 0, 0, 0.05)

    -- old sector name
    window:createLabel(vsplitLeft.right, "Current Name:"%_t, 15)
    oldNameLabel = window:createLabel(vsplit.right, "", 15)

    -- text field
    local vsplitLeft = UIVerticalSplitter(hsplitTop.bottom, 5, 5, 0.15)
    local vsplitRight = UIVerticalSplitter(vsplitLeft.right, 5, 5, 0.82)
    nameField = window:createTextBox(vsplitRight.left, "")
    nameField.maxCharacters = 20
    window:createFrame(vsplitRight.left)

    -- buttons
    local vsplit = UIVerticalSplitter(hsplit.bottom, 5, 5, 0.5)
    local confirmButton = window:createButton(vsplit.left, "Confirm"%_t, "onConfirmPressed")
    confirmButton.maxTextSize = 15
    local cancelButton = window:createButton(vsplit.right, "Cancel"%_t, "onCancelPressed")
    cancelButton.maxTextSize = 15

    invokeServerFunction("showSectorName")
end

-- client functions

function SectorRenamingBeacon.onShowWindow()
    invokeServerFunction("showSectorName")
    nameField.text = ""
end

function SectorRenamingBeacon.onConfirmPressed()
    local newName
    if nameField.text ~= "" then
        newName = nameField.text
    else
        local x, y = Sector():getCoordinates()
        newName = x .. " : " .. y
    end

    invokeServerFunction("renameSectorOnServer", newName)

    window:hide()
end

function SectorRenamingBeacon.onCancelPressed()
    window:hide()
end

function SectorRenamingBeacon.fillSectorNameField(name)
    oldNameLabel.caption = "\"" .. name .. "\""
end

function SectorRenamingBeacon.renameSectorOnClient(name)
    if onServer() then return end

    Sector().name = name
end

-- server functions

function SectorRenamingBeacon.showSectorName()
    local name = Sector().name

    invokeClientFunction(Player(callingPlayer), "fillSectorNameField", name)
end
callable(SectorRenamingBeacon, "showSectorName")

function SectorRenamingBeacon.renameSectorOnServer(name)
    if onClient() then return end

    local x, y = Sector():getCoordinates()
    local player = Player(callingPlayer)
    local controllingFaction = Galaxy():getControllingFaction(x, y)

    if controllingFaction.index == player.index then
        Sector().name = name
        broadcastInvokeClientFunction("renameSectorOnClient", name)
    elseif player.alliance and controllingFaction.index == player.allianceIndex then
        if player.alliance:hasPrivilege(player.index, AlliancePrivilege.ManageStations) then
            Sector().name = name
            broadcastInvokeClientFunction("renameSectorOnClient", name)
        else
            player:sendChatMessage("", ChatMessageType.Error, "You don't have permission to use the beacon in the name of your alliance."%_T)
        end
    else
        player:sendChatMessage("", ChatMessageType.Error, "Can’t use beacon in a sector that you don't control."%_T)
    end
end
callable(SectorRenamingBeacon, "renameSectorOnServer")






