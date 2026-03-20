package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
package.path = package.path .. ";?"

include ("utility")
include ("randomext")
include ("goods")
include ("galaxy")
local AsyncShipGenerator = include("asyncshipgenerator")

local TradingUtility = {}

local scripts =
{
    "/consumer.lua",
    "/seller.lua",
    "/turretfactoryseller.lua",
    "/turretfactorysupplier.lua",
    "/factory.lua",
    "/tradingpost.lua",
    "/planetarytradingpost.lua",
    "/casino.lua",
    "/habitat.lua",
    "/biotope.lua"
}

local TradeType = makeReadOnlyTable(
{
    SellToStation = 0,
    BuyFromStation = 1,
})

TradingUtility.TradeType = TradeType

function TradingUtility.getTradeableScripts()
    return scripts
end

function TradingUtility.isScriptAConsumer(script)
    if script == "/casino.lua"
            or script == "/biotope.lua"
            or script == "/habitat.lua"
            or script == "/consumer.lua" then
        return true
    end

    return false
end

function TradingUtility.getBuysFromOthers(station, script)
    local error, buys = station:invokeFunction(script, "getBuysFromOthers")
    return buys
end

function TradingUtility.getSellsToOthers(station, script)
    local error, sells = station:invokeFunction(script, "getSellsToOthers")
    return sells
end

function TradingUtility.hasTraders(station)
    -- check if there are traders flying to this station
    local traders = {Sector():getEntitiesByScript("merchants/tradeship.lua")}

    for _, trader in pairs(traders) do
        local partner = trader:getValue("trade_partner")

        if partner and station.index.string == partner then
            return true
        end
    end

    return false
end

function TradingUtility.getEntityBuysGood(entity, name)
    local scripts = TradingUtility.getTradeableScripts()
    for _, script in pairs(scripts) do
        local callOk, good = entity:invokeFunction(script, "getBoughtGoodByName", name)
        if callOk == 0 and good then
            return script
        end
    end
end

function TradingUtility.getEntitySellsGood(entity, name)
    local scripts = TradingUtility.getTradeableScripts()
    for _, script in pairs(scripts) do
        local callOk, good = entity:invokeFunction(script, "getSoldGoodByName", name)
        if callOk == 0 and good then
            return script
        end
    end
end

function TradingUtility.getBuyableAndSellableGoods(station, sellable, buyable, faction)
    sellable = sellable or {}
    buyable = buyable or {}

    local faction = faction or Faction()
    if faction then
        local scripts = TradingUtility.getTradeableScripts()
        for _, script in pairs(scripts) do

            local results = {station:invokeFunction(script, "getBoughtGoods")}
            local callResult = results[1]

            if callResult == 0 then -- call was successful, the station buys goods

                for i = 2, #results do
                    local name = results[i];

                    local callOk, good = station:invokeFunction(script, "getGoodByName", name)
                    if callOk ~= 0 then print("getGoodByName failed: " .. callOk) end

                    local callOk, stock, maxStock = station:invokeFunction(script, "getStock", name)
                    if callOk ~= 0 then print("getStock failed" .. callOk) end

                    local callOk, price = station:invokeFunction(script, "getBuyPrice", name, faction.index)
                    if callOk ~= 0 then print("getBuyPrice failed" .. callOk) end

                    if maxStock > 0 then
                        table.insert(sellable, {
                            good = good,
                            price = price,
                            stock = stock,
                            maxStock = maxStock,
                            station = station.title,
                            titleArgs = station:getTitleArguments(),
                            owner = station.factionIndex,
                            stationIndex = station.index,
                            script = script,
                            coords = vec2(Sector():getCoordinates())
                        })
                    end
                end
            else
                -- print("getBoughtGoods failed " .. callResult)
            end

            local results = {station:invokeFunction(script, "getSoldGoods")}
            local callResult = results[1]

            if callResult == 0 then -- call was successful, the station sells goods

                for i = 2, #results do
                    local name = results[i];

                    local callOk, good = station:invokeFunction(script, "getGoodByName", name)
                    if callOk ~= 0 then print("getGoodByName failed: " .. callOk) end

                    local callOk, stock, maxStock = station:invokeFunction(script, "getStock", name)
                    if callOk ~= 0 then print("getStock failed" .. callOk) end

                    local callOk, price = station:invokeFunction(script, "getSellPrice", name, faction.index)
                    if callOk ~= 0 then print("getSellPrice failed" .. callOk) end

                    if maxStock > 0 then
                        table.insert(buyable, {
                            good = good,
                            price = price,
                            stock = stock,
                            maxStock = maxStock,
                            station = station.title,
                            titleArgs = station:getTitleArguments(),
                            owner = station.factionIndex,
                            stationIndex = station.index,
                            script = script,
                            coords = vec2(Sector():getCoordinates())
                        })
                    end
                end
            else
                -- print("getSoldGoods failed " .. callResult)
            end
        end
    end

    return sellable, buyable
