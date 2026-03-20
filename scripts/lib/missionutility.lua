package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("randomext")
AsyncShipGenerator = include("asyncshipgenerator")
local SectorSpecifics = include ("sectorspecifics")
include("galaxy")

local MissionUT = {}

local locations = {data = {}}

-- sector utility
-- check this before setting a new target location for a mission
function MissionUT.getMissionLocations()

    locations.insert = function(self, x, y)
        table.insert(self.data, {x=x, y=y})
    end

    locations.contains = function(self, x, y)
        for _, p in pairs(self.data) do
            if p.x == x and p.y == y then
                return true
            end
        end

        return false
    end

    if not isPlayerScript() then return locations end

    local player = Player()
    if not player then return locations end

    for _, script in pairs(player:getScripts()) do
        local result = {player:invokeFunction(script, "getMissionLocation")}
        if result[1] ~= 0 then goto continue1 end

        for k, cood in pairs(result) do
            if k == 1 then goto continueInner end

            if result[k] and result[k+1] and not locations:contains(result[k], result[k+1]) then
                locations:insert(result[k], result[k+1])
            end

            ::continueInner::
        end

        ::continue1::

        -- consider custom locations as well, they are reserved for future use
        local result2 = {player:invokeFunction(script, "getReservedMissionLocation")}
        if result2[1] ~= 0 then goto continue2 end

        for k, cood in pairs(result2) do
            if k == 1 then goto continueInner end

            if result2[k] and result2[k+1] and not locations:contains(result2[k], result2[k+1]) then
                locations:insert(result2[k], result2[k+1])
            end

            ::continueInner::
        end

        ::continue2::
    end

    return locations
end

function MissionUT.countPirates()
    local num = 0
    for _, entity in pairs({Sector():getEntitiesByType(EntityType.Ship)}) do
        if entity:getValue("is_pirate") then
            num = num + 1
        end
    end

    return num
end

function MissionUT.getPirates()
    local result = {}
    for _, entity in pairs({Sector():getEntitiesByType(EntityType.Ship)}) do
        if entity:getValue("is_pirate") then
            table.insert(result, entity)
        end
    end

    return result
end

function MissionUT.getPirateIdStrings()
    local result = {}
    for _, entity in pairs({Sector():getEntitiesByType(EntityType.Ship)}) do
        if entity:getValue("is_pirate") then
            table.insert(result, entity.id.string)
        end
    end

    return result
end

function MissionUT.countXsotan()
    local num = 0
    for _, entity in pairs({Sector():getEntitiesByType(EntityType.Ship)}) do
        if entity:getValue("is_xsotan") then
            num = num + 1
        end
    end

    return num
end

function MissionUT.getXsotan()
    local result = {}
    for _, entity in pairs({Sector():getEntitiesByType(EntityType.Ship)}) do
        if entity:getValue("is_xsotan") then
            table.insert(result, entity)
        end
    end

    return result
end

function MissionUT.getXsotanIdStrings()
    local result = {}
    for _, entity in pairs({Sector():getEntitiesByType(EntityType.Ship)}) do
        if entity:getValue("is_xsotan") then
            table.insert(result, entity.id.string)
        end
    end

    return result
end

-- entity utility
function MissionUT.deleteOnPlayersLeft(entity)
    entity:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
end

-- binds an entity's lifetime to the currently executed mission
-- once the mission is over, the added script will make sure that the entity gets deleted
function MissionUT.bindToMission(entity)
    local player = Player()
    if not player then return end

    entity:addScriptOnce("data/scripts/entity/deleteonmissionover.lua", scriptPath(), player.index)
end

-- map & faction utility
function MissionUT.getNeighboringFactions(faction, d, numTries)
    if type(faction) == "number" then faction = Faction(faction) end
    d = d or 125

    local x, y = faction:getHomeSectorCoordinates()
    local homeSectors = Galaxy():getMapHomeSectors(x, y, d)
    homeSectors[faction.index] = nil

    local result = {}
    for idx, coords in pairs(homeSectors) do
        table.insert(result, Faction(idx))
    end

    return result
end

