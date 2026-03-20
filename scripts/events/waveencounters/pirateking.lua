
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
local WaveUtility = include("waveutility")
local SpawnUtility = include("spawnutility")
local AsyncPirateGenerator = include("asyncpirategenerator")

function getDefaults()
    return {
        waves = {},
        chatMessageSent = false,
        wavesStarted = false,
        initialEnemies = true,
        waveSpawned = false,
        waveNumber = 1,
        welcomeTimer = 10,
        welcomeTimerPassed = false,
    }
end

local data = getDefaults()

--sets the scenario
function initializeWaves()
    -- initialize scenario
    data.waves = WaveUtility.getWaves(nil, 2, nil, 4, 4)
    data.waveSpawned = false
    WaveUtility.createPirateWave(data.waveNumber, data.waves[data.waveNumber], onInitialPiratesGenerated)

    local sector = Sector()
    sector:sendCallback("onWaveEncounterStarted")
end

function updateServer(timeStep)
    if Sector().numPlayers == 0 then return end

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
            if data.welcomeTimerPassed then
                startEncounter()
            end
            local enemy = WaveUtility.getWaveMember()
            Sector():broadcastChatMessage(enemy, ChatMessageType.Chatter, "Make way for our king! Leave this sector immediately!"%_t)
            data.welcomeTimer = 40
            data.welcomeTimerPassed = true
        end
    end

    if data.waveSpawned == true then
        local numEnemies = WaveUtility.getNumEnemies()

        if numEnemies <= 2 then
            data.waveSpawned = false

            if data.waveNumber < WaveUtility.data.numWaves then
                data.waveNumber = data.waveNumber + 1
                WaveUtility.createPirateWave(data.waveNumber, data.waves[data.waveNumber], onPiratesGenerated)
                WaveUtility.createPirateWave(data.waveNumber, data.waves[data.waveNumber], onPiratesGenerated)
                createPirateKing()
            end
        end
    end

    if data.bossDefeated and WaveUtility.getNumEnemies() == 0 then
        sectorCleared()
    end
end

function createPirateKing()
    local generator = AsyncPirateGenerator(nil, onKingGenerated)
    local dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
    local up = vec3(0, 1, 0)
    local pos = dir * 1000
    generator:createScaledBoss(MatrixLookUpPosition(-dir, up, pos))
end

-- checks if the playership is near the enemies
function isPlayerClose()
    local ships = {Sector():getEntitiesByType(EntityType.Ship)}
    local vicinity = false
    for _, ship in pairs(ships) do
        if ship:getValue("is_wave") then
            vicinity = WaveUtility.playerVicinityCheck(ship, 300)
            if vicinity then
                break
            end
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
        ship:setValue("is_wave", true)
        ship:removeScript("patrol.lua")
        ship:addScript("ai/patrolpeacefully")
        ship:registerCallback("onDamaged", "onDamaged")
        local x = getVectorValue()
        local y = getVectorValue()
        local z = getVectorValue()
        ship.translation = dvec3(x, y, z)
    end

    data.waveSpawned = true
end

function onDamaged(objectIndex, amount, inflictor, damageType)
    if data.initialEnemies then
        WaveUtility.onDamaged(objectIndex, amount, inflictor, damageType)
    end
end

function getVectorValue()
    local value = random():getFloat(-300, 0)
    if value > -150 then value = value + 300 end
    return value
end

-- sets loot for king
function onKingGenerated(king)
    king:setValue("is_wave", true)

    king.name = "Pirate King"%_t
    local kingLoot = Loot(king.id)

    -- adds legendary turret drop
    king:addScriptOnce("internal/common/entity/background/legendaryloot.lua", 0.1)
    king:addScriptOnce("utility/buildingknowledgeloot.lua")
    king:registerCallback("onDestroyed", "onBossDefeated")

    for _, turret in pairs(WaveUtility.generateTurrets()) do
        kingLoot:insert(turret)
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


-- used to activate pirates which will start wave encounter
function startEncounter()
    local enemies = {Sector():getEntitiesByType(EntityType.Ship)}
    for _, enemy in pairs(enemies) do
        if enemy:getValue("is_wave") then
            if not data.chatMessageSent then
                Sector():broadcastChatMessage(enemy, ChatMessageType.Chatter, "Long live the king!"%_t)
                data.chatMessageSent = true
            end
            enemy:removeScript("patrolpeacefully.lua")
            enemy:addScript("ai/patrol")
        end
    end

    data.initialEnemies = false
end

function secure()
    return {dat = data, wdata = WaveUtility.data}
end

function restore(data_in)
    data = data_in.dat
    WaveUtility.data = data_in.wdata
end
