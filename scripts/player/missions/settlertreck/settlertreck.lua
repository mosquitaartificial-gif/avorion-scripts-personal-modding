package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("structuredmission")
include ("utility")
include ("defaultscripts")
include ("productions")
include ("callable")
include("randomext")

local Balancing = include ("galaxy")
local AsyncShipGenerator = include ("asyncshipgenerator")
local AsyncPirateGenerator = include("asyncpirategenerator")
local SpawnUtility = include ("spawnutility")

mission.data.timeLimit = 3600
mission.data.timeLimitInDescription = true

mission.data.title = "Settler Trek"%_t
mission.data.brief = "Protection of a settler trek"%_t

mission.data.autoTrackMission = true

mission.data.accomplishMessage = "Thank you for your help! Now that the pirates are finally gone we can found our colony in peace."%_t
mission.data.finishMessage = "Our hopes to colonize this sector are gone with our settlers. We will try to expand our realm in another direction."%_t
mission.data.failMessage = "You failed to protect our helpless settlers. They trusted you! But you left them as prey for the pirates!"%_t

mission.data.description = {}

mission.globalPhase = {}
mission.globalPhase.onBeginServer = function()
    local faction = Faction(mission.data.giver.factionIndex)
    local playCount = faction:getValue("settler_treck_played_count") or 0
    faction:setValue("settler_treck_played_count", playCount + 1)

    mission.phases[3].factionVanquishChecks[1].factionIndex = mission.data.giver.factionIndex

    mission.data.description[1] = {text = "${faction} is trying to found a colony in sector (${x}:${y}). The settlers report that they are under constant attacks by pirates. You have been hired to protect the settlers from further attacks."%_t, arguments = {x = mission.data.location.x, y = mission.data.location.y, faction = Faction(mission.data.giver.factionIndex).name}}
end

mission.globalPhase.factionVanquishChecks = {}
mission.globalPhase.factionVanquishChecks[1] =
    {
        callback = function(contributors)
            punish()
            fail()
        end
    }

mission.phases[1] = {}
mission.phases[1].onTargetLocationEntered = function (x, y)
    if onClient() then return end

    createSettlers()
    nextPhase()
end

mission.phases[2] = {}
mission.phases[2].triggers = {}
mission.phases[2].triggers[1] =
{
    condition = function() return checkSettlerCreated() end,
    callback = function() showInitialSettlerDialog() end
}

mission.phases[3] = {}
mission.phases[3].onTargetLocationLeft = function() punish() fail() end
mission.phases[3].timers = {}
if onServer() then
mission.phases[3].timers[1] = {time = 7, callback = function() createPirates(onFirstWaveSpawned) end}
mission.phases[3].timers[2] = {callback = function() createPirates(onSecondWaveSpawned) end}
end
mission.phases[3].triggers = {}
mission.phases[3].triggers[1] =
    {
        condition = function()
            if not mission.data.custom.firstWaveSpawned then return false end

            if MissionUT.countPirates() <= (0.5 * mission.data.custom.numPirates) then return true end
        end,
        callback = function()
            if onServer() then mission.phases[3].timers[2].time = 10 end
        end,
    }
mission.phases[3].triggers[2] =
    {
        condition = function()
            if not (mission.data.custom.firstWaveSpawned and mission.data.custom.secondWaveSpawned) then return false end

            x, y = Sector():getCoordinates()
            if x == mission.data.location.x and y == mission.data.location.y and MissionUT.countPirates() == 0 then return true end
        end,
        callback = function()
            reward()
            accomplish()
        end,
    }

mission.phases[3].factionVanquishChecks = {}
mission.phases[3].factionVanquishChecks[1] =
{
    callback = function(contributors)
        punish()
        fail()
    end
}

function createSettlers()
    local faction = Faction(mission.data.giver.factionIndex)

    local dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
    local up = vec3(0, 1, 0)
    local right = normalize(cross(dir, up))
    local pos = dir * 1000
    local distance = 50

    local generator = AsyncShipGenerator(nil, onCreated)

    generator:startBatch()

    freighterNumber = random():getInt(2, 3)
    for i = 1, freighterNumber do
        generator:createFreighterShip(faction, MatrixLookUpPosition(-dir, up, pos + right * distance * (i - 1)))
    end

    generator:endBatch()

end

function onCreated(ships)
    for _, ship in pairs(ships) do
        ship:addScriptOnce("ai/patrol.lua")
        ship:addScriptOnce("player/missions/settlertreck/transformonplayersleft.lua")

        if not mission.data.custom.settlerId then mission.data.custom.settlerId = ship.id.string end
    end

    sync()
end

function checkSettlerCreated()
    if onServer() then return false end

    local settler
    if mission.data.custom.settlerId then
        settler = Entity(mission.data.custom.settlerId)
    end

    return settler ~= nil
