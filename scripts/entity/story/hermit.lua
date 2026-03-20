package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("callable")
include("utility")
local MissionUT = include("missionutility")
local SectorSpecifics = include ("sectorspecifics")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Hermit
Hermit = {}

function Hermit.getFaction()
    local faction = Galaxy():findFaction("The Hermit"%_T)
    if faction == nil then
        faction = Galaxy():createFaction("The Hermit"%_T, 300, 0)
        faction.initialRelations = 0
        faction.initialRelationsToPlayer = 0
        faction.staticRelationsToAll = true
    end

    faction.homeSectorUnknown = true
    return faction
end

function Hermit.spawn()
    -- don't double-spawn
    local present = Sector():getEntitiesByScript("data/scripts/entity/story/hermit.lua")
    if present then return present end

    local faction = Hermit.getFaction()
    local volume = Balancing_GetSectorShipVolume(Sector():getCoordinates()) * 2

    local plan = LoadPlanFromFile("data/plans/hermit.xml")
    plan.accumulatingHealth = false

    local translation = random():getDirection() * 1000
    local position = MatrixLookUpPosition(-translation, vec3(0, 1, 0), translation)

    local ship = Sector():createShip(faction, "", plan, position)
    ship.title = "The Hermit"%_T
    ship:setValue("no_attack_events", true)
    ship.invincible = true
    ship.dockable = false
    ship:addScript("story/hermit.lua")
    ship:addScript("data/scripts/entity/utility/basicinteract.lua")

    return ship
end

function Hermit.getLocation(x, y)
    local target = nil
    local distanceFromCenterHermit = 340
    local distanceFromCenterPlayer = length(vec2(x,y))
    local ratio = distanceFromCenterPlayer / distanceFromCenterHermit
    local xHermit = math.floor(x / ratio)
    local yHermit = math.floor(y / ratio)
    local playerInsideBarrier = MissionUT.checkSectorInsideBarrier(xHermit, yHermit)

    local test = function(xHermit, yHermit, regular, offgrid, blocked, home, dust, factionIndex, centralArea)
        if regular then return end
        if blocked then return end
        if offgrid then return end
        if home then return end
        if Balancing_InsideRing(xHermit, yHermit) ~= playerInsideBarrier then return end

        return true
    end

    local specs = SectorSpecifics(xHermit, yHermit, GameSeed())

    for i = 0, 20 do
        local target = specs:findSector(random(), xHermit, yHermit, test, 20 + i * 15, i * 15)

        if target then
            return target.x, target.y
        else
            -- this should never happen, if it does we need to check the code! (unless it is caused by mods)
            print ("Hermit.lua: Error: couldn't find Hermit location")
        end
    end
end

return Hermit
