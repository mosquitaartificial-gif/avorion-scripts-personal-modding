package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
include("randomext")
local ShipGenerator = include("shipgenerator")
local NamePool = include ("namepool")

function create(item, rarity, allyIndex)

    rarity = Rarity(RarityType.Exotic)

    item.stackable = false
    item.depleteOnUse = true
    item.name = "Trade Guild Beacon"%_t
    item.price = 1000000
    item.icon = "data/textures/icons/cash.png"
    item.rarity = rarity
    item:setValue("subtype", "EquipmentMerchantCaller")
    item:setValue("factionIndex", allyIndex)

    local tooltip = Tooltip()
    tooltip.icon = item.icon
    tooltip.rarity = rarity

    local title = "Trade Guild Beacon"%_t

    local headLineSize = 25
    local headLineFontSize = 15
    local line = TooltipLine(headLineSize, headLineFontSize)
    line.ctext = title
    line.ccolor = rarity.tooltipFontColor
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 14)
    line.ltext = "Ally"%_t
    line.rtext = "${faction:"..allyIndex.."}"
    line.icon = "data/textures/icons/flying-flag.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(line)

    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 14)
    line.ltext = "Merchant Type"%_t
    line.rtext = "Equipment"%_t
    line.icon = "data/textures/icons/ship.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(line)

    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 14)
    line.ltext = "Subsystems"%_t
    line.rtext = "Yes"%_t
    line.rcolor = ColorRGB(0.3, 1, 0.3)
    line.icon = "data/textures/icons/circuitry.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(line)

    local line = TooltipLine(20, 14)
    line.ltext = "Turrets"%_t
    line.rtext = "Yes"%_t
    line.rcolor = ColorRGB(0.3, 1, 0.3)
    line.icon = "data/textures/icons/turret.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(line)

    local line = TooltipLine(20, 14)
    line.ltext = "Utilities"%_t
    line.rtext = "Yes"%_t
    line.rcolor = ColorRGB(0.3, 1, 0.3)
    line.icon = "data/textures/icons/satellite.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(line)

    local line = TooltipLine(20, 14)
    line.ltext = "Torpedoes"%_t
    line.rtext = "No"%_t
    line.rcolor = ColorRGB(1, 0.3, 0.3)
    line.icon = "data/textures/icons/missile-pod.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(line)

    local line = TooltipLine(20, 14)
    line.ltext = "Rare Artifacts"%_t
    line.rtext = "Yes"%_t
    line.rcolor = ColorRGB(0.3, 1, 0.3)
    line.icon = "data/textures/icons/circuitry.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
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

    local line = TooltipLine(20, 14)
    line.ltext = "Calls in a merchant of your allies."%_t
    tooltip:addLine(line)

    local line = TooltipLine(20, 14)
    line.ltext = "Must be used in your allies' territory."%_t
    tooltip:addLine(line)

    item:setTooltip(tooltip)

    return item
end

function activate(item)

    local x, y = Sector():getCoordinates()
    if Galaxy():sectorInRift(x, y) then
        Player():sendChatMessage("", ChatMessageType.Information, "No response."%_T)
        return false
    end

    local faction = Galaxy():getControllingFaction(x, y)
    if not faction then
        Player():sendChatMessage("", ChatMessageType.Information, "No response."%_T)
        return false
    end

    if not faction.isAIFaction then
        Player():sendChatMessage("", ChatMessageType.Information, "No response."%_T)
        return false
    end

    local allyIndex = item:getValue("factionIndex")
    if not allyIndex then
        Player():sendChatMessage("", ChatMessageType.Information, "No response."%_T)
        return false
    end

    if faction.index ~= allyIndex then
        Player():sendChatMessage("", ChatMessageType.Information, "No response."%_T)
        return false
    end

    local sender = NamedFormat("${faction} Headquarters"%_T, {faction = faction.baseName})

    local player = Player()
    local playerFaction = player.craftFaction

    if playerFaction:getRelationStatus(faction.index) ~= RelationStatus.Allies then
        Player():sendChatMessage(sender, ChatMessageType.Normal, "Our merchant guild only responds to calls from our allies."%_T)
        return false
    end

    if Sector():getEntitiesByScriptValue("called_equipment_merchant") then
        Player():sendChatMessage(sender, ChatMessageType.Normal, "There is already an agent of our guild in your sector."%_T)
        return false
    end

    local craft = player.craft
    if not craft then
        Player():sendChatMessage(sender, ChatMessageType.Error, "You must be in a ship to use this."%_T)
        return false
    end

    -- create the merchant
    local pos = random():getDirection() * 1500
    local matrix = MatrixLookUpPosition(normalize(-pos), vec3(0, 1, 0), pos)

    local ship = ShipGenerator.createTradingShip(faction, matrix)

    ship:invokeFunction("icon.lua", "set", nil)
    ship:removeScript("icon.lua")

    ship.title = "Mobile Merchant"%_T
    ship:addScriptOnce("data/scripts/entity/merchants/equipmentdock.lua")
    ship:addScriptOnce("data/scripts/entity/merchants/turretmerchant.lua")
    ship:addScriptOnce("data/scripts/entity/merchants/utilitymerchant.lua") -- To get extra tab
    ship:addScriptOnce("deleteonplayersleft.lua")
    ship:setValue("called_equipment_merchant", true)
    NamePool.setShipName(ship)

    ship:invokeFunction("equipmentdock", "setStaticSeed", true)
    ship:invokeFunction("equipmentdock", "setSpecialOffer", SystemUpgradeTemplate("data/scripts/systems/teleporterkey4.lua", Rarity(RarityType.Legendary), Seed(1)), 1)
    ship:invokeFunction("utilitymerchant", "addFront", UsableInventoryItem("jumperbosscaller.lua", Rarity(RarityType.Legendary)), 1)

    local x, y = faction:getHomeSectorCoordinates()
    if x and y then
        local distToCenter = math.sqrt(x * x + y * y)
        if distToCenter < 150 then
            -- ai map only if merchant faction lives inside barrier
            ship:invokeFunction("utilitymerchant", "addFront", UsableInventoryItem("aimap.lua", Rarity(RarityType.Legendary)), 1)
        end
    end

    Sector():broadcastChatMessage(ship, 0, "The merchant guild received a call from this sector. Who can we help?"%_t, ship.title, ship.name)

    return true
end
