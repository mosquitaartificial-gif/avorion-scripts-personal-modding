package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("structuredmission")
include ("utility")
include ("callable")
include("randomext")

local SectorSpecifics = include ("sectorspecifics")
local Balancing = include ("galaxy")
local AsyncPirateGenerator = include("asyncpirategenerator")
local ShipGenerator = include ("shipgenerator")
local Placer = include("placer")
local SpawnUtility = include ("spawnutility")
local MissionUT = include ("missionutility")

--mission.tracing = true

-- mission data
mission.data.title = "Transfer Vessel"%_t
mission.data.brief = mission.data.title

mission.data.autoTrackMission = true

mission.data.description = {}
mission.data.description[1] = "We need a good pilot with a little time on their hands. We have this gorgeous little ship here that needs to be transported to a wealthy client. Easy money for an experienced pilot!"%_T
-- mission.data.description[2] -- defined somewhere else
mission.data.description[3] = {text = "Report to ${entityType} ${entityName} to complete the job"%_T, bulletPoint = true, visible = false}

mission.data.accomplishMessage = "The vessel was successfully transferred."%_t
mission.data.failMessage = "We gave you more than enough time to get that ship to our customer, and yet we see no ship! We'll keep your deposit as compensation. Don't bother showing up."%_t

mission.data.timeLimit = 25 * 60
mission.data.timeLimitInDescription = true

-- custom mission data
mission.data.custom.shipBeginMoneyValue = 0
mission.data.custom.shipDeposit = 0
mission.data.custom.shipToTransferId = nil
mission.data.custom.shipToTransferName = nil
mission.data.custom.contactId = nil

-- test whether the ship is destroyed on the way
mission.globalPhase = {}
mission.globalPhase.updateServer = function()
    if mission.data.custom.shipToTransferId then
        local player = Player()
        if player:getShipDestroyed(mission.data.custom.shipToTransferName) then
            player:removeDestroyedShipInfo(mission.data.custom.shipToTransferName)
            mission.data.failMessage = "You lost the ship we entrusted you with. You won't see any of your deposit back!"%_T
            fail()
        end
    end
end
mission.globalPhase.onFail = function()
    local entity = Entity(mission.data.custom.shipToTransferId)
    if valid(entity) then
        Sector():deleteEntity(entity)
    end
end

-- Phase 1: Calculate all necessary values and spawn ship
mission.phases[1] = {}
mission.phases[1].onBeginServer = function()
    local ship = createShip()
    mission.data.custom.shipBeginMoneyValue = Entity(ship.id):getPlanMoneyValue()

    -- set deposit higher than actual value of the ship to prevent players from keeping or selling it
    mission.data.custom.shipDeposit = math.floor(mission.data.custom.shipBeginMoneyValue * 1.5)
end
mission.phases[1].updateServer = function()
    if mission.data.custom.shipToTransferId then
        setPhase(2)
    end
end

-- Phase 2: Have player accept mission and "terms and services"
mission.phases[2] = {}
local dialogStarted = false
mission.phases[2].updateClient = function()
    if not dialogStarted then
        if not mission.data.custom.shipToTransferId then sync() return end

        ScriptUI(mission.data.custom.shipToTransferId):interactShowDialog(startDialog(), false)
        dialogStarted = true
    end
end

-- Phase 3: Give player ship and send them on their journey - spawn pirates along the way
mission.phases[3] = {}
mission.phases[3].onBeginServer = function()
    mission.data.description[2] = {text = "Fly the ship to sector (${x}:${y})"%_T, arguments = {x = mission.data.location.x, y = mission.data.location.y}, bulletPoint = true, fulfilled = false}

    -- entity may not be here, if we already were in phase 4 and got reset
    local entity = Entity(mission.data.custom.shipToTransferId)
    if entity then
        entity.factionIndex = Player().index

        -- mark ship
        showShipToTransferHint()
    end
end
mission.phases[3].updateServer = function()
    -- if player arrived independently from ship and before that ship got here
    -- we can still continue to phase 4
    if MissionUT.playerInTargetSector(Player(), mission.data.location) then
        local entity = Sector():getEntitiesByScriptValue("transfer_vessel_"..mission.data.custom.shipToTransferName)
        if entity then
            setPhase(4)
        end
    end
end
mission.phases[3].onSectorEntered = function (x, y)
    if onClient() then return end
    local regular, offgrid, blocked, home = SectorSpecifics():determineContent(x, y, Server().seed)
    if not regular and not home then
        local random = random():getFloat(0, 1)
        if random >= 0.75 then
            spawnPirates()
        end
    end
