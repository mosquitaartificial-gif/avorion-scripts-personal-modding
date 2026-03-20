package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("stringutility")
include ("goods")
local DockAI = include ("entity/ai/dock")

local TradeUT = {}
local self = TradeUT

self.data = {}

function getUpdateInterval()
    return 1
end

function secure()
    return self.data
end

function restore(data)
    self.data = data
end

function TradeUT.onDockingOver(ship, msg)
    self.data.partner = nil
    DockAI.reset()
end

function TradeUT.isInteractableStation(station)

    local docks = DockingPositions(station)
    if not docks or not docks.docksEnabled or docks.numDockingPositions == 0 then
        return
    end

    if station:getValue("minimum_population_fulfilled") == false then -- explicitly check for 'false'
        return
    end

    return true
end

function TradeUT.refreshPartnerStation()
    local station = nil
    if self.data.partner then
        station = Sector():getEntity(self.data.partner.id)
    end

    if not station then return end
    if not TradeUT.isInteractableStation(station) then return end

    return station
end

function TradeUT.updateDocking(timeStep, transaction)
    local station = TradeUT.refreshPartnerStation()

    if not station then
        -- station must have been destroyed / disabled, reset
        self.data.partner = nil
        return
    else
        self.lastPartner = station.id.string
    end

    DockAI.updateDockingUndocking(timeStep, station, 10, transaction, TradeUT.onDockingOver)

    -- if all of this works, we can reset errors
    TradeUT.resetError()
end

function TradeUT.updateErrorHandling(timeStep)
    if not self.currentError then return end

    local maximum = 10 * 60

    self.notificationTimer = (self.notificationTimer or maximum) + timeStep
    self.lastError = self.lastError or ""

    local newError = self.lastError ~= self.currentError.text

    if self.notificationTimer > maximum or newError then
        self.notificationTimer = 0
        self.lastError = self.currentError.text

        if self.currentError.critical or not newError then
            -- notify whenever an error has been there for a while
            -- or when a critical error happens for the first time
            Faction():sendChatMessage(Entity().name, ChatMessageType.Normal, self.currentError.text, unpack(self.currentError.args))
        end
    end

    DockAI.reset()
end

function TradeUT.setSoftError(msg, ...)
    self.currentError = {text = msg, critical = false, args = {...}}
end

function TradeUT.setCriticalError(msg, ...)
    self.currentError = {text = msg, critical = true, args = {...}}
end

function TradeUT.resetError()
    self.currentError = nil
end

function getLastPartner()
    return self.lastPartner
end

function getLastError()
    return self.lastError
end

return TradeUT
