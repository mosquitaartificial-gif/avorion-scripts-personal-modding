package.path = package.path .. ";data/scripts/lib/?.lua"

include ("stringutility")
include ("faction")
include ("callable")
include ("utility")

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function interactionPossible(playerIndex, option)

    local player = Player(playerIndex)
    local self = Entity()

    local craft = player.craft
    if craft == nil then return false end

    local dist = craft:getNearestDistance(self)

    if dist > 20 then
        return false, "You are not close enough to claim the object!"%_t
    end

    if self.factionIndex ~= 0 then
        return false
    end

    return true
end

function initialize()
    Entity():setValue("valuable_object", RarityType.Exceptional)
end

-- create all required UI elements for the client side
function initUI()

    local res = getResolution()
    local size = vec2(800, 600)

    local menu = ScriptUI()
    local window = menu:createWindow(Rect(vec2(0, 0), vec2(0, 0)))

    menu:registerWindow(window, "Claim"%_t, 5);
end

function onShowWindow()
    invokeServerFunction("claim")
    ScriptUI():stopInteraction()
end

function claim()
    local ok, msg = interactionPossible(callingPlayer)
    if not ok then

        if msg then
            local player = Player(callingPlayer)
            if player then
                player:sendChatMessage("", 1, msg)
            end
        end

        return
    end

    local faction, ship, player = getInteractingFaction(callingPlayer)
    if not faction then return end

    local entity = Entity()
    if entity.factionIndex ~= 0 then
        return false
    end

    entity.factionIndex = faction.index
    entity:addScriptOnce("minefounder.lua")
    entity:addScriptOnce("sellobject.lua")
    entity:setValue("valuable_object", nil)
    entity:setValue("map_marker", "Claimed Asteroid"%_T)

    terminate()

    local sector = Sector()
    local x, y = sector:getCoordinates()
    player:sendCallback("onAsteroidClaimed", makeCallbackSenderInfo(entity))
end
callable(nil, "claim")
