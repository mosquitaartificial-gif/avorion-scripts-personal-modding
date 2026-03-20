-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace DeleteOnPlayersLeft
DeleteOnPlayersLeft = {}

if onServer() then

function DeleteOnPlayersLeft.initialize()
    Sector():registerCallback("onPlayerLeft", "updateDeletion")
end

function DeleteOnPlayersLeft.onSectorChanged()
    Sector():registerCallback("onPlayerLeft", "updateDeletion")
end

function DeleteOnPlayersLeft.updateDeletion()
    if Sector().numPlayers == 0 then
        Sector():deleteEntity(Entity())
    end
end

end
