package.path = package.path .. ";data/scripts/lib/?.lua"

include("callable")
include("stringutility")
include("utility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace MarkerBuoy
MarkerBuoy = {}

local data = {}
data.color = ColorRGB(0.6, 0.6, 0.6).html
data.icon = ""
data.text = "Buoy online."%_T
data.initialMessageSet = false


local colorSelection = nil
local iconSelection = nil
local textBox = nil
local colors = nil


function MarkerBuoy.interactionPossible(playerIndex, option)
    local buoyFaction = Entity().factionIndex
    local player = Player()

    return buoyFaction == player.index or buoyFaction == player.allianceIndex
end

function MarkerBuoy.initialize()
    if onServer() then
        local self = Entity()
        self.title = "Marker Buoy"%_T
        self:setValue("ai_no_attack", true) -- not attacked by AI ships
    end


    if onClient() then
        MarkerBuoy.sendInitialMessage("Buoy online."%_t)
        MarkerBuoy.sync()
        Player():registerCallback("onPostRenderIndicators", "onPostRenderIndicators")
    end
end

function MarkerBuoy.sendInitialMessage(msg)
    if data.initialMessageSet then return end

    data.text = msg
    InteractionText().text = msg
    data.initialMessageSet = true
end
rcall(MarkerBuoy, "sendInitialMessage")

-- create all required UI elements for the client side
function MarkerBuoy.initUI()
    local res = getResolution()
    local size = vec2(400, 400)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))

    window.caption = "Marker Buoy"%_t
    window.showCloseButton = 1
    window.moveable = 1

    menu:registerWindow(window, "Configure"%_t, 4);

    local hmsplit = UIHorizontalMultiSplitter(Rect(window.size), 10, 10, 2)

    colorSelection = window:createSelection(hmsplit:partition(0), 10)
    colorSelection:add(ColorSelectionItem(Color(0, 0, 0, 0)))

    for _, color in pairs(MarkerBuoy.getColors()) do
        local item = ColorSelectionItem(color)
        item.hasTooltip = false
        colorSelection:add(item)
    end
    colorSelection.onSelectedFunction = "onColorSelected"
    colorSelection.hasSelectedItemFrame = true

    iconSelection = window:createSelection(hmsplit:partition(1), 10)
    for _, icon in pairs(MarkerBuoy.getIcons()) do
        iconSelection:add(PixelIconSelectionItem(icon))
    end
    iconSelection.onSelectedFunction = "onIconSelected"
    iconSelection.hasSelectedItemFrame = true

    textBox = window:createMultiLineTextBox(hmsplit:partition(2), "onTextChanged")
    textBox.maxCharacters = 300

end

function MarkerBuoy.onPostRenderIndicators()
    local self = Entity()

    local renderer = UIRenderer()

    if data.color then
        renderer:renderEntityTargeter(self, Color(data.color))
    end

    if data.icon and data.icon ~= "" then
        local indicator = TargetIndicator(self)

        renderer:renderPixelIcon(indicator.rect.lower + vec2(4), Color(data.color), data.icon)
    end

    renderer:display()
end

function MarkerBuoy.onColorSelected(...)
    local selected = colorSelection.selected
    MarkerBuoy.setData()
end

function MarkerBuoy.onIconSelected(...)
    local selected = iconSelection.selected
    MarkerBuoy.setData()
end

function MarkerBuoy.setData(dataIn)
    if onClient() then
        local newData = {}
        local colorItem = colorSelection.selected
        if colorItem then
            newData.color = colorItem.color.html
        end

        local iconItem = iconSelection.selected
        if iconItem then
            newData.icon = iconItem.icon
        end

        newData.text = textBox.text

        invokeServerFunction("setData", newData)
    else
        local player = Player(callingPlayer)
        local buoyFaction = Entity().factionIndex

        if buoyFaction == player.index or buoyFaction == player.allianceIndex then
            for k, v in pairs(dataIn) do
                data[k] = v
            end

            data.text = string.sub(data.text, 0, 300)

            InteractionText().text = data.text

            MarkerBuoy.sync()
        end
    end
end
callable(MarkerBuoy, "setData")

