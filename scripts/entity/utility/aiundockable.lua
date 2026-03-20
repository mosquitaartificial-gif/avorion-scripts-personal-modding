-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace AIUndockable
AIUndockable = {}

if onServer() then

function AIUndockable.getUpdateInterval()
    return 1
end

function AIUndockable.initialize()
    local self = Entity()
    if self.playerOwned or self.allianceOwned then
        self.dockable = true
        terminate()
        return
    end

    self:registerCallback("onDockedByEntity", "onDockedByEntity")
    self.dockable = false
end

function AIUndockable.onDockedByEntity(ownId, id)

    local self = Entity()
    if self.playerOwned or self.allianceOwned then
        self.dockable = true
        terminate()
        return
    end

    local parent = DockingClamps(id)
    if not valid(parent) then return end

    parent:undock(self)
end

function AIUndockable.update()
    local self = Entity()
    if self.playerOwned or self.allianceOwned then
        self.dockable = true
        terminate()
        return
    end

    local parentId = self.dockingParent
    if parentId then
        local parent = DockingClamps(parentId)
        if valid(parent) then
            parent:undock(self)
        end
    end
end

end
