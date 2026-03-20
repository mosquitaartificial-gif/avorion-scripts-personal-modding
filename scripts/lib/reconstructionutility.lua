package.path = package.path .. ";data/scripts/lib/?.lua"
include ("stringutility")
include ("utility")

function countReconstructionKits(faction, shipName, factionIndex)

    factionIndex = factionIndex or faction.index

    local items = faction:getInventory():getItemsByType(InventoryItemType.UsableItem)
    for idx, slot in pairs(items) do
        local amount = slot.amount
        local item = slot.item

        -- we assume they're stackable, so we return here
        if item:getValue("subtype") == "ReconstructionKit"
                and item:getValue("ship") == shipName
                and item:getValue("faction") == factionIndex then
            return amount, item, idx
        end
    end

    return 0, nil
end

function removeReconstructionKits(faction, shipName, factionIndex)

    factionIndex = factionIndex or faction.index

    local items = faction:getInventory():getItemsByType(InventoryItemType.UsableItem)
    for idx, slot in pairs(items) do
        local amount = slot.amount
        local item = slot.item

        -- we assume they're stackable, so we return here
        if item:getValue("subtype") == "ReconstructionKit"
                and item:getValue("ship") == shipName
                and item:getValue("faction") == factionIndex then

            faction:getInventory():removeAll(idx)
        end
    end

    return 0, nil
end

function createReconstructionKit(craft)
    return UsableInventoryItem("data/scripts/items/reconstructionkit.lua", Rarity(RarityType.Exotic), craft.factionIndex, craft.name)
end
