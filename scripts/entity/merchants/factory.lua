
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("randomext")
include ("galaxy")
include ("utility")
include ("goods")
include ("productions")
include ("faction")
include ("stringutility")
include ("callable")
local FactoryMap = include ("factorymap")
local ConsumerGoods = include ("consumergoods")
local TradingUtility = include ("tradingutility")
local TradingAPI = include ("tradingmanager")
local Dialog = include("dialogutility")
local UICollection = include("uicollection")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Factory
Factory = {}
Factory = TradingAPI:CreateNamespace()

local tabbedWindow = nil


local production = nil

local factorySize = 1

local currentProductions = {}

local deliveredStations = {}
local deliveringStations = {}

local buyTab
local sellTab
local configTab

local basePriceLabel
local basePriceSlider
local allowBuyCheckBox
local allowSellCheckBox
local activelyRequestCheckBox
local activelySellCheckBox
local upgradeProductionPriceLabel
local upgradeProductionButton
local upgradeShuttlesPriceLabel
local upgradeShuttlesButton
local productionErrorSign

local productionError
local newProductionError

local productionIcon
local numProductionsLabel

local ingredientLabels = {}
local productLabels = {}
local statsLabels = {}

local deliveredStationsCombos = {}
local deliveringStationsCombos = {}

local deliveredStationsErrorLabels = {}
local deliveringStationsErrorLabels = {}

local deliveredStationsErrors = {}
local deliveringStationsErrors = {}

local newDeliveredStationsErrors = {}
local newDeliveringStationsErrors = {}

Factory.MinimumCapacity = 100
Factory.PlanCapacityFactor = 1.0
Factory.MinimumTimeToProduce = 15.0
Factory.MaxShuttleVolume = 50
Factory.SectorTradeInterval = 6 -- trade with other stations every this many seconds

Factory.timeToProduce = Factory.MinimumTimeToProduce
Factory.productionCapacity = Factory.MinimumCapacity
Factory.maxNumProductions = 2
Factory.shuttleVolume = 20

Factory.lowestPriceFactor = 0.9
Factory.highestPriceFactor = 1.1
Factory.traderRequestCooldown = random():getFloat(30, 150)
Factory.immediateTradeCooldown = random():getFloat(1, 10)

Factory.trader.relationsThreshold = -30000

-- this is only important for initialization, won't be used afterwards
Factory.minLevel = nil
Factory.maxLevel = nil

-- cache these values, they are used frequently
local requiredSpaceRatioByGood

-- special version of getMaxStock for factories
Factory.trader.getMaxStock = function(self, good)
    if not requiredSpaceRatioByGood then
        -- fill cache
        local spaceByGood = {}
        local requiredSpaceForOneProduction = 0

        for _, productionPart in pairs({production.ingredients, production.results, production.garbages}) do
            for _, productionGood in pairs(productionPart) do
                -- if the good does not exist in the goods index for some reason, assume it has size 1
                local size = 1
                if goods[productionGood.name] then
                    size = goods[productionGood.name].size
                end

                local space = size * productionGood.amount

                spaceByGood[productionGood.name] = space
                requiredSpaceForOneProduction = requiredSpaceForOneProduction + space
            end
        end

        requiredSpaceRatioByGood = {}
        for name, space in pairs(spaceByGood) do
            -- the ratio of the total space that is used for the given good
            requiredSpaceRatioByGood[name] = space / requiredSpaceForOneProduction
        end
    end

    local ratio = requiredSpaceRatioByGood[good.name]
    if not ratio then
        return 0
    end

    local maxStock = Entity().maxCargoSpace * ratio / good.size
    if maxStock > 100 then
        -- round to 100
        return math.min(50000, round(maxStock / 100) * 100)
    else
        -- not very much space already, don't round
        return math.floor(maxStock)
    end
end

-- if this function returns false, the script will not be listed in the interaction window on the client,
-- even though its UI may be registered
function Factory.interactionPossible(playerIndex, option)
    -- if Player(playerIndex).craftIndex == Entity().index then return false end

    return CheckFactionInteraction(playerIndex, Factory.trader.relationsThreshold)
end


function Factory.restore(data)
    Factory.maxNumProductions = data.maxNumProductions
    Factory.shuttleVolume = data.shuttleVolume or 20
    factorySize = data.maxNumProductions - 1
    production = data.production
    currentProductions = data.currentProductions

    for i, v in pairs(currentProductions) do
        if type(v) == "number" then
            currentProductions[i] = {progress = v}
        end
    end


    Factory.restoreTradingGoods(data.tradingData)

    Factory.refreshProductionTime()
    Factory.updateOwnSupply()

    Factory.playAmbientSound()
end

function Factory.secure()
    local data = {}
    data.maxNumProductions = Factory.maxNumProductions
    data.production = production
    data.currentProductions = currentProductions
    data.shuttleVolume = Factory.shuttleVolume
    data.tradingData = Factory.secureTradingGoods()
    return data
end


-- this function gets called on creation of the entity the script is attached to, on client and server
function Factory.initialize(producedGood, productionIndex, size)

    if onServer() then
        Sector():addScriptOnce("sector/traders.lua")

        local self = Entity()
        local productionInitialized = self:getValue("factory_production_initialized")

        -- for large stations it's possible that the generator sacrifices cargo bay for generators etc.
        local cargoBay = CargoBay()
        if Factory.trader.minimumCargoBay and self.aiOwned then
            if cargoBay.cargoHold < Factory.trader.minimumCargoBay then
                cargoBay.fixedSize = true
                cargoBay.cargoHold = Factory.trader.minimumCargoBay
            end
        else
            cargoBay.fixedSize = false
        end

        if type(producedGood) == "table" then
            Factory.setProduction(producedGood, size)
        elseif producedGood or productionIndex or size or not productionInitialized then
            Factory.initializeProduction(producedGood, productionIndex, size)
        end

        Sector():registerCallback("onRestoredFromDisk", "onRestoredFromDisk")

        -- execute the callback for initialization, to be sure
        Factory.onBlockPlanChanged(self.id, true)

        -- set background noise
        Factory.playAmbientSound()

    else
        Factory.requestProductionStats()
        Factory.requestGoods()
        Factory.sync()
    end

    Entity():registerCallback("onBlockPlanChanged", "onBlockPlanChanged")
end

function Factory.playAmbientSound()
    local self = Entity()
    self:addScriptOnce("stationambientsound.lua")

    if production and (string.match(production.factory, "Mine") or string.match(production.factory, "Oil Rig")) then
        self:invokeFunction("stationambientsound.lua", "setSound", "ambiences/mine", 0.16)
    else
        self:invokeFunction("stationambientsound.lua", "setSound", "ambiences/factory_thumping1", 0.7)
    end
end

function Factory.onRestoredFromDisk(timeSinceLastSimulation)
    local boughtStock, soldStock = Factory.getInitialGoods(Factory.trader.boughtGoods, Factory.trader.soldGoods)
    local entity = Entity()

    local factor = math.max(0, math.min(1, (timeSinceLastSimulation - 10 * 60) / (100 * 60)))

    -- simulate deliveries to factory
    local faction = Faction()

    if faction and faction.isAIFaction then
        for good, amount in pairs(boughtStock) do
            local curAmount = entity:getCargoAmount(good)
            local diff = math.floor((amount - curAmount) * factor)

            if diff > 0 then
                Factory.increaseGoods(good.name, diff)
            end
        end
    end

    -- calculate production
    -- limit by time
    local maxAmountProduced = math.floor(timeSinceLastSimulation / Factory.timeToProduce) * Factory.maxNumProductions

    -- limit by goods
    for _, ingredient in pairs(production.ingredients) do
        if ingredient.optional == 0 then
            maxAmountProduced = math.min(maxAmountProduced, math.floor(Factory.getNumGoods(ingredient.name) / ingredient.amount))
        end
    end

    -- limit by space
    local productSpace = 0
    for _, ingredient in pairs(production.ingredients) do
        if ingredient.optional == 0 then
            local size = Factory.getGoodSize(ingredient.name)
            productSpace = productSpace - ingredient.amount * size
        end
    end

    for _, garbage in pairs(production.garbages) do
        local size = Factory.getGoodSize(garbage.name)
        productSpace = productSpace + garbage.amount * size
    end

    for _, result in pairs(production.results) do
        local size = Factory.getGoodSize(result.name)
        productSpace = productSpace + result.amount * size
    end

    if productSpace > 0 then
        maxAmountProduced = math.min(maxAmountProduced, math.floor(entity.freeCargoSpace / productSpace))
    end

    -- do production
    for _, ingredient in pairs(production.ingredients) do
        Factory.decreaseGoods(ingredient.name, ingredient.amount * maxAmountProduced)
    end

    for _, garbage in pairs(production.garbages) do
        Factory.increaseGoods(garbage.name, garbage.amount * maxAmountProduced)
    end

    for _, result in pairs(production.results) do
        Factory.increaseGoods(result.name, result.amount * maxAmountProduced)
    end

    -- simulate goods bought from the factory
    if faction and faction.isAIFaction then
        for good, amount in pairs(soldStock) do
            local curAmount = entity:getCargoAmount(good)
            local diff = math.floor((amount - curAmount) * factor)

            if diff < 0 then
                Factory.decreaseGoods(good.name, -diff)
            end
        end
    end
