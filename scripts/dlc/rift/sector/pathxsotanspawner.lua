package.path = package.path .. ";data/scripts/lib/?.lua"

local Xsotan = include("story/xsotan")
local WaveUtility = include("waveutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace PathXsotanSpawner
PathXsotanSpawner = {}

local spawnLocations = {}

if onServer() then

function PathXsotanSpawner.getUpdateInterval()
    return 2
end

function PathXsotanSpawner.initialize(specs)

    -- add spawners for landmarks & paths
    for i = 2, #specs.landmarks do
        local landmark = specs.landmarks[i]
        local additionals = landmark.distance * 0.5

        additionals = math.floor(additionals)
        table.insert(spawnLocations, {location = landmark.location, radius = 2000, numXsotan = 4 + additionals})
    end

    for _, path in pairs(specs.paths) do
        local f = random():getFloat(0.3, 0.7)
        local location = lerp(f, 0, 1, path.a.location, path.b.location)
        table.insert(spawnLocations, {location = location, radius = 3000, numXsotan = 4})
    end

end

function PathXsotanSpawner.updateServer(timeStep)

    local ships = {Sector():getEntitiesByType(EntityType.Ship)}
    for _, ship in pairs(ships) do
        if ship.playerOrAllianceOwned then
            for k, spawner in pairs(spawnLocations) do
                if distance2(ship.translationf, spawner.location) < spawner.radius * spawner.radius then

                    local waves = WaveUtility.getWaves(nil, 1, nil, spawner.numXsotan, nil)
                    local position = MatrixLookUpPosition(random():getDirection(), random():getDirection(), spawner.location)
                    WaveUtility.createXsotanWaveAsync(1, waves[1], position, nil, nil, PathXsotanSpawner)

                    if random():test(0.25) then
                        PathXsotanSpawner.spawnSpecialXsotan(spawner.location + random():getDirection() * 500)
                    end

                    spawnLocations[k] = nil
                end
            end
        end
    end

end

function PathXsotanSpawner.spawnSpecialXsotan(location)
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

    return ship
end

end