-- isInsideBarrier: set to true/false or use nil if you don't care
-- CAVEAT: This function can return nil if no such sector is found within maxDist!
function MissionUT.getSector(centerX, centerY, minDist, maxDist, isRegular, isOffgrid, isBlocked, isHome, isInsideBarrier)
    local specs = SectorSpecifics()
    local coords = specs.getShuffledCoordinates(random(), centerX, centerY, minDist, maxDist)
    local otherMissionLocations = MissionUT.getMissionLocations()
    local x, y

    for _, coord in pairs(coords) do
        local regular, offgrid, blocked, home = specs:determineContent(coord.x, coord.y, Server().seed)

        if isInsideBarrier ~= nil then
            if MissionUT.checkSectorInsideBarrier(coord.x, coord.y) ~= isInsideBarrier then goto continue end
        end

        if (isRegular == nil or (regular == isRegular)) and
                (isOffgrid == nil or (offgrid == isOffgrid)) and
                (isBlocked == nil or (blocked == isBlocked)) and
                (isHome == nil or (home == isHome)) then

                    -- check on other missions' locations
                    if not otherMissionLocations or not otherMissionLocations:contains(x, y) then
                        x = coord.x
                        y = coord.y
                        break
                    end
        end

        ::continue::
    end

    return x, y
end

function MissionUT.getEmptySector(centerX, centerY, minDist, maxDist, isInsideBarrier)
   return MissionUT.getSector(centerX, centerY, minDist, maxDist, false, false, false, false, isInsideBarrier)
end

-- script has to be given as "sectors/templatename" without .lua, either directly or multiple in a table
-- set isRegular etc to save performance as less sectors will have to be initialized
-- isInsideBarrier: set to true/false or use nil if you don't care
function MissionUT.getSectorWithScript(centerX, centerY, minDist, maxDist, script, isRegular, isOffgrid, isBlocked, isHome, isInsideBarrier, excludedSectors)
    local specs = SectorSpecifics()
    local coords = specs.getShuffledCoordinates(random(), centerX, centerY, minDist, maxDist)
    local x, y

    local insideBarrier = inside or false
    local serverSeed = Server().seed

    for _, coord in pairs(coords) do
        if excludedSectors then
            local key = MissionUT.makeSectorKey(coord.x, coord.y)
            if excludedSectors[key] == true then
                goto outerContinue
            end
        end

        local regular, offgrid, blocked, home = specs:determineContent(coord.x, coord.y, serverSeed)

        if (isRegular == nil or (regular == isRegular)) and
                (isOffgrid == nil or (offgrid == isOffgrid)) and
                (isBlocked == nil or (blocked == isBlocked)) and
                (isHome == nil or (home == isHome)) then

            if isInsideBarrier ~= nil then
                if MissionUT.checkSectorInsideBarrier(coord.x, coord.y) ~= isInsideBarrier then goto continue end
            end

            -- check if the sector template script matches the requirement
            specs:initialize(coord.x, coord.y, serverSeed)
            local scriptMatches = false
            if type(script) == "string" then
                if specs.generationTemplate.path == script then
                    scriptMatches = true
                end
            elseif type(script) == "table" then
                for _, path in pairs(script) do
                    if specs.generationTemplate.path == path then
                        scriptMatches = true
                        break
                    end
                end
            end

            if scriptMatches then
                if not Galaxy():sectorExists(coord.x, coord.y) then
                    x = coord.x
                    y = coord.y
                    break
                end
            end

            ::continue::
        end

        ::outerContinue::
    end

    return x, y
end


function MissionUT.makeSectorKey(x, y)
    return tostring(x) .. ":" .. tostring(y)
end

