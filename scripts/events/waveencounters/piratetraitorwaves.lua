
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
local WaveUtility = include("waveutility")
local AsyncPirateGenerator = include("asyncpirategenerator")
local SpawnUtility = include("spawnutility")

function getDefaults()
    return {
        waves = {},
        traitorId = nil,
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
    local generator = AsyncPirateGenerator(nil, onTraitorCreated)
    generator:createScaledMarauder()
    data.waves = WaveUtility.getWaves()
    data.waveSpawned = false

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
                Sector():broadcastChatMessage(enemy, ChatMessageType.Chatter, "We need to deal with a traitor. We don't need no witnesses."%_t)
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

function onTraitorCreated(generated)
    local traitor = generated
    data.traitorId = traitor.index
    local pirateFaction = AsyncPirateGenerator():getPirateFaction()

    local factionName = "${pirates} Traitor"%_T % {pirates = pirateFaction.name}

    local faction = Galaxy():findFaction(factionName)
    if not faction then
        faction = Galaxy():createFaction(factionName, Sector():getCoordinates())
    end

    generated.factionIndex = faction.index
    local translation = dvec3(random():getFloat(-300, 300), random():getFloat(-300, 300), random():getFloat(-300, 300))
    generated.translation = translation
    generated:registerCallback("onDestroyed", "startEncounter")
    generated:setValue("wave_encounter_specific", true)

    -- spawn henchmen
    WaveUtility.createPirateWave(data.waveNumber, data.waves[data.waveNumber], onInitialPiratesGenerated)
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
            ship:registerCallback("onDamaged", "onDamaged")
            local x = getVectorValue()
            local y = getVectorValue()
            local z = getVectorValue()
            local traitor = Entity(data.traitorId)
            ship.translation = traitor.translation + dvec3(x, y, z)
            ShipAI(ship.id):setAttack(traitor)
        end
    end

    data.waveSpawned = true
end

-- callback for generator in wavegenerator. Needed here because it doesn't work when set in wavegenerator
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


function getVectorValue()
    local value = random():getFloat(-400, 0)
    if value > -200 then value = value + 400 end
    return value
end

function onDamaged(objectIndex, amount, inflictor, damageType)
    if data.initialEnemies then
        WaveUtility.onDamaged(objectIndex, amount, inflictor, damageType)
    end
end

-- used to activate pirates which will start wave encounter
function startEncounter()
    local enemies = {Sector():getEntitiesByType(EntityType.Ship)}
    for _, enemy in pairs(enemies) do
        if enemy:getValue("is_wave") then
            if not data.chatMessageSentd then
                Sector():broadcastChatMessage(enemy, ChatMessageType.Chatter, "We told you we need no witness, now we have to eradicate you."%_t)
                data.chatMessageSentd = true
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
    data = data_in.dat
    WaveUtility.data = data_in.wdata
end
