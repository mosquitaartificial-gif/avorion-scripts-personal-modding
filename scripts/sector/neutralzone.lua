
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("stringutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace NeutralZone
NeutralZone = {}

if onServer() then

function NeutralZone.initialize()
    Sector():registerCallback("onPlayerArrivalConfirmed", "onPlayerArrivalConfirmed")
    Sector().pvpDamage = 0
    Sector():setValue("neutral_zone", 1)

    Sector():removeScript("data/scripts/sector/factionwar/initfactionwar.lua")
end

function NeutralZone.onPlayerArrivalConfirmed(playerIndex)
    local player = Player(playerIndex)
    local msg = "You have entered a neutral zone. Player to player damage is disabled in this sector."%_T

    player:sendChatMessage("", 3, msg)
end

end
