package.path = package.path .. ";data/scripts/lib/?.lua"
include ("stringutility")
include ("faction")
local ShopAPI = include ("shop")
local BuildingKnowledgeUT = include("buildingknowledgeutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace BuildingKnowledgeMerchant
BuildingKnowledgeMerchant = {}
BuildingKnowledgeMerchant = ShopAPI.CreateNamespace()

BuildingKnowledgeMerchant.interactionThreshold = 64500
BuildingKnowledgeMerchant.shop.relationThreshold = 64500
BuildingKnowledgeMerchant.shop.everythingCanBeBought = true

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function BuildingKnowledgeMerchant.interactionPossible(playerIndex, option)
    local player = Player(playerIndex)
    if player then
        local material = BuildingKnowledgeUT.getLocalKnowledgeMaterial()
        if player.maxBuildableMaterial >= material then
            return false
        end
    end

    return CheckFactionInteraction(playerIndex, BuildingKnowledgeMerchant.interactionThreshold)
end

function BuildingKnowledgeMerchant.initialize()
    local station = Entity()
    BuildingKnowledgeMerchant.shop:initialize(station.translatedTitle)
end

function BuildingKnowledgeMerchant.shop:onSold(item, buyer, player)
    item.item = BuildingKnowledgeUT.getLocalKnowledge(x, y, player.index)
end

function BuildingKnowledgeMerchant.shop:addItems()
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

    local item = BuildingKnowledgeUT.getLocalKnowledge()
    BuildingKnowledgeMerchant.add(item, 1)
end

function BuildingKnowledgeMerchant.initUI()
    BuildingKnowledgeMerchant.shop:initUI("Building Knowledge"%_t, "Shipyard"%_t, "Building Knowledge"%_t, "data/textures/icons/building-knowledge.png", {showSpecialOffer = false})
    BuildingKnowledgeMerchant.shop.tabbedWindow:deactivateTab(BuildingKnowledgeMerchant.shop.sellTab)
    BuildingKnowledgeMerchant.shop.tabbedWindow:deactivateTab(BuildingKnowledgeMerchant.shop.buyBackTab)
end
