
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local SectorGenerator = include ("SectorGenerator")
local Scientist = include ("story/scientist")
local Placer = include("placer")
include("music")

local SectorTemplate = {}

-- must be defined, will be used to get the probability of this sector
function SectorTemplate.getProbabilityWeight(x, y)
    local d2 = length2(vec2(x, y))

    if d2 > 150 * 150 and d2 < 240 * 240 then
        return 300
    end

    return 0
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
    local seed = Seed(string.join({GameSeed(), x, y, "researchsatellite"}, "-"))
    math.randomseed(seed);

    local random = random()

    local contents = {ships = 0, stations = 0, seed = tostring(seed)}
    contents.resourceAsteroids = random:getInt(1, 3)

    local generator = SectorGenerator(x, y)
    contents.asteroidEstimation = generator:estimateAsteroidNumbers(3 + contents.resourceAsteroids)

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

    for i = 1, 3 do
        generator:createAsteroidField(0.075);
    end

    for i = 1, contents.resourceAsteroids do
        local position = generator:createAsteroidField(0.075);
        generator:createBigAsteroid(position)
    end

    Scientist.createSatellite(Matrix())
    --createSatellite(generator:getPositionInSector())

    if random:test(generator:getWormHoleProbability()) then generator:createRandomWormHole() end

    Sector():addScriptOnce("story/respawnresearchsatellite.lua")

    generator:addOffgridAmbientEvents()
    Placer.resolveIntersections()

end

return SectorTemplate
