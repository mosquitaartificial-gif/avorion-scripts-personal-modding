package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/player/background/simulation/?.lua"

local CommandType = include ("commandtype")
local SimulationUtility = include ("simulationutility")
local CaptainUtility = include ("captainutility")
local TorpedoGenerator = include ("torpedogenerator")
local SectorFighterGenerator = include ("sectorfightergenerator")
local TorpedoUtility = include ("torpedoutility")
local SellableTorpedo = include ("sellabletorpedo")
local SellableFighter = include ("sellablefighter")
include ("utility")
include ("randomext")


local MaintenanceCommand = {}
MaintenanceCommand.__index = MaintenanceCommand
MaintenanceCommand.type = CommandType.Maintenance

local function new(ship, area, config)
    local command = setmetatable({
        -- all commands need these variables to function within the bg simulation framework
        -- type contains the CommandType of the command, required to restore
        type = CommandType.Maintenance,

        -- the ship that has the command
        shipName = ship,

        -- the area where the ship is doing its thing
        area = area,

        -- config that was given to the ship
        config = config,

        -- holds any data necessary to fulfill the command, that should be saved to database, eg. timers and so on
        -- this should only contain variables that can be saved to database (eg. returned in a secure()) call
        -- this will be automatically restored/secured
        data = {},

        -- will be set from external, only listed here for completeness' sake
        simulation = nil

    }, MaintenanceCommand)

    command.data.runTime = 0

    return command
end


function MaintenanceCommand:initialize()
    local parent = getParentFaction()
    local prediction = self:calculatePrediction(parent.index, self.shipName, self.area, self.config)
    self.data.prediction = prediction
end

function MaintenanceCommand:update(timeStep)
    self.data.runTime = self.data.runTime + timeStep
    if self.data.runTime >= self.data.prediction.duration.value then
        self:finish()
        return
    end
end

function MaintenanceCommand:onAreaAnalysisStart(results, meta)
    results.friendlySectors = 0
    results.closestSector = {x = 500, y = 500}
    results.closestDistanceSquaredToCenter = math.huge

    results.reconstructionSiteNearby = false
    if meta.callingPlayer then
        local player = Player(meta.callingPlayer)
        local rx, ry = player:getReconstructionSiteCoordinates()

        local lower = meta.area.lower
        local upper = meta.area.upper

        if rx >= lower.x and rx <= upper.x then
            if ry >= lower.y and ry <= upper.y then
                results.reconstructionSiteNearby = true
            end
        end
    end

    -- use this as a cache for relation status to a specific faction
    -- this is so that we don't have to access the Player all the time which can be costly
    meta.statuses = {}
end

function MaintenanceCommand:onAreaAnalysisSector(results, meta, x, y, sectorDetails)
    -- check sector friendly or not
    local factionIndex = sectorDetails.faction
    if factionIndex ~= 0 then -- it's dangerous if it's no-man's-space
        local status = meta.statuses[factionIndex]
        if status == nil then
            status = meta.faction:getRelationStatus(factionIndex)
            meta.statuses[factionIndex] = status
        end

        if status ~= RelationStatus.War then
            results.friendlySectors = results.friendlySectors + 1
        end
    end

    -- check distance to center and remember sector if it is closer
    local distanceSquared = x * x + y * y
    if distanceSquared < results.closestDistanceSquaredToCenter then
        results.closestDistanceSquaredToCenter = distanceSquared
        results.closestSector = {x = x, y = y}
    end
end

function MaintenanceCommand:onStart()
    -- save position from which ship is going to start
    local parent = getParentFaction()
    local entry = ShipDatabaseEntry(parent.index, self.shipName)
    local startX, startY = entry:getCoordinates()
    self.data.startCoordinates = { x = startX, y = startY }

    local budget = self.data.prediction.costs
    local faction = getParentFaction()
    local canPay, msg, args = faction:canPay(budget)

    if not canPay then
        return msg, args
    end

    -- the captain receives the entire budget at this point
    faction:pay(Format("Gave the captain of '%1%' a budget of %2% credits for maintenance."%_T, (self.shipName or "")), budget)
end

function MaintenanceCommand:onRecall()
    local timeCompleted = self.data.runTime / self.data.prediction.duration.value

    if timeCompleted >= 0.30 then
        self:finishCommand(timeCompleted * 0.85) -- 15 % deduction to make recall less attractive
    else
        local message = "Sadly we didn't have enough time to finish maintenance. Here are the remaining funds."%_T
        -- we didn't use budget -> add yield to give money back
        self:addYield(message, self.data.prediction.costs)
    end
end

function MaintenanceCommand:onFinish()
    self:finishCommand(1)
end

function MaintenanceCommand:getAdjustedCrew(entry, maxCrew, totalFighters)
    local crew = entry:getCrew()
    local minimal = entry:buildIdealCrew()

    local availableWorkforceUD = crew:getWorkforce()
    local minimalWorkforceUD = minimal:getWorkforce()

    -- convert to tables with a number as key to avoid double entries when using userdata 'CrewProfession'
    local availableWorkforce = {}
    local minimalWorkforce = {}
    for profession, workforce in pairs(minimalWorkforceUD) do
        minimalWorkforce[profession.value] = workforce
    end
    for profession, workforce in pairs(availableWorkforceUD) do
        availableWorkforce[profession.value] = workforce
    end

    minimalWorkforce[CrewProfessionType.Pilot] = minimalWorkforce[CrewProfessionType.Pilot] or 0

    local cost = 0
    local specialistsHired = 0
    local vaniallaHired = 0

    for profession, required in pairs(minimalWorkforce) do
        local available = 0
        available = availableWorkforce[profession] or 0

        if maxCrew then
            if profession == CrewProfessionType.Engine
                    or profession == CrewProfessionType.Repair then
                required = required * 3
            end
        end

        if profession == CrewProfessionType.Pilot then
            required = math.max(required, totalFighters)
        end

        local required = math.max(required - available, 0)

        local hired = 0
        if profession == CrewProfessionType.Pilot then
            hired = math.ceil(required)
        else
            hired = math.ceil(required / 1.5)
        end

        local profession = CrewProfession(profession)
        cost = cost + hired * profession.price * 1.2 -- +20% as that's the tax for hiring crew (see crewboard.lua)
        specialistsHired = specialistsHired + hired

        crew:add(hired, CrewMan(profession, true, 0))
    end

    if maxCrew then
        local free = crew.maxSize - crew.size
        if free > 0 then
            crew:add(free, CrewMan(CrewProfession(CrewProfessionType.None), false, 0))
            vaniallaHired = free
        end
    end

    return crew, round(cost), specialistsHired, vaniallaHired
