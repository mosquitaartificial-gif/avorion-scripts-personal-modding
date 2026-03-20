
local UICollection = {}
UICollection.__index = UICollection

local function new()
    local instance = {}
    instance.elements = {}
    return setmetatable(instance, UICollection)
end

function UICollection:insert(element)
    table.insert(self.elements, element)
end

function UICollection:show()
    for _, element in pairs(self.elements) do
        element:show()
    end
end

function UICollection:hide()
    for _, element in pairs(self.elements) do
        element:hide()
    end
end


return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
