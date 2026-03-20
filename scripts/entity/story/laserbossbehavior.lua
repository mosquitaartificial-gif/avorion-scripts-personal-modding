package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("randomext")
include ("stringutility")
include ("utility")
include ("callable")

-- namespace LaserBossBehavior
LaserBossBehavior = {}

local data = {}
data.numAsteroidsLeft = 4
data.targetEntityId = nil
data.targetingTimer = 0
data.shotTimer = 0
data.roidCount = 4
data.aggressive = false

local laser = nil
local targetLaser = nil
local roidLasers = {}

data.targetLaserData = {}
data.targetLaserData.from = nil
data.targetLaserData.to = nil
data.bossLook = vec3()
data.bossRight = vec3()
data.bossUp = vec3()

laserActive = false
shootNow = false
shotJustNow = 5
glowColor = ColorRGB(0.1, 0.3, 0.5)

function LaserBossBehavior.interactionPossible(playerIndex)
    return true
end

function LaserBossBehavior.initialize()
    local boss = Entity()
    if onClient() then
        registerBoss(boss.index)
    end

    ShipAI():setIdle()
    data.aggressive = false
    boss:registerCallback("onDestroyed", "onDestroyed")
    Sector():registerCallback("onPlayerArrivalConfirmed", "onPlayerArrivalConfirmed")
end

function LaserBossBehavior.onPlayerArrivalConfirmed(playerIndex)
    invokeClientFunction(Player(playerIndex), "startDialog")
end

function LaserBossBehavior.initUI()
    ScriptUI():registerInteraction("Greet"%_t, "startDialog")
end

function LaserBossBehavior.onDestroyed()
    LaserBossBehavior.deleteCurrentLasers()

    if onServer() then
        local server = Server()
        server:setValue("last_killed_laser_boss", server.unpausedRuntime)

        local info = makeCallbackSenderInfo(Entity())
        for _, player in pairs({Sector():getPlayers()}) do
            player:sendCallback("onLaserBossDestroyed", info)
        end
    end
end

function LaserBossBehavior.update(timeStep)


    if not done then
        LaserBossBehavior.createAsteroidLaser()
        done = true
    end

    if data.aggressive then

        if not laserActive then
            LaserBossBehavior.createTargetingLaser()
        end

        LaserBossBehavior.updateAsteroids()
        LaserBossBehavior.updateShield()
        LaserBossBehavior.updateAsteroidLaser()
        LaserBossBehavior.updateIntersection(timeStep)
        LaserBossBehavior.updateLaser()

        if shootNow then
            LaserBossBehavior.showChargeEffect()
        end

        local boss = Entity()

        if onServer() then
            if not data.targetEntityId or not Entity(data.targetEntityId) or not Entity(data.targetEntityId).isShip then
                -- set new target
                local players = {Sector():getPlayers()}
                shuffle(random(), players)
                local newTarget = nil
                for _, player in pairs(players) do
                    if not player.craft then goto continue end

                    newTarget = player.craft.id
                    break

                    ::continue::
                end
                data.targetEntityId = newTarget
                LaserBossBehavior.sync()
            end
        end

        shotJustNow = shotJustNow + timeStep
    end
end

function LaserBossBehavior.updateAsteroids()
    -- update glow effect for shield asteroids while we count them anyway -> glow dies with asteroid

    local count = 0
    local sector = Sector()
    local asteroids = {sector:getEntitiesByType(EntityType.Asteroid)}
    for _, asteroid in pairs(asteroids) do
        if asteroid:getValue("laser_asteroid") then
            count = count + 1
        end
    end
    data.roidCount = count
end

function LaserBossBehavior.updateAsteroidLaser()
    if onServer() then broadcastInvokeClientFunction("updateAsteroidLaser") return end
    -- update the positions of the laser endpoints
    local sector = Sector()
    for k, p in pairs(roidLasers) do
        local laser = p.laser
        local a = sector:getEntity(p.fromIndex)
        local b = sector:getEntity(p.toIndex)

        if valid(laser) and a and b then
            local from = a.position:transformCoord(p.fromLocal)
            local to = b.position:transformCoord(p.toLocal)

            laser.from = from
            laser.to = to
            laser.aliveTime = 0
        else
            if valid(laser) then
                sector:removeLaser(laser)
            end
            roidLasers[k] = nil
        end
    end
end

function LaserBossBehavior.updateShield()
    -- set shield health
    local boss = Entity()
    local shield = Shield(boss.id)

    shield.durability = (shield.maximum / 4) * data.roidCount
    if boss.invincible and data.roidCount == 0 then
        boss.invincible = false
    end
end