end

function MaintenanceCommand:finishCommand(timeCompleted)
    local parent = getParentFaction()
    local entry = ShipDatabaseEntry(parent.index, self.shipName)
    local captain = entry:getCaptain()
    local prediction = self.data.prediction

    local unspentMoney = 0

    -- torpedoes
    local generator = TorpedoGenerator(Seed(self.data.prediction.seedStr))
    local shafts, launcherTable = entry:getTorpedoes()
    local torpedoesInStorage = {shafts[-1]:getTorpedoes()}

    for _, purchase in pairs(prediction.torpedoPurchases) do
        local x, y = prediction.mostCentralSector.x, prediction.mostCentralSector.y
        local torpedo = generator:generate(x, y, 0, Rarity(purchase.rarity), purchase.warhead, purchase.bodyClass)
        torpedo.size = purchase.size

        if purchase.amount > 0 then
            local amount = math.floor(purchase.amount * timeCompleted)

            for i = 1, amount do
                table.insert(torpedoesInStorage, torpedo)
            end

            unspentMoney = unspentMoney + purchase.price * (1 - amount / purchase.amount)
        end

        if purchase.amountInLaunchers > 0 then
            local amount = math.floor(purchase.amountInLaunchers * timeCompleted)

            for i, shaft in pairs(shafts) do
                if i >= 0 and shaft.enabled and shaft.automaticLoadingType == purchase.warhead then
                    local torpedoes = {shaft:getTorpedoes()}
                    local addable = math.min(shaft.freeSpace, amount)

                    for i = 1, addable do
                        table.insert(torpedoes, torpedo)
                        amount = amount - 1
                    end

                    shaft:setTorpedoes(unpack(torpedoes))
                end
            end

            unspentMoney = unspentMoney + purchase.price * (amount / purchase.amountInLaunchers)
        end
    end

    shafts[-1]:setTorpedoes(unpack(torpedoesInStorage))
    entry:setTorpedoes(shafts)

    -- fighters
    local hangar, info = entry:getHangar()
    local generator = SectorFighterGenerator(Seed(self.data.prediction.seedStr))

    local free = info.freeSpace

    for squadIndex, purchase in pairs(prediction.fighterPurchases) do
        if purchase.amount > 0 then
            local bought = 0

            local squad = hangar[purchase.squadIndex]
            if squad then
                local amount = math.floor(purchase.amount * timeCompleted)
                local x, y = prediction.mostCentralSector.x, prediction.mostCentralSector.y

                local fighter
                if purchase.weaponType == "shuttle" then
                    fighter = generator:generateCrewShuttle(x, y, nil)
                else
                    fighter = generator:generate(x, y, 0, Rarity(purchase.rarity), purchase.weaponType, nil)
                end
                fighter.diameter = 1.25

                local pricePerFighter = SellableFighter(fighter).price

                for i = 1, amount do
                    if free >= fighter.volume then
                        free = free - fighter.volume
                        squad:addFighter(fighter)
                        bought = bought + 1
                    end
                end

                -- this is what the fighters actually cost
                local actualPrice = bought * pricePerFighter

                -- if the actual price is higher than what we gave the captain, we just let the player be lucky
                local overpaid = math.max(purchase.price - actualPrice, 0)
                unspentMoney = unspentMoney + overpaid
            end
        end
    end

    entry:setHangar(hangar)

    local totalFighters = 0
    for _, squad in pairs(hangar) do
        totalFighters = totalFighters + squad.numFighters
    end

    -- restore starting position of command
    if self.data.startCoordinates then
        local startX = self.data.startCoordinates.x
        local startY = self.data.startCoordinates.y
        entry:setCoordinates(startX, startY)
    end

    -- always repair ship, as the ship can't be recalled during repairs
    -- once it can be recalled it should be repaired
    entry:setDurabilityMalus(1.0, MalusReason.None)
    entry:setDurabilityPercentage(1.0)

    -- crew is finished first, after a certain amount of time
    if self.config.crewAction then
        local secondsPassed = timeCompleted * self.data.prediction.duration.value
        if timeCompleted >= 1 or secondsPassed >= self.data.prediction.baseDuration + self.data.prediction.crewDuration then
            -- add crew
            local maxCrew = (self.config.crewAction == 2)
            local crew = self:getAdjustedCrew(entry, maxCrew, totalFighters)
            entry:setCrew(crew)
        end
    end

    if timeCompleted == 1 then
        -- send chat message as a yield message is simply not necessary
        local x, y = entry:getCoordinates()
        parent:sendChatMessage(self.shipName, ChatMessageType.Information, "%1% has finished maintenance and is awaiting your next orders in \\s(%2%:%3%)."%_T, self.shipName, x, y)

    else
        unspentMoney = unspentMoney + self.data.prediction.crewCost
    end

    -- relation changes
    local sellingFaction = self.area.analysis.biggestFactionInArea
    if sellingFaction then
        local spent = math.max(0, self.data.prediction.costs - unspentMoney)
        local relationsChange = GetRelationChangeFromMoney(spent) * 0.25 -- only a quarter of the usual relations because it was captain who did the trading
        changeRelations(parent.index, sellingFaction, relationsChange, RelationChangeType.GoodsTrade)
    end

    if unspentMoney > 0 then
        local message = "We didn't spend all the money you gave us. Here are the remaining funds."%_T
        if timeCompleted < 1 then
            message = "Sadly we didn't have enough time to finish maintenance. Here are the remaining funds."%_T
        end

        -- we didn't use entire budget -> add yield to give back money
        self:addYield(message, unspentMoney)
    end
