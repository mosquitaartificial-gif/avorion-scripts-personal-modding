package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("utility")
include("goods")
include("productions")
include("randomext")

local FactoryPredictor = {}

function FactoryPredictor.generateMineProductions(x, y, amount)
    local random = Random(Seed(makeFastHash(GameSeed().int32, x, y)))

    local miningProductions = getMiningProductions()
    if #miningProductions == 0 then return {} end -- safeguard against infinite loops with broken data

    local productions = {}
    for i = 1, amount do
        local p = miningProductions[random:getInt(1, #miningProductions)]
        table.insert(productions, p.production)
    end

    return productions
end

function FactoryPredictor.generateFactoryProductions(x, y, amount)

    local random = Random(Seed(makeFastHash(GameSeed().int32, x, y)))

    -- generate whether or not the sector will be specialized
    local specialization = FactoryPredictor.getLocalSpecialization(x, y)
    local chain
    if specialization then
        -- if there is a specialization, then with X% probability the sector will be specialized
        if random:test(0.85) then
            if specialization == 0 then
                chain = "technology"
            elseif specialization == 1 then
                chain = "industrial"
            elseif specialization == 2 then
                chain = "military"
            elseif specialization == 3 then
                chain = "consumer"
            end
        end
    end

--    print ("chain: " .. tostring(chain))

    local probabilities = {}
    table.insert(probabilities, {weight = 6, minLevel = 0, maxLevel = 10000})
    table.insert(probabilities, {weight = 8, minLevel = 0, maxLevel = 0})
    table.insert(probabilities, {weight = 7, minLevel = 1, maxLevel = 3})
    table.insert(probabilities, {weight = 5, minLevel = 4, maxLevel = 6})
    table.insert(probabilities, {weight = 4, minLevel = 7, maxLevel = 10000})

    local weights = {}
    for index, levels in pairs(probabilities) do
        weights[index] = levels.weight
    end

    local selectedLevels = probabilities[getValueFromDistribution(weights, random)]
    local minLevel, maxLevel = selectedLevels.minLevel, selectedLevels.maxLevel

--    print ("min / max level: %s / %s", minLevel, maxLevel)

    -- choose a production by evaluating specialization, importance & level
    -- read all levels of all products
    local potentialGoods = {}
    local highestLevel = 0
    local spawnable = table.deepcopy(spawnableGoods)

    table.sort(spawnable, function(a, b) return a.name < b.name end )

    for i = 1, 10 do
        for _, good in pairs(spawnable) do

            if not good.level then goto continue end -- if it has no level, it is not produced
            if chain and not good.chains[chain] then goto continue end -- if its chain doesn't match, return false

            if good.level >= minLevel and good.level <= maxLevel then
                table.insert(potentialGoods, good)

                -- increase max level
                highestLevel = math.max(highestLevel, good.level)
                if highestLevel < good.level then
                    highestLevel = good.level
                end
            end

            ::continue::
        end

        -- in case that the constraints are too tight, loosen them with every iteration
        if #potentialGoods > 0 then break end
        minLevel = minLevel - i
        maxLevel = maxLevel + i
    end

    -- calculate the probability that a certain production is chosen
    local probabilities = {}
    for i, good in pairs(potentialGoods) do
        -- goods are more likely to be created the more important they are
        local probability = good.importance * 2
        -- make sure that higher goods have a smaller chance of being chosen
        probability = probability + (highestLevel - good.level) * 0.5
        -- add a little more randomness, so not only the "important" factories are created
        -- also: some goods have an importance of 0 -> they would never be produced
        probability = probability + 2

        probabilities[i] = probability
    end

    local singleProductionOnly = random:test(0.25)

    -- choose produced good
    local productions = {}

    local tries = 0 -- safeguard against infinite loops with broken data
    while #productions < amount and tries < amount * 50 do
        tries = tries + 1

        -- choose produced good at random from probability table
        local i = getValueFromDistribution(probabilities, random)
        local producedGood = potentialGoods[i].name

        if not productionsByGood[producedGood] then
            -- good is not produced, skip it, nil it (so it's not selected again), and repeat
            probabilities[i] = nil
            goto continue
        end

        local numProductions = #productionsByGood[producedGood]
        if numProductions == nil or numProductions == 0 then
            -- good is not produced, skip it, nil it (so it's not selected again), and repeat
            -- print("product is invalid: " .. product .. "\n")
            probabilities[i] = nil
            goto continue
        end

        local productionIndex = random:getInt(1, numProductions)
        local production = productionsByGood[producedGood][productionIndex]
        if production then

            if production.mine then
                probabilities[i] = nil
                goto continue
            end

            table.insert(productions, production)

            if singleProductionOnly then
                for j = 2, amount do
                    table.insert(productions, production)
                end

                break
            end
        end

        ::continue::
    end

    return productions
end

function FactoryPredictor.getNearbySpecializationCenters(x, y, diameter)
    diameter = diameter or 50
    local variation = diameter * 0.4

    -- find the 'original position'
    local cx = math.floor(x / diameter) * diameter
    local cy = math.floor(y / diameter) * diameter

    local positions = {}

    for dx = -2, 2 do
        for dy = -2, 2 do
            local x = cx + (dx * diameter) + (diameter * 0.5)
            local y = cy + (dy * diameter) + (diameter * 0.5)

            -- add some variation, this adds a random offset between -variation and +variation
            local hash1 = makeFastHash(x, y, GameSeed().int32)
            local hash2 = makeFastHash(y, GameSeed().int32, x)

            x = x + (math.fmod(hash1, variation * 2) - variation)
            y = y + (math.fmod(hash2, variation * 2) - variation)

            positions[#positions+1] = {x = x, y = y}
        end
    end

    return positions
end

function FactoryPredictor.getLocalSpecialization(x, y)
    local diameter = 50
    local positions = FactoryPredictor.getNearbySpecializationCenters(x, y, diameter)

    -- find closest of the above points
    local result
    local closest = (diameter / 2) * (diameter / 2) -- if it's too far away from any specialization point, no specialization happens
    for _, point in pairs(positions) do
        local dx = x - point.x
        local dy = y - point.y

        local d2 = dx * dx + dy * dy
        if d2 < closest then
            result = point
            closest = d2
        end
    end

    -- this is on purpose: if no specialization was found (because too far away from our made-up centers)
    -- then NO specialization is present in that area
    if not result then return end

    local hash = makeFastHash(result.x + 1, result.y + 2, GameSeed().int32)

    local specializations = 4
    local specialization = math.fmod(hash, specializations)

    return specialization, result.x, result.y
end

return FactoryPredictor
