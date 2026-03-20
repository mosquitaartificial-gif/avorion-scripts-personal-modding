
local DockingBlockConstraint = {}
DockingBlockConstraint.__index = DockingBlockConstraint

local function new(type)
    local constraint = setmetatable({
        type = type,
        name = "Docking Equipment Required"%_t,
        icon = "data/textures/icons/dock.png",
        description = "Your ship needs to have unobstructed dock blocks to be able to complete this mission."%_t,
        error = "Not enough docking blocks."%_t
    }, DockingBlockConstraint)

    return constraint
end

function DockingBlockConstraint:initialize()
end

function DockingBlockConstraint:isFulfilled(entity)
    if not entity then return false end

    local clamps = DockingClamps(entity.id)
    -- numDocks only counts unobstructed docks
    if clamps and clamps.numDocks > 2 then
        return true
    end

    return false
end

function DockingBlockConstraint:getMissionDescription()
    return "Have at least 3 working dock blocks"%_T, {}
end

function DockingBlockConstraint:getUIValue()
end

function DockingBlockConstraint:getTooltipValue()
end


return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