end

function TradingUtility.detectBuyableAndSellableGoods(sellable, buyable)
    sellable = sellable or {}
    buyable = buyable or {}

    local entities = {Sector():getEntitiesByType(EntityType.Station)}
    for _, entity in pairs({Sector():getEntitiesByType(EntityType.Ship)}) do
        table.insert(entities, entity)
    end

    for _, station in pairs(entities) do
        TradingUtility.getBuyableAndSellableGoods(station, sellable, buyable)
    end

    return sellable, buyable
end

function TradingUtility.spawnSeller(stationIndex, script, goodName, amount, namespace, immediateTransaction)
    local station = Entity(stationIndex)
    if not station then return end

    -- print ("spawn seller")

    local trade = {tradeType = TradeType.SellToStation, station = station, script = script, name = goodName, amount = amount}
    TradingUtility.spawnTrader(trade, namespace, immediateTransaction)
end

function TradingUtility.spawnBuyer(stationIndex, script, goodName, namespace, immediateTransaction)
    local station = Entity(stationIndex)
    if not station then return end

    -- print ("spawn buyer")

    local trade = {tradeType = TradeType.BuyFromStation, station = station, script = script, name = goodName}
    TradingUtility.spawnTrader(trade, namespace, immediateTransaction)
end

function TradingUtility.spawnTrader(trade, namespace, immediateTransaction)
    local sector = Sector()

    -- don't spawn helpless ships in war zones
    if sector:getValue("war_zone") then return end

    -- don't spawn if player wrongly controlled too many ships
    if sector:getValue("no_trade_zone") then return end

    --print ("spawning trader...")

    -- find a position rather outside the sector
    -- this is the position where the trader spawns
    local tradingFaction = Galaxy():getNearestFaction(sector:getCoordinates())

    local eradicatedFactions = getGlobal("eradicated_factions") or {}
    if eradicatedFactions[tradingFaction.index] == true then return end

    -- factions at war with each other don't trade
    if not immediateTransaction
        and tradingFaction:getRelations(trade.station.factionIndex) < -40000 then

        return
    end

    local g = goods[trade.name]
    if not g then
        print ("invalid good: '" .. trade.name .. "'")
        return
    end

    local good = g:good()

    local x, y = sector:getCoordinates()
    local maxValue = Balancing_GetSectorRichnessFactor(x, y, 50) * 750000

    -- still allow some high-value transports
    if math.random() < 0.2 then
        maxValue = maxValue * (1 + math.random() * 4)
    end

    local maxAmount = maxValue / good.price

    local amount = trade.amount or 100 + math.random() * 1000
    amount = math.ceil(math.min(maxAmount, amount))

    if not immediateTransaction then
        local pos = random():getDirection() * 1500
        local matrix = MatrixLookUpPosition(normalize(-pos), vec3(0, 1, 0), pos)

        local onGenerated = function (ship)
            if not valid(trade.station) then
                Sector():deleteEntity(ship)
                return
            end

            ship:setValue("trade_partner", trade.station.id.string)

            -- if the trader buys, he has no cargo, if he sells, add cargo
            if trade.tradeType == TradeType.SellToStation then
                ship:addCargo(good, amount)
                ship:addScript("merchants/tradeship.lua", trade.station.id, trade.script)
                -- print ("creating a trader for " .. trade.station.title .. " to sell " .. amount .. " " .. trade.name)
            elseif trade.tradeType == TradeType.BuyFromStation then
                ship:addScript("merchants/tradeship.lua", trade.station.id, trade.script, trade.name, amount)
                -- print ("creating a trader for " .. trade.station.title .. " to buy " .. amount .. " " .. trade.name)
            end
        end

        -- create the trader
        local generator = AsyncShipGenerator(namespace, onGenerated)
        generator:createFreighterShip(tradingFaction, matrix)
    else
        -- do transaction immediately
        if trade.tradeType == TradeType.SellToStation then
            local error = trade.station:invokeFunction(trade.script, "buyGoods", good, amount, tradingFaction.index)

            if error ~= 0 then
                print ("buy error: " .. error)
            end

            -- print ("immediate sell to station transaction")
        elseif trade.tradeType == TradeType.BuyFromStation then
            local error = trade.station:invokeFunction(trade.script, "sellGoods", good, amount, tradingFaction.index)

            if error ~= 0 then
                print ("sell error: " .. error)
            end
            -- print ("immediate buy from station transaction")
        end
    end

end

return TradingUtility
