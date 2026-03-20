package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/encyclopedia/lib/?.lua"
package.path = package.path .. ";data/scripts/encyclopedia/?.lua"
include ("stringutility")
include ("contents")
include ("goodsindex")
include ("productionsindex")
include ("goods")
local ConsumerGoods = include ("consumergoods")

Categories = Categories or {}
category = {}

table.insert(Categories, category)

category.title = "Production Glossary"%_t

-- get all needed goods for station
function getIngredientsText(ingredients)
    local noEntry = true
    local multipleTypes = false

    local ingredientsText = "Needs:"%_t .. "\n"

    for i, ingredientTable in pairs(ingredients) do
        if #ingredients > 1 and not (#ingredientTable == 0) then
            multipleTypes = true
        end

        if multipleTypes == true then
            ingredientsText = ingredientsText .. "Type ${i}: "%_t % {i = i}
        end

        ingredientsText = ingredientsText .. string.join(ingredientTable, ", ", function(i, good)
            noEntry = false
            return getTranslatedGoodName(good.name)
        end)

        if multipleTypes == true then
            ingredientsText = ingredientsText .. "\n"
        end
    end

    if noEntry then
        return ""
    end

    ingredientsText = ingredientsText .. "\n\n"

    return ingredientsText
end

-- get all produced goods for station
function getResultsText(results)
    local noEntry = true
    local multipleTypes = false

    local resultsText = "Produces:"%_t .. "\n"

    for i, resultTable in pairs(results) do
        if #results > 1 and not (#resultTable == 0) then
            multipleTypes = true
        end

        if multipleTypes == true then
            resultsText = resultsText .. "Type ${i}: "%_t % {i = i}
        end

        resultsText = resultsText .. string.join(resultTable, ", ", function(i, good)
            noEntry = false
            return getTranslatedGoodName(good.name)
        end)

        if multipleTypes == true then
            resultsText = resultsText .. "\n"
        end
    end

    if noEntry then
        return ""
    end

    return resultsText
end

local dataTable = {}

-- get data for all station types
for _, production in pairs(productions) do
    local factoryName = getTranslatedFactoryName(production, "")

    for _, factory in pairs(dataTable) do
        if factory.title == factoryName then
            table.insert(factory.needs, production.ingredients)
            table.insert(factory.produces, production.results)
            goto continue
        end
    end

    local factory =
    {
        title = factoryName,
        needs = {production.ingredients},
        produces = {production.results},
        style = production.factoryStyle,
    }

    table.insert(dataTable, factory)
    ::continue::
end

local factoriesArticles = {}
local minesArticles = {}
local collectorArticles = {}
local farmsArticles = {}

for _, factory in pairs(dataTable) do
    local ingredientsText = getIngredientsText(factory.needs)
    local resultsText = getResultsText(factory.produces)

    local factoryArticle =
    {
        title = factory.title,
        text = ingredientsText .. resultsText
    }

    if factory.style == "Factory" or factory.style == "SolarPowerPlant" then
        factoryArticle.picture = "data/textures/ui/encyclopedia/exploring/stations/Factory.jpg"
        table.insert(factoriesArticles, factoryArticle)
    elseif factory.style == "Mine" then
        factoryArticle.picture = "data/textures/ui/encyclopedia/production/mine.jpg"
        table.insert(minesArticles, factoryArticle)
    elseif factory.style == "Collector" then
        factoryArticle.picture = "data/textures/ui/encyclopedia/production/collector.jpg"
        table.insert(collectorArticles, factoryArticle)
    elseif factory.style == "Farm" or factory.style == "Ranch" then
        factoryArticle.picture = "data/textures/ui/encyclopedia/production/farm.jpg"
        table.insert(farmsArticles, factoryArticle)
    end
end

-- consumers only buy and are not set in a script
function getConsumerText(goodsTable)
    local consumerText = "Needs:"%_t .. "\n"
    local duplicatesTable = {}
    local uniqueGoodsTable = {}
    local counter = 0

    for key, goodName in pairs(goodsTable) do
        if not uniqueGoodsTable[goodName] then
            uniqueGoodsTable[key] = goodName
        end
    end

    for key, goodName in pairs(uniqueGoodsTable) do
        local seperator = ", "
        if key == #uniqueGoodsTable then
            seperator = ""
        elseif key % 3 == 0 then
            seperator = ",\n"
        end

        consumerText = consumerText .. getTranslatedGoodName(goodName) .. seperator
    end

    return consumerText
end

-- actual encyclopedia entry
category.chapters =
{
    {
        title = "Factories"%_t,
        picture = "data/textures/ui/encyclopedia/exploring/stations/Factory.jpg",
        text = "Factories produce goods. Most of them need ingredients to convert them into new goods."%_t,
        articles = factoriesArticles,
    },

    {
        title = "Mines"%_t,
        picture = "data/textures/ui/encyclopedia/production/mine.jpg",
        text = "Mines extract minerals from asteroids. They specialize in only a few goods and sell them."%_t,
        articles = minesArticles,
    },

    {
        title = "Collectors"%_t,
        picture = "data/textures/ui/encyclopedia/production/collector.jpg",
        text = "Collectors use special technology to attract rare particles from space. They collect those particles and sell them."%_t,
        articles = collectorArticles,
    },

    {
        title = "Farms and Ranches"%_t,
        picture = "data/textures/ui/encyclopedia/production/farm.jpg",
        text = "Farms and Ranches are the agricultural part of production in space. They need \\c(0d0)water\\c(), animal feed or \\c(0d0)fertilizer\\c() to produce different kinds of food, animals and waste products."%_t,
        articles = farmsArticles,
    },

    {
        title = "Consumers"%_t,
        picture = "data/textures/ui/encyclopedia/production/habitat.jpg",
        text = "Consumers only buy things. They are the end of the production chain. Their inhabitants consume the goods that are sold to them."%_t,
        articles =
        {
            {
                title = "Habitat"%_t,
                picture = "data/textures/ui/encyclopedia/production/habitat.jpg",
                text = getConsumerText(ConsumerGoods.Habitat())
            },
            {
                title = "Biotope"%_t,
                picture = "data/textures/ui/encyclopedia/production/biotope.jpg",
                text = getConsumerText(ConsumerGoods.Biotope())
            },
            {
                title = "Casino"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/Casino.jpg",
                text = getConsumerText(ConsumerGoods.Casino())
            },
            {
                title = "Shipyard"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/Shipyard.jpg",
                text = getConsumerText(ConsumerGoods.Shipyard())
            },
            {
                title = "Equipment Dock"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/EquipmentDock.jpg",
                text = getConsumerText(ConsumerGoods.EquipmentDock())
            },
            {
                title = "Repair Dock"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/RepairDock.jpg",
                text = getConsumerText(ConsumerGoods.RepairDock())
            },
            {
                title = "Military Outpost"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/MilitaryOutpost.jpg",
                text = getConsumerText(ConsumerGoods.MilitaryOutpost())
            },
            {
                title = "Research Station"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/Research.jpg",
                text = getConsumerText(ConsumerGoods.ResearchStation())
            },
            {
                title = "Travel Hub"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/TravelHub.jpg",
                text = getConsumerText(ConsumerGoods.TravelHub())
            },
        },
    },
}
