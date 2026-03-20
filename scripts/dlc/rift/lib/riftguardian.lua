package.path = package.path .. ";data/scripts/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"

local RiftObjects = include("dlc/rift/lib/riftobjects")
local AsteroidFieldGenerator = include ("asteroidfieldgenerator")
local AsteroidPlanGenerator = include("asteroidplangenerator")
local SectorTurretGenerator = include ("sectorturretgenerator")
local UpgradeGenerator = include ("upgradegenerator")
local Xsotan = include("story/xsotan")
local PlanGenerator = include ("plangenerator")
local ShipUtility = include ("shiputility")
local RiftMissionUT = include("dlc/rift/lib/riftmissionutility")

local RiftGuardian = {}

function RiftGuardian.createStation(position)
    local x, y = Sector():getCoordinates()
    dx = dx or x
    dy = dy or y

    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))
    if material.value < MaterialType.Naonite then material = Material(MaterialType.Naonite) end
    local volume = Balancing_GetSectorShipVolume(x, y) * 25
    local faction = Xsotan.getFaction()
    local plan = PlanGenerator.makeXsotanShipPlan(volume, material)
    plan:addBlock(vec3(), vec3(1, 1, 1), plan.rootIndex, -1, ColorRGB(1, 1, 1), material, Matrix(), BlockType.ShieldGenerator, ColorNone())

    local desc = StationDescriptor()
    desc.type = EntityType.Unknown
    desc:removeComponent(ComponentType.DockingPositions)
    desc:removeComponent(ComponentType.CraftDecay)
    desc:setValue("inconspicuous_indicator", true)
    desc.position = position
    desc.factionIndex = faction.index
    desc:setMovePlan(plan)
    desc:setTitle("Wormhole Sustainer"%_T, {})
    desc:addScriptOnce("story/xsotanbehaviour.lua")
    desc:setValue("is_xsotan", true)

    local station = Sector():createEntity(desc)

    -- Xsotan have random turrets
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false

    local turret = generator:generate(x, y, 0, Rarity(RarityType.Rare), WeaponType.RailGun)
    local numTurrets = math.max(2, Balancing_GetEnemySectorTurrets(x, y) * 0.75)

    ShipUtility.addTurretsToCraft(station, turret, numTurrets)

    station.crew = station.idealCrew
    station.shieldDurability = station.shieldMaxDurability

    AddDefaultShipScripts(station)

    Boarding(station).boardable = false
    station.dockable = false

    return station
end

function RiftGuardian.createWormhole(position, dx, dy)
    local desc = WormholeDescriptor()

    local cpwormhole = desc:getComponent(ComponentType.WormHole)
    cpwormhole:setTargetCoordinates(dx, dy)
    cpwormhole.color = ColorRGB(1, 0, 0)
    cpwormhole.visualSize = 250
    cpwormhole.passageSize = math.huge
    cpwormhole.simplifiedVisuals = true
    cpwormhole.enabled = false
    cpwormhole.oneWay = true

    desc:addScriptOnce("data/scripts/entity/wormhole.lua")

    desc.position = position

    local wormHole = Sector():createEntity(desc)
    wormHole:setValue("rift_guardian_wormhole", true)

    return wormHole
end

function RiftGuardian.createNormalAsteroidField(location, numAsteroids)
    numAsteroids = numAsteroids or 300
    local generator = AsteroidFieldGenerator(Sector():getCoordinates())

    generator.asteroidPositions = generator:generateOrganicCloud(numAsteroids, location)
    local position, asteroids = generator:createAsteroidFieldEx(numAsteroids, _, 10.0, 25.0, false, 0);

    for _, asteroid in pairs(asteroids) do
        asteroid:setValue("rg_normal", true)
    end
end

function RiftGuardian.createRichAsteroidField(location, numAsteroids)
    numAsteroids = numAsteroids or 300
    local generator = AsteroidFieldGenerator(Sector():getCoordinates())

    generator.asteroidPositions = generator:generateOrganicCloud(numAsteroids, location)
    local position, asteroids = generator:createAsteroidFieldEx(numAsteroids, _, 10.0, 25.0, true, 1);

    for _, asteroid in pairs(asteroids) do
        asteroid:setValue("rg_rich", true)
    end
end

