
local MaxSlotsConstraint = {}
MaxSlotsConstraint.__index = MaxSlotsConstraint

local function new(type)
    local constraint = setmetatable({
        type = type,
        name = "Maximum Possible Slots"%_T,
        icon = "data/textures/icons/circuitry.png",
        error = "Too many slots."%_t
    }, MaxSlotsConstraint)

    return constraint
end

function MaxSlotsConstraint:initialize(maxSlots)
    self.maxSlots = maxSlots
end

function MaxSlotsConstraint:isFulfilled(entity)
    if not entity then return false end

    local shipSystem = ShipSystem(entity)
    if not shipSystem then return false end

    return shipSystem.numSockets <= self.maxSlots
end

function MaxSlotsConstraint:getMissionDescription()
    return "No more than ${arg} slots"%_T, {arg = self.maxSlots}
end

function MaxSlotsConstraint:getUIValue()
    return self.maxSlots
end

function MaxSlotsConstraint:getTooltipValue()
    return self.maxSlots
end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
