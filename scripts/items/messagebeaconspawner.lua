package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
include("randomext")
local SectorGenerator = include("SectorGenerator")

function create(item, rarity)
    rarity = Rarity(RarityType.Uncommon)

    item.stackable = false
    item.depleteOnUse = true
    item.name = "PCL Message Transmitter /* Pioneer Company Limited */"%_t
    item.price = 30000
    item.icon = "data/textures/icons/speech-bubble.png"
    item.rarity = rarity

    local tooltip = Tooltip()
    tooltip.icon = item.icon
    tooltip.rarity = rarity

    local title = "PCL's Message Transmitter /* Pioneer Company Limited */"%_T

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
    line.ltext = "Allows you to leave a message for others."%_T
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "Only the owner of the beacon can edit the message."%_T
    tooltip:addLine(line)

    item:setTooltip(tooltip)

    return item
end

function activate(item)
    local player = Player()

    -- spawn the beacon
    local position = player.craft.position
    local beaconPosition = copy(position)
    beaconPosition.pos = beaconPosition.pos + random():getDirection() * 50.0

    local beacon = SectorGenerator(Sector():getCoordinates()):createBeacon(beaconPosition, player.craftFaction, "")

    beacon:removeScript("data/scripts/entity/beacon.lua")

    local beaconText = "This is the interface of the PCL's Message Transmitter /* Pioneer Company Limited */, would you like to leave a message for others?"%_t
    beacon:addScriptOnce("data/scripts/entity/messagebeacon.lua", beaconText)
    beacon:setValue("untransferrable", true)
    beacon.title = "PCL's Message Transmitter /* Pioneer Company Limited */"%_t
    beacon.dockable = false

    return true
end
