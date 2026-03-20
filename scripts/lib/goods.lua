package.path = package.path .. ";data/scripts/lib/?.lua"
include("goodsindex")

function tableToGood(s)
    local g = TradingGood(s.name, s.plural, s.description, s.icon, s.price, s.size)
    g.mesh = s.mesh or ""
    g.illegal = s.illegal or false
    g.suspicious = s.suspicious or false
    g.stolen = s.stolen or false
    g.dangerous = s.dangerous or false
    g.tags = s.tags or {}
    return g
end

function goodToTable(g)
    return
    {
        name = g.name,
        plural = g.plural,
        description = g.description,
        icon = g.icon,
        mesh = g.mesh,
        price = g.price,
        size = g.size,
        illegal = g.illegal,
        stolen = g.stolen,
        suspicious = g.suspicious,
        dangerous = g.dangerous,
        tags = g.tags,
    }
end

goodsArray = {}
for name, good in pairs(goods) do
    if good.price == 0 then
        good.price = 500
    end

    good.good = tableToGood

    table.insert(goodsArray, good)
end
goods["Silicium"] = goods["Silicon"] -- backwards compatibility
goods["Aluminium"] = goods["Aluminum"] -- backwards compatibility

table.sort(goodsArray, function (a, b) return a.name < b.name end)

spawnableGoods = {}
legalSpawnableGoods = {}
illegalSpawnableGoods = {}
uncomplicatedSpawnableGoods = {}

for _, good in pairs(goodsArray) do
    if not (good.tags.trinium or good.tags.xanion or good.tags.ogonite or good.tags.avorion) then
        if not good.illegal then
            table.insert(legalSpawnableGoods, good)
        end

        if not good.suspicious
                and not good.illegal
                and not good.dangerous
                and not good.stolen then
            table.insert(uncomplicatedSpawnableGoods, good)
        end

        table.insert(spawnableGoods, good)
    end

    if good.illegal then
        table.insert(illegalSpawnableGoods, good)
    end
end


function getGoodAttribute(name, attribute)
    local good = goods[name]
    return good[attribute]
end

function getTranslatedGoodName(name)
    local good = goods[name]
    return good:good():displayName(1)
end
