
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
local WaveUtility = include("waveutility")
local SectorGenerator = include ("SectorGenerator")
local SpawnUtility = include("spawnutility")

function getDefaults()
    return {
        waves = {},
        wreckageId = nil,
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
    createWreckage()
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
                Sector():broadcastChatMessage(enemy, ChatMessageType.Chatter, "Go away! We made this wreckage and we salvage this wreckage!"%_t)
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
                    WaveUtility.createPirateBossWave(onBossWaveGenerated)
                end
            end
        end

        if data.bossDefeated and WaveUtility.getNumEnemies() == 0 then
            sectorCleared()
        end
    end
end

function createWreckage()
    local generator = SectorGenerator(Sector():getCoordinates())
    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local wreckage = generator:createWreckage(faction, nil, 0)
    data.wreckageId = wreckage.index

    wreckage:registerCallback("onShotHit", "onWreckageHit")
    wreckage:setValue("wave_encounter_specific", true)
end

-- checks if the playership is near the enemies or the wreckage
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

    vicinity = WaveUtility.playerVicinityCheck(Entity(data.wreckageId), 200)
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
            ship.translation = Entity(data.wreckageId).translation + dvec3(x, y, z)
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

-- callback for trying to mine the asteroid
function onWreckageHit(objectIndex, shooterIndex, torpedo)
    local entity = Entity(shooterIndex)
    if entity and entity.playerOwned and data.initialEnemies then
        startEncounter()
    end
end


-- needed in multiple scenarios
function onBossWaveGenerated(generated)
    SpawnUtility.addEnemyBuffs(generated)
    for _, ship in pairs(generated) do
        ship:setValue("is_wave", true)
    end
    local boss = generated[#generated]
    local bossLoot = Loot(boss.id)

    -- adds legendary turret drop
    boss:addScriptOnce("internal/common/entity/background/legendaryloot.lua", 0.1)
    boss:addScriptOnce("utility/buildingknowledgeloot.lua")
    boss:registerCallback("onDestroyed", "onBossDefeated")

    for _, turret in pairs(WaveUtility.generateTurrets()) do
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
        Sector():broadcastChatMessage(enemyToChat, ChatMessageType.Chatter, "Why couldn't you just leave? Now we will kill you!"%_t)
        data.chatMessageSent = true
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
