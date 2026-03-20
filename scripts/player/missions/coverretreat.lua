package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("structuredmission")
include ("callable")
include ("relations")
include("randomext")

local Balancing = include ("galaxy")
local AsyncShipGenerator = include("asyncshipgenerator")
local SpawnUtility = include ("spawnutility")

mission.data.timeLimit = 1800
mission.data.timeLimitInDescription = true

mission.data.description = {}

mission.data.title = "Cover Retreat"%_t
mission.data.brief = "Help to cover the retreat of a fleet"%_t

mission.data.autoTrackMission = true

mission.data.accomplishMessage = "We secured the bulk of our fleet. We will gather our forces and strike back another time!"%_t
mission.data.finishMessage = "You fought well. We may have lost this battle, but we have not lost the war!"%_t
mission.data.failMessage = "Why are you running away? Our fleet is still in danger! We will lose the war, and it will be your fault!"%_t

mission.globalPhase = {}
mission.globalPhase.onBeginServer = function()
    mission.data.description[1] = {text = "After they have lost a crucial battle, ${faction} need help slowing down their opponent to bring their main fleet to safety.\n\nTheir rearguard is gathering in sector (${x}:${y}) in order to delay the enemy. Go there and support them."%_t, arguments = {faction = Faction(mission.data.giver.factionIndex).name, x = mission.data.location.x, y = mission.data.location.y}}
end
mission.globalPhase.onTargetLocationLeft = function(x, y)
    fail()
end
mission.globalPhase.onAccomplish = function()
    for _, ship in pairs({Sector():getEntitiesByFaction(mission.data.giver.factionIndex)}) do
        ship:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(3, 6))
    end
end

mission.globalPhase.onFail = function() punish() end

mission.phases[1] = {}
mission.phases[1].onTargetLocationEntered = function(x, y)
    createEnemyFleet()
    createFriendlyFleet()
    mission.data.timeLimit = nil
    mission.data.timeLimitInDescription = false
end
mission.phases[1].triggers = {}
mission.phases[1].triggers[1] =
    {
        condition = function() return checkFleetsCreated() end,
        callback = function() nextPhase() end
    }


mission.phases[2] = {}
mission.phases[2].onBegin = function()
    if onClient() then
        local friendlyFaction = Faction(mission.data.giver.factionIndex)
        local enemyFaction = Faction(mission.data.arguments.enemyFactionIndex)
        setRelationStatus(friendlyFaction, enemyFaction, RelationStatus.War, true, true)
        showMissionUpdated("Distract the enemy until the main fleet has gotten to safety."%_t)
    else
        mission.phases[2].factionVanquishChecks[1].factionIndex = mission.data.arguments.enemyFactionIndex
    end
end
mission.phases[2].timers = {}
mission.phases[2].timers[1] = {time = 300, callback = function() endMission() end}
if onServer() then
mission.phases[2].timers[2] =
    {
        time = 5,
        callback = function()
            for _, ship in pairs({Sector():getEntitiesByFaction(mission.data.giver.factionIndex)}) do
                if ship.type == EntityType.Ship then
                    Player():sendChatMessage(ship, ChatMessageType.Normal, "They were faster than expected! Help us engage their ships!"%_T)
                    return
                end
            end
        end
    }
end

mission.phases[2].factionVanquishChecks = {}
mission.phases[2].factionVanquishChecks[1] = {callback = function() endMission() end}

function getEnemyFactionIndex(factionIndex)
    local neighbors = MissionUT.getNeighboringFactions(factionIndex, 125)
    local faction = Faction(factionIndex)

    for _, neighbor in pairs(neighbors) do
        if faction:getValue("enemy_faction") == neighbor.index then
            return neighbor.index
        end
    end
end

