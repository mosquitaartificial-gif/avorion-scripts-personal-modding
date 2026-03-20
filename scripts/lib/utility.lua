package.path = package.path .. ";data/scripts/lib/?.lua"
include("stringutility")

function lerp(factor, lowerBound, upperBound, lowerValue, upperValue, allowOverstepping)
    if lowerBound > upperBound then
        lowerBound, upperBound = upperBound, lowerBound
        lowerValue, upperValue = upperValue, lowerValue
    end

    if lowerBound == upperBound then
        return lowerValue
    end

    local value
    if allowOverstepping then
        value = (factor - lowerBound) / (upperBound - lowerBound)
    else
        value = math.min(1.0, math.max(0.0, (factor - lowerBound) / (upperBound - lowerBound)))
    end

    return lowerValue + (upperValue - lowerValue) * value
end

function multilerp(factor, from, to, values)
    factor = (factor - from) / (to - from)
    if factor > 1 then factor = 1 end
    if factor < 0 then factor = 0 end

    if #values == 0 then return nil end
    if #values == 1 then return values[1] end

    factor = factor * (#values - 1) + 1
    for i = 2, #values do
        local prev = i - 1
        if factor >= prev and factor < i then
            return lerp(factor, prev, i, values[prev], values[i])
        end
    end

    return values[#values]
end

function multilerpGeneric(factor, values)
    -- value has to be an array of (position, value) pairs where position indicates the "x-axis value", e.g. the dimension of 'factor'
    -- positions must be in ascending order

    if #values == 0 then return nil end
    if #values == 1 then return values[1].value end

    factor = math.max(factor, values[1].position)

    for i = 2, #values do
        local prev = values[i - 1]
        local current = values[i]
        if factor >= prev.position and factor < current.position then
            return lerp(factor, prev.position, current.position, prev.value, current.value)
        end
    end

    return values[#values].value
end

function round(num, idp)
    local mult = 10^(idp or 0)
    if num >= 0 then return math.floor(num * mult + 0.5) / mult
    else return math.ceil(num * mult - 0.5) / mult end
end

function getRandomEntry(tbl)
    return tbl[getInt(1, tablelength(tbl))]
end

function getDistribution(numElements, variation)
    assert(variation >= 0 and variation < 1, "Variation must be between [0 , 1)")
    assert(numElements > 0, "numElements must be > 0")

    local result = {}

    variation = variation * 0.5

    local sum = 0
    for i = 0, numElements - 1, 1 do
        local value = getFloat(0.5 - variation, 0.5 + variation)

        sum = sum + value

        result[i] = value
    end

    for i = 0, numElements - 1, 1 do
        result[i] = result[i] / sum
    end

    return result

end

function getValueFromDistribution(distribution, random)

    local thresholds = {}

    local sum = 0.0

    for key, value in pairs(distribution) do

        local t = {}

        t.lower = sum
        sum = sum + value
        t.upper = sum

        thresholds[key] = t
    end

    local rnd
    if random then
        rnd = random:getFloat(0.0, 1.0) * sum
    else
        rnd = math.random() * sum
    end

    local lastkey
    for key, value in pairs(thresholds) do

        if rnd >= value.lower and rnd < value.upper then
            return key
        end

        lastkey = key
    end

    return lastkey
end

function createDigitalTimeString(seconds)

    seconds = math.floor(seconds)

    local hours = math.floor(seconds / 3600)
    seconds = seconds - hours * 3600

    local minutes = math.floor(seconds / 60)
    seconds = seconds - minutes * 60


    local result = ""

    local tbl = {hours = hours, minutes = minutes, seconds = seconds}

    if hours > 0 and hours > 9 and minutes <= 9 then
        return "${hours}:0${minutes}" % tbl, tbl
    end
    if hours > 0 and hours > 9 and minutes > 9 then
        return "${hours}:${minutes}" % tbl, tbl
    end
    if hours > 0 and hours <= 9 and minutes > 9 then
        return "0${hours}:${minutes}" % tbl, tbl
    end
    if hours > 0 and hours <= 9 and minutes <= 9 then
        return "0${hours}:0${minutes}" % tbl, tbl
    end


    if minutes > 0 and minutes > 9 and seconds <= 9 then
        return "${minutes}:0${seconds}" % tbl, tbl
    end
    if minutes > 0 and minutes > 9 and seconds > 9 then
        return "${minutes}:${seconds}" % tbl, tbl
    end
    if minutes > 0 and minutes <= 9 and seconds > 9 then
        return "0${minutes}:${seconds}" % tbl, tbl
    end
    if minutes > 0 and minutes <= 9 and seconds <= 9 then
        return "0${minutes}:0${seconds}" % tbl, tbl
    end

    if seconds > 9 then
        return "00:${seconds}" % tbl, tbl
    end
    if seconds <= 9 then
        return "00:0${seconds}" % tbl, tbl
    end

end

function createReadableTimeTable(seconds)

    seconds = math.floor(seconds)

    local hours = math.floor(seconds / 3600)
    seconds = seconds - hours * 3600

    local minutes = math.floor(seconds / 60)
    seconds = seconds - minutes * 60

    local result = ""

    local tbl = {hours = hours, minutes = minutes, seconds = seconds}

    return tbl
end


function createReadableTimeString(seconds)

    seconds = math.floor(seconds)

    local hours = math.floor(seconds / 3600)
    seconds = seconds - hours * 3600

    local minutes = math.floor(seconds / 60)
    seconds = seconds - minutes * 60

    local result = ""

    local tbl = {hours = hours, minutes = minutes, seconds = seconds}

    if hours > 0 then
        return "${hours} hours, ${minutes} minutes"%_t % tbl
    end

    if minutes > 0 then
        return "${minutes} minutes, ${seconds} seconds"%_t % tbl
    end

    return "${seconds} seconds"%_t % tbl
end

function createReadableShortTimeString(seconds)

    seconds = math.floor(seconds)

    local hours = math.floor(seconds / 3600)
    seconds = seconds - hours * 3600

    local minutes = math.floor(seconds / 60)
    seconds = seconds - minutes * 60

    local result = ""

    local tbl = {hours = hours, minutes = minutes, seconds = seconds}

    if hours > 0 then
        return "${hours} h ${minutes} min"%_t % tbl
    end

    if minutes > 0 and seconds > 0 then
        return "${minutes} min, ${seconds} s"%_t % tbl
    elseif minutes > 0 then
        return "${minutes} min"%_t % tbl
    end

    return "${seconds} s"%_t % tbl
end

function toReadableValue(value, unit)
    local value, prefix = getReadableValue(value)

    return tostring(value) .. " " .. prefix .. (unit or "")
end

function getReadableValue(value, decimals_in)
    local unitPrefix = ""

    if value > 10.0 ^ 24 then
        value = value / 10.0 ^ 24
        unitPrefix = "Y /*10^24, prefix*/"%_t
    elseif value > 10.0 ^ 21 then
        value = value / 10.0 ^ 21
        unitPrefix = "Z /*10^21, prefix*/"%_t
    elseif value > 10.0 ^ 18 then
        value = value / 10.0 ^ 18
        unitPrefix = "E /*10^18, prefix*/"%_t
    elseif value > 10.0 ^ 15 then
        value = value / 10.0 ^ 15
        unitPrefix = "P /*10^15, prefix*/"%_t
    elseif value > 10.0 ^ 12 then
        value = value / 10.0 ^ 12
        unitPrefix = "T /*10^12, prefix*/"%_t
    elseif value > 10.0 ^ 9 then
        value = value / 10.0 ^ 9
        unitPrefix = "G /*10^9, prefix*/"%_t
    elseif value > 10.0 ^ 6 then
        value = value / 10.0 ^ 6
        unitPrefix = "M /*10^6, prefix*/"%_t
    elseif value > 10.0 ^ 3 then
        value = value / 10.0 ^ 3
        unitPrefix = "k /*10^3, prefix*/"%_t
    end

    decimals = decimals_in or 2
    return round(value, decimals), unitPrefix
end


function toReadableNumber(value, decimals)
    local value, prefix = getReadableNumber(value, decimals)

    return tostring(value) .. prefix
end

function getReadableNumber(value, decimals_in)
    local abbreviation = ""

    if value > 10.0 ^ 12 then
        value = value / 10.0 ^ 12
        abbreviation = "trill /*10^12, abbreviation*/"%_t
    elseif value > 10.0 ^ 9 then
        value = value / 10.0 ^ 9
        abbreviation = "bill /*10^9, abbreviation*/"%_t
    elseif value > 10.0 ^ 6 then
        value = value / 10.0 ^ 6
        abbreviation = "mill /*10^6, abbreviation*/"%_t
    elseif value > 10.0 ^ 3 then
        value = value / 10.0 ^ 3
        abbreviation = "k /*10^3, abbreviation*/"%_t
    end

    decimals = decimals_in or 2
    return round(value, decimals), abbreviation
end

function toGreekNumber(number)
    local greekAlphabet = { "Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta",
    "Eta", "Theta", "Iota", "Kappa", "Lambda", "My", "Ny", "Xi", "Omikron", "Pi",
    "Rho", "Sigma", "Tau", "Ypsilon", "Phi", "Chi", "Psi", "Omega" }

    return greekAlphabet[((number - 1) % #greekAlphabet) + 1]
end

function toRomanLiterals(number)

    local result = ""
    if number < 0 then
        number = -number
        result = "-"
    end

    while number >= 1000 do
        number = number - 1000
        result = result .. "M"
    end

    if number >= 900 then result = result .. "CM"; number = number - 900
    elseif number >= 800 then result = result .. "DCCC"; number = number - 800
    elseif number >= 700 then result = result .. "DCC"; number = number - 700
    elseif number >= 600 then result = result .. "DC"; number = number - 600
    elseif number >= 500 then result = result .. "D"; number = number - 500
    elseif number >= 400 then result = result .. "CD"; number = number - 400
    elseif number >= 300 then result = result .. "CCC"; number = number - 300
    elseif number >= 200 then result = result .. "CC"; number = number - 200
    elseif number >= 100 then result = result .. "C"; number = number - 100
    end

    if number >= 90 then result = result .. "XC"; number = number - 90
    elseif number >= 80 then result = result .. "LXXX"; number = number - 80
    elseif number >= 70 then result = result .. "LXX"; number = number - 70
    elseif number >= 60 then result = result .. "LX"; number = number - 60
    elseif number >= 50 then result = result .. "L"; number = number - 50
    elseif number >= 40 then result = result .. "XL"; number = number - 40
    elseif number >= 30 then result = result .. "XXX"; number = number - 30
    elseif number >= 20 then result = result .. "XX"; number = number - 20
    elseif number >= 10 then result = result .. "X"; number = number - 10
    end

    if number >= 9 then result = result .. "IX"
    elseif number >= 8 then result = result .. "VIII"
    elseif number >= 7 then result = result .. "VII"
    elseif number >= 6 then result = result .. "VI"
    elseif number >= 5 then result = result .. "V"
    elseif number >= 4 then result = result .. "IV"
    elseif number >= 3 then result = result .. "III"
    elseif number >= 2 then result = result .. "II"
    elseif number >= 1 then result = result .. "I"
    end

    return result;

end

function renderText(pos, caption, fontSize, outlined, alpha)
    local fontSize = fontSize or 12
    local alpha = alpha or 1
    local outlined = outlined or 2
    local py = pos.y + fontSize * 1.5
    drawText(caption, pos.x, py, ColorARGB(alpha, 1, 1, 1), fontSize, 0, 0, outlined)

    return py - pos.y + 10
end

function renderPrices(pos, caption, money, resources)

    local earlyExit = true
    money = money or 0
    resources = resources or {}

    if money > 0 then earlyExit = false end

    for i, v in ipairs(resources) do
        if v > 0 then
            earlyExit = false
            break
        end
    end

    if earlyExit then return 0 end

    local fontSize = 13

    drawText(caption, pos.x, pos.y, ColorRGB(1, 1, 1), fontSize, 0, 0, 2)
    local py = pos.y + fontSize * 1.5

    -- render contruction costs
    if money > 0 then
        drawText("¢", pos.x, py, ColorRGB(1, 1, 1), fontSize, 0, 0, 2)
        drawText(createMonetaryString(round(money, 0)), pos.x + 100, py, ColorRGB(1, 1, 1), fontSize, 0, 0, 2)
        py = py + fontSize
    end

    -- render resources costs
    for i, v in ipairs(resources) do
        local planResources = resources[i]

        if planResources > 0 then
            drawText(Material(i - 1).name, pos.x, py, Material(i - 1).color, fontSize, 0, 0, 2)
            drawText(createMonetaryString(round(planResources, 0)), pos.x + 100, py, Material(i - 1).color, fontSize, 0, 0, 2)
            py = py + fontSize
        end
    end

    return py - pos.y + 10
end

function GetRelationChangeFromMoney(money)
    return 1 + money / 500
end

function tablelength(T)
    if T == nil then return 0 end

    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

function table.first(tbl)
    for _, value in pairs(tbl) do
        return value
    end
end

function pairsByKeys (t, f)
    local a = {}
    for n in pairs(t) do table.insert(a, n) end
    table.sort(a, f)
    local i = 0      -- iterator variable
    local iter = function ()   -- iterator function
        i = i + 1
        if a[i] == nil then return nil
        else return a[i], t[a[i]]
        end
    end
    return iter
end

-- shamelessly copied from the lua doc
function string:split(sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end

function string:firstToUpper()
    return (self:gsub("^%l", string.upper))
end

function printEntityDebugInfo(entity)
    entity = entity or Entity()
    if not entity then return end

    local scripts = ""
    for _, name in pairs(entity:getScripts()) do
        scripts = scripts .. "'" .. name .. "' "
    end

    local faction = Faction(entity.factionIndex)
    local factionName = ""

    if faction then factionName = faction.translatedName end

    print ("## Entity Information ##")
    print ("Index: " .. entity.index.string)
    print ("Title: " .. (entity.title or ""))
    print ("Scripts: " .. scripts)
    print ("Owner: " .. factionName)
    print ("## Entity Information End ##")

end

function findMinimum(array, eval)
    local d = math.huge
    local min
    for _, e in pairs(array) do
        local de = eval(e)
        if de < d then
            d = de
            min = e
        end
    end
    return min
end

function findMaximum(array, eval)
    local d = -math.huge
    local max
    for _, e in pairs(array) do
        local de = eval(e)
        if de > d then
            d = de
            max = e
        end
    end
    return max
end

function multimin(a, b, ...)
    if not b then return a end
    return multimin(math.min(a, b), ...)
end

function multimax(a, b, ...)
    if not b then return a end
    return multimax(math.max(a, b), ...)
end

function printVec2(vec, prefix)
    local text = ""
    if prefix then
        text = text .. prefix .. " "
    end

    text = text .. "(" .. vec.x .. ", " .. vec.y .. ")"
    print(text)
end

function printVec3(vec, prefix)
    local text = ""
    if prefix then
        text = text .. prefix .. " "
    end

    text = text .. "(" .. vec.x .. ", " .. vec.y .. ", " .. vec.z .. ")"
    print(text)
end

function printTable(tbl, prefix, maxDepth, ignoreFunctions)
    if not maxDepth then maxDepth = 100 end

    if prefix and string.len(prefix) > maxDepth then return end

    prefix = prefix or ""
    for k, v in pairs(tbl) do
        if type(v) == "string" then
            print (prefix .. "." .. tostring(k) .. " -> \"" .. tostring(v) .. "\"")
        elseif type(v) == "userdata" and v.__avoriontype then
            print (prefix .. "." .. tostring(k) .. " -> [" .. v.__avoriontype .. "] " .. tostring(v))
        elseif type(v) == "function" then
            if not ignoreFunctions then
                print (prefix .. "." .. tostring(k) .. " -> " .. tostring(v))
            end
        else
            print (prefix .. "." .. tostring(k) .. " -> " .. tostring(v))
        end

        if type(v) == "table" then
            printTable(v, prefix .. "  ", maxDepth, ignoreFunctions)
        end
    end
end

function directionalDistance(d, coords)
    coords = coords or vec2(Sector():getCoordinates())

    local dir = vec2(coords.x, coords.y) -- this way we can use tables, too
    normalize_ip(dir)

    dir = dir * d

    return {x = math.floor(dir.x + 0.5), y = math.floor(dir.y + 0.5)}
end

-- whenever you execute code with this function, remember that any global variables you create (except for the run(...) function)
-- will remain in the global namespace since there's no way of determining which variables/functions were created
function execute(code, ...)

    local f = assert(loadstring(code))
    local runBefore = run

    f()

    local returnValues = {run(...)}
    run = runBefore

    return unpack(returnValues)
end

function makeReadOnlyTable(table)
   return setmetatable({}, {
     __index = table,
     __newindex = function(table, key, value)
                    error("Attempt to modify read-only table")
                  end,
     __metatable = false
   });
end

function nonils(...)
    local values = {...}
    if #values == 0 then return false end

    for _, var in pairs(values) do
        if var == nil then return false end
    end

    return true
end

function anynils(...)
    local values = {...}
    if #values == 0 then return true end

    for _, var in pairs(values) do
        if var == nil then return true end
    end

    return false
end

function is_type(value, expected)
    local typestr = type(value)

    if typestr == "userdata" then
        return trim(expected:lower()) == string.lower(value.__avoriontype)
    else
        return trim(expected:lower()) == string.lower(typestr)
    end
end

function atype(value)
    local typestr = type(value)

    if typestr == "userdata" then
        return value.__avoriontype
    else
        return typestr
    end
end

-- Save copied tables in `copies`, indexed by original table.
function table.deepcopy(orig)

    local function deepcopy(orig, copies)
        copies = copies or {}
        local orig_type = type(orig)
        local copy
        if orig_type == 'table' then
            if copies[orig] then
                copy = copies[orig]
            else
                copy = {}
                for orig_key, orig_value in next, orig, nil do
                    copy[deepcopy(orig_key, copies)] = deepcopy(orig_value, copies)
                end
                copies[orig] = copy
                setmetatable(copy, deepcopy(getmetatable(orig), copies))
            end
        else -- number, string, boolean, etc
            copy = orig
        end
        return copy
    end

    return deepcopy(orig)
end

function dbg(a)
    if type(a) == "userdata" then
        print (tostring(a) .. " " .. a.__avoriontype)
    else
        print (tostring(a))
    end
end


function table.getOrInsert(tbl, key, v)
    local existing = tbl[key]
    if existing then return existing end

    tbl[key] = v
    return v
end

function table.concatenate(tbl, add)
    for _, value in pairs(add) do
        table.insert(tbl, value)
    end
end

function makeCallbackSenderInfo(entity)
    local x, y = Sector():getCoordinates()
    return {id = entity.id, coordinates = {x = x, y = y}}
end
