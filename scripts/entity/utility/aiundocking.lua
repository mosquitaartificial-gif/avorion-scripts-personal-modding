package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")
include("relations")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace AIAutoUndocking
AIAutoUndocking = {}

if onServer() then

function AIAutoUndocking.getUpdateInterval()
    return 1
end

function AIAutoUndocking.initialize()
    local self = Entity()
    if self.playerOwned or self.allianceOwned then
        terminate()
        return
    end

    self:registerCallback("onDockedByEntity", "onDockedByEntity")
end

function AIAutoUndocking.onDockedByEntity(ownId, id)

    local self = Entity()
    if self.playerOwned or self.allianceOwned then
        terminate()
        return
    end

    local parent = Entity(id)
    if not valid(parent) then return end

    -- don't immediately undock from same faction
    if parent.factionIndex == self.factionIndex then return end

    local parent = DockingClamps(id)
    if not valid(parent) then return end

    local messages = {
        "Stop that!"%_T,
        "What do you think you're doing?"%_T,
        "We did not give you docking permissions!"%_T,
        "Leave us alone!"%_T,
        "This is illegal!"%_T,
    }

    Sector():broadcastChatMessage(self, ChatMessageType.Chatter, randomEntry(messages))
    changeRelations(self, id, -2500, RelationChangeType.GeneralIllegal, true, true)

    parent:undock(self)
end

function AIAutoUndocking.update()
    local self = Entity()
    if self.playerOwned or self.allianceOwned then
        terminate()
        return
    end

    local parentId = self.dockingParent
    if parentId then
        local parent = DockingClamps(parentId)
        if valid(parent) then
            -- don't immediately undock from same faction
            if Entity(parentId).factionIndex == self.factionIndex then return end

            parent:undock(self)
        end
    end
end

end
