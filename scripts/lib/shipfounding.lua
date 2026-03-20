
local ShipFounding = {}

ShipFounding.costs = {}
local costs = ShipFounding.costs

costs[00] = {material = Material(MaterialType.Iron)}
costs[01] = {material = Material(MaterialType.Iron)}
costs[02] = {material = Material(MaterialType.Iron)}
costs[03] = {material = Material(MaterialType.Titanium)}
costs[04] = {material = Material(MaterialType.Titanium)}
costs[05] = {material = Material(MaterialType.Titanium)}
costs[06] = {material = Material(MaterialType.Titanium)}
costs[07] = {material = Material(MaterialType.Naonite)}
costs[08] = {material = Material(MaterialType.Naonite)}
costs[09] = {material = Material(MaterialType.Naonite)}
costs[10] = {material = Material(MaterialType.Naonite)}
costs[11] = {material = Material(MaterialType.Trinium)}
costs[12] = {material = Material(MaterialType.Trinium)}
costs[13] = {material = Material(MaterialType.Trinium)}
costs[14] = {material = Material(MaterialType.Trinium)}
costs[15] = {material = Material(MaterialType.Xanion)}
costs[16] = {material = Material(MaterialType.Xanion)}
costs[17] = {material = Material(MaterialType.Xanion)}
costs[18] = {material = Material(MaterialType.Xanion)}
costs[19] = {material = Material(MaterialType.Ogonite)}
costs[20] = {material = Material(MaterialType.Ogonite)}
costs[21] = {material = Material(MaterialType.Ogonite)}
costs[22] = {material = Material(MaterialType.Ogonite)}
costs[23] = {material = Material(MaterialType.Avorion)}
costs[24] = {material = Material(MaterialType.Avorion)}

function ShipFounding.getCosts(ships)
    local resources = {}

    for i = 0, MaterialType.Avorion do
        resources[i+1] = 0
    end

    local highest = 24

    if ships <= highest then
        resources[costs[ships].material.value+1] = 500
    else
        resources[MaterialType.Avorion+1] = 500
    end

    return resources, ships
end

function ShipFounding.getNextShipCosts(faction)

    if faction.isAlliance then
        faction = Alliance(faction.index)
    elseif faction.isPlayer then
        faction = Player(faction.index)
    end

    -- count number of ships
    local ships = 0
    for _, name in pairs({faction:getShipNames()}) do
        if faction:getShipType(name) == EntityType.Ship then
            ships = ships + 1
        end
    end

    return ShipFounding.getCosts(ships)
end

return ShipFounding
