package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local Diplomacy = include("player/ui/diplomacy")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace PlayerDiplomacy
PlayerDiplomacy = Diplomacy.CreateNamespace()

if onServer() then

function PlayerDiplomacy.instance.getUserFaction()
--    print("PlayerDiplomacy: get user faction [server]")
    local player = Player(callingPlayer)

    -- return the interacting player as well
    return player, player
end

else

function PlayerDiplomacy.instance.getUserFaction()
--    print("PlayerDiplomacy: get user faction [client]")
    local player = Player()
    return player, player
end

function PlayerDiplomacy.instance.getParentWindow()
--    print("PlayerDiplomacy: get parent window")
    return PlayerWindow()
end

end
