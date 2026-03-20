package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("galaxy")
include ("utility")
include ("goods")
include ("tooltipmaker")
include ("relations")
include ("inventoryitemprice")

local RiftMissionUT = include("dlc/rift/lib/riftmissionutility")

local TradeableResearchDataItem = {}
TradeableResearchDataItem.__index = TradeableResearchDataItem

-- during a rift run with max possible scientist captain a player can collect up to 35 data goods on average
-- (this assumes that we spawn ~50 Xsotan with a drop chance of 10%, and the player has a fully leveled scientist on board the whole time)
-- 50 * 0.1 * 3 = 15: a scientist makes Xsotan drop 3 goods instead of 1
-- 15 * 60 / 45 = 20: a fully leveled tier 3 scientist generates research data every 45s for 15 min (80s - (3 + 4) * 5s = 45s)
local prices = {}
prices[RarityType.Petty] = 15
prices[RarityType.Common] = 30
prices[RarityType.Uncommon] = 40
prices[RarityType.Rare] = 125
prices[RarityType.Exceptional] = 250
prices[RarityType.Exotic] = 400
prices[RarityType.Legendary] = 750

-- reduced prices used for non-combination subspace distortion protection subsystems
local protectionPrices = {}
protectionPrices[RarityType.Petty] = 2
protectionPrices[RarityType.Common] = 5
protectionPrices[RarityType.Uncommon] = 10
protectionPrices[RarityType.Rare] = 20
protectionPrices[RarityType.Exceptional] = 40
protectionPrices[RarityType.Exotic] = 80
protectionPrices[RarityType.Legendary] = 160

local function new(item, index, owner)
    local obj = setmetatable({item = item, index = index}, TradeableResearchDataItem)

    -- initialize the item
    obj.price = 0
    obj.name = item.name
    obj.rarity = obj.item.rarity
    obj.material = obj:getMaterial()
    obj.icon = obj:getIcon()
    obj.tech = obj:getTech()
    obj.sellable = obj:getSellable()
    obj.good = "Rift Research Data"

    -- basic protection items get reduced prices
    if item.script == "internal/dlc/rift/systems/independentsubspacedistortionprotection.lua" then
        obj.goodsPrice = protectionPrices[obj.rarity.value] or 100
    else
        obj.goodsPrice = prices[obj.rarity.value] or 100
    end

    obj.displayedPrice = createMonetaryString(obj.goodsPrice)

    if owner and index then
        obj.amount = owner:getInventory():amount(index)
    elseif index and type(index) == "number" then
        obj.amount = index
    else
        obj.amount = 1
    end

    return obj
end

function TradeableResearchDataItem:getMaterial()
    local item = self.item

    if item.itemType == InventoryItemType.Turret or item.itemType == InventoryItemType.TurretTemplate then
        return item.material
    end
end

function TradeableResearchDataItem:getIcon()
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

function TradeableResearchDataItem:getSellable()
    local item = self.item

    if item.itemType == InventoryItemType.VanillaItem or item.itemType == InventoryItemType.UsableItem then
        if item:getValue("unsellable") then
            return false
        end
    end

    return true
end

function TradeableResearchDataItem:getTech()
    local item = self.item

    if item.itemType == InventoryItemType.Turret or item.itemType == InventoryItemType.TurretTemplate then
        return round(item.averageTech, 1)
    end
end

function TradeableResearchDataItem:getTooltip()
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

function TradeableResearchDataItem:getName()
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

function TradeableResearchDataItem:getRelationChangeType()
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

function TradeableResearchDataItem:canBeBought(player, ai)
    return true
end

function TradeableResearchDataItem:boughtByPlayer(ship, amount)
    amount = amount or 1

    local good = RiftMissionUT.getRiftDataGood()

    local cargoBay = CargoBay(ship)
    if not cargoBay then
        return "You need at least %1% %2%."%_T, {createMonetaryString(self.goodsPrice), good:displayName(self.goodsPrice)}
    end

    local amountOnShip = cargoBay:getNumCargos(good)
    if amountOnShip < self.goodsPrice then
        return "You need at least %1% %2%."%_T, {createMonetaryString(self.goodsPrice), good:displayName(self.goodsPrice)}
    end

    cargoBay:removeCargo(good, self.goodsPrice)

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

function TradeableResearchDataItem:soldByPlayer(ship)

    local faction = Faction(ship.factionIndex)
    if not faction then return end

    local item = faction:getInventory():take(self.index)
    if item == nil then
        return "Item to sell not found"%_T, {}
    end

end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})


