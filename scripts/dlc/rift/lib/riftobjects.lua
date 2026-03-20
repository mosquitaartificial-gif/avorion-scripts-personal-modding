package.path = package.path .. ";data/scripts/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"

local PlanGenerator = include ("plangenerator")
local NamePool = include ("namepool")
local SectorGenerator = include("SectorGenerator")
local AsteroidPlanGenerator = include("asteroidplangenerator")
local SectorTurretGenerator = include("sectorturretgenerator")
local ShipUtility = include("shiputility")
include("plangeneratorbase")
include("randomext")


local RiftObjects = {}

function RiftObjects.getFaction()
    local name = "Ancient Tech"%_T

    local galaxy = Galaxy()
    local faction = galaxy:findFaction(name)
    if faction == nil then
        faction = galaxy:createFaction(name, 350, 0)
        faction.initialRelations = 0
        faction.initialRelationsToPlayer = 0
        faction.staticRelationsToPlayers = true
        faction.homeSectorUnknown = true

        for trait, value in pairs(faction:getTraits()) do
            faction:setTrait(trait, 0) -- completely neutral / unknown
        end

        faction:setTrait("invisible", 1)
    end

    faction.initialRelationsToPlayer = 0
    faction.staticRelationsToPlayers = true
    faction.homeSectorUnknown = true

    return faction
end

function RiftObjects.makeRiftObjectDescriptor(position)
    local desc = StationDescriptor()
    desc.type = EntityType.Unknown

    desc:removeComponent(ComponentType.DockingPositions)
    desc:removeComponent(ComponentType.CraftDecay)
    desc.position = position
    desc:setValue("inconspicuous_indicator", true)
    desc:setValue("untransferrable", true)

    return desc
end

function RiftObjects.makeSimpleRiftObjectDescriptor(position)
    local desc = EntityDescriptor()
    desc.type = EntityType.Unknown

    desc:addComponents(
       ComponentType.Plan,
       ComponentType.BspTree,
       ComponentType.Intersection,
       ComponentType.Asleep,
       ComponentType.DamageContributors,
       ComponentType.BoundingSphere,
       ComponentType.BoundingBox,
       ComponentType.Velocity,
       ComponentType.Physics,
       ComponentType.Scripts,
       ComponentType.ScriptCallback,
       ComponentType.Title,
       ComponentType.Owner,
       ComponentType.FactionNotifier,
       ComponentType.WreckageCreator,
       ComponentType.InteractionText,
       ComponentType.Loot
       )
    desc.position = position
    desc:setValue("inconspicuous_indicator", true)
    desc:setValue("untransferrable", true)

    return desc
end

-- platforms
function RiftObjects.createRepairPlatform(position)
    local faction = RiftObjects.getFaction()

    local desc = RiftObjects.makeRiftObjectDescriptor(position)
    desc.factionIndex = faction.index

    local plan = PlanGenerator.makeStationPlan(faction, styleName, nil, 1000)
    desc:setMovePlan(plan)

    local platform = Sector():createEntity(desc)
    platform:addScript("internal/dlc/rift/entity/riftobjects/repairplatform.lua")

    Durability(platform).maxDurabilityFactor = RiftObjects.setPlatformDurabilityFactor()

    return platform
end

function RiftObjects.createProtectionPlatform(position)
    local faction = RiftObjects.getFaction()

    local desc = RiftObjects.makeRiftObjectDescriptor(position)
    desc.factionIndex = faction.index

    local plan = PlanGenerator.makeStationPlan(faction, styleName, nil, 1000)
    desc:setMovePlan(plan)

    local platform = Sector():createEntity(desc)
    platform:addScript("internal/dlc/rift/entity/riftobjects/protectionplatform.lua")

    Durability(platform).maxDurabilityFactor = RiftObjects.setPlatformDurabilityFactor()

    return platform
end

