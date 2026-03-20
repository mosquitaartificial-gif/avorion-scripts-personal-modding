package.path = package.path .. ";data/scripts/lib/?.lua"
include ("galaxy")
include ("utility")
include ("tooltipmaker")
include ("relations")
include ("inventoryitemprice")

local SellableInventoryItem = {}
SellableInventoryItem.__index = SellableInventoryItem

function SortSellableInventoryItems(a, b)
    if a.rarity.value == b.rarity.value then
        if a.item.itemType == b.item.itemType then
            if a.item.itemType == InventoryItemType.Turret or a.item.itemType == InventoryItemType.TurretTemplate then
                if a.item.weaponPrefix == b.item.weaponPrefix then
                    if a.price == b.price then
                        return a.material > b.material
                    else
                        return a.price > b.price
                    end
                else
                    return a.item.weaponPrefix < b.item.weaponPrefix
                end
            elseif a.item.itemType == InventoryItemType.SystemUpgrade then
                if a.item.script == b.item.script then
                    return a.price > b.price
                else
                    return a.item.script < b.item.script
                end
            end
        else
            return a.item.itemType < b.item.itemType
        end
    else
        return a.rarity.value > b.rarity.value
    end
end

local function new(item, index, owner)
    local obj = setmetatable({item = item, index = index}, SellableInventoryItem)

    -- initialize the item
    obj.price = obj:getPrice()
    obj.name = item.name
    obj.rarity = obj.item.rarity
    obj.material = obj:getMaterial()
    obj.icon = obj:getIcon()
    obj.tech = obj:getTech()
    obj.sellable = obj:getSellable()

    if owner and index then
        obj.amount = owner:getInventory():amount(index)
    elseif index and type(index) == "number" then
        obj.amount = index
    else
        obj.amount = 1
    end

    return obj
end

function SellableInventoryItem:getMaterial()
    local item = self.item

    if item.itemType == InventoryItemType.Turret or item.itemType == InventoryItemType.TurretTemplate then
        return item.material
    end
end

function SellableInventoryItem:getIcon()
    local item = self.item

    if item.itemType == InventoryItemType.Turret or item.itemType == InventoryItemType.TurretTemplate then
        return item.weaponIcon
    elseif item.itemType == InventoryItemType.SystemUpgrade then
        return item.icon
    elseif item.itemType == InventoryItemType.VanillaItem
        or item.itemType == InventoryItemType.UsableItem then
        return item.icon
    end
end

function SellableInventoryItem:getSellable()
    local item = self.item

    if item.itemType == InventoryItemType.VanillaItem or item.itemType == InventoryItemType.UsableItem then
        if item:getValue("unsellable") then
            return false
        end
    end

    return true
end

function SellableInventoryItem:getTech()
    local item = self.item

    if item.itemType == InventoryItemType.Turret or item.itemType == InventoryItemType.TurretTemplate then
        return round(item.averageTech, 1)
    end
end

function SellableInventoryItem:getTooltip()
    local item = self.item

    if self.tooltip == nil then
        if item.itemType == InventoryItemType.Turret or item.itemType == InventoryItemType.TurretTemplate then

            local tooltipType = 1
            if ClientSettings and ClientSettings().detailedTurretTooltips then tooltipType = 2 end

            self.tooltip = makeTurretTooltip(item, nil, tooltipType)
        elseif item.itemType == InventoryItemType.SystemUpgrade then
            self.tooltip = item.tooltip
        elseif item.itemType == InventoryItemType.VanillaItem then
            self.tooltip = makeVanillaItemTooltip(item)
        elseif item.itemType == InventoryItemType.UsableItem then
            self.tooltip = makeUsableItemTooltip(item)
        end
    end

    return self.tooltip
end

function SellableInventoryItem:getPrice()
    local item = self.item
    local value = 0

    if item.itemType == InventoryItemType.Turret or item.itemType == InventoryItemType.TurretTemplate then
        return round(ArmedObjectPrice(item))

    elseif item.itemType == InventoryItemType.SystemUpgrade then
        value = item.price

    elseif item.itemType == InventoryItemType.VanillaItem
        or item.itemType == InventoryItemType.UsableItem then
        value = item.price
    end

    return value
end

