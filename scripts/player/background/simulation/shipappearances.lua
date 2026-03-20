
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/player/background/simulation/?.lua"

include("callable")
local CommandType = include ("commandtype")
local SimulationUtility = include ("simulationutility")
local SectorSpecifics = include("sectorspecifics")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace ShipAppearances
ShipAppearances = {}


local data =
{
    visibleShips = {},

    -- alliance ships have to be kept track of by their members since alliances don't update in-sector and have no onSectorEntered() callback
    allianceVisualizations = {},
}

-- these cannot be visualized
-- they either have no area, or ships already move around (or both)
-- CommandType.Trade, -- very hard to do in a way that it looks natural
-- CommandType.Travel, -- could be abusable
-- CommandType.Supply, -- already has the ships appearing from time to time
-- CommandType.Escort, -- handled together with the others

local VisualizableCommands = {}
VisualizableCommands[CommandType.Scout] = true
VisualizableCommands[CommandType.Mine] = true
VisualizableCommands[CommandType.Salvage] = true
VisualizableCommands[CommandType.Refine] = true
VisualizableCommands[CommandType.Procure] = true
VisualizableCommands[CommandType.Sell] = true
VisualizableCommands[CommandType.Expedition] = true
VisualizableCommands[CommandType.Maintenance] = true

local AppearanceChances = {}
AppearanceChances[CommandType.Scout] = 0.5
AppearanceChances[CommandType.Mine] = 0.5
AppearanceChances[CommandType.Salvage] = 0.5
AppearanceChances[CommandType.Procure] = 0.35
AppearanceChances[CommandType.Sell] = 0.35
AppearanceChances[CommandType.Expedition] = 0.5
AppearanceChances[CommandType.Refine] = 0.35
AppearanceChances[CommandType.Maintenance] = 0.35

local AppearanceLengths = {}
AppearanceLengths[CommandType.Scout] = 2
AppearanceLengths[CommandType.Mine] = 10
AppearanceLengths[CommandType.Salvage] = 10
AppearanceLengths[CommandType.Procure] = 2
AppearanceLengths[CommandType.Sell] = 2
AppearanceLengths[CommandType.Expedition] = 2
AppearanceLengths[CommandType.Refine] = 2
AppearanceLengths[CommandType.Maintenance] = 2



if onServer() then

function ShipAppearances.getUpdateInterval()
    return 30
end

function ShipAppearances.initialize()
    local owner = getParentFaction()

    owner:registerCallback("onShipAvailabilityUpdated", "onShipAvailabilityUpdated")

    if owner.isPlayer then
        owner:registerCallback("onSectorEntered", "onSectorEntered")
    end
end

function ShipAppearances.updateServer(timeStep)
    -- every x seconds, update locations of ships
    ShipAppearances.cleanUp()

    local imminentAttacks = ShipAppearances.getImminentAttacks()
    local commandsByShip = ShipAppearances.getCommandsByShip()
    local owner = getParentFaction()

    -- find ships that can be visualized
    for name, command in pairs(commandsByShip) do

        -- if there is an attack imminent, have the ship disappear
        if imminentAttacks[name] then
            -- have ship disappear again
            ShipAppearances.removeFromVisible(owner, name)
            goto continue
        end

        local visualizedShip = data.visibleShips[name]

        if VisualizableCommands[command.type] then
            local appearanceChance = AppearanceChances[command.type] or 0.15

            -- if a ship isn't there, give it a chance of appearing this tick
            if not visualizedShip and random():test(appearanceChance) then
                -- find a new location
                local x, y = ShipAppearances.findLocation(name, command.type)

                if x and y then
                    visualizedShip = {
                        name = name,
                        command = command.type,
                        appearanceLength = AppearanceLengths[command.type] or 10
                    }

                    if command.config.escorts then
                        visualizedShip.escorts = table.deepcopy(command.config.escorts)
                    end

                    ShipAppearances.addToVisible(owner.index, visualizedShip, x, y)
                end
            end
        end

        ::continue::
    end

    -- update the visualizing simulation
    for name, command in pairs(commandsByShip) do
        local visualizedShip = data.visibleShips[name]

        if visualizedShip then
            visualizedShip.counter = (visualizedShip.counter or 0) + (timeStep / 60)
            if visualizedShip.counter > visualizedShip.appearanceLength then
                -- return to background simulation
                ShipAppearances.removeFromVisible(owner, name)
            end
        end

    end

    -- spawn ships that may have moved into the sector
    if isPlayerScript() then
        local x, y = Sector():getCoordinates()
        ShipAppearances.spawnShips(x, y)
    end

    ShipAppearances.sync()
end

