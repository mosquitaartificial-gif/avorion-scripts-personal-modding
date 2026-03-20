
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("randomext")
include ("galaxy")
include ("utility")
include ("stringutility")
include ("defaultscripts")
include ("goods")
include ("merchantutility")
local AsteroidPlanGenerator = include ("asteroidplangenerator")
local SectorSpecifics = include ("sectorspecifics")

local AsteroidFieldGenerator = {}
AsteroidFieldGenerator.__index = AsteroidFieldGenerator

local function new(x, y)
    if not x or not y then
        local sx, sy = Sector():getCoordinates()
        x = x or sx
        y = y or sy
    end

    local instance = {coordX = x, coordY = y}
    instance.planGenerator = AsteroidPlanGenerator()

    if onServer() then
        local specs = SectorSpecifics()
        local regular, offgrid, rift = specs:determineContent(x, y, Server().seed)
        if rift then
            instance.planGenerator:setToRiftStone()
        end
    end

    return setmetatable(instance, AsteroidFieldGenerator)
end

function AsteroidFieldGenerator:getFieldPosition(maxDist)
    local position = vec3(math.random(), math.random(), math.random());
    local dist = 0
    if maxDist == nil then
        dist = getFloat(-5000, 5000)
    else
        dist = getFloat(-maxDist, maxDist)
    end

    position = position * dist

    -- create a random up vector
    local up = vec3(math.random(), math.random(), math.random())

    -- create a random right vector
    local look = vec3(math.random(), math.random(), math.random())

    -- create the look vector from them
    local mat = MatrixLookUp(look, up)
    mat.pos = position

    return mat
end

-- returns an asteroid type, based on the sector's position in the galaxy
function AsteroidFieldGenerator:getAsteroidType()
    local probabilities = Balancing_GetMaterialProbability(self.coordX, self.coordY)
    return Material(getValueFromDistribution(probabilities))
end

function AsteroidFieldGenerator:getNextAsteroidPosition(asteroidFieldPosition, fieldSize)
    -- if there's a predefined position, use that
    if self.asteroidPositions and #self.asteroidPositions > 0 then
        return table.remove(self.asteroidPositions)
    end

    -- create the local position in the field
    local angle = getFloat(0, math.pi * 2.0)
    local height = getFloat(-fieldSize / 5, fieldSize / 5)

    local distFromCenter = getFloat(0, fieldSize * 0.75)
    local asteroidPosition = vec3(math.sin(angle) * distFromCenter, height, math.cos(angle) * distFromCenter)

    return asteroidFieldPosition:transformCoord(asteroidPosition)
end

function AsteroidFieldGenerator:createClaimableAsteroid(position)
    local desc = AsteroidDescriptor()
    desc:removeComponent(ComponentType.MineableMaterial)
    desc:addComponents(
       ComponentType.Owner,
       ComponentType.FactionNotifier
       )

    desc.position = position or self:getFieldPosition()
    desc:setMovePlan(self.planGenerator:makeBigAsteroidPlan(100, false, Material(0)))
    desc:addScript("claim.lua")

    return Sector():createEntity(desc)
end

-- creates an asteroid
function AsteroidFieldGenerator:createSmallAsteroid(translation, size, resources, material, title)
    --acquire a random seed for the asteroid
    local plan = self.planGenerator:makeSmallAsteroidPlan(size, resources, material)
    plan.accumulatingHealth = false

    local position = MatrixLookUp(vec3(math.random(), math.random(), math.random()), vec3(math.random(), math.random(), math.random()))
    position.pos = translation

    local desc = AsteroidDescriptor()
    desc:setMovePlan(plan)
    desc.position = position
    if not resources then
        desc:removeComponent(ComponentType.MineableMaterial)
    else
        desc.isObviouslyMineable = true
    end

    if title then
        desc:addComponent(ComponentType.Title)
        desc.title = title
    end

    local asteroid = Sector():createEntity(desc)
    return asteroid
end

function AsteroidFieldGenerator:createHiddenTreasureAsteroid(translation, size, material)
    --acquire a random seed for the asteroid
    local plan = self.planGenerator:makeSmallHiddenResourcesAsteroidPlan(size, material)
    plan.accumulatingHealth = false

    local position = MatrixLookUp(vec3(math.random(), math.random(), math.random()), vec3(math.random(), math.random(), math.random()))
    position.pos = translation

    local asteroid = Sector():createAsteroid(plan, true, position)

    asteroid.isObviouslyMineable = false
    return asteroid
