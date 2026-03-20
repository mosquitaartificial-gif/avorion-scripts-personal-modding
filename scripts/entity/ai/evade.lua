package.path = package.path .. ";data/scripts/lib/?.lua"
include ("stringutility")
include ("randomext")

local waypoint
local waypointSpread = 2000 -- fly up to 20 km from the center

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace AIEvade
AIEvade = {}

if onServer() then

function AIEvade.getUpdateInterval()
    return math.random() + 1.0
end

function AIEvade.initialize(waypointIn)
    if onServer() then
        if not _restoring then
            -- ensure ai state change
            ShipAI():setPassive()
            ShipAI():setPassiveShooting(true)
        end

        AIEvade.setWaypoint(waypointIn)
    end
end

-- this function will be executed every frame on the server only
function AIEvade.updateServer(timeStep)
    local ship = Entity()
    local ai = ShipAI()
    ai:setStatusMessage("Evading players /* ship AI status*/"%_T, {})

    if not waypoint then
        waypoint = AIEvade.findNewWaypoint()
    end

    local d = (ship:getBoundingSphere().radius * 2)
    local d2 = d * d

    if distance2(ship.translationf, waypoint) < d2 then
        waypoint = AIEvade.findNewWaypoint()
    end

    ai:setFly(waypoint, ship:getBoundingSphere().radius)
end

function AIEvade.findNewWaypoint()
    local ownFactionIndex = Entity().factionIndex

    local waypoints = {}
    for i = 1, 20 do
        table.insert(waypoints, random():getDirection() * waypointSpread * random():getFloat(0.5, 1))
    end

    -- find relevant entities
    local entities = {}
    for _, entity in pairs({Sector():getEntities()}) do
        if entity.factionIndex ~= 0 and entity.factionIndex ~= ownFactionIndex then
            table.insert(entities, entity)
        end
    end

    if #entities == 0 then
--        print("no entities, return random waypoint")
        return randomEntry(waypoints)
    end

    local sortedWaypoints = {}
    for _, point in pairs(waypoints) do
        -- find closest distance to entity
        local minDist2
        for _, entity in pairs(entities) do
            local dist2 = distance2(point, entity.translationf)
            if minDist2 == nil or dist2 < minDist2 then
                minDist2 = dist2
            end
        end

        table.insert(sortedWaypoints, {waypoint = point, dist2 = minDist2})
    end

    table.sort(sortedWaypoints, function(a, b) return a.dist2 > b.dist2 end)
    return sortedWaypoints[1].waypoint
end

function AIEvade.setWaypoint(waypointIn)
    waypoint = waypointIn
end

end
