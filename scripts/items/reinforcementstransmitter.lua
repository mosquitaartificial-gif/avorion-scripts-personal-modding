package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local FactionEradicationUtility = include("factioneradicationutility")
local ShipGenerator = include("shipgenerator")
include("stringutility")

function create(item, rarity, allyIndex)

    rarity = Rarity(RarityType.Exotic)

    item.stackable = false
    item.depleteOnUse = false
    item.name = "Reinforcements Transmitter"%_t
    item.price = 3000000
    item.icon = "data/textures/icons/firing-ship.png"
    item.rarity = rarity
    item:setValue("subtype", "ReinforcementsTransmitter")
    item:setValue("factionIndex", allyIndex)

    local tooltip = Tooltip()
    tooltip.icon = item.icon
    tooltip.rarity = rarity

    local title = "Reinforcements Transmitter"%_t

    local headLineSize = 25
    local headLineFontSize = 15
    local line = TooltipLine(headLineSize, headLineFontSize)
    line.ctext = title
    line.ccolor = rarity.tooltipFontColor
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Ally"%_t
    line.rtext = "${faction:"..allyIndex.."}"
    line.icon = "data/textures/icons/flying-flag.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "Ships"%_t
    line.rtext = "3 - 7"
    line.icon = "data/textures/icons/ship.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Cooldown"%_t
    line.rtext = "1h"%_t
    line.icon = "data/textures/icons/recharge-time.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Can be activated by the player"%_t
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "Calls in reinforcements from your allies"%_t
    tooltip:addLine(line)

    item:setTooltip(tooltip)

    return item
end

function inReachOfFaction(faction)

    local x, y = Sector():getCoordinates()
    local controller = Galaxy():getControllingFaction(x, y)

    if controller and controller.index == faction.index then return true end

    local hx, hy = faction:getHomeSectorCoordinates()

    return distance2(vec2(hx, hy), vec2(x, y)) <= 100 * 100
end

function activate(item)
    local x, y = Sector():getCoordinates()
    if Galaxy():sectorInRift(x, y) then
        Player():sendChatMessage("", ChatMessageType.Information, "No response."%_T)
        return false
    end

    -- check if the faction is in reach
    local allyIndex = item:getValue("factionIndex")
    if not allyIndex then
        Player():sendChatMessage("", ChatMessageType.Information, "No response."%_T)
        return false
    end

    local faction = Faction(allyIndex)
    if not faction then
        Player():sendChatMessage("", ChatMessageType.Information, "No response."%_T)
        return false
    end

    if not faction.isAIFaction then
        Player():sendChatMessage("", ChatMessageType.Information, "No response."%_T)
        return false
    end

    if FactionEradicationUtility.isFactionEradicated(faction.index) then
        Player():sendChatMessage("", ChatMessageType.Information, "No response."%_T)
        return false
    end

    local sender = NamedFormat("${faction} Headquarters"%_T, {faction = faction.baseName})

    local player = Player()
    local playerFaction = player.craftFaction

    if playerFaction:getRelationStatus(allyIndex) ~= RelationStatus.Allies then
        Player():sendChatMessage(sender, ChatMessageType.Normal, "We only send out combat support for our allies."%_T)
        return false
    end

    if not inReachOfFaction(faction) then
        Player():sendChatMessage(sender, ChatMessageType.Normal, "We're sorry, but you're too far out. We can't send reinforcements that far."%_T)
        return false
    end

    local craft = player.craft
    if not craft then
        Player():sendChatMessage(sender, ChatMessageType.Error, "You must be in a ship to use this."%_T)
        return false
    end

    local key = "reinforcements_requested_" .. faction.index
    local timeStamp = playerFaction:getValue(key)
    local now = Server().unpausedRuntime

    if timeStamp then
        local ago = now - timeStamp
        local wait = 60 * 60

        if ago < wait then
            Player():sendChatMessage(sender, ChatMessageType.Normal, "We can't send out reinforcements that quickly again! You'll have to wait another %i minutes!"%_T, math.ceil((wait - ago)/60))
            return false
        end
    end

    playerFaction:setValue(key, now)

    local position = craft.translationf

    -- let the backup spawn behind the player
    local dir = normalize(normalize(position) + vec3(0.01, 0.0, 0.0))
    local pos = position + dir * 750
    local up = vec3(0, 1, 0)
    local look = -dir

    local right = normalize(cross(dir, up))

    local ships = {}
    table.insert(ships, ShipGenerator.createDefender(faction, MatrixLookUpPosition(look, up, pos)))
    table.insert(ships, ShipGenerator.createDefender(faction, MatrixLookUpPosition(look, up, pos + right * 100)))

    if (faction:getTrait("peaceful") or 0) < 0.5 then
        table.insert(ships, ShipGenerator.createDefender(faction, MatrixLookUpPosition(look, up, pos - right * 100)))
    end

    if (faction:getTrait("brave") or 0) > 0.5 then
        table.insert(ships, ShipGenerator.createDefender(faction, MatrixLookUpPosition(look, up, pos + right * 200)))
    end
    if (faction:getTrait("brave") or 0) > 0.85 then
        table.insert(ships, ShipGenerator.createDefender(faction, MatrixLookUpPosition(look, up, pos - right * 200)))
    end

    if (faction:getTrait("aggressive") or 0) > 0.85 then
        table.insert(ships, ShipGenerator.createDefender(faction, MatrixLookUpPosition(look, up, pos + right * 300)))
    end
    if (faction:getTrait("honorable") or 0) > 0.85 then
        table.insert(ships, ShipGenerator.createDefender(faction, MatrixLookUpPosition(look, up, pos - right * 300)))
    end

    for _, ship in pairs(ships) do
        ship:addScriptOnce("deleteonplayersleft.lua")
    end

    return true
end