function RiftObjects.createAttackPlatform(position)
    local faction = RiftObjects.getFaction()

    local desc = RiftObjects.makeRiftObjectDescriptor(position)
    desc.factionIndex = faction.index
    local plan = PlanGenerator.makeStationPlan(faction, styleName, nil, 1000)
    desc:setMovePlan(plan)

    local sector = Sector()
    local platform = sector:createEntity(desc)
    platform:addScript("internal/dlc/rift/entity/riftobjects/attackplatform.lua")

    -- add turrets
    local x, y = sector:getCoordinates()
    local generator = SectorTurretGenerator()
    local railgunTurret = generator:generate(x, y, nil, nil, WeaponType.RailGun)
    local bolterTurret = generator:generate(x, y, nil, nil, WeaponType.Bolter)
    local plasmaTurret = generator:generate(x, y, nil, nil, WeaponType.PlasmaGun)

    local numTurrets = math.max(1, Balancing_GetEnemySectorTurrets(x, y) / 2)

    for _, turret in pairs({railgunTurret, plasmaTurret, bolterTurret}) do
        turret:setRange(1500)
        turret.turningSpeed = 2
        turret.coaxial = false
        turret.size = 0.5

        -- no recoil
        local weapons = {turret:getWeapons()}
        turret:clearWeapons()
        for _, weapon in pairs(weapons) do
            weapon.recoil = 0
            turret:addWeapon(weapon)
        end

        ShipUtility.addTurretsToCraft(platform, turret, numTurrets, numTurrets)
    end

    platform.damageMultiplier = platform.damageMultiplier * 2 * (sector:getValue("xsotan_damage") or 1)

    return platform
end

-- landmarks
function RiftObjects.createLandmark(position)
    local objects = {}
    table.insert(objects, function(position) return RiftObjects.createLandmarkAsteroid(position) end)
    table.insert(objects, function(position) return RiftObjects.createLandmarkMonolith(position) end)
    table.insert(objects, function(position) return RiftObjects.createLandmarkCuboid(position) end)
    table.insert(objects, function(position) return RiftObjects.createLandmarkIcicle(position) end)
    table.insert(objects, function(position) return RiftObjects.createLandmarkMolten(position) end)

    local generationFunction = randomEntry(objects)
    local landmark = generationFunction(position)
    landmark:setValue("riftsector_landmark", true)
    landmark:setValue("untransferrable", true)
    landmark:setValue("valuable_object", RarityType.Common)

    return landmark
end

function RiftObjects.makeLandmarkAsteroidDescriptor(plan, position)
    local desc = AsteroidDescriptor()
    desc:removeComponent(ComponentType.MineableMaterial)
    desc:addComponent(ComponentType.Title)
    desc:setMovePlan(plan)
    desc.position = position
    desc.title = "Monolith"%_T

    return desc
end

function RiftObjects.createLandmarkAsteroid(position)
    local generator = AsteroidPlanGenerator()
    generator:setToRiftStone()
    local plan = generator:makeBigAsteroidPlan(getFloat(250, 300), false, Material(MaterialType.Titanium))

    local desc = RiftObjects.makeLandmarkAsteroidDescriptor(plan, position)
    local asteroid = Sector():createEntity(desc)

    return asteroid
end

function RiftObjects.createLandmarkMonolith(position)
    local generator = AsteroidPlanGenerator()
    generator:setToRiftStone()

    local plan = generator:makeMonolithAsteroidPlan(10, Material(MaterialType.Titanium))
    plan:scale(vec3(15))
    plan.accumulatingHealth = false

    local desc = RiftObjects.makeLandmarkAsteroidDescriptor(plan, position)
    local asteroid = Sector():createEntity(desc)

    return asteroid
end

function RiftObjects.createLandmarkCuboid(position)

    local generator = AsteroidPlanGenerator()
    generator:setToRiftStone()

    local plan = generator:makeCuboidAsteroidPlan(10, Material(MaterialType.Titanium))
    plan:scale(vec3(8))
    plan.accumulatingHealth = false

    local desc = RiftObjects.makeLandmarkAsteroidDescriptor(plan, position)
    local asteroid = Sector():createEntity(desc)

    return asteroid
end

function RiftObjects.createLandmarkIcicle(position)
    local plan = LoadPlanFromFile("data/plans/landmark-icicle.xml")
    plan:center()
    plan:scale(vec3(2))
    plan.accumulatingHealth = false

    local desc = RiftObjects.makeLandmarkAsteroidDescriptor(plan, position)
    local asteroid = Sector():createEntity(desc)

    return asteroid
end

