package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("mission")
include("relations")
include("utility")
include("stringutility")
include("callable")
include("randomext")
local Balancing = include("galaxy")
local SectorSpecifics = include("sectorspecifics")
local Dialog = include ("dialogutility")
local MissionUT = include("missionutility")


missionData.brief = "Explore Sector"%_t
missionData.title = "Explore sector (${location.x}:${location.y})"%_t
missionData.autoTrackMission = true

missionData.description = "The ${giver} asked you to explore sector (${location.x}:${location.y})."%_t

function initialize(giverIndex, x, y, reward)
    local player = Player()

    if onClient() then
        sync()
        player:registerCallback("onPreRenderHud", "onPreRenderHud")
        player:registerCallback("onStartDialog", "startDialog")

    else
        player:registerCallback("onSectorEntered", "onSectorEntered")
        player:registerCallback("onMissionObjectExplored", "onMissionObjectExplored")

        -- if it's not being initialized from outside, skip initialization
        -- the script will be restored via restore()
        if _restoring or not giverIndex then return end

        missionData.explored = 0
        missionData.enemies = {}
        missionData.interestingPoints = nil
        missionData.finishedExploration = false
        missionData.firstTime = true
        missionData.fulfilled = 0

        -- don't initialize data if there is none
        if not giverIndex then
            terminate()
            return
        end

        local station = Entity(giverIndex)
        missionData.giver = Sector().name .. " " .. station.translatedTitle
        missionData.location = {x = x, y = y}
        missionData.reward = reward
        missionData.justStarted = true
        missionData.factionIndex = station.factionIndex
        local x0, y0 = Sector():getCoordinates()
        missionData.giverCoordinates = {x = x0, y = y0}
    end
end

function onSectorEntered(playerindex, x, y)
    if not missionData.firstTime then return end
    if missionData.location.x ~= x or missionData.location.y ~= y then return end

    local player = Player()
    local specs = SectorSpecifics()
    local serverSeed = Server().seed
    specs:initialize(x, y, serverSeed)

    local explorable = {}

    --used if there are pirates
    if specs.generationTemplate.path == "sectors/pirateasteroidfield" or specs.generationTemplate.path == "sectors/piratefight" or specs.generationTemplate.path == "sector/piratestation" then
--                    print("pirates")
        local ships = {Sector():getEntitiesByType(EntityType.Ship)}
        for _, ship in pairs(ships) do
            if not ship.id == player.craftIndex then
                table.insert(explorable, ship)
                ship:registerCallback("onDestroyed", "destroyedExplorable")
            end

            if #explorable >= 3 then
                break
            end
        end

    --used if there are wreckages
    elseif specs.generationTemplate.path == "sectors/functionalwreckage" or specs.generationTemplate.path == "sectors/stationwreckage" or specs.generationTemplate.path == "sectors/wreckageasteroidfield" or specs.generationTemplate.path == "sectors/wreckagefield" then
--                    print("wreckages")
        local wreckages = {Sector():getEntitiesByType(EntityType.Wreckage)}
        for _, wreckage in pairs(wreckages) do
            table.insert(explorable, wreckage)
            wreckage:registerCallback("onDestroyed", "destroyedExplorable")

            if #explorable >= 2 then
                break
            end
        end

    --used if there are nonagressive factions
    elseif specs.generationTemplate.path == "sectors/smugglerhideout" or specs.generationTemplate.path == "sectors/cultists" or specs.generationTemplate.path == "sectors/resistancecell" then
--                    print("nonagressive faction")
        local stations = {Sector():getEntitiesByType(EntityType.Station)}
        for _, station in pairs(stations) do
            table.insert(explorable, station)
            station:registerCallback("onDestroyed", "destroyedExplorable")

            if #explorable >= 2 then
                break
            end
        end

        local ships = {Sector():getEntitiesByType(EntityType.Ship)}
        for _, ship in pairs(ships) do
            if not ship.id == player.craftIndex then
                table.insert(explorable, ship)
                ship:registerCallback("onDestroyed", "destroyedExplorable")
            end

            if #explorable >= 5 then
                break
            end
        end

    --used if there is a containerfield
    elseif specs.generationTemplate.path == "sectors/containerfield"
            or specs.generationTemplate.path == "sectors/massivecontainerfield" then
--                    print("containerfield")
        local containers = {Sector():getEntitiesByType(EntityType.None)}
        for _, container in pairs(containers) do
            table.insert(explorable, container)
            container:registerCallback("onDestroyed", "destroyedExplorable")

            if #explorable >= 3 then
                break
            end
        end
    end

    --add some asteroids to the objects to explore
    local asteroids = {Sector():getEntitiesByType(EntityType.Asteroid)}
    for _, asteroid in pairs(asteroids) do
        if #explorable >= math.random(5, 8) then
            break
        end

        asteroid:registerCallback("onDestroyed", "destroyedExplorable")
        table.insert(explorable, asteroid)
    end


    for i = 1, #explorable do
        explorable[i]:addScriptOnce("player/missions/exploresector/exploreobject.lua")
        explorable[i] = explorable[i].id.string
    end

    missionData.interestingPoints = explorable
    missionData.firstTime = nil
    sync()
end

function destroyedExplorable()
    if onClient() then
        invokeServerFunction("destroyedExplorable")
    end

    showMissionFailed()
    terminate()
    return
