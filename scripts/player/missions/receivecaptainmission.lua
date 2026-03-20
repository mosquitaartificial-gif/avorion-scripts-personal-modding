package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("structuredmission")
include ("utility")
include ("callable")
include ("randomext")
include("productions")
local MissionUT = include ("missionutility")
local Balancing = include ("galaxy")
local CaptainGenerator = include ("captaingenerator")
local CaptainUtility = include ("captainutility")
local SectorGenerator = include ("SectorGenerator")
local ASyncPirateGenerator = include ("asyncpirategenerator")
local Dialog = include ("dialogutility")
local WaveUtility = include ("waveutility")
local Placer = include ("placer")

-- mission.tracing = true

-- mission data
mission.data.title = "A Lost Friend"%_t
mission.data.brief = mission.data.title

mission.data.autoTrackMission = true

mission.data.targets = {}
mission.data.icon = "data/textures/icons/captain.png"

mission.data.description = {}
mission.data.description[1] = {text = "Look for hints on the whereabouts of your client's friend, the ${classtype}. /* male variant */"%_T}
mission.data.description[2] = {text = "Go to (${x}:${y})"%_T, bulletPoint = true, visible = false}
mission.data.description[3] = {text = "Search the wreckage for information"%_T, bulletPoint = true, visible = false}
mission.data.description[4] = {text = "Go to (${x}:${y})"%_T, bulletPoint = true, visible = false}
mission.data.description[5] = {text = "Defeat the pirates"%_T, bulletPoint = true, visible = false}
mission.data.description[6] = {text = "Pick up Captain ${name} at the station in (${x}:${y})"%_T, bulletPoint = true, visible = false}

-- values to control wave encounter
local currentWave = 1
local spawnWave = {}
local waveSpawned = {}
-- dialog after wave encounter
local dialogStarted = false
-- window to show credentials
local window = nil
-- captain that player can get as reward
local captain = nil

-- disable event spawns for less confusion
mission.globalPhase.noPlayerEventsTargetSector = true
mission.globalPhase.noBossEncountersTargetSector = true
mission.globalPhase.noLocalPlayerEventsTargetSector = true

-- phase 1: wait for player to reach target sector -> spawn wreckage with hint dialog
mission.phases[1] = {}
mission.phases[1].onBeginServer = function()
    local savedGender = mission.data.arguments.captain.genderId
    if savedGender == CaptainGenderId.Female then
        mission.data.description[1].text = "Look for hints on the whereabouts of your client's friend, the ${classtype}. /* female variant */"%_T
    end

    local savedClassName = mission.data.arguments.captain.className
    mission.data.description[1].arguments = {classtype = savedClassName}
    mission.data.description[2].arguments = {x = mission.data.location.x, y = mission.data.location.y}
    mission.data.description[2].visible = true
    sync() -- in reset case only server has updated mission location
end
mission.phases[1].onTargetLocationEntered = function()
    if onClient() then return end

    local wreckage = spawnMissionWreckage()
    mission.data.targets = {}
    table.insert(mission.data.targets, wreckage.id.string)
end
mission.phases[1].onTargetLocationArrivalConfirmed = function()
    nextPhase()
end

-- phase 2: wait for interaction with wreckage
mission.phases[2] = {}
mission.phases[2].onBeginServer = function()
    mission.data.description[2].fulfilled = true
    mission.data.description[3].visible = true

    -- calculate next location
    local insideBarrier = MissionUT.checkSectorInsideBarrier(mission.data.location.x, mission.data.location.y)
    local x, y = MissionUT.getSector(mission.data.location.x, mission.data.location.y, 19, 21, false, false, false, false, insideBarrier)
    mission.data.custom.location = {x = x, y = y}
    sync() -- we need location on client
end
mission.phases[2].playerCallbacks = {}
mission.phases[2].playerCallbacks[1] =
{
    name = "onStoryHintWreckageSearched",
    func = function(entityId)
        if mission.data.custom.wreckageId == tostring(entityId) then
            ScriptUI(entityId):interactShowDialog(makeWreckageHintDialog())
            mission.data.targets = {}
        end
    end
}
mission.phases[2].onSectorLeft = function()
    resetToPhase(1)
end
mission.phases[2].onRestore = function()
    resetToPhase(1, true)
