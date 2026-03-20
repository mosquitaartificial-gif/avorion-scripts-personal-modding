package.path = package.path .. ";data/scripts/lib/?.lua"

include ("galaxy")
include ("utility")
local WorldBossUT = include("worldbossutility")
local PlanGenerator = include ("plangenerator")
local StyleGenerator = include ("internal/stylegenerator.lua")
local SectorTurretGenerator = include ("sectorturretgenerator")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace CryoColonyArena
CryoColonyArena = {}

function CryoColonyArena.initialize()
    if onClient() then return end

    CryoColonyArena.trySpawnBoss()

    local sector = Sector()
    sector:registerCallback("onPlayerEntered", "onPlayerEntered")
    sector:registerCallback("showWorldBossStartFightChatter", "showWorldBossStartFightChatter")
end

function CryoColonyArena.onPlayerEntered(playerIndex)
    CryoColonyArena.trySpawnBoss()
end

function CryoColonyArena.showWorldBossStartFightChatter()
    local sector = Sector()
    local boss = sector:getEntitiesByScript("worldboss.lua")
    if not boss then return end

    sector:broadcastChatMessage(boss, ChatMessageType.Chatter, "Dangerous approach detected! Start defensive maneuvers!"%_t)
end

function CryoColonyArena.trySpawnBoss()
    local sector = Sector()
    if WorldBossUT.canSpawn(sector:getValue("worldboss_defeated")) then
        local factionName = "Cryo Tech"%_T
        local faction = WorldBossUT.getFaction(factionName)
        local x, y = sector:getCoordinates()

        local bossTitle = "Hope I"%_t
        local bossPlan = CryoColonyArena.getBossPlan(x, y, faction)
        local bossChatterLines = CryoColonyArena.getBossChatter()
        local bossData = {title = bossTitle, plan = bossPlan, chatterLines = bossChatterLines, volumeFactor = 15}

        local beaconTitle = "System-Log"%_t
        local interactionText = "This is the automated log of the 'Hope I'.\n\nOur mission: to preserve life.\n\nOur ship 'Hope I' is equipped with an extremely powerful artificial intelligence that will monitor life support."%_t
        local beacon = {title = beaconTitle, interactionText = interactionText}

        local specialLoot = WorldBossUT.generateSystemUpgradeTemplate(x, y, "data/scripts/systems/energybooster.lua")

        local turretData = CryoColonyArena.getTurretData()

        local bossShip = WorldBossUT.generateBoss(faction, bossData, beacon, specialLoot, turretData)

        CryoColonyArena.addCargo(bossShip.id)

        local contents = CryoColonyArena.getArenaContents()
        WorldBossUT.generateBossArena(x, y, contents)
    end
end

function CryoColonyArena.addCargo(bossId)
    local boss = Entity(bossId)
    local goodList = {"Food", "Protein", "Water", "Oxygen"}

    local usableCargoSpace = math.min(200, boss.freeCargoSpace)
    local compartmentSize = usableCargoSpace / #goodList

    for i, name in pairs(goodList) do
        local good = goods[name]:good()
        amount = math.floor(compartmentSize / good.size)
        boss:addCargo(good, amount)
    end
end

function CryoColonyArena.getBossPlan(x, y, faction)
    local volume = WorldBossUT.getBossVolume() * 2 -- higher volume/hp, fewer turrets/dps
    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))
    local bossPlan = PlanGenerator.makeShipPlan(faction, volume, nil, material)

    local styleGenerator = StyleGenerator(faction.index)
    styleGenerator.factionDetails.paintColor = {r = 0.2, g = random():getFloat(0.5, 0.9), b = random():getFloat(0.6, 1.0)}
    styleGenerator.factionDetails.lightColor = {r = 0.4, g = 0.6, b = 1.0}
    styleGenerator.factionDetails.lightLines = true

    local style = styleGenerator:makeColonyShipStyle(random():createSeed())

    local plan = GeneratePlanFromStyle(style, random():createSeed(), volume, 10000, nil, material)

    return plan
end

function CryoColonyArena.getArenaContents()
    local contents = {}
    local asteroids = {
        {type = "Default", numFields = random():getInt(5, 6)},
    }

    contents.asteroids = asteroids
    return contents
end

function CryoColonyArena.getTurretData()
    local x, y = Sector():getCoordinates()

    -- generate Railguns
    local turrets = {}
    local numTurrets = Balancing_GetEnemySectorTurrets(x, y) * 0.75 -- fewer turrets, higher HP
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false

    local turret = generator:generate(x, y, 0, Rarity(RarityType.Exceptional), WeaponType.RailGun)
    turret.turningSpeed = 6
    turrets[turret] = numTurrets

    return {numTurrets = numTurrets, turrets = turrets}
end

function CryoColonyArena.getBeaconDialog()
    local dialog = {}

    dialog.text = "Log 17:97-AZR:\nAI GenLife activated. First diagnostic scan completed: Age average - low; Health status - very good; Life support systems - active."%_t .. "\n\n" ..
    "Log 64:05-SSF:\nLeak discovered in cargo hold. Injured personnel received medical attention and were placed in cryo-sleep for their safety. Leak has been repaired."%_t .. "\n\n" ..
    "Log 45:61-SVH:\nAge rate of crew is increasing, some passengers have shown signs of aging. Affected individuals were placed in cryo-sleep for their safety."%_t .. "\n\n" ..
    "Log 47:75-FGJ:\nCryo-systems identified as survival pathway. Expansion cryo-sleep will ensure survival."%_t .. "\n\n" ..
    "Log 84:20-DVA:\nHealth condition - not optimal; put remaining passengers into cryo-sleep. Autopilot activated, enemy detection activated. Life support on board ensured in the long term."%_t .. "\n\n" ..
    "Log 15:53-FWO:\nUnknown vessel detected on scanner. DANGER! Defense systems activated. Attack distance: 5km."%_t .. "\n\n" ..
    "Log 74:27-IOS:\nExternal attack averted. Danger spectrum extended. Destroy unknown ships for self-protection."%_t

    return dialog
end

function CryoColonyArena.getBossChatter()
    local chatterLines =
    {
        "Danger to passengers detected!"%_t,
        "Warning. Enemy entity detected. Launch offensive defense."%_t,
        "Guarantee survival of passengers. Destroy recognized dangers!"%_t,
        "Danger from unknown intruders. Destruction of the danger has the highest priority."%_t,
    }

    return chatterLines
end
