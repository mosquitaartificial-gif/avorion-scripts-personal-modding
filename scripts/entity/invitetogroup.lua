package.path = package.path .. ";data/scripts/lib/?.lua"

include ("stringutility")
include ("callable")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace InviteToGroup
InviteToGroup = {}

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function InviteToGroup.interactionPossible(playerIndex, option)
    local self = Entity()

    local faction = Faction()
    if not faction then return end

    if faction.isAIFaction then return false end

    -- inviting self should not be possible
    if self.factionIndex == playerIndex then return false end

    return true
end

-- create all required UI elements for the client side
function InviteToGroup.initUI()
    ScriptUI():registerInteraction("Invite to Group"%_t, "invite", 2)
end

function InviteToGroup.invite()
    if onClient() then
        invokeServerFunction("invite")
        return
    end

    local self = Entity()
    local player = Player(callingPlayer)
    local pilot = self:getPilotIndices()

    if not pilot then
        player:sendChatMessage("", ChatMessageType.Error, "No player is flying this ship."%_t)
        return
    end

    Server():addChatCommand(player, "/invite " .. pilot)
end
callable(InviteToGroup, "invite")
