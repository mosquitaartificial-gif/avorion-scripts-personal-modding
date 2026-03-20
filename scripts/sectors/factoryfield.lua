package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local SectorGenerator = include ("SectorGenerator")
local Placer = include("placer")
local FactoryPredictor = include("factorypredictor")
local ShipGenerator = include("shipgenerator")
include("music")

local SectorTemplate = {}

-- must be defined, will be used to get the probability of this sector
function SectorTemplate.getProbabilityWeight(x, y, seed, factionIndex, innerArea)
    if factionIndex then
        if innerArea then
            return 1400
        else
            return 800
        end
    else
        return 0
    end
end

function SectorTemplate.offgrid(x, y)
    return false
end

-- this function returns whether or not a sector should have space gates
function SectorTemplate.gates(x, y)
    return true
end

-- this function returns what relevant contents there will be in the sector (exact)
function SectorTemplate.contents(x, y)
    local seed = Seed(string.join({GameSeed(), x, y, "factoryfield"}, "-"))
    math.randomseed(seed);

    local random = random()

    local contents = {ships = 0, stations = 0, seed = tostring(seed)}
    contents.factories = random:getInt(5, 6)

    if random:test(0.33) then
        contents.tradingPosts = 1
    end

    if random:test(0.33) then
        contents.turretFactories = 1
        contents.turretFactorySuppliers = 1
    end

    if random:test(0.33) then
        contents.fighterFactories = 1
    end

    if random:test(0.5) then
        contents.resourceDepots = 1
    end

    local sx = x + random:getInt(-15, 15)
    local sy = y + random:getInt(-15, 15)

    local faction, otherFaction
    if onServer() then
        faction = Galaxy():getLocalFaction(x, y) or Galaxy():getNearestFaction(x, y)

        otherFaction = Galaxy():getNearestFaction(sx, sy)
        if not valid(faction) or not valid(otherFaction) then return end
        if faction:getRelations(otherFaction.index) < -20000 then otherFaction = nil end
    end

    -- create a trader from maybe another faction
    if random:test(0.5) then
        if onServer() then
            if otherFaction and faction.index ~= otherFaction.index then
                contents.neighborTradingPosts = 1
            end
        end
    end


    -- create defenders
    local defendersFactor
    if Galaxy():isCentralFactionArea(x, y) then
        defendersFactor = 1.5
    else
        defendersFactor = 0.75
    end

    contents.defenders = round(random:getInt(4, 6) * defendersFactor)

    contents.ships = contents.defenders
    contents.stations = contents.factories
                        + (contents.tradingPosts or 0)
                        + (contents.neighborTradingPosts or 0)
                        + (contents.turretFactories or 0)
                        + (contents.turretFactorySuppliers or 0)
                        + (contents.fighterFactories or 0)
                        + (contents.resourceDepots or 0)

    if onServer() then
        contents.faction = faction.index

        if otherFaction then
            contents.neighbor = otherFaction.index
        end
    end

    local generator = SectorGenerator(x, y)
    contents.asteroidEstimation = generator:estimateAsteroidNumbers(2, 2.5)

    return contents, random, faction, otherFaction
end

function SectorTemplate.musicTracks()
    local good = {
        primary = TrackCollection.HappyNoParticle(),
        secondary = TrackCollection.HappyNeutral(),
    }

    local neutral = {
        primary = TrackCollection.Neutral(),
        secondary = TrackCollection.HappyNeutral(),
    }

    local bad = {
        primary = TrackCollection.Middle(),
        secondary = TrackCollection.Neutral(),
    }

    return good, neutral, bad
end

-- player is the player who triggered the creation of the sector (only set in start sector, otherwise nil)
function SectorTemplate.generate(player, seed, x, y)
    local contents, random, faction, otherFaction = SectorTemplate.contents(x, y)

    local generator = SectorGenerator(x, y)

    -- create a trading post
    if contents.tradingPosts then
        generator:createStation(faction, "data/scripts/entity/merchants/tradingpost.lua");
    end

    -- create several factories
    local productions = FactoryPredictor.generateFactoryProductions(x, y, contents.factories, false)

    local containerStations = {}
    for _, production in pairs(productions) do
        local station = generator:createStation(faction, "data/scripts/entity/merchants/factory.lua", production);
        table.insert(containerStations, station)
    end

    -- create a turret factory
    if contents.turretFactories then
        generator:createTurretFactory(faction)
    end
    if contents.turretFactorySuppliers then
        generator:createStation(faction, "merchants/turretfactorysupplier.lua");
    end

    if contents.fighterFactories then
        generator:createFighterFactory(faction)
    end

    if contents.resourceDepots then
        generator:createStation(faction, "merchants/resourcetrader.lua");
    end

    -- create a trader from maybe another faction
    if contents.neighborTradingPosts then
        generator:createStation(otherFaction, "data/scripts/entity/merchants/tradingpost.lua");
    end

    -- create defenders
    for i = 1, contents.defenders do
        ShipGenerator.createDefender(faction, generator:getPositionInSector())
    end


    -- maybe create some asteroids
    local numFields = random:getInt(0, 2)
    for i = 1, numFields do
        generator:createEmptyAsteroidField();
    end

    numFields = random:getInt(0, 2)
    for i = 1, numFields do
        generator:createAsteroidField();
    end

    local numSmallFields = random:getInt(0, 5)
    for i = 1, numSmallFields do
        generator:createSmallAsteroidField()
    end

    -- generate station containers last so their stations won't get displaced by other stations being created
    for i, station in pairs(containerStations) do
        if random:test(0.15) then
            generator:generateStationContainers(station)
        end
    end

    if SectorTemplate.gates(x, y) then generator:createGates() end

    if random:test(generator:getWormHoleProbability()) then generator:createRandomWormHole() end

    Sector():addScriptOnce("data/scripts/sector/eventscheduler.lua", "events/pirateattack.lua")

    generator:addAmbientEvents()
    Placer.resolveIntersections()
end

-- called by respawndefenders.lua
function SectorTemplate.getDefenders(contents, seed, x, y)
    return contents.faction, contents.defenders
end

return SectorTemplate
