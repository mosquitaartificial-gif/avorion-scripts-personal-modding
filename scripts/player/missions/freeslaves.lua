package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("utility")
include ("structuredmission")
include ("galaxy")
include ("goods")
include ("stringutility")
include ("callable")
include("randomext")

local SectorGenerator = include ("SectorGenerator")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local Balancing = include ("galaxy")
local SpawnUtility = include ("spawnutility")
local ShipUtility = include ("shiputility")

mission.data.title = "Free slaves"%_t
mission.data.brief = mission.data.title

mission.data.autoTrackMission = true

mission.data.description = {}
mission.data.description[1] = "Traffickers kidnapped some of our people. They were just normal males, females and children. We discovered the hideout of those traffickers, but we fear they will take our people hostage or even kill them if one of our ships comes close. If you help, you'll have our endless gratitude."%_T

mission.data.accomplishMessage = "Thank you so much for bringing back our families. We are very, very thankful for your help."%_t
mission.data.failMessage = "We lost track of our families and friends. Who knows where they are now. Nevertheless, thank you for trying to help."%_t

mission.data.timeLimit = 15 * 60
mission.data.timeLimitInDescription = true

mission.data.custom.stationId = nil
mission.data.custom.price = 200000  + math.floor(math.random()*50000)
mission.data.custom.amountSlaves = 10
mission.data.custom.piratesSpawned = 0
mission.data.custom.haveSubmitted = false
mission.data.custom.pirateIds = {}

mission.globalPhase = {}
mission.globalPhase.noBossEncountersTargetSector = true
mission.globalPhase.noPlayerEventsTargetSector = true


function SlavesGood()
    local good = TradingGood("Freed Slave"%_T, plural_t("Freed Slave", "Freed Slaves", 1), "A now freed life form that was forced to work for almost no food."%_T, "data/textures/icons/slave.png", 0, 1)
    good.tags = {mission_relevant = true}
    return good
end


-- player enters target sector and pirates are spawned
mission.phases[1] = {}
mission.phases[1].onBegin = function()
    local giver = Entity(mission.data.giver.id)
    if not giver then return end
    mission.data.description[2] = {text = "Go to sector (${x}:${y}) and free the slaves"%_T, arguments = {x = mission.data.location.x, y = mission.data.location.y}, bulletPoint = true, fulfilled = false}
    mission.data.description[3] = {text = "Bring the slaves back to the ${title} ${name} in (${x}:${y})"%_T, arguments = {title = giver.translatedTitle, name = giver.name, x = mission.data.giver.coordinates.x, y = mission.data.giver.coordinates.y}, bulletPoint = true, fulfilled = false, visible = false}
end
mission.phases[1].onTargetLocationEntered = function()
    if onClient() then return end
    createPirates(pirateFaction) -- this is async - go to next phase as soon as it's finished
end

-- in phase 2 player has chance to buy slaves, if he doesn't go to phase 3
mission.phases[2] = {}
mission.phases[2].triggers = {}
mission.phases[2].triggers[1] =
{
    condition = function() return checkStationCreated() end,
    callback = function () return onStartDialog() end,
}
mission.phases[2].playerEntityCallbacks = {}
mission.phases[2].playerEntityCallbacks[1] =
{
    name = "onCargoChanged",
    -- if slaves are bought, mission skips phase 3
    func = function(objectIndex, delta, good)
        checkSlavesAdded(objectIndex, delta, good)
    end
}

-- check how many pirates have been destroyed => pirates chicken out if two thirds of them are dead
mission.phases[3] = {}
mission.phases[3].updateServer = function()
    if not mission.data.custom.haveSubmitted and inTargetLocation() then
        checkEnoughKilled()
    end
end
-- wait for player to collect all slaves
mission.phases[3].playerEntityCallbacks = {}
mission.phases[3].playerEntityCallbacks[1] =
{
    name = "onCargoChanged",
    func = function(objectIndex, delta, good)
        checkSlavesAdded(objectIndex, delta, good)
    end
}
mission.phases[3].showUpdateOnEnd = true

