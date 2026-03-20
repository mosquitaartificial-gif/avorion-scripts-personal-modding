package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("utility")
include ("stringutility")
include ("callable")
include ("galaxy")
include ("faction")
include("randomext")
include ("structuredmission")

MissionUT = include ("missionutility")
local ShipUtility = include ("shiputility")
local AdventurerGuide = include ("story/adventurerguide")
local TorpedoGenerator = include ("torpedogenerator")
local AsyncPirateGenerator = include("asyncpirategenerator")
local PlanGenerator = include ("plangenerator")

-- mission.tracing = true

-- mission data
abandon = nil
mission.data.autoTrackMission = true
mission.data.playerShipOnly = true
mission.data.brief = "Torpedo Tests"%_T
mission.data.title = "Torpedo Tests"%_T
mission.data.icon = "data/textures/icons/graduate-cap.png"
mission.data.priority = 5

mission.data.description = {}
mission.data.description[1] = ""
mission.data.description[2] = {text = "Read the Adventurer's mail"%_T, bulletPoint = true, fulfilled = false}
mission.data.description[3] = {text = "Meet the Adventurer in (${xCoord}:${yCoord})"%_T, bulletPoint = true, fulfilled = false, visible = false}
mission.data.description[4] = {text = "Build a Torpedo Launcher and Storage of at least size 9"%_T, bulletPoint = true, fulfilled = false, visible = false}
mission.data.description[5] = {text = "Open the torpedoes tab in your ship window. Drag & drop the torpedo into a torpedo shaft. In the ship tab, bind the shaft to a keyboard shortcut to activate it"%_T, bulletPoint = true, fulfilled = false, visible = false}
mission.data.description[6] = {text = "Shoot the wreckage with the torpedo [${torpedoKey}]"%_T, bulletPoint = true, fulfilled = false, visible = false}
mission.data.description[7] = {text = "Use the torpedo to destroy the pirate"%_T, bulletPoint = true, fulfilled = false, visible = false}

-- custom data
mission.data.custom = {}
mission.data.custom.adventurerId = nil
mission.data.custom.pirateTorpedoLaunched = false
mission.data.custom.wreckageTorpedoLaunched = false
mission.data.custom.wreckageId = nil
mission.data.custom.torpedoHit = false
mission.data.custom.location = {}

-- mission phases
mission.globalPhase = {}
mission.globalPhase.noBossEncountersTargetSector = true
mission.globalPhase.noPlayerEventsTargetSector = true
mission.globalPhase.updateClient = function()
    local tmp = mission.data.torpedoKey
    mission.data.torpedoKey = GameInput():getKeyName(ControlAction.FireTorpedoes)
    if tmp ~= mission.data.torpedoKey then
        invokeServerFunction("syncGameKey", mission.data.torpedoKey)
    end
end
mission.globalPhase.onTargetLocationEntered = function()
    if onClient() then return end

    -- create necessary entities
    createAdventurer() -- always necessary
    if mission.internals.phaseIndex <= 7 then
        createWreckage() -- only needed until phase 7 where player shoots it
    end

    -- reset phase dialogs
    mission.data.custom.dialogPhase3Started = false
    mission.data.custom.dialogPhase4Started = false
    mission.data.custom.dialogPhase5Started = false
    mission.data.custom.dialogPhase10Started = false
end
mission.globalPhase.onTargetLocationLeft = function()
    if onClient() then return end

    if mission.internals.phaseIndex > 1 then
        resetToPhase2()
    end
