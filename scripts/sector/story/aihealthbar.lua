package.path = package.path .. ";data/scripts/lib/?.lua"
include("callable")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace AIHealthBar
AIHealthBar = {}

local maxHealth = 1;
local health = 0;
local maxShield = 1;
local shield = 0;
local visible = false;

if onClient() then

function AIHealthBar.getUpdateInterval()
    return 0.15
end


function AIHealthBar.initialize()

end

function AIHealthBar.updateClient(timePassed)

    if not visible then
        unregisterBoss(Uuid())
        return
    end

    health = 0
    shield = 0

    local maxHealthSum = 0
    local maxShieldSum = 0

    local entities = {Sector():getEntitiesByScript("/aibehaviour.lua")}
    for _, entity in pairs(entities) do
        health = health + entity.durability
        shield = shield + entity.shieldDurability

        maxHealthSum = maxHealthSum + entity.maxDurability
        maxShieldSum = maxShieldSum + entity.shieldMaxDurability
    end

    maxHealth = math.max(maxHealth, maxHealthSum)
    maxShield = math.max(maxShield, maxShieldSum)

    if health > 0 or shield > 0 then
        registerBoss(Uuid(), nil, nil, "data/music/special/ai.ogg", "The AI"%_t)
        setBossHealth(Uuid(), health, maxHealth, shield, maxShield)
    else
        unregisterBoss(Uuid())
        invokeServerFunction("terminateServer")
    end
end

end

if onServer() then

function AIHealthBar.getUpdateInterval()
    return 1
end

function AIHealthBar.updateServer(timePassed)
    if Sector():getNumEntitiesByScript("/aibehaviour.lua") == 0 then
        terminate()
    end
end

end

function AIHealthBar.setVisible()
    if onServer() then
        broadcastInvokeClientFunction("setVisible")
        return
    end

    visible = true
end

function AIHealthBar.terminateServer()
    terminate()
end
callable(AIHealthBar, "terminateServer")


