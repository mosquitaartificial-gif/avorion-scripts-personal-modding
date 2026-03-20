
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
        provocationEnded = false,
        provocationSent = false,
        provocationTimer = 20,
        wavesStarted = false,
        initialEnemies = true,
        waveSpawned = false,
        waveNumber = 1,
    }
end

local data = getDefaults()


--sets the scenario
function initializeWaves()
    -- initialize scenario
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

        if not data.provocationEnded then
            data.provocationTimer = data.provocationTimer - timeStep
        end

        if data.provocationTimer <= 0 then
            provoke()
            data.provocationTimer = 30
            data.provocationSent = false
        end


        if data.initialEnemies and isPlayerClose() then
            startEncounter()
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

function provoke()
    local enemies = {Sector():getEntitiesByType(EntityType.Ship)}
    local provocations = {
        "You call this a ship? More like a dump!"%_t,
        "Look at this! I thought only intelligent species were allowed to fly ships."%_t,
        "If you fell into a black hole, that would be a misfortune. But if someone saved you, that would be a calamity."%_t,
        "Your mother was a hamster and your father smelt of elderberries!"%_t,
        "We fart in your general direction."%_t
        }

    local provocation = provocations[random():getInt(1, #provocations)]
    for _, enemy in pairs(enemies) do
        if enemy:getValue("is_wave") and not data.provocationSent then
            Sector():broadcastChatMessage(enemy, ChatMessageType.Chatter, provocation)
            data.provocationSent = true
        end
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
    for _, enemy in pairs(enemies) do
        if enemy:getValue("is_wave") then
            if not data.chatMessageSent then
                Sector():broadcastChatMessage(enemy, ChatMessageType.Chatter, "Oh yeah? You think you're tough? My men and I will get you!"%_t)
                data.chatMessageSent = true
            end
            ShipAI(enemy.id):setAggressive()
        end
    end

    data.provocationEnded = true
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