end
mission.globalPhase.onRestore = function()
    -- make sure all descriptions are there (they might not be if the mission was started in old version of the game), and if not, reset to phase 1
    local descriptionsKnown = true
    for i = 1, 7 do
        if not mission.data.description[i] then
            descriptionsKnown = false
            break
        end
    end

    if descriptionsKnown == false then
        mission.data.description[1] = ""
        mission.data.description[2] = {text = "Read the Adventurer's mail"%_T, bulletPoint = true, fulfilled = false}
        mission.data.description[3] = {text = "Meet the Adventurer in (${xCoord}:${yCoord})"%_T, bulletPoint = true, fulfilled = false, visible = false}
        mission.data.description[4] = {text = "Build a Torpedo Launcher and Storage of at least size 9"%_T, bulletPoint = true, fulfilled = false, visible = false}
        mission.data.description[5] = {text = "Open the torpedoes tab in your ship window. Drag & drop the torpedo into a torpedo shaft. In the ship tab, bind the shaft to a keyboard shortcut to activate it"%_T, bulletPoint = true, fulfilled = false, visible = false}
        mission.data.description[6] = {text = "Shoot the wreckage with the torpedo [${torpedoKey}]"%_T, bulletPoint = true, fulfilled = false, visible = false}
        mission.data.description[7] = {text = "Use the torpedo to destroy the pirate"%_T, bulletPoint = true, fulfilled = false, visible = false}

        setPhase(1)
    end

    -- reset mission progress
    if atTargetLocation() then
        if mission.internals.phaseIndex > 1 then
            resetToPhase2()
        end
    end
end

-- read introductory mail
mission.phases[1] = {}
mission.phases[1].onBeginServer = function()
    mission.data.description[1] = {text = "Learn how to use torpedoes. A complete guide by ${name}, the Adventurer."%_T, arguments = {name = MissionUT.getAdventurerName()}}
    mission.data.description[2].visible = true

    local x, y = Sector():getCoordinates()
    local tx, ty = MissionUT.getEmptySector(x, y, 1, 20, false, false, false, false, false)
    if tx == nil or ty == nil then
        tx, ty = MissionUT.getEmptySector(x, y, 21, 40, false, false, false, false, false)
    end

    mission.data.custom.location = {x = tx, y = ty}

    local player = Player()
    local mail = createStartMail()
    player:addMail(mail)
end
mission.phases[1].playerCallbacks =
{
    {
        name = "onMailRead",
        func = function(playerIndex, mailIndex, mailId)
            -- define mission location here, so that sector is only marked after player read the mail
            mission.data.location = mission.data.custom.location

            if mailId == "Tutorial_Torpedoes" then
                mission.data.description[2].fulfilled = true
                mission.data.description[3].arguments = {xCoord = mission.data.location.x, yCoord = mission.data.location.y}
                mission.data.description[3].visible = true
                nextPhase()
            end
        end
    }
}

-- go to target sector - checkpoint, mission progress will be reset to here if something goes wrong
mission.phases[2] = {}
mission.phases[2].updateClient = function()
    if not Hud().mailWindowVisible then
        Player():sendCallback("onShowEncyclopediaArticle", "Torpedoes")
    end
end
mission.phases[2].onTargetLocationEntered = function()
    if onClient() then
        setTrackThisMission() -- track here to entice player to do this immediately
        return
    end

    nextPhase()
end

-- read dialog that explains torpedoes existing
mission.phases[3] = {}
mission.phases[3].onBeginServer = function()
    mission.data.custom.dialogPhase3Started = false
    mission.data.description[3].fulfilled = true
end
mission.phases[3].updateClient = function()
    if mission.data.custom.dialogPhase3Started == false then
        if checkAdventurerCreated() then
            onStartFirstDialog()
            mission.data.custom.dialogPhase3Started = true
        end
    end
end
mission.phases[3].showUpdateOnEnd = true

-- read dialog telling player to satisfy torpedo requirements
mission.phases[4] = {}
mission.phases[4].onBeginServer = function()
    mission.data.description[4].visible = true
end
mission.phases[4].onBeginClient = function()
    if atTargetLocation() and not mission.data.custom.dialogPhase4Started then
        buildTorpedoStorageDialog()
    end
end
mission.phases[4].updateServer = function()
    if shipMeetsRequirements() then
        mission.data.description[4].fulfilled = true
        nextPhase()
    end
end
mission.phases[4].showUpdateOnEnd = true

-- tell player to equip torpedo
mission.phases[5] = {}
mission.phases[5].onBeginServer = function()
    if atTargetLocation() then
        givePlayerTorpedo()
        nextPhase()
    end
