package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("randomext")
include ("stationextensions")
local TeleporterGenerator = include ("teleportergenerator")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace RespawnTeleporter
RespawnTeleporter = {}

if onServer() then

function RespawnTeleporter.initialize()
    -- this checks on missing teleporters and spawns them if necessary
    TeleporterGenerator.createTeleporters()
end

end

