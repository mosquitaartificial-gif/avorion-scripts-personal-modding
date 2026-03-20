package.path = package.path .. ";data/scripts/lib/?.lua"

include ("stringutility")
include ("faction")
include ("callable")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace ClaimFromAlliance
ClaimFromAlliance = {}

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function ClaimFromAlliance.interactionPossible(playerIndex, option)

    if onClient() then
        return not Galaxy():factionExists(Entity().factionIndex)
    else
        return not Galaxy():findFaction(Entity().factionIndex)
    end
end

-- create all required UI elements for the client side
function ClaimFromAlliance.initUI()
    ScriptUI():registerInteraction("Claim"%_t, "onClaim", 5);
end

function ClaimFromAlliance.onClaim()
    invokeServerFunction("claim")
end

function ClaimFromAlliance.claim()
    if not ClaimFromAlliance.interactionPossible(callingPlayer) then return end

    local faction, ship, player = getInteractingFaction(callingPlayer)
    if not faction then return end

    local str = string.format("%s claimed a ship for faction %s", player.fullLogId, faction.fullLogId)
    print(str)
    printlog(str)

    Entity().factionIndex = faction.index

    terminate()
end
callable(ClaimFromAlliance, "claim")
