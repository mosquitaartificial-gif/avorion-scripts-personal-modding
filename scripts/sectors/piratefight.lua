
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

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
            return 10
        else
            return 100
        end
    else
        return 100
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
    local seed = Seed(string.join({GameSeed(), x, y, "piratefight"}, "-"))
    math.randomseed(seed);

    local random = random()
    local contents = {ships = 0, stations = 0, seed = tostring(seed)}

    contents.pirates = 0
    local maximum = random:getInt(1, 2)
    contents.claimableAsteroids = random:multitest(maximum, 0.33)
    contents.resourceAsteroids = random:getInt(2, 4)

    local dist = math.sqrt(x * x + y * y)
    local shipsA = random:getInt(5, 7)
    local shipsB = random:getInt(5, 7)

    shipsA = round(lerp(dist, 450, 370, 2, shipsA))
    shipsB = round(lerp(dist, 450, 370, 2, shipsB))

    contents.pirates = shipsA + shipsB
    contents.ships = contents.pirates

    local generator = SectorGenerator(x, y)
    contents.asteroidEstimation = generator:estimateAsteroidNumbers(3 + contents.resourceAsteroids + contents.claimableAsteroids, 1.5)

    contents.pirateEncounter = true

    return contents, random, shipsA, shipsB
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
    local contents, random, shipsA, shipsB = SectorTemplate.contents(x, y)

    local generator = SectorGenerator(x, y)

    local numFields = random:getInt(2, 4)

    for i = 1, numFields do
        generator:createAsteroidField();
    end

    for i = 1, contents.resourceAsteroids do
        local position = generator:createAsteroidField()
        generator:createBigAsteroid(position)
    end

    local numSmallFields = random:getInt(6, 10)
    for i = 1, numSmallFields do
        generator:createSmallAsteroidField()
    end

    local piratesA = {}
    -- create pirate ships 1
    for i = 1, shipsA do
        table.insert(piratesA, PirateGenerator.createPirate(generator:getPositionInSector(5000)))
    end
    -- add buffs
    SpawnUtility.addEnemyBuffs(piratesA)

    -- create pirate ships 2
    PirateGenerator.pirateLevel = Balancing_GetPirateLevel(x, y) - 1

    local piratesB = {}
    for i = 1, shipsB do
        table.insert(piratesB, PirateGenerator.createPirate(generator:getPositionInSector(5000)))
    end
    -- and add buffs
    SpawnUtility.addEnemyBuffs(piratesB)

    for i = 1, contents.claimableAsteroids do
        local mat = generator:createAsteroidField()
        local asteroid = generator:createClaimableAsteroid()
        asteroid.position = mat
    end

    if random:test(generator:getWormHoleProbability()) then generator:createRandomWormHole() end

    Sector():addScriptOnce("data/scripts/sector/eventscheduler.lua", "events/pirateattack.lua")
    Sector():addScript("data/scripts/sector/background/respawnresourceasteroids.lua")

    generator:addOffgridAmbientEvents()
    Placer.resolveIntersections()
end

return SectorTemplate
