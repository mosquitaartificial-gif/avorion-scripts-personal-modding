package.path = package.path .. ";data/scripts/lib/?.lua"

local FactionsMap = include ("factionsmap")

-- this script adjusts all views to the new gate map
if onServer() then

function initialize()
    local parent = getParentFaction()
    if parent:getValue("gates2.0") then return end

    local factionsMap = FactionsMap(Server().seed)

    -- collect all map factions that we've got sector views of
    local factions = {}
    local views = {parent:getKnownSectors()}
    for _, view in pairs(views) do
        if factionsMap:exists(view.factionIndex) then
            factions[view.factionIndex] = true
        end
    end

    -- for each faction we get a map updater
    for factionIndex, _ in pairs(factions) do
        local item = UsableInventoryItem("data/scripts/items/gatemapupdate.lua", Rarity(RarityType.Exotic), parent.index, factionIndex, parent.isAlliance)
        parent:getInventory():add(item, true)
    end

    -- remember that the player/alliance got the update for 2.0 gate maps
    parent:setValue("gates2.0", true)

    terminate()
end

end
