package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
include ("randomext")
include ("utility")
include ("callable")
local LaserBossLocation = include ("story/laserbosslocation")
local AsteroidFieldGenerator = include("asteroidfieldgenerator")
local Placer = include("placer")
local SectorGenerator = include ("SectorGenerator")
local SectorTurretGenerator = include ("sectorturretgenerator")
local PlanGenerator = include ("plangenerator")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace LaserBoss
LaserBoss = {}

local data = {}
data.xCoord = 0
data.yCoord = 0
data.foundX = false
data.foundBoth = false
data.countTries = 0

local rand = Random(Seed(134))

function LaserBoss.sync(data_in)
    if onServer() then
        invokeClientFunction(Player(), "sync", data)
    else
        if data_in then
            data = data_in
        else
            invokeServerFunction("sync")
        end
    end
end
callable(LaserBoss, "sync")

function LaserBoss.initialize()
    if onServer() then
        Player():registerCallback("onSectorEntered", "onSectorEntered")
    else
        -- to be able to mark sector
        Player():registerCallback("onMapRenderAfterUI", "onMapRenderAfterUI")
        LaserBoss.sync()
    end
end

if onClient() then

function LaserBoss.onMapRenderAfterUI()
    LaserBoss.renderIcons()
end

function LaserBoss.renderIcons()
    if not data.foundBoth then return end

    local map = GalaxyMap()
    local renderer = UIRenderer()
    local icon = "data/textures/icons/pixel/skull_big.png"

    local sx, sy = map:getCoordinatesScreenPosition(ivec2(data.xCoord, data.yCoord))
    renderer:renderCenteredPixelIcon(vec2(sx, sy), ColorRGB(1, 0.1, 0), icon)

    renderer:display()
end
end

if onServer() then

function LaserBoss.getHint()
    if data.countTries >= 4 then
        data.countTries = 0
        LaserBoss.setHintCoordinate()
    else
        local test = rand:test(0.1)
        if test == false then
            data.countTries = data.countTries + 1
        else
            LaserBoss.setHintCoordinate()
        end
    end
end


function LaserBoss.setHintCoordinate()
    if not data.foundX then
        data.xCoord = LaserBossLocation.getCoordinate("x")
        data.foundX = true
        LaserBoss.sync()
        Player():sendChatMessage("General Bliks"%_T, ChatMessageType.Information, "We found a weird shard. It that seems there is another part missing. We'll wait for more information."%_T)
    else
        data.yCoord = LaserBossLocation.getCoordinate("y")
        Player():sendChatMessage("General Bliks"%_T, ChatMessageType.Information, "Another part of this weird shard. Together they show coordinates. The coordinates are \\s(%1%:%2%)."%_T, data.xCoord, data.yCoord)
        data.foundBoth = true
        LaserBoss.sync()
    end
end


function LaserBoss.onSectorEntered(player, x, y, changeType)
    if onServer() then
        local targetX, targetY = LaserBossLocation.getSector()
        if x == targetX and y == targetY then
            -- check if boss was recently defeated
            local server = Server()
            local lastKilledLaserBoss = server:getValue("last_killed_laser_boss")
            if not lastKilledLaserBoss or server.unpausedRuntime - lastKilledLaserBoss >= 60 * 60 then
                data.foundBoth = false
                data.foundX = false
                LaserBoss.spawnBoss()
            else
                Player():sendChatMessage("Server", ChatMessageType.Information, "There are remnants of a battle. But nobody's here right now."%_t)
            end
        end
    end
end

function LaserBoss.spawnBoss()
    -- no double spawning
    if Sector():getEntitiesByScript("data/scripts/entity/story/laserbossbehavior.lua") then return end

    LaserBoss.clearSector()
    LaserBoss.spawnLaserBoss()
    LaserBoss.spawnArena()
end

function LaserBoss.clearSector()
    local sector = Sector()

    for _, asteroid in pairs({Sector():getEntitiesByType(EntityType.Asteroid)}) do
        sector:deleteEntity(asteroid)
    end
end

