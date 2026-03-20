package.path = package.path .. ";data/scripts/lib/?.lua"

include ("utility")
include ("stringutility")
include ("galaxy")
include ("faction")
include ("callable")
include ("relations")


include ("productions")
include ("goods")
include ("randomext")
include ("defaultscripts")

local SectorGenerator = include ("SectorGenerator")
local FactoryPredictor = include("factorypredictor")
local PlanGenerator = include ("plangenerator")

if onServer() then

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function initialize()
    Sector():registerCallback("onPlayerLeft", "onPlayerLeft")
end

function onPlayerLeft()
    local playersInSector = Sector():getPlayers()
    if not playersInSector and random():test(0.25) then
        createMine()
    end
end

function createMine()
    local asteroid = Entity()

    -- this will delete the asteroid and deactivate the collision detection so the original asteroid doesn't interfere with the new station
    asteroid:setPlan(BlockPlan())

    --  chose a good the mine produces
    local productions = FactoryPredictor.generateMineProductions(x, y, 1)

    local faction = Faction()
    local plan = PlanGenerator.makeStationPlan(faction, "SingleAsteroidMine")
    local station = Sector():createStation(faction, plan, asteroid.position, "data/scripts/entity/merchants/factory.lua", productions[1])

    local generator = SectorGenerator(Sector():getCoordinates())
    generator:postStationCreation(station)

    station.position = asteroid.position

    station:invokeFunction("factory", "updateTitle")
    station:setValue("factory_type", "mine")

    -- remove all goods from mine, it should start from scratch
    CargoBay(station):clear();

    -- remove all cargo that might have been added by the factory script
    for cargo, amount in pairs(station:getCargos()) do
        station:removeCargo(cargo, amount)
    end

    terminate()
end

end
