package.path = package.path .. ";data/scripts/lib/?.lua"

include ("stringutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace ExitCraft
ExitCraft = {}

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function ExitCraft.interactionPossible(playerIndex, option)
    local self = Entity()
    local player = Player(playerIndex)

    local craft = player.craft
    if craft == nil then return false end

    -- players can only exit their own craft
    if craft.index == self.index then
        return true
    end

    return false
end

function ExitCraft.initUI()
    ScriptUI():registerInteraction("Exit Into Drone"%_t, "onExitCraft", -1);
end

function ExitCraft.getIcon()
    return "data/textures/icons/drone.png"
end

function ExitCraft.onExitCraft()
    local player = Player()
    if player then
        player.craftIndex = Uuid()
    end
end