function RiftObjects.createLandmarkMolten(position)
    local plans =
    {
        "data/plans/landmark-molten-type1.xml",
        "data/plans/landmark-molten-type2.xml",
        "data/plans/landmark-molten-type3.xml",
    }

    local plan = LoadPlanFromFile(randomEntry(random(), plans))
    plan:center()
    plan:scale(vec3(2.5))
    plan.accumulatingHealth = false

    local desc = RiftObjects.makeLandmarkAsteroidDescriptor(plan, position)
    local asteroid = Sector():createEntity(desc)

    return asteroid
end

-- buoy
function RiftObjects.createBuoy(position, offset, pathIndex, startBuoy)
    local x, y = Sector():getCoordinates()

    local desc = EntityDescriptor()
    desc:addComponents(
       ComponentType.Plan,
       ComponentType.BspTree,
       ComponentType.Intersection,
       ComponentType.Asleep,
       ComponentType.DamageContributors,
       ComponentType.BoundingSphere,
       ComponentType.BoundingBox,
       ComponentType.Velocity,
       ComponentType.Physics,
       ComponentType.Scripts,
       ComponentType.ScriptCallback,
       ComponentType.Title
       )
    desc.position = position

    local plan = PlanGenerator.makeBeaconPlan()
    desc:setMovePlan(plan)
    desc:addScript("internal/dlc/rift/entity/riftobjects/buoy.lua")
    desc:setValue("untransferrable", true)
    desc:setValue("buoy_offset", offset)
    desc:setValue("buoy_path", pathIndex)
    desc:setValue("buoy_start", startBuoy)
    desc.title = "Buoy"%_T

    local physics = desc:getComponent(ComponentType.Physics)
    physics.driftDecrease = 0.2

    return Sector():createEntity(desc)
end

-- small treasures
function RiftObjects.createSmallRiftTreasure(position)
    local objects = {}
    table.insert(objects, function(position) return RiftObjects.createStash(position) end)
    table.insert(objects, function(position) return RiftObjects.createCargoStash(position) end)
    table.insert(objects, function(position) return RiftObjects.createSmallScannableObject(position) end)
    table.insert(objects, function(position) return RiftObjects.createRadiatingWreckage(position, 0.6, random():getInt(5, 7)) end)
    table.insert(objects, function(position) return RiftObjects.createValuablesDetectorBeacon(position) end)
    table.insert(objects, function(position) return RiftObjects.createXsotanLoreObject(position) end)

    local generationFunction = randomEntry(objects)
    return generationFunction(position)
end

function RiftObjects.createStash(position)
    local x, y = Sector():getCoordinates()
    local sectorGenerator = SectorGenerator(x, y)
    local stash = sectorGenerator:createStash(position)
    stash:setValue("untransferrable", true)
    stash:setValue("small_treasure", true)

    return stash
end

function RiftObjects.createCargoStash(position)
    local x, y = Sector():getCoordinates()
    local sectorGenerator = SectorGenerator(x, y)
    local stash = sectorGenerator:createStash(position)
    stash:removeScript("stash.lua")
    stash:addScript("cargostash.lua")
    stash:setValue("untransferrable", true)
    stash:setValue("small_treasure", true)

    return stash
end

function RiftObjects.createSmallScannableObject(position, numDroppedData)
    local x, y = Sector():getCoordinates()

    local generationFunctions = {
        function() return PlanGenerator.makeContainerPlan() end,
        function() return PlanGenerator.makeBeaconPlan() end,
        function() return AsteroidPlanGenerator():makeCuboidAsteroidPlan(5) end,
        function() return AsteroidPlanGenerator():makeMonolithAsteroidPlan(5) end,
    }
    local plan = randomEntry(generationFunctions)()

    local desc = RiftObjects.makeSimpleRiftObjectDescriptor(position)
    desc:setMovePlan(plan)

    local object = Sector():createEntity(desc)
    object:addScript("internal/dlc/rift/entity/riftobjects/scannableobject.lua", numDroppedData or 3)
    object.title = "Mysterious Object"%_T

    object:setValue("small_treasure", true)

    return object
end

