package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
package.path = package.path .. ";data/scripts/systems/?.lua"

include("randomext")
include("relations")
local AsyncPirateGenerator = include("asyncpirategenerator")
local PirateGenerator = include("pirategenerator")
local AsyncShipGenerator = include("asyncshipgenerator")
local AsyncXsotanGenerator = include ("asyncxsotangenerator")
local Xsotan = include("story/xsotan")
local SectorTurretGenerator = include("sectorturretgenerator")
local FactionEradicationUtility = include("factioneradicationutility")
local SectorSpecifics = include("sectorspecifics")

local WaveUtility = {}
WaveUtility.__index = WaveUtility

local waves = {}

local lvl1 = 1
local lvl2 = 2
local lvl3 = 3
local lvl4 = 4
local lvl5 = 5
local lvl6 = 6
local lvl7 = 7

WaveUtility.data = {}
WaveUtility.data.startingWave = nil
WaveUtility.data.numWaves = nil
WaveUtility.data.waveStrength = nil
WaveUtility.data.waveSize = nil
WaveUtility.data.waveStep = nil


-- waves should be taken from the middle of the table the two rows/columns on the edge are a buffer
-- optimal range for average wave strength is between waves 7 and 12 from column 2 to 5
waves[1] =  {lvl1,  lvl2,  lvl1,  lvl2,  lvl2,  lvl3,  lvl2,  lvl3}
waves[2] =  {lvl2,  lvl1,  lvl2,  lvl2,  lvl3,  lvl2,  lvl3,  lvl3}
waves[3] =  {lvl1,  lvl2,  lvl2,  lvl3,  lvl2,  lvl3,  lvl3,  lvl4}
waves[4] =  {lvl2,  lvl2,  lvl3,  lvl2,  lvl3,  lvl3,  lvl4,  lvl3}
waves[5] =  {lvl2,  lvl3,  lvl2,  lvl3,  lvl3,  lvl4,  lvl3,  lvl4}
waves[6] =  {lvl3,  lvl2,  lvl3,  lvl3,  lvl4,  lvl3,  lvl4,  lvl4}
waves[7] =  {lvl2,  lvl3,  lvl3,  lvl4,  lvl3,  lvl4,  lvl4,  lvl5}
waves[8] =  {lvl3,  lvl3,  lvl4,  lvl3,  lvl4,  lvl4,  lvl5,  lvl4}
waves[9] =  {lvl3,  lvl4,  lvl3,  lvl4,  lvl4,  lvl5,  lvl4,  lvl5}
waves[10] = {lvl4,  lvl3,  lvl4,  lvl4,  lvl5,  lvl4,  lvl5,  lvl5}
waves[11] = {lvl3,  lvl4,  lvl4,  lvl5,  lvl4,  lvl5,  lvl5,  lvl6}
waves[12] = {lvl4,  lvl4,  lvl5,  lvl4,  lvl5,  lvl5,  lvl6,  lvl5}
waves[13] = {lvl4,  lvl5,  lvl4,  lvl5,  lvl5,  lvl6,  lvl5,  lvl6}
waves[14] = {lvl5,  lvl4,  lvl5,  lvl5,  lvl6,  lvl5,  lvl6,  lvl6}
waves[15] = {lvl4,  lvl5,  lvl5,  lvl6,  lvl5,  lvl6,  lvl6,  lvl7}
waves[16] = {lvl5,  lvl5,  lvl6,  lvl5,  lvl6,  lvl6,  lvl7,  lvl6}
waves[17] = {lvl5,  lvl6,  lvl5,  lvl6,  lvl6,  lvl7,  lvl6,  lvl7}
waves[18] = {lvl6,  lvl5,  lvl6,  lvl6,  lvl7,  lvl6,  lvl7,  lvl7}
waves[19] = {lvl5,  lvl6,  lvl6,  lvl7,  lvl6,  lvl7,  lvl7,  lvl7}

