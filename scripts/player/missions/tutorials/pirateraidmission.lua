package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")
local MissionUT = include("missionutility")
local WaveUtility = include ("waveutility")
local Placer = include ("placer")

-- mission.tracing = true

mission.data.brief = "Pirate Raid"%_T
mission.data.title = "Pirate Raid"%_T
mission.data.icon = "data/textures/icons/graduate-cap.png"
mission.data.priority = 5

mission.data.description = {}
mission.data.description[1] = {text = "Improve your ship to prepare for a fight. Tips from ${name}, the Adventurer."%_T}
mission.data.description[2] = {text = "Read the Adventurer's mail"%_T, bulletPoint = true}
mission.data.description[3] = {text = "Build enough integrity field generators to reach a coverage of over 90%"%_T, bulletPoint = true, fulfilled = false, visible = false}
mission.data.description[4] = {text = "Increase your ship's size and processing power with functional blocks until it supports at least 4 subsystem slots"%_T, bulletPoint = true, fulfilled = false, visible = false}
mission.data.description[5] = {text = "Add enough offensive turrets to reach a firepower of 60 Omicron (DPS) or more"%_T, bulletPoint = true, fulfilled = false, visible = false}
mission.data.description[6] = {text = "Defeat the pirates in sector (${x}:${y})"%_T, bulletPoint = true, fulfilled = false, visible = false}


mission.globalPhase.noBossEncountersTargetSector = true
mission.globalPhase.noPlayerEventsTargetSector = true
mission.globalPhase.noLocalPlayerEventsTargetSector = true

-- phase 1: introduce mission
mission.phases[1] = {}
mission.phases[1].onBeginServer = function()
    mission.data.description[1].arguments = {name = MissionUT.getAdventurerName()}
    sendIntroductionMail()
end
mission.phases[1].playerCallbacks =
{
    {
        name = "onMailRead",
        func = function(playerIndex, mailIndex, mailId)
            if mailId == "PirateRaidMail" then
                setPhase(2)
            end
        end
    }
}
mission.phases[1].showUpdateOnEnd = true

-- phase 2: build ship
mission.phases[2] = {}
mission.phases[2].onBegin = function()
    mission.data.description[2].fulfilled = true

    mission.data.description[3].visible = true
    mission.data.description[4].visible = true
    mission.data.description[5].visible = true
end
mission.phases[2].updateServer = function()
    -- regularly check as well
    -- turrets build onto the ship don't trigger callbacks down below
    checkShipProperties()
end
mission.phases[2].updateInterval = 3
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].playerEntityCallbacks = {}
mission.phases[2].playerEntityCallbacks[1] =
{
    name = "onPlanModifiedByBuilding",
    func = function()
        if onServer() then
            checkShipProperties()
        end
    end
}
mission.phases[2].playerEntityCallbacks[2] =
{
    name = "onShipChanged",
    func = function()
        if onServer() then
            checkShipProperties()
        end
    end
}

-- values to control wave encounter (used in phase 3 and 4)
local currentWave = 1
local spawnWave = {}
local waveSpawned = {}

-- phase 3: move to target sector
mission.phases[3] = {}
mission.phases[3].onBegin = function()
    mission.data.description[3].fulfilled = true
    mission.data.description[4].fulfilled = true
    mission.data.description[5].fulfilled = true
end
mission.phases[3].updateServer = function()
    checkShipProperties()
end
mission.phases[3].updateInterval = 5
mission.phases[3].onTargetLocationEntered = function()
    if onClient() then return end

    initWaveEncounter()
    nextPhase()
end

-- phase 4: fight
mission.phases[4] = {}
mission.phases[4].showUpdateOnStart = true
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

    -- count pirates and initiate spawning if necessary
    if waveSpawned[currentWave] and WaveUtility.getNumEnemies() <= 2 then
        if currentWave == 1 then
            spawnWave[currentWave] = true
        elseif currentWave == 2 then
            spawnWave[currentWave] = true
        end
    end

    -- last wave was defeated
    if waveSpawned[3] and WaveUtility.getNumEnemies() == 0 then
        setPhase(5)
    end
end
mission.phases[4].onSectorLeft = function()
    resetToPhase(2)
end
mission.phases[4].onRestore = function()
    resetToPhase(2, true)
end

-- phase 5: First show "Sector cleared" then "Mission accomplished"
mission.phases[5] = {}
mission.phases[5].onBegin = function()
    if onServer() then
        deferredCallback(1.5, "accomplish")
        Player():setValue("tutorial_pirateraid_accomplished", true)
    else
        displayMissionAccomplishedText("SECTOR CLEARED"%_T, "")
        playSound("interface/mission-accomplished", SoundType.UI, 1)
    end
end


