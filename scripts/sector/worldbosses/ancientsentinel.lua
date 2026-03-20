package.path = package.path .. ";data/scripts/lib/?.lua"

include ("galaxy")
include ("utility")
local WorldBossUT = include("worldbossutility")
local PlanGenerator = include ("plangenerator")
local SectorTurretGenerator = include ("sectorturretgenerator")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace AncientSentinelArena
AncientSentinelArena = {}

local factionName = "Sentinel"%_T

function AncientSentinelArena.initialize()
    if onClient() then return end

    AncientSentinelArena.trySpawnBoss()

    local sector = Sector()
    sector:registerCallback("onPlayerEntered", "onPlayerEntered")
    sector:registerCallback("showWorldBossStartFightChatter", "showWorldBossStartFightChatter")
end

function AncientSentinelArena.onPlayerEntered(playerIndex)
    AncientSentinelArena.trySpawnBoss()
end

function AncientSentinelArena.showWorldBossStartFightChatter()
    local sector = Sector()
    local boss = sector:getEntitiesByScript("worldboss.lua")
    if not boss then return end

    sector:broadcastChatMessage(boss, ChatMessageType.Chatter, "Enemy identified... Defense protocols activated..."%_t)
end

function AncientSentinelArena.trySpawnBoss()
    local sector = Sector()
    if WorldBossUT.canSpawn(sector:getValue("worldboss_defeated")) then
        local faction = WorldBossUT.getFaction(factionName)

        local x, y = Sector():getCoordinates()
        local rnd = Random(Seed(x..y))
        local serialNumber = makeSerialNumber(rnd, 3, "SP-")
        local bossTitle = "Sentinel ${serialNumber}"%_t % {serialNumber = serialNumber}
        local bossPlan = AncientSentinelArena.getBossPlan(x, y, faction)
        local bossChatterLines = AncientSentinelArena.getBossChatter()
        local bossData = {title = bossTitle, plan = bossPlan, chatterLines = bossChatterLines}

        local beaconTitle = "Sector Logbook"%_t
        local text = "Logbook of the sector ${x}:${y}"%_t
        local beacon = {title = beaconTitle, interactionText = text, args = {x = x, y = y}}

        local specialLoot = WorldBossUT.generateSystemUpgradeTemplate(x, y, "data/scripts/systems/militarytcs.lua")

        local turretData = AncientSentinelArena.getTurretData()

        local boss = WorldBossUT.generateBoss(faction, bossData, beacon, specialLoot, turretData)

        local contents = AncientSentinelArena.getArenaContents()
        WorldBossUT.generateBossArena(x, y, contents, boss.translationf)
    end
end

function AncientSentinelArena.makeSerialNumber(rnd, length, prefix, postfix)

    function generate(chars, num)
        local result = ""

        for i = 1, num do
            local c = rnd:getInt(1, #chars)
            result = result .. chars:sub(c, c)
        end

        return result
    end

    local chars = "123456789"

    return (prefix or "") .. generate(chars, length) .. (postfix or "")
end

function AncientSentinelArena.getBossPlan(x, y, faction)
    local volume = WorldBossUT.getBossVolume()
    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))
    local bossPlan = PlanGenerator.makeStationPlan(faction, styleName, nil, volume, material)

    for _, index in pairs({bossPlan:getBlockIndices()}) do
        local blocktype = bossPlan:getBlockType(index)

        if blocktype == BlockType.Hull then
            if random():test(0.5) then
                bossPlan:setBlockType(index, BlockType.Stone)
            end
        end
        if blocktype == BlockType.EdgeHull then
            bossPlan:setBlockType(index, BlockType.StoneEdge)
        end
        if blocktype == BlockType.CornerHull then
            bossPlan:setBlockType(index, BlockType.StoneCorner)
        end
    end

    return bossPlan
end

