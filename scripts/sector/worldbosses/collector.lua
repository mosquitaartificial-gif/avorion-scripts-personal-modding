package.path = package.path .. ";data/scripts/lib/?.lua"

include ("galaxy")
local WorldBossUT = include("worldbossutility")
local SectorTurretGenerator = include ("sectorturretgenerator")
local LegendaryTurretGenerator = include ("internal/common/lib/legendaryturretgenerator.lua")
local AsteroidFieldGenerator = include ("asteroidfieldgenerator")
local PlanGenerator = include ("plangenerator")
local SectorGenerator = include ("SectorGenerator")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace CollectorArena
CollectorArena = {}

function CollectorArena.initialize()
    if onClient() then return end

    CollectorArena.trySpawnBoss()

    local sector = Sector()
    sector:registerCallback("onPlayerEntered", "onPlayerEntered")
    sector:registerCallback("showWorldBossStartFightChatter", "showWorldBossStartFightChatter")
end

function CollectorArena.onPlayerEntered(playerIndex)
    CollectorArena.trySpawnBoss()
end

function CollectorArena.showWorldBossStartFightChatter()
    local sector = Sector()
    local boss = sector:getEntitiesByScript("worldboss.lua")
    if not boss then return end

    sector:broadcastChatMessage(boss, ChatMessageType.Chatter, "Stop! I want to take a closer look at your ship! In all ... parts."%_t)
end

function CollectorArena.trySpawnBoss()
    local sector = Sector()
    if WorldBossUT.canSpawn(sector:getValue("worldboss_defeated")) then
        local factionName = "Collectors"%_T
        local faction = WorldBossUT.getFaction(factionName)

        local bossTitle = "The Collector"%_t
        local bossChatterLines = CollectorArena.getBossChatter()
        local bossData = {title = bossTitle, chatterLines = bossChatterLines, volumeFactor = 15}

        local beaconTitle = "Wanted Poster"%_t
        local text = "WANTED!\n- For multiple robberies of ships -"%_t
        local beacon = {title = beaconTitle, interactionText = text}

        local x, y = sector:getCoordinates()

        local generator = LegendaryTurretGenerator()
        local specialLoot = InventoryTurret(generator:generateLauncherBattery(x, y, 0))

        local turretData = CollectorArena.getTurretData()

        local boss = WorldBossUT.generateBoss(faction, bossData, beacon, specialLoot, turretData)

        local x, y = Sector():getCoordinates()

        CollectorArena.generateArena(x, y, boss.translationf)
        WorldBossUT.generateBossMinions(3, boss, 1)
    end
end

function CollectorArena.getTurretData()
    local x, y = Sector():getCoordinates()

    -- generate weapons: a good mix of every damage type
    local turrets = {}
    local numTurrets = Balancing_GetEnemySectorTurrets(x, y) * 1.5
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false

    local turret = generator:generate(x, y, 0, Rarity(RarityType.Rare), WeaponType.RailGun)
    turret.turningSpeed = 6
    turrets[turret] = math.floor(numTurrets / 3)

    local turret = generator:generate(x, y, 0, Rarity(RarityType.Rare), WeaponType.PlasmaGun)
    turret.turningSpeed = 6
    turrets[turret] = math.floor(numTurrets * (2 / 3)) -- two thirds of the weapons are plasmaguns

    return {numTurrets = numTurrets, turrets = turrets}
end

