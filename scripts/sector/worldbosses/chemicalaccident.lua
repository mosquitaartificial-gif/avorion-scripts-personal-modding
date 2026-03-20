package.path = package.path .. ";data/scripts/lib/?.lua"

local WorldBossUT = include("worldbossutility")
local SectorTurretGenerator = include ("sectorturretgenerator")
local LegendaryTurretGenerator = include ("internal/common/lib/legendaryturretgenerator.lua")
local PlanGenerator = include("plangenerator")
local AsteroidFieldGenerator = include ("asteroidfieldgenerator")
local SectorGenerator = include ("SectorGenerator")
local StyleGenerator = include ("internal/stylegenerator.lua")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace ChemicalAccidentArena
ChemicalAccidentArena = {}

function ChemicalAccidentArena.initialize()
    if onClient() then return end

    ChemicalAccidentArena.trySpawnBoss()

    local sector = Sector()
    sector:registerCallback("onPlayerEntered", "onPlayerEntered")
    sector:registerCallback("showWorldBossStartFightChatter", "showWorldBossStartFightChatter")
end

function ChemicalAccidentArena.onPlayerEntered(playerIndex)
    ChemicalAccidentArena.trySpawnBoss()
end

function ChemicalAccidentArena.showWorldBossStartFightChatter()
    local sector = Sector()
    local boss = sector:getEntitiesByScript("worldboss.lua")
    if not boss then return end

    sector:broadcastChatMessage(boss, ChatMessageType.Chatter, "WE'RE GOING TO KICK YOUR ASS!!!"%_t)
end

function ChemicalAccidentArena.trySpawnBoss()
    local sector = Sector()
    local x, y = sector:getCoordinates()

    if WorldBossUT.canSpawn(sector:getValue("worldboss_defeated")) then
        local factionName = "ChemCorp"%_T
        local faction = WorldBossUT.getFaction(factionName)

        local rnd = Random(Seed(x..y))
        local serialNumber = makeSerialNumber(rnd, 3, "VX-")
        local bossTitle = "Chemical Transport ${serialNumber}"%_t % {serialNumber = serialNumber}
        local bossChatterLines = ChemicalAccidentArena.getBossChatter()
        local bossPlan = ChemicalAccidentArena.getBossPlan(x, y, faction)
        local bossData = {title = bossTitle, plan = bossPlan, chatterLines = bossChatterLines}

        local beaconTitle = "Voice recordings of the bridge"%_t
        local text = beaconTitle
        local beacon = {title = beaconTitle, interactionText = text}

        -- boss drops the special weapon, that boss uses to fight
        local generator = LegendaryTurretGenerator()
        local specialLoot = InventoryTurret(generator:generateFireflyPlasmaGun(x, y, 0))

        local turretData = ChemicalAccidentArena.getTurretData()

        local boss = WorldBossUT.generateBoss(faction, bossData, beacon, specialLoot, turretData)

        local cargospace = math.min(200, boss.freeCargoSpace)
        local good = goods["Chemicals"]:good()
        amount = math.floor(cargospace / good.size)
        boss:addCargo(good, amount)

        ChemicalAccidentArena.generateArena(x, y, boss.translationf, boss.look)
    end
end

function ChemicalAccidentArena.makeSerialNumber(rnd, length, prefix, postfix)

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

function ChemicalAccidentArena.getBossPlan(x, y, faction)
    local volume = WorldBossUT.getBossVolume() * 2 -- higher volume/hp, fewer turrets/dps
    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))
    local bossPlan = PlanGenerator.makeShipPlan(faction, volume, nil, material)

    local styleGenerator = StyleGenerator(faction.index)
    styleGenerator.factionDetails.paintColor = {r = random():getFloat(0.2, 0.5), g = random():getFloat(0.6, 1.0), b = 0.2}
    styleGenerator.factionDetails.lightColor = {r = 0.4, g = 1.0, b = 0.3}
    styleGenerator.factionDetails.lightLines = true

    local style = styleGenerator:makeGasFreighterStyle(random():createSeed())

    local plan = GeneratePlanFromStyle(style, random():createSeed(), volume, 10000, nil, material)

    return plan
end

function ChemicalAccidentArena.getTurretData()
    local x, y = Sector():getCoordinates()

    local turrets = {}
    local numTurrets = Balancing_GetEnemySectorTurrets(x, y) * 1.5
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false

    local turret = LegendaryTurretGenerator():generateFireflyPlasmaGun(x, y, 0)
    local weapons = {turret:getWeapons()}
    turret:clearWeapons()
    for _, weapon in pairs(weapons) do
        weapon.pcolor = ColorRGB(0.2, 0.75, 0.2)
        weapon.damage = weapon.damage * 2.5
        turret:addWeapon(weapon)
    end
    turret.turningSpeed = 6
    turrets[turret] = math.floor(numTurrets / 3)

    local numDefenseTurrets = Balancing_GetEnemySectorTurrets(x, y) * 1.5
    local defenseTurrets = {}
    local turret = generator:generate(x, y, 0, Rarity(RarityType.Exceptional), WeaponType.PointDefenseChainGun)
    local weapons = {turret:getWeapons()}
    turret:clearWeapons()
    for _, weapon in pairs(weapons) do
        weapon.pcolor = ColorRGB(0.2, 0.75, 0.2)
        turret:addWeapon(weapon)
    end
    turret.turningSpeed = 6
    defenseTurrets[turret] = numDefenseTurrets

    return {numTurrets = numTurrets, turrets = turrets, numDefenseTurrets = numDefenseTurrets, defenseTurrets = defenseTurrets}
