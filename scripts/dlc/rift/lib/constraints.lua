package.path = package.path .. ";data/scripts/?.lua"

local Constraints = {}

-- The existing UUIDs should NOT be changed
-- the order of the constraints in the table doesn't matter, feel free to sort/organize
-- UUIDs were generated using https://www.uuidgenerator.net/ (Version 4 UUID)
Constraints.Type =
{
    MaxSlots = "17952767-a346-4f11-9c36-592688328310",
    MaxMass = "86c91bb2-fa12-47cd-8cac-c4a325091e43",
    CargoSpace = "dd862486-37d3-4a51-8dc1-799f8a30c5dc",
    DockingBlock = "4a958817-d1e0-45ab-85c7-a7fd273529be",
}

local registry = {}
registry[Constraints.Type.MaxSlots] = include("dlc/rift/lib/constraints/maxslotsconstraint")
registry[Constraints.Type.MaxMass] = include("dlc/rift/lib/constraints/maxmassconstraint")
registry[Constraints.Type.CargoSpace] = include("dlc/rift/lib/constraints/cargospaceconstraint")
registry[Constraints.Type.DockingBlock] = include("dlc/rift/lib/constraints/dockingblockconstraint")

function Constraints.makeConstraint(type, ...)
    local ConstraintClass = registry[type]

    if not ConstraintClass then
        eprint("Error: Constraint type %s not found", type)
        return
    end

    local instance = ConstraintClass(type)
    instance:initialize(...)

    return instance
end

function Constraints.getAllItemScripts()
    local result = {}
    for type, constraint in pairs(registry) do
        local instance = Constraints.makeConstraint(type)
        if instance.itemScript then
            table.insert(result, instance.itemScript)
        end
    end

    return result
end

return Constraints
