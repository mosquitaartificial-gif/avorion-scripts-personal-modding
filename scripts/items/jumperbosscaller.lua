package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
local JumperBoss = include("player/events/spawnjumperboss")

function create(item, rarity)
    rarity = Rarity(RarityType.Legendary)

    item.stackable = false
    item.depleteOnUse = true
    item.name = "Hyperspace Interrupter"%_t
    item.price = 50000
    item.icon = "data/textures/icons/screen-impact.png"
    item.rarity = rarity
    item:setValue("subtype", "JumperBossCaller")

    local tooltip = Tooltip()
    tooltip.icon = item.icon
    tooltip.rarity = rarity

    local title = "Hyperspace Interrupter"%_t

    local headLineSize = 25
    local headLineFontSize = 15
    local line = TooltipLine(headLineSize, headLineFontSize)
    line.ctext = title
    line.ccolor = rarity.tooltipFontColor
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Can be used to interrupt the hyperspace jump of Fidget."%_t
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
    local x, y = Sector():getCoordinates()
    if Galaxy():sectorInRift(x, y) then
        return false
    end

    local cooldown = 25 * 60

    local player = Player()
    local timestamp = player:getValue("jumperboss_last_called_timestamp")
    local unpausedRuntime = Server().unpausedRuntime

    if timestamp ~= nil and unpausedRuntime - timestamp < cooldown then
        local remainingCooldown = (cooldown - (unpausedRuntime - timestamp))
        local displayedMinutes = math.ceil(remainingCooldown / 60)
        player:sendChatMessage("", ChatMessageType.Error, "The Hyperspace Interrupter still needs about %1% min to track Fidget's ship."%_t, displayedMinutes)

        return false
    end

    local boss = JumperBoss.spawnBoss(x, y)
    player:setValue("jumperboss_last_called_timestamp", unpausedRuntime)

    return true
end
