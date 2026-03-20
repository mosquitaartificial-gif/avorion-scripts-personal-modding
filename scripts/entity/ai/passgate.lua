
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("randomext")

-- ships passing through
local entryPosition = vec3()
local gateId = Uuid()
local finalPhase = nil

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace PassGate
PassGate = {}

if onServer() then

function PassGate.getUpdateInterval()
    return 1
end

function PassGate.initialize(gate_id)
    local self = Entity()
    self:registerCallback("onSectorEntered", "stop")

    gateId = gate_id
    if not gateId then
        -- we need to have a gateId here
        -- terminate if we don't
        PassGate.stop()
        return
    end

    local gate = Entity(gateId)

    -- we want to behave like playerships do
    -- so we fly to an entry point before actually flying into the gate
    local entryDistance = self:getBoundingSphere().radius * 2
        + gate:getBoundingSphere().radius

    -- determine best direction for entering the gate
    if dot(gate.look, self.translationf - gate.translationf) > 0 then
        entryPosition = gate.translationf + gate.look * entryDistance
    else
        entryPosition = gate.translationf - gate.look * entryDistance
    end

    ShipAI():setFly(entryPosition, 0)
end

function PassGate.update(timeStep)

    -- check if arrived at the target sector
    local self = Entity()
    local gate = Entity(gateId)
    if not gate then
        PassGate.stop()
        return
    end

    -- fly to gate
    if PassGate.finalPhase ~= true then
        -- determine distance to gate-entry-line
        local entryDirection = gate.look
        local entryShip = self.translationf - entryPosition
        local entryGate = gate.translationf - entryPosition

        local dist2 = dot(entryGate, entryGate)
        local t = dot(entryShip, entryGate) / dist2

        if t < 0 then t = 0 end

        local distanceVector = entryPosition + entryGate * t - self.translationf
        local distanceToEntry2 = dot(distanceVector, distanceVector)
        local shipRadius = self:getBoundingSphere().radius

        if distanceToEntry2 > (shipRadius + 10) * (shipRadius + 10) then
            -- fly to the entry of the gate
            ShipAI():setFly(entryPosition, 0)
        else
            -- fly into the gate
            PassGate.finalPhase = true
        end

    else
        -- fly into the gate
        PassGate.finalPhase = true
        ShipAI():setFly(gate.translationf, 0, gate)
    end
end

function PassGate.stop()
    local self = Entity()
    if not Sector():getPlayers() then
        self:addScriptOnce("deletejumped.lua")
    else
        -- do normal pass sector behavior
        local destination = -self.translationf + vec3(math.random(), math.random(), math.random()) * 1000
        destination = normalize(destination) * 1500

        self:addScriptOnce("ai/passsector.lua", destination)
    end

    terminate()
end

function PassGate.secure()
    return
    {
        entryPosition = {x = entryPosition.x, y = entryPosition.y, z = entryPosition.z},
        finalPhase = finalPhase,
        gateId = gateId,
    }
end

function PassGate.restore(values)
    entryPosition = vec3(values.entryPosition.x, values.entryPosition.y, values.entryPosition.z)
    finalPhase = values.finalPhase
    gateId = values.gateId
end

end
