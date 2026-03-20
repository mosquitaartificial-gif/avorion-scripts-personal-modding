-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace TransformOnPlayersLeft
TransformOnPlayersLeft = {}

local SectorGenerator = include ("SectorGenerator")

if onServer() then

function TransformOnPlayersLeft.initialize()
    Sector():registerCallback("onPlayerLeft", "transform")
end

function TransformOnPlayersLeft.onSectorChanged()
    Sector():registerCallback("onPlayerLeft", "transform")
end

function TransformOnPlayersLeft.transform()
    if Sector().numPlayers == 0 then
        local ship = Entity()
        Sector():deleteEntity(ship)

        local generator = SectorGenerator(Sector():getCoordinates())
        local faction = Faction(ship.factionIndex)

        local consumerType = math.random(1, 3)
        if consumerType == 1 then
            station = generator:createStation(faction, "data/scripts/entity/merchants/casino.lua");
        elseif consumerType == 2 then
            station = generator:createStation(faction, "data/scripts/entity/merchants/biotope.lua");
        elseif consumerType == 3 then
            station = generator:createStation(faction, "data/scripts/entity/merchants/habitat.lua");
        end

        station.position = ship.position
        station.name = ship.name
    end
end

end