function WaveUtility.getWaves(startingWave, numWaves, waveStrength, waveSize, waveStep)
    local x, y = Sector():getCoordinates()
    local distToCenter = math.sqrt(x * x + y * y)

    WaveUtility.data.startingWave = startingWave or round(lerp(distToCenter, 0, 500, 9, 1))

    -- note: this is balanced to feel good with building knowledge progression
    -- ONLY CHANGE IF YOU KEEP BUILDING PROGRESSION IN MIND
    if distToCenter >= 400 then
        WaveUtility.data.numWaves = numWaves or 2
    elseif distToCenter >= 240 then
        WaveUtility.data.numWaves = numWaves or 3
    else
        WaveUtility.data.numWaves = numWaves or 4
    end

    -- note: this is balanced to feel good with building knowledge progression
    -- ONLY CHANGE IF YOU KEEP BUILDING PROGRESSION IN MIND
    if distToCenter >= 430 then
        WaveUtility.data.waveSize = waveSize or 2
    elseif distToCenter >= 350 then
        WaveUtility.data.waveSize = waveSize or 3
    else
        WaveUtility.data.waveSize = waveSize or 4
    end

    WaveUtility.data.waveStrength = waveStrength or round(lerp(distToCenter, 0, 500,  5, 1))
    WaveUtility.data.waveStep = waveStep or 1

    -- change startingWave according number of players with one player as default
    local playerDifficulty = Sector().numPlayers - 1
    if playerDifficulty > 3 then
        playerDifficulty = 4
    end

    local result = {}
    local maxWaveIndex = #waves
    local maxWaveStrength = #waves[1]
    local clampedHeight = false
    local clampedWidth = false
    for i = WaveUtility.data.startingWave, (WaveUtility.data.startingWave + (WaveUtility.data.numWaves * WaveUtility.data.waveStep) - 1), WaveUtility.data.waveStep do
        if i > maxWaveIndex then
            i = maxWaveIndex
            clampedHeight = true
        end

        local wave = {}
        for j = WaveUtility.data.waveStrength, (WaveUtility.data.waveStrength + WaveUtility.data.waveSize - 1) do
            if j > maxWaveStrength then
                j = maxWaveStrength
                clampedWidth = true
            end

            table.insert(wave, waves[i][j])
        end

        table.insert(result, wave)
    end

    -- warn user about overstepping boundaries
    if clampedHeight then
        eprint("WaveUtility: Requested invalid level " .. (WaveUtility.data.startingWave + (WaveUtility.data.numWaves * WaveUtility.data.waveStep) - 1) .. ": Using last valid index instead.")
    end

    if clampedWidth then
        eprint("WaveUtility: Requested invalid wave width " .. (WaveUtility.data.waveStrength + WaveUtility.data.waveSize - 1) .. ": Using last valid index instead.")
    end

    return result
end

function WaveUtility.createPirateWave(waveNumber, wave, callback, position)
    local up, pos, dir
    if position then
        up = position.up
        dir = position.look
        pos = position.pos + dir * 1000
    else
        up = vec3(0, 1, 0)
        dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
        pos = dir * 1000
    end

    local right = normalize(cross(dir, up))
    local distance = 150 -- distance between pirate ships

    if waveNumber == 2 then
        WaveUtility.trySpawnBackup(up, pos, dir, right, distance)
    end

    local generator = AsyncPirateGenerator(nil, callback)
    generator:startBatch()

    local counter = 0
    for _, level in pairs(wave) do
        if level == 1 then
            generator:createScaledOutlaw(MatrixLookUpPosition(-dir, up, pos + right * distance * counter))
        elseif level == 2 then
            generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos + right * distance * counter))
        elseif level == 3 then
            generator:createScaledPirate(MatrixLookUpPosition(-dir, up, pos + right * distance * counter))
        elseif level == 4 then
            if random():getFloat(0, 1) >= 0.25 then
                generator:createScaledMarauder(MatrixLookUpPosition(-dir, up, pos + right * distance * counter))
            else
                generator:createScaledDisruptor(MatrixLookUpPosition(-dir, up, pos + right * distance * counter))
            end
        elseif level == 5 then
            generator:createScaledRaider(MatrixLookUpPosition(-dir, up, pos + right * distance * counter))
        elseif level == 6 then
            generator:createScaledRavager(MatrixLookUpPosition(-dir, up, pos + right * distance * counter))
        elseif level == 7 then
            generator:createScaledBoss(MatrixLookUpPosition(-dir, up, pos + right * distance * counter))
        else
            print("WaveUtility: Couldn't find level")
        end
        counter = counter + 1
    end

    -- try spawning lootgoon
    if waveNumber ~= 1 then
        WaveUtility.trySpawnLootGoon(generator, up, pos + right * distance * (counter + 1))
    end

    generator:endBatch()
