package.path = package.path .. ";data/scripts/lib/?.lua"

include("callable")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace TransportMode
TransportMode = {}
TransportMode.data = {}
local self = TransportMode

self.restorationTime = 10 * 60

local data = self.data
data.enabled = nil
data.restoreCountdown = 0

function TransportMode.getUpdateInterval()
    return 1
end

function TransportMode.initialize()
    if onClient() then
        self.sync()
    end

    if onServer() then
        self.refreshDockability()
    end
end

function TransportMode.interactionPossible(playerIndex, option)
    local entity = Entity()

    if not checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations) then return false end

    if option == 0 then -- should transport mode option be visible?
        -- if transport mode is enabled, we can't go into transport mode
        return not data.enabled
    end

    if option == 1 then -- should station mode option be visible?
        local transportEnabled = data.enabled

        -- if transport mode is enabled, return true, unless we're already setting up
        if transportEnabled then
            if data.restoreCountdown > 0 then

                local readyInStr = ""
                if data.restoreCountdown > 60 then
                    readyInStr = "Station will be ready in ${minutes} minutes."%_t % {minutes = math.ceil(data.restoreCountdown / 60)}
                elseif data.restoreCountdown > 1 then
                    readyInStr = "Station will be ready in ${seconds} seconds."%_t % {seconds = math.ceil(data.restoreCountdown)}
                end

                return false, "Currently engaging 'Station' mode. Please wait."%_t .. " " .. readyInStr
            end

            return true
        end

        return false
    end

    return true
end

function TransportMode.isStationFunctional()
    return not data.enabled and data.restoreCountdown == 0
end

function TransportMode.initUI()
    ScriptUI():registerInteraction("Engage Transport Mode"%_t, "onTransportModeSelected");
    ScriptUI():registerInteraction("Engage Station Mode"%_t, "onStationModeSelected");
end

function TransportMode.onTransportModeSelected()
    local dialog = {}
    dialog.text = "'Transport' mode: Station can be docked by for transport, but not interacted with. Reengaging 'Station' mode will take ${minutes} minutes. Proceed?"%_t % {minutes = math.ceil(self.restorationTime / 60)}
    dialog.answers = {
        {answer = "Yes"%_t, onSelect = "onTransportModePressed"},
        {answer = "No"%_t},
    }
    ScriptUI():showDialog(dialog)
end

function TransportMode.onStationModeSelected()
    local dialog = {}
    dialog.text = "Engaging 'Station' mode will take ${minutes} minutes. Proceed?"%_t % {minutes = math.ceil(self.restorationTime / 60)}
    dialog.answers = {
        {answer = "Yes"%_t, onSelect = "onStationModePressed"},
        {answer = "No"%_t},
    }
    ScriptUI():showDialog(dialog)
end

function TransportMode.onTransportModePressed()
    if onClient() then
        invokeServerFunction("onTransportModePressed")
        return
    end

    local owner, station, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations)
    if not owner then return end

    data.restoreCountdown = 0
    data.enabled = true

    self.refreshDockability()
    self.sync()

    player:sendChatMessage(station, ChatMessageType.Chatter, "Transport Mode engaged."%_T)

    station:sendCallback("onTransportModeStarted", station.id)
end
callable(TransportMode, "onTransportModePressed")

function TransportMode.onStationModePressed()
    if onClient() then
        invokeServerFunction("onStationModePressed")
        return
    end

    local owner, station, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations)
    if not owner then return end

    data.restoreCountdown = self.restorationTime

    self.refreshDockability()
    self.sync()

    player:sendChatMessage(station, ChatMessageType.Chatter, "Reengaging station mode. Please wait."%_T)
end
callable(TransportMode, "onStationModePressed")

function TransportMode.renderUIIndicator(px, py, size)

    if data.restoreCountdown == 0 then return end
    if not checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations) then return end

    local x = px - size / 2;
    local y = py + size / 2 + 7;

    -- outer rect
    local sx = size + 2
    local sy = 4

    drawRect(Rect(x, y, sx + x, sy + y), ColorRGB(0, 0, 0));

    -- inner rect
    sx = sx - 2
    sy = sy - 2

    sx = sx * (1 - data.restoreCountdown / (self.restorationTime + 1))

    drawRect(Rect(x + 1, y + 1, sx + x + 1, sy + y + 1), ColorRGB(1.0, 0.4, 0.1));
end

function TransportMode.update(timeStep)
    if data.restoreCountdown > 0 then
        data.restoreCountdown = math.min(data.restoreCountdown, self.restorationTime)
        data.restoreCountdown = math.max(0, data.restoreCountdown - timeStep)

        if onServer() then
            if data.restoreCountdown == 0 then
                data.enabled = false
                self.refreshDockability()
                self.sync()

                local station = Entity()
                station:sendCallback("onTransportModeEnded", station.id)

                local sector = Sector()
                sector:broadcastChatMessage(station, ChatMessageType.Chatter, "Station Mode engaged. All systems fully functional again."%_T)

                sector:addScriptOnce("sector/traders.lua")
                sector:addScriptOnce("sector/passingships.lua")

                -- update sector contents, check if the sector's controlling faction changed
                sector:invokeFunction("data/scripts/sector/background/sectorcontentsupdater.lua", "updateServer")
            end
        end
    end
end

function TransportMode.refreshDockability()
    local entity = Entity()

    -- prevent this station from auto-undocking from other stations when "dockable" is set to false
    DockingParent():addAutoUndockException(EntityType.Station)

    if data.enabled and data.restoreCountdown == 0 then
        entity.dockable = true
    else
        entity.dockable = false
    end

    if data.enabled or data.restoreCountdown > 0 then
        DockingPositions().docksEnabled = false
    else
        DockingPositions().docksEnabled = true
    end
end

function TransportMode.sync(values)
    if onClient() then
        if values then
            self.data = values
            data = values
        else
            invokeServerFunction("sync")
        end
    else
        if callingPlayer then
            invokeClientFunction(Player(callingPlayer), "sync", data)
        else
            broadcastInvokeClientFunction("sync", data)
        end
    end
end
callable(TransportMode, "sync")

function TransportMode.secure()
    return data
end

function TransportMode.restore(values)
    self.data = values
    data = self.data

    self.refreshDockability()
end