end

function MaintenanceCommand:onSecure()
end

function MaintenanceCommand:onRestore()
end

function MaintenanceCommand:getIgnoredErrors()
    -- caveat: Some errors cannot be ignored as they don't make sense, such as UsableError.Unavailable, UsableError.NoCaptain or UsableError.NotAShip
    local ignored = {}
    ignored[SimulationUtility.UsableError.BadCrew] = true
    ignored[SimulationUtility.UsableError.BadEnergy] = true
    ignored[SimulationUtility.UsableError.Damaged] = true
    return ignored
end

function MaintenanceCommand:getDescriptionText()
    local totalRuntime = self.data.prediction.duration.value
    local timeRemaining = round((totalRuntime - self.data.runTime) / 60) * 60
    local completed = round(self.data.runTime / totalRuntime * 100)

    return "The ship is doing maintenance.\n\nTime remaining: ${timeRemaining} (${completed} % done)."%_T, {timeRemaining = createReadableShortTimeString(timeRemaining), completed = completed}
end

function MaintenanceCommand:getStatusMessage()
    return "Maintenance /* ship AI status*/"%_T
end


function MaintenanceCommand:getIcon()
    return "data/textures/icons/maintenance-command.png"
end

function MaintenanceCommand:getRecallError()
    if self.data.runTime < 600 and self.data.prediction.repairsNecessary then
        return "Ship is currently under repair and cannot be recalled."%_T
    end
end

function MaintenanceCommand:getErrors(ownerIndex, shipName, area, config)
    local prediction = self:calculatePrediction(ownerIndex, shipName, area, config)

    local totalTorpedoesToBuy = 0
    for _, purchase in pairs(prediction.torpedoPurchases) do
        totalTorpedoesToBuy = totalTorpedoesToBuy + (purchase.amount or 0) + (purchase.amountInLaunchers or 0)
    end

    if not prediction.repairsNecessary and (prediction.hiredCrew or 0) == 0 then
        if totalTorpedoesToBuy == 0 and tablelength(config.fightersToBuy) == 0  then
            return "No maintenance to do."%_T, {}
        end
    end

    if tablelength(config.torpedoesToBuy) > 0 then
        if area.analysis.closestDistanceSquaredToCenter > 380 * 380 then
            return "We're too far from the galaxy center to buy torpedoes!"%_T, {}
        end
    end

    -- check whether faction has enough money
    local owner = Galaxy():findFaction(ownerIndex)

    if owner.isAlliance then
        -- uses the local player (when on client) or callingPlayer (when on server), depending on what's correct
        -- in case this is called on the server, in an alliance context, without a callingPlayer, Player() will return nil and the if won't be entered
        -- that's okay since we wouldn't even know what player to check privileges for anyway
        local player = Player(callingPlayer)
        if player then
            if not owner:hasPrivilege(player.index, AlliancePrivilege.SpendResources) then
                return "You don't have permission to pay with alliance funds!"%_T, {}
            end
        end
    end

    local canPay, msg, args = owner:canPay(prediction.costs)
    if not canPay then
        return msg, args
    end

end

function MaintenanceCommand:getAreaSize(ownerIndex, shipName)
    return {x = 15, y = 15}
end

function MaintenanceCommand:getAreaBounds()
    return {lower = self.area.lower, upper = self.area.upper}
end

function MaintenanceCommand:isShipRequiredInArea(ownerIndex, shipName)
    return true
end

function MaintenanceCommand:isAreaFixed(ownerIndex, shipName)
    return true
end

function MaintenanceCommand:getConfigurableValues(ownerIndex, shipName)
    local values = {}
    values.torpedoesToBuy = {} -- legacy code
    return values
end

function MaintenanceCommand:getPredictableValues()
    local values = {}
    values.attackChance = {displayName = SimulationUtility.AttackChanceLabelCaption}
    values.duration = {displayName = "Duration"%_t}
    values.moneyNeeded = {displayName = "Price (up to)"%_t}
    return values
end

