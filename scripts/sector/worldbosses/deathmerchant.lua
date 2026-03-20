package.path = package.path .. ";data/scripts/lib/?.lua"

include ("galaxy")
include ("utility")
include ("productions")
local WorldBossUT = include("worldbossutility")
local PlanGenerator = include ("plangenerator")
local SectorGenerator = include ("SectorGenerator")
local SectorTurretGenerator = include ("sectorturretgenerator")
local AsteroidFieldGenerator = include ("asteroidfieldgenerator")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace DeathMerchantArena
DeathMerchantArena = {}

function DeathMerchantArena.initialize(position)
    if onClient() then return end
    if position then
        data.position = position
    end

    DeathMerchantArena.trySpawnBoss()

    local sector = Sector()
    sector:registerCallback("onPlayerEntered", "onPlayerEntered")
    sector:registerCallback("showWorldBossStartFightChatter", "showWorldBossStartFightChatter")
end

function DeathMerchantArena.onPlayerEntered(playerIndex)
    DeathMerchantArena.trySpawnBoss()
end

function DeathMerchantArena.showWorldBossStartFightChatter()
    local sector = Sector()
    local boss = sector:getEntitiesByScript("worldboss.lua")
    if not boss then return end

    sector:broadcastChatMessage(boss, ChatMessageType.Chatter, "Are you hoping for the bounty? Give it a try!"%_t)
end

function DeathMerchantArena.trySpawnBoss()
    local sector = Sector()
    if WorldBossUT.canSpawn(sector:getValue("worldboss_defeated")) then
        local factionName = "Merchants"%_T
        local faction = WorldBossUT.getFaction(factionName)
        local x, y = Sector():getCoordinates()

        local bossTitle = "The Merchant"%_t
        local bossPlan = DeathMerchantArena.getBossPlan(x, y, faction)
        local bossChatterLines = DeathMerchantArena.getBossChatter()
        local bossData = {title = bossTitle, plan = bossPlan, chatterLines = bossChatterLines, volumeFactor = 15}

        local beaconTitle = "Bulletin Board"%_t
        local text = beaconTitle
        local beacon = {title = beaconTitle, interactionText = text}

        local specialLoot = WorldBossUT.generateSystemUpgradeTemplate(x, y, "data/scripts/systems/tradingoverview.lua")

        local turretData = DeathMerchantArena.getTurretData()

        local boss = WorldBossUT.generateBoss(faction, bossData, beacon, specialLoot, turretData)
        DeathMerchantArena.addCargo(boss.id)

        DeathMerchantArena.generateArena(x, y, boss.translationf, boss.up)
        WorldBossUT.generateBossMinions(4, boss, 1)
    end
end

function DeathMerchantArena.addCargo(bossId)
    local boss = Entity(bossId)
    local goodList = {"Jewelry", "Diamond", "Gold", "Luxury Food", "Gem"}

    local usableCargoSpace = math.min(50, boss.freeCargoSpace)
    local compartmentSize = usableCargoSpace / #goodList

    for i, name in pairs(goodList) do
        local good = goods[name]:good()
        amount = math.floor(compartmentSize / good.size)
        boss:addCargo(good, amount)
    end
end

function DeathMerchantArena.getBossPlan(x, y, faction)
    local volume = WorldBossUT.getBossVolume()
    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))
    local bossPlan = PlanGenerator.makeFreighterPlan(faction, volume, nil, material)

    return bossPlan
end

function DeathMerchantArena.getTurretData()
    local x, y = Sector():getCoordinates()

    -- generate weapons
    local turrets = {}
    local numTurrets = Balancing_GetEnemySectorTurrets(x, y) + 3
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false

    local turret = generator:generate(x, y, 0, Rarity(RarityType.Exceptional), WeaponType.Laser)
    local weapons = {turret:getWeapons()}
    turret:clearWeapons()
    for _, weapon in pairs(weapons) do
        weapon.binnerColor = ColorRGB(0.3, 0.2, 0.2)
        weapon.bouterColor = ColorRGB(0.8, 0.7, 0.2)
        turret:addWeapon(weapon)
    end
    turret.turningSpeed = 6
    turrets[turret] = numTurrets

    return {numTurrets = numTurrets, turrets = turrets}
end

