package.path = package.path .. ";data/scripts/lib/?.lua"

include ("galaxy")
local WorldBossUT = include("worldbossutility")
local LegendaryTurretGenerator = include ("internal/common/lib/legendaryturretgenerator.lua")
local SectorTurretGenerator = include ("sectorturretgenerator")
local SectorGenerator = include ("SectorGenerator")
local AsteroidFieldGenerator = include ("asteroidfieldgenerator")
local PlanGenerator = include ("plangenerator")
local Placer = include ("placer")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace ScrapBotArena
ScrapBotArena = {}

local lasers = {}

function ScrapBotArena.initialize()
    if onClient() then return end

    ScrapBotArena.trySpawnBoss()

    local sector = Sector()
    sector:registerCallback("onPlayerEntered", "onPlayerEntered")
    sector:registerCallback("showWorldBossStartFightChatter", "showWorldBossStartFightChatter")
end

function ScrapBotArena.onPlayerEntered(playerIndex)
    ScrapBotArena.trySpawnBoss()
end

function ScrapBotArena.showWorldBossStartFightChatter()
    local sector = Sector()
    local boss = sector:getEntitiesByScript("worldboss.lua")
    if not boss then return end

    sector:broadcastChatMessage(boss, ChatMessageType.Chatter, "High value target located. Starting salvage routine."%_t)
end

function ScrapBotArena.updateInterval()
    return 1
end

function ScrapBotArena.updateClient()
    if #lasers == 0 then
        local sector = Sector()
        local fencePosts = {sector:getEntitiesByScriptValue("scrapbot_fencePost")}
        for index = 1, 6, 2 do
            local nextIndex = index + 1
            if index == 6 then
                nextIndex = 1
            end

            local startPost, endPost
            for _, post in pairs(fencePosts) do
                if post:getValue("scrapbot_fencePost") == index then
                    startPost = post
                elseif post:getValue("scrapbot_fencePost") == nextIndex then
                    endPost = post
                end

                if startPost and endPost then break end
            end

            if not startPost or not endPost then goto continue end

            local laser = sector:createLaser(startPost.translationf, endPost.translationf, ColorRGB(0.1, 0.6, 0.9), 10.0)
            laser.collision = false
            laser.sound = ""
            laser.animationSpeed = 0
            laser.maxAliveTime = 2

            local laserData = {laser = laser, fromId = startPost.id, toId = endPost.id}
            table.insert(lasers, laserData)

            ::continue::
        end
    else
        -- update laser alive time and position
        for index, laserData in pairs(lasers) do
            if valid(laserData.laser) then
                laserData.laser.maxAliveTime = laserData.laser.aliveTime + 1

                local startPost = Entity(laserData.fromId)
                local endPost = Entity(laserData.toId)
                if not startPost or not endPost then
                    lasers[index] = nil
                    goto continue
                end

                laserData.laser.from = startPost.translationf
                laserData.laser.to = endPost.translationf
            end

            ::continue::
        end
    end
end

function ScrapBotArena.trySpawnBoss()
    local sector = Sector()
    if WorldBossUT.canSpawn(sector:getValue("worldboss_defeated")) then
        local factionName = "Scrap Bot"%_T
        local faction = WorldBossUT.getFaction(factionName)

        local bossTitle = "Scrapper 5000"%_T
        local bossChatterLines = ScrapBotArena.getBossChatter()
        local bossData = {title = bossTitle, chatterLines = bossChatterLines}

        local beaconTitle = "Advertisement"%_t
        local text = "Brochure to pass on to possible interested parties"%_t
        local beacon = {title = beaconTitle, interactionText = text}

        local x, y = sector:getCoordinates()
        local generator = LegendaryTurretGenerator()
        local specialLoot = InventoryTurret(generator:generateSuperSalvagingLaser(x, y, 0))

        local turretData = ScrapBotArena.getTurretData()

        local boss = WorldBossUT.generateBoss(faction, bossData, beacon, specialLoot, turretData)
        boss.name = "Jackpot the Scrap God"%_T

        ScrapBotArena.addCargo(boss.id)
        ScrapBotArena.generateArena(x, y, boss.translationf)
    end
end

function ScrapBotArena.addCargo(bossId)
    local boss = Entity(bossId)

    local goodList = {"Scrap Metal"}

    local probabilities = Balancing_GetTechnologyMaterialProbability(Sector():getCoordinates())
    for i, probability in pairs(probabilities) do
        if probability > 0 then
            table.insert(goodList, "Scrap "..tostring(Material(i).name))
        end
    end

    local usableCargoSpace = math.min(200, boss.freeCargoSpace)
    local compartmentSize = usableCargoSpace / #goodList

    for i, name in pairs(goodList) do
        local good = goods[name]:good()
        amount = math.floor(compartmentSize / good.size)
        boss:addCargo(good, amount)
    end
end

