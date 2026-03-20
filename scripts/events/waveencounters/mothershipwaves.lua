package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"


include("utility")
include("randomext")
local WaveUtility = include("waveutility")
local AsyncPirateGenerator = include("asyncpirategenerator")
local SpawnUtility = include("spawnutility")

local lasers = {}
local fxColor = ColorRGB(0.4, 1.0, 1.0)

function getDefaults()
    return {
        waves = {},
        mothershipId = nil,
        mothershipInactive = true,
        chatMessageSent = false,
        wavesStarted = false,
        initialEnemies = true,
        waveSpawned = false,
        waveNumber = 1,
        welcomeTimer = 10,
    }
end

local data = getDefaults()


--sets the scenario
function initializeWaves()
    -- initialize scenario
    local generator = AsyncPirateGenerator(nil, onMothershipCreated)
    generator:createScaledBoss()
    data.waves = WaveUtility.getWaves()
    data.waveSpawned = false
    WaveUtility.createPirateWave(data.waveNumber, data.waves[data.waveNumber], onInitialPiratesGenerated)

    local sector = Sector()
    sector:sendCallback("onWaveEncounterStarted")
end

function updateServer(timeStep)

    if Sector().numPlayers >= 1 then
        if not data.wavesStarted then
            initializeWaves()
            data.wavesStarted = true
        end

        if data.initialEnemies then
            if isPlayerClose() then
                startEncounter()
            end

            data.welcomeTimer = data.welcomeTimer - timeStep

            if data.welcomeTimer <= 0 then
                local enemy = WaveUtility.getWaveMember()
                Sector():broadcastChatMessage(enemy, ChatMessageType.Chatter, "The boss is busy. Just leave and you won't be harmed."%_t)
                data.welcomeTimer = 40
            end
        end

        if data.waveSpawned == true then
            local numEnemies = WaveUtility.getNumEnemies()

            if numEnemies <= 1 then
                data.waveSpawned = false

                if data.waveNumber < WaveUtility.data.numWaves then
                    data.waveNumber = data.waveNumber + 1
                    WaveUtility.createPirateWave(data.waveNumber, data.waves[data.waveNumber], onPiratesGenerated)
                elseif data.waveNumber == WaveUtility.data.numWaves then
                    data.waveNumber = data.waveNumber + 1
                    activateMothership()
                end
            end
        end
    end

    if data.bossDefeated and WaveUtility.getNumEnemies() == 0 then
        sectorCleared()
    end
end

-- sets all values for mothership (boss) including loot
function onMothershipCreated(generated)
    if not valid(generated) then return end
    data.mothershipId = generated.id
    ShipAI(generated.id):setIdle()
    ShipAI(generated.id):setPassiveShooting(false)
    generated.invincible = true
    generated:setValue("is_mothership", true)
    generated:setValue("is_wave", true)
    generated.dockable = false
    local translation = dvec3(random():getFloat(-300, 300), random():getFloat(-300, 300), random():getFloat(-300, 300))
    generated.translation = translation

    local bossLoot = Loot(generated.id)

    generated:addScriptOnce("data/scripts/entity/removeinvincibilityonsectorchanged.lua")

    -- adds legendary turret drop
    generated:addScriptOnce("internal/common/entity/background/legendaryloot.lua", 0.1)
    generated:addScriptOnce("utility/buildingknowledgeloot.lua")
    generated:registerCallback("onDestroyed", "onBossDefeated")

    for _, turret in pairs(WaveUtility.generateTurrets()) do
        bossLoot:insert(turret)
    end
end

-- checks if the playership is near the enemies
function isPlayerClose()
    local ships = {Sector():getEntitiesByType(EntityType.Ship)}
    local vicinity = false
    for _, ship in pairs(ships) do
        if ship:getValue("is_wave") then
            vicinity = WaveUtility.playerVicinityCheck(ship, 300)
            if vicinity then
                return vicinity
            end
        end
    end

    for _, ship in pairs({Sector():getEntitiesByType(EntityType.Ship)}) do
        if ship:getValue("is_mothership") then
            vicinity = WaveUtility.playerVicinityCheck(ship, 300)
        end
    end

    return vicinity
end

-- callback for generator in wavegenerator. Needed here because it doesn't work when set in wavegenerator
function onPiratesGenerated(generated)
    SpawnUtility.addEnemyBuffs(generated)
    for _, ship in pairs(generated) do
        if valid(ship) then
            ship:setValue("is_wave", true)
        end
    end

    data.waveSpawned = true
end