end
mission.phases[3].onTargetLocationEnteredReportedByClient = function()
    -- player flew the ship here, we can be sure that id is still the same
    if Player().craftIndex.string == mission.data.custom.shipToTransferId then
        nextPhase()
        return
    end
end

-- Phase 5: Dialog and finish up
mission.phases[4] = {}
mission.phases[4].onBegin = function()
    if onClient() then
        Player():registerCallback("onPreRenderHud", "onPreRenderHud") -- in case the dialog isn't working, the player gets contact marked and can talk to him later
        return
    end

    local contact = findOrSpawnContact()
    mission.data.custom.contactId = contact.id.string

    mission.data.description[2].fulfilled = true
    mission.data.description[3].arguments = {entityType = contact.translatedTitle, entityName = contact.name}
    mission.data.description[3].visible = true
    sync()
end
mission.phases[4].updateClient = function(timestep)
    if not mission.data.custom.interacted and mission.data.custom.contactId then
        -- start dialog
        local scriptUi = ScriptUI(mission.data.custom.contactId)
        if not scriptUi then return end
        scriptUi:interactShowDialog(finishDialog(), false)

        -- this highlights contact as interesting object and draws a little arrow
        mission.data.custom.interacted = true
    end
end
mission.phases[4].onStartDialog = function(entityId)
    print(mission.data.custom.contactId)
    if entityId.string == mission.data.custom.contactId then
        local scriptUi = ScriptUI(mission.data.custom.contactId)
        scriptUi:addDialogOption("[Deliver Ship]"%_t, "showFinishDialog")
    end
end
mission.phases[4].onTargetLocationLeft = function()
    mission.data.description[2].fulfilled = false
    mission.data.description[3].visible = false
    setPhase(3)
end
mission.phases[4].onRestore = function()
    mission.phases[4].onBegin()
end
mission.phases[4].timers = {}
mission.phases[4].timers[1] = {
    callback = function() onStartAIBehavior() end
}

function findOrSpawnContact()
    local station = Sector():getEntitiesByType(EntityType.Station)
    local contact = nil
    local count = 0

    if station then
        contact = station
    else
        contact = createShip()
        contact:addScript("data/scripts/entity/utility/basicinteract.lua")
    end

    return contact
end

-- helper functions
function createShip()
    if onClient() then invokeServerFunction("createShip") return end

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates()) -- don't use mission.giver faction here, as it might be the players faction
    local volume = Balancing_GetSectorShipVolume(faction:getHomeSectorCoordinates())

    local ship = ShipGenerator.createShip(faction, Matrix(), volume)
    if mission.currentPhase == mission.phases[4] then
        mission.data.custom.contactId = ship.id.string
        ship:setTitle("${giver}'s Contact"%_T, {giver = mission.data.giver.baseTitle})
        ship:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
    else
        mission.data.custom.shipToTransferId = ship.id.string
        mission.data.custom.shipToTransferName = ship.name
        ship:setValue("transfer_vessel_" .. ship.name, true)
    end

    syncValues()

    Placer.resolveIntersections()
    return ship
end
callable(nil, "createShip")

function onPreRenderHud()

    local player = Player()
    if not player then return end
    if player.state == PlayerStateType.BuildCraft or player.state == PlayerStateType.BuildTurret or player.state == PlayerStateType.PhotoMode then return end

    if not mission.data.custom.contactId then return end

    local entity = Entity(mission.data.custom.contactId)
    if not entity then return end

    local renderer = UIRenderer()

    renderer:renderEntityTargeter(entity, MissionUT.getBasicMissionColor())
    renderer:renderEntityArrow(entity, 30, 10, 250, MissionUT.getBasicMissionColor())

    renderer:display()
end

function spawnPirates()
    if onClient() then invokeServerFunction("spawnPirates") return end
    local dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
    local up = vec3(0, 1, 0)
    local right = normalize(cross(dir, up))
    local pos = dir * 1000
    local distance = 50

    local generator = AsyncPirateGenerator(nil, onBackupGenerated)
    local amount = random():getInt(3, 4)

    generator:startBatch()

    for i = 1, amount do
        if i <= 3 then
            generator:createScaledOutlaw(MatrixLookUpPosition(-dir, up, pos + right * distance * (i - 1)))
        elseif i <= 4 then
            generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos + right * distance * (i - 1)))
        end
    end

    generator:endBatch()
end
callable(nil, "spawnPirates")