end

function WaveUtility.createPirateBossWave(callback)
    local bossWave = {}
    -- skips one wave to make the bossWave stronger than the expected wave in normal order would be, unless we already have the highest wave
    wave = WaveUtility.data.startingWave + (WaveUtility.data.numWaves * WaveUtility.data.waveStep) + WaveUtility.data.waveStep + 1
    if wave > 19 then wave = 19 end

    for i = WaveUtility.data.waveStrength, (WaveUtility.data.waveStrength + WaveUtility.data.waveSize - 1) do
        table.insert(bossWave, waves[wave][i])
    end

     WaveUtility.createPirateWave(nil, bossWave, callback)
end

function WaveUtility.trySpawnLootGoon(generator, up, pos)
    local dir = random():getDirection()
    local matrix = MatrixLookUpPosition(-dir, up, pos)
    local resetAllPityCounters = false

    -- spawn loot goon with a chance of 1/50, each wave
    if random():test(0.02) then
        generator:createScaledLootGoon(matrix)
        resetAllPityCounters = true
    else
        -- spawn lootgoon if there hasn't been a lootgoon for 10 waveencounters
        for _, player in pairs({Sector():getPlayers()}) do
            local counter = player:getValue("loot_goon_pity_counter") or 0
            if counter >= 10 then
                generator:createScaledLootGoon(matrix)
                resetAllPityCounters = true
                break
            end
        end
    end

    if resetAllPityCounters == true then
        for _, player in pairs({Sector():getPlayers()}) do
            player:setValue("loot_goon_pity_counter", 0)
        end
    end
end

function WaveUtility.createXsotanWave(waveNumber, wave, position, lootGoonChance, spacing)
    waveNumber = waveNumber or 1
    wave = wave or waves[7]

    local ships = {}

    local up, pos, dir
    if position then
        up = position.up
        dir = position.look
        pos = position.pos + dir * 1500
    else
        up = vec3(0, 1, 0)
        dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
        pos = dir * 1000
    end

    local right = normalize(cross(dir, up))
    local distance = spacing or 250 -- distance between Xsotan ships

    local scalesPerLevel = {0.5, 1, 1.5, 2, 2.5, 3, 3.5}
    local counter = 0
    local ship
    for _, level in pairs(wave) do
        local position = MatrixLookUpPosition(-dir, up, pos + random():getDirection() * distance * counter)
        local scale = scalesPerLevel[level] or 2

        if random():test(0.2) then
            local decider = random():getInt(1, 3)
            if decider == 1 then
                ship = Xsotan.createLongRange(position, scale)
            elseif decider == 2 then
                ship = Xsotan.createShortRange(position, scale)
            else
                ship = Xsotan.createDasher(position, scale)
            end
        else
            ship = Xsotan.createShip(position, scale)
        end

        counter = counter + 1
        ship:setValue("is_wave", true)
        table.insert(ships, ship)
    end

    -- try spawning lootgoon - higher chance for xsotan loot goons is on purpose
    -- they are harder to kill and identify
    if random():test(lootGoonChance or 0.03) then
        local position = MatrixLookUpPosition(-dir, up, pos + right * distance * (counter + 1))
        local ship = Xsotan.createLootGoon(position)
        table.insert(ships, ship)
    end

    return ships
end

