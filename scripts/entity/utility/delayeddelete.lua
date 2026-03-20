-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace DelayedDelete
DelayedDelete = {}

if onServer() then

function DelayedDelete.initialize(time)
    local faction = Faction()
    if not faction or faction.isPlayer or faction.isAlliance then
        terminate()
        return
    end

    if time and not _restoring then
        DelayedDelete.time = time
        deferredCallback(time - 4.5, "delete") -- minus 4.5 because deletejumped.lua takes 4.5 seconds
    else
        eprint("DelayedDelete: time is nil")
        terminate()
    end
end

function DelayedDelete.delete()
    Entity():addScript("deletejumped.lua", 4.5)
end

function DelayedDelete.secure()
    return {time = DelayedDelete.time}
end

function DelayedDelete.restore(data)
    DelayedDelete.time = data.time
    deferredCallback(DelayedDelete.time - 4.5, "delete") -- minus 4.5 because deletejumped.lua takes 4.5 seconds
end

end
