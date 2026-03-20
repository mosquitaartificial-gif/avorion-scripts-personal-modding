package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
include("galaxy")
local SectorSpecifics = include("sectorspecifics")

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


function create(item, rarity, selfIndex, factionIndex, alliance)

    item.stackable = true
    item.depleteOnUse = true
    item.icon = "data/textures/icons/map-fragment.png"
    item.rarity = rarity
    item:setValue("subtype", "FactionMapSegment")
    item:setValue("factionIndex", factionIndex)
    item:setValue("selfIndex", selfIndex)
    item.name = "Faction Gate Map Update"%_t
    item.price = 10

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
    line.ltext = "Area"%_t
    line.icon = "data/textures/icons/map-fragment.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    line.rtext = "Full Territory"%_t

    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Gate Network"%_t
    line.icon = "data/textures/icons/patrol.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(toYesNo(line, true))

    local line = TooltipLine(18, 14)
    line.ltext = "Network Version"%_t
    line.icon = "data/textures/icons/circuitry.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    line.rtext = "2.0"
    tooltip:addLine(line)

    if alliance then
        local line = TooltipLine(18, 14)
        line.ltext = "Alliance"%_t
        line.icon = "data/textures/icons/alliance.png"
        line.iconColor = ColorRGB(0.8, 0.8, 0.8)
        tooltip:addLine(toYesNo(line, true))
    end

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
    line.ltext = "Updates gate connections of the faction's territory"%_t
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "A chip with gate information."%_t
    line.lcolor = ColorRGB(0.4, 0.4, 0.4)
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "Courtesy of Galaxy Gates United."%_t
    line.lcolor = ColorRGB(0.4, 0.4, 0.4)
    tooltip:addLine(line)

    item:setTooltip(tooltip)

    return item
end

function run(selfIndex, factionIndex, playerIndex)
    local GatesMap = include("gatesmap")

    local galaxy = Galaxy()
    local parent = galaxy:findFaction(selfIndex)

    local seed = Server().seed
    local gatesMap = GatesMap(seed)
    local specs = SectorSpecifics()

    local sectors = 0

    local views = {parent:getKnownSectors()}
    for _, view in pairs(views) do
        local x, y = view:getCoordinates()

        -- only update in that faction's area
        local faction = galaxy:getLocalFaction(x, y)
        if not faction or faction.index ~= factionIndex then goto continue end

        sectors = sectors + 1

        local changed

        -- clear existing gates
        local destinations = {view:getGateDestinations()}
        if #destinations > 0 then
            view:setGateDestinations()
            changed = true
        end

        -- add new gates
        local regular, offgrid, dust = specs.determineFastContent(x, y, seed)
        if regular or offgrid then
            local regular, offgrid = specs:determineContent(x, y, seed)

            if regular then
                local connections = gatesMap:getConnectedSectors({x = x, y = y})
                if #connections > 0 then
                    local gateDestinations = {}
                    for _, connection in pairs(connections) do
                        table.insert(gateDestinations, ivec2(connection.x, connection.y))
                    end

                    view:setGateDestinations(unpack(gateDestinations))
                    changed = true
                end
            end
        end

        -- if something changed, update
        if changed then
            parent:updateKnownSector(view)
        end

        ::continue::
    end

    local player = Player(playerIndex)
    player:setValue("block_async_execution", nil)

    parent:sendChatMessage("", ChatMessageType.Information, "Map information added to the Galaxy Map."%_t)

end

function activate(item)

    local player = Player()

    local factionIndex = item:getValue("factionIndex")
    if not factionIndex then return false end

    local faction = Faction(factionIndex)
    if not faction.isAIFaction then return false end

    local selfIndex = item:getValue("selfIndex")
    if not selfIndex then return false end

    local parent = Faction(selfIndex)
    if parent.isAIFaction then return false end

    if player:getValue("block_async_execution") then
        player:sendChatMessage("", ChatMessageType.Error, "Still updating."%_T)
        return false
    end

    -- ensure that players don't start all their map updaters at once
    player:setValue("block_async_execution", true)

    asyncf("", "data/scripts/items/gatemapupdate.lua", selfIndex, factionIndex, player.index)

    return true
end
