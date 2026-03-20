
package.path = package.path .. ";data/scripts/lib/?.lua"
include("stringutility")
include("callable")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace FlyThroughGate
FlyThroughGate = {}

FlyThroughGate.gateId = nil
FlyThroughGate.finalPhase = nil

function FlyThroughGate.initialize(gate)
    if onServer() then
        local ship = Entity()
        ship:registerCallback("onSectorEntered", "stop")

        FlyThroughGate.gateId = gate

        ShipAI():setStatusMessage("Flying Through Gate /* ship AI status*/"%_T, {})

        ship:addScriptOnce("data/scripts/entity/ai/landfighters.lua")

    else
        invokeServerFunction("sync")
    end
end

function FlyThroughGate.sync(gateId)
    if onServer() then
        invokeClientFunction(Player(callingPlayer), "sync", FlyThroughGate.gateId)
        return
    else

        FlyThroughGate.gateId = gateId
    end
end
callable(FlyThroughGate, "sync")

if onServer() then

function FlyThroughGate.getUpdateInterval()
    return 2
end

function FlyThroughGate.secure()
    return {gateId = FlyThroughGate.gateId}
end

function FlyThroughGate.restore(data)
    FlyThroughGate.gateId = data.gateId
end

-- this function will be executed every frame on the server only
function FlyThroughGate.updateServer(timeStep)
    if FlyThroughGate.gateId == nil then FlyThroughGate.stop() return end

    local ship = Entity()

    -- wait for fighters to land before flying through the gate
    if ship:hasScript("data/scripts/entity/ai/landfighters.lua") then
        ShipAI():setPassive()
        return
    end

    local shipRadius = ship:getBoundingSphere().radius

    local gate = Sector():getEntity(Uuid(FlyThroughGate.gateId))
    if not valid(gate) then
        FlyThroughGate.stop()
        return
    end

    local wormhole = WormHole(gate)
    if wormhole and not wormhole:fitsThrough(ship) then
        local x, y = Sector():getCoordinates()
        Faction():sendChatMessage(ship.name, ChatMessageType.Warning, "Commander, we can't fly through there, our ship is too big! \\s(%1%:%2%)"%_T, x, y)
        FlyThroughGate.stop()
        return
    end

    -- determine best direction for entering the gate
    local entryDistance = shipRadius * 2 + gate:getBoundingSphere().radius

    local entryPosition
    if dot(gate.look, ship.translationf - gate.translationf) > 0 then
        entryPosition = gate.translationf + gate.look * entryDistance
    else
        entryPosition = gate.translationf - gate.look * entryDistance
    end

    -- determine distance to gate-entry-line
    local entryDirection = gate.look
    local entryShip = ship.translationf - entryPosition
    local entryGate = gate.translationf - entryPosition

    local dist2 = dot(entryGate, entryGate)
    local t = dot(entryShip, entryGate) / dist2

    if t < 0 then t = 0 end
--    if t > 1 then t = 1 end

    local distanceVector = entryPosition + entryGate * t - ship.translationf
    local distanceToEntry2 = dot(distanceVector, distanceVector)

    if FlyThroughGate.finalPhase ~= true and distanceToEntry2 > (shipRadius + 10) * (shipRadius + 10) then
        -- fly to the entry of the gate
        ShipAI():setFly(entryPosition, 0)
    else
        -- fly into the gate
        FlyThroughGate.finalPhase = true
        ShipAI():setFly(gate.translationf, 0, gate)
    end

    -- if possible, preload the target sector so that the transition goes smoothly on the galaxy map
    FlyThroughGate.tryRequestingTargetSector(ship, gate)
end

function FlyThroughGate.tryRequestingTargetSector(ship, gate)
    -- we only want to load sectors into memory if the owning player/alliance is currently online
    if not ship.playerOwned and not ship.allianceOwned then return end
    if not Server():isOnline(ship.factionIndex) then return end

    local wormhole = WormHole(gate)
    if not valid(wormhole) then return end

    local x, y = wormhole:getTargetCoordinates()
    Galaxy():keepOrGetSector(x, y, 5)
end

function FlyThroughGate.stop()
    ShipAI():setPassive()
    terminate()
end

end