end

function Factory.initializeProduction(producedGood, productionIndex, size)
    local station = Entity()
    station:setValue("factory_production_initialized", true)

    local seed = Sector().seed + Sector().numEntities
    math.randomseed(seed)

    -- determine the ratio with which the factory will set its sell/buy prices
    Factory.setBuySellFactor(random():getFloat(Factory.lowestPriceFactor, Factory.highestPriceFactor))

    if producedGood and productionIndex == nil then

        if producedGood == "nothing" then
            return
        end

        local numProductions = tablelength(productionsByGood[producedGood])
        if numProductions == nil or numProductions == 0 then
            -- good is not produced, skip and choose randomly
            print("No productions found for " .. producedGood .. ", choosing production at random")

            producedGood = nil
        else
            productionIndex = 1
        end
    end

    if producedGood == nil or productionIndex == nil then
        -- choose a production by evaluating importance
        Factory.minLevel = Factory.minLevel or 0
        Factory.maxLevel = Factory.maxLevel or 10000

        -- choose a product by level
        -- read all levels of all products
        local potentialGoods = {}
        local highestLevel = 0

        for _, good in pairs(spawnableGoods) do
            if good.level ~= nil then -- if it has no level, it is not produced
                if good.level >= Factory.minLevel and good.level <= Factory.maxLevel then

                    table.insert(potentialGoods, good)

                    -- increase max level
                    if highestLevel < good.level then
                        highestLevel = good.level
                    end
                end
            end
        end

        -- calculate the probability that a certain production is chosen
        local probabilities = {}
        for i, good in pairs(potentialGoods) do
            -- highestlevel - good.level makes sure the higher goods have a smaller probability of being chosen
            -- +3 to add a little more randomness, so not only the "important" factories are created
            probabilities[i] = (highestLevel - good.level) + good.importance + 3
        end

        -- choose produced good
        local numProductions = nil

        while ((numProductions == nil) or (numProductions == 0)) do

            -- choose produced good at random from probability table
            local i = getValueFromDistribution(probabilities)
            producedGood = potentialGoods[i].name

            -- choose a production type, a good may be produced in multiple factories
            numProductions = tablelength(productionsByGood[producedGood])

            if numProductions == nil or numProductions == 0 then
                -- good is not produced, skip and take next
                -- print("product is invalid: " .. product .. "\n")
                probabilities[i] = nil
            end
        end

        productionIndex = math.random(1, numProductions)
    end

    local chosenProduction = productionsByGood[producedGood][productionIndex]
    if chosenProduction then
        Factory.setProduction(chosenProduction, size)
    end

    math.randomseed(appTimeMs())
end

function Factory.setBuySellFactor(factor)
    Factory.trader.buyPriceFactor = factor
    Factory.trader.sellPriceFactor = Factory.trader.buyPriceFactor * (math.random() * 0.2 + 1.0) -- this is coupled to the buy factor with variation 1.0 to 1.2
end

function Factory.setProduction(production_in, size)

    if size == nil then
        local distanceFromCenter = length(vec2(Sector():getCoordinates()))
        local probabilities = {}

        probabilities[1] = 1.0

        if distanceFromCenter < 450 then
            probabilities[2] = 0.5
        end

        if distanceFromCenter < 400 then
            probabilities[3] = 0.35
        end

        if distanceFromCenter < 350 then
            probabilities[4] = 0.25
        end

        if distanceFromCenter < 300 then
            probabilities[5] = 0.15
        end

        size = getValueFromDistribution(probabilities)
    end

    factorySize = size or 1
    Factory.maxNumProductions = 1 + factorySize
    production = production_in

    -- make lists of all items that will be sold/bought
    local bought = {}

    -- ingredients are bought
    for i, ingredient in pairs(production.ingredients) do
        local g = goods[ingredient.name]
        table.insert(bought, g:good())
    end

    -- results and garbage are sold
    local sold = {}

    for i, result in pairs(production.results) do
        local g = goods[result.name]
        table.insert(sold, g:good())
    end

    for i, garbage in pairs(production.garbages) do
        local g = goods[garbage.name]
        table.insert(sold, g:good())
    end

    local station = Entity()

    -- set title
    if station.title == "" then
        Factory.updateTitle()

        station:setValue("factory_type", "factory")

        if production.mine then
            station:setValue("factory_type", "mine")
            station:addScriptOnce("data/scripts/entity/merchants/consumer.lua", "Mine /*station type*/"%_T, unpack(ConsumerGoods.Mine()))
        end
    end

    Factory.refreshProductionTime()

    Factory.initializeTrading(bought, sold)
    Factory.updateOwnSupply()
end

function Factory.updateOwnSupply()
    local factoryMap = FactoryMap()

    for _, ingredient in pairs(production.ingredients) do
        Factory.trader.ownSupplyTypes[ingredient.name] = factoryMap.SupplyType.FactoryDemand
    end

    for _, result in pairs(production.results) do
        Factory.trader.ownSupplyTypes[result.name] = factoryMap.SupplyType.FactorySupply
    end

    for _, garbage in pairs(production.garbages) do
        Factory.trader.ownSupplyTypes[garbage.name] = factoryMap.SupplyType.FactoryGarbage
    end
end

function Factory.updateTitle()
    local station = Entity()
    station.title = "Factory"%_t

    local size = ""
    if factorySize == 1 then size = "S /* Size, as in S, M, L, XL etc.*/"%_t
    elseif factorySize == 2 then size = "M /* Size, as in S, M, L, XL etc.*/"%_t
    elseif factorySize == 3 then size = "L /* Size, as in S, M, L, XL etc.*/"%_t
    elseif factorySize == 4 then size = "XL /* Size, as in S, M, L, XL etc.*/"%_t
    elseif factorySize == 5 then size = "XXL /* Size, as in S, M, L, XL etc.*/"%_t
    end

    local name, args = formatFactoryName(production, size)

    local station = Entity()
    station:setTitle(name, args)
end

function Factory.sync(data)
    if onClient() then
        if not data then
            invokeServerFunction("sync")
        else
            Factory.maxNumProductions = data.maxNumProductions
            Factory.shuttleVolume = data.shuttleVolume
            factorySize = data.maxNumProductions - 1
            production = data.production

            InteractionText().text = Dialog.generateStationInteractionText(Entity(), random())

            Factory.onShowWindow()
        end
    else
        local data = {}
        data.maxNumProductions = Factory.maxNumProductions
        data.shuttleVolume = Factory.shuttleVolume
        data.factorySize = factorySize
        data.production = production

        invokeClientFunction(Player(callingPlayer), "sync", data)
    end
end
callable(Factory, "sync")

-- this function gets called on creation of the entity the script is attached to, on client only
-- AFTER initialize above
-- create all required UI elements for the client side
function Factory.initUI()

    tabbedWindow = TradingAPI.CreateTabbedWindow("Factory"%_t)

    -- create buy tab
    buyTab = tabbedWindow:createTab("Buy"%_t, "data/textures/icons/bag.png", "Buy from factory"%_t)
    Factory.buildBuyGui(buyTab)

    -- create sell tab
    sellTab = tabbedWindow:createTab("Sell"%_t, "data/textures/icons/sell.png", "Sell to factory"%_t)
    Factory.buildSellGui(sellTab)

    configTab = tabbedWindow:createTab("Configure"%_t, "data/textures/icons/cog.png", "Factory configuration"%_t)
    Factory.buildConfigUI(configTab)

    Factory.trader.guiInitialized = true

    Factory.requestGoods()
end

