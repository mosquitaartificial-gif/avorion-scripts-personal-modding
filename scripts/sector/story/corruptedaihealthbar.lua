package.path = package.path .. ";data/scripts/lib/?.lua"
include("callable")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace CorruptedAIHealthBar
CorruptedAIHealthBar = {}

local ais = {}
local fakeEndboss

local maxHealth = 1;
local health = 0;
local maxShield = 1;
local shield = 0;

if onClient() then

function CorruptedAIHealthBar.getUpdateInterval()
    return 0.15
end


function CorruptedAIHealthBar.initialize()

end

function CorruptedAIHealthBar.updateClient(timePassed)

    health = 0
    shield = 0

    local maxHealthSum = 0
    local maxShieldSum = 0

    local entities = {Sector():getEntitiesByType(EntityType.Ship)}
    for _, entity in pairs(entities) do
        if entity:hasScript("corruptedaibehaviour.lua") then

            health = health + entity.durability
            shield = shield + entity.shieldDurability

            maxHealthSum = maxHealthSum + entity.maxDurability
            maxShieldSum = maxShieldSum + entity.shieldMaxDurability
        end
    end

    maxHealth = math.max(maxHealth, maxHealthSum)
    maxShield = math.max(maxShield, maxShieldSum)

    if health > 0 or shield > 0 then
        registerBoss(Uuid(), nil, nil, "data/music/special/ai.ogg", "5468 6520 4149"%_t)
        setBossHealth(Uuid(), health, maxHealth, shield, maxShield)
    else
        unregisterBoss(Uuid())
        invokeServerFunction("terminateServer")
    end
end

end

function CorruptedAIHealthBar.terminateServer()
    terminate()
end
callable(CorruptedAIHealthBar, "terminateServer")


