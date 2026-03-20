
-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace LostShips
LostShips = {}

function LostShips.getUpdateInterval()
    return 5
end

function LostShips.updateServer()
    local faction = getParentFaction()
    local names = {faction:getShipNames()}
    local galaxy = Galaxy()

    for _, name in pairs(names) do
        local entry = ShipDatabaseEntry(faction.index, name)
        local x, y = entry:getCoordinates()

        if entry:getAvailability() == ShipAvailability.Available then
            if galaxy:sectorInRift(x, y) and not galaxy:sectorLoaded(x, y) then
                if entry:getScriptValue("left_in_rift") then
                    entry:setAvailability(ShipAvailability.Destroyed)
                    entry:setScriptValue("lost_in_rift", true)
                    entry:setScriptValue("left_in_rift", nil)

                    -- give turrets back as they'd be lost
                    if GameSettings().reconstructionAllowed then
                        local turrets = entry:getTurrets()
                        local inventory = faction:getInventory()

                        for turret, info in pairs(turrets) do
                            inventory:add(InventoryTurret(turret))
                        end
                    end
                else
                    if faction.isPlayer then
                        -- move ship to respawn site / same sector as player
                        entry:setCoordinates(Player(callingPlayer):getRespawnSiteCoordinates())
                    elseif faction.isAlliance then
                        -- alliance has no reconstruction site, use the first members' reconstruction site
                        local members = {faction:getMembers()}

                        -- an alliance is guaranteed to have at least 1 member
                        local first = nil
                        for _, playerIndex in pairs(members) do
                            if not first then
                                first = Player(playerIndex)
                                faction:sendChatMessage("", ChatMessageType.Normal, "The ship %1% has been moved to the reconstruction site of %2%."%_T, name, first.name)
                            end

                            local rx, ry = first:getReconstructionSiteCoordinates()
                            LostShips.sendTowedFromRiftMail(playerIndex, name, first.name, rx, ry)
                        end

                        entry:setCoordinates(first:getReconstructionSiteCoordinates())
                    end
                end
            end
        end
    end
end

function LostShips.sendTowedFromRiftMail(recipientPlayerIndex, shipName, reconstructionPlayerName, rx, ry)
    local recipient = Player(recipientPlayerIndex)

    local mail = Mail()
    mail.text = Format("Your alliance ship %1% mysteriously appeared near a rift right next to our towing crew. We brought it to the reconstruction site of %2% at (%3%:%4%)."%_T,
        shipName, reconstructionPlayerName, rx, ry)
    mail.header = "Pick up your ship! /* Mail Subject */"%_T
    mail.sender = "Reconstruction Site"%_T

    recipient:addMail(mail)
end
