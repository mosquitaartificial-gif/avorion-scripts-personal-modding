package.path = package.path .. ";data/scripts/lib/?.lua"
include ("utility")
include ("randomext")
include ("faction")
local ShopAPI = include ("shop")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace UtilityMerchant
UtilityMerchant = {}
UtilityMerchant = ShopAPI.CreateNamespace()

UtilityMerchant.interactionThreshold = -30000

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function UtilityMerchant.interactionPossible(playerIndex, option)
    return CheckFactionInteraction(playerIndex, UtilityMerchant.interactionThreshold)
end

local function sortSystems(a, b)
    if a.rarity.value == b.rarity.value then
        return a.price > b.price
    end

    return a.rarity.value > b.rarity.value
end

function UtilityMerchant.shop:addItems()

    local x, y = Sector():getCoordinates()

    local faction = Faction()

    if faction then
        local item = UsableInventoryItem("reinforcementstransmitter.lua", Rarity(RarityType.Exotic), faction.index)
        UtilityMerchant.add(item, getInt(1, 2))
        local item = UsableInventoryItem("equipmentmerchantcaller.lua", Rarity(RarityType.Exceptional), faction.index)
        UtilityMerchant.add(item, getInt(2, 3))

        local hx, hy = faction:getHomeSectorCoordinates()

        local item = UsableInventoryItem("factionmapsegment.lua", Rarity(RarityType.Exotic), faction.index, hx, hy, x, y)
        UtilityMerchant.add(item, getInt(2, 3))
        local item = UsableInventoryItem("factionmapsegment.lua", Rarity(RarityType.Exceptional), faction.index, hx, hy, x, y)
        UtilityMerchant.add(item, getInt(2, 3))
        local item = UsableInventoryItem("factionmapsegment.lua", Rarity(RarityType.Rare), faction.index, hx, hy, x, y)
        UtilityMerchant.add(item, getInt(2, 3))
        local item = UsableInventoryItem("factionmapsegment.lua", Rarity(RarityType.Uncommon), faction.index, hx, hy, x, y)
        UtilityMerchant.add(item, getInt(2, 3))
    end

    if not GameSettings().permaDestruction then
        local item = UsableInventoryItem("coopreconstructionkit.lua", Rarity(RarityType.Exceptional))
        UtilityMerchant.add(item, getInt(2, 3))
    end

    local item = UsableInventoryItem("energysuppressor.lua", Rarity(RarityType.Exceptional))
    UtilityMerchant.add(item, getInt(2, 3))
    local item = UsableInventoryItem("markerbuoyspawner.lua", Rarity(RarityType.Uncommon))
    UtilityMerchant.add(item, getInt(8, 12))
    local item = UsableInventoryItem("renamingbeaconspawner.lua", Rarity(RarityType.Uncommon))
    UtilityMerchant.add(item, getInt(1, 2))
    local item = UsableInventoryItem("messagebeaconspawner.lua", Rarity(RarityType.Uncommon))
    UtilityMerchant.add(item, getInt(1, 2))

end

function UtilityMerchant.initialize()
    UtilityMerchant.shop:initialize("Utility Merchant"%_t)
end

function UtilityMerchant.initUI()
    UtilityMerchant.shop:initUI("Trade Equipment"%_t, "Utility Merchant"%_t, "Utilities"%_t, "data/textures/icons/bag_satellite.png", {showSpecialOffer = false})
end
