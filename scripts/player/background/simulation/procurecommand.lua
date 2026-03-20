package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/player/background/simulation/?.lua"

local CommandType = include ("commandtype")
local FactoryMap = include ("factorymap")
local SimulationUtility = include ("simulationutility")
local CaptainUtility = include("captainutility")
local GatesMap = include ("gatesmap")
local SectorSpecifics = include("sectorspecifics")

include ("utility")
include ("stringutility")
include ("goods")


local ProcureCommand = {}
ProcureCommand.__index = ProcureCommand
ProcureCommand.type = CommandType.Procure

-- all commands need this kind of "new" to function within the bg simulation framework
local function new(ship, area, config)
    local command = setmetatable({
        -- all commands need these variables to function within the bg simulation framework
        -- type contains the CommandType of the command, required to restore
        type = CommandType.Procure,

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
        simulation = nil,
    }, ProcureCommand)

    command.data.runTime = 0

    return command
end

function ProcureCommand:initialize()
    local parent = getParentFaction()
    local prediction = self:calculatePrediction(parent.index, self.shipName, self.area, self.config)
    self.data.prediction = prediction

    if prediction.error then
        return prediction.error, prediction.errorArgs
    end
end

function ProcureCommand:update(timeStep)
    self.data.runTime = self.data.runTime + timeStep

    if self.data.runTime >= self.data.prediction.duration.value then
        self:finish()
        return
    end
end

local function isGoodTradeable(name)
    local good = goods[name]
    if good.tags.ore or good.tags.scrap then
        return false
    end

    return true
end

-- executed when an area analysis involving this type of command starts
-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function ProcureCommand:onAreaAnalysisStart(results, meta)
    local factoryMap = FactoryMap()

    local supplyAndDemand = factoryMap:getAreaSupplyAndDemand(meta.area.lower, meta.area.upper)

    results.goodsInArea = {}
    results.smugglerGoodsInArea = {}
    local goodsInSector = {}
    local pricesForGood = {}
    local galaxy = Galaxy()
    local owner = galaxy:findFaction(meta.factionIndex)

    local entry = ShipDatabaseEntry(meta.factionIndex, meta.shipName)
    local captain = entry:getCaptain()
    local captainIsMerchant = captain:hasClass(CaptainUtility.ClassType.Merchant)

    for _, sectorInfo in pairs(supplyAndDemand) do
        goodsInSector = {}
        local faction = galaxy:getControllingFaction(sectorInfo.coordinates.x, sectorInfo.coordinates.y)

        if faction then
            if owner:getRelationStatus(faction.index) == RelationStatus.War then
                if not captainIsMerchant then
                    goto continue -- you can't trade when you're at war
                elseif Galaxy():isCentralFactionArea(sectorInfo.coordinates.x, sectorInfo.coordinates.y, faction.index) then
                    goto continue -- merchants can trade in outer areas of factions they are at war with
                end
            end
        end

        for goodName, supply in pairs(sectorInfo.supply or {}) do
            if isGoodTradeable(goodName) then
                if not pricesForGood[goodName] then pricesForGood[goodName] = {} end

                table.insert(pricesForGood[goodName], factoryMap:supplyToPriceChange(sectorInfo.sum[goodName] or 0))
                results.goodsInArea[goodName] = (results.goodsInArea[goodName] or 0) + 1
                if goodsInSector[goodName] then
                    results.goodsInArea[goodName] = results.goodsInArea[goodName] - 1
                end

                goodsInSector[goodName] = true
            end
        end

        for smugglerGood, _ in pairs(sectorInfo.demand or {}) do
            if isGoodTradeable(smugglerGood) then
                results.smugglerGoodsInArea[smugglerGood] = true
            end
        end

        ::continue::
    end

    results.averagePriceFactors = {}
    results.lowestPriceFactors = {}

    for goodName, priceList in pairs(pricesForGood) do
        local sum = 0
        local lowestFactor = 0
        for _, price in pairs(priceList) do
            sum = sum + price

            if price < lowestFactor then
                lowestFactor = price
            end
        end

        results.averagePriceFactors[goodName] = sum / #pricesForGood[goodName]
        results.lowestPriceFactors[goodName] = lowestFactor
    end
end

-- executed when an area analysis involving this type of command is checking a specific sector
-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function ProcureCommand:onAreaAnalysisSector(results, meta, x, y)

end

-- executed when an area analysis involving this type of command finished
-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function ProcureCommand:onAreaAnalysisFinished(results, meta)

end

-- executed when the command starts for the first time (not when being restored)
function ProcureCommand:onStart()
    local owner = getParentFaction()
    local budget = self.data.prediction.totalBudget
    local canPay, msg, args = owner:canPay(budget)

    if not canPay then return end

    -- the captain receives the entire budget at this point
    owner:pay(Format("Gave the captain of '%1%' a budget of %2% credits to procure goods."%_T, (self.shipName or "")), budget)

    local entry = ShipDatabaseEntry(owner.index, self.shipName)
    entry:setStatusMessage("Procuring"%_t)

    -- set position at which ship is going to reappear
    local startX, startY = entry:getCoordinates()
    self.data.startCoordinates = { x = startX, y = startY }

    if self.data.prediction.attackLocation then
        if self.simulation.disableAttack == true then return end -- for unit tests

        local time = random():getFloat(0.1, 0.75) * self.data.prediction.duration.value
        local location = self.data.prediction.attackLocation
        local x, y = location.x, location.y

        self:registerForAttack({x = x, y = y}, location.faction, time, "Your ship '%1%' is under attack in sector \\s(%2%:%3%)!"%_T, {self.shipName, x, y})
    end
end

-- executed when the ship is being recalled by the player
function ProcureCommand:onRecall()
    if self.data.runTime >= 11 * 60 then -- captain needs at least 11 minutes to buy something
        local percentageCompleted = self.data.runTime / self.data.prediction.duration.value
        self:finishProcureCommand(percentageCompleted)
    else
        self:addYield("We haven't managed to acquire any goods yet. Here's your down payment back."%_t, self.data.prediction.totalBudget, {}, {})
    end
end

function ProcureCommand:onAttacked()
end

-- executed when the command is finished
function ProcureCommand:onFinish()
    self:finishProcureCommand(1)

    local parent = getParentFaction()
    local entry = ShipDatabaseEntry(parent.index, self.shipName)
    local captain = entry:getCaptain()

    if captain:hasClass(CaptainUtility.ClassType.Explorer) then
        self:onExplorerFinish(captain)
    end
end

