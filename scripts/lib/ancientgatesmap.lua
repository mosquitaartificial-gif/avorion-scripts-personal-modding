
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local GatesMap = include ("gatesmap")
local OperationExodus = include ("story/operationexodus")

local AncientGatesMap = {}
AncientGatesMap.__index = AncientGatesMap

local function new(serverSeed)
    local obj = GatesMap(serverSeed)
    obj.range = 150
    obj.range2 = obj.range * obj.range

    obj.hasGates = function(self, x, y)
        if x < -499 or x > 500 or y < -499 or y > 500 then return false end

        local specs = self.specs

        if not self.exodusCorners then
            self.exodusCorners = OperationExodus.getCornerPoints()
        end

        -- exodus corners always have an ancient gate
        for _, corner in pairs(self.exodusCorners) do
            if x == corner.x and y == corner.y then
                return true
            end
        end

        local regular, offgrid, blocked, home = self.specs:determineContent(x, y, self.serverSeed)
        if blocked or (not regular and not offgrid and not home) then return false end

        specs:initialize(x, y, self.serverSeed)

        return specs.ancientGates
    end

    return obj
end


return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
