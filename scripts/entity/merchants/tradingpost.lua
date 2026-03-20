package.path = package.path .. ";data/scripts/lib/?.lua"
include ("randomext")
include ("galaxy")
include ("faction")
include ("utility")
include ("stringutility")
include ("callable")
local FactoryMap = include ("factorymap")
local TradingAPI = include ("tradingmanager")
local Dialog = include("dialogutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace TradingPost
TradingPost = {}
TradingPost = TradingAPI:CreateNamespace()
TradingPost.trader.tax = 0.0
TradingPost.trader.factionPaymentFactor = 1.0
TradingPost.trader.relationsThreshold = -30000
TradingPost.trader.supplyDemandInfluence = 0.5
TradingPost.trader.stockInfluence = 0.25
TradingPost.trader.minimumCargoBay = 100000


function TradingPost.getUpdateInterval()
    return 5
end


-- if this function returns false, the script will not be listed in the interaction window on the client,
-- even though its UI may be registered
function TradingPost.interactionPossible(playerIndex, option)
    if Player(playerIndex).craftIndex == Entity().index then return false end

    return CheckFactionInteraction(playerIndex, TradingPost.trader.relationsThreshold)
end

function TradingPost.restore(data)
    TradingPost.restoreTradingGoods(data)

    TradingPost.buyingConfigured = data.buyingConfigured
    if not TradingPost.buyingConfigured then
        local entity = Entity()
        if entity.playerOwned or entity.allianceOwned then
            TradingPost.trader.buyFromOthers = false
        end
    end

    TradingPost.trader.stockInfluence = 0.25
end

function TradingPost.secure()
    local values = TradingPost.secureTradingGoods()

    values.buyingConfigured = TradingPost.buyingConfigured

    return values
end

function TradingPost.updateServer(timeStep)
    TradingPost.useUpBoughtGoods(timeStep)

    TradingPost.updateOrganizeGoodsBulletins(timeStep)
    TradingPost.updateDeliveryBulletins(timeStep)
end

-- this function gets called on creation of the entity the script is attached to, on client and server
function TradingPost.initialize()

    local station = Entity()
    if station.title == "" then
        station.title = "Trading Post"%_t
    end

    if onServer() then
        Sector():addScriptOnce("sector/traders.lua")

        -- for large stations it's possible that the generator sacrifices cargo bay for generators etc.
        local cargoBay = CargoBay()
        if TradingPost.trader.minimumCargoBay and station.aiOwned then
            if cargoBay.cargoHold < TradingPost.trader.minimumCargoBay then
                cargoBay.fixedSize = true
                cargoBay.cargoHold = TradingPost.trader.minimumCargoBay
            end
        else
            cargoBay.fixedSize = false
        end

        local faction = Faction()
        if not _restoring then
            math.randomseed(Sector().seed + Sector().numEntities);

            -- make lists of all items that will be sold/bought
            local bought, sold = TradingPost.generateGoods()

            TradingPost.trader.buyPriceFactor = math.random() * 0.2 + 0.9 -- 0.9 to 1.1
            -- ensure that price for selling is higher than price for buying (so the station makes a profit and player's can't just buy & sell as much as they want)
            TradingPost.trader.sellPriceFactor = TradingPost.trader.buyPriceFactor + 0.2

            TradingPost.initializeTrading(bought, sold)

            if faction and (faction.isAlliance or faction.isPlayer) then
                TradingPost.trader.buyFromOthers = false
            end

            math.randomseed(appTimeMs())
        end

        if faction and faction.isAIFaction then
            Sector():registerCallback("onRestoredFromDisk", "onRestoredFromDisk")
        end

    else
        TradingPost.requestGoods()

        if EntityIcon().icon == "" then
            EntityIcon().icon = "data/textures/icons/pixel/trade.png"
            InteractionText(station.index).text = Dialog.generateStationInteractionText(station, random())
        end

    end

    station:addScriptOnce("data/scripts/entity/merchants/cargotransportlicensemerchant.lua")
end

function TradingPost.trader:getInitialGoods(boughtGoodsIn, soldGoodsIn)
    local resourceAmount = math.random(1, 5)

    local boughtStockByGood = {}

    for _, v in ipairs(boughtGoodsIn) do
        local maxStock = self:getMaxStock(v)
        if maxStock > 0 then

            local amount
            if resourceAmount == 1 then
                -- station has few resources available
                amount = math.random(0, maxStock * 0.15)
            else
                -- normal amount of resources available
                amount = math.random(maxStock * 0.1, maxStock * 0.5)
            end

            -- limit by value
            local maxValue = 300 * 1000 * Balancing_GetSectorRichnessFactor(Sector():getCoordinates())
            amount = math.min(amount, math.floor(maxValue / v.price))

            boughtStockByGood[v] = amount
        end
    end

    return boughtStockByGood, boughtStockByGood
end

function TradingPost.onRestoredFromDisk(timeSinceLastSimulation)
    TradingPost.simulatePassedTime(timeSinceLastSimulation)
end

-- this function gets called on creation of the entity the script is attached to, on client only
-- AFTER initialize above
-- create all required UI elements for the client side
function TradingPost.initUI()
    local station = Entity()
    local tabbedWindow = TradingAPI.CreateTabbedWindow(station.translatedTitle)

    -- create buy tab
    local buyTab = tabbedWindow:createTab("Buy"%_t, "data/textures/icons/bag.png", "Buy from station"%_t)
    TradingPost.buildBuyGui(buyTab)

    -- create sell tab
    local sellTab = tabbedWindow:createTab("Sell"%_t, "data/textures/icons/sell.png", "Sell to station"%_t)
    TradingPost.buildSellGui(sellTab)

    TradingPost.toggleBuyButton = sellTab:createButton(Rect(sellTab.size.x - 30, -5, sellTab.size.x, 25), "", "onToggleBuyPressed")
    TradingPost.toggleBuyButton.icon = "data/textures/icons/sell.png"

    TradingPost.trader.guiInitialized = true

    TradingPost.requestGoods()
end

function TradingPost.initializationFinished()
    -- use the initilizationFinished() function on the client since in initialize() we may not be able to access Sector scripts on the client
    if onClient() then
        local ok, r = Sector():invokeFunction("radiochatter", "addSpecificLines", Entity().id.string,
        {
            "Occupy cash register ${N3} please."%_t,
            "Special offers for all residents, only today!"%_t,
            "${R} still needs the forms for our last shipment."%_t,
            "Nobody likes smugglers. Get your cargo transport licenses here!"%_t,
            "Careful with those dangerous goods! Get a transport license here!"%_t,
            "Trade your goods here! We offer a vastly better choice than any factory!"%_t,
        })
    end
end

function TradingPost.generateGoods(x, y)

    if not x or not y then
        x, y = Sector():getCoordinates()
    end

    local map = FactoryMap()
    local supply, demand, sum = map:getSupplyAndDemand(x, y)

    local accumulated = {}

    for good, value in pairs(supply) do
        accumulated[good] = value
    end
    for good, value in pairs(demand) do
        accumulated[good] = (accumulated[good] or 0) + value
    end

    local existingGoods = {}
    local bought = {}
    local sold = {}

    local byWeight = {}
    for good, value in pairs(accumulated) do
        byWeight[good] = value + 10
    end

    for i = 1, 15 do
        local good = selectByWeight(byWeight)

        if good and not existingGoods[good] then
            bought[#bought + 1] = goods[good]:good()
            sold[#sold + 1] = goods[good]:good()

            existingGoods[good] = true
        end
    end

    return bought, sold
end

function TradingPost.onShowWindow()
    TradingPost.requestGoods()

    local faction = Faction()
    local player = Player()

    if player.index == faction.index or player.allianceIndex == faction.index then
        invokeServerFunction("sendConfig")
        TradingPost.toggleBuyButton:show()
    else
        TradingPost.toggleBuyButton:hide()
    end
end

function TradingPost.onToggleBuyPressed()
    TradingPost.sendConfig()
end

function TradingPost.refreshConfigUI()
    if TradingPost.trader.buyFromOthers then
        TradingPost.toggleBuyButton.icon = "data/textures/icons/sell-enabled.png"
        TradingPost.toggleBuyButton.tooltip = "This station buys goods from traders to resell them."%_t
    else
        TradingPost.toggleBuyButton.icon = "data/textures/icons/sell-disabled.png"
        TradingPost.toggleBuyButton.tooltip = "This station doesn't buy goods from traders to resell them."%_t
    end
end


function TradingPost.sendConfig()
    local config = {}
    if onClient() then
        -- read new config from ui elements
        config.buyFromOthers = not TradingPost.trader.buyFromOthers

        invokeServerFunction("setConfig", config)
    else
        -- read config from factory settings
        config.buyFromOthers = TradingPost.trader.buyFromOthers

        invokeClientFunction(Player(callingPlayer), "setConfig", config)
    end
end
callable(TradingPost, "sendConfig")

function TradingPost.setConfig(config)
    if onClient() then
        -- apply config to UI elements
        TradingPost.trader.buyFromOthers = config.buyFromOthers

        if TradingAPI.window.visible then
            TradingPost.refreshConfigUI()
        end
    else
        if not config then return end

        -- apply config to factory settings
        local owner, station, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations)
        if not owner then return end

        TradingPost.trader.buyFromOthers = config.buyFromOthers
        TradingPost.buyingConfigured = true

        TradingPost.sendConfig()
    end
end
callable(TradingPost, "setConfig")







