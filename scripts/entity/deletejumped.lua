
-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace DeleteJumped
DeleteJumped = {}


function DeleteJumped.initialize(time)
    if onServer() then
        deferredCallback(time or 4.5, "deleteMe")
    end

    if onClient() then
        Sector():createHyperspaceEnteringGlowAnimation(Entity())
    end
end

function DeleteJumped.updateServer()
    ShipAI():setIdle()
    ControlUnit():setDesiredVelocity(1)
end

function DeleteJumped.deleteMe()
    Sector():deleteEntityJumped(Entity())
end
