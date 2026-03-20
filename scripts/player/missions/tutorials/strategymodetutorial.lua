package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("structuredmission")
include ("stringutility")
include ("randomext")

local MissionUT = include("missionutility")
local AdventurerGuide = include("story/adventurerguide")
local ShipGenerator = include("shipgenerator")

-- mission.tracing = true

-- data
abandon = nil
mission.data.autoTrackMission = true
mission.data.playerShipOnly = true
mission.data.title = "Ships, Strategies & Captains"%_T
mission.data.brief = "Ships, Strategies & Captains"%_T
mission.data.icon = "data/textures/icons/graduate-cap.png"
mission.data.priority = 5

mission.data.targets = {}
mission.data.location = {}
mission.data.description = {}
mission.data.description[1] = {text = "\\c(f00)To play this mission, you are not allowed to fly the Lady yourself. Change back into your own ship!\\c()"%_T, visible = false}
mission.data.description[2] = {text = "${name} the Adventurer has a surprise for you."%_T} -- arguments call function and can't be filled in right away
mission.data.description[3] = {text = "Read the mail from the Adventurer"%_T, bulletPoint = true, visible = true}
mission.data.description[4] = {text = "Meet the Adventurer in sector (${xCoord}:${yCoord})"%_T, bulletPoint = true, visible = false}
mission.data.description[5] = {text = "Open Strategy Mode by using the Strategy Mode button in the top right or press [${key}]"%_T, bulletPoint = true, visible = false}
mission.data.description[6] = {text = "Using Strategy Mode, order the Lady Adventurous to escort you"%_T, bulletPoint = true, visible = false}

mission.data.custom.keyBind = nil
mission.data.custom.ladyGivenToPlayer = false

-- disable event spawns for less confusion
mission.globalPhase.noPlayerEventsTargetSector = true
mission.globalPhase.noBossEncountersTargetSector = true
mission.globalPhase.noLocalPlayerEventsTargetSector = true
mission.globalPhase.updateServer = function()
    local player = Player()

    -- don't try to look for ship data base entry if it can't exist yet
    if not mission.data.custom.shipName then return end

    -- if lady doesn't belong to the player yet this will return nil
    local entry = ShipDatabaseEntry(player.index, mission.data.custom.shipName)
    if not entry then
        if mission.internals.phaseIndex >= 4 and mission.internals.phaseIndex < 8 then
            fail()
            return
        end

        return
    end

    -- check for our script value in case player made his own lady
    local values = entry:getScriptValues()
    if not values["strategy_command_lady"] then return end

    -- lady is owned by player => check she is still where we expect her to be
    local x, y = entry:getCoordinates()
    if not (x == mission.data.location.x and y == mission.data.location.y) then
        fail()
    end

    -- check lady isn't destroyed
    if player:getShipDestroyed(mission.data.custom.shipName) then
        fail()
    end
end
mission.globalPhase.updateInterval = 2
mission.globalPhase.playerCallbacks =
{
    {
        name = "onShipChanged",
        func = function(playerIndex, craftId)
            local lady = Sector():getEntitiesByScriptValue("strategy_command_lady")
            if not lady then return end

            if craftId == lady.index then
                mission.data.description[1].visible = true
            else
                mission.data.description[1].visible = false
            end
        end
    },
    {
        name = "onShipNameUpdated",
        func = function(name, newName)
            if mission.data.custom.shipName == name then
                mission.data.custom.shipName = newName
            end
        end
    }
}
mission.globalPhase.onTargetLocationLeft = function(playerIndex, x, y)
    local lady = Sector():getEntitiesByScriptValue("strategy_command_lady")
    if not lady then return end

    -- fail if player abducts lady
    local player = Player()
    if playerIndex == player.index and player.craftIndex == lady.index then
        fail()
    end
end
mission.globalPhase.onFail = function()
    -- remove adventurer
    local entity = Sector():getEntitiesByScript("story/missionadventurer.lua")
    if entity then
        invokeClientFunction(Player(), "stopHailClient")
        entity:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(8, 12))
    end

    -- remove lady if it doesn't belong to the player yet
    local lady = Sector():getEntitiesByScriptValue("strategy_command_lady")
    if lady then
        lady:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(1, 5))

        -- remove lady's script value
        lady:setValue("strategy_command_lady", nil)
    end

    -- set no repeat value
    Player():setValue("tutorial_strategycommands_accomplished", true)