-- set isRegular etc to save performance as less sectors will have to be initialized
-- isInsideBarrier: set to true/false or use nil if you don't care
function MissionUT.getSectorWithStations(centerX, centerY, minDist, maxDist, isRegular, isOffgrid, isBlocked, isHome, isInsideBarrier, excludedSectors, stationType)
    stationType = stationType or "stations"

    local specs = SectorSpecifics()
    local coords = specs.getShuffledCoordinates(random(), centerX, centerY, minDist, maxDist)
    local x, y

    local insideBarrier = inside or false
    local serverSeed = Server().seed

    for _, coord in pairs(coords) do
        if excludedSectors then
            local key = MissionUT.makeSectorKey(coord.x, coord.y)
            if excludedSectors[key] == true then
                goto outerContinue
            end
        end

        local regular, offgrid, blocked, home = specs:determineContent(coord.x, coord.y, serverSeed)

        if (isRegular == nil or (regular == isRegular)) and
                (isOffgrid == nil or (offgrid == isOffgrid)) and
                (isBlocked == nil or (blocked == isBlocked)) and
                (isHome == nil or (home == isHome)) then

            if isInsideBarrier ~= nil then
                if MissionUT.checkSectorInsideBarrier(coord.x, coord.y) ~= isInsideBarrier then goto continue end
            end

            specs:initialize(coord.x, coord.y, serverSeed)

            if specs.generationTemplate then
                local contents = specs.generationTemplate.contents(coord.x, coord.y)
                if contents and contents[stationType] and contents[stationType] > 0 then
                    x = coord.x
                    y = coord.y
                    break
                end
            end

            ::continue::
        end

        ::outerContinue::
    end

    return x, y
end

-- get galaxy wide adventurer name
function MissionUT.getAdventurerName()
    local player = Player()
    local faction = Galaxy():getNearestFaction(player:getHomeSectorCoordinates())
    local language = faction:getLanguage()
    language.seed = Seed(GameSettings().seed)
    return language:getName()
end

-- objective creation
function MissionUT.createFreighter(faction, position, onFinished)

    position = position or Matrix()
    if type(faction) == "number" then
        faction = Faction(faction)
    end

    local sector = Sector()
    if not faction then
        local x, y = sector:getCoordinates()
        faction = Galaxy():getNearestFaction(x, y)
    end

    local generator = AsyncShipGenerator(nil, onFinished)
    generator:createFreighterShip(faction, position)

end

function MissionUT.checkSectorInsideBarrier(x, y)
    local distance2 = (x * x) + (y * y)
    if distance2 < (Balancing_GetBlockRingMax() * Balancing_GetBlockRingMax()) then
        return true
    end

    return false
end

function MissionUT.detectFoundArtifacts(player)

    local inventory = player:getInventory()
    local upgrades = inventory:getItemsByType(InventoryItemType.SystemUpgrade)
    local count = {}

    for _, u in pairs(upgrades) do
        local upgrade = u.item
        if upgrade.rarity == Rarity(RarityType.Legendary) then
            if upgrade.script == "data/scripts/systems/teleporterkey1.lua" then
                count[1] = true
            elseif upgrade.script == "data/scripts/systems/teleporterkey2.lua" then
                count[2] = true
            elseif upgrade.script == "data/scripts/systems/teleporterkey3.lua" then
                count[3] = true
            elseif upgrade.script == "data/scripts/systems/teleporterkey4.lua" then
                count[4] = true
            elseif upgrade.script == "data/scripts/systems/teleporterkey5.lua" then
                count[5] = true
            elseif upgrade.script == "data/scripts/systems/teleporterkey6.lua" then
                count[6] = true
            elseif upgrade.script == "data/scripts/systems/teleporterkey7.lua" then
                count[7] = true
            elseif upgrade.script == "data/scripts/systems/teleporterkey8.lua" then
                count[8] = true
            end
        end
    end

    local shipNames = {player:getShipNames()}
    for _, name in pairs(shipNames) do
        for system, _ in pairs(player:getShipSystems(name)) do
            if system.script == "data/scripts/systems/teleporterkey1.lua" then
                count[1] = true
            elseif system.script == "data/scripts/systems/teleporterkey2.lua" then
                count[2] = true
            elseif system.script == "data/scripts/systems/teleporterkey3.lua" then
                count[3] = true
            elseif system.script == "data/scripts/systems/teleporterkey4.lua" then
                count[4] = true
            elseif system.script == "data/scripts/systems/teleporterkey5.lua" then
                count[5] = true
            elseif system.script == "data/scripts/systems/teleporterkey6.lua" then
                count[6] = true
            elseif system.script == "data/scripts/systems/teleporterkey7.lua" then
                count[7] = true
            elseif system.script == "data/scripts/systems/teleporterkey8.lua" then
                count[8] = true
            end
        end
    end

    return count
end

function MissionUT.playerInTargetSector(player, targetCoords)
    if not player then return false end

    local x, y = Sector():getCoordinates()
    if not x or not y then return false end

    if not targetCoords then return true end

    if x == targetCoords.x and y == targetCoords.y then
        return true
    end

    return false
