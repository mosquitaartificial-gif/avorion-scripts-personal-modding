
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local SectorGenerator = include ("SectorGenerator")
local Placer = include("placer")
local SpawnUtility = include ("spawnutility")
local ShipGenerator = include("shipgenerator")
include("music")

local SectorTemplate = {}

-- must be defined, will be used to get the probability of this sector
function SectorTemplate.getProbabilityWeight(x, y, seed, factionIndex, innerArea)
    if factionIndex then
        if innerArea then
            return 0
        else
            return 50
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
    local seed = Seed(string.join({GameSeed(), x, y, "piratestation"}, "-"))
    math.randomseed(seed);

    local random = random()

    local contents = {ships = 0, stations = 0, seed = tostring(seed)}

    local dist = math.sqrt(x * x + y * y)
    if dist < 410 then
        -- create a shipyard station
        contents.shipyards = 1
        contents.stations = 1
    end

    contents.ships = random:getInt(10, 15)
    contents.ships = round(lerp(dist, 450, 370, 2, contents.ships))
    contents.defenders = random:getInt(4, 6)
    contents.defenders = round(lerp(dist, 450, 370, 1, contents.defenders))
    contents.resourceAsteroids = random:getInt(0, 2)

    contents.ships = contents.ships + contents.defenders

    local generator = SectorGenerator(x, y)
    contents.asteroidEstimation = generator:estimateAsteroidNumbers(1 + contents.resourceAsteroids, 3.5)

    contents.pirateEncounter = true

    return contents, random
end

function SectorTemplate.musicTracks()
    local good = {
        primary = TrackCollection.Neutral(),
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
    local dist = math.sqrt(x * x + y * y)

    local faction = Galaxy():getPirateFaction(Balancing_GetPirateLevel(x, y) + 1)

    if contents.shipyards then
        local shipyard = generator:createShipyard(faction);
        shipyard:addScriptOnce("utility/buildingknowledgeloot.lua")
    end

    -- maybe create some asteroids
    local numFields = random:getInt(0, 2)
    for i = 1, numFields do
        generator:createAsteroidField();
    end

    for i = 1, contents.resourceAsteroids do
        local position = generator:createAsteroidField()
        generator:createBigAsteroid(position)
    end

    -- create ships
    local pirates = {}
    for i = 1, contents.ships - contents.defenders do
        local ship = ShipGenerator.createMilitaryShip(faction, generator:getPositionInSector())
        ship:setValue("is_pirate", true)
        ship:addScript("ai/patrol.lua")
        table.insert(pirates, ship)
    end

    for i = 1, contents.defenders do
        local ship = ShipGenerator.createDefender(faction, generator:getPositionInSector())
        ship:setValue("is_pirate", true)
        table.insert(pirates, ship)
    end
    SpawnUtility.addEnemyBuffs(pirates)

    local numSmallFields = random:getInt(2, 5)
    for i = 1, numSmallFields do
        generator:createSmallAsteroidField()
    end

    if random:test(generator:getWormHoleProbability()) then generator:createRandomWormHole() end

    Sector():addScriptOnce("data/scripts/sector/eventscheduler.lua", "events/pirateattack.lua")

    generator:addOffgridAmbientEvents()
    Placer.resolveIntersections()
end

-- don't respawn defenders
--function SectorTemplate.getDefenders(contents, seed, x, y)
--end


return SectorTemplate
