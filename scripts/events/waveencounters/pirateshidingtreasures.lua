
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
include("randomext")
local WaveUtility = include("waveutility")
local SpawnUtility = include("spawnutility")

function getDefaults()
    return {
        waves = {},
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
    data.waves = WaveUtility.getWaves(nil, nil, nil, nil, 2)
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
                local enemies = {Sector():getEntitiesByType(EntityType.Ship)}
                for _, enemy in pairs(enemies) do
                    if enemy:getValue("is_wave") then
                        Sector():broadcastChatMessage(enemy, ChatMessageType.Chatter, "Maybe this one? Hey! What do you want here? Leave immediately or pay the price!"%_t)
                        break
                    end
                end
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
                elseif data.waveNumber == WaveUtility.data.numWaves and not bossWaveSpawned then
                    WaveUtility.createPirateBossWave(onBossWaveGenerated)
                end
            end
        end
    end

    if data.bossDefeated and WaveUtility.getNumEnemies() == 0 then
        sectorCleared()
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
            if valid(ship) then
                ship:setValue("is_wave", true)
            end
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
            ship.translation = dvec3(x, y, z)
        end
    end

    data.waveSpawned = true
end

function getVectorValue()
    local value = random():getFloat(-300, 0)
    if value > -150 then value = value + 300 end
    return value
end

function onDamaged(objectIndex, amount, inflictor, damageType)
    if data.initialEnemies then
        WaveUtility.onDamaged(objectIndex, amount, inflictor, damageType)
    end
end

-- sets loot for boss
function onBossWaveGenerated(generated)
    SpawnUtility.addEnemyBuffs(generated)

    for _, ship in pairs(generated) do
        if valid(ship) then
            ship:setValue("is_wave", true)
        end
    end
    local boss = generated[#generated]
    local bossLoot = Loot(boss.id)

    -- adds legendary turret drop
    boss:addScriptOnce("internal/common/entity/background/legendaryloot.lua", 0.1)
    boss:addScriptOnce("utility/buildingknowledgeloot.lua")
    boss:registerCallback("onDestroyed", "onBossDefeated")

    for _, turret in pairs(WaveUtility.generateTurrets(2)) do
        bossLoot:insert(turret)
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
    local enemyToChat
    for _, enemy in pairs(enemies) do
        if enemy:getValue("is_wave") then
            ShipAI(enemy.id):setAggressive()
            enemyToChat = enemy
        end
    end
    if not data.chatMessageSent then
        Sector():broadcastChatMessage(enemyToChat, ChatMessageType.Chatter, "We warned you! Now you're gonna pay for your interference!"%_t)
        data.chatMessageSent = true
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
