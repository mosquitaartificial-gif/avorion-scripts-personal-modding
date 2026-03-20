package.path = package.path .. ";data/scripts/lib/?.lua"

include ("utility")
include ("stringutility")
include ("callable")
local OperationExodus = include("story/operationexodus")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace ExodusWormholeBeacon
ExodusWormholeBeacon = {}

local window
local codeLabel
local lastCodeEnteredLabel
local warningIcon
local confirmButton

local fragmentButtons = {}
local codeInTextfield = {}
local lastCodeEntered = 0

function ExodusWormholeBeacon.interactionPossible(playerIndex, option)
    return true
end

-- create all required UI elements for the client side
function ExodusWormholeBeacon.initUI()
    local res = getResolution()
    local size = vec2(700, 700)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))

    window.caption = "Enter Code"%_t
    window.showCloseButton = 1
    window.moveable = 1

    menu:registerWindow(window, "Enter Code"%_t, 4);

    local size = window.size

    local hsplitTop = UIHorizontalSplitter(Rect(vec2(10, 10), size - vec2(10, 10)), 5, 5, 0.5)
    hsplitTop.topSize = 35
    local hsplitBottom = UIHorizontalSplitter(hsplitTop.bottom, 0, 0, 0.5)
    hsplitBottom.bottomSize = 40

    -- top line
    local vsplit = UIVerticalSplitter(hsplitTop.top, 0, 0, 0.75)
    local vsplitRight = UIVerticalSplitter(vsplit.right, 0, 0, 0.05)
    vsplitRight:setPadding(5, 5, 2, 3)
    local vsplitLeft = UIVerticalSplitter(vsplit.left, 0, 0, 0.4)
    local vsplitFarLeft = UIVerticalSplitter(vsplitLeft.left, 0, 0, 0.9)

    local label = window:createLabel(vsplitFarLeft.left, "A B"%_t, 15)
    label:setRightAligned()

    codeLabel = window:createLabel(vsplitLeft.right, "", 15)
    codeLabel:setCenterAligned()
    codeLabel.width = 200

    local codeFrame = window:createFrame(vsplitLeft.right)
    codeFrame.width = 200

    window:createButton(vsplitRight.right, "Clear"%_t, "onClearPressed")

    -- button field
    window:createFrame(hsplitBottom.top)

    local gsplit = UIGridSplitter(hsplitBottom.top, 5, 5, 16, 16)

    for i = 0, 255 do
        fragmentButtons[i] = {};
        fragmentButtons[i].button = window:createButton(gsplit:partition(i), OperationExodus.convertToHexadecimal(i), "onCodeFragmentEntered")
        fragmentButtons[i].button.fontType = FontType.Normal
        fragmentButtons[i].button.uppercase = false
        fragmentButtons[i].button.maxTextSize = 14
        fragmentButtons[i].code = OperationExodus.convertToHexadecimal(i)
    end

    -- bottom line
    local vsplit = UIVerticalSplitter(hsplitBottom.bottom, 0, 0, 0.75)
    local vsplitRight = UIVerticalSplitter(vsplit.right, 0, 0, 0.05)
    vsplitRight:setPadding(5, 5, 7, 3)
    local vsplitLeft = UIVerticalSplitter(vsplit.left, 0, 0, 0.5)
    vsplitLeft:setPadding(5, 5, 7, 3)
    vsplitLeft:setLeftQuadratic()

    warningIcon = window:createPicture(vsplitLeft.left, "data/textures/icons/hazard-sign.png")
    warningIcon.isIcon = true
    warningIcon.color = ColorRGB(1, 0, 0)
    warningIcon:hide()

    lastCodeEnteredLabel = window:createLabel(vsplitLeft.right, "Access Denied. System temporarily locked."%_t, 15)
    lastCodeEnteredLabel:setLeftAligned()
    lastCodeEnteredLabel.color = ColorRGB(1, 0, 0)
    lastCodeEnteredLabel:hide()

    confirmButton = window:createButton(vsplitRight.right, "Confirm"%_t, "onConfirmPressed")

    invokeServerFunction("sendBeaconStatus")
end

