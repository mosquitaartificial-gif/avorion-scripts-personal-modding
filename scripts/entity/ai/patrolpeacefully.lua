package.path = package.path .. ";data/scripts/lib/?.lua"
include ("stringutility")

local waypoints
local current = 1
local waypointSpread = 1500 -- fly up to 15 km from the center

-- This script has AI ships fly around the sector peacefully without attacking even if enemies are present.
-- If one of their faction is attacked, this script is terminated and patrol.lua is added => they will attack all present enemies

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace AIPatrolPeacefully
AIPatrolPeacefully = {}

local accuAmount = 0

if onServer() then

function AIPatrolPeacefully.getUpdateInterval()
    return math.random() + 1.0
end

function AIPatrolPeacefully.initialize(...)
    if onServer() then
        if not _restoring then
            ShipAI():setPassive()
        end
        AIPatrolPeacefully.setWaypoints({...})
        Sector():registerCallback("onDamaged", "onSetAggressive")
    end
end

-- this function will be executed every frame on the server only
function AIPatrolPeacefully.updateServer(timeStep)
    local ai = ShipAI()
    ai:setStatusMessage("Patrolling Sector /* ship AI status*/"%_T, {})

    AIPatrolPeacefully.updateFlying(timeStep)
end

function AIPatrolPeacefully.onSetAggressive(objectIndex, amount, inflictor, damageType)
    local entity = Entity(objectIndex)
    if not valid(entity) then return end

    -- amount worth fuzzing over? 5% of entities hp or higher if it's a ship or 1% if it's a station
    local limit = entity.maxDurability * 0.05
    if entity.isStation then
        limit = entity.maxDurability * 0.01
    end
    accuAmount = accuAmount + amount
    if accuAmount <= limit then return end

    -- see if entity of my faction has been attacked and retaliate if so
    local self = Entity()
    if entity.factionIndex == self.factionIndex then
        if not inflictor or inflictor == 0 then return end
        self:addScriptOnce("data/scripts/entity/ai/patrol.lua")
        terminate()
    end

end

function AIPatrolPeacefully.updateFlying(timeStep)

    if not waypoints or #waypoints == 0 then
        waypoints = {}
        for i = 1, 5 do
            table.insert(waypoints, vec3(math.random(-1, 1), math.random(-1, 1), math.random(-1, 1)) * waypointSpread)
        end

        current = 1
    end

    local ship = Entity()
    local ai = ShipAI()

    local d = (ship:getBoundingSphere().radius * 2)
    local d2 = d * d

    if distance2(ship.translationf, waypoints[current]) < d2 then
        current = current + 1
        if current > #waypoints then
            current = 1
        end
    end

    ai:setFly(waypoints[current], ship:getBoundingSphere().radius)
end

function AIPatrolPeacefully.setWaypoints(waypointsIn)
    waypoints = waypointsIn
    current = 1
end


function AIPatrolPeacefully.setShipStatusMessage(msg, arguments)
    -- only set AI state if auto pilot inactive
    if not ControlUnit().autoPilotEnabled then
        local ai = ShipAI()
        ai:setStatusMessage(msg, arguments)
    end
end


end
