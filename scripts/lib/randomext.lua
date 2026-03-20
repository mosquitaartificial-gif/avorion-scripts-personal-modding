-- This library serves as an extension to the existing random functions.
-- The math.random() function uses the c rand() and srand() functions, which are global for all lua states.
-- This means that whenever a lua state sets a new seed or requests a new value, the seed is changed for all other lua states as well.
-- In order to avoid this and to introduce 64bit seeds, these extensions were created.
-- They behave exactly the same way as the lua math.random() math.randomseed() functions, but accept Avorion's Seed class as well, which is basically a 64bit integer.
-- In addition to the 64 bit seeds, each lua state has a separate random number generator.
local rand = Random(Seed(appTimeMs()))

function isint(n)
    return n == math.floor(n)
end

function random()
    return rand
end

math.random = function(min, max)
    if min and max then
        return rand:getInt(min, max)
    elseif min then
        return rand:getInt(1, min)
    end

    return rand:getFloat()
end

math.randomseed = function(seed)
    if type(seed) == "number" then
        rand = Random(Seed(seed))
    else
        rand = Random(seed)
    end
end

function getFloat(minValue, maxValue)
    if minValue > maxValue then
        minValue, maxValue = maxValue, minValue
    end

    return rand:getFloat(minValue, maxValue)
end

function getInt(minValue, maxValue)
    if minValue > maxValue then
        minValue, maxValue = maxValue, minValue
    end

    return rand:getInt(minValue, maxValue)
end

function selectByWeight(random, values)
    if not values and type(random) == "table" then
        values = random
        random = rand
    end

    local thresholds = {}

    local sum = 0.0

    for key, value in pairs(values) do

        local t = {}

        t.lower = sum
        sum = sum + value
        t.upper = sum

        thresholds[key] = t
    end

    local rnd = random:getFloat(sum)
    local lastkey
    for key, value in pairs(thresholds) do

        if rnd >= value.lower and rnd < value.upper then
            return key
        end

        lastkey = key
    end

    return lastkey
end

function shuffle(random, array)
    if not array and type(random) == "table" then
        array = random
        random = rand
    end

    local entries = #array
    for i = 1, entries do
        local o = random:getInt(1, #array)
        array[i], array[o] = array[o], array[i]
    end
end

function randomEntry(random, array)
    if not array and type(random) == "table" then
        array = random
        random = rand
    end

    return array[random:getInt(1, #array)]
end

function makeSerialNumber(rnd_or_seed, length, prefix, postfix, chars)

    local random = rnd_or_seed or rand
    if type(random) == "number" or type(random) == "string" then
        random = Random(Seed(random))
    end
    if atype(random) == "Seed" then
        random = Random(random)
    end

    function generate(chars, num)
        local result = ""

        for i = 1, num do
            local c = random:getInt(1, #chars)
            result = result .. chars:sub(c, c)
        end

        return result
    end

    local usedChars = chars or "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

    return (prefix or "") .. generate(usedChars, length) .. (postfix or "")
end

function resetFixedRandomness()
    rand = Random(Seed(appTimeMs()))
end

function setFixedRandomness(float, int, testThreshold)
    rand = {}
    rand.getInt = function(self, min, max)
        min = min or int
        max = max or int

        return math.max(min, math.min(max, int))
    end

    rand.getFloat = function(self, min, max)
        min = min or float
        max = max or float

        return math.max(min, math.min(max, float))
    end

    rand.test = function(self, chance)
        return testThreshold > chance
    end

end
