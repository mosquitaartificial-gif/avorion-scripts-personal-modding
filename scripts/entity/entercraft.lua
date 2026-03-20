package.path = package.path .. ";data/scripts/lib/?.lua"

include ("stringutility")
include ("faction")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace EnterCraft
EnterCraft = {}

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function EnterCraft.interactionPossible(playerIndex, option)
    local self = Entity()

    if not checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FlyCrafts) then
        return false
    end

    -- players can't fly the craft they're currently in
    local player = Player(playerIndex)

    local craft = player.craft
    if craft == nil then
        return false
    end

    if craft.index == self.index then
        return false
    end

    return true
end

-- create all required UI elements for the client side
function EnterCraft.initUI()
    ScriptUI():registerInteraction("Enter"%_t, "onEnter", -1);
end

function EnterCraft.onEnter()
    if checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FlyCrafts) then
        Player().craftIndex = Entity().index
    end
end