function AncientSentinelArena.getTurretData()
    local x, y = Sector():getCoordinates()

    -- generate turrets of "old-tech" with long range: Cannons and PDCs
    local turrets = {}
    local numTurrets = Balancing_GetEnemySectorTurrets(x, y) * 1.5
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false

    local turret = generator:generate(x, y, 0, Rarity(RarityType.Exceptional), WeaponType.Cannon)
    local weapons = {turret:getWeapons()}
    turret:clearWeapons()
    for _, weapon in pairs(weapons) do
        weapon.pcolor = ColorRGB(0.2, 0.2, 0.8)
        turret:addWeapon(weapon)
    end
    turret.turningSpeed = 6
    turrets[turret] = numTurrets

    local numDefenseTurrets = Balancing_GetEnemySectorTurrets(x, y) * 1.5
    local defenseTurrets = {}
    local turret = generator:generate(x, y, 0, Rarity(RarityType.Exceptional), WeaponType.PointDefenseChainGun)
    local weapons = {turret:getWeapons()}
    turret:clearWeapons()
    for _, weapon in pairs(weapons) do
        weapon.pcolor = ColorRGB(0.2, 0.2, 0.8)
        turret:addWeapon(weapon)
    end
    turret.turningSpeed = 6
    defenseTurrets[turret] = numDefenseTurrets

    return {numTurrets = numTurrets, turrets = turrets, numDefenseTurrets = numDefenseTurrets, defenseTurrets = defenseTurrets}
end

function AncientSentinelArena.getArenaContents()
    local contents = {}

    local wreckages = {
         {size = 10, amount = 5, minDist = 1000, maxDist = 1500},
         {size = 30, amount = 3, minDist = 1000, maxDist = 1500}
    }

    local stationWreckages = {
        {type = "data/scripts/entity/merchants/shipyard.lua", size = 1, amount = 1, minDist = 50, maxDist = 200},
        {type = "data/scripts/entity/merchants/tradingpost.lua", size = 1, amount = 1, minDist = 1000, maxDist = 2500},
        {type = "data/scripts/entity/merchants/militaryoutpost.lua", size = 1, amount = 1, minDist = 1000, maxDist = 5000},
        {type = "data/scripts/entity/merchants/factory.lua", size = 1, amount = 1, minDist = 1000, maxDist = 5000},
        {type = "data/scripts/entity/merchants/factory.lua", size = 1, amount = 1, minDist = 1000, maxDist = 1500},
        {type = "data/scripts/entity/merchants/factory.lua", size = 1, amount = 1, minDist = 1000, maxDist = 1500}
    }

    local asteroids = {
        {type = "Default", numFields = 1},
    }

    local containerFields = {
        {factionName = factionName, sizeX = random():getInt(20, 30), sizeY = random():getInt(20, 30), circular = 1, numFields = random():getInt(2, 3), hackables = random():getInt(1, 2), minDist = 500, maxDist = 800},
    }

    contents.wreckages = wreckages
    contents.stationWreckages = stationWreckages
    contents.asteroids = asteroids
    contents.containerFields = containerFields

    return contents
end

function AncientSentinelArena.getBeaconDialog()
    local dialog = {}

    local x, y = Sector():getCoordinates()
    local language = Language(Seed(x..y))
    local planetName = language:getName()

    dialog.text = "We dedicate this guardian to our planet ${planetName}. May we be eternally safe through the protection of this masterpiece of modern technology. May it protect us from every threat the galaxy holds!"%_t % {planetName = planetName} .. "\n\n" ..
    "The new technologies we have tested and used in building this masterpiece bring us a big step closer to successfully colonizing space."%_t .. "\n\n" ..
    "We hope that, thanks to our efforts, future generations will also live in peace and grow and prosper under the guardian's protection."%_t .. "\n\n" ..
    "- Records unreadable -"%_t .. "\n\n" ..
    "We must leave this area, this ancient relic will remain here. Its protection will help new settlers quickly establish a safe colony."%_t

    return dialog
end

function AncientSentinelArena.getBossChatter()
    local chatterLines =
    {
        "Enemy detected, combat operations continue."%_t,
        "Critical warning: Friend enemy detection faulty."%_t,
        "Warning: Planet not in range. Emergency mode cannot be deactivated."%_t,
        "Threat detected. Weapons clearance granted."%_t,
    }

    return chatterLines
end
