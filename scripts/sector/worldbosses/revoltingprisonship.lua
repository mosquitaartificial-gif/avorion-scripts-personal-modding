package.path = package.path .. ";data/scripts/lib/?.lua"

include ("galaxy")
include ("utility")
local WorldBossUT = include ("worldbossutility")
local LegendaryTurretGenerator = include ("internal/common/lib/legendaryturretgenerator.lua")
local SectorTurretGenerator = include ("sectorturretgenerator")
local PlanGenerator = include ("plangenerator")
local AsteroidFieldGenerator = include ("asteroidfieldgenerator")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace RevoltingPrisonShipArena
RevoltingPrisonShipArena = {}

function RevoltingPrisonShipArena.initialize()
    if onClient() then return end

    RevoltingPrisonShipArena.trySpawnBoss()

    local sector = Sector()
    sector:registerCallback("onPlayerEntered", "onPlayerEntered")
    sector:registerCallback("showWorldBossStartFightChatter", "showWorldBossStartFightChatter")
end

function RevoltingPrisonShipArena.onPlayerEntered(playerIndex)
    RevoltingPrisonShipArena.trySpawnBoss()
end

function RevoltingPrisonShipArena.showWorldBossStartFightChatter()
    local sector = Sector()
    local boss = sector:getEntitiesByScript("worldboss.lua")
    if not boss then return end

    sector:broadcastChatMessage(boss, ChatMessageType.Chatter, "Don't let them get us! Attack!"%_t)
end

function RevoltingPrisonShipArena.trySpawnBoss()
    local sector = Sector()
    if WorldBossUT.canSpawn(sector:getValue("worldboss_defeated")) then
        local factionName = "High Sec Comp."%_T
        local faction = WorldBossUT.getFaction(factionName)
        local x, y = sector:getCoordinates()

        local bossTitle = "Complex HSP"%_t
        local bossPlan = RevoltingPrisonShipArena.getBossPlan(x, y, faction)
        local bossChatterLines = RevoltingPrisonShipArena.getBossChatter()


        local bossData = {title = bossTitle, plan = bossPlan, chatterLines = bossChatterLines}

        local x, y = Sector():getCoordinates()
        local language = Language(Seed(x..y))
        local writerName = language:getName()

        local beaconTitle = "Log"%_t
        local interactionText = "Excerpts from ${writerName}'s diary."%_t % {writerName = writerName}
        local beacon = {title = beaconTitle, interactionText = interactionText}

        local specialLoot = WorldBossUT.generateSystemUpgradeTemplate(x, y, "data/scripts/systems/autotcs.lua")

        local turretData = RevoltingPrisonShipArena.getTurretData()

        local boss = WorldBossUT.generateBoss(faction, bossData, beacon, specialLoot, turretData)

        RevoltingPrisonShipArena.generateArena(x, y, boss.translationf, faction.index)
    end
end

function RevoltingPrisonShipArena.getBossPlan(x, y, faction)
    local volume = WorldBossUT.getBossVolume()
    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))
    local bossPlan = PlanGenerator.makeShipPlan(faction, volume, nil, material)
    local bossLength = bossPlan:getBoundingBox().size.z
    local stripeWidth = bossLength / 5

    for _, index in pairs({bossPlan:getBlockIndices()}) do
        local block = bossPlan:getBlock(index)
        local centerZ = block.box.center.z

        if round(centerZ / stripeWidth) % 2 == 0 then
            bossPlan:setBlockColor(index, ColorRGB(0.8, 0.8, 0.8))
        else
            bossPlan:setBlockColor(index, ColorRGB(0.2, 0.2, 0.2))
        end
    end

    return bossPlan
end

function RevoltingPrisonShipArena.getTurretData()
    local x, y = Sector():getCoordinates()

    -- generate lots of different weapons, so that we get versatile shot colors
    local turrets = {}
    local numTurrets = Balancing_GetEnemySectorTurrets(x, y) * 1.5
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false

    local turret = generator:generate(x, y, 0, Rarity(RarityType.Exotic), WeaponType.Bolter)
    turret.turningSpeed = 6
    turrets[turret] = numTurrets

    local numDefenseTurrets = Balancing_GetEnemySectorTurrets(x, y)
    local defenseTurrets = {}
    local turret = generator:generate(x, y, 0, Rarity(RarityType.Exotic), WeaponType.PointDefenseChainGun)
    turret.turningSpeed = 6
    defenseTurrets[turret] = numDefenseTurrets

    return {numTurrets = numTurrets, turrets = turrets, numDefenseTurrets = numDefenseTurrets, defenseTurrets = defenseTurrets}
end