function Factory.initializationFinished()
    -- use the initilizationFinished() function on the client since in initialize() we may not be able to access Sector scripts on the client
    if onClient() then
        local ok, r = Sector():invokeFunction("radiochatter", "addSpecificLines", Entity().id.string,
        {
            "Only two more years of work, and I'll get my free weekend!"%_t,
            "We are always looking for workers. Everyone who is young and strong can apply."%_t,
            "Reminder to all factory workers: there will be no compensation for lost limbs or loss of life."%_t,
            "Trade your goods at a factory, we offer way better prices than any trading post!"%_t,
            "The best prices in the sector in our factory outlet store!"%_t,
        })
    end
end

function Factory.buildConfigUI(tab)
    local thsplit = UIHorizontalSplitter(Rect(tab.size), 10, 0, 0.35)
    local thsplit2 = UIHorizontalSplitter(thsplit.top, 10, 0, 0.75)

    -- top area showing production
    tab:createFrame(thsplit2.top)

    local vsplit = UIVerticalMultiSplitter(thsplit2.top, 80, 10, 2)

    local lister = UIVerticalLister(vsplit:partition(0), 4, 0)
    ingredientLabels = {}
    for i = 1, 20 do
        local rect = lister:nextRect(10)
        local vsplit = UIVerticalSplitter(rect, 5, 0, 0.86)

        local left = tab:createLabel(vsplit.left, "", 11)
        left:setLeftAligned()
        left.font = FontType.Normal

        local right = tab:createLabel(vsplit.left, "", 11)
        right:setRightAligned()
        right.font = FontType.Normal

        local supply = tab:createLabel(vsplit.right, "", 11)
        supply:setRightAligned()
        supply.font = FontType.Normal
        supply.color = ColorRGB(0, 1, 0)

        table.insert(ingredientLabels, {left = left, right = right, supply = supply})
    end

    local lister = UIVerticalLister(vsplit:partition(1), 4, 0)
    productLabels = {}
    for i = 1, 20 do
        local rect = lister:nextRect(10)
        local vsplit = UIVerticalSplitter(rect, 5, 0, 0.86)

        local left = tab:createLabel(vsplit.left, "", 11)
        left:setLeftAligned()
        left.font = FontType.Normal

        local right = tab:createLabel(vsplit.left, "", 11)
        right:setRightAligned()
        right.font = FontType.Normal

        local supply = tab:createLabel(vsplit.right, "", 11)
        supply:setRightAligned()
        supply.font = FontType.Normal
        supply.color = ColorRGB(0, 1, 0)

        table.insert(productLabels, {left = left, right = right, supply = supply})
    end

    local lister = UIVerticalLister(vsplit:partition(2), 4, 0)
    statsLabels = {}
    for i = 1, 8 do
        local rect = lister:nextRect(10)

        local left = tab:createLabel(rect, "", 11)
        left:setLeftAligned()
        left.font = FontType.Normal

        local right = tab:createLabel(rect, "", 11)
        right:setRightAligned()
        right.font = FontType.Normal

        table.insert(statsLabels, {left = left, right = right})
    end

    local a = vsplit:partition(0)
    local b = vsplit:partition(1)
    local center = (a.center + b.center) / 2

    local r = Rect(center - 30, center + 30)
    r.position = r.position + vec2(0, -20)
    productionIcon = tab:createPicture(r, "data/textures/icons/production.png")
    productionIcon.isIcon = true

    r.position = r.position + vec2(0, 40)
    numProductionsLabel = tab:createLabel(r, "x3", 20)
    numProductionsLabel:setCenterAligned()

    -- error label for production problems
    productionErrorSign = UICollection()
    local frame = tab:createFrame(thsplit2.bottom)

    thsplit2:setPadding(15, 15, 15, 15)

    local label = tab:createLabel(thsplit2.bottom, "Station can't produce because ingredients are missing!"%_t, 14)
    label.color = ColorRGB(1, 1, 0)
    label.centered = true

    local vsplit = UIVerticalSplitter(thsplit2.bottom, 0, 0, 0.5)
    vsplit:setLeftQuadratic()

    local icon = tab:createPicture(vsplit.left, "data/textures/icons/hazard-sign.png")
    icon.isIcon = true
    icon.color = ColorRGB(1, 1, 0)
    icon.lower = icon.lower - vec2(5, 5)
    icon.upper = icon.upper + vec2(5, 5)

    productionErrorSign:insert(label)
    productionErrorSign:insert(icon)
    productionErrorSign:insert(frame)
    productionErrorSign.label = label
    productionErrorSign.icon = icon

    productionErrorSign:hide()


    -- lower area with config options
    local hsplit = UIHorizontalSplitter(thsplit.bottom, 10, 0, 0.8)
    local vsplit = UIVerticalMultiSplitter(thsplit.bottom, 10, 0, 2)
    local lister = UIVerticalLister(vsplit:partition(0), 5, 0)

    basePriceLabel = tab:createLabel(Rect(), "Base Price %"%_t, 12)
    lister:placeElementTop(basePriceLabel)
    basePriceLabel.centered = true

    basePriceSlider = tab:createSlider(Rect(), -20, 20, 40, "", "onBasePriceSliderChanged")
    lister:placeElementTop(basePriceSlider)
    basePriceSlider:setValueNoCallback(0)
    basePriceSlider.unit = "%"
    basePriceSlider.tooltip = "Sets the base price of goods bought and sold by this station. A low base price attracts more buyers and a high base price attracts more sellers."%_t


    lister:nextRect(15)

    allowBuyCheckBox = tab:createCheckBox(Rect(), "Buy goods from others"%_t, "onAllowBuyChecked")
    lister:placeElementTop(allowBuyCheckBox)
    allowBuyCheckBox:setCheckedNoCallback(true)
    allowBuyCheckBox.tooltip = "If checked, the station will buy goods from traders from other factions than you."%_t

    allowSellCheckBox = tab:createCheckBox(Rect(), "Sell goods to others"%_t, "onAllowSellChecked")
    lister:placeElementTop(allowSellCheckBox)
    allowSellCheckBox:setCheckedNoCallback(true)
    allowSellCheckBox.tooltip = "If checked, the station will sell goods to traders from other factions than you."%_t

    lister:nextRect(10)

    activelyRequestCheckBox = tab:createCheckBox(Rect(), "Actively request goods"%_t, "onActivelyRequestChecked")
    lister:placeElementTop(activelyRequestCheckBox)
    activelyRequestCheckBox:setCheckedNoCallback(true)
    activelyRequestCheckBox.tooltip = "If checked, the station will actively request traders to deliver goods when it's empty.\nIf unchecked, it may stay empty until a trader visits randomly."%_t

    activelySellCheckBox = tab:createCheckBox(Rect(), "Actively sell goods"%_t, "onActivelySellChecked")
    lister:placeElementTop(activelySellCheckBox)
    activelySellCheckBox:setCheckedNoCallback(true)
    activelySellCheckBox.tooltip = "If checked, the station will request traders that will buy its goods when it's full.\nIf unchecked, its goods may sit around until a trader visits randomly."%_t

    lister:nextRect(10)


    -- delivery UI
    local lister = UIVerticalLister(vsplit:partition(1), 8, 0)
    local label = tab:createLabel(Rect(), "Deliver goods to stations:"%_t, 12)
    lister:placeElementTop(label)
    label.centered = true

    lister:nextRect(5)

    local combo = tab:createValueComboBox(Rect(), "sendConfig")
    lister:placeElementTop(combo)
    table.insert(deliveredStationsCombos, combo)

    local combo = tab:createValueComboBox(Rect(), "sendConfig")
    lister:placeElementTop(combo)
    table.insert(deliveredStationsCombos, combo)

    local combo = tab:createValueComboBox(Rect(), "sendConfig")
    lister:placeElementTop(combo)
    table.insert(deliveredStationsCombos, combo)

    lister:nextRect(30)


    local label = tab:createLabel(Rect(), "Fetch goods from stations:"%_t, 12)
    lister:placeElementTop(label)
    label.centered = true

    lister:nextRect(5)

    local combo = tab:createValueComboBox(Rect(), "sendConfig")
    lister:placeElementTop(combo)
    table.insert(deliveringStationsCombos, combo)

    local combo = tab:createValueComboBox(Rect(), "sendConfig")
    lister:placeElementTop(combo)
    table.insert(deliveringStationsCombos, combo)

    local combo = tab:createValueComboBox(Rect(), "sendConfig")
    lister:placeElementTop(combo)
    table.insert(deliveringStationsCombos, combo)



    -- error labels
    local lister = UIVerticalLister(vsplit:partition(2), 15, 0)
    local label = tab:createLabel(Rect(), "", 6)
    lister:placeElementTop(label)
    label.centered = true
    lister:nextRect(0)

    local label = tab:createLabel(Rect(), "", 14)
    lister:placeElementTop(label)
    table.insert(deliveredStationsErrorLabels, label)

    local label = tab:createLabel(Rect(), "", 14)
    lister:placeElementTop(label)
    table.insert(deliveredStationsErrorLabels, label)

    local label = tab:createLabel(Rect(), "", 14)
    lister:placeElementTop(label)
    table.insert(deliveredStationsErrorLabels, label)

    lister:nextRect(12)


    local label = tab:createLabel(Rect(), "", 12)
    lister:placeElementTop(label)
    label.centered = true

    lister:nextRect(5)

    local label = tab:createLabel(Rect(), "", 14)
    lister:placeElementTop(label)
    table.insert(deliveringStationsErrorLabels, label)

    local label = tab:createLabel(Rect(), "", 14)
    lister:placeElementTop(label)
    table.insert(deliveringStationsErrorLabels, label)

    local label = tab:createLabel(Rect(), "", 14)
    lister:placeElementTop(label)
    table.insert(deliveringStationsErrorLabels, label)

    for _, labels in pairs({deliveringStationsErrorLabels, deliveredStationsErrorLabels}) do
        for _, label in pairs(labels) do
            label.caption = ""
            label.color = ColorRGB(1, 1, 0)
        end
    end


    -- upgrade UI
    local vsplit = UIVerticalMultiSplitter(hsplit.bottom, 10, 0, 2)

    local upgradeRect = vsplit:partition(0)
    upgradeRect.lower = upgradeRect.lower - vec2(0, 20)
    local bhsplit = UIHorizontalSplitter(upgradeRect, 10, 0, 0.5)

    local bvsplit = UIVerticalSplitter(bhsplit.top, 10, 0, 0.5)
    bvsplit:setLeftQuadratic()
    upgradeProductionButton = tab:createButton(bvsplit.left, "", "onUpgradeProductionButtonPressed")
    upgradeProductionButton.icon = "data/textures/icons/upgrade-production.png"
    upgradeProductionPriceLabel = tab:createLabel(bvsplit.right, "", 14)
    upgradeProductionPriceLabel:setRightAligned()

    local bvsplit = UIVerticalSplitter(bhsplit.bottom, 10, 0, 0.5)
    bvsplit:setLeftQuadratic()
    upgradeShuttlesButton = tab:createButton(bvsplit.left, "", "onUpgradeShuttlesButtonPressed")
    upgradeShuttlesButton.icon = "data/textures/icons/upgrade-shuttles.png"
    upgradeShuttlesPriceLabel = tab:createLabel(bvsplit.right, "", 14)
    upgradeShuttlesPriceLabel:setRightAligned()

    -- transport capacity UI
    local bvsplit = UIVerticalSplitter(vsplit:partition(1), 10, 10, 0.5)
    bvsplit.marginLeft = 80
    bvsplit:setLeftQuadratic()

    local tooltip = "Shuttles transport a certain amount of volume (but always at least 1 good) per every few seconds to other stations."%_t
    local transportIcon = tab:createPicture(bvsplit.left, "data/textures/icons/transport-shuttles.png")
    transportIcon.isIcon = true
    transportIcon.tooltip = tooltip

    transportCapacityLabel = tab:createLabel(bvsplit.right, "", 14)
    transportCapacityLabel:setLeftAligned()
    transportCapacityLabel.tooltip = tooltip