function ExodusWormholeBeacon.onCodeFragmentEntered(button)
    local code
    for i = 0, #fragmentButtons do
        if fragmentButtons[i].button.index == button.index then
            code = fragmentButtons[i].code
            break
        end
    end

    -- update label but don't let if overflow
    if #codeInTextfield < 6 then
        codeLabel.caption = codeLabel.caption .. code
        table.insert(codeInTextfield, code)
    end
end

function ExodusWormholeBeacon.onClearPressed()
    codeLabel.caption = ""
    codeInTextfield = {}
end

function ExodusWormholeBeacon.onConfirmPressed()
    invokeServerFunction("checkCode", codeInTextfield)
end

function ExodusWormholeBeacon.checkCode(codeInTextfield)
    local runtime = Server().unpausedRuntime
    if lastCodeEntered ~= 0 and runtime - lastCodeEntered < 30 * 60 then return end

    local code = OperationExodus.getCodeFragments()

    if code.a == codeInTextfield[1] and code.b == codeInTextfield[2] then
        ExodusWormholeBeacon.openWormhole()
        invokeClientFunction(Player(callingPlayer), "closeWindow")
    else
        invokeClientFunction(Player(callingPlayer), "updateBeaconStatus", false)
        lastCodeEntered = Server().unpausedRuntime
    end
end
callable(ExodusWormholeBeacon, "checkCode")

function ExodusWormholeBeacon.sendBeaconStatus()
    if not lastCodeEntered then lastCodeEntered = 0 end

    local runtime = Server().unpausedRuntime

    local enabled = false
    if lastCodeEntered == 0 or runtime - lastCodeEntered >= 30 * 60 then
        enabled = true
    end

    invokeClientFunction(Player(callingPlayer), "updateBeaconStatus", enabled)
end
callable(ExodusWormholeBeacon, "sendBeaconStatus")

function ExodusWormholeBeacon.closeWindow()
    window:hide()
end

function ExodusWormholeBeacon.updateClient(timestep)
    invokeServerFunction("sendBeaconStatus")
end

function ExodusWormholeBeacon.getUpdateInterval()
    return 60 -- since we don't actually say how long the button will be inactive, it doesn't matter if we only update once a minute
end

function ExodusWormholeBeacon.updateBeaconStatus(buttonActive)
    if not confirmButton then return end

    if buttonActive == true then
        confirmButton.active = true
        warningIcon:hide()
        lastCodeEnteredLabel:hide()
    else
        confirmButton.active = false
        warningIcon:show()
        lastCodeEnteredLabel:show()
    end
end

function ExodusWormholeBeacon.openWormhole()
    local wormhole = Sector():getEntitiesByScriptValue("exodus_wormhole")
    if wormhole then return end

    local beacon = Entity()
    beacon:setValue("untransferrable", true)
    local closestCorner = ExodusWormholeBeacon.getClosestCorner()
    local desc = WormholeDescriptor()
    desc:addComponent(ComponentType.DeletionTimer)

    local cpwormhole = desc:getComponent(ComponentType.WormHole)
    cpwormhole.color = ColorRGB(1, 0, 0)
    cpwormhole:setTargetCoordinates(closestCorner.x, closestCorner.y)
    cpwormhole.visualSize = 250
    cpwormhole.passageSize = math.huge
    -- we want the wormhole to be one-way only
    cpwormhole.oneWay = true

    desc:addScriptOnce("data/scripts/entity/wormhole.lua")

    desc.translation = dvec3(beacon.translationf + beacon.look * beacon.radius * 150)

    local wormHole = Sector():createEntity(desc)
    wormHole:setValue("exodus_wormhole", true)

    DeletionTimer(wormHole).timeLeft = 5 * 60 -- open for 5 minutes
end

function ExodusWormholeBeacon.getClosestCorner()
    local corners = OperationExodus.getCornerPoints()
    local x, y = Sector():getCoordinates()

    local eval = function (e)
        local a = e.x - x
        local b = e.y - y
        return a * a + b * b
    end

    return findMinimum(corners, eval)
end

function ExodusWormholeBeacon.secure()
    return {lastCodeEntered = lastCodeEntered}
end

function ExodusWormholeBeacon.restore(data)
    lastCodeEntered = data.lastCodeEntered
end

