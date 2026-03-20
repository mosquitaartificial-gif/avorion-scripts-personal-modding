package.path = package.path .. ";data/scripts/lib/?.lua"
include ("sellableinventoryitem")

local SellableFighterItem = {}
SellableFighterItem.__index = SellableFighterItem

local function new(fighter, index, player)
    local obj = setmetatable({fighter = fighter, item = fighter, index = index}, SellableFighterItem)

    -- initialize the item
    obj.price = obj:getPrice()
    obj.rarity = obj.fighter.rarity
    obj.material = obj.fighter.material
    obj.tech = obj:getTech()

    if fighter.type == FighterType.CrewShuttle then
        obj.name = "Boarding Shuttle"%_t
        obj.icon = "data/textures/icons/crew.png"
    elseif fighter.type == FighterType.Fighter then
        obj.name = "${weaponPrefix} Fighter"%_t % {weaponPrefix = (obj.fighter.weaponPrefix .. " /* Weapon Prefix*/") % _t}
        obj.icon = obj.fighter.weaponIcon
    end

    if player and index then
        obj.amount = player:getInventory():amount(index)
    elseif index and type(index) == "number" then
        obj.amount = index
    else
        obj.amount = 1
    end

    return obj
end

function SellableFighterItem:getTooltip()

    if self.tooltip == nil then
        self.tooltip = makeFighterTooltip(self.fighter)
    end

    return self.tooltip
end

function SellableFighterItem:getName()
    return self.name
end

function SellableFighterItem:getPrice()
    return FighterPrice(self.fighter)
end

function SellableFighterItem:getTech()
    local result = round(self.fighter.averageTech, 1)
    if result > 0 then
        return result
    end
end

function SellableFighterItem:getRelationChangeType()
    if self.fighter.armed then
        return RelationChangeType.WeaponsTrade
    end

    return RelationChangeType.EquipmentTrade
end

function SellableFighterItem:canBeBought(player, ai)
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
        return false, "You cannot buy fighters while relations are 'Bad' or 'Hostile'. /* 'Bad' & 'Hostile' must be the names of the relation statuses */"%_T, {}
    end

    if self.fighter.rarity.value >= RarityType.Exotic then
        return false, "You must be allied with the faction to buy 'Exotic' or better fighters. /* 'Exotic' must be the name of the Rarity */"%_T, {}
    end

    if relationChange == RelationChangeType.WeaponsTrade then
        if relation.status == RelationStatus.Ceasefire then
            return false, "You cannot buy military fighters during a ceasefire. /* 'Ceasefire' must be the name of the relation status */"%_T, {}
        end

        if relation.level < 30000 then
            if self.fighter.rarity.value >= RarityType.Rare then
                return false, "Relations must be at least 'Good' to buy 'Rare' or better fighters. /* 'Good' and 'Rare' must be the names of the Relation status and Rarity */"%_T, {}
            end
        end

        if relation.level < 80000 then
            if self.fighter.rarity.value >= RarityType.Exceptional then
                return false, "Relations must be at least 'Excellent' to buy 'Exceptional' or better military fighters. /* 'Excellent' and 'Exotic' must be the names of the Relation status and Rarity */"%_T, {}
            end
        end
    else
        if relation.level < 30000 then
            if self.fighter.rarity.value >= RarityType.Exceptional then
                return false, "Relations must be at least 'Good' to buy 'Exceptional' or better equipment. /* 'Good' and 'Exceptional' must be the names of the Relation status and Rarity */"%_T, {}
            end
        end
    end

    return true
end

function SellableFighterItem:boughtByPlayer(ship, amount)
    amount = amount or 1

    local hangar = Hangar(ship.index)

    if not hangar then
        return "Your ship doesn't have a hangar."%_t, {}
    end

    -- check if there is enough space in ship
    if hangar.freeSpace < self.fighter.volume * amount then
        return "You don't have enough space in your hangar."%_t, {}
    end

    -- find a squad that has space for a fighter
    local squads = {hangar:getSquads()}

    local typeMatches = true

    local squad
    for _, i in pairs(squads) do
        local fighters = hangar:getSquadFighters(i)
        local free = hangar:getSquadFreeSlots(i)

        if free >= amount then
            if hangar:fighterTypeMatchesSquad(self.fighter, i) then
                squad = i
                break
            else
                typeMatches = false
            end
        end
    end

    if squad == nil then
        -- try to add a new squad
        squad = hangar:addSquad("New Squad"%_t)

        -- check if it was successful
        if squad >= hangar.maxSquads then squad = nil end
    end

    if squad == nil then
        if typeMatches then
            return "There is no free squad to place the fighter in."%_t, {}
        else
            return "There is no squad with the correct type to place the fighter in."%_t, {}
        end
    end

    for _ = 1, amount do
        hangar:addFighter(squad, self.fighter)
    end
end

function SellableFighterItem:soldByPlayer(ship)

    local hangar = Hangar(ship.index)

    if not hangar then
        return "Your ship doesn't have a hangar."%_t, {}
    end

    self.fighter = hangar:getFighter(self.squadIndex, self.fighterIndex)

    if self.fighter == nil then
        return "Fighter to sell not found."%_t, {}
    end

    local price = FighterPrice(fighter) / 8.0
    hangar:removeFighter(self.squadIndex, self.fighterIndex)

end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
