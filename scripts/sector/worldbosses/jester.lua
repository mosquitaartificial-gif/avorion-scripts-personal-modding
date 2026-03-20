package.path = package.path .. ";data/scripts/lib/?.lua"

include ("galaxy")
include ("utility")
local WorldBossUT = include ("worldbossutility")
local LegendaryTurretGenerator = include ("internal/common/lib/legendaryturretgenerator.lua")
local AsteroidFieldGenerator = include ("asteroidfieldgenerator")
local SectorTurretGenerator = include ("sectorturretgenerator")
local SectorGenerator = include ("SectorGenerator")
local PlanGenerator = include ("plangenerator")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace JesterArena
JesterArena = {}

function JesterArena.initialize(position)
    if onClient() then return end

    JesterArena.trySpawnBoss()

    local sector = Sector()
    sector:registerCallback("onPlayerEntered", "onPlayerEntered")
    sector:registerCallback("showWorldBossStartFightChatter", "showWorldBossStartFightChatter")
end

function JesterArena.onPlayerEntered(playerIndex)
    JesterArena.trySpawnBoss()
end

function JesterArena.showWorldBossStartFightChatter()
    local sector = Sector()
    local boss = sector:getEntitiesByScript("worldboss.lua")
    if not boss then return end

    sector:broadcastChatMessage(boss, ChatMessageType.Chatter, "WE BRING COLOR! COLOR FOR EVERYONE!"%_t)
end

function JesterArena.trySpawnBoss()
    local sector = Sector()
    if WorldBossUT.canSpawn(sector:getValue("worldboss_defeated")) then
        local factionName = "Clowns"%_T
        local faction = WorldBossUT.getFaction(factionName)
        local x, y = sector:getCoordinates()

        local bossTitle = "The Jester"%_t
        local bossPlan = JesterArena.getBossPlan(x, y, faction)
        local bossChatterLines = JesterArena.getBossChatter()
        local bossData = {title = bossTitle, plan = bossPlan, chatterLines = bossChatterLines}

        local beaconTitle = "Captain's Log"%_t
        local text = beaconTitle
        local beacon = {title = beaconTitle, interactionText = text}

        local generator = LegendaryTurretGenerator()
        local specialLoot = InventoryTurret(generator:generatePartyTrumpet(x, y, 0))

        local turretData = JesterArena.getTurretData()

        local boss = WorldBossUT.generateBoss(faction, bossData, beacon, specialLoot, turretData)

        local cargospace = math.min(100, boss.freeCargoSpace)
        local good = goods["Paint"]:good()
        amount = math.floor(cargospace / good.size)
        boss:addCargo(good, amount)

        JesterArena.generateArena(x, y, boss.translationf)
    end
end

function JesterArena.getBossPlan(x, y, faction)
    local volume = WorldBossUT.getBossVolume()
    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))
    local bossPlan = PlanGenerator.makeShipPlan(faction, volume, nil, material)

    for _, index in pairs({bossPlan:getBlockIndices()}) do
        bossPlan:setBlockColor(index, ColorRGB(random():getFloat(0.1, 0.75), random():getFloat(0.1, 0.75), random():getFloat(0.1, 0.75)))
    end

    return bossPlan
end

function JesterArena.getTurretData()
    local x, y = Sector():getCoordinates()

    local turrets = {}
    local numTurrets = Balancing_GetEnemySectorTurrets(x, y) * 2
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false

    -- generate lots of different weapons, so that we get versatile shot colors
    for i = 1, math.floor(numTurrets / 3) - 2 do
        local laser = generator:generate(x, y, 0, Rarity(RarityType.Exotic), WeaponType.Laser)
        laser.turningSpeed = 6
        turrets[laser] = 1
    end

    for i = 1, math.floor(numTurrets / 3) do
        local turret = generator:generate(x, y, 0, Rarity(RarityType.Exotic), WeaponType.PlasmaGun)
        turret.turningSpeed = 6
        turrets[turret] = 1
    end

    for i = 1, math.floor(numTurrets / 3) do
        local turret = generator:generate(x, y, 0, Rarity(RarityType.Exotic), WeaponType.Bolter)
        turret.turningSpeed = 6
        turrets[turret] = 1
    end

    -- add party trumpets as this boss' specialty
    local generator = LegendaryTurretGenerator()
    local turret = generator:generatePartyTrumpet(x, y, 0, nil, Rarity(RarityType.Exotic))
    turrets[turret] = 2

    return {numTurrets = numTurrets, turrets = turrets}