function createEnemyFleet()
    if onClient() then return end

    local faction = Faction(mission.data.arguments.enemyFactionIndex)

    local onCreatedEnemy = function(ships)
        for _, ship in pairs(ships) do
            ShipAI(ship.id):setAggressive()
            ShipAI(ship.id):registerEnemyFaction(Player().index)
            ShipAI(ship.id):registerEnemyFaction(mission.data.giver.factionIndex)
            ship:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
            ship:setValue("coverretreat_ship", "enemy")
        end

        -- add enemy buffs
        SpawnUtility.addEnemyBuffs(ships)

        mission.data.custom.enemiesCreated = true
    end

    local generator = AsyncShipGenerator(nil, onCreatedEnemy)

    generator:startBatch()

    local fleetNumber = random():getInt(12, 14)
    local flagshipNumber = random():getInt(0, 1)
    local battleshipNumber = random():getInt(0, 2)
    local torpedoNumber = random():getInt(4, 6)

    for i = 1, fleetNumber do
        local look = random():getDirection()
        local up = vec3(0, 1, 0)
        local pos = vec3(random():getFloat(-500, 500), random():getFloat(-500, 500), random():getFloat(-500, 500))

        if flagshipNumber >= 1 then
            generator:createMilitaryShip(faction, MatrixLookUpPosition(look, up, pos))
            flagshipNumber = flagshipNumber - 1
        elseif battleshipNumber >= 1 then
            local volume = Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation()
            generator:createMilitaryShip(faction, MatrixLookUpPosition(look, up, pos), volume * 8)
            battleshipNumber = battleshipNumber - 1
        elseif torpedoNumber >= 1 then
            generator:createTorpedoShip(faction, MatrixLookUpPosition(look, up, pos))
            torpedoNumber = torpedoNumber - 1
        else
            generator:createMilitaryShip(faction, MatrixLookUpPosition(look, up, pos))
        end
    end

    generator:endBatch()
end

function createFriendlyFleet()
    if onClient() then return end

    local onCreatedFriendly = function(ships)
        for _, ship in pairs(ships) do
            ShipAI(ship.id):setAggressive()
            ShipAI(ship.id):registerEnemyFaction(mission.data.arguments.enemyFactionIndex)
            ship:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
            ship:setValue("coverretreat_ship", "ally")
        end

        mission.data.custom.friendsCreated = true
    end

    local faction = Faction(mission.data.giver.factionIndex)
    local generator = AsyncShipGenerator(nil, onCreatedFriendly)

    generator:startBatch()

    local fleetNumber = random():getInt(4, 6)
    local battleshipNumber = random():getInt(0, 2)
    local torpedoNumber = random():getInt(2, 4)

    for i = 1, fleetNumber do
        local look = random():getDirection()
        local up = vec3(0, 1, 0)
        local pos = vec3(random():getFloat(-500, 500), random():getFloat(-500, 500), random():getFloat(-500, 500))

        if battleshipNumber >= 1 then
            local volume = Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation()
            local ship = generator:createMilitaryShip(faction, MatrixLookUpPosition(look, up, pos), volume * 8)
            battleshipNumber = battleshipNumber - 1
        elseif torpedoNumber >= 1 then
            local ship = generator:createTorpedoShip(faction, MatrixLookUpPosition(look, up, pos))
            torpedoNumber = torpedoNumber - 1
        else
            local ship = generator:createMilitaryShip(faction, MatrixLookUpPosition(look, up, pos))
        end
    end

    generator:endBatch()

end


function checkFleetsCreated()
    return mission.data.custom.enemiesCreated and mission.data.custom.friendsCreated
end

function endMission()
    reward()
    accomplish()
end


mission.makeBulletin = function(station)
    if station.playerOwned then --[[ no coverretreat at player owned stations ]] return end

    local enemyFaction = getEnemyFactionIndex(station.factionIndex)
    if not enemyFaction then return end

    --find empty sector
    local target = {}
    local x, y = Sector():getCoordinates()
    local giverInsideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    target.x, target.y = MissionUT.getSector(x, y, 3, 6, false, false, false, false)

    if not target.x or not target.y or giverInsideBarrier ~= MissionUT.checkSectorInsideBarrier(target.x, target.y) then return end

    local balancing = Balancing.GetSectorRewardFactor(Sector():getCoordinates())
    reward = {credits = 50000 * balancing, relations = 7500, paymentMessage = "Earned %1% Credits for covering a retreat."%_T}
    local materialAmount = round(random():getInt(7000, 8000) / 100) * 100
    MissionUT.addSectorRewardMaterial(x, y, reward, materialAmount)

    punishment = {relations = reward.relations}

    local bulletin =
    {
        -- data for the bulletin board
        brief = "Help us distract the enemy"%_T,
        title = mission.data.title,
        description = "We lost a crucial battle against ${faction}. The remains of our fleet are retreating with the bulk of the enemy fleet in pursuit. Our rearguard is fighting desperately to cover our retreat.\n\nWe are gathering in sector (${x}:${y}). Rendezvous with our fleet and intercept the enemy!"%_T,
        difficulty = "Difficult /*difficulty*/"%_T,
        reward = "¢${reward}"%_t,
        script = "missions/coverretreat.lua",
        formatArguments = {faction = Faction(enemyFaction).name, x = target.x, y = target.y, reward = createMonetaryString(reward.credits)},
        msg = "Come with your battleship to \\s(%1%:%2%) and support our rearguard."%_T,
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
            enemyFactionIndex = enemyFaction
        }},
    }

    return bulletin
end
