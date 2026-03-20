package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local SectorGenerator = include ("SectorGenerator")
local Placer = include("placer")
local ShipGenerator = include("shipgenerator")
include("music")

local SectorTemplate = {}

-- must be defined, will be used to get the probability of this sector
function SectorTemplate.getProbabilityWeight(x, y, seed, factionIndex, innerArea)
    if factionIndex then
        if innerArea then
            return 200
        else
            return 400
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
    return makeFastHash(x, y, 1) % 3 == 0
end

-- this function returns what relevant contents there will be in the sector (exact)
function SectorTemplate.contents(x, y)
    local seed = Seed(string.join({GameSeed(), x, y, "loneconsumer"}, "-"))
    math.randomseed(seed);

    local random = random()

    local contents = {ships = 0, stations = 0, seed = tostring(seed)}

    -- create a random consumer
    local consumerType = random:getInt(1, 6)
    if consumerType == 1 then
        contents.casinos = 1
    elseif consumerType == 2 then
        contents.biotopes = 1
    elseif consumerType == 3 then
        contents.habitats = 1
    elseif consumerType == 4 then
        contents.researchStations = 1
    elseif consumerType == 5 then
        contents.militaryOutposts = 1
        contents.travelHubs = 1
    elseif consumerType == 6 then
        contents.travelHubs = 1
    end

    local defendersFactor
    if Galaxy():isCentralFactionArea(x, y) then
        defendersFactor = 1.5
    else
        defendersFactor = 0.75

        if not contents.travelHubs and random:test(0.15) then
            contents.travelHubs = 1
        end
    end

    contents.defenders = round(random:getInt(0, 2) * defendersFactor)
    contents.ships = contents.defenders
    contents.stations = (contents.casinos or 0)
                        + (contents.biotopes or 0)
                        + (contents.habitats or 0)
                        + (contents.researchStations or 0)
                        + (contents.militaryOutposts or 0)
                        + (contents.travelHubs or 0)

    contents.resourceAsteroids = random:getInt(0, 2)
    local maximum = random:getInt(0, 1)
    contents.claimableAsteroids = random:multitest(maximum, 0.33)

    local generator = SectorGenerator(x, y)
    contents.asteroidEstimation = generator:estimateAsteroidNumbers(2 + contents.resourceAsteroids + contents.claimableAsteroids, 1.5)

    return contents, random
end

function SectorTemplate.musicTracks()
    local good = {
        primary = TrackCollection.HappyNeutral(),
        secondary = combine(TrackCollection.Happy(), TrackCollection.Neutral()),
    }

    local neutral = {
        primary = TrackCollection.Neutral(),
        secondary = TrackCollection.All(),
    }

    local bad = {
        primary = combine(TrackCollection.Middle(), TrackCollection.Desolate()),
        secondary = TrackCollection.Neutral(),
    }

    return good, neutral, bad
end

-- player is the player who triggered the creation of the sector (only set in start sector, otherwise nil)
function SectorTemplate.generate(player, seed, x, y)
    local contents, random = SectorTemplate.contents(x, y)

    local generator = SectorGenerator(x, y)

    local faction = Galaxy():getLocalFaction(x, y) or Galaxy():getNearestFaction(x, y)

    -- create a consumer
    if contents.casinos then
        generator:createStation(faction, "data/scripts/entity/merchants/casino.lua");
    end

    if contents.biotopes then
        generator:createStation(faction, "data/scripts/entity/merchants/biotope.lua");
    end

    if contents.habitats then
        generator:createStation(faction, "data/scripts/entity/merchants/habitat.lua");
    end

    if contents.researchStations then
        generator:createResearchStation(faction)
    end

    if contents.militaryOutposts then
        generator:createMilitaryBase(faction)
    end

    if contents.travelHubs then
        generator:createTravelHub(faction)
    end

    -- maybe create some asteroids
    local numFields = random:getInt(0, 4)
    for i = 1, numFields do
        local mat = generator:createAsteroidField()
        if random:test(0.15) then generator:createStash(mat) end
    end

    for i = 1, contents.resourceAsteroids do
        local position = generator:createAsteroidField()
        generator:createBigAsteroid(position)
    end

    -- create ships
    for i = 1, contents.defenders do
        ShipGenerator.createDefender(faction, generator:getPositionInSector())
    end

    local numSmallFields = random:getInt(0, 3)
    for i = 1, numSmallFields do
        generator:createSmallAsteroidField()
    end

    for i = 1, contents.claimableAsteroids do
        local mat = generator:createAsteroidField()
        local asteroid = generator:createClaimableAsteroid()
        asteroid.position = mat
    end

    if SectorTemplate.gates(x, y) then generator:createGates() end

    if random:test(generator:getWormHoleProbability()) then generator:createRandomWormHole() end

    Sector():addScriptOnce("data/scripts/sector/eventscheduler.lua", "events/pirateattack.lua")

    generator:addAmbientEvents()
    Placer.resolveIntersections()
end

-- called by respawndefenders.lua
function SectorTemplate.getDefenders(contents, seed, x, y)
    local faction = Galaxy():getLocalFaction(x, y) or Galaxy():getNearestFaction(x, y)
    return faction.index, contents.defenders
end

return SectorTemplate