end

-- create an asteroid field. this field is already placed randomly in the sector.
function AsteroidFieldGenerator:createAsteroidFieldEx(numAsteroids, fieldSize, minAsteroidSize, maxAsteroidSize, hasResources, probability)

    fieldSize = fieldSize or 2000
    minAsteroidSize = minAsteroidSize or 5.0
    maxAsteroidSize = maxAsteroidSize or 25.0
    if hasResources == false then probability = 0 end

    local asteroidsWithResources = numAsteroids * (probability or 0.05)

    asteroidsWithResources = asteroidsWithResources * GameSettings().resourceAsteroidFactor

    local asteroidFieldPosition = self:getFieldPosition()
    local asteroids = {}

    -- if no specific asteroid positions were set, create an organic cloud of asteroids
    if not self.asteroidPositions then
        local points = self:generateOrganicCloud(numAsteroids)

        self.asteroidPositions = {}
        for _, point in pairs(points) do
            table.insert(self.asteroidPositions, asteroidFieldPosition:transformCoord(point))
        end
    end

    for i = 1, numAsteroids do
        local resources = false
        if asteroidsWithResources > 0 then
            resources = true
            asteroidsWithResources = asteroidsWithResources - 1
        end

        -- create asteroid size from those min/max values and the actual value
        local size
        local hiddenTreasure = false

        if math.random() < 0.15 then
            -- create a bigger asteroid, but without resources
            size = lerp(math.random(), 0, 1.0, minAsteroidSize, maxAsteroidSize);
            if resources then
                resources = false
                asteroidsWithResources = asteroidsWithResources + 1
            end
        else
            -- normal asteroid
            size = lerp(math.random(), 0, 2.5, minAsteroidSize, maxAsteroidSize);
        end

        if math.random() < (1 / 50) then
            hiddenTreasure = true
        end

        local asteroidPosition = self:getNextAsteroidPosition(asteroidFieldPosition, fieldSize)
        local material = self:getAsteroidType()

        local asteroid = nil
        if hiddenTreasure then
            asteroid = self:createHiddenTreasureAsteroid(asteroidPosition, size, material)
        else
            asteroid = self:createSmallAsteroid(asteroidPosition, size, resources, material)
        end
        table.insert(asteroids, asteroid)
    end

    -- clear the asteroid positions once they're empty
    if self.asteroidPositions and #self.asteroidPositions == 0 then
        self.asteroidPositions = nil
    end

    return asteroidFieldPosition, asteroids
end

function AsteroidFieldGenerator:generateOrganicCloud(numPoints, translation, roughSize)
    numPoints = numPoints or 2500
    translation = translation or vec3()

    local rand = random()
--    local rand = Random(Seed(123))

    local roughSize = roughSize or 750
    local partial = roughSize / 3

    local points = {}
    for i = 1, numPoints do
        local d = (roughSize + rand:getFloat(-partial, partial) + rand:getFloat(-partial, partial) + rand:getFloat(-partial, partial))
        table.insert(points, rand:getDirection() * d)
    end

    for i = 1, 15 do
        local d = (roughSize + rand:getFloat(-partial, partial) + rand:getFloat(-partial, partial) + rand:getFloat(-partial, partial))
        local center = rand:getDirection() * d
        center = center * 1.5

        local radius = roughSize * rand:getFloat(0.5, 1.4)

        for _, point in pairs(points) do
            local dir = point - center
            local l = length(dir)
            dir = dir / l

            local offset = lerp(l, 0, radius, radius * 0.6, 0)
            point.x = point.x + dir.x * offset
            point.y = point.y + dir.y * offset
            point.z = point.z + dir.z * offset

        end
    end

    for i = 1, 50 do
        local d = (roughSize + rand:getFloat(-partial, partial) + rand:getFloat(-partial, partial) + rand:getFloat(-partial, partial))
        local center = rand:getDirection() * d
        center = center * 1.5

        local radius = roughSize * 0.75

        for _, point in pairs(points) do
            local dir = point - center
            local l = length(dir)
            dir = dir / l

            local offset = lerp(l, 0, radius, radius * 0.75, 0)
            point.x = point.x + dir.x * offset
            point.y = point.y + dir.y * offset
            point.z = point.z + dir.z * offset
        end
    end

    for i = 1, numPoints do
        for j = i + 1, numPoints do

            local dir = points[i] - points[j]
            local l2 = length2(dir)
            if l2 < 80 * 80 then
                l = math.sqrt(l2)
                dir = dir / l

                local offset = 80 - l
                points[i].x = points[i].x + dir.x * offset
                points[i].y = points[i].y + dir.y * offset
                points[i].z = points[i].z + dir.z * offset

                points[j].x = points[j].x - dir.x * offset
                points[j].y = points[j].y - dir.y * offset
                points[j].z = points[j].z - dir.z * offset
            end
        end
    end

    local scale = 1.1
    for _, point in pairs(points) do
        point.x = point.x * scale + translation.x
        point.y = point.y * scale + translation.y
        point.z = point.z * scale + translation.z
    end

    return points
