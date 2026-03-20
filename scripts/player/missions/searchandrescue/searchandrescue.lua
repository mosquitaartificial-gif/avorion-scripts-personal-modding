package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("structuredmission")
include ("galaxy")
local SectorGenerator = include ("SectorGenerator")
local Balancing = include ("galaxy")
local PlanGenerator = include ("plangenerator")
local SectorTurretGenerator = include ("sectorturretgenerator")
local UpgradeGenerator = include ("upgradegenerator")

include ("callable")
include("randomext")

-- mission.tracing = true

mission.data.title = "Search and Rescue"%_t
mission.data.brief = "Search and Rescue"%_t
mission.data.description = {}
mission.data.description[1] = "You received an emergency call from an unknown source. Your ship's sensors were unable to trace their exact position, but it produced these possible locations:"%_t

mission.data.failMessage = "The flight recorder was destroyed."%_t
mission.data.reward = {credits = (math.random() * 50000 + 10000), relations = 6000}

mission.data.custom.locations = {}
mission.data.custom.numLocations = 0
mission.data.custom.wreckagePieceIds = {}
mission.data.custom.faction = nil
mission.data.custom.staticMessages =
{
    "CHRRK....Mayday, mayd....CHRRRRK....explosion...CHRRK....Need help....CHRRK"%_t,
    "Hello?...Can you....CHRRK...Can you hear us?...CHHRRK....Emergency"%_t,
    "This is.....emergency call.....CHRRRK....life threatening situation....."%_t,
    "CHRRK....Lost.....Navigate....CHRRRK.....immediate help.....someone...CHRRRK"%_t,
}
mission.data.custom.clearMessages =
{
    "Mayday, mayday! We had an explosion. We need help as fast as possible!"%_t,
    "Hello? Can you hear us? Can you hear us? We are having an emergency. Help us please!"%_t,
    "This is an emergency call. We are in a life-threatening situation. Please help us!"%_t,
    "We lost our ability to navigate and we need immediate help. Is someone out there?"%_t,
}

mission.getRewardedItems = function()

    local x, y = Sector():getCoordinates()
    if random():test(0.5) then
        local generator = SectorTurretGenerator()
        generator.minRarity = Rarity(RarityType.Exceptional)

        return InventoryTurret(generator:generate(x, y, 0))
    else
        local generator = UpgradeGenerator()
        generator.minRarity = Rarity(RarityType.Exceptional)

        return generator:generateSectorSystem(x, y)
    end
end

-- phase 1: Player gets first chat message => calculates the where and adds it and some deceiving coords to the description
mission.phases[1] = {}
mission.phases[1].onBeginServer = function()

    local currentX, currentY = Sector():getCoordinates()
    local startInsideBarrier = MissionUT.checkSectorInsideBarrier(currentX, currentY)
    -- update description
    mission.data.custom.locations = createMissionLocations()
    for k, coords in pairs(mission.data.custom.locations) do
        local targetInsideBarrier = MissionUT.checkSectorInsideBarrier(coords.x, coords.y)
        if startInsideBarrier ~= targetInsideBarrier then return end

        mission.data.description[k + 1] = {text = "(${x}:${y})"%_T % {x = coords.x, y = coords.y}, bulletPoint = true, fulfilled = false}
    end

    -- add material to reward
    local materialAmount = round(random():getInt(7000, 8000) / 100) * 100
    MissionUT.addSectorRewardMaterial(currentX, currentY, mission.data.reward, materialAmount)

    -- send first chat message
    local player = Player()
    player:sendChatMessage("Unknown"%_t, 0, randomEntry(random(), mission.data.custom.staticMessages))
    player:sendChatMessage("", 3, "You have received an emergency signal from an unknown source."%_t)

    -- go to next phase
    nextPhase()
end

-- phase 2: Player needs to jump through marked sectors until he finds the right one
mission.phases[2] = {}
mission.phases[2].onSectorEntered = function()
    if onClient() then return end

    local player = Player()
    local x, y = Sector():getCoordinates()
    if enteredOneTargetLocation(x, y) then
        if enteredTheTargetLocation(x, y) then
            player:sendChatMessage("Unknown"%_t, 0, randomEntry(random(), mission.data.custom.clearMessages)) -- player found target sector

            -- grey out all coords and remove them as target locations => player doesn't have to move anymore
            for pos, coords in pairs(mission.data.custom.locations) do
                checkDescriptionBullet(pos + 1)
                mission.data.custom.locations = {}
                mission.data.custom.locations = {{x = x, y = y}}
            end

            -- change last sector description to search wreckage - player won't notice one of the coords missing and we know for sure that it won't break old saves
            mission.data.description[mission.data.custom.numLocations + 1] = {text = "Search the wreckage for information"%_T, bulletPoint = true, fulfilled = false, visible = true}
            mission.data.description[mission.data.custom.numLocations + 1].color = "\\c()"

            nextPhase()
        else
            player:sendChatMessage("Unknown"%_t, 0, randomEntry(random(), mission.data.custom.staticMessages)) -- player is on the right track
        end
    end
end

-- phase 3: Generate the wreckages to interact with
mission.phases[3] = {}
mission.phases[3].onBeginServer = function()
    createWreckage()
    nextPhase()
end

