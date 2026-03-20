package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("stringutility")
include ("callable")
local Dialog = include ("dialogutility")

function initialize()
end

function interactionPossible(player, option)
    local craft = Player().craft
    if craft == nil then return false end

    local dist = craft:getNearestDistance(Entity())
    if dist < 100.0 then
        return true
    end

    return false, "You're not close enough to search the object."%_t
end

function initUI()
    ScriptUI():registerInteraction("[Scan the Wreckage]"%_t, "onSearchPressed")
end

function onSearchPressed()
    ScriptUI():showDialog(Dialog.empty())

    local player = Player()
    if not player then player = Player(callingPlayer) end
    if not player then return end

    player:sendCallback("onStoryHintWreckageSearched", Entity().id)
end