function onBackupGenerated(generated)
    -- add enemy buffs
    SpawnUtility.addEnemyBuffs(generated)
end

function syncValues(values) -- additional sync just for custom data
    if onServer() then
        invokeClientFunction(Player(), "syncValues", mission.data.custom)
    else
        mission.data.custom = values
    end
end

function showShipToTransferHint()
    if onServer() then invokeClientFunction(Player(), "showShipToTransferHint") return end

    Hud():displayHint("Fly this ship safely to (${x}:${y}).\nPress '${transfer}' to enter it."%_t % {x = mission.data.location.x, y = mission.data.location.y, transfer = tostring(GameInput():getKeyName(ControlAction.TransferPlayer))}, Entity(mission.data.custom.shipToTransferId))
end

function calculateCurrentShipValuePercentage()
    local ship = Sector():getEntitiesByScriptValue("transfer_vessel_"..mission.data.custom.shipToTransferName)
    if not ship then return 0.01 end

    local shipBeginMoneyValue = mission.data.custom.shipBeginMoneyValue
    local shipMoneyValue = ship:getPlanMoneyValue()

    -- Clamp ship value to shipBeginMoneyValue in case player modified the ship
    if shipMoneyValue > shipBeginMoneyValue then
        shipMoneyValue = shipBeginMoneyValue
    end
    return shipMoneyValue / shipBeginMoneyValue
end

function startDialog()
    local d0_Start = {}
    local d1_Finish = {}

    d0_Start.talker = mission.data.giver.baseTitle
    d0_Start.text = "If you want to transfer our vessel, you have to pay a deposit for the ship.\n\nYou will get it back if you bring the ship to the given location. The deposit is set to ${deposit} Credits."%_t % {deposit = createMonetaryString(mission.data.custom.shipDeposit)}
    d0_Start.answers = {
        {answer = "I understand the terms and will pay the ${deposit} Credits."%_t % {deposit = createMonetaryString(mission.data.custom.shipDeposit)}, followUp = secondDialog()},
        {answer = "I don't want to do this anymore."%_t, followUp = d1_Finish}
    }

    d1_Finish.talker = mission.data.giver.baseTitle
    d1_Finish.text = "Okay, we will find someone else willing to help us."%_t
    d1_Finish.onEnd = "abortMission"

    return d0_Start
end

function secondDialog()
    local d0_EnoughMoney = {}
    local d1_NotEnoughMoney = {}

    d0_EnoughMoney.text = "We have taken the money out of your account and will keep it safe until the ship arrives safely."%_t
    d0_EnoughMoney.onEnd = "continueMission"

    d1_NotEnoughMoney.text = "You don't have enough money to pay the necessary deposit. We can't give you this job, sorry."%_t
    d1_NotEnoughMoney.onEnd = "abortMission"

    if Player():canPay(mission.data.custom.shipDeposit) then
        return d0_EnoughMoney
    else
        return d1_NotEnoughMoney
    end
end

function abortMission()
    if onClient() then invokeServerFunction("abortMission") return end
    mission.data.failMessage = nil
    fail() -- there is no 'MISSION ABORTED' so we use failed
end
callable(nil, "abortMission")

function continueMission()
    if onClient() then invokeServerFunction("continueMission") return end

    Player():pay(Format("Paid %1% Credits as deposit for the ship."%_T, createMonetaryString(mission.data.custom.shipDeposit)), mission.data.custom.shipDeposit)
    nextPhase()
end
callable(nil, "continueMission")

function showFinishDialog()
    local scriptUI = ScriptUI(mission.data.custom.contactId)
    scriptUI:interactShowDialog(finishDialog(), false)
end

function finishDialog()
    local d0_Hello = {}
    local d1_Remind = {}

    d0_Hello.text = "Hello. Thank you for transferring the ship. I will take care of it now. We'll just take a quick look at its condition first."%_t
    d0_Hello.answers = {{answer = "Okay."%_t, followUp = d1_Remind}}

    d1_Remind.text = "Did you take all your personal stuff off the ship? If not, do that now and talk to me once you're done!"%_t
    d1_Remind.answers = {
        {answer = "Right, I'll check."%_t},
        {answer = "All clear, go ahead."%_t, followUp = checkConditionDialog()}
    }

    return d0_Hello
end