end
mission.phases[5].onBeginClient = function()
    if atTargetLocation() and not mission.data.custom.dialogPhase5Started then
        equipTorpedoDialog()
    end
end
mission.phases[5].updateInterval = 15
mission.phases[5].updateTargetLocationServer = function()
    -- if player destroyed the torpedo or lost it in some other way, give him a new one
    if mission.data.custom.wreckageTorpedoLaunched and not playerHasTorpedo() then
        givePlayerTorpedo(RarityType.Petty)
    end
end
mission.phases[5].showUpdateOnEnd = true

-- update description to tell player to shoot torpedo, create Wreckage
mission.phases[6] = {}
mission.phases[6].onBeginServer = function()
    mission.data.description[5].visible = true
    mission.data.description[6].visible = true
    mission.data.description[6].arguments = {torpedoKey = torpedoKey}

    createWreckage()
    nextPhase()
end
mission.phases[6].showUpdateOnEnd = true

-- wait for player to hit wreckage
mission.phases[7] = {}
mission.phases[7].showUpdateOnEnd = true
mission.phases[7].onBeginServer = function()
    local wreckage = Sector():getEntitiesByScriptValue("torpedoes_tutorial_wreckage")
    if wreckage then
        wreckage:registerCallback("onTorpedoHit", "onTorpedoHit")
    end

    local craft = Player().craft
    if not craft or not shipMeetsRequirements() then
        -- do nothing yet, we listen with callback for craft switching and do it then
        return
    end

    craft:registerCallback("onTorpedoLaunched", "onWreckageTorpedoLaunched")
end
mission.phases[7].updateInterval = 10
mission.phases[7].updateTargetLocationServer = function(timeStep)
    -- if player destroyed the torpedo or lost it in some other way, give him a new one
    if mission.data.custom.wreckageTorpedoLaunched == false and not playerHasTorpedo() then
        givePlayerTorpedo(RarityType.Petty)
    end
end
mission.phases[7].timers = {}
mission.phases[7].timers[1] = {callback = function() showAPirateSpawnedDialog() end}
mission.phases[7].timers[2] = {callback = function() onNeedsNewTorpedo() end}
mission.phases[7].playerCallbacks = {}
mission.phases[7].playerCallbacks[1] =
{
    name = "onShipChanged",
    func = function(playerIndex, craftId)
        local craft = Player().craft
        if not craft then return end

        if shipMeetsRequirements() then
            mission.data.description[4].fulfilled = true
            craft:registerCallback("onTorpedoLaunched", "onWreckageTorpedoLaunched")

            -- give player torpedo if they have none to make sure they can continue tutorial
            if not playerHasTorpedo() then
                givePlayerTorpedo(RarityType.Petty)
            end

        else
            mission.data.description[4].fulfilled = false
            mission.data.description[4].visible = true
        end
    end
}

-- have player fire at pirate
mission.phases[8] = {}
local phase8Timer = 10
mission.phases[8].onBeginServer = function()
    local craft = Player().craft
    if not craft or not shipMeetsRequirements() then return end

    craft:registerCallback("onTorpedoLaunched", "onPirateTorpedoLaunched")
end
mission.phases[8].updateTargetLocationServer = function(timeStep)
    if mission.data.custom.pirateTorpedoLaunched then
        local torps = Sector():getEntitiesByType(EntityType.Torpedo)
        if not torps then
            nextPhase()
        end
    end

    phase8Timer = phase8Timer - timeStep
    if phase8Timer <= 0 then
        -- if player destroyed the torpedo or lost it in some other way, give him a new one
        if mission.data.custom.pirateTorpedoLaunched == false and not playerHasTorpedo() then
            givePlayerTorpedo(RarityType.Petty)
            phase8Timer = 10
        end
    end