function MaintenanceCommand:calculatePrediction(ownerIndex, shipName, area, config)
    local results = self:getPredictableValues()

    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local captain = entry:getCaptain()
    local x, y = entry:getCoordinates()

    -- duration
    local baseDuration = 5 * 60 -- base duration - increased to 20 min if no friendly sector available
    if area.analysis.friendlySectors == 0 then
        baseDuration = 20 * 60
    end

    local duration = baseDuration

    -- cost
    local totalCost = 0
    local repairCost = 0
    local crewCost = 0
    local crewDuration = 0
    local hiredCrew = 0
    local torpedoPurchases = {}

    local priceFactor = 1
    for _, perk in pairs({captain:getPerks()}) do
        priceFactor = priceFactor + CaptainUtility.getMaintenancePricePerkImpact(captain, perk)
    end

    -- repairs
    local maxHP, healthPercentage, malusFactor, malusReason, damaged = entry:getDurabilityProperties()
    if damaged or healthPercentage < 0.95 then
        results.repairsNecessary = true

        if not area.analysis.reconstructionSiteNearby then
            local value = entry:getPlanValue()
            repairCost = value * (1 - healthPercentage) * 0.3 * priceFactor
        end
        totalCost = totalCost + repairCost
    end

    -- torpedo purchasing
    local seedStr = captain.name .. tostring(x) .. tostring(y) .. tostring(GameSeed())
    local seed = Seed(seedStr)
    local rand = Random(seed)

    local generator = TorpedoGenerator(seed)
    local possibleBodyClasses = generator:getBodyProbability(x, y)
    local bodyClass = selectByWeight(rand, possibleBodyClasses)

    -- transaction time is increased by 25% per rarity level above common
    local rarityFactor = {}
    rarityFactor[RarityType.Petty] = 1.0
    rarityFactor[RarityType.Common] = 1.0
    rarityFactor[RarityType.Uncommon] = 1.1
    rarityFactor[RarityType.Rare] = 1.25
    rarityFactor[RarityType.Exceptional] = 1.5
    rarityFactor[RarityType.Exotic] = 2.0
    rarityFactor[RarityType.Legendary] = 3.0

    local total = 0
    for i, order in pairs(config.torpedoesToBuy) do
        total = total + order.percentage
    end

    local purchasePercentageFactor = 1
    if total > 100 then purchasePercentageFactor = 100 / total end

    local launcherTypesDone = {}

    local shafts, info = entry:getTorpedoes()
    for i, order in pairs(config.torpedoesToBuy) do
        local torpedo = generator:generate(area.analysis.closestSector.x, area.analysis.closestSector.y, 0, Rarity(order.rarity), order.warhead, bodyClass)
        local amount = math.floor(((order.percentage / 100) * info.freeSpace) / torpedo.size * purchasePercentageFactor)

        local amountInLaunchers = 0
        if not launcherTypesDone[order.warhead] then
            launcherTypesDone[order.warhead] = true
            for shaftIndex, shaft in pairs(shafts) do
                if shaftIndex >= 0 then
                    if shaft.enabled and shaft.automaticLoadingType == order.warhead then
                        amountInLaunchers = amountInLaunchers + shaft.freeSpace
                    end
                end
            end
        end

        amountInLaunchers = math.ceil(amountInLaunchers * order.percentage / 100)

        local price = SellableTorpedo(torpedo).price * (amount + amountInLaunchers) * priceFactor
        totalCost = totalCost + price

        local purchase = {
            warhead = order.warhead,
            bodyClass = order.bodyClass,
            rarity = order.rarity,
            price = price,
            amount = amount,
            amountInLaunchers = amountInLaunchers,
            size = torpedo.size,
            percentage = round(order.percentage * purchasePercentageFactor, 1)
        }
        torpedoPurchases[i] = purchase

        local transactionTime = 5 -- base transaction time
        duration = duration + (amount + amountInLaunchers) * transactionTime * rarityFactor[order.rarity]
    end

    -- fighters
    local hangar, info = entry:getLightweightHangar()
    local free = info.freeSpace
    local hangarCapacity = info.space
    local hangarUtilization = info.occupiedSpace

    local fighterPurchases = {}
    local generator = SectorFighterGenerator(seed)
    generator.emptyPlan = true

    local totalFighters = 0
    for _, squad in pairs(hangar) do
        totalFighters = totalFighters + squad.numFighters
    end

    for i, order in pairs(config.fightersToBuy) do
        local squadIndex = i - 1
        local squad = hangar[squadIndex]

        if squad then
            local x, y = area.analysis.closestSector.x, area.analysis.closestSector.y
            local fighter
            if order.weaponType == "shuttle" then
                fighter = generator:generateCrewShuttle(x, y, nil)
            else
                fighter = generator:generate(x, y, 0, Rarity(order.rarity), order.weaponType, nil)
            end
            fighter.diameter = 1.25

            local price = SellableFighter(fighter).price * order.amount * priceFactor
            totalCost = totalCost + price
            hangarUtilization = hangarUtilization + fighter.volume * order.amount

            local purchase = {
                x = x,
                y = y,
                rarity = order.rarity,
                weaponType = order.weaponType,
                price = price,
                amount = order.amount,
                squadIndex = squadIndex,
            }
            fighterPurchases[i] = purchase

            local transactionTime = 15 -- base transaction time
            duration = duration + order.amount * transactionTime * rarityFactor[order.rarity]

            totalFighters = totalFighters + order.amount
        end
    end

    -- crew
    if config.crewAction then
        local maxCrew = (config.crewAction == 2)
        local crew, cost, specialistsHired, vanillaHired = self:getAdjustedCrew(entry, maxCrew, totalFighters)
        crewCost = cost * priceFactor

        totalCost = totalCost + crewCost

        -- +1 minute for every 25 specialists
        crewDuration = crewDuration + math.ceil(specialistsHired / 25) * 60
        -- +1 minute for every 50 vanilla
        crewDuration = crewDuration + math.ceil(vanillaHired / 50) * 60

        duration = duration + crewDuration
        hiredCrew = specialistsHired + vanillaHired

        if hiredCrew > 0 and crew.size > crew.maxSize then
            results.overpopulated = true
        end
    end

    -- cargo on ship that would lead to controls increases duration by 15 %
    if not captain:hasClass(CaptainUtility.ClassType.Smuggler) then
        local cargo = entry:getCargo()
        local stolenOrIllegal, dangerousOrSuspicious = SimulationUtility.getSpecialCargoCategories(cargo)
        if captain:hasClass(CaptainUtility.ClassType.Merchant) then
            dangerousOrSuspicious = false
        end

        if stolenOrIllegal or dangerousOrSuspicious then
            duration = duration * 1.15
            crewDuration = crewDuration * 1.15
        end
    end

    -- captain's perks can influence duration (no class influence for maintenance operation)
    local factor = 1
    for _, perk in pairs({captain:getPerks()}) do
        factor = factor * (1 + CaptainUtility.getMaintenanceTimePerkImpact(captain, perk))
    end

    duration = duration * factor
    crewDuration = crewDuration * factor
    baseDuration = baseDuration * factor

    totalCost = math.max(1000, math.ceil(totalCost / 1000) * 1000)

    -- finalize
    results.costs = totalCost
    results.crewCost = crewCost
    results.crewDuration = crewDuration
    results.hiredCrew = hiredCrew
    results.repairCost = repairCost
    results.torpedoPurchases = torpedoPurchases
    results.fighterPurchases = fighterPurchases
    results.hangarCapacity = hangarCapacity
    results.hangarUtilization = hangarUtilization
    results.baseDuration = baseDuration
    results.duration.value = math.ceil(duration / 60) * 60
    results.mostCentralSector = area.analysis.closestSector
    results.attackChance = 0
    results.seedStr = seedStr

    return results
end

