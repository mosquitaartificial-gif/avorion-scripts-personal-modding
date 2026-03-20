package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
include("galaxy")

local function getQuadrant(hx, hy, x, y)
    if x >= hx then
        if y >= hy then
            return 2
        else
            return 4
        end
    else
        if y >= hy then
            return 1
        else
            return 3
        end
    end
end

local toYesNo = function(line, value)
    if value then
        line.rtext = "Yes"%_t
        line.rcolor = ColorRGB(0.3, 1.0, 0.3)
    else
        line.rtext = "No"%_t
        line.rcolor = ColorRGB(1.0, 0.3, 0.3)
    end

    return line
end

local QuadrantNames = {}
QuadrantNames[1] = "North West"%_t
QuadrantNames[2] = "North East"%_t
QuadrantNames[3] = "South West"%_t
QuadrantNames[4] = "South East"%_t

function create(item, rarity, factionIndex, hx, hy, x, y)

    item.stackable = true
    item.depleteOnUse = true
    item.icon = "data/textures/icons/map-fragment.png"
    item.rarity = rarity
    item:setValue("subtype", "FactionMapSegment")
    item:setValue("factionIndex", factionIndex)

    local price = 0
    if rarity.value >= RarityType.Exotic then
        item.name = "Faction Territory Map"%_t
        price = 500000
    elseif rarity.value >= RarityType.Exceptional then
        item.name = "Faction Quadrant Map"%_t
        price = 250000
    elseif rarity.value >= RarityType.Rare then
        item.name = "Explorer's Quadrant Map"%_t
        price = 30000
    else
        item.name = "Traveler's Quadrant Map"%_t
        price = 10000
    end

    item.price = price * Balancing_GetSectorRichnessFactor(hx, hy)

    local quadrant = getQuadrant(hx, hy, x, y)
    item:setValue("quadrant", quadrant)

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
    line.ltext = "Faction"%_t
    line.rtext = "${faction:"..factionIndex.."}"
    line.icon = "data/textures/icons/flying-flag.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Quadrant"%_t
    line.icon = "data/textures/icons/map-fragment.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)

    if rarity.value >= RarityType.Exotic then
        toYesNo(line, true)
        line.rtext = "Full Territory"%_t
    else
        line.rtext = QuadrantNames[quadrant]
    end

    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Gate Network"%_t
    line.icon = "data/textures/icons/patrol.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(toYesNo(line, true))

    local line = TooltipLine(18, 14)
    line.ltext = "Additional Sectors"%_t
    line.icon = "data/textures/icons/diamonds.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(toYesNo(line, rarity.value >= RarityType.Rare))

    local line = TooltipLine(18, 14)
    line.ltext = "Sector Stations"%_t
    line.icon = "data/textures/icons/checklist.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(toYesNo(line, rarity.value >= RarityType.Exceptional))


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

    local line = TooltipLine(18, 14)
    line.ltext = "Unveils a quadrant of the faction's territory."%_t
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "Territory info is loaded into the Galaxy Map"%_t
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "A chip with territory information."%_t
    line.lcolor = ColorRGB(0.4, 0.4, 0.4)
    tooltip:addLine(line)

    item:setTooltip(tooltip)

    return item
end

function run(playerIndex, factionIndex, withOffgrid, withContent, quadrant)

    local FactoryPredictor = include ("factorypredictor")
    local SectorSpecifics = include ("sectorspecifics")
    local GatesMap = include ("gatesmap")

    local timer = HighResolutionTimer()
    timer:start()

    local gatesMap = GatesMap(GameSeed())

    local player = Player(playerIndex)
    local faction = Faction(factionIndex)

    local hx, hy = faction:getHomeSectorCoordinates()

    -- +----+----+
    -- | NW | NE |
    -- | 1  | 2  |
    -- +--- H ---+
    -- | SW | SE |
    -- | 3  | 4  |
    -- +----+----+

    local startX = hx - 200
    local endX = hx + 200
    local startY = hy - 200
    local endY = hy + 200

    if quadrant then
        if quadrant == 3 then
            endX = hx
            endY = hy
        elseif quadrant == 4 then
            startX = hx
            endY = hy
        elseif quadrant == 1 then
            endX = hx
            startY = hy
        elseif quadrant == 2 then
            startX = hx
            startY = hy
        end
    end

    if startX < -500 then startX = -500 end
    if startY < -500 then startY = -500 end

    if endX > 500 then endX = 500 end
    if endY > 500 then endY = 500 end

    -- print ("h: %i %i, s: %i %i, e: %i %i, q: %i", hx, hy, startX, startY, endX, endY, quadrant)

    local specs = SectorSpecifics()

    local seed = GameSeed()
    for x = startX, endX do
        for y = startY, endY do
            local regular, offgrid, dust = specs.determineFastContent(x, y, seed)

            if regular or offgrid then
                specs:initialize(x, y, seed)

                if specs.regular and specs.factionIndex == factionIndex
                        and specs.generationTemplate
                        and (withOffgrid or specs.gates) then
                    local view = player:getKnownSector(x, y) or SectorView()

                    if not view.visited then
                        specs:fillSectorView(view, gatesMap, withContent)

                        player:updateKnownSectorPreserveNote(view)
                    end

                end
            end
            ::continuey::
        end
        ::continuex::
    end

    local view = player:getKnownSector(hx, hy) or SectorView()
    view:setCoordinates(hx, hy)
    view.note = "Home Sector"%_T
    player:updateKnownSectorPreserveNote(view)

    player:setValue("block_async_execution", nil)

    player:sendChatMessage("", ChatMessageType.Information, "Map information added to the Galaxy Map."%_t)

end


function activate(item)

    local player = Player()

    local factionIndex = item:getValue("factionIndex")
    if not factionIndex then return false end

    local faction = Faction(factionIndex)
    if not faction.isAIFaction then return false end

    local quadrant = item:getValue("quadrant") or 1
    if item.rarity.value >= RarityType.Exotic then quadrant = nil end

    local withContent = item.rarity.value >= RarityType.Exceptional
    local withOffgrid = item.rarity.value >= RarityType.Rare

    if player:getValue("block_async_execution") then
        player:sendChatMessage("", ChatMessageType.Error, "Still updating."%_T)
        return false
    end

    -- ensure that players don't start all their map updaters at once
    player:setValue("block_async_execution", true)

    asyncf("", "data/scripts/items/factionmapsegment.lua", player.index, factionIndex, withOffgrid, withContent, quadrant)

    return true
end