end

function AsteroidFieldGenerator:generateRing(numPoints, radius, translation, rotation)
    numPoints = numPoints or 2500
    radius = radius or 500
    translation = translation or vec3()

    local rand = random()

    local matrix = rotation
    if not rotation then
        matrix = rotate(Matrix(), rand:getFloat(0, math.pi), rand:getDirection())
    end

    matrix.position = translation

    local points = {}
    for i = 1, numPoints do
        local angle = i / numPoints * math.pi * 2

        local jitter = rand:getVector(-50, 50)
        local point = vec3()
        point.x = math.sin(angle) * radius
        point.y = 0
        point.z = math.cos(angle) * radius

        table.insert(points, matrix:transformCoord(point + jitter))
    end

    return points
end

function AsteroidFieldGenerator:generateSpikes(numPoints, radius, translation)
    numPoints = numPoints or 2500
    radius = radius or 500
    translation = translation or vec3()

    local rand = random()

    local matrix = rotate(Matrix(), rand:getFloat(0, math.pi), rand:getDirection())
    matrix.position = translation

    local directions = {}
    for i = 1, 25 do
        table.insert(directions, rand:getDirection())
    end

    local points = {}
    for i = 1, numPoints do
        local layer = math.floor(i / #directions)
        local direction = directions[(i % #directions) + 1]

        local jitter = rand:getVector(-30, 30)
        local point = direction * (radius + layer * 120)

        table.insert(points, matrix:transformCoord(point + jitter))
    end

    return points
end

-- create a ball (hedgehog) asteroid field. This field is either placed randomly in the sector or at the position that is given in the parameters
function AsteroidFieldGenerator:createBallAsteroidFieldEx(numAsteroids, fieldSize, minAsteroidSize, maxAsteroidSize, hasResources, probability, translation)
    local layers = 10
    numAsteroids = layers * 26 -- the number of asteroids, only the number of layers should be changed to generate a different number of asteroids

    translation = translation or self:getFieldPosition().translation

    self.asteroidPositions = {}

    local radius = 5
    -- 26 evently spaced points on a ball are calculated, then a certain number of balls (= layers) are placed inside each other with a new radius
    for i = 1, layers do
        -- the positions of the 26 evenly spaced points one ball are calculated individually
        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(45)) * math.cos(math.rad(0)  ) * 100) + translation.x, (radius * math.sin(math.rad(45)) * math.sin(math.rad(0)  ) * 100) + translation.y, (radius * math.cos(math.rad(45)) * 100) + translation.z))
        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(45)) * math.cos(math.rad(45) ) * 100) + translation.x, (radius * math.sin(math.rad(45)) * math.sin(math.rad(45) ) * 100) + translation.y, (radius * math.cos(math.rad(45)) * 100) + translation.z))
        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(45)) * math.cos(math.rad(90) ) * 100) + translation.x, (radius * math.sin(math.rad(45)) * math.sin(math.rad(90) ) * 100) + translation.y, (radius * math.cos(math.rad(45)) * 100) + translation.z))
        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(45)) * math.cos(math.rad(135)) * 100) + translation.x, (radius * math.sin(math.rad(45)) * math.sin(math.rad(135)) * 100) + translation.y, (radius * math.cos(math.rad(45)) * 100) + translation.z))
        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(45)) * math.cos(math.rad(180)) * 100) + translation.x, (radius * math.sin(math.rad(45)) * math.sin(math.rad(180)) * 100) + translation.y, (radius * math.cos(math.rad(45)) * 100) + translation.z))
        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(45)) * math.cos(math.rad(225)) * 100) + translation.x, (radius * math.sin(math.rad(45)) * math.sin(math.rad(225)) * 100) + translation.y, (radius * math.cos(math.rad(45)) * 100) + translation.z))
        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(45)) * math.cos(math.rad(270)) * 100) + translation.x, (radius * math.sin(math.rad(45)) * math.sin(math.rad(270)) * 100) + translation.y, (radius * math.cos(math.rad(45)) * 100) + translation.z))
        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(45)) * math.cos(math.rad(315)) * 100) + translation.x, (radius * math.sin(math.rad(45)) * math.sin(math.rad(315)) * 100) + translation.y, (radius * math.cos(math.rad(45)) * 100) + translation.z))

        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(90)) * math.cos(math.rad(0)  ) * 100) + translation.x, (radius * math.sin(math.rad(90)) * math.sin(math.rad(0)  ) * 100) + translation.y, (radius * math.cos(math.rad(90)) * 100) + translation.z))
        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(90)) * math.cos(math.rad(45) ) * 100) + translation.x, (radius * math.sin(math.rad(90)) * math.sin(math.rad(45) ) * 100) + translation.y, (radius * math.cos(math.rad(90)) * 100) + translation.z))
        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(90)) * math.cos(math.rad(90) ) * 100) + translation.x, (radius * math.sin(math.rad(90)) * math.sin(math.rad(90) ) * 100) + translation.y, (radius * math.cos(math.rad(90)) * 100) + translation.z))
        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(90)) * math.cos(math.rad(135)) * 100) + translation.x, (radius * math.sin(math.rad(90)) * math.sin(math.rad(135)) * 100) + translation.y, (radius * math.cos(math.rad(90)) * 100) + translation.z))
        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(90)) * math.cos(math.rad(180)) * 100) + translation.x, (radius * math.sin(math.rad(90)) * math.sin(math.rad(180)) * 100) + translation.y, (radius * math.cos(math.rad(90)) * 100) + translation.z))
        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(90)) * math.cos(math.rad(225)) * 100) + translation.x, (radius * math.sin(math.rad(90)) * math.sin(math.rad(225)) * 100) + translation.y, (radius * math.cos(math.rad(90)) * 100) + translation.z))
        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(90)) * math.cos(math.rad(270)) * 100) + translation.x, (radius * math.sin(math.rad(90)) * math.sin(math.rad(270)) * 100) + translation.y, (radius * math.cos(math.rad(90)) * 100) + translation.z))
        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(90)) * math.cos(math.rad(315)) * 100) + translation.x, (radius * math.sin(math.rad(90)) * math.sin(math.rad(315)) * 100) + translation.y, (radius * math.cos(math.rad(90)) * 100) + translation.z))

        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(135)) * math.cos(math.rad(0)  ) * 100) + translation.x, (radius * math.sin(math.rad(135)) * math.sin(math.rad(0)  ) * 100) + translation.y, (radius * math.cos(math.rad(135)) * 100) + translation.z))
        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(135)) * math.cos(math.rad(45) ) * 100) + translation.x, (radius * math.sin(math.rad(135)) * math.sin(math.rad(45) ) * 100) + translation.y, (radius * math.cos(math.rad(135)) * 100) + translation.z))
        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(135)) * math.cos(math.rad(90) ) * 100) + translation.x, (radius * math.sin(math.rad(135)) * math.sin(math.rad(90) ) * 100) + translation.y, (radius * math.cos(math.rad(135)) * 100) + translation.z))
        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(135)) * math.cos(math.rad(135)) * 100) + translation.x, (radius * math.sin(math.rad(135)) * math.sin(math.rad(135)) * 100) + translation.y, (radius * math.cos(math.rad(135)) * 100) + translation.z))
        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(135)) * math.cos(math.rad(180)) * 100) + translation.x, (radius * math.sin(math.rad(135)) * math.sin(math.rad(180)) * 100) + translation.y, (radius * math.cos(math.rad(135)) * 100) + translation.z))
        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(135)) * math.cos(math.rad(225)) * 100) + translation.x, (radius * math.sin(math.rad(135)) * math.sin(math.rad(225)) * 100) + translation.y, (radius * math.cos(math.rad(135)) * 100) + translation.z))
        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(135)) * math.cos(math.rad(270)) * 100) + translation.x, (radius * math.sin(math.rad(135)) * math.sin(math.rad(270)) * 100) + translation.y, (radius * math.cos(math.rad(135)) * 100) + translation.z))
        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(135)) * math.cos(math.rad(315)) * 100) + translation.x, (radius * math.sin(math.rad(135)) * math.sin(math.rad(315)) * 100) + translation.y, (radius * math.cos(math.rad(135)) * 100) + translation.z))

        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(0)) * math.cos(math.rad(180)) * 100) + translation.x, (radius * math.sin(math.rad(0)) * math.sin(math.rad(180)) * 100) + translation.y, (radius * math.cos(math.rad(0)) * 100) + translation.z))
        table.insert(self.asteroidPositions, vec3((radius * math.sin(math.rad(0)) * math.cos(math.rad(0)) * 100) + translation.x, (radius * math.sin(math.rad(0)) * math.sin(math.rad(0)) * 100) + translation.y, (radius * math.cos(math.rad(0)) * 100) + translation.z))

        radius = radius + 0.8
    end

    local results = {self:createAsteroidFieldEx(numAsteroids, fieldSize, minAsteroidSize, maxAsteroidSize, hasResources, probability)}

    self.asteroidPositions = nil
