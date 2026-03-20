
package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")
include("stringutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace HomeSectorRelations
HomeSectorRelations = {}

local hx, hy
local startAlly

if onServer() then

function HomeSectorRelations.initialize()
    local player = Player()
    startAlly = player:getValue("start_ally")

    if startAlly then
        local ally = Faction(startAlly)
        if ally then
            player:registerCallback("onMoveToReconstructionSite", "onMoveToReconstructionSite")
            hx, hy = player:getHomeSectorCoordinates()
        end
    end

end

function HomeSectorRelations.onMoveToReconstructionSite(playerIndex)

    local player = Player()
    local x, y = player:getReconstructionSiteCoordinates()
    if x == hx and y == hy then
        if player:getRelationStatus(startAlly) == RelationStatus.War then
            local ally = Faction(startAlly)
            Galaxy():setFactionRelationStatus(player, ally, RelationStatus.Ceasefire, true, true)

            local money = player.money
            local resources = {player:getResources()}

            money = money * 0.15
            for m, amount in pairs(resources) do
                resources[m] = amount * 0.15
            end

            player:pay(money, unpack(resources))

            local mail = Mail()
            mail.header = "Ceasefire Conditions /* Mail Subject */"%_T
            mail.sender = ally.name
            mail.text = "To the Troublemaker:\n\nWe cannot tolerate your actions against us but we hope that if we give you another chance, you will come back to your senses. Therefore, we reconstructed your drone in your home sector and offer you a ceasefire.\nFor this generous offer, we took the liberty to charge you a compensation payment of 15% of your money and resources. We hope that these troubles can be avoided in the future."%_T
            player:addMail(mail)

        end
    end

end

end
