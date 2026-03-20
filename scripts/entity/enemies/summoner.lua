package.path = package.path .. ";data/scripts/lib/?.lua"

local Xsotan = include ("story/xsotan")
include ("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Summoner
Summoner = {}
local self = Summoner

self.timeStep = 5
self.data = {}
self.lasers = {}

local lasers = self.lasers

function Summoner.initialize()
    local entity = Entity()
    entity:setValue("xsotan_summoner", true)
end

if onServer() then
function Summoner.getUpdateInterval()
    return self.timeStep
end
else
function Summoner.getUpdateInterval()
    return 0
end
end

function Summoner.updateServer(timeStep)
    self.timeStep = random():getFloat(5, 7)

    local entity = Entity()

    if ShipAI(entity).isAttackingSomething then
        if self.getSpawnableMinions() > 0 then
            self.spawnMinion()
            self.timeStep = random():getFloat(2, 3)
        end
    end
end

function Summoner.updateClient(timeStep)
    local entity = Entity()
    for k, l in pairs(lasers) do

        if valid(l.laser) then
            l.laser.from = entity.translationf
            l.laser.to = l.to
        else
            lasers[k] = nil
        end
    end
end

function Summoner.spawnMinion()
    local direction = random():getDirection()

    local master = Entity()
    local pos = master.translationf
    local radius = master.radius
    local minionPosition = pos + direction * radius * random():getFloat(5, 10)

    broadcastInvokeClientFunction("animation", direction, minionPosition)
    self.createWormhole(minionPosition)

    local matrix = MatrixLookUpPosition(master.look, master.up, minionPosition)
    local minion = Xsotan.createShip(matrix, 0.5)
    minion:setValue("xsotan_summoner_minion", true)
    minion:setTitle("Xsotan Minion"%_T, {})

    local attackedId = ShipAI(master).attackedEntity
    minion:invokeFunction("xsotanbehaviour.lua", "onSetToAggressive", attackedId)

    self.data.spawned = (self.data.spawned or 0) + 1
end

function Summoner.createWormhole(position)
    -- spawn a wormhole
    local desc = WormholeDescriptor()
    desc:removeComponent(ComponentType.EntityTransferrer)
    desc:addComponents(ComponentType.DeletionTimer)
    desc.position = MatrixLookUpPosition(vec3(0, 1, 0), vec3(1, 0, 0), position)

    local size = random():getFloat(15, 25)
    local wormhole = desc:getComponent(ComponentType.WormHole)
    wormhole:setTargetCoordinates(random():getInt(-50, 50), random():getInt(-50, 50))
    wormhole.visible = true
    wormhole.visualSize = size
    wormhole.passageSize = math.huge
    wormhole.oneWay = true
    wormhole.simplifiedVisuals = true

    desc:addScriptOnce("data/scripts/entity/wormhole.lua")

    local wormhole = Sector():createEntity(desc)

    local timer = DeletionTimer(wormhole.index)
    timer.timeLeft = 3
end

function Summoner.animation(direction, minionPosition)
    local sector = Sector()

    local entity = Entity()
    local pos = entity.translationf

    local laser = sector:createLaser(entity.translationf, minionPosition, ColorRGB(0.8, 0.6, 0.1), 1.5)
    laser.maxAliveTime = 1.5
    laser.collision = false
    laser.animationSpeed = -500

    table.insert(lasers, {laser = laser, to = minionPosition})
end

function Summoner.getSpawnableMinions(amount)
    local summoners = Sector():getNumEntitiesByScriptValue("xsotan_summoner")
    local minions = Sector():getNumEntitiesByScriptValue("xsotan_summoner_minion")

    local minionsPerSummoner = 6 + GameSettings().difficulty
    local open = (summoners * minionsPerSummoner) - minions

    -- spawn at max 25 minions to avoid infinite spawning
    local maxSpawnable = 25
    open = math.min(open, maxSpawnable - (self.data.spawned or 0))
    open = math.max(0, open)

    return open
end

function Summoner.secure()
    return self.data
end

function Summoner.restore(data)
    self.data = data or {}
end
