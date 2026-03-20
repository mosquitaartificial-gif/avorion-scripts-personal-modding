
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace RespawnWaveEncounters
RespawnWaveEncounters = {}
local self = RespawnWaveEncounters

if onServer() then

self.data = {}
self.data.encounterLastSeen = nil
self.respawnTime = 24 * 60 * 60
self.cancelRespawnTime = 2 * 60 * 60

function RespawnWaveEncounters.getUpdateInterval()
    return 60
end

function RespawnWaveEncounters.initialize(encounterScript)

    local sector = Sector()
    sector:registerCallback("onCancelWaveEncounter", "onCancelWaveEncounter")

    if not _restoring then
        self.data.encounterScript = encounterScript

        self.refreshStatus()
    end
end

function RespawnWaveEncounters.updateServer()
    self.refreshStatus()
end

function RespawnWaveEncounters.onPlayerLeft()
    self.refreshStatus()
end

function RespawnWaveEncounters.resetEncounter()

    local sector = Sector()

    -- if the encounter is not there, then check if we can already readd it
    if not sector:hasScript(self.data.encounterScript) then
        if self.canRespawnEncounterByTime() then
            self.addEncounter()
        end
    else
        -- if it's already there, check if we can/should reset the encounter
        if self.isResetPossible() then
            self.removeEncounter()
            self.addEncounter()
        end
    end

end

function RespawnWaveEncounters.refreshStatus()

    -- if the encounter is there, remember when we last saw it
    if Sector():hasScript(self.data.encounterScript) then
        self.data.encounterLastSeen = Server().unpausedRuntime
    else
        if self.canRespawnEncounterByTime() then
            self.addEncounter()
        end
    end

end

function RespawnWaveEncounters.canRespawnEncounterByTime()
    local now = Server().unpausedRuntime

    if not self.data.encounterLastSeen or now - self.data.encounterLastSeen > self.respawnTime then
        return true
    end
end

function RespawnWaveEncounters.onCancelWaveEncounter()
    self.removeEncounter()
    self.setRespawnIn(self.cancelRespawnTime)
end

function RespawnWaveEncounters.addEncounter()
    Sector():addScriptOnce(self.data.encounterScript)
    self.data.encounterLastSeen = Server().unpausedRuntime
end

function RespawnWaveEncounters.removeEncounter()
    local sector = Sector()
    sector:removeScript(self.data.encounterScript)

    -- delete all wave-encounter specific entities
    for _, entity in pairs({sector:getEntitiesByScriptValue("wave_encounter_specific")}) do
        sector:deleteEntity(entity)
    end

    for _, entity in pairs({sector:getEntitiesByScriptValue("is_wave")}) do
        sector:deleteEntity(entity)
    end

    -- delete all wreckages with a timer
    for _, entity in pairs({sector:getEntitiesByType(EntityType.Wreckage)}) do
        if entity:hasComponent(ComponentType.DeletionTimer) then
            local timer = DeletionTimer(entity)
            if timer.enabled then
                sector:deleteEntity(entity)
            end
        end
    end
end

function RespawnWaveEncounters.isResetPossible()
    -- only reset when there are no players or their entities in the sector
    local sector = Sector()

    -- if the encounter is not there, don't reset
    if not sector:hasScript(self.data.encounterScript) then return false end

    -- only reset without players
    if sector.numPlayers > 0 then return false end

    -- only without player entities
    for _, type in pairs({EntityType.Ship, EntityType.Station, EntityType.Fighter}) do
        for _, entity in pairs({sector:getEntitiesByType(type)}) do
            if entity.playerOwned or entity.allianceOwned then
                return false
            end
        end
    end

    return true
end

-- ensures that the next encounter respawns in timeFromNow seconds
function RespawnWaveEncounters.setRespawnIn(timeFromNow)
    local now = Server().unpausedRuntime

    self.data.encounterLastSeen = (now + timeFromNow) - self.respawnTime
end


function RespawnWaveEncounters.secure()
    return self.data
end

function RespawnWaveEncounters.restore(values)
    self.data = values

    self.resetEncounter()
    self.refreshStatus()
end

end
