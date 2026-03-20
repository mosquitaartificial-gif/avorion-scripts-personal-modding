package.path = package.path .. ";data/scripts/lib/?.lua"
include ("utility")
include ("randomext")
include ("faction")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace PlayerMissionItem
PlayerMissionItem = {}

function PlayerMissionItem.create(item, rarity)
    rarity = Rarity(RarityType.Legendary)

    item.stackable = false
    item.depleteOnUse = true
    item.tradeable = false
    item.droppable = false
    item.name = "Data Chip"%_t
    item.price = 0
    item.icon = "data/textures/icons/save.png"
    item.rarity = rarity
    item:setValue("subtype", "PlayerMissionItem")

    local tooltip = Tooltip()
    tooltip.icon = item.icon
    tooltip.rarity = rarity

    local title = "Mysterious Package"%_t

    local headLineSize = 25
    local headLineFontSize = 15
    local line = TooltipLine(headLineSize, headLineFontSize)
    line.ctext = title
    line.ccolor = item.rarity.tooltipFontColor
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "A chip with data on it."%_t
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 14)
    line.ltext = "Don't peek, we need to protect your eyes."%_t
    tooltip:addLine(line)

    item:setTooltip(tooltip)

    return item
end

function PlayerMissionItem.activate(item)
    return false
end