function MaintenanceCommand:generateAssessmentFromPrediction(prediction, captain, ownerIndex, shipName, area, config)

    -- cargo on board
    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local cargo = entry:getCargo()
    local stolenOrIllegal, dangerousOrSuspicious = SimulationUtility.getSpecialCargoCategories(cargo)
    local cargobayLines = SimulationUtility.getIllegalCargoAssessmentLines(stolenOrIllegal, dangerousOrSuspicious, captain)

    local hangarLines = {}
    if prediction.hangarUtilization > prediction.hangarCapacity then
        table.insert(hangarLines, "\\c(d93)Our hangar isn't big enough, we won't be able to obtain all fighters.\\c()"%_t)
    end

    local overpopulatedLines = {}
    if prediction.overpopulated then
        table.insert(overpopulatedLines, "\\c(dd3)There aren't enough quarters for all the crew we're about to hire. The ship will be overpopulated when we're back.\\c()"%_t)
    end

    -- radioSilence
    local radioSilence, returnLines = SimulationUtility.getDisappearanceAssessmentLines(0)

    local rnd = Random(Seed(captain.name .. tostring(x) .. tostring(y) .. tostring(GameSeed())))

    return {
        randomEntry(rnd, hangarLines),
        randomEntry(rnd, overpopulatedLines),
        randomEntry(rnd, cargobayLines),
        randomEntry(rnd, radioSilence),
        randomEntry(rnd, returnLines),
    }
end

local function getWarheadName(head)
    for _, warheadType in pairs(TorpedoUtility.Warheads) do
        if warheadType.type == head then
            return warheadType.name
        end
    end

    return ""
end

local function getWarheadColor(head)
    for _, warheadType in pairs(TorpedoUtility.Warheads) do
        if warheadType.type == head then
            return warheadType.color
        end
    end

    return ColorRGB(0.9, 0.9, 0.9)
end

function MaintenanceCommand:buildSingleTorpedoConfigUI(window, rect, configValues, configChangedCallback)
    local ui = {}

    local hlist = UIHorizontalLister(rect, 10, 0)

    ui.icon = window:createPicture(hlist:nextQuadraticRect(), "data/textures/icons/missile-pod.png")
    ui.icon.isIcon = true

    ui.typeCombo = window:createValueComboBox(hlist:nextRect(120), configChangedCallback)
    ui.rarityCombo = window:createValueComboBox(hlist:nextRect(80), configChangedCallback)
    for i = 0, 3 do
        local rarity = Rarity(i)
        ui.rarityCombo:addEntry(i, rarity.name, rarity.color);
    end

    ui.amountSlider = window:createSlider(hlist.inner, 0, 100, 100, "", configChangedCallback)
    ui.amountSlider.showValue = false

    ui.setVisible = function(self, visible)
        self.icon.visible = visible
        self.typeCombo.visible = visible
        self.rarityCombo.visible = visible
        self.amountSlider.visible = visible
    end

    return ui
end

function MaintenanceCommand:buildSingleFighterConfigUI(window, rect, configValues, configChangedCallback)
    local ui = {}

    local vlist = UIVerticalLister(rect, 10, 0)
    vlist.marginLeft = 15
    vlist.marginRight = 15
    local rect = vlist:nextQuadraticRect()
    vlist.marginLeft = 0
    vlist.marginRight = 0

    ui.icon = window:createPicture(rect, "data/textures/icons/fighter.png")
    ui.icon.isIcon = true

    local organizer = UIOrganizer(rect)
    ui.categoryIcon = window:createPicture(organizer:getTopRightRect(Rect(vec2(15))), "data/textures/icons/fighter.png")
    ui.categoryIcon.isIcon = true

    rect.lower = rect.lower - vec2(10, 0)
    ui.fightersLabel = window:createLabel(rect, "12", 10)
    ui.fightersLabel:setBottomLeftAligned()

    ui.amountSlider = window:createSlider(vlist:nextRect(20), 0, 12, 12, "", configChangedCallback)
    ui.amountSlider.showScale = false
    ui.amountSlider.showValue = false

    vlist.padding = 5

    ui.typeCombo = window:createValueComboBox(vlist:nextRect(25), configChangedCallback)
    ui.rarityCombo = window:createValueComboBox(vlist:nextRect(25), configChangedCallback)

    ui.setVisible = function(self, visible)
        self.icon.visible = visible
        self.categoryIcon.visible = visible
        self.typeCombo.visible = visible
        self.rarityCombo.visible = visible
        self.amountSlider.visible = visible
        self.fightersLabel.visible = visible
    end

    return ui
end

