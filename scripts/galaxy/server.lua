package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/server/?.lua"
include ("factions")
include ("stringutility")
local FactionPacks = include ("factionpacks")

function initialize()
    Server():registerCallback("onPlayerLogIn", "onPlayerLogIn")
    Server():registerCallback("onPlayerLogOff", "onPlayerLogOff")
    Galaxy():registerCallback("onPlayerCreated", "onPlayerCreated")
    Galaxy():registerCallback("onFactionCreated", "onFactionCreated")

    FactionPacks.initialize()
end

-- guardian_respawn_time:   Respawn Time of Guardian (updated in line 22ff, set in wormholeguardian.lua:79)
-- xsotan_swarm_time:       Respawn Time of Xsotan Swarm (updated in line 34ff and set in line 55 and 65)
-- xsotan_swarm_duration:   Base time player have to complete the xsotan swarm event, is increased by 10 min if end boss spawns
function update(timeStep)
    local server = Server()

    local guardianRespawnTime = server:getValue("guardian_respawn_time")
    if guardianRespawnTime then

        guardianRespawnTime = guardianRespawnTime - timeStep
        if guardianRespawnTime < 0 then
            guardianRespawnTime = nil
            server:broadcastChatMessage("Server", ChatMessageType.Information, "Strong subspace disturbances have been detected. They seem to be originating from the center of the galaxy."%_T)
        end

        server:setValue("guardian_respawn_time", guardianRespawnTime)
    end

    local xsotanSwarmSpawnTime = server:getValue("xsotan_swarm_time")
    if xsotanSwarmSpawnTime then
        xsotanSwarmSpawnTime = xsotanSwarmSpawnTime - timeStep
        if xsotanSwarmSpawnTime <= 0 then
            server:setValue("xsotan_swarm_active", true)
            server:setValue("xsotan_swarm_success", nil)
            server:setValue("xsotan_swarm_duration", 30 * 60)
            server:setValue("xsotan_swarm_time", nil)
            server:broadcastChatMessage("", ChatMessageType.Information, "Massive amounts of Xsotan are swarming in the center of the galaxy."%_T)
        else
            server:setValue("xsotan_swarm_time", xsotanSwarmSpawnTime)
        end
    end

    local xsotanSwarmEventTime = server:getValue("xsotan_swarm_duration")
    if xsotanSwarmEventTime then
        xsotanSwarmEventTime = xsotanSwarmEventTime - timeStep
        local success = server:getValue("xsotan_swarm_success")
        if success then
            -- xsotan swarm defeated => set respawn time
            server:sendCallback("onXsotanSwarmEventWon")
            server:setValue("xsotan_swarm_time", 120 * 60)
            server:setValue("xsotan_swarm_duration", nil)
            server:setValue("xsotan_swarm_active", false)
            server:broadcastChatMessage("", ChatMessageType.Information, "The Xsotan swarm invasion has been defeated!"%_T)

        elseif xsotanSwarmEventTime <= 0 then
            server:setValue("xsotan_swarm_active", false)
            server:setValue("xsotan_swarm_duration", nil)
            if not success then
                -- xsotan swarm has not been defeated
                server:sendCallback("onXsotanSwarmEventFailed")
                server:setValue("xsotan_swarm_time", 120 * 60)
                server:setValue("xsotan_swarm_success", false)
                server:broadcastChatMessage("", ChatMessageType.Information, "The defenses were overrun. The attack of the Xsotan swarm succeded."%_T)
            end
        else
            server:setValue("xsotan_swarm_duration", xsotanSwarmEventTime)
        end
    end

    local serverRuntime = server:getValue("online_time") or 0
    serverRuntime = serverRuntime + timeStep
    server:setValue("online_time", serverRuntime)

end

function onPlayerCreated(index)
    local player = Player(index)
    Server():broadcastChatMessage("Server", ChatMessageType.ServerInfo, "Player %s created!"%_t, player.name)
end

function onFactionCreated(index)

end

function onPlayerLogIn(playerIndex)
    local player = Player(playerIndex)
    Server():broadcastChatMessage("Server", ChatMessageType.ServerInfo, "Player %s joined the galaxy"%_t, player.name)

    player.infiniteResources = Server().infiniteResources

    local settings = GameSettings()
    if settings.fullBuildingUnlocked then
        player.maxBuildableMaterial = Material(MaterialType.Avorion)
    end

    if settings.unlimitedProcessingPower or settings.fullBuildingUnlocked then
        player.maxBuildableSockets = 0
    end
end

function onPlayerLogOff(playerIndex)
    local player = Player(playerIndex)
    Server():broadcastChatMessage("Server", ChatMessageType.ServerInfo, "Player %s left the galaxy"%_t, player.name)

end
