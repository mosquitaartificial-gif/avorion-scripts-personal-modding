package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local SectorGenerator = include ("SectorGenerator")
local NamePool = include ("namepool")
local Placer = include("placer")
local Balancing = include("galaxy")
local ShipGenerator = include("shipgenerator")
include("stringutility")
include("music")
include("randomext")

local SectorTemplate = {}

-- must be defined, will be used to get the probability of this sector
function SectorTemplate.getProbabilityWeight(x, y, seed, factionIndex, innerArea)
    if factionIndex then
        if innerArea then
            return 0
        else
            return 250
        end
    else
        return 350
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
    local seed = Seed(string.join({GameSeed(), x, y, "smugglerhideout"}, "-"))
    math.randomseed(seed);

    local random = random()

    local contents = {ships = 0, stations = 0, seed = tostring(seed)}

    contents.smugglersMarkets = 1
    contents.stations = 2
    contents.shipyards = 1
    contents.defenders = 3
    contents.ships = 3

    contents.resourceAsteroids = random:getInt(0, 2)

    local coords = vec2(x, y)
    if length2(coords) >= Balancing.BlockRingMin2 then
        contents.ships = contents.ships + 1
    end

    local generator = SectorGenerator(x, y)
    contents.asteroidEstimation = generator:estimateAsteroidNumbers(3.5 + contents.resourceAsteroids, 3.5)

    return contents, random
end

function SectorTemplate.musicTracks()
    local good = {
        primary = combine(TrackCollection.Desolate()),
        secondary = combine(TrackCollection.Neutral()),
    }

    local neutral = {
        primary = combine(TrackCollection.Desolate()),
        secondary = combine(TrackCollection.Neutral(), TrackCollection.Middle()),
    }

    local bad = {
        primary = combine(TrackCollection.Middle(), TrackCollection.Desolate()),
        secondary = TrackCollection.Neutral(),
    }

    return good, neutral, bad
end

function SectorTemplate.getFaction(x, y)
    local hx = round(x / 7.5)
    local hy = round(y / 7.5)

    local language = Language(Seed(makeFastHash(GameSeed().value, hx, hy)))
    local baseName = language:getName()
    local stateForm = "The %s Syndicate"%_T
    local factionName = string.format(stateForm, baseName)

    local faction = Galaxy():findFaction(factionName)
    if not faction then
        faction = Galaxy():createFaction(factionName, x * 0.9, y * 0.9)
        faction.baseName = baseName
        faction.stateForm = stateForm
    end

    return faction
end

-- player is the player who triggered the creation of the sector (only set in start sector, otherwise nil)
function SectorTemplate.generate(player, seed, x, y)
    local contents, random = SectorTemplate.contents(x, y)

    local generator = SectorGenerator(x, y)
    local faction = SectorTemplate.getFaction(x, y)

    local station = generator:createStation(faction, "merchants/smugglersmarket.lua")
    station.title = "Smuggler Hideout"%_t
    station:addScript("merchants/tradingpost.lua")
    station:addScript("story/spawnsmugglerrepresentative.lua")
    NamePool.setStationName(station)

    generator:createShipyard(faction);

    -- create ships
    for i = 1, contents.defenders do
        local ship = ShipGenerator.createDefender(faction, generator:getPositionInSector())
        ship:removeScript("antismuggle.lua")
    end

    -- create some asteroids
    local numFields = random:getInt(3, 4)
    for i = 1, numFields do
        local mat = generator:createAsteroidField();
        if random:test(0.15) then generator:createStash(mat) end
    end

    for i = 1, contents.resourceAsteroids do
        local position = generator:createAsteroidField()
        generator:createBigAsteroid(position)
    end

    local numSmallFields = random:getInt(2, 5)
    for i = 1, numSmallFields do
        generator:createSmallAsteroidField()
    end

    if SectorTemplate.gates(x, y) then generator:createGates() end

    if random:test(generator:getWormHoleProbability()) then generator:createRandomWormHole() end

    generator:addOffgridAmbientEvents()
    Placer.resolveIntersections()

    local sector = Sector()

    sector:addScript("data/scripts/sector/background/respawnresourceasteroids.lua")

    local localFaction = Galaxy():getNearestFaction(x, y)

    if localFaction and (localFaction:getTrait("honorable") or 0) > 0.7 then
        sector:addScriptOnce("data/scripts/sector/eventscheduler.lua")
        sector:invokeFunction("data/scripts/sector/eventscheduler.lua", "addEvent", "data/scripts/events/factionattackssmugglers.lua", 120 * 60)
    end

    Placer.resolveIntersections()
end

-- called by respawndefenders.lua
function SectorTemplate.getDefenders(contents, seed, x, y)
    local faction = SectorTemplate.getFaction(x, y)

    return faction.index, contents.defenders, "noAntiSmuggle"
end


return SectorTemplate
