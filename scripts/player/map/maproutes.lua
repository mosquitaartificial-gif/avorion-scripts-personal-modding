package.path = package.path .. ";data/scripts/lib/?.lua"
include("data/scripts/player/map/common")
include("ordertypes")
include("stringutility")
include("utility")
include("goodsindex")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace MapRoutes
MapRoutes = {}

local routesContainer
local routesByShip = {}

if onClient() then

function MapRoutes.initialize()
    local player = Player()

    player:registerCallback("onShowGalaxyMap", "onShowGalaxyMap")

    player:registerCallback("onMapRenderAfterUI", "onMapRenderAfterUI")

    player:registerCallback("onShipOrderInfoUpdated", "onPlayerShipOrderInfoUpdated")
    player:registerCallback("onShipPositionUpdated", "onPlayerShipPositionUpdated")

    routesContainer = GalaxyMap():createContainer()
end

function MapRoutes.clearRoute(factionIndex, name)

    local id = name .. "_" .. tostring(factionIndex)
    local route = routesByShip[id]
    if route then
        route.container:clear()
    end

    routesByShip[id] = nil
end

function MapRoutes.getRoute(factionIndex, name)
    local id = name .. "_" .. tostring(factionIndex)
    local route = routesByShip[id]
    if route then
        route.container:clear()
    else
        local container = routesContainer:createContainer(Rect())
        route = {container = container}
        routesByShip[id] = route
    end

    return route
end

function MapRoutes.setCustomRoute(factionIndex, name, lines)
    if #lines == 0 then return end

    local route = MapRoutes.getRoute(factionIndex, name)

    for _, line in pairs(lines) do

        local from = line.from
        local to = line.to

        local line = route.container:createMapArrowLine()
        line.layer = -10
        line.from = ivec2(from.x, from.y)
        line.to = ivec2(to.x, to.y)
        line.color = ColorARGB(0.4, 0, 0.8, 0)
        line.width = 10
    end
end

function MapRoutes.makeRoute(faction, name, info, start)

    if not info then return end
    if not start then return end
    if not info.chain then return end
    if #info.chain == 0 then return end
    if not info.currentIndex then return end
    if info.finished then return end

    local route = MapRoutes.getRoute(faction.index, name)
    local map = GalaxyMap()

    -- plot routes
    local visited = {}

    local i = info.currentIndex
    if i == 0 then i = 1 end
    local cx, cy = start.x, start.y
    while i <= #info.chain do

        if visited[i] then break end
        visited[i] = true

        local current = info.chain[i]
        if not current then break end

        if current.action == OrderType.Jump or current.action == OrderType.FlyThroughWormhole then
            local line = route.container:createMapArrowLine()
            line.layer = -10
            line.from = ivec2(cx, cy)
            line.to = ivec2(current.x, current.y)
            if current.action == OrderType.Jump then
                line.color = ColorARGB(0.4, 0, 0.8, 0)
            else
                line.color = ColorARGB(0.6, 0.4, 0.0, 0.8)
            end
            line.width = 10

            cx, cy = current.x, current.y
        else
            local orderType = OrderTypes[current.action]
            if orderType then
                route.container:createMapIcon(orderType.pixelIcon, ivec2(cx, cy))
            end
        end

        if current.action == OrderType.Loop then
            i = current.loopIndex
        else
            i = i + 1
        end
    end
end

function MapRoutes.onShowGalaxyMap()
    local player = Player()
    local alliance = player.alliance
    if alliance then
        alliance:registerCallback("onShipOrderInfoUpdated", "onAllianceShipOrderInfoUpdated")
        alliance:registerCallback("onShipPositionUpdated", "onAllianceShipPositionUpdated")
    end

    routesContainer:clear()
    routesByShip = {}
end

function MapRoutes.onPlayerShipOrderInfoUpdated(name, info)
    if not info then return end

    local player = Player()
    if MapCommands.isSelected(name .. "_" .. player.index) and not info.finished then
        local x, y = player:getShipPosition(name)
        MapRoutes.makeRoute(player, name, info, {x=x, y=y})
    else
        MapRoutes.clearRoute(player.index, name)
    end
end

function MapRoutes.onAllianceShipOrderInfoUpdated(name, info)
    if not info then return end

    local player = Player()
    local alliance = player.alliance
    if MapCommands.isSelected(name .. "_" .. alliance.index) and not info.finished then
        local x, y = alliance:getShipPosition(name)
        MapRoutes.makeRoute(alliance, name, info, {x=x, y=y})
    else
        MapRoutes.clearRoute(alliance.index, name)
    end
end

function MapRoutes.onMapRenderAfterUI()
    MapRoutes.renderTooltips()
end

