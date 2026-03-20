package.path = package.path .. ";data/scripts/lib/?.lua"

include ("stringutility")
include ("callable")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Beacon
Beacon = {}

local window
local text = ""
local args = {}

function Beacon.initialize(text_in, args_in)
    if onServer() then
        text = text_in or ""
        args = args_in or {}
    else
        Player():registerCallback("onPreRenderHud", "onPreRenderHud")

        Beacon.sync()
    end
end

function Beacon.interactionPossible(player, option)
    if option == 0 then
        if Player().index == Entity().factionIndex then return 1 end
        return false
    end
    return true
end

function Beacon.initUI()
    local res = getResolution()
    local size = vec2(400, 150)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    menu:registerWindow(window, "Set Beacon Welcome Message"%_t, 2)

    window.caption = "Beacon Text"%_t
    window.showCloseButton = 1
    window.moveable = 1

    local hsplit = UIHorizontalSplitter(Rect(window.size), 10, 10, 0.5)
    hsplit.bottomSize = 35

    textBox = window:createMultiLineTextBox(hsplit.top)
    textBox.text = InteractionText(Entity().index).text
    textBox.setFontSize = 15
    textBox.clearOnClick = true;

    local vsplit = UIVerticalSplitter(hsplit.bottom, 10, 0, 0.5)
    window:createButton(vsplit.left, "Save"%_t, "onSaveClick")
    window:createButton(vsplit.right, "Cancel"%_t, "onCancelClick")

    menu:registerInteraction("Close"%_t, "onCloseClick")
end

function Beacon.onPreRenderHud()
    local player = Player()
    if not player then return end

    if player.state == PlayerStateType.BuildCraft or player.state == PlayerStateType.BuildTurret or player.state == PlayerStateType.PhotoMode then return end

    if os.time() % 2 == 0 then
        local renderer = UIRenderer()
        renderer:renderEntityTargeter(Entity(), ColorRGB(1, 1, 1));
        renderer:display()
    end
end

function Beacon.onSaveClick()
    invokeServerFunction("setText", textBox.text)
    window:hide()
end

function Beacon.onCancelClick()
    window:hide()
    textBox.text = InteractionText(Entity().index).text
end

function Beacon.onCloseClick()
    local player = Player(callingPlayer)
    if not player then return end

    player:sendCallback("onBeaconMessageRead", Entity().id.string)
end

function Beacon.onShowWindow()
    textBox.text = InteractionText(Entity().index).text
end

function Beacon.setText(text_in, args_in)
    if callingPlayer and callingPlayer ~= Entity().factionIndex then return end

    args = args_in or {}
    text = text_in or ""
    broadcastInvokeClientFunction("sync", text, args)
end
callable(Beacon, "setText")

function Beacon.getText()
    return text
end

function Beacon.sync(text_in, args_in)
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
callable(Beacon, "sync")

function Beacon.secure()
    return {text = text, args = args}
end

function Beacon.restore(values)
    text = values.text or ""
    args = values.args or {}
end





