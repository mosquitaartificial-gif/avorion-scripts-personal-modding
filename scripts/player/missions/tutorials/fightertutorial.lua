package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("utility")
include("stringutility")
include("callable")
include("randomext")
include("structuredmission")
MissionUT = include ("missionutility")
local SectorFighterGenerator = include("sectorfightergenerator")
local AdventurerGuide = include ("story/adventurerguide")
local SectorSpecifics = include("sectorspecifics")

-- mission.tracing = true

-- mission data
abandon = nil
mission.data.autoTrackMission = true
mission.data.playerShipOnly = true
mission.data.brief = "Commanding Fighters"%_T
mission.data.title = "Commanding Fighters"%_T
mission.data.icon = "data/textures/icons/graduate-cap.png"
mission.data.priority = 5
mission.data.description = {}

-- mission custom data
mission.data.custom.miningFighterCount = 0
mission.data.custom.armedFighterCount = 0
mission.data.custom.firstMailRead = false
mission.data.custom.secondMailRead = false
mission.data.custom.lastMailRead = false
mission.data.custom.adventurerId = nil
mission.data.custom.weaponType = nil
mission.data.custom.buyMiningFighters = false
mission.data.custom.buyArmedFighters = false
mission.data.custom.damagedEntities = {}
mission.data.custom.entityDestroyed = false
mission.data.custom.endDialogStarted = false
mission.data.custom.done = false
mission.data.custom.location = {}
mission.data.custom.rewardGiven = false

--rewards
mission.getRewardedItems = function()
    if onClient() then return end

    squadName = squadName or "Adventurer's Squad"%_T

    local ship = Player().craft
    if not ship then return end
    local hangar = Hangar(ship.index)
    if hangar == nil then return end

    local x, y = Sector():getCoordinates()

    local squad = hangar:addSquad(squadName)
    local fighter = SectorFighterGenerator():generate(x, y, nil, Rarity(RarityType.Uncommon), mission.data.custom.weaponType, nil)

    if mission.data.custom.rewardGiven then return end -- only give reward once
    for i = 1, 6 do
        hangar:addFighter(squad, fighter)
    end

    mission.data.custom.rewardGiven = true
    nextPhase()
end


-- mission phases
mission.phases[1] = {}
mission.phases[1].onBeginServer = function()
    mission.data.description[1] = {text = "Learn how to use fighters. A complete guide by ${name}, the Adventurer."%_T, arguments= {name = getAdventurerName()}}
    mission.data.description[2] = {text = "Read the instruction mail"%_T, bulletPoint = true, fulfilled = false}

    local player = Player()
    local mail = createStartMail()
    player:addMail(mail)
end
mission.phases[1].playerCallbacks = {
    {
        name = "onMailRead",
        func = function(...) onMailRead(...) end
    }
}
mission.phases[1].showUpdateOnEnd = true

mission.phases[2] = {}
mission.phases[2].updateClient = function()
    if not Hud().mailWindowVisible then
        Player():sendCallback("onShowEncyclopediaArticle", "Fighters")
    end
end
mission.phases[2].playerEntityCallbacks = {
    {
        name = "onFighterAdded",
        func =  function(...) onFighterAdded(...) end
    }
}
mission.phases[2].showUpdateOnEnd = true

mission.phases[3] = {}
mission.phases[3].onBeginServer = function()
    mission.data.description[2].fulfilled = true
    mission.data.description[3] = {text = "Collect 2500 Trinium with fighters"%_T, bulletPoint = true, fulfilled = false}

    local player = Player()
    local resources = {player:getResources()}
    mission.data.custom.startTrinium = resources[MaterialType.Trinium+1]
end
mission.phases[3].playerCallbacks = {
    {
        name = "onResourcesChanged",
        func = function(...) onResourcesChanged(...) end
    }
}
mission.phases[3].showUpdateOnEnd = true

mission.phases[4] = {}
mission.phases[4].onBeginServer = function()
    mission.data.description[3].fulfilled = true
    mission.data.description[4] = {text = "Read the Adventurer's second mail"%_T, bulletPoint = true, fulfilled = false}
    local mail = createBuyArmedMail()
    Player():addMail(mail)
end
mission.phases[4].playerCallbacks = {
    {
        name = "onMailRead",
        func = function(...) onMailRead(...) end
    }
}
mission.phases[4].showUpdateOnEnd = true

mission.phases[5] = {} -- here we only wait that player buys armed fighters, switch to next phase is in callback
mission.phases[5].showUpdateOnEnd = true
mission.phases[5].playerEntityCallbacks = {
    {
        name = "onFighterAdded",
        func =  function(...) onFighterAdded(...) end
    }
}

