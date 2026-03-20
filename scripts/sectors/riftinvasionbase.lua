
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local SectorGenerator = include ("SectorGenerator")
local Placer = include("placer")
local FactoryPredictor = include("factorypredictor")
local ShipUtility = include("shiputility")
local ShipGenerator = include("shipgenerator")
local PassageMap = include ("passagemap")
include("music")

local SectorTemplate = {}

-- must be defined, will be used to get the probability of this sector
function SectorTemplate.getProbabilityWeight(x, y, seed, factionIndex, innerArea)
    if not SectorTemplate.checkRiftNearby(x, y) then
        return 0
    end
    if factionIndex then
        if innerArea then
            return 2500
        else
            return 1500
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
    return false
end

-- this function returns what relevant contents there will be in the sector (exact)
function SectorTemplate.contents(x, y)
    local seed = Seed(string.join({GameSeed(), x, y, "riftinvasionbase"}, "-"))
    math.randomseed(seed);

    local random = random()

    local contents = {ships = 0, stations = 0, seed = tostring(seed)}

    contents.riftResearchCenters = 1
    contents.shipyards = 1
    contents.repairDocks = 1
    contents.equipmentDocks = 1

    faction = Galaxy():getLocalFaction(x, y) or Galaxy():getNearestFaction(x, y)

    -- create defenders
    local defendersFactor
    if Galaxy():isCentralFactionArea(x, y) then
        defendersFactor = 1.5
    else
        defendersFactor = 0.5
    end

    contents.defenders = round(random:getFloat(1, 2) * defendersFactor)

    contents.ships = contents.defenders
    contents.stations = 4

    if onServer() then
        contents.faction = faction.index
    end

    local generator = SectorGenerator(x, y)
    contents.asteroidEstimation = generator:estimateAsteroidNumbers(1, 2.5)

    return contents, random, faction
end


function SectorTemplate.musicTracks()
    local good = {
        primary = TrackCollection.HappyNoParticle(),
        secondary = TrackCollection.HappyNeutral(),
    }

    local neutral = {
        primary = TrackCollection.Neutral(),
        secondary = TrackCollection.HappyNeutral(),
    }

    local bad = {
        primary = TrackCollection.Middle(),
        secondary = TrackCollection.Neutral(),
    }

    return good, neutral, bad
end

-- player is the player who triggered the creation of the sector (only set in start sector, otherwise nil)
function SectorTemplate.generate(player, seed, x, y)
    local contents, random, faction = SectorTemplate.contents(x, y)

    local generator = SectorGenerator(x, y)

    -- create stations
    generator:createRiftResearchCenter(faction);
    generator:createShipyard(faction);
    generator:createRepairDock(faction);
    generator:createEquipmentDock(faction)

    -- maybe create some asteroids
    local numFields = random:getInt(0, 1)
    for i = 1, numFields do
        local pos = generator:createEmptyAsteroidField();
        if random:test(0.4) then generator:createEmptyBigAsteroid(pos) end
    end

    numFields = random:getInt(0, 1)
    for i = 1, numFields do
        local pos = generator:createAsteroidField();
        if random:test(0.4) then generator:createBigAsteroid(pos) end
    end

    -- create defenders
    for i = 1, contents.defenders do
        ShipGenerator.createDefender(faction, generator:getPositionInSector())
    end

    local numSmallFields = random:getInt(0, 5)
    for i = 1, numSmallFields do
        generator:createSmallAsteroidField()
    end

    if SectorTemplate.gates(x, y) then generator:createGates() end

    if random:test(generator:getWormHoleProbability()) then generator:createRandomWormHole() end

    Sector():addScriptOnce("data/scripts/sector/eventscheduler.lua", "events/pirateattack.lua")

    generator:addAmbientEvents()
    Placer.resolveIntersections()
end

-- called by respawndefenders.lua
function SectorTemplate.getDefenders(contents, seed, x, y)
    return contents.faction, contents.defenders
end

function SectorTemplate.checkRiftNearby(x_in, y_in)
    local passageMap = PassageMap(GameSeed())
    for x = x_in - 3, x_in + 3 do
        for y = y_in - 3, y_in + 3 do
            if not passageMap:passable(x, y) then return true end
        end
    end

    return false
end

return SectorTemplate
