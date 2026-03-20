package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")
include("stringutility")
include("callable")
include("relations")
MissionUT = include("missionutility")

-- API FUNCTIONS SYNOPSIS
-- nextPhase() -- switch to the next phase in index order (ie 1 -> 2, 3 -> 4 and so on)
-- setPhase(index) -- switch to a specific phase
-- fail() -- have the mission fail. Displays "MISSION FAILED" text and terminates the script
-- abandon() -- the player abandons the mission, this should not be called by the script in general. Displays "MISSION ABANDONED" text and Terminates the script; Set abandon = nil if mission should not be abandonable. This will grey out the abandon button in missions tab and show a hint.
-- finish() -- the mission is gracefully cancelled. Displays "MISSION ACCOMPLISHED" text and Terminates the script
-- accomplish() -- have the player accomplish the mission (doesn't automatically reward!). Displays "MISSION ACCOMPLISHED" text and Terminates the script
-- reward() -- give all rewards to the player
-- punish() -- give all punishments to the player
-- addDialogInteraction(text, callback) -- call this during a onStartDialog callback to add an interaction for that dialog. 'callback' can be either a function or a dialog. See function definition below for more info
-- makeDialogServerCallback(functionName, phase, callback) -- call this to create a callback for a dialog, that automatically invokes itself on the server (not client). See function definition below for more info
-- atTargetLocation() -- returns true if the player is currently in the getMissionLocation() sector

-- sync() -- on client: tells the server that a sync should happen. on server: Sends the mission.data table to the client

-- this is the table where everything lives in
mission = {}
mission.tracing = false -- set to true for debug output while developing

mission.data = {} -- this will be secured / restored. it's a collection of all important mission data. Synced between client and server with sync() calls

-- brief description of the mission, text that will be displayed in the Mission Tab, in the list on the left -- leave empty if mission should not be listed there
mission.data.brief = ""

-- flag that will lead to mission being automatically tracked if no other mission is currently tracked
-- this should not be used for optional missions that are auto-accepted for the player (e.g. pirate delivery)
mission.data.autoTrackMission = false

-- long description of the mission.
-- This text should be more verbose than 'title' and 'brief', and should remind players of what they're supposed to do, and why.
-- When a player doesn't know what the mission was about, it should be explained in here.
-- It should also serve as a log for what happened already in longer missions.
-- This text will be displayed in the Mission Tab on the right.
mission.data.description = {}
-- An array of bullet points is also possible:
-- mission.data.description =
-- {
--      "Try out your new R-Mining Lasers.", -- either normal text
--      {text = "Special green line", color = "\\c(0f0)"}, -- or tables, if you need more control, ie. for coloring
--      {text = "Finished Bullet Point", bulletPoint = true, fulfilled = true}, -- the lines can be marked as bullet points and fulfilled
--      {text = "Finished Bullet Point 2", bulletPoint = true, fulfilled = true},
--      {text = "Invisible point", bulletPoint = true, fulfilled = true, visible = false}, -- or they can be hidden
--      {text = "Gather 3500 ores", bulletPoint = true},
--      {text = "Refine your ore at a resource depot", bulletPoint = true, visible = false},
-- }




-- text that will be shown upon completion/abandonment/failing/starting; Example: MISSION ACCOMPLISHED - [Mission Title]
mission.data.title = ""
mission.data.reward = {} -- set to something like {credits = 123, relations = 5012, relationChangeType = RelationChangeType.CombatSupport, paymentMessage = "Earned %1% credits for completing a mission", iron = 150, xanion = 510}
mission.data.punishment = {} -- similar to reward, but is taken away from player. no items possible
mission.data.custom = {} -- custom data for users
mission.data.location = nil -- use something like {x = 2, y = -300}
mission.data.silent = nil -- bool; set to true if mission is not supposed to show "NEW MISSION" and similar messages

mission.data.accomplishMessage = nil -- string; chat message that's sent to the player when he successfully accomplishes the mission
mission.data.finishMessage = nil -- string; chat message that's sent to the player when the mission is finished (gracefully cancelled)
mission.data.abandonMessage = nil -- string; chat message that's sent to the player when he abandons the mission
mission.data.failMessage = nil -- string; chat message that's sent to the player when the mission is failed

mission.data.timeLimit = nil -- set a time limit. when it runs out (ie. mission.internals.timePassed > mission.data.timeLimit) then the mission fails, unless mission.data.fulfilled == true. Then it's accomplished.
mission.data.timeLimitInDescription = nil -- set to true to show the remaining time in description of the mission

-- set to true if the mission should only be doable in player ships, not alliance ships
-- this is a soft check that pauses mission updates. callbacks are still sent.
-- this also changes the mission locations and the mission description for the player,
-- to clarify that they should change into a player ship, not an alliance ship
mission.data.playerShipOnly = nil

mission.getRewardedItems = function() end -- multiple return values: Return all items that you want to reward to the player in reward()

-- Bulletin
local ExampleBulletin = {}


ExampleBulletin.arguments = {{
    -- all of the below fields are optional, and will be copied to mission.data (even if already set)
    timeLimit = 60, -- seconds time limit, after that the mission fails. Use nil for no time limit

    giver = "", -- uuid string for the giver of the mission, results in:
    -- mission.data.giver.id = giver.index
    -- mission.data.giver.factionIndex = giver.factionIndex
    -- mission.data.giver.coordinates = {x = coords.x, y = coords.y}
    -- mission.data.giver.baseTitle = giver.title
    -- mission.data.giver.titleArgs = giver:getTitleArguments()

    location = {x = 10, y = 30}, -- initial target location that will be copied to mission.data.location

    brief = "", -- brief description
    title = "", -- title of the mission

    -- will be copied to mission.data.reward
    reward = {credits = 10000, paymentMessage = "Some chat message", trinium = 5000, relations = 2000},
    -- OR --
    reward = 10000, -- results in {credits = 10000, paymentMessage = ""},

}}


-- INTERNALS
-- these variables are not primarily meant for direct external use in missions
mission.internals = {}

-- is set to true in the "initialize" function when the mission is first initialized.
-- this variable will be reset to nil upon synchronizing and is
-- meant for the client to detect when the mission has just started,
-- so it can display the "NEW MISSION: [Title]" text.
mission.internals.justStarted = nil
mission.internals.phaseIndex = 1
mission.internals.fulfilled = nil -- use this to have a mission be fulfilled successfully after the time limit runs out
mission.internals.timePassed = 0
mission.data.internals = mission.internals


mission.phases = {}
mission.globalPhase = {}
mission.phases[0] = mission.globalPhase
mission.phases[1] = {} -- this phase must always be set
local InitialPhase = {}
mission.currentPhase = InitialPhase


-- Phase
local ExamplePhase = {}
ExamplePhase.updateInterval = 0.5 -- tick every 0.5 seconds during this phase
ExamplePhase.location = {x = 3, y = 1} -- target location to use and display for the phase. Can be used but is discouraged. Use mission.data.location instead.
ExamplePhase.showUpdateOnStart = true -- set this to true if you want to show the "MISSION UPDATED" text on phase change when this phase starts
ExamplePhase.showUpdateOnEnd = true -- set this to true if you want to show the "MISSION UPDATED" text on phase change when this phase ends
ExamplePhase.playerShipOnly = nil -- set to true to enable player ship only for this phase (details see above)

-- set to true if you want to disable all player-bound events in the target sector
-- NOTE: Sector-Related events (some pirate attacks, persecutors, spawning of traders & freighters)
-- will not be influenced and may still happen.
-- If you don't want those events to happen, have the mission take place in another sector,
-- or make it robust enough to handle those situations
ExamplePhase.noPlayerEventsTargetSector = true

-- set to true if you want to disable local player-bound events in the target sector
-- local events are those that change the immediate content of the sector, for example by spawning entities
-- Examples for local events: Xsotan/Pirate Attacks, Travelling Merchants
-- Examples for non-local events: Distress Calls
-- NOTE: Sector-Related events (some pirate attacks, persecutors, spawning of traders & freighters)
-- will not be influenced and may still happen.
-- If you don't want those events to happen, have the mission take place in another sector,
-- or make it robust enough to handle those situations
ExamplePhase.noLocalPlayerEventsTargetSector = true
ExamplePhase.noBossEncountersTargetSector = true -- set to true if you want to avoid boss encounters in target sector for this phase

ExamplePhase.getRewardedItems = function() end -- multiple return values: Return all items that you want to give to the player in reward()

ExamplePhase.update = function(timestep) end -- client + server: called every tick
ExamplePhase.updateClient = function(timestep) end -- client: called every tick
ExamplePhase.updateServer = function(timestep) end -- server: called every tick
ExamplePhase.updateTargetLocation = function(timestep) end -- client + server: called every tick, if at target location
ExamplePhase.updateTargetLocationClient = function(timestep) end -- client: called every tick, if at target location
ExamplePhase.updateTargetLocationServer = function(timestep) end -- server: called every tick, if at target location

-- Fires when player sees the blue jump-away particle effect
-- Spawn entities and do calculations here. don't update description and don't send chat messages here,
-- if they're supposed to be visible in the next sector!
ExamplePhase.onTargetLocationEntered = function(x, y) end -- client + server: called when player enters the target location
ExamplePhase.onSectorEntered = function(x, y) end -- client + server: called when player enters any sector;
ExamplePhase.onTargetLocationLeft = function(x, y) end -- client + server: called when player leaves target location
ExamplePhase.onSectorLeft = function(x, y) end -- client + server: called when player leaves any sector

-- these are callbacks for the server-side of the script,
-- where the server gets a report from the client-side, that it arrived in/left a sector and the scene was initialized on the client
-- NOTE: These have to be defined both on server and client, but will only be called on server!
-- If not defined on the client, the callback won't be reported to the server, to save networking bandwidth.
-- NOTE: These will always be called AFTER onTargetLocationEntered, onSectorEntered, onTargetLocationLeft, onSectorLeft!
-- update descriptions here
ExamplePhase.onSectorLeftReportedByClient = function(x, y) end -- server only: called when client confirms the leaving of a sector
ExamplePhase.onSectorEnteredReportedByClient = function(x, y) end -- server only: called when client confirms entering a sectpr
ExamplePhase.onTargetLocationLeftReportedByClient = function(x, y) end -- server only: called when client confirms entering of target location
ExamplePhase.onTargetLocationEnteredReportedByClient = function(x, y) end -- server only: called when player confirms leaving of target location

-- callbacks only server-side
-- where the server gets a report from client-side, that player fully arrived in the sector (waits on loading screen finish)
-- NOTE: These will always be called AFTER onTargetLocationEntered, onSectorEntered, onTargetLocationLeft, onSectorLeft!
-- update descriptions here
ExamplePhase.onSectorArrivalConfirmed = function(x, y) end -- server only: called when client confirms entering a sector
ExamplePhase.onTargetLocationArrivalConfirmed = function(x, y) end -- server only: called when player confirms entering target sector

ExamplePhase.onSync = function() end -- client only: called when a sync has happened
ExamplePhase.onRestore = function() end -- server only: called after a restore(). Does NOT call onBegin() functions

ExamplePhase.initialize = function(restoring) end -- Always called when the phase starts or is restored (similar to initialize())

ExamplePhase.onBegin = function() end -- called when the phase starts. onBegin* functions are NOT called on restore()
ExamplePhase.onBeginClient = function() end -- client only: called when the phase starts
ExamplePhase.onBeginServer = function() end -- server only: called when the phase starts
ExamplePhase.onEnd = function() end -- called when the phase ends
ExamplePhase.onEndClient = function() end -- client only: called when the phase ends
ExamplePhase.onEndServer = function() end -- server only: called when the phase ends

ExamplePhase.onStartDialog = function(entityId) end -- client only: called when a dialog with another entity is started

ExamplePhase.onAbandon = function() end -- server only: called when the mission is abandoned
ExamplePhase.onFail = function() end -- server only: called when the mission is failed
ExamplePhase.onFinish = function() end -- server only: called when the mission is finished (gracefully cancelled)
ExamplePhase.onAccomplish = function() end -- server only: called when the mission is accomplished
ExamplePhase.onReward = function() end -- server only: called just before rewards are given to the player
ExamplePhase.onPunish = function() end -- server only: called just before punishments are given to the player

-- server only: define / override these functions if you want to add your own checks for failing/finishing/accomplishing missions
-- if any of there are defined and return true during an update, the mission will fail/finish/be accomplished
ExamplePhase.isFailed = function() end
ExamplePhase.isFinished = function() end
ExamplePhase.isAccomplished = function() end

-- more comfortable way to have callbacks that only register/fire when the corresponding phase is active
ExamplePhase.playerCallbacks = {}
local ExamplePlayerCallback = {
    name = "onShipChanged",
    func = function(...)
        -- this is called when the callback fires
    end
}

ExamplePhase.galaxyCallbacks = {}
local ExampleGalaxyCallback = {
    name = "onConvoyEventStarted",
    func = function(...)
        -- this is called when the callback fires
    end
}

-- these callbacks always refer to the player's current ship (be it alliance or not)
ExamplePhase.playerEntityCallbacks = {}
local ExamplePlayerEntityCallback = {
    name = "onDamaged",
    func = function(...)
        -- this is called when the callback fires
    end
}

-- these callbacks always refer to the player's current sector
ExamplePhase.sectorCallbacks = {}
local ExampleSectorCallback = {
    name = "onDamaged",
    func = function(id, ...)
        -- this is called when the callback fires
    end
}


ExamplePhase.timers = {} -- Timers that tick down and call a callback
ExamplePhase.resetTimers = false        -- if true, timers are reset on phase change

local ExampleTimer = {}
ExampleTimer.repeating = false          -- if true, resets after running through and starts anew
ExampleTimer.time = 10                  -- time spent during phase until callback is called
ExampleTimer.callback = function() end  -- callback that will be executed after time passed
ExampleTimer.passed = 0                 -- internal, don't use
ExampleTimer.stopped = false            -- internal, don't use

ExamplePhase.triggers = {} -- Custom triggers that are checked every update step
-- WARNING: The state of triggers on the client cannot be saved when the server is shut down or a player relogs
-- use a server-sided trigger to make sure the trigger(ed) status is saved
local ExampleTrigger = {}
ExampleTrigger.repeating = nil                          -- if true, will be tested and (possibly) triggered every update
ExampleTrigger.condition = function() return false end  -- function where if it returns true, callback will be executed
ExampleTrigger.callback = function() end                -- callback to be executed when condition is true
ExampleTrigger.triggered = nil                          -- internal, don't use


-- Server only
ExamplePhase.distanceChecks = {} -- Distance checks that are checked for every update step
local ExampleDistanceCheck = {}
ExampleDistanceCheck.id = ""                                    -- the entity that is checked for
ExampleDistanceCheck.otherId = ""                               -- the OTHER entity that is checked for, defaults to player's current ship when nil
ExampleDistanceCheck.distance = 10                              -- the reference distance the checks will be done with
ExampleDistanceCheck.onGreater = function(a, b, d) end          -- function that is called once the distance becomes greater than "distance"
ExampleDistanceCheck.onLower = function(a, b, d) end            -- function that is called once the distance becomes lower than "distance"
ExampleDistanceCheck.updateGreater = function(t, a, b, d) end   -- function that is called every time the distance is greater than "distance"
ExampleDistanceCheck.updateLower = function(t, a, b, d) end     -- function that is called every time the distance is lower than "distance"

ExamplePhase.destructionChecks = {} -- Destruction checks for destruction of entities
local ExampleDestructionCheck = {}
ExampleDestructionCheck.id = ""                         -- the entity that should be checked for
ExampleDestructionCheck.callback = function(entity) end -- the callback that will be executed when the entity was destroyed

ExamplePhase.factionVanquishChecks = {} -- check for a faction that was vanquished (first it's there, then it's completely gone).
local ExampleVanquishCheck = {}
ExampleVanquishCheck.factionIndex = 0                       -- the index of the faction that is checked against
ExampleVanquishCheck.callback = function(contributors) end  -- the callback that will be executed when the faction was vanquished.
ExampleVanquishCheck.coordinates = nil                      -- If set to a table like {x = 31, y = 41}, the vanquish check will only be done for the sector at those coordinates. Will be set automatically for the current sector when nil
ExampleVanquishCheck.contributors = {}                      -- internal, don't use. on destruction of a matching entity, players and alliances that participated in destruction of the object are inserted into this

ExamplePhase.entityVanquishChecks = {} -- check for a group of entities that were vanquished (first they're there, then they're completely gone).
local ExampleVanquishCheck = {}
ExampleVanquishCheck.entities = {"", "", ""}                -- indices (uuids as strings) of the entities that are to be checked against
ExampleVanquishCheck.callback = function(contributors) end  -- the callback that will be executed when the group was vanquished.
ExampleVanquishCheck.coordinates = nil                      -- If set to a table like {x = 31, y = 41}, the vanquish check will only be done for the sector at those coordinates. Will be set automatically for the current sector when nil
ExampleVanquishCheck.contributors = {}                      -- internal, don't use. on destruction of a matching entity, players and alliances that participated in destruction of the object are inserted into this
ExampleVanquishCheck.byIdStr = {}                           -- internal, don't use

local DialogTempData = nil

-- the last/current known sector of the client side of this script
local lastSectorClient = nil

local trace = function(txt, ...)
    if mission.tracing then
        local result
        if not mission.data.title or type(mission.data.title) == "string" then
            result = ((mission.data.title or "")%_t) % mission.data
        else
            local fmtargs = {}
            for k, v in pairs(mission.data.title.arguments or {}) do
                fmtargs[k] = GetLocalizedString(v)
            end
            result = GetLocalizedString(mission.data.title.text) % fmtargs
        end

        local name = ""
        local player = Player()
        if valid(player) then name = player.name end

        local prefix = "[Player '" .. name .. "' Mission: ".. tostring(result) .. "|Phase ".. tostring(mission.internals.phaseIndex) .."|";
        if onClient() then prefix = prefix .. "Client" end
        if onServer() then prefix = prefix .. "Server" end
        prefix = prefix .. "] "

        print (prefix .. txt, ...)
    end
end

-- predefined functions
function initialize(data_in, bulletin)

    local player = Player()
    if not player then
        trace("Cancelling mission, no Player in context found (Player() returned nil)")
        terminate()
        return
    end

    local sector = Sector()

    if onClient() then
        player:registerCallback("onSectorChanged", "Mission_onSectorChanged")
        player:registerCallback("onConfirmSectorArrival", "Mission_onConfirmSectorArrival")
        player:registerCallback("onStartDialog", "Mission_onStartDialog")
        player:registerCallback("onPostRenderIndicators", "Mission_onPostRenderIndicators")
        player:registerCallback("onPostRenderHud", "Mission_onPostRenderHud")
        player:registerCallback("onPreRenderHud", "Mission_onPreRenderHud")

        local x, y = sector:getCoordinates()
        lastSectorClient = {x=x, y=y}

        initialSync()

        if mission.globalPhase.initialize then mission.globalPhase.initialize() end
        if mission.globalPhase.onBegin then mission.globalPhase.onBegin() end
        if mission.globalPhase.onBeginClient then mission.globalPhase.onBeginClient() end

        return
    end

    player:registerCallback("onSectorEntered", "Mission_onSectorEntered")
    player:registerCallback("onSectorLeft", "Mission_onSectorLeft")
    player:registerCallback("onSectorArrivalConfirmed", "Mission_onSectorArrivalConfirmed")

    sector:registerCallback("onDestroyed", "Mission_onEntityDestroyed")

    -- don't initialize anything when restoring
    if _restoring then
        trace("restoring mission")
        return
    end

    mission.data.bulletin = bulletin

    data_in = data_in or {}
    mission.data.arguments = data_in

    local x, y = sector:getCoordinates()
    mission.data.start = {x = x, y = y}

    local giver = nil
    if data_in.giver then giver = Entity(data_in.giver) end

    if giver then
        mission.data.giver = {}
        mission.data.giver.id = giver.index
        mission.data.giver.factionIndex = giver.factionIndex
        mission.data.giver.coordinates = {x = x, y = y}
        mission.data.giver.baseTitle = giver.title
        mission.data.giver.titleArgs = giver:getTitleArguments()
    end

    mission.data.timeLeft = data_in.timeLimit or mission.data.timeLimit
    mission.data.location = data_in.location or mission.data.location or {}
    mission.data.brief = data_in.brief or mission.data.brief or ""
    mission.data.title = data_in.title or mission.data.title or ""
    mission.data.autoTrackMission = data_in.autoTrackMission or mission.data.autoTrackMission or false
    mission.data.icon = data_in.icon or mission.data.icon or nil
    mission.data.priority = data_in.priority or mission.data.priority or 0
    mission.data.description = data_in.description or mission.data.description or {}

    if type(data_in.reward) == "table" then
        mission.data.reward = data_in.reward
    else
        mission.data.reward.credits = data_in.reward or mission.data.reward.credits or 0
        mission.data.reward.paymentMessage = mission.data.reward.paymentMessage or ""
    end

    if type(data_in.punishment) == "table" then
        mission.data.punishment = data_in.punishment
    end

    mission.internals.fulfilled = false
    mission.internals.justStarted = true

    if mission.globalPhase.initialize then mission.globalPhase.initialize() end
    if mission.globalPhase.onBegin then mission.globalPhase.onBegin() end
    if mission.globalPhase.onBeginServer then mission.globalPhase.onBeginServer() end

    setPhase(1)
end

function getUpdateInterval()
    return mission.currentPhase.updateInterval or mission.globalPhase.updateInterval or 1
end

function updateClient(timeStep)
    if isInWrongShip() then return end

    if mission.currentPhase.updateClient then mission.currentPhase.updateClient(timeStep) end
    if mission.globalPhase.updateClient then mission.globalPhase.updateClient(timeStep) end

    if atTargetLocation() then
        if mission.currentPhase.updateTargetLocationClient then mission.currentPhase.updateTargetLocationClient(timeStep) end
        if mission.globalPhase.updateTargetLocationClient then mission.globalPhase.updateTargetLocationClient(timeStep) end
    end
end

function updateServer(timeStep)
    if isInWrongShip() then return end

    if mission.currentPhase.updateServer then mission.currentPhase.updateServer(timeStep) end
    if mission.globalPhase.updateServer then mission.globalPhase.updateServer(timeStep) end

    if atTargetLocation() then
        if mission.currentPhase.updateTargetLocationServer then mission.currentPhase.updateTargetLocationServer(timeStep) end
        if mission.globalPhase.updateTargetLocationServer then mission.globalPhase.updateTargetLocationServer(timeStep) end

    end

    updateBossSpawnDeactivation()
    updateEventDeactivation()
    updateDistanceChecks(nil, timeStep)
    updateVanquishChecks()

    if mission.currentPhase.isFinished and mission.currentPhase.isFinished() then finish() end
    if mission.currentPhase.isFailed and mission.currentPhase.isFailed() then fail() end
    if mission.currentPhase.isAccomplished and mission.currentPhase.isAccomplished() then accomplish() end

    if mission.globalPhase.isFinished and mission.globalPhase.isFinished() then finish() end
    if mission.globalPhase.isFailed and mission.globalPhase.isFailed() then fail() end
    if mission.globalPhase.isAccomplished and mission.globalPhase.isAccomplished() then accomplish() end

end

function update(timeStep)
    if isInWrongShip() then return end

    if mission.currentPhase.update then mission.currentPhase.update(timeStep) end
    if mission.globalPhase.update then mission.globalPhase.update(timeStep) end

    if atTargetLocation() then
        if mission.currentPhase.updateTargetLocation then mission.currentPhase.updateTargetLocation(timeStep) end
        if mission.globalPhase.updateTargetLocation then mission.globalPhase.updateTargetLocation(timeStep) end
    end

    mission.internals.timePassed = (mission.internals.timePassed or 0) + timeStep

    updateTimers(timeStep)
    updateTriggers()
end

-- own "API" functions
function setPhase(index)
    local phase = mission.phases[index]
    if not phase then
        trace("Error setting phase %s: phase is nil", index)
        return
    end

    trace("Setting Phase %s", index)

    if mission.currentPhase and mission.currentPhase ~= InitialPhase then
        trace("Previous phase: onEnd()", mission.internals.phaseIndex)

        -- reset timers if necesary
        if mission.currentPhase.resetTimers then resetPhaseTimers(mission.currentPhase) end

        -- finalize current phase
        if mission.currentPhase.onEnd then mission.currentPhase.onEnd() end

        if onServer() then
            if mission.currentPhase.onEndServer then mission.currentPhase.onEndServer() end
            if mission.currentPhase.showUpdateOnEnd then showMissionUpdated() end
        elseif onClient() then
            if mission.currentPhase.onEndClient then mission.currentPhase.onEndClient() end
        end
    end

    mission.internals.phaseIndex = index
    mission.currentPhase = phase

    registerCurrentCallbacks()
    initDistanceChecks()

    trace("Phase %s: onStart()", mission.internals.phaseIndex)

    -- start up new phase
    if mission.currentPhase.initialize then mission.currentPhase.initialize() end
    if mission.currentPhase.onBegin then mission.currentPhase.onBegin() end

    if onServer() then
        if mission.currentPhase.onBeginServer then mission.currentPhase.onBeginServer() end
        if mission.currentPhase.showUpdateOnStart then showMissionUpdated() end

        invokeClientFunction(Player(), "setPhase", index)
        sync()
    elseif onClient() then
        if mission.currentPhase.onBeginClient then mission.currentPhase.onBeginClient() end
    end

end

function nextPhase()
    setPhase(mission.internals.phaseIndex + 1)
end


-- Example Usage 1:
-- local dialog = {text = "Hi there old friend! Thank you for coming!"}
-- mission.phases[1].onStartDialog = function(entity)
--     addDialogInteraction("Hello!", function(entityId)
--         ScriptUI(entityId):interactShowDialog(dialog)
--     end)
-- end

-- -- Example Usage 2:
-- mission.phases[1].onStartDialog = function(entity)
--     addDialogInteraction("Hello!", dialog)
-- end
function addDialogInteraction(text, callback)

    trace("addDialogInteraction(%s, %s)", text, tostring(callback))

    if type(callback) == "table" then
        local dialog = callback
        callback = function(entityId)
            ScriptUI(entityId):interactShowDialog(dialog)
        end
    end

    if not DialogTempData or not valid(DialogTempData.entityId) then
        trace("Error adding dialog interaction")
        return
    end

    local scriptUI = ScriptUI(DialogTempData.entityId)
    if not scriptUI then
        trace("Error adding dialog interaction: No ScriptUI in Entity")
        return
    end

    DialogTempData.interactions = DialogTempData.interactions or {}

    local index = #DialogTempData.interactions
    local name = "_mission_interaction" .. tostring(index)

    -- create a function that will be called from the game when the interaction is selected
    _G[name] = callback

    -- register it
    scriptUI:addDialogOption(text, name)

    -- remember it
    table.insert(DialogTempData.interactions, {functionName = name, callback = callback})
end


-- -- Example Usage
-- -- Must be defined in global scope!
-- -- NOTE: These can be called by cheaters at any time, which is why a phase filter can be added
-- local onDialogEnd = makeDialogServerCallback("onDialogEnd", 4, function() -- passing '4' as second argument lets this only be executed in phase 4
--     -- executed on the server, but only if phase 4 is active
--     print ("onDialogEnd, server: " .. tostring(onServer()))
-- end)
-- -- Use this if you don't want to limit it to any particular phase
-- -- Careful with cheaters though!
-- local onDialogEnd = makeDialogServerCallback("onDialogEnd", function() -- not passing a phase, it can be executed in any phase
--     -- executed on the server
--     print ("onDialogEnd, server: " .. tostring(onServer()))
-- end)
--
-- function createDialog()
--     local dialog = {}
--     dialog.text = "Hi there old friend! Thank you for coming!"%_t
--     dialog.onEnd = onDialogEnd
--     return dialog
-- end
function makeDialogServerCallback(callback, phase, func)

    trace("makeDialogServerCallback(%s, %s, %s)", tostring(callback), tostring(phase), tostring(func))

    if type(phase) == "function" and not func then
        func = phase
        phase = nil
    end

    local proxyName = "_mission_dialog_callback" .. callback
    if onClient() then
        _G[proxyName] = function()
            invokeServerFunction(callback) -- RemoteInvocationsChecker_Ignore
        end
    else
        _G[callback] = function()
            trace("DialogServerCallback: " .. callback)

            if not phase or mission.internals.phaseIndex == phase then
                func()
            else
                trace("Phase filter mismatch, can only be executed in phase %s", phase)
            end
        end

        callable(nil, callback)
    end

    return proxyName
end

function abandon()
    if onClient() then
        invokeServerFunction("abandon")
        return
    end

    terminate()
    trace("abandon()")

    onAbandon()

    if mission.data.abandonMessage and mission.data.abandonMessage ~= "" then
        local player = Player()
        local sender
        if mission.data.giver then
            sender = NamedFormat(mission.data.giver.baseTitle or "", mission.data.giver.titleArgs or {})
        else
            sender = NamedFormat("", {})
        end
        player:sendChatMessage(sender, 0, mission.data.abandonMessage)
    end

    showMissionAbandoned()
end
callable(nil, "abandon")

function fail()
    if onClient() then return end

    trace("fail()")

    onFail()

    if mission.data.failMessage and mission.data.failMessage ~= "" then
        local player = Player()
        local sender
        if mission.data.giver then
            sender = NamedFormat(mission.data.giver.baseTitle or "", mission.data.giver.titleArgs or {})
        else
            sender = NamedFormat("", {})
        end
        player:sendChatMessage(sender, 0, mission.data.failMessage)
    end

    showMissionFailed()
    terminate()
end

function finish()
    if onClient() then return end

    trace("finish()")

    onFinish()

    if mission.data.finishMessage and mission.data.finishMessage ~= "" then
        local player = Player()
        local sender
        if mission.data.giver then
            sender = NamedFormat(mission.data.giver.baseTitle or "", mission.data.giver.titleArgs or {})
        else
            sender = NamedFormat("", {})
        end
        player:sendChatMessage(sender, 0, mission.data.finishMessage)
    end

    terminate()
end

function accomplish()
    if onClient() then return end

    trace("accomplish()")

    onAccomplish()

    if mission.data.accomplishMessage and mission.data.accomplishMessage ~= "" then
        local player = Player()
        local sender
        if mission.data.giver then
            sender = NamedFormat(mission.data.giver.baseTitle or "", mission.data.giver.titleArgs or {})
        else
            sender = NamedFormat("", {})
        end
        player:sendChatMessage(sender, 0, mission.data.accomplishMessage)
    end

    showMissionAccomplished()
    terminate()
end

function reward()
    if onClient() then return end

    trace("reward()")

    onReward()

    local receiver = Player().craftFaction or Player()

    local r = mission.data.reward

    if r.credits
        or r.iron
        or r.titanium
        or r.naonite
        or r.trinium
        or r.xanion
        or r.ogonite
        or r.avorion then

        receiver:receive(r.paymentMessage or "", r.credits or 0, r.iron or 0, r.titanium or 0, r.naonite or 0, r.trinium or 0, r.xanion or 0, r.ogonite or 0, r.avorion or 0)
    end

    if r.relations and mission.data.giver and mission.data.giver.factionIndex then
        local faction = Faction(mission.data.giver.factionIndex)
        if faction and faction.isAIFaction then
            changeRelations(receiver, faction, r.relations, r.relationChangeType, true, false)
        end
    end

    local items = getRewardedItems()
    for _, item in pairs(items) do
        receiver:getInventory():addOrDrop(item, true)
    end
end

function punish()
    if onClient() then return end

    trace("punish()")

    onPunish()

    local player = Player()

    local p = mission.data.punishment

    if p.credits
        or p.iron
        or p.titanium
        or p.naonite
        or p.trinium
        or p.xanion
        or p.ogonite
        or p.avorion then

        player:pay(p.paymentMessage or "",
                math.abs(p.credits or 0),
                math.abs(p.iron or 0),
                math.abs(p.titanium or 0),
                math.abs(p.naonite or 0),
                math.abs(p.trinium or 0),
                math.abs(p.xanion or 0),
                math.abs(p.ogonite or 0),
                math.abs(p.avorion or 0))
    end

    if p.relations and mission.data.giver and mission.data.giver.factionIndex then
        local faction = Faction(mission.data.giver.factionIndex)
        if faction and faction.isAIFaction then
            changeRelations(player, faction, -math.abs(p.relations), nil)
        end
    end
end

function showMissionStarted(text)
    if onServer() then
        invokeClientFunction(Player(), "showMissionStarted", text)
        return
    end

    if mission.data.silent then return end

    local result
    if not mission.data.title or type(mission.data.title) == "string" then
        result = ((mission.data.title or "")%_t) % mission.data
    else
        local fmtargs = {}
        for k, v in pairs(mission.data.title.arguments or {}) do
            fmtargs[k] = GetLocalizedString(v)
        end
        result = GetLocalizedString(mission.data.title.text) % fmtargs
    end

    displayMissionAccomplishedText("NEW MISSION"%_t, (text or result or "")%_t % mission.data)
end

function showMissionAccomplished(text)
    if onServer() then
        invokeClientFunction(Player(), "showMissionAccomplished", text)
        return
    end

    if mission.data.silent then return end

    local result
    if not mission.data.title or type(mission.data.title) == "string" then
        result = ((mission.data.title or "")%_t) % mission.data
    else
        local fmtargs = {}
        for k, v in pairs(mission.data.title.arguments or {}) do
            fmtargs[k] = GetLocalizedString(v)
        end
        result = GetLocalizedString(mission.data.title.text) % fmtargs
    end

    displayMissionAccomplishedText("MISSION ACCOMPLISHED"%_t, (text or result or "")%_t % mission.data)
    playSound("interface/mission-accomplished", SoundType.UI, 1)
end

function showMissionFailed(text)
    if onServer() then
        invokeClientFunction(Player(), "showMissionFailed", text)
        return
    end

    if mission.data.silent then return end

    local result
    if not mission.data.title or type(mission.data.title) == "string" then
        result = ((mission.data.title or "")%_t) % mission.data
    else
        local fmtargs = {}
        for k, v in pairs(mission.data.title.arguments or {}) do
            fmtargs[k] = GetLocalizedString(v)
        end
        result = GetLocalizedString(mission.data.title.text) % fmtargs
    end

    displayMissionAccomplishedText("MISSION FAILED"%_t, (text or result or "")%_t % mission.data)
end

function showMissionAbandoned(text)
    if onServer() then
        invokeClientFunction(Player(), "showMissionAbandoned", text)
        return
    end

    if mission.data.silent then return end

    local result
    if not mission.data.title or type(mission.data.title) == "string" then
        result = ((mission.data.title or "")%_t) % mission.data
    else
        local fmtargs = {}
        for k, v in pairs(mission.data.title.arguments or {}) do
            fmtargs[k] = GetLocalizedString(v)
        end
        result = GetLocalizedString(mission.data.title.text) % fmtargs
    end

    displayMissionAccomplishedText("MISSION ABANDONED"%_t, (text or result or "")%_t % mission.data)
end

function showMissionUpdated(text)
    if onServer() then
        invokeClientFunction(Player(), "showMissionUpdated", text)
        return
    end

    if mission.data.silent then return end

    local result
    if not mission.data.title or type(mission.data.title) == "string" then
        result = ((mission.data.title or "")%_t) % mission.data
    else
        local fmtargs = {}
        for k, v in pairs(mission.data.title.arguments or {}) do
            fmtargs[k] = GetLocalizedString(v)
        end
        result = GetLocalizedString(mission.data.title.text) % fmtargs
    end

    displayMissionAccomplishedText("MISSION UPDATED"%_t, (text or result or "")%_t % mission.data)
end

-- helper functions
function atTargetLocation()
    local tx, ty = internalGetMissionLocation()
    if tx and ty then
        local x, y = Sector():getCoordinates()
        return x == tx and y == ty
    end
end

if onClient() then

function trackMission(index)
    setTrackedMission(index)
end

function initialSync()
    invokeServerFunction("initialSync")
end

function sync(data_in)
    if data_in then
        mission.data = data_in
        mission.internals = mission.data.internals

        onSync(data_in)

        if mission.internals.justStarted then
            -- check if there is no other mission tracked right now
            -- if tracker is empty and the mission has autoTrack enabled we track it
            if onClient() then
                if mission.data.autoTrackMission and not getTrackedMissionScriptIndex() then
                    setTrackThisMission()
                end
            end

            showMissionStarted()
            setPhase(1)
        else
            mission.currentPhase = mission.phases[mission.internals.phaseIndex] or mission.phases[1]

            registerCurrentCallbacks()
            initDistanceChecks()
        end
    else
        invokeServerFunction("sync")
    end
end

else

function initialSync()
    sync()
    mission.internals.justStarted = nil
end
callable(nil, "initialSync")

function sync()
    local player
    if callingPlayer then
        player = Player(callingPlayer)
    else
        player = Player()
    end

    invokeClientFunction(player, "sync", mission.data)
end
callable(nil, "sync")

end

-- trigger / timer updates
function updateTimers(timeStep)

    -- update mission/phase time limit
    if mission.data.timeLimit then
        if mission.internals.timePassed > mission.data.timeLimit then
            trace("mission.data.timeLimit exceeded")

            if mission.internals.fulfilled then
                accomplish()
            else
                fail()
            end
        end
    end

    -- update custom timers
    if mission.currentPhase.timers then updatePhaseTimers(mission.currentPhase, timeStep) end
    if mission.globalPhase.timers then updatePhaseTimers(mission.globalPhase, timeStep) end

end

function updatePhaseTimers(phase, timeStep)
    for key, timer in pairs(phase.timers) do
        if timer.time and not timer.stopped then
            timer.passed = (timer.passed or 0) + timeStep

            if timer.passed > timer.time then
                if timer.callback then
                    trace("Timer with time %d exceeded", timer.time)

                    timer.callback()

                    if timer.repeating then
                        timer.passed = 0
                    else
                        timer.stopped = true
                    end
                end
            end
        end
    end
end

function resetPhaseTimers(phase)
    if not phase then return end

    for key, timer in pairs(phase.timers) do
        timer.stopped = false
        timer.passed = 0
    end
end

function updateTriggers()
    if mission.currentPhase.triggers then updatePhaseTriggers(mission.currentPhase) end
    if mission.globalPhase.triggers then updatePhaseTriggers(mission.globalPhase) end
end

function updatePhaseTriggers(phase)
    for _, trigger in pairs(phase.triggers) do
        if trigger.repeating or not trigger.triggered then
            if trigger.condition and trigger.condition() then
                trace("Trigger callback")

                trigger.callback()
                trigger.triggered = true
            end
        end
    end
end

function updateBossSpawnDeactivation()

    if mission.currentPhase.noBossEncountersTargetSector or mission.globalPhase.noBossEncountersTargetSector then
        local locations = {getMissionLocation()}
        for k, _ in pairs(locations) do
            if type(locations[k]) ~= "number" then
                Player():invokeFunction("player/story/spawnrandombosses.lua", "disableSpawn", locations[k].x, locations[k].y)
            elseif locations[k] and locations[k+1] then
                Player():invokeFunction("player/story/spawnrandombosses.lua", "disableSpawn", locations[k], locations[k+1])
            end
        end
    end

end

function updateEventDeactivation()

    if mission.currentPhase.noPlayerEventsTargetSector or mission.globalPhase.noPlayerEventsTargetSector then
        local locations = {getMissionLocation()}
        for k, _ in pairs(locations) do
            if type(locations[k]) ~= "number" then
                Player():invokeFunction("player/events/eventscheduler.lua", "disableEvents", locations[k].x, locations[k].y)
            elseif locations[k] and locations[k+1] then
                Player():invokeFunction("player/events/eventscheduler.lua", "disableEvents", locations[k], locations[k+1])
            end
        end

    elseif mission.currentPhase.noLocalPlayerEventsTargetSector or mission.globalPhase.noLocalPlayerEventsTargetSector then
        local locations = {getMissionLocation()}
        for k, _ in pairs(locations) do
            if type(locations[k]) ~= "number" then
                Player():invokeFunction("player/events/eventscheduler.lua", "disableLocalEvents", locations[k].x, locations[k].y)
            elseif locations[k] and locations[k+1] then
                Player():invokeFunction("player/events/eventscheduler.lua", "disableLocalEvents", locations[k], locations[k+1])
            end
        end
    end

end

function updateVanquishChecks()
    if mission.currentPhase.factionVanquishChecks then updatePhaseFactionVanquishChecks(mission.currentPhase) end
    if mission.globalPhase.factionVanquishChecks then updatePhaseFactionVanquishChecks(mission.globalPhase) end

    if mission.currentPhase.entityVanquishChecks then updatePhaseEntityVanquishChecks(mission.currentPhase) end
    if mission.globalPhase.entityVanquishChecks then updatePhaseEntityVanquishChecks(mission.globalPhase) end
end

function updatePhaseFactionVanquishChecks(phase)

    local sector = Sector()
    for _, check in pairs(phase.factionVanquishChecks) do
        if check.factionIndex then
            -- vanquish checks are sector bound: if no sector is set yet, use the current one
            local x, y = Sector():getCoordinates()
            if not check.coordinates then check.coordinates = {x = x, y = y} end

            if check.coordinates.x == x and check.coordinates.y == y then
                local amount = sector:getNumEntitiesByFaction(check.factionIndex)

                if check.lastAmount and check.lastAmount > 0 and amount == 0 then
                    trace("Faction %i vanquished at %i:%i", check.factionIndex, x, y)
                    check.callback(check.contributors or {})
                end

                check.lastAmount = amount
            end
        end
    end

end

function updatePhaseEntityVanquishChecks(phase)

    local sector = Sector()
    local x, y = sector:getCoordinates()
    for _, check in pairs(phase.entityVanquishChecks) do
        if not check.entities then goto continue end

        -- if not present, build a table sorted by indices for fast access
        if not check.byIdStr then
            check.byIdStr = {}
            for _, idstr in pairs(check.entities) do
                check.byIdStr[idstr] = true
            end
        end

        -- vanquish checks are sector bound: if no sector is set yet, use the current one
        if not check.coordinates then check.coordinates = {x = x, y = y} end

        -- the entities were last seen in this sector, check if they're still here
        if check.coordinates.x == x and check.coordinates.y == y then
            -- scan sector for the entities
            local found = 0
            for _, id in pairs(check.entities) do
                if sector:exists(id) then
                    found = found + 1
                end
            end

            if check.lastAmount and check.lastAmount > 0 and found == 0 then
                trace("%i entities vanquished at %i:%i", #check.entities, x, y)
                check.callback(check.contributors or {})
            end

            check.lastAmount = found
        end

        ::continue::
    end

end

function initDistanceChecks(phase)
    if mission.currentPhase.distanceChecks then initPhaseDistanceChecks(mission.currentPhase) end
    if mission.globalPhase.distanceChecks then initPhaseDistanceChecks(mission.globalPhase) end
end

function initPhaseDistanceChecks(phase)
    local sector = Sector()
    for _, check in pairs(phase.distanceChecks) do
        check.entity = nil
        check.other = nil
    end
end

function updateDistanceChecks(checks, timeStep)

    -- when called without a "checks" argument, call it for every distance checks variable there is
    if not checks then
        if mission.currentPhase.distanceChecks then
            updateDistanceChecks(mission.currentPhase.distanceChecks, timeStep)
        end
        if mission.globalPhase.distanceChecks then
            updateDistanceChecks(mission.globalPhase.distanceChecks, timeStep)
        end

        return
    end

    local player = Player()
    local playerShip = player.craft

    for _, check in pairs(checks) do

        -- get the entity, if necessary
        if not valid(check.entity) and check.id then
            check.entity = Entity(check.id)

            if not check.entity then
                goto continue
            end
        end

        -- get the other entity, if set
        if check.otherId then
            check.other = Sector():getEntity(check.otherId)

            if not check.other or not valid(check.other) then
                goto continue
            end
        else
            check.other = playerShip
        end

        -- skip distance check when no two entities are there to check
        if not valid(check.entity) or not valid(check.other) then goto continue end

        -- do distance measuring
        local d = check.entity:getNearestDistance(check.other)

        if check.lastDistance then
            -- last distance set -> first time triggers count only when last time result was different
            if check.onGreater and d > check.distance and check.lastDistance < check.distance then
                trace("onGreater distance check triggered: %d, %s, %s", check.distance, check.entity.id.string, check.other.id.string)
                check.onGreater(check.entity, check.other, d)
            end
            if check.onLower and d < check.distance and check.lastDistance > check.distance then
                trace("onLower distance check triggered: %d, %s, %s", check.distance, check.entity.id.string, check.other.id.string)
                check.onLower(check.entity, check.other, d)
            end
        else
            -- no last distance set -> first time triggers count as well
            if check.onGreater and d > check.distance then
                trace("onGreater distance check triggered: %d, %s, %s", check.distance, check.entity.id.string, check.other.id.string)
                check.onGreater(check.entity, check.other, d)
            end
            if check.onLower and d < check.distance then
                trace("onLower distance check triggered: %d, %s, %s", check.distance, check.entity.id.string, check.other.id.string)
                check.onLower(check.entity, check.other, d)
            end
        end

        -- call updates, if set
        if check.updateGreater and d > check.distance then check.updateGreater(timeStep, check.entity, check.other, d) end
        if check.updateLower and d < check.distance then check.updateLower(timeStep, check.entity, check.other, d) end

        check.lastDistance = d

        ::continue::
    end
end


-- callbacks
function registerCurrentCallbacks()
    if mission.currentPhase.sectorCallbacks then registerCurrentSectorCallbacks(mission.currentPhase.sectorCallbacks) end
    if mission.currentPhase.playerCallbacks then registerCurrentPlayerCallbacks(mission.currentPhase.playerCallbacks) end
    if mission.currentPhase.playerEntityCallbacks then registerCurrentPlayerEntityCallbacks(mission.currentPhase.playerEntityCallbacks) end

    if mission.globalPhase.sectorCallbacks then registerCurrentSectorCallbacks(mission.globalPhase.sectorCallbacks, true) end
    if mission.globalPhase.playerCallbacks then registerCurrentPlayerCallbacks(mission.globalPhase.playerCallbacks, true) end
    if mission.globalPhase.playerEntityCallbacks then registerCurrentPlayerEntityCallbacks(mission.globalPhase.playerEntityCallbacks, true) end

    if onServer() then
        if mission.currentPhase.galaxyCallbacks then registerCurrentGalaxyCallbacks(mission.currentPhase.galaxyCallbacks) end
        if mission.globalPhase.galaxyCallbacks then registerCurrentGalaxyCallbacks(mission.globalPhase.galaxyCallbacks, true) end
    end
end

function registerCurrentPlayerCallbacks(callbacks, global)

    local player = Player()
    for _, callback in pairs(callbacks) do
        local functionName = "Mission_pc_" .. callback.name
        local callbackName = callback.name

        if not _G[functionName] then

            -- define a callback function
            _G[functionName] = function(...)
                local phase
                if global then
                    phase = mission.globalPhase
                else
                    phase = mission.currentPhase
                end

                if phase.playerCallbacks then
                    for _, callback in pairs(phase.playerCallbacks) do
                        if callback.name == callbackName then
                            trace("Player callback called: %s", callbackName)
                            callback.func(...)
                        end
                    end
                end
            end
        end

        -- register it
        player:registerCallback(callback.name, functionName)
    end
end

function registerCurrentGalaxyCallbacks(callbacks, global)

    local galaxy = Galaxy()
    for _, callback in pairs(callbacks) do
        local functionName = "Mission_gc_" .. callback.name
        local callbackName = callback.name

        if not _G[functionName] then

            -- define a callback function
            _G[functionName] = function(...)
                local phase
                if global then
                    phase = mission.globalPhase
                else
                    phase = mission.currentPhase
                end

                if phase.galaxyCallbacks then
                    for _, callback in pairs(phase.galaxyCallbacks) do
                        if callback.name == callbackName then
                            trace("Galaxy callback called: %s", callbackName)
                            callback.func(...)
                        end
                    end
                end
            end
        end

        -- register it
        galaxy:registerCallback(callback.name, functionName)
    end
end

function registerCurrentSectorCallbacks(callbacks, global)

    local sector = Sector()
    for _, callback in pairs(callbacks) do
        local functionName = "Mission_sc_" .. callback.name
        local callbackName = callback.name

        if not _G[functionName] then

            -- define a callback function
            _G[functionName] = function(...)
                local phase
                if global then
                    phase = mission.globalPhase
                else
                    phase = mission.currentPhase
                end

                if phase.sectorCallbacks then
                    for _, callback in pairs(phase.sectorCallbacks) do
                        if callback.name == callbackName then
                            trace("Sector callback called: %s", callbackName)
                            callback.func(...)
                        end
                    end
                end
            end
        end

        -- register it
        sector:registerCallback(callback.name, functionName)
    end
end

function registerCurrentPlayerEntityCallbacks(callbacks, global)

    local sector = Sector()
    for _, callback in pairs(callbacks) do
        local functionName = "Mission_pec_" .. callback.name
        local callbackName = callback.name

        if not _G[functionName] then

            -- define a callback function
            _G[functionName] = function(id, ...)
                local phase
                if global then
                    phase = mission.globalPhase
                else
                    phase = mission.currentPhase
                end

                if not phase.playerEntityCallbacks then return end
                if not is_type(id, "Uuid") then return end

                local ship = Player().craft
                if ship and ship.id ~= id then return end

                for _, callback in pairs(phase.playerEntityCallbacks) do
                    if callback.name == callbackName then
                        trace("Player Entity callback called: %s", callbackName)
                        callback.func(id, ...)
                    end
                end
            end
        end

        -- register it
        sector:registerCallback(callback.name, functionName)
    end
end

function Mission_onSectorEntered(player, x, y)

    trace("Sector Entered")

    Sector():registerCallback("onDestroyed", "Mission_onEntityDestroyed")

    registerCurrentCallbacks()
    initDistanceChecks()

    local tx, ty = internalGetMissionLocation()
    if tx and ty then
        if x == tx and y == ty then
            trace("Target Location Entered")

            if mission.currentPhase.onTargetLocationEntered then mission.currentPhase.onTargetLocationEntered(x, y) end
            if mission.globalPhase.onTargetLocationEntered then mission.globalPhase.onTargetLocationEntered(x, y) end
        end
    end

    if mission.currentPhase.onSectorEntered then mission.currentPhase.onSectorEntered(x, y) end
    if mission.globalPhase.onSectorEntered then mission.globalPhase.onSectorEntered(x, y) end

    sync()
end

function Mission_onSectorLeft(player, x, y)

    trace("Sector Left")

    local tx, ty = internalGetMissionLocation()
    if tx and ty then
        if x == tx and y == ty then
            trace("Target Location Left")

            if mission.currentPhase.onTargetLocationLeft then mission.currentPhase.onTargetLocationLeft(x, y) end
            if mission.globalPhase.onTargetLocationLeft then mission.globalPhase.onTargetLocationLeft(x, y) end
        end
    end

    if mission.currentPhase.onSectorLeft then mission.currentPhase.onSectorLeft(x, y) end
    if mission.globalPhase.onSectorLeft then mission.globalPhase.onSectorLeft(x, y) end

end

function Mission_onSectorArrivalConfirmed(player, x, y)
    trace("Sector Arrival Confirmed")

    Sector():registerCallback("onDestroyed", "Mission_onEntityDestroyed")

    registerCurrentCallbacks()
    initDistanceChecks()

    local tx, ty = internalGetMissionLocation()
    if tx and ty then
        if x == tx and y == ty then
            trace("Target Location Arrival Confirmed")

            if mission.currentPhase.onTargetLocationArrivalConfirmed then mission.currentPhase.onTargetLocationArrivalConfirmed(x, y) end
            if mission.globalPhase.onTargetLocationArrivalConfirmed then mission.globalPhase.onTargetLocationArrivalConfirmed(x, y) end
        end
    end

    if mission.currentPhase.onSectorArrivalConfirmed then mission.currentPhase.onSectorArrivalConfirmed(x, y) end
    if mission.globalPhase.onSectorArrivalConfirmed then mission.globalPhase.onSectorArrivalConfirmed(x, y) end
end

function Mission_Phase_onEntityDestroyed(phase, id, lastDamageInflictor)
    if phase.onEntityDestroyed then phase.onEntityDestroyed(id, lastDamageInflictor) end

    if phase.destructionChecks then
        for _, check in pairs(phase.destructionChecks) do
            if check.id == id.string then
                trace("Entity Destruction Callback: %s, %s", tostring(id), tostring(lastDamageInflictor))

                check.callback(id, lastDamageInflictor)
            end
        end
    end

    local entity = nil
    if phase.factionVanquishChecks then
        entity = Entity(id)
        if entity and entity.factionIndex then
            for _, check in pairs(phase.factionVanquishChecks) do

                if check.factionIndex == entity.factionIndex then
                    -- vanquish checks are sector bound: if no sector is set yet, use the current one
                    local x, y = Sector():getCoordinates()
                    if not check.coordinates then check.coordinates = {x = x, y = y} end

                    if check.coordinates.x == x and check.coordinates.y == y then
                        -- remember ships / factions that attacked the destroyed entity
                        check.contributors = check.contributors or {}

                        for _, index in pairs({entity:getDamageContributorPlayerFactions()}) do
                            check.contributors[index] = true
                        end
                    end
                end
            end
        end
    end

    if phase.entityVanquishChecks then
        for _, check in pairs(phase.entityVanquishChecks) do
            if not check.entities then goto continue end

            -- if not present, build a table sorted by indices for fast access
            if not check.byIdStr then
                check.byIdStr = {}
                for _, idstr in pairs(check.entities) do
                    check.byIdStr[idstr] = true
                end
            end

            -- in group ?
            if check.byIdStr[id.string] then
                entity = entity or Entity(id)

                -- remember ships / factions that attacked the destroyed entity
                check.contributors = check.contributors or {}

                for _, index in pairs({entity:getDamageContributorPlayerFactions()}) do
                    check.contributors[index] = true
                end

                -- we could do the callback here already when the last entity was destroyed -
                -- but we want to keep behavior similar to faction vanquish
            end

            ::continue::
        end
    end

end

function Mission_onEntityDestroyed(id, lastDamageInflictor)
    Mission_Phase_onEntityDestroyed(mission.currentPhase, id, lastDamageInflictor)
    Mission_Phase_onEntityDestroyed(mission.globalPhase, id, lastDamageInflictor)
end

function reportSectorEntered(x, y, lx, ly)
    if onClient() then
        trace("Sector Entered Report: %s:%s -> %s:%s", lx, ly, x, y)
        invokeServerFunction("reportSectorEntered", x, y, lx, ly)
        return
    end

    if not callingPlayer then return end

    -- quick sanity check to ensure that the report sent by the client is accurate
    local sx, sy = Sector():getCoordinates()
    if sx ~= x or sy ~= y then return end

    trace("Sector Entered Report: %s:%s -> %s:%s", lx, ly, x, y)


    local tx, ty = internalGetMissionLocation()

    if lx and ly then
        -- check if we left the target sector
        if lx == tx and ly == ty then
            if mission.currentPhase.onTargetLocationLeftReportedByClient then mission.currentPhase.onTargetLocationLeftReportedByClient(lx, ly) end
            if mission.globalPhase.onTargetLocationLeftReportedByClient then mission.globalPhase.onTargetLocationLeftReportedByClient(lx, ly) end
        end

        -- callback for leaving a sector
        if mission.currentPhase.onSectorLeftReportedByClient then mission.currentPhase.onSectorLeftReportedByClient(lx, ly) end
        if mission.globalPhase.onSectorLeftReportedByClient then mission.globalPhase.onSectorLeftReportedByClient(lx, ly) end
    end

    -- check if we entered the target sector
    if x == tx and y == ty then
        if mission.currentPhase.onTargetLocationEnteredReportedByClient then mission.currentPhase.onTargetLocationEnteredReportedByClient(x, y) end
        if mission.globalPhase.onTargetLocationEnteredReportedByClient then mission.globalPhase.onTargetLocationEnteredReportedByClient(x, y) end
    end

    -- callback for entering a sector
    if mission.currentPhase.onSectorEnteredReportedByClient then mission.currentPhase.onSectorEnteredReportedByClient(x, y) end
    if mission.globalPhase.onSectorEnteredReportedByClient then mission.globalPhase.onSectorEnteredReportedByClient(x, y) end
end
callable(nil, "reportSectorEntered")

function Mission_onSectorChanged(x, y) -- client!
    trace("Sector Changed")

    local tx, ty = internalGetMissionLocation()

    if lastSectorClient then
        local x, y = lastSectorClient.x, lastSectorClient.y

        trace("Sector Left")

        if tx and ty then
            if x == tx and y == ty then
                trace("Target Location Left")

                if mission.currentPhase.onTargetLocationLeft then mission.currentPhase.onTargetLocationLeft(x, y) end
                if mission.globalPhase.onTargetLocationLeft then mission.globalPhase.onTargetLocationLeft(x, y) end
            end
        end

        if mission.currentPhase.onSectorLeft then mission.currentPhase.onSectorLeft(x, y) end
        if mission.globalPhase.onSectorLeft then mission.globalPhase.onSectorLeft(x, y) end
    end

    if tx and ty then
        if x == tx and y == ty then
            trace("Target Location Entered")

            if mission.currentPhase.onTargetLocationEntered then mission.currentPhase.onTargetLocationEntered(x, y) end
            if mission.globalPhase.onTargetLocationEntered then mission.globalPhase.onTargetLocationEntered(x, y) end
        end
    end

    if mission.currentPhase.onSectorEntered then mission.currentPhase.onSectorEntered(x, y) end
    if mission.globalPhase.onSectorEntered then mission.globalPhase.onSectorEntered(x, y) end

    -- only send a report for changing a sector if the function is defined in the current context
    if mission.currentPhase.onSectorEnteredReportedByClient
            or mission.currentPhase.onSectorLeftReportedByClient
            or mission.currentPhase.onTargetLocationEnteredReportedByClient
            or mission.currentPhase.onTargetLocationLeftReportedByClient
            or mission.globalPhase.onSectorEnteredReportedByClient
            or mission.globalPhase.onSectorLeftReportedByClient
            or mission.globalPhase.onTargetLocationEnteredReportedByClient
            or mission.globalPhase.onTargetLocationLeftReportedByClient then

        local lx, ly
        if lastSectorClient then
            lx, ly = lastSectorClient.x, lastSectorClient.y
        end

        reportSectorEntered(x, y, lx, ly)
    end

    lastSectorClient = {x=x, y=y}
end

function Mission_onConfirmSectorArrival(x, y) -- client!
    trace("Confirm Sector Arrival")

    if mission.currentPhase.onConfirmSectorArrival then mission.currentPhase.onConfirmSectorArrival(x, y) end
    if mission.globalPhase.onConfirmSectorArrival then mission.globalPhase.onConfirmSectorArrival(x, y) end
end

function Mission_onStartDialog(entityId)

    trace("Starting Dialog with %s", tostring(entityId))

    DialogTempData = {entityId = entityId}

    if mission.currentPhase.onStartDialog then mission.currentPhase.onStartDialog(entityId) end
    if mission.globalPhase.onStartDialog then mission.globalPhase.onStartDialog(entityId) end
end

function Mission_onPreRenderHud()
    local player = Player()
    if player.state == PlayerStateType.BuildCraft or player.state == PlayerStateType.BuildTurret or player.state == PlayerStateType.PhotoMode then return end

    if mission.currentPhase.onPreRenderHud then mission.currentPhase.onPreRenderHud() end
    if mission.globalPhase.onPreRenderHud then mission.globalPhase.onPreRenderHud() end
end

function Mission_onPostRenderHud()
    local player = Player()
    if player.state == PlayerStateType.BuildCraft or player.state == PlayerStateType.BuildTurret or player.state == PlayerStateType.PhotoMode then return end

    if mission.currentPhase.onPostRenderHud then mission.currentPhase.onPostRenderHud() end
    if mission.globalPhase.onPostRenderHud then mission.globalPhase.onPostRenderHud() end

end

function Mission_onPostRenderIndicators()
    local player = Player()
    if player.state == PlayerStateType.BuildCraft or player.state == PlayerStateType.BuildTurret or player.state == PlayerStateType.PhotoMode then return end

    local targets = {getMissionTargets()}
    if #targets > 0 then
        local renderer = UIRenderer()
        for _, target in pairs(targets) do
            if not target then goto continue end

            local object = Entity(target)
            if not object then goto continue end

            renderer:renderEntityTargeter(object, MissionUT.getBasicMissionColor())
            renderer:renderEntityArrow(object, 30, 10, 250, MissionUT.getBasicMissionColor())

            ::continue::
        end

        renderer:display()
    end

    if mission.currentPhase.onPostRenderIndicators then mission.currentPhase.onPostRenderIndicators() end
    if mission.globalPhase.onPostRenderIndicators then mission.globalPhase.onPostRenderIndicators() end

end

function onSync(data)
    trace ("onSync()")
    if mission.currentPhase.onSync then mission.currentPhase.onSync(data) end
    if mission.globalPhase.onSync then mission.globalPhase.onSync(data) end
end

function onRestore(data)
    trace ("onRestore()")
    if mission.currentPhase.onRestore then mission.currentPhase.onRestore(data) end
    if mission.globalPhase.onRestore then mission.globalPhase.onRestore(data) end
end

function onAbandon()
    trace ("onAbandon()")
    if mission.currentPhase.onAbandon then mission.currentPhase.onAbandon() end
    if mission.globalPhase.onAbandon then mission.globalPhase.onAbandon() end
end

function onFail()
    trace ("onFail()")
    if mission.currentPhase.onFail then mission.currentPhase.onFail() end
    if mission.globalPhase.onFail then mission.globalPhase.onFail() end
end

function onFinish()
    trace ("onFinish()")
    if mission.currentPhase.onFinish then mission.currentPhase.onFinish() end
    if mission.globalPhase.onFinish then mission.globalPhase.onFinish() end
end

function onAccomplish()
    trace ("onAccomplish()")
    if mission.currentPhase.onAccomplish then mission.currentPhase.onAccomplish() end
    if mission.globalPhase.onAccomplish then mission.globalPhase.onAccomplish() end
end

function onReward()
    trace ("onReward()")
    if mission.currentPhase.onReward then mission.currentPhase.onReward() end
    if mission.globalPhase.onReward then mission.globalPhase.onReward() end
end

function onPunish()
    trace ("onPunish()")
    if mission.currentPhase.onPunish then mission.currentPhase.onPunish() end
    if mission.globalPhase.onPunish then mission.globalPhase.onPunish() end
end

function isInCorrectShip()
    local playerShipRequired = mission.data.playerShipOnly
    if not playerShipRequired then playerShipRequired = mission.globalPhase.playerShipOnly end
    if not playerShipRequired then playerShipRequired = mission.currentPhase.playerShipOnly end

    -- a player ship is not required -> we can safely say that the player is in the correct ship
    if not playerShipRequired then return true end

    local ship = Player().craft
    if not ship then return false end

    -- player ship is required -> player is in correct ship if it's theirs
    return ship.factionIndex == Player().index
end

function isInWrongShip()
    local playerShipRequired = mission.data.playerShipOnly
    if not playerShipRequired then playerShipRequired = mission.globalPhase.playerShipOnly end
    if not playerShipRequired then playerShipRequired = mission.currentPhase.playerShipOnly end

    -- a player ship is not required -> we can safely say that the player is in the correct ship
    if not playerShipRequired then return false end

    local ship = Player().craft
    if not ship then return false end

    -- player ship is required -> player is in correct ship if it's theirs
    return ship.factionIndex ~= Player().index
end

-- save / restore interface for server
local function securePhaseValues(phases, collection)
    -- this function walks over a collection phases[i][collection] assuming that it's an array,
    -- and makes a shallow copy of all tables inside that collection, but only for all POD values
    local data = {}

    for i, phase in pairs(phases) do
        local array = phase[collection]
        if array then
            data[i] = {}

            for j, tbl in pairs(array) do

                -- create a shallow copy including only PODs
                local copy = {}
                for k, v in pairs(tbl) do
                    local t = type(v)
                    if t == "number" or t == "boolean" or t == "string" then
                        copy[k] = v
                    elseif t == "table" then
                        copy[k] = table.deepcopy(v)
                    elseif t == "userdata" then
                        print("Warning: While securing mission values: mission.phases[" .. i .. "]." .. collection .. "[" .. j .. "]." .. k .. " is a user data: " .. tostring(v.__avoriontype))
                    elseif t ~= "function" then
                        print("Warning: While securing mission values: mission.phases[" .. i .. "]." .. collection .. "[" .. j .. "]." .. k .. " is a " .. t)
                    end
                end

                data[i][j] = copy
            end
        end
    end

    return data
end

local function restorePhaseValues(phases, collection, data)
    if not data then return end

    for i, phase in pairs(phases) do

        local array = phase[collection]
        if array and data[i] then

            for j, to in pairs(array) do
                local from = data[i][j]

                if from and to then
                    for k, v in pairs(from) do
                        to[k] = v
                    end
                end
            end
        end
    end

end

function secure()
    if onClient() then return end

    if mission.onSecure then mission.onSecure() end

    local result = {data = mission.data}

    result.timerData = securePhaseValues(mission.phases, "timers")
    result.distanceData = securePhaseValues(mission.phases, "distanceChecks")
    result.destructionData = securePhaseValues(mission.phases, "destructionChecks")
    result.triggerData = securePhaseValues(mission.phases, "triggers")
    result.factionVanquishData = securePhaseValues(mission.phases, "factionVanquishChecks")
    result.entityVanquishData = securePhaseValues(mission.phases, "entityVanquishChecks")

    return result
end

function restore(data)
    if onClient() then return end

    mission.data = data.data or {}
    mission.data.internals = mission.data.internals or {}
    mission.internals = mission.data.internals

    restorePhaseValues(mission.phases, "timers", data.timerData)
    restorePhaseValues(mission.phases, "distanceChecks", data.distanceData)
    restorePhaseValues(mission.phases, "destructionChecks", data.destructionData)
    restorePhaseValues(mission.phases, "triggers", data.triggerData)
    restorePhaseValues(mission.phases, "factionVanquishChecks", data.factionVanquishData)
    restorePhaseValues(mission.phases, "entityVanquishChecks", data.entityVanquishData)

    mission.currentPhase = mission.phases[mission.internals.phaseIndex]

    if not mission.currentPhase then
        mission.internals.phaseIndex = 1
        mission.currentPhase = mission.phases[1]
    end

    registerCurrentCallbacks()
    initDistanceChecks()

    -- reset timers if necessary
    if mission.globalPhase.resetTimers then resetPhaseTimers(mission.globalPhase) end
    if mission.currentPhase.resetTimers then resetPhaseTimers(mission.currentPhase) end

    if mission.globalPhase.initialize then mission.globalPhase.initialize(true) end
    if mission.currentPhase.initialize then mission.currentPhase.initialize(true) end

    onRestore(data)
end

function getRewardedItems()
--    trace ("getRewardedItems()")

    local result = {}
    if mission.currentPhase.getRewardedItems then
        local items = {mission.currentPhase.getRewardedItems()}
        for _, i in pairs(items) do table.insert(result, i) end
    end

    if mission.globalPhase.getRewardedItems then
        local items = {mission.globalPhase.getRewardedItems()}
        for _, i in pairs(items) do table.insert(result, i) end
    end

    if mission.getRewardedItems then
        local items = {mission.getRewardedItems()}
        for _, i in pairs(items) do table.insert(result, i) end
    end

    return result
end

-- interface for client
function getMissionBrief()
--    trace ("getMissionBrief()")

    if not mission.data.brief or type(mission.data.brief) == "string" then
        return ((mission.data.brief or "")%_t) % mission.data
    end

    local result

    local fmtargs = {}
    for k, v in pairs(mission.data.brief.arguments or {}) do
        fmtargs[k] = GetLocalizedString(v)
    end
    result = GetLocalizedString(mission.data.brief.text) % fmtargs

    return ((result or "")%_t) % mission.data
end

-- interface for client
function getMissionIcon()
--    trace ("getMissionIcon()")

    return mission.data.icon or ""
end

function getMissionPriority()
--    trace ("getMissionPriority()")

    return mission.data.priority or 0
end

function getAutoTrackMission()
    return mission.data.autoTrackMission or false
end

function getMissionDescription()
--    trace ("getMissionDescription()")

    local description = ""
    if type(mission.data.description) == "table" then

        -- lua can resort tables independent of key values
        -- we need to resort here to make sure we have correct order
        local keys = {}
        for k, _ in pairs(mission.data.description) do
            table.insert(keys, k)
        end

        table.sort(keys)

        local sortedDescriptions = {}
        for _, k in pairs(keys) do
            table.insert(sortedDescriptions, mission.data.description[k])
        end

        local numFulfilled = 0
        local visibleDescriptions = {}
        for _, desc in pairs(sortedDescriptions) do
            if type(desc) == "table" then
                if desc.visible ~= false then
                    table.insert(visibleDescriptions, desc)

                    if desc.fulfilled then
                        numFulfilled = numFulfilled + 1
                    end
                end
            else
                table.insert(visibleDescriptions, {text = tostring(desc)})
            end
        end

        if numFulfilled >= 4 then
            local temp = {}

            local numFulfilled = 0
            for i = #visibleDescriptions, 1, -1 do
                local description = visibleDescriptions[i]
                if description.visible == false then goto continue end

                if description.fulfilled then
                    numFulfilled = numFulfilled + 1
                    if numFulfilled >= 4 then goto continue end
                end

                table.insert(temp, description)

                ::continue::
            end

            visibleDescriptions = {}
            for i = #temp, 1, -1 do
                table.insert(visibleDescriptions, temp[i])
            end
        end

        description = string.join(visibleDescriptions, "\n", function(i, str)
            local color = str.color
            if i > 1 and not color then color = "\\c(ddd)" end

            local result

            local fmtargs = {}
            for k, v in pairs(str.arguments or {}) do
                fmtargs[k] = GetLocalizedString(v)
            end
            result = GetLocalizedString(str.text) % fmtargs

            if str.fulfilled then
                color = "\\c(444)"
                result = "(done)"%_t .. " " .. result
            end

            if str.bulletPoint then
                result = "- " .. result
            end

            if i > 1 then
                result = "\n" .. color .. result
            end

            result = result .. "\\c()"
            return result
        end)
    elseif type(mission.data.description) == "string" then
        description = mission.data.description % _t
    end

    if isInWrongShip() then
        description = "\\c(f00)" .. "To play this mission, you must be in one of your own ships, not an alliance ship!"%_t .. "\\c()\n\n" .. description
    end

    if mission.data.timeLimitInDescription then
        mission.data.timeLeft = mission.data.timeLimit - (mission.internals.timePassed or 0)
        local timeLeftStr = plural_t("1 minute", "${i} minutes", math.floor(mission.data.timeLeft / 60))

        if mission.data.timeLeft < 60 then
            timeLeftStr = "< 1 minute"%_t
        end

        return (description%_t  % mission.data .. "\n\n" .. "Time Left: "%_t .. timeLeftStr)
    end

    return description % mission.data
end

function internalGetMissionLocation()
    if mission.currentPhase.location then
        return mission.currentPhase.location.x, mission.currentPhase.location.y
    end

    if mission.globalPhase.location then
        return mission.globalPhase.location.x, mission.globalPhase.location.y
    end

    if mission.data.location then
        return mission.data.location.x, mission.data.location.y
    end
end

function getMissionLocation()
--    trace ("getMissionLocation()")

    if isInWrongShip() then return end

    return internalGetMissionLocation()
end

function internalGetReservedMissionLocation()
    if mission.data.custom.location then
        return mission.data.custom.location.x, mission.data.custom.location.y
    end
end

function getReservedMissionLocation()
--    trace ("getReservedMissionLocation()")

    return internalGetReservedMissionLocation()
end

function getMissionTargets()
--    trace ("getMissionTargets()")

    if isInWrongShip() then return end

    if mission.currentPhase.targets then return unpack(mission.currentPhase.targets) end
    if mission.globalPhase.targets then return unpack(mission.globalPhase.targets) end
    if mission.data.targets then return unpack(mission.data.targets) end
end

-- interface for bulletin board
function getBulletin(entity)
    trace ("getBulletin()")

    if mission.makeBulletin then
        return mission.makeBulletin(entity)
    end
end

return mission
