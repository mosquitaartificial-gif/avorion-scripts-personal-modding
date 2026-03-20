package.path = package.path .. ";data/scripts/lib/?.lua"
include ("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace LandFighters
LandFighters = {}

if onServer() then

function LandFighters.getUpdateInterval()
    return math.random() + 1.0
end

function LandFighters.initialize()
    LandFighters.updateLanding()
end

-- this function will be executed every frame on the server only
function LandFighters.updateServer(timeStep)
    LandFighters.updateLanding()
end

function LandFighters.updateLanding()
    local hangar = Hangar()
    local fighterController = FighterController()
    if not hangar or not fighterController then
        terminate()
        return
    end

    local deployedFighters = false
    for _, squad in pairs({hangar:getSquads()}) do
        if fighterController:getDeployedFighters(squad) ~= nil then
            fighterController:setSquadOrders(squad, FighterOrders.Return, Uuid())
            deployedFighters = true
        end
    end

    -- terminate when all fighters have landed
    if deployedFighters == false then
        terminate()
        return
    end
end

end
