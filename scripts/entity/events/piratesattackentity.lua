package.path = package.path .. ";data/scripts/lib/?.lua"

include ("randomext")
local AsyncPirateGenerator = include("asyncpirategenerator")
local Placer = include("placer")
local CaptainUtility = include ("captainutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace PiratesAttackEntity
PiratesAttackEntity = {}

PiratesAttackEntity.attackerGenerationStarted = false

if onServer() then

local gracePeriod = 30 -- 30 seconds

function PiratesAttackEntity.initialize()
    -- this script is added while ship is in background => this function will only be called without arguments
end

function PiratesAttackEntity.getUpdateInterval()
    return 1
end

function PiratesAttackEntity.update(timeStep)

    if PiratesAttackEntity.attackerGenerationStarted then
        return
    end

    -- see if we're still in grace period
    gracePeriod = gracePeriod - timeStep
    if (Sector().numPlayers > 0) or gracePeriod <= 0 then
        -- spawn attackers
        PiratesAttackEntity.spawnAttackers()
        PiratesAttackEntity.attackerGenerationStarted = true
    end
end

function PiratesAttackEntity.onPiratesGenerated(ships)
    local entity = Entity()
    local owner = Galaxy():findFaction(entity.factionIndex)

    -- apply a damage buff if the captain has the perk for it
    local strength
    local captain = entity:getCaptain()
    if captain then
        if captain:hasPerk(CaptainUtility.PerkType.Cunning) then
            strength = CaptainUtility.getAttackStrengthPerks(captain, CaptainUtility.PerkType.Cunning)
        end

        if captain:hasPerk(CaptainUtility.PerkType.Harmless) then
            strength = CaptainUtility.getAttackStrengthPerks(captain, CaptainUtility.PerkType.Harmless)
        end
    end

    -- make sure that the player isn't abusing the mechanic
    local disableDrops
    if owner and (owner.isAlliance or owner.isPlayer) then
        local now = Server().unpausedRuntime
        local last = owner:getValue("last_bgs_attack")
        if last and now - last < 20 * 60 then
            disableDrops = true
        end

        owner:setValue("last_bgs_attack", now)
    end

    for _, ship in pairs(ships) do
        ship:setValue("background_attacker", true)

        if strength then
            ship.damageMultiplier = ship.damageMultiplier * strength
        end

        if disableDrops then
            ship:setDropsLoot(false)
        end
    end

    Placer.resolveIntersections()
    terminate() -- nothing more to do
end

function PiratesAttackEntity.spawnAttackers()

    local generator = AsyncPirateGenerator(PiratesAttackEntity, PiratesAttackEntity.onPiratesGenerated)
    local entity = Entity()
    local pos = entity.translationf

    generator:startBatch()

    local dir = random():getDirection()
    local up = vec3(0, 1, 0)
    local right = cross(dir, up)

    local matrix = MatrixLookUpPosition(-dir, up, pos + dir * 1800 + right * 75 * 1)
    generator:createScaledPirate(matrix)

    local matrix = MatrixLookUpPosition(-dir, up, pos + dir * 1800 + right * 75 * 2)
    generator:createScaledPirate(matrix)

    local matrix = MatrixLookUpPosition(-dir, up, pos + dir * 1800 + right * 75 * 3)
    generator:createScaledRaider(matrix)

    local matrix = MatrixLookUpPosition(-dir, up, pos + dir * 1800 + right * 75 * 4)
    generator:createScaledPirate(matrix)

    local matrix = MatrixLookUpPosition(-dir, up, pos + dir * 1800 + right * 75 * 5)
    generator:createScaledPirate(matrix)

    generator:endBatch()

    HyperspaceEngine(entity):exhaust()

    if entity:getNumArmedTurrets() > 0 then
        ShipAI(entity):setAggressive(false, false)
    end

end

end