end

function Factory.sendConfig()
    local config = {}
    if onClient() then
        -- read new config from ui elements
        config.priceFactor = 1.0 + basePriceSlider.value / 100.0
        config.activelyRequest = activelyRequestCheckBox.checked
        config.activelySell = activelySellCheckBox.checked
        config.buyFromOthers = allowBuyCheckBox.checked
        config.sellToOthers = allowSellCheckBox.checked

        config.deliveringStations = {}
        config.deliveredStations = {}

        for _, combo in pairs(deliveredStationsCombos) do
            local id = combo.selectedValue

            if id then
                local trades = deliveredStations[id] or {}
                config.deliveredStations[id] = trades
            end
        end

        for _, combo in pairs(deliveringStationsCombos) do
            local id = combo.selectedValue

            if id then
                local trades = deliveringStations[id] or {}
                config.deliveringStations[id] = trades
            end
        end

        invokeServerFunction("setConfig", config)
    else
        -- read config from factory settings
        config.priceFactor = Factory.trader.buyPriceFactor

        config.buyFromOthers = Factory.trader.buyFromOthers
        config.sellToOthers = Factory.trader.sellToOthers
        config.activelyRequest = Factory.trader.activelyRequest
        config.activelySell = Factory.trader.activelySell
        config.deliveredStations = Factory.trader.deliveredStations
        config.deliveringStations = Factory.trader.deliveringStations

        invokeClientFunction(Player(callingPlayer), "setConfig", config)
    end
end
callable(Factory, "sendConfig")


function Factory.setConfig(config)
    if onClient() then
        -- apply config to UI elements
        basePriceSlider:setValueNoCallback(round((config.priceFactor - 1.0) * 100.0))
        basePriceLabel.tooltip = "This station will buy and sell its goods for ${percentage}% of the normal price."%_t % {percentage = round(config.priceFactor * 100.0)}

        allowBuyCheckBox:setCheckedNoCallback(config.buyFromOthers)
        allowSellCheckBox:setCheckedNoCallback(config.sellToOthers)
        activelyRequestCheckBox:setCheckedNoCallback(config.activelyRequest)
        activelySellCheckBox:setCheckedNoCallback(config.activelySell)

        local i = 1
        for id, trades in pairs(config.deliveredStations) do
            deliveredStationsCombos[i]:setSelectedValueNoCallback(id)
            i = i + 1
        end

        for a = i, 3 do
            deliveredStationsCombos[a]:setSelectedIndexNoCallback(0)
        end

        local i = 1
        for id, trades in pairs(config.deliveringStations) do
            deliveringStationsCombos[i]:setSelectedValueNoCallback(id)
            i = i + 1
        end

        for a = i, 3 do
            deliveringStationsCombos[a]:setSelectedIndexNoCallback(0)
        end

        if TradingAPI.window.visible then
            Factory.refreshConfigUI()
        end
    else
        if not config then return end

        -- apply config to factory settings
        local owner, station, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations)
        if not owner then return end

        Factory.trader.buyPriceFactor = math.min(1.5, math.max(0.5, config.priceFactor))
        Factory.trader.sellPriceFactor = Factory.trader.buyPriceFactor + 0.2

        Factory.trader.buyFromOthers = config.buyFromOthers
        Factory.trader.sellToOthers = config.sellToOthers
        Factory.trader.activelyRequest = config.buyFromOthers and config.activelyRequest
        Factory.trader.activelySell = config.sellToOthers and config.activelySell
        Factory.trader.deliveredStations = config.deliveredStations or {}
        Factory.trader.deliveringStations = config.deliveringStations or {}

        Factory.sendConfig()
    end
end
callable(Factory, "setConfig")

-- this functions gets called when the indicator of the station is rendered on the client
function Factory.renderUIIndicator(px, py, size)

    x = px - size / 2
    y = py + size / 2

    local index = 0
    for i, p in pairs(currentProductions) do
        index = index + 1

        -- outer rect
        dx = x
        dy = y + index * 5

        sx = size + 2
        sy = 4

        drawRect(Rect(dx, dy, sx + dx, sy + dy), ColorRGB(0, 0, 0))

        -- inner rect
        dx = dx + 1
        dy = dy + 1

        sx = sx - 2
        sy = sy - 2

        sx = sx * p.progress

        drawRect(Rect(dx, dy, sx + dx, sy + dy), ColorRGB(0.66, 0.66, 1.0))
    end

end