-- player now must bring slaves home to the sector he got the mission from
mission.phases[4] = {}
mission.phases[4].onBegin = function()
    mission.data.description[2].fulfilled = true
    mission.data.description[3].visible = true
    -- set target coords, so player knows where to go
    mission.data.location = mission.data.giver.coordinates
end
mission.phases[4].onTargetLocationArrivalConfirmed = function()
    -- first check if player actually has the slaves
    if onServer() then
        local player = Player()
        local ship = player.craft
        if not ship then return end

        local playerHas = ship:getCargoAmount(SlavesGood())
        local station = Entity(mission.data.giver.id)
        if station and playerHas > 0 then
            invokeClientFunction(Player(), "showBroughtHomeDialog", station.id, playerHas, false)
        end
    end
end
mission.phases[4].onSectorEntered = function()
    if onClient() then
        local drops = {Sector():getEntitiesByType(EntityType.Loot)}
        for _, drop in pairs(drops) do
            if drop.id == mission.data.custom.droppedSlavesId then
                Hud():displayHint("You need more cargo space to pick up these slaves!"%_t, drop)
            end
        end
    end
end
mission.phases[4].onRestore = function()
    mission.phases[4].onTargetLocationArrivalConfirmed()
end

function checkSlavesAdded(objectIndex, delta, good)
    if onServer() then
        local ship = Player().craft
        if not ship then return end

        if objectIndex == ship.id and delta > 0 and good == SlavesGood() then
            setPhase(4)
        end
    end
end

function syncCustomValues(values)
    if onServer() then
        invokeClientFunction(Player(), "syncCustomValues", mission.data.custom)
    else
        mission.data.custom = values
    end
end

function fightPirates()
    if onClient() then
        -- make sure Server knows we fight now
        invokeServerFunction("fightPirates")
    end
    -- set pirates aggressive
    for _, pirateId in pairs(mission.data.custom.pirateIds) do
        if not pirateId then goto continue end
        local pirate = Entity(pirateId)
        if not pirate then goto continue end
        pirate:removeScript("entity/ai/patrolpeacefully.lua")
        pirate:addScriptOnce("entity/ai/patrol.lua")
        ::continue::
    end

    -- set station aggressive as well
    if mission.data.custom.stationId then
        local station = Entity(mission.data.custom.stationId)
        if not station then goto continue2 end
        station:removeScript("entity/ai/patrolpeacefully.lua")
        station:addScriptOnce("entity/ai/patrol.lua")
    end
    ::continue2::

    -- next phase
    setPhase(3)
end
callable(nil, "fightPirates")

function countPirates()
    local num = 0
    for _, entity in pairs({Sector():getEntitiesByType(EntityType.Ship)}) do
        if entity:getValue("is_pirate") then
            num = num + 1
        end
    end

    return num
end

function countAggressivePirates()
    local num = 0
    for _, entity in pairs({Sector():getEntitiesByType(EntityType.Ship)}) do
        if entity:getValue("is_pirate") then
            if ShipAI(entity.id).state == AIState.Aggressive then
                num = num + 1
            end
        end
    end

    return num
end

function checkEnoughKilled()
    -- if two thirds of them are dead
    local count = countPirates() -- counts pirate ships
    local threshold = mission.data.custom.piratesSpawned * (2 / 3)
    if count < threshold then
        piratesSubmit()
        mission.data.custom.haveSubmitted = true
    end

    -- or station is half-dead
    local pirateStation = Entity(mission.data.custom.stationId)
    if not pirateStation then return end
    local health = pirateStation.durability
    local healthThreshold = pirateStation.maxDurability / 2
    if health < healthThreshold then
        piratesSubmit()
        mission.data.custom.haveSubmitted = true
    end
end