function LaserBossBehavior.updateIntersection(timeStep)
    if onClient() then return end

    local ray = Ray()
    ray.origin = vec3(data.targetLaserData.from) or vec3()
    ray.direction = (vec3(data.targetLaserData.to) or vec3()) - ray.origin
    ray.planeIntersectionThickness = 5
    if not ray then return end

    local boss = Entity()
    result = Sector():intersectBeamRay(ray, boss, nil)

    if not shootNow then
        if shotJustNow > 0.3 then
            -- reset laser after shot
            LaserBossBehavior.createTargetingLaser()
            LaserBossBehavior.updateTimer(result, timeStep)
        end
        -- have a little rest, so that the huge shot beam can dissipate
    else
        LaserBossBehavior.initializeShot(result, timeStep)
    end

end

function LaserBossBehavior.updateTimer(entity, timeStep)

    local gotEntity = false

    -- we have target player in sight
    if entity and entity.id == data.targetEntityId then
        gotEntity = true
        data.targetingTimer = (data.targetingTimer or 0) + timeStep

        if data.targetingTimer > 1.5 then -- we had him long enough in sights => commence shot mechanic
            data.targetingTimer = 0
            data.shotTimer = 0
            LaserBossBehavior.createTargetLockedLaser()
            shootNow = true
        end
    end

    if not gotEntity then
        data.targetingTimer = 0 -- reset timer
        if not data.targetEntityId or not Entity(data.targetEntityId) then return end

        local shipAI = ShipAI()
        if not shipAI then return end

        shipAI:setPassiveTurning(Entity(data.targetEntityId).translationf) -- turn while we update timer
        return
    end

    if not data.targetEntityId then return end
    ShipAI():setPassiveTurning(Entity(data.targetEntityId).translationf) -- turn while we update timer
end

function LaserBossBehavior.initializeShot(entity, timeStep)
    ShipAI():setPassive() -- don't turn while shooting
    data.shotTimer = data.shotTimer + timeStep

    if entity and data.shotTimer > 2 then
        -- remove old laser and create shot laser
        LaserBossBehavior.createShotLaser()
        data.shotTimer = 0
        shootNow = false
        shotJustNow = 0
        data.targetEntityId = nil -- find a new target

        -- do damage to entity
        if entity:getValue("laser_asteroid") then
            entity.invincible = false
            LaserBossBehavior.showExplosion(entity)
            entity:destroy(Entity().id, 1, DamageType.Energy)
            if entity then Sector():deleteEntity(entity) end
        else
            local durability = Durability(entity.id)
            if not durability then return end
            durability:inflictDamage(1000000 + 1000000 * GameSettings().damageMultiplier, 1, DamageType.Energy, Entity().id)
        end
    elseif not entity and data.shotTimer > 2 then
        LaserBossBehavior.createShotLaser()
        data.shotTimer = 0
        shootNow = false
        shotJustNow = 0
    end
end

function LaserBossBehavior.createShotLaser()
    if onServer() then
        broadcastInvokeClientFunction("createShotLaser")
        return
    end

    LaserBossBehavior.deleteCurrentLasers()
    LaserBossBehavior.createLaser(50, ColorRGB(0.1, 0.0, 1.0), false)
    laser.sound = "weapon/laser_electro"
    laser.soundVolume = 1
    laser.soundMinRadius = 200
    laser.soundMaxRadius = 1000

    local position = Entity().translationf
    play3DSound("weapon/electro_laser_initial2", SoundType.Other, position, 2000, 1)
    play3DSound("weapon/laser_initial3", SoundType.Other, position, 2000, 1)
    play3DSound("weapon/railgun2", SoundType.Other, position, 2000, 1)
end

function LaserBossBehavior.createTargetLockedLaser()
    if onServer() then
        broadcastInvokeClientFunction("createTargetLockedLaser")
        return
    end

    LaserBossBehavior.deleteCurrentLasers()
    LaserBossBehavior.createLaser(3, ColorRGB(0.1, 1.0, 0.1), true)

    LaserBossBehavior.showChargeEffect()
end

function LaserBossBehavior.createTargetingLaser()
    laserActive = true

    if onServer() then
        broadcastInvokeClientFunction("createTargetingLaser")
        return
    end

    LaserBossBehavior.deleteCurrentLasers()
    LaserBossBehavior.createLaser(1, ColorRGB(1, 0, 0), true)
end

function LaserBossBehavior.deleteCurrentLasers()
    if onServer() then
        broadcastInvokeClientFunction("deleteCurrentLasers")
        return
    end

    if valid(laser) then Sector():removeLaser(laser) end
    if valid(targetLaser) then Sector():removeLaser(targetLaser) end

    laser = nil
    targetLaser = nil
end

function LaserBossBehavior.updateLaser()
    if onClient() then
        if not valid(laser) then return end
        if not valid(targetLaser) then return end

        local bo = Entity()
        laser.from = bo.translationf - bo.look * 25
        laser.to = laser.from + bo.look * 145
        laser.aliveTime = 0

        targetLaser.from = laser.to
        targetLaser.to = laser.to + bo.look * 10000
        targetLaser.aliveTime = 0

        data.targetLaserData.from = targetLaser.from
        data.targetLaserData.to = targetLaser.to

        data.bossLook = bo.look
        data.bossRight = bo.right
        data.bossUp = bo.up

        LaserBossBehavior.syncLaserData(data.targetLaserData)
    end