end

-- phase 3: go to new target sector -> spawn pirate base sector
mission.phases[3] = {}
mission.phases[3].onBeginServer = function()
    mission.data.location = mission.data.custom.location
    mission.data.targets = {}

    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true
    mission.data.description[4].arguments = {x = mission.data.location.x, y = mission.data.location.y}
    sync()
end
local stationLocation = nil
mission.phases[3].onTargetLocationEntered = function()
    if onClient() then return end

    -- create station
    local station = spawnPirateStation()

    if station then
        stationLocation = station.position
    end

    -- initiate pirate wave encounter
    mission.data.custom.waves = WaveUtility.getWaves(8, 4, 3, 4, 2)
    WaveUtility.createPirateWave(nil, mission.data.custom.waves[1], onPirateWaveGenerated, stationLocation)
end
mission.phases[3].onTargetLocationArrivalConfirmed = function()
    nextPhase()
end
mission.phases[3].playerCallbacks = {}
mission.phases[3].playerCallbacks[1] =
{
    name = "onStoryHintWreckageSearched",
    func = function(entityId)
        -- allow player to repeat dialog of previous phase
        if mission.data.custom.wreckageId == tostring(entityId) then
            ScriptUI(entityId):interactShowDialog(makeWreckageHintDialog())
            mission.data.targets = {}
        end
    end
}

-- phase 4: fight wave encounter
mission.phases[4] = {}
mission.phases[4].onBegin = function()
    mission.data.description[4].fulfilled = true
    mission.data.description[5].visible = true
end
mission.phases[4].updateServer = function()
    -- spawning
    if spawnWave[1] then
        spawnWave[1] = false
        currentWave = 2
        WaveUtility.createPirateWave(nil, mission.data.custom.waves[currentWave], onPirateWaveGenerated, stationLocation)
    end

    if spawnWave[2] then
        spawnWave[2] = false
        currentWave = 3
        WaveUtility.createPirateWave(nil, mission.data.custom.waves[currentWave], onPirateWaveGenerated, stationLocation)
    end

    if spawnWave[3] then
        spawnWave[3] = false
        currentWave = 4
        WaveUtility.createPirateWave(nil, mission.data.custom.waves[currentWave], onPirateWaveGenerated, stationLocation)
    end

    -- count pirates and initiate spawning if necessary
    if waveSpawned[currentWave] and WaveUtility.getNumEnemies() <= 2 then
        if currentWave == 1 then
            spawnWave[currentWave] = true
        elseif currentWave == 2 then
            spawnWave[currentWave] = true
        elseif currentWave == 3 then
            spawnWave[currentWave] = true
        end
    end

    -- last wave was defeated
    if waveSpawned[4] and WaveUtility.getNumEnemies() == 0 then
        nextPhase()
    end
end
mission.phases[4].onSectorLeft = function()
    resetToPhase(3)
end
mission.phases[4].onRestore = function()
    resetToPhase(3, true)
end

-- phase 5: dialog with captain => player gets to decide to keep captain or get money
mission.phases[5] = {}
mission.phases[5].onBegin = function()
    mission.data.description[5].fulfilled = true

    -- create a captain that we offer to the player
    if not captain then
        captain = generateCaptain()
    end

    -- gift station to local faction - it'll be cleaned up as soon as the last player leaves the sector
    if onServer() then
        local sector = Sector()
        local station = sector:getEntitiesByScriptValue("captainmission_station", true)
        if not valid(station) then return end

        local localFaction = Galaxy():getNearestFaction(sector:getCoordinates())
        station.factionIndex = localFaction.index
        station:addScriptOnce("data/scripts/entity/utility/temporaryinvincibility.lua", 20, 1, true)
    end
end
mission.phases[5].updateClient = function()
    if not dialogStarted and MissionUT.playerInTargetSector(Player(), mission.data.location) then
        dialogStarted = true
        startStationDialog(false)
    end
end
mission.phases[5].onStartDialog = function(entityId)
    if entityId.string == mission.data.custom.stationId then
        local scriptUI = ScriptUI(mission.data.custom.stationId)
        if not scriptUI then return end

        scriptUI:addDialogOption(string.format("I'm looking for ${name}."%_t % {name = mission.data.arguments.captain.name}), "startStationDialog")
    end
