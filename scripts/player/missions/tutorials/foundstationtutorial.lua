package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
package.path = package.path .. ";data/scripts/entity/?.lua"

include("utility")
include("stringutility")
include("callable")
include("structuredmission")

include("defaultscripts")
MissionUT = include("missionutility")
local Adventurer = include("story/missionadventurer")
local AdventurerGuide = include("story/adventurerguide")

-- mission.tracing = true

-- data
abandon = nil
mission.data.autoTrackMission = true
mission.data.playerShipOnly = true
mission.data.title = "Station Founding"%_T
mission.data.brief = "Station Founding"%_T
mission.data.icon = "data/textures/icons/graduate-cap.png"
mission.data.priority = 5
mission.data.description = {}

-- custom data
mission.data.custom.adventurerId = nil
mission.data.custom.shipId = nil
mission.data.custom.createdStationfounder = false
mission.data.custom.createdStation = false
mission.data.custom.thirdDialogStarted = false
mission.data.custom.secondMailRead = false
mission.data.custom.lastMailRead = false

-- phases
-- Phase 1: Player comes into sector => spawn Adventurer and set descriptions
mission.phases[1] = {}
mission.phases[1].onBegin = function()
    if onServer() then
        mission.data.description[1] = {text = "${name} the Adventurer wants to teach you how to found your own station."%_T, arguments = {name = getAdventurerName()}}
        createAdventurer()
    end

    nextPhase()
end
mission.phases[1].noBossEncountersTargetSector = true
mission.phases[1].noPlayerEventsTargetSector = true

-- Phase 2: Wait until Adventurer is finished spawning - start first dialog
mission.phases[2] = {}
local talked
mission.phases[2].updateClient = function()
    if not talked then
        local adventurer = Sector():getEntitiesByScript("story/missionadventurer.lua")
        if not adventurer then return end

        startFirstDialog()
        talked = true
    end
end
mission.phases[2].onSectorLeft = function()
    if onServer() then
        terminate() -- postpone mission
    end
end

-- Phase 3: Check if player built a ship with station founder
mission.phases[3] = {}
mission.phases[3].onBeginServer = function()
    mission.data.description[2] = {text = "Select 'Station Founder' when having a ship built at a shipyard."%_T, bulletPoint = true, fulfilled = false}
end
mission.phases[3].playerCallbacks = {}
mission.phases[3].playerCallbacks[1] =
{
    name = "onShipCreationFinished",
    func = function(senderInfo, shipIndex, founder)
        if onServer() then
            if founder then
                nextPhase()
            end
        end
    end
}

-- Phase 4: Recheck that Adventurer is still here and continue with a dialog (or a mail if player went elsewhere)
mission.phases[4] = {}
mission.phases[4].onBegin = function()
    mission.data.description[2].fulfilled = true
    mission.data.description[3] = {text = "Turn a station founder ship into a station. Careful: You'll need at least 4 Million Credits!"%_T, bulletPoint = true, fulfilled = false}
    if onClient() then
        local adventurerHere = Sector():getEntitiesByScript("story/missionadventurer.lua")
        if adventurerHere then
            startSecondDialog()
        else
            sendSecondDialogMail()
        end
    end
end
mission.phases[4].playerCallbacks = {
    {
        name = "onTransformedToStation",
        func = function(senderInfo, stationIndex)
            if onServer() then
                local station = Entity(stationIndex)
                if station and station.factionIndex == Player().index then
                    nextPhase()
                end
            end
        end
    }
}

-- Phase 5: Recheck that Adventurer is still here and finish up with a dialog (or a mail if player went elsewhere)
mission.phases[5] = {}
mission.phases[5].onBegin = function()
    if onClient() then
        local adventurerHere = checkAdventurerCreated()
        if adventurerHere then
            startLastDialog()
        else
            sendLastDialogMail()
            finishUp()
        end
    end
end
mission.phases[5].timers = {}
mission.phases[5].timers[1] = {callback = function() finishUp() end}
mission.phases[5].showUpdateOnBegin = true


-- helper functions
function getAdventurerName()
    local player = Player()
    local faction = Galaxy():getNearestFaction(player:getHomeSectorCoordinates())
    local language = faction:getLanguage()
    language.seed = Server().seed
    return language:getName()
end

function createAdventurer()
    if onClient() then invokeServerFunction("createAdventurer") return end

    local adventShip = AdventurerGuide.spawnOrFindMissionAdventurer(Player())
    if not adventShip then
        setPhase(3) -- adventurer dialog isn't vital here - skip it
        return
    end
    adventShip.invincible = true
    adventShip.dockable = false
    MissionUT.deleteOnPlayersLeft(adventShip)
    mission.data.custom.adventurerId = adventShip.id.string
    adventShip:invokeFunction("story/missionadventurer.lua", "setInteractingScript", "player/missions/tutorials/foundstationtutorial.lua")
    sync()
end
callable(nil, "createAdventurer")

function checkAdventurerCreated()
    if onServer() then invokeClientFunction(Player(), "checkAdventurerCreated") return false end

    if not mission.data.custom.adventurerId then return false end
    return Entity(mission.data.custom.adventurerId) ~= nil
end

