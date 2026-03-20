package.path = package.path .. ";data/scripts/lib/?.lua"

include ("randomext")
local AsyncShipGenerator = include("asyncshipgenerator")
local Placer = include("placer")
local CaptainUtility = include ("captainutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace FactionAttackEntity
FactionAttackEntity = {}

FactionAttackEntity.attackerGenerationStarted = false

if onServer() then

local gracePeriod = 30 -- 30 seconds

function FactionAttackEntity.initialize()
    -- this script is added while ship is in background => this function will be called without arguments
    FactionAttackEntity.checkForAttackerFaction()
end

function FactionAttackEntity.checkForAttackerFaction()
    local sector = Sector()
    local controllingFaction = Galaxy():getControllingFaction(sector:getCoordinates())

    local foundFaction = false
    if controllingFaction and controllingFaction.isAIFaction then
        -- check if owner has beef with controlling faction
        local ownerIndex = Entity().factionIndex
        local relation = controllingFaction:getRelation(ownerIndex)
        if relation.status == RelationStatus.War then
            foundFaction = true
        end
    end

    if not foundFaction then
        -- we aren't actually at war => spawn pirates instead
        local entity = Entity()
        entity:addScriptOnce("data/scripts/entity/events/piratesattackentity.lua")
        terminate()
    end
end

function FactionAttackEntity.getUpdateInterval()
    return 1
end

function FactionAttackEntity.update(timeStep)

    if FactionAttackEntity.attackerGenerationStarted then
        return
    end

    -- see if we're still in grace period or player present
    gracePeriod = gracePeriod - timeStep
    if (Sector().numPlayers > 0) or gracePeriod <= 0 then
        -- spawn attackers
        FactionAttackEntity.spawnAttackers()
        FactionAttackEntity.attackerGenerationStarted = true
    end
end

function FactionAttackEntity.onShipsGenerated(ships)
    local entity = Entity()
    local owner = Galaxy():findFaction(entity.factionIndex)

    -- apply a damage buff if the captain has the perk for it
    local strength
    local captain = entity:getCaptain()
    if captain then
        if captain:hasPerk(CaptainUtility.PerkType.Cunning) then
            strength =  CaptainUtility.getAttackStrengthPerks(captain, CaptainUtility.PerkType.Cunning)
        end

        if captain:hasPerk(CaptainUtility.PerkType.Harmless) then
            strength =  CaptainUtility.getAttackStrengthPerks(captain, CaptainUtility.PerkType.Harmless)
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
        ship:setValue("is_defender", true)

        local ai = ShipAI(ship.id)
        ai:registerEnemyEntity(entity.id)

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

function FactionAttackEntity.spawnAttackers()
    local generator = AsyncShipGenerator(FactionAttackEntity, FactionAttackEntity.onShipsGenerated)
    local numShips = random():getInt(5, 7)
    local entity = Entity()
    local pos = entity.translationf

    local controllingFaction = Galaxy():getControllingFaction(Sector():getCoordinates())
    -- no eradication check is required here because this script is only added if the faction is not eradicated

    generator:startBatch()
    for i = 1, numShips do
        local dir = random():getDirection()
        local matrix = MatrixLookUpPosition(-dir, vec3(0, 1, 0), pos + dir * 1800)
        generator:createDefender(controllingFaction, matrix)
    end

    generator:endBatch()

    HyperspaceEngine(entity):exhaust()

    if entity:getNumArmedTurrets() > 0 then
        ShipAI(entity):setAggressive(false, false)
    end
end

end
