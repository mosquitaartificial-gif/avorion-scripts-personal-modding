
package.path = package.path .. ";data/scripts/lib/?.lua"

local ShipUtility = include("shiputility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace AddArmedTurrets
AddArmedTurrets = {}

if onServer() then

function AddArmedTurrets.initialize()
    ShipUtility.addArmedTurretsToCraft(Entity())
    terminate()
end

end
