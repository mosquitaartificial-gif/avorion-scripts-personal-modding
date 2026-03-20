package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local SectorGenerator = include ("SectorGenerator")
local Placer = include("placer")
local SectorTurretGenerator = include ("sectorturretgenerator")
local UpgradeGenerator = include ("upgradegenerator")
local ShipGenerator = include("shipgenerator")
include("stringutility")
include("music")

local SectorTemplate = {}

-- must be defined, will be used to get the probability of this sector
function SectorTemplate.getProbabilityWeight(x, y, seed, factionIndex, innerArea)
    if factionIndex then
        if innerArea then
            return 0
        else
            return 100
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
    local seed = Seed(string.join({GameSeed(), x, y, "cultists"}, "-"))
    math.randomseed(seed)

    local random = random()

    local contents = {ships = 0, stations = 0, seed = tostring(seed)}
    contents.ships = random:getInt(6, 12)

    contents.asteroidEstimation = 250
    contents.asteroidCultists = true

    return contents, random
end

function SectorTemplate.musicTracks()
    local good = {
        primary = combine(TrackCollection.Neutral(), TrackCollection.Desolate()),
        secondary = combine(TrackCollection.Melancholic(), TrackCollection.Neutral()),
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

local leaderName = { "Priest"%_t, "Father"%_t, "Bishop"%_t, "Abbot"%_t, "Apostle"%_t, "Elder"%_t, "Pastor"%_t, "Abhyasi"%_t,
"Bhagat"%_t, "Guru"%_t, "Saint"%_t, "Ayatollah"%_t, "Imam"%_t, "Rabbi"%_t, "Druid"%_t}

-- player is the player who triggered the creation of the sector (only set in start sector, otherwise nil)
function SectorTemplate.generate(player, seed, x, y)
    local contents, random = SectorTemplate.contents(x, y)

    local generator = SectorGenerator(x, y)

    local language = Language(Seed(makeFastHash(seed.value, x, y)))
    local baseName = language:getName()
    local stateForm = "The %s Cult"%_T
    local factionName = string.format(stateForm, baseName)

    local faction = Galaxy():findFaction(factionName)
    if not faction then
        faction = Galaxy():createFaction(factionName, x / 2, y / 2)
        faction.baseName = baseName
        faction.stateForm = stateForm
    end
    faction.homeSectorUnknown = true

    -- create big asteroid in the center
    local matrix = generator:getPositionInSector(1000);
    local asteroid = generator:createBigAsteroid(matrix)

    -- create asteroid rings
    local radius = 300
    local angle = 0

    for i = 1, random:getInt(2, 3) do
        radius = radius + getFloat(300, 500)
        local ringMatrix = generator:getUniformPositionInSector(0)
        ringMatrix.pos = matrix.pos

        for i = 0, (random:getInt(70, 100)) do
            local size = getFloat(5, 15)
            local asteroidPos = vec3(math.cos(angle), math.sin(angle), 0) * (radius + getFloat(0, 10))
            asteroidPos = ringMatrix:transformCoord(asteroidPos)

            generator:createSmallAsteroid(asteroidPos, size, false, generator:getAsteroidType())
            angle = angle + getFloat(1, 2)
        end
    end

    -- create cultist ships
    local cultistRadius = getFloat(200, 600)
    local cultists = {}

    for i = 1, contents.ships do
        local angle = 2 * math.pi * i / contents.ships
        local cultistLook = vec3(math.cos(angle), math.sin(angle), 0)
        local cultistMatrix = MatrixLookUpPosition(-cultistLook, matrix.up,
                                                   matrix.pos + cultistLook * cultistRadius)

        local volume = Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation()
        local ship
        if i == 1 then
            ship = ShipGenerator.createMilitaryShip(faction, cultistMatrix, volume * 3)
            ship:addScript("dialogs/encounters/cultistleader.lua")
            ship.title = leaderName[random:getInt(1, #leaderName)]
            addLeaderLoot(ship)
        else
            ship = ShipGenerator.createMilitaryShip(faction, cultistMatrix, volume)
        end

        table.insert(cultists, ship.index.string)
        ship:setValue("is_cultist", true)
    end


    Sector():addScriptOnce("data/scripts/sector/eventscheduler.lua", "events/pirateattack.lua")
    Sector():addScript("data/scripts/sector/cultistbehavior.lua", matrix, asteroid.index.string, unpack(cultists))

    generator:addOffgridAmbientEvents()
    Placer.resolveIntersections()
end

-- use loot similar to pirate mothership
function addLeaderLoot(craft)
    local x, y = Sector():getCoordinates()

    local turretGenerator = SectorTurretGenerator()
    local turretRarities = turretGenerator:getSectorRarityDistribution(x, y)

    local upgradeGenerator = UpgradeGenerator()
    local upgradeRarities = upgradeGenerator:getSectorRarityDistribution(x, y)

    turretRarities[-1] = 0 -- no petty turrets
    turretRarities[0] = 0 -- no common turrets
    turretRarities[1] = 0 -- no uncommon turrets
    turretRarities[2] = turretRarities[2] * 0.5 -- reduce rates for rare turrets to have higher chance for the others

    upgradeRarities[-1] = 0 -- no petty upgrades
    upgradeRarities[0] = 0 -- no common upgrades
    upgradeRarities[1] = 0 -- no uncommon upgrades
    upgradeRarities[2] = upgradeRarities[2] * 0.5 -- reduce rates for rare subsystems to have higher chance for the others

    turretGenerator.rarities = turretRarities

    -- has more potential loot then a pirate mothership, to compensate for missing turrets on ship
    for i = 1, 3 do
        if random():test(0.5) then
            Loot(craft):insert(upgradeGenerator:generateSectorSystem(x, y, nil, upgradeRarities))
        else
            Loot(craft):insert(InventoryTurret(turretGenerator:generate(x, y)))
        end
    end
end

return SectorTemplate