end
mission.phases[8].playerCallbacks = {}
mission.phases[8].playerCallbacks[1] =
{
    name = "onShipChanged",
    func = function(playerIndex, craftId)
        local craft = Player().craft
        if not craft then return end

        if shipMeetsRequirements() then
            mission.data.description[4].fulfilled = true
            craft:registerCallback("onTorpedoLaunched", "onPirateTorpedoLaunched")

            -- give player torpedo if they have none to make sure they can continue tutorial
            if not playerHasTorpedo() then
                givePlayerTorpedo(RarityType.Petty)
            end

        else
            mission.data.description[4].fulfilled = false
            mission.data.description[4].visible = true
        end
    end
}

-- despawn pirate with some fluff
mission.phases[9] = {}
mission.phases[9].onBeginServer = function()
    local pirate = Sector():getEntitiesByScriptValue("torpedoes_tutorial_pirate")
    if pirate then
        Player():sendChatMessage(pirate, ChatMessageType.Chatter, "Dammit, torpedoes again, that's not worth it. I'm out of here."%_T)
        local ai = ShipAI(pirate)
        if ai then
            ai:setPassive()
        end
    end

    mission.phases[9].timers[1].time = 5
end
mission.phases[9].timers = {}
--mission.phases[9].resetTimers = true
mission.phases[9].timers[1] = {callback = function() onPirateJump() end}

-- read end dialog
mission.phases[10] = {}
mission.data.custom.dialogPhase10Started = false
mission.phases[10].updateTargetLocationClient = function()
    if not mission.data.custom.dialogPhase10Started then
        local dialog = {}
        dialog.text = "Phew! This pirate had special anti-torpedo weapons. Good for us that he wasn't in the mood for a fight!\n\nLet me give you my spare torpedoes. I've got three with different warheads here. Warheads change the effect of the torpedo, while bodies change speed and maneuverability.\n\nHere, take them, I'd rather do research than fight. They'll be of more use to you."%_t
        dialog.onEnd = "onFinalDialogEnd"

        local entity = Entity(mission.data.custom.adventurerId)
        entity:invokeFunction("story/missionadventurer.lua", "setData", true, false, dialog)
        mission.data.custom.dialogPhase10Started = true
    end
end
mission.phases[10].timers = {}
--mission.phases[10].resetTimers = true
mission.phases[10].timers[1] = {callback = function() showAdventurerChatter() end}


-- helper functions
function syncGameKey(key)
    mission.data.torpedoKey = key
end
callable(nil, "syncGameKey")

function createStartMail()
    local mail = Mail()
    mail.text = Format("Hi there,\n\nI see you found the torpedo launchers. Torpedoes are fantastic weapons with great range that can possibly deal a lot of damage.\n\nMeet me in sector (%1%:%2%) and I'll show you how to get the hang of it. After learning how to use them, you can have some of my old ones.\n\nGreetings,\n%3%"%_T, mission.data.custom.location.x, mission.data.custom.location.y, MissionUT.getAdventurerName())
    mail.header = "Torpedo Instructions /* Mail Subject */"%_T
    mail.sender = Format("%1%, the Adventurer"%_T, MissionUT.getAdventurerName())
    mail.id = "Tutorial_Torpedoes"
    return mail
end

function createAdventurer()
    if onClient() then return end

    local adventShip = AdventurerGuide.spawnOrFindMissionAdventurer(Player())
    if not adventShip then
        -- set new target location and retry
        resetToPhase2()
        return
    end

    adventShip.invincible = true
    MissionUT.deleteOnPlayersLeft(adventShip)
    mission.data.custom.adventurerId = adventShip.id.string
    adventShip:invokeFunction("story/missionadventurer.lua", "setInteractingScript", "player/missions/tutorials/torpedoestutorial.lua")
end

function createWreckage()
    local w = Sector():getEntitiesByScriptValue("torpedoes_tutorial_wreckage")
    if w then
        mission.data.targets = {}
        table.insert(mission.data.targets, w.id.string)
        return
    end

    local faction = Galaxy():getNearestFaction(mission.data.location.x, mission.data.location.y)
    local plan = PlanGenerator.makeShipPlan(faction, 30, nil, Material(MaterialType.Iron))
    local position = Player().craft.position
    position.pos = position.pos + position.up * 1500
    local wreckage = Sector():createWreckage(plan, position)

    wreckage:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
    wreckage:setValue("torpedoes_tutorial_wreckage", true)
    mission.data.custom.wreckageId = wreckage.id.string

    mission.data.targets = {}
    table.insert(mission.data.targets, wreckage.id.string)
