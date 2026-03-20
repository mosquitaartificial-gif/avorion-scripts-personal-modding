package.path = package.path .. ";data/scripts/lib/?.lua"
include ("stringutility")
include ("faction")
local ShopAPI = include ("shop")
local BuildingKnowledgeUT = include("buildingknowledgeutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace SmugglerBuildingKnowledgeMerchant
SmugglerBuildingKnowledgeMerchant = {}
SmugglerBuildingKnowledgeMerchant = ShopAPI.CreateNamespace()

SmugglerBuildingKnowledgeMerchant.interactionThreshold = -80000
SmugglerBuildingKnowledgeMerchant.shop.relationThreshold = -80000
SmugglerBuildingKnowledgeMerchant.shop.everythingCanBeBought = true

-- smuggler's markets always sell, but for a crazy high price
SmugglerBuildingKnowledgeMerchant.shop.priceRatio = 11

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function SmugglerBuildingKnowledgeMerchant.interactionPossible(playerIndex, option)
    local player = Player(playerIndex)
    local material = BuildingKnowledgeUT.getLocalKnowledgeMaterial()

    if player then
        if player.maxBuildableMaterial >= material then
            return false
        end
    end

    return CheckFactionInteraction(playerIndex, -80000)
end

function SmugglerBuildingKnowledgeMerchant.initialize()
    local station = Entity()
    SmugglerBuildingKnowledgeMerchant.shop:initialize(station.translatedTitle)
end

function SmugglerBuildingKnowledgeMerchant.shop:onSold(item, buyer, player)
    item.item = BuildingKnowledgeUT.getLocalKnowledge(x, y, player.index)
end

function SmugglerBuildingKnowledgeMerchant.shop:addItems()
    local faction = Faction()
    if not faction then return end

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
    local sellableItem = SmugglerBuildingKnowledgeMerchant.add(item, 1)
end

function SmugglerBuildingKnowledgeMerchant.initUI()
    local station = Entity()
    SmugglerBuildingKnowledgeMerchant.shop:initUI("Building Knowledge"%_t, station.translatedTitle, "Building Knowledge"%_t, "data/textures/icons/building-knowledge.png", {showSpecialOffer = false})
    SmugglerBuildingKnowledgeMerchant.shop.tabbedWindow:deactivateTab(SmugglerBuildingKnowledgeMerchant.shop.sellTab)
    SmugglerBuildingKnowledgeMerchant.shop.tabbedWindow:deactivateTab(SmugglerBuildingKnowledgeMerchant.shop.buyBackTab)
end
