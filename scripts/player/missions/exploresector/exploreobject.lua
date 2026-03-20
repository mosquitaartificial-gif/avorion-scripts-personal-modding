package.path = package.path .. ";data/scripts/lib/?.lua"

include("defaultscripts")
include("stringutility")
include("callable")

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function interactionPossible(playerIndex)

    local player = Player(playerIndex)
    local self = Entity()

    local craft = player.craft
    if craft == nil then return false end

    local dist = craft:getNearestDistance(self)

    if dist < 300 then
        return true
    end

    return false, "You're not close enough to search the object."%_t
end

function initUI()
    ScriptUI():registerInteraction("Explore"%_t, "onExplore")
end

function onExplore()
    ScriptUI():showDialog(makeDialog())
end

function makeDialog()
    local d0_YouFoundSomeInf = {}

    d0_YouFoundSomeInf.text = "Exploration finished in this part of the sector."%_t
    d0_YouFoundSomeInf.answers = {
        {answer = "OK"%_t, onSelect = "explored"}
    }

    return d0_YouFoundSomeInf
end

function explored()
    if onClient() then
        invokeServerFunction("explored")
        return
    end

    Player(callingPlayer):sendCallback("onMissionObjectExplored", Entity().id.string)
    terminate()
    return
end
callable(nil, "explored")
