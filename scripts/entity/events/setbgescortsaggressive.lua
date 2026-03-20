package.path = package.path .. ";data/scripts/lib/?.lua"

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace SetBGEscortsAggressive
SetBGEscortsAggressive = {}

function SetBGEscortsAggressive.initialize()
    local ai = ShipAI()
    ai:setAggressive()
    terminate()
end
