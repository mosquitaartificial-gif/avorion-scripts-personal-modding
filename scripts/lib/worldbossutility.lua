package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
package.path = package.path .. ";data/scripts/systems/?.lua"

include ("randomext")
include ("galaxy")
include ("utility")
local ShipGenerator = include("shipgenerator")
local ShipUtility = include ("shiputility")
local SectorTurretGenerator = include ("sectorturretgenerator")
local UpgradeGenerator = include ("upgradegenerator")
local PlanGenerator = include ("plangenerator")
local SectorGenerator = include ("SectorGenerator")
local AsteroidFieldGenerator = include ("asteroidfieldgenerator")
local Placer = include("placer")

local WorldBossUtility = {}

WorldBossUtility.respawnTime = 60 * 60 -- 60 minutes
WorldBossUtility.fightTriggerDistance = 1000

function WorldBossUtility.getFaction(factionName)
    local faction = Galaxy():findFaction(factionName)

    if not faction then
        faction = Galaxy():createFaction(factionName, 175, 0)
        faction.initialRelationsToPlayer = 0
        faction.staticRelationsToPlayers = true
        faction.alwaysAtWar = true
    end

    faction.homeSectorUnknown = true

    return faction
end

function WorldBossUtility.canSpawn(bossDefeatedTime)
    if Sector():getEntitiesByScript("worldboss.lua") then return false end

    if bossDefeatedTime == nil then return true end

    local runtime = Server().unpausedRuntime
    if runtime - bossDefeatedTime > WorldBossUtility.respawnTime then
        return true
    end

    return false
end

function WorldBossUtility.generateBoss(faction, bossData, beacon, specialLoot, turretData)
    local sector = Sector()
    local x, y = sector:getCoordinates()

    local plan = bossData.plan
    if not plan then
        local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
        local material = Material(getValueFromDistribution(probabilities))
        plan = PlanGenerator.makeShipPlan(faction, WorldBossUtility.getBossVolume(bossData.volumeFactor), nil, material)
    end

    local position = bossData.position
    if not position then
        position = Matrix()
    end

    local ship = sector:createShip(faction, "", plan, position)
    ship.crew = ship.idealCrew
    ship.shieldDurability = ship.shieldMaxDurability

    ship.title = bossData.title

    local numTurrets = Balancing_GetEnemySectorTurrets(x, y) * 1.5
    local maxTurrets = 0
    if turretData and turretData.turrets then
        maxTurrets = maxTurrets + turretData.numTurrets
        for turret, num in pairs(turretData.turrets) do
            ShipUtility.addTurretsToCraft(ship, turret, num, maxTurrets)
        end
    else
        maxTurrets = maxTurrets + numTurrets
        -- add generic sector dependent turrets
        ShipUtility.addArmedTurretsToCraft(ship, maxTurrets)
    end

    if turretData and turretData.defenseTurrets then
        maxTurrets = turretData.numDefenseTurrets
        for turret, num in pairs(turretData.defenseTurrets) do
            ShipUtility.addTurretsToCraft(ship, turret, num, maxTurrets)
        end
    else
        -- add generic PDCs and Anti-Fighter
        local num = math.floor(numTurrets / 6)
        ShipUtility.addBossAntiTorpedoEquipment(ship, num)
        ShipUtility.addBossAntiFighterEquipment(ship, num)
    end

    -- this has to be set, as bosses have special turrets that must not be dropped
    ship:setDropsAttachedTurrets(false)

    WorldBossUtility.addBossLoot(ship, specialLoot)

    ship:addScriptOnce("data/scripts/entity/enemies/worldboss.lua", beacon, bossData.chatterLines)
    ship:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")

    ship.damageMultiplier = ship.damageMultiplier * 2 -- increase boss damage so that we have more action during fight

    return ship
end

function WorldBossUtility.generateBossMinions(amount, boss, volumeFactor)
    local faction = Faction(boss.factionIndex)
    local position = boss.position
    local volumeFactor = volumeFactor or 1

    for i = 1, amount do
        local volume = Balancing_GetSectorShipVolume(Sector():getCoordinates()) * random():getFloat(0.9, 1.1) * volumeFactor
        position.pos = position.pos + random():getDirection() * random():getInt(50, 200)
        local ship = ShipGenerator.createMilitaryShip(faction, position, volume)

        ship:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
        ship:removeScript("icon.lua")

        ship:setValue("world_boss_minion", true)
    end
end

function WorldBossUtility.getBossVolume(volumeFactor)
    local volumeFactor = volumeFactor or 20
    local volume = Balancing_GetSectorShipVolume(Sector():getCoordinates()) * random():getFloat(0.9, 1.1) * volumeFactor

    return volume
end

function WorldBossUtility.addBossLoot(craft, specialLoot)
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

    for i = 1, 6 do
        if random():test(0.5) then
            Loot(craft):insert(upgradeGenerator:generateSectorSystem(x, y, nil, upgradeRarities))
        else
            Loot(craft):insert(InventoryTurret(turretGenerator:generate(x, y)))
        end
    end

    Loot(craft):insert(specialLoot)
end

function WorldBossUtility.generateSystemUpgradeTemplate(x, y, script)
    local upgradeGenerator = UpgradeGenerator()
    local rarity = getValueFromDistribution(upgradeGenerator:getSectorBossLootRarityDistribution(x, y), random())
    local system = SystemUpgradeTemplate(script, Rarity(rarity), random():createSeed())
    return system
end

