
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("randomext")

-- ships passing through
local destination = vec3()
local timeInSector = 0
local timeThreshold = random():getFloat(9 * 60, 10 * 60)

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace PassSector
PassSector = {}

if onServer() then

function PassSector.getUpdateInterval()
    return 5
end

function PassSector.initialize(destination_in)
    destination = destination_in or vec3()

    if destination_in then
        ShipAI():setFly(destination, 0)
    end
end

function PassSector.update(timeStep)

    timeInSector = timeInSector + timeStep

    -- check if arrived at the target position
    local self = Entity()
    local sphere = self:getBoundingSphere()

    ShipAI():setFly(destination, 0)

    if distance(sphere.center, destination) < sphere.radius + 50
        or timeInSector > timeThreshold then

        if self.playerOwned or self.allianceOwned then
            print ("Error: Tried to jump-delete a ship of a player! Ship: %i, Player: %s", self.index, Faction(self.factionIndex).name)
            terminate()
        else
            self:addScriptOnce("deletejumped.lua")
        end
    end
end

function PassSector.secure()
    return
    {
        destination = {x = destination.x, y = destination.y, z = destination.z},
        timeInSector = timeInSector,
    }
end

function PassSector.restore(values)
    destination = vec3(values.destination.x, values.destination.y, values.destination.z)
    timeInSector = values.timeInSector or 0
end

end
