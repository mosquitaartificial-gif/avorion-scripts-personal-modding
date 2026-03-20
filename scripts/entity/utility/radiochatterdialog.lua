package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace EntityRadioChatterDialog
EntityRadioChatterDialog = {}
local self = EntityRadioChatterDialog

local data = {}

if onServer() then

self.dialog = nil
self.dialogIndex = 1

function EntityRadioChatterDialog.getUpdateInterval()
    if self.dialog then
        return 8 + random():getInt(5)
    end

    return 180 + random():getInt(150)
end

function EntityRadioChatterDialog.initialize(lines)
    if not _restoring then
        data = lines
    end
end


function EntityRadioChatterDialog.update(timeStep)

    if not self.dialog then
        local messages = randomEntry(random(), data)
        if messages then
            self.dialog = messages
            self.dialogIndex = 1
        else
            eprint("Dialog table without texts found")
            return
        end
    end

    if self.dialogIndex <= #self.dialog then

        local sender = Entity(self.dialog[self.dialogIndex].id) or Entity()

        if sender then
            local msg = self.dialog[self.dialogIndex].text
            Sector():broadcastChatMessage(sender, ChatMessageType.Chatter, msg)
        end

        self.dialogIndex = self.dialogIndex + 1
    else
        self.dialogIndex = 1
        self.dialog = nil
    end

end

function EntityRadioChatterDialog.secure()
    return data
end

function EntityRadioChatterDialog.restore(data_in)
    data = data_in
end

end
