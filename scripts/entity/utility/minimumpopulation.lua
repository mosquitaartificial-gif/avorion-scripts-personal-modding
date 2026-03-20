package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace MinimumPopulation
MinimumPopulation = {}

function MinimumPopulation.getUpdateInterval()
    return 1
end

function MinimumPopulation.initialize()
    local self = Entity()

    if onServer() then
        self:registerCallback("onCrewChanged", "onCrewChanged")
        self:registerCallback("onBlockPlanChanged", "onBlockPlanChanged")
    end

    if not self:getValue("min_pop_fix_applied") then
        self:setValue("min_pop_fix_applied", true)
        MinimumPopulation.fixStationIssues()
    end

    MinimumPopulation.updateFulfilledValue()
end

function MinimumPopulation.fixStationIssues()
    local self = Entity()

    if self.crewSize < 30 then
        self:addCrew(30 - self.crewSize, CrewMan(CrewProfessionType.None, false, 1))
    end

    if self.maxCrewSize < 30 then
        local plan = Plan()
        local lowestY = plan:getNthBlock(0)

        for i = 1, plan.numBlocks - 1 do
            local block = plan:getNthBlock(i)

            local box = block.box
            if box.lower.y < lowestY.box.lower.y then lowestY = block end
        end

        local size = vec3(4, 4, 4)
        local direction = vec3(0, -1, 0)

        local position = lowestY.box.center + (lowestY.box.size * 0.5 * direction) + (size * 0.5 * direction)
        local orientation = MatrixLookUp(direction, vec3(0, 1, 0))
        plan:addBlock(position, size, lowestY.index, -1, lowestY.color, lowestY.material, orientation, BlockType.Quarters, ColorNone())
    end
end

function MinimumPopulation.updateClient(timeStep)
    if MinimumPopulation.isFulfilled() then
        removeShipProblem("MinimumPopulation", Entity().id)
    else
        local text = "Station needs a minimum population of at least 30 crewmen (and quarters) to function."%_t
        local color = ColorRGB(1, 1, 0)
        local icon = "data/textures/icons/minimum-population.png"

        addShipProblem("MinimumPopulation", Entity().id, text, icon, color)
    end
end

function MinimumPopulation.updateFulfilledValue()
    Entity():setValue("minimum_population_fulfilled", MinimumPopulation.isFulfilled())
end

function MinimumPopulation.isFulfilled()
    local self = Entity()
    if not self.playerOrAllianceOwned then return true end

    return self.crewSize >= 30 and self.maxCrewSize >= 30
end

function MinimumPopulation.onBlockPlanChanged()
    MinimumPopulation.updateFulfilledValue()
end

function MinimumPopulation.onCrewChanged()
    MinimumPopulation.updateFulfilledValue()
end