end

function checkAdventurerCreated()
    if onServer() then return false end
    if mission.data.custom.adventurerId == nil then return false end

    return Entity(mission.data.custom.adventurerId) ~= nil
end

local decideShipNeedsAdjustement = makeDialogServerCallback("decideShipNeedsAdjustement", 3, function()
    if shipMeetsRequirements() then
        setPhase(5) -- skip phase to adjust player ship
    else
        setPhase(4)
    end
end)

function onStartFirstDialog()
    local dialog = {}
    dialog.text = "Hi there, thank you for coming! I'll explain to you how to use torpedoes.\nI've brought this wreckage for target practice."%_t
    dialog.answers = {{answer = "Okay, let's do it."%_t}}
    dialog.onEnd = decideShipNeedsAdjustement

    local entity = Entity(mission.data.custom.adventurerId)
    entity:invokeFunction("story/missionadventurer.lua", "setData", true, true, dialog)
end

function buildTorpedoStorageDialog()
    local dialog = {}
    dialog.text = "Let's start with building a Torpedo Launcher and Torpedo Storage that is big enough for our test torpedoes. The overall storage size should be at least 9. Remember that Torpedo Storage needs a certain minimum size for a torpedo to fit in."%_t
    dialog.answers = {{answer = "Okay."%_t}}

    local entity = Entity(mission.data.custom.adventurerId)
    if not entity then return end
    entity:invokeFunction("story/missionadventurer.lua", "setData", true, false, dialog)

    mission.data.custom.dialogPhase4Started = true
end

function equipTorpedoDialog()
    local dialog = {}
    dialog.text = "Here is your first test torpedo. To equip it, you first have to load the torpedo into a Torpedo Shaft.\n\nIn your ship menu, go to the tab for torpedoes and drag & drop the torpedo into the shaft.\n\nThen, go to the overview tab and bind the shaft to a weapon number to set it as active.\n\nI suggest you just go ahead and try to shoot the wreckage as soon as you've done that.\n\nEach torpedo has a certain range so make sure you are close enough to your target!"%_t
    dialog.answers = {{answer = "Okay."%_t}}

    local entity = Sector():getEntitiesByScript("story/missionadventurer.lua")
    if not entity then return end
    entity:invokeFunction("story/missionadventurer.lua", "setData", true, false, dialog)

    mission.data.custom.dialogPhase5Started = true
end

function shipMeetsRequirements()
    local craft = Player().craft
    if not craft then return false end

    if craft.allianceOwned then
        -- player is not allowed to play this tutorial in an alliance ship
        return false
    end

    local plan = Plan(craft.id)
    if not plan then return false end

    -- we need a torpedo launcher
    local torpedoLauncher = plan:getBlocksByType(BlockType.TorpedoLauncher)
    local foundLauncher = false
    for _, entry in pairs(torpedoLauncher) do
        if entry ~= nil then
            foundLauncher = true
            break
        end
    end

    if not foundLauncher then return false end

    -- and enough storage
    local torpedoStorage = plan:getBlocksByType(BlockType.TorpedoStorage)
    if not torpedoStorage then
        return false
    end

    local stats = plan:getStats()
    if not stats then return false end
    if stats.torpedoSpace < 8 then
        return false
    end

    return true
end

local warningSent = false
function givePlayerTorpedo(rarity)
    if onClient() then invokeServerFunction("givePlayerTorpedo") return end
    if not atTargetLocation() then return end

    local rarity = rarity or RarityType.Uncommon
    if playerHasTorpedo() then rarity = RarityType.Petty end

    local player = Player()
    local craft = player.craft
    if not craft then return end

    local torpedoLauncher = TorpedoLauncher(craft.id)

    if not torpedoLauncher then
        if not warningSent then
            player:sendChatMessage("The Adventurer"%_T, ChatMessageType.Information, "Your current ship has no torpedo launcher."%_T)
            warningSent = true
        end

        return
    end

    local x, y = Sector():getCoordinates()
    local torpedo = TorpedoGenerator():generate(x, y, 0, Rarity(rarity), 1, 1)
    torpedoLauncher:addTorpedo(torpedo)