function onInitialPiratesGenerated(generated)
    SpawnUtility.addEnemyBuffs(generated)
    for _, ship in pairs(generated) do
        if valid(ship) then
            ship:setValue("is_wave", true)
            ShipAI(ship.id):setIdle()
            ship:registerCallback("onDamaged", "onDamaged")
            local x = getVectorValue()
            local y = getVectorValue()
            local z = getVectorValue()
            if not data.mothershipId then
                ship.translation = dvec3(x, y, z)
            else
                local entity = Entity(data.mothershipId)
                ship.translation = entity.translation + dvec3(x, y, z)
            end
        end
    end

    data.waveSpawned = true
end

function getVectorValue()
    local value = random():getFloat(-100, 0)
    if value > -50 then value = value + 100 end
    return value
end

function onDamaged(objectIndex, amount, inflictor, damageType)
    if data.initialEnemies then
        WaveUtility.onDamaged(objectIndex, amount, inflictor, damageType)
    end
end

function onBossDefeated()
    data.bossDefeated = true
end

function sectorCleared()
    Sector():sendCallback("onWaveEncounterFinished")
    broadcastInvokeClientFunction("showClearedMessage")
    WaveUtility.increaseLootGoonPityCounter()
    WaveUtility.improveReputation()
    terminate()
end

function showClearedMessage()
    if onServer() then return end

    WaveUtility.showSectorCleared()
end


-- wakes up mothership to get used as boss
function activateMothership()
    data.mothershipInactive = false
    for _, ship in pairs({Sector():getEntitiesByType(EntityType.Ship)}) do
        if ship:getValue("is_mothership") then
            ShipAI(ship):setAggressive()
            ship.invincible = false
            Sector():broadcastChatMessage(ship, ChatMessageType.Chatter, "Who are you supposed to be, you maggot? I'll teach you some manners!"%_t)
        end
    end

    local bossWave = {3, 3, 4, 4}
    WaveUtility.createPirateWave(data.waveNumber, bossWave, onPiratesGenerated)
    data.waveSpawned = false
end

-- used to activate pirates which will start wave encounter
function startEncounter()
    local enemies = {Sector():getEntitiesByType(EntityType.Ship)}
    for _, enemy in pairs(enemies) do
        if enemy:getValue("is_wave") then
            if not data.chatMessageSent then
                Sector():broadcastChatMessage(enemy, ChatMessageType.Chatter, "You should have left us alone. We already called reinforcements. Get ready to die!"%_t)
                data.chatMessageSent = true
            end
            ShipAI(enemy.id):setAggressive()
        end
    end

    data.initialEnemies = false
end

function secure()
    return {dat = data, wdata = WaveUtility.data}
end

function restore(data_in)
    data_in = data_in or {}

    data = data_in.dat or getDefaults()
    WaveUtility.data = data_in.wdata or {}
end


function updateClient()
    local nearby = getNearbyWaveShips()
    updateLasers(nearby)
end

function getNearbyWaveShips()
    local ships = {Sector():getEntitiesByType(EntityType.Ship)}
    local nearby = {}

    for _, ship in pairs(ships) do
        if ship:getValue("is_wave") then
            nearby[ship.id.string] = ship
        end
    end

    return nearby
end


function updateLasers(nearbyShips)
    local sector = Sector()
    local mothership = nil
    for _, ship in pairs({sector:getEntitiesByType(EntityType.Ship)}) do
        if ship:getValue("is_mothership") then
            mothership = ship
        end
    end
    if not mothership or not mothership.invincible then return end

    for _, ship in pairs(nearbyShips) do
        local laser = lasers[ship.id.string]
        if not laser or not valid(laser.laser) then
            laser = {}
            laser.ship = ship
            laser.laser = sector:createLaser(mothership.translationf, ship.translationf, fxColor, 2)
            laser.laser.maxAliveTime = 3
            laser.laser.collision = false
            laser.laser.animationSpeed = 1
            laser.laser.shape = BeamShape.Swirly
            laser.laser.shapeSize = 5
            laser.laser.sound = "weapon/laser_heal"

            lasers[ship.id.string] = laser
        end

        -- prolong alive time
        laser.laser.maxAliveTime = laser.laser.aliveTime + 1
    end

    for k, laser in pairs(lasers) do
        local inRange = valid(laser.ship) and nearbyShips[laser.ship.id.string]

        if inRange and valid(laser.laser) then
            laser.laser.from = mothership.translationf
            laser.laser.to = laser.ship.translationf
        else
            lasers[k] = nil

            if valid(laser.laser) then
                sector:removeLaser(laser.laser)
            end
        end
    end
end