function RevoltingPrisonShipArena.generateArena(x, y, center, factionIndex)
    local sector = Sector()

    -- create some ambient asteroid fields
    if #{sector:getEntitiesByType(EntityType.Asteroid)} < 15 then
        local asteroidFieldGenerator = AsteroidFieldGenerator()

        local directions = {
            vec3(1, 0, 0),
            vec3(-1, 0, 0),
            vec3(0, 1, 0),
            vec3(0, -1, 0),
            vec3(0, 0, 1),
            vec3(0, 0, -1),
        }

        -- one in the center that is very dense
        local numPoints = random():getInt(100, 150)
        local fieldPosition = center
        local points = asteroidFieldGenerator:generateOrganicCloud(numPoints, fieldPosition, 800)
        asteroidFieldGenerator.asteroidPositions = points
        asteroidFieldGenerator:createAsteroidFieldEx(numPoints, _, 20, 40, false);

        -- more on the outside of the dense field to make arena more memorable
        for i = 1, #directions do
            local numPoints = random():getInt(150, 200)
            local fieldPosition = center + directions[i] * random():getInt(2000, 3000)
            local points = asteroidFieldGenerator:generateOrganicCloud(numPoints, fieldPosition, 1000)
            asteroidFieldGenerator.asteroidPositions = points
            asteroidFieldGenerator:createAsteroidFieldEx(numPoints, _, 20, 40, false);
        end
    end

    -- remove old satellites
    for _, entity in pairs({sector:getEntitiesByScriptValue("prisonship_satellite")}) do
        sector:deleteEntity(entity)
    end

    -- add expired energy suppressors
    local dist = 500
    local satellitePositions = {
        {x = dist, y = 0},
        {x = -dist, y = dist},
        {x = -dist, y = -dist},
    }

    local matrix = Matrix()

    for _, position in pairs(satellitePositions) do
        local pos = center + vec3(position.x, position.y, 0)
        matrix.position = pos
        RevoltingPrisonShipArena.generateEnergySuppressor(matrix, factionIndex)
    end
end

function RevoltingPrisonShipArena.generateEnergySuppressor(position, factionIndex)
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
       ComponentType.Name,
       ComponentType.Owner,
       ComponentType.Durability,
       ComponentType.PlanMaxDurability,
       ComponentType.InteractionText,
       ComponentType.EnergySystem
       )

    local faction = Faction(factionIndex)
    local plan = PlanGenerator.makeStationPlan(faction)
    plan:forceMaterial(Material(MaterialType.Iron))

    local s = 15 / plan:getBoundingSphere().radius
    plan:scale(vec3(s, s, s))
    plan.accumulatingHealth = true

    desc.position = position
    desc:setMovePlan(plan)
    desc.factionIndex = factionIndex

    local satellite = Sector():createEntity(desc)
    satellite.title = "Energy Signature Suppressor"%_T
    satellite.name = "- Burned Out -"%_T

    satellite:setValue("prisonship_satellite", true)
end

function RevoltingPrisonShipArena.getBeaconDialog()
    local dialog = {}

    dialog.text = "TB-0541"%_t .. "\n" .. "The prisoners seem restless lately. We should calm them down quickly. There's already been a small riot in cell block A4R. I'm glad to be far away from it. Everything is quiet here so far."%_t .. "\n\n" ..
    "TB-0653:"%_t .. "\n" .. "Today there was a riot in the whole B7 section. We had to seal off the area completely. I hope that all colleagues were evacuated in time. I have a feeling we're losing control. But the boss has already called for reinforcements from home."%_t .. "\n\n" ..
    "TB-0837:"%_t .. "\n" .. "By now, alarms are going off all the time! I do not know where to go. I'm afraid it's going off on me too! Parts of the ship are completely under their control! Those damn reinforcements must be there before the armory falls!!!"%_t .. "\n\n" ..
    "TB-1345:"%_t .. "\n" .. "Where's that damn backup? It's getting tight! Some prisoners have found uniforms! We can't trust anyone anymore!"%_t .. "\n\n" ..
    "TB-1498:"%_t .. "\n" .. "The armory has fallen!! We are retreating as far as we can! WHERE IS OUR REINFORCEMENT?!!"%_t .. "\n\n" ..
    "TB-1623:"%_t .. "\n" .. "they are almost here... we can already hear them screaming... the door is breached... they are coming.... /* lowercase on purpose */"%_t .. "\n\n" ..
    "TB-1624:"%_t .. "\n" .. "fancy diary, this is now mine. was probably nix with reinforcement. maybe next time? xD"%_t

    return dialog
end

function RevoltingPrisonShipArena.getBossChatter()
    local chatterLines =
    {
        "You will be destroyed! We cannot use any witnesses!"%_t,
        "We will not let our freedom be taken away from us anymore!"%_t,
        "We got our guards, we'll get you too!"%_t,
        "You must be the reinforcements? Unfortunately too late!"%_t,
    }

    return chatterLines
end
