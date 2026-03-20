package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("randomext")
include ("stringutility")
include ("callable")
include ("relations")
local ShipUtility = include ("shiputility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace AsteroidShieldBoss
AsteroidShieldBoss = {}

AsteroidShieldBoss.numAsteroidsLeft = 4
AsteroidShieldBoss.invincible = true
AsteroidShieldBoss.lasers = {}
AsteroidShieldBoss.glowColor = ColorRGB(0.1, 0.3, 0.5)
AsteroidShieldBoss.aggressive = false

function AsteroidShieldBoss.initialize()
    if onClient() then
        registerBoss(Entity().index) -- for fancy boss health bar
    else
        AsteroidShieldBoss.aggressive = false

        Sector():registerCallback("onPlayerArrivalConfirmed", "onPlayerArrivalConfirmed")
        Entity():registerCallback("onDestroyed", "onDestroyed")
    end
end

function AsteroidShieldBoss.onPlayerArrivalConfirmed(playerIndex)
    if not AsteroidShieldBoss.aggressive then
        invokeClientFunction(Player(playerIndex), "startDialog")
    end
end

function AsteroidShieldBoss.update(timestep)
    if not done then
        AsteroidShieldBoss.createBeams()
        done = true
    end

    AsteroidShieldBoss.updateShield()
    AsteroidShieldBoss.updateLaserBeams()
end

function AsteroidShieldBoss.updateShield()
    -- take no shield damage until all asteroids have been destroyed
    if AsteroidShieldBoss.invincible then
        AsteroidShieldBoss.numAsteroidsLeft = 0
        local sector = Sector()
        local asteroids = {sector:getEntitiesByType(EntityType.Asteroid)}
        -- update glow effect for shield asteroids while we count them anyway -> glow dies with asteroid
        for _, asteroid in pairs(asteroids) do
            if asteroid:getValue("shield_asteroid") then
                AsteroidShieldBoss.numAsteroidsLeft = AsteroidShieldBoss.numAsteroidsLeft + 1
                -- glow - multiple to get a good strong glow that fits lasers
                if onClient() then sector:createGlow(asteroid.translationf, 160, AsteroidShieldBoss.glowColor) end
                if onClient() then sector:createGlow(asteroid.translationf, 160, AsteroidShieldBoss.glowColor) end
                if onClient() then sector:createGlow(asteroid.translationf, 160, AsteroidShieldBoss.glowColor) end
                if onClient() then sector:createGlow(asteroid.translationf, 160, AsteroidShieldBoss.glowColor) end
            end
        end
        if AsteroidShieldBoss.numAsteroidsLeft == 0 then            
            AsteroidShieldBoss.toggleInvincibility()
        end
    end
    AsteroidShieldBoss.setBossShieldDurability(AsteroidShieldBoss.numAsteroidsLeft)
end

function AsteroidShieldBoss.updateLaserBeams()
    if onClient() then
        -- update the positions of the laser endpoints
        local sector = Sector()
        for k, p in pairs(AsteroidShieldBoss.lasers) do
            local laser = p.laser
            local a = sector:getEntity(p.fromIndex)
            local b = sector:getEntity(p.toIndex)

            if valid(laser) and a and b then
                local from = a.position:transformCoord(p.fromLocal)
                local to = b.position:transformCoord(p.toLocal)

                laser.from = from
                laser.to = to
            else
                if valid(laser) then sector:removeLaser(laser) end
                AsteroidShieldBoss.lasers[k] = nil
            end
        end
    end
end

function AsteroidShieldBoss.onDestroyed()
    local info = makeCallbackSenderInfo(Entity())
    for _, player in pairs({Sector():getPlayers()}) do
        player:sendCallback("onAsteroidShieldBossDestroyed", info)
    end
end

function AsteroidShieldBoss.toggleInvincibility()
    local boss = Sector():getEntitiesByScript("asteroidshieldboss.lua")
    if not boss then return end
    boss.invincible = false
    AsteroidShieldBoss.invincible = false
end

function AsteroidShieldBoss.setBossShieldDurability(numberAsteroids)
    local boss = Sector():getEntitiesByScript("asteroidshieldboss.lua")
    if not boss then return end
    if boss.shieldDurability <= 0 then return end


    local multiplier = 0.25 * numberAsteroids
    if multiplier > 1 then multiplier = 1 end
    boss.shieldDurability = boss.shieldMaxDurability * multiplier
end

function AsteroidShieldBoss.startDialog()
    local boss = Sector():getEntitiesByScript("asteroidshieldboss.lua")

    local dialog = {}
    local newTech = {}
    local provoke = {}
    local questions = {}
    local peaceout = {}

    dialog.text = "Hey you. Leave me alone. I am testing a new technology. You won't be able to hurt me anyway."%_t
    dialog.answers = {
        {answer = "Which new technology?"%_t, followUp = newTech},
        {answer = "I won't take orders from you (attack)."%_t, followUp = provoke},
        {answer = "Ok, I won't bother you."%_t, followUp = peaceout}
    }

    newTech.text = "You wouldn't understand the technical details, but in the end my ship will be indestructible."%_t
    newTech.answers = {
        {answer = "Try me."%_t, followUp = questions},
        {answer = "Indestructible? We will see... (attack)"%_t, followUp = provoke},
        {answer = "Ok, I won't bother you anymore."%_t, followUp = peaceout}
    }

    questions.text = "I said you wouldn't understand. Leave or I will have to teach you a lesson."%_t
    questions.answers = {
        {answer = "What are the technical details?"%_t, followUp = provoke},
        {answer = "Maybe I should teach YOU a lesson!"%_t, followUp = provoke},
        {answer = "Ok, I'll leave now."%_t, followUp = peaceout}
    }

    provoke.text = "Enough joking. I will show you my superiority."%_t
    provoke.onEnd = "onEndDialogAggressive"

    peaceout.text = "Just don't come too close. I'll shoot."%_t
    peaceout.onEnd = "onEndDialogPassive"

    local scriptUI = ScriptUI(boss.id)
    if scriptUI then
        scriptUI:interactShowDialog(dialog, false)
    else
        AsteroidShieldBoss.onEndDialog()
    end
end

function AsteroidShieldBoss.onEndDialogAggressive()
    if onClient() then invokeServerFunction("onEndDialogAggressive") return end

    -- set boss aggressive
    AsteroidShieldBoss.aggressive = true
    local entity = Entity()
    local bossFaction = Faction(entity.factionIndex)
    local galaxy = Galaxy()
    local players = {Sector():getPlayers()}
    local bossAI = ShipAI(entity.id)

    for _, player in pairs(players) do
        galaxy:setFactionRelations(bossFaction, player, -100000)
        galaxy:setFactionRelationStatus(bossFaction, player, RelationStatus.War)

        bossAI:registerEnemyFaction(player.index)
        if player.allianceIndex then
            bossAI:registerEnemyFaction(player.allianceIndex)
        end
    end

    bossAI:setAggressive()
end
callable(AsteroidShieldBoss, "onEndDialogAggressive")

function AsteroidShieldBoss.onEndDialogPassive()
    if onClient() then invokeServerFunction("onEndDialogPassive") return end

    -- set boss passive until player damages him or the asteroids
    local entity = Entity()
    Sector():registerCallback("onDamaged", "onSetAggressive")
    ShipAI(entity.id):setPassive()
    AsteroidShieldBoss.aggressive = false
end
callable(AsteroidShieldBoss, "onEndDialogPassive")

function AsteroidShieldBoss.onSetAggressive(objectIndex, amount, inflictor, damageType)
    if onClient() then
        ScriptUI():stopInteraction()
        invokeServerFunction("onSetAggressive")
        return
    end

    if AsteroidShieldBoss.aggressive then return end

    -- if player damages anything boss turns aggressive
    Sector():broadcastChatMessage(boss, ChatMessageType.Chatter, "I said don't touch anything!"%_T)
    AsteroidShieldBoss.onEndDialogAggressive()
end
callable(AsteroidShieldBoss, "onSetAggressive")

function AsteroidShieldBoss.createBeams()
    if onServer() then
        broadcastInvokeClientFunction("createBeams")
        return
    end
    local color = AsteroidShieldBoss.glowColor

    local sector = Sector()
    local bo = sector:getEntitiesByScript("asteroidshieldboss.lua")
    local asteroids = {sector:getEntitiesByType(EntityType.Asteroid)}
    for _, asteroid in pairs(asteroids) do
        if asteroid:getValue("shield_asteroid") then
            local as = sector:getEntity(asteroid.index)

            if not bo or not as then return end

            local laser = sector:createLaser(as.translationf, bo.translationf, color, 2.0)

            local fromIndex = as.index
            local toIndex = bo.index

            local fromLocal = vec3()
            local toLocal = vec3()

            local planA = Plan(fromIndex)
            local planB = Plan(toIndex)
            if planA then fromLocal = planA.root.box.center end
            if planB then toLocal = planB.root.box.center end

            laser.animationSpeed = -500
            laser.collision = false

            table.insert(AsteroidShieldBoss.lasers, {laser = laser, fromIndex = fromIndex, toIndex = toIndex, fromLocal = fromLocal, toLocal = toLocal})
        end
    end
end
