package.path = package.path .. ";data/scripts/lib/?.lua"
include ("sellableinventoryitem")

local SellableTorpedoItem = {}
SellableTorpedoItem.__index = SellableTorpedoItem

local function new(torpedo, index, player)
    local obj = setmetatable({torpedo = torpedo, item = torpedo, index = index}, SellableTorpedoItem)

    -- initialize the item
    obj.price = obj:getPrice()
    obj.rarity = obj.torpedo.rarity

    obj.name = obj.torpedo.name%_t % {warhead = obj.torpedo.warheadClass%_t, speed = obj.torpedo.bodyClass%_t}
    obj.icon = obj.torpedo.icon
    obj.tech = obj:getTech()

    if player and index then
        obj.amount = player:getInventory():amount(index)
    elseif index and type(index) == "number" then
        obj.amount = index
    else
        obj.amount = 1
    end

    return obj
end

function SellableTorpedoItem:getTooltip()

    if self.tooltip == nil then
        self.tooltip = makeTorpedoTooltip(self.torpedo)
    end

    return self.tooltip
end

function SellableTorpedoItem:getName()
    return self.name
end

function SellableTorpedoItem:getPrice()
    return TorpedoPrice(self.torpedo)
end

function SellableTorpedoItem:getRelationChangeType()
    return RelationChangeType.WeaponsTrade
end

function SellableTorpedoItem:getTech()
    return self.torpedo.tech
end

function SellableTorpedoItem:canBeBought(player, ai)
    local relation = player:getRelation(ai.index)
    local relationChange = self:getRelationChangeType()

    if relation.status == RelationStatus.War then
        -- nothing can be bought during war times
        return false, "You cannot buy torpedoes from a faction while at war."%_T, {}
    elseif relation.status == RelationStatus.Allies then
        -- once you're allied you can buy anything
        return true
    end

    if relation.level < -30000 then
        return false, "You cannot buy torpedoes while relations are 'Bad' or 'Hostile'. /* 'Bad' & 'Hostile' must be the names of the relation statuses */"%_T, {}
    end

    if self.torpedo.rarity.value >= RarityType.Exotic then
        return false, "You must be allied with the faction to buy 'Exotic' or better torpedoes. /* 'Exotic' must be the name of the Rarity */"%_T, {}
    end

    if relation.status == RelationStatus.Ceasefire then
        return false, "You cannot buy torpedoes during a ceasefire. /* 'Ceasefire' must be the name of the relation status */"%_T, {}
    end

    if relation.level < 30000 then
        if self.torpedo.rarity.value >= RarityType.Rare then
            return false, "Relations must be at least 'Good' to buy 'Rare' or better torpedoes. /* 'Good' and 'Rare' must be the names of the Relation status and Rarity */"%_T, {}
        end
    end

    if relation.level < 80000 then
        if self.torpedo.rarity.value >= RarityType.Exceptional then
            return false, "Relations must be at least 'Excellent' to buy 'Exceptional' or better torpedoes. /* 'Excellent' and 'Exotic' must be the names of the Relation status and Rarity */"%_T, {}
        end
    end

    return true
end


function SellableTorpedoItem:boughtByPlayer(ship, amount)
    amount = amount or 1

    local launcher = TorpedoLauncher(ship.index)

    if not launcher then
        return "Your ship doesn't have a torpedo launcher."%_t, {}
    end

    if self.torpedo.size * amount > launcher.freeStorage then
        return "Your ship doesn't have enough free torpedo storage."%_t, {}
    end

    for _ = 1, amount do
        launcher:addTorpedo(self.torpedo)
    end
end

function SellableTorpedoItem:soldByPlayer(ship)
    local launcher = TorpedoLauncher(ship.index)

    if not launcher then
        return "Your ship doesn't have a torpedo launcher."%_t, {}
    end

    self.torpedo = launcher:getTorpedo(self.shaftIndex, self.torpedoIndex)

    if self.torpedo == nil then
        return "Torpedo to sell not found."%_t, {}
    end

    local price = getTorpedoPrice(self.torpedo) / 8.0
    launcher:removeTorpedo(self.shaftIndex, self.torpedoIndex)
end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
