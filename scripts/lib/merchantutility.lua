package.path = package.path .. ";data/scripts/lib/?.lua"
include("stringutility")
include("utility")
include("randomext")

function receiveTransactionTax(station, amount)
    if not amount then return end
    amount = round(amount)
    if amount == 0 then return end

    local stationOwner = Faction(station.factionIndex)
    local x, y = Sector():getCoordinates()

    if stationOwner then
        local msg = Format("\\s(%1%:%2%) %3%: Gained %4% Credits transaction tax."%_T,
            x,
            y,
            station.title)

        stationOwner:receive(msg, amount)
    end
end

function factionReceiveTransactionTax(faction, amount)
    if not amount then return end
    amount = round(amount)
    if amount == 0 then return end

    local x, y = Sector():getCoordinates()

    if faction then
        local msg = Format("\\s(%1%:%2%) %3%: Gained %4% Credits transaction tax."%_T,
            x,
            y,
            faction.name)

        faction:receive(msg, amount)
    end
end

function isPlayerAndTheirAlliance(a, b)
    if type(a) == "number" then a = Faction(a) end
    if type(b) == "number" then b = Faction(b) end

    local player, allianceIndex
    if a.isPlayer then player = Player(a.index)
    elseif b.isPlayer then player = Player(b.index) end

    if a.isAlliance then allianceIndex = a.index
    elseif b.isAlliance then allianceIndex = b.index end

    return (player and player.allianceIndex and player.allianceIndex == allianceIndex)
end

function getMaterialBuyingPriceFactor(stationFaction, orderingFactionIndex)

    if isPlayerAndTheirAlliance(stationFaction, orderingFactionIndex) then return 1 end
    if orderingFactionIndex == stationFaction.index then return 1 end

    local percentage = 1;
    local relation = stationFaction:getRelations(orderingFactionIndex)

    -- 1.5 at relation = 0
    -- 1.05 at relation = 100000
    if relation >= 0 then
        percentage = lerp(relation, 0, 100000, 1.5, 1.05)
    end

    -- 1.5 at relation = 0
    -- 2.0 at relation = -10000
    -- 2.0 at relation < -10000
    if relation < 0 then
        percentage = lerp(relation, -10000, 0, 2, 1.5)
    end

    return percentage
end

function getMaterialSellingPriceFactor(stationFaction, orderingFactionIndex)

    if isPlayerAndTheirAlliance(stationFaction, orderingFactionIndex) then return 1 end
    if orderingFactionIndex == stationFaction.index then return 1 end

    local percentage = 1;
    local relation = stationFaction:getRelations(orderingFactionIndex)

    -- 0.5 at relation = 0
    -- 0.8 at relation = 100000
    if relation >= 0 then
        percentage = lerp(relation, 0, 100000, 0.75, 0.95)
    end

    -- 0.75 at relation = 0
    -- 0.5 at relation <= -10000
    if relation < 0 then
        percentage = lerp(relation, -10000, 0, 0.5, 0.75);
    end

    return percentage
end

function getRefineTaxFactor(stationFactionIndex, customerFaction)
    if stationFactionIndex == customerFaction.index then return 0 end
    return lerp(customerFaction:getRelations(stationFactionIndex), -25000, 100000, 0.1, 0.01)
end
