
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("randomext")
include ("galaxy")
include ("stringutility")
include ("faction")
include ("callable")

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function interactionPossible(playerIndex, option)

    local player = Player(playerIndex)
    local self = Entity()

    local craft = player.craft
    if craft == nil then return false end

    local dist = craft:getNearestDistance(self)

    if dist < 20.0 then
        return true
    end

    return false, "You're not close enough to open the object."%_t
end

function initialize()
    local entity = Entity()

    if entity.title == "" then entity.title = "Smuggler's Cache"%_t end

    entity:setValue("valuable_object", RarityType.Exceptional)
    entity.dockable = false
end

-- create all required UI elements for the client side
function initUI()
    ScriptUI():registerInteraction("Open"%_t, "startAlert", 5);
end

function startAlert()
    if onClient() then
        invokeServerFunction("startAlert")
        return
    end

    local sector = Sector()
    sector:broadcastChatMessage(Entity(), ChatMessageType.Chatter, "Alarm system initalized... Response forces will arrive soon..."%_T)
    sector:invokeFunction("data/scripts/events/waveencounters/hiddentreasurewaves.lua", "startEncounter")

    Entity():setValue("valuable_object", nil)
    terminate()
end
callable(nil, "startAlert")








