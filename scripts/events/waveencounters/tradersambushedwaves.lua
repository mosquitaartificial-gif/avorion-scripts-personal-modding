
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("utility")
local WaveUtility = include("waveutility")
local SectorGenerator = include ("SectorGenerator")
local SpawnUtility = include("spawnutility")


function getDefaults()
    return {
        waves = {},
        wreckageIds = {},
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
    createWreckages()
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
                Sector():broadcastChatMessage(enemy, ChatMessageType.Chatter, "This is our prey. Go away!"%_t)
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

function createWreckages()
    local generator = SectorGenerator(Sector():getCoordinates())
    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    for i = 1, 3 do
        rand = Random():getInt(0, 3)
        local wreckage = generator:createWreckage(faction, nil, rand)
        wreckage:setValue("wave_encounter_specific", true)
        local wreckageId = wreckage.index
        table.insert(data.wreckageIds, wreckageId)
    end

    local wreckages = {Sector():getEntitiesByType(EntityType.Wreckage)}
    for _, tmpWreckage in pairs(wreckages) do
        tmpWreckage:registerCallback("onShotHit", "onWreckageHit")
    end
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

    for wreckageId in pairs(data.wreckageIds) do
        vicinity = WaveUtility.playerVicinityCheck(Entity(wreckageId), 200)
        if vicinity then
            return vicinity
        end
    end
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
            rand = Random():getInt(1, #data.wreckageIds)
            ship.translation = Entity(data.wreckageIds[rand]).translation + dvec3(x, y, z)
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
    local shooter = Entity(shooterIndex)
    if shooter and shooter.playerOwned and data.initialEnemies then
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
        Sector():broadcastChatMessage(enemyToChat, ChatMessageType.Chatter, "Oh well, looks like we've found our next target."%_t)
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
