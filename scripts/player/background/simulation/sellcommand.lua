
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

local SellCommand = {}
SellCommand.__index = SellCommand
SellCommand.type = CommandType.Sell

local function new(ship, area, config)
    local command = setmetatable({
        type = CommandType.Sell,

        shipName = ship,
        area = area,
        config = config,
        data = {},

        simulation = nil,
    }, SellCommand)

    command.data.runTime = 0

    return command
end

function SellCommand:initialize()
    local parent = getParentFaction()
    local prediction = self:calculatePrediction(parent.index, self.shipName, self.area, self.config)

    self.data.duration = prediction.duration.value
    self.data.yield = prediction.yield.value
    self.data.pricesPerUnit = prediction.pricesPerUnit
    self.data.attackLocation = prediction.attackLocation
end

function SellCommand:update(timeStep)
    self.data.runTime = self.data.runTime + timeStep

    if self.data.runTime >= self.data.duration then
        self:finish()
        return
    end
end

function SellCommand:onAreaAnalysisStart(results, meta)
    local factoryMap = FactoryMap()

    local supplyAndDemand = factoryMap:getAreaSupplyAndDemand(meta.area.lower, meta.area.upper)

    results.goodsInDemand = {}
    results.numSectorsWithGoodInDemand = {}
    results.goodsInSupply = {}
    results.numSectorsWithGoodInSupply = {}
    local pricesForGoods = {}
    local faction = Faction(meta.factionIndex)

    local entry = ShipDatabaseEntry(meta.factionIndex, meta.shipName)
    local captain = entry:getCaptain()
    local captainIsMerchant = captain:hasClass(CaptainUtility.ClassType.Merchant)

    local galaxy = Galaxy()
    for _, sectorInfo in pairs(supplyAndDemand) do
        local aiFaction = galaxy:getControllingFaction(sectorInfo.coordinates.x, sectorInfo.coordinates.y)

        if aiFaction then
            if faction:getRelationStatus(aiFaction.index) == RelationStatus.War then
                if not captainIsMerchant then
                    goto continue -- you can't trade when you're at war
                elseif galaxy:isCentralFactionArea(sectorInfo.coordinates.x, sectorInfo.coordinates.y, aiFaction.index) then
                    goto continue -- merchants can trade in outer areas of factions they are at war with
                end
            end
        end

        -- standard goods that can be sold by any captain
        if sectorInfo.demand then
            for name, demand in pairs(sectorInfo.demand) do
                if not pricesForGoods[name] then pricesForGoods[name] = {} end

                table.insert(pricesForGoods[name], factoryMap:supplyToPriceChange(sectorInfo.sum[name] or 0))
                results.goodsInDemand[name] = true
                results.numSectorsWithGoodInDemand[name] = (results.numSectorsWithGoodInDemand[name] or 0) + 1
            end
        end

        -- smuggler and traders can sell these, too, but with a price penalty
        if sectorInfo.supply then
            for name, _ in pairs(sectorInfo.supply) do
                results.goodsInSupply[name] = true
                results.numSectorsWithGoodInSupply[name] = (results.numSectorsWithGoodInSupply[name] or 0) + 1
            end
        end

        ::continue::
    end

    -- calculate pricefactors
    results.averagePriceFactors = {}
    results.highestPriceFactors = {}
    for goodName, prices in pairs(pricesForGoods) do
        local sum = 0
        local samples = 0
        local highestPriceFactor = nil

        for _, priceFactor in pairs(prices) do
            sum = sum + priceFactor
            samples = samples + 1

            if not highestPriceFactor or priceFactor > highestPriceFactor then
                highestPriceFactor = priceFactor
            end
        end

        if samples > 0 then
            results.averagePriceFactors[goodName] = sum / samples
            results.highestPriceFactors[goodName] = highestPriceFactor
        end
    end
end

function SellCommand:onAreaAnalysisFinished(results, meta)
end

function SellCommand:onStart()
    -- save position from which ship is going to start
    local parent = getParentFaction()
    local entry = ShipDatabaseEntry(parent.index, self.shipName)
    local startX, startY = entry:getCoordinates()
    self.data.startCoordinates = { x = startX, y = startY }

    if self.data.attackLocation then
        if self.simulation.disableAttack then return end -- for unit tests

        local time = random():getFloat(0.1, 0.75) * self.data.duration
        local location = self.data.attackLocation
        local x, y = location.x, location.y

        self:registerForAttack({x = x, y = y}, location.faction, time, "Your ship '%1%' is under attack in sector \\s(%2%:%3%)!"%_T, {self.shipName, x, y})
    end
end

function SellCommand:onRecall()
    -- captain needs at least 11 minutes to sell something
    -- if recalled before that we simply return with cargo still on board
    if (self.data.runTime >= 11 * 60) or (self.data.runTime > (self.data.duration * 0.8)) then
        local percentageCompleted = (self.data.runTime / self.data.duration)
        self:finishSellCommand(percentageCompleted)
    end
end

function SellCommand:onFinish()
    self:finishSellCommand(1.0)

    local parent = getParentFaction()
    local entry = ShipDatabaseEntry(parent.index, self.shipName)
    local captain = entry:getCaptain()

    if captain:hasClass(CaptainUtility.ClassType.Explorer) then
        self:revealExploredSectors(captain)
    end
end

function SellCommand:revealExploredSectors(captain)

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
        if revealed >= 3 then break end

        ::continue::
    end

end

local function goodsAreEqual(good1, good2)
    if good1.name == good2.name
        and good1.stolen == good2.stolen
        and good1.illegal == good2.illegal
        and good1.dangerous == good2.dangerous
        and good1.suspicious == good2.suspicious then

        return true
    end

    return false
end