end
callable(nil, "givePlayerTorpedo")

function onTorpedoHit(objectIndex, shooterIndex, location)
    if mission.data.custom.torpedoHit then return end
    if objectIndex and objectIndex.string ~= mission.data.custom.wreckageId then return end

    local wreckage = Entity(objectIndex)
    if wreckage then wreckage:unregisterCallback("onTorpedoHit", "onTorpedoHit") end

    local craft = Player().craft
    if not craft then return end

    craft:unregisterCallback("onTorpedoLaunched", "onWreckageTorpedoLaunched")
    mission.data.custom.torpedoHit = true
    mission.data.targets = {}
    mission.data.description[6].fulfilled = true

    createPirate()
    mission.phases[7].timers[1].time = 5
    mission.phases[7].timers[1].passed = 0
    mission.phases[7].timers[1].stopped = false
end

function onWreckageTorpedoLaunched()
    mission.data.description[5].fulfilled = true

    if onClient() then return end -- don't run this on Client, we want timer to be server only

    -- player only gets one torpedo at a time from adventurer
    if mission.data.custom.wreckageTorpedoLaunched then return end

    mission.data.custom.wreckageTorpedoLaunched = true

    -- reset timer
    mission.phases[7].timers[2].passed = 0
    mission.phases[7].timers[2].stopped = false
    mission.phases[7].timers[2].time = 15
end

function onNeedsNewTorpedo()
    if onServer() then
        -- if we hit the wreckage, but it still called this function we have to return
        if mission.data.custom.torpedoHit then return end

        mission.data.custom.wreckageTorpedoLaunched = false
        invokeClientFunction(Player(), "newTorpedoDialog")
    end
end

local receiveAnotherTestTorpedo = makeDialogServerCallback("receiveAnotherTestTorpedo", 7, function()
    if not playerHasTorpedo() then givePlayerTorpedo() end
end)

function newTorpedoDialog()
    local dialog = {}
    dialog.text = "Ah, dang it. Here, have another one and try again!"%_t
    dialog.answers = {{answer = "Thanks, I will!"%_t}}
    dialog.onEnd = receiveAnotherTestTorpedo

    local entity = Entity(mission.data.custom.adventurerId)
    if not entity then return end
    entity:invokeFunction("story/missionadventurer.lua", "setData", true, false, dialog)
end

function playerHasTorpedo()
    local player = Player()
    local craft = player.craft
    if not craft then return false end

    local torpedoLauncher = TorpedoLauncher(craft.id)
    if not torpedoLauncher then return false end

    return (torpedoLauncher.numTorpedoes > 0)
end

function createPirate()
    local pirate = Sector():getEntitiesByScriptValue("torpedoes_tutorial_pirate", true)
    if pirate then
        return
    end

    local onPirateCreated = function(pirate)
        ShipAI(pirate.id):setPassive()
        pirate.invincible = true
        pirate.dockable = false
        pirate:setValue("torpedoes_tutorial_pirate", true)
        pirate:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")

        ShipUtility.addCIWSEquipment(pirate)
    end

    local generator = AsyncPirateGenerator(nil, onPirateCreated)

    local dir = random():getDirection()
    local up = vec3(0, 1, 0)
    local pos = dir * 1000
    generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos))
end

function showAPirateSpawnedDialog()
    if onServer() then invokeClientFunction(Player(), "showAPirateSpawnedDialog") return end

    if atTargetLocation() then
        local dialog = {}
        dialog.text = "Uh oh, there's a pirate! Here, take this torpedo and shoot them down!"%_t
        dialog.onEnd = "onPirateSpawnedDialogEnd"

        local entity = Entity(mission.data.custom.adventurerId)
        if not entity then onPirateSpawnedDialogEnd() return end
        entity:invokeFunction("story/missionadventurer.lua", "setData", true, false, dialog)
    end