function CollectorArena.generateArena(x, y, center)
    local sector = Sector()

    if #{sector:getEntitiesByType(EntityType.Asteroid)} < 25 then
        local asteroidFieldGenerator = AsteroidFieldGenerator()
        local ringRotation = rotate(Matrix(), random():getFloat(0, math.pi), random():getDirection())
        local ringRotation2 = rotate(Matrix(), random():getFloat(0, math.pi), random():getDirection())

        -- create multiple rings out of asteroids
        local asteroidRings = {
            {numPoints = 50, radius = 1500, center = position, rotation = ringRotation2},
            {numPoints = 50, radius = 2000, center = position, rotation = ringRotation},
            {numPoints = 50, radius = 3500, center = position, rotation = ringRotation2},
        }

        for _, entry in pairs(asteroidRings) do
            local points = asteroidFieldGenerator:generateRing(entry.numPoints, entry.radius, entry.center, entry.rotation)
            asteroidFieldGenerator.asteroidPositions = points

            for _, location in pairs(points) do
                local size = random():getInt(30, 50)
                local plan = PlanGenerator.makeSmallAsteroidPlan(size, false)
                local bbsize = plan:getBoundingBox().size
                plan:scale(vec3((size * random():getFloat(1.5, 2)) / bbsize.x, (size * random():getFloat(1.5, 2)) / bbsize.y, size * 0.5 / bbsize.z))

                local position = MatrixLookUpPosition(center-location, vec3(0, 1, 0), location)
                sector:createAsteroid(plan, resources, position)
            end
        end

        -- create some wreckage rings to make arena look much more menacing
        local wreckageRings = {
            {numPoints = 35, radius = 1000, center = position, rotation = ringRotation},
            {numPoints = 35, radius = 2500, center = position, rotation = ringRotation2},
            {numPoints = 50, radius = 3000, center = position, rotation = ringRotation},
        }

        -- get nearby factions so that wreckages have differing styles
        -- use only existing factions
        local galaxy = Galaxy()
        local mapFactions = galaxy:getMapHomeSectors(x, y, 100)
        local factionCandidates = {}
        for index, _ in pairs(mapFactions) do
            local faction = galaxy:findFaction(index)
            if faction then
                table.insert(factionCandidates, faction)
            end
        end

        -- use all kinds of plan generation functions to have more different ships
        local planFunctions = {}
        table.insert(planFunctions, function(faction, volume) return PlanGenerator.makeShipPlan(faction, volume) end)
        table.insert(planFunctions, function(faction, volume) return PlanGenerator.makeFreighterPlan(faction, volume) end)
        table.insert(planFunctions, function(faction, volume) return PlanGenerator.makeMinerPlan(faction, volume) end)
        table.insert(planFunctions, function(faction, volume) return PlanGenerator.makeCarrierPlan(faction, volume) end)

        local sectorGenerator = SectorGenerator(x, y)
        local scaleFactor = 5

        for _, entry in pairs(wreckageRings) do
            local points = asteroidFieldGenerator:generateRing(entry.numPoints, entry.radius, entry.center, entry.rotation)

            for _, location in pairs(points) do
                local faction = randomEntry(factionCandidates)
                local generationFunction = randomEntry(planFunctions)
                local position = MatrixLookUpPosition(center - location, vec3(0, 1, 0), location)

                if random():test(0.25) then
                    local plan = generationFunction(faction)
                    sector:createWreckage(plan, position)
                else
                    local plan = PlanGenerator.makeContainerPlan()
                    plan:scale(vec3(scaleFactor))
                    sectorGenerator:createContainer(plan, position)
                end

            end
        end
    end
end

function CollectorArena.getBeaconDialog()
    local dialog = {}
    local dialog2 = {}

    dialog.text = "\"A former Xsotan Hunter is being sought to destroy and cannibalize ships.\nExtreme caution is advised! Attacks occur without warning!\""%_t .. "\n\n" ..
    "\"Clues leading to the capture of the captain will be rewarded at an appropriate rate.\nIt is strongly discouraged to act independently!\""%_t
    dialog.answers = {{answer = "[Attached Notes]"%_t, followUp = dialog2}}

    dialog2.talker = "Attached Notes"%_t
    dialog2.text = "Look at how famous we are! They fear us!"%_t .. "\n\n" .. "You are all a part of this crew! Together we will capture the rarest systems and components!"%_t

    return dialog
end

function CollectorArena.getBossChatter()
    local chatterLines =
    {
        "Such a component is still missing in my collection!"%_t,
        "I'll get you! It's easier for all of us if you don't fight back."%_t,
        "No, no, no, if you fight back, you'll end up breaking something important!"%_t,
        "You think you have a chance? Guess again!"%_t,
        "I have caught bigger and stronger ships. Stop fighting back!"%_t
    }

    return chatterLines
end