end

-- phase 1: Calculate target sector and send mail
mission.phases[1] = {}
mission.phases[1].onBeginServer = function()
    mission.data.description[2].arguments = {name = MissionUT.getAdventurerName()}

    -- find meet-up sector
    mission.data.custom.location = findSector(5, 10)

    local player = Player()
    local mail = createStartMail()
    player:addMail(mail)
end
mission.phases[1].playerCallbacks =
{
    {
        name = "onMailRead",
        func = function(playerIndex, mailIndex, mailId)
            if mailId == "Tutorial_StrategyCommandsStart" then
                -- mission location now visible
                mission.data.location = mission.data.custom.location
                mission.data.description[3].fulfilled = true
                mission.data.description[4].arguments = {xCoord = mission.data.location.x, yCoord = mission.data.location.y}
                mission.data.description[4].visible = true

                nextPhase()
            end
        end
    }
}

-- phase 2: wait for player to reach sector
mission.phases[2] = {}
mission.phases[2].onTargetLocationEntered = function()
    if onClient() then return end

    -- spawn adventurer and lady, at first she is of the same faction as the adventurer
    createAdventurer()
    createLady()
end
mission.phases[2].onTargetLocationArrivalConfirmed = function()
    mission.data.description[4].fulfilled = true
    nextPhase()
end

-- phase 3: talk - explain what is about to happen
local startedTalkPhase3 = false
mission.phases[3] = {}
mission.phases[3].onBeginClient = function()
    startedTalkPhase3 = false
    mission.data.custom.keyBind = tostring(GameInput():getKeyName(ControlAction.ToggleStrategyMode))
    syncKeyBindToServer(mission.data.custom.keyBind)
end
mission.phases[3].updateClient = function()
    if not startedTalkPhase3 then
        onStartExplainMissionDialog()
        startedTalkPhase3 = true
    end
end
mission.phases[3].onEntityDestroyed = function(id)
    if onServer() then
        local entity = Entity(id)
        if entity.name == mission.data.custom.shipName and entity:getValue("strategy_command_lady") then
            fail()
        end
    end
end
mission.phases[3].onTargetLocationLeft = function()
    resetToPhase(2)
end
mission.phases[3].onRestore = function()
    resetToPhase(2, true)
end

-- phase 4: wait for player to open strategy mode
local usedStrategy = false
mission.phases[4] = {}
mission.phases[4].onBegin = function()
    usedStrategy = false

    local lady = Sector():getEntitiesByScriptValue("strategy_command_lady")
    if not lady then
        if onServer() then resetToPhase(2, true) return end
        return
    end

    -- player now owns lady
    lady.factionIndex = Player().index
    lady:removeScript("entity/deleteonplayersleft.lua")
    mission.data.custom.ladyGivenToPlayer = true -- remember not to respawn lady
    table.insert(mission.data.targets, lady.id.string)

    if onClient() then
        -- player just read dialog with adventurer => we assume he wants to do this now and track this mission
        setTrackThisMission()
    end
end
mission.phases[4].updateClient = function()
    if not usedStrategy and Player().state == PlayerStateType.Strategy then
        onStrategyModeOpened()
        usedStrategy = true
    end
end
mission.phases[4].onTargetLocationLeft = function()
    resetToPhase(2)
end
mission.phases[4].onRestore = function()
    resetToPhase(2, true)
end

-- phase 5: player now should read the encyclopedia entry
local encyclopediaClosed = false
mission.phases[5] = {}
mission.phases[5].updateClient = function()
    if not encyclopediaClosed and not Hud().playerWindowVisible then
        onPlayerWindowClosed()
        encyclopediaClosed = true
    end
end
mission.phases[5].onTargetLocationLeft = function()
    resetToPhase(2)
end
mission.phases[5].onRestore = function()
    resetToPhase(2, true)
end

