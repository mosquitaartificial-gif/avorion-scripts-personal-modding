package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
include("reconstructionutility")

function create(item, rarity)

    rarity = Rarity(RarityType.Legendary)

    item.stackable = true
    item.depleteOnUse = true
    item.name = "Unbound Q-n-D Reconstruction Kit"%_t
    item.price = 10000
    item.icon = "data/textures/icons/reconstruction-token.png"
    item.rarity = rarity
    item:setValue("subtype", "UnbrandedReconstructionToken")

    local tooltip = Tooltip()
    tooltip.icon = item.icon
    tooltip.rarity = rarity

    local title = item.name

    local headLineSize = 25
    local headLineFontSize = 15
    local line = TooltipLine(headLineSize, headLineFontSize)
    line.ctext = title
    line.ccolor = rarity.tooltipFontColor
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Can be bound to any ship"%_t
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Craft"%_t
    line.rtext = "Not yet assigned"%_t
    line.icon = "data/textures/icons/round-star.png"
    line.iconColor = ColorRGB(0.3, 1, 1)
    line.lcolor = ColorRGB(0.3, 1, 1)
    line.rcolor = ColorRGB(0.3, 1, 1)
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Use while inside a craft"%_t
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "Turns into a bound reconstruction kit"%_t
    tooltip:addLine(line)


    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Disclaimer: Additional Repairs Necessary!"%_t
    line.lcolor = ColorRGB(0.5, 0.5, 0.5)
    tooltip:addLine(line)


    item:setTooltip(tooltip)

    return item
end

function activate(item)

    local player = Player()
    local craft = Player().craft
    if not craft then return false end
    if craft.type ~= EntityType.Ship then return false end

    local receiver = player.craftFaction

    receiver:getInventory():addOrDrop(createReconstructionKit(craft))

    return true
end