function RiftObjects.createRadiatingWreckage(position, size, amountAsteroids)
    size = size or 1

    local x, y = Sector():getCoordinates()
    local sectorGenerator = SectorGenerator(x, y)

    -- create wreckage
    local faction = Galaxy():getNearestFaction(x, y)
    local probabilities = Balancing_GetMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))
    local volume = Balancing_GetSectorShipVolume(x, y) * size

    local shipPlan = PlanGenerator.makeShipPlan(faction, volume, nil, material)
    shipPlan:scale(vec3(size))

    local wreckage = sectorGenerator:createUnstrippedWreckage(faction, shipPlan, 0, position)

    local random = random()

    -- make wreckage claimable
    if random:getFloat(0.0, 1.0) < 0.2 then
        -- find largest wreckage
        NamePool.setWreckageName(wreckage)
        wreckage.title = "Abandoned Ship"%_t
        wreckage:addScript("wreckagetoship.lua")
    end

    -- spawn radiating asteroids
    for i = 1, amountAsteroids or 3 do
        asteroidPosition = MatrixLookUpPosition(position.right, position.up, position.translation + random:getDirection() * size * 100)
        RiftObjects.createRadiatingAsteroid(asteroidPosition, random:getInt(2, 4))
    end

    if size < 1 then
        wreckage:setValue("small_treasure", true)
    else
        wreckage:setValue("medium_treasure", true)
    end

    return wreckage
end

function RiftObjects.createValuablesDetectorBeacon(position)
    local x, y = Sector():getCoordinates()
    local plan = PlanGenerator.makeBeaconPlan()

    local desc = RiftObjects.makeSimpleRiftObjectDescriptor(position)
    desc:setMovePlan(plan)

    local object = Sector():createEntity(desc)
    object:addScript("internal/dlc/rift/entity/riftobjects/valuablesdetectorbeacon.lua")
    object:setValue("highlight_color", "fd5")
    object:setValue("valuable_object", RarityType.Rare)
    object:setValue("small_treasure", true)

    return object
end

function RiftObjects.createXsotanLoreObject(position)
    local droppedData = 1
    local object = RiftObjects.createSmallScannableObject(position, droppedData)

    object:addScriptOnce("internal/dlc/rift/entity/riftobjects/xsotanloreobject.lua")
    object:setValue("highlight_color", Rarity(RarityType.Rare).color.html)
    object:setValue("small_treasure", true)

    return object
end

-- medium treasures
function RiftObjects.createMediumRiftTreasure(position)
    local objects = {}
    table.insert(objects, function(position) return RiftObjects.createBigAsteroid(position) end)
    table.insert(objects, function(position) return RiftObjects.createClaimableWreckage(position) end)
    table.insert(objects, function(position) return RiftObjects.createStationWreckage(position, 1.0) end)
    table.insert(objects, function(position) return RiftObjects.createBigScannableObject(position, 8) end)
    table.insert(objects, function(position) return RiftObjects.createRadiatingWreckage(position, 1, random():getInt(8, 10)) end)
    table.insert(objects, function(position) return RiftObjects.createBatteryStash(position) end)

    local generationFunction = randomEntry(objects)
    local treasure = generationFunction(position)
    treasure:setValue("untransferrable", true)

    return treasure
end

function RiftObjects.createBatteryStash(position)
    local x, y = Sector():getCoordinates()
    local sectorGenerator = SectorGenerator(x, y)

    local desc = RiftObjects.makeSimpleRiftObjectDescriptor(position)
    desc:addComponents(ComponentType.DockingClamps)

    local physics = desc:getComponent(ComponentType.Physics)
    physics.driftDecrease = 0.1

    local plan = PlanGenerator.makeContainerPlan()
    plan:scale(vec3(1.5))

    -- add a dock block
    local rootBox = plan.root.box
    local dockPosition = rootBox.position
    local matrix = MatrixLookUp(vec3(0, 1, 0), vec3(1, 0, 0))
    local height = math.max(8, plan:getBoundingBox().size.y + 1)
    plan:addBlock(dockPosition, vec3(2, height, 2), plan.rootIndex, -1, ColorRGB(1, 1, 1), Material(MaterialType.Titanium), matrix, BlockType.Dock, ColorNone())

    desc:setMovePlan(plan)
    local planComponent = desc:getComponent(ComponentType.Plan)
    planComponent.singleBlockDestructionEnabled = false

    local stash = Sector():createEntity(desc)
    stash:addScriptOnce("internal/dlc/rift/entity/riftobjects/batterystash.lua")
    stash.title = "Locked Stash"%_T
    stash:setValue("valuable_object", RarityType.Exceptional)
    stash:setValue("untransferrable", true)
    stash:setValue("medium_treasure", true)

    local location = position.translation + random():getDirection() * random():getFloat(800, 1200)
    local matrix = MatrixLookUpPosition(random():getDirection(), random():getDirection(), location)
    local battery1 = RiftObjects.createBattery(matrix)
    battery1.invincible = true

    local location = position.translation + random():getDirection() * random():getFloat(800, 1200)
    local matrix = MatrixLookUpPosition(random():getDirection(), random():getDirection(), location)
    local battery2 = RiftObjects.createBattery(matrix)
    battery2.invincible = true

    return stash, battery1, battery2
