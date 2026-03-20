package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local SectorGenerator = include ("SectorGenerator")
local Placer = include("placer")
local Balancing = include("galaxy")
local ShipGenerator = include("shipgenerator")
local FactoryPredictor = include("factorypredictor")
include("music")

local SectorTemplate = {}

-- must be defined, will be used to get the probability of this sector
function SectorTemplate.getProbabilityWeight(x, y, seed, factionIndex, innerArea)
    local d2 = length2(vec2(x, y))

    if d2 > 30 and d2 < Balancing.BlockRingMin2 then
        if factionIndex then
            if innerArea then
                return 10
            else
                return 200
            end
        else
            return 750
        end
    else
        return 0
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
    local seed = Seed(string.join({GameSeed(), x, y, "resistancecell"}, "-"))
    math.randomseed(seed);

    local random = random()

    local contents = {ships = 0, stations = 0, seed = tostring(seed)}
    contents.resourceAsteroids = random:getInt(0, 2)
    contents.resistanceOutposts = 1

    local defendersFactor
    if Galaxy():isCentralFactionArea(x, y) then
        defendersFactor = 1.5
    else
        defendersFactor = 0.75
    end

    contents.defenders = round(random:getInt(4, 6) * defendersFactor)

    contents.stations = 2
    contents.shipyards = 1
    contents.ships = contents.defenders
    local maximum = random:getInt(0, 2)
    contents.claimableAsteroids = random:multitest(maximum, 0.33)

    local possible =
    {
        "merchants/equipmentdock.lua",
        "merchants/factory.lua", -- make factory slightly more likely
        "merchants/factory.lua",
        "merchants/factory.lua",
        "merchants/turretfactory.lua",
        "merchants/repairdock.lua",
        "merchants/resourcetrader.lua",
        "merchants/tradingpost.lua",
        "merchants/casino.lua",
        "merchants/researchstation.lua",
        "merchants/biotope.lua",
        "merchants/militaryoutpost.lua",
    }

    local script = possible[random:getInt(1, #possible)]

    if script == "merchants/factory.lua" then
        contents.factories = 1
    elseif script == "merchants/equipmentdock.lua" then
        contents.equipmentDocks = 1
    elseif script == "merchants/turretfactory.lua" then
        contents.turretFactories = 1
    elseif script == "merchants/repairdock.lua" then
        contents.repairDocks = 1
    elseif script == "merchants/resourcetrader.lua" then
        contents.resourceDepots = 1
    elseif script == "merchants/tradingpost.lua" then
        contents.tradingPosts = 1
    elseif script == "merchants/casino.lua" then
        contents.casinos = 1
    elseif script == "merchants/researchstation.lua" then
        contents.researchStations = 1
    elseif script == "merchants/biotope.lua" then
        contents.biotopes = 1
    elseif script == "merchants/militaryoutpost.lua" then
        contents.militaryOutposts = 1
    end

    local generator = SectorGenerator(x, y)
    contents.asteroidEstimation = generator:estimateAsteroidNumbers(5 + contents.resourceAsteroids + contents.claimableAsteroids, 11.5)

    return contents, random, script
end

function SectorTemplate.musicTracks()
    local good = {
        primary = combine(TrackCollection.Desolate(), TrackCollection.Melancholic()),
        secondary = combine(TrackCollection.Neutral()),
    }

    local neutral = {
        primary = combine(TrackCollection.Desolate(), TrackCollection.Melancholic()),
        secondary = combine(TrackCollection.Neutral(), TrackCollection.Middle()),
    }

    local bad = {
        primary = combine(TrackCollection.Middle(), TrackCollection.Desolate()),
        secondary = TrackCollection.Neutral(),
    }

    return good, neutral, bad
end

-- player is the player who triggered the creation of the sector (only set in start sector, otherwise nil)
function SectorTemplate.generate(player, seed, x, y)
    local contents, random, script = SectorTemplate.contents(x, y)

    local generator = SectorGenerator(x, y)

    local faction = Galaxy():getNearestFaction(x, y)

    local numFields = random:getInt(2, 3)
    for i = 1, numFields do
        generator:createAsteroidField(0.075);
    end

    for i = 1, contents.resourceAsteroids do
        local position = generator:createAsteroidField(0.075);
        generator:createBigAsteroid(position)
    end

    for i = 1, 5 - numFields do
        local position = generator:createEmptyAsteroidField();
        if random:test(0.5) then generator:createEmptyBigAsteroid(position) end
    end

    local numSmallFields = random:getInt(8, 15)
    for i = 1, numSmallFields do
        local mat = generator:createSmallAsteroidField()

        if random:test(0.2) then generator:createStash(mat) end
    end

    for i = 1, contents.claimableAsteroids do
        local mat = generator:createAsteroidField()
        local asteroid = generator:createClaimableAsteroid()
        asteroid.position = mat
    end

    local station = generator:createStation(faction, "merchants/resistanceoutpost.lua")
    if script == "merchants/factory.lua" then
        local production = FactoryPredictor.generateFactoryProductions(x, y, 1)[1]
        station:addScript(script, production)
    else
        station:addScript(script)
    end

    generator:createShipyard(faction);

    for i = 1, contents.defenders do
        ShipGenerator.createDefender(faction)
    end

    if random:test(generator:getWormHoleProbability()) then generator:createRandomWormHole() end

    Sector():addScript("data/scripts/sector/background/respawnresourceasteroids.lua")

    generator:addOffgridAmbientEvents()
    Placer.resolveIntersections()
end

-- called by respawndefenders.lua
function SectorTemplate.getDefenders(contents, seed, x, y)
    local faction = Galaxy():getNearestFaction(x, y)
    return faction.index, contents.defenders
end

return SectorTemplate
