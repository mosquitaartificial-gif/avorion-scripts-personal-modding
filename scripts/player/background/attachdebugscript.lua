package.path = package.path .. ";data/scripts/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"

include("callable")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace AttachDebugScript
AttachDebugScript = {}

function AttachDebugScript.getUpdateInterval()
    return 0
end

function AttachDebugScript.updateClient()
    if GameInput():keyDown(ControlAction.DebugScript) then
        local player = Player()

        local selectedId = player.selectedObject
        if not selectedId or selectedId == Uuid() then
            selectedId = player.craftId
            player.selectedObject = player.craft
        end

        if selectedId then
            AttachDebugScript.attachAndInteract(selectedId)
        end
    end
end

function AttachDebugScript.attachAndInteract(entityId)
    local entity = Entity(entityId)
    if not entity then return end
    if not GameSettings().devMode then return end

    entity:addScriptOnce("lib/entitydbg.lua")

    invokeClientFunction(Player(callingPlayer), "startInteraction", entityId)
end
rcall(AttachDebugScript, "attachAndInteract")

function AttachDebugScript.startInteraction(entityId)
    Player():startInteracting(Entity(entityId), "lib/entitydbg.lua", 0)
end
