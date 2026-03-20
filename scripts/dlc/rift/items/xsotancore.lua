package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")

function create(item, rarity)
    rarity = Rarity(RarityType.Exotic)

    item.stackable = false
    item.tradeable = false
    item.droppable = false
    item.missionRelevant = true
    item.price = 0
    item.rarity = rarity
    item:setValue("subtype", "XsotanCore")
    item:setValue("rift_mission_item", true)

    item.name = "Xsotan Core"%_t
    item.icon = "data/textures/icons/xsotan-core.png"

    local tooltip = Tooltip()
    tooltip.icon = item.icon
    tooltip.rarity = rarity

    local title = "Xsotan Core"%_T
    local headLineSize = 25
    local headLineFontSize = 15
    local line = TooltipLine(headLineSize, headLineFontSize)
    line.ctext = title
    line.ccolor = rarity.tooltipFontColor
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Xsotan core ripped out of a/* 1st half of: Xsotan core ripped out of a particularly powerful Xsotan. */"%_T
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "particularly powerful Xsotan./* 2nd half of: Xsotan core ripped out of a particularly powerful Xsotan. */"%_T
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "The scientists at the Rift Research/* 1st half of: The scientists at the Rift Research Center will have a use for this.*/"%_T
    tooltip:addLine(line)
    local line = TooltipLine(18, 14)
    line.ltext = "Center will have a use for this./* 2nd half of: The scientists at the Rift Research Center will have a use for this.*/"%_T
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "It glows strangely."%_T
    tooltip:addLine(line)

    item:setTooltip(tooltip)

    return item
end

function activate(item)
    Player():sendChatMessage("Science Log"%_T, ChatMessageType.Normal, "It starts to pulsate when touched."%_T)
    return false -- this item must not be consumed
end
