package.path = package.path .. ";data/scripts/lib/?.lua"

include ("stringutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace ShowShipWindow
ShowShipWindow = {}

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function ShowShipWindow.interactionPossible(playerIndex, option)
    local entity = Entity()

    if entity.factionIndex == playerIndex then
        return true
    end

    if not checkEntityInteractionPermissions(entity, AlliancePrivilege.ManageShips) then
        return false
    end

    return false
end

function ShowShipWindow.initUI()
    ScriptUI():registerInteraction("Manage"%_t, "onManagePressed", -1);
end

function ShowShipWindow.onManagePressed()
    ShipWindow():show(Entity().id)
end

