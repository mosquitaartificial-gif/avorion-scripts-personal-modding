package.path = package.path .. ";data/scripts/lib/?.lua"

include("stringutility")
include("callable")

local somethingToBeFound = false

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function interactionPossible(playerIndex)

    local player = Player(playerIndex)
    local self = Entity()

    local craft = player.craft
    if craft == nil then return false end

    local dist = craft:getNearestDistance(self)

    if dist < 200 then
        return true
    end

    return false, "You're not close enough to search the object."%_t
end

function initUI()
    local entity = Entity()
    local p = Plan(entity.id)
    local block = p:getBlocksByType(BlockType.BlackBox)
    if block and #block > 0 then
        somethingToBeFound = true
    end

    ScriptUI():registerInteraction("[Scan the Wreckage]"%_t, "onSearch")
end

function onSearch(entityIndex)
    local ui = ScriptUI(entityIndex)
    if not ui then return end

    if somethingToBeFound then
        ui:showDialog(foundSomethingDialog())
    else
        ui:showDialog(foundNothingDialog())
    end
end

function foundNothingDialog()
    local d0_NothingFoundHer = {}

    d0_NothingFoundHer.text = "Nothing found here."%_t
    d0_NothingFoundHer.answers = {
        {answer = "OK"%_t, onSelect = "finishScript"}
    }

    return d0_NothingFoundHer
end

function foundSomethingDialog()
    -- make dialog
    local d0_YouFoundSomeInf = {}
    local dialog1_1 = {}

    d0_YouFoundSomeInf.text = "This ship seems empty. There's no heat registering on your scanners, and all crew aboard is frozen stiff.\n\nThe energy generator looks torn apart, it may have released toxic fumes into their air system. The only working thing is the automatic help message you received."%_t
    d0_YouFoundSomeInf.answers = {
        {answer = "Check message system"%_t, followUp = dialog1_1}
    }

    dialog1_1.text = "To whomever finds this message: Please bring the information home to our families. They need to know about our fate."%_t
    dialog1_1.answers = {{answer = "Close"%_t, onSelect = "onFoundEnd"}}

    return d0_YouFoundSomeInf
end

function finishScript()
    terminate()
    return
end

function onFoundEnd()
    local player = Player()
    local entityId = Entity().id
    for index, script in pairs(player:getScripts()) do
        if script == "data/scripts/player/missions/searchandrescue/searchandrescue.lua" then
            player:invokeFunction(index, "onFoundDialogEnd", entityId)
        end
    end
end

function secure()
    return somethingToBeFound
end

function restore(value)
    somethingToBeFound = value
end