end

function RiftObjects.createBigAsteroid(position)
    local x, y = Sector():getCoordinates()
    local sectorGenerator = SectorGenerator(x, y)
    local object = sectorGenerator:createBigAsteroidEx(position, getFloat(60, 80), true)
    object:setValue("medium_treasure", true)

    return object
end

function RiftObjects.createRadiatingAsteroid(position, size, isScannable)
    size = size or 5
    isScannable = isScannable or random():test(0.2)

    local x, y = Sector():getCoordinates()
    local sectorGenerator = SectorGenerator(x, y)

    -- set up asteroid plan generator
    local generator = AsteroidPlanGenerator()

    generator.Stone = BlockType.GlowStone
    generator.StoneEdge = BlockType.GlowStoneEdge
    generator.StoneCorner = BlockType.GlowStoneCorner
    generator.StoneOuterCorner = BlockType.GlowStoneOuterCorner
    generator.StoneInnerCorner = BlockType.GlowStoneInnerCorner
    generator.StoneTwistedCorner1 = BlockType.GlowStoneTwistedCorner1
    generator.StoneTwistedCorner2 = BlockType.GlowStoneTwistedCorner2
    generator.StoneFlatCorner = BlockType.GlowStoneFlatCorner

    -- create plan
    local material = Material(MaterialType.Titanium)
    local generationFunctions = {
        function() return generator:makeTitaniumAsteroidPlan(size, material, {}) end,
        function() return generator:makeTriniumAsteroidPlan(size, material, {}) end,
        function() return generator:makeXanionAsteroidPlan(size, material, {}) end,
        function() return generator:makeOgoniteAsteroidPlan(size, material, {}) end,
        function() return generator:makeAvorionAsteroidPlan(size, material, {}) end,
    }

    if isScannable then
        generationFunctions = {
            function() return generator:makeCuboidAsteroidPlan(size, material) end,
            function() return generator:makeMonolithAsteroidPlan(size, material) end,
        }
    end

    local plan = randomEntry(generationFunctions)()

    if isScannable then
        plan:setColor(ColorRGB(0.2, 0.5, 0.1))
    else
        plan:setColor(ColorRGB(0.45, 0.35, 0.075))
    end

    -- create descriptor
    local desc = RiftObjects.makeSimpleRiftObjectDescriptor(position)
    desc.type = EntityType.Asteroid
    desc:addComponent(ComponentType.Durability)
    desc:addComponent(ComponentType.PlanMaxDurability)

    desc:setMovePlan(plan)
    desc.title = "Radiating Asteroid"%_T

    -- create entity
    local entity = Sector():createEntity(desc)
    entity:addScript("internal/dlc/rift/entity/riftobjects/radiatingasteroid.lua", isScannable)

    return asteroid
end

function RiftObjects.createClaimableWreckage(position)
    local x, y = Sector():getCoordinates()
    local sectorGenerator = SectorGenerator(x, y)

    local faction = Galaxy():getNearestFaction(x, y)
    local wreckage = sectorGenerator:createWreckage(faction, nil, 0, position)

    -- find largest wreckage
    NamePool.setWreckageName(wreckage)
    wreckage.title = "Abandoned Ship"%_t
    wreckage:addScript("wreckagetoship.lua")
    wreckage:setValue("medium_treasure", true)

    return wreckage
end

