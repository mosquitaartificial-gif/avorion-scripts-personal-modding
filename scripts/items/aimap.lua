package.path = package.path .. ";data/scripts/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/lib/story/?.lua"

include("stringutility")
local AILocatorUtility = include("ailocatorutility")

function create(item, rarity)

    rarity = Rarity(RarityType.Legendary)

    item.stackable = true
    item.depleteOnUse = true
    item.name = "Maintenance Chip MCAI04"%_t
    item.price = 1000000 + math.random(0, 10000)
    item.icon = "data/textures/icons/triple-plier.png"
    item.rarity = rarity
    item:setValue("subtype", "AIMapMarker")

    local tooltip = Tooltip()
    tooltip.icon = item.icon
    tooltip.rarity = rarity

    local title = "Maintenance Chip MCAI04"%_t

    local headLineSize = 25
    local headLineFontSize = 15
    local line = TooltipLine(headLineSize, headLineFontSize)
    line.ctext = title
    line.ccolor = item.rarity.tooltipFontColor
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "This seems to be a chip to track some AI-controlled entity."%_t
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

    if onServer() then
        -- get global coords for next spawn
        local x, y = AILocatorUtility.getCoordinates(false)

        -- send notification
        Player():sendChatMessage("", ChatMessageType.Information, "Next AI Location: \\s(%1%:%2%)"%_T, x, y)

        -- give player spawn script for big AI - remove and readd so that current location is used
        Player():removeScript("data/scripts/player/events/spawnbigai.lua")
        Player():addScriptOnce("data/scripts/player/events/spawnbigai.lua")
    end

    return true
end
