package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
include("randomext")
local SectorSpecifics = include ("sectorspecifics")

function create(item, rarity, x, y)
    rarity = Rarity(RarityType.Exceptional)

    -- remember info needed for activation
    item:setValue("coordX", x)
    item:setValue("coordY", y)

    item.stackable = false
    item.depleteOnUse = false
    item.tradeable = false
    item.droppable = false
    item.missionRelevant = true
    item.price = 0
    item.rarity = rarity
    item:setValue("subtype", "Ripcord")
    item:setValue("rift_mission_item", true)

    item.name = "Rift Ripcord"%_t
    item.icon = "data/textures/icons/rift-exit.png"

    local tooltip = Tooltip()
    tooltip.icon = item.icon
    tooltip.rarity = rarity

    local title = "Rift Ripcord"%_t
    local headLineSize = 25
    local headLineFontSize = 15
    local line = TooltipLine(headLineSize, headLineFontSize)
    line.ctext = title
    line.ccolor = rarity.tooltipFontColor
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Ping the scientists to let them know /* 1st half of: Ping the scientists to let them know you're ready for teleportation. */"%_T
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "you're ready for teleportation. /* 2nd half of: Ping the scientists to let them know you're ready for teleportation. */"%_T
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 15)
    line.ltext = "Depleted on Use"%_t
    line.lcolor = ColorRGB(1.0, 1.0, 0.3)
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 14)
    line.ltext = "Can be activated by the player"%_t
    tooltip:addLine(line)

    item:setTooltip(tooltip)

    return item
end

function activate(item)

    local player = Player()

    -- check not already there
    local tx = item:getValue("coordX")
    local ty = item:getValue("coordY")
    if not tx or not ty then return false end

    local sector = Sector()
    local cx, cy = sector:getCoordinates()
    if cx == tx and cy == ty then return false end

    -- check we're in a rift
    local seed = GameSeed()
    local specs = SectorSpecifics(cx, cy, seed)
    local regular, offgrid, blocked = specs:determineContent(cx, cy, seed)
    if not blocked then return false end

    -- let mission know that we're using the item
    -- this gives mission the opportunity to react and e.g. move other player ships or fail due to mission objectives not being fulfilled
    if player.craft then
        player:sendCallback("onRipcordActivated", player.craft.index, cx, cy, tx, ty)
    end

    return true
end