-- mail
function sendIntroductionMail()
    local player = Player()
    local name = MissionUT.getAdventurerName()

    local mail = Mail()
    mail.text = Format("Hello!\n\nI’ve been told you met some pirates. I’m not surprised, the galaxy is infested with them. The local factions and I would be very happy if you help to defeat as many of them as you can.\n\nI’ve attached some instructions on how to boost your ship’s strength. As soon as your ship is ready for a fight, you should test it. Remember those pirates that shot your ship to pieces? I think they would make a perfect first target.\n\nGreetings,\n%1%"%_T, name)
    mail.header = "Pirate Trouble? /* Mail Subject */"%_T
    mail.sender = Format("%1%, the Adventurer"%_T, name)
    mail.id = "PirateRaidMail"

    player:addMail(mail)
end

-- check ship properties and advance mission if all are met
-- updates description to let player know what is already fulfilled
function checkShipProperties()
    local integrityFulfilled = false
    local slotsFulfilled = false
    local firepowerFulfilled = false

    -- check only for ships
    local player = Player()
    local craft = player.craft
    if craft and craft.isShip then
        -- fire power
        firepowerFulfilled = craft.firePower >= 60

        -- integrity
        local plan = Plan(craft.id)
        if plan:getNumBlocks(BlockType.IntegrityGenerator) > 0 then
            local integrity = StructuralIntegrity(craft)
            local protected = {integrity:getProtectedBlocks()}
            if protected and #protected > 0 then
                local numHoloBlocks = plan:getNumBlocks(BlockType.Holo) + plan:getNumBlocks(BlockType.HoloCorner)
                                        + plan:getNumBlocks(BlockType.HoloEdge) + plan:getNumBlocks(BlockType.HoloFlatCorner)
                                        + plan:getNumBlocks(BlockType.HoloInnerCorner) + plan:getNumBlocks(BlockType.HoloOuterCorner)
                                        + plan:getNumBlocks(BlockType.HoloTwistedCorner1) + plan:getNumBlocks(BlockType.HoloTwistedCorner2)

                -- calculate amount of blocks without holos (holos can't be protected)
                local numBlocks = plan.numBlocks - numHoloBlocks
                if #protected > 0.9 * numBlocks then
                    integrityFulfilled = true
                end
            end
        end

        -- sybsystem sockets
        local shipSystem = ShipSystem(craft.id)
        if shipSystem then
            slotsFulfilled = shipSystem.numSockets >= 4
        end
    end

    -- check if we have to sync description
    local syncNeeded = false
    if mission.data.description[3].fulfilled ~= integrityFulfilled
        or mission.data.description[4].fulfilled ~= slotsFulfilled
        or mission.data.description[5].fulfilled ~= firepowerFulfilled then

        syncNeeded = true
    end

    if integrityFulfilled and slotsFulfilled and firepowerFulfilled then
        if mission.internals.phaseIndex == 2 then
            -- ready to fight
            -- don't reset location, if location is already set
            if not mission.data.location.x then
                mission.data.location = findTargetLocation()
            end
            mission.data.description[6].arguments = {x = mission.data.location.x, y = mission.data.location.y}
            mission.data.description[6].visible = true

            setPhase(3)
            syncNeeded = false -- no double sync
        elseif mission.internals.phaseIndex == 3 then
            if MissionUT.playerInTargetSector(player, mission.data.location) then
                initWaveEncounter()
                nextPhase()
            end
        end
    else
        if mission.internals.phaseIndex == 3 then
            -- we lost something => go back to building stage
            resetToPhase(2)
            syncNeeded = false -- no double sync
        end
    end

    if syncNeeded then
        -- update description
        mission.data.description[3].fulfilled = integrityFulfilled
        mission.data.description[4].fulfilled = slotsFulfilled
        mission.data.description[5].fulfilled = firepowerFulfilled
        sync()
    end
end

function findTargetLocation()
    local location = {}

    -- find empty sector close by
    local cx, cy = Sector():getCoordinates()
    local x, y = MissionUT.getSector(cx, cy, 7, 9, false, false, false, false, MissionUT.checkSectorInsideBarrier(cx, cy))
    location = {x = x, y = y}
    return location
end

-- spawn helper
function onPirateWaveGenerated(pirates)
    for _, pirate in pairs(pirates) do
        pirate:setValue("is_wave", true)
        pirate:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
    end

    Placer.resolveIntersections()

    waveSpawned[currentWave] = true
end

-- reset
function resetToPhase(index, newSector)
    if onClient() then return end

    if newSector then
        local insideBarrier = MissionUT.checkSectorInsideBarrier(mission.data.location.x, mission.data.location.y)
        local x, y = MissionUT.getSector(mission.data.location.x, mission.data.location.y, 3, 8, false, false, false, false, insideBarrier)
        mission.data.location = {x = x, y = y}
    end

    if index == 2 then
        for i = 3, #mission.data.description do
            mission.data.description[i].fulfilled = false
            mission.data.description[i].visible = false
        end

        currentWave = 1
        spawnWave = {}
        waveSpawned = {}
        mission.data.custom.location = mission.data.location
        mission.data.custom.waves = nil

        setPhase(index)
    end
end

function initWaveEncounter()
    -- initiate pirate wave encounter
    mission.data.custom.waves = WaveUtility.getWaves(3, 3, 1, 3, 1)
    WaveUtility.createPirateWave(nil, mission.data.custom.waves[1], onPirateWaveGenerated)
end

