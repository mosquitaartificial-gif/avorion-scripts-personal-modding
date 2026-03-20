package.path = package.path .. ";data/scripts/lib/?.lua"
include("productionsindex")
include("stringutility")

productionsByGood = {}

function formatFactoryName(production, size)
    size = size or ""

    local args = {size = size}
    local factoryName = "Factory ${size}"%_t
    local result = goods[production.results[1].name]

    if result then
        local good = result:good()
        if good then
            factoryName = production.factory
            args.good = good.name
            args.prefix = (good.name .. " /* prefix */")
            args.plural = good.plural
        end
    end

    return factoryName, args
end

function getTranslatedFactoryName(production, size)
    local name, args = formatFactoryName(production, size)

    name = name % _t
    for k, v in pairs(args) do
        args[k] = v % _t
    end

    return name % args;
end

for i, production in pairs(productions) do
    production.index = i

    if (string.match(production.factory, " Mine") and not string.match(production.factory, "Mineral"))
            or string.match(production.factory, "Oil Rig") then

        production.mine = true
    end

    for _, result in pairs(production.results) do
        local collection = productionsByGood[result.name]

        if not collection then
            collection = {}
            productionsByGood[result.name] = collection
        end

        table.insert(collection, production)
    end

end

function getMiningProductions()

    local miningProductions = {}

    for _, productions in pairs(productionsByGood) do
        for index, production in pairs(productions) do
            if production.mine then
                table.insert(miningProductions, {production=production, index=index})
            end
        end
    end

    -- sort the array to make it deterministic
    local function comp(a, b) return a.production.index < b.production.index end
    table.sort(miningProductions, comp)

    return miningProductions
end

function getFactoryCost(production)

    -- calculate the difference between the value of ingredients and results
    local ingredientValue = 0
    local resultValue = 0

    for _, ingredient in pairs(production.ingredients) do
        local good = goods[ingredient.name]
        ingredientValue = ingredientValue + good.price * ingredient.amount
    end

    for _, result in pairs(production.results) do
        local good = goods[result.name]
        resultValue = resultValue + good.price * result.amount
    end

    local diff = resultValue - ingredientValue

    local costs = 2500000 -- 2.5 mio minimum for a factory
    costs = costs + diff * 3500
    return costs
end

function getFactoryUpgradeCost(production, size)

    -- calculate the difference between the value of ingredients and results
    local ingredientValue = 0
    local resultValue = 0

    for _, ingredient in pairs(production.ingredients) do
        local good = goods[ingredient.name]
        ingredientValue = ingredientValue + good.price * ingredient.amount
    end

    for _, result in pairs(production.results) do
        local good = goods[result.name]
        resultValue = resultValue + good.price * result.amount
    end
    -- factor in garbage results as well
    for _, result in pairs(production.garbages) do
        local good = goods[result.name]
        resultValue = resultValue + good.price * result.amount
    end

    local diff = resultValue - ingredientValue

    local costs = diff * 1000 * size
    return costs
end