end

function LaserBossBehavior.createLaser(width, color, collision)
    if onServer() then
        broadcastInvokeClientFunction("createLaser")
        return
    end

    local color = color or ColorRGB(0.1, 0.1, 0.1)
    local targetColor = color or ColorRGB(0.1, 0.1, 0.1)

    local sector = Sector()
    local bo = sector:getEntitiesByScript("laserbossbehavior.lua")

    -- laser till bow of ship
    local from = bo.translationf - bo.look * 25
    local to = from + bo.look * 145
    laser = sector:createLaser(vec3(), vec3(), color, width or 1)
    laser.collision = false
    laser.from = from
    laser.to = to

    -- laser beyond ship used for targeting
    local targetFrom = to
    local targetTo = to + bo.look * 10000
    targetLaser = sector:createLaser(vec3(), vec3(), targetColor, width or 1)
    targetLaser.collision = collision
    targetLaser.from = targetFrom
    targetLaser.to = targetTo

    -- write to extra data structure for easier intersection calc
    data.targetLaserData.from = targetLaser.from
    data.targetLaserData.to = targetLaser.to

    laser.maxAliveTime = 5
    targetLaser.maxAliveTime = 5
end

function LaserBossBehavior.createAsteroidLaser()
    if onServer() then
        broadcastInvokeClientFunction("createAsteroidLaser")
        return
    end

    local sector = Sector()
    local bo = Entity()
    local color = glowColor
    local asteroids = {sector:getEntitiesByType(EntityType.Asteroid)}
    for _, asteroid in pairs(asteroids) do
        if asteroid:getValue("laser_asteroid") then
            local as = sector:getEntity(asteroid.index)

            if not bo or not as then return end

            local laser = sector:createLaser(as.translationf, bo.translationf - bo.look * 50, color, 5.0)

            local fromIndex = as.index
            local toIndex = bo.index

            local fromLocal = vec3()
            local toLocal = vec3()

            local planA = Plan(fromIndex)
            local planB = Plan(toIndex)
            if planA then fromLocal = planA.root.box.center end
            if planB then toLocal = planB.root.box.center end

            laser.animationSpeed = 1
            laser.collision = false

            table.insert(roidLasers, {laser = laser, fromIndex = fromIndex, toIndex = toIndex, fromLocal = fromLocal, toLocal = toLocal})
        end
    end
end

function LaserBossBehavior.showChargeEffect()
    if onServer() then
        broadcastInvokeClientFunction("showChargeEffect", entity)
        return
    end

    if not laser then return end
    local from = laser.from
    local look = laser.to
    local size = 50 + 50 * math.floor(data.shotTimer)

    Sector():createGlow(from, size, ColorRGB(0.2,0.2,1))
    Sector():createGlow(from, size, ColorRGB(0.2,0.2,1))
    Sector():createGlow(from, size, ColorRGB(0.2,0.2,1))
end


function LaserBossBehavior.showExplosion(entity)
    if onServer() then
        broadcastInvokeClientFunction("showExplosion", entity)
        return
    end

    if not entity then return end
    local position = entity.translationf
    Sector():createExplosion(position, 200, false)
end

function LaserBossBehavior.startDialog()
    local boss = Entity()

    local dialog = LaserBossBehavior.makeDialog()
    local scriptUI = ScriptUI(boss.id)
    if scriptUI then
        scriptUI:interactShowDialog(dialog, false)
    end
end

function LaserBossBehavior.makeDialog()
    local dialog = {}
    local preparing = {}
    local interrupt = {}

    dialog.text = "Hey! What do you want here? I am preparing and you're interrupting! Get lost!"%_t
    dialog.answers = {
        {answer = "What are you preparing for?"%_t, followUp = preparing},
        {answer = "Watch your tone, or I'll do more than interrupt!"%_t, followUp = interrupt}
    }

    preparing.text = "I prepare for a huge fight.\n\nHey, while you're here, I could use you for target practice. Ready or not, here we go!"%_t
    preparing.onEnd = "onEndDialog"

    interrupt.text = "All right. Then I'll take care of you first!"%_t
    interrupt.onEnd = "onEndDialog"

    return dialog
end

function LaserBossBehavior.onEndDialog()
    if onClient() then invokeServerFunction("onEndDialog") end
    data.aggressive = true
    ShipAI():setAggressive()
end
callable(LaserBossBehavior, "onEndDialog")

function LaserBossBehavior.sync(data_in)
    if onServer() then
        broadcastInvokeClientFunction("sync", data)
    else
        if data_in then
            data = data_in
        else
            invokeServerFunction("sync")
        end
    end
end
callable(LaserBossBehavior, "sync")

function LaserBossBehavior.syncLaserData(data_in)
    if onClient() then
        invokeServerFunction("syncLaserData", data.targetLaserData)
    else
        data.targetLaserData = data_in
    end
end
callable(LaserBossBehavior, "syncLaserData")
