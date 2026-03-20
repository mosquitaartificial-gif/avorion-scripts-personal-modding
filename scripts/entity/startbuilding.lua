package.path = package.path .. ";data/scripts/lib/?.lua"

include ("stringutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace StartBuilding
StartBuilding = {}

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function StartBuilding.interactionPossible(playerIndex, option)
    if checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ModifyCrafts, AlliancePrivilege.SpendResources) then
        return true
    end

    return false
end

function StartBuilding.initUI()
    ScriptUI():registerInteraction("Build"%_t, "onBuildPressed", -1);
end

function StartBuilding.onBuildPressed()

    local ok, error = Player():buildingAllowed(Entity())
    if not ok then
        displayChatMessage(error, "", 1)
        return
    end

    Player():startBuilding(Entity())
end

