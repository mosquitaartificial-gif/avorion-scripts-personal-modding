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

category.title = "Goods Glossary"%_t

-- build goods articles
function getConsumerList(goodName)
    local consumerText = ""
    for i, consumerGoodName in pairs(ConsumerGoods.Habitat()) do
        if consumerGoodName == goodName then
            consumerText = consumerText .. "Habitat"%_t .. ", "
        end
    end

    for i, consumerGoodName in pairs(ConsumerGoods.Biotope()) do
        if consumerGoodName == goodName then
            consumerText = consumerText .. "Biotope"%_t .. ", "
        end
    end

    for i, consumerGoodName in pairs(ConsumerGoods.Casino()) do
        if consumerGoodName == goodName then
            consumerText = consumerText .. "Casino"%_t .. ", "
        end
    end

    for i, consumerGoodName in pairs(ConsumerGoods.EquipmentDock()) do
        if consumerGoodName == goodName then
            consumerText = consumerText .. "Equipment Dock"%_t .. ", "
        end
    end

    for i, consumerGoodName in pairs(ConsumerGoods.Shipyard()) do
        if consumerGoodName == goodName then
            consumerText = consumerText .. "Shipyard"%_t .. ", "
        end
    end

    for i, consumerGoodName in pairs(ConsumerGoods.RepairDock()) do
        if consumerGoodName == goodName then
            consumerText = consumerText .. "Repair Dock"%_t .. ", "
        end
    end

    for i, consumerGoodName in pairs(ConsumerGoods.MilitaryOutpost()) do
        if consumerGoodName == goodName then
            consumerText = consumerText .. "Military Outpost"%_t .. ", "
        end
    end

    for i, consumerGoodName in pairs(ConsumerGoods.ResearchStation()) do
        if consumerGoodName == goodName then
            consumerText = consumerText .. "Research Station"%_t .. ", "
        end
    end

    for i, consumerGoodName in pairs(ConsumerGoods.TravelHub()) do
        if consumerGoodName == goodName then
            consumerText = consumerText .. "Travel Hub"%_t .. ", "
        end
    end

    for i, consumerGoodName in pairs(ConsumerGoods.Mine()) do
        if consumerGoodName == goodName then
            consumerText = consumerText .. "Mine"%_t .. ", "
        end
    end

    for i, consumerGoodName in pairs(ConsumerGoods.TurretFactory(true)) do
        if consumerGoodName == goodName then
            consumerText = consumerText .. "Turret Factory"%_t .. ", "
        end
    end

    return consumerText
end

local sortedGoods = {}
for name, good in pairs(goods) do
    local addEntry = true
    for _, tempGood in pairs(sortedGoods)do
        if good.name == tempGood.name then
            addEntry = false
        end
    end
    if addEntry then
        table.insert(sortedGoods, good)
    end
end

function goodsByName(a, b) return getTranslatedGoodName(a.name) < getTranslatedGoodName(b.name) end
table.sort(sortedGoods, goodsByName)

function makeGoodsArticle(type)
    local goodsArticles = {}

    for name, good in pairs(sortedGoods) do
        -- Rift Research Data has its own article at another place
        if good.name == "Rift Research Data" then
            goto continue
        end

        if good.tags[type] then
            local text = ""
            local goodsText = ""

            -- add goods description
            text = text .. good.description%_t .. "\n\n"

            -- add mention of illegal and dangerous goods
            if good.dangerous then text = text .. "Dangerous good"%_t .. "\n\n" end
            if good.illegal then text = text .. "Illegal good"%_t .. "\n\n" end

            local sellerSet = {}

            -- sets all stations where good is sold
            goodsText = goodsText .. "Sold at:"%_t .. "\n"
            for i, production in pairs(productions) do
                for i, result in pairs(production.results) do
                    -- filters duplicates from stations
                    if result.name == good.name then
                        local entry = string.trim(getTranslatedFactoryName(production, ""))
                        sellerSet[entry] = true
                    end
                end
            end

            -- illegal goods are not traded at trading posts
            if not good.illegal then
                sellerSet["Trading Post"%_t] = true
            elseif #sellerSet == 0 then
                sellerSet["Nowhere"%_t] = true
            end

            goodsText = goodsText .. string.join(sellerSet, ", ", function(a,b) return a end)

            -- spacer between sold and bought
            goodsText = goodsText .. "\n\n"

            -- sets all station where good is bought
            goodsText = goodsText .. "Bought at:"%_t .. "\n"
            goodsText = goodsText .. getConsumerList(good.name)

            local buyerSet = {}

            for i, production in pairs(productions) do
                for i, ingredient in pairs(production.ingredients) do
                -- filters duplicates from stations
                    if ingredient.name == good.name then
                        local entry = string.trim(getTranslatedFactoryName(production, ""))
                        buyerSet[entry] = true
                    end
                end
            end

            if not good.illegal then
                buyerSet["Trading Post"%_t] = true
            end

            -- smugglers buy everything
            buyerSet["Smuggler's Market"%_t] = true

            goodsText = goodsText .. string.join(buyerSet, ", ", function(a, b) return a end)

            local tags = good.tags

            -- ores and scraps get another text
            -- scrap metal is a trading good and not the scrap we are looking for here
            if tags.scrap or tags.ore then
                if tags.ore and tags.rift then
                    text = text .. "Ores are mined out of \\c(0d0)Rift Asteroids\\c() with both types of \\c(0d0)Mining Lasers\\c(), but \\c(0d0)R-Mining Lasers\\c() have a much higher efficiency."%_t
                elseif tags.ore then
                    text = text .. "Ores are mined out of \\c(0d0)Asteroids\\c() with \\c(0d0)R-Mining Lasers\\c()."%_t
                elseif tags.scrap then
                    text = text .. "Scraps are mined out of wreckages with \\c(0d0)R-Salvaging Lasers\\c()."%_t
                end
                text = text .. "\n\n" .. "Can be refined at a \\c(0d0)Resource Depot\\c()."%_t
            else
                text = text .. goodsText
            end

            text = text .. "\n\n" .. "Trading goods are stored in your cargo bay and can be bought and sold for a profit. They can also be used to craft weapons."%_t

            local goodsArticle =
            {
                title = getTranslatedGoodName(good.name),
                picture = "data/textures/ui/encyclopedia/trade/goods_small.jpg",
                text = text
            }
            table.insert(goodsArticles, goodsArticle)
        end

        ::continue::
    end
    return goodsArticles
end

local basicGoodsArticles = makeGoodsArticle("basic")
local technologyGoodsArticles = makeGoodsArticle("technology")
local consumerGoodsArticles = makeGoodsArticle("consumer")
local industrialGoodsArticles = makeGoodsArticle("industrial")
local militaryGoodsArticles = makeGoodsArticle("military")

-- actual encyclopedia entry
category.chapters =
{
    {
        title = "Basic Goods"%_t,
        articles = basicGoodsArticles,
    },

    {
        title = "Industrial Goods"%_t,
        articles = industrialGoodsArticles,
    },

    {
        title = "Military Goods"%_t,
        articles = militaryGoodsArticles,
    },

    {
        title = "Technological Goods"%_t,
        articles = technologyGoodsArticles,
    },

    {
        title = "Consumer Goods"%_t,
        articles = consumerGoodsArticles,
    },
}
