package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
include("randomext")
local SectorGenerator = include("SectorGenerator")

function create(item, rarity)
    rarity = Rarity(RarityType.Uncommon)

    item.stackable = false
    item.depleteOnUse = true
    item.name = "IGA-1510 Sector Label Applicator"%_t
    item.price = 50000
    item.icon = "data/textures/icons/flying-flag.png"
    item.rarity = rarity

    local tooltip = Tooltip()
    tooltip.icon = item.icon
    tooltip.rarity = rarity

    local title = "IGA-1510 Sector Label Applicator /* IGA = Inter-Galactic Association */"%_T

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

    local line = TooltipLine(18, 14)
    line.ltext = "Time"%_t
    line.rtext = "Permanent"%_t
    line.icon = "data/textures/icons/recharge-time.png"
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
    line.ltext = "Allows you to rename a sector /* Part of a sentence. Full sentence: 'Allows you to rename a sector if you or your alliance control it.' */"%_T
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "if you or your alliance control it. /* Part of a sentence. Full sentence: 'Allows you to rename a sector if you or your alliance control it.' */"%_T
    tooltip:addLine(line)

    item:setTooltip(tooltip)

    return item
end

function activate(item)
    local controllingFaction = Galaxy():getControllingFaction(Sector():getCoordinates())
    local player = Player()

    local x, y = Sector():getCoordinates()
    if Galaxy():sectorInRift(x, y) then
        player:sendChatMessage("", ChatMessageType.Error, "Can’t deploy beacon in a sector that you don't control."%_T)
        return false
    end

    if not controllingFaction then
        player:sendChatMessage("", ChatMessageType.Error, "Can’t deploy beacon in a sector that you don't control."%_T)
        return false
    end

    if controllingFaction.isAIFaction then
        player:sendChatMessage("", ChatMessageType.Error, "Can’t deploy beacon in a sector that you don't control."%_T)
        return false
    end

    if player.allianceIndex then
        if not controllingFaction.index == player.index and not controllingFaction.index == player.allianceIndex then
            player:sendChatMessage("", ChatMessageType.Error, "Can’t deploy beacon in a sector that you don't control."%_T)
            return false
        elseif controllingFaction.index == player.allianceIndex and not player.alliance:hasPrivilege(player.index, AlliancePrivilege.ManageStations) then
            player:sendChatMessage("", ChatMessageType.Error, "You don't have permission to deploy the beacon in the name of your alliance."%_T)
            return false
        end
    else
        if not controllingFaction.index == player.index then
            player:sendChatMessage("", ChatMessageType.Error, "Can’t deploy beacon in a sector that you don't control."%_T)
            return false
        end
    end

    -- spawn the beacon
    local position = player.craft.position
    local beaconPosition = copy(position)
    beaconPosition.pos = beaconPosition.pos + random():getDirection() * 50.0

    local beacon = SectorGenerator(Sector():getCoordinates()):createBeacon(beaconPosition, Faction(player.craft.factionIndex), "This is the interface of the IGA-1510 Sector Label Applicator, would you like to change the name of this sector? /* IGA = Inter-Galactic Association */"%_t)
    beacon:addScriptOnce("data/scripts/entity/sectorrenamingbeacon.lua")
    beacon:setValue("untransferrable", true)
    beacon.title = "IGA-1510 Sector Label Applicator /* IGA = Inter-Galactic Association */"%_t
    beacon.dockable = false

    return true
end