end

-- create a forest asteroid field. This field is already placed randomly in the sector.
function AsteroidFieldGenerator:createForestAsteroidFieldEx(numAsteroids, fieldSize, minAsteroidSize, maxAsteroidSize, hasResources, probability, position)

    numAsteroids = 250 -- the number of asteroids

    probability = probability or 0.05

    local asteroidsWithResources = numAsteroids * probability
    if not hasResources then asteroidsWithResources = 0 end

    local mat = self:getFieldPosition()
    if position ~= nil then
        mat.position = position
    end

    local xcoord = mat.pos.x
    local ycoord = mat.pos.y
    local zcoord = mat.pos.z

    local asteroids = {}

    local counter = 0
    local angle = getFloat(0, math.pi * 2.0)
    local height = getFloat(-fieldSize / 5, fieldSize / 5)
    local distFromCenter = getFloat(0, fieldSize * 0.75)

    for i = 1, numAsteroids do
        local resources = false
            if asteroidsWithResources > 0 then
                resources = true
                asteroidsWithResources = asteroidsWithResources - 1
            end
            -- create asteroid size from those min/max values and the actual value
            local size
            local hiddenTreasure = false

            if math.random() < 0.15 then
                size = lerp(math.random(), 0, 1.0, minAsteroidSize, maxAsteroidSize);
                if resources then
                    resources = false
                    asteroidsWithResources = asteroidsWithResources + 1
                end
            else
                size = lerp(math.random(), 0, 2.5, minAsteroidSize, maxAsteroidSize);
            end

            if math.random() < (1 / 50) then
                hiddenTreasure = true
            end

            zcoord = zcoord + 40
            counter = counter + 1
            local randomHeight = math.random(4,9)

            if counter == randomHeight or counter >= 10 then

                zcoord = mat.pos.z
                counter = 0
                angle = getFloat(0, math.pi * 2.0)
                height = getFloat(-fieldSize / 5, fieldSize / 5)
                distFromCenter = getFloat(0, fieldSize * 0.75)

            end

            local asteroidPosition = vec3(math.sin(angle) * distFromCenter, height, zcoord)

            asteroidPosition = mat:transformCoord(asteroidPosition)
            local material = self:getAsteroidType()

            local asteroid = nil
            if hiddenTreasure then
                asteroid = self:createHiddenTreasureAsteroid(asteroidPosition, size, material)
            else
                asteroid = self:createSmallAsteroid(asteroidPosition, size, resources, material)
            end
            table.insert(asteroids, asteroid)
        end
    return mat, asteroids
end

function AsteroidFieldGenerator:createForestAsteroidField(probability, position)
    local size = getFloat(0.5, 1.0)

    return self:createForestAsteroidFieldEx(300 * size, 1800 * size, 5.0, 25.0, true, probability, position);
end

function AsteroidFieldGenerator:createBallAsteroidField(probability, position)
    local size = getFloat(0.5, 1.0)

    return self:createBallAsteroidFieldEx(300 * size, 1800 * size, 5.0, 25.0, true, probability, position);
end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
