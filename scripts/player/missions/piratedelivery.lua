package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("structuredmission")
include ("stringutility")
include ("defaultscripts")
include ("utility")
include ("goods")
include ("callable")
include("randomext")

local Balancing = include ("galaxy")
local AsyncPirateGenerator = include("asyncpirategenerator")
local SectorTurretGenerator = include ("sectorturretgenerator")
local SpawnUtility = include ("spawnutility")

mission.data.timeLimit = 3600
mission.data.timeLimitInDescription = true

mission.data.brief = "Urgent delivery of unknown origin."%_t
mission.data.title = "Urgent Delivery"%_t

mission.data.accomplishMessage = nil -- there is no mission giver, it came in via radio broadcast
mission.data.finishMessage = nil
mission.data.description = {}

mission.globalPhase = {}

mission.globalPhase.onBeginServer = function()
    local currentX, currentY = Sector():getCoordinates()
    local startInsideBarrier = MissionUT.checkSectorInsideBarrier(currentX, currentY)
    local x, y = MissionUT.getSector(currentX, currentY, 5, 8, false, false, false, false)

    if x == nil or y == nil then
        finish()
        return
    end

    local targetInsideBarrier = MissionUT.checkSectorInsideBarrier(x, y)

    if startInsideBarrier ~= targetInsideBarrier then return end

    local good = getRequiredGood()
    local amount = getRequiredAmount(good, x, y)

    mission.data.location = {x = x, y = y}
    mission.data.custom.requiredGood = good
    mission.data.custom.requiredGoodAmount = amount

    local tradingGood = tableToGood(good)
    Player():sendChatMessage("Unknown"%_t, ChatMessageType.Normal, "This is an emergency! We need someone to deliver us %1% %2% to \\s(%3%,%4%) in one hour! We'll pay you 4x the regular price."%_T, amount, tradingGood:pluralForm(amount), x, y)

    mission.data.description[1] = {text = "You have received a radio message of unknown origin. Someone is asking you to deliver ${amount} ${good} to a specific location. They are saying it is an emergency."%_T, arguments = {amount = amount, good = good.name}}
end

mission.phases[1] = {}
mission.phases[1].onTargetLocationEntered = function (x, y)
    if onClient() then return end

    if playerHasRequiredCargo() then
        mission.data.timeLimit = nil
        mission.data.timeLimitInDescription = false
        mission.data.failMessage = nil
        nextPhase()
    end
end


mission.phases[2] = {}
mission.phases[2].onBeginServer = function()
    createPirate()
end

mission.phases[2].triggers = {}
mission.phases[2].triggers[1] =
{
    condition = function() return checkPirateCreated() end,
    callback = function() onStartDialog() end
}

mission.phases[3]= {}
mission.phases[3].onTargetLocationLeft = function(x, y)
    fail()
end
mission.phases[3].updateServer = function(timestep)
    if MissionUT.countPirates() <= 0 then
        accomplish()
    end
end

mission.phases[3].timers = {}
mission.phases[3].timers[1] = {callback = function() onDeliveredRequestBackup() end}
mission.phases[3].timers[2] = {callback = function() generateBackup() end}
mission.phases[3].timers[3] = {callback = function() generateBackup() end}

function getRequiredGood()
    local goodNames = {"Ammunition", "Body Armor", "Targeting System", "War Robot", "Warhead", "Explosive Charge"}
    local rand = random():getInt(1, #goodNames)
    local goodName = goodNames[rand]
    local good = goods[goodName]

    return good
end

function getRequiredAmount(good, x, y)
    local value = Balancing_GetSectorRichnessFactor(x, y) * 50000
    local amount = math.ceil(value / good.price)

    return amount
end

function sendChatMessage(message)
    displayChatMessage(message, "Anonymous", 0)
end

function playerHasRequiredCargo()
    local craft = Player().craft
    if not craft then return false end

    local amount = craft:getCargoAmount(mission.data.custom.requiredGood.name)
    if not amount then amount = 0 end
    return amount >= mission.data.custom.requiredGoodAmount
end

function checkPirateCreated()
    if onServer() then return false end

    local pirate
    if mission.data.custom.pirateId then
        pirate = Entity(mission.data.custom.pirateId)
    end

    return pirate ~= nil
end

function onStartDialog()
    if onServer() then return end

    local dialog = pirateDialog()
    local scriptUI = ScriptUI(mission.data.custom.pirateId)
    scriptUI:interactShowDialog(dialog, false)
end

function createPirate()
    local dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
    local up = vec3(0, 1, 0)
    local pos = dir * 1000

    local generator = AsyncPirateGenerator(nil, onPirateCreated)

    generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos))
