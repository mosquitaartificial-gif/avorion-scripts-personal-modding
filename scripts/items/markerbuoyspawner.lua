package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
include("randomext")
local SectorGenerator = include("SectorGenerator")

function create(item, rarity)
    rarity = Rarity(RarityType.Uncommon)

    local title = "In-Sector Marker Buoy"%_T

    item.stackable = true
    item.depleteOnUse = true
    item.name = title
    item.price = 5000
    item.icon = "data/textures/icons/marker-buoy.png"
    item.rarity = rarity

    local tooltip = Tooltip()
    tooltip.icon = item.icon
    tooltip.rarity = rarity

    local headLineSize = 25
    local headLineFontSize = 15
    local line = TooltipLine(headLineSize, headLineFontSize)
    line.ctext = title
    line.ccolor = rarity.tooltipFontColor
    tooltip:addLine(line)

    -- empty line
    local line = TooltipLine(14, 14)
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "Visibility"%_t
    line.rtext = "Sector"%_t
    line.icon = "data/textures/icons/select.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 15)
    line.ltext = "Depleted on Use"%_t
    line.lcolor = ColorRGB(1.0, 1.0, 0.3)
    tooltip:addLine(line)

    -- empty line
    local line = TooltipLine(14, 14)
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "Can be deployed by the player."%_T
    tooltip:addLine(line)

    local line = TooltipLine(14, 14)
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "Marks a location in the sector."%_T
    tooltip:addLine(line)

    item:setTooltip(tooltip)

    return item
end

function activate(item)
    local player = Player()

    local sector = Sector()
    local buoys = sector:getNumEntitiesByScript("entity/markerbuoy.lua")
    if buoys >= 20 then
        player:sendChatMessage("", ChatMessageType.Error, "Too many marker buoys."%_T)
        return false
    end

    -- spawn the beacon
    local craft = player.craft
    if not craft then return end

    local beaconPosition = craft.position
    beaconPosition.pos = craft.translationf + craft.look * (50.0 + craft.radius)

    local x, y = sector:getCoordinates()
    local desc = SectorGenerator(x, y):makeBeaconDescriptor(beaconPosition, craft.factionIndex)

    local physics = desc:getComponent(ComponentType.Physics)
    physics.driftDecrease = 0.1

    local beacon = Sector():createEntity(desc)
    beacon:addScript("data/scripts/entity/markerbuoy.lua")

    return true
end

