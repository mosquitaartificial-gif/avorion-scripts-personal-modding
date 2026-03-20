package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua;"

include("defaultscripts")
include("stringutility")
include("callable")

local tx, ty = 0
local name = 0

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
    ScriptUI():registerInteraction("Inspect"%_t, "onInspect")
end

function initialize(x, y)
    name = math.random(1, 150)
    tx = x
    ty = y
    if onClient() then
        Player():registerCallback("onPreRenderHud", "onPreRenderHud")
        sync()
    end
end

function updateClient(timeStep)
    local entity = Entity()

    local plan = Plan(entity.id)
    if not plan then return end
    local blocks = plan:getBlocksByType(BlockType.Stone)

    for _, block in pairs(blocks) do
        local parent = plan:getBlock(block)
        if parent.numChildren == 0 then
            Sector():createGlow(entity.translationf + normalize(parent.box.position) * 200, 50, ColorRGB(0.1, 0.3, 0.5))
            Sector():createGlow(entity.translationf + normalize(parent.box.position) * 200, 50, ColorRGB(0.1, 0.3, 0.5))
        end
    end
end

function onPreRenderHud()
    -- display nearest x
    if os.time() % 3 == 0 then
        local renderer = UIRenderer()
        renderer:renderEntityTargeter(Entity(), ColorRGB(1, 1, 1));
        renderer:display()
    end
end

function onInspect()
    sync()
    ScriptUI():showDialog(makeDialog())
end

function sync(x, y)
    if onServer() then invokeClientFunction(Player(callingPlayer), "sync", tx, ty) return end
    if x and y then
        tx = x
        ty = y
    else
        invokeServerFunction("sync")
    end
end
callable(nil, "sync")

function makeDialog()
    local dialog = {}
    local digDeaper = {}
    if tx and ty then
        dialog.text = "Shield entity No. ${random}. Routing shield power to Specimen 8055. Location set to (${x}:${y})."%_t % {random = name, x = tx, y = ty}
    else
        dialog.text = "Shield entity No. ${random}. Routing shield power to Specimen 8055. Waiting for location..."%_t % {random = name}
    end
        return dialog
end
