package.path = package.path .. ";data/scripts/lib/?.lua"
include ("galaxy")
include ("utility")
include ("randomext")
include ("faction")
include ("sellableinventoryitem")
include ("stringutility")
local TorpedoGenerator = include("torpedogenerator")
local Dialog = include("dialogutility")
local ShopAPI = include ("shop")
local SellableTorpedo = include ("sellabletorpedo")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace TorpedoMerchant
TorpedoMerchant = {}
TorpedoMerchant = ShopAPI.CreateNamespace()
TorpedoMerchant.interactionThreshold = -30000

TorpedoMerchant.rarityFactors = {}
TorpedoMerchant.rarityFactors[-1] = 1.0
TorpedoMerchant.rarityFactors[0] = 1.0
TorpedoMerchant.rarityFactors[1] = 1.0
TorpedoMerchant.rarityFactors[2] = 1.0
TorpedoMerchant.rarityFactors[3] = 1.0
TorpedoMerchant.rarityFactors[4] = 1.0
TorpedoMerchant.rarityFactors[5] = 1.0

TorpedoMerchant.specialOfferRarityFactors = {}
TorpedoMerchant.specialOfferRarityFactors[-1] = 0.0
TorpedoMerchant.specialOfferRarityFactors[0] = 0.0
TorpedoMerchant.specialOfferRarityFactors[1] = 0.0
TorpedoMerchant.specialOfferRarityFactors[2] = 1.0
TorpedoMerchant.specialOfferRarityFactors[3] = 1.0
TorpedoMerchant.specialOfferRarityFactors[4] = 0.25
TorpedoMerchant.specialOfferRarityFactors[5] = 0.0

-- if this function returns false, the script will not be listed in the interaction window on the client,
-- even though its UI may be registered
function TorpedoMerchant.interactionPossible(playerIndex, option)
    return CheckFactionInteraction(playerIndex, TorpedoMerchant.interactionThreshold)
end

local function comp(a, b)
    local ta = a.torpedo;
    local tb = b.torpedo;

    if ta.rarity == tb.rarity then
        return ta.name < tb.name
    else
        return ta.rarity.value > tb.rarity.value
    end
end

function TorpedoMerchant.shop:addItems()

    local station = Entity()

    if station.title == "" then
        station.title = "Torpedo Merchant"%_t
    end

    -- create all torpedoes
    local allTorpedoes = {}
    local generator = TorpedoGenerator()
    generator.rarities = generator:getDefaultRarityDistribution()

    for i, rarity in pairs(generator.rarities) do
        generator.rarities[i] = rarity * TorpedoMerchant.rarityFactors[i] or 1
    end

    for i = 1, 12 do
        local torpedo = generator:generate(Sector():getCoordinates())

        for _, p in pairs(allTorpedoes) do
            if torpedo.warheadClass == p.torpedo.warheadClass
                    and torpedo.bodyClass == p.torpedo.bodyClass
                    and torpedo.rarity == p.torpedo.rarity then
                 goto continue
            end
        end

        local pair = {}
        pair.torpedo = torpedo
        pair.amount = 1

        if torpedo.rarity.value >= RarityType.Exotic then
            pair.amount = getInt(5, 10)
        elseif torpedo.rarity.value == RarityType.Exceptional then
            pair.amount = getInt(10, 20)
        elseif torpedo.rarity.value == RarityType.Rare then
            pair.amount = getInt(30, 40)
        elseif torpedo.rarity.value == RarityType.Uncommon then
            pair.amount = getInt(30, 40)
        elseif torpedo.rarity.value == RarityType.Common then
            pair.amount = getInt(40, 50)
        end

        table.insert(allTorpedoes, pair)

        ::continue::
    end

    table.sort(allTorpedoes, comp)

    for _, pair in pairs(allTorpedoes) do
        TorpedoMerchant.shop:add(pair.torpedo, pair.amount)
    end
end

-- sets the special offer that gets updated every 20 minutes
function TorpedoMerchant.shop:onSpecialOfferSeedChanged()
    local generator = TorpedoGenerator(TorpedoMerchant.shop:generateSeed())

    local rarities = generator:getDefaultRarityDistribution()

    for i, rarity in pairs(rarities) do
        rarities[i] = rarity * TorpedoMerchant.specialOfferRarityFactors[i] or 1
    end

    generator.rarities = rarities

    local specialTorpedo = generator:generate(Sector():getCoordinates())
    local amount = getInt(4, 6)

    TorpedoMerchant.shop:setSpecialOffer(specialTorpedo, amount)
end

function TorpedoMerchant.initialize()
    TorpedoMerchant.shop:initialize("Torpedo Merchant"%_t)

    if onClient() and EntityIcon().icon == "" then
        EntityIcon().icon = "data/textures/icons/pixel/trade.png" -- TODO @Philipp
    end
end

function TorpedoMerchant.initUI()
    TorpedoMerchant.shop:initUI("Trade Equipment"%_t, "Torpedo Merchant"%_t, "Torpedoes"%_t, "data/textures/icons/bag-missile-pod.png")
end

TorpedoMerchant.shop.ItemWrapper = SellableTorpedo
TorpedoMerchant.shop.SortFunction = comp