function WaveUtility.createXsotanWaveAsync(waveNumber, wave, position, lootGoonChance, spacing, namespace, callback)
    waveNumber = waveNumber or 1
    wave = wave or waves[7]

    local up, pos, dir
    if position then
        up = position.up
        dir = position.look
        pos = position.pos + dir * 1500
    else
        up = vec3(0, 1, 0)
        dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
        pos = dir * 1000
    end

    local right = normalize(cross(dir, up))
    local distance = spacing or 250 -- distance between Xsotan ships

    local generator = AsyncXsotanGenerator(namespace, callback or function(generated)
        for _, ship in pairs(generated) do
            ship:setValue("is_wave", true)
        end
    end)

    generator:startBatch()

    local scalesPerLevel = {0.5, 1, 1.5, 2, 2.5, 3, 3.5}

    local counter = 0
    for _, level in pairs(wave) do
        local position = MatrixLookUpPosition(-dir, up, pos + random():getDirection() * distance * counter)
        local scale = scalesPerLevel[level] or 2

        if random():test(0.2) then
            local decider = random():getInt(1, 3)
            if decider == 1 then
                generator:createLongRange(position, scale)
            elseif decider == 2 then
                generator:createShortRange(position, scale)
            else
                generator:createDasher(position, scale)
            end
        else
            generator:createShip(position, scale)
        end

        counter = counter + 1
    end

    -- try spawning lootgoon - higher chance for xsotan loot goons is on purpose
    -- they are harder to kill and identify
    if random():test(lootGoonChance or 0.03) then
        local position = MatrixLookUpPosition(-dir, up, pos + right * distance * (counter + 1))
        generator:createLootGoon(position)
    end

    generator:endBatch()
end

function WaveUtility.trySpawnBackup(up, pos, dir, right, distance)
    -- find neighboring brave faction
    local sector = Sector()
    local galaxy = Galaxy()

    local x, y = sector:getCoordinates()
    local specs = SectorSpecifics()
    local regular, offgrid, blocked, home = specs:determineContent(x, y, Server().seed)
    if blocked then return end -- don't spawn in rifts

    local faction = galaxy:getLocalFaction(x, y)
    if not faction then return end

    if FactionEradicationUtility.isFactionEradicated(faction.index) then return end

    -- the faction has to be at least 25% brave
    -- 100% brave means 50% probability
    local backupProbability = lerp(faction:getTrait("brave"), 0.25, 1, 0, 0.5)
    if not random():test(backupProbability) and not alwaysSendBackupTest then -- for tests
        return
    end

    -- only players not at war get backup
    local players = {}
    for _, player in pairs({sector:getPlayers()}) do
        local craftFaction = player.craftFaction
        if galaxy:getFactionRelationStatus(faction, craftFaction) ~= RelationStatus.War then
            table.insert(players, craftFaction)
        end
    end

    if #players == 0 then return end

    -- only spawn backup once every 2 hours
    local now = Server().unpausedRuntime
    local backupKey = "waveencounter_backup_" .. faction.index
    for _, player in pairs(players) do
        local lastBackup = player:getValue(backupKey)
        if lastBackup and now - lastBackup < 2 * 60 * 60 then return end
    end

    for _, player in pairs(players) do
        player:setValue(backupKey, now)
    end

    WaveUtility.spawnBackup(faction, up, pos, dir, right, distance)
end

function WaveUtility.spawnBackup(faction, up, pos, dir, right, distance)
    local generator = AsyncShipGenerator(nil, WaveUtility.onBackupGenerated)

    generator:startBatch()
    local counter = 0
    for i = 1, 2 do
        generator:createDefender(faction, MatrixLookUpPosition(dir, up, -pos + right * distance * counter))
        counter = counter + 1
    end

    generator:endBatch()
end

