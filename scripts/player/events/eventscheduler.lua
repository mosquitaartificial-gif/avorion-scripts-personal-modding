
package.path = package.path .. ";data/scripts/lib/?.lua"

include ("randomext")
include ("utility")

local events =
{
    -- for best compatibility with previous saves, append to this list. Not appending doesn't break anything though.
    -- if event is allowed to happen in rifts, add the variable inRifts = true to the table
    {schedule = random():getInt(45, 60) * 60,   localEvent = false, script = "events/convoidistresssignal", arguments = {true}, to = 560, centralFactor = 0.5, outerFactor = 1, noMansFactor = 1.2},
    {schedule = random():getInt(120, 150) * 60, localEvent = false, script = "events/fakedistresssignal", arguments = {true}, to = 560, centralFactor = 0.5, outerFactor = 1, noMansFactor = 1.2},
    {schedule = random():getInt(60, 80) * 60,   localEvent = true,  script = "events/sectoreventstarter", arguments = {"pirateattack.lua"}, to = 560, centralFactor = 0.5, outerFactor = 1, noMansFactor = 1.2},
    {schedule = random():getInt(60, 80) * 60,   localEvent = true,  script = "events/sectoreventstarter", arguments = {"traderattackedbypirates.lua"}, to = 560, centralFactor = 0.3, outerFactor = 1.3, noMansFactor = 1},
    {schedule = random():getInt(40, 50) * 60,   localEvent = true,  script = "events/alienattack", arguments = {0}, minimum = 15 * 60, from = 0, to = 500, centralFactor = 0.7, outerFactor = 1, noMansFactor = 1.2},
    {schedule = random():getInt(45, 70) * 60,   localEvent = true,  script = "events/alienattack", arguments = {1}, minimum = 25 * 60, to = 350, centralFactor = 0.7, outerFactor = 0.8, noMansFactor = 1.2},
    {schedule = random():getInt(60, 80) * 60,   localEvent = true,  script = "events/alienattack", arguments = {2}, minimum = 60 * 60, to = 300, centralFactor = 0.7, outerFactor = 0.8, noMansFactor = 1.2},
    {schedule = random():getInt(100, 120) * 60, localEvent = true,  script = "events/alienattack", arguments = {3}, minimum = 120 * 60, to = 250, centralFactor = 0.7, outerFactor = 0.8, noMansFactor = 1.2},
    {schedule = random():getInt(50, 70) * 60,   localEvent = true,  script = "events/spawntravellingmerchant", to = 520},
    {schedule = random():getInt(150, 170) * 60, localEvent = false, script = "data/scripts/player/missions/piratedelivery", to = 520, centralFactor = 0.3, outerFactor = 1.1, noMansFactor = 1.3},
    {schedule = random():getInt(90, 120) * 60,  localEvent = false, script = "data/scripts/player/missions/searchandrescue/searchandrescue.lua", from = 150, to = 520, centralFactor = 0.5, outerFactor = 1, noMansFactor = 1.2},
    {schedule = random():getInt(100, 140) * 60, localEvent = false, script = "events/passiveplayerattackstarter.lua", inRifts = true},
}

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace EventScheduler
EventScheduler = {}
local self = EventScheduler

self.pause = 10 * 60
self.pauseTime = self.pause
self.defaultEventMinimum = 10 * 60
self.partySpeedUp = 1.5 -- if we're not alone, we speed up events by 50%
self.eventInterdictions = {}
self.events = events

if onServer() then

function EventScheduler.initialize()
    for _, event in pairs(self.events) do
        event.time = (event.minimum or self.defaultEventMinimum) + math.random() * event.schedule
    end

    local frequency = 0
    for _, event in pairs(self.events) do
        frequency = frequency + 1 / event.schedule
    end

    -- print ("player events roughly every " .. round((1 / frequency + self.pause) / 60, 2) .. " minutes")

end

function EventScheduler.getUpdateInterval()
    return 5
end

function EventScheduler.updateServer(timeStep)
    self.updateEventInterdictions(timeStep)
    self.updateEventStarting(timeStep)
