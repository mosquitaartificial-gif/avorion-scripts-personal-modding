package.path = package.path .. ";data/scripts/lib/?.lua"

local RiftSectorGenerator = include("internal/dlc/rift/lib/riftsectorgenerator")
include("randomext")
include("utility")

local specs = {}

function initialize()
    if onServer() then return end

    local generator = RiftSectorGenerator()
    specs = generator:generateSpecs()
end

function updateClient()
    local rand = Random(Seed(123))

    drawDebugSphere(Sphere(specs.startingPosition, 50), ColorRGB(0.8, 0.4, 0.2))
    drawDebugSphere(Sphere(vec3(), 50), ColorRGB(1, 1, 1))
    drawDebugSphere(Sphere(vec3(80, 0, 0), 50), ColorRGB(1, 0, 0))
    drawDebugSphere(Sphere(vec3(0, 80, 0), 50), ColorRGB(0, 1, 0))
    drawDebugSphere(Sphere(vec3(0, 0, 80), 50), ColorRGB(0, 0, 1))

    -- draw points of interest
    local color = ColorRGB(0, 1, 1)
    for _, lm in pairs(specs.landmarks) do
        drawDebugSphere(Sphere(lm.location, 100), color)
    end

    local color = ColorRGB(0.7, 0.5, 1)
    for _, secret in pairs(specs.secrets) do
        drawDebugSphere(Sphere(secret.location, 100), color)
    end

    for _, collection in pairs({specs.landmarks, specs.paths, specs.secrets}) do
        for _, poi in pairs(collection) do
            -- draw asteroids
            local resourceChance = poi.resourceChance or 0.01

            local color = ColorRGB(70/255,35/255,10/255)
            for _, point in pairs(poi.asteroids) do
                if rand:test(resourceChance) then
                    drawDebugSphere(Sphere(point, rand:getFloat(10, 25)), Material(MaterialType.Ogonite).color)
                else
                    drawDebugSphere(Sphere(point, rand:getFloat(10, 25)), color)
                end
            end

            -- draw wreckages
            local color = ColorRGB(0.5, 0.5, 0.5)
            for _, point in pairs(poi.wreckages) do
                drawDebugSphere(Sphere(point, rand:getFloat(40, 60)), color)
            end
            for _, point in pairs(poi.stationWreckages) do
                drawDebugSphere(Sphere(point, 200), color)
            end

            -- draw buoys
            local color = ColorRGB(0.75, 0.75, 0.75)
            for _, buoy in pairs(poi.buoys) do
                drawDebugSphere(Sphere(buoy.location, 15), color)
            end

            -- draw treasures
            local color = ColorRGB(1.0, 1.0, 0.2)
            for _, point in pairs(poi.treasures) do
                drawDebugSphere(Sphere(point, 30), color)
            end

            -- draw anomalies
            local color = ColorRGB(0.2, 0.5, 1.0)
            for _, data in pairs(poi.anomaly) do
                drawDebugSphere(Sphere(data.location1, 30), color)
                drawDebugSphere(Sphere(data.location2, 30), color)
            end
        end
    end

    for _, collection in pairs({specs.landmarks, specs.paths, specs.secrets}) do
        for _, poi in pairs(collection) do

            -- draw buff backgrounds
            local color = ColorRGB(0.2, 1.0, 0.2)
            for _, point in pairs(poi.buffs) do
                drawDebugSphere(Sphere(point, -500), ColorARGB(0.1, 0.2, 1.0, 0.2))
            end

            -- draw safety backgrounds
            for _, point in pairs(poi.safeLocations) do
                drawDebugSphere(Sphere(point, -500), ColorARGB(0.1, 0.2, 0.2, 1.0))
            end

            -- draw danger backgrounds
            for _, point in pairs(poi.dangers) do
                drawDebugSphere(Sphere(point, -1500), ColorARGB(0.15, 1.0, 0.2, 0.2))
            end
        end
    end

    for _, collection in pairs({specs.landmarks, specs.paths, specs.secrets}) do
        for _, poi in pairs(collection) do
            -- draw buffs
            for _, point in pairs(poi.buffs) do
                drawDebugSphere(Sphere(point, 65), ColorRGB(0.2, 1.0, 0.2))
                drawDebugSphere(Sphere(point, 500), ColorARGB(0.1, 0.2, 1.0, 0.2))
            end

            -- draw safe locations
            for _, point in pairs(poi.safeLocations) do
                drawDebugSphere(Sphere(point, 65), ColorRGB(0.2, 0.2, 1.0))
                drawDebugSphere(Sphere(point, 500), ColorARGB(0.1, 0.2, 0.2, 1.0))
            end

            -- draw dangers
            for _, point in pairs(poi.dangers) do
                drawDebugSphere(Sphere(point, 100), ColorRGB(1.0, 0.2, 0.2))
                drawDebugSphere(Sphere(point, 1500), ColorARGB(0.15, 1.0, 0.2, 0.2))
            end
        end
    end


end
