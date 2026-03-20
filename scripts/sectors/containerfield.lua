
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local SectorGenerator = include ("SectorGenerator")
local Placer = include("placer")
include("music")

local SectorTemplate = {}

-- must be defined, will be used to get the probability of this sector
function SectorTemplate.getProbabilityWeight(x, y, seed, factionIndex, innerArea)
    if factionIndex then
        if innerArea then
            return 200
        else
            return 250
        end
    else
        return 50
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
    local seed = Seed(string.join({GameSeed(), x, y, "containerfield"}, "-"))
    math.randomseed(seed)

    local random = random()

    local contents = {ships = 0, stations = 0, seed = tostring(seed)}

    local maximum = random:getInt(0, 1)
    contents.claimableAsteroids = random:multitest(maximum, 0.33)

    local generator = SectorGenerator(x, y)
    contents.asteroidEstimation = generator:estimateAsteroidNumbers(1.5, 2.5)

    contents.pirateEncounter = random:test(0.3)

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

    generator:createContainerField()

    -- add stashes to containerfields
    local possibleContainers = {Sector():getEntities()}
    for _, possibleContainer in pairs(possibleContainers) do
        if possibleContainer.title == "Container" then
            possibleContainer:addScript("stash.lua")
            break
        end
    end

    -- claimable asteroid
    for i = 1, contents.claimableAsteroids do
        local mat = generator:createAsteroidField()
        local asteroid = generator:createClaimableAsteroid()
        asteroid.position = mat
    end

    -- create asteroid fields
    local numFields = random:getInt(1, 2)
    for i = 1, numFields do
        generator:createAsteroidField(0.075)
    end

    local numSmallFields = random:getInt(1, 4)
    for i = 1, numSmallFields do
        generator:createSmallAsteroidField()
    end

    if contents.pirateEncounter then
        -- create wave encounters
        local encounters = {
            "data/scripts/events/waveencounters/fakestashwaves.lua",
            "data/scripts/events/waveencounters/hiddentreasurewaves.lua",
            "data/scripts/events/waveencounters/pirateambushpreparation.lua",
            "data/scripts/events/waveencounters/pirateasteroidwaves.lua",
            "data/scripts/events/waveencounters/pirateinitiation.lua",
            "data/scripts/events/waveencounters/piratemeeting.lua",
            "data/scripts/events/waveencounters/pirateprovocation.lua",
            "data/scripts/events/waveencounters/pirateshidingtreasures.lua",
            "data/scripts/events/waveencounters/piratestreasurehunt.lua",
            "data/scripts/events/waveencounters/piratetraitorwaves.lua",
        }

        Sector():addScript("data/scripts/events/waveencounters/respawnwaveencounters.lua", randomEntry(random, encounters))
    end

    if random:test(generator:getWormHoleProbability()) then generator:createRandomWormHole() end

    Sector():addScriptOnce("data/scripts/sector/eventscheduler.lua", "events/pirateattack.lua")
    Sector():addScriptOnce("data/scripts/sector/background/respawncontainerfield.lua")

    generator:addOffgridAmbientEvents()
    Placer.resolveIntersections()
end

return SectorTemplate
