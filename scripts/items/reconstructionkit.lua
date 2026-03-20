package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
include("randomext")
include("utility")
local NamePool = include ("namepool")

function create(kit, rarity, factionIndex, craftName)

    kit.name = "Q-n-D Reconstruction Kit"%_t
    kit.price = 10 * 1000

    kit.rarity = rarity
    kit:setValue("subtype", "ReconstructionKit")
    kit:setValue("ship", craftName)
    kit:setValue("faction", factionIndex)
    kit.icon = "data/textures/icons/reconstruction-token.png"
    kit.iconColor = rarity.color
    kit.stackable = true
    kit.droppable = false
    kit.depleteOnUse = true

    local tooltip = Tooltip()
    tooltip.icon = kit.icon
    tooltip.rarity = rarity

    local title = kit.name

    local headLineSize = 25
    local headLineFontSize = 15
    local line = TooltipLine(headLineSize, headLineFontSize)
    line.ctext = title
    line.ccolor = kit.rarity.tooltipFontColor
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 14)
    line.ltext = "Craft"%_t
    line.rtext = craftName
    line.icon = "data/textures/icons/ship.png"
    line.iconColor = ColorRGB(0.3, 1, 1)
    line.lcolor = ColorRGB(0.3, 1, 1)
    line.rcolor = ColorRGB(0.3, 1, 1)
    tooltip:addLine(line)

    local line = TooltipLine(20, 14)
    line.ltext = "Owner"%_t
    line.rtext = "${faction:"..factionIndex.."}"
    line.icon = "data/textures/icons/player.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Bound to a specific craft"%_t
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "Use near the wreckage of the destroyed craft"%_t
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "Quickly reassembles the bound craft"%_t
    tooltip:addLine(line)


    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 15)
    line.ltext = "Depleted on Use"%_t
    line.lcolor = ColorRGB(1.0, 1.0, 0.3)
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Can be activated by the player"%_t
    tooltip:addLine(line)


    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Disclaimer: Additional Repairs Necessary!"%_t
    line.lcolor = ColorRGB(0.5, 0.5, 0.5)
    tooltip:addLine(line)

    kit:setTooltip(tooltip)

    return kit
end

function activate(item)

    local player = Player()

    local factionIndex = item:getValue("faction")
    if not factionIndex then return false end

    local shipName = item:getValue("ship")
    if not shipName then return false end

    local faction = Galaxy():findFaction(factionIndex)
    if faction.isAIFaction then return false end

    local sector = Sector()
    local sx, sy = faction:getShipPosition(shipName)
    local x, y = sector:getCoordinates()

    if sx ~= x or sy ~= y then
        player:sendChatMessage("", ChatMessageType.Error, "Wreckage not found."%_T)
        return false
    end

    if not faction:getShipDestroyed(shipName) then
        player:sendChatMessage("", ChatMessageType.Error, "Wreckage not found."%_T)
        return false
    end

    local entry = ShipDatabaseEntry(faction.index, shipName)
    if entry:getScriptValue("lost_in_rift") then
        player:sendChatMessage("", ChatMessageType.Error, "Wreckage not found."%_t)
        return false
    end

    local maxHp, hpPercentage, hpMalusFactor, hpMalusReason, damaged = entry:getDurabilityProperties()

    local craft = faction:restoreCraft(shipName, entry:getLocalPosition(), true)
    if not craft then
        player:sendChatMessage("", ChatMessageType.Error, "Error reconstructing craft."%_t)
        return false
    end

    CargoBay(craft):clear()
    craft:setValue("untransferrable", nil) -- tutorial could have broken this
    craft:setMalusFactor(1, MalusReason.None) -- must reset first

    -- set a new malus that is either 50%, or the malus that was there before reconstruction
    craft:setMalusFactor(math.min(hpMalusFactor, 0.5), MalusReason.Reconstruction)

    craft:sendCallback("onReconstructed", craft.id, player.index)

    -- delete all remnants that might still be floating around
    local wreckages = {sector:getEntitiesByScriptValue("reconstruct_faction", factionIndex)}
    for _, wreck in pairs(wreckages) do
        local name = wreck:getValue("reconstruct_name")

        if name == shipName then
            sector:deleteEntity(wreck)
        end
    end

    local info = makeCallbackSenderInfo(craft)
    player:sendCallback("onReconstructionKitUsed", info)

    return true
end
