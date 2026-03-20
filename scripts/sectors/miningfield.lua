package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local SectorGenerator = include ("SectorGenerator")
local Placer = include("placer")
local FactoryPredictor = include("factorypredictor")
local ShipGenerator = include("shipgenerator")
include ("productions")
include ("music")

local SectorTemplate = {}

-- must be defined, will be used to get the probability of this sector
function SectorTemplate.getProbabilityWeight(x, y, seed, factionIndex, innerArea)
    if factionIndex then
        if innerArea then
            return 300
        else
            return 500
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
    local seed = Seed(string.join({GameSeed(), x, y, "miningfield"}, "-"))
    math.randomseed(seed);

    local random = random()
    local contents = {ships = 0, stations = 0, seed = tostring(seed)}

    contents.mines = 6

    if random:test(0.75) then
        contents.resourceDepots = 1
    end

    local faction, otherFaction
    local sx = x + random:getInt(-15, 15)
    local sy = y + random:getInt(-15, 15)

    if random:test(0.33) then
        contents.tradingPosts = 1
    end

    local otherTradingPostPossible = random:test(0.5)

    if onServer() then
        faction = Galaxy():getLocalFaction(x, y) or Galaxy():getNearestFaction(x, y)

        otherFaction = Galaxy():getNearestFaction(sx, sy)
        if faction:getRelations(otherFaction.index) < -20000 then otherFaction = nil end

        -- create a trader from maybe another faction
        if contents.tradingPosts then
            if otherTradingPostPossible then
                if otherFaction and faction.index ~= otherFaction.index then
                    contents.neighborTradingPosts = 1
                end
            end
        end
    end

    -- create ships
    local defendersFactor
    if Galaxy():isCentralFactionArea(x, y) then
        defendersFactor = 1.5
    else
        defendersFactor = 0.75
    end

    contents.defenders = round(random:getInt(4, 6) * defendersFactor)
    contents.miners = random:getInt(1, 2)

    contents.ships = contents.defenders + contents.miners
    contents.stations = contents.mines + (contents.resourceDepots or 0) + (contents.tradingPosts or 0) + (contents.neighborTradingPosts or 0)

    local maximum = random:getInt(0, 1)
    contents.claimableAsteroids = random:multitest(maximum, 0.33)

    if onServer() then
        contents.faction = faction.index

        if otherFaction then
            contents.neighbor = otherFaction.index
        end
    end

    local generator = SectorGenerator(x, y)
    contents.asteroidEstimation = generator:estimateAsteroidNumbers(1 + contents.mines + contents.claimableAsteroids, 2.5)

    return contents, random, faction, otherFaction
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
    local contents, random, faction, otherFaction = SectorTemplate.contents(x, y)

    local generator = SectorGenerator(x, y)
    local faction = Galaxy():getLocalFaction(x, y) or Galaxy():getNearestFaction(x, y)
    if not faction then return end

    -- find out productions that take place in mines
--    local miningProductions = getMiningProductions()
    local productions = FactoryPredictor.generateMineProductions(x, y, contents.mines)

    -- create several mines
    for _, production in pairs(productions) do
        -- create asteroid field
        local pos = generator:createAsteroidField(0.075);

        -- create the mine inside the field
        local mine = generator:createStation(faction, "data/scripts/entity/merchants/factory.lua", production);
        mine.position = pos
    end

    -- maybe create some asteroids
    local numFields = random:getInt(0, 2)
    for i = 1, numFields do
        generator:createEmptyAsteroidField();
    end

    -- create a trading post
    if contents.tradingPosts then
        generator:createStation(faction, "data/scripts/entity/merchants/tradingpost.lua");
    end

    if contents.resourceDepots then
        generator:createStation(faction, "data/scripts/entity/merchants/resourcetrader.lua");
    end

    -- create defenders
    for i = 1, contents.defenders do
        ShipGenerator.createDefender(faction, generator:getPositionInSector())
    end

    -- create a trader from maybe another faction
    if contents.neighborTradingPosts then
        generator:createStation(otherFaction, "data/scripts/entity/merchants/tradingpost.lua");
    end

    for i = 1, contents.claimableAsteroids do
        local mat = generator:createAsteroidField()
        local asteroid = generator:createClaimableAsteroid()
        asteroid.position = mat
    end

    for i = 1, contents.miners do
        local ship = ShipGenerator.createMiningShip(faction, generator:getPositionInSector())
        ship:addScript("ai/mine.lua")
    end

    local numSmallFields = random:getInt(0, 5)
    for i = 1, numSmallFields do
        generator:createSmallAsteroidField(0.1)
    end

    if SectorTemplate.gates(x, y) then generator:createGates() end

    if random:test(generator:getWormHoleProbability()) then generator:createRandomWormHole() end

    Sector():addScriptOnce("data/scripts/sector/eventscheduler.lua", "events/pirateattack.lua")
    Sector():addScript("data/scripts/sector/background/respawnresourceasteroids.lua")

    generator:addAmbientEvents()

    Placer.resolveIntersections()
    generator:deleteObjectsFromDockingPositions()
end

-- called by respawndefenders.lua
function SectorTemplate.getDefenders(contents, seed, x, y)
    return contents.faction, contents.defenders
end

return SectorTemplate