function RiftObjects.createStationWreckage(position, unstrippedChance)
    local x, y = Sector():getCoordinates()
    local faction = Galaxy():getNearestFaction(x, y)

    local sectorGenerator = SectorGenerator(x, y)
    sectorGenerator.chanceForUnstrippedWreckage = (unstrippedChance or 0.5) * GameSettings().resourceWreckageFactor

    local stations = {}
    for name, value in pairs(StationSubType) do
        table.insert(stations, name)
    end

    local volume = Balancing_GetSectorStationVolume(0, 0) * 2.5
    local plan = PlanGenerator.makeStationPlan(faction, randomEntry(stations), nil, volume)

    local holoBlocks = {}
    for i = 0, plan.numBlocks - 1 do
        local block = plan:getNthBlock(i)

        if block.blockCategoryIndex == BlockType.Glow then
            plan:setBlockColor(block.index, ColorRGB(0.1, 0.1, 0.1))
        elseif block.blockCategoryIndex == BlockType.Holo then
            table.insert(holoBlocks, block.index)
        end
    end

    for _, index in pairs(holoBlocks) do
        plan:removeBlock(index)
    end

    local wreckage = sectorGenerator:createWreckage(faction, plan, 0, position)

    wreckage:setValue("medium_treasure", true)

    return wreckage
end

function RiftObjects.createBigScannableObject(position, numDroppedData)
    local x, y = Sector():getCoordinates()
    local sectorGenerator = SectorGenerator(x, y)

    local faction = Galaxy():getNearestFaction(x, y)
    local object = sectorGenerator:createWreckage(faction, nil, 0, position)
    object:addScript("internal/dlc/rift/entity/riftobjects/scannableobject.lua", numDroppedData or 8)

    -- override object detector value set by scannable to a higher rarity as this object is more valuable
    -- this object counts as 'rift treasure' for valuables detector
    object:setValue("valuable_object", RarityType.Exceptional)
    object.title = "Old Research Ship"%_T
    object:setValue("medium_treasure", true)

    return object
end

-- weapon chamber
function RiftObjects.createWeaponChamberSwitch(position)
    local x, y = Sector():getCoordinates()
    local faction = Galaxy():getNearestFaction(x, y)

    local desc = EntityDescriptor()
    desc:addComponents(
       ComponentType.Plan,
       ComponentType.BspTree,
       ComponentType.Intersection,
       ComponentType.Asleep,
       ComponentType.DamageContributors,
       ComponentType.BoundingSphere,
       ComponentType.BoundingBox,
       ComponentType.Velocity,
       ComponentType.Physics,
       ComponentType.Scripts,
       ComponentType.ScriptCallback,
       ComponentType.Title,
       ComponentType.DockingClamps,
       ComponentType.InteractionText
       )
    desc.position = position

    local plan = PlanGenerator.makeBeaconPlan()
    plan:scale(vec3(1.5))

    -- add a dock block
    local rootBox = plan.root.box
    local dockPosition = rootBox.position + vec3(0, rootBox.size.y * 0.5, 0) + vec3(0, 1, 0)
    local matrix = MatrixLookUp(vec3(0, 1, 0), vec3(1, 0, 0))
    plan:addBlock(dockPosition, vec3(2, 2, 2), plan.rootIndex, -1, ColorRGB(1, 1, 1), Material(MaterialType.Titanium), matrix, BlockType.Dock, ColorNone())

    desc:setMovePlan(plan)

    local planComponent = desc:getComponent(ComponentType.Plan)
    planComponent.singleBlockDestructionEnabled = false

    local physics = desc:getComponent(ComponentType.Physics)
    physics.driftDecrease = 0.1

    local switch = Sector():createEntity(desc)
    switch:addScript("internal/dlc/rift/entity/riftobjects/weaponchamberswitch.lua")
    switch.title = "Switch /* a physical switch */"%_T
    switch:setValue("valuable_object", RarityType.Exotic)
    switch:setValue("untransferrable", true)

    return switch
end

function RiftObjects.createBattery(position)
    local x, y = Sector():getCoordinates()
    local faction = Galaxy():getNearestFaction(x, y)

    local desc = EntityDescriptor()
    desc:addComponents(
       ComponentType.Plan,
       ComponentType.Durability,
       ComponentType.PlanMaxDurability,
       ComponentType.BspTree,
       ComponentType.Intersection,
       ComponentType.Asleep,
       ComponentType.DamageContributors,
       ComponentType.BoundingSphere,
       ComponentType.BoundingBox,
       ComponentType.Velocity,
       ComponentType.Physics,
       ComponentType.Scripts,
       ComponentType.ScriptCallback,
       ComponentType.Title
       )
    desc.position = position
    desc.title = "Battery"%_T
    desc:setValue("rift_battery", true)
    desc:setValue("valuable_object", RarityType.Rare)
    desc:setValue("untransferrable", true)

    local plan = LoadPlanFromFile("data/plans/battery.xml")
    plan:scale(vec3(0.75))
    desc:setMovePlan(plan)

    desc:addScript("internal/dlc/rift/entity/riftobjects/battery.lua")

    local physics = desc:getComponent(ComponentType.Physics)
    physics.driftDecrease = 0.175

    local battery = Sector():createEntity(desc)
    battery.invincible = true

    return battery