function SellCommand:finishSellCommand(percentage)
    local percentage = percentage or 1
    local moneyEarned = 0

    local parent = getParentFaction()
    local entry = ShipDatabaseEntry(parent.index, self.shipName)
    local cargo = entry:getCargo()

    for _, toSell in pairs(self.config.goodsToSell) do
        local good = goods[toSell.goodName]:good()
        good.stolen = toSell.stolen

        for goodOnBoard, amountOnBoard in pairs(cargo) do

            local displayName = goodOnBoard:displayName(amountOnBoard) -- we use displayName here to allow distinction between normal and stolen/illegal/dangerous/suspicious variants

            if goodsAreEqual(good, goodOnBoard) then
                local amountSold = math.ceil(toSell.amount * percentage)
                moneyEarned = moneyEarned + (self.data.pricesPerUnit[displayName] * amountSold)

                local amountRemaining = amountOnBoard - amountSold
                if amountRemaining <= 0 then
                    cargo[goodOnBoard] = nil
                else
                    cargo[goodOnBoard] = amountRemaining
                end

                break
            end
        end
    end

    entry:setCargo(cargo)

    local buyingFaction = self.area.analysis.biggestFactionInArea
    if buyingFaction then
        local relationsChange = GetRelationChangeFromMoney(moneyEarned) * 0.15 -- only a quarter of the usual relations because it was captain who did the trading
        changeRelations(parent.index, buyingFaction, relationsChange, RelationChangeType.GoodsTrade)
    end

    if percentage == 1 then -- command finished regularly
        -- restore starting position of sell command
        if self.data.startCoordinates then
            local startX = self.data.startCoordinates.x
            local startY = self.data.startCoordinates.y
            entry:setCoordinates(startX, startY)
        end

        local x, y = entry:getCoordinates()
        parent:sendChatMessage(self.shipName, ChatMessageType.Information, "%1% has finished selling goods and is awaiting your next orders in \\s(%2%:%3%)."%_T, self.shipName, x, y)

        self:addYield("We have successfully sold the goods. Here are the profits earned."%_T, self.data.yield, {}, {})

    else -- early recall
        self:addYield("We only started to sell the goods and weren't able to complete the trade. Here is what we already earned. The rest of the goods are still in the cargo bay."%_T, math.floor(moneyEarned), {}, {})
    end
end

function SellCommand:onSecure()
end

function SellCommand:onRestore()
end

function SellCommand:onAttacked(attackerFaction, x, y)
end

function SellCommand:getIcon()
    return "data/textures/icons/sell-command.png"
end

function SellCommand:getDescriptionText()
    local totalRuntime = self.data.duration
    local timeRemaining = round((totalRuntime - self.data.runTime) / 60) * 60
    local completed = round(self.data.runTime / totalRuntime * 100)

    return "The ship is selling cargo.\n\nTime remaining: ${timeRemaining} (${completed} % done)."%_T, {timeRemaining = createReadableShortTimeString(timeRemaining), completed = completed}
end

function SellCommand:getStatusMessage()
    return "Selling cargo /* ship AI status*/"%_T
end

function SellCommand:getRecallError()
end

function SellCommand:getErrors(ownerIndex, shipName, area, config)
    local entry = ShipDatabaseEntry(ownerIndex, shipName)

    local cantSellErrorMsg = "I can't sell this!"%_t

    for _, toSell in pairs(config.goodsToSell) do
        local good = goods[toSell.goodName]
        if not good then
            -- goods that are not in the goodsindex can't be sold
            return "I don't know how to sell '${name}' here."%_t % {name = toSell.goodName % _t}
        end
    end

    -- cargo
    local noGoodToSell = true
    for _, toSell in pairs(config.goodsToSell) do
        noGoodToSell = false
        if toSell.amount == 0 then
            local good = goods[toSell.goodName]:good()
            good.stolen = toSell.stolen
            return "No amount for ${good} selected!"%_t % {good = good:displayName(2)}
        end
    end

    if noGoodToSell then
        return "No good to sell selected!"%_t, {}
    end

    -- check config not exceeding actual cargo
    local cargo = entry:getCargo()
    for _, toSell in pairs(config.goodsToSell) do
        local goodInConfig = goods[toSell.goodName]:good()
        goodInConfig.stolen = toSell.stolen
        local amountInConfig = toSell.amount

        local goodFound = false
        for goodOnBoard, amountOnBoard in pairs(cargo) do
            if goodsAreEqual(goodInConfig, goodOnBoard) then
                goodFound = true
                if amountInConfig > amountOnBoard then
                    return "Not enough of ${good} aboard!"%_t % {good = goodInConfig:displayName(amountInConfig)}
                end

                break
            end
        end

        if not goodFound then
            return "Cargo to sell isn't on the ship!"%_t, {}
        end
    end

    -- check captain is allowed to sell goods
    -- code broken apart for better readability
    local captain = entry:getCaptain()
    local isMerchant = captain:hasClass(CaptainUtility.ClassType.Merchant)
    local isSmuggler = captain:hasClass(CaptainUtility.ClassType.Smuggler)

    local goodsToSell = {}
    for _, toSell in pairs(config.goodsToSell) do
        local good = goods[toSell.goodName]:good()
        good.stolen = toSell.stolen

        goodsToSell[good] = toSell.amount
    end

    local stolenOrIllegal, dangerousOrSuspicious = SimulationUtility.getSpecialCargoCategories(goodsToSell)

    if stolenOrIllegal and not isSmuggler then
        return cantSellErrorMsg, {}
    end

    if dangerousOrSuspicious and not (isSmuggler or isMerchant) then
        return cantSellErrorMsg, {}
    end

    for _, toSell in pairs(config.goodsToSell) do
        -- check demands and supplies of area
        if (area.analysis.goodsInDemand and not area.analysis.goodsInDemand[toSell.goodName])
            and not (isSmuggler or isMerchant) then

            return "There is no demand for '${name}' here."%_t % {name = toSell.goodName % _t}
        end

        if (area.analysis.goodsInSupply and area.analysis.goodsInSupply[toSell.goodName])
            and not (area.analysis.goodsInDemand and area.analysis.goodsInDemand[toSell.goodName])
            and not isSmuggler then

            return "There is no demand for '${name}' here."%_t % {name = toSell.goodName % _t}
        end
    end
