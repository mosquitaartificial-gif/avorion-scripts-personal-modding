package.path = package.path .. ";data/scripts/lib/?.lua"
include ("randomext")
include ("galaxy")
include ("faction")
include ("utility")
include ("stringutility")
local TradingAPI = include ("tradingmanager")
local Dialog = include("dialogutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace PlanetaryTradingPost
PlanetaryTradingPost = {}
PlanetaryTradingPost = TradingAPI:CreateNamespace()

PlanetaryTradingPost.trader.relationsThreshold = -45000

-- if this function returns false, the script will not be listed in the interaction window on the client,
-- even though its UI may be registered
function PlanetaryTradingPost.interactionPossible(playerIndex, option)
    if Player(playerIndex).craftIndex == Entity().index then return false end

    return CheckFactionInteraction(playerIndex, -45000)
end

function PlanetaryTradingPost.restore(data)
    PlanetaryTradingPost.restoreTradingGoods(data)
end

function PlanetaryTradingPost.secure()
    return PlanetaryTradingPost.secureTradingGoods()
end

-- this function gets called on creation of the entity the script is attached to, on client and server
function PlanetaryTradingPost.initialize(planet)

    local station = Entity()
    if station.title == "" then
        station.title = "Planetary Trading Post"%_t
    end

    if onServer() then
        Sector():addScriptOnce("sector/traders.lua")

        if planet then
            math.randomseed(Sector().seed + Sector().numEntities);

            -- make lists of all items that will be sold/bought
            local bought, sold = PlanetaryTradingPost.generatePlanetGoods(planet, 13, 15) -- generate both at the same time, this won't create duplicates

            PlanetaryTradingPost.trader.buyPriceFactor = math.random() * 0.2 + 0.9 -- 0.9 to 1.1
            PlanetaryTradingPost.trader.sellPriceFactor = math.random() * 0.2 + 0.9 -- 0.9 to 1.1

            Entity():setValue("goods_generated", nil)
            PlanetaryTradingPost.initializeTrading(bought, sold)

            if Faction().isAIFaction then
                Sector():registerCallback("onRestoredFromDisk", "onRestoredFromDisk")
            end

            math.randomseed(appTimeMs())
        end

    else
        PlanetaryTradingPost.requestGoods()

        if EntityIcon().icon == "" then
            EntityIcon().icon = "data/textures/icons/pixel/trade.png"
            InteractionText(station.index).text = Dialog.generateStationInteractionText(station, random())
        end

    end

    station:addScriptOnce("data/scripts/entity/merchants/cargotransportlicensemerchant.lua")
end

function PlanetaryTradingPost.onRestoredFromDisk(timeSinceLastSimulation)
    PlanetaryTradingPost.simulatePassedTime(timeSinceLastSimulation)
end

-- this function gets called on creation of the entity the script is attached to, on client only
-- AFTER initialize above
-- create all required UI elements for the client side
function PlanetaryTradingPost.initUI()
    local station = Entity()
    local tabbedWindow = TradingAPI.CreateTabbedWindow(station.translatedTitle)

    -- create buy tab
    local buyTab = tabbedWindow:createTab("Buy"%_t, "data/textures/icons/bag.png", "Buy from station"%_t)
    PlanetaryTradingPost.buildBuyGui(buyTab)

    -- create sell tab
    local sellTab = tabbedWindow:createTab("Sell"%_t, "data/textures/icons/sell.png", "Sell to station"%_t)
    PlanetaryTradingPost.buildSellGui(sellTab)

    PlanetaryTradingPost.trader.guiInitialized = true

    PlanetaryTradingPost.requestGoods()
end

-- this functions gets called when the indicator of the station is rendered on the client
--function renderUIIndicator(px, py, size)
--
--end
--
---- this function gets called every time the window is shown on the client, ie. when a player presses F and if interactionPossible() returned 1
function PlanetaryTradingPost.onShowWindow()
    PlanetaryTradingPost.requestGoods()
end
--
---- this function gets called every time the window is closed on the client
--function onCloseWindow()
--
--end
--
---- this function gets called each tick, on client and server
--function update(timeStep)
--
--end
--
---- this function gets called each tick, on client only
--function updateClient(timeStep)
--
--end

function PlanetaryTradingPost.getUpdateInterval()
    return 5
end

---- this function gets called each tick, on server only
function updateServer(timeStep)
    PlanetaryTradingPost.useUpBoughtGoods(timeStep)

    PlanetaryTradingPost.updateOrganizeGoodsBulletins(timeStep)
    PlanetaryTradingPost.updateDeliveryBulletins(timeStep)
end
--
---- this function gets called whenever the ui window gets rendered, AFTER the window was rendered (client only)
--function renderUI()
--
--end

function PlanetaryTradingPost.generatePlanetGoods(planet)
    local planetType = planet.type
    local bought = {}
    local sold = {}
    local existingGoods = {}

    local planetaryGoods = {}
    -- get goods that match the planet type
    if planetType == PlanetType.Terrestrial then
        table.insert(sold, goods["Beer"]:good())
        table.insert(sold, goods["Bio Gas"]:good())
        table.insert(sold, goods["Coal"]:good())
        table.insert(sold, goods["Cattle"]:good())
        table.insert(sold, goods["Clothes"]:good())
        table.insert(sold, goods["Coffee"]:good())
        table.insert(sold, goods["Dairy"]:good())
        table.insert(sold, goods["Oil"]:good())
        table.insert(sold, goods["Ore"]:good())
        table.insert(sold, goods["Potato"]:good())
        table.insert(sold, goods["Rice"]:good())
        table.insert(sold, goods["Sheep"]:good())
        table.insert(sold, goods["Spices"]:good())
        table.insert(sold, goods["Wood"]:good())

        table.insert(bought, goods["Chemicals"]:good())
        table.insert(bought, goods["Drill"]:good())
        table.insert(bought, goods["Drone"]:good())
        table.insert(bought, goods["Energy Cell"]:good())
        table.insert(bought, goods["Energy Generator"]:good())
        table.insert(bought, goods["Fabric"]:good())
        table.insert(bought, goods["Satellite"]:good())
        table.insert(bought, goods["Solar Panel"]:good())
        table.insert(bought, goods["Turbine"]:good())

    elseif planetType == PlanetType.Rocky or planetType == PlanetType.Moon then
        table.insert(sold, goods["Carbon"]:good())
        table.insert(sold, goods["Copper"]:good())
        table.insert(sold, goods["Gem"]:good())
        table.insert(sold, goods["Gold"]:good())
        table.insert(sold, goods["Lead"]:good())
        table.insert(sold, goods["Mineral"]:good())
        table.insert(sold, goods["Ore"]:good())
        table.insert(sold, goods["Raw Oil"]:good())
        table.insert(sold, goods["Silicon"]:good())

        table.insert(bought, goods["Drill"]:good())
        table.insert(bought, goods["Drone"]:good())
        table.insert(bought, goods["Energy Cell"]:good())
        table.insert(bought, goods["Energy Generator"]:good())
        table.insert(bought, goods["Explosive Charge"]:good())
        table.insert(bought, goods["Fuel"]:good())
        table.insert(bought, goods["Mining Robot"]:good())
        table.insert(bought, goods["Solar Panel"]:good())
        table.insert(bought, goods["Tools"]:good())

    elseif planetType == PlanetType.GasGiant then
        table.insert(sold, goods["Helium"]:good())
        table.insert(sold, goods["Hydrogen"]:good())
        table.insert(sold, goods["Oxygen"]:good())
        table.insert(sold, goods["Carbon"]:good())

        table.insert(bought, goods["Drone"]:good())
        table.insert(bought, goods["Energy Cell"]:good())
        table.insert(bought, goods["Energy Generator"]:good())
        table.insert(bought, goods["Mining Robot"]:good())
        table.insert(bought, goods["High Pressure Tube"]:good())
        table.insert(bought, goods["Solar Panel"]:good())
        table.insert(bought, goods["Steel Tube"]:good())
        table.insert(bought, goods["Turbine"]:good())

    elseif planetType == PlanetType.Smooth then
        table.insert(sold, goods["Oxygen"]:good())
        table.insert(sold, goods["Carbon"]:good())
        table.insert(sold, goods["Neon"]:good())
        table.insert(sold, goods["Nitrogen"]:good())

        table.insert(bought, goods["Drone"]:good())
        table.insert(bought, goods["Energy Cell"]:good())
        table.insert(bought, goods["Energy Generator"]:good())
        table.insert(bought, goods["Mining Robot"]:good())
        table.insert(bought, goods["High Pressure Tube"]:good())
        table.insert(bought, goods["Solar Panel"]:good())
        table.insert(bought, goods["Steel Tube"]:good())
        table.insert(bought, goods["Turbine"]:good())

    elseif planetType == PlanetType.Volcanic then
        table.insert(sold, goods["Bio Gas"]:good())
        table.insert(sold, goods["Carbon"]:good())
        table.insert(sold, goods["Coal"]:good())
        table.insert(sold, goods["Mineral"]:good())
        table.insert(sold, goods["Oil"]:good())
        table.insert(sold, goods["Ore"]:good())
        table.insert(sold, goods["Raw Oil"]:good())

        table.insert(bought, goods["Drone"]:good())
        table.insert(bought, goods["Energy Cell"]:good())
        table.insert(bought, goods["Energy Generator"]:good())
        table.insert(bought, goods["Explosive Charge"]:good())
        table.insert(bought, goods["Fuel"]:good())
        table.insert(bought, goods["Mining Robot"]:good())
        table.insert(bought, goods["Solar Panel"]:good())
        table.insert(bought, goods["Tools"]:good())

    elseif planetType == PlanetType.BlackHole then
    end

    return bought, sold
end
