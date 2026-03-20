package.path = package.path .. ";data/scripts/lib/?.lua"

include("stringutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace JumpRangeBoost
JumpRangeBoost = {}

local data = {}
JumpRangeBoost.entityId = nil

function JumpRangeBoost.initialize(distance)
    if onServer() then
        Entity():registerCallback("onHyperspaceEntered", "onHyperspaceEntered")
    end

    data.distance = distance or 5

    if not _restoring then
        Entity():addAbsoluteBias(StatsBonuses.HyperspaceReach, data.distance)
    end

    if onClient() then
        local entity = Entity()
        JumpRangeBoost.entityId = entity.id

        Sector():addStaticHyperspaceGlow(JumpRangeBoost.entityId)
        addShipProblem("HSJumpRangeBoost", JumpRangeBoost.entityId, "The range of your next jump is increased!"%_t, "data/textures/icons/vortex.png", ColorRGB(0.2, 1.0, 1.0))
    end
end

function JumpRangeBoost.onHyperspaceEntered()
    terminate()
end

if onClient() then
function JumpRangeBoost.onDelete()
    Sector():removeStaticHyperspaceGlow(JumpRangeBoost.entityId)
    removeShipProblem("HSJumpRangeBoost", JumpRangeBoost.entityId)
end
end

function JumpRangeBoost.getDistance()
    return data.distance
end

function JumpRangeBoost.restore(data_in)
    data = data_in

    Entity():addAbsoluteBias(StatsBonuses.HyperspaceReach, data.distance)
end

function JumpRangeBoost.secure()
    return data
end