local cleanUp = makeDialogServerCallback("cleanUp", 4, function()
    local player = Player()
    local craft = player.craft
    local sector = Sector()

    -- throw player out of the ship
    local entity = Sector():getEntitiesByScriptValue("transfer_vessel_"..mission.data.custom.shipToTransferName)
    if craft and craft.id == entity.id then
        player.craftIndex = Uuid()
    end

    local contact = Entity(mission.data.custom.contactId)

    -- now transfer shippie to contact faction and let it do something
    entity.factionIndex = contact.factionIndex
    entity:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
    entity:addScriptOnce("data/scripts/entity/utility/delayeddelete.lua", 60)

    if contact and contact.isShip then
        contact:addScriptOnce("data/scripts/entity/utility/delayeddelete.lua", 60)
    elseif contact then
        ShipAI(entity.id):setFollow(contact, true)
    end

    mission.phases[4].timers[1].time = 3 -- wait a bit so it is less abrupt
end)

function checkConditionDialog()

    local dialog = {}
    local shipValuePercentage = calculateCurrentShipValuePercentage()
    local amount = math.floor(shipValuePercentage * mission.data.custom.shipDeposit)

    dialog.text = "Alright, the scan is done.\n\n"%_t
    if shipValuePercentage == 1 then
        dialog.text = dialog.text .. "No damage detected - you did well with the ship! Thank you. Here's the full deposit back."%_t
    elseif shipValuePercentage >= 0.9 then
        dialog.text = dialog.text .. "Mh, some minor scratches. Well, I guess some scratches are okay. I'll deduct the repair costs from your deposit. You will get ${amount} Credits back."%_t % {amount = amount}
    elseif shipValuePercentage >= 0.5 then
        dialog.text = dialog.text .. "What did you do to the ship? Well, at least it has arrived. The repairs will be expensive, though. Let me see, I guess you can have ${amount} Credits of your deposit back."%_t % {amount = amount}
    else
        dialog.text = dialog.text .. "I don't think we need to talk about the condition of the ship. Take the rest of the deposit and get out of my face."%_t
    end

    dialog.answers = {
        {answer = "You are welcome."%_t},
        {answer = "I did my best."%_t}
    }
    dialog.onEnd = cleanUp

    return dialog
end

function refundDeposit()
    if onClient() then invokeServerFunction("refundDeposit") return end

    local player = Player()

    local refund = math.floor(mission.data.custom.shipDeposit * calculateCurrentShipValuePercentage())
    if player.infiniteResources then refund = 0 end

    player:receive(Format("Got %1% Credits of deposit back."%_T, createMonetaryString(refund)), refund)
end
callable(nil, "refundDeposit")

function onStartAIBehavior()
    local entity = Sector():getEntitiesByScriptValue("transfer_vessel_"..mission.data.custom.shipToTransferName)

    if entity then
        local shipAI = ShipAI(entity)
        shipAI:setFollow(Entity(mission.data.custom.contactId), true)
    end

    refundDeposit()
    reward()
    accomplish()
end

mission.makeBulletin = function(station)
    --find empty sector
    local target = {}
    local x, y = Sector():getCoordinates()
    local giverInsideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    target.x, target.y = MissionUT.getSector(x, y, 10, 12, true, false, false, false)

    if not target.x or not target.y or giverInsideBarrier ~= MissionUT.checkSectorInsideBarrier(target.x, target.y) then return end
    mission.data.location = target

    local balancing = Balancing.GetSectorRewardFactor(Sector():getCoordinates())
    reward = {credits = 50000 * balancing, relations = 6500, paymentMessage = "Earned %1% Credits for transferring a vessel."%_T}
    local materialAmount = round(random():getInt(7000, 8000) / 100) * 100
    MissionUT.addSectorRewardMaterial(x, y, reward, materialAmount)

    punishment = {relations = reward.relations}

    local bulletin =
    {
        -- data for the bulletin board
        brief = mission.data.brief,
        title = mission.data.title,
        description = mission.data.description[1],
        difficulty = "Normal /*difficulty*/"%_T,
        reward = "¢${reward}"%_T,
        script = "missions/transfervessel.lua",
        formatArguments = {x = target.x, y = target.y, reward = createMonetaryString(reward.credits)},
        msg = "Transfer the vessel to \\s(%1%:%2%)."%_T,
        giverTitle = station.title,
        giverTitleArgs = station:getTitleArguments(),
        onAccept = [[
            local self, player = ...
            player:sendChatMessage(Entity(self.arguments[1].giver), 0, self.msg, self.formatArguments.x, self.formatArguments.y)
        ]],

        -- data that's important for our own mission
        arguments = {{
            giver = station.id,
            location = target,
            reward = reward,
            punishment = punishment,
        }},
    }
    return bulletin
end