mission.phases[6] = {}
mission.phases[6].onBeginServer = function()
    mission.data.description[5].fulfilled = true
    mission.data.description[6] = {text = "Destroy an enemy with your fighters"%_T, bulletPoint = true, fulfilled = false}
end
mission.phases[6].updateServer = function()
    if mission.data.custom.entityDestroyed then
        mission.data.description[6].fulfilled = true
        mission.data.description[7] = {text = "Read the Adventurer's last mail"%_T, bulletPoint = true, fulfilled = false}
        Player():addMail(createLastMail())
        nextPhase()
    end
end
mission.phases[6].showUpdateOnEnd = true
mission.phases[6].onEntityDestroyed = function(index, lastDamageInflictor)
    if not mission.data.custom.entityDestroyed then
        for _,k in pairs(mission.data.custom.damagedEntities) do
            if k == index.string then
                mission.data.custom.entityDestroyed = true
                return
            end
        end
    end
end
mission.phases[6].onRestore = function()
    mission.data.custom.entityDestroyed  = false
end
mission.phases[6].playerCallbacks = {
    {
        name = "onMailRead",
        func = function(...) onMailRead(...) end
    }
}
mission.phases[6].sectorCallbacks = {
    {
        name = "onDamaged",
        func = function(...) onEntityDamaged(...) end
    }
}

mission.phases[7] = {} -- wait for player to read the mail and jump to new sector
mission.phases[7].playerCallbacks = {
    {
        name = "onMailRead",
        func = function(...) onMailRead(...) end
    }
}

mission.phases[8] = {}
mission.phases[8].onTargetLocationEntered = function()
    if onServer() then
        createAdventurer()
        mission.data.description[8].fulfilled = true
    end
end
mission.phases[8].onTargetLocationArrivalConfirmed = function()
    nextPhase()
end
mission.phases[8].noBossEncountersTargetSector = true
mission.phases[8].noPlayerEventsTargetSector = true

mission.phases[9] = {}
local showedDialog
mission.phases[9].updateClient = function()
    local adventurer = Sector():getEntitiesByScript("story/missionadventurer.lua")
    if adventurer and not showedDialog then
        onLastDialog()
        showedDialog = true
    end
end
mission.phases[9].onRestore = function()
    if atTargetLocation() then
        showedDialog = false
        createAdventurer()
    end
end
mission.phases[9].onTargetLocationLeft = function()
    showedDialog = false
    mission.data.description[8].fulfilled = false
end
mission.phases[9].onTargetLocationEntered = function()
    if onServer() then
        createAdventurer()
    end

    showedDialog = false
    mission.data.description[8].fulfilled = true
end
mission.phases[9].noBossEncountersTargetSector = true
mission.phases[9].noPlayerEventsTargetSector = true

mission.phases[10] = {}
mission.phases[10].onBeginServer = function()
    local ai = ShipAI(mission.data.custom.adventurerId)
    if ai then
        ai:setPassive()
    end

    Player():sendChatMessage(Entity(mission.data.custom.adventurerId), ChatMessageType.Chatter, "Until next time. Good bye!"%_T)
    -- have adventurer despawn after a while
    Entity(mission.data.custom.adventurerId):addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(6, 10))
end
mission.phases[10].updateServer = function()
    if not mission.data.custom.done then
        accomplish()
        mission.data.custom.done = true
    end
end
mission.phases[10].noBossEncountersTargetSector = true
mission.phases[10].noPlayerEventsTargetSector = true

-- helper functions
function createStartMail()
    local mail = Mail()
    mail.text = Format("Hi there,\n\nNow that your ship has a hangar, you can try out the different ways to use it. To start things off, buy some Mining Fighters at an Equipment Dock.\n\nGreetings,\n%1%, the Adventurer"%_T, getAdventurerName())
    mail.header = "Hangar / Fighter Instructions /* Mail Subject */"%_T
    mail.sender = Format("%1%, the Adventurer"%_T, getAdventurerName())
    mail.id = "Tutorial_Fighters"
    return mail
end

function createBuyArmedMail()
    local mail = Mail()
    mail.text = Format("Hello friend,\n\nI've heard you were successful in mining some Trinium with your fighters. But fighters aren't only for mining - they can come in very handy in fights as well. You should buy some and destroy an enemy!\n\nGreetings,\n%1%, the Adventurer"%_T, getAdventurerName())
    mail.header = "Hangar / Fighter Instructions continued /* Mail Subject */"%_T
    mail.sender = Format("%1%, the Adventurer"%_T, getAdventurerName())
    mail.id = "Tutorial_Fighters_continued"
    return mail