-- generate generic sector contents
function WorldBossUtility.generateBossArena(x, y, contents, bossPosition)
    local sector = Sector()
    local generator = SectorGenerator(x, y)
    local random = random()

    if contents then
        if contents.wreckages then
            if #{sector:getEntitiesByType(EntityType.Wreckage)} < 3 then
                for _, entry in pairs(contents.wreckages) do
                    local faction = Galaxy():getNearestFaction(x, y)
                    for i = 1, entry.amount do
                        local position = (bossPosition or vec3()) + random:getDirection() * random:getFloat(entry.minDist, entry.maxDist)
                        local matrix = MatrixLookUpPosition(random:getDirection(), random:getDirection(), position)

                        local plan = PlanGenerator.makeShipPlan(faction, Balancing_GetSectorShipVolume(x, y) * entry.size)
                        wreckify(plan)
                        local wreckage = generator:createWreckage(faction, plan, 0, matrix)
                        wreckage:removeScript("captainslogs.lua")
                    end
                end
            end
        end

        if contents.stationWreckages then
            for _, entry in pairs(contents.stationWreckages) do
                local faction = Galaxy():getNearestFaction(x, y);
                for i = 1, entry.amount do
                    local position = (bossPosition or vec3()) + random:getDirection() * random:getFloat(entry.minDist, entry.maxDist)
                    local matrix = MatrixLookUpPosition(random:getDirection(), random:getDirection(), position)

                    local stationStyle = nil
                    if entry.type then
                        stationStyle = PlanGenerator.determineStationStyleFromScriptArguments(entry.type)
                    end

                    local plan = PlanGenerator.makeStationPlan(faction, stationStyle, nil, Balancing_GetSectorStationVolume(x, y) * entry.size)
                    wreckify(plan)
                    local wreckage = generator:createUnstrippedWreckage(faction, plan, 0, matrix);
                    wreckage:addScript("deleteonplayersleft.lua")
                    wreckage:removeScript("captainslogs.lua")
                end
            end
        end

        if contents.containerFields then
            if #{sector:getEntitiesByType(EntityType.Container)} < 15 then
                for _, entry in pairs(contents.containerFields) do
                    local look = random:getDirection()
                    local up = random:getDirection()
                    for i = 1, entry.numFields do
                        local position = (bossPosition or vec3()) + random:getDirection() * random:getFloat(entry.minDist, entry.maxDist)
                        local matrix = MatrixLookUpPosition(look, up, position)
                        generator:createContainerField(nil, nil, entry.circular, matrix, nil, entry.hackables)
                    end
                end
            end
        end

        if contents.asteroids then
            if #{sector:getEntitiesByType(EntityType.Asteroid)} < 15 then
                for _, entry in pairs(contents.asteroids) do
                    if entry.type == "Organic" then
                        local asteroidFieldGenerator = AsteroidFieldGenerator()

                        for i = 1, entry.numFields do
                            local fieldPosition = (bossPosition or vec3()) + random:getDirection() * random:getInt(entry.minDist, entry.maxDist)
                            local points = asteroidFieldGenerator:generateOrganicCloud(entry.numPoints, fieldPosition, entry.size)
                            asteroidFieldGenerator.asteroidPositions = points
                            asteroidFieldGenerator:createAsteroidFieldEx(entry.numPoints, _, entry.asteroidSize - 15.0, entry.asteroidSize + 15.0, true, 0.01);
                        end
                    end

                    if entry.type == "Default" then
                        for i = 1, entry.numFields do
                            generator:createAsteroidField(0.075)
                        end
                    end

                    if entry.type == "Forest" then
                        local asteroidFieldGenerator = AsteroidFieldGenerator()
                        local position = (bossPosition or vec3()) + random:getDirection() * random:getFloat(500, 1000)
                        local matrix = Matrix()
                        matrix.position = position

                        for i = 1, entry.numFields do
                            asteroidFieldGenerator:createForestAsteroidField(0.075, matrix)
                        end
                    end

                    if entry.type == "Ring" then
                        local asteroidFieldGenerator = AsteroidFieldGenerator()

                        local points = asteroidFieldGenerator:generateRing(entry.numPoints, entry.radius, entry.center, entry.rotation)
                        asteroidFieldGenerator.asteroidPositions = points
                        asteroidFieldGenerator:createAsteroidFieldEx(entry.numPoints, _, entry.asteroidSize - 15.0, entry.asteroidSize + 15.0, true, entry.probability);
                    end
                end
            end
        end
    else
        -- create asteroid fields
        if #{sector:getEntitiesByType(EntityType.Asteroid)} < 15 then
            for i = 1, random:getInt(2, 4) do
                generator:createAsteroidField(0.075)
            end
        end
    end

    Placer.resolveIntersections()
end

function WorldBossUtility.playerApproached()
    local sector = Sector()

    local bossShips = {}
    table.insert(bossShips, sector:getEntitiesByScript("worldboss.lua"))
    for _, entity in pairs({sector:getEntitiesByScriptValue("world_boss_minion")}) do
        table.insert(bossShips, entity)
    end

    local playerShips = {}
    for _, player in pairs({sector:getPlayers()}) do
        table.insert(playerShips, player.craft)
    end

    for _, playerShip in pairs(playerShips) do
        for _, bossShip in pairs(bossShips) do
            if playerShip:getNearestDistance(bossShip) <= WorldBossUtility.fightTriggerDistance then
                return true
            end
        end
    end

    return false
end

return WorldBossUtility
