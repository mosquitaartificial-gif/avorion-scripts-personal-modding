
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("utility")

local DockAI = {}

DockAI.usedDock = nil
DockAI.dockStage = 0

function DockAI.reset()
    DockAI.usedDock = nil
    DockAI.dockStage = 0

    DockAI.undockStage = 0

    DockAI.dockUndockStage = 0
    DockAI.tractorWaitCount = 0

    DockAI.waitCount = 0

    DockAI.nearingDistance = nil
    DockAI.flyLinear = false

    ShipAI():stop()
end

function DockAI.flyToDock(ship, station)

    DockAI.dockStage = DockAI.dockStage or 0

    local ai = ShipAI(ship)
    local docks = DockingPositions(station)
    local tracingEnabled = nil
--    tracingEnabled = ship.playerOwned

    if tracingEnabled then
        print ("flyToDock Stage: " .. tostring(DockAI.dockStage))
        print ("flyToDock usedDock: " .. tostring(DockAI.usedDock))
        print ("flyToDock target station: " .. tostring(station.id))
    end

    if station:isInDockingArea(ship) then
        ai:setPassive()
        DockAI.dockStage = 0
        DockAI.usedDock = nil
        return true
    end


    if DockAI.dockStage == 0 then

        -- no dock chosen yet -> find one
        if not DockAI.usedDock then
            -- if there are no docks on the station at all, we can't do anything
            if docks.numDockingPositions == 0 then
                if tracingEnabled then print ("no docks") end

                return false
            end

            -- find a free dock
            local freeDock = docks:getFreeDock(ship)
            if freeDock then
                DockAI.usedDock = freeDock
                ai:setPassive() -- reset the fly state so that new fly states will be accepted later on
            else
                if tracingEnabled then print ("no free docks") end
            end
        end

        if DockAI.usedDock then
            if not docks:isLightLineFree(DockAI.usedDock, ship) then
                -- if the dock is not free, reset it and look for another one
                DockAI.usedDock = nil
                ai:setPassive() -- reset the fly state so that new fly states will be accepted later on
            end
        end

        -- still no free dock found? nothing we can do except fly near the station and wait for the dock to free
        if not DockAI.usedDock then
            local target = station.translationf
            local dir = target - ship.translationf
            normalize_ip(dir)

            target = target - dir * (station.radius * 1.5 + ship.radius)

            if ai.state ~= AIState.Fly or ai.isStuck or not ai.flyTarget or (ivec3(target) ~= ivec3(ai.flyTarget)) then
                if tracingEnabled then print ("set fly") end

                ai:setFly(target, 0)
            end

            return
        end

        -- fly towards the light line of the dock
        local dock = docks:getDockingPosition(DockAI.usedDock)
        if not dock then
            DockAI.usedDock = nil
            ai:setPassive() -- reset the fly state so that new fly states will be accepted later on
            return
        end

        local pos = vec3(dock.position.x, dock.position.y, dock.position.z)
        local dir = vec3(dock.direction.x, dock.direction.y, dock.direction.z)

        local target = station.position:transformCoord(pos + dir * 250)

        if ai.state ~= AIState.Fly or ai.isStuck or not ai.flyTarget or (ivec3(target) ~= ivec3(ai.flyTarget)) then
            if tracingEnabled then print ("set fly") end

            ai:setFly(target, 0)
        end

        if tracingEnabled then print ("stuck: " .. tostring(ai.isStuck)) end

        if docks:inLightArea(ship, DockAI.usedDock) then
            -- when the light area was reached, start stage 1 of the docking process
            DockAI.dockStage = 1
            return false
        end
    end

    -- stage 1 is flying towards the dock inside the light-line
    if DockAI.dockStage == 1 then
        -- if docking doesn't work, go back to stage 0 and find a free dock
        if not docks:startPulling(ship, DockAI.usedDock) then
            DockAI.dockStage = 0
            return false
        else
            -- docking worked: set AI to passive to allow tractor beams to grab it
            DockAI.dockStage = 2
            ai:setPassive()
        end
    end

    if DockAI.dockStage == 2 then
        -- once the ship is at the dock, wait
        if tracingEnabled then print ("docking: " .. tostring(DockingPositions(station):isTractoring(ship) )) end

        if station:isInDockingArea(ship) then
            if tracingEnabled then print ("docked") end
            ai:setPassive()

            DockAI.dockStage = 0
            DockAI.usedDock = nil
            return true
        else
            if tracingEnabled then print ("being pulled in") end
            -- tractor beams are active
            return false, true
        end
    end

    return false
end

DockAI.undockStage = 0

function DockAI.flyAwayFromDock(ship, station)

    local ai = ShipAI(ship.index)
    local docks = DockingPositions(station)

    if DockAI.undockStage == 0 then
        docks:startPushing(ship)
        ai:setPassive()
        DockAI.undockStage = 1
    elseif DockAI.undockStage == 1 then

        if not docks:isPushing(ship) then
            DockAI.undockStage = 0
            return true
        end

        ai:setPassive()
    end

    return false
end

DockAI.dockUndockStage = 0
DockAI.tractorWaitCount = 0

function DockAI.updateDockingUndockingWithDock(timeStep, ship, station, dockWaitingTime, doTransaction, finished, skipUndocking)

    local tracingEnabled = nil
