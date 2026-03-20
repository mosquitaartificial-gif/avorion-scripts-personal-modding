package.path = package.path .. ";data/scripts/lib/?.lua"

include("callable")
local Xsotan = include("story/xsotan")
local WaveUtility = include("waveutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace OutOfCoverXsotanSpawner
OutOfCoverXsotanSpawner = {}

local landmarks
local paths
local pathRadius = 3000
local maxPathRadius = 6000 -- the distance from which xsotan will spawn fastest
local spawnInterval = 45 -- the time until xsotan will spawn when at pathRadius distance

local maxNumXsotan = 20
local waveOffset = -2
local incrementWaveOffsetCounter = 0

local spawnTimerByPlayer = {}
local warningsByPlayer = {}
local oneTimeWarningsByPlayer = {}

function OutOfCoverXsotanSpawner.initialize(sectorSpecs)
    if sectorSpecs then
        landmarks = {sectorSpecs.startingPosition}
        paths = {}

        for _, landmark in pairs(sectorSpecs.landmarks) do
            table.insert(landmarks, landmark.location)
        end

        for _, secret in pairs(sectorSpecs.secrets) do
            table.insert(landmarks, secret.location)
        end

        for _, path in pairs(sectorSpecs.paths) do
            table.insert(paths, {a = path.a.location, b = path.b.location})
        end
    end

    if onClient() then
        OutOfCoverXsotanSpawner.sync()
    end
end

function OutOfCoverXsotanSpawner.secure()
    return
    {
        landmarks = landmarks,
        paths = paths,
    }
end

function OutOfCoverXsotanSpawner.restore(data)
    landmarks = {}
    for _, pos in pairs(data.landmarks) do
        table.insert(landmarks, vec3(pos.x, pos.y, pos.z))
    end

    paths = {}
    for _, path in pairs(data.paths) do
        table.insert(paths, {a = vec3(path.a.x, path.a.y, path.a.z), b = vec3(path.b.x, path.b.y, path.b.z)})
    end

    OutOfCoverXsotanSpawner.sync()
end

function OutOfCoverXsotanSpawner.getUpdateInterval()
    return 2
end

function OutOfCoverXsotanSpawner.updateServer(timeStep)
    local sector = Sector()
    for _, player in pairs({sector:getPlayers()}) do
        local isOnPath, dist2, closestPointOnPath = OutOfCoverXsotanSpawner.calculatePlayerOnPath(player)

        if isOnPath then
            -- player is on path, reset the timer
            spawnTimerByPlayer[player.index] = nil
            warningsByPlayer[player.index] = nil

        else
            -- send a one-time immediate warning
            if not oneTimeWarningsByPlayer[player.index] then
                oneTimeWarningsByPlayer[player.index] = true

                Player(player.index):sendChatMessage("Rift Research Center"%_T, ChatMessageType.Normal, "Careful! The Xsotan can track you in open space! Get back into the safe area around the asteroids and buoys!"%_t)
            end

            -- player is not on path
            local timer = spawnTimerByPlayer[player.index] or 0

            -- the farther away, the sooner the xsotan spawn
            local dist = math.sqrt(dist2)
            local timeFactor = lerp(dist, pathRadius, maxPathRadius, 1, 3)

            timer = timer + timeStep * timeFactor
            spawnTimerByPlayer[player.index] = timer

            if not warningsByPlayer[player.index] and timer > spawnInterval * 0.5 then
                warningsByPlayer[player.index] = true

                Player(player.index):sendChatMessage("Rift Research Center"%_T, ChatMessageType.Normal, "Careful! The Xsotan are going to attack you at any moment! Fly back to safety!"%_t)
            end

            if timer > spawnInterval then
                spawnTimerByPlayer[player.index] = nil

                local numXsotan = sector:getNumEntitiesByScriptValue("is_xsotan")
                if numXsotan < maxNumXsotan then
                    OutOfCoverXsotanSpawner.spawnXsotan(player, numXsotan, closestPointOnPath)
                end
            end
        end
    end
end

function OutOfCoverXsotanSpawner.calculatePlayerOnPath(player)
    local craft = player.craft
    if not craft then return true end

    local position = craft.translationf
    local minDist2 = math.huge
    local closestPoint

    -- calculate distance to landmarks
    for _, landmark in pairs(landmarks) do
        local dist2 = distance2(position, landmark)
        if dist2 <= pathRadius * pathRadius then
            return true
        end

        if dist2 < minDist2 then
            minDist2 = dist2
            closestPoint = landmark
        end
    end

    -- calculate if within path radius (cylinder around path)
    for _, path in pairs(paths) do
        local ray = Ray(path.a, path.b - path.a)

        local projected, t = ray:projectPoint(position)
        if t < 0 or t > 1 then goto continue end

        local dist2 = distance2(position, projected)
        if dist2 <= pathRadius * pathRadius then
            return true
        end

        if dist2 < minDist2 then
            minDist2 = dist2
            closestPoint = projected
        end

        ::continue::
    end

    return false, minDist2, closestPoint
end

function OutOfCoverXsotanSpawner.spawnXsotan(player, numCurrentXsotan, closestPointOnPath)
    local numXsotanToSpawn = math.min(math.max(0, maxNumXsotan - numCurrentXsotan), 3)
    if numXsotanToSpawn == 0 then return end

    local spawnSpecialXsotan = random():test(0.15)
    if spawnSpecialXsotan then
        numXsotanToSpawn = numXsotanToSpawn - 1
    end

    local craft = player.craft
    if not craft then return end

    local direction = normalize(craft.translationf - closestPointOnPath) -- spawn xsotan out of cover so that retreating leads back into cover
    local location = craft.translationf + direction * 750

    local waves = WaveUtility.getWaves(math.min(5 + waveOffset, 19), 1, 1, numXsotanToSpawn, 1)
    local position = MatrixLookUpPosition(random():getDirection(), random():getDirection(), location)
    local lootGoonChance = 0
    local spacing = nil
    local ships = WaveUtility.createXsotanWaveAsync(waveNumber, waves[1], position, lootGoonChance, spacing, OutOfCoverXsotanSpawner, function(generated)
        -- no loot from enemies from this script
        for _, ship in pairs(generated) do
            ship:setValue("is_wave", true)
            ship:setDropsLoot(false)
            ship:setValue("xsotan_no_research_data", true)
        end

        Xsotan.aggroAll()

        if spawnSpecialXsotan then
            OutOfCoverXsotanSpawner.spawnSpecialXsotan(location + direction * 250) -- behind the wave
        end
    end)

    -- increase wave strength every 3 spawns
    incrementWaveOffsetCounter = incrementWaveOffsetCounter + 1
    if incrementWaveOffsetCounter >= 3 then
        incrementWaveOffsetCounter = 0

        waveOffset = waveOffset + 1
    end
end

function OutOfCoverXsotanSpawner.spawnSpecialXsotan(location)
    local candidates =
    {
        Xsotan.createQuantum,
        Xsotan.createCarrier,
        Xsotan.createShielded,
        Xsotan.createBuffer,
        Xsotan.createSummoner,
    }

    local spawnFunction = randomEntry(random(), candidates)
    local ship = spawnFunction(translate(Matrix(), location), 6)

    -- no loot from enemies from this script
    ship:setDropsLoot(false)
    ship:setValue("xsotan_no_research_data", true)

    Xsotan.aggroShip(ship)

    return ship
end

function OutOfCoverXsotanSpawner.updateClient(timeStep)
    if not landmarks or not paths then return end

    local player = Player()
    local isOnPath, dist2 = OutOfCoverXsotanSpawner.calculatePlayerOnPath(player)
    if isOnPath then
        removeSectorProblem("OutOfCoverXsotanSpawn")

    else
        local color = ColorRGB(1, 0.15, 0.15)
        addSectorProblem("OutOfCoverXsotanSpawn", "Careful, in open space the ship can easily be tracked down by Xsotan!"%_t, "data/textures/icons/xsotan.png", color)
    end
end

function OutOfCoverXsotanSpawner.sync(data)
    if onServer() then
        local data = {landmarks = landmarks, paths = paths}
        if callingPlayer then
            invokeClientFunction(Player(callingPlayer), "sync", data)
        else
            broadcastInvokeClientFunction("sync", data)
        end
    else
        if data then
            landmarks = data.landmarks
            paths = data.paths
        else
            invokeServerFunction("sync")
        end
    end
end
callable(OutOfCoverXsotanSpawner, "sync")
