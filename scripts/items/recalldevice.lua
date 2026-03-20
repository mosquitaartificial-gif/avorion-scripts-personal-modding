package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("utility")
include("stringutility")
include("randomext")

local cooldown = 10 * 60

function create(item, rarity, playerIndex)

    rarity = Rarity(RarityType.Legendary)

    item.stackable = false
    item.depleteOnUse = false
    item.name = "Xsotan Wormhole Device"%_t
    item.price = 1000
    item.icon = "data/textures/icons/recall-device.png"
    item.rarity = rarity
    item:setValue("subtype", "RecallDevice")
    item:setValue("playerIndex", playerIndex)
    item.boundFaction = playerIndex
    item.tradeable = false
    item.droppable = false

    local tooltip = Tooltip()
    tooltip.icon = item.icon
    tooltip.rarity = rarity

    local title = "Xsotan Wormhole Device"%_t

    local headLineSize = 25
    local headLineFontSize = 15
    local line = TooltipLine(headLineSize, headLineFontSize)
    line.ctext = title
    line.ccolor = rarity.tooltipFontColor
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 14)
    line.ltext = "Opens Wormholes"%_t
    line.rtext = "Probably?"%_t
    line.rcolor = ColorRGB(1.0, 1.0, 0.3)
    line.icon = "data/textures/icons/wormhole.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(line)

    local line = TooltipLine(20, 14)
    line.ltext = "Closes Wormholes"%_t
    line.rtext = "Maybe?"%_t
    line.rcolor = ColorRGB(1.0, 1.0, 0.3)
    line.icon = "data/textures/icons/wormhole.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(line)

    local line = TooltipLine(20, 14)
    line.ltext = "Bound Player"%_t
    line.rtext = "${faction:"..playerIndex.."}"
    line.icon = "data/textures/icons/player.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(line)

    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 14)
    line.ltext = "Destination"%_t
    line.rtext = "Unclear"%_t
    line.rcolor = ColorRGB(1.0, 1.0, 0.3)
    line.icon = "data/textures/icons/position-marker.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 14)
    line.ltext = "Has a little light that points in a direction."%_t
    tooltip:addLine(line)

    local line = TooltipLine(20, 14)
    line.ltext = "Seems to point towards your Reconstruction Site."%_t
    tooltip:addLine(line)

    tooltip:addLine(TooltipLine(10, 10))

    local line = TooltipLine(20, 14)
    line.ltext = "Can be activated by the player"%_t
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 14)
    line.ltext = "Is this thing even working..?"%_t
    line.lcolor = ColorRGB(1.0, 0.5, 0.5)
    tooltip:addLine(line)

    local line = TooltipLine(20, 14)
    line.ltext = "Only one way to find out..."%_t
    line.lcolor = ColorRGB(1.0, 0.5, 0.5)
    tooltip:addLine(line)

    item:setTooltip(tooltip)

    return item
end

function activate(item)

    local player = Player()
    local sector = Sector()

    if player.index ~= item.boundFaction then
        return
    end

    -- must be in a ship to use
    local craft = player.craft
    if not craft then
        return
    end

    -- checks for a cooldown of 10 minutes
    local runtime = Server().unpausedRuntime
    local lastRecall = player:getValue("last_recall")
    if lastRecall then
        local diff = runtime - lastRecall
        if diff < cooldown then
            local remaining = cooldown - diff
            local minutesRemaining = math.floor(remaining / 60)

            if minutesRemaining > 0 then
                -- it's not possible to see "1 minute remaining"
                player:sendChatMessage("", ChatMessageType.Error, "You must wait another %1% minutes before this works again."%_T, minutesRemaining + 1)
            else
                -- avoid "1 second'S' remaining"
                local secondsRemaining = math.max(2, math.ceil(remaining - minutesRemaining * 60))
                player:sendChatMessage("", ChatMessageType.Error, "You must wait another %1% seconds before this works again."%_T, secondsRemaining)
            end
            return
        end
    end

    local dx, dy = player:getReconstructionSiteCoordinates()
    local x, y = sector:getCoordinates()
    if x == dx and y == dy then
        player:sendChatMessage("", ChatMessageType.Information, "Nothing is happening. Maybe try from another sector?"%_T)
        return
    end

    -- note: hyperspace engine must be ready, but having non-attacking enemies nearby is fine.
    -- when ship is under attack, its hyperspace engine will be distorted, so we don't have to check for attackers here
    local hyperspaceEngine = HyperspaceEngine(craft)
    if not valid(hyperspaceEngine) then
        player:sendChatMessage("", ChatMessageType.Error, "No hyperspace engine on your ship."%_T)
        return
    end

    if hyperspaceEngine.currentCooldown > 0 then
        player:sendChatMessage("", ChatMessageType.Error, "Your hyperspace engine must be fully recharged to do this."%_T)
        return
    end

    if hyperspaceEngine.distorted then
        player:sendChatMessage("", ChatMessageType.Error, "You can't do this while your hyperspace engine is being distorted by something."%_T)
        return
    end

    if hyperspaceEngine.blocked then
        player:sendChatMessage("", ChatMessageType.Error, "You can't do this while your hyperspace engine is being blocked by something."%_T)
        return
    end

    hyperspaceEngine:exhaust()

    local desc = WormholeDescriptor()
    desc:addComponent(ComponentType.DeletionTimer)

    local cpwormhole = desc:getComponent(ComponentType.WormHole)
    cpwormhole.color = ColorRGB(1, 0, 0)
    cpwormhole:setTargetCoordinates(dx, dy)
    cpwormhole.visualSize = craft.radius * 3.5
    cpwormhole.passageSize = math.huge
    -- we want the wormhole to be one-way only, using the recall device should be a commitment
    cpwormhole.oneWay = true

    desc:addScriptOnce("data/scripts/entity/wormhole.lua")

    desc.translation = dvec3(craft.translationf + craft.look * craft.radius * 15)

    local wormHole = sector:createEntity(desc)

    DeletionTimer(wormHole.index).timeLeft = 2 * 60 -- open for 2 minutes
    EntityTransferrer(wormHole):addWhitelistedFaction(player.index)
    if player.allianceIndex then
        EntityTransferrer(wormHole):addWhitelistedFaction(player.allianceIndex)
    end
    player:setValue("last_recall", runtime)

    -- passing of more parameters to this callback is not necessary
    -- current location and destination can be read from the player's internal variables
    player:sendCallback("onPlayerRecall", player.index)

end
