
local CargoSpaceConstraint = {}
CargoSpaceConstraint.__index = CargoSpaceConstraint

local function new(type, freeCargoSpace)
    local constraint = setmetatable({
        type = type,
        name = "Necessary Free Cargo Space"%_T,
        icon = "data/textures/icons/crate.png",
        error = "Not enough free cargo space."%_t
    }, CargoSpaceConstraint)

    return constraint
end

function CargoSpaceConstraint:initialize(freeCargoSpace)
    self.freeCargoSpace = freeCargoSpace
end

function CargoSpaceConstraint:isFulfilled(entity)
    if not entity then return false end

    return (entity.freeCargoSpace or 0) >= self.freeCargoSpace
end

function CargoSpaceConstraint:getMissionDescription()
    return "At least ${arg} free cargo space"%_T, {arg = self.freeCargoSpace}
end

function CargoSpaceConstraint:getUIValue()
    return self.freeCargoSpace
end

function CargoSpaceConstraint:getTooltipValue()
    return self.freeCargoSpace
end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
