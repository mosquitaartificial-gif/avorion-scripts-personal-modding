package.path = package.path .. ";data/scripts/lib/?.lua"

local WorldBossUT = include("worldbossutility")
local SectorTurretGenerator = include ("sectorturretgenerator")
local PlanGenerator = include ("plangenerator")
local StyleGenerator = include ("internal/stylegenerator.lua")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace CultShipArena
CultShipArena = {}

function CultShipArena.initialize()
    if onClient() then return end

    CultShipArena.trySpawnBoss()

    local sector = Sector()
    sector:registerCallback("onPlayerEntered", "onPlayerEntered")
    sector:registerCallback("showWorldBossStartFightChatter", "showWorldBossStartFightChatter")
end

function CultShipArena.onPlayerEntered(playerIndex)
    CultShipArena.trySpawnBoss()
    Player(playerIndex):registerCallback("onSectorArrivalConfirmed", "onSectorArrivalConfirmed")
end

function CultShipArena.showWorldBossStartFightChatter()
    local sector = Sector()
    local boss = sector:getEntitiesByScript("worldboss.lua")
    if not boss then return end

    sector:broadcastChatMessage(boss, ChatMessageType.Chatter, "You are not on the list! You are not welcome here!"%_t)
end

function CultShipArena.trySpawnBoss()
    local sector = Sector()
    if WorldBossUT.canSpawn(sector:getValue("worldboss_defeated")) then
        local factionName = "Free People"%_T
        local faction = WorldBossUT.getFaction(factionName)
        local x, y = sector:getCoordinates()

        local bossTitle = "Opportunity"%_t
        local bossPlan = CultShipArena.getBossPlan(x, y, faction)
        local bossChatterLines = CultShipArena.getBossChatter()
        local bossData = {title = bossTitle, plan = bossPlan, chatterLines = bossChatterLines, volumeFactor = 15}

        local beaconTitle = "Manifesto"%_t
        local text = "Manifesto of the Free People"%_t
        local beacon = {title = beaconTitle, interactionText = text}

        local specialLoot = WorldBossUT.generateSystemUpgradeTemplate(x, y, "data/scripts/systems/hyperspacebooster.lua")

        local turretData = CultShipArena.getTurretData()

        local boss = WorldBossUT.generateBoss(faction, bossData, beacon, specialLoot, turretData)

        local x, y = Sector():getCoordinates()
        local contents = CultShipArena.getArenaContents()

        WorldBossUT.generateBossArena(x, y, contents, boss.translationf)
        WorldBossUT.generateBossMinions(2, boss, 1.5)
    end
end

function CultShipArena.getBossPlan(x, y, faction)
    local volume = WorldBossUT.getBossVolume() * 2 -- higher volume/hp, fewer turrets/dps
    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))
    local bossPlan = PlanGenerator.makeShipPlan(faction, volume, nil, material)

    local styleGenerator = StyleGenerator(faction.index)
    styleGenerator.factionDetails.lightLines = false

    local style = styleGenerator:makeColonyShipStyle(random():createSeed())

    local plan = GeneratePlanFromStyle(style, random():createSeed(), volume, 10000, nil, material)

    return plan
end

function CultShipArena.getTurretData()
    local x, y = Sector():getCoordinates()

    local turrets = {}
    local numTurrets = Balancing_GetEnemySectorTurrets(x, y) * 0.75 -- higher volume/hp, fewer turrets/dps
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false

    local turret = generator:generate(x, y, 0, Rarity(RarityType.Rare), WeaponType.RailGun)
    local weapons = {turret:getWeapons()}
    turret:clearWeapons()
    for _, weapon in pairs(weapons) do
        weapon.bouterColor = ColorRGB(0.6, 0.1, 0.2)
        turret:addWeapon(weapon)
    end
    turret.turningSpeed = 6
    turrets[turret] = numTurrets

    local numDefenseTurrets = Balancing_GetEnemySectorTurrets(x, y) * 1.5
    local defenseTurrets = {}
    local turret = generator:generate(x, y, 0, Rarity(RarityType.Rare), WeaponType.PointDefenseChainGun)
    local weapons = {turret:getWeapons()}
    turret:clearWeapons()
    for _, weapon in pairs(weapons) do
        weapon.pcolor = ColorRGB(0.8, 0.1, 0.2)
        turret:addWeapon(weapon)
    end
    turret.turningSpeed = 6
    defenseTurrets[turret] = numDefenseTurrets

    return {numTurrets = numTurrets, turrets = turrets, numDefenseTurrets = numDefenseTurrets, defenseTurrets = defenseTurrets}
end

function CultShipArena.getArenaContents()
    local contents = {}

    local asteroids = {
        {type = "Ring", asteroidSize = 30, probability = 0.2, numPoints = 150, radius = 4000, center = position},
        {type = "Ring", asteroidSize = 30, probability = 0.2, numPoints = 150, radius = 4000, center = position},
        {type = "Ring", asteroidSize = 30, probability = 0.2, numPoints = 150, radius = 4000, center = position},
        {type = "Ring", asteroidSize = 30, probability = 0.2, numPoints = 150, radius = 4000, center = position},
        {type = "Ring", asteroidSize = 30, probability = 0.2, numPoints = 150, radius = 4000, center = position},

        {type = "Ring", asteroidSize = 30, probability = 0.2, numPoints = 200, radius = 4000, center = position},
        {type = "Ring", asteroidSize = 30, probability = 0.2, numPoints = 200, radius = 4000, center = position},
        {type = "Ring", asteroidSize = 30, probability = 0.2, numPoints = 200, radius = 4000, center = position},
        {type = "Ring", asteroidSize = 30, probability = 0.2, numPoints = 200, radius = 4000, center = position},
        {type = "Ring", asteroidSize = 30, probability = 0.2, numPoints = 200, radius = 4000, center = position},
    }

    contents.asteroids = asteroids

    return contents
end

function CultShipArena.getBeaconDialog()
    local dialog = {}

    dialog.text = "Calling all those with a clear mind!"%_t .. "\n\n" ..
    "The end is near! Research institutions try to find a way into the cracks! Without sense and understanding with the fire is played and opened thereby door and gate for a big Xsotaninvasion!"%_t .. "\n\n" ..
    "To every clear-thinking person: We must prepare for the catastrophe! We make the beginning, join us!"%_t .. "\n\n" ..
    "We will leave this galaxy before we can be dragged down with it!"%_t .. "\n\n" ..
    "We have created supplies for this, but only enough for a limited number of passengers. Register now and secure your place aboard the \"Opportunity\"!"%_t

    return dialog
end

function CultShipArena.getBossChatter()
    local chatterLines =
    {
        "These are OUR supplies! Get out of here or we'll finish you off!"%_t,
        "We are on the way to salvation, you can't stop it!"%_t,
        "We will not give up! Each of us has fought hard for his place on the ship!"%_t,
        "You are too late! All seats are taken!"%_t,
        "You are doomed! Let us find salvation!"%_t
    }

    return chatterLines
end
