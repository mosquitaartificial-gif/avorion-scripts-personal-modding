package.path = package.path .. ";data/scripts/lib/story/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
local AILocatorUtility = include("ailocatorutility")

function create(item, rarity)

    rarity = Rarity(RarityType.Legendary)

    item.stackable = false
    item.depleteOnUse = false
    item.name = "4d43 4149 3034 /* part of hexCode description */"%_t
    item.price = 0
    item.icon = "data/textures/icons/triple-plier_corrupted.png"
    item.rarity = rarity
    item:setValue("subtype", "CorruptedAIMapMarker")

    local tooltip = Tooltip()
    tooltip.icon = item.icon
    tooltip.rarity = rarity

    local title = "4d43 4149 3034 /* part of hexCode description */"%_t

    local headLineSize = 25
    local headLineFontSize = 15
    local line = TooltipLine(headLineSize, headLineFontSize)
    line.ctext = title
    line.ccolor = rarity.tooltipFontColor
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "               54 6869 7320 7365 656d 7320 /* part of hexCode description */"%_t
    tooltip:addLine(line)
    line.ltext = "746f 2062 6520 6120 6368 6970 2074 6f20 /* part of hexCode description */"%_t
    tooltip:addLine(line)
    line.ltext = "7472 6163 6b20 736f 6d65 2041 492d 636f /* part of hexCode description */"%_t
    tooltip:addLine(line)
    line.ltext = "6e74 726f 6c6c 6564 2065 6e74 6974 792e /* part of hexCode description */"%_t
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 14)
    line.ltext = "4361 6e20 6265 2061 6374 6976 6174 6564 /* part of hexCode description */"%_t
    tooltip:addLine(line)
    line.ltext = "     2062 7920 7468 6520 706c 6179 6572 /* part of hexCode description */"%_t
    tooltip:addLine(line)

    item:setTooltip(tooltip)

    return item
end

function activate(item)

    if onServer() then

        -- look if AI can be spawned
        local server = Server()
        local timer = server:getValue("corrupted_ai_timer")
        if timer and (server.unpausedRuntime - timer) <= 3600 then
            Player():sendChatMessage("", ChatMessageType.Information, "4c 6f61 6469 6e67..."%_T)
            return false
        end

        -- get global coords for next spawn
        local x, y = AILocatorUtility.getCoordinates(true)

        -- send notification
        Player():sendChatMessage("", ChatMessageType.Information, "4e 6578 7420 4149 204c 6f63 6174 696f 6e3a \\s(%1%:%2%)"%_T, x, y)

        -- give player spawn script for corrupted AI - remove and readd so that current location is used
        Player():removeScript("data/scripts/player/events/spawnbigaicorrupted.lua")
        Player():addScriptOnce("data/scripts/player/events/spawnbigaicorrupted.lua")
    end

    return true
end
