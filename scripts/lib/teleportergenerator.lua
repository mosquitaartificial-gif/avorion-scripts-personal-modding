local Balancing = include ("galaxy")
include ("stationextensions")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace TeleporterGenerator
TeleporterGenerator = {}

if onServer() then

function TeleporterGenerator.createTeleporters()
    local neededNumbers = {}

    -- don't double spawn
    local entities = {Sector():getEntitiesByScriptValue("teleporter")}
    for _, teleporter in pairs(entities) do
        local number = teleporter:getValue("teleporter")
        if number then
            neededNumbers[number] = true
        end
    end

    -- spawn missing ones
    local num = 8
    for i = 1, num do
        if not neededNumbers[i] then
            -- spawn missing teleporter
            local angle = i * (1 / num) * math.pi * 2.0
            local p = vec3(math.sin(angle), 0, math.cos(angle)) * 1000

            local desc = EntityDescriptor()
            desc:addComponents(
               ComponentType.Plan,
               ComponentType.BspTree,
               ComponentType.Intersection,
               ComponentType.Asleep,
               ComponentType.DamageContributors,
               ComponentType.BoundingSphere,
               ComponentType.BoundingBox,
               ComponentType.Velocity,
               ComponentType.Physics,
               ComponentType.Scripts,
               ComponentType.ScriptCallback,
               ComponentType.Title,
               ComponentType.WreckageCreator
               )

            desc:setPlan(TeleporterGenerator.getPlan())
            desc.title = toRomanLiterals(i)
            desc.position = MatrixLookUpPosition(vec3(0, 1, 0), p, p)

            addAsteroid(desc)

            local entity = Sector():createEntity(desc)

            entity:setValue("teleporter", i)
        end
    end
end

function TeleporterGenerator.getPlan()

    if TeleporterGenerator.plan then return TeleporterGenerator.plan end

    local plan = LoadPlanFromFile("data/plans/teleporter.xml")
    plan.accumulatingHealth = true

    TeleporterGenerator.plan = plan -- prevent multiple loads

    return plan
end

end

return TeleporterGenerator
