package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
package.path = package.path .. ";?"

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace DeleteEntitiesOnPlayersLeft
DeleteEntitiesOnPlayersLeft = {}
local data = {}

if onServer() then

function DeleteEntitiesOnPlayersLeft.initialize(entityTypes)
    data.entityTypes = entityTypes or {}

    Sector():registerCallback("onPlayerLeft", "updateDeletion")
end

function DeleteEntitiesOnPlayersLeft.updateDeletion(index, sectorChangeType) -- entites get deleted also when player logs out, because missions expect that behavior
    local sector = Sector()
    if sector.numPlayers ~= 0 then return end

    for _, entityType in pairs(data.entityTypes) do
        for _, entity in pairs({sector:getEntitiesByType(entityType)}) do
            if entity.playerOwned or entity.allianceOwned then goto continue end

            sector:deleteEntity(entity)

            ::continue::
        end
    end

    terminate()
end

function DeleteEntitiesOnPlayersLeft.secure()
    return data
end

function DeleteEntitiesOnPlayersLeft.restore(values)
    data = values
    data.entityTypes = data.entityTypes or {}
end

end
