-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace DeleteOnMissionOver
DeleteOnMissionOver = {}

local data = {}

if onServer() then

function DeleteOnMissionOver.initialize(script, playerIndex)
    if not _restoring then
        data.script = script
        data.playerIndex = playerIndex

        DeleteOnMissionOver.updateDeletion()
    end

    Sector():registerCallback("onPlayerLeft", "updateDeletion")
end

function DeleteOnMissionOver.onSectorChanged()
    Sector():registerCallback("onPlayerLeft", "updateDeletion")
end

function DeleteOnMissionOver.updateDeletion()
    if not data.script or not data.playerIndex then
        terminate()
        return
    end

    if Sector().numPlayers > 0 then return end

    local player = Player(data.playerIndex)
    if not player then -- no player -> no assumptions can be made
        terminate()
        return
    end

    if not player:hasScript(data.script) then
        Sector():deleteEntity(Entity())
    end
end

function DeleteOnMissionOver.secure()
    return data
end

function DeleteOnMissionOver.restore(data_in)
    data = data_in

    DeleteOnMissionOver.updateDeletion()
end

end