function WaveUtility.onBackupGenerated(ships)
    for _, ship in pairs(ships) do
        ship:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
    end

    local backupChatterLines =
    {
        "We noticed that these pirates are gathering here and came here to help."%_T,
        "We are always on the lookout for pirate activity. Let's make this galaxy a little safer!"%_T,
        "Greetings! We are on your side. We noticed pirate activity and came as fast as we could. Those pirate hideouts need to be cleaned up."%_T,
    }

    Sector():broadcastChatMessage(ships[1], ChatMessageType.Chatter, randomEntry(backupChatterLines))
end

function WaveUtility.playerVicinityCheck(entity, minDistance)
    if not valid(entity) then return false end

    local playerShips = {}
    for _, player in pairs({Sector():getPlayers()}) do
        table.insert(playerShips, player.craft)
    end
    for _, playerShip in pairs(playerShips) do
        local dist = playerShip:getNearestDistance(entity)
        if dist <= minDistance then
            initialEnemies = false
            return true
        end
    end
end

function WaveUtility.getWaveMember()
    for _, ship in pairs({Sector():getEntitiesByType(EntityType.Ship)}) do
        if ship:getValue("is_wave") then
            return ship
        end
    end
end

function WaveUtility.onDamaged(objectIndex, amount, inflictor, damageType)
    local entity = Entity(inflictor)
    if valid(entity) and entity.playerOwned then
        startEncounter()
    end
end

function WaveUtility.getNumEnemies()
    local enemies = {Sector():getEntitiesByType(EntityType.Ship)}
    local numEnemies = 0
    for _, enemy in pairs(enemies) do
        if enemy:getValue("is_wave") then
            numEnemies = numEnemies + 1
        end
    end

   return numEnemies
end

function WaveUtility.generateTurrets(amount)
    local turrets = {}
    if not amount then amount = 1 end

    for i = 1, amount do
        local rarities = {}
        rarities[RarityType.Exceptional] = 4
        rarities[RarityType.Exotic] = 1
        rarities[RarityType.Legendary] = 0.25

        local probabilities = Balancing_GetMaterialProbability(Sector():getCoordinates())
        local materials = {}
        materials[0] = probabilities[0]
        materials[1] = probabilities[1]
        materials[2] = probabilities[2]
        materials[3] = probabilities[3]
        materials[4] = probabilities[4]
        materials[5] = probabilities[5]
        materials[6] = probabilities[6]

        local x, y = Sector():getCoordinates()

        local rarity = selectByWeight(random(), rarities)
        local material = selectByWeight(random(), materials)

        local turret = InventoryTurret(SectorTurretGenerator():generateArmed(x, y, 0, Rarity(rarity), Material(material)))

        table.insert(turrets, turret)
    end

    return turrets
end

function WaveUtility.showSectorCleared()
    if onServer() then return end

    displayMissionAccomplishedText("SECTOR CLEARED"%_t, "")
    playSound("interface/mission-accomplished", SoundType.UI, 1)
end

function WaveUtility.increaseLootGoonPityCounter()
    for _, player in pairs({Sector():getPlayers()}) do
        local increased = (player:getValue("loot_goon_pity_counter") or 0) + 1
        player:setValue("loot_goon_pity_counter", increased)
    end
end

function WaveUtility.improveReputation()
    local sector = Sector()
    local galaxy = Galaxy()
    local x, y = Sector():getCoordinates()

    local faction = nil

    local offsets = {vec2(0, 0), vec2(2, 0), vec2(2, 2), vec2(-2, 0), vec2(-2, 2), vec2(0, 2), vec2(2, -2), vec2(0, -2), vec2(-2, -2)}
    for i = 1, 5 do
        for _, offset in pairs(offsets) do
            local sx, sy = x + offset.x * i, y + offset.y * i
            faction = galaxy:getControllingFaction(sx, sy)
            if faction then break end

            faction = galaxy:getLocalFaction(sx, sy)
            if faction then break end
        end

        if faction then break end
    end

    if not faction then return end

    local players = {sector:getPlayers()}
    for _, player in pairs(players) do
        local playerFaction = player.craftFaction
        if playerFaction then
            changeRelations(playerFaction, faction, 3500)
        end
    end
end

return WaveUtility
