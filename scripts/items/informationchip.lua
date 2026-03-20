package.path = package.path .. ";data/scripts/lib/?.lua"
include ("utility")
include ("randomext")
include ("faction")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace InformationChip
InformationChip = {}

function InformationChip.create(item, rarity, locations)

    rarity = Rarity(RarityType.Exotic)

    item.stackable = false
    item.depleteOnUse = true
    item.tradeable = false
    item.droppable = false
    item.missionRelevant = true
    item.name = "Data Chip"%_t
    item.price = 0
    item.icon = "data/textures/icons/processor.png"
    item.rarity = rarity
    item:setValue("subtype", "InformationChip")

    local tooltip = Tooltip()
    tooltip.icon = item.icon
    tooltip.rarity = rarity

    local title = "Data Chip"%_t

    local headLineSize = 25
    local headLineFontSize = 15
    local line = TooltipLine(headLineSize, headLineFontSize)
    line.ctext = title
    line.ccolor = rarity.tooltipFontColor
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "A data chip with fragmented transcripts."%_t
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 14)
    line.ltext = "Double-click for computer analysis."%_t
    tooltip:addLine(line)

    item:setTooltip(tooltip)

    return item
end

function InformationChip.activate(item)

    if onServer() then
        local player = Player()
        player:sendChatMessage("System"%_T, ChatMessageType.Information, "Finished analysis. Writing results to chat log."%_T)

        -- send callback that we opened it
        player:sendCallback("onInformationChipAnalyzed")
    end

    return true
end
