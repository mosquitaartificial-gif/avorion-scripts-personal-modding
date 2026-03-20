package.path = package.path .. ";data/scripts/lib/?.lua"
include ("sellableinventoryitem")
include ("goods")

local SellableTradingGood = {}
SellableTradingGood.__index = SellableTradingGood

local function new(good, index, player)
    local obj = setmetatable({good = good, item = good, index = index}, SellableTradingGood)

    -- initialize the item
    local tradingGood = tableToGood(good)
    obj.price = good.price
    obj.rarity = {color = tradingGood.color}
    obj.name = good.name
    obj.icon = good.icon

    if index and type(index) == "number" then
        obj.amount = index
    else
        obj.amount = 1
    end

    return obj
end

function SellableTradingGood:getTooltip()

    if self.tooltip == nil then
        self.tooltip = Tooltip()

        local fontSize = 14
        local lineHeight = 20

        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = self.good.description
        self.tooltip:addLine(line)
    end

    return self.tooltip
end

function SellableTradingGood:getPrice()
    return self.good.price
end

function SellableTradingGood:getName()
    return tableToGood(self.good):displayName(self.amount)
end

function SellableTradingGood:getRelationChangeType()
    return RelationChangeType.GoodsTrade
end

function SellableTradingGood:canBeBought(player, ai)
    return true
end

function SellableTradingGood:boughtByPlayer(ship, amount)
    amount = amount or 1

    local cargoBay = CargoBay(ship)
    if not cargoBay then
        return "Not enough space in your cargo bay!"%_t, {}
    end

    if cargoBay.freeSpace < self.good.size * amount then
        return "Not enough space in your cargo bay!"%_t, {}
    end

    cargoBay:addCargo(self.good:good(), amount)
end

function SellableTradingGood:soldByPlayer(ship, amount)
    local cargoBay = CargoBay(ship)
    if not cargoBay then
        return "You don't have any of this!"%_t, {}
    end

    local tradingGood = self.good:good()
    local amountOnShip = cargoBay:getNumCargos(tradingGood)
    if amountOnShip == nil or amountOnShip < amount then
        return "You don't have any of this!"%_t, {}
    end

    cargoBay:removeCargo(tradingGood, amount)
end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
