package.path = package.path .. ";data/scripts/lib/?.lua"

include ("stringutility")
include ("callable")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace MessageBeacon
MessageBeacon = {}

local window
local text = ""
local args = {}
local numberCharactersLabel
local maxCharacters = 280

function MessageBeacon.initialize(text_in)
    if onServer() then
        text = text_in or ""
    else
        Player():registerCallback("onPreRenderHud", "onPreRenderHud")

        MessageBeacon.sync()
    end
end

function MessageBeacon.interactionPossible(playerIndex, option)
    if option == 0 then
        local beacon = Entity()
        local beaconFactionIndex = beacon.factionIndex
        local beaconFaction = Faction(beaconFactionIndex)
        local player = Player(playerIndex)

        if beaconFaction.isAIFaction then return false
        elseif beaconFaction.isAlliance and player.allianceIndex == beaconFactionIndex then return true
        elseif beaconFaction.isPlayer and playerIndex == beaconFactionIndex then return true
        end

        return false
    end

    return true
end

function MessageBeacon.initUI()
    local res = getResolution()
    local size = vec2(400, 190)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    menu:registerWindow(window, "Set New Message"%_t, 2)

    window.caption = "Change Beacon Message"%_t
    window.showCloseButton = 1
    window.moveable = 1

    local hsplit = UIHorizontalSplitter(Rect(window.size), 0, 10, 0.5)
    hsplit.bottomSize = 35

    local hsplitTop = UIHorizontalSplitter(hsplit.top, 5, 0, 0.8)

    textBox = window:createMultiLineTextBox(hsplitTop.top)
    textBox.text = InteractionText(Entity().index).text
    textBox.setFontSize = 15
    textBox.maxCharacters = maxCharacters
    textBox.clearOnClick = true;

    local numberCharactersString = textBox.getNumberCharacters .. " / " .. maxCharacters
    numberCharactersLabel = window:createLabel(hsplitTop.bottom, numberCharactersString, 15)
    numberCharactersLabel.centered = true;

    local vsplitBottom = UIVerticalSplitter(hsplit.bottom, 10, 0, 0.5)

    window:createButton(vsplitBottom.left, "Save"%_t, "onSaveClick")
    window:createButton(vsplitBottom.right, "Cancel"%_t, "onCancelClick")

    menu:registerInteraction("Close"%_t, "onCloseClick")
end

function MessageBeacon.update(timestep)
    if numberCharactersLabel and textBox and textBox.isTypingActive then
        local numberCharacters = textBox.getNumberCharacters
        numberCharactersLabel.caption = numberCharacters .. " / " .. maxCharacters

        if (numberCharacters >= maxCharacters) then
            numberCharactersLabel.color = ColorRGB(1.0, 0.0, 0.0)
        else
            numberCharactersLabel.color = ColorRGB(1.0, 1.0, 1.0)
        end
    end
end

function MessageBeacon.onPreRenderHud()
    local player = Player()
    if not player then return end

    if player.state == PlayerStateType.BuildCraft or player.state == PlayerStateType.BuildTurret or player.state == PlayerStateType.PhotoMode then return end

    if os.time() % 2 == 0 then
        local renderer = UIRenderer()
        renderer:renderEntityTargeter(Entity(), ColorRGB(1, 1, 1));
        renderer:display()
    end
end

function MessageBeacon.onSaveClick()
    invokeServerFunction("setText", textBox.text)
    window:hide()
end

function MessageBeacon.onCancelClick()
    window:hide()
    textBox.text = InteractionText(Entity().index).text
end

function MessageBeacon.onCloseClick()
    local player = Player(callingPlayer)
    if not player then return end

    player:sendCallback("onMessageBeaconMessageRead", Entity().id.string)
end

function MessageBeacon.setText(text_in, args_in)
    if callingPlayer then
        local beacon = Entity()
        local beaconFactionIndex = beacon.factionIndex
        local beaconFaction = Faction(beaconFactionIndex)
        local player = Player(callingPlayer)

        if beaconFaction.isAIFaction then return end
        if beaconFaction.isAlliance and player.allianceIndex ~= beaconFactionIndex then return end
        if beaconFaction.isPlayer and callingPlayer ~= beaconFactionIndex then return end

        text = text_in or ""

        beacon:removeScript("data/scripts/entity/utility/radiochatter.lua")
        beacon:addScriptOnce("data/scripts/entity/utility/radiochatter.lua", { text }, 4 * 60, 5 * 60, 3, true)
        player:sendChatMessage("", ChatMessageType.Information, "Message set successfully. Thanks for choosing PCL's Message Transmitter! /* Pioneer Company Limited */"%_t)
    end

    text = text_in or ""

    broadcastInvokeClientFunction("sync", text, args)
end
callable(MessageBeacon, "setText")

function MessageBeacon.getText()
    return text
end

function MessageBeacon.sync(text_in, args_in)
    if onClient() then
        if text_in then
            InteractionText(Entity().index).text = text_in%_t % (args_in or {})
            text = text_in
        else
            invokeServerFunction("sync")
        end
    else
        invokeClientFunction(Player(callingPlayer), "sync", text, args)
    end

end
callable(MessageBeacon, "sync")

function MessageBeacon.secure()
    return {text = text, args = args}
end

function MessageBeacon.restore(values)
    text = values.text or ""
    args = values.args or {}
end