end

function SellCommand:getAreaSize(shipName)
    return {x = 15, y = 15}
end

function SellCommand:getAreaBounds()
    return {lower = self.area.lower, upper = self.area.upper}
end

function SellCommand:getAreaSelectionTooltip(craftName, area, valid)
    return "Left-Click to select area to sell in"%_t
end

function SellCommand:isAreaFixed()
    return false
end

function SellCommand:isShipRequiredInArea(shipName)
    return true
end

function SellCommand:getConfigurableValues(ownerIndex, shipName)
    local values = {}

    -- value names here must match with values returned in ui:buildConfig() below
    values.goodsToSell = {}

    return values
end

function SellCommand:getPredictableValues()
    local values = {}

    values.duration = {displayName = "Duration"%_t, value = 0}
    values.yield = {displayName = "Profit"%_t}
    values.attackChance = {displayName = SimulationUtility.AttackChanceLabelCaption}
    values.percentages = {}
    values.pricesPerGood = {}
    values.tooltips = {}

    return values
end

function SellCommand:calculatePrediction(ownerIndex, shipName, area, config)
    local results = self:getPredictableValues()
    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local cargo = entry:getCargo()

    --- calculate duration ---
    local captain = entry:getCaptain()
    local duration = 10 * 60 -- base duration any trade command takes
    local minTradeDuration = 1 * 60 -- 1 minute
    local durationFactor = 5 * 60 -- 5 minutes
    local demandFactor = 1 -- percentage of sectors where good is in demand
    local transactionVolume = 1500

    -- goods to sell increase duration - scales by volume as we can only sell 16 per transaction
    local size = self:getAreaSize()
    local numSectors = (size.x * size.y) - area.analysis.unreachable + 1

    for _, toSell in pairs(config.goodsToSell) do
        local name = toSell.goodName
        if not goods[name] then goto continue end

        local good = goods[name]:good()
        good.stolen = toSell.stolen
        local goodSize = good.size

        local numSectorsWithDemand = 0
        if area.analysis.goodsInDemand and area.analysis.goodsInDemand[name] ~= 0 then
            numSectorsWithDemand = area.analysis.numSectorsWithGoodInDemand[name]
        end

        local availabilityPerSector = (numSectors  - (numSectorsWithDemand or 0)) / numSectors

        local volume = toSell.amount * goodSize
        local numTransactions = math.ceil(volume / transactionVolume)
        for i = 1, numTransactions do
            local increase = math.max(minTradeDuration, availabilityPerSector * durationFactor)
            duration = duration + increase
        end

        ::continue::
    end

    -- cargo on ship that would lead to controls increases duration by 15 %
    if not captain:hasClass(CaptainUtility.ClassType.Smuggler) then
        local stolenOrIllegal, dangerousOrSuspicious = SimulationUtility.getSpecialCargoCategories(cargo)
        if captain:hasClass(CaptainUtility.ClassType.Merchant) then
            dangerousOrSuspicious = false
        end

        if stolenOrIllegal or dangerousOrSuspicious then
            duration = duration * 1.15
        end
    end

    -- captain's classes and perks can influence duration
    if captain then
        -- first perks
        local factor = 1
        for _, perk in pairs({captain:getPerks()}) do
            factor = factor * (1 + CaptainUtility.getSellTimePerkImpact(captain, perk))
        end

        duration = duration * factor

        -- then class
        if captain:hasClass(CaptainUtility.ClassType.Merchant) then
            duration = duration * 0.85
        end
    end

    --- calculate earnings ---
    local earnings = 0
    local pricesPerUnit = {}
    local pricesPerCargo = {}
    local regularPricesPerGood = {}

    -- check trading system
    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local subsystems = entry:getSystems()
    for subsystem, _ in pairs(subsystems) do
        if subsystem.script == "data/scripts/systems/tradingoverview.lua"
                or string.match(subsystem.script, "/systems/hypertradingsystem.lua") then
            results.bestPrice = true
            results.tradingUpgrade = true
            break
        end
    end

    -- check perks
    local captain = entry:getCaptain()
    if captain and captain:hasPerk(CaptainUtility.PerkType.MarketExpert) then
        results.bestPrice = true
        results.marketExpert = true
    end

    for _, toSell in pairs(config.goodsToSell) do
        local name = toSell.goodName
        if not goods[name] then goto continue end

        local good = goods[name]:good()
        good.stolen = toSell.stolen
        local amount = toSell.amount

        local displayName = good:displayName(amount) -- we use displayName here to allow distinction between normal and stolen/illegal/dangerous/suspicious variants

        local avgPrice = 0
        local highestPrice = 0
        local standardPrice = goods[good.name]:good().price

        regularPricesPerGood[displayName] = standardPrice * amount

        if area.analysis.averagePriceFactors and area.analysis.highestPriceFactors then
            avgPrice = standardPrice + (area.analysis.averagePriceFactors[name] or 0) * standardPrice
            highestPrice = standardPrice + (area.analysis.highestPriceFactors[name] or 0) * standardPrice

            -- no demand for the good, but we can still sell it at half price
            if (not area.analysis.averagePriceFactors[name] or not area.analysis.highestPriceFactors[name]) then
                avgPrice = standardPrice * 0.5
                highestPrice = standardPrice * 0.5
                results.tooltips[displayName] = "No demand for the good in this area,\ncan only be sold at a very low price"%_t
            end
        end

        -- stolen and illegal goods always get price penalty
        if good.stolen or good.illegal then
            avgPrice = standardPrice * 0.5
            highestPrice = standardPrice * 0.5

            if good.stolen then
                results.tooltips[displayName] = "This good is marked as stolen,\ncan only be sold at a very low price"%_t
            else
                results.tooltips[displayName] = "This good isn't legal,\ncan only be sold at a very low price"%_t
            end
        end

        local perkFactor = self:getPerkPriceInfluence(ownerIndex, shipName)

        if results.bestPrice then
            local pricePerUnit = highestPrice * perkFactor
            earnings = earnings + pricePerUnit * amount
            pricesPerUnit[displayName] = pricePerUnit
            pricesPerCargo[displayName] = pricePerUnit * amount
        else
            local pricePerUnit = avgPrice * perkFactor
            earnings = earnings + pricePerUnit * amount
            pricesPerUnit[displayName] = pricePerUnit
            pricesPerCargo[displayName] = pricePerUnit * amount
        end

        ::continue::
    end

    -- (5 * tier) % chance to earn a 5 % bonus
    local bonusFactor = 0.05
    local bonusChance = 0.05 * captain.tier
    if captain:hasClass(CaptainUtility.ClassType.Merchant) then
        bonusChance = bonusChance * 2
    end

    local x, y = entry:getCoordinates()
    local rand = Random(Seed(captain.name .. tostring(x) .. tostring(y)))
    if rand:test(bonusChance) then
        earnings = earnings + earnings * bonusFactor
        for displayName, price in pairs(pricesPerCargo) do
            pricesPerCargo[displayName] = pricesPerCargo[displayName] + pricesPerCargo[displayName] * bonusFactor
        end
    end

    for displayName, price in pairs(pricesPerCargo) do
        if price ~= 0 then
            results.percentages[displayName] = round(price / regularPricesPerGood[displayName] * 100)
        end

        results.pricesPerGood[displayName] = math.ceil(price)
    end

    --- results ---
    results.duration.value = math.max(duration, 5 * 60)
    results.attackChance.value, results.attackLocation = SimulationUtility.calculateAttackProbability(ownerIndex, shipName, area, config.escorts, results.duration.value / 3600)
    results.yield.value = math.ceil(earnings)
    results.pricesPerUnit = pricesPerUnit

    return results