function piratesSubmit()
    if onServer() then
        Player():sendChatMessage(Entity(mission.data.custom.stationId), 0, "Guys! Hold your fire."%_t)
        invokeClientFunction(Player(), "piratesSubmit")
    end

    local livingPirateShip = nil
    -- set pirates to fly around a bit without engaging
    for _, pirateId in pairs(mission.data.custom.pirateIds) do
        if not pirateId then goto continue end
        livingPirateShip = Entity(pirateId)
        if not livingPirateShip then goto continue end

        livingPirateShip:removeScript("entity/ai/patrol.lua")
        livingPirateShip:addScriptOnce("entity/ai/patrolpeacefully.lua")
        ::continue::
    end

    if mission.data.custom.stationId then
        local station = Entity(mission.data.custom.stationId)
        if not station then goto continue2 end
        station:removeScript("entity/ai/patrol.lua")
        station:addScriptOnce("entity/ai/patrolpeacefully.lua")
        ::continue2::
    end

    if onClient() then
        -- check if station still exists - if so make dialog with station
        if mission.data.custom.stationId then
            local station = Entity(mission.data.custom.stationId)
            if station then
                ScriptUI(station):interactShowDialog(submitDialog(), false)
            elseif livingPirateShip then
                -- use any other pirate entity in sector - living pirate from before
                ScriptUI(livingPirateShip):interactShowDialog(submitDialog(), false)
            else
                -- no pirate to talk => immediately drop goods
                prepForHomeComing()
            end
        end
    end
end

function buySlaves()
    -- check if player actually has enough money to buy the slaves
    if onClient() then
        invokeServerFunction("buySlaves")
        return
    end

    local player = Player()
    local canPay, msg, args = player:canPay(mission.data.custom.price)
    if not canPay then
        player:sendChatMessage(Entity(mission.data.custom.stationId), 0, "You want to play games?! DIE!"%_T)
        -- attack player
        fightPirates()
    else
        player:pay("Paid %1% Credits to buy the slaves."%_T, mission.data.custom.price)
        player:sendChatMessage(Entity(mission.data.custom.stationId), 0, "Pleasure doing business with you."%_T)
        prepForHomeComing()
    end
end
callable(nil, "buySlaves")

function prepForHomeComing()

    if onClient() then invokeServerFunction("prepForHomeComing") return end

    -- stop timer, slaves are free now
    mission.data.timeLimitInDescription = false
    mission.data.timeLimit = nil

    -- add as many slaves as fit - drop the rest
    local count = 0
    local player = Player()
    local ship = player.craft
    if (not ship) or (ship.freeCargoSpace == nil) then
        -- drop everything
        dropAndHighlight(mission.data.custom.amountSlaves)
    elseif ship.freeCargoSpace < mission.data.custom.amountSlaves then
        -- add as many as you can, drop the rest
        while ship.freeCargoSpace >= 1 do
            ship:addCargo(SlavesGood(), 1)
            count = count + 1
        end
        local toDrop = mission.data.custom.amountSlaves - count
        dropAndHighlight(toDrop)
    else
        -- add all at once
        ship:addCargo(SlavesGood(), mission.data.custom.amountSlaves)
    end
end
callable(nil, "prepForHomeComing")

function dropAndHighlight(amount)
    if amount <= 0 then return end

    if onServer() then
        local player = Player()
        local ship = player.craft
        if ship then
            mission.data.custom.droppedSlavesId = (Sector():dropCargo(ship.translationf, player, nil, SlavesGood(), 0, amount)).id
        else
            mission.data.custom.droppedSlavesId = (Sector():dropCargo(nil, player, nil, SlavesGood(), 0, amount)).id
        end
        syncCustomValues()
        invokeClientFunction(Player(), "dropAndHighlight", amount)
    return end

    local drops = {Sector():getEntitiesByType(EntityType.Loot)}
    for _, drop in pairs(drops) do
        if drop.id == mission.data.custom.droppedSlavesId then
            Hud():displayHint("You need more cargo space to pick up these slaves!"%_t, drop)
        end
    end
end

function onBroughtHomeEnd()
    if onClient() then invokeServerFunction("onBroughtHomeEnd") return end
    -- we're happy and take them
    local ship = Player().craft
    -- if player doesn't bring back all slaves, the reward needs to be adjusted to the actual amount of freed slaves
    local slaveAmount = ship:getCargoAmount(SlavesGood())
    if slaveAmount > 10 then
        slaveAmount = 10
    end

    mission.data.reward.relations = mission.data.reward.relations * (slaveAmount / 10)
    ship:removeCargo(SlavesGood(), slaveAmount)
    reward()
    accomplish()