end

-- selects a dialog based on the specified condition.
-- if the condition is true, it selects a dialog based on the docking state.
-- the messages are created using the supplied dialog maker functions, which have to return dialogs.
-- you can also supply additional arguments to forward to the dialog maker functions
function MissionUT.dockedDialogSelector(stationId, condition, failedDialogMaker, undockedDialogMaker, dockedDialogMaker, ...)
    local scriptUI = ScriptUI(stationId)
    if not scriptUI then return end

    if condition then
        local station = Entity(stationId)
        local errors = {}

        if not CheckPlayerDocked(Player(), station, errors) then
            -- not docked -> tell player to dock
            scriptUI:interactShowDialog(undockedDialogMaker(...), true)
        else
            -- docked -> tell the player, what's next
            scriptUI:interactShowDialog(dockedDialogMaker(...), true)
        end
    else
        -- condition failed -> tell the player what's wrong
        scriptUI:interactShowDialog(failedDialogMaker(...), true)
    end
end

function MissionUT.getBasicMissionColor()
--    return ColorRGB(0.8, 0.6, 0.7) -- very light purple
    return ColorRGB(1, 0.68, 0.2) -- "gold"
end

-- Moretti, Adriana, Juliana
function MissionUT.getDialogTalkerColor1()
--    return ColorRGB(1, 0.8, 0.6) -- light yellow
    return MissionUT.getDialogTextColor1() -- "gold"
end

-- Moretti, Adriana, Juliana
function MissionUT.getDialogTextColor1()
    return ColorRGB(1, 0.9, 0.75) -- "gold"
end

-- Mr. Jackson, Emperor
function MissionUT.getDialogTalkerColor2()
    return MissionUT.getDialogTextColor2() -- red
end

-- Mr. Jackson, Emperor
function MissionUT.getDialogTextColor2()
    return ColorRGB(1, 0.65, 0.65) -- red
end

-- Izzy
function MissionUT.getDialogTalkerColor3()
    return MissionUT.getDialogTextColor3() -- light purple
end

-- Izzy
function MissionUT.getDialogTextColor3()
    return ColorRGB(1, 0.8, 0.95) -- light purple
end

-- Zach
function MissionUT.getZachDialogColor()
    return ColorRGB(0.8, 0.8, 1.0) -- blue
end

-- Yavana
function MissionUT.getYavanaDialogColor()
    return ColorRGB(0.8, 0.9, 0.8) -- green
end

function MissionUT.getMissionFaction()
    local name = "Uxhi'ma"%_T

    local galaxy = Galaxy()
    local faction = galaxy:findFaction(name)
    if faction == nil then
        faction = galaxy:createFaction(name, 400, 0)
        faction.initialRelations = 0
        faction.initialRelationsToPlayer = 0
        faction.staticRelationsToAll = true
        faction.homeSectorUnknown = true
    end

    return faction
end

function MissionUT.getMissionSmugglerFaction()
    local name = "Uisht'gin Smugglers"%_T

    local galaxy = Galaxy()
    local faction = galaxy:findFaction(name)
    if faction == nil then
        faction = galaxy:createFaction(name, 400, 0)
        faction.initialRelations = 0
        faction.initialRelationsToPlayer = 0
        faction.staticRelationsToAll = true
        faction.homeSectorUnknown = true
    end

    return faction
end

function MissionUT.addSectorRewardMaterial(x, y, reward, materialAmount)
    local distance = math.sqrt(x * x + y * y)
    if distance <= 75 then
        reward.avorion = (reward.avorion or 0) + materialAmount
    elseif distance <= 150 then
        reward.ogonite = (reward.ogonite or 0) + materialAmount
    elseif distance <= 215 then
        reward.xanion = (reward.xanion or 0) + materialAmount
    elseif distance <= 290 then
        reward.trinium = (reward.trinium or 0) + materialAmount
    elseif distance <= 360 then
        reward.naonite = (reward.naonite or 0) + materialAmount
    elseif distance <= 425 then
        reward.titanium = (reward.titanium or 0) + materialAmount
    else
        reward.iron = (reward.iron or 0) + materialAmount
    end

    return reward
end


return MissionUT