--    tracingEnabled = ship.playerOwned

    if not valid(station) then
        if finished then finished(ship, "No station found") end
        if tracingEnabled then print ("No station found") end

        return
    end

    if tracingEnabled then
        print ("dockUndockStage: " .. tostring(DockAI.dockUndockStage))
    end

    local docks = DockingPositions(station)

    -- stages
    if not valid(docks) or docks.numDockingPositions == 0 then
        -- something is not right, abort
        if finished then finished(ship, "No docks found") end
        if tracingEnabled then print ("No docks found") end

        return
    end

    DockAI.dockUndockStage = DockAI.dockUndockStage or 0

    -- stage 0 is flying towards the light-line and being pulled in
    if DockAI.dockUndockStage == 0 then
        local atDock, tractorActive = DockAI.flyToDock(ship, station)

        if atDock then
            DockAI.dockUndockStage = 2
            DockAI.tractorWaitCount = nil
        end

        if tractorActive then
            DockAI.tractorWaitCount = DockAI.tractorWaitCount or 0
            DockAI.tractorWaitCount = DockAI.tractorWaitCount + timeStep

            if DockAI.tractorWaitCount > 2 * 60 then -- seconds
                docks:stopPulling(ship)
                if finished then finished(ship, "Docking failed") end
                if tracingEnabled then print ("Docking failed") end

                DockAI.tractorWaitCount = nil
            end
        end
    end

    -- stage 2 is waiting
    if DockAI.dockUndockStage == 2 then
        DockAI.waitCount = DockAI.waitCount or 0
        DockAI.waitCount = DockAI.waitCount + timeStep

        if DockAI.waitCount > dockWaitingTime then -- seconds waiting
            if doTransaction then doTransaction(ship, station) end
            -- fly away
            DockAI.dockUndockStage = 3
            DockAI.waitCount = 0
        end
    end

    -- fly back to the end of the lights
    if DockAI.dockUndockStage == 3 then
        if skipUndocking == true then
            if finished then finished(ship, "Trading is now over, skipped undocking") end
            if tracingEnabled then print ("Trading is now over, skipped undocking") end

            DockAI.dockUndockStage = 0
        else
            if DockAI.flyAwayFromDock(ship, station) then
                if finished then finished(ship, "Trading is now over") end
                if tracingEnabled then print ("Trading is now over") end
                DockAI.dockUndockStage = 0
            end
        end
    end

end

DockAI.flyLinear = false

function DockAI.updateDockingUndockingWithTransporter(timeStep, ship, station, dockWaitingTime, doTransaction, finished)
    if not ship then return end
    if not station then return end

    if station:isInDockingArea(ship) then
        -- we're docked, wait and then do the transaction
        DockAI.waitCount = DockAI.waitCount or 0
        DockAI.waitCount = DockAI.waitCount + timeStep

        if DockAI.waitCount > dockWaitingTime then -- seconds waiting
            if doTransaction then doTransaction(ship, station) end
            if finished then finished(ship, "Trading is now over") end
            if tracingEnabled then print ("Trading is now over") end

            DockAI.waitCount = 0
        else
            ShipAI(ship):setPassive()
        end
    else
        -- fly towards the station
        local range = ship.transporterRange

        local dir = normalize(ship.translationf - station.translationf)
        DockAI.nearingDistance = DockAI.nearingDistance or (range + ship.radius + station.radius)

        local target = station.translationf + (dir * DockAI.nearingDistance)

        -- it's possible that we're not docked yet even if we reached the point we wanted to reach
        if distance(target, ship.translationf) < ship.radius * 1.5 then -- radius * 1.5 since it's possible that the center of the bounding sphere is not the same as the translation center
            -- in this case, reduce the nearing distance
            DockAI.nearingDistance = DockAI.nearingDistance - 10
            DockAI.flyLinear = false

            if DockAI.nearingDistance <= 0 then
                if finished then finished(ship, "Docking via transporter failed") end
                if tracingEnabled then print ("Docking via transporter failed") end
            end
        else
            local ai = ShipAI(ship)
            if DockAI.flyLinear then
                if ai.state ~= AIState.LinearFly then
                    ai:setFlyLinear(target, 0)
                end
            else
                if ai.isStuck then
                    DockAI.flyLinear = true
                end

                if ai.state ~= AIState.Fly or ai.isStuck or not ai.flyTarget or (ivec3(target) ~= ivec3(ai.flyTarget)) then
                    ai:setFly(target, 0)
                end
            end
        end

    end
end

function DockAI.updateDockingUndocking(timeStep, station, dockWaitingTime, doTransaction, finished, skipUndocking)
    if not station then return end
    dockWaitingTime = dockWaitingTime or 10

    local ship = Entity()
    if (ship.transporterRange or 0) > 0 then
        DockAI.updateDockingUndockingWithTransporter(timeStep, ship, station, dockWaitingTime, doTransaction, finished)
    else
        DockAI.updateDockingUndockingWithDock(timeStep, ship, station, dockWaitingTime, doTransaction, finished, skipUndocking)
    end
end


function DockAI.secure(data)
    data.DockAI = {}
    data.DockAI.usedDock = DockAI.usedDock
    data.DockAI.dockStage = DockAI.dockStage
    data.DockAI.undockStage = DockAI.undockStage
    data.DockAI.dockUndockStage = DockAI.dockUndockStage
end

function DockAI.restore(data)
    if not data.DockAI then return end

    DockAI.usedDock = data.DockAI.usedDock
    DockAI.dockStage = data.DockAI.dockStage or 0
    DockAI.undockStage = data.DockAI.undockStage or 0
    DockAI.dockUndockStage = data.DockAI.dockUndockStage or 0
end

return DockAI
