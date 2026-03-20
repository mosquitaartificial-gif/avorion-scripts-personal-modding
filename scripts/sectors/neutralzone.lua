
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local SectorGenerator = include ("SectorGenerator")
local Placer = include("placer")
local ShipGenerator = include("shipgenerator")
include("music")

local SectorTemplate = {}

-- must be defined, will be used to get the probability of this sector
function SectorTemplate.getProbabilityWeight(x, y, seed, factionIndex, innerArea)
    if factionIndex then
        if innerArea then
            return 500
        else
            return 400
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
    return true
end

-- this function returns what relevant contents there will be in the sector (exact)
function SectorTemplate.contents(x, y)
    local seed = Seed(string.join({GameSeed(), x, y, "neutralzone"}, "-"))
    math.randomseed(seed);

    local random = random()
    local contents = {ships = 0, stations = 0, seed = tostring(seed)}

    contents.resourceDepots = 1
    contents.tradingPosts = 1
    contents.repairDocks = 1
    contents.neighborTradingPosts = 0

    -- create trading posts from other factions
    local faction
    local otherFactions = {}

    if onServer() then
        faction = Galaxy():getLocalFaction(x, y) or Galaxy():getNearestFaction(x, y)
        contents.faction = faction.index

        otherFactions[faction.index] = true
    end

    for i = 1, 10 do
        local dx = random:getInt(-20, 20)
        local dy = random:getInt(-20, 20)

        if onServer() then
            local otherFaction = Galaxy():getNearestFaction(x + dx, y + dy)

            if otherFaction and not otherFactions[otherFaction.index] then
                otherFactions[otherFaction.index] = true

                contents.neighborTradingPosts = contents.neighborTradingPosts + 1
                contents.neighbor = otherFaction.index
            end
        end
    end

    if onServer() then
        otherFactions[faction.index] = nil
    end

    local defendersFactor
    if Galaxy():isCentralFactionArea(x, y) then
        defendersFactor = 1.5
    else
        defendersFactor = 0.75

        if random:test(0.05) then
            contents.travelHubs = 1
        end
    end

    contents.defenders = round(random:getInt(4, 6) * defendersFactor)

    contents.ships = contents.defenders
    contents.stations = 3 + contents.neighborTradingPosts + (contents.travelHubs or 0)

    local generator = SectorGenerator(x, y)
    contents.asteroidEstimation = generator:estimateAsteroidNumbers(1, 2.5)

    return contents, random, faction, otherFactions
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
    local contents, random, faction, otherFactions = SectorTemplate.contents(x, y)

    local generator = SectorGenerator(x, y)

    generator:createStation(faction, "data/scripts/entity/merchants/resourcetrader.lua");
    generator:createStation(faction, "data/scripts/entity/merchants/tradingpost.lua");
    generator:createRepairDock(faction);

    if contents.travelHubs then
        generator:createTravelHub(faction);
    end

    -- create trading posts from other factions
    for factionIndex, _ in pairs(otherFactions) do
        generator:createStation(Faction(factionIndex), "data/scripts/entity/merchants/tradingpost.lua");
    end

    -- maybe create some asteroids
    local numFields = random:getInt(0, 1)
    for i = 1, numFields do
        local pos = generator:createEmptyAsteroidField();
        if random:test(0.4) then generator:createEmptyBigAsteroid(pos) end
    end

    local numFields = random:getInt(0, 1)
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

    Sector():addScriptOnce("data/scripts/sector/eventscheduler.lua")
    generator:addAmbientEvents()

    -- this one is added last since it will adjust the events that have been added
    Sector():addScript("data/scripts/sector/neutralzone.lua")

    Placer.resolveIntersections()
end

-- called by respawndefenders.lua
function SectorTemplate.getDefenders(contents, seed, x, y)
    return contents.faction, contents.defenders
end

return SectorTemplate
