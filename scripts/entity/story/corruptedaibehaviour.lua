package.path = package.path .. ";data/scripts/lib/?.lua"

TurretGenerator = include ("turretgenerator")
local TorpedoGenerator = include ("torpedogenerator")
ShipUtility = include ("shiputility")
AI = include ("player/events/spawnbigaicorrupted")
include ("randomext")
include ("stringutility")

local angry = 0
local random = Random(Seed(151))


function initialize()
    if onServer() then
        local entity = Entity()
        entity.dockable = false

        entity:registerCallback("onBreak", "onBreak")
        entity:registerCallback("onDamaged", "onDamaged")
        entity:registerCallback("onShieldDamaged", "onShieldDamaged")
        entity:registerCallback("onDestroyed", "onChildDestroyed")
        Sector():addScriptOnce("story/corruptedaihealthbar.lua")
    end

end


function getUpdateInterval()
    time = time or math.random() * 0.5 + 0.5
    return time
end

function updateServer(timeStep)

    -- self destruct when it becomes too small
    local plan = Plan()
    if plan.numBlocks > 0 and plan.numBlocks <= 3 then
        local entity = Entity()
        entity:destroy(Uuid())
    end

    -- while it's not angry, it's got all power routed to its shield
    if angry == 0 then
        local entity = Entity()
        local shield = Shield(entity.id)
        entity.shieldDurability = shield.maximum

        -- if there are multiple instances of the AI, the fight has begun and it should be angry, always
        local ais = {Sector():getEntitiesByScript("story/corruptedaibehaviour.lua")}
        if #ais > 1 then
            setAngry()
        end
    end
end

function onBreak(entityId, ...)
    local entity = Entity(entityId)

    setAngry()

    local parts = {...}
    for _, newPlan in pairs(parts) do

        newPlan.accumulatingHealth = false

        local root = newPlan:getNthBlock(0)
        local box = root.box

        -- calculate new relative position of the wreck
        -- Matrix wreckPosition = mut::translate(Matrix(), box.position + (newPlan.centerOfMass - box.position));
        local wreckPosition = Matrix()
        wreckPosition.translation = box.position + (newPlan.centerOfMass - box.position)

        -- desc->get<Position>().setWorldMatrix(wreckPosition * position.getWorldMatrix());
        wreckPosition = wreckPosition * entity.position

        -- displace the wreck plan so it will match with the new position
        newPlan:displace(-(box.position + (newPlan.centerOfMass - box.position)));

        local fireTorpedo = true

        if newPlan.numBlocks >= 8 then

            local desc = ShipDescriptor()

            desc.position = wreckPosition
            desc.factionIndex = entity.factionIndex
            desc:setMovePlan(newPlan)
            desc:addScriptOnce("story/corruptedaibehaviour")
            desc:addScriptOnce("deleteonplayersleft")
            desc.title = "5468 6520 4149"%_T
            desc.name = ""

            desc:getComponent(ComponentType.Boarding).boardable = false

            -- finally create the "wreck"
            local child = Sector():createEntity(desc);
            child:registerCallback("onDestroyed", "onChildDestroyed")

            local numTurrets = newPlan.numBlocks / 25 + 1
            AI.addTurrets(child, numTurrets)

            local shield = Shield(child.id)
            shield.maxDurabilityFactor = 0.5

            WreckageCreator(child.index).active = false
            child:invokeFunction("story/corruptedaibehaviour.lua", "setAngry")

            fireTorpedo = false

        elseif newPlan.numBlocks >= 3 then

            local desc = WreckageDescriptor()

            desc.position = wreckPosition
            desc:setMovePlan(newPlan)

            -- finally create the wreck
             Sector():createEntity(desc);
        end

        if fireTorpedo then
            fireTorpedoAtPlayer(entity, wreckPosition)
        end

    end
end

function setAngry()
    angry = 1

    -- when it gets angry, it starts attacking all players
    local ai = ShipAI()
    ai:setAggressive()

    local players = {Sector():getPlayers()}
    for _, player in pairs(players) do
        ai:registerEnemyFaction(player.index)

        local allianceIndex = player.allianceIndex
        if allianceIndex then
            ai:registerEnemyFaction(allianceIndex)
        end
    end
end


local damageUntilAngry = 10000
local damages = {}

function registerDamage(damage, inflictor)

    local inflictorEntity = Entity(inflictor)
    if inflictorEntity and inflictorEntity.factionIndex == Entity().factionIndex then return end

    inflictor = inflictor or Uuid()

    local received = damages[inflictor] or 0
    received = received + damage
    damages[inflictor] = received

    if received > damageUntilAngry then
        ShipAI():registerEnemyEntity(inflictor)

        setAngry()
    end
end

function onDamaged(entityId, damage, inflictor)
    registerDamage(damage, inflictor)
end

function onShieldDamaged(entityId, damage, damageType, inflictor)
    registerDamage(damage, inflictor)
end

function fireTorpedoAtPlayer(entity, position)
    local torpedoTemplate = generateTorpedo()

    local desc = TorpedoDescriptor()
    local torpedoAI = desc:getComponent(ComponentType.TorpedoAI)
    local torpedo = desc:getComponent(ComponentType.Torpedo)
    local velocity = desc:getComponent(ComponentType.Velocity)
    local owner = desc:getComponent(ComponentType.Owner)
    local flight = desc:getComponent(ComponentType.DirectFlightPhysics)
    local durability = desc:getComponent(ComponentType.Durability)

    -- get target
    local ships = {Sector():getEntitiesByType(EntityType.Ship)}
    local pShips = {}
    for _, p in pairs(ships) do
        if p.playerOwned then
            table.insert(pShips, p)
        end
    end
    local targetShip = randomEntry(random(), pShips)
    if not targetShip then return end
    torpedoAI.target = targetShip.id
    torpedo.intendedTargetFaction = targetShip.factionIndex

    -- set torpedo properties
    torpedoAI.driftTime = 1 -- can't be 0

    desc.position = position

    torpedo.shootingCraft = entity.id
    torpedo.firedByAIControlledPlayerShip = false
    torpedo.collisionWithParentEnabled = false
    torpedo:setTemplate(torpedoTemplate)

    owner.factionIndex = entity.factionIndex

    flight.drifting = true
    flight.maxVelocity = torpedoTemplate.maxVelocity
    flight.turningSpeed = torpedoTemplate.turningSpeed * 2 -- a bit more turning speed so that they hit even in close range

    velocity.velocityf = vec3(1,1,1) * 10 -- "eject speed" that is then used to calculate fly speed

    durability.maximum = torpedoTemplate.durability
    durability.durability = torpedoTemplate.durability

    -- create torpedo
    Sector():createEntity(desc)
end

function generateTorpedo()
    local coords = {Sector():getCoordinates()}

    local generator = TorpedoGenerator()
    return generator:generate(coords.x, coords.y, 0, Rarity(RarityType.Exotic), random:getInt(1,10), random:getInt(1, 9))
end

function secure()
    return {angry = angry}
end

function restore(data)
    angry = data.angry
end
