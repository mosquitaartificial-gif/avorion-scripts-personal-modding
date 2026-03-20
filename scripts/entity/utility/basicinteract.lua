package.path = package.path .. ";data/scripts/lib/?.lua"
include ("stringutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace BasicInteract
BasicInteract = {}

if onClient() then

function BasicInteract.interactionPossible()
    return true
end

function BasicInteract.initialize()
    local interactionText = InteractionText()

    if interactionText.text == "" then
        interactionText.text = "Yes?"%_t
    end
end

function BasicInteract.initUI()
    ScriptUI():registerInteraction("Close"%_t, "", -5);
end

end