end

function RiftObjects.createWeaponChamber(position)
    local x, y = Sector():getCoordinates()
    local sectorGenerator = SectorGenerator(x, y)
    local plan = LoadPlanFromFile("data/plans/vault.xml")

    local container = sectorGenerator:createContainer(plan, position)
    container:addScript("internal/dlc/rift/entity/riftobjects/weaponchamber.lua")
    container.title = "Vault"%_T
    container:setValue("valuable_object", RarityType.Exotic)
    container:setValue("untransferrable", true)

    -- add rift decrease to make weapon chamber look really heavy
    Physics(container).driftDecrease = 0.2

    return container
end

function RiftObjects.createInactiveGate(position, targetX, targetY)
    local desc = EntityDescriptor()
    desc:addComponents(
       ComponentType.Plan,
       ComponentType.BspTree,
       ComponentType.Intersection,
       ComponentType.Asleep,
       ComponentType.DamageContributors,
       ComponentType.BoundingSphere,
       ComponentType.PlanMaxDurability,
       ComponentType.Durability,
       ComponentType.BoundingBox,
       ComponentType.Velocity,
       ComponentType.Physics,
       ComponentType.Scripts,
       ComponentType.ScriptCallback,
       ComponentType.Title,
       ComponentType.Owner,
       ComponentType.FactionNotifier,
       ComponentType.WormHole,
       ComponentType.EnergySystem,
       ComponentType.EntityTransferrer,
       ComponentType.InteractionText
       )
    desc.position = position
    desc:setValue("ai_no_attack", true)
    desc:addScript("internal/dlc/rift/entity/riftobjects/inactivegate.lua")

    local plan = PlanGenerator.makeGatePlan(random():createSeed(), ColorRGB(1, 1, 1), ColorRGB(0.5, 0.5, 0.5), ColorRGB(1.0, 0.25, 0.25))
    plan:scale(vec3(2))
    desc:setMovePlan(plan)

    local durability = desc:getComponent(ComponentType.Durability)
    durability.maxDurabilityFactor = 10

    local wormhole = desc:getComponent(ComponentType.WormHole)
    wormhole:setTargetCoordinates(targetX, targetY)
    wormhole.enabled = false
    wormhole.visible = false
    wormhole.visualSize = 50
    wormhole.passageSize = 50
    wormhole.oneWay = true

    desc.title = "Ancient Gate"%_T

    return Sector():createEntity(desc)
end

function RiftObjects.createInactiveGateActivator(position)
    local desc = RiftObjects.makeRiftObjectDescriptor(position)

    local plan = PlanGenerator.makeContainerPlan()
    plan:scale(vec3(2.0))

    -- add a dock block
    local rootBox = plan.root.box
    local dockPosition = rootBox.position + vec3(0, rootBox.size.y * 0.5, 0) + vec3(0, 1, 0)
    local matrix = MatrixLookUp(vec3(0, 1, 0), vec3(1, 0, 0))
    plan:addBlock(dockPosition, vec3(2, 20, 2), plan.rootIndex, -1, ColorRGB(1, 1, 1), Material(MaterialType.Titanium), matrix, BlockType.Dock, ColorNone())

    desc:setMovePlan(plan)
    local planComponent = desc:getComponent(ComponentType.Plan)
    planComponent.singleBlockDestructionEnabled = false

    desc:addScript("internal/dlc/rift/entity/riftobjects/inactivegateactivator.lua")
    desc.title = "Ancient Tech Activator"%_T
    desc:setValue("untransferrable", true)

    local activator = Sector():createEntity(desc)
    activator.invincible = true

    -- create two batteries upon spawning -> one extra in case player loses one
    for i = 1, 2 do
        local look = random():getDirection()
        local up = random():getDirection()
        local position = activator.translationf + random():getDirection() * random():getFloat(750, 1000)
        RiftObjects.createBattery(MatrixLookUpPosition(look, up, position))
    end

    return activator