end

function SellCommand:getPerkPriceInfluence(ownerIndex, shipName)
    local result = 1.0

    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local captain = entry:getCaptain()
    if not captain then return result end

    for _, perk in pairs({captain:getPerks()}) do
        result = result + CaptainUtility.getSellPricePerkImpact(captain, perk)
    end

    return result
end

local function getRegionLines(area, config)
    local result = {}

    -- calculate percentage of sectors with good in demand (meaning we get better prices)
    local numSectorsWithDemand = 0
    local numGoods = 0
    local total = area.analysis.sectors

    local areaQuality = 0
    local combinedAreaQuality = 0

    for _, toSell in pairs(config.goodsToSell) do
        numGoods = numGoods + 1
        local num = area.analysis.numSectorsWithGoodInDemand[toSell.goodName]
        if num then
            numSectorsWithDemand = num
            areaQuality = numSectorsWithDemand / total
            combinedAreaQuality = combinedAreaQuality + areaQuality
        end
    end

    -- use average
    combinedAreaQuality = combinedAreaQuality / numGoods

    if combinedAreaQuality > 0.90 then
        table.insert(result, "This is a good area to sell our goods."%_t)
        table.insert(result, "There is a lot of demand for our goods in this area. I will be able to sell them at very good prices."%_t)
    elseif combinedAreaQuality > 0.65 then
        table.insert(result, "Demand could be better, but I will be able to sell our goods at reasonable prices."%_t)
        table.insert(result, "This area looks alright. There are some merchants, I think I can get reasonable prices here."%_t)
        table.insert(result, "There are some good merchants in this area who will buy our goods."%_t)
    elseif combinedAreaQuality > 0.45 then
        table.insert(result, "\\c(dd5)This area is not great for selling these goods. Maybe we should consider trying another area.\\c()"%_t)
        table.insert(result, "\\c(dd5)According to initial calculations, the area is not ideal, but I may be able to sell the goods if you don't expect huge profits.\\c()"%_t)
    else
        table.insert(result, "\\c(d93)We shouldn't try to sell these goods in this area. We can do the job, but we will have to lower the prices drastically.\\c()"%_t)
        table.insert(result, "\\c(d93)I can try to sell these goods here, but I don't think they will fetch good prices in this area.\\c()"%_t)
        table.insert(result, "\\c(d93)In this area it will be difficult to sell our goods. We should try another area.\\c()"%_t)
    end

    return result
end

function SellCommand:generateAssessmentFromPrediction(prediction, captain, ownerIndex, shipName, area, config)
    local parent = getParentFaction()
    local entry = ShipDatabaseEntry(ownerIndex, shipName)

    -- region
    local regionLines = getRegionLines(area, config)

    -- cargo on board
    local cargo = entry:getCargo()
    local stolenOrIllegal, dangerousOrSuspicious = SimulationUtility.getSpecialCargoCategories(cargo)
    local cargobayLines = SimulationUtility.getIllegalCargoAssessmentLines(stolenOrIllegal, dangerousOrSuspicious, captain)

    -- attacks and radio silence
    local attackChance = prediction.attackChance.value
    local pirateSectorRatio = SimulationUtility.calculatePirateAttackSectorRatio(area)
    local pirateLines = SimulationUtility.getPirateAssessmentLines(pirateSectorRatio)
    local attackLines = SimulationUtility.getAttackAssessmentLines(attackChance)
    local radioSilence, returnLines = SimulationUtility.getDisappearanceAssessmentLines(attackChance)

    local rnd = Random(Seed(captain.name))

    return {
        randomEntry(rnd, regionLines),
        randomEntry(rnd, cargobayLines),
        randomEntry(rnd, attackLines),
        randomEntry(rnd, pirateLines),
        randomEntry(rnd, radioSilence),
        randomEntry(rnd, returnLines),
    }
