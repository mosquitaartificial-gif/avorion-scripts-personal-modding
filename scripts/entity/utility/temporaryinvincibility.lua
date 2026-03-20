package.path = package.path .. ";data/scripts/lib/?.lua"

include("stringutility")
include("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace TemporaryInvincibility
TemporaryInvincibility = {}

TemporaryInvincibility.data = {}
local data = TemporaryInvincibility.data

if onServer() then

function TemporaryInvincibility.getUpdateInterval()
    return 1
end

function TemporaryInvincibility.initialize(invincibilityTimer, invincibilityValue, noDamageByPlayer)

    data.self = Entity()
    data.self:registerCallback("onDamaged" , "onDamaged")
    data.self:registerCallback("onShieldDamaged" , "onShieldDamaged")

    data.allowDamageByPlayer = true
    if noDamageByPlayer then
        data.allowDamageByPlayer = false
    end

    data.invincibilityTimer = invincibilityTimer or 120 -- get timer for how long ship should survive at least

    if not _restoring then
        data.percentage = invincibilityValue or 0.15
    end

    Durability().invincibility = data.percentage
end

function TemporaryInvincibility.updateServer(timeStep)

    data.invincibilityTimer = data.invincibilityTimer - timeStep

    if data.invincibilityTimer <= 0 then
        TemporaryInvincibility.clearAndTerminate()
    end
end

function TemporaryInvincibility.onDamaged(entityId, damage, inflictor)
    TemporaryInvincibility.registerDamage(inflictor)
end

function TemporaryInvincibility.onShieldDamaged(entityId, damage, damageType, inflictor)
    TemporaryInvincibility.registerDamage(inflictor)
end

function TemporaryInvincibility.registerDamage(inflictor)
    local inflictorEntity = Entity(inflictor)

    if inflictorEntity
            and inflictorEntity.playerOrAllianceOwned
            and data.allowDamageByPlayer then
        TemporaryInvincibility.clearAndTerminate()
    end
end

function TemporaryInvincibility.clearAndTerminate()
    Durability().invincibility = 0
    terminate()
end

function TemporaryInvincibility.secure()
    return data
end

function TemporaryInvincibility.restore(data_in)
    data = data_in

    Durability().invincibility = data.percentage
end

end