end

function RiftObjects.createTeleportAnomalyPair(anomalyPosition1, anomalyPosition2)
    local anomaly1 = RiftObjects.createTeleportAnomaly(anomalyPosition1)
    local anomaly2 = RiftObjects.createTeleportAnomaly(anomalyPosition2)

    anomaly1:invokeFunction("teleportanomaly.lua", "setPartnerAnomaly", anomaly2.id)
    anomaly2:invokeFunction("teleportanomaly.lua", "setPartnerAnomaly", anomaly1.id)
end

function RiftObjects.createTeleportAnomaly(position)
    local desc = EntityDescriptor()
    desc.type = EntityType.Anomaly

    desc:addComponents(
       ComponentType.Scripts,
       ComponentType.ScriptCallback,
       ComponentType.Title,
       ComponentType.Position,
       ComponentType.EntityType
       )

    desc.position = position
    desc:setValue("inconspicuous_indicator", true)
    desc:setValue("untransferrable", true)

    desc.title = "Anomaly"%_T
    local anomaly = Sector():createEntity(desc)

    -- add script here, bc adding it in the descriptor means it'll have restoring flag set on first initialize
    anomaly:addScript("internal/dlc/rift/entity/riftobjects/teleportanomaly.lua")
    return anomaly
end

function RiftObjects.createShockwaveAnomaly(position, intensity)
    intensity = intensity or 1

    local desc = EntityDescriptor()
    desc.type = EntityType.Anomaly

    desc:addComponents(
       ComponentType.Scripts,
       ComponentType.ScriptCallback,
       ComponentType.Position,
       ComponentType.EntityType
       )

    desc.position = position
    desc:setValue("inconspicuous_indicator", true)
    desc:setValue("untransferrable", true)

    local anomaly = Sector():createEntity(desc)

    -- add script here, bc adding it in the descriptor means it'll have restoring flag set on first initialize
    anomaly:addScript("internal/dlc/rift/entity/riftobjects/shockwaveanomaly.lua", intensity)
    return anomaly
end

function RiftObjects.createGravityAnomaly(position, intensity)
    intensity = intensity or 1

    local desc = EntityDescriptor()
    desc.type = EntityType.Anomaly

    desc:addComponents(
        ComponentType.Scripts,
        ComponentType.ScriptCallback,
        ComponentType.Intersection
        )

    desc.position = position
    desc:setValue("inconspicuous_indicator", true)
    desc:setValue("untransferrable", true)

    local anomaly = Sector():createEntity(desc)
    anomaly:addScript("internal/dlc/rift/entity/riftobjects/gravityanomaly.lua", intensity)
    return anomaly
end

function RiftObjects.createStoryResetBeacon(position)
    local desc = RiftObjects.makeSimpleRiftObjectDescriptor(position)
    desc:addComponent(ComponentType.EnergySystem) -- needed to have light blocks work

    local plan = LoadPlanFromFile("data/plans/itr-story-reset-beacon.xml")
    desc:setMovePlan(plan)
    desc:setValue("itr_story_reset_beacon", true)

    desc:setTitle("Time Device /* title of an object that can reset player story progress */"%_T, {})

    local beacon = Sector():createEntity(desc)
    beacon:addScript("internal/dlc/rift/entity/riftobjects/itrstoryresetbeacon.lua")

    return beacon
end

function RiftObjects.setPlatformDurabilityFactor()
    -- scale durability of platforms according to sector damage factor to keep destruction time approx. the same
    local x, y = Sector():getCoordinates()
    -- damage of enemies in the sector
    local sectorEnemyDamage = Balancing_GetSectorWeaponDPS(x, y) * Balancing_GetEnemySectorTurretsUnrounded(x, y)
    -- damage of enemies at distance 450
    local baseEnemyDamage = Balancing_GetSectorWeaponDPS(450, 0) * Balancing_GetEnemySectorTurretsUnrounded(450, 0)

    -- sector damage factor in relation to damage at distance 450
    local factor = sectorEnemyDamage / baseEnemyDamage
    -- factor shouldn't be less then 1
    factor = math.max(1, factor)

    -- we want the durability at 450 doubled
    factor = factor + 1

    return factor
end

return RiftObjects
