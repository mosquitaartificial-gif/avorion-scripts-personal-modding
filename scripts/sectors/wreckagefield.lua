
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local OperationExodus = include ("story/operationexodus")
local SectorGenerator = include ("SectorGenerator")
local PirateGenerator = include ("pirategenerator")
local Placer = include("placer")
include("music")
include("randomext")

local SectorTemplate = {}

-- must be defined, will be used to get the probability of this sector
function SectorTemplate.getProbabilityWeight(x, y, seed, factionIndex, innerArea)
    if factionIndex then
        if innerArea then
            return 250
        else
            return 450
        end
    else
        return 300
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
    local seed = Seed(string.join({GameSeed(), x, y, "wreckagefield"}, "-"))
    math.randomseed(seed);
    local random = random()
    local contents = {ships = 0, stations = 0, seed = tostring(seed)}

    contents.wreckageEstimation = 50

    contents.pirateEncounter = random:test(0.75)

    return contents, random
end

function SectorTemplate.musicTracks()
    local good = {
        primary = combine(TrackCollection.Desolate()),
        secondary = combine(TrackCollection.Melancholic()),
    }

    local neutral = {
        primary = combine(TrackCollection.Desolate()),
        secondary = combine(TrackCollection.Melancholic(), TrackCollection.Middle()),
    }

    local bad = {
        primary = combine(TrackCollection.Middle(), TrackCollection.Desolate()),
        secondary = TrackCollection.Neutral(),
    }

    return good, neutral, bad
end

-- player is the player who triggered the creation of the sector (only set in start sector, otherwise nil)
function SectorTemplate.generate(player, seed, x, y)
    local contents, random, squads = SectorTemplate.contents(x, y)

    local generator = SectorGenerator(x, y)

    local faction = Galaxy():getNearestFaction(x, y);

    for i = 0, 30 do
        generator:createWreckage(faction);
    end

    local distance2 = (x * x) + (y * y)
    local barrier2 = Balancing_GetBlockRingMax() * Balancing_GetBlockRingMax()
    local maxDistance2 = 180 * 180

    if distance2 > barrier2 and distance2 < maxDistance2 then
        local wreckages = {Sector(x, y):getEntitiesByType(EntityType.Wreckage)}
        for _, wreckage in pairs(wreckages) do
            if random:test(0.05) then
                wreckage:addScript("entity/story/brotherhoodhints.lua")
                break
            end
        end
    end

    if random:test(0.3) then
        local numSmallFields = random:getInt(0, 3)
        for i = 1, numSmallFields do
            generator:createSmallAsteroidField()
        end
    end

    OperationExodus.tryGenerateBeacon(generator)

    if contents.pirateEncounter then
        -- create wave encounters
        local encounters = {
            "data/scripts/events/waveencounters/mothershipwaves.lua",
            "data/scripts/events/waveencounters/pirateambushpreparation.lua",
            "data/scripts/events/waveencounters/pirateinitiation.lua",
            "data/scripts/events/waveencounters/pirateking.lua",
            "data/scripts/events/waveencounters/pirateprovocation.lua",
            "data/scripts/events/waveencounters/piratestationwaves.lua",
            "data/scripts/events/waveencounters/piratetraitorwaves.lua",
            "data/scripts/events/waveencounters/piratewreckagewaves.lua",
            "data/scripts/events/waveencounters/tradersambushedwaves.lua",
        }

        Sector():addScript("data/scripts/events/waveencounters/respawnwaveencounters.lua", randomEntry(random, encounters))
    end

    if random:test(generator:getWormHoleProbability()) then generator:createRandomWormHole() end

    Sector():addScriptOnce("data/scripts/sector/eventscheduler.lua", "events/pirateattack.lua")

    generator:addOffgridAmbientEvents()
    Placer.resolveIntersections()
end

return SectorTemplate
