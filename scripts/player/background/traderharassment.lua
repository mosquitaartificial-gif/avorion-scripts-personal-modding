package.path = package.path .. ";data/scripts/lib/?.lua"

include ("galaxy")
include ("stringutility")
include ("randomext")
include ("callable")
include ("relations")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace ControlTraders
ControlTraders = {}

local data = {}
data.wronglyAccusedCounter = 0

-- threshold at which defenders actively attack player
-- this threshold only counts wrongly accused ships
-- at threshold - 1 the player gets a chat message with a warning
local defenderTakeActionThreshold = 5

if onServer() then

function ControlTraders.initialize()
    local player = Player()
    player:registerCallback("onTraderScanned", "onTraderScanned")

    player:registerCallback("onSectorLeft", "onSectorLeft")
end

function ControlTraders.onSectorLeft()
    -- reset counter so that player has no long-lasting negative consequences from this
    data.wronglyAccusedCounter = 0
end


local defendersAggressive
function ControlTraders.onTraderScanned(entityId, bribe)
    if bribe == 0 then
        data.wronglyAccusedCounter = data.wronglyAccusedCounter + 1
    end

    if data.wronglyAccusedCounter == defenderTakeActionThreshold - 1 then
        -- NPC warn player
        for _, defender in pairs(ControlTraders.getDefenders()) do
            if defender then
                Player():sendChatMessage(defender, ChatMessageType.Normal, "Stop harassing traders or we will take action against you!"%_t)
                break
            end
        end
    elseif data.wronglyAccusedCounter >= defenderTakeActionThreshold and not defendersAggressive then
        -- NPCs start attacking
        ControlTraders.setAggressive(ControlTraders.getDefenders())
        defendersAggressive = true
    end
end

function ControlTraders.setAggressive(defenders)
    local craft = Player().craft
    if not craft then return end

    for _, defender in pairs(defenders) do
        if defender then
            ShipAI(defender.id):registerEnemyEntity(craft.id)
        end
    end
end

function ControlTraders.getDefenders()
    return {Sector():getEntitiesByScriptValue("is_defender")}
end

end