function RiftGuardian.createCrystallineAsteroidField(location, numAsteroids)
    numAsteroids = numAsteroids or 300

    local sector = Sector()
    local fieldGenerator = AsteroidFieldGenerator(sector:getCoordinates())
    local asteroidPositions = fieldGenerator:generateOrganicCloud(numAsteroids, location)

    local generator = AsteroidPlanGenerator()
    generator.Stone = BlockType.Glass
    generator.StoneEdge = BlockType.GlassEdge
    generator.StoneCorner = BlockType.GlassCorner
    generator.StoneOuterCorner = BlockType.GlassOuterCorner
    generator.StoneInnerCorner = BlockType.GlassInnerCorner
    generator.StoneTwistedCorner1 = BlockType.GlassTwistedCorner1
    generator.StoneTwistedCorner2 = BlockType.GlassTwistedCorner2
    generator.StoneFlatCorner = BlockType.GlassFlatCorner
    generator.RichStone = BlockType.Glass
    generator.RichStoneEdge = BlockType.GlassEdge
    generator.RichStoneCorner = BlockType.GlassCorner
    generator.RichStoneInnerCorner = BlockType.GlassInnerCorner
    generator.RichStoneOuterCorner = BlockType.GlassOuterCorner
    generator.RichStoneTwistedCorner1 = BlockType.GlassTwistedCorner1
    generator.RichStoneTwistedCorner2 = BlockType.GlassTwistedCorner2
    generator.RichStoneFlatCorner = BlockType.GlassFlatCorner
    generator.SuperRichStone = BlockType.Glass
    generator.SuperRichStoneEdge = BlockType.GlassEdge
    generator.SuperRichStoneCorner = BlockType.GlassCorner
    generator.SuperRichStoneInnerCorner = BlockType.GlassInnerCorner
    generator.SuperRichStoneOuterCorner = BlockType.GlassOuterCorner
    generator.SuperRichStoneTwistedCorner1 = BlockType.GlassTwistedCorner1
    generator.SuperRichStoneTwistedCorner2 = BlockType.GlassTwistedCorner2
    generator.SuperRichStoneFlatCorner = BlockType.GlassFlatCorner

    local material = Material(MaterialType.Titanium)
    local generationFunctions = {
        function() return generator:makeTitaniumAsteroidPlan(10, material, {}) end,
        function() return generator:makeTriniumAsteroidPlan(10, material, {}) end,
        function() return generator:makeXanionAsteroidPlan(10, material, {}) end,
        function() return generator:makeOgoniteAsteroidPlan(10, material, {}) end,
        function() return generator:makeAvorionAsteroidPlan(10, material, {}) end,
    }

    for _, location in pairs(asteroidPositions) do
        local plan = randomEntry(generationFunctions)()
        plan:setColor(ColorRGB(0.4, 0.9, 0.9))

        local position = MatrixLookUpPosition(random():getDirection(), random():getDirection(), location)
        local asteroid = sector:createAsteroid(plan, false, position)
        asteroid:setValue("rg_crystal", true)
    end
end

function RiftGuardian.createMetalAsteroidField(location, numAsteroids)
    numAsteroids = numAsteroids or 300

    local sector = Sector()
    local fieldGenerator = AsteroidFieldGenerator(sector:getCoordinates())
    local asteroidPositions = fieldGenerator:generateOrganicCloud(numAsteroids, location)

    local generator = AsteroidPlanGenerator()
    generator.Stone = BlockType.BlankHull
    generator.StoneEdge = BlockType.EdgeHull
    generator.StoneCorner = BlockType.CornerHull
    generator.StoneOuterCorner = BlockType.OuterCornerHull
    generator.StoneInnerCorner = BlockType.InnerCornerHull
    generator.StoneTwistedCorner1 = BlockType.TwistedCorner1
    generator.StoneTwistedCorner2 = BlockType.TwistedCorner2
    generator.StoneFlatCorner = BlockType.FlatCornerHull
    generator.RichStone = BlockType.BlankHull
    generator.RichStoneEdge = BlockType.EdgeHull
    generator.RichStoneCorner = BlockType.CornerHull
    generator.RichStoneInnerCorner = BlockType.InnerCornerHull
    generator.RichStoneOuterCorner = BlockType.OuterCornerHull
    generator.RichStoneTwistedCorner1 = BlockType.TwistedCorner1
    generator.RichStoneTwistedCorner2 = BlockType.TwistedCorner2
    generator.RichStoneFlatCorner = BlockType.FlatCornerHull
    generator.SuperRichStone = BlockType.BlankHull
    generator.SuperRichStoneEdge = BlockType.EdgeHull
    generator.SuperRichStoneCorner = BlockType.CornerHull
    generator.SuperRichStoneInnerCorner = BlockType.InnerCornerHull
    generator.SuperRichStoneOuterCorner = BlockType.OuterCornerHull
    generator.SuperRichStoneTwistedCorner1 = BlockType.TwistedCorner1
    generator.SuperRichStoneTwistedCorner2 = BlockType.TwistedCorner2
    generator.SuperRichStoneFlatCorner = BlockType.FlatCornerHull

    local material = Material(MaterialType.Titanium)
    local generationFunctions = {
        function() return generator:makeTitaniumAsteroidPlan(10, material, {}) end,
        function() return generator:makeTriniumAsteroidPlan(10, material, {}) end,
        function() return generator:makeXanionAsteroidPlan(10, material, {}) end,
        function() return generator:makeOgoniteAsteroidPlan(10, material, {}) end,
        function() return generator:makeAvorionAsteroidPlan(10, material, {}) end,
        function() return generator:makeCuboidAsteroidPlan(10, material) end,
        function() return generator:makeMonolithAsteroidPlan(10, material) end,
    }

    for _, location in pairs(asteroidPositions) do
        local plan = randomEntry(generationFunctions)()
        plan:setColor(ColorRGB(0.25, 0.25, 0.25))

        local position = MatrixLookUpPosition(random():getDirection(), random():getDirection(), location)
        local asteroid = sector:createAsteroid(plan, false, position)
        asteroid:setValue("rg_metal", true)
    end