end

local function isGoodSellable(name)
    local good = goods[name]
    if not good or good.tags.ore or good.tags.scrap then
        return false
    end

    return true
end

function SellCommand:buildCargoUI(window, rect, configChangedCallback, ownerIndex, shipName)
    local ui = {}

    local hsplit = UIHorizontalSplitter(rect, 10, 0, 0.5)
    hsplit.topSize = 20

    local vsplitConfig = UIArbitraryVerticalSplitter(hsplit.top, 10, 5, 211, 283, 451, 490)
    window:createLabel(vsplitConfig:partition(0), "Cargo to sell:"%_t, 14)
    window:createLabel(vsplitConfig:partition(1), "Amount:"%_t, 14)
    window:createLabel(vsplitConfig:partition(2), "Estimated yield:"%_t, 14)
    ui.percentageLabel = window:createLabel(vsplitConfig:partition(3), "+-%"%_t, 14)
    ui.selectAllButton = window:createButton(vsplitConfig:partition(4), "Select All"%_t, "sellCommandToggleAllPressed")
    ui.selectAllButton.maxTextSize = 11
    ui.selectAllButton.height = 20

    local cargoRect = hsplit.bottom
    ui.cargoList = window:createListBoxEx(cargoRect)
    ui.cargoList.columns = 7
    ui.cargoList:setColumnWidth(0, 20)
    ui.cargoList:setColumnWidth(1, 20)
    ui.cargoList:setColumnWidth(2, 160)
    ui.cargoList:setColumnWidth(3, 60)
    ui.cargoList:setColumnWidth(4, 140)
    ui.cargoList:setColumnWidth(5, 80)
    ui.cargoList:setColumnWidth(6, 180)
    ui.cargoList.entriesSelectable = false
    ui.allowedCargo = {} -- used to save which cargo is allowed so that it doesn't need to be recalculated when config is built

    local vlist = UIVerticalLister(hsplit.bottom, 10, 0)

    ui.refresh = function(self, ownerIndex, shipName, area, config)
        self.cargoList.onChangedFunction = ""
        self.cargoList:clear()

        -- get cargo
        local entry = ShipDatabaseEntry(ownerIndex, shipName)
        local cargo, cargoHold = entry:getCargo()
        local captain = entry:getCaptain()

        -- list all cargo and their amount
        local cargoToUse = {}

        local isSmuggler = captain:hasClass(CaptainUtility.ClassType.Smuggler)
        local isMerchant = captain:hasClass(CaptainUtility.ClassType.Merchant)
        local specialGoods = {} -- remember illegal etc goods in case we have a smuggler captain

        for good, amount in pairs(cargo) do
            if not isGoodSellable(good.name) then goto continue end

            -- merchants can sell everything, including dangerous and suspicious goods
            -- but not illegal or stolen goods
            if isMerchant then
                if not good.stolen and not good.illegal then
                    cargoToUse[good] = true
                    goto continue
                end
            end

            -- every captain can sell goods that are in demand
            -- but not illegal, stolen, dangerous or suspicious ones
            if area.analysis.goodsInDemand[good.name] then
                if not good.stolen and not good.illegal
                    and not good.dangerous and not good.suspicious then

                    cargoToUse[good] = true
                    goto continue
                else
                    table.insert(specialGoods, good)
                    goto continue
                end
            end

            if isSmuggler then
                -- if captain is smuggler check supply as well
                if area.analysis.goodsInSupply[good.name] then
                    cargoToUse[good] = true
                end
            end

            ::continue::
        end

        if isSmuggler then
            -- smuggler can sell illegal, stolen, dangerous and suspicious goods from demand
            for _, good in pairs(specialGoods) do
                cargoToUse[good] = true
            end
        end

        -- convert to sorted table
        local sortedGoods = SellCommand:filterAndSortCargo(cargo, cargoToUse)

        -- build cargo selection
        local activeColor = ColorRGB(1.0, 1.0, 1.0)
        local notSellableColor = ColorRGB(0.3, 0.3, 0.3)
        local warningColor = ColorRGB(0.85, 0.85, 0)
        local percentageColor = ColorRGB(1.0, 1.0, 1.0)

        for _, entry in pairs(sortedGoods) do
            self.cargoList:addRow(entry.good.name)
            local rowIndex = self.cargoList.rows - 1

            if entry.active then
                self.cargoList:setEntry(0, rowIndex, entry.good.icon, false, false, activeColor)
                self.cargoList:setEntry(2, rowIndex, entry.good:displayName(entry.amount), false, false, activeColor)
                self.cargoList:setEntry(3, rowIndex, entry.amount, false, false, activeColor, nil, 1)
                self.cargoList:setEntry(4, rowIndex, "", false, false, activeColor, nil, 1)
                self.cargoList:setEntry(5, rowIndex, "", false, false, percentageColor, nil, 1)
                self.cargoList:setEntry(6, rowIndex, "checked", false, false, activeColor, nil, 1)

                self.cargoList:setEntryType(0, rowIndex, ListBoxEntryType.Icon)
                self.cargoList:setEntryType(1, rowIndex, ListBoxEntryType.Icon)
                self.cargoList:setEntryType(2, rowIndex, ListBoxEntryType.Text)
                self.cargoList:setEntryType(3, rowIndex, ListBoxEntryType.Text)
                self.cargoList:setEntryType(4, rowIndex, ListBoxEntryType.Text)
                self.cargoList:setEntryType(5, rowIndex, ListBoxEntryType.Text)
                self.cargoList:setEntryType(6, rowIndex, ListBoxEntryType.CheckBox)

                -- remember which ones are allowed so that selectAll button knows which ones to take
                ui.allowedCargo[entry.good] = true

            else
                self.cargoList:setEntry(0, rowIndex, entry.good.icon, false, false, notSellableColor)
                self.cargoList:setEntry(2, rowIndex, entry.good:displayName(entry.amount), false, false, notSellableColor)
                self.cargoList:setEntry(3, rowIndex, entry.amount, false, false, notSellableColor, nil, 1)
                self.cargoList:setEntry(4, rowIndex, "", false, false, notSellableColor, nil, 1)
                self.cargoList:setEntry(5, rowIndex, "", false, false, notSellableColor, nil, 1)
                self.cargoList:setEntry(6, rowIndex, "", false, false, notSellableColor, nil, 1)

                self.cargoList:setEntryType(0, rowIndex, ListBoxEntryType.Icon)
                self.cargoList:setEntryType(2, rowIndex, ListBoxEntryType.Text)
                self.cargoList:setEntryType(3, rowIndex, ListBoxEntryType.Text)

                self.cargoList:setTooltip(rowIndex, SellCommand:getUnsellableTooltipText(captain, entry))
            end

            self.cargoList:setEntry(1, rowIndex, "", false, false, ColorRGB(1, 0.3, 1))

            if entry.good.tags["mission_relevant"] then
                self.cargoList:setEntry(1, rowIndex, "data/textures/icons/mission-item.png", false, false, ColorRGB(1, 1, 0.3))
                self.cargoList:setEntryTooltip(1, rowIndex, "Mission relevant"%_t)
            elseif entry.good.stolen then
                self.cargoList:setEntry(1, rowIndex, "data/textures/icons/hazard-sign.png", false, false, ColorRGB(1, 1, 0.3))
                self.cargoList:setEntryTooltip(1, rowIndex, "These goods are stolen! Can only be sold by a Smuggler."%_t)
            elseif entry.good.illegal then
                self.cargoList:setEntry(1, rowIndex, "data/textures/icons/hazard-sign.png", false, false, ColorRGB(1, 1, 0.3))
                self.cargoList:setEntryTooltip(1, rowIndex, "These goods are illegal! Can only be sold by a Smuggler."%_t)
            elseif entry.good.dangerous then
                self.cargoList:setEntry(1, rowIndex, "data/textures/icons/hazard-sign.png", false, false, ColorRGB(1, 1, 0.3))
                self.cargoList:setEntryTooltip(1, rowIndex, "These goods are dangerous! Can only be sold by a Merchant or Smuggler."%_t)
            elseif entry.good.suspicious then
                self.cargoList:setEntry(1, rowIndex, "data/textures/icons/hazard-sign.png", false, false, ColorRGB(1, 1, 0.3))
                self.cargoList:setEntryTooltip(1, rowIndex, "These goods are suspicious! Can only be sold by a Merchant or Smuggler."%_t)
            end

            self.cargoList:setEntryType(1, rowIndex, ListBoxEntryType.Icon)

        end

        self.cargoList.onChangedFunction = configChangedCallback
    end

    ui.refreshPredictions = function(self, prediction)
        self.cargoList.onChangedFunction = nil

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

        local activeColor = ColorRGB(1.0, 1.0, 1.0)
        local warningColor = ColorRGB(0.85, 0.85, 0)

        for i = 0, self.cargoList.rows - 1 do
            local displayName, _, _, _, name = self.cargoList:getEntry(2, i)
            local amount = self.cargoList:getEntry(3, i)

            -- bring percentage into readable form
            local percentage = prediction.percentages[displayName] or 0
            local percentageColor = ColorRGB(1.0, 1.0, 1.0)
            if percentage > 100 then
                local colors = {vec3(0.7, 0.9, 0.7), vec3(0.5, 0.9, 0.5), vec3(0.0, 0.9, 0.0)}
                percentageColor = multilerp(percentage, 100, 130, colors)
                percentageColor = ColorRGB(percentageColor.x, percentageColor.y, percentageColor.z)
            elseif percentage < 100 then
                local colors = {vec3(1.0, 0.4, 0.2), vec3(0.9, 0.9, 0.2), vec3(0.9, 0.9, 0.5)}
                percentageColor = multilerp(percentage, 70, 100, colors)
                percentageColor = ColorRGB(percentageColor.x, percentageColor.y, percentageColor.z)
            end

            if percentage < 70 and prediction.tooltips and prediction.tooltips[displayName] then
                percentageColor = warningColor
            end

            local percentageToShow = ""
            if percentage == 0 then
                percentageToShow = 0 .. "%"
            elseif percentage < 100 then
                percentageToShow = "-" .. 100 - percentage .. "%"
            else
                percentageToShow = "+" .. percentage - 100 .. "%"
            end

            -- convert price to readable form
            local priceToShow = string.format("¢%s"%_t, createMonetaryString(prediction.pricesPerGood[displayName] or 0))

            -- fill in price
            if prediction.pricesPerGood[displayName] then
                self.cargoList:setEntry(4, i, priceToShow, false, false, activeColor, nil, 1)
                self.cargoList:setEntryType(4, i, ListBoxEntryType.Text)
            else
                self.cargoList:setEntry(4, i, "", false, false, activeColor, nil, 1)
                self.cargoList:setEntryType(4, i, ListBoxEntryType.Text)
            end

            -- fill in percentage
            if prediction.percentages[displayName] then
                self.cargoList:setEntry(5, i, percentageToShow, false, false, percentageColor, nil, 1)
                self.cargoList:setEntryType(5, i, ListBoxEntryType.Text)
            else
                self.cargoList:setEntry(5, i, "", false, false, percentageColor, nil, 1)
                self.cargoList:setEntryType(5, i, ListBoxEntryType.Text)
            end

            -- add tooltip
            if prediction.tooltips and prediction.tooltips[displayName] then
                self.cargoList:setEntryTooltip(5, i, prediction.tooltips[displayName])
            end
        end

        self.cargoList.onChangedFunction = configChangedCallback
    end

    return ui