end
mission.phases[5].onSectorLeft = function()
    if onClient() and window then window:hide() end

    resetToPhase(5)
end
mission.phases[5].onRestore = function()
    resetToPhase(5, MissionUT.playerInTargetSector(Player(), mission.data.location)) -- new sector only necessary if we're in target sector
end
mission.phases[5].onTargetLocationEntered = function()
    if onClient() then return end

    -- backup - create station again in case something went wrong
    local station = spawnPirateStation()
end

-- dialogs
----------
local wreckageHintAskedOnEnd = makeDialogServerCallback("wreckageHintAskedOnEnd", 2, function()
    setPhase(3)
end)

function makeWreckageHintDialog()
    local dialog = {}
    local dialog_2 = {}
    local dialog_3 = {}

    local randomNumbers = getRandomLogNumbers()
    dialog.text = string.format("Log entry ${number}:\nOur instruments picked up strange interferences that our engineers can't explain."%_t % {number = randomNumbers[1]})
    dialog.answers = {{answer = "Proceed"%_t, followUp = dialog_2}}

    dialog_2.text = string.format("Log entry ${number}:\nIt seems that we're being followed.\n\nTheir ship is registered to sector (${x}:${y}). I didn't even know that sector was habitable.\n\nWe'll try to move faster to lose them."%_t % {number = randomNumbers[2], x = mission.data.custom.location.x, y = mission.data.custom.location.y})
    dialog_2.answers = {{answer = "Proceed"%_t, followUp = dialog_3}}

    dialog_3.text = string.format("Log entry ${number}:\nThey've caught up with us.\nThey want to send over a boarding party. We're preparing the airlock."%_t % {number = randomNumbers[3]})
    dialog_3.answers = {{answer = "Close"%_t}}
    dialog_3.onEnd = wreckageHintAskedOnEnd

    return dialog
end

local onNotInterestedSelected = makeDialogServerCallback("onNotInterestedSelected", 5, function()
    -- end mission
    reward()
    accomplish()
end)

local onTakeCaptainSelected = makeDialogServerCallback("onTakeCaptainSelected", 5, function()

    -- check if we can give player captain and return money if not
    local errorMsg = "It seems I can't come aboard afterall. Here is your money back."%_T
    local player = Player()
    local craft = player.craft

    if not craft then
        -- player in drone => can only be player
        player:receive(errorMsg, mission.data.reward)
        accomplish()
        return
    end

    local crew = CrewComponent(craft)
    if not crew then
        -- player in drone => can only be player
        player:receive(errorMsg, mission.data.reward.credits)
        accomplish()
        return
    end

    if not craft:getCaptain() then
        crew:setCaptain(captain)
    else
        -- add captain as passenger
        crew:addPassenger(captain)
    end

    -- end mission
    accomplish()
end)

function onShowCredentials()
    -- create window that shows captain tooltip
    window = CaptainUtility.makeCredentialsWindow(captain)
    window:show()
    Hud():addMouseShowingWindow(window)
end

function makeStationDialogFull()
    local dialog = {}
    local dialog_1 = {}
    local dialog_2 = {}
    local dialog_3 = {}
    local dialog_4 = {}
    local dialog_5 = {}

    dialog.text = "Yes! Nice work! And perfect timing!\n\nThose pirates kidnapped us and locked us up, who knows what they would have done to us!\n\nWe just broke out of our cells and took control of the station. Thank you for distracting those pirates!"%_t
    dialog.answers = {{answer = string.format("I'm looking for ${name}."%_t % {name = mission.data.arguments.captain.name}), followUp = dialog_1}}

    dialog_1.text = "That's me! I've led the riot here. Thank you so much for your help."%_t
    dialog_1.answers = {{answer = "Sure, no problem."%_t, followUp = dialog_2}}

    dialog_2.text = "Why exactly are you looking for me?"%_t
    dialog_2.answers = {{answer = string.format("${name} is looking for you."%_t % {name = mission.data.arguments.client}), followUp = dialog_3}}

    dialog_3.text = string.format("Ah ${name}, he always has my back. I'll contact him immediately!"%_t % {name = mission.data.arguments.client})
    dialog_3.followUp = dialog_4

    dialog_4.text = "Now the question is, how will I get off this station now? They destroyed my ship!\n\nHey you know what, you seem awesome, do you happen to be in need of a captain?\n\nI just need to settle some affairs, but that should be easy if you let me have the reward for finding me."%_t
    dialog_4.answers = {
        {answer = "Can I see your credentials?"%_t, followUp = dialog_5},
        {answer = "Sorry, I need the money myself."%_t, onSelect = onNotInterestedSelected}
    }

    dialog_5.text = "Sure thing, here you go!"%_t
    dialog_5.onEnd = "onShowCredentials"

    return dialog