-- this function gets called every time the window is shown on the client, ie. when a player presses F and if interactionPossible() returned 1
function Factory.onShowWindow()

    local station = Entity()
    local player = Player()

    if buyTab then
        if #Factory.trader.soldGoods == 0 or player.craftIndex == station.index then
            tabbedWindow:deactivateTab(buyTab)
        else
            tabbedWindow:activateTab(buyTab)
        end
    end

    if sellTab then
        if #Factory.trader.boughtGoods == 0 or player.craftIndex == station.index then
            tabbedWindow:deactivateTab(sellTab)
        else
            tabbedWindow:activateTab(sellTab)
        end
    end

    if configTab then
        local faction = Faction()

        if player.index == faction.index or player.allianceIndex == faction.index then
            tabbedWindow:activateTab(configTab)
            Factory.refreshConfigUI()
            Factory.refreshConfigCombos()
            Factory.refreshConfigErrors()

            invokeServerFunction("sendConfig")
            invokeServerFunction("sendDeliveryErrors")
        else
            tabbedWindow:deactivateTab(configTab)
        end
    end

    Factory.requestGoods()

end

function Factory.refreshConfigUI()
    if not production then return end

    for _, labelCollection in pairs({ingredientLabels, productLabels}) do
        for _, labels in pairs(labelCollection) do
            labels.left:hide()
            labels.right:hide()
            labels.supply:hide()
        end
    end

    numProductionsLabel.caption = "x${productions}"%_t % {productions = Factory.maxNumProductions}

    local tooltip = "This factory can have up to ${productions} productions running in parallel."%_t % {productions = Factory.maxNumProductions}
    numProductionsLabel.tooltip = tooltip
    productionIcon.tooltip = tooltip

    ingredientLabels[1].left:show()
    ingredientLabels[1].left.caption = "[No ingredients required]"%_t

    local ingredientSum = 0
    local productSum = 0

    local i = 1
    for _, good in pairs(production.ingredients) do
        local labels = ingredientLabels[i]
        labels.left:show()
        labels.right:show()
        labels.supply:show()

        local tgood = goods[good.name]
        if not tgood then goto continue end
        tgood = tgood:good()

        labels.left.caption = "${name} (x${amount})"%_t % {name = tgood:displayName(good.amount), amount = good.amount}

        local price, _, supplyDemandFactor, relationFactor, buySellMarginFactor = Factory.getBuyPrice(good.name)
        if price == 0 or supplyDemandFactor == nil then goto continue end

        local basePrice = tgood.price
        local price = createMonetaryString(basePrice * supplyDemandFactor * buySellMarginFactor)
        labels.right.caption = credits() .. createMonetaryString(basePrice * supplyDemandFactor * buySellMarginFactor)

        ingredientSum = ingredientSum + basePrice * supplyDemandFactor * buySellMarginFactor * good.amount

        local tooltip = "${c}${price} - Base Price"%_t % {price = createMonetaryString(basePrice), c = credits()} .. "\n\n" ..
                        "x ${factor}% - Base Price Factor"%_t % {factor = round(buySellMarginFactor * 100)} .. "\n" ..
                        "x ${factor}% - Regional Supply/Demand"%_t % {factor = round(supplyDemandFactor * 100)} .. "\n\n" ..
                        "${c}${price} - Final Price"%_t % {price = price, c = credits()} .. "\n\n" ..
                        "Note: Prices are influenced by regional supply and demand."%_t .. "\n\n" ..
                        "Note: Additionally, the price of this good is influenced by your relations with the seller."%_t

        labels.left.italic = false
        if good.optional == 1 then
            tooltip = tooltip .. "\n\n" .. "Optional Ingredient: This ingredient is not required for production, but when used will double production speed."%_t
            labels.left.italic = true
        end

        labels.left.tooltip = tooltip

        local priceChange = round(supplyDemandFactor * 100) - 100
        local percentage = string.format("%+d%%", round(supplyDemandFactor * 100) - 100)
        labels.supply.caption = percentage
        local tooltip
        if priceChange > 0 then
            labels.supply.color = ColorRGB(0.4, 0.4, 1.0)
            tooltip = "Prices for ${goods} are ${percentage} higher in this region, because there is a high demand for this good."%_t % {goods = tgood:displayName(100), percentage = percentage}
        elseif priceChange < 0 then
            labels.supply.color = ColorRGB(0.0, 1.0, 0.0)
            tooltip = "Prices for ${goods} are ${percentage} lower in this region, because there is a high supply for this good."%_t % {goods = tgood:displayName(100), percentage = percentage}
        else
            labels.supply.color = ColorRGB(0.8, 0.8, 0.8)
            tooltip = "Prices for ${goods} are unchanged in this region. There is no special regional demand for this good."%_t % {goods = tgood:displayName(100), percentage = percentage}
        end

        tooltip = tooltip .. "\n\n" .. "Note: This is a regional effect, and has no influence on the amount of traders visiting your factory."%_t
        labels.supply.tooltip = tooltip

        i = i + 1
        ::continue::
    end

    local i = 1
    for _, list in pairs({production.results, production.garbages}) do
    for _, good in pairs(list) do
        local labels = productLabels[i]
        labels.left:show()
        labels.right:show()
        labels.supply:show()

        local tgood = goods[good.name]
        if not tgood then goto continue end
        tgood = tgood:good()

        labels.left.caption = "${name} (x${amount})"%_t % {name = tgood:displayName(good.amount), amount = good.amount}

        local price, _, supplyDemandFactor, relationFactor, buySellMarginFactor = Factory.getSellPrice(good.name)
        if price == 0 or supplyDemandFactor == nil then goto continue end

        local basePrice = tgood.price
        local price = createMonetaryString(basePrice * supplyDemandFactor * buySellMarginFactor)
        labels.right.caption = credits() .. createMonetaryString(basePrice * supplyDemandFactor * buySellMarginFactor)

        productSum = productSum + basePrice * supplyDemandFactor * buySellMarginFactor * good.amount

        local tooltip = "${c}${price} - Base Price"%_t % {price = createMonetaryString(basePrice), c = credits()} .. "\n\n" ..
                        "x ${factor}% - Base Price Factor"%_t % {factor = round(buySellMarginFactor * 100)} .. "\n" ..
                        "x ${factor}% - Regional Supply/Demand"%_t % {factor = round(supplyDemandFactor * 100)} .. "\n\n" ..
                        "${c}${price} - Final Price"%_t % {price = price, c = credits()} .. "\n\n" ..
                        "Note: Prices are influenced by regional supply and demand."%_t .. "\n\n" ..
                        "Note: Additionally, the price of this good is influenced by your relations with the buyer."%_t

        labels.left.tooltip = tooltip

        local priceChange = round(supplyDemandFactor * 100) - 100
        local percentage = string.format("%+d%%", round(supplyDemandFactor * 100) - 100)
        labels.supply.caption = percentage
        local tooltip

        if priceChange > 0 then
            labels.supply.color = ColorRGB(0.0, 1.0, 0.0)
            tooltip = "Prices for ${goods} are ${percentage} higher in this region, because there is a high demand for this good."%_t % {goods = tgood:displayName(100), percentage = percentage}
        elseif priceChange < 0 then
            labels.supply.color = ColorRGB(0.4, 0.4, 1.0)
            tooltip = "Prices for ${goods} are ${percentage} lower in this region, because there is a high supply for this good."%_t % {goods = tgood:displayName(100), percentage = percentage}
        else
            labels.supply.color = ColorRGB(0.8, 0.8, 0.8)
            tooltip = "Prices for ${goods} are unchanged in this region. There is no special regional demand for this good."%_t % {goods = tgood:displayName(100), percentage = percentage}
        end

        tooltip = tooltip .. "\n\n" .. "Note: This is a regional effect, and has no influence on the amount of traders visiting your factory."%_t
        labels.supply.tooltip = tooltip

        i = i + 1
        ::continue::
    end
    end


    local stats = Factory.trader.stats
    statsLabels[1].left.caption = "Profit / production"%_t
    statsLabels[1].right.caption = "${c}${money}"%_t % {c = credits(), money = createMonetaryString(productSum - ingredientSum)}
    statsLabels[1].left.tooltip = "The average amount of profit per production, calculated by comparing the value of all products against the value of all ingredients."%_t

    statsLabels[3].left.caption = "Money spent"%_t
    statsLabels[3].right.caption = "${c}${money}"%_t % {c = credits(), money = createMonetaryString(stats.moneySpentOnGoods)}
    statsLabels[3].left.tooltip = "Amount of money spent on purchasing ingredients for production.\n\nNote: In the beginning, factories have to invest some money and may not yield profits immediately."%_t

    statsLabels[4].left.caption = "Money gained"%_t
    statsLabels[4].right.caption = "${c}${money}"%_t % {c = credits(), money = createMonetaryString(stats.moneyGainedFromGoods)}
    statsLabels[4].left.tooltip = "Amount of money gained by selling products."%_t

    statsLabels[6].left.caption = "Profit"%_t
    statsLabels[6].right.caption = "${c}${money}"%_t % {c = credits(), money = createMonetaryString(stats.moneyGainedFromGoods + stats.moneyGainedFromTax - stats.moneySpentOnGoods)}
    statsLabels[6].left.tooltip = "Total profit of the factory; (sales - purchases).\n\nNote: In the beginning, factories have to invest some money and may not yield profits immediately."%_t

    if factorySize < 5 then
        local price = createMonetaryString(getFactoryUpgradeCost(production, factorySize + 1))
        upgradeProductionPriceLabel.caption = "${price} Cr"%_t % {price = price}
        upgradeProductionPriceLabel.visible = true
        upgradeProductionButton.tooltip = "Upgrade to allow up to ${amount} parallel productions."%_t % {amount = factorySize + 2}
        upgradeProductionButton.visible = true
    else
        upgradeProductionPriceLabel.visible = false
        upgradeProductionButton.visible = true
        upgradeProductionButton.active = false
        upgradeProductionButton.tooltip = nil
    end

    if Factory.shuttleVolume < Factory.MaxShuttleVolume then
        local price = createMonetaryString(Factory.getShuttleUpgradeCost())
        upgradeShuttlesPriceLabel.caption = "${price} Cr"%_t % {price = price}

        upgradeShuttlesButton.visible = true
        upgradeShuttlesPriceLabel.visible = true

        upgradeShuttlesButton.tooltip = "Upgrade to allow up to ${volume} transported volume per shuttle every ${seconds} seconds."%_t % {volume = Factory.shuttleVolume + 5, seconds = Factory.SectorTradeInterval}
    else
        upgradeShuttlesPriceLabel.visible = false
        upgradeShuttlesButton.visible = true
        upgradeShuttlesButton.active = false
        upgradeShuttlesButton.tooltip = nil
    end

    transportCapacityLabel.caption = "${volume}vol/${seconds}s"%_t % {volume = Factory.shuttleVolume, seconds = Factory.SectorTradeInterval}