function ProcureCommand:onExplorerFinish(captain)
    local faction = getParentFaction()
    local specs = SectorSpecifics()
    local seed = Server().seed

    local notes = {}
    table.insert(notes, "Commander, I marked this sector on the map for you.\n\nRegards, Captain ${name}"%_T)
    table.insert(notes, "Commander, we discovered this sector that you didn't have on the map yet.\n\nRegards, Captain ${name}"%_T)
    table.insert(notes, "Discovered a sector here.\n\nRegards, Captain ${name}"%_T)
    table.insert(notes, "As a small courtesy, I explored this sector for you.\n\nRegards, Captain ${name}"%_T)

    local revealed = 0
    local gatesMap

    for _, coords in pairs(self.area.analysis.reachableCoordinates) do
        local x, y = coords.x, coords.y
        local regular, offgrid = specs.determineFastContent(x, y, seed)

        -- regular and offgrid can be changed into each other depending on central region or no man's space
        if not regular and not offgrid then goto continue end

        local regular, offgrid, blocked, home = specs:determineContent(x, y, seed)
        if not regular then goto continue end
        if blocked then goto continue end -- there can't be anything if the sector is blocked

        local view = faction:getKnownSector(x, y)
        if view then goto continue end -- don't override existing data

        view = SectorView()
        gatesMap = gatesMap or GatesMap(GameSeed())

        specs:initialize(x, y, seed)
        specs:fillSectorView(view, gatesMap, true)

        view.note = NamedFormat(randomEntry(notes), {name = captain.name})
        -- make sure that no new icons are created
        if view.tagIconPath == "" then view.tagIconPath = "data/textures/icons/nothing.png" end

        faction:addKnownSector(view)

        revealed = revealed + 1
        if revealed >= 5 then break end

        ::continue::
    end
end

function ProcureCommand:finishProcureCommand(percentageCompleted)
    local percentageCompleted = percentageCompleted or 1
    local parent = getParentFaction()
    local entry = ShipDatabaseEntry(parent.index, self.shipName)
    local captain = entry:getCaptain()

    -- restore starting position of procure command
    if self.data.startCoordinates and percentageCompleted >= 1 then
        local startX = self.data.startCoordinates.x
        local startY = self.data.startCoordinates.y
        entry:setCoordinates(startX, startY)
    end

    local surpriseDiscount = 0.9 -- the money that wasn't spent (the percentage of the budget that is returned to player), at least 10% because that was the captainsGuess

    if random():test(self.data.prediction.discountChance.value) then
        surpriseDiscount = 0.8
    end

    local totalBudgetSpent = self.data.prediction.totalBudget * percentageCompleted * surpriseDiscount
    local moneyReturnedToOwner = self.data.prediction.totalBudget - totalBudgetSpent

    local cargos, cargoHold = entry:getCargo()

    local captainIsSmuggler = captain:hasClass(CaptainUtility.ClassType.Smuggler)
    for _, good in pairs(self.config.goodsToBuy) do
        if good then
            local tradingGood = goods[good.name]:good()

            if captainIsSmuggler and not self.area.analysis.goodsInArea[good.name] then
                tradingGood.stolen = true
            elseif good.stolen == true then
                tradingGood.stolen = true
            end

            cargos[tradingGood] = (cargos[tradingGood] or 0) + math.ceil(good.amount * percentageCompleted)
        end
    end

    entry:setCargo(cargos)

    local sellingFaction = self.area.analysis.biggestFactionInArea
    if sellingFaction then
        local relationsChange = GetRelationChangeFromMoney(totalBudgetSpent) * 0.15 -- only a quarter of the usual relations because it was captain who did the trading
        changeRelations(parent.index, sellingFaction, relationsChange, RelationChangeType.GoodsTrade)
    end

    if percentageCompleted == 1 then -- this means that the command was finished regularly
        self:addYield("We have finished acquiring goods. The goods are in our cargo bay. We are sending you what is left of our budget."%_t, moneyReturnedToOwner, {}, {})
    else -- this means that captain was recalled
        self:addYield("We had begun to acquire goods. The goods we managed to buy before you called us back are in our cargo bay. We are sending you what is left of our budget."%_t, moneyReturnedToOwner, {}, {})
    end

    -- send chat message that ship is finished
    local x, y = entry:getCoordinates()
    parent:sendChatMessage(self.shipName, ChatMessageType.Information, "%1% has finished procuring goods and is awaiting your next orders in \\s(%2%:%3%)."%_T, self.shipName, x, y)
end

-- after this function was called, self.data will be read to be saved to database
function ProcureCommand:onSecure()
end

-- this is called after the command was recreated and self.data was assigned
function ProcureCommand:onRestore()
end

function ProcureCommand:getAreaSize(ownerIndex, shipName)
    return {x = 11, y = 11}
end

function ProcureCommand:getAreaBounds()
    return {lower = self.area.lower, upper = self.area.upper}
end

function ProcureCommand:isAreaFixed(ownerIndex, shipName)
    return false
end

function ProcureCommand:isShipRequiredInArea(ownerIndex, shipName)
    return true
end

function ProcureCommand:getIcon()
    return "data/textures/icons/procure-command.png"
end

function ProcureCommand:getDescriptionText()
    local totalRuntime = self.data.prediction.duration.value
    local timeRemaining = round((totalRuntime - self.data.runTime) / 60)
    local completed = round(self.data.runTime / totalRuntime * 100)

    return "The ship is procuring goods.\n\nTime remaining: ${timeRemaining} (${completed} % done)."%_T, {timeRemaining = createReadableShortTimeString(timeRemaining * 60), completed = completed}
end

function ProcureCommand:getStatusMessage()
    return "Procuring"%_t
end

function ProcureCommand:getRecallError()
end

-- returns whether the config sent by a client has errors
-- note: before this is called, there is already a preliminary check based on getConfigurableValues(), where values are clamped or default-set
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function ProcureCommand:getErrors(ownerIndex, shipName, area, config)

    -- error independent of config
    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    if entry:getFreeCargoSpace() == 0 then
        return "Not enough cargo space!"%_t, {}
    end

    -- config based errors
    local prediction = self:calculatePrediction(ownerIndex, shipName, area, config)

    if prediction.cargoSpaceMissing.value > 0 then
       return "Not enough cargo space!"%_t, {}
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

    local canPay, msg, args = owner:canPay(prediction.totalBudget)
    if not canPay then
        return msg, args
    end

    -- check whether player selected at least one good
    local goodSelected = false
    for _, good in pairs(config.goodsToBuy) do
        if good then
            goodSelected = true
        end

        if good and good.amount == 0 then
            if entry:getFreeCargoSpace() < goods[good.name]:good().size then
                return "Not enough cargo space!"%_t, {}
            else
                return "No amount to procure selected!"%_t, {}
            end
        end
    end

    if goodSelected == false then
        return "No good selected!"%_t, {}
    end
end

function ProcureCommand:getAreaSelectionTooltip(ownerIndex, shipName, area, valid)
    return "Left-Click to select the area to procure in"%_t
end

-- returns the configurable values for this command (if any).
-- variable naming should speak for itself, though you're free to do whatever you want in here.
-- config will only be used by the command itself and nothing else
-- this may be called on a temporary instance of the command. all values written to "self" may not persist
function ProcureCommand:getConfigurableValues(ownerIndex, shipName)
    local values = { }

    -- value names here must match with values returned in ui:buildConfig() below
    values.goods = {}
    values.amounts = {}

    for i = 1, 5 do
        table.insert(values.goods, {displayName = "Good to procure"%_t, default = ""})
        table.insert(values.amounts, {displayName = "Amount of good"%_t, from = 0, to = 100, segments = 0, default = 0})
    end  

    return values