end

function onPirateCreated(pirate)
    mission.data.custom.pirateId = pirate.id.string
    ShipAI(pirate.id):setPassive()

    local loot = Loot(pirate.id)
    -- reward: an upgrade or a turret with the possibility to get both
    local rand = random():getInt(1, 9)
    if rand <= 5 then loot:insert(generateUpgrade()) end
    if rand >= 5 then loot:insert(generateTurret()) end

    local playerShip = Player().craft
    local distance = playerShip:getBoundingSphere().radius + pirate:getBoundingSphere().radius + (150 * random():getFloat(0.8, 1.2))
    local position = playerShip.translationf + playerShip.look * distance
    pirate.translation = dvec3(position.x, position.y, position.z)

    sync()
end

function pirateDialog()
    local d0_DoYouHaveTheGoo = {}
    local d1_LovelyAndNowGiv = {}
    local d2_SureIAmAndNow = {}
    local d3_HahahLetsGetOut = {}
    local d4_ThenDIE = {}

    d0_DoYouHaveTheGoo.text = "Do you have the goods?"%_t
    d0_DoYouHaveTheGoo.answers = {
        {answer = "Yes, I've got them all."%_t, followUp = d1_LovelyAndNowGiv},
        {answer = "I won't give them to you!"%_t, followUp = d4_ThenDIE}
    }

    d1_LovelyAndNowGiv.text = "Lovely.\n\nAnd now hand them over!"%_t
    d1_LovelyAndNowGiv.answers = {
        {answer = "Here you go. "%_t, followUp = d3_HahahLetsGetOut},
        {answer = "Wait, aren't you a pirate?"%_t, followUp = d2_SureIAmAndNow},
    }

    d2_SureIAmAndNow.text = "I don't know what you're talking about. Give me the goods and don't ask stupid questions! I don't want to have to hurt you."%_t
    d2_SureIAmAndNow.answers = {
         {answer = "Ok, I don't want any trouble."%_t, followUp = d3_HahahLetsGetOut},
         {answer = "No, I can't give that to a pirate!"%_t, followUp = d4_ThenDIE}
     }

     d3_HahahLetsGetOut.text = "Hahah, let's get out of here."%_t
     d3_HahahLetsGetOut.onEnd = "onGoodsDelivered"

     d4_ThenDIE.text = "Then DIE!"%_t
     d4_ThenDIE.onEnd = "onDeliveryRefusedRequestBackup"

     return d0_DoYouHaveTheGoo
 end

function onGoodsDelivered()
    if onClient() then
        invokeServerFunction("onGoodsDelivered")
        return
    end

    local ship = Player().craft
    ship:removeCargo(mission.data.custom.requiredGood.name, mission.data.custom.requiredGoodAmount)

    local pirateShip = Entity(mission.data.custom.pirateId)
    local tradingGood = tableToGood(mission.data.custom.requiredGood)
    pirateShip:addCargo(tradingGood, mission.data.custom.requiredGoodAmount)

    -- delayed: call for backup
    mission.phases[3].timers[1].time = 5
    -- delayed: spawn backup
    mission.phases[3].timers[2].time = 20
    ShipAI(mission.data.custom.pirateId):setAggressive()

    nextPhase()
end
callable(nil, "onGoodsDelivered")

function onDeliveredRequestBackup()
    if onClient() then return end

    local pirate = Entity(mission.data.custom.pirateId)
    if not pirate then return end

    Player():sendChatMessage(pirate, ChatMessageType.Normal, "My bloody hyperspace engine is still charging. I need backup NOW!"%_T)
    ShipAI(pirate):setAggressive()

