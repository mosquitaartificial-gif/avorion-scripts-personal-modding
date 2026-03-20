package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")
local SectorGenerator = include("SectorGenerator")
local Placer = include("placer")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace RespawnResourceAsteroids
RespawnResourceAsteroids = {}
local self = RespawnResourceAsteroids

self.respawningThreshold = 0.06
self.respawnedFields = 3
self.respawnArea = 200

if onServer() then

function RespawnResourceAsteroids.initialize()

    local numAsteroids = Sector():getNumEntitiesByType(EntityType.Asteroid)
    if numAsteroids < 200 then
        self.respawnFields()
    end

    -- respawn rich asteroids next to normal ones
    self.respawnRichAsteroids()

end

function RespawnResourceAsteroids.respawnRichAsteroids()
    local sector = Sector()
    local richAsteroids = sector:getNumEntitiesByComponent(ComponentType.MineableMaterial)
    local numAsteroids = sector:getNumEntitiesByType(EntityType.Asteroid)

    if numAsteroids == 0 then return end
    if richAsteroids / numAsteroids > self.respawningThreshold then return end

    -- respawn them
    local asteroids = {Sector():getEntitiesByType(EntityType.Asteroid)}
    local generator = SectorGenerator(Sector():getCoordinates())

    local spawned = {}

    for _, asteroid in pairs(asteroids) do

        local sphere = Sphere(asteroid.translationf, self.respawnArea)
        local others = {Sector():getEntitiesByLocation(sphere)}

        local numEmptyAsteroids = 0
        if #others >= 10 then
            for _, entity in pairs(others) do
                if entity:hasComponent(ComponentType.MineableMaterial) then
                    numEmptyAsteroids = 0
                    break
                end

                if entity.type == EntityType.Asteroid then
                    numEmptyAsteroids = numEmptyAsteroids + 1
                end
            end
        end

        if numEmptyAsteroids >= 10 then
            local translation = sphere.center + random():getDirection() * sphere.radius
            local size = random():getFloat(5.0, 15.0)

            local asteroid = generator:createSmallAsteroid(translation, size, true, generator:getAsteroidType())

            table.insert(spawned, asteroid)

            richAsteroids = richAsteroids + 1
            numAsteroids = numAsteroids + 1
        end

        if richAsteroids / numAsteroids > self.respawningThreshold then break end
    end

    Placer.resolveIntersections(spawned)

end

function RespawnResourceAsteroids.respawnFields()

    local x, y = Sector():getCoordinates()
    local generator = SectorGenerator(x, y)

    for i = 1, self.respawnedFields do
        generator:createAsteroidField()
    end

    Placer.resolveIntersections()
end


end
