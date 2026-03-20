package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("randomext")
include("stringutility")
local SectorSpecifics = include ("sectorspecifics")

function create(item, rarity, x, y)

    -- remember info needed for wormhole destination
    item:setValue("destination_x", x)
    item:setValue("destination_y", y)

    item.stackable = false
    item.depleteOnUse = true
    item.tradeable = false
    item.droppable = false
    item.missionRelevant = true
    item.price = 0
    item.rarity = rarity
    item:setValue("rift_mission_item", true)
    item:setValue("subtype", "WormholeDevice")

    item.name = "Wormhole Device"%_T
    item.icon = "data/textures/icons/wormhole-spawner.png"
    local tooltip = Tooltip()
    tooltip.icon = item.icon
    tooltip.rarity = rarity

    local title = item.name
    local headLineSize = 25
    local headLineFontSize = 15
    local line = TooltipLine(headLineSize, headLineFontSize)
    line.ctext = title
    line.ccolor = rarity.tooltipFontColor
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Facilitates a safe return from a rift."%_t
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 15)
    line.ltext = "Depleted on Use"%_T
    line.lcolor = ColorRGB(1.0, 1.0, 0.3)
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 14)
    line.ltext = "Can be activated by the player"%_T
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 14)
    line.ltext = "Replicated from ancient instructions."%_T
    tooltip:addLine(line)

    local line = TooltipLine(20, 14)
    line.ltext = "A feat of historic science!"%_T
    tooltip:addLine(line)

    item:setTooltip(tooltip)

    return item
end

function activate(item)
    local player = Player()
    local craft = player.craft
    if not craft then return false end

    local tx = item:getValue("destination_x")
    local ty = item:getValue("destination_y")

    -- check not already there or not in a rift => wormhole wouldn't spawn and item vanish otherwise
    local sector = Sector()
    local cx, cy = sector:getCoordinates()
    if (cx == tx and cy == ty)
            or not Galaxy():sectorInRift(cx, cy) then

        player:sendChatMessage("", ChatMessageType.Error, "Nothing happens."%_T)
        return false
    end

    -- prepare spawn
    -- find a position for the wormhole
    local landmarks = {sector:getEntitiesByScriptValue("riftsector_landmark")}
    local sortedLandmarks = {}
    for _, landmark in pairs(landmarks) do
        local dist = distance(landmark.translationf, craft.translationf)
        table.insert(sortedLandmarks, {entity = landmark, dist = dist})
    end

    table.sort(sortedLandmarks, function(a, b) return a.dist < b.dist end)

    -- we prefer the second closest landmark,
    -- if there aren't enough landmarks in the sector spawn at a random position with a good distance to player
    local pos
    if #sortedLandmarks >= 2 then
        pos = sortedLandmarks[2].entity.translationf + random():getDirection() * 1500
    else
        pos = craft.translationf + random():getDirection() * 5000
    end

    local position = MatrixLookUpPosition(vec3(0, 1, 0), vec3(1, 0, 0), pos)

    -- spawn a wormhole
    local desc = WormholeDescriptor()
    desc.position = position

    local wormhole = desc:getComponent(ComponentType.WormHole)
    wormhole:setTargetCoordinates(tx, ty)
    wormhole.visible = true
    wormhole.visualSize = 50
    wormhole.passageSize = math.huge
    wormhole.oneWay = true
    wormhole.simplifiedVisuals = true

    desc:addScriptOnce("internal/dlc/rift/entity/extractionwormhole.lua")

    local wormhole = sector:createEntity(desc)

    player:sendCallback("onExtractionWormholeDeviceActivated")
    return true
end