end

function createLastMail()
    local mail = Mail()
    mission.data.custom.location = findMeetUpSector()
    mail.text = Format("Hello,\n\nI heard you successfully used your fighters to destroy an enemy. Well done! For all that hard work, I'd like to give you a reward. Meet me in (%1%:%2%)!\n\nGreetings,\n%3%, the Adventurer"%_T, mission.data.custom.location.x, mission.data.custom.location.y, getAdventurerName())
    mail.header = "Hangar / Fighter Instructions well done!/* Mail Subject */"%_T
    mail.sender = Format("%1%, the Adventurer"%_T, getAdventurerName())
    mail.id = "Tutorial_Fighters_Last"
    return mail
end

function getAdventurerName()
    local player = Player()
    local faction = Galaxy():getNearestFaction(player:getHomeSectorCoordinates())
    local language = faction:getLanguage()
    language.seed = Server().seed
    return language:getName()
end

function onMailRead(playerIndex, mailIndex, mailId)
    if mailId == "Tutorial_Fighters" and not mission.data.custom.firstMailRead then
        mission.data.description[2].fulfilled = true
        mission.data.description[3] = {text = "Buy three Mining Fighters"%_T, bulletPoint = true, fulfilled = false}
        mission.data.custom.firstMailRead = true
        mission.data.custom.buyMiningFighters = true
        nextPhase()
        return
    end

    if mailId == "Tutorial_Fighters_continued" and not mission.data.custom.secondMailRead then
        mission.data.custom.secondMailRead = true
        mission.data.custom.buyArmedFighters = true
        mission.data.description[4].fulfilled = true
        mission.data.description[5] = {text = "Buy three Armed Fighters"%_T, bulletPoint = true, fulfilled = false}
        nextPhase()
        return
    end

    if mailId == "Tutorial_Fighters_Last" and not mission.data.custom.lastMailRead then
        mission.data.custom.lastMailRead = true
        mission.data.description[7].fulfilled = true
        mission.data.description[8] = {text = "Meet the Adventurer"%_t, bulletPoint = true, fulfilled = false}
        mission.data.location = mission.data.custom.location -- Now let the player see the coordinates on the map
        nextPhase()
    end
end

function onFighterAdded(entityId, squadIndex, fighterIndex, landed)
    if landed then return end

    local craft = Entity(entityId)
    if not craft then return end

    if not isInCorrectShip() then return end

    local plan = Plan(craft.id)
    if not plan then return end
    local hangar = plan:getBlocksByType(BlockType.Hangar)
    if not hangar then return end
    local fighter = Hangar(entityId):getFighter(squadIndex, fighterIndex)
    if not fighter then return end

    if fighter.type == FighterType.Fighter and fighter.stoneBestEfficiency > 0 then
        mission.data.custom.miningFighterCount = mission.data.custom.miningFighterCount + 1
    elseif fighter.type == FighterType.Fighter and fighter.armed then
        mission.data.custom.armedFighterCount = mission.data.custom.armedFighterCount + 1
    end

    if mission.data.custom.buyMiningFighters and mission.data.custom.miningFighterCount >= 3 then
        mission.data.custom.buyMiningFighters = false
        nextPhase()
    elseif mission.data.custom.buyArmedFighters and mission.data.custom.armedFighterCount >= 3 then
        craft:unregisterCallback("onFighterAdded", "onFighterAdded")
        mission.data.custom.buyArmedFighters = false
        nextPhase()
    end
end

function onResourcesChanged(playerIndex)
    local player = Player()
    local resources = {player:getResources()}
    if mission.data.custom.startTrinium and ((resources[MaterialType.Trinium + 1] - mission.data.custom.startTrinium) >= 2500) then
        player:unregisterCallback("onResourcesChanged", "onResourcesChanged")
        setPhase(4)
    elseif not mission.data.custom.startTrinium and resources[MaterialType.Trinium + 1] >= 2500 then
        player:unregisterCallback("onResourcesChanged", "onResourcesChanged")
        setPhase(4)
    end
end

