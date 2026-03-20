package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local Diplomacy = include("player/ui/diplomacy")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace AllianceDiplomacy
AllianceDiplomacy = Diplomacy.CreateNamespace()

AllianceDiplomacy.instance.isAttachedToAlliance = true

if onServer() then

function AllianceDiplomacy.instance.getUserFaction()
--    print("AllianceDiplomacy: get user faction [server]")
    local player = Player(callingPlayer)
    if not player then return end

    -- return the interacting player as well
    return player.alliance, player
end

else

function AllianceDiplomacy.instance.getUserFaction()
--    print("AllianceDiplomacy: get user faction [client]")
    local player = Player()
    if not player then return end

    return player.alliance, player
end

function AllianceDiplomacy.instance.getParentWindow()
--    print("AllianceDiplomacy: get parent window")
    return AllianceTab()
end

end
