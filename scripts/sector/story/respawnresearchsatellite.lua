
package.path = package.path .. ";data/scripts/lib/?.lua"

local Scientist = include ("story/scientist")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace RespawnResearchSatellite
RespawnResearchSatellite = {}

if onServer() then

function RespawnResearchSatellite.initialize()
    -- check if there is already a satellite
    if Sector():getEntitiesByScript("data/scripts/entity/story/researchsatellite.lua") then return end

    -- if not, create a new one
    Scientist.createSatellite(Matrix())
end


end