function MaintenanceCommand:buildMaintenanceUI(window, rect, configValues, configChangedCallback)
    local ui = {}

    local vlist = UIVerticalLister(rect, 25, 0)

    local vsplit = UIVerticalSplitter(vlist:nextRect(25), 10, 0, 0.5)
    ui.repairCheckbox = window:createCheckBox(vsplit.left, "Repair Ship"%_t, "")
    ui.repairCheckbox.active = false
    ui.repairCheckbox.checked = true
    ui.repairCheckbox.captionLeft = false

    local vsplitCrew = UIVerticalSplitter(vsplit.right, 10, 0, 0.5)
    vsplitCrew:setRightQuadratic()
    ui.hireCrewCombo = window:createValueComboBox(vsplitCrew.left, configChangedCallback)
    ui.hireCrewCombo:addEntry(nil, "No Crew Hiring"%_t)
    ui.hireCrewCombo:addEntry(1, "Required Crew"%_t)
    ui.hireCrewCombo:addEntry(2, "Maximum Crew"%_t)

    ui.hireCrewWarning = window:createPicture(vsplitCrew.right, "data/textures/icons/hazard-sign.png")
    ui.hireCrewWarning.isIcon = true
    ui.hireCrewWarning.color = ColorRGB(1, 1, 0.2)
    ui.hireCrewWarning.tooltip = "Not enough quarters, the ship will be overpopulated."%_t
    ui.hireCrewWarning.visible = false

    ui.torpedoSelections = {}
    local torpedoRect = vlist:nextRect(60)
    local gsplit = UIGridSplitter(torpedoRect, 10, 0, 2, 2)
    for i = 0, 3 do
        table.insert(ui.torpedoSelections, self:buildSingleTorpedoConfigUI(window, gsplit:partition(i), configValues, configChangedCallback))
    end

    ui.fighterSelections = {}
    local fighterRect = vlist:nextRect(115)
    local vsplit = UIVerticalMultiSplitter(fighterRect, 10, 0, 9)
    for i = 0, 9 do
        table.insert(ui.fighterSelections, self:buildSingleFighterConfigUI(window, vsplit:partition(i), configValues, configChangedCallback))
    end

    local organizer = UIOrganizer(vsplit:partition(9))
    local rect = organizer:getTopRightRect(Rect(vec2(15)))
    rect.position = rect.position + vec2(5, 0)
    ui.maxFightersButton = window:createButton(rect, "", "maintenanceCommandMaxFightersPressed")
    ui.maxFightersButton.icon = "data/textures/icons/fill-up-arrow.png"
    ui.maxFightersButton.tooltip = "Set all fighter purchases to full"%_t

    ui.hangarErrorLabel = window:createLabel(vlist:nextRect(15), "", 12)
    ui.hangarErrorLabel.color = Color("f55")
    ui.hangarErrorLabel:setCenterAligned()


    -- functions
    ui.clear = function(self)
        for _, ui in pairs(self.torpedoSelections) do
            ui.rarityCombo:setSelectedIndexNoCallback(0)
            ui.amountSlider:setValueNoCallback(0)
            ui.typeCombo:clear()
        end
        for _, ui in pairs(self.fighterSelections) do
            ui.rarityCombo:setSelectedIndexNoCallback(0)
            ui.amountSlider:setValueNoCallback(0)
            ui.typeCombo:clear()
        end
    end

    ui.refresh = function(self, ownerIndex, shipName, area, config)
        -- make selection of warheads
        local entry = ShipDatabaseEntry(ownerIndex, shipName)
        local captain = entry:getCaptain()
        local x, y = entry:getCoordinates()

        local seedStr = captain.name .. tostring(x) .. tostring(y) .. tostring(GameSeed())
        local generator = TorpedoGenerator(Seed(seedStr))

        -- warheads for selection
        local torpedoShafts, info = entry:getTorpedoes()

        local warheadProbabilities = generator:getWarheadProbability(x, y)
        for i, ui in pairs(self.torpedoSelections) do
            for head, p in pairs(warheadProbabilities) do
                ui.typeCombo:addEntry(head, getWarheadName(head), getWarheadColor(head))
            end

            local shaft = torpedoShafts[i-1]
            if shaft then
                local preselectedType = shaft.automaticLoadingType
                ui.typeCombo:setSelectedValueNoCallback(preselectedType)
            end
        end

        local hangar, info = entry:getLightweightHangar()
        for i, ui in pairs(self.fighterSelections) do
            local squad = hangar[i - 1]
            ui:setVisible(squad ~= nil)

            if squad then
                -- preselected values
                local example = squad:getBlueprint()
                if not example then
                    example = squad:getFighter(0)
                end

                ui.rarityCombo:clear()

                local rarity = Rarity(RarityType.Common)
                ui.rarityCombo:addEntry(rarity.value, rarity.name, rarity.color);

                if not example or example.type == FighterType.Fighter then
                    -- fighter types for selection
                    local weaponProbabilities = Balancing_GetWeaponProbability(x, y)
                    for type, p in pairs(weaponProbabilities) do
                        if p > 0 then
                            ui.typeCombo:addEntry(type, WeaponTypes.nameByType[type])
                        end
                    end

                    for j = 1, 3 do
                        local rarity = Rarity(j)
                        ui.rarityCombo:addEntry(j, rarity.name, rarity.color);
                    end
                end

                if not example or example.type == FighterType.CrewShuttle then
                    ui.typeCombo:addEntry("shuttle", "Boarding Shuttle"%_t)
                end

                ui.categoryIcon.visible = false
                ui.typeCombo:setSelectedValueNoCallback(WeaponType.ChainGun)

                if example then
                    if example.category == WeaponCategory.Mining then
                        ui.typeCombo:setSelectedValueNoCallback(WeaponType.MiningLaser)
                    elseif example.category == WeaponCategory.Salvaging then
                        ui.typeCombo:setSelectedValueNoCallback(WeaponType.SalvagingLaser)
                    end

                    ui.typeCombo:setSelectedValueNoCallback(WeaponTypes.getTypeOfItem(example))
                    ui.rarityCombo:setSelectedValueNoCallback(example.rarity.value)

                    ui.categoryIcon.visible = true
                    ui.categoryIcon.picture = example.categoryIcon
                end

                ui.squadName = squad.name
                ui.squadFighters = squad.numFighters

                local buyable = 12 - squad.numFighters
                ui.amountSlider.active = buyable > 0
                ui.typeCombo.active = buyable > 0
                ui.rarityCombo.active = buyable > 0
                if buyable > 0 then
                    ui.amountSlider.max = buyable
                else
                    ui.amountSlider.max = 12
                end
                ui.amountSlider.stepSize = 1
                ui.icon.color = ColorRGB(0.9, 0.9, 0.9)
            else
                ui.icon.visible = true
                ui.icon.color = ColorRGB(0.4, 0.4, 0.4)
                ui.icon.tooltip = nil
            end
        end
    end

    self.mapCommands.maintenanceCommandMaxFightersPressed = function()
        for _, fui in pairs(ui.fighterSelections) do
            if fui.amountSlider.visible and fui.amountSlider.active then
                fui.amountSlider:setValueNoCallback(12)
            end
        end

        self.mapCommands[configChangedCallback]()
    end

    return ui
end