function LaserBoss.spawnLaserBoss()
    -- no double spawning
    if Sector():getEntitiesByScript("data/scripts/entity/story/laserbossbehavior.lua") then return end

    local faction = LaserBoss.getFaction()
    local volume = Balancing_GetSectorShipVolume(Sector():getCoordinates()) * 30

    local plan = LoadPlanFromFile("data/plans/laserboss.xml")
    plan.accumulatingHealth = false

    local pos = random():getVector(-1000, 1000)
    pos = MatrixLookUpPosition(-pos, vec3(0, 1, 0), pos)

    local boss = Sector():createShip(faction, "", plan, pos)
    boss.shieldDurability = boss.shieldMaxDurability
    boss.title = "Project IHDTX"%_T
    boss.name = ""
    boss.crew = boss.idealCrew

    -- increase turning speed independent of plan
    local thrusters = Thrusters(boss.id)
    thrusters.baseYaw = thrusters.baseYaw * ((GameSettings().difficulty+3)/3) * 2
    thrusters.basePitch = thrusters.basePitch * ((GameSettings().difficulty+3)/3)
    thrusters.baseRoll = thrusters.baseRoll * ((GameSettings().difficulty+3)/3)
    thrusters.fixedStats = true

    -- boss is invincible until asteroids destroyed
    boss.invincible = true
    local shield = Shield(boss.id)
    shield.invincible = true

    boss:addScriptOnce("data/scripts/entity/story/laserbossbehavior.lua")
    LaserBoss.addTurrets(boss, 15)

    local generator = SectorTurretGenerator()
    Loot(boss.index):insert(SystemUpgradeTemplate("data/scripts/systems/shieldbooster.lua", Rarity(RarityType.Exotic), random():createSeed()))
    Loot(boss.index):insert(InventoryTurret(generator:generate(0, 5, 0, Rarity(RarityType.Exotic), WeaponType.Laser)))
    Loot(boss.index):insert(InventoryTurret(generator:generate(0, 5, 0, Rarity(RarityType.Legendary), WeaponType.Laser)))

    -- adds legendary turret drop
    boss:addScriptOnce("internal/common/entity/background/legendaryloot.lua")

    WreckageCreator(boss.index).active = false
    Boarding(boss).boardable = false
    boss.dockable = false
    boss:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")

    return boss
end

function LaserBoss.spawnArena()
    -- check on already spawned asteroids
    local sector = Sector()
    local laserasteroids = {sector:getEntitiesByScriptValue("laser_asteroid", true)}
    if laserasteroids and #laserasteroids >= 4 then
        for _, asteroid in pairs(laserasteroids) do
            asteroid:addScript("data/scripts/player/events/laserasteroid.lua")
        end

        return -- do nothing else
    end

    maxAsteroids = 4
    local dimChanges =
    {
        vec3(1500 + math.random(1, 1500), math.random(1, 10), math.random(1, 10)),
        vec3(-1500 - math.random(1, 1500), math.random(1, 10), math.random(1, 10)),
        vec3(math.random(1, 10), math.random(1, 10), 1500 + math.random(1, 1500)),
        vec3(math.random(1, 10), math.random(1, 10), -1500 - math.random(1, 1500)),
    }

    local sectorCoords = {}
    sectorCoords.x, sectorCoords.y = sector:getCoordinates()
    local generator = SectorGenerator(sectorCoords.x, sectorCoords.y)

    for i = 1, maxAsteroids do
        local matrix = Matrix()
        local translation = vec3(0 + (dimChanges[i].x), 0 + (dimChanges[i].y), 0 + (dimChanges[i].z))
        matrix.translation = translation
        local plan = PlanGenerator.makeBigAsteroidPlan(50, false, Material(MaterialType.Avorion))
        plan.accumulatingHealth = false

        plan:scale(vec3(3, 3, 3))
        local desc = AsteroidDescriptor()
        desc:removeComponent(ComponentType.MineableMaterial)
        desc:addComponents(
           ComponentType.Owner,
           ComponentType.FactionNotifier
           )

        desc.position = matrix
        desc:setMovePlan(plan)

        local asteroid = Sector():createEntity(desc)
        asteroid:setValue("laser_asteroid", true)
        asteroid:addScript("data/scripts/player/events/laserasteroid.lua")
        asteroid:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")

        local asteroidfieldgenerator = AsteroidFieldGenerator(sectorCoords.x, sectorCoords.y)

        -- spawns the "explosion shaped" asteroid balls around the shield asteroids
        ballAsteroidPosition = translation
        local asteroid = asteroidfieldgenerator:createBallAsteroidField(0.1, ballAsteroidPosition)
    end

    Placer.resolveIntersections()
end

function LaserBoss.getFaction()
    local name = "The Pariah"%_T
    local faction = Galaxy():findFaction(name)
    if faction == nil then
        faction = Galaxy():createFaction(name, 0, 0)
        faction.initialRelations = 0
        faction.initialRelationsToPlayer = 0
        faction.staticRelationsToPlayers = true
    end

    faction.initialRelationsToPlayer = 0
    faction.staticRelationsToPlayers = true
    faction.homeSectorUnknown = true

    return faction
end

function LaserBoss.addTurrets(boss, numTurrets)
    ShipUtility.addBossAntiTorpedoEquipment(boss, numTurrets)
end

function LaserBoss.secure()
    return data
end

function LaserBoss.restore(data_in)
    data = data_in
end

end


return LaserBoss
