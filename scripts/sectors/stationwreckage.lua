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
            return 100
        else
            return 400
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
    local seed = Seed(string.join({GameSeed(), x, y, "stationwreckage"}, "-"))
    math.randomseed(seed);
    local random = random()
    local contents = {ships = 0, stations = 0, seed = tostring(seed)}

    local generator = SectorGenerator(x, y)
    contents.asteroidEstimation = generator:estimateAsteroidNumbers(1, 3.5)
    contents.wreckageEstimation = 20

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
    local contents, random = SectorTemplate.contents(x, y)

    local generator = SectorGenerator(x, y)

    local numFields = random:getInt(0, 2)
    for i = 1, numFields do
        generator:createAsteroidField();
    end

    local numFields = random:getInt(2, 5)
    for i = 1, 5 - numFields do
        generator:createEmptyAsteroidField();
    end

    local stations =
    {
        "data/scripts/entity/merchants/resourcetrader.lua",
        "data/scripts/entity/merchants/shipyard.lua",
        "data/scripts/entity/merchants/repairdock.lua",
        "data/scripts/entity/merchants/tradingpost.lua",
        "data/scripts/entity/merchants/factory.lua",
    }

    local probabilities = {}
    for i, v in ipairs(stations) do
        probabilities[i] = 1
    end

    local script = stations[selectByWeight(random(), probabilities)]

    local faction = Galaxy():getNearestFaction(x, y)
    local station = generator:createStation(faction, script);

    -- remove backup script so there won't be any additional ships
    for i, script in pairs(station:getScripts()) do
        if string.match(script, "backup") then
            station:removeScript(script) -- don't spawn military ships coming for help
        end
    end

    -- clear cargo bay so goods are not leaked when changing the plan
    station:clearCargoBay()

    local blockPlan = Plan(station.id):getMove()
    generator:createWreckage(faction, blockPlan, 10)

    if random:test(generator:getWormHoleProbability()) then generator:createRandomWormHole() end

    local sector = Sector()
    sector:deleteEntity(station)

    sector:addScriptOnce("data/scripts/sector/eventscheduler.lua", "events/pirateattack.lua")

    Placer.resolveIntersections()
end

return SectorTemplate