end

function Factory.refreshConfigCombos()
    if not production then return end
    if not production.ingredients then return end
    if not production.results then return end
    if not production.garbages then return end

    local stations = {Sector():getEntitiesByType(EntityType.Station)}

    deliveredStations = {}
    deliveringStations = {}

    for _, station in pairs(stations) do
        for _, ingredient in pairs(production.ingredients) do
            local good = ingredient.name
            local script = TradingUtility.getEntitySellsGood(station, good)
            if script then
                local trades = deliveringStations[station.id.string] or {}
                table.insert(trades, {good = good, script = script})

                deliveringStations[station.id.string] = trades
            end
        end

        for _, result in pairs(production.results) do
            local good = result.name
            local script = TradingUtility.getEntityBuysGood(station, good)
            if script then
                local trades = deliveredStations[station.id.string] or {}
                table.insert(trades, {good = good, script = script})

                deliveredStations[station.id.string] = trades
            end
        end

        for _, garbage in pairs(production.garbages) do
            local good = garbage.name
            local script = TradingUtility.getEntityBuysGood(station, good)
            if script then
                local trades = deliveredStations[station.id.string] or {}
                table.insert(trades, {good = good, script = script})

                deliveredStations[station.id.string] = trades
            end
        end
    end

    for _, combo in pairs(deliveredStationsCombos) do
        combo:clear()
        combo:addEntry(nil, "- None -"%_t)

        for id, _ in pairs(deliveredStations) do
            local station = Sector():getEntity(id)
            local name = station.translatedTitle .. " " .. station.name

            local faction = Faction(station.factionIndex)
            if faction then
                name = name .. " - (" .. faction.translatedName .. ")"
            end

            combo:addEntry(id, name)
        end
    end

    for _, combo in pairs(deliveringStationsCombos) do
        combo:clear()
        combo:addEntry(nil, "- None -"%_t)

        for id, _ in pairs(deliveringStations) do
            local station = Sector():getEntity(id)
            local name = station.translatedTitle .. " - " .. station.name

            local faction = Faction(station.factionIndex)
            if faction then
                name = name .. " - (" .. faction.translatedName .. ")"
            end

            combo:addEntry(id, name)
        end
    end

end

function Factory.refreshConfigErrors()
    if not Factory.trader.guiInitialized then return end

    for _, labels in pairs({deliveringStationsErrorLabels, deliveredStationsErrorLabels}) do
        for _, label in pairs(labels) do
            label.caption = ""
            label.color = ColorRGB(1, 1, 0)
        end
    end

    for index, error in pairs(deliveredStationsErrors) do
        if index and error then
            deliveredStationsErrorLabels[index].caption = GetLocalizedString(error)
        end
    end

    for index, error in pairs(deliveringStationsErrors) do
        if index and error then
            deliveringStationsErrorLabels[index].caption = GetLocalizedString(error)
        end
    end

    if not productionError or productionError == "" then
        productionErrorSign:show()
        productionErrorSign.label.caption = "Factory appears to be working as intended."%_t
        productionErrorSign.label.color = ColorRGB(0, 1, 0)
        productionErrorSign.icon.color = ColorRGB(0, 1, 0)
        productionErrorSign.icon.picture = "data/textures/icons/checkmark.png"
    else
        productionErrorSign:show()
        productionErrorSign.label.caption = productionError or ""
        productionErrorSign.label.color = ColorRGB(1, 1, 0)
        productionErrorSign.icon.color = ColorRGB(1, 1, 0)
        productionErrorSign.icon.picture = "data/textures/icons/hazard-sign.png"
    end
end


function Factory.onBasePriceSliderChanged() Factory.sendConfig() end
function Factory.onAllowBuyChecked() Factory.sendConfig() end
function Factory.onAllowSellChecked() Factory.sendConfig() end
function Factory.onActivelyRequestChecked() Factory.sendConfig() end
function Factory.onActivelySellChecked() Factory.sendConfig() end
function Factory.onDeliveringStationsChanged() Factory.sendConfig() end

function Factory.onUpgradeProductionButtonPressed()
    if onClient() then
        invokeServerFunction("onUpgradeProductionButtonPressed")
        return
    end

    local buyer, _, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources, AlliancePrivilege.ManageStations)
    if not buyer then return end

    if factorySize >= 5 then
        player:sendChatMessage("", ChatMessageType.Error, "This factory is already at its highest level."%_t)
        return
    end

    local price = getFactoryUpgradeCost(production, factorySize + 1)

    local canPay, msg, args = buyer:canPay(price)
    if not canPay then -- if there was an error, print it
        player:sendChatMessage(Entity(), 1, msg, unpack(args))
        return
    end

    buyer:pay(price)

    local newSize = factorySize + 1
    factorySize = newSize
    Factory.maxNumProductions = factorySize + 1
    Factory.updateTitle()

    Factory.sync()
    invokeClientFunction(player, "refreshConfigUI")
end
callable(Factory, "onUpgradeProductionButtonPressed")

function Factory.onUpgradeShuttlesButtonPressed()
    if onClient() then
        invokeServerFunction("onUpgradeShuttlesButtonPressed")
        return
    end

    local buyer, _, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources, AlliancePrivilege.ManageStations)
    if not buyer then return end

    if Factory.shuttleVolume >= Factory.MaxShuttleVolume then
        player:sendChatMessage("", ChatMessageType.Error, "Transport capacity is already at maximum."%_t)
        return
    end

    local price = Factory.getShuttleUpgradeCost(production, factorySize + 1)

    local canPay, msg, args = buyer:canPay(price)
    if not canPay then -- if there was an error, print it
        player:sendChatMessage(Entity(), 1, msg, unpack(args))
        return
    end

    buyer:pay(price)

    Factory.shuttleVolume = Factory.shuttleVolume + 5

    Factory.sync()
    invokeClientFunction(player, "refreshConfigUI")
end
callable(Factory, "onUpgradeShuttlesButtonPressed")

-- this function gets called every time the window is closed on the client
--function onCloseWindow()
--
--end

function Factory.startProduction(timeStep, boosted)
    table.insert(currentProductions, {progress = timeStep / Factory.timeToProduce, boosted = boosted})

    if onServer() then
        broadcastInvokeClientFunction("startProduction", timeStep, boosted)
    end