function createAdventurer()
    local adventShip = AdventurerGuide.spawnOrFindMissionAdventurer(Player())
    if not adventShip then
        setPhase(mission.internals.phaseIndex)
        return
    end

    adventShip.invincible = true
    adventShip.dockable = false
    MissionUT.deleteOnPlayersLeft(adventShip)
    mission.data.custom.adventurerId = adventShip.id.string
    adventShip:invokeFunction("story/missionadventurer.lua", "setInteractingScript", "player/missions/tutorials/fightertutorial.lua")
end

function checkAdventurerCreated()
    if onServer() then invokeClientFunction(Player(), "checkAdventurerCreated") end

    return Entity(mission.data.custom.adventurerId) ~= nil
end

function onLastDialog()
    local dialog = {}
    local miningDialog = {}
    local armedDialog = {}
    local boardingDialog = {}
    dialog.text = "Nice job! As a thank you for working with me, I'd like to give you some more fighters. Which type would you prefer?"%_t
    dialog.answers =
    {
        {answer = "Mining Fighters"%_t, followUp = miningDialog},
        {answer = "Armed Fighters"%_t, followUp = armedDialog}
    }


    miningDialog.text = "Good choice! Good luck on your journey through the galaxy."%_t
    miningDialog.answers = {{answer = "Thank you and goodbye!"%_t, followUp = boardingDialog}}
    miningDialog.onEnd = "onLastDialogEndMining"

    armedDialog.text = miningDialog.text
    armedDialog.answers = miningDialog.answers
    armedDialog.onEnd = "onLastDialogEndArmed"

    boardingDialog.text = "Before you go, I heard that you can use a special type of fighter to shuttle crew to other ships. I've no need for that but some people use it to bring ships under their command without running the risk of destroying the cargo.\n\nI'll pin the information on how to do that to your mission log, in case you want to give it a go."%_t
    boardingDialog.answers = {{answer = "Okay, thank you."%_t}}
    boardingDialog.onEnd = "onLastDialogEnd"

    local entity = Sector():getEntitiesByScript("story/missionadventurer.lua")
    if not entity then return end
    entity:invokeFunction("story/missionadventurer.lua", "setData", true, false, dialog)
end

function onLastDialogEndMining()
    if onClient() then invokeServerFunction("onLastDialogEndMining") return end
    mission.data.custom.weaponType = WeaponType.MiningLaser
end
callable(nil, "onLastDialogEndMining")

function onLastDialogEndArmed()
    if onClient() then invokeServerFunction("onLastDialogEndArmed") return end
    mission.data.custom.weaponType = WeaponType.Laser
end
callable(nil, "onLastDialogEndArmed")

function onLastDialogEnd()
    if onClient() then invokeServerFunction("onLastDialogEnd") return end

    local player = Player()
    player:setValue("tutorial_fighters_accomplished", true)

    if not player:getValue("tutorial_boarding_accomplished") then
        player:addScriptOnce("data/scripts/player/missions/tutorials/boardingtutorial.lua")
    end

    reward()
end
callable(nil, "onLastDialogEnd")

function onEntityDamaged(objectIndex, amount, inflictor, damageType)
    local damageDealer = Entity(inflictor)
    if not damageDealer then return end

    local entity = Entity(objectIndex)
    if entity and (entity.type == EntityType.Ship or entity.type == EntityType.Station) and damageDealer.type == EntityType.Fighter then
        local player = Player()
        if damageDealer.factionIndex == player.index then
            table.insert(mission.data.custom.damagedEntities, objectIndex.string)
        end
    end
end

function findMeetUpSector(cx, cy)
    if not cx and not cy then
        cx, cy = Sector():getCoordinates()
    end

    local missionTarget = nil
    local playerInsideBarrier = MissionUT.checkSectorInsideBarrier(cx, cy)
    local otherMissionLocations = MissionUT.getMissionLocations()

    local test = function(x, y, regular, offgrid, blocked, home, dust, factionIndex, centralArea)
        if regular then return end
        if blocked then return end
        if offgrid then return end
        if home then return end
        if Balancing_InsideRing(x, y) ~= playerInsideBarrier then return end
        if otherMissionLocations:contains(x, y) then return end

        return true
    end

    local specs = SectorSpecifics(cx, cy, GameSeed())

    for i = 0, 20 do
        local target = specs:findSector(random(), cx, cy, test, 20 + i * 15, i * 15)

        if target then
            missionTarget = target
            break
        end
    end

    if not missionTarget then
        -- use any sector
        missionTarget.x, missionTarget.y = MissionUT.getSector(0, 0, 225, 275, false, false, false, false)
    end

    return missionTarget
end

function onAdventurerDespawn()
    Sector():deleteEntityJumped(Entity(mission.data.custom.adventurerId))
end
