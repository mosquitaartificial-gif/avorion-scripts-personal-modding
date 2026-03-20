
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/player/background/simulation/?.lua"

local CommandType = include ("commandtype")
local CommandFactory = include("commandfactory")
local UpgradeGenerator = include ("upgradegenerator")
local SectorTurretGenerator = include ("sectorturretgenerator")
local SimulationUtility = include ("simulationutility")
local CaptainUtility = include ("captainutility")
local Queue = include("queue")
local Galaxy = include("galaxy")
local FactionEradicationUtility = include("factioneradicationutility")
local CaptainClass = include("captainclass")
include ("callable")
include ("utility")
include ("stringutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Simulation
Simulation = {}

-- shortcut so we don't have to write "Simulation.XXX" inside this module and can write "self.XXX" instead
-- exception: Function definitions like "Simulation.getUpdateInterval()"
local self = Simulation

-- #### COMMANDS #### --
self.commands = {}
local commands = self.commands -- shortcut to the actual data for easier access

function Simulation.makeCommand(type, ...)
    -- we don't use the base command returned by the factory
    -- we need to add some more functionality that the simulation relies on
    local command = CommandFactory.makeCommand(type, ...)

    command.simulation = Simulation
    command.simInternals = {runtime = 0}
    command.addYield = function(self, ...) self.simulation.addYield(self.shipName, ...) end
    command.finish = function(self, ...) self.simulation.finishCommand(self.shipName, ...) end
    command.registerForAttack = function(self, coords, faction, timeOfAttack, message, arguments)
        -- remember necessary data in command
        self.data.attack =
        {
            coordinates = coords,
            faction = faction,
            timeOfAttack = timeOfAttack,
            countDown = timeOfAttack,
            message = message,
            arguments = arguments
        }
    end
    command.clampConfig = function(self, ownerIndex, shipName)
        local configurable = self:getConfigurableValues(ownerIndex, shipName)

        for name, properties in pairs(configurable) do
            local value = self.config[name]

            if properties.default and value == nil then
                value = properties.default
            end

            if properties.from and value < properties.from then
                value = properties.from
            end

            if properties.to and value > properties.to then
                value = properties.to
            end

            self.config[name] = value
        end
    end

    return command
end

-- remember which areas were analyzed to reuse them on command start
-- we have to use the server-side area analysis as the analysis from clients can't be trusted
self.analyzedAreas = {}

self.startedAnalyses = Queue()

-- #### YIELDS #### --
-- yields are unsorted but receive a shipName so they can be assigned to a ship
-- it's potentially problematic to rename a ship while there's still some yield from it
-- the database can't know if there is still yield since yield is saved in this script
-- solutions:
--  1. yield where it's not clear where it came from is taken first whenever yield is taken
--  2. the ship ui doesn't let a ship get renamed while there is still yield (a cheater or mod might succeeed though)
self.yields = {}

local ExampleYield = {}
ExampleYield.message = "We found an absurdly large asteroid with all kinds of stuff in it!"
ExampleYield.ship = "The Indestructible II"
ExampleYield.money = 10000
ExampleYield.resources = {100, 100, 200, 100, 300, 400, 60}
ExampleYield.items =
{
    subsystems =
    {
        { x = 30, y = 120, seed = "jda0asd912", type = "data/scripts/systems/militarytcs.lua", rarity = RarityType.Exceptional, },
    },
    turrets =
    {
        { x = 12, y = -350, seed = "5asd423152", type = WeaponType.ChainGun, rarity = RarityType.Rare, },
        { x = 50, y = -250, seed = "9081u23das", type = WeaponType.ChainGun, rarity = RarityType.Exceptional, },
    },
    blueprints =
    {
        { x = 12, y = -350, seed = "r923slvny783", type = WeaponType.Bolter, rarity = RarityType.Rare, },
    },
}

-- #### CLIENT DESCRIPTIONS #### --
self.commandDescriptions = {}


-- #### DEV HELP #### --
local SpeedUp = 1


-- #### ACTUAL SCRIPT #### --
function Simulation.initialize()
    if onClient() then
        self.sync()
    end

    if onServer() then
        local owner = getParentFaction()
        owner:registerCallback("onShipAvailabilityUpdated", "onShipAvailabilityUpdated")
    end

end

function Simulation.getRawYields(shipName)
    if shipName then
        local result = {}

        local faction = getParentFaction()
        local firstShipName = faction:getShipNames()
        if shipName == firstShipName then
            -- show the orphaned yields when querying the first ship
            -- see takeRawYield
            for i, yield in pairs(self.yields) do
                if not faction:ownsShip(yield.ship) then
                    table.insert(result, yield)
                end
            end
        end

        -- add yields for shipName
        for _, yield in pairs(self.yields) do
            if yield.ship == shipName then
                table.insert(result, yield)
            end
        end

        return result
    end

    return self.yields
end

function Simulation.transformYield(yield)
    if not yield.items then return end

    yield.items = Simulation.makeYieldItems(yield)
end

function Simulation.makeYieldItems(yield)

    if not yield.items then return end

    local items = {}
    for _, subsystem in pairs(yield.items.subsystems or {}) do
        -- generate a subsystem based on the specs in the yield
        subsystem.seed = subsystem.seed or tostring(random():createSeed())
        subsystem.seed = tostring(subsystem.seed) -- make sure it's really a string
        subsystem.x = subsystem.x or 500
        subsystem.y = subsystem.y or 500

        local generator = UpgradeGenerator(subsystem.seed)
        local item = generator:generateSectorSystem(subsystem.x, subsystem.y, subsystem.rarity)

        if subsystem.type then
            item = SystemUpgradeTemplate(subsystem.type, item.rarity, item.seed)
        end

        table.insert(items, item)
    end

    for _, turret in pairs(yield.items.turrets or {}) do
        -- generate a turret based on the specs in the yield
        turret.seed = turret.seed or tostring(random():createSeed())
        turret.seed = tostring(turret.seed) -- make sure it's really a string
        turret.x = turret.x or 500
        turret.y = turret.y or 500

        local generator = SectorTurretGenerator(turret.seed)

        local rarity
        if turret.rarity then rarity = Rarity(turret.rarity) end
        local material
        if turret.material then material = Material(turret.material) end

        local item = generator:generate(turret.x, turret.y, turret.offset, rarity, turret.type, material)

        table.insert(items, InventoryTurret(item))
    end

    for _, turret in pairs(yield.items.blueprints or {}) do
        -- generate a turret based on the specs in the yield
        turret.seed = turret.seed or tostring(random():createSeed())
        turret.seed = tostring(turret.seed) -- make sure it's really a string
        turret.x = turret.x or 500
        turret.y = turret.y or 500

        local generator = SectorTurretGenerator(turret.seed)

        local rarity
        if turret.rarity then rarity = Rarity(turret.rarity) end
        local material
        if turret.material then material = Material(turret.material) end

        local item = generator:generate(turret.x, turret.y, turret.offset, rarity, turret.type, material)

        table.insert(items, item)
    end

    return items
end

function Simulation.getYields(shipName)

    local raw = Simulation.getRawYields(shipName)
    local transformed = table.deepcopy(raw)

    -- transform the items of the yields into actual items from their specs
    for _, yield in pairs(transformed) do
        Simulation.transformYield(yield)
    end

    return transformed
end

function Simulation.getNextYield(shipName)

    local raw = Simulation.getRawYields(shipName)
    if #raw == 0 then return {} end

    local next = table.deepcopy(raw[1])

    -- transform the items of the yields into actual items from their specs
    Simulation.transformYield(next)

    return next
end

function Simulation.getNumYields(shipName)
    local raw = Simulation.getRawYields(shipName)
    return #raw
end

function Simulation.hasYield(shipName)
    local faction = getParentFaction()
    local firstShipName = faction:getShipNames()
    if shipName == firstShipName then
        -- return orphaned yields when querying the first ship
        for i, yield in pairs(self.yields) do
            if not faction:ownsShip(yield.ship) then
                return true
            end
        end
    end

    for _, yield in pairs(self.yields) do
        if yield.ship == shipName then
            return true
        end
    end

    return false
end

function Simulation.getCommandUIData(shipName)
    return self.uiData[shipName], self.commandDescriptions[shipName].arguments
end

function Simulation.isEscorting(shipName)
    for ship, description in pairs(self.commandDescriptions) do
        if ship == shipName and description.command == CommandType.Escort then
            return true
        end
    end

    return false
end

function Simulation.getDescriptionText(shipName)
    for ship, description in pairs(self.commandDescriptions) do
        if ship == shipName then
            local text = description.text % _t % description.arguments

            -- not doing a recursive call on purpose here to avoid pot. infinite recursions in case 2 escort ships would escort each other
            -- this should be impossible anyway but I'm just making sure
            if description.command == CommandType.Escort then
                for other, otherDescription in pairs(self.commandDescriptions) do
                    if other == description.escortee then
                        local addition = otherDescription.text % _t % otherDescription.arguments
                        text = text .. " " .. addition
                    end
                end
            end

            return text
        end
    end

    return ""
end

function Simulation.getDescription(shipName)
    for ship, description in pairs(self.commandDescriptions) do
        if ship == shipName then
            return description
        end
    end
end

function Simulation.getAreaBounds(shipName)
    for ship, description in pairs(self.commandDescriptions) do
        if ship == shipName then
            return description.area
        end
    end
end

function Simulation.requestReachableSectors(shipName, callerScript)
    if onClient() then
        invokeServerFunction("requestReachableSectors", shipName, callerScript)
        return
    end

    for _, command in pairs(self.commands) do
        if command.shipName == shipName then
            if command.area and command.area.analysis then
                invokeClientFunction(Player(callingPlayer), "receiveReachableSectors", shipName, command.area.analysis.reachableCoordinates, callerScript)
            end

            break
        end
    end
end
callable(Simulation, "requestReachableSectors")

function Simulation.receiveReachableSectors(shipName, reachable, callerScript)
    local faction = getParentFaction()
    Player():invokeFunction(callerScript or "mapcommands.lua", "receiveReachableSectors", faction.index, shipName, reachable)
end

function Simulation.sync(yields, commandDescriptions, uiData)
    if onClient() then
        if not yields then
            invokeServerFunction("sync")
        else
            self.yields = yields
            self.commandDescriptions = commandDescriptions
            self.uiData = uiData
        end
    else

        -- pack up UI data for the client
        local uiData = {}
        for _, command in pairs(self.commands) do
            uiData[command.shipName] = command.uiData
        end

        if isAllianceScript() then
            local alliance = Alliance()
            local onlineMembers = {alliance:getOnlineMembers()}

            for _, playerIndex in pairs(onlineMembers) do
                invokeClientFunction(Player(playerIndex), "sync", self.yields, self.commandDescriptions, uiData)
            end
        else
            invokeClientFunction(Player(callingPlayer), "sync", self.yields, self.commandDescriptions, uiData)
        end
    end
end
callable(Simulation, "sync")

function Simulation.takeYield(shipName)
    if onClient() then
        invokeServerFunction("takeYield", shipName)
        return
    end

    local yield = Simulation.takeRawYield(shipName)
    if not yield then return end

    Simulation.transformYield(yield)

    local faction = getParentFaction()
    if yield.money > 0 then
        local description = Format("Received ¢%1% from your ship %2%."%_T, createMonetaryString(yield.money), yield.ship)
        faction:receive(description, yield.money)
    end

    if #yield.resources > 0 then
        local description = Format("Received resources from your ship %1%."%_T, yield.ship)
        faction:receive(description, 0, unpack(yield.resources))
    end

    local inventory = faction:getInventory()
    for _, item in pairs(yield.items) do
        inventory:add(item, true)
    end

    return yield
end
callable(Simulation, "takeYield")

function Simulation.startCommand(shipName, type, config)
    if onClient() then
        invokeServerFunction("startCommand", shipName, type, config)
        return
    end

    -- ensure arguments are correct
    if anynils(shipName, type, config) then return end

    -- we can only start commands for ships that are available
    local faction = getParentFaction()
    local player = Player(callingPlayer)
    if not player then player = faction end

    local ignoredErrors
    local command = CommandFactory.makeCommand(type)
    if command.getIgnoredErrors then
        ignoredErrors = command:getIgnoredErrors() or {}
    end

    local error = SimulationUtility.isShipUsable(faction.index, shipName, ignoredErrors)
    if error then
        if error == SimulationUtility.UsableError.Unavailable then
            player:sendChatMessage("", ChatMessageType.Error, "Ship not available."%_T)
        elseif error == SimulationUtility.UsableError.NotAShip then
            player:sendChatMessage("", ChatMessageType.Error, "This isn't a ship."%_T)
        elseif error == SimulationUtility.UsableError.NoCaptain then
            player:sendChatMessage("", ChatMessageType.Error, "Ship doesn't have a captain."%_T)
        elseif error == SimulationUtility.UsableError.BadCrew then
            player:sendChatMessage("", ChatMessageType.Error, "There are issues with the crew."%_T)
        elseif error == SimulationUtility.UsableError.BadEnergy then
            player:sendChatMessage("", ChatMessageType.Error, "Ship doesn't fulfill minimal energy requirements."%_T)
        elseif error == SimulationUtility.UsableError.Damaged then
            player:sendChatMessage("", ChatMessageType.Error, "The ship is damaged."%_T)
        elseif error == SimulationUtility.UsableError.UnderAttack then
            player:sendChatMessage("", ChatMessageType.Error, "The ship is under attack!"%_T)
        end

        return
    end

    if faction.isAlliance and callingPlayer then
        if not faction:hasPrivilege(callingPlayer, AlliancePrivilege.ManageShips) then
            player:sendChatMessage("", 1, "You don't have permission to manage alliance ships."%_T)
            return
        end
    end

    -- find the last analyzed area for this type of command
    local lastAnalyzed = self.analyzedAreas[shipName]
    if not lastAnalyzed or lastAnalyzed.command ~= type or not lastAnalyzed.area then
        player:sendChatMessage("", ChatMessageType.Error, "No area analyzed for %1%."%_T, shipName)
        return
    end

    local area = lastAnalyzed.area

    -- note: There is no need to check that no captain/cargo/armament change
    --       happened since the area analysis (and thus the client prediction).
    --       Cheat-Scenario: Open Map, do analysis with amazing captain/equipment,
    --       somehow change captain or equipment for a worse version (via alliance member, for example), start order.
    --       Uncritical Because: The command will do its thing based on the ShipDatabaseEntry (after it disappeared into the background),
    --       not the prediction done on the client. Even if the cheat would be attempted,
    --       the command would be working with the worse variant of the captain/equipment.

    -- check that escorting ships are in the area and available
    config.escorts = config.escorts or {}
    for _, escorter in pairs(config.escorts) do
        local error, secondaryError = SimulationUtility.isShipUsableAsEscort(faction, escorter, shipName)

        if error then
            if error == SimulationUtility.EscortError.Unavailable then
                player:sendChatMessage("", ChatMessageType.Error, "Escorting ship '%1%' not available."%_T, escorter)
            elseif error == SimulationUtility.EscortError.TooFarAway then
                player:sendChatMessage("", ChatMessageType.Error, "Escorting ship '%1%' is too far away."%_T, escorter)
            elseif error == SimulationUtility.EscortError.Unreachable then
                player:sendChatMessage("", ChatMessageType.Error, "Escorting ship '%1%' can't reach the ship."%_T, escorter)
            elseif error == SimulationUtility.EscortError.Unusable then

                if secondaryError == SimulationUtility.UsableError.Unavailable then
                    player:sendChatMessage("", ChatMessageType.Error, "Escorting ship '%1%' not available."%_T, escorter)
                elseif secondaryError == SimulationUtility.UsableError.NotAShip then
                    player:sendChatMessage("", ChatMessageType.Error, "'%1%' isn't a ship."%_T, escorter)
                elseif secondaryError == SimulationUtility.UsableError.NoCaptain then
                    player:sendChatMessage("", ChatMessageType.Error, "Escorting ship '%1%' doesn't have a captain."%_T, escorter)
                elseif secondaryError == SimulationUtility.UsableError.BadCrew then
                    player:sendChatMessage("", ChatMessageType.Error, "Escorting ship '%1%' has issues with the crew."%_T, escorter)
                elseif secondaryError == SimulationUtility.UsableError.BadEnergy then
                    player:sendChatMessage("", ChatMessageType.Error, "Escorting ship '%1%' doesn't fulfill minimal energy requirements."%_T, escorter)
                elseif secondaryError == SimulationUtility.UsableError.Damaged then
                    player:sendChatMessage("", ChatMessageType.Error, "Escorting ship '%1%' is damaged."%_T, escorter)
                elseif secondaryError == SimulationUtility.UsableError.UnderAttack then
                    player:sendChatMessage("", ChatMessageType.Error, "Escorting ship '%1%' is under attack!"%_T, escorter)
                else
                    player:sendChatMessage("", ChatMessageType.Error, "Escorting ship '%1%' not available."%_T, escorter)
                end
            end
            return
        end
    end

    -- create the command and check the area size & configs
    local command = Simulation.makeCommand(type, shipName, area, config)
    command:clampConfig(faction.index, shipName)

    -- check that the area is still the correct size, captain may have changed since startAreaAnalysis
    local allowedSizes = {command:getAreaSize(faction.index, shipName)}
    local matches = false
    for _, allowedSize in pairs(allowedSizes) do
        local size = {x = area.upper.x - area.lower.x + 1, y = area.upper.y - area.lower.y + 1} -- +1 because upper is inclusive

        if size.x == allowedSize.x and size.y == allowedSize.y then
            matches = true
            break
        end
    end

    if not matches then
        player:sendChatMessage("", ChatMessageType.Error, "Area size for %1% changed."%_T, shipName)
        return
    end

    -- check that the ship is still in the area (if the command dictates it)
    if command:isShipRequiredInArea(faction.index, shipName) then
        local x, y = faction:getShipPosition(shipName)
        local inside = (x >= area.lower.x and y >= area.lower.y and x <= area.upper.x and y <= area.upper.y)

        if not inside then
            player:sendChatMessage("", ChatMessageType.Error, "Ship is not inside the target area."%_T)
            return
        end
    end

    -- check that the config doesn't have any errors
    local error, args = command:getErrors(faction.index, command.shipName, command.area, command.config)
    if error then
        if error == true then
            error = "Error in command configuration."%_T
            args = {}
        end

        player:sendChatMessage("", ChatMessageType.Error, error, unpack(args or {}))
        return
    end

    -- check that the command can initialize
    local error, args = command:initialize()
    if error then
        player:sendChatMessage("", ChatMessageType.Error, error, unpack(args or {}))
        return
    end

    -- check that the command can start
    local error, args = command:onStart()
    if error then
        player:sendChatMessage("", ChatMessageType.Error, error, unpack(args or {}))
        return
    end

    -- let the ship disappear into the background (deletes it where necessary)

    faction:setShipAvailability(shipName, ShipAvailability.InBackground)

    -- get ship status message to set from command
    local entry = ShipDatabaseEntry(faction.index, shipName)
    local status = command:getStatusMessage()
    if status then
        entry:setStatusMessage(status)
    end

    -- send escort into background as well
    for _, escorter in pairs(config.escorts) do
        faction:setShipAvailability(escorter, ShipAvailability.InBackground)
    end

    -- save UI data that will be sent to the client for displaying running commands
    command.uiData = {}
    command.uiData.config = command.config
    command.uiData.area = SimulationUtility.getAreaStats(command.area)
    command.uiData.prediction = command:calculatePrediction(faction.index, command.shipName, command.area, command.config)
    command.uiData.assessment = command:generateAssessmentFromPrediction(command.uiData.prediction, entry:getCaptain(), faction.index, command.shipName, command.area, command.config)

    -- everything is okay, we can start the command
    table.insert(self.commands, command)

    self.analyzedAreas[shipName] = nil

    faction:sendCallback("onBackgroundCommandStarted", shipName, command.type)

    -- start Escort commands for the escorting ships
    for _, escorter in pairs(config.escorts) do
        local area = {}
        local config = {escortedShip = shipName}

        local escortCommand = Simulation.makeCommand(CommandType.Escort, escorter, area, config)
        table.insert(self.commands, escortCommand)

        self.analyzedAreas[escorter] = nil

        -- set ship status to escort
        local entry = ShipDatabaseEntry(faction.index, escorter)
        local status = escortCommand:getStatusMessage()
        entry:setStatusMessage(status)
    end

    Simulation.updateCommandDescriptions()
end
callable(Simulation, "startCommand")

function Simulation.finishCommand(shipName)

    print ("Server: finishing " .. shipName .. " ...")

    local faction = getParentFaction()
    if faction:getShipAvailability(shipName) ~= ShipAvailability.InBackground then return end

    -- remove the command in question
    local escorts = {}
    local finishedCommand = nil
    for i, command in pairs(self.commands) do
        if command.shipName == shipName then
            Simulation.finalize(shipName)
            command:onFinish()
            table.remove(self.commands, i)

            escorts = command.config.escorts or {}
            finishedCommand = command
        end
    end

    -- restore the availability state so the ship gets restored
    faction:setShipAvailability(shipName, ShipAvailability.Available)

    if finishedCommand then
        faction:sendCallback("onBackgroundCommandFinished", shipName, finishedCommand.type)
    end

    -- resurface escorts
    for _, escorter in pairs(escorts) do
        Simulation.finishCommand(escorter)
    end

    print ("Server: Finish successful")

    Simulation.updateCommandDescriptions()
end

function Simulation.recall(shipName)
    if onClient() then
        invokeServerFunction("recall", shipName)

        -- send a force recall immediately afterwards, in case something went wrong while recalling
        invokeServerFunction("forceRecall", shipName)
        return
    end

    local faction = getParentFaction()
    if faction.isAlliance and callingPlayer then
        if not faction:hasPrivilege(callingPlayer, AlliancePrivilege.ManageShips) then
            Player(callingPlayer):sendChatMessage("", ChatMessageType.Error, "You don't have permission to manage alliance ships."%_T)
            return
        end
    end

    print ("Server: recalling " .. shipName .. " ...")

    if faction:getShipAvailability(shipName) ~= ShipAvailability.InBackground then return end

    -- remove the command in question
    local escorts = {}
    local finishedCommand = nil
    for i, command in pairs(self.commands) do
        if command.shipName == shipName then
            local error, args = command:getRecallError()
            if error then
                Player(callingPlayer):sendChatMessage("", ChatMessageType.Error, error, unpack(args or {}))
                return
            end

            Simulation.finalize(shipName)

            command:onRecall()
            table.remove(self.commands, i)

            escorts = command.config.escorts or {}
            finishedCommand = command
        end
    end

    -- restore the availability state so the ship gets restored
    faction:setShipAvailability(shipName, ShipAvailability.Available)

    if finishedCommand then
        faction:sendCallback("onBackgroundCommandRecalled", shipName, finishedCommand.type)
    end

    -- resurface escorts
    for _, escorter in pairs(escorts) do
        Simulation.finishCommand(escorter)
    end

    print ("Server: Recall successful")

    Simulation.updateCommandDescriptions()
end
callable(Simulation, "recall")

function Simulation.forceRecall(shipName)
    if onClient() then
        invokeServerFunction("forceRecall", shipName)
        return
    end

    local faction = getParentFaction()
    if faction.isAlliance and callingPlayer then
        if not faction:hasPrivilege(callingPlayer, AlliancePrivilege.ManageShips) then
            return
        end
    end

    if faction:getShipAvailability(shipName) ~= ShipAvailability.InBackground then return end

    for i, command in pairs(self.commands) do
        if command.shipName == shipName then
            local error, args = command:getRecallError()
            if error then
                return
            end
        end
    end

    print ("Server: force recalling " .. shipName .. " ...")

    -- restore the availability state so the ship gets restored
    faction:setShipAvailability(shipName, ShipAvailability.Available)
end
callable(Simulation, "forceRecall")

function Simulation.startAreaAnalysis(shipName, type, area)
    if onClient() then
        invokeServerFunction("startAreaAnalysis", shipName, type, area)
        return
    end

    if anynils(shipName, type, area) then return end

    -- only a certain number of analyses can be started in a certain time frame to not overload the system
    if not Simulation.canStartNewAnalysis() then
        print ("Too many area analysis requests from %s", getParentFaction().name)
        return
    end

    local faction = getParentFaction()
    if faction.isAlliance and callingPlayer then
        if not faction:hasPrivilege(callingPlayer, AlliancePrivilege.ManageShips) then
            Player(callingPlayer):sendChatMessage("", 1, "You don't have permission to manage alliance ships."%_T)
            return
        end
    end

    -- security/performance: only start area analysis for ships that are available
    if faction:getShipAvailability(shipName) ~= ShipAvailability.Available then return end

    -- clamp area to allowed size
    local command = CommandFactory.makeCommand(type)
    local allowedSizes = {command:getAreaSize(faction.index, shipName)}

    if command:isAreaFixed(faction.index, shipName) then
        local allowedSize = allowedSizes[1]
        local x, y = faction:getShipPosition(shipName)

        local halfX = math.floor((allowedSize.x - 1) / 2)
        local halfY = math.floor((allowedSize.y - 1) / 2)

        area.lower.x = x - halfX
        area.lower.y = y - halfY

        area.upper.x = area.lower.x + allowedSize.x - 1 -- minus 1 because upper is inclusive
        area.upper.y = area.lower.y + allowedSize.y - 1 -- minus 1 because upper is inclusive
    else
        local sx = area.upper.x - area.lower.x + 1
        local sy = area.upper.y - area.lower.y + 1

        -- check if it matches one of the allowed sizes
        local matches = false
        for _, allowedSize in pairs(allowedSizes) do
            if sx == allowedSize.x and sy == allowedSize.y then
                matches = true
                break
            end
        end

        if not matches then
            local allowedSize = allowedSizes[1]
            area.upper.x = area.lower.x + allowedSize.x - 1 -- minus 1 because upper is inclusive
            area.upper.y = area.lower.y + allowedSize.y - 1 -- minus 1 because upper is inclusive
        end
    end

    -- ensure that ship is inside the target area
    if command:isShipRequiredInArea(faction.index, shipName) then
        local x, y = faction:getShipPosition(shipName)
        local inside = (x >= area.lower.x and y >= area.lower.y and x <= area.upper.x and y <= area.upper.y)

        if not inside then
            faction:sendChatMessage("", ChatMessageType.Error, "Ship is not inside the target area."%_T)
            return
        end
    end

    print ("server: startAreaAnalysis", callingPlayer)

    Simulation.registerAnalysisStart()

    Simulation.analyzeArea(shipName, type, area, callingPlayer)
end
callable(Simulation, "startAreaAnalysis")

function Simulation.areaAnalysisFinished(shipName, type, area, results, callingPlayer)
    if onServer() then
        print ("server: finished AreaAnalysis", callingPlayer)

        local player = Player(callingPlayer)
        if valid(player) then
            invokeClientFunction(player, "areaAnalysisFinished", shipName, type, area, results)
        end

        -- remember the result of this analysis
        area.analysis = results
        self.analyzedAreas[shipName] = {command = type, area = area};
        return
    end

    local player = Player()
    local shipOwner = getParentFaction()
    local ownerIndex = shipOwner.index

    player:invokeFunction("data/scripts/player/map/mapcommands.lua", "onAreaAnalysisFinished", ownerIndex, shipName, type, area, results)

    print ("Client: Simulation.areaAnalysisFinished", ownerIndex, player.index)
end


if onServer() then

function Simulation.getUpdateInterval()
    -- chosen by gut feeling to keep simulation light-weight, feel free to change if necessary
    return 60 / SpeedUp
end

function Simulation.update(timeStep)

    timeStep = timeStep * SpeedUp

    Simulation.updateAttacks(timeStep)

    Simulation.cleanUp()
    Simulation.restoreShipsWithoutCommands()
    Simulation.simulate(timeStep)
    Simulation.updateCommandDescriptions()
end

-- only a certain amount of analyses can be started in a certain timeframe to not overload the server (by cheaters)
function Simulation.canStartNewAnalysis()

    -- we allow [threshold] analyses to be started over a time of [timeframe] seconds
    -- note: we allow 2 per 1 second and not 10 per 5 seconds so that no 10 can be started in 0.01s, potentially causing issues
    local timeframe = 1
    local threshold = 2

    -- we could also use appTime() here, but it's harder to handle in unit tests as it's not modifiable (as if tied to system clock)
    -- Server().unpausedRuntime can be directly modified in unit tests and for this code it doesn't really make a difference which one we use
    -- so we're going with Server().unpausedRuntime
    local now = Server().unpausedRuntime

    local queue = self.startedAnalyses

    -- the queue is sorted chronologically so we can just remove values from the front until we arrive at a value that's too recent
    while not queue:empty() do
        local startTime = queue:front()
        local passed = now - startTime
        if passed > timeframe then
            queue:popFront()
        else
            break
        end
    end

    return queue:size() < threshold
end

-- for unit testing
function Simulation.getStartedAnalysesQueueSize()
    return self.startedAnalyses:size()
end

function Simulation.registerAnalysisStart()
    local now = Server().unpausedRuntime
    self.startedAnalyses:pushBack(now)
end

function Simulation.clearAreaAnalysisQueue()
    self.startedAnalyses:clear()
end

function Simulation.updateAttacks(timeStep)
    for _, command in pairs(self.commands) do
        if command.data
                and command.data.attack
                and command.data.attack.countDown then

            command.data.attack.countDown = command.data.attack.countDown - timeStep
            if command.data.attack.countDown <= 0 then
                Simulation.startAttack(command.shipName)
                command.data.attack.countDown = nil -- to make sure we don't try to start the attack twice
            end
        end
    end
end

function Simulation.clearAreaAnalysisQueue()
    self.startedAnalyses:clear()
end

function Simulation.cleanUp()
    -- remove commands where the ship is not currently in background simulation
    -- concept: database is always correct and we have to follow it

    local faction = getParentFaction()
    local stopped = {}
    local escorts = {}
    local escortees = {}

    for i, command in pairs(self.commands) do
        if command.diagnostics then
            table.insert(stopped, i)
            eprint("Removed broken command: '%s', type: %s, ship: '%s'", command.diagnostics.name, command.type, command.shipName)
            goto continue
        end

        if faction:getShipAvailability(command.shipName) ~= ShipAvailability.InBackground then
            table.insert(stopped, i)

            for _, escort in pairs(command.config.escorts or {}) do
                table.insert(escorts, escort)
            end

            if command.config.escortedShip then
                table.insert(escortees, command.config.escortedShip)
            end
        end

        ::continue::
    end

    -- since we're removing by index, we have to sort the removal order to start at the end
    -- otherwise the indices are displaced once the first one was removed
    table.sort(stopped, function(a, b) return a > b end)

    for _, index in pairs(stopped) do
        print("Removed command %s because the ship in question is no longer in BG simulation", CommandFactory.getCommandName(self.commands[index].type))
        table.remove(self.commands, index)
    end

    -- resurface escorts of stopped commands
    for _, escort in pairs(escorts) do
        Simulation.finishCommand(escort)
    end

    -- resurface escortees of stopped commands
    for _, escortee in pairs(escortees) do
        Simulation.recall(escortee)
    end

    -- remove all areas that were analyzed but not used and the ship was renamed
    for shipName, area in pairs(self.analyzedAreas) do
        if not faction:ownsShip(shipName) then
            self.analyzedAreas[shipName] = nil
        end
    end
end

function Simulation.restoreShipsWithoutCommands()
    local faction = getParentFaction()
    local names = {}

    -- find all ships that are in background simulation
    for _, name in pairs({faction:getShipNames()}) do
        if faction:getShipAvailability(name) == ShipAvailability.InBackground then
            names[name] = true
        end
    end

    -- now filter ships that have a running command
    for i, command in pairs(self.commands) do
        names[command.shipName] = nil
    end

    -- all remaining ships are in background but don't have a command running -> restore them
    for name, _ in pairs(names) do
        faction:setShipAvailability(name, ShipAvailability.Available)
    end

end

function Simulation.simulate(timeStep)

    -- make a copy since commands can remove themselves during update(), messing up the for loop
    local copy = {}
    for _, command in pairs(self.commands) do
        table.insert(copy, command)
    end

    local faction = getParentFaction()
    for _, command in pairs(copy) do
        command.diagnostics = {name = "update()"}

        command:update(timeStep)

        -- get ship status message to set from command
        local entry = ShipDatabaseEntry(faction.index, command.shipName)
        if entry then
            local status = command:getStatusMessage()
            entry:setStatusMessage(status or "")
        end

        command.simInternals.runtime = command.simInternals.runtime + timeStep

        command.diagnostics = nil
    end

end

function Simulation.updateCommandDescriptions()

    local descriptions = {}

    for _, command in pairs(self.commands) do
        command.diagnostics = {name = "updateCommandDescriptions()"}

        local description = {}
        description.command = command.type

        local text, args = command:getDescriptionText()
        text = text or ""
        args = args or {}
        description.text = text
        description.arguments = args
        description.area = command:getAreaBounds()

        if command.type == CommandType.Escort then
            description.escortee = command.config.escortedShip
        end

        descriptions[command.shipName] = description

        command.diagnostics = nil
    end

    self.commandDescriptions = descriptions

    Simulation.sync()
end

function Simulation.analyzeArea(shipName, type, area, callingPlayer)
    self.analyzedAreas[shipName] = nil

    asyncf("areaAnalysisFinished", "data/scripts/player/background/simulation/areaanalysis.lua", getParentFaction().index, shipName, type, area, callingPlayer)
end

function Simulation.startAttack(shipName)
    local command
    for _, c in pairs(self.commands) do
        if c.shipName == shipName then
            command = c
            break
        end
    end

    if not command then return end

    local attack = command.data.attack
    local shipName = command.shipName

    -- check ship is actually still in background
    local faction = getParentFaction()
    if faction:getShipAvailability(shipName) ~= ShipAvailability.InBackground then return end

    -- move ship and escort (if existing) to precalculated sector
    local shipDatabaseEntry = ShipDatabaseEntry(faction.index, shipName)
    shipDatabaseEntry:setCoordinates(attack.coordinates.x, attack.coordinates.y)

    -- notify faction
    if attack.message and attack.message ~= "" then
        faction:sendChatMessage(shipName, ChatMessageType.Warning, attack.message, unpack(attack.arguments))
    else
        faction:sendChatMessage(shipName, ChatMessageType.Warning, "Your ship '%1%' is under attack in sector \\s(%2%:%3%)!"%_T, shipName, attack.coordinates.x, attack.coordinates.y)
    end

    -- add attack script to entity
    if attack.faction and attack.faction > 0 and not FactionEradicationUtility.isFactionEradicated(attack.faction) then
        shipDatabaseEntry:addScriptOnce("data/scripts/entity/events/factionattackentity.lua")
    else
        shipDatabaseEntry:addScriptOnce("data/scripts/entity/events/piratesattackentity.lua")
    end

    -- add setAggressive script for escorts (if existing)
    local escorts = {}
    for i, command in pairs(self.commands) do
        if command.shipName == shipName then
            escorts = command.config.escorts or {}
        end
    end

    for _, escorter in pairs(escorts) do
        local shipDatabaseEntry = ShipDatabaseEntry(faction.index, escorter)
        shipDatabaseEntry:addScriptOnce("data/scripts/entity/events/setbgescortsaggressive.lua")
    end

    -- call onAttacked() of command
    command:onAttacked(attack.faction, attack.coordinates.x, attack.coordinates.y)

    -- remove the command in question and recall ship and escort
    Simulation.recall(shipName)
end

function Simulation.finalize(shipName, skipLeveling)
    local command
    for _, c in pairs(self.commands) do
        if c.shipName == shipName then
            command = c
            break
        end
    end

    if not command then return end

    local faction = getParentFaction()
    local entry = ShipDatabaseEntry(faction.index, shipName)
    local hours = command.simInternals.runtime / 3600

    -- generally ships are healed completely in ca 1h by mechanics, provided they have enough (which they must to enter BG simulation)
    -- they can be healed quicker sometimes, but this is mostly to simulate ships being repaired over time if you send them away
    local healedPercentage = hours
    local maxHP, healthPercentage, malusFactor, malusReason, damaged = entry:getDurabilityProperties()
    healthPercentage = math.min(1.0, healthPercentage + healedPercentage)

    local captain = entry:getCaptain()

    -- an unlucky captain might get the ship damaged on return
    if healthPercentage > 0.2 and captain:hasPerk(CaptainUtility.PerkType.Unlucky) then
        local chance = CaptainUtility.getUnluckyPerk(captain, CaptainUtility.PerkType.Unlucky)
        chance = chance * hours

        if random():test(chance) then
            local damage = random():getFloat(0.2, 0.4) -- between 20% and 40% damage
            healthPercentage = math.max(0.2, healthPercentage - damage)
        end
    end

    -- lucky captain might find something valuable
    if captain:hasPerk(CaptainUtility.PerkType.Lucky) then
        local x, y = entry:getCoordinates()
        local items = {}
        CaptainUtility.generateLuckyFinishingItems(items, captain, {x = x, y = y}, hours)

        local lines = {}
        table.insert(lines, "Commander, we were lucky and found an absurdly large asteroid with all kinds of stuff in it!"%_T)
        table.insert(lines, "Commander, we're in luck! There was a stash inside of an asteroid that had all kinds of goods in it!"%_T)
        table.insert(lines, "Commander, during the mission we stumbled upon an old wreckage. Not worth salvaging for scrap metal, but we were lucky and found these!"%_T)
        table.insert(lines, "Commander, luck was on our side! During the mission I found a stash with all kinds of goods in it!"%_T)
        table.insert(lines, "Commander, today must be our lucky day! First there was a loud crash, but then I noticed that we had rammed a container full of valuable goods. Fortunately, nothing happened to the ship or the goods!"%_T)

        -- avoid empty yield messages
        local hasItems = false
        if items.turrets and #items.turrets > 0 then
            hasItems = true
        elseif items.subsystems and #items.subsystems > 0 then
            hasItems = true
        elseif items.blueprints and #items.blueprints > 0 then
            hasItems = true
        end

        if hasItems then
            Simulation.addYield(shipName, randomEntry(lines), nil, nil, items)
        end
    end

    if not skipLeveling then -- variable is only used in testing
        -- let captain gain experience and level up
        -- this is intentionally done after the application of the other perks
        local level = captain.level
        CaptainUtility.applyLeveling(captain, command.simInternals.runtime / 60)
        if captain.level > level then
            faction:sendChatMessage("", ChatMessageType.Information, "Captain %1% has reached level %2%!"%_T, captain.displayName, captain.level + 1)

            if captain.level == 4 and captain.tier == 0 then
                if command.type == CommandType.Mine then captain.primaryClass = CaptainClass.Miner end
                if command.type == CommandType.Refine then captain.primaryClass = CaptainClass.Miner end
                if command.type == CommandType.Salvage then captain.primaryClass = CaptainClass.Scavenger end
                if command.type == CommandType.Expedition then captain.primaryClass = CaptainClass.Daredevil end
                if command.type == CommandType.Scout then captain.primaryClass = CaptainClass.Explorer end
                if command.type == CommandType.Travel then captain.primaryClass = CaptainClass.Explorer end
                if command.type == CommandType.Procure then captain.primaryClass = CaptainClass.Merchant end
                if command.type == CommandType.Maintenance then captain.primaryClass = CaptainClass.Merchant end
                if command.type == CommandType.Sell then captain.primaryClass = CaptainClass.Merchant end
                if command.type == CommandType.Supply then captain.primaryClass = CaptainClass.Merchant end
                if command.type == CommandType.Trade then captain.primaryClass = CaptainClass.Merchant end
                if command.type == CommandType.Escort then captain.primaryClass = CaptainClass.Commodore end
                if command.type == CommandType.Prototype then captain.primaryClass = CaptainClass.Daredevil end -- just for test

                local classProperties = CaptainUtility.ClassProperties()
                local primary = classProperties[captain.primaryClass]

                if captain.genderId == CaptainGenderId.Male then
                    faction:sendChatMessage("", ChatMessageType.Information, "Captain %1% has acquired the specialization: %2%!"%_T, captain.displayName, primary.displayName)
                else
                    faction:sendChatMessage("", ChatMessageType.Information, "Captain %1% has acquired the specialization: %2%!"%_T, captain.displayName, primary.displayNameFemale)
                end
            end
        end
    end

    entry:setCaptain(captain)
    entry:setDurabilityPercentage(healthPercentage)

    -- update passed time for relevant components
    entry:setScriptValue("time_to_catch_up", command.simInternals.runtime)
    entry:addScriptOnce("data/scripts/entity/utility/catchupcomponents.lua")
end

function Simulation.addYield(shipName, message, money, resources, items)
    local yield = {}
    yield.ship = shipName
    yield.message = message or ""
    yield.money = money or 0
    yield.resources = resources or {}
    yield.items = items or {}

    -- this sets correctly randomly selected values for all unspecified properties of the yield
    -- ie. sets turret rarities to correct, randomly selected rarities. same with weapon types, script types, etc.
    Simulation.makeYieldItems(yield)

    table.insert(self.yields, yield)

    Simulation.sync()
end

function Simulation.takeRawYield(shipName)

    local result = nil

    -- if there is a ship that's no longer in the list of ships (because it was destroyed, deleted or renamed etc)
    -- we take that orphaned yield first so nothing gets lost
    local faction = getParentFaction()

    for i, yield in pairs(self.yields) do

        if not faction:ownsShip(yield.ship) then
            table.remove(self.yields, i)
            result = yield
            break
        end
    end

    -- otherwise take the yield of the given ship
    if not result then
        for i, yield in pairs(self.yields) do
            if yield.ship == shipName then
                table.remove(self.yields, i)
                result = yield
                break
            end
        end
    end

    Simulation.sync()

    return result
end

function Simulation.onShipAvailabilityUpdated()
    Simulation.cleanUp()
end

function Simulation.secure()

    -- we can't just simply return the data.commands collection since we have tables with functions and metatables (read: classes) in it
    -- instead we walk over all commands and secure their data
    local secured = {}
    secured.commands = {}

    for _, command in pairs(self.commands) do
        command:onSecure()

        local data = {
            type = command.type,
            shipName = command.shipName,
            area = command.area,
            config = command.config or {},
            data = command.data or {},
            simInternals = command.simInternals or {runtime = 0},
            uiData = command.uiData or {},
        }

        table.insert(secured.commands, data)
    end

    secured.yields = self.yields

    return secured
end

function Simulation.restore(secured)
    self.yields = secured.yields or {}

    self.commands = {}

    -- we have to restore each command from its type
    for _, data in pairs(secured.commands or {}) do
        -- recreate the correct command, must be done based on type since we recreate a class here
        local command = Simulation.makeCommand(data.type, data.shipName, data.area, data.config)
        command.data = data.data
        command.simInternals = data.simInternals
        command.uiData = data.uiData

        command:onRestore()

        table.insert(self.commands, command)
    end

    Simulation.updateCommandDescriptions()
end

function Simulation.invokeCommandFunction(shipName, functionName, ...)
    for _, command in pairs(self.commands) do
        if command.shipName == shipName then
            local func = command[functionName]
            if func then
                func(command, ...)
            end
        end
    end
end

-- for unit tests
function Simulation.calculatePrediction(ownerIndex, shipName, config)
    local lastAnalyzed = self.analyzedAreas[shipName]
    local command = Simulation.makeCommand(lastAnalyzed.command)

    return command:calculatePrediction(ownerIndex, shipName, lastAnalyzed.area, config)
end

function Simulation.setFixedRandomness(...)
    setFixedRandomness(...)
end

function Simulation.registerTestAttack(shipName, coords, timeOfAttack)
    for _, command in pairs(self.commands) do
        if command.shipName == shipName then
            command:registerForAttack(coords, 0, timeOfAttack, "Test Attack", {})
        end
    end
end

end