function SellableInventoryItem:getName()
    local item = self.item
    local name = ""

    if item.itemType == InventoryItemType.Turret or item.itemType == InventoryItemType.TurretTemplate then
        if onClient() then
            local tooltip = self:getTooltip()
            return tooltip:getLine(0).ctext
        else
            return "Turret"%_t;
        end

    elseif item.itemType == InventoryItemType.SystemUpgrade then
        return item.name
    elseif item.itemType == InventoryItemType.VanillaItem
        or item.itemType == InventoryItemType.UsableItem then

        if onClient() then
            local tooltip = self:getTooltip()
            return tooltip:getLine(0).ctext
        end

        return item.name
    end

    return name
end

function SellableInventoryItem:getRelationChangeType()
    local item = self.item

    if item.itemType == InventoryItemType.Turret or item.itemType == InventoryItemType.TurretTemplate then
        if item.armed then
            return RelationChangeType.WeaponsTrade
        end

        return RelationChangeType.EquipmentTrade
    elseif item.itemType == InventoryItemType.SystemUpgrade then

        if item.script == "data/scripts/systems/militarytcs.lua" then
            return RelationChangeType.WeaponsTrade
        end

        return RelationChangeType.EquipmentTrade
    elseif item.itemType == InventoryItemType.VanillaItem
            or item.itemType == InventoryItemType.UsableItem then

        return RelationChangeType.EquipmentTrade
    end

    return RelationChangeType.Commerce
end

function SellableInventoryItem:canBeBought(player, ai)
    local relation = player:getRelation(ai.index)
    local relationChange = self:getRelationChangeType()

    if relation.status == RelationStatus.War then
        -- nothing can be bought during war times
        return false, "You cannot buy items from a faction while at war."%_T, {}
    elseif relation.status == RelationStatus.Allies then
        -- once you're allied you can buy anything
        return true
    end

    if relation.level < -30000 then
        return false, "You cannot buy equipment while relations are 'Bad' or 'Hostile'. /* 'Bad' & 'Hostile' must be the names of the relation statuses */"%_T, {}
    end

    if self.item.rarity.value >= RarityType.Exotic then
        return false, "You must be allied with the faction to buy 'Exotic' or better equipment. /* 'Exotic' must be the name of the Rarity */"%_T, {}
    end

    if relationChange == RelationChangeType.WeaponsTrade then
        if relation.status == RelationStatus.Ceasefire then
            return false, "You cannot buy military equipment during a ceasefire. /* 'Ceasefire' must be the name of the relation status */"%_T, {}
        end

        if relation.level < 30000 then
            if self.item.rarity.value >= RarityType.Rare then
                return false, "Relations must be at least 'Good' to buy 'Rare' or better military equipment. /* 'Good' and 'Rare' must be the names of the Relation status and Rarity */"%_T, {}
            end
        end

        if relation.level < 80000 then
            if self.item.rarity.value >= RarityType.Exceptional then
                return false, "Relations must be at least 'Excellent' to buy 'Exceptional' or better military equipment. /* 'Excellent' and 'Exotic' must be the names of the Relation status and Rarity */"%_T, {}
            end
        end
    else
        if relation.level < 30000 then
            if self.item.rarity.value >= RarityType.Exceptional then
                return false, "Relations must be at least 'Good' to buy 'Exceptional' or better equipment. /* 'Good' and 'Exceptional' must be the names of the Relation status and Rarity */"%_T, {}
            end
        end
    end


    return true
end

function SellableInventoryItem:boughtByPlayer(ship, amount)
    amount = amount or 1

    local faction = Faction(ship.factionIndex)

    if faction then
        local inventory = faction:getInventory()
        if self.item.stackable then
            -- item is stackable, so if there is one suitable slot all amount items will fit
            if not inventory:hasSlot(self.item) then
                return "Your inventory is full (%1%/%2%)."%_T, {inventory.occupiedSlots, inventory.maxSlots}
            end
        else
            -- item is not stackable, each item needs its own slot
            if inventory.maxSlots > 0 and inventory.occupiedSlots + amount > inventory.maxSlots then
                return "Your inventory is full (%1%/%2%)."%_T, {inventory.occupiedSlots, inventory.maxSlots}
            end
        end

        for _ = 1, amount do
            inventory:addOrDrop(self.item)
        end
    end
end

function SellableInventoryItem:soldByPlayer(ship)

    local faction = Faction(ship.factionIndex)
    if not faction then return end

    local item = faction:getInventory():take(self.index)
    if item == nil then
        return "Item to sell not found", {}
    end

end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})