function ScrapBotArena.getTurretData()
    local x, y = Sector():getCoordinates()

    local turrets = {}
    local numTurrets = Balancing_GetEnemySectorTurrets(x, y) * 1.5
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false

    local turret = generator:generate(x, y, 0, Rarity(RarityType.Rare), WeaponType.Laser)
    local weapons = {turret:getWeapons()}
    turret:clearWeapons()
    for _, weapon in pairs(weapons) do
        weapon.bouterColor = ColorRGB(0.1, 0.4, 0.6)
        turret:addWeapon(weapon)
    end
    turret.turningSpeed = 6
    turrets[turret] = numTurrets

    local numDefenseTurrets = Balancing_GetEnemySectorTurrets(x, y) * 1.5
    local defenseTurrets = {}
    local turret = generator:generate(x, y, 0, Rarity(RarityType.Exceptional), WeaponType.PointDefenseLaser)
    local weapons = {turret:getWeapons()}
    turret:clearWeapons()
    for _, weapon in pairs(weapons) do
        weapon.bouterColor = ColorRGB(0.1, 0.3, 0.7)
        turret:addWeapon(weapon)
    end
    turret.turningSpeed = 6
    defenseTurrets[turret] = numDefenseTurrets

    return {numTurrets = numTurrets, turrets = turrets, numDefenseTurrets = numDefenseTurrets, defenseTurrets = defenseTurrets}
end

function ScrapBotArena.generateArena(x, y, translation)
    local generator = SectorGenerator(x, y)
    local random = random()
    local sector = Sector()
    local dist = 500
    local center = translation

    -- remove old fence posts in case they got moved
    -- we're spawning boss now, so we need a neat looking arena
    local existingFencePosts = {sector:getEntitiesByScriptValue("scrapbot_fencePost")}
    if #existingFencePosts > 0 then
        for _, entity in pairs(existingFencePosts) do
            sector:deleteEntity(entity)
        end
    end

    -- create objects that are used to make a "fence"
    local matrix = Matrix()
    matrix.translation = center

    local angle = math.pi / 3

    local fencePostPositions = {
        {x = dist * math.cos(0),            y = dist * math.sin(0)},
        {x = dist * math.cos(angle),        y = dist * math.sin(angle)},
        {x = dist * math.cos(2 * angle),    y = dist * math.sin(2 * angle)},
        {x = dist * math.cos(3 * angle),    y = dist * math.sin(3 * angle)},
        {x = dist * math.cos(4 * angle),    y = dist * math.sin(4 * angle)},
        {x = dist * math.cos(5 * angle),    y = dist * math.sin(5 * angle)},
    }

    local containerPlan = PlanGenerator.makeContainerPlan()
    containerPlan:scale(vec3(5.0))

    for index, position in pairs(fencePostPositions) do
        matrix.translation = center + vec3(position.x, position.y, 0)
        local container = generator:createContainer(containerPlan, matrix)
        container.dockable = false
        container:setValue("scrapbot_fencePost", index)

        local plan = Plan(container)
        plan.singleBlockDestructionEnabled = false
    end

    -- create wreckages within the fence, use same plane
    if #{sector:getEntitiesByType(EntityType.Wreckage)} < 3 then
        local faction = Galaxy():getNearestFaction(x, y)
        for i = 1, 25 do
            local position = center + vec3(random:getFloat(-1, 1), random:getFloat(-1, 1), 0) * random:getFloat(-(dist-100), (dist-100))
            local matrix = MatrixLookUpPosition(random:getDirection(), random:getDirection(), position)

            local plan = PlanGenerator.makeShipPlan(faction, Balancing_GetSectorShipVolume(x, y))
            generator:createWreckage(faction, plan, 0, matrix);
        end
    end

    -- create some ambient asteroid fields
    if #{sector:getEntitiesByType(EntityType.Asteroid)} < 15 then
        local asteroidFieldGenerator = AsteroidFieldGenerator()

        for i = 1, 5 do
            local numPoints = random:getInt(100, 150)
            local fieldPosition = center + random:getDirection() * random:getInt(2000, 4000)
            local points = asteroidFieldGenerator:generateOrganicCloud(numPoints, fieldPosition, 1000)
            asteroidFieldGenerator.asteroidPositions = points
            asteroidFieldGenerator:createAsteroidFieldEx(numPoints, _, 20, 40, false);
        end
    end

    Placer.resolveIntersections()
end

function ScrapBotArena.getBeaconDialog()
    local dialog = {}
    local dialog2 = {}

    dialog.text = "The Scrap Bot 5000 is the best invention since the dishwasher!\n\nThanks to the latest and improved scrapping technology, the Scrap Bot 5000 is the most efficient and employer-friendly way to recycle wrecks!"%_t .. "\n\n" ..
    "No hassle of towing wrecks halfway across the galaxy, no need to operate in only one sector - Call the Scrap Bot 5000 and harvest your scrap!"%_t
    dialog.answers = {{answer = "[Go to Reviews]"%_t, followUp = dialog2}}

    dialog2.talker = "Reviews"%_t
    dialog2.text = "Downloading Reviews....."%_t .. "\n\n" ..
    "5 / 5 stars - The bot is exactly what I was looking for! No salary negotiations, does his job and quickly!\n4 / 5 stars - Simply perfect."%_t .. "\n\n" ..
     "1 / 5 stars - Would give less stars, but you can’t, of course.. This bot just went rampage. It scrapped EVERYTHING. Including our Station! This is a disaster!\n1 / 5 stars - DON’T BUY! This bot has no safety measures in place and will deny orders to stop! We had to destroy it!"%_t

    return dialog
end

function ScrapBotArena.getBossChatter()
    local chatterLines =
    {
        "Experience the unique capabilities of our Scrap Bot!"%_t,
        "Review of the day: 1/5 stars - I didn't like the color after all."%_t,
        "Most helpful review: 4/5 stars - Bot wanted to scrap my ship right away. Otherwise everything wonderful."%_t,
        "If you are satisfied with our work, we will be glad to receive a positive review."%_t,
        "Please do not forget to empty the cargo hold regularly!"%_t,
    }

    return chatterLines
end