end

function showInitialSettlerDialog()
    if onServer() then return end

    local dialog = makeInitialSettlerDialog()
    local scriptUI = ScriptUI(mission.data.custom.settlerId)
    scriptUI:interactShowDialog(dialog, false)
end

function makeInitialSettlerDialog()
    local d0_HeyWeAreTryingT = {}

    d0_HeyWeAreTryingT.text = "We're so happy you're here! Pirates are attacking us all the time. We've already lost so many friends! Please help us to get rid of those vicious criminals! Your are our only hope! \n\nI think they're coming back..."%_t
    d0_HeyWeAreTryingT.answers = {
        {answer = "I will protect you!"%_t}
    }
    d0_HeyWeAreTryingT.onEnd = "initialSettlerDialogFinished"

    return d0_HeyWeAreTryingT
end

function initialSettlerDialogFinished()
    if onClient() then
        invokeServerFunction("initialSettlerDialogFinished")
        return
    end

    nextPhase()
end
callable(nil, "initialSettlerDialogFinished")

function createPirates(callback)
    local dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
    local up = vec3(0, 1, 0)
    local right = normalize(cross(dir, up))
    local pos = dir * 1000
    local distance = 150

    local generator = AsyncPirateGenerator(nil, callback)

    local numPirates = random():getInt(4, 5)
    mission.data.custom.numPirates = numPirates

    generator:startBatch()

    if mission.data.custom.firstWaveSpawned then
        generator:createScaledBoss(MatrixLookUpPosition(-dir, up, pos + right))
        numPirates = random():getInt(1, 2)
    end

    for i = 1, numPirates do
        if i <= 1 then
            generator:createScaledPirate(MatrixLookUpPosition(-dir, up, pos + right * distance * i))
        else
            generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos + right * distance * i))
        end
    end


    generator:endBatch()
end

function onFirstWaveSpawned(generated)

    -- add enemy buffs
    SpawnUtility.addEnemyBuffs(generated)

    mission.data.custom.firstWaveSpawned = true
end

function onSecondWaveSpawned(generated)

    -- add enemy buffs
    SpawnUtility.addEnemyBuffs(generated)

    mission.data.custom.secondWaveSpawned = true
end

-- used for testing
function countPirates()
    return MissionUT.countPirates()
end


mission.makeBulletin = function(station)
    -- check if mission is possible
    local faction = Faction(station.factionIndex)
    if not faction then return end
    local traits =
    {
        "opportunistic",
        "brave",
        "greedy",
    }

    local traitFound = false
    for _, trait in pairs(traits) do
        if faction:getTrait(trait) > 0.8 then
            traitFound = true
            break
        end
    end

    if not traitFound then return end

    -- check if mission has already happened
    local playCount = faction:getValue("settler_treck_played_count")
    if playCount and playCount >= 2 then return end

    -- find empty sector
    local target = {}
    local x, y = Sector():getCoordinates()
    local giverInsideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    target.x, target.y = MissionUT.getSector(x, y, 5, 8, false, false, false, false)

    if not target.x or not target.y or giverInsideBarrier ~= MissionUT.checkSectorInsideBarrier(target.x, target.y) then return end

    local balancing = Balancing.GetSectorRewardFactor(Sector():getCoordinates())
    reward = {credits = 60000 * balancing, relations = 6000, paymentMessage = "Earned %1% Credits for protecting settlers from pirates"%_t}
    local materialAmount = round(random():getInt(7000, 8000) / 100) * 100
    MissionUT.addSectorRewardMaterial(x, y, reward, materialAmount)

    punishment = {relations = reward.relations}

    local bulletin =
    {
        -- data for the bulletin board
        brief = mission.data.brief,
        description = "We sent out a group of settlers to colonize new sectors. They safely arrived at the sector they want to settle in, but are under constant attack. They need help to survive!"%_t,
        title = mission.data.title,
        difficulty = "Medium /*difficulty*/"%_t,
        reward = "¢${reward}"%_t,
        script = "missions/settlertreck/settlertreck.lua",
        formatArguments = {x = target.x, y = target.y, reward = createMonetaryString(reward.credits)},
        msg = "Go to \\s(%1%:%2%) to protect our settlers."%_T,
        giverTitle = station.title,
        giverTitleArgs = station:getTitleArguments(),
        onAccept = [[
            local self, player = ...
            player:sendChatMessage(Entity(self.arguments[1].giver), 0, self.msg, self.formatArguments.x, self.formatArguments.y)
        ]],

        -- data that's important for our own mission
        arguments = {{
            giver = station.id,
            location = target,
            reward = reward,
            punishment = punishment,
        }},
    }

    return bulletin
end