end

function makeStationDialogOnReturn()
    local dialog = {}

    dialog.text = "Hi! You came back. Everything ready now?"%_t
    if canTakeCaptain() then
        dialog.answers = {
            {answer = "Yes, welcome aboard!"%_t, onSelect = onTakeCaptainSelected},
            {answer = "Let me get my ship."%_t},
            {answer = "Sorry, I need the money myself."%_t, onSelect = onNotInterestedSelected}
        }
    else
        dialog.answers = {
            {answer = "Let me get my ship."%_t},
            {answer = "Sorry, I need the money myself."%_t, onSelect = onNotInterestedSelected}
        }
    end

    return dialog
end

local onLetMeGetMyShip = makeDialogServerCallback("onLetMeGetMyShip", 5, function()
    mission.data.description[6].visible = true
    mission.data.description[6].arguments = {name = captain.name, x = mission.data.location.x, y = mission.data.location.y}
    sync()
end)

function makeDecisionDialog()
    local dialog = {}
    local dialog_2 = {}
    dialog.text = "What do you think? /* Respectfully asking player */"%_t

    -- offer player a "think about it"-option if he can't take captain now
    if not canTakeCaptain() then
        dialog.answers = {
            {answer = "Let me get my ship."%_t, followUp = dialog_2},
            {answer = "Sorry, I need the money myself."%_t, onSelect = onNotInterestedSelected}
        }

        dialog_2.text = "Oh sure, I'll be waiting here. Come back once everything is ready!"%_t
        dialog_2.onEnd = onLetMeGetMyShip
    else
        dialog.answers = {
            {answer = "Welcome aboard!"%_t, onSelect = onTakeCaptainSelected},
            {answer = "Sorry, I need the money myself."%_t, onSelect = onNotInterestedSelected}
        }
    end

    return dialog
end

function canTakeCaptain()
    local craft = Player().craft
    if not craft then return false end
    if not CrewComponent(craft) then return false end

    return true
end

function startStationDialog(withIntro)
    local dialog = {}
    if withIntro then
        dialog = makeStationDialogOnReturn()
    else
        dialog = makeStationDialogFull()
    end

    ScriptUI(mission.data.custom.stationId):interactShowDialog(dialog, false)
end

function onClosePressed()
    window:hide()
    ScriptUI(mission.data.custom.stationId):interactShowDialog(makeDecisionDialog(), false)
end

-- helper functions
-------------------
function resetToPhase(index, newLocation)
    if onClient() then return end

    if newLocation then
        local insideBarrier = MissionUT.checkSectorInsideBarrier(mission.data.location.x, mission.data.location.y)
        local x, y = MissionUT.getSector(mission.data.location.x, mission.data.location.y, 3, 8, false, false, false, false, insideBarrier)
        mission.data.location = {x = x, y = y}
    end

    mission.data.targets = {}

    if index == 1 then
        for i = 2, #mission.data.description do
            mission.data.description[i].fulfilled = false
            mission.data.description[i].visible = false
        end

        setPhase(index)
    end

    if index == 3 then
        for i = 4, #mission.data.description do
            mission.data.description[i].fulfilled = false
            mission.data.description[i].visible = false
        end

        currentWave = 1
        spawnWave = {}
        waveSpawned = {}
        mission.data.custom.location = mission.data.location
        dialogStarted = false

        setPhase(index)
    end

    if index == 5 then
        dialogStarted = false

        if not captain then
            captain = generateCaptain()
        end

        mission.data.description[6].visible = true
        mission.data.description[6].arguments = {name = captain.name, x = mission.data.location.x, y = mission.data.location.y}

        sync() -- sync manually here as we don't change phase

        setPhase(index)
    end
end

