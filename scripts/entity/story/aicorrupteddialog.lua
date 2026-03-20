package.path = package.path .. ";data/scripts/lib/?.lua"

include ("randomext")
include ("stringutility")
include ("callable")
AI = include ("story/ai")

local interactable = true

function initialize()
    if onClient() then
        Entity():registerCallback("onBreak", "onBreak")
    end
end

function interactionPossible(playerIndex, option)
    return interactable
end

function initUI()
    ScriptUI():registerInteraction("Hail"%_t, "onHail")
end

function startAttacking()
    if onClient() then
        invokeServerFunction("startAttacking")
        return
    end

    Entity():invokeFunction("aibehaviour.lua", "setAngry")
end
callable(nil, "startAttacking")

function onHail()

    local negative = {}
    negative.text = "..."
    negative.followUp = {text = "[There seems to be no reaction.]"%_t}

    local positive = {}
    positive.text = "Non-Xsotan detected. Commencing attack."%_t
    positive.followUp = {text = "Routing power from shields to weapons."%_t, onEnd = "startAttacking"}

    local ship = Player().craft
    ScriptUI():showDialog(positive, false)
    interactable = false
end

function getUpdateInterval()
    return 0.5
end

function updateClient(timeStep)
    if interactable then
        local ship = Player().craft
        if ship then
            Player():startInteracting(Entity(), "aicorrupteddialog.lua", 0)
        end
    end
end

