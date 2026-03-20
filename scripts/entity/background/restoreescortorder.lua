package.path = package.path .. ";data/scripts/lib/?.lua"
include ("utility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace RestoreEscortOrder
RestoreEscortOrder = {}

if onServer() then

RestoreEscortOrder.maxWaitTicks = 10

local data = {}

function RestoreEscortOrder.initialize(id, factionIndex, name)
    data.id = Uuid(id)
    data.factionIndex = factionIndex
    data.name = name
end

local tries = 0
function RestoreEscortOrder.update()
    tries = tries + 1

    if tries > RestoreEscortOrder.maxWaitTicks then
        terminate()
        return
    end

    local target = Sector():getEntity(data.id)
    if not target and data.factionIndex and data.name then
        target = Sector():getEntityByFactionAndName(data.factionIndex, data.name)
    end

    if target then
        Entity():invokeFunction("entity/orderchain.lua", "onUserEscortOrder", target.id)
        terminate()
    end
end

end -- onServer
