
package.path = package.path .. ";data/scripts/lib/?.lua"
local OperationExodus = include("story/operationexodus")
local SectorGenerator = include("SectorGenerator")
local Placer = include("placer")
local PlanGenerator = include ("plangenerator")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace ExodusSectorGenerator
ExodusSectorGenerator = {}

local corners
local visitedCorners = {}

if onServer() then

function ExodusSectorGenerator.secure()
    return {visitedCorners = visitedCorners}
end

function ExodusSectorGenerator.restore(data)
    visitedCorners = data.visitedCorners or {}
end


function ExodusSectorGenerator.initialize()
    local player = Player()
    player:registerCallback("onSectorEntered", "onSectorEntered")

    corners = OperationExodus.getCornerPoints()
end

function ExodusSectorGenerator.onSectorEntered(player, x, y)
    local cornerIndex = 1
    for _, coords in pairs(corners) do
        if coords.x == x and coords.y == y then
            ExodusSectorGenerator.placeFinalWreckages(cornerIndex)
            return
        end

        cornerIndex = cornerIndex + 1
    end
end

function ExodusSectorGenerator.placeFinalWreckages(cornerIndex)
    -- check if there's a communication beacon
    local sector = Sector()
    local beacon = sector:getEntitiesByScript("data/scripts/entity/story/exodustalkbeacon.lua")

    -- if not, create one
    if not beacon then
        beacon = SectorGenerator(sector:getCoordinates()):createBeacon(nil, nil, "")
        beacon:removeScript("data/scripts/entity/beacon.lua")
        beacon:addScript("story/exodustalkbeacon.lua")
    end

    -- create ancient gate if it is missing
    local gate = sector:getEntitiesByComponent(ComponentType.WormHole)
    if not gate then
        local generator = SectorGenerator(sector:getCoordinates())
        generator:createAncientGates()
    end


    -- only generate the wreckages once (per player)
    if visitedCorners[cornerIndex] == true then return end
    visitedCorners[cornerIndex] = true


    local wreckages = {Sector():getEntitiesByType(EntityType.Wreckage)}
    if #wreckages > 15 then return end

    local faction = OperationExodus.getFaction()
    local generator = SectorGenerator(faction:getHomeSectorCoordinates())

    for i = 1, 50 do
        generator:createWreckage(faction)
    end

    for i = 1, 3 do
        local plan = PlanGenerator.makeStationPlan(faction)

        generator:createWreckage(faction, plan, 25)
    end

    Placer.resolveIntersections()
end

end
