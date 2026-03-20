package.path = package.path .. ";data/scripts/lib/?.lua"

local CommandFactory = include("simulation/commandfactory")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace MapCommandAreas
MapCommandAreas = {}

local displayedAreas = {}
local showAreas = true
local showAllianceAreas = true

if onClient() then

function MapCommandAreas.initialize()
    local player = Player()

    player:registerCallback("onShipAvailabilityUpdated", "onPlayerShipAvailabilityUpdated")
    player:registerCallback("onShowGalaxyMap", "onShowGalaxyMap")
    player:registerCallback("onGalaxyMapUpdate", "onGalaxyMapUpdate")

end

function MapCommandAreas.makeKey(owner, shipName)
    return tostring(owner) .. shipName
end

function MapCommandAreas.onPlayerShipAvailabilityUpdated(shipName, availability)
    MapCommandAreas.onShipAvailabilityUpdated(Player().index, shipName, availability)
end

function MapCommandAreas.onAllianceShipAvailabilityUpdated(shipName, availability)
    MapCommandAreas.onShipAvailabilityUpdated(Player().allianceIndex, shipName, availability)
end

function MapCommandAreas.isMouseOverArea(owner, shipName)
    local key = MapCommandAreas.makeKey(owner, shipName)

    local area = displayedAreas[key]
    if not area then return end

    local hx, hy = GalaxyMap():getHoveredCoordinates()

    if hx >= area.lower.x
            and hy >= area.lower.y
            and hx < area.upper.x
            and hy < area.upper.y then
        return true
    end
end

function MapCommandAreas.onShipAvailabilityUpdated(owner, shipName, availability)
    if not showAreas then return end

    local key = MapCommandAreas.makeKey(owner, shipName)

    if availability == ShipAvailability.InBackground then
        MapCommandAreas.requestArea(owner, shipName)
    else
        GalaxyMap():removeHighlightedArea(key)
        displayedAreas[key] = nil
    end
end

function MapCommandAreas.onShowGalaxyMap()
    local map = GalaxyMap()
    showAreas = map.showBackgroundShipAreas
    showAllianceAreas = map.showAllianceInfo
    MapCommandAreas.refreshAreas()
end

function MapCommandAreas.onGalaxyMapUpdate()
    local map = GalaxyMap()
    local current = map.showBackgroundShipAreas
    local currentAlliance = map.showAllianceInfo

    local changed = (current ~= showAreas) or (currentAlliance ~= showAllianceAreas)
    showAreas = current
    showAllianceAreas = currentAlliance

    if changed then
        MapCommandAreas.refreshAreas()
    end
end

function MapCommandAreas.refreshAreas()
    -- if we don't show the areas, just clear everything and that's it
    local map = GalaxyMap()
    if not showAreas then
        map:resetHighlightedAreas()
        displayedAreas = {}
        return
    end

    local player = Player()

    for _, name in pairs({player:getShipNames()}) do
        if player:getShipAvailability(name) == ShipAvailability.InBackground then
            MapCommandAreas.requestAreaIfNecessary(player.index, name)
        else
            MapCommandAreas.removeArea(player.index, name)
        end
    end

    local alliance = player.alliance
    if alliance then
        alliance:registerCallback("onShipAvailabilityUpdated", "onAllianceShipAvailabilityUpdated")

        for _, name in pairs({alliance:getShipNames()}) do
            if alliance:getShipAvailability(name) == ShipAvailability.InBackground and showAllianceAreas then
                MapCommandAreas.requestAreaIfNecessary(alliance.index, name)
            else
                MapCommandAreas.removeArea(alliance.index, name)
            end
        end
    end

end

function MapCommandAreas.requestAreaIfNecessary(owner, shipName)
    local key = MapCommandAreas.makeKey(owner, shipName)
    if displayedAreas[key] then return end

    MapCommandAreas.requestArea(owner, shipName)
end

function MapCommandAreas.removeArea(owner, shipName)
    local key = MapCommandAreas.makeKey(owner, shipName)

    GalaxyMap():removeHighlightedArea(key)
    displayedAreas[key] = nil
end

function MapCommandAreas.requestArea(owner, shipName)
    local shipOwner = Galaxy():findFaction(owner)
    if not shipOwner then return end

    shipOwner:invokeFunction("data/scripts/player/background/simulation/simulation.lua", "requestReachableSectors", shipName, "mapcommandareas.lua")
end

function MapCommandAreas.receiveReachableSectors(owner, shipName, reachableCoordinates)
    MapCommandAreas.highlightSectors(owner, shipName, reachableCoordinates)
end

function MapCommandAreas.highlightSectors(owner, shipName, reachableCoordinates)
    local highlighted = {}
    local statuses = {}
    local player = Player()

    -- visualize the area where the ship is doing its thing
    local color = "2000a000"
    highlighted.borderColor = "8000ff00"

    if owner == player.allianceIndex then
        color = "20a000a0"
        highlighted.borderColor = "80ff00ff"
    end

    local lx, ly = 0, 0
    local ux, uy = 0, 0

    if #reachableCoordinates > 0 then
        local sector = reachableCoordinates[1]
        lx, ly = sector.x, sector.y
        ux, uy = lx + 1, uy + 1
    end

    for _, sector in pairs(reachableCoordinates) do
        if sector.hidden then goto continue end

        local x, y = sector.x, sector.y

        table.insert(highlighted, {x = x, y = y, color = color})

        lx = math.min(lx, x)
        ly = math.min(ly, y)

        ux = math.max(ux, x)
        uy = math.max(uy, y)

        ::continue::
    end

    ux, uy = ux + 1, uy + 1

    local shipOwner = Galaxy():findFaction(owner)
    if shipOwner then
        local ok, description = shipOwner:invokeFunction("simulation.lua", "getDescription", shipName)
        if description then
            if description.command then
                local command = CommandFactory.makeCommand(description.command)
                highlighted.texture = command:getIcon()
            end
        end
    end

    local key = MapCommandAreas.makeKey(owner, shipName)
    GalaxyMap():setHighlightedSectors(highlighted, key)

    displayedAreas[key] = {lower = {x = lx, y = ly}, upper = {x = ux, y = uy}}
end



end -- onClient
