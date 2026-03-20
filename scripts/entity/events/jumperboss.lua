package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local ShipUtility = include("shiputility")
local TurretGenerator = include ("turretgenerator")
local Balancing = include("galaxy")

local stunned = Timer()
local chatter = Timer()
local firstChatter = true
local firstChatterEnergy = true
local aggressive = true
local stunDuration = 5
local chatterDuration = 30
local isStunned = false
local explosionCounter = 0

local glowColor = ColorRGB(0.2, 0.2, 0.5)

local torpedoesLaunched = {}

function initialize()
    if onClient() then
        registerBoss(Entity().index)
    else
        local entity = Entity()
        entity:registerCallback("onDamaged", "onDamaged")
        entity:registerCallback("onDestroyed", "onDestroyed")
        stunned:start()
        chatter:start()

        -- set aggressive and at war
        local players = {Sector():getPlayers()}
        for _, player in pairs(players) do
            Galaxy():setFactionRelations(Faction(entity.factionIndex), player, -100000)
            Galaxy():setFactionRelationStatus(Faction(entity.factionIndex), player, RelationStatus.War)
        end
    end
end

function updateServer(timestep)
    if stunned.seconds > stunDuration then
        if isStunned then
            isStunned = false
            sync()
        end

        if not aggressive then
            ShipAI(Entity().id):setAggressive()
            aggressive = true
            onJump() -- immediately jump away after stun is over
        end
    end
end

function updateClient()
    if isStunned then showGlowAndSparks() end
end

function onDamaged(objectIndex, amount, inflictor, damageSource, damageType)
    local entity = Entity()
    -- get stunned by electric weapons, jump away if hit with any other kind of damage
    if damageType == DamageType.Electric then
        onStunned()
    else
        if stunned.seconds > stunDuration then
            onJump()
        end
    end
end

function onDestroyed()
    local info = makeCallbackSenderInfo(Entity())
    for _, player in pairs({Sector():getPlayers()}) do
        player:sendCallback("onJumperBossDestroyed", info)
    end
end

function onStunned()
    local entity = Entity()
    stunned:restart()
    if aggressive then
        ShipAI(entity.id):stop()
        aggressive = false
    end
    if chatter.seconds > chatterDuration or firstChatterEnergy then
        Sector():broadcastChatMessage(entity, ChatMessageType.Chatter, "My jumpsystems will be back online shortly - you can't hold me forever!"%_T)
        firstChatterEnergy = false
        chatter:restart()
    end

    -- add some kind of effect
    isStunned = true
    explosionCounter = 0
    sync()
end

function sync(stunValue)
    if stunValue == nil then
        if onServer() then
            broadcastInvokeClientFunction("sync", isStunned)
        end
    else
        isStunned = stunValue
    end
end

function showGlowAndSparks()
    if onServer() then
        print("broadcastnow")
        broadcastInvokeClientFunction("showGlow")
        return
    end
    local sector = Sector()
    local entity = Entity()

    sector:createGlow(entity.translationf, 80 + 50 * math.random(), glowColor)
    sector:createGlow(entity.translationf, 80 + 50 * math.random(), glowColor)
    sector:createGlow(entity.translationf, 80 + 50 * math.random(), glowColor)
    explosionCounter = explosionCounter + 1
    if explosionCounter == 1 then
        sector:createExplosion(entity.translationf, 3, true)
    elseif explosionCounter > 30 then
        explosionCounter = 0
    end

end

local rand = Random(Seed(151))
function onJump()
    local entity = Entity()
    local startPosition = entity.translation
    local newPosition = dvec3(rand:getInt(500, 1000), rand:getInt(500, 1000), rand:getInt(500, 1000))
    local normalizedStartPosition = normalize(startPosition)
    local normalizedNewPosition = normalize(newPosition)
    local scalarProduct = normalizedStartPosition.x * normalizedNewPosition.x + normalizedStartPosition.y * normalizedNewPosition.y + normalizedStartPosition.z * normalizedNewPosition.z

    if scalarProduct > 0 then
        newPosition = -newPosition
    end
    entity.translation = newPosition

    if chatter.seconds > chatterDuration or firstChatter then
        Sector():broadcastChatMessage(Entity(), ChatMessageType.Chatter, "Hahaha, your common weapons don't phase me! You'll need something better to short-circuit my jump engine!"%_T)
        firstChatter = false
        chatter:restart()
    end
end

