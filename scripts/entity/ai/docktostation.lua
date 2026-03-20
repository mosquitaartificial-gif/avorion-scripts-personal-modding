
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/entity/?.lua"

include ("stringutility")
include ("callable")
local DockAI = include ("ai/dock")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace AIDockToStation
AIDockToStation = {}

local data = {}
data.docking = true
data.station = Uuid()

function AIDockToStation.getUpdateInterval()
    return 2
end

function AIDockToStation.initialize(station, docking)
    if onServer() and station then
        data.station = station
        if docking ~= nil then data.docking = docking end
    end

    if onClient() then
        AIDockToStation.sync()
    end
end

-- this function will be executed every frame on the server only
function AIDockToStation.updateServer(timeStep)
    local ship = Entity()

    if ship.playerOwned or ship.allianceOwned then
        if ship.hasPilot and not ControlUnit().autoPilotEnabled then
            AIDockToStation.finalize(true)
            return
        end
    end

    AIDockToStation.updateDocking(timeStep)
end

function AIDockToStation.updateDocking(timeStep)
    local ship = Entity()
    local station = Sector():getEntity(data.station)

    -- in case the station doesn't exist any more, stop
    if not valid(station) then
        AIDockToStation.finalize(true)
        return
    end

    local docks = DockingPositions(station)

    -- stages
    if not valid(docks) or docks.numDockingPositions == 0 then
        -- something is not right, abort
        AIDockToStation.finalize(true)
        return
    end

    if data.docking then
        -- if we're docking, fly to the dock
        if DockAI.flyToDock(ship, station) then
            AIDockToStation.finalize(true)
        end
    else
        -- otherwise, fly away from the dock
        if DockAI.flyAwayFromDock(ship, station) then
            AIDockToStation.finalize(true)
        end
    end

end

function AIDockToStation.finalize(notifyPlayer)
    local ship = Entity()
    if notifyPlayer then
        ship:invokeFunction("orderchain.lua", "orderCompleted")
    end

    -- tell dock we don't want to be moved anymore
    local station = Sector():getEntity(data.station)
    if station then
        local docks = DockingPositions(station)
        docks:stopPulling(ship)
        docks:stopPushing(ship)
    end

    DockAI.reset()
    ShipAI():setPassive()
    terminate()
end

function AIDockToStation.secure()
    return data
end

function AIDockToStation.restore(data_in)
    data = data_in
end

function AIDockToStation.sync(data_in)
    if onClient() then
        if not data_in then
            invokeServerFunction("sync")
        else
            data = data_in
        end
    else
        invokeClientFunction(Player(callingPlayer), "sync", data)
    end
end
callable(AIDockToStation, "sync")

function AIDockToStation.getStationId()
    if type(data.station) == "string" then
        return Uuid(data.station)
    end

    return data.station
end

---- this function will be executed every frame on the client only
--function updateClient(timeStep)
--
--    if valid(minedWreckage) then
--        drawDebugSphere(minedWreckage:getBoundingSphere(), ColorRGB(1, 0, 0))
--    end
--end