end
callable(nil, "destroyedExplorable")

function onPreRenderHud()

    if not missionData.interestingPoints then return end

    local player = Player()
    if not player then return end
    if player.state == PlayerStateType.BuildCraft or player.state == PlayerStateType.BuildTurret or player.state == PlayerStateType.PhotoMode then return end

    local renderer = UIRenderer()

    local sector = Sector()
    for i = 1, #missionData.interestingPoints do
        local color = ColorRGB(0.2, 0.5, 0.2)
        local entity = sector:getEntity(Uuid(missionData.interestingPoints[i]))
        if entity and entity:hasScript("exploreobject.lua") then
            renderer:renderEntityTargeter(entity, color)
            renderer:renderEntityArrow(entity, 30, 10, 250, color)
        end
    end
    renderer:display()
end

function onMissionObjectExplored(entityIdString)
    -- target sector was not visited yet
    if not missionData.interestingPoints then return end

    -- check if explored object is one of this mission
    local explorableFound = false
    for _, id in pairs(missionData.interestingPoints) do
        if id == entityIdString then
            explorableFound = true
            break
        end
    end

    if not explorableFound then return end

    missionData.explored = missionData.explored + 1

    if missionData.explored >= #missionData.interestingPoints then
        finishedExploration()
    end
end

function finishedExploration()
    showMissionUpdated("Sector Explored"%_t)
    missionData.description = "You have explored the sector. Report back to the client."%_t
    missionData.location = {x = missionData.giverCoordinates.x, y = missionData.giverCoordinates.y}
    missionData.finishedExploration = true
    sync()
end

function startDialog(entityId)
    if missionData.finishedExploration == true and missionData.fulfilled == 0 then
        local potentialClient = Sector():getEntity(entityId)
        local isMilitaryOutpost = potentialClient:hasScript("militaryoutpost.lua")
        local isHeadquarters = potentialClient:hasScript("headquarters.lua")
        local isResearchStation = potentialClient:hasScript("researchstation.lua")

        if missionData.factionIndex == potentialClient.factionIndex and (isMilitaryOutpost or isHeadquarters or isResearchStation) then
            ScriptUI(entityId):addDialogOption("I found some information in the explored sector."%_t, "onDeliver")
        end
    end
end

function onDeliver(entityId)
    if onClient() then
        invokeServerFunction("onDeliver", entityId)
        return
    end

    if missionData.fulfilled == 1 then
        return
    end

    missionData.timeLimit = 5
    missionData.fulfilled = 1
    onAccomplished(entityId)
    sync()
    --invokeClientFunction(Player(), "onAccomplished", entityId)
end
callable(nil, "onDeliver")

function onAccomplished(entityId)
    if onServer then
        local r = missionData.reward
        player = Player()
        player:receive("Earned %1% Credits for exploring a sector."%_T, r.credits, r.iron or 0, r.titanium or 0, r.naonite or 0, r.trinium or 0, r.xanion or 0, r.ogonite or 0, r.avorion or 0)
        player:sendChatMessage(missionData.giver, 0, "Thank you for helping us expand our borders. We have transferred the reward to your account."%_t)


        changeRelations(player.index, missionData.factionIndex, 5000, nil)
        finish()
    end
end

function getBulletin(station)
    local specs = SectorSpecifics()
    local x, y = Sector():getCoordinates()
    local giverInsideBarrier = MissionUT.checkSectorInsideBarrier(x, y)

    local sectorTemplateCandidates =
    {
        "sectors/containerfield",
        "sectors/massivecontainerfield",
        "sectors/cultists",
        "sectors/functionalwreckage",
        "sectors/pirateastroidfield",
        "sectors/piratefight",
        "sectors/piratestation",
        "sectors/resitancecell",
        "sectors/smugglerhideout",
        "sectors/stationwreckage",
        "sectors/wreckageastroidfield",
        "sectors/wreckagefiled"
    }

    local tx, ty = MissionUT.getSectorWithScript(x, y, 10, 20, sectorTemplateCandidates, false, true, false, false, giverInsideBarrier)
    if not tx or not ty then return end

    local description = "We are picking up unusual activity in a nearby sector. We will pay you to assist us in scanning some of the objects in that sector.\n\nSector: (${x} : ${y})"%_t

    reward = {credits = 40000 * Balancing.GetSectorRewardFactor(Sector():getCoordinates())}
    local materialAmount = round(random():getInt(7000, 8000) / 100) * 100
    MissionUT.addSectorRewardMaterial(x, y, reward, materialAmount)

    local bulletin =
    {
        brief = "Explore Sector"%_t,
        description = description,
        difficulty = "Easy /*difficulty*/"%_t,
        reward = "¢${reward}"%_t,
        script = "missions/exploresector/exploresector.lua",
        arguments = {Entity().id, tx, ty, reward},
        formatArguments = {x = tx, y = ty, reward = createMonetaryString(reward.credits)},
        msg = "The sector is \\s(%1%:%2%)."%_T,
        entityTitle = station.title,
        entityTitleArgs = station:getTitleArguments(),
        onAccept = [[
            local self, player = ...
            local title = self.entityTitle % self.entityTitleArgs
            player:sendChatMessage(title, 0, self.msg, self.formatArguments.x, self.formatArguments.y)
        ]]
    }

    return bulletin

end