-- phase 6: have adventurer give player hint on what we want them to do
mission.phases[6] = {}
mission.phases[6].onBeginClient = function()
    orderButtonHintShown = false

    -- mark lady
    local lady = Sector():getEntitiesByScriptValue("strategy_command_lady")
    Hud():displayHint("Select the Lady by clicking on her or by dragging a box around her."%_t, lady)
end
local orderButtonHintShown = false
mission.phases[6].update = function()
    local lady = Sector():getEntitiesByScriptValue("strategy_command_lady")

    -- once lady is selected we switch hints
    if onClient() then
        local player = Player()
        local selection = player.selectedObject
        if selection == lady.id then
            orderButtonHintShown = true

            local hud = Hud()
            hud:displayHint("Now right-click on your own ship to issue the escort order."%_t, player.craft)
        end
    end

    -- player did what we wanted them to do => go to next phase
    if onServer() then
        if lady and ShipAI(lady.id).state == AIState.Escort then
            nextPhase()
        end
    end
end
mission.phases[6].onEnd = function()
    if onServer() then return end
    Hud():displayHint("")
end
mission.phases[6].onStartDialog = function(entityId)
    local adventurer = Sector():getEntitiesByScript("story/missionadventurer.lua")
    if adventurer.id == entityId then
        ScriptUI(entityId):addDialogOption("What do I do now?"%_t, "showHelpDialog")
    end
end
mission.phases[6].onTargetLocationLeft = function()
    resetToPhase(2)
end
mission.phases[6].onRestore = function()
    resetToPhase(2, true)
end

-- phase 7: wait for lady to come close enough
mission.phases[7] = {}
mission.phases[7].onStartDialog = function(entityId)
    local adventurer = Sector():getEntitiesByScript("story/missionadventurer.lua")
    if adventurer.id == entityId then
        ScriptUI(entityId):addDialogOption("What do I do now?"%_t, "showHelpDialog")
    end
end
mission.phases[7].updateServer = function()
    local lady = Sector():getEntitiesByScriptValue("strategy_command_lady")
    if lady and ShipAI(lady.id).state == AIState.Escort then
        mission.phases[7].distanceChecks[1].id = lady.id
    end
end
mission.phases[7].distanceChecks = {}
mission.phases[7].distanceChecks[1] =
{
    distance = 200,
    updateLower = function() onShipCloseEnough() end
}
mission.phases[7].onTargetLocationLeft = function()
    resetToPhase(2)
end
mission.phases[7].onRestore = function()
    resetToPhase(2, true)
end

-- phase 8: end talk - mission accomplishes on end of the dialog
local startedTalkPhase8 = false
mission.phases[8] = {}
mission.phases[8].onBeginClient = function()
    startedTalkPhase3 = false
end
mission.phases[8].updateClient = function()
    if not startedTalkPhase8 then
        onEndDialog()
        startedTalkPhase8 = true
    end
end
mission.phases[8].onTargetLocationLeft = function()
    resetToPhase(2)
end
mission.phases[8].onRestore = function()
    resetToPhase(2, true)
end

-- helper functions
function findSector(minDist, maxDist)
    local x, y = Sector():getCoordinates()
    local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)

    local newX, newY = MissionUT.getSector(x, y, minDist, maxDist, false, false, false, false, inside)
    return {x = newX, y = newY}
end

function resetToPhase(index, newLocation)
    if onClient() then return end

    if newLocation then
        -- if player doesn't own lady we can simply calculate a new sector
        -- if he does own lady, we try to find her for them
        local oldCoords = mission.data.location
        local entry = ShipDatabaseEntry(Player().index, mission.data.custom.shipName)
        if entry then
            -- lady is owned by player => check location
            local x, y = entry:getCoordinates()
            mission.data.location = {x = x, y = y}
            mission.data.custom.location = mission.data.location

            if mission.data.location.x == oldCoords.x and mission.data.location.y == oldCoords.y then
                -- we're still in the same sector => respawn adventurer
                createAdventurer()
                newLocation = false
            end
        else
            mission.data.location = findSector(3, 8)
            mission.data.custom.location = mission.data.location
        end
    end

    if index == 2 then
        for i = 3, #mission.data.description do
            mission.data.description[i].visible = false
            mission.data.description[i].fulfilled = false
        end

        mission.data.description[4].arguments = {xCoord = mission.data.location.x, yCoord = mission.data.location.y}
        mission.data.description[4].visible = true

        if not newLocation then
            mission.data.description[4].fulfilled = true

        end

        if not newLocation and MissionUT.playerInTargetSector(player, mission.data.location) then
            setPhase(3)
            return
        else
            setPhase(2)
            return
        end
    end

    setPhase(index)