function ShipAppearances.addToVisible(ownerIndex, visualizedShip, x, y)
    data.visibleShips[visualizedShip.name] = visualizedShip

    -- move the ship and escorts to the new visualizedShip
    local entry = ShipDatabaseEntry(ownerIndex, visualizedShip.name)
    entry:setCoordinates(x, y)

    -- also move the escorts
    for _, escort in pairs(visualizedShip.escorts or {}) do
        local escortShip = {
            name = escort,
            escortee = visualizedShip.name,
            appearanceLength = visualizedShip.appearanceLength,
            command = CommandType.Escort
        }

        local entry = ShipDatabaseEntry(ownerIndex, escort)
        entry:setCoordinates(x, y)

        data.visibleShips[escort] = escortShip
    end
end

function ShipAppearances.removeFromVisible(owner, name)
    data.visibleShips[name] = nil
    Galaxy():sendCallback("onBackgroundShipDisappear", owner.index, name) -- send a callback to initiate deletion
end

function ShipAppearances.findLocation(name, commandType)
    if not Simulation then
        eprint("ShipAppearances.findLocation: Simulation namespace not found")
        return
    end

    local command = nil
    local analysis = nil
    for _, runningCommand in pairs(Simulation.commands) do
        if runningCommand.shipName == name then
            if runningCommand.area and runningCommand.area.analysis then
                command = runningCommand
                analysis = runningCommand.area.analysis
                break
            end
        end
    end

    if not analysis then
        print ("no sectors")
        return
    end

    local sectors = analysis.reachableCoordinates or {}

    -- safe mode means that the commands only use safe sectors
    if command.config.safeMode then
        sectors = {}

        for _, i in pairs(analysis.safeSectors) do
            table.insert(sectors, analysis.reachableCoordinates[i])
        end
    end

    local candidates = {}

    -- depending on the command, use a location that makes more sense, such as a known asteroid field for mine command
    if commandType == CommandType.Mine then
        local owner = getParentFaction()
        local specs = SectorSpecifics()

        for _, sector in pairs(sectors) do
            if ShipAppearances.isLucrativeForMining(owner, specs, sector.x, sector.y) then
                table.insert(candidates, sector)
            end
        end

    elseif commandType == CommandType.Salvage then
        local owner = getParentFaction()
        local specs = SectorSpecifics()

        for _, sector in pairs(sectors) do
            if ShipAppearances.isLucrativeForSalvaging(owner, specs, sector.x, sector.y) then
                table.insert(candidates, sector)
            end
        end
    end

    -- fallback in case no candidates were found
    if #candidates == 0 then
        candidates = sectors
    end

    if #candidates == 0 then return end

    local coords = candidates[random():getInt(1, #candidates)]
    return coords.x, coords.y
end

function ShipAppearances.isLucrativeForMining(owner, specs, x, y)
    local view = owner:getKnownSector(x, y)

    if view then
        if view.numAsteroids == 0 then return false end

        -- check that there aren't any enemy ships
        for faction, crafts in pairs(view:getCraftsByFaction()) do
            if crafts > 0 and owner:getRelationStatus(faction) == RelationStatus.War then
                return false
            end
        end

        -- check that there are no cultists
        specs:initialize(x, y, GameSeed())

        if specs.blocked then return false end

        if specs.generationTemplate then
            local contents = specs.generationTemplate.contents(x, y)
            if contents.asteroidCultists then return false end
        end

        return view.numAsteroids > 0
    else
        local seed = GameSeed()

        local regular, offgrid = specs.determineFastContent(x, y, seed)
        if not regular and not offgrid then return false end

        specs:initialize(x, y, seed)

        if specs.blocked then return false end

        local contents = specs.generationTemplate.contents(x, y)
        if contents.pirateEncounter or contents.xsotan or contents.pirates or contents.asteroidCultists then return false end

        return (contents.asteroidEstimation or 0) > 0
    end
end

function ShipAppearances.isLucrativeForSalvaging(owner, specs, x, y)
    local view = owner:getKnownSector(x, y)

    if view then
        if view.numWrecks == 0 then return false end

        -- check that there aren't any enemy ships
        for faction, crafts in pairs(view:getCraftsByFaction()) do
            if crafts > 0 and owner:getRelationStatus(faction) == RelationStatus.War then
                return false
            end
        end

        return view.numWrecks > 0
    else
        local seed = GameSeed()

        local regular, offgrid = specs.determineFastContent(x, y, seed)
        if not regular and not offgrid then return false end

        specs:initialize(x, y, seed)

        if specs.blocked then return false end

        local contents = specs.generationTemplate.contents(x, y)
        if contents.pirateEncounter or contents.xsotan or contents.pirates then return false end

        return (contents.wreckageEstimation or 0) > 0
    end
end

function ShipAppearances.cleanUp()
    local owner = getParentFaction()

    local syncNecessary

    if owner.isPlayer and not owner.allianceIndex then
        -- no alliance -> no alliance visualizations
        data.allianceVisualizations = {}
    end

    -- delete all ship visualizedShips that are invalid
    -- delete all visualizedShips of faulty or outdated ships
    for name, visualizedShip in pairs(data.visibleShips) do
        if not owner:ownsShip(name) or owner:getShipAvailability(name) ~= ShipAvailability.InBackground then
            data.visibleShips[name] = nil
            syncNecessary = true
        end
    end

    if syncNecessary then
        ShipAppearances.sync()
    end
end

function ShipAppearances.getImminentAttacks()
    local result = {}

    if not Simulation then
        eprint("ShipAppearances.getImminentAttacks: Simulation namespace not found")
        return result
    end

    -- check if the ship has an attack incoming
    for _, command in pairs(Simulation.commands) do
        if command.data and command.data.attack and command.data.attack.countDown <= 180 then
            result[command.shipName] = true
        end
    end

    return result
end

function ShipAppearances.getCommandsByShip()
    local result = {}

    if not Simulation then
        eprint("ShipAppearances.getCommandsByShip: Simulation namespace not found")
        return result
    end

    local result = {}

    for _, command in pairs(Simulation.commands) do
        result[command.shipName] = command
    end

    return result
end

function ShipAppearances.getVisibleShips()
    return data.visibleShips
end

function ShipAppearances.getVisualization(name)
    return data.visibleShips[name]
end

function ShipAppearances.getShipsOfSector(owner, x, y)
    local ships = {}

    local collection = data.visibleShips
    if owner.isAlliance then collection = data.allianceVisualizations end

    for name, visualizedShip in pairs(collection) do
        local sx, sy = owner:getShipPosition(name)

        if sx == x and sy == y then
            table.insert(ships, visualizedShip)
        end
    end

    return ships
end

function ShipAppearances.onShipAvailabilityUpdated()
    ShipAppearances.cleanUp()
end

function ShipAppearances.onSectorEntered(playerIndex, x, y, changeType)
    ShipAppearances.cleanUp()
    ShipAppearances.spawnShips(x, y)
end

function ShipAppearances.spawnShips(x, y)
    local factions = {getParentFaction()}

    local alliance = Alliance()
    if alliance then
        table.insert(factions, alliance)
    end

    for _, owner in pairs(factions) do
        local ships = ShipAppearances.getShipsOfSector(owner, x, y)
        for _, ship in pairs(ships) do
            local appearance = SimulationUtility.spawnAppearance(owner, ship.name)

            local commandData = {}
            commandData.escortee = ship.escortee

            appearance:invokeFunction("utility/backgroundshipappearance.lua", "setCommandData", ship.command, commandData)
        end
    end
end

function ShipAppearances.secure()
    return data
end

function ShipAppearances.restore(data_in)
    data = data_in

    -- reset visible ships on purpose, makes the simulation robust and saves a lot of work
    -- this only means that ships will appear in different places after a relog
    data.visibleShips = {}
    data.allianceVisualizations = {}
end

function ShipAppearances.setAllianceAppearances(allianceVisualizations)
    data.allianceVisualizations = allianceVisualizations

    -- spawn alliance ships that may have moved into the sector
    if isPlayerScript() then
        local x, y = Sector():getCoordinates()
        ShipAppearances.spawnShips(x, y)
    end
end

end -- onServer()


function ShipAppearances.sync(data_in)
    if onClient() then
        if data_in then
            data = data_in
        else
            invokeServerFunction("sync")
        end
    else
        if isAllianceScript() then
            if callingPlayer then
                invokeClientFunction(Player(callingPlayer), "sync", data)
            else
                local alliance = Alliance()
                local onlineMembers = {alliance:getOnlineMembers()}

                for _, playerIndex in pairs(onlineMembers) do
                    -- sync to all members, both network and in-sector
                    invokeClientFunction(Player(playerIndex), "sync", data)
                    invokeFactionFunction(playerIndex, true, "shipappearances.lua", "setAllianceAppearances", data.visibleShips)
                end
            end
        else
            invokeClientFunction(Player(callingPlayer), "sync", data)
        end
    end
end
callable(ShipAppearances, "sync")


if onClient() then

function ShipAppearances.initialize()
    local player = Player()
    player:registerCallback("onMapRenderAfterLayers", "onMapRenderAfterLayers")

    ShipAppearances.sync()
end

function ShipAppearances.onMapRenderAfterLayers()
    local renderer = UIRenderer()
    local owner = getParentFaction()

    local map = GalaxyMap()
    local showAllianceShips = map.showAllianceInfo

    local color = Player():getRelation(owner.index).color

    for _, ship in pairs(data.visibleShips) do

        if owner.isAlliance and not showAllianceShips then
            -- don't show where alliance ships are if player doesn't want alliance info
            goto continue
        end

        local x, y = owner:getShipPosition(ship.name)
        if x and y then
            local sx, sy = GalaxyMap():getCoordinatesScreenPosition(ivec2(x, y))
            local size = 23

            renderer:renderTargeter(vec2(sx,sy), size, color, 0)
        end

        ::continue::
    end

    renderer:display()
end

end -- onClient()

