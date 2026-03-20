
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local OperationExodus = include ("story/operationexodus")
local SectorGenerator = include ("SectorGenerator")
local PirateGenerator = include ("pirategenerator")
local Placer = include("placer")
local SpawnUtility = include ("spawnutility")
include("music")

local SectorTemplate = {}

-- must be defined, will be used to get the probability of this sector
function SectorTemplate.getProbabilityWeight(x, y, seed, factionIndex, innerArea)
    if factionIndex then
        if innerArea then
            return 20
        else
            return 600
        end
    else
        return 700
    end
end

function SectorTemplate.offgrid(x, y)
    return true
end

-- this function returns whether or not a sector should have space gates
function SectorTemplate.gates(x, y)
    return false
end

-- this function returns what relevant contents there will be in the sector (exact)
function SectorTemplate.contents(x, y)
    local seed = Seed(string.join({GameSeed(), x, y, "pirateasteroidfield"}, "-"))
    math.randomseed(seed);

    local random = random()
    local contents = {ships = 0, stations = 0, seed = tostring(seed)}

    local maximum = random:getInt(1, 2)
    contents.claimableAsteroids = random:multitest(maximum, 0.33)

    contents.resourceAsteroids = random:getInt(2, 3)

    local dist = math.sqrt(x * x + y * y)

    local generator = SectorGenerator(x, y)
    contents.asteroidEstimation = generator:estimateAsteroidNumbers(3 + contents.resourceAsteroids + contents.claimableAsteroids, 8)

    contents.pirateEncounter = true

    return contents, random
end

function SectorTemplate.musicTracks()
    local good = {
        primary = combine(TrackCollection.Neutral(), TrackCollection.Desolate()),
        secondary = combine(TrackCollection.Happy(), TrackCollection.Neutral()),
    }

    local neutral = {
        primary = combine(TrackCollection.Neutral(), TrackCollection.Desolate()),
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

    local numFields = random:getInt(2, 4)

    -- create asteroid fields
    for i = 1, numFields do
        generator:createAsteroidField(0.075)
    end

    for i = 1, contents.resourceAsteroids do
        local position = generator:createAsteroidField()
        generator:createBigAsteroid(position)
    end

    local numSmallFields = random:getInt(6, 10)
    for i = 1, numSmallFields do
        generator:createSmallAsteroidField()
    end

    -- create wave encounters
    local encounters = {
        "data/scripts/events/waveencounters/fakestashwaves.lua",
        "data/scripts/events/waveencounters/hiddentreasurewaves.lua",
        "data/scripts/events/waveencounters/mothershipwaves.lua",
        "data/scripts/events/waveencounters/pirateambushpreparation.lua",
        "data/scripts/events/waveencounters/pirateasteroidwaves.lua",
        "data/scripts/events/waveencounters/pirateinitiation.lua",
        "data/scripts/events/waveencounters/pirateking.lua",
        "data/scripts/events/waveencounters/piratemeeting.lua",
        "data/scripts/events/waveencounters/pirateprovocation.lua",
        "data/scripts/events/waveencounters/pirateshidingtreasures.lua",
        "data/scripts/events/waveencounters/piratestationwaves.lua",
        "data/scripts/events/waveencounters/piratestreasurehunt.lua",
        "data/scripts/events/waveencounters/piratetraitorwaves.lua",
    }

    Sector():addScript("data/scripts/events/waveencounters/respawnwaveencounters.lua", randomEntry(random, encounters))

    -- claimable asteroid
    for i = 1, contents.claimableAsteroids do
        local mat = generator:createAsteroidField()
        local asteroid = generator:createClaimableAsteroid()
        asteroid.position = mat
    end

    OperationExodus.tryGenerateBeacon(generator)

    if random:test(generator:getWormHoleProbability()) then generator:createRandomWormHole() end

    Sector():addScriptOnce("data/scripts/sector/eventscheduler.lua", "events/pirateattack.lua")
    Sector():addScript("data/scripts/sector/background/respawnresourceasteroids.lua")

    generator:addOffgridAmbientEvents()
    Placer.resolveIntersections()
end

return SectorTemplate