end

function createAdventurer()
    local adventShip = AdventurerGuide.spawnOrFindMissionAdventurer(Player())
    if not adventShip then resetToPhase(2, true) return end

    adventShip:invokeFunction("story/missionadventurer.lua", "setInteractingScript", "player/missions/tutorials/strategymodetutorial.lua")

    adventShip.invincible = true
    adventShip.dockable = false
    MissionUT.bindToMission(adventShip)
    adventShip:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
end

function createLady()
    local sector = Sector()
    if sector:getEntitiesByScriptValue("strategy_command_lady") then return end
    if mission.data.custom.ladyGivenToPlayer then return end

    local adventShip = sector:getEntitiesByScript("story/missionadventurer.lua")
    if not adventShip then resetToPhase(2, true) return end

    local faction = Faction(adventShip.factionIndex)
    local volume = Balancing_GetSectorShipVolume(450, 0)

    -- spawn lady close to adventurer
    local adventurerPosition = adventShip.position
    local translation = random():getDirection() * 100
    local position = MatrixLookUpPosition(adventurerPosition.look, adventurerPosition.up, adventurerPosition.pos + translation)

    local ship = ShipGenerator.createShip(faction, position, volume)
    mission.data.custom.shipId = ship.id.string
    ship.title = "Lady Adventurous"%_T
    ship.name = "Lady"%_T
    ship:setValue("strategy_command_lady", true)
    mission.data.custom.shipName = ship.name

    -- add deletion script in case something goes wrong, and we never give the ship to player => if given to player remove it!
    ship:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
end

function onStrategyModeOpened()
    if onClient() then invokeServerFunction("onStrategyModeOpened") end

    if mission.internals.phaseIndex == 4 then
        mission.data.description[5].fulfilled = true
        mission.data.description[6].visible = true
        nextPhase()
    end
end
callable(nil, "onStrategyModeOpened")

function onPlayerWindowClosed()
    if onClient() then invokeServerFunction("onPlayerWindowClosed") end

    if mission.internals.phaseIndex == 5 then
        nextPhase()
    end
end
callable(nil, "onPlayerWindowClosed")

function onShipCloseEnough()
    -- check player not flying lady
    local lady = Sector():getEntitiesByScriptValue("strategy_command_lady")
    if Player().craftIndex == lady.id then return end

    nextPhase()
end

function syncKeyBindToServer(keyBind)
    if onClient() then
        invokeServerFunction("syncKeyBindToServer", keyBind)
        return
    end

    mission.data.custom.keyBind = keyBind
end
callable(nil, "syncKeyBindToServer")

-- mails and dialogs
function createStartMail()
    local mail = Mail()

    local x = mission.data.custom.location.x
    local y = mission.data.custom.location.y
    mail.text = Format("Hi,\n\nI heard you hired a captain! That's really good news. A captain is an important step towards building your own fleet.\n\nAnyway, I'd like to talk to you about that ship that I still owe you. Meet me in sector (%1%:%2%) if you're interested!\n\nHope to see you soon!\n%3%"%_T, x, y, MissionUT.getAdventurerName())
    mail.header = "About that ship... /* Mail Subject */"%_T
    mail.sender = Format("%1%, the Adventurer"%_T, MissionUT.getAdventurerName())
    mail.id = "Tutorial_StrategyCommandsStart"

    return mail
end

local onEndExplainMissionDialog = makeDialogServerCallback("onEndExplainMissionDialog", 3, function()
    -- go to next phase so that we don't respawn lady on reset
    mission.data.description[5].visible = true
    mission.data.description[5].arguments = {key = mission.data.custom.keyBind}

    nextPhase()
end)