-- client functions
function MarkerBuoy.onShowWindow()
    textBox.text = data.text

    for key, item in pairs(colorSelection:getItems()) do
        if item.color.html == data.color then
            colorSelection:selectNoCallback(key)
            break
        end
    end

    for key, item in pairs(iconSelection:getItems()) do
        if item.icon == data.icon then
            iconSelection:selectNoCallback(key)
            break
        end
    end
end

function MarkerBuoy.onCloseWindow()
    MarkerBuoy.setData()
end

function MarkerBuoy.sync(dataIn)
    if onServer() then
        broadcastInvokeClientFunction("sync", data)
    else
        if dataIn then
            data = dataIn
        else
            invokeServerFunction("sync")
        end
    end
end
callable(MarkerBuoy, "sync")

function MarkerBuoy.secure()
    return data
end

function MarkerBuoy.restore(dataIn)
    data = dataIn
    InteractionText().text = data.text or ""
end

function MarkerBuoy.getIcons()
    if icons then return icons end

    icons =
    {
        "",
        "data/textures/icons/pixel/asteroid.png",
        "data/textures/icons/pixel/salvaging.png",
        "data/textures/icons/pixel/refine.png",
        "data/textures/icons/pixel/vortex.png",
        "data/textures/icons/pixel/star.png",
        "data/textures/icons/pixel/skull-detailed.png",
        "data/textures/icons/pixel/exclamation-mark.png",
        "data/textures/icons/pixel/mission-white.png",
        "data/textures/icons/pixel/marker.png",
        "data/textures/icons/pixel/cross.png",

        "data/textures/icons/pixel/shield.png",
        "data/textures/icons/pixel/attack.png",
        "data/textures/icons/pixel/crossed_swords.png",
        "data/textures/icons/pixel/patrol.png",
        "data/textures/icons/pixel/shipyard-repair.png",

        "data/textures/icons/pixel/flag.png",
        "data/textures/icons/pixel/groupmember.png",
        "data/textures/icons/pixel/selling.png",
        "data/textures/icons/pixel/sleep.png",
    }

    return icons
end

function MarkerBuoy.getColors()
    if colors then return colors end

    colors =
    {
        ColorRGB(0.9, 0.9, 0.9),
        ColorRGB(0.6, 0.6, 0.6),
        ColorRGB(0.3, 0.3, 0.3),
        ColorRGB(0.1, 0.1, 0.1),

        ColorRGB(1, 0.2, 0.2),
        ColorRGB(0.2, 1.0, 0.2),
        ColorRGB(0.2, 0.2, 1.0),
        ColorRGB(1.0, 0.6, 0.3),
        ColorRGB(0.4, 0.2, 0.05),
        ColorRGB(1.0, 1.0, 0.2),
        ColorRGB(0.2, 1.0, 1.0),
        ColorRGB(1.0, 0.2, 1.0),

        ColorRGB(1, 0.5, 0.5),
        ColorRGB(0.5, 1.0, 0.5),
        ColorRGB(0.5, 0.5, 1.0),
        ColorRGB(0.4, 0.5, 0.05),
        ColorRGB(0.5, 1.0, 1.0),
        ColorRGB(1.0, 0.5, 1.0),

        -- Xanion and Avorion are omitted since they're too similar to other, already existing colors
        Material(MaterialType.Iron).color,
        Material(MaterialType.Titanium).color,
        Material(MaterialType.Naonite).color,
        Material(MaterialType.Trinium).color,
        -- Material(MaterialType.Xanion).color,
        Material(MaterialType.Ogonite).color,
        -- Material(MaterialType.Avorion).color,

        Rarity(RarityType.Common).color,
        Rarity(RarityType.Uncommon).color,
        Rarity(RarityType.Rare).color,
        Rarity(RarityType.Exceptional).color,
        Rarity(RarityType.Exotic).color,
        Rarity(RarityType.Legendary).color,
    }

    table.sort(colors, function(a, b)
        if a.hue == b.hue then
            if a.saturation == b.saturation then
                return a.value < b.value
            else
                return a.saturation < b.saturation
            end
        else
            return a.hue < b.hue
        end
    end)

    return colors
end


-- for testing
function MarkerBuoy.getData()
    return data
end