end
callable(nil, "onBroughtHomeEnd")

function onStartDialog()
    local station = Entity(mission.data.custom.stationId)
    if not station then return end
    ScriptUI(station):interactShowDialog(pirateDialog(), false)
end

function showBroughtHomeDialog(stationId, amount, closeable)
    local ui = ScriptUI(stationId)
    ui:interactShowDialog(broughtHomeDialog(amount), closeable)
end

function broughtHomeDialog(amount)
    amount = amount or 0

    local dialog = {}
    local d1_End = {}
    local d2_Reimburse = {}

    if amount < mission.data.custom.amountSlaves then
        dialog.text = "We missed more of our people. But it seems, we lost the others. Thanks for your help anyway, but we have to prepare mourning ceremonies."%_t
        dialog.onEnd = "onBroughtHomeEnd"
    else
        dialog.text = "Thank you so much for getting our people home! Everything went smoothly, I hope?"%_t
        dialog.answers = {
            {answer = "It was fine. Don't mention it."%_t, followUp = d1_End},
            {answer = "Yeah, you don't need to worry about them anymore."%_t, followUp = d1_End},
            {answer = "They had me pay ${money} Credits for your people!"%_t % {money = mission.data.custom.price}, followUp = d2_Reimburse}
        }

        d1_End.text = "That's good to hear! Thank you again and have a wonderful time."%_t
        d1_End.onEnd = "onBroughtHomeEnd"

        d2_Reimburse.text = "You had to pay for them? I'm so sorry to hear that, but we can't pay you back. If we had that kind of money lying around, we would've bought them immediately."%_t
        d2_Reimburse.onEnd = "onBroughtHomeEnd"
    end

    return dialog
end

function submitDialog()
    local dialog = {}
    dialog.text = "Okay, okay. You can have them. Just leave us alone. Stop destroying our ships and you can get those slaves for free!"%_t
    dialog.answers = {{answer = "Your lives for the slaves? We have a deal."%_t}}
    dialog.onEnd = "prepForHomeComing" -- give slaves to player
    return dialog
end

function pirateDialog()
    local d0_Hello = {}
    local d1_Buy = {}
    local d2_Attack = {}
    local d3_Deal = {}
    local d4_Negotiate = {}

    d0_Hello.text = "Hey you! What do you want? Speak fast or leave!"%_t
    d0_Hello.answers = {
        {answer = "I heard you have slaves of ${faction}."%_t % {faction = Faction(mission.data.giver.factionIndex).translatedName}, followUp = d1_Buy},
        {answer = "I will free the poor people you enslaved."%_t, followUp = d2_Attack},
        {answer = "(attack)"%_t, followUp = d2_Attack},
    }

    d1_Buy.text = "We do, we do. Do you want to buy them? You can have them for only ${price} Credits."%_t % {price = mission.data.custom.price}
    d1_Buy.answers = {
        {answer = "That sounds good, we have a deal."%_t, followUp = d3_Deal},
        {answer = "That is too expensive for some slaves! Let's talk about a better price."%_t, followUp = d4_Negotiate},
        {answer = "I won't pay this... but I will take them. (attack)"%_t, followUp = d2_Attack}
    }

    d2_Attack.text = "Hahaha, well you can try!"%_t
    d2_Attack.onEnd = "fightPirates"

    d3_Deal.text = "Wonderful! Pay up and we'll transport the slaves to your ship."%_t
    d3_Deal.answers = {
        {answer = "Here is the money."%_t},
        {answer = "I changed my mind, I won't pay you any money!"%_t, followUp = d2_Attack}
    }
    d3_Deal.onEnd = "buySlaves"

    d4_Negotiate.text = "We don't negotiate. Give us the money or get out of here."%_t
    d4_Negotiate.answers = {
        {answer = "Ok, so ${price} then."%_t % {price = mission.data.custom.price}, followUp = d3_Deal},
        {answer = "Why should I pay so much? I'll just take them."%_t, followUp = d2_Attack}
    }

    return d0_Hello
