
-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace CatchUpComponents
CatchUpComponents = {}

if onServer() then

function CatchUpComponents.initialize()
end

function CatchUpComponents.updateServer()
    -- this must not be done in initialize
    -- because it relies on other scripts having been initialized, e.g. fighter squad systems
    local entity = Entity()
    local timeToCatchUp = entity:getValue("time_to_catch_up")

    if timeToCatchUp then
        entity:updateProductionCatchingUp(timeToCatchUp)
    end

    entity:setValue("time_to_catch_up", nil)

    terminate()
end

end