-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function MaintenanceCommand:buildUI(startPressedCallback, changeAreaPressedCallback, recallPressedCallback, configChangedCallback)
    local ui = {}
    ui.orderName = "Maintenance"%_t
    ui.icon = MaintenanceCommand:getIcon()

    local size = vec2(850, 700)
    ui.window = GalaxyMap():createWindow(Rect(size))
    ui.window.caption = "Maintenance Operation"%_t

    local settings = {areaHeight = 130, configHeight = 280, hideEscortUI = true}
    ui.commonUI = SimulationUtility.buildCommandUI(ui.window, startPressedCallback, changeAreaPressedCallback, recallPressedCallback, configChangedCallback, settings)

    -- configurable values
    local configValues = self:getConfigurableValues()
    ui.maintenanceUI = self:buildMaintenanceUI(ui.window, ui.commonUI.configRect, configValues, configChangedCallback)

    -- predictable values
    local predictable = self:getPredictableValues()
    local vlist = UIVerticalLister(ui.commonUI.predictionRect, 5, 0)
    vlist.marginTop = 30

    local vsplitYields = UIVerticalSplitter(vlist:nextRect(15), 5, 0, 0.65)
    vsplitYields.marginLeft = 10
    vsplitYields.marginRight = 10
    local label = ui.window:createLabel(vsplitYields.left, predictable.attackChance.displayName .. ":", 12)
    -- as attackChance is static we set it immediately
    ui.commonUI.attackChanceLabel = ui.window:createLabel(vsplitYields.right, "0 %"%_t, 12)
    ui.commonUI.attackChanceLabel:setRightAligned()

    local vsplitYields = UIVerticalSplitter(vlist:nextRect(15), 5, 0, 0.65)
    vsplitYields.marginLeft = 10
    vsplitYields.marginRight = 10
    local label = ui.window:createLabel(vsplitYields.left, predictable.duration.displayName .. ":", 12)
    ui.durationLabel = ui.window:createLabel(vsplitYields.right, "", 12)
    ui.durationLabel:setRightAligned()

    local vsplitYields = UIVerticalSplitter(vlist:nextRect(15), 5, 0, 0.65)
    vsplitYields.marginLeft = 10
    vsplitYields.marginRight = 10
    local label = ui.window:createLabel(vsplitYields.left, predictable.moneyNeeded.displayName .. ":", 12)
    ui.priceLabel = ui.window:createLabel(vsplitYields.right, "", 12)
    ui.priceLabel:setRightAligned()

    -- functions
    ui.clear = function(self, shipName)
        self.commonUI:clear(shipName)
        self.maintenanceUI:clear()
    end

    ui.refresh = function(self, ownerIndex, shipName, area, config)
        self.commonUI:refresh(ownerIndex, shipName, area, config)
        self.maintenanceUI:refresh(ownerIndex, shipName, area, config)

        if not config then
            config = self:buildConfig()
        end

        self:refreshPredictions(ownerIndex, shipName, area, config)
    end

    ui.refreshPredictions = function(self, ownerIndex, shipName, area, config)
        local prediction = MaintenanceCommand:calculatePrediction(ownerIndex, shipName, area, config)
        self:displayPrediction(prediction, config, ownerIndex)

        self.commonUI:refreshPredictions(ownerIndex, shipName, area, config, MaintenanceCommand, prediction)
    end

    ui.displayPrediction = function(self, prediction, config, ownerIndex)
        -- duration
        if prediction.duration.value > 0 then
            self.durationLabel.caption = createReadableShortTimeString(prediction.duration.value)
        end

        -- repairs
        self.maintenanceUI.repairCheckbox.checked = prediction.repairsNecessary
        if prediction.repairsNecessary then
            local text = "Maintenance will always repair the ship."%_t

            if prediction.repairCost > 0 then
                text = text .. "\n\n" .. "¢${repairCost}"%_t % {repairCost = createMonetaryString(prediction.repairCost)}
            else
                text = text .. "\n\n" .. "¢0 (Reconstruction Site nearby)"%_t
            end

            self.maintenanceUI.repairCheckbox.tooltip = text
        else
            self.maintenanceUI.repairCheckbox.tooltip = "No major repairs necessary."%_t
        end

        self.maintenanceUI.hireCrewCombo:setEntryTooltip(1, "Hire the basic crew required for the ship to function."%_t)
        self.maintenanceUI.hireCrewCombo:setEntryTooltip(2, "Hire the maximum possible crew for the ship."%_t)

        -- crew
        if config.crewAction then
            local text = nil
            if config.crewAction == 1 then
                text = "Hire the basic crew required for the ship to function."%_t
            else
                text = "Hire the maximum possible crew for the ship."%_t
            end

            if prediction.crewCost > 0 then
                text = text .. "\n\n" .. "${num} people will be hired"%_t % {num = prediction.hiredCrew}
                text = text .. "\n" .. "Price: ¢${price}"%_t % {price = createMonetaryString(prediction.crewCost)}
                text = text .. "\n" .. "Duration: +${duration} min"%_t % {duration = round(prediction.crewDuration / 60)}
            else
                text = text .. "\n" .. "No more crew necessary."%_t
            end

            self.maintenanceUI.hireCrewCombo:setEntryTooltip(config.crewAction, text)
            self.maintenanceUI.hireCrewWarning.visible = prediction.overpopulated
        else
            self.maintenanceUI.hireCrewCombo.tooltip = nil
            self.maintenanceUI.hireCrewWarning.visible = false
        end

        -- torpedoes
        for i, ui in pairs(self.maintenanceUI.torpedoSelections) do

            ui.amountSlider.description = "0%"
            local color = getWarheadColor(ui.typeCombo.selectedValue)
            if config.torpedoesToBuy[i] then color = getWarheadColor(config.torpedoesToBuy[i].warhead) end
            ui.icon.color = color

            local purchase = prediction.torpedoPurchases[i]
            if purchase then
                local text = ""
                text = text .. "Fill ${percentage}% of free torpedo storage"%_t % purchase
                text = text .. "\n" .. "+${amount} Torpedoes in Storage"%_t % purchase
                if (purchase.amountInLaunchers or 0) > 0 then
                    text = text .. "\n" .. "+${amountInLaunchers} Torpedoes in Launcher Shafts"%_t % purchase
                end
                text = text .. "\n" .. "¢${money}"%_t % {money = createMonetaryString(purchase.price or 0)}

                ui.icon.tooltip = text
                ui.amountSlider.tooltip = text

                local color = getWarheadColor(ui.typeCombo.selectedValue)
                if config.torpedoesToBuy[i] then color = getWarheadColor(config.torpedoesToBuy[i].warhead) end
                ui.icon.color = color

                ui.amountSlider.description = "${percentage}%"%_t % purchase
            else
                ui.icon.tooltip = nil
                ui.amountSlider.tooltip = nil
            end

        end

        -- fighters        
        for i, ui in pairs(self.maintenanceUI.fighterSelections) do
            local text = ui.squadName or ""
            ui.fightersLabel.caption = ui.squadFighters
            ui.amountSlider.description = "0"

            local purchase = prediction.fighterPurchases[i]
            if purchase then
                -- icon caption
                text = text .. "\n" .. "+${amount} Fighters"%_t % purchase
                text = text .. "\n" .. "¢${money}"%_t % {money = createMonetaryString(purchase.price or 0)}

                ui.amountSlider.description = "+${amount}"%_t % purchase
            end

            local text = string.trim(text)
            if text ~= "" then
                ui.icon.tooltip = text
            else
                ui.icon.tooltip = nil
            end
        end

        if prediction.hangarUtilization > prediction.hangarCapacity then
            local capacity = round(prediction.hangarCapacity, 1)
            local utilization = round(prediction.hangarUtilization, 1)
            self.maintenanceUI.hangarErrorLabel.caption = "Hangar capacity full ${utilization}/${capacity}"%_t % {utilization = utilization, capacity = capacity}
        else
            self.maintenanceUI.hangarErrorLabel.caption = ""
        end

        self.priceLabel.caption = "¢${money}"%_t % {money = createMonetaryString(prediction.costs)}

        -- refresh common UI
        self.commonUI:setAttackChance(prediction.attackChance)
    end

    ui.buildConfig = function(self)
        local ui = self.maintenanceUI
        local config = {}

        config.crewAction = self.maintenanceUI.hireCrewCombo.selectedValue

        -- torpedoes
        config.torpedoesToBuy = {}
        for i, ui in pairs(self.maintenanceUI.torpedoSelections) do
            local type = ui.typeCombo.selectedValue or 1
            local rarity = ui.rarityCombo.selectedValue or 0
            local percentage = ui.amountSlider.value or 0

            if percentage > 0 then
                config.torpedoesToBuy[i] = {rarity = rarity, warhead = type, percentage = percentage}
            end
        end

        -- fighters
        config.fightersToBuy = {}
        for i, ui in pairs(self.maintenanceUI.fighterSelections) do
            local type = ui.typeCombo.selectedValue or 1

            if type == "shuttle" then
                -- only allow "Common" for shuttles (there are no others, we don't want to mislead players)
                ui.rarityCombo:clear()

                local rarity = Rarity(RarityType.Common)
                ui.rarityCombo:addEntry(RarityType.Common, rarity.name, rarity.color);
                ui.rarityCombo:setSelectedValueNoCallback(rarity.value)
            else
                -- allow all rarities for armed fighters
                local rarity = Rarity(ui.rarityCombo.selectedValue or 0)

                ui.rarityCombo:clear()
                for i = 0, 3 do
                    local rarity = Rarity(i)
                    ui.rarityCombo:addEntry(i, rarity.name, rarity.color);
                end

                ui.rarityCombo:setSelectedValueNoCallback(rarity.value)
            end

            local rarity = ui.rarityCombo.selectedValue or 0
            local amount = ui.amountSlider.value or 0

            if amount > 0 then
                config.fightersToBuy[i] = {rarity = rarity, weaponType = type, amount = amount}
            end
        end

        return config
    end

    ui.setActive = function(self, active, description)
        self.commonUI:setActive(active, description)
        self.maintenanceUI.hireCrewCombo.active = active
        self.maintenanceUI.maxFightersButton.active = active

        for i, ui in pairs(self.maintenanceUI.torpedoSelections) do
            ui.typeCombo.active = active
            ui.rarityCombo.active = active
            ui.amountSlider.active = active
        end

        for i, ui in pairs(self.maintenanceUI.fighterSelections) do
            ui.typeCombo.active = active
            ui.rarityCombo.active = active
            ui.amountSlider.active = active
        end
    end

    ui.displayConfig = function(self, config, ownerIndex, entry)
        for i, ui in pairs(self.maintenanceUI.torpedoSelections) do
            ui:setVisible(false)
            ui.typeCombo:clear()
            ui.amountSlider:setValueNoCallback(0)
        end
        for i, ui in pairs(self.maintenanceUI.fighterSelections) do
            ui:setVisible(false)
            ui.typeCombo:clear()
            ui.amountSlider:setValueNoCallback(0)
        end

        for i, torpedo in pairs(config.torpedoesToBuy) do
            local ui = self.maintenanceUI.torpedoSelections[i]
            ui:setVisible(true)

            ui.rarityCombo:setSelectedIndexNoCallback(torpedo.rarity)
            ui.typeCombo:addEntry(torpedo.warhead, getWarheadName(torpedo.warhead), getWarheadColor(torpedo.warhead))
            ui.amountSlider:setValueNoCallback(torpedo.percentage)
        end

        local hangar, info = entry:getLightweightHangar()
        for i, fighter in pairs(config.fightersToBuy) do
            local ui = self.maintenanceUI.fighterSelections[i]
            ui:setVisible(true)

            local squad = hangar[i - 1]
            if squad then
                ui.squadName = squad.name
                ui.fightersLabel.caption = squad.numFighters
            else
                ui.squadName = ""
                ui.fightersLabel.caption = ""
            end

            ui.rarityCombo:clear()
            local rarity = Rarity(fighter.rarity)
            ui.rarityCombo:addEntry(rarity.value, rarity.name, rarity.color);

            ui.rarityCombo:setSelectedIndexNoCallback(fighter.rarity)
            if fighter.weaponType == "shuttle" then
                ui.typeCombo:addEntry(fighter.weaponType, "Boarding Shuttle"%_t)
            else
                ui.typeCombo:addEntry(fighter.weaponType, WeaponTypes.nameByType[fighter.weaponType])
            end
            ui.amountSlider:setValueNoCallback(fighter.amount)
        end
    end

    return ui
end


return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
