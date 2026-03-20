package.path = package.path .. ";data/scripts/lib/?.lua"

include ("galaxy")
include ("utility")
local WorldBossUT = include("worldbossutility")
local LegendaryTurretGenerator = include ("internal/common/lib/legendaryturretgenerator.lua")
local AsteroidFieldGenerator = include ("asteroidfieldgenerator")
local PlanGenerator = include ("plangenerator")
local SectorTurretGenerator = include ("sectorturretgenerator")
local ShipUtility = include ("shiputility")
local TorpedoGenerator = include ("torpedogenerator")
local TorpedoUtility = include ("torpedoutility")
local SectorGenerator = include ("SectorGenerator")
local Placer = include ("placer")
local ShipUtility = include ("shiputility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace LostWMDArena
LostWMDArena = {}

function LostWMDArena.initialize()
    if onClient() then return end

    LostWMDArena.trySpawnBoss()

    local sector = Sector()
    sector:registerCallback("onPlayerEntered", "onPlayerEntered")
    sector:registerCallback("showWorldBossStartFightChatter", "showWorldBossStartFightChatter")
end

function LostWMDArena.onPlayerEntered(playerIndex)
    LostWMDArena.trySpawnBoss()
end

function LostWMDArena.showWorldBossStartFightChatter()
    local sector = Sector()
    local boss = sector:getEntitiesByScript("worldboss.lua")
    if not boss then return end

    sector:broadcastChatMessage(boss, ChatMessageType.Chatter, "Hostile object detected. Attack is initiated."%_t)
end

function LostWMDArena.trySpawnBoss()
    local sector = Sector()
    if WorldBossUT.canSpawn(sector:getValue("worldboss_defeated")) then
        local factionName = "WMD"%_T
        local faction = WorldBossUT.getFaction(factionName)
        local x, y = sector:getCoordinates()

        local bossTitle = "Exterminatus"%_t

        local bossPlan = LostWMDArena.getBossPlan(x, y, faction)
        local bossChatterLines = LostWMDArena.getBossChatter()
        local bossData = {title = bossTitle, plan = bossPlan, chatterLines = bossChatterLines}

        local beaconTitle = "Voice Recording"%_t
        local text = "Voice recording for startup"%_t
        local beacon = {title = beaconTitle, interactionText = text}

        local generator = LegendaryTurretGenerator()
        local specialLoot = InventoryTurret(generator:generateSeekerCannon(x, y, 0))

        local turretData = LostWMDArena.getTurretData()

        local boss = WorldBossUT.generateBoss(faction, bossData, beacon, specialLoot, turretData)
        LostWMDArena.generateArena(x, y, boss.translationf)

        -- add torpedoes
        LostWMDArena.addTorpedoes(boss)
        boss:addScriptOnce("data/scripts/sector/worldbosses/lostwmdadditionaltorpedoes.lua")

    end
end

function LostWMDArena.getBossPlan(x, y, faction)
    local volume = WorldBossUT.getBossVolume()
    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))
    local bossPlan = PlanGenerator.makeShipPlan(faction, volume, nil, material)

    for _, index in pairs({bossPlan:getBlockIndices()}) do
        local blocktype = bossPlan:getBlockType(index)

        if random():test(0.5) then
            bossPlan:setBlockColor(index, ColorRGB(0.3, 0.3, 0.3))
        else
            bossPlan:setBlockColor(index, ColorRGB(0.75, 0.5, 0.1))
        end

        if blocktype == BlockType.Hull then
            if random():test(0.25) then
                bossPlan:setBlockType(index, BlockType.TorpedoStorage)
            end
        end
    end

    return bossPlan
end

function LostWMDArena.getTurretData()
    local x, y = Sector():getCoordinates()

    -- generate weapons: long range rocket launcher, torpedoes are added later
    local turrets = {}
    local numTurrets = Balancing_GetEnemySectorTurrets(x, y) + 3
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false

    local turret = generator:generate(x, y, 0, Rarity(RarityType.Exotic), WeaponType.RocketLauncher)
    turret.turningSpeed = 6
    turrets[turret] = math.floor(numTurrets)

    return {numTurrets = numTurrets, turrets = turrets}
end

function LostWMDArena.generateArena(x, y, center)
    local sector = Sector()

    if #{sector:getEntitiesByType(EntityType.Asteroid)} < 100 then
        local generator = AsteroidFieldGenerator()
        local radius = 2000

        local index = 1
        local numFields = 16

        local faction = Galaxy():getNearestFaction(x, y)

        for index = 1, 3 do
            local angle = 2 * math.pi * index / numFields
            local look = vec3(math.cos(angle), math.sin(angle), 0)

            -- first cloud closer to center
            local points = {}
            local asteroids = generator:generateOrganicCloud(100, center + look * radius)
            table.concatenate(points, asteroids)

            -- second cloud further away with half the asteroids
            local asteroids = generator:generateOrganicCloud(50, center + look * (radius * 1.5))
            table.concatenate(points, asteroids)

            for _, location in pairs(points) do
                local position = MatrixLookUpPosition(center-location, vec3(0, 1, 0), location)
                local size = random():getInt(15, 40)
                if random():test(0.1) then
                    local plan = PlanGenerator.makeShipPlan(faction)
                    local wreckage = sector:createWreckage(plan, position)
                    ShipUtility.stripWreckage(wreckage)
                else
                    local plan = PlanGenerator.makeSmallAsteroidPlan(size, false)
                    local bbsize = plan:getBoundingBox().size
                    plan:scale(vec3(size / bbsize.x, size / bbsize.y, (size * random():getFloat(3, 6)) / bbsize.z))
                    sector:createAsteroid(plan, resources, position)
                end
            end
        end

        Placer.resolveIntersections()
    end
end

function LostWMDArena.addTorpedoes(boss)
    local x, y = Sector():getCoordinates()
    local generator = TorpedoGenerator()
    local torpedo = generator:generate(x, y, 0, nil, TorpedoUtility.WarheadType.Neutron, nil)
    ShipUtility.addTorpedoesToCraft(boss, torpedo, 12)
end

function LostWMDArena.getBeaconDialog()
    local dialog = {}
    local dialog2 = {}

    dialog.text = "Today we lift the veil from the project with which our fleet has dared to take the next step. With the completion of this system, we no longer need to fear anyone. The Exterminatus is capable of taking on any fleet on its own."%_t .. "\n\n" ..
    "To our friends we say: Do not be afraid! An attack on you, we will retaliate, as if we ourselves had been the target!"%_t .. "\n\n" ..
    "To our enemies, however, be told: Fear! Every provocation will from now on be repaid with all the strength that is now at our disposal!"%_t
    dialog.followUp = dialog2

    dialog2.talker = "Internal Log"%_t
    dialog2.text = "Internal log 000001:\nStart sequence: Initiated; Friend enemy detection: Initiated;"%_t .. "\n\n" ..
    "Startup sequence: Completed; Friend enemy detection: Error;"%_t

    return dialog
end

function LostWMDArena.getBossChatter()
    local chatterLines =
    {
        "Current priority: extermination of the enemy."%_t,
        "Target coordinates recalculated. Weapon launch initiated."%_t,
        "Only enemy objects detected. All weapons initialized."%_t,
        "All targets cleared for destruction: 3, 2, 1 ..."%_t,
    }

    return chatterLines
end
