package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace DropTradingGoods
DropTradingGoods = {}
local data = {}

data.tradingGoodName = ""
data.tradingGoodPlural = ""
data.tradingGoodDescription = ""
data.tradingGoodIcon = ""
data.tradingGoodPrice = 0
data.tradingGoodSize = 1
data.tradingGoodMesh = ""
data.tradingGoodTags = {}

data.dropOnBlockDestruction = true
data.dropOnFullDestruction = true

if onServer() then

function DropTradingGoods.initialize(tradingGood_in, dropOnBlockDestruction, dropOnFullDestruction)
    if dropOnBlockDestruction == nil then dropOnBlockDestruction = true end
    if dropOnFullDestruction == nil then dropOnFullDestruction = true end

    if not _restoring then
        data.tradingGoodName = tradingGood_in.name
        data.tradingGoodPlural = tradingGood_in.plural
        data.tradingGoodDescription = tradingGood_in.description
        data.tradingGoodIcon = tradingGood_in.icon
        data.tradingGoodPrice = tradingGood_in.price
        data.tradingGoodSize = tradingGood_in.size
        data.tradingGoodMesh = tradingGood_in.mesh
        data.tradingGoodTags = tradingGood_in.tags

        data.dropOnBlockDestruction = dropOnBlockDestruction
        data.dropOnFullDestruction = dropOnFullDestruction

        if data.dropOnBlockDestruction then Entity():registerCallback("onBlockDestroyed", "onBlockDestroyed") end
        if data.dropOnFullDestruction then Entity():registerCallback("onDestroyed", "onDestroyed") end
    end

end

function DropTradingGoods.secure()
    return data
end

function DropTradingGoods.restore(data_in)
    data = data_in

    if data.dropOnBlockDestruction then Entity():registerCallback("onBlockDestroyed", "onBlockDestroyed") end
    if data.dropOnFullDestruction then Entity():registerCallback("onDestroyed", "onDestroyed") end
end

function DropTradingGoods.onBlockDestroyed(entityId, blockIndex, block, lastDamageInflictorId)
    local position = Entity().position:transformCoord(block.box.position)
    DropTradingGoods.drop(position)
end

function DropTradingGoods.onDestroyed(entityId, lastDamageInflictorId)
    DropTradingGoods.drop(Entity().translationf)
end

function DropTradingGoods.drop(location)
    local good = TradingGood(data.tradingGoodName, data.tradingGoodPlural, data.tradingGoodDescription, data.tradingGoodIcon, data.tradingGoodPrice, data.tradingGoodSize)
    good.tags = data.tradingGoodTags
    good.mesh = data.tradingGoodMesh

    Sector():dropCargo(location, nil, nil, good, 0, 1)
end

end
