package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace RiftStartingPosition
RiftStartingPosition = {}

local startingPosition
local firstLandmarkPosition
function RiftStartingPosition.initialize(specs)
    if onServer() then
        if specs then
            startingPosition = specs.startingPosition
            firstLandmarkPosition = specs.landmarks[1].location
        end

        Sector():registerCallback("onEntityEntered", "onEntityEntered")
    end
end

function RiftStartingPosition.secure()
    return
    {
        startingPosition = startingPosition,
        firstLandmarkPosition = firstLandmarkPosition,
    }
end

function RiftStartingPosition.restore(data)
    startingPosition = data.startingPosition
    firstLandmarkPosition = data.firstLandmarkPosition
end

function RiftStartingPosition.onEntityEntered(id)
    local entity = Entity(id)
    if entity.type ~= EntityType.Ship then return end
    if not entity.playerOrAllianceOwned then return end

    local position = startingPosition + random():getDirection() * random():getFloat(70, 400)
    local look = normalize(firstLandmarkPosition - position)

    entity.position = MatrixLookUpPosition(look, random():getDirection(), position)
end

-- for tests
function RiftStartingPosition.getStartingPosition()
    return startingPosition
end
