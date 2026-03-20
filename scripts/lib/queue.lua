
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("utility")

local Queue = {}
Queue.__index = Queue

local function new(seed)

    local instance = setmetatable({
        first = 0,
        last = -1,
        entries = {},
    }, Queue)

    return instance
end

function Queue:pushFront(value)
    local first = self.first - 1
    self.entries[first] = value
    self.first = first
end

function Queue:pushBack(value)
    local last = self.last + 1
    self.entries[last] = value
    self.last = last
end

function Queue:popFront()
    if self:empty() then return end

    local first = self.first
    local value = self.entries[first]
    self.entries[first] = nil
    self.first = first + 1

    -- do some cleanup to combat overflow over time
    if self:empty() then
        self.first = 0
        self.last = -1
    end

    return value
end

function Queue:popBack()
    if self:empty() then return end

    local last = self.last
    local value = self.entries[last]
    self.entries[last] = nil
    self.last = last - 1

    -- do some cleanup to combat overflow over time
    if self:empty() then
        self.first = 0
        self.last = -1
    end

    return value
end

function Queue:front()
    return self.entries[self.first]
end

function Queue:back()
    return self.entries[self.last]
end

function Queue:size()
    return self.last - self.first + 1
end

function Queue:empty()
    return self.first > self.last
end

function Queue:clear()
    self.first = 0
    self.last = -1
    self.entries = {}
end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
