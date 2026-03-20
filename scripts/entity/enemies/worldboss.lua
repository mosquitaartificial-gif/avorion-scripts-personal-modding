package.path = package.path .. ";data/scripts/lib/?.lua"

include ("randomext")
local PlanGenerator = include ("plangenerator")
local WorldBossUT = include ("worldbossutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace WorldBoss
WorldBoss = {}

WorldBoss.bossRegistered = false
WorldBoss.beaconData = {}
WorldBoss.chatterLines = {}
WorldBoss.chatterTimer = 3 * 60 -- 3 minutes

WorldBoss.fightStarted = false

function WorldBoss.initialize(beacon, chatterLines)
    if onServer() then
        Entity():registerCallback("onDestroyed", "onDestroyed")

        local sector = Sector()
        sector:registerCallback("onShotFired", "onShotFired")
        sector:registerCallback("onDamaged", "onDamaged")
        sector:registerCallback("onShieldDamaged", "onShieldDamaged")

        if beacon then
            WorldBoss.beaconData = beacon
        end

        if chatterLines then
            WorldBoss.chatterLines = chatterLines
        end
    end
end

function WorldBoss.updateServer(timeStep)
    if not WorldBoss.fightStarted then
        if WorldBossUT.playerApproached() then
            WorldBoss.initiateFight()
        end
    else
        WorldBoss.chatterTimer = WorldBoss.chatterTimer - timeStep
        local self = Entity()
        if WorldBoss.chatterTimer <= 0 and self.durability >= 0.3 * self.maxDurability then
            Sector():broadcastChatMessage(Entity(), ChatMessageType.Chatter, randomEntry(WorldBoss.chatterLines))
            WorldBoss.chatterTimer = 3 * 60 -- 3 minutes
        end
    end
end

function WorldBoss.updateClient(timeStep)
    if WorldBoss.fightStarted and not WorldBoss.bossRegistered then
        -- show boss health bar on the client
        registerBoss(Entity().id)
        WorldBoss.bossRegistered = true
    end
end

function WorldBoss.onDestroyed()
    local desc = EntityDescriptor()
    desc:addComponents(
        ComponentType.Plan,
        ComponentType.BspTree,
        ComponentType.Intersection,
        ComponentType.Asleep,
        ComponentType.DamageContributors,
        ComponentType.BoundingSphere,
        ComponentType.BoundingBox,
        ComponentType.Velocity,
        ComponentType.Physics,
        ComponentType.Scripts,
        ComponentType.ScriptCallback,
        ComponentType.Title,
        ComponentType.InteractionText
    )

    local plan = PlanGenerator.makeBeaconPlan()

    desc.position = Entity().position
    desc:setMovePlan(plan)

    local beacon = Sector():createEntity(desc)
    beacon:addScriptOnce("data/scripts/entity/worldbossbeacon.lua", WorldBoss.beaconData)
    beacon:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
    beacon.dockable = false

    Sector():setValue("worldboss_defeated", Server().unpausedRuntime)
end

function WorldBoss.onShotFired(id)
    if WorldBoss.fightStarted then return end

    local turret = Turret(id)
    if not valid(turret) then return end

    local shooterId = turret.shootingCraft
    if not valid(shooterId) then return end

    local entity = Entity()
    if shooterId == entity.id or entity:getValue("world_boss_minion") then
        WorldBoss.initiateFight()
    end
end

function WorldBoss.onShieldDamaged(entityId)
    if WorldBoss.fightStarted then return end

    -- listen for damage on minions as well as the boss itself
    local entity = Entity()
    if entityId == entity.id or entity:getValue("world_boss_minion") then
        WorldBoss.initiateFight()
    end
end

function WorldBoss.onDamaged(entityId)
    if WorldBoss.fightStarted then return end

    -- listen for damage on minions as well as the boss itself
    local entity = Entity()
    if entityId == entity.id or entity:getValue("world_boss_minion") then
        WorldBoss.initiateFight()
    end
end

function WorldBoss.initiateFight()
    WorldBoss.fightStarted = true
    WorldBoss.sync()

    ShipAI(Entity()):setAggressive()

    for _, entity in pairs({Sector():getEntitiesByScriptValue("world_boss_minion")}) do
        ShipAI(entity):setAggressive()
    end

    Sector():sendCallback("showWorldBossStartFightChatter")
end

function WorldBoss.sync(data_in)
    if onServer() then
        broadcastInvokeClientFunction("sync", WorldBoss.fightStarted)
    else
        WorldBoss.fightStarted = data_in
    end
end