end

function createPirates(pirateFaction)

    -- create ships
    local generator = AsyncPirateGenerator(nil, onPiratesCreated)
    local numShips = math.random(5, 6)
    local defenders = math.random(1, 2)

    mission.data.custom.pirateFactionId = generator:getPirateFaction().index

    generator:startBatch()
    for i = 1, numShips do
        if i <= 3 then
            generator:createScaledBandit(getPositionInSector())
        else
            generator:createScaledPirate(getPositionInSector())
        end
    end

    for i = 1, defenders do
        if i <= 1 then
            generator:createScaledRaider(getPositionInSector())
        end
    end

    generator:createScaledRavager(getPositionInSector())

    generator:endBatch()
    mission.data.custom.piratesSpawned = numShips + defenders


    -- create station
    local coords = {}
    coords.x, coords.y = Sector():getCoordinates()
    local sectorGenerator = SectorGenerator(coords.x, coords.y)
    local pirateFaction = Faction(mission.data.custom.pirateFactionId)

    local station = sectorGenerator:createStation(pirateFaction, "data/scripts/entity/merchants/shipyard.lua")
    ShipUtility.addArmedTurretsToCraft(station)
    station:addScriptOnce("entity/ai/patrolpeacefully.lua")
    mission.data.custom.stationId = station.id
    Boarding(station).boardable = false

    syncCustomValues()

end

function onPiratesCreated(generated)

    for _, pirate in pairs(generated) do
        table.insert(mission.data.custom.pirateIds, pirate.id)
        pirate:addScriptOnce("entity/ai/patrolpeacefully.lua") -- don't attack yet, but fly around so that background looks more alive
    end

    -- add enemy buffs
    SpawnUtility.addEnemyBuffs(generated)

    -- set next phase
    setPhase(2)
end

function checkStationCreated()
    if onServer() then return end

    -- check only on client
    local entities = {Sector():getEntitiesByType(EntityType.Station)}
    for _, ent in pairs(entities) do
        if ent.id == mission.data.custom.stationId then
            return true
        end
    end
    return false
end

function inTargetLocation()
    local coords = {}
    coords.x, coords.y = Sector():getCoordinates()
    if mission.data.location.x == coords.x and mission.data.location.y == coords.y then
        return true
    end
    return false
end

function getPositionInSector()
    local position = vec3(math.random(), math.random(), math.random());
    local dist = getFloat(-5000, 5000)
    position = position * dist

    -- create a random up, right and look vector
    local up = vec3(math.random(), math.random(), math.random())
    local look = vec3(math.random(), math.random(), math.random())
    local mat = MatrixLookUp(look, up)
    mat.pos = position

    return mat
end

mission.makeBulletin = function(station)
    -- find empty sector
    local target = {}
    local x, y = Sector():getCoordinates()
    local giverInsideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    target.x, target.y = MissionUT.getSector(x, y, 5, 10, false, false, false, false)

    if not target.x or not target.y or giverInsideBarrier ~= MissionUT.checkSectorInsideBarrier(target.x, target.y) then return end

    local generator = AsyncPirateGenerator()
    local faction = generator:getPirateFaction()
    if not faction then return end

    reward = {relations = 12000}
    local materialAmount = round(random():getInt(7000, 8000) / 100) * 100
    MissionUT.addSectorRewardMaterial(x, y, reward, materialAmount)
    punishment = {relations = reward.relations}

    local bulletin =
    {
        -- data for the bulletin board
        brief = "Free Slaves"%_T,
        title = mission.data.title,
        description = mission.data.description[1],
        difficulty = "Difficult /*difficulty*/"%_T,
        reward = "¢${reward}"%_T,
        script = "missions/freeslaves.lua",
        formatArguments = {x = target.x, y = target.y, reward = createMonetaryString(reward.credits)},
        msg = "Please go to sector \\s(%1%:%2%) and free our family members."%_T,
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
            pirateFactionId = faction.index,
        }},
    }

    return bulletin
end
