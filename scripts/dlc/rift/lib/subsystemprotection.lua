
SubsystemProtection = {}
SubsystemProtection.maxProtection = 15

function SubsystemProtection.calculateProtection(seed, max)
    max = max or SubsystemProtection.maxProtection

    local value
    if type(seed) == "number" then
        value = seed
    else
        value = seed.value
    end

    if value < 0 then value = -value end
    if value == 0 then return 0 end

    value = value % max

    if value == 0 then
        -- we want 1, 2, 3, 4, 5 with a max of 3 to return 1, 2, 3, 1, 2; not 1, 2, 0, 1, 2
        return max
    else
        return value
    end
end

function SubsystemProtection.getProtection(craft)
    local sum = 0

    for i, script in pairs(craft:getScripts()) do
        local ok, value = craft:invokeFunction(i, "getSubspaceDistortionProtection")
        if ok == 0 and value then
            sum = sum + value
        end
    end

    return sum
end

function SubsystemProtection.adjustSeed(seed, protection)
    local sum = 0

    if type(seed) == "number" then
        value = seed
    else
        value = seed.value
    end

    -- we must reduce the seed spectrum to avoid rounding errors in very large floating point numbers
    value = value % 10000000
    value = math.floor(value / SubsystemProtection.maxProtection) * SubsystemProtection.maxProtection + protection

    return Seed(value)
end

return SubsystemProtection
