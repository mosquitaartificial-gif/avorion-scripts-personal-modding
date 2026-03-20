package.path = package.path .. ";data/scripts/lib/?.lua"
include ("galaxy")
include ("randomext")
include ("utility")
include ("faction")
include ("callable")
include ("stringutility")
local FactoryMap = include ("factorymap")
local TradingAPI = include ("tradingmanager")
local Dialog = include("dialogutility")

local window

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Seller
Seller = {}
Seller = TradingAPI:CreateNamespace()

Seller.customSellPriceFactor = nil -- set this to override the sell price factor
Seller.sellerName = ""
Seller.sellerIcon = ""
Seller.soldGoods = {}
Seller.trader.relationsThreshold = -30000

function Seller.interactionPossible(playerIndex, option)
    if Player(playerIndex).craftIndex == Entity().index then return false end

    return CheckFactionInteraction(playerIndex, -30000)
end

function Seller.restore(values)
    local originallySold = Seller.soldGoods

    Seller.restoreTradingGoods(values)
    Seller.sellerName = values.sellerName
    Seller.soldGoods = values.sellableGoods or Seller.soldGoods

    if type(Seller.soldGoods) ~= "table" or #Seller.soldGoods == 0 then
        Seller.soldGoods = {Seller.getSoldGoods()}
    end

    local broken = (#{Seller.getSoldGoods()} == 0)
    for _, good in pairs({Seller.getSoldGoods()}) do
        if good == "nil" then
            broken = true
            break
        end
    end

    if broken and #Seller.soldGoods > 0 then
        local sold = {}

        for i, name in pairs(originallySold) do
            local g = goods[name]
            table.insert(sold, g:good())
        end

        Seller.initializeTrading({}, sold)
    end

    Seller.updateOwnSupply()
end

function Seller.secure()
    local values = Seller.secureTradingGoods()
    values.sellerName = Seller.sellerName
    values.sellableGoods = Seller.soldGoods -- values.soldGoods collides with a variable from TradingManager, don't use!

    return values
end

function Seller.initialize(name_in, ...)

    local entity = Entity()

    if onServer() then
        Sector():addScriptOnce("sector/traders.lua")

        Seller.sellerName = name_in or Seller.sellerName

        -- only use parameter goods if there are any, otherwise we prefer the goods we might already have in soldGoods
        local sellableGoods_in = {...}
        if #sellableGoods_in > 0 then
            Seller.soldGoods = sellableGoods_in
            Seller.updateOwnSupply()
        end

        local station = Entity()

        -- add the name as title
        if Seller.sellerName ~= "" and entity.title == "" then
            entity.title = Seller.sellerName
        end

        local seed = Sector().seed + Sector().numEntities
        math.randomseed(seed);

        -- sellers only sell
        Seller.trader.sellPriceFactor = Seller.customSellPriceFactor or math.random() * 0.2 + 0.9 -- 0.9 to 1.1

        local sold = {}

        for i, name in pairs(Seller.soldGoods) do
            local g = goods[name]
            table.insert(sold, g:good())
        end

        Seller.initializeTrading({}, sold)

        local faction = Faction()
        if valid(faction) and faction.isAIFaction then
            Sector():registerCallback("onRestoredFromDisk", "onRestoredFromDisk")
        end

        math.randomseed(appTimeMs())
    else
        Seller.requestGoods()

        if Seller.sellerIcon ~= "" and EntityIcon().icon == "" then
            EntityIcon().icon = Seller.sellerIcon
            InteractionText().text = Dialog.generateStationInteractionText(entity, random())
        end
    end

end

function Seller.onRestoredFromDisk(timeSinceLastSimulation)
    Seller.simulatePassedTime(timeSinceLastSimulation)
end

-- create all required UI elements for the client side
function Seller.initUI()

    local tabbedWindow = TradingAPI.CreateTabbedWindow()

    -- create buy tab
    local buyTab = tabbedWindow:createTab("Buy"%_t, "data/textures/icons/bag.png", "Buy from station"%_t)
    Seller.buildBuyGui(buyTab)

    -- create sell tab
    local sellTab = tabbedWindow:createTab("Sell"%_t, "data/textures/icons/sell.png", "Sell to station"%_t)
    Seller.buildSellGui(sellTab)

    tabbedWindow:deactivateTab(sellTab)

    Seller.trader.guiInitialized = 1

    invokeServerFunction("sendName")
    Seller.requestGoods()

end

function Seller.sendName()
    invokeClientFunction(Player(callingPlayer), "receiveName", Seller.sellerName)
end
callable(Seller, "sendName")

function Seller.receiveName(name)
    if TradingAPI.window.caption ~= "" and name ~= "" then
        TradingAPI.window.caption = name%_t
    end
end

function Seller.updateOwnSupply()
    local factoryMap = FactoryMap()

    for _, name in pairs(Seller.soldGoods) do
        Seller.trader.ownSupplyTypes[name] = factoryMap.SupplyType.Seller
    end
end

function Seller.onShowWindow()
    Seller.requestGoods()
end

function Seller.getUpdateInterval()
    return 5
end

function Seller.getSellableGoods() -- "getSoldGoods" collides with a function from TradingManager, don't use!
    return Seller.soldGoods
end

function Seller.updateServer(timeStep)
    Seller.useUpBoughtGoods(timeStep)
    Seller.updateOrganizeGoodsBulletins(timeStep)
end

return Seller