end

function RiftGuardian.createAllroundAsteroidField(location, numAsteroids)
    numAsteroids = numAsteroids or 300

    RiftGuardian.createNormalAsteroidField(location, numAsteroids / 4)
    RiftGuardian.createRichAsteroidField(location, numAsteroids / 4)
    RiftGuardian.createCrystallineAsteroidField(location, numAsteroids / 4)
    RiftGuardian.createMetalAsteroidField(location, numAsteroids / 4)
end

function RiftGuardian.create(position, dx, dy, minimal)
    position = position or Matrix()

    RiftGuardian.createWormhole(position, dx, dy)

    local functions = {
        RiftGuardian.createNormalAsteroidField,
        RiftGuardian.createRichAsteroidField,
        RiftGuardian.createCrystallineAsteroidField,
        RiftGuardian.createMetalAsteroidField,
        RiftGuardian.createAllroundAsteroidField,
    }

    for i = 1, 5 do
        local angle = i / 5 * math.pi * 2
        local dir = vec3(math.sin(angle), math.cos(angle), 0) * 4000

        local stationPosition = MatrixLookUpPosition(-dir, vec3(0, 0, 1), dir) * position
        local station = RiftGuardian.createStation(stationPosition)
        station:setValue("rift_guardian_station", i)

        local numAsteroids = 300
        if minimal then numAsteroids = 25 end

        functions[i](stationPosition.translation, numAsteroids)
    end

    local x, y = Sector():getCoordinates()
    dx = dx or x
    dy = dy or y

    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))
    if material.value < MaterialType.Naonite then material = Material(MaterialType.Naonite) end
    local volume = Balancing_GetSectorShipVolume(x, y) * 20
    local faction = Xsotan.getFaction()
    local plan = PlanGenerator.makeXsotanShipPlan(volume, material)
    plan:addBlock(vec3(), vec3(1, 1, 1), plan.rootIndex, -1, ColorRGB(1, 1, 1), material, Matrix(), BlockType.ShieldGenerator, ColorNone())

    local ship = Sector():createShip(faction, "", plan, position)

    -- Xsotan have random turrets
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false

    local turret = generator:generate(x, y, 0, Rarity(RarityType.Rare), WeaponType.RailGun)
    local numTurrets = math.max(2, Balancing_GetEnemySectorTurrets(x, y) * 0.75)

    ShipUtility.addTurretsToCraft(ship, turret, numTurrets)

    ship:setTitle("Xsotan Rift Guardian"%_T, {})
    ship.crew = ship.idealCrew
    ship.shieldDurability = ship.shieldMaxDurability

    AddDefaultShipScripts(ship)

    local upgrades =
    {
        {rarity = Rarity(RarityType.Legendary), amount = 2},
        {rarity = Rarity(RarityType.Exotic), amount = 3},
        {rarity = Rarity(RarityType.Exceptional), amount = 3},
        {rarity = Rarity(RarityType.Rare), amount = 5},
        {rarity = Rarity(RarityType.Uncommon), amount = 8},
        {rarity = Rarity(RarityType.Common), amount = 14},
    }

    local turrets =
    {
        {rarity = Rarity(RarityType.Legendary), amount = 2},
        {rarity = Rarity(RarityType.Exotic), amount = 3},
        {rarity = Rarity(RarityType.Exceptional), amount = 3},
        {rarity = Rarity(RarityType.Rare), amount = 5},
        {rarity = Rarity(RarityType.Uncommon), amount = 8},
        {rarity = Rarity(RarityType.Common), amount = 14},
    }

    local generator = UpgradeGenerator()
    for _, p in pairs(upgrades) do
        for i = 1, p.amount do
            Loot(ship):insert(generator:generateSectorSystem(x, y, p.rarity))
        end
    end

    for _, p in pairs(turrets) do
        for i = 1, p.amount do
            Loot(ship):insert(InventoryTurret(SectorTurretGenerator():generate(x, y, 0, p.rarity)))
        end
    end

    local riftDepth = 25

    -- adds legendary turret drop
    ship:addScriptOnce("internal/common/entity/background/legendaryloot.lua")
    -- adds exotic hybrid upgrade drop
    local upgrade = RiftMissionUT.getDroppableHybridUpgrade(x, y, riftDepth, Rarity(RarityType.Exotic))
    Loot(ship):insert(upgrade)

    ship:addScriptOnce("story/xsotanbehaviour.lua")
    ship:addScriptOnce("internal/dlc/rift/entity/xsotanriftguardian.lua", dx, dy)
    ship:setValue("is_xsotan", true)
    ship.name = ""

    Boarding(ship).boardable = false
    ship.dockable = false

    return ship
end

return RiftGuardian