end

function SellCommand:getUnsellableTooltipText(captain, entry)
    local isSmuggler = captain:hasClass(CaptainUtility.ClassType.Smuggler)
    local isMerchant = captain:hasClass(CaptainUtility.ClassType.Merchant)

    if (entry.good.suspicious or entry.good.dangerous) and not (isSmuggler or isMerchant) then
        return "Captain can't sell this!"%_t
    end

    if (entry.good.illegal or entry.good.stolen) and not isSmuggler then
        return "Captain can't sell this!"%_t
    end

    if not isGoodSellable(entry.good.name) then
        return "This isn't tradeable!"%_t
    end

    return "This can't be sold in this area!"%_t
end

function SellCommand:filterAndSortCargo(cargo, cargoToUse)
    local sortedGoods = {}
    local activeGoods = {}
    local inActiveGoods = {}

    for good, amount in pairs(cargo) do
        local entry = {good = good, amount = amount}

        if cargoToUse[good] then
            entry.active = true
            table.insert(activeGoods, entry)
        else
            entry.active = false
            table.insert(inActiveGoods, entry)
        end
    end

    -- sort and put in goods that we can sell first
    table.sort(activeGoods, function(a, b) return a.good:displayName(a.amount) < b.good:displayName(b.amount) end)
    for _, good in pairs(activeGoods) do
        table.insert(sortedGoods, good)
    end

    -- sort and put in goods that we can't sell
    table.sort(inActiveGoods, function(a, b) return a.good:displayName(a.amount) < b.good:displayName(b.amount) end)
    for _, good in pairs(inActiveGoods) do
        table.insert(sortedGoods, good)
    end

    return sortedGoods
