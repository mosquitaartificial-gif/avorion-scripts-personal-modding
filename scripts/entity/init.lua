-- This is always the first script that is executed for an entity with the Scripts component

-- Note: This script does not get attached to the Entity
-- Note: This script is called BEFORE any other scripts are initialized
-- Note: This script is called BEFORE any other scripts are added when creating new Entities (like stations)
-- Note: When loading from Database, other scripts attached to the Entity are available through Entity():hasScript() etc.
-- Note: When adding scripts to the entity from here with addScript() or addScriptOnce(),
--       the added scripts will NOT get initialized immediately,
--       their initialization order is not defined,
--       parameters passed in addition to the script name will be IGNORED and NOT passed to the script's initialize() function,
--       and the script will instead be treated as if loaded from database, with the _restoring variable set in its initialize() function

if onServer() then

local entity = Entity()

if entity:hasComponent(ComponentType.DockingPositions) and entity.type == EntityType.Station then
    entity:addScriptOnce("entity/regrowdocks.lua")
    entity:addScriptOnce("entity/utility/transportmode.lua")
else
    entity:removeScript("entity/regrowdocks.lua")
end

if entity:hasComponent(ComponentType.Crew) then
    entity:addScriptOnce("entity/utility/captainshipbonuses.lua")
end

if entity.allianceOwned then
    entity:addScriptOnce("entity/claimalliance.lua")
end

if entity:hasComponent(ComponentType.ShipAI) then
    entity:addScriptOnce("data/scripts/entity/orderchain.lua")

    if entity.aiOwned then
        entity:addScriptOnce("data/scripts/entity/utility/aiundocking.lua")
    end
end

if entity.type == EntityType.Ship then
    entity:addScriptOnce("entity/showshipwindow.lua")
end

if entity.type == EntityType.Station then
    entity:addScriptOnce("data/scripts/entity/stationambientsound.lua")
    entity:addScriptOnce("entity/utility/updatefactioneradication.lua")
    entity:addScriptOnce("entity/utility/minimumpopulation.lua")
    entity:addScriptOnce("entity/showshipwindow.lua")
end

end
