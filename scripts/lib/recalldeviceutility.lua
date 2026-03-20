package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("randomext")
include("utility")
local MissionUT = include("missionutility")

local RecallDeviceUT = {}
RecallDeviceUT.mailId = "recall_device_gift"

function RecallDeviceUT.hasRecallDevice(player)

    local items = player:getInventory():getItemsByType(InventoryItemType.UsableItem)
    for idx, slot in pairs(items) do
        local item = slot.item

        if item:getValue("subtype") == "RecallDevice"
                and item:getValue("playerIndex") == player.index then
            return true
        end
    end

    -- also check if there is a mail with the item still in it
    local mails = {player:getMailsById(RecallDeviceUT.mailId)}
    for _, mail in pairs(mails) do
        -- we're always sending the item in that mail, so we don't have to check the actual item
        if mail.numItems > 0 then
            return true
        end
    end

    return false
end

function RecallDeviceUT.qualifiesForRecallDevice(player)
    -- player qualifies when home sector and respawn sector differ
    local rx, ry = player:getReconstructionSiteCoordinates()
    local hx, hy = player:getHomeSectorCoordinates()
    if hx ~= rx or hy ~= ry then return true end

    -- player qualifies when some artifacts were found
    local foundArtifacts = MissionUT.detectFoundArtifacts(player)
    if tablelength(foundArtifacts) > 0 then return true end

    return false
end

function RecallDeviceUT.sendRecallDeviceMail(player)
    local mail = Mail()
    mail.text = Format("Hello!\n\nI found this strange Xsotan device. I'm not really sure what it does, and I think it might actually be broken. A first scan showed that it somehow interacts with subspace waves, like wormholes do. It also seems to resonate with hyperspace generators. It's definitely not the kind of thing I'm looking for, and I don't think it's particularly valuable. Anyway, I can't really make anything of it, but maybe you can?\n\nGreetings,\n%1%"%_T, MissionUT.getAdventurerName())
    mail.header = "Strange Xsotan Device..? /* Mail Subject */"%_T
    mail.sender = Format("%1%, the Adventurer"%_T, MissionUT.getAdventurerName())
    mail.id = RecallDeviceUT.mailId

    local device = UsableInventoryItem("data/scripts/items/recalldevice.lua", Rarity(RarityType.Legendary), player.index)
    mail:addItem(device)

    player:addMail(mail)
end

function RecallDeviceUT.sendFollowUpToHermitMail(player)
    local mail = Mail()
    mail.text = Format("Hello!\n\nSince we're already talking about artifacts, I just remembered: I found this strange Xsotan device.\n\nI'm not really sure what it does, and I think it might actually be broken. A first scan showed that it somehow interacts with subspace waves, like wormholes do. It also seems to resonate with hyperspace generators. It's definitely not the kind of thing I'm looking for, and I don't think it's particularly valuable. Anyway, I can't really make anything of it, but maybe you can?\n\nGreetings,\n%1%"%_T, MissionUT.getAdventurerName())
    mail.header = "Strange Xsotan Device..? /* Mail Subject */"%_T
    mail.sender = Format("%1%, the Adventurer"%_T, MissionUT.getAdventurerName())
    mail.id = RecallDeviceUT.mailId

    local device = UsableInventoryItem("data/scripts/items/recalldevice.lua", Rarity(RarityType.Legendary), player.index)
    mail:addItem(device)

    player:addMail(mail)
end

function RecallDeviceUT.dropRecallDevice()

end

return RecallDeviceUT