end

function SellCommand:buildUI(startPressedCallback, changeAreaPressedCallback, recallPressedCallback, configChangedCallback)
    local ui = {}
    ui.orderName = "Sell"%_t
    ui.icon = SellCommand:getIcon()

    local size = vec2(650, 700)
    ui.window = GalaxyMap():createWindow(Rect(size))
    ui.window.caption = "Sell Command"%_t

    ui.commonUI = SimulationUtility.buildCommandUI(ui.window, startPressedCallback, changeAreaPressedCallback, recallPressedCallback, configChangedCallback, {configHeight = 220, changeAreaButton = true})

    -- build cargo ui
    ui.cargoUI = SellCommand:buildCargoUI(ui.window, ui.commonUI.configRect, configChangedCallback, ownerIndex, shipName)

    -- predicted values: yield, duration and attack probability
    local predictable = self:getPredictableValues()
    local vsplitPrediction = UIVerticalSplitter(ui.commonUI.predictionRect, 5, 0, 0.65)
    local vlistPredictionCaptions = UIVerticalLister(vsplitPrediction.left, 5, 0)
    vlistPredictionCaptions.marginTop = 35
    ui.window:createLabel(vlistPredictionCaptions:nextRect(15), predictable.attackChance.displayName .. ":", 12)
    ui.window:createLabel(vlistPredictionCaptions:nextRect(15), predictable.duration.displayName .. ":", 12)
    ui.window:createLabel(vlistPredictionCaptions:nextRect(15), predictable.yield.displayName .. ":", 12)

    local vlistPredictionLabels = UIVerticalLister(vsplitPrediction.right, 5, 0)
    vlistPredictionLabels.marginTop = 35
    vlistPredictionLabels.marginRight = 15
    ui.commonUI.attackChanceLabel = ui.window:createLabel(vlistPredictionLabels:nextRect(15), "", 12)
    ui.commonUI.attackChanceLabel:setRightAligned()
    ui.durationLabel = ui.window:createLabel(vlistPredictionLabels:nextRect(15), "", 12)
    ui.durationLabel:setRightAligned()
    ui.yieldLabel = ui.window:createLabel(vlistPredictionLabels:nextRect(15), "", 12)
    ui.yieldLabel:setRightAligned()

    --- functions ---
    self.mapCommands.sellCommandToggleAllPressed = function()
        -- check if we are toggling on or off
        local allChecked = true
        local noneChecked = true
        for i = 0, ui.cargoUI.cargoList.rows - 1 do
            local checked, _, _, _, name = ui.cargoUI.cargoList:getEntry(6, i)
            local displayName = ui.cargoUI.cargoList:getEntry(2, i)
            local amount = ui.cargoUI.cargoList:getEntry(3, i)

            for good, _  in pairs(ui.cargoUI.allowedCargo) do
                if good:displayName(tonumber(amount)) == displayName then
                    if checked ~= "" then
                        noneChecked = false
                    else
                        allChecked = false
                    end
                end
            end
        end

        -- toggle checkboxes
        for i = 0, ui.cargoUI.cargoList.rows - 1 do
            local checked, _, _, _, name = ui.cargoUI.cargoList:getEntry(6, i)
            local displayName = ui.cargoUI.cargoList:getEntry(2, i)
            local amount = ui.cargoUI.cargoList:getEntry(3, i)

            for good, _  in pairs(ui.cargoUI.allowedCargo) do
                if good:displayName(tonumber(amount)) == displayName then
                    if allChecked then
                        -- toggle off, but only if all are on
                        ui.cargoUI.cargoList:setEntry(6, i, "", false, false, ColorRGB(1, 1, 1))
                        ui.cargoUI.cargoList:setEntryType(6, i, ListBoxEntryType.CheckBox)
                    else
                        -- toggle on
                        ui.cargoUI.cargoList:setEntry(6, i, "checked", false, false, ColorRGB(1, 1, 1))
                        ui.cargoUI.cargoList:setEntryType(6, i, ListBoxEntryType.CheckBox)
                    end

                    break
                end
            end
        end

        self.mapCommands[configChangedCallback]()
    end

    -- clear all and reset to default
    ui.clear = function(self, shipName)
        self.commonUI:clear(shipName)
        self.durationLabel.caption = "0"
        self.yieldLabel.caption = "0"
        self.cargoUI.cargoList:clear()
    end

    -- used to fill values into the UI
    -- config == nil means fill with default values
    ui.refresh = function(self, ownerIndex, shipName, area, config)

        -- cargo UI needs to be refreshed before common UI as it influences captain assessment!
        self.cargoUI:refresh(ownerIndex, shipName, area, config)
        self.commonUI:refresh(ownerIndex, shipName, area, config)

        if not config then
            config = self:buildConfig(ownerIndex, shipName, area)
        end

        self:refreshPredictions(ownerIndex, shipName, area, config)
    end

    -- refresh predictions if player changed config
    ui.refreshPredictions = function(self, ownerIndex, shipName, area, config)
        local prediction = SellCommand:calculatePrediction(ownerIndex, shipName, area, config)
        self:displayPrediction(prediction, config, ownerIndex)

        -- common UI
        self.commonUI:refreshPredictions(ownerIndex, shipName, area, config, SellCommand, prediction)
    end

    ui.displayPrediction = function(self, prediction, config, ownerIndex)
        -- cargo UI
        self.cargoUI:refreshPredictions(prediction)

        -- yield / earnings
        self.yieldLabel.caption = string.format("¢%s"%_t, createMonetaryString(prediction.yield.value))

        -- duration
        local duration = math.ceil(prediction.duration.value / 60) * 60
        self.durationLabel.caption = createReadableShortTimeString(duration)

        -- attack chance
        self.commonUI:setAttackChance(prediction.attackChance.value)
    end

    -- build config that is used to start the command
    ui.buildConfig = function(self)
        local config = {}
        config.goodsToSell = {}

        -- determine what player wants to sell - checked checkboxes
        for i = 0, self.cargoUI.cargoList.rows - 1 do
            local checked, _, _, _, name = self.cargoUI.cargoList:getEntry(6, i)

            if checked ~= "" then
                local displayName = self.cargoUI.cargoList:getEntry(2, i)
                local amount = self.cargoUI.cargoList:getEntry(3, i)

                -- we're saving price and percentage as well to re-read it when we need to display the config of a ship that's in BGS
                -- price and percentage won't be used anywhere else and are meant purely for UI usability on redisplay
                local price = self.cargoUI.cargoList:getEntry(4, i)
                local percentage = self.cargoUI.cargoList:getEntry(5, i)

                for good, _  in pairs(ui.cargoUI.allowedCargo) do
                    if good:displayName(tonumber(amount)) == displayName then
                        table.insert(config.goodsToSell, {goodName = good.name, stolen = good.stolen, amount = tonumber(amount), price = price, percentage = percentage})
                        break
                    end
                end
            end
        end

        config.escorts = self.commonUI.escortUI:buildConfig()

        return config
    end

    ui.setActive = function(self, active, description)
        self.commonUI:setActive(active, description)

        self.cargoUI.selectAllButton.visible = active
    end

    ui.displayConfig = function(self, config, ownerIndex)
        local activeColor = ColorRGB(1.0, 1.0, 1.0)

        local cargoList = self.cargoUI.cargoList
        cargoList:clear()

        for _, toSell in pairs(config.goodsToSell) do
            local good = goods[toSell.goodName]:good()
            good.stolen = toSell.stolen

            cargoList:addRow(good.name)
            local rowIndex = cargoList.rows - 1

            cargoList:setEntry(0, rowIndex, good.icon, false, false, activeColor)
            cargoList:setEntry(2, rowIndex, good:displayName(toSell.amount), false, false, activeColor)
            cargoList:setEntry(3, rowIndex, toSell.amount, false, false, activeColor, nil, 1)
            cargoList:setEntry(4, rowIndex, toSell.price or "", false, false, activeColor, nil, 1)
            cargoList:setEntry(5, rowIndex, toSell.percentage or "", false, false, activeColor, nil, 1)
            -- don't add the checkbox to column 5

            if good.stolen then
                cargoList:setEntry(1, rowIndex, "data/textures/icons/hazard-sign.png", false, false, ColorRGB(1, 1, 0.3))
                cargoList:setEntryTooltip(1, rowIndex, "These goods are stolen!"%_t)
            elseif good.illegal then
                cargoList:setEntry(1, rowIndex, "data/textures/icons/hazard-sign.png", false, false, ColorRGB(1, 1, 0.3))
                cargoList:setEntryTooltip(1, rowIndex, "These goods are illegal!"%_t)
            elseif good.dangerous then
                cargoList:setEntry(1, rowIndex, "data/textures/icons/hazard-sign.png", false, false, ColorRGB(1, 1, 0.3))
                cargoList:setEntryTooltip(1, rowIndex, "These goods are dangerous!"%_t)
            elseif good.suspicious then
                cargoList:setEntry(1, rowIndex, "data/textures/icons/hazard-sign.png", false, false, ColorRGB(1, 1, 0.3))
                cargoList:setEntryTooltip(1, rowIndex, "These goods are suspicious!"%_t)
            end

            cargoList:setEntryType(0, rowIndex, ListBoxEntryType.Icon)
            cargoList:setEntryType(1, rowIndex, ListBoxEntryType.Icon)
            cargoList:setEntryType(2, rowIndex, ListBoxEntryType.Text)
            cargoList:setEntryType(3, rowIndex, ListBoxEntryType.Text)
            cargoList:setEntryType(4, rowIndex, ListBoxEntryType.Text)
            cargoList:setEntryType(5, rowIndex, ListBoxEntryType.Text)
        end
    end

    return ui
end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