function onStartExplainMissionDialog()
    local dialog = {}
    local dialog2 = {}

    dialog.text = "Hi, thank you for coming!\n\nSo I've tried everything to get your ship back, but I couldn't manage to do it. I'm truly sorry about that.\n\nBut I want to make it up to you, so you can have one of my ships, the Lady Adventurous!\n\nAlso, while we're already at it, I'll show you quickly how to command ships that are in the same sector as you.\n\nHave you already found the strategy interface? It's really useful! Here, I'll teach you."%_t
    dialog.answers = {{answer = "Okay, what do I need to do?"%_t, followUp = dialog2}}

    dialog2.text = string.format("Open Strategy Mode with the Strategy Mode Button and read the encyclopedia entry, if you haven't already. You'll find all the important information there.\n\nThen, order the Lady Adventurous to escort you.\n\nIf you're unsure, you can exit Strategy Mode any time and ask me again."%_t, tostring(GameInput():getKeyName(ControlAction.ToggleStrategyMode)))
    dialog2.onEnd = onEndExplainMissionDialog

    local adventurer = Sector():getEntitiesByScript("story/missionadventurer.lua")
    if not adventurer then resetToPhase(2, true) return end

    adventurer:invokeFunction("story/missionadventurer.lua", "setData", true, true, dialog)
end

function showHelpDialog()
    local dialog = {}
    dialog.text = "In Strategy Mode, select the Lady Adventurous and then right-click on the ship you're currently flying to issue an escort command."%_t

    local entity = Sector():getEntitiesByScript("story/missionadventurer.lua")
    if not entity then return end

    ScriptUI(entity.id):interactShowDialog(dialog)
end

local onEndDialogFinished = makeDialogServerCallback("onEndDialogFinished", 8, function()
    local adventurer = Sector():getEntitiesByScript("story/missionadventurer.lua")
    if adventurer then
        adventurer:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(8, 12))
    end

    local lady = Sector():getEntitiesByScriptValue("strategy_command_lady")
    if lady then
        -- remove lady's script value
        lady:setValue("strategy_command_lady", nil)
    end

    Player():setValue("tutorial_strategycommands_accomplished", true)

    accomplish()
end)

function onEndDialog()
    local dialog = {}
    local captainExplanation = {}
    local finish = {}

    dialog.text = "Wonderful! I believe you'll find even more good use for the Strategy Mode.\n\nYou can order your ships to do many many things in there, like flying to a location, mining or docking for you.\n\nFor the simple tasks you won't even need a captain, the ship's Autopilot will do that for you."%_t
    dialog.answers = {
        {answer = "So, why captains then?"%_t, followUp = captainExplanation},
        {answer = "See you around."%_t, followUp = finish}
    }

    captainExplanation.text = "Contrary to the Autopilot, Captains are highly skilled individuals who will work completely independently, and who can do various different long-term tasks.\n\nYou just have to assign them as the captain of a ship, and they're ready to go. They'll even give you bonuses for your ship, depending on their class.\n\nThen, on the Galaxy Map, you can give them many different orders, such as flying trade routes for you, mining or salvaging for a long time, or even scouting sectors or going on an expedition."%_t
    captainExplanation.answers = {
        {answer = "Okay."%_t, followUp = finish},
    }

    finish.text = "The crew of the Lady Adventurous has agreed to work for you. Since I still owe you a ship, I'd like to sign her over to you permanently.\n\nMaybe you can assign your newly hired captain to her?\n\nAnyway, I'm off to look for a way to cross the Great Barrier! Until next time."%_t
    finish.answers = { {answer = "Thanks!"%_t }, }
    finish.onEnd = onEndDialogFinished

    local adventurer = Sector():getEntitiesByScript("story/missionadventurer.lua")
    if not adventurer then return end
    ScriptUI(adventurer.id):interactShowDialog(dialog, false)
end

function stopHailClient()
    local adventurer = Sector():getEntitiesByScript("story/missionadventurer.lua")
    if not adventurer then return end

    adventurer:invokeFunction("story/missionadventurer.lua", "setData", true, true, {})
    ScriptUI(adventurer.id):stopHailing()
end