function MapRoutes.renderTooltips()
    local portraits = MapCommands.shipList.selectedPortraits
    if #portraits == 0 then return end

    local tooltip = Tooltip()

    if #portraits == 1 then
        local portrait = portraits[1]
        local info = portrait.info

        -- don't render the "enchain commands" tooltip for ships that are in the background
        if not portrait.portrait.available then return end

        MapRoutes.fillOrderInfoTooltip(tooltip, info)
    end

    local line = TooltipLine(15, 14)
    line.ltext = "[Hold SHIFT]"%_t
    line.lcolor = ColorRGB(0, 1, 1)
    line.rtext = "Enchain commands"%_t
    line.rcolor = ColorRGB(0, 1, 1)
    tooltip:addLine(line)

    local renderer = TooltipRenderer(tooltip)

    local resolution = getResolution()
    renderer:draw(vec2(10, resolution.y))
end

function MapRoutes.fillOrderInfoTooltip(tooltip, info)
    if not info then return end

    -- prevent the list from getting too long
    local maxVisibleLines = math.floor((getResolution().y - 300) / 20)
    local numLines = #info.chain

    local lastVisibleLine = math.max(maxVisibleLines, (info.currentIndex or 0) + math.ceil(maxVisibleLines / 2))
    if lastVisibleLine > numLines then
        -- clamp
        lastVisibleLine = numLines
    elseif lastVisibleLine < numLines then
        -- make space for "..." and the last line
        lastVisibleLine = lastVisibleLine - 2
        maxVisibleLines = maxVisibleLines - 2
    end

    local firstVisibleLine = math.max(1, lastVisibleLine - maxVisibleLines + 1)
    if firstVisibleLine > 1 then
        -- make space for "..."
        firstVisibleLine = firstVisibleLine + 1
    end

    for i, action in pairs(info.chain) do
        -- "..." entries
        if i < firstVisibleLine or i > lastVisibleLine then
            if i == firstVisibleLine - 1 or i == lastVisibleLine + 1 then
                local line = TooltipLine(20, 14)
                line.ltext = "..."
                line.ctext = "..."
                tooltip:addLine(line)
            end

            if i ~= numLines then
                goto continue
            end
        end

        -- normal entries
        local line = TooltipLine(20, 14)

        MapRoutes.getOrderDescription(action, i, line)

        if i == info.currentIndex then
            line.lcolor = ColorRGB(0, 1, 0)
            line.ccolor = ColorRGB(0, 1, 0)
            line.rcolor = ColorRGB(0, 1, 0)
        end

        if action.action and OrderTypes[action.action] and OrderTypes[action.action].icon then
            line.icon = OrderTypes[action.action].icon
            line.iconColor = ColorRGB(1, 1, 1)
        end

        tooltip:addLine(line)

        ::continue::
    end

    tooltip:addLine(TooltipLine(20, 10))
end

function MapRoutes.getOrderDescription(order, i, line)
    if order.action == OrderType.Jump then
        line.ltext = "[${i}] Jump"%_t % {i=i}
        line.ctext = " >>> "
        line.rtext = order.x .. " : " .. order.y
    elseif order.action == OrderType.FlyThroughWormhole then
        if order.gate then
            line.ltext = "[${i}] Gate"%_t % {i=i}
        else
            line.ltext = "[${i}] Wormhole"%_t % {i=i}
        end
        line.ctext = " >>> "
        line.rtext = order.x .. " : " .. order.y
    elseif order.action == OrderType.Mine then
        line.ltext = "[${i}] Mine Asteroids"%_t % {i=i}
    elseif order.action == OrderType.Salvage then
        line.ltext = "[${i}] Salvage Wreckages"%_t % {i=i}
    elseif order.action == OrderType.Loop then
        line.ltext = "[${i}] Loop"%_t % {i=i}
        line.ctext = " >>> "
        line.rtext = order.loopIndex
    elseif order.action == OrderType.Aggressive then
        line.ltext = "[${i}] Attack Enemies"%_t % {i=i}
    elseif order.action == OrderType.Patrol then
        line.ltext = "[${i}] Patrol Sector"%_t % {i=i}
    elseif order.action == OrderType.RefineOres then
        line.ltext = "[${i}] Refine Ores"%_t % {i = i}
    end
end

function MapRoutes.onPlayerShipPositionUpdated(name, x, y)
    local player = Player()
    if MapCommands.isSelected(name .. "_" .. player.index) then
        local info = player:getShipOrderInfo(name)
        MapRoutes.makeRoute(player, name, info, {x=x, y=y})
    else
        MapRoutes.clearRoute(player.index, name)
    end
end

function MapRoutes.onAllianceShipPositionUpdated(name, x, y)
    local player = Player()
    local alliance = player.alliance
    if MapCommands.isSelected(name .. "_" .. alliance.index) then
        local info = alliance:getShipOrderInfo(name)
        MapRoutes.makeRoute(alliance, name, info, {x=x, y=y})
    else
        MapRoutes.clearRoute(alliance.index, name)
    end
end

function MapRoutes.onPortraitSelectionChanged(portrait, selected)
    local faction = Player()
    if portrait.isAlliance then
        faction = faction.alliance
    end

    if selected then
        MapRoutes.makeRoute(faction, portrait.name, portrait.info, portrait.coordinates)
    else
        MapRoutes.clearRoute(faction.index, portrait.name)
    end
end

end -- onClient()