end

local interval = random():getFloat(0.98, 1.02)
function Factory.getUpdateInterval()

    if onServer() and ReadOnlySector().numPlayers == 0 then
        -- only update every 5 seconds when no players are around to save performance
        return interval + 4
    else
        return interval
    end
end

function Factory.updateParallelSelf(timeStep)
    for i, p in pairs(currentProductions) do

        p.progress = p.progress + timeStep / Factory.timeToProduce
        if p.boosted then p.progress = p.progress + timeStep / Factory.timeToProduce end

        -- print ("progress: " .. p.progress)

        if p.progress >= 1.0 then
            -- production finished
            currentProductions[i] = nil

            if onServer() then
                for i, result in pairs(production.results) do
                    Factory.increaseGoods(result.name, result.amount)
                end

                for i, garbage in pairs(production.garbages) do
                    Factory.increaseGoods(garbage.name, garbage.amount)
                end
            end
        end
    end

    if onServer() then
        -- simulate multiple time steps to start productions correctly while weak updating is active
        if timeStep > 1.1 then
            -- cap the amount of time steps to 20 (which should be plenty) to ensure performance even if a very large timeStep is done (which shouldn't be happening anyway)
            local steps = math.min(20, math.floor(timeStep))

            for i = 1, steps do
                Factory.updateProduction(1)
            end

            -- timestep now contains the rest, will be updated below
            timeStep = timeStep - steps
        end

        Factory.updateProduction(timeStep)
    end
end

-- function Factory.updateParallelRead(timeStep)
    -- print ("parallel update, read")
-- end

function Factory.updateClient(timeStep)
    if EntityIcon().icon == "" then

        local title = Entity().title

        if production then
            if production.factoryStyle == "Mine" then
                EntityIcon().icon = "data/textures/icons/pixel/mine.png"
            elseif production.factoryStyle == "Ranch" then
                EntityIcon().icon = "data/textures/icons/pixel/ranch.png"
            elseif production.factoryStyle == "Farm" then
                EntityIcon().icon = "data/textures/icons/pixel/farm.png"
            else
                EntityIcon().icon = "data/textures/icons/pixel/factory.png"
            end
        end
    end

    Factory.updateStepDone = true
end

function Factory.updateUI()
    if Factory.updateStepDone then
        Factory.updateStepDone = false
        Factory.requestGoods()

        if tabbedWindow:getActiveTab().index == configTab.index then
            Factory.refreshConfigUI()
        end
    end
end

function Factory.updateServer(timeStep)
    Factory.requestTraders(timeStep)

    local sectorTradeInterval = Factory.SectorTradeInterval -- trade with other stations every X seconds
    if Sector():getValue("war_zone") then -- warzone -> trade is massively inhibited
        sectorTradeInterval = 60
    end

    local dockedOnly = true
    Factory.immediateTradeCooldown = Factory.immediateTradeCooldown + timeStep
    if Factory.immediateTradeCooldown >= sectorTradeInterval then
        Factory.immediateTradeCooldown = Factory.immediateTradeCooldown - sectorTradeInterval
        dockedOnly = false
    end

    Factory.updateDeliveryToOtherStations(timeStep, dockedOnly)
    Factory.updateFetchingFromOtherStations(timeStep, dockedOnly)

    Factory.updateOrganizeGoodsBulletins(timeStep)
    Factory.updateDeliveryBulletins(timeStep)

    Factory.sendDeliveryErrors()
    Factory.sendProductionError()
end

function Factory.sendDeliveryErrors()

    if not Owner().isPlayer then return end

    local messages = {}
    local send = false

    for i = 1, 3 do
        local error = deliveredStationsErrors[i]
        local newError = newDeliveredStationsErrors[i]

        if error ~= newError then
            send = true
        end
    end

    deliveredStationsErrors = newDeliveredStationsErrors
    newDeliveredStationsErrors = {}

    for i = 1, 3 do
        local error = deliveringStationsErrors[i]
        local newError = newDeliveringStationsErrors[i]

        if error ~= newError then
            send = true
        end
    end

    deliveringStationsErrors = newDeliveringStationsErrors
    newDeliveringStationsErrors = {}

    if send then
        local player = Player()
        local x, y = Sector():getCoordinates()
        local px, py = Player():getSectorCoordinates()

        if x == px and y == py then
            invokeClientFunction(player, "receiveDeliveryErrors", deliveredStationsErrors, deliveringStationsErrors)
        end
    end

end
callable(Factory, "sendDeliveryErrors")

function Factory.receiveDeliveryErrors(delivered, delivering)
    deliveredStationsErrors = delivered
    deliveringStationsErrors = delivering

    Factory.refreshConfigErrors()
end

function Factory.sendProductionError()

    if not Owner().isPlayer then return end

    local send = false

    if productionError ~= newProductionError then
        send = true
    end

    productionError = newProductionError

    if send and productionError then
        local player = Player()
        local x, y = Sector():getCoordinates()
        local px, py = player:getSectorCoordinates()

        if x == px and y == py then
            invokeClientFunction(Player(), "receiveProductionError", productionError)
        end
    end

end

function Factory.receiveProductionError(error)
    productionError = error or ""

    Factory.refreshConfigErrors()
end

function Factory.updateDeliveryToOtherStations(timeStep, dockedOnly)
    local ids = {}
    for id, trades in pairs(Factory.trader.deliveredStations) do
        if #trades > 0 then
            table.insert(ids, id)
        end
    end

    local sector = Sector()
    local self = Entity()

    shuffle(random(), ids)

    for index, id in pairs(ids) do
        local trades = Factory.trader.deliveredStations[id]
        local trade = randomEntry(random(), trades)

        local station = sector:getEntity(id)
        if not station then
            newDeliveredStationsErrors[index] = "Error with partner station!"%_T
            goto continue
        end

        -- if station isn't docked, only trade every 10 seconds with it
        if dockedOnly then
            if station.dockingParent ~= self.id and self.dockingParent ~= station.id then
                goto continue
            end
        end

        local ownStock = self:getCargoAmount(trade.good)
        if ownStock == 0 then
            newDeliveredStationsErrors[index] = "No more goods!"%_T
            goto continue
        end

        local good = Factory.getSoldGoodByName(trade.good)
        if not good then
            newDeliveredStationsErrors[index] = "Partner station doesn't buy this!"%_T
            goto continue
        end

        local amount = math.max(1, math.floor(Factory.shuttleVolume / good.size))
        amount = math.min(ownStock, amount)

        -- do the transaction
        local errorCode1, errorCode2, price = station:invokeFunction(trade.script, "buyGoods", good, amount, self.factionIndex, true)
        if errorCode1 ~= 0 then
            newDeliveredStationsErrors[index] = "Error with partner station!"%_T
            goto continue
        end

        if errorCode2 ~= 0 then
            newDeliveredStationsErrors[index] = Factory.getBuyGoodsErrorMessage(errorCode2)
            goto continue
        end

        Factory.trader.stats.moneyGainedFromGoods = Factory.trader.stats.moneyGainedFromGoods + price

        station:addCargo(good, amount)

        Factory.decreaseGoods(trade.good, amount)

        break
        ::continue::
    end
end

function Factory.updateFetchingFromOtherStations(timeStep, dockedOnly)
    local sector = Sector()
    local self = Entity()

    local ids = {}
    for id, trades in pairs(Factory.trader.deliveringStations) do
        if #trades > 0 then
            table.insert(ids, id)
        end
    end

    shuffle(random(), ids)

    for index, id in pairs(ids) do
        local trades = Factory.trader.deliveringStations[id]
        local trade = randomEntry(random(), trades)

        local station = Sector():getEntity(id)
        if not station then goto continue end

        -- if station isn't docked, only trade every 10 seconds with it
        if dockedOnly then
            if station.dockingParent ~= self.id and self.dockingParent ~= station.id then
                goto continue
            end
        end

        local errorCode, otherStock, maxAmount = station:invokeFunction(trade.script, "getStock", trade.good)
        if errorCode ~= 0 then
            newDeliveringStationsErrors[index] = "Error with partner station!"%_T
            print ("error requesting goods from other station: " .. errorCode .. " " .. station.title)
            goto continue
        end

        if otherStock == 0 then
            newDeliveringStationsErrors[index] = "No more goods on partner station!"%_T
            goto continue
        end

        local ownStock, maxAmount = Factory.getStock(trade.good)
        if ownStock >= maxAmount then
            newDeliveringStationsErrors[index] = "Station at full capacity!"%_T
            goto continue
        end

        local good = goods[trade.good]:good()
        if not good then return end

        if self.freeCargoSpace < good.size then
            newDeliveringStationsErrors[index] = "Station at full capacity!"%_T
            goto continue
        end

        local amount = math.max(1, math.floor(Factory.shuttleVolume / good.size))
        amount = math.min(amount, otherStock)

        local error1, error2, price = station:invokeFunction(trade.script, "sellGoods", good, amount, self.factionIndex)
        if error1 ~= 0 then
            newDeliveringStationsErrors[index] = "Error with partner station!"%_T
            goto continue
        end

        if error2 ~= 0 then
            newDeliveringStationsErrors[index] = Factory.getSellGoodsErrorMessage(error2)
            goto continue
        end

        Factory.trader.stats.moneySpentOnGoods = Factory.trader.stats.moneySpentOnGoods + price

        self:addCargo(good, amount)

        break
        ::continue::
    end
end

function Factory.onBlockPlanChanged(entityId, allBlocks)
    Factory.productionCapacity = Plan():getStats().productionCapacity * Factory.PlanCapacityFactor
    Factory.productionCapacity = math.max(Factory.MinimumCapacity, Factory.productionCapacity)

    Factory.refreshProductionTime()
end

function Factory.refreshProductionTime()
    if not production then return end

    local value = 0
    local averageLevel = 0
    local samples = 0
    for _, result in pairs(production.results) do
        local good = goods[result.name]
        if good then
            value = value + good.price * result.amount
            averageLevel = averageLevel + (good.level or 0)
            samples = samples + 1
        end
    end

    if production.garbages then
        for i, garbage in pairs(production.garbages) do
            local good = goods[garbage.name]
            if good then
                value = value + good.price * garbage.amount
                averageLevel = averageLevel + (good.level or 0)
                samples = samples + 1
            end
        end
    end

    if samples > 0 then
        averageLevel = averageLevel / samples
    end
    local levelSpeedup = 1 + averageLevel / 100

    Factory.timeToProduce = math.max(Factory.MinimumTimeToProduce, value / Factory.productionCapacity / levelSpeedup)
end

function Factory.requestProductionStats()
    invokeServerFunction("sendProductionStats")
end

function Factory.sendProductionStats()
    invokeClientFunction(Player(callingPlayer), "receiveProductionStats", Factory.timeToProduce)
end
callable(Factory, "sendProductionStats")

function Factory.receiveProductionStats(timeToProduce)
    Factory.timeToProduce = timeToProduce
end

function Factory.requestTraders(timeStep)
    Factory.traderRequestCooldown = Factory.traderRequestCooldown - timeStep
    if Factory.traderRequestCooldown > 0 then
        -- print ("cooldown: " .. Factory.traderRequestCooldown)
        return
    end

    Factory.traderRequestCooldown = 90

    local sector = Sector()
    if sector:getValue("war_zone") then
        -- print ("war zone")
        return
    end

    -- if the result isn't there yet, can't call for new goods or buyers
    if not production then
        -- print ("no productions")
        return
    end

    local self = Entity()
    if TradingUtility.hasTraders(self) then
        -- print ("has traders")
        return
    end

    local immediate = (sector.numPlayers == 0)

    -- we only have to check buy price factor since sell price factor is directly coupled to buy price factor
    -- high prices for goods make it more likely for sellers to show up since they earn more money
    -- low prices for goods make it more likely for buyers to show up since they can save money here
    local pSeller = Factory.getSellerProbability()
    local seller = random():test(pSeller)

    -- call for buyers first
    -- this decreases the time until the factory generates profit
    if not seller and Factory.trader.activelySell then
        for _, result in pairs(production.results) do
            if Factory.trySpawnBuyer(self, result, immediate) then return end
        end
    end

    -- then call for ingredients
    if seller and Factory.trader.activelyRequest then
        for _, ingredient in pairs(production.ingredients) do
            if Factory.trySpawnSeller(self, ingredient, immediate) then return end
        end
    end

    -- then call for garbages
    if not seller and Factory.trader.activelySell then
        for _, garbage in pairs(production.garbages) do
            if Factory.trySpawnBuyer(self, garbage, immediate) then return end
        end
    end

end

function Factory.getShuttleUpgradeCost()
    local stage = (Factory.shuttleVolume - 20) / 5 + 1
    local price = getFactoryUpgradeCost(production, stage) / 10
    return price
end

function Factory.getSellerProbability()
    local pSeller = lerp(Factory.trader.buyPriceFactor, 0.8, 1.2, 0.1, 0.9)
    return pSeller
end

function Factory.trySpawnSeller(self, good, immediate)
    local have = Factory.getNumGoods(good.name)
    if have < good.amount then
        local maximum = Factory.getMaxGoods(good.name)

        maximum = math.min(maximum, 500)

        local amount = maximum - have
        if immediate then amount = round(amount * 0.3) end

        TradingUtility.spawnSeller(self.id, getScriptPath(), good.name, amount, Factory, immediate)
        return true
    end
end

function Factory.trySpawnBuyer(self, good, immediate)
    if not goods[good.name] then return end

    local newAmount = Factory.getNumGoods(good.name) + good.amount
    local maxGoods = Factory.getMaxGoods(good.name)

    local value = newAmount * goods[good.name].price

    -- print("newAmount: " .. newAmount .. ", maxGoods: " .. maxGoods .. ", value: " .. value)

    -- spawn a trader when stocks are almost full, or when the value of the produced stocks exceeds 100.000k
    if newAmount > maxGoods * 0.8 or (value > 100 * 1000 and random():test(0.3)) then
        TradingUtility.spawnBuyer(self.id, getScriptPath(), good.name, Factory, immediate)
        return true
    end
end

function Factory.updateProduction(timeStep)
    -- if the result isn't there yet, don't produce
    if not production then return end

    -- if not yet fully used, start producing
    local numProductions = tablelength(currentProductions)
    local canProduce = true

    if numProductions >= Factory.maxNumProductions then
        canProduce = false
        -- print("can't produce as there are no more slots free for production")
    end

    if MinimumPopulation and not MinimumPopulation.isFulfilled() then
        canProduce = false
        -- print("can't produce as min pop isn't fulfilled")
    end

    -- only start if there are actually enough ingredients for producing
    for i, ingredient in pairs(production.ingredients) do
        if ingredient.optional == 0 and Factory.getNumGoods(ingredient.name) < ingredient.amount then
            canProduce = false
            newProductionError = "Factory can't produce because ingredients are missing!"%_T
            -- print("can't produce due to missing ingredients: " .. ingredient.amount .. " " .. ingredient.name .. ", have: " .. Factory.getNumGoods(ingredient.name))
            break
        end
    end

    local station = Entity()
    for i, garbage in pairs(production.garbages) do
        local newAmount = Factory.getNumGoods(garbage.name) + garbage.amount
        local size = Factory.getGoodSize(garbage.name)

        if newAmount > Factory.getMaxStock({name = garbage.name, size = size}) or station.freeCargoSpace < garbage.amount * size then
            canProduce = false
            newProductionError = "Factory can't produce because there is not enough cargo space for products!"%_T
            -- print("can't produce due to missing room for garbage")
            break
        end
    end

    for _, result in pairs(production.results) do
        local newAmount = Factory.getNumGoods(result.name) + result.amount
        local size = Factory.getGoodSize(result.name)

        if newAmount > Factory.getMaxStock({name = result.name, size = size}) or station.freeCargoSpace < result.amount * size then
            canProduce = false
            newProductionError = "Factory can't produce because there is not enough cargo space for products!"%_T
            -- print("can't produce due to missing room for result")
            break
        end
    end

    if canProduce then
        local boosted
        for i, ingredient in pairs(production.ingredients) do
            local removed = Factory.decreaseGoods(ingredient.name, ingredient.amount)

            if ingredient.optional == 1 and removed then
                boosted = true
            end
        end

        newProductionError = ""
        -- print("start production")

        -- start production
        Factory.startProduction(timeStep, boosted)
    end

end

function Factory.getBuysFromOthers()
    return Factory.trader.buyFromOthers
end

function Factory.getSellsToOthers()
    return Factory.trader.sellToOthers
end

function Factory.getProduction()
    return production
end


return Factory