function startFirstDialog()
    local dialog = {}
    local dialog2 = {}
    local dialog3 = {}
    local dialogPost = {}
    local dialogAbandon = {}

    dialog.text = "Hello!\n\nYou seem like someone who would enjoy owning a station.\n\nDo you want me to show you the quickest way to get one? The quickest legal way, that is."%_t
    dialog.answers =
    {
        {answer = "Sure."%_t, followUp = dialog2},
        {answer = "Not right now."%_t, followUp = dialogPost},
    }

    dialog2.text = "See that shipyard over there? You can have ships built at any shipyard.\n\nIf you want to found a station, you need to make sure to check the box 'Station Founder' when you give your order to the crew at the shipyard."%_t
    dialog2.answers = {{answer = "Thanks, I'll check it out."%_t, followUp = dialog3}}

    dialog3.text = "Make sure to bring enough money! You'll need at least 4 Million to found one.\n\nIt doesn't matter if you don't have the money right now, though. You can always do it later and use this ship as a normal ship for now!"%_t
    dialog3.onEnd = "onEndFirstDialog"

    dialogPost.text = "Oh, okay. Until later then."%_t
    dialogPost.onEnd = "onDialogPost"

    local entity = Entity(mission.data.custom.adventurerId)
    -- it's possible that the adventurer doesn't exist here, but it's not a big deal
    -- if he's not there he should be created somewhere else later
    if entity then
        entity:invokeFunction("story/missionadventurer.lua", "setData", true, true, dialog)
    end
end

function onDialogPost()
    if onClient() then invokeServerFunction("onDialogPost") return end

    -- let adventurer jump away
    local adventurer = Entity(mission.data.custom.adventurerId)
    if adventurer then
        Sector():deleteEntityJumped(adventurer)
    end

    terminate() -- mission silently dies and is readded on next sector entered with shipyard present
end
callable(nil, "onDialogPost")

function onEndFirstDialog()
    if onClient() then
        invokeServerFunction("onEndFirstDialog")
        return
    end

    mission.data.description[2] = {text = "Select 'Station Founder' when having a ship built at a shipyard."%_T, bulletPoint = true, fulfilled = false}
    if mission.currentPhase == mission.phases[2] then
        nextPhase()
    end
end
callable(nil, "onEndFirstDialog")

function onHailRejected()
    if onClient() then
        invokeServerFunction("onHailRejected")
        return
    end

    terminate() -- mission silently dies and is readded on next sector entered with shipyard present
end
callable(nil, "onHailRejected")

function startSecondDialog()
    if onServer() then invokeClientFunction(Player(), "startSecondDialog") return end

    local dialog = {}
    dialog.text = "Well done. Now you have a ship that you can use to found a station. Just enter it, fly it to where you want the station to be, and found a station the same way you would normally found a ship."%_t
    dialog.answers = {{answer = "Thank you."%_t}}

    local entity = Sector():getEntitiesByScript("story/missionadventurer.lua")
    entity:invokeFunction("story/missionadventurer.lua", "setData", true, false, dialog)
end

function sendSecondDialogMail()
    if onClient() then invokeServerFunction("sendSecondDialogMail") return end

    local mail = Mail()
    mail.text = Format("Well done. Now you have a ship you can use to found a station. Just enter it, fly it to where you want the station to be, and found a station the same way you would normally found a ship.\n\nGreetings,\n%s"%_T, getAdventurerName())
    mail.header = "A step in the right direction /* Mail Subject */"%_T
    mail.sender = Format("%1%, the Adventurer"%_T, getAdventurerName())
    mail.id = "Tutorial_FoundStation1"

    Player():addMail(mail)
end
callable(nil, "sendSecondDialogMail")

function startLastDialog()
    if onServer() then invokeClientFunction(Player(), "startLastDialog") return end

    local dialog = {}
    dialog.text = "Good job, you founded a station! It's still a little small. You should expand it and hire and assign more crew. The next time I come to this sector, I'm sure I'll find a magnificent station!"%_t
    dialog.answers = {{answer = "Thank you."%_t}}
    dialog.onEnd = "finishUp"

    local entity = Sector():getEntitiesByScript("story/missionadventurer.lua")
    entity:invokeFunction("story/missionadventurer.lua", "setData", true, false, dialog)
end

function sendLastDialogMail()
    if onClient() then invokeServerFunction("sendLastDialogMail") return end

    local mail = Mail()
    mail.text = Format("Good job, you founded a station! It's still a little small. You should expand it and hire and assign more crew.\n\nThe next time I come to this sector, I'm sure I'll find a magnificent station!\n\nGreetings,\n%s"%_T, getAdventurerName())
    mail.header = "Congratulations on your station! /* Mail Subject */"%_T
    mail.sender = Format("%1%, the Adventurer"%_T, getAdventurerName())
    mail.id = "Tutorial_FoundStation2"

    Player():addMail(mail)
end
callable(nil, "sendLastDialogMail")

function finishUp()
    if onClient() and mission.internals.phaseIndex == 5 then invokeServerFunction("finishUp") return end

    local entity = Entity(mission.data.custom.adventurerId)
    if entity then
        Sector():deleteEntityJumped(entity)
    end

    Player():setValue("tutorial_foundstation_accomplished", true)
    accomplish()
end
callable(nil, "finishUp")