end

function ChemicalAccidentArena.generateArena(x, y, position, bossLook)
    local asteroidFieldGenerator = AsteroidFieldGenerator()
    local random = random()
    local sector = Sector()

    if #{sector:getEntitiesByType(EntityType.Asteroid)} < 100 then
        local points = asteroidFieldGenerator:generateOrganicCloud(1000, position, 1500)
        asteroidFieldGenerator.asteroidPositions = points

        asteroidFieldGenerator:createAsteroidFieldEx(350, _, 15.0, 35.0, false);
    end

    if #{sector:getEntitiesByType(EntityType.Container)} < 50 then
        local plan = LoadPlanFromFile("data/plans/barrel.xml")
        plan:center()
        plan.accumulatingHealth = false

        local generator = SectorGenerator(x, y)

        local numFields = 3
        local radius = 750
        for i = 1, numFields do
            local angle = 2 * math.pi * i / numFields
            local look = vec3(math.cos(angle), math.sin(angle), 0)

            local position = position + look * radius
            local matrix = MatrixLookUpPosition(look, bossLook, position) -- use boss.look as up, so that field "lies" flat next to boss
            local containers = generator:createContainerField(30, 20, 1, matrix, nil, 0, plan)

            for _, container in pairs(containers) do
                local hue = random:getInt(60, 105)
                if random:test(0.2) then
                    container:setValue("chemicalaccident_broken_barrel", true)
                    hue = 5
                end

                ChemicalAccidentArena.colorGlowBlocks(container, ColorHSV(hue, 1, random:getFloat(0.5, 0.8)))
            end
        end
    end
end

function ChemicalAccidentArena.colorGlowBlocks(entity, color)
    local plan = entity:getFullPlanCopy()
    for _, index in pairs({plan:getBlockIndices()}) do
        local blocktype = plan:getBlockType(index)
        if blocktype == BlockType.Glow then
            plan:setBlockColor(index, color)
        end
    end

    entity:setMovePlan(plan)
end

local fogDataSet = false
function ChemicalAccidentArena.updateClient()
    if not fogDataSet then
        ChemicalAccidentArena.setFogVisuals()
        fogDataSet = true
    end

    -- update toxic clouds of barrels
    local sector = Sector()
    local barrels = {sector:getEntitiesByScriptValue("chemicalaccident_broken_barrel")}
    local cameraPosition = Player().cameraEye

    -- all barrels are the same - we can use the same spark properties for each one
    local rand = random()
    local size = rand:getFloat(0.2, 0.3) * 4.8
    local lifetime = rand:getFloat(3.8, 4.2)
    local speed = rand:getDirection() * 1.3
    local color = ColorHSV(rand:getInt(65, 120), 0.5, rand:getFloat(0.3, 0.4))

    for _, barrel in pairs(barrels) do
        local d2 = distance2(cameraPosition, barrel.translationf)
        if d2 > 500 * 500 then
            goto continue
        end

        sector:createSpark(barrel.translationf, speed, size, lifetime, color, 0)
        ::continue::
    end
end

function ChemicalAccidentArena.setFogVisuals()
    local sector = Sector()
    sector:setFogColor(ColorRGB(1.0, 1.0, 0.2))
    sector:setFogColorFactor(1.5)
    sector:setFogDensity(3)
end

function ChemicalAccidentArena.getBeaconDialog()
    local dialog = {}

    local x, y = Sector():getCoordinates()
    local language = Language(Seed(x..y))
    local aggroName = language:getName()
    local victimName = language:getName()

    dialog.text = "Entry 175/1/4:\n\"Captain! We have detected a leak from a container in the cargo hold. It is section C-17. A sealing crew has already been alerted.\""%_t .. "\n\n" ..
    "Entry 175/2/4:\n\"There are problems with the waterproofing crew. They are arguing about who gets to apply the waterproofing material.\""%_t .. "\n\n" ..
    "Entry 175/2/5:\n\"This is nonsense! Such a nothingness! Then let the other one do it next time...\""%_t .. "\n\n" ..
    "Entry 175/3/3:\n\"The sealing does not seem to have been done properly. We have another warning message here!\""%_t .. "\n...\n" ..
    "\"Hey ${aggroName}, what is this? Abort, abort! Leave him alone right now! Damn it! Captain! ${aggroName} just hit ${victimName}!\""%_t % {aggroName = aggroName, victimName = victimName} .. "\n\n" ..
    "Entry 175/3/5:\n\"This can't be happening! ${aggroName} will be detained immediately. I want peace and order on my ship.\""%_t % {aggroName = aggroName} .. "\n\n" ..
    "Entry 175/6/4:\n\"The violence continues! Captain, what should we do? It seems like the whole crew is slowly going crazy! WHAT DO WE DO NOW?\""%_t .. "\n\n" ..
    "Entry 175/12/4:\n\"THEY ARE HERE! LOCK ALL DOORS!\""%_t .. "\n\n" ..
    "Entry 175/13/4:\n\"SLAUGHTER THEM!\"\n\"FINISH THEM!\"\n\"FINALLY! THE SHIP IS OURS!\""%_t

    return dialog
end

function ChemicalAccidentArena.getBossChatter()
    local chatterLines =
    {
        "COME HERE, COWARD!!"%_t,
        "RAAAAAAAAAHHH!"%_t,
        "WE'RE GOING TO KICK YOUR ASS!!!"%_t,
        "DESTROY!!"%_t,
        "WE WILL SQUASH YOU!!"%_t,
    }

    return chatterLines
end