-- phase 4: Wait for player to talk to the wreck
mission.phases[4] = {}
mission.phases[4].showUpdateOnEnd = true

-- phase 5: Send player to deliver info
mission.phases[5] = {}
mission.phases[5].onBeginServer = function()
    -- remove highlight and target location
    mission.data.targets = {}
    mission.data.custom.locations = {}

    mission.data.description[mission.data.custom.numLocations + 1] = {text = "Find other members of ${faction} and tell them what you found out"%_T, arguments = {faction = Faction(mission.data.custom.factionId).name}, bulletPoint = true, fulfilled = false}
end
mission.phases[5].onStartDialog = function(entityId)
    -- player can deliver info to any ship or station of that faction

    local entity = Entity(entityId)
    if not entity then return end
    if entity.factionIndex ~= mission.data.custom.factionId then return end
    if not entity.isStation and not entity.isShip then return end

    ScriptUI(entityId):addDialogOption("I have news for you."%_t, "onDeliver")
end


-- helper functions
function createMissionLocations()
    local locations = {}
    local num = math.random(3, 6)
    mission.data.custom.numLocations = num
    local currentCoords = {}
    currentCoords.x, currentCoords.y = Sector():getCoordinates()

    -- this is the sector where the wreckage will be spawned, the others are just a diversion
    local firstX, firstY = MissionUT.getSector(currentCoords.x, currentCoords.y, 10, 15, false, false, false, false)
    table.insert(locations, {x = firstX, y = firstY})

    mission.data.custom.targetSector = {firstX, firstY}

    local count = 1
    while count < num do
        local x, y = MissionUT.getSector(firstX, firstY, 1, 8, false, false, false, false)

        -- don't take currentCoords as target sector
        if x == currentCoords.x and y == currentCoords.y then
            goto continue
        end

        -- check if we already have this sector in the list, if so repeat this run
        for _, coords in pairs(locations) do
            if coords.x == x and coords.y == y then goto continue end
        end

        -- these coords are new => we take them
        table.insert(locations, {x = x, y = y})
        count = count + 1

        ::continue::
    end

    shuffle(random(), locations)

    return locations
end

function createWreckage()
    if onClient() then return end
    local generator = SectorGenerator(Sector():getCoordinates())
    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    mission.data.custom.factionId = faction.index
    local plan = PlanGenerator.makeFreighterPlan(faction)
    plan:setBlockType(plan.rootIndex, BlockType.BlackBox)

    local wreckages = {generator:createWreckage(faction, plan, 0)}
    mission.data.custom.wreckagePieceIds = {}

    for _, w in pairs(wreckages) do
        local p = Plan(w.id)
        local block = p:getBlocksByType(BlockType.BlackBox)
        if block and #block > 0 then
            w:registerCallback("onDestroyed", "onWreckageDestroyed")
        end

        w:addScriptOnce("player/missions/searchandrescue/searchwreckage.lua")
        w:addScriptOnce("data/scripts/entity/utility/radiochatter.lua", mission.data.custom.clearMessages, 10, 10, 1, true)
        w:removeScript("captainslogs.lua")
        table.insert(mission.data.custom.wreckagePieceIds, w.id.string)

        mission.data.targets = {}
        table.insert(mission.data.targets, w.id)
    end
end

function onFoundDialogEnd(entityId)
    if onClient() then
        invokeServerFunction("onFoundDialogEnd", entityId)
        return
    end

    if mission.internals.phaseIndex ~= 4 then return end

    for _, id in pairs(mission.data.custom.wreckagePieceIds) do
        if id == entityId.string then
            -- player talked to our wreck
            nextPhase()
            return
        end
    end
end
callable(nil, "onFoundDialogEnd")

function onWreckageDestroyed()
    -- player destroyed the wreckage that contained black box
    -- this is pretty hard to achieve, so player most likely salvaged whole wreck to get into this situation
    fail()
end

function onDeliver(entityId)
    local dialog = {}
    dialog.text = "This is sad news. Thank you for letting us know. We transferred some money to your account for your troubles."%_t
    dialog.onEnd = "finishUp"
    ScriptUI(entityId):showDialog(dialog)
end

function finishUp()
    if onClient() then invokeServerFunction("finishUp") return end
    reward()
    accomplish()
end
callable(nil, "finishUp")

-- multiple marks on map
function getMissionLocation()
    local locations = {}
    for _, coordinates in pairs(mission.data.custom.locations) do
        table.insert(locations, ivec2(coordinates.x, coordinates.y))
    end

    return unpack(locations)
end

-- are we in one of the target sectors
function enteredOneTargetLocation(x, y)
    local locations = {getMissionLocation()}
    for pos, coords in pairs(locations) do
        if x == coords.x and y == coords.y then
            checkDescriptionBullet(pos+1)

            for i, targetLocation in pairs(mission.data.custom.locations) do
                if x == targetLocation.x and y == targetLocation.y then
                    mission.data.custom.locations[i] = nil
                end
            end

            return true
        end
    end
    return false
end

function enteredTheTargetLocation(x, y)
    local coords = mission.data.custom.targetSector

    if x == coords[1] and y == coords[2] then
        return true
    end
    return false
end

function checkDescriptionBullet(pos)
    if mission.data.description[pos] then
        mission.data.description[pos].color = "\\c(444)" -- mark as if done, but don't write "(done)"
    end
end
