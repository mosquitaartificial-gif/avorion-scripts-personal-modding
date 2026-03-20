package.path = package.path .. ";data/scripts/lib/?.lua"
include ("stringutility")
include ("faction")
local ShopAPI = include ("shop")
local BuildingKnowledgeUT = include("buildingknowledgeutility")
local TradeableInventoryItem = include("tradeableinventoryitem")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace ResourceDepotBuildingKnowledgeMerchant
ResourceDepotBuildingKnowledgeMerchant = {}
ResourceDepotBuildingKnowledgeMerchant = ShopAPI.CreateNamespace()
ResourceDepotBuildingKnowledgeMerchant.shop.everythingCanBeBought = true

-- resource depots sell for goods
ResourceDepotBuildingKnowledgeMerchant.shop.ItemWrapper = TradeableInventoryItem

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function ResourceDepotBuildingKnowledgeMerchant.interactionPossible(playerIndex, option)
    local player = Player(playerIndex)
    local material = BuildingKnowledgeUT.getLocalKnowledgeMaterial()

    if player then
        if player.maxBuildableMaterial >= material then
            return false
        end
    end

    return CheckFactionInteraction(playerIndex, 0)
end

function ResourceDepotBuildingKnowledgeMerchant.initialize()
    ResourceDepotBuildingKnowledgeMerchant.interactionThreshold = 0
    ResourceDepotBuildingKnowledgeMerchant.shop.relationThreshold = 0

    local station = Entity()
    ResourceDepotBuildingKnowledgeMerchant.shop:initialize(station.translatedTitle)
end

function ResourceDepotBuildingKnowledgeMerchant.shop:onSold(item, buyer, player)
    local it, material = BuildingKnowledgeUT.getLocalKnowledge(x, y, player.index)
    item.item = it
    item.item.price = round(item.item.price / 10 / material.costFactor / 1000) * 1000
end

function ResourceDepotBuildingKnowledgeMerchant.shop:addItems()
    local faction = Faction()

    if faction.isPlayer then
        local player = Player()
        local material = BuildingKnowledgeUT.getLocalKnowledgeMaterial()

        if player.maxBuildableMaterial < material then
            return
        end
    end

    if faction.isAlliance then
        return
    end

    local item, material = BuildingKnowledgeUT.getLocalKnowledge()
    item.price = round(item.price / 10 / material.costFactor / 1000) * 1000

    local oreNames = {}
    oreNames[1] = "Iron Ore" -- names are hardcoded here since it's about those specific ores (used as keys)
    oreNames[2] = "Titanium Ore"
    oreNames[3] = "Naonite Ore"
    oreNames[4] = "Trinium Ore"
    oreNames[5] = "Xanion Ore"
    oreNames[6] = "Ogonite Ore"
    oreNames[7] = "Avorion Ore"

    local sellableItem = ResourceDepotBuildingKnowledgeMerchant.add(item, 1)
    sellableItem.good = oreNames[material.value + 1]
    sellableItem.material = material
end

function ResourceDepotBuildingKnowledgeMerchant.initUI()
    local station = Entity()
    ResourceDepotBuildingKnowledgeMerchant.shop:initUI("Building Knowledge"%_t, station.translatedTitle, "Building Knowledge"%_t, "data/textures/icons/building-knowledge.png", {showSpecialOffer = false})
    ResourceDepotBuildingKnowledgeMerchant.shop.tabbedWindow:deactivateTab(ResourceDepotBuildingKnowledgeMerchant.shop.sellTab)
    ResourceDepotBuildingKnowledgeMerchant.shop.tabbedWindow:deactivateTab(ResourceDepotBuildingKnowledgeMerchant.shop.buyBackTab)

    -- resource depots sell for goods
    ResourceDepotBuildingKnowledgeMerchant.shop.currencyLabel.caption = "RAW ORE*"%_t
    ResourceDepotBuildingKnowledgeMerchant.shop.currencyLabel.tooltip = "You can exchange raw ores from your cargo bay for Building Knowledge here. You need an R-Mining-Laser to gather raw ores."%_t
end