end

function onPirateSpawnedDialogEnd()
    if onClient() then invokeServerFunction("onPirateSpawnedDialogEnd") return end

    mission.data.description[7].visible = true

    if not playerHasTorpedo() then
        givePlayerTorpedo()
    end

    local pirate = Sector():getEntitiesByScriptValue("torpedoes_tutorial_pirate")
    if not pirate then
        -- pirate wasn't spawned yet, reset mission as something is definitely wrong
        resetToPhase2()
        return
    end

    ShipAI(pirate):setAggressive()
    setPhase(8)
end
callable(nil, "onPirateSpawnedDialogEnd")

function onPirateTorpedoLaunched(entityId, torpedoId)
    mission.data.custom.pirateTorpedoLaunched = true
end

function onPirateJump()
    local pirate = Sector():getEntitiesByScriptValue("torpedoes_tutorial_pirate")
    if pirate then
        Sector():deleteEntityJumped(pirate)
        mission.data.description[7].fulfilled = true
    end

    setPhase(10)
end

function onFinalDialogEnd()
    if onClient() then
        invokeServerFunction("onFinalDialogEnd")
        return
    end

    local player = Player()
    player:setValue("tutorial_torpedoes_accomplished", true) -- we set this here, so that players can't farm this mission

    givePlayerReward()
    mission.phases[10].timers[1].time = 3
end
callable(nil, "onFinalDialogEnd")

function givePlayerReward()
    local player = Player()
    local craft = player.craft
    if not craft then return end

    local torpedoLauncher = TorpedoLauncher(craft.id)
    local x = mission.data.location.x
    local y = mission.data.location.y

    local generator = TorpedoGenerator()
    local torpedo = generator:generate(x, y, 0, Rarity(RarityType.Uncommon), 1, 9)
    local torpedo2 = generator:generate(x, y, 0, Rarity(RarityType.Uncommon), 2, 5)
    local torpedo3 = generator:generate(x, y, 0, Rarity(RarityType.Uncommon), 4, 1)

    if torpedoLauncher then
        torpedoLauncher:addTorpedo(torpedo)
        torpedoLauncher:addTorpedo(torpedo2)
        torpedoLauncher:addTorpedo(torpedo3)
    else
        Sector():dropTorpedo(craft.translationf, player, nil, torpedo)
        Sector():dropTorpedo(craft.translationf, player, nil, torpedo2)
        Sector():dropTorpedo(craft.translationf, player, nil, torpedo3)
    end
end

function showAdventurerChatter()
    Player():sendChatMessage(Entity(mission.data.custom.adventurerId), ChatMessageType.Chatter, "Nice, this one has potential. And another good deed done."%_T)
    Entity(mission.data.custom.adventurerId):addScript("data/scripts/entity/utility/delayeddelete.lua", random():getFloat(10, 20))
    accomplish()
end

function resetToPhase2()
    -- get new location and reset to phase 2
    local x, y = Sector():getCoordinates()
    local tx, ty = MissionUT.getEmptySector(x, y, 1, 20, false, false, false, false, MissionUT.checkSectorInsideBarrier(x, y))
    if tx == nil or ty == nil then
        tx, ty = MissionUT.getEmptySector(x, y, 21, 40, false, false, false, false, false)
    end

    mission.data.custom.location = {x = tx, y = ty}
    mission.data.location = mission.data.custom.location

    mission.data.description[3].arguments = {xCoord = mission.data.location.x, yCoord = mission.data.location.y}
    mission.data.description[3].fulfilled = false

    for i = 4, #mission.data.description do
        mission.data.description[i].visible = false
        mission.data.description[i].fulfilled = false
    end

    mission.data.custom.torpedoHit = false
    mission.data.custom.pirateTorpedoLaunched = false
    mission.data.custom.wreckageTorpedoLaunched = false

    mission.phases[7].timers[1].time = nil
    mission.phases[7].timers[2].time = nil
    mission.phases[9].timers[1].time = nil
    mission.phases[10].timers[1].time = nil

    setPhase(2)
end