end

function EventScheduler.updateEventStarting(timeStep)
    local player = Player()

    local x, y = Sector():getCoordinates()
    if x == 0 and y == 0 then return end

    -- only run script for the lowest player index in the sector -> no stacking events
    local players = {Sector():getPlayers()}
    for _, p in pairs(players) do
        -- when there is a player with a lower index, we return
        if p.index < player.index then return end
    end


    -- but, if we're not alone, we speed up events a little
    if #players > 1 then timeStep = timeStep * self.partySpeedUp end
    timeStep = timeStep * GameSettings().eventsFactor

    -- adjust cooldown for events depending on faction area
    local galaxy = Galaxy()
    local controllingFaction = galaxy:getControllingFaction(x, y)
    local area = {}
    if controllingFaction then
        local isCentralFactionArea = galaxy:isCentralFactionArea(x, y, controllingFaction.index)
        if isCentralFactionArea then
            area.central = true
        else
            area.outer = true
        end
    else
        area.noMansLand = true
    end

    if self.pauseTime > 0 then
        self.pauseTime = self.pauseTime - timeStep
        return
    end

    local inRift = galaxy:sectorInRift(x, y)

    -- update times of events
    for _, event in pairs(self.events) do
        if self.getEventDisabled(x, y, event) then goto continue end
        if inRift and not event.inRifts then goto continue end

        local speedUpFactor = 1
        if area.central then
            speedUpFactor = event.centralFactor or 1
        elseif area.outer then
            speedUpFactor = event.outerFactor or 1
        elseif area.noMansLand then
            speedUpFactor = event.noMansFactor or 1
        end

        event.time = event.time - timeStep * speedUpFactor

        if event.time < 0 then
            -- check if the location is OK
            local from = event.from or 0
            local to = event.to or math.huge

            local position = length(vec2(Sector():getCoordinates()))
            if position >= from and position <= to then
                -- start event
                local arguments = event.arguments or {}
                Player():addScriptOnce(event.script, unpack(arguments))
                event.time = event.schedule

                -- print ("starting event " .. event.script)

                self.pauseTime = self.pause

                break;
            end
        end

        ::continue::
    end

end

function EventScheduler.updateEventInterdictions(timeStep)
    -- update event interdictions of sectors where no combat events may be spawned
    for i, interdiction in pairs(self.eventInterdictions) do
        interdiction.time = interdiction.time - timeStep

        if interdiction.time <= 0.0 then
            self.eventInterdictions[i] = nil
        end
    end
end

function EventScheduler.disableLocalEvents(x, y, time)
    self.disableEvents(x, y, time, true)
end

function EventScheduler.disableEvents(x, y, time, localEvents)
    time = time or 15

    -- if there is already an interdiction present for the sector, just update it
    for _, interdiction in pairs(self.eventInterdictions) do
        if interdiction.coordinates.x == x and interdiction.coordinates.y == y
                and interdiction.localEvents == localEvents then

            interdiction.time = math.max(time, interdiction.time)
            return
        end
    end

    -- no interdiction found -> continue
    local i = 0
    while true do
        i = i + 1

        if not self.eventInterdictions[i] then
            break
        end
    end

    self.eventInterdictions[i] = {coordinates = {x=x, y=y}, time = time, localEvents = localEvents}
end

function EventScheduler.getEventDisabled(x, y, event)

    local function matchesFilter(interdiction, event)
        if interdiction.localEvents and interdiction.localEvents ~= event.localEvent then
            return false
        end
        return true
    end

    for _, interdiction in pairs(self.eventInterdictions) do
        if interdiction.coordinates.x == x and interdiction.coordinates.y == y then
            if matchesFilter(interdiction, event) then
                return true
            end
        end
    end

    return false
end



function EventScheduler.secure()
    local times = {}

    for _, event in pairs(self.events) do
        table.insert(times, event.time)
    end

    return times
end

function EventScheduler.restore(times)
    for i = 1, math.min(#times, #self.events) do
        self.events[i].time = times[i]
    end
end


end