function spawnMissionWreckage()
    local sector = Sector()
    local entity = sector:getEntitiesByScriptValue("captainmission_wreckage")
    if entity then return entity end -- already existing, no need to generate a new one

    local x, y = sector:getCoordinates()
    local generator = SectorGenerator(x, y)

    -- ambient asteroid field
    local pos, asteroids = generator:createAsteroidField(0.075);
    sector:addScriptOnce("sector/deleteentitiesonplayersleft.lua", {EntityType.Asteroid})

    -- wreckage
    local faction = Galaxy():getNearestFaction(x, y)
    local wreckage = generator:createWreckage(faction, nil, 0)
    wreckage:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
    wreckage:removeScript("data/scripts/entity/story/captainslogs.lua")
    wreckage:addScriptOnce("data/scripts/entity/story/storyhintwreckage.lua")
    wreckage:setValue("captainmission_wreckage", true)
    mission.data.custom.wreckageId = wreckage.id.string

    return wreckage
end

function spawnPirateStation()
    local sector = Sector()
    local station = sector:getEntitiesByScriptValue("captainmission_station", true)
    if valid(station) then return end

    local x, y = sector:getCoordinates()
    local generator = SectorGenerator(x, y)
    local faction = ASyncPirateGenerator():getPirateFaction()

    local productionToUse
    for _, production in pairs(productions) do
        for _, result in pairs(production.results) do
            if result.name == "Coal" then
                productionToUse = production
                break
            end
        end
    end

    -- create mine
    local mine = generator:createStation(faction, "data/scripts/entity/merchants/factory.lua", productionToUse);
    mission.data.custom.stationId = mine.id.string
    mine:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
    mine:addScriptOnce("data/scripts/entity/utility/basicinteract.lua")
    mine:setValue("captainmission_station", true)
    mine.invincible = true

    -- remove normal station behavior
    mine:setValue("no_chatter")
    mine:removeScript("data/scripts/entity/bulletinboard.lua")
    mine:removeScript("data/scripts/entity/missionbulletins.lua")
    mine:removeScript("data/scripts/entity/story/bulletins.lua")
    mine:removeScript("data/scripts/entity/crewboard.lua")
    mine:removeScript("data/scripts/entity/merchants/factory.lua")

    return mine
end

function onPirateWaveGenerated(pirates)
    for _, pirate in pairs(pirates) do
        pirate:setValue("is_wave", true)
        pirate:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
    end

    Placer.resolveIntersections()

    waveSpawned[currentWave] = true
end

