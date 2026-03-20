package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("utility")

local assert = assert
local FactionsMap = {}
FactionsMap.__index = FactionsMap

local function new(seed)

    local instance = {
        civilisationRange = 17,
    }

    local obj = setmetatable(instance, FactionsMap)

    obj:initialize(seed, -499, 500, 1750, GameSettings().mapFactions)

    return obj
end

function FactionsMap:initialize(seed, min, max, numCivilisationDots, numFactions)
    -- build up data
    self.seed = seed;

    local random = Random(seed)

    -- create quad tree & index map
    self.civilisationTree = QuadTree(vec2(min, min), vec2(max, max), 7)
    self.factionTree = QuadTree(vec2(min, min), vec2(max, max), 7)
    self.homeSectors = {}
    self.factions = {}
    self.factionIndexOffset = 2000000
    self.numCivilisationDots = numCivilisationDots
    self.numFactions = numFactions

    -- start counting at 2mio to make sure that factions created during runtime (such as players)
    -- are not mistaken for factions on the map
    local offset = self.factionIndexOffset
    local dotsCreated = 0
    local dotsPerFaction = numCivilisationDots / numFactions
    local factionCreationWeight = math.max(0, math.min(1, 1 / dotsPerFaction))
    local factionCreationCount = 0
    local coords = vec2()

    while dotsCreated < numCivilisationDots do
        local x = random:getInt(min, max)
        local y = random:getInt(min, max)

        coords.x = x
        coords.y = y
        local rx, ry = self.civilisationTree:nearest(x, y)

        local create = true

        -- make sure coordinates are not yet in the tree
        if rx and ry then
            if rx == x and ry == y then
                create = false
            end
        end

        local d = length(coords)

        -- don't create sectors that are too near to the center
        if d < 50 then
            create = false
            dotsCreated = dotsCreated + 1
        end

        local probability = math.max(0, d - 50) / 400
        probability = math.max(0.15, probability)
        if random:getFloat(0, 1) > probability then
            create = false
            dotsCreated = dotsCreated + 1
        end


        -- or too far away
        if d > 450 then

            local probability = (650 - d) / 300
            if random:getFloat(0, 1) > probability then
                create = false
                dotsCreated = dotsCreated + 1
            end
        end

        if create then
            self.civilisationTree:insert(coords)

            -- create a faction every X dots
            factionCreationCount = factionCreationCount + factionCreationWeight
            if factionCreationCount > 1 then
                factionCreationCount = factionCreationCount - 1
                self:insert(offset + dotsCreated, coords)
            end

            dotsCreated = dotsCreated + 1
        end
    end

end

function FactionsMap:insert(factionIndex, coords)
--    print ("Faction " .. factionIndex .. " at " .. coords.x .. " - " .. coords.y)

    local x, y = coords.x, coords.y

    self.factionTree:insert(vec2(x, y))

    self.homeSectors[factionIndex] = vec2(x, y)

    self.factions[x] = self.factions[x] or {}
    assert(self.factions[x][y] == nil)
    self.factions[x][y] = factionIndex
end

function FactionsMap:exists(factionIndex)
    return self.homeSectors[factionIndex] ~= nil
end

function FactionsMap:getHomeSector(factionIndex)
    return self.homeSectors[factionIndex]
end

function FactionsMap:getFaction(x, y)
    return self:retrieve(x, y)
end

function FactionsMap:retrieve(x, y)
    local cx, cy = self.civilisationTree:nearest(x, y, self.civilisationRange)

    if cx and cy then
        x, y = self.factionTree:nearest(x, y)

        if x and y and self.factions[x] then
            return self.factions[x][y]
        end
    end
end

function FactionsMap:getNearestFaction(x, y)
    local x, y = self.factionTree:nearest(x, y)

    if x and y and self.factions[x] then
        return self.factions[x][y]
    end
end

function FactionsMap:getFactionIndices()
    local result = {}

    for index, hs in pairs(self.homeSectors) do
        table.insert(result, index)
    end

    return result
end

function FactionsMap:isCentralFactionArea(x, y, factionIndex)
    if not factionIndex then
        factionIndex = self:getFaction(x, y)
    end

    local homeSector = self.homeSectors[factionIndex]
    if not homeSector then return false end

    local dx = x - homeSector.x
    local dy = y - homeSector.y
    return dx * dx + dy * dy <= 20 * 20
end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