end

function JesterArena.generateArena(x, y, position)
    local asteroidFieldGenerator = AsteroidFieldGenerator()
    local sectorGenerator = SectorGenerator(x, y)
    local rnd = random()
    local sector = Sector()

    for i = 1, 4 do
        local fieldPosition = position + rnd:getDirection() * rnd:getInt(1000, 1500)
        local points = asteroidFieldGenerator:generateOrganicCloud(150, fieldPosition, nil)

        for _, location in pairs(points) do
            local isAsteroid = false
            local plan

            -- randomly replace some asteroids with containers or big asteroids
            if rnd:test(0.1) then
                if rnd:test(0.5) then
                    plan = PlanGenerator.makeContainerPlan()
                else
                    plan = PlanGenerator.makeBigAsteroidPlan(rnd:getFloat(65, 80), false)
                    isAsteroid = true
                end
            else
                plan = PlanGenerator.makeSmallAsteroidPlan(rnd:getFloat(5.0, 25.0), false)
                isAsteroid = true
            end

            for _, index in pairs({plan:getBlockIndices()}) do
                plan:setBlockColor(index, ColorHSV(rnd:getInt(0, 360), 1.0, 1.0))
            end

            local matrix = MatrixLookUpPosition(rnd:getDirection(), rnd:getDirection(), location)
            if isAsteroid then
                sector:createAsteroid(plan, false, matrix)
            else
                sectorGenerator:createContainer(plan, matrix, nil)
            end
        end
    end
end

function JesterArena.getBeaconDialog()
    local dialog = {}

    local x, y = Sector():getCoordinates()
    local language = Language(Seed(x..y))
    local crewMember1 = language:getName()
    local crewMember2 = language:getName()
    local crewMember3 = language:getName()

    dialog.text = "Captain's Log G23-1863"%_t .. "\n" .. "Our voyage continues without any major incidents. However, there was a minor inconvenience today when the ship was struck by a strange flash of light. The flash seems to have come from the nearby crack. Fortunately, nothing was damaged."%_t .. "\n\n" ..
    "Captain's Log G26-2934"%_t .. "\n" .. "I noticed that our ship looks really boring. ${crewMember1} and ${crewMember2} have started painting some walls. I decided to spend more paints and the crew is now enthusiastically beautifying the corridors of our ship."%_t % {crewMember1 = crewMember1, crewMember2 = crewMember2} .. "\n\n" ..
    "Captain's Log G28-5634"%_t .. "\n" .. "We did it! Not the smallest corner is still gray! But it seems that some crew members are permanently addicted to the old dreariness. We will have to find a way to still convince even the boring ones."%_t .. "\n\n" ..
    "Captain's Log G29-5872"%_t .. "\n" .. "The new uniforms are ready. Gone are the days of monochrome! From now on there is a one week arrest for wearing the old uniforms!"%_t .. "\n\n" ..
    "Captain's Log G30-3457"%_t .. "\n" .. "The view from the bridge has become almost IMPOSSIBLE. We had to act and also make the outside of our ship COLORFUL! The crew started full of EXCITEMENT. We created a WONDERFUL WORK. COLOR EVERYWHERE!!!"%_t .. "\n\n" ..
    "Captain's Log G30-6599"%_t .. "\n" .. "It's ENOUGH now! ${crewMember3} has refused the new uniforms until today. No more arrest will do for this CRIME!"%_t % {crewMember3 = crewMember3}.. "\n\n" ..
    "Captain's Log G32-6751"%_t .. "\n" .. "I CAN'T TAKE IT ANYMORE! THE WHOLE GALAXY IS GRAY! COLOR IS NEEDED! WE WILL ERADICATE THIS MONOTONY! COLOR OR DEATH!!!!"%_t
    return dialog
end

function JesterArena.getBossChatter()
    local chatterLines =
    {
        "Get colored!"%_t,
        "Your greyness is disgusting!"%_t,
        "COLOR OR DEATH!!"%_t,
        "Do you see that? COLOR, the whole sector COLOR!"%_t,
        "... Mallow ... Topaz ... Sage ... Loden green ... Chartreuse ... Umber ..."%_t
    }

    return chatterLines
end