end

function onDeliveryRefusedRequestBackup()
    if onClient() then
        invokeServerFunction("onDeliveryRefusedRequestBackup")
        return
    end

    local pirate = Entity(mission.data.custom.pirateId)
    if not pirate then return end

    Player():sendChatMessage(pirate, ChatMessageType.Normal, "This one seems to wanna play games. Let's teach them a little lesson!"%_T)
    ShipAI(pirate):setAggressive()

    mission.phases[3].timers[3].time = 5
    nextPhase()
end
callable(nil, "onDeliveryRefusedRequestBackup")

function generateBackup()
    if onClient() then
        invokeServerFunction("generateBackup")
        return
    end

    local dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
    local up = vec3(0, 1, 0)
    local right = normalize(cross(dir, up))
    local pos = dir * 1000
    local distance = 50

    local generator = AsyncPirateGenerator(nil, onBackupGenerated)
    local amount = random():getInt(3, 5)

    generator:startBatch()

    for i = 1, amount do
        if i <= 2 then
            generator:createScaledOutlaw(MatrixLookUpPosition(-dir, up, pos + right * distance * (i - 1)))
        elseif i <= 4 then
            generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos + right * distance * (i - 1)))
        else
            generator:createScaledOutlaw(MatrixLookUpPosition(-dir, up, pos + right * distance * (i - 1)))
        end
    end

    generator:endBatch()
end
callable(nil, "generateBackup")

function onBackupGenerated(generated)
    -- for testing
    mission.data.custom.backupGenerated = true

    -- add enemy buffs
    SpawnUtility.addEnemyBuffs(generated)
end

function generateUpgrade()
    local upgrades = {
        "data/scripts/systems/arbitrarytcs.lua",
        "data/scripts/systems/militarytcs.lua",
        "data/scripts/systems/defensesystem.lua",
        "data/scripts/systems/radarbooster.lua",
        "data/scripts/systems/scannerbooster.lua",
        "data/scripts/systems/valuablesdetector.lua",
    }
    local randUpgrades = random():getInt(1, #upgrades)
    local upgradeName = upgrades[randUpgrades]

    local rarities = {2, 2, 2, 3, 3, 3, 3, 4}
    local randRarities = random():getInt(1, #rarities)
    local rarity = rarities[randRarities]

    return SystemUpgradeTemplate(upgradeName, Rarity(rarity), random():createSeed())
end

function generateTurret()
    local weaponTypes = {}
    weaponTypes[WeaponType.ChainGun] = 1
    weaponTypes[WeaponType.Laser] = 1
    weaponTypes[WeaponType.PlasmaGun] = 1
    weaponTypes[WeaponType.RocketLauncher] = 1
    weaponTypes[WeaponType.Cannon] = 1
    weaponTypes[WeaponType.RailGun] = 1
    weaponTypes[WeaponType.Bolter] = 1
    weaponTypes[WeaponType.LightningGun] = 1
    weaponTypes[WeaponType.TeslaGun] = 1
    weaponTypes[WeaponType.PulseCannon] = 1

    local rarities = {}
    rarities[RarityType.Rare] = 3
    rarities[RarityType.Exceptional] = 4
    rarities[RarityType.Exotic] = 1


    local probabilities = Balancing_GetMaterialProbability(Sector():getCoordinates())
    local materials = {}
    materials[0] = probabilities[0]
    materials[1] = probabilities[1]
    materials[2] = probabilities[2]
    materials[3] = probabilities[3]
    materials[4] = probabilities[4]
    materials[5] = probabilities[5]
    materials[6] = probabilities[6]

    local x, y = Sector():getCoordinates()

    local rarity = selectByWeight(random(), rarities)
    local material = selectByWeight(random(), materials)
    local weaponType = selectByWeight(random(), weaponTypes)

    return InventoryTurret(SectorTurretGenerator():generate(x, y, 0, Rarity(rarity), weaponType, Material(material)))
end