function DeathMerchantArena.generateArena(x, y, center, bossUp)
    local generator = SectorGenerator(x, y)
    local random = random()
    local sector = Sector()

    -- generate station
    local position = center + random():getDirection() * 250
    local faction = Galaxy():getNearestFaction(x, y);

    if not sector:getEntitiesByScriptValue("deathmerchant_station") then
        local productionToUse
        for _, production in pairs(productions) do
            for _, result in pairs(production.results) do
                if result.name == "Coal" then
                    productionToUse = production
                    break
                end
            end
        end

        local stationStyle = PlanGenerator.determineStationStyleFromScriptArguments("data/scripts/entity/merchants/factory.lua", productionToUse)

        local stationPlan = PlanGenerator.makeStationPlan(faction, stationStyle, nil, Balancing_GetSectorStationVolume(x, y) * 0.5)
        for _, index in pairs({stationPlan:getBlockIndices()}) do
            local blocktype = stationPlan:getBlockType(index)
            if blocktype == BlockType.Holo
                    or blocktype == BlockType.HoloCorner
                    or blocktype == BlockType.HoloEdge then
                stationPlan:removeBlock(index)
            end

            if blocktype == BlockType.Glow
                    or blocktype == BlockType.GlowCorner
                    or blocktype == BlockType.GlowEdge then
                stationPlan:setBlockColor(index, ColorRGB(0.1, 0.1, 0.1))
            end
        end

        local matrix = MatrixLookUpPosition(random:getDirection(), bossUp, center + random():getDirection() * 250)

        local stationAsteroid = generator:createEmptyBigAsteroid(matrix)
        stationAsteroid:setMovePlan(stationPlan)
        stationAsteroid:setValue("deathmerchant_station", true)
    end

    -- generate ambient cargo hauler wrecks close to station
    if #{sector:getEntitiesByType(EntityType.Wreckage)} < 5 then
        for i = 1, 5 do
            local position = position + random:getDirection() * random:getFloat(100, 250)
            local matrix = MatrixLookUpPosition(random:getDirection(), bossUp, position)

            local shipPlan = PlanGenerator.makeFreighterPlan(faction)
            local wreckage = generator:createWreckage(faction, shipPlan, 0, matrix)
            wreckage:removeScript("captainslogs.lua")
        end
    end

    -- generate ambient asteroid fields
    if #{sector:getEntitiesByType(EntityType.Asteroid)} < 15 then
        local asteroidFieldGenerator = AsteroidFieldGenerator()
        local fieldPosition = position
        local numPoints = 500
        local points = asteroidFieldGenerator:generateOrganicCloud(numPoints, fieldPosition, 3000)
        asteroidFieldGenerator.asteroidPositions = points
        asteroidFieldGenerator:createAsteroidFieldEx(numPoints, _, 15, 40, true, 0.01);
    end
end

function DeathMerchantArena.getArenaContents()
    local contents = {}

    local asteroids = {
        {type = "Default", numFields = random():getInt(5, 6)}
    }

    contents.asteroids = asteroids

    return contents
end

function DeathMerchantArena.getBeaconDialog()
    local dialog = {}
    local dialog2 = {}
    local dialog3 = {}
    local dialog4 = {}
    local dialog5 = {}

    dialog.text = "hey, check this out, they are reporting about us! we are now fully famous ;)"%_t
    dialog.followUp = dialog2

    dialog2.talker = "Reports from the outer sectors"%_t
    dialog2.text = "\"Recently, attacks on our merchant ships have increased. According to current information, ships disguised as traders are attacking other ships flying alone or even convoys.\""%_t
    .. "\n\n" .. "\"Avoid contact with unknown traders and fly only in official convoys escorted by our fleet.\""%_t
    dialog2.followUp = dialog3

    dialog3.text = "yeah yeah, great fleet they have. they couldn't even handle a few dealers, lol. the captain's tactic of posing as a dealer works almost too well :D /* typos and lowercase are on purpose */"%_t
    dialog3.followUp = dialog4

    dialog4.talker = "Official Notification"%_t
    dialog4.text = "\"Important message to all ships:\nThe capacity of our fleet is not sufficient to protect all convoys! We advise you to use your own security ships or to wait until official convoys start again!\""%_t
    dialog4.followUp = dialog5

    dialog5.text = "actually a good tactic. we should also offer convoys, so we can attract even more iditoes, hehe /* typos and lowercase are on purpose */"%_t

    return dialog
end

function DeathMerchantArena.getBossChatter()
    local chatterLines =
    {
        "You can't stop us! You should never have come here!"%_t,
        "You have found us, but no one will ever find you!"%_t,
        "You should not have interfered in our business!"%_t,
        "Do you think you are better than us? You yourselves exploit every weakness!"%_t,
    }

    return chatterLines
end