end

-- returns the predictable values for this command (if any).
-- variable naming should speak for itself, though you're free to do whatever you want in here.
-- config will only be used by the command itself and nothing else
-- this may be called on a temporary instance of the command. all values written to "self" may not persist
function ProcureCommand:getPredictableValues()
    local values = { }

    values.factors = {}
    values.budgets = {}
    values.tooltips = {}

    for i = 1, 6 do
        table.insert(values.budgets, {value = 0})
    end

    values.attackChance = {displayName = SimulationUtility.AttackChanceLabelCaption, value = 0}
    values.duration = {displayName = "Duration"%_t, value = 0}
    values.totalBudget = {displayName = "Estimated Total Price"%_t, value = 0}
    values.discountChance = {displayName = "Discount Chance"%_t, value = 0}
    values.cargoSpaceMissing = {displayName = "Required Cargo Space"%_t, value = 0}

    return values
end

-- calculate the predictions for the ship, area and config
-- gut feeling says that each config option change should always be reflected in the predictions if it impacts the behavior
-- this may be called on a temporary instance of the command. all values written to "self" may not persist
function ProcureCommand:calculatePrediction(ownerIndex, shipName, area, config)
    local results = self:getPredictableValues()
    local tradingSystemInstalled = false

    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local subsystems = entry:getSystems()
    for subsystem, _ in pairs(subsystems) do
        if subsystem.script == "data/scripts/systems/tradingoverview.lua"
                or string.match(subsystem.script, "/systems/hypertradingsystem.lua") then
            tradingSystemInstalled = true
            results.bestPrice = true
            results.tradingUpgrade = true
            break
        end
    end

    local captain = entry:getCaptain()
    local shipX, shipY = entry:getCoordinates()

    local totalBudget = 0
    local reducedBudget = 0
    local reducedBudgets = {0, 0, 0, 0, 0}
    local priceFactors = {0, 0, 0, 0, 0}
    local reducedPriceFactors = {0, 0, 0, 0, 0}
    local duration = 10 * 60 -- base duration any trade command takes
    local transactionVolume = 1500 -- volume of cargo hold the captain can fill per trade/station
    local minDurationPerTrade = 2 * 60 -- we imagine that the trader can only acquire a certain number of goods per trade/station
    local maxDurationPerTrade = 5 * 60
    local basePerDifferentGood = 2 * 60
    local captainsGuess = 1.1 -- the percentage (10%) the captain guesses the goods will cost more than they actually cost so that player gets money back
    local requiredCargoSpace = 0
    local size = self.getAreaSize()
    local areaSize = (size.x * size.y) - area.analysis.unreachable + 1


    -- sort config by name to prevent inconsistencies in duration calculation
    local sortedConfig = {}
    local goodsCopy = table.deepcopy(config.goodsToBuy)
    for _, goodToBuy in pairs(goodsCopy) do
        local name = goodToBuy.name
        if not sortedConfig[name] then
            sortedConfig[name] = goodToBuy
        else
            sortedConfig[name].amount = sortedConfig[name].amount + goodToBuy.amount
        end
    end

    for name, goodToBuy in pairs(sortedConfig) do
        local amount = goodToBuy.amount or 0
        local good = goods[name]:good()

        -- cargo space
        local requiredCargoSpaceForGood = good.size * amount
        requiredCargoSpace = requiredCargoSpace + requiredCargoSpaceForGood

        -- duration calculation
        local availabilityPerSector = (areaSize - (area.analysis.goodsInArea[name] or 0)) / areaSize
        local durationPerGood = 0
        for i = 1, math.ceil(requiredCargoSpaceForGood / transactionVolume) do
            durationPerGood = durationPerGood + math.max(minDurationPerTrade, availabilityPerSector * maxDurationPerTrade)
        end

        duration = duration + math.ceil(durationPerGood)
        if amount > 0 then
            duration = duration + basePerDifferentGood
        end

        -- if the amount of a certain good exceeds a certain number, the duration increases by 45 minutes
        -- (since it wouldn't be logical that the captain can find so much of one good)
        -- the threshold is based on the amount of good a factory in that area would have in stock
        local maxValue = 750 * 1000 * Balancing_GetSectorRichnessFactor(shipX, shipY)
        local threshold = maxValue / (good.price or 1)
        if threshold < 50 then threshold = 50 end

        if amount > threshold then
            local additionalFlights = math.floor(amount / threshold)
            duration = duration + (20 * 60 * additionalFlights)
            results.durationWarning = true
        end
    end

    for _, goodToBuy in pairs(config.goodsToBuy) do
        local name = goodToBuy.name
        local amount = goodToBuy.amount or 0
        local good = goods[name]:good()

        -- budget calculation
        if area.analysis.averagePriceFactors then
            local priceFactor = area.analysis.averagePriceFactors[name]
            local tradingSystemPriceFactor = area.analysis.lowestPriceFactors[name]

            -- if good cannot be found in area (i.e has no entry in averagePriceFactors) it will be twice the base price for that good
            local regularGoodFactor = good.price + good.price * (priceFactor or 1)
            local tradingSystemFactor = good.price + good.price * (tradingSystemPriceFactor or 1)

            if not area.analysis.averagePriceFactors[name] and not area.analysis.lowestPriceFactors[name] then
                results.tooltips[goodToBuy.slot] = "No supply for the good in this area. It can only be bought at a very high price."%_t
            end

            -- smuggler can buy stolen goods and goods with only demand
            if captain:hasClass(CaptainUtility.ClassType.Smuggler) then
                -- if good cannot be found in area (i.e has no entry in averagePriceFactors) it will be half the base price for that good
                regularGoodFactor = good.price + good.price * (priceFactor or 0.5)
                tradingSystemFactor = good.price + good.price * (tradingSystemPriceFactor or 0.5)

                if goodToBuy.stolen == true and priceFactor then
                    -- if good can be found in area BUT is marked as stolen it will be half as expensive as the local price for that sector
                    regularGoodFactor = (good.price + good.price * priceFactor) * 0.5
                    tradingSystemFactor = (good.price + good.price * tradingSystemPriceFactor) * 0.5
                end

                -- rift research data takes long to procure
                if goodToBuy.name == "Rift Research Data" then
                    duration = duration + 45 * amount
                end
            end

            results.budgets[goodToBuy.slot].value = math.ceil(regularGoodFactor * amount * captainsGuess)
            reducedBudgets[goodToBuy.slot] = math.ceil(tradingSystemFactor * amount * captainsGuess)

            -- calculate percentage that price deviates from regular price
            if amount > 0 then
                priceFactors[goodToBuy.slot] = round(results.budgets[goodToBuy.slot].value / (amount) * 100 / good.price)
                reducedPriceFactors[goodToBuy.slot] = round(reducedBudgets[goodToBuy.slot] / (amount) * 100 / good.price)
            end

            totalBudget = totalBudget + results.budgets[goodToBuy.slot].value
            reducedBudget = reducedBudget + reducedBudgets[goodToBuy.slot]
        end
    end

    -- with trading system player always gets lowest price
    if tradingSystemInstalled == true then
        totalBudget = reducedBudget
        results.factors = reducedPriceFactors
    else
        results.factors = priceFactors
    end

    -- smuggler captains don't have to slow down when transporting special goods
    if not captain:hasClass(CaptainUtility.ClassType.Smuggler) then
        local stolenOrIllegal, dangerousOrSuspicious = SimulationUtility.getSpecialCargoCategories(entry:getCargo())

        -- merchant captains don't have to slow down when transporting dangerous or suspicious goods
        if captain:hasClass(CaptainUtility.ClassType.Merchant) then
            dangerousOrSuspicious = false
        end

        -- cargo on ship that would lead to controls increases duration by 15 %
        if stolenOrIllegal or dangerousOrSuspicious then
            duration = duration * 1.15
        end
    end

    -- captain influence on duration and budget
    -- check market expert first because he has a different base price
    if captain:hasPerk(CaptainUtility.PerkType.MarketExpert) then
        totalBudget = reducedBudget
        for i = 1, 5 do
            results.budgets[i].value = reducedBudgets[i]
            results.factors[i] = reducedPriceFactors[i] or 0
        end

        results.bestPrice = true
        results.marketExpert = true
    end

    -- check if perks influence duration or price
    local durationFactor = 1
    local priceFactor = 0

    for _, perk in pairs({captain:getPerks()}) do
        durationFactor = durationFactor * (1 + CaptainUtility.getProcureTimePerkImpact(captain, perk))
        priceFactor = priceFactor + CaptainUtility.getProcurePricePerkImpact(captain, perk)
    end

    duration = duration * durationFactor
    totalBudget = math.ceil(totalBudget + totalBudget * priceFactor)
    for i = 1, 5 do
        if results.budgets[i].value then
            results.budgets[i].value = math.ceil(results.budgets[i].value + results.budgets[i].value * priceFactor) or 0
        end

        if results.factors[i] then
            results.factors[i] = math.ceil(results.factors[i] + results.factors[i] * priceFactor) or 0
        end
    end

    for i = 1, 5 do
        if results.factors[i] ~= 0 then
            if results.factors[i] < 100 then
                results.factors[i] = "-" .. 100 - results.factors[i]
            else
                results.factors[i] = "+" .. results.factors[i] - 100
            end
        end
    end

    -- merchant influences duration & discount
    local discountChance = 0.05
    if captain:hasClass(CaptainUtility.ClassType.Merchant) then
        duration = math.floor(duration * 0.85)
        discountChance = 0.1
    end

    -- results
    local freeCargoSpace = entry:getFreeCargoSpace()
    results.freeCargoSpace = freeCargoSpace
    results.requiredCargoSpace = requiredCargoSpace
    results.cargoSpaceMissing.value = math.max(0, requiredCargoSpace - freeCargoSpace)
    results.duration.value = math.max(math.ceil(duration / 60) * 60, 5 * 60)
    results.attackChance.value, results.attackLocation = SimulationUtility.calculateAttackProbability(ownerIndex, shipName, area, config.escorts, duration / 3600)
    results.totalBudget = totalBudget
    results.discountChance.value = discountChance

    if results.cargoSpaceMissing.value > 0 then
        results.error = "We don't have enough cargo space to buy goods."%_t
    end

    return results
end

local function getRegionLines(area, config)
    local result = {}

    local lowestPriceFactor = 0
    for _, good in pairs(config.goodsToBuy) do
        if good and (area.analysis.lowestPriceFactors[good.name] or 0) > lowestPriceFactor then
            lowestPriceFactor = area.analysis.lowestPriceFactors[good.name] or 0
        end
    end

    if lowestPriceFactor > 0.4 then
        table.insert(result, "I should be able to procure the goods for a very low price here."%_t)
        table.insert(result, "This area seems very promising. I will be able to buy cheap goods here."%_t)
        table.insert(result, "The area has a lot of supply. I will be able to buy goods at very good prices."%_t)
    elseif lowestPriceFactor > 0.25 then
        table.insert(result, "The supply here could be better, but I will be able to buy goods at reasonable prices."%_t)
        table.insert(result, "This area looks alright. There are some traders, I think I can get reasonable prices here."%_t)
        table.insert(result, "There are some good merchants in this area, we should be able to get some good deals."%_t)
     elseif lowestPriceFactor > -0.25 then
        table.insert(result, "\\c(dd5)This is not a good area for buying goods. Perhaps we should try another area where the goods will be less expensive.\\c()"%_t)
        table.insert(result, "\\c(dd5)According to initial calculations, this area is not ideal, it will be expensive to buy goods here.\\c()"%_t)
    else
        table.insert(result, "\\c(d93)This area is not suitable for purchasing goods. We can do the job, but the prices will be very high.\\c()"%_t)
        table.insert(result, "\\c(d93)I can try to buy goods here, but I don't think we can expect good prices in this area.\\c()"%_t)
        table.insert(result, "\\c(d93)In this area it may be difficult to buy goods for a reasonable price. We should try another area.\\c()"%_t)
    end

    return result
end

function ProcureCommand:generateAssessmentFromPrediction(prediction, captain, ownerIndex, shipName, area, config)
    local total = area.analysis.sectors - area.analysis.unreachable
    if total == 0 then return "There are no stations in this area that we can trade with."%_t end

    local pirates = area.analysis.sectorsByFaction[0] or 0
    local attackChance = prediction.attackChance.value
    local pirateSectorRatio = SimulationUtility.calculatePirateAttackSectorRatio(area)

    local regionLines = getRegionLines(area, config)

    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local captain = entry:getCaptain()
    local cargo = entry:getCargo()
    local stolenOrIllegal, dangerousOrSuspicious = SimulationUtility.getSpecialCargoCategories(cargo)
    local cargobayLines = SimulationUtility.getIllegalCargoAssessmentLines(stolenOrIllegal, dangerousOrSuspicious, captain)

    local pirateLines = SimulationUtility.getPirateAssessmentLines(pirateSectorRatio)
    local attackLines = SimulationUtility.getAttackAssessmentLines(attackChance)
    local underRadar, returnLines = SimulationUtility.getDisappearanceAssessmentLines(attackChance)

    local rnd = Random(Seed(captain.name))

    return {
        randomEntry(rnd, regionLines),
        randomEntry(rnd, pirateLines),
        randomEntry(rnd, attackLines),
        randomEntry(rnd, cargobayLines),
        randomEntry(rnd, underRadar),
        randomEntry(rnd, returnLines),
    }
end

-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function ProcureCommand:buildUI(startPressedCallback, changeAreaPressedCallback, recallPressedCallback, configChangedCallback)
    local ui = {}

    ui.orderName = "Procure"%_t
    ui.icon = ProcureCommand:getIcon()

    local size = vec2(700, 700)
    local numSelectableGoods = 5

    ui.window = GalaxyMap():createWindow(Rect(size))
    ui.window.caption = "Procurement Contract"%_t

    ui.commonUI = SimulationUtility.buildCommandUI(ui.window, startPressedCallback, changeAreaPressedCallback, recallPressedCallback, configChangedCallback, {configHeight = 225, changeAreaButton = true})

    -- background frames
    local hsplitConfig = UIArbitraryHorizontalSplitter(ui.commonUI.configRect, 0, 0, 30, 68, 108, 146, 188)
    ui.frames = {}
    for i = 1, (numSelectableGoods + 1) do
        if i % 2 == 0 then
            local frame = ui.window:createFrame(hsplitConfig:partition(i-1))
            frame.backgroundColor = ColorARGB(0.1, 0.9, 0.9, 0.9)
            table.insert(ui.frames, frame)
        end
    end

    -- configurable values
    local configValues = self:getConfigurableValues()

    local vsplitConfig = UIArbitraryVerticalSplitter(ui.commonUI.configRect, 5, 5, 190, 250, 460, 585)

    -- goods
    local vlist0 = UIVerticalLister(vsplitConfig:partition(0), 10, 0)
    ui.window:createLabel(vlist0:nextRect(20), " Goods:"%_t, 13)

    ui.goodComboBoxes = {}

    for i = 1, numSelectableGoods do
        local hsplitCombo = UIVerticalSplitter(vlist0:nextRect(30), 0, 0, 0.85)
        ui.goodComboBoxes[i] = ui.window:createValueComboBox(hsplitCombo.left, "onGoodChanged");
        ui.goodComboBoxes[i].height = 25
        ui.goodComboBoxes[i].width = 185
    end

    -- 'stolen' check boxes
    local vlist1 = UIVerticalLister(vsplitConfig:partition(1), 10, 0)
    ui.window:createLabel(vlist1:nextRect(20), "", 13)

    ui.stolenCheckBoxes = {}
    ui.stolenIcons = {}
    for i = 1, numSelectableGoods do
        local vsplit = UIVerticalSplitter(vlist1:nextRect(30), 0, 5, 0.5)
        vsplit:setRightQuadratic()
        ui.stolenCheckBoxes[i] = ui.window:createCheckBox(vsplit.left, " ", configChangedCallback);
        ui.stolenCheckBoxes[i].tooltip = "Procure goods illegally.\nGoods will be flagged as 'stolen'.\nCaptain will be able to... 'buy' them for only 50% of the usual price."%_t
        ui.stolenCheckBoxes[i].captionLeft = false
        ui.stolenIcons[i] = ui.window:createPicture(vsplit.right, "data/textures/icons/domino-mask.png");
        ui.stolenIcons[i].width = 20
        ui.stolenIcons[i].isIcon = true
    end

    -- amounts
    local vlist2 = UIVerticalLister(vsplitConfig:partition(2), 10, 0)
    ui.window:createLabel(vlist2:nextRect(20), " Amount:"%_t, 13)

    ui.amountSliders = {}
    ui.amountBoxes = {}

    for i = 1, numSelectableGoods do
        local hsplit = UIVerticalSplitter(vlist2:nextRect(30), 0, 0, 0.7)
        ui.amountSliders[i] = ui.window:createSlider(hsplit.left, configValues.amounts[i].from, configValues.amounts[i].to, configValues.amounts[i].segments, " ", "onAmountSliderChanged")
        ui.amountSliders[i].showValue = false
        ui.amountSliders[i].showDescription = true

        local hsplitRight = UIVerticalSplitter(hsplit.right, 0, 0, 0.1)
        ui.amountBoxes[i] = ui.window:createTextBox(hsplitRight.right, "onAmountBoxChanged")
        ui.amountBoxes[i].allowedCharacters = "0123456789"
        ui.amountBoxes[i].text = ui.amountSliders[i].value
    end

    -- prices
    local vlist3 = UIVerticalLister(vsplitConfig:partition(3), 10, 0)
    local hsplit = UIVerticalSplitter(vlist3:nextRect(20), 0, 5, 0.05)
    ui.window:createLabel(hsplit.right, "Estimated Price:"%_t, 13)

    ui.budgetLabels = {}

    for i = 1, numSelectableGoods do
        local hsplit = UIVerticalSplitter(vlist3:nextRect(30), 0, 5, 0.05)
        ui.budgetLabels[i] = ui.window:createLabel(hsplit.right, "", 15)
        ui.budgetLabels[i].tooltip = "Estimation of how much the captain will have to spend on the good."%_t
    end

    -- percentages
    local vlist4 = UIVerticalLister(vsplitConfig:partition(4), 10, 0)
    local hsplit = UIVerticalSplitter(vlist4:nextRect(20), 0, 5, 0.05)
    ui.percentageLabel = ui.window:createLabel(hsplit.right, "+-%:"%_t, 13)
    ui.percentageLabel.tooltip = "Percentage of how much the price diverges from the regular price of the good."%_t

    ui.factorsLabels = {}

    for i = 1, numSelectableGoods do
        local hsplit = UIVerticalSplitter(vlist4:nextRect(30), 0, 5, 0.05)
        ui.factorsLabels[i] = ui.window:createLabel(hsplit.right, "", 15)
    end

    -- callbacks
    self.mapCommands.onGoodChanged = function(comboBox)
        local index = 0
        for i = 1, #ui.goodComboBoxes do
            if ui.goodComboBoxes[i].index == comboBox.index then
                index = i
                break
            end
        end

        ui.amountSliders[index]:setValueNoCallback(0)
        ui.amountSliders[index].description = tostring(0)
        ui.amountBoxes[index].text = 0
        ui.budgetLabels[index].caption = string.format("¢%s", 0)
        ui.factorsLabels[index].caption = string.format("", 0)

        self.mapCommands[configChangedCallback]()
    end

    self.mapCommands.onAmountBoxChanged = function(box)
        local index = 0
        for i = 1, #ui.amountBoxes do
            if ui.amountBoxes[i].index == box.index then
                index = i
                break
            end
        end

        local text = ui.amountBoxes[index].text or "0"
        local max = ui.amountSliders[index].max or 0
        if text ~= "" and tonumber(text) > max then
            ui.amountBoxes[index].text = ui.amountSliders[index].max
        end

        local value = tonumber(ui.amountBoxes[index].text) or 0
        ui.amountSliders[index].description = tostring(value)
        ui.amountSliders[index]:setValueNoCallback(tonumber(value))
        self.mapCommands[configChangedCallback]()
    end

    self.mapCommands.onAmountSliderChanged = function(slider)
        local index = 0
        for i = 1, #ui.amountSliders do
            if ui.amountSliders[i].index == slider.index then
                index = i
                break
            end
        end

        ui.amountSliders[index].description = tostring(slider.value)
        ui.amountBoxes[index].text = ui.amountSliders[index].value or 0
        self.mapCommands[configChangedCallback]()
    end

    -- yields & issues
    local predictable = self:getPredictableValues()

    local vlist = UIVerticalLister(ui.commonUI.predictionRect, 0, 0)

    -- attack chance
    local vsplit0 = UIVerticalSplitter(vlist:nextRect(20), 0, 0, 0.6)
    local label = ui.window:createLabel(vsplit0.left, predictable.attackChance.displayName .. ":", 12)
    label.tooltip = SimulationUtility.AttackChanceLabelTooltip
    ui.commonUI.attackChanceLabel = ui.window:createLabel(vsplit0.right, "", 12)
    ui.commonUI.attackChanceLabel:setRightAligned()

    -- duration
    local vsplit1 = UIVerticalSplitter(vlist:nextRect(20), 0, 0, 0.6)
    local label = ui.window:createLabel(vsplit1.left, predictable.duration.displayName .. ":", 12)
    ui.durationLabel = ui.window:createLabel(vsplit1.right, "", 12)
    ui.durationLabel:setRightAligned()

    -- total budget
    local vsplit2 = UIVerticalSplitter(vlist:nextRect(20), 0, 0, 0.6)
    local label = ui.window:createLabel(vsplit2.left, predictable.totalBudget.displayName .. ":", 12)
    label.tooltip = "Credits you need to give to the captain in advance. They will return everything they don't spend."%_t
    ui.totalBudgetLabel = ui.window:createLabel(vsplit2.right, "", 12)
    ui.totalBudgetLabel.tooltip = "Credits you need to give to the captain in advance. They will return everything they don't spend."%_t
    ui.totalBudgetLabel:setRightAligned()

    -- discount chance
    local vsplit2 = UIVerticalSplitter(vlist:nextRect(20), 0, 0, 0.6)
    local label = ui.window:createLabel(vsplit2.left, predictable.discountChance.displayName .. ":", 12)
    label.tooltip = "Chance that the captain will find a discount."%_t
    ui.discountChanceLabel = ui.window:createLabel(vsplit2.right, "", 12)
    ui.discountChanceLabel.tooltip = "Chance that the captain will find a discount."%_t
    ui.discountChanceLabel:setRightAligned()

    vlist:nextRect(20)

    -- cargo space
    local vsplit3 = UIVerticalSplitter(vlist:nextRect(20), 0, 0, 0.6)
    local label = ui.window:createLabel(vsplit3.left, predictable.cargoSpaceMissing.displayName .. ":", 12)
    ui.cargoSpaceLabel = ui.window:createLabel(vsplit3.right, "", 12)
    ui.cargoSpaceLabel:setRightAligned()

    ui.cargoSpaceBar = ui.window:createStatisticsBar(vlist:nextRect(30), ColorRGB(1, 1, 1))
    ui.cargoSpaceBar.height = 15
    ui.cargoSpaceBar:setRange(0, 0)

    local hsplitBottom = UIHorizontalSplitter(Rect(size), 10, 10, 0.5)
    hsplitBottom.bottomSize = 40
    local vsplit = UIVerticalMultiSplitter(hsplitBottom.bottom, 10, 0, 3)

    ui.clear = function(self, shipName)
        self.commonUI:clear(shipName)

        for i = 1, numSelectableGoods do
            self.budgetLabels[i].caption = string.format("¢%s", 0)
            self.factorsLabels[i].caption = string.format("")
        end

        self.totalBudgetLabel.caption = string.format("¢%s", 0)
        self.cargoSpaceLabel.caption = "0 / 0"
        self.durationLabel.caption = "0 min"
        self.commonUI.attackChanceLabel.caption = ""
    end

    ui.showMerchantLines = function(self)
        for i = 1, numSelectableGoods do
            self.goodComboBoxes[i]:show()
            self.amountSliders[i]:show()
            self.amountBoxes[i]:show()
            self.stolenIcons[i]:show()
            self.budgetLabels[i]:show()
            self.factorsLabels[i]:show()
            self.frames[3]:show()
            self.stolenCheckBoxes[i]:hide()
            self.stolenIcons[i]:hide()
        end
    end

    ui.showSmugglerLines = function(self)
        self.goodComboBoxes[numSelectableGoods]:hide()
        self.amountSliders[numSelectableGoods]:hide()
        self.amountBoxes[numSelectableGoods]:hide()
        self.stolenCheckBoxes[numSelectableGoods]:hide()
        self.stolenIcons[numSelectableGoods]:hide()
        self.budgetLabels[numSelectableGoods]:hide()
        self.factorsLabels[numSelectableGoods]:hide()
        self.frames[3]:hide()

        self.goodComboBoxes[numSelectableGoods - 1]:show()
        self.amountSliders[numSelectableGoods - 1]:show()
        self.amountBoxes[numSelectableGoods - 1]:show()
        self.stolenCheckBoxes[numSelectableGoods - 1]:show()
        self.stolenIcons[numSelectableGoods - 1]:show()
        self.budgetLabels[numSelectableGoods - 1]:show()
        self.factorsLabels[numSelectableGoods - 1]:show()

        for i = 1, numSelectableGoods - 1 do
            self.stolenCheckBoxes[i]:show()
            self.stolenIcons[i]:show()
        end
    end

    ui.showRegularLines = function(self)
        for i = numSelectableGoods - 1, numSelectableGoods do
            self.goodComboBoxes[i]:hide()
            self.amountSliders[i]:hide()
            self.amountBoxes[i]:hide()
            self.stolenCheckBoxes[i]:hide()
            self.stolenIcons[i]:hide()
            self.budgetLabels[i]:hide()
            self.factorsLabels[i]:hide()
        end

        self.frames[3]:hide()

        for i = 1, numSelectableGoods do
            self.stolenCheckBoxes[i]:hide()
            self.stolenIcons[i]:hide()
        end
    end

    -- used to fill values into the UI
    -- config == nil means fill with default values
    ui.refresh = function(self, ownerIndex, shipName, area, config)
        self.commonUI:refresh(ownerIndex, shipName, area, config)

        local captainIsMerchant = false
        local captainIsSmuggler = false
        local numSelectableGoods = 5

        if config then
            numSelectableGoods = config.numSelectableGoods or 5
        end

        local entry = ShipDatabaseEntry(ownerIndex, shipName)
        if valid(entry) then
            local captain = entry:getCaptain()
            if valid(captain) then
                if captain:hasClass(CaptainUtility.ClassType.Smuggler) then captainIsSmuggler = true end
                if captain:hasClass(CaptainUtility.ClassType.Merchant) then captainIsMerchant = true end
            end
        end

        local goodsInArea = {}
        for goodName, _ in pairs(area.analysis.goodsInArea) do
            table.insert(goodsInArea, goodName)
        end

        function sortGoodsByName(a, b) return goods[a]:good():displayName(1) < goods[b]:good():displayName(1) end
        table.sort(goodsInArea, sortGoodsByName)

        for i = 1, numSelectableGoods do
            self.goodComboBoxes[i]:clear()
            self.goodComboBoxes[i]:addEntry("", "")
        end

        local normalIllegalAndDangerousGoods = goodsInArea
        local normalAndDangerousGoods = {}
        local normalGoods = {}

        local goodsInComboBox = {}

        if captainIsSmuggler and not captainIsMerchant then
            self:showSmugglerLines()
            goodsInComboBox = normalIllegalAndDangerousGoods
        elseif captainIsMerchant then
            self:showMerchantLines()

            if captainIsSmuggler then
                for i = 1, numSelectableGoods do
                    self.stolenCheckBoxes[i]:show()
                    self.stolenIcons[i]:show()
                end
            end

            for _, good in pairs(goodsInArea) do
                if not goods[good]:good().illegal then
                    table.insert(normalAndDangerousGoods, good)
                end
            end

            goodsInComboBox = normalAndDangerousGoods
        else
            self:showRegularLines()

            for _, good in pairs(goodsInArea) do
                if not goods[good]:good().illegal and not goods[good]:good().dangerous then
                    table.insert(normalGoods, good)
                end
            end

            goodsInComboBox = normalGoods
        end

        for index, good in pairs(goodsInComboBox) do
            for i = 1, numSelectableGoods do
                self.goodComboBoxes[i]:addEntry(good, good % _t)
                self.goodComboBoxes[i]:setEntryTooltip(index, good % _t)
            end
        end

        -- merchant captain has access to all goods, even those that are not actually sold in the area
        if captainIsMerchant == true then
            local allGoods = {}
            local goodsNotInArea = {}
            local alreadyPresent = false

            for name, good in pairs(goods) do
                table.insert(allGoods, good.name)
            end

            function goodsByName(a, b) return goods[a]:good():displayName(1) < goods[b]:good():displayName(1) end
            table.sort(allGoods, goodsByName)

            for _, name in pairs(allGoods) do
                if not goods[name]:good().illegal and not area.analysis.goodsInArea[name] then
                    if isGoodTradeable(name) then
                        table.insert(goodsNotInArea, name)
                    end
                end
            end

            for index, good in pairs(goodsNotInArea) do
                for i = 1, numSelectableGoods do
                    self.goodComboBoxes[i]:addEntry(good, good % _t .. " *")
                    self.goodComboBoxes[i]:setEntryTooltip((index + #goodsInComboBox), good % _t .. ": Goods not usually available in this area.\nCaptain will only be able to procure them for double the usual price."%_t)
                end
            end
        elseif captainIsSmuggler then -- smuggler captain has access to all goods that have either supply or demand in the area
            local smugglerGoodsInArea = {}
            local smugglerGoodsOnly = {}
            for goodName, _ in pairs(area.analysis.smugglerGoodsInArea) do
                table.insert(smugglerGoodsInArea, goodName)
            end

            function smugglerGoodsByName(a, b) return goods[a]:good():displayName(1) < goods[b]:good():displayName(1) end
            table.sort(smugglerGoodsInArea, smugglerGoodsByName)

            for _, name in pairs(smugglerGoodsInArea) do
                if not area.analysis.goodsInArea[name] then
                    table.insert(smugglerGoodsOnly, name)
                end
            end

            for index, good in pairs(smugglerGoodsOnly) do
                for i = 1, numSelectableGoods do
                    self.goodComboBoxes[i]:addEntry(good, good % _t .. " (stolen)"%_t)
                    self.goodComboBoxes[i]:setEntryTooltip((index + #goodsInComboBox), good % _t .. ": can only be procured illegally.\nGoods will be flagged as 'stolen'.\nCaptain will be able to ... let's say organize them for only 50% of the usual price."%_t)
                end
            end
        end        

        if not config then
            -- no config: fill UI with default values, then build config, then use it to calculate yields
            local values = ProcureCommand:getConfigurableValues(ownerIndex, shipName)

            -- use "setValueNoCallback" since we don't want to trigger "refreshPredictions()" while filling in default values
            for i = 1, numSelectableGoods do
                self.amountSliders[i]:setValueNoCallback(values.amounts[i].default)
                self.amountSliders[i]:setMaxNoCallback(0)
                self.amountSliders[i].description = tostring(0)
                self.goodComboBoxes[i]:setSelectedValueNoCallback("")
                if captainIsSmuggler then
                    self.stolenCheckBoxes[i]:setCheckedNoCallback(false)
                end
            end

            config = self:buildConfig()
        end

        self:refreshPredictions(ownerIndex, shipName, area, config)
    end

    -- each config option change should always be reflected in the predictions if it impacts the behavior
    ui.refreshPredictions = function(self, ownerIndex, shipName, area, config)
        local prediction = ProcureCommand:calculatePrediction(ownerIndex, shipName, area, config)

        local entry = ShipDatabaseEntry(ownerIndex, shipName)
        local captainIsSmuggler = entry:getCaptain():hasClass(CaptainUtility.ClassType.Smuggler)
        self:displayPrediction(prediction, config, ownerIndex, captainIsSmuggler, area)

        self.commonUI:refreshPredictions(ownerIndex, shipName, area, config, ProcureCommand, prediction)
    end

    ui.displayPrediction = function(self, prediction, config, ownerIndex, --[[additional arguments, only required when configuring:]] captainIsSmuggler, area)
        local requiredCargoSpace
        if prediction.requiredCargoSpace <= prediction.freeCargoSpace then
            requiredCargoSpace = math.floor(prediction.requiredCargoSpace)
        else
            requiredCargoSpace = math.ceil(prediction.requiredCargoSpace)
        end

        self.cargoSpaceLabel.caption = toReadableNumber(requiredCargoSpace) .. " / " .. toReadableNumber(math.floor(prediction.freeCargoSpace))

        ui.cargoSpaceBar:setRange(0, prediction.freeCargoSpace)

        local cargoSpaceUsed = math.min(math.ceil(prediction.requiredCargoSpace), prediction.freeCargoSpace)
        local barColor = ColorRGB(1, 1, 1)
        if prediction.cargoSpaceMissing.value > 0 then barColor = ColorRGB(1, 0, 0) end

        self.cargoSpaceBar:setValue(cargoSpaceUsed, string.format("Cargo space required: %d"%_t, math.ceil(prediction.requiredCargoSpace)), barColor)

        self.durationLabel.caption = createReadableShortTimeString(round(prediction.duration.value))
        if prediction.durationWarning then
            self.durationLabel.color = ColorRGB(1, 1, 0.3)
            self.durationLabel.tooltip = "Ordering a lot of a certain good may cause the duration to rise drastically!"%_t
        else
            self.durationLabel.color = ColorRGB(1, 1, 1)
            self.durationLabel.tooltip = nil
        end

        self.totalBudgetLabel.caption = string.format("¢%s"%_t, createMonetaryString(prediction.totalBudget or 0))

        local owner = Galaxy():findFaction(ownerIndex)
        if not owner:canPay(prediction.totalBudget) then
            self.totalBudgetLabel.color = ColorRGB(1, 0, 0)
            self.totalBudgetLabel.tooltip = "Not enough money!"%_t
        else
            self.totalBudgetLabel.color = ColorRGB(1, 1, 1)
        end

        self.discountChanceLabel.caption = string.format("%s%%"%_t, round(prediction.discountChance.value * 100))

        -- set selected values of good combo boxes from config
        for index, good in pairs(config.goodsToBuy) do
            self.goodComboBoxes[index]:setSelectedValueNoCallback(good.name)
        end

        for i = 1, numSelectableGoods do
            if self.goodComboBoxes[i].selectedValue and self.goodComboBoxes[i].selectedValue ~= "" and self.goodComboBoxes[i].selectedValue ~= " " then
                local goodSize = goods[self.goodComboBoxes[i].selectedValue]:good().size

                local oldValue = self.amountSliders[i].value
                self.amountSliders[i]:setMaxNoCallback(math.floor(prediction.freeCargoSpace / goodSize))
                self.amountSliders[i]:setNumSegmentsNoCallback(math.floor(prediction.freeCargoSpace / goodSize))
                self.amountSliders[i]:setValueNoCallback(oldValue) -- keep the old value
                self.amountSliders[i].description = tostring(oldValue)

                self.amountBoxes[i].text = self.amountSliders[i].value or 0
                self.budgetLabels[i].caption = string.format("¢%s"%_t, createMonetaryString(prediction.budgets[i].value or 0))
                self.factorsLabels[i].caption = string.format("%s%%"%_t, prediction.factors[i] or "")
                if prediction.tooltips[i] then
                    self.factorsLabels[i].tooltip = prediction.tooltips[i]
                    self.factorsLabels[i].color = ColorRGB(0.85, 0.85, 0)
                else
                    self.factorsLabels[i].tooltip = nil
                    self.factorsLabels[i].color = ColorRGB(0.9, 0.9, 0.9)
                end
            else
                self.amountSliders[i]:setMaxNoCallback(0)
                self.amountSliders[i]:setNumSegmentsNoCallback(0)
                self.amountSliders[i].description = tostring(0)
                self.amountBoxes[i].text = "0"
            end
        end

        -- make sure the stolen checkbox is checked if it has to be
        -- if we are showing a running command this is not required, because the config can be trusted in this case
        if captainIsSmuggler then
            for i = 1, #config.goodsToBuy do
                if config.goodsToBuy[i] and not area.analysis.goodsInArea[config.goodsToBuy[i].name] then
                    self.stolenCheckBoxes[i]:setCheckedNoCallback(true)
                end
            end
        end

        local tooltip = "Percentage of how much the estimated yield diverges from the regular price of the good."%_t
        if prediction.bestPrice then
            ui.percentageLabel.color = ColorRGB(0.3, 1, 0.3)

            if prediction.tradingUpgrade then
                tooltip = tooltip .. "\n\n" .. "Bonus: Your ship has a Trading Subsystem, so you're guaranteed to get the best prices of the area."%_t
            elseif prediction.marketExpert then
                tooltip = tooltip .. "\n\n" .. "Bonus: Your captain is a Market Expert, so you're guaranteed to get the best prices of the area."%_t
            end
        else
            ui.percentageLabel.color = ColorRGB(0.9, 0.9, 0.9)
        end

        ui.percentageLabel.tooltip = tooltip

        self.commonUI:setAttackChance(prediction.attackChance.value)
    end

    -- used to build a config table for the command, based on values configured in the UI
    -- gut feeling says that each config option change should always be reflected in the predictions if it impacts the behavior
    ui.buildConfig = function(self)
        local config = {}

        config.goods = {}
        config.goodsToBuy = {}
        config.numSelectableGoods = 5

        for i = 1, numSelectableGoods do
            local good = {}
            good.name = self.goodComboBoxes[i].selectedValue
            if good.name and good.name ~= "" then
                good.amount = self.amountSliders[i].value
                good.stolen = self.stolenCheckBoxes[i].visible and self.stolenCheckBoxes[i].checked
                good.slot = i

                config.goodsToBuy[i] = good
            end
        end

        config.escorts = self.commonUI.escortUI:buildConfig()

        return config
    end

    ui.setActive = function(self, active, description)
        self.commonUI:setActive(active, description)

        for _, comboBox in pairs(self.goodComboBoxes) do comboBox.active = active end
        for _, checkBox in pairs(self.stolenCheckBoxes) do checkBox.active = active end
        for _, slider in pairs(self.amountSliders) do slider.active = active end
        for _, textBox in pairs(self.amountBoxes) do textBox.editable = active end

        if active == true then
            for _, comboBox in pairs(self.goodComboBoxes) do comboBox.visible = true end
            for _, checkBox in pairs(self.stolenCheckBoxes) do checkBox.visible = true end
            for _, icon in pairs(self.stolenIcons) do icon.visible = true end
            for _, slider in pairs(self.amountSliders) do slider.visible = true end
            for _, textBox in pairs(self.amountBoxes) do textBox.visible = true end
            for _, label in pairs(self.budgetLabels) do label.visible = true end
            for _, label in pairs(self.factorsLabels) do label.visible = true end
        end
    end

    ui.displayConfig = function(self, config, ownerIndex)
        for _, comboBox in pairs(self.goodComboBoxes) do comboBox.visible = false end
        for _, checkBox in pairs(self.stolenCheckBoxes) do checkBox.visible = false end
        for _, icon in pairs(self.stolenIcons) do icon.visible = false end
        for _, slider in pairs(self.amountSliders) do slider.visible = false end
        for _, textBox in pairs(self.amountBoxes) do textBox.visible = false end
        for _, label in pairs(self.budgetLabels) do label.visible = false end
        for _, label in pairs(self.factorsLabels) do label.visible = false end

        for i, good in pairs(config.goodsToBuy) do
            local comboBox = self.goodComboBoxes[i]
            comboBox.visible = true
            comboBox:addEntry(good.name, good.name%_t)

            if good.stolen then
                local checkBox = self.stolenCheckBoxes[i]
                checkBox.visible = true
                checkBox:setCheckedNoCallback(good.stolen)

                local icon = self.stolenIcons[i]
                icon.visible = true
            end

            local slider = self.amountSliders[i]
            slider.visible = true
            slider:setValueNoCallback(good.amount)
            slider.description = tostring(good.amount)

            local textBox = self.amountBoxes[i]
            textBox.visible = true
            textBox.text = good.amount

            local label = self.budgetLabels[i]
            label.visible = true
            -- the caption is set in displayPrediction

            local label = self.factorsLabels[i]
            label.visible = true
            -- the caption is set in displayPrediction
        end
    end

    return ui
end


return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