-- generate increasing random number in the format of 03-455
function getRandomLogNumbers()
    local results = {}
    local numbers = "0123456789"

    local n1 = random():getInt(1, 4)
    local n2 = random():getInt(5, #numbers)
    local n3 = random():getInt(1, #numbers)
    local firstSection = "" .. numbers:sub(n1, n1) .. numbers:sub(n2, n2) .. "-" .. numbers:sub(n3, n3)

    local old = 10
    for i = 1, 3 do
        local secondSection = random():getInt(old, math.min(old + 10, 100))
        old = secondSection
        local combination = firstSection .. tostring(secondSection)
        table.insert(results, combination)
    end

    return results
end

function generateCaptain()
    -- seed either from remembered seed, or if old version of this mission is active only the client name as a fallback
    local seed = Seed(mission.data.arguments.client)
    local tier = mission.data.arguments.captain.tier
    local level = mission.data.arguments.captain.level
    local primaryClass = mission.data.arguments.captain.primaryClass
    local secondaryClass = mission.data.arguments.captain.secondaryClass
    local captain = CaptainGenerator(seed):generate(tier, level, primaryClass, secondaryClass)

    if captain.name ~= mission.data.arguments.captain.name then
        captain.name = mission.data.arguments.captain.name -- here for safety, shouldn't be needed
    end

    return captain
end


-- bulletin
-----------
function calculateReward(salary)
    -- round reward to a more logic number
    local reward = (salary or 50000)

    if reward > 10000 then
        reward = round(reward / 10000) * 10000
    elseif reward > 1000 then
        reward = round(reward / 1000) * 1000
    elseif reward > 100 then
        reward = round(reward / 100) * 100
    end

    return reward
end

function getClassFromStation(station)
    local title = station.title
    if title == "Smuggler's Market" or title == "Smuggler Hideout" then
        return CaptainUtility.ClassType.Smuggler
    end

    if title == "Military Outpost" then
        return CaptainUtility.ClassType.Commodore
    end

    if title == "Trading Post" then
        return CaptainUtility.ClassType.Merchant
    end

    if string.match(title, " Mine") then
        return CaptainUtility.ClassType.Miner
    end

    if title == "Scrapyard" then
        return CaptainUtility.ClassType.Scavenger
    end

    if title == "Research Station" then
        return CaptainUtility.ClassType.Explorer
    end

    if title == "Resistance Outpost" then
        return CaptainUtility.ClassType.Hunter
    end

    if title == "Rift Research Center" then
        return CaptainUtility.ClassType.Scientist
    end

    if title == "Casino" or title == "Habitat" then
        return CaptainUtility.ClassType.Daredevil
    end

    return nil
end

mission.makeBulletin = function(station)
    -- find empty sector
    local target = {}

    local x, y = Sector():getCoordinates()
    local giverInsideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    target.x, target.y = MissionUT.getSector(x, y, 15, 17, false, false, false, false)

    if not target.x or not target.y or giverInsideBarrier ~= MissionUT.checkSectorInsideBarrier(target.x, target.y) then return end
    mission.data.location = target

    -- generate a client
    local language = Language(random():createSeed())
    local client = language:getName()

    -- generate captain (needed to know salary)
    local primaryClass = getClassFromStation(station)
    local seed = Seed(client)
    local captain = CaptainGenerator(seed):generate(3, nil, primaryClass, nil) -- explicitly tier 3
    if not captain then return end

    -- abort if client is looking for himself
    if captain.name == client then return end

    -- reward
    credits = calculateReward(captain.salary)

    local classProperties = CaptainUtility.ClassProperties()[captain.primaryClass]
    local genderedClass = classProperties.untranslatedName
    if captain.genderId == CaptainGenderId.Female then
        genderedClass = classProperties.untranslatedNameFemale
    end

    local age = math.random(35, 120)

    -- add prosa text to entice the player
    if captain.genderId == CaptainGenderId.Male then
        missionDescription = "Missing:\nName: ${displayName}\nProfession: ${class}\nAge: ${age}\nLast Known Location: (${x}:${y})\n\nIt's been a while since I've last had word from my good friend ${displayName}. Usually he checks in with me regularly. I'm worried that something bad might have happened to him. The only clue I have to go on is his last message that he was on his way to sector (${x}:${y}). Please help me find my friend!\n\nAnyone who can lead me towards him will receive a reward of ${reward}¢!\n\n${client}"%_t
    else
        missionDescription = "Missing:\nName: ${displayName}\nProfession: ${class}\nAge: ${age}\nLast Known Location: (${x}:${y})\n\nIt's been a while since I've last had word from my good friend ${displayName}. Usually she checks in with me regularly. I'm worried that something bad might have happened to her. The only clue I have to go on is her last message that she was on her way to sector (${x}:${y}). Please help me find my friend!\n\nAnyone who can lead me towards her will receive a reward of ${reward}¢!\n\n${client}"%_t
    end


    local bulletin =
    {
        -- data for the bulletin board
        brief = mission.data.brief,
        title = mission.data.title,
        icon = mission.data.icon,
        description = missionDescription,
        difficulty = "Difficult /*difficulty*/"%_T,
        reward = "¢${reward}"%_T,
        script = "missions/receivecaptainmission.lua",
        formatArguments = {displayName = captain.displayName, class = genderedClass, age = age, client = client, x = target.x, y = target.y, reward = createMonetaryString(credits)},
        msg = "Check the last known location of the missing person in \\s(%2%:%3%)."%_T,
        onAccept = [[
            local self, player = ...
            player:sendChatMessage(Entity(self.arguments[1].giver), 0, self.msg, self.formatArguments.displayName, self.formatArguments.x, self.formatArguments.y)
        ]],

        -- data that's important for the mission
        arguments = {{
            giver = station.id,
            location = target,
            reward = credits,
            client = client,
            captain = {name = captain.displayName, genderId = captain.genderId, className = genderedClass, tier = captain.tier, level = captain.level, primaryClass = captain.primaryClass, secondaryClass = captain.secondaryClass}
        }},
    }
    return bulletin
end
