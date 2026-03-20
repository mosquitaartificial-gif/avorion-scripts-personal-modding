package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/player/background/simulation/?.lua"

local CommandType = include ("commandtype")
local SimulationUtility = include ("simulationutility")
local CaptainUtility = include ("captainutility")
include ("utility")


local PrototypeCommand = {}
PrototypeCommand.__index = PrototypeCommand
PrototypeCommand.type = CommandType.Prototype

-- all commands need this kind of "new" to function within the bg simulation framework
-- it must be possible to call the command without any parameters to access some functionality
local function new(ship, area, config)
    local command = setmetatable({
        -- all commands need these variables to function within the bg simulation framework
        -- type contains the CommandType of the command, required to restore
        type = CommandType.Prototype,

        -- the ship that has the command
        shipName = ship,

        -- the area where the ship is doing its thing
        area = area,

        -- config that was given to the ship
        config = config,

        -- holds any data necessary to fulfill the command, that should be saved to database, eg. timers and so on
        -- this should only contain variables that can be saved to database (eg. returned in a secure()) call
        -- this will be automatically restored/secured
        data = {},

        -- will be set from external, only listed here for completeness' sake
        simulation = nil,
    }, PrototypeCommand)

    command.data.runTime = 0
    command.data.yieldCounter = 0

    -- print ("Prototype()")

    return command
end

-- all commands have the following functions, even if not listed here (added by Simulation script on command creation):
-- function PrototypeCommand:addYield(message, money, resources, items) end
-- function PrototypeCommand:finish() end
-- function PrototypeCommand:registerForAttack(coords, faction, timeOfAttack, message, arguments) end



-- you can return an error message here such as:
-- return "Command cannot initialize because %1% and %2% went wrong", {"Player", "Config"}
function PrototypeCommand:initialize()
    print ("Prototype: initialize")

    local parent = getParentFaction()
    local prediction = self:calculatePrediction(parent.index, self.shipName, self.area, self.config)
    print ("# Received Area:")
    printTable(self.area)
    print ("# Received Config:")
    printTable(self.config)
    print ("# Prediction:")
    printTable(prediction)

    if self.config.initializationError then
        return "Prototype Command reports %1% test error in initialize() '%2%'!", {"1", "foo"}
    end

end

-- this is the regularly called function to update the time passing while the command is running
-- timestep is typically a longer period, such as a minute
-- this function should be as lightweight as possible. best practice is to
-- only do count downs here and do all calculations during area analysis and initialization
function PrototypeCommand:update(timeStep)

    if self.config.crashDuringUpdate then
        if self.fantasy.test > 0 then
            print ("This should never be printed")
        end
    end

    -- every 30m we yield something
    self.data.runTime = self.data.runTime + timeStep
    self.data.yieldCounter = self.data.yieldCounter + timeStep

    if self.data.runTime >= 120 * 60 then
        self:finish()
        return
    end

    if self.data.yieldCounter >= 30 * 60 then
        self.data.yieldCounter = self.data.yieldCounter - 30 * 60

        local money = 1500
        local resources = {200, 300, 50, 1000, 560, 10, 150}
        local items = {
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
                { x = 120, y = -350, seed = "r923slvny783", type = WeaponType.Bolter, rarity = RarityType.Rare, },
            },
        }

        self:addYield("Prototype intermediate yield Message!", money, resources, items)
    end

end

-- executed before an area analysis involving this type of command starts
-- return a table of sectors here to start a special analysis of those sectors instead of a rect
-- this will be called on a temporary instance of the command. all values written to "self" will not persist
-- note: See TravelCommand for an extensive example
function PrototypeCommand:getAreaAnalysisSectors(results, meta)
    print ("Prototype: getAreaAnalysisSectors")

end

-- executed when an area analysis involving this type of command starts
-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function PrototypeCommand:onAreaAnalysisStart(results, meta)
    print ("Prototype: onAreaAnalysisStart")

end

-- executed when an area analysis involving this type of command is checking a specific sector
-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function PrototypeCommand:onAreaAnalysisSector(results, meta, x, y)
    -- commenting this out since it's too annoying
    -- print ("Prototype: onAreaAnalysisSector")

end

-- executed when an area analysis involving this type of command finished
-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function PrototypeCommand:onAreaAnalysisFinished(results, meta)
    print ("Prototype: onAreaAnalysisFinished")

end

-- executed when the command starts for the first time (not when being restored)
-- do things like paying money in here and return errors when it's not possible because the player doesn't have enough money
-- you can return an error message here such as:
-- return "Command cannot start because %1% doesn't fulfill requirement '%2%'!", {"Player", "Money"}
-- calculate and register the command for an attack if necessary here
function PrototypeCommand:onStart()
    print ("Prototype: onStart")

    if self.config.onStartError then
        return "Prototype Command reports %1% test error in onStart() '%2%'!", {"3", "foo_bar"}
    end

    if self.config.attacked then
        self:registerForAttack({x = 50, y = 150}, nil, self.config.duration * 0.5, "Prototype Command: Ship is attacked in sector \\s(%1%:%2%).", {"50", "150"})
    end

    local parent = getParentFaction()
    local entry = ShipDatabaseEntry(parent.index, self.shipName)
    entry:setStatusMessage("Prototyping")
end

-- executed when the ship is being recalled by the player
function PrototypeCommand:onRecall()
    print ("Prototype: onRecall")
end

-- executed when the command is finished
function PrototypeCommand:onFinish()
    print ("Prototype: onFinish")

    self:addYield("Prototype final yield Message!", 2500, {220, 330, 55, 1100, 616, 11, 165}, {})
end

-- after this function was called, self.data will be read to be saved to database
function PrototypeCommand:onSecure()
    print ("Prototype: onSecure")
end

-- this is called after the command was recreated and self.data was assigned
function PrototypeCommand:onRestore()
    print ("Prototype: onRestore")
end

-- this is called when the beforehand calculated pirate or faction attack happens
-- called after notification of player and after attack script is added to the ship database entry
-- but before the ship and its escort is recalled from background
-- note: attackerFaction is nil in case of a pirate attack
function PrototypeCommand:onAttacked(attackerFaction, x, y)
    print ("Prototype: onAttacked")
end

function PrototypeCommand:getDescriptionText()
    print ("Prototype: getDescription")

    -- return the time remaining in a new line and the percent completed
    -- comfort feature for the player:
    --  - player has more information to decide whether to recall the ship or wait the remainder of time
    local totalRuntime = 120 * 60
    local timeRemaining = round((totalRuntime - self.data.runTime) / 60) * 60
    local completed = round(self.data.runTime / totalRuntime * 100)

    return "The ship is performing ${task}. Don't question.\n\nTime remaining: ${timeRemaining} (${completed} % done).", {task = "a prototype command background task", timeRemaining = createReadableShortTimeString(timeRemaining), completed = completed}
end

-- returns the message that should be shown as the current ship action in ship list
-- keep this message very short, there isn't much space here
-- the return value can be a NamedFormat
function PrototypeCommand:getStatusMessage()
    return "Prototyping Area"
end

-- returns the path to the icon that will be used in UI and on the galaxy map
function PrototypeCommand:getIcon()
    return "data/textures/icons/jigsaw-piece.png"
end

-- returns the size of the area where the command is currently running
-- this is used to visualize where the command is running at the moment
function PrototypeCommand:getAreaBounds()
    return {lower = self.area.lower, upper = self.area.upper}
end

function PrototypeCommand:getRecallError()
end

-- returns whether there are errors with the command, either in the config, or otherwise
-- (ship has no mining turrets, not enough energy, player doesn't have enough money, etc.)
-- this function is also executed on the client and used to grey out the "start" button so players know that their config is flawed
-- note: before this is called, there is already a preliminary check based on getConfigurableValues(),
-- where values are clamped or default-set
function PrototypeCommand:getErrors(ownerIndex, shipName, area, config)
    print ("Prototype: getErrors")

    -- in case of error, return an error message here that will tell players that something went wrong
    -- return "You can't set an efficiency above 100%!"
    if config.errorMsg then
        return "Prototype Command reports %1% test error in config '%2%'!", {"1", "foo"}
    end

    -- alternatively, return true for a generic error
    if config.error then
        return true
    end

    -- if your command has a
    -- function MyCommand:isValidAreaSelection(ownerIndex, shipName, area, mouseCoordinates)
    -- defined, then make sure to re-check that in here as well!

    -- if there are no errors, just return
    return
end

-- returns the size of the area where the command will run
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function PrototypeCommand:getAreaSize(ownerIndex, shipName)
    return {x = 21, y = 21}
end

-- returns whether the command requires the ship to be inside the selected area
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function PrototypeCommand:isShipRequiredInArea(ownerIndex, shipName)
    return true
end

-- returns whether the command has a fixed area. if yes, the area will be calculated with the ship in the middle
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function PrototypeCommand:isAreaFixed(ownerIndex, shipName)
    return false
end

-- returns whether the current selection on the galaxy map is acceptable
-- this is only necessary if there are any special cases outside the normal area selection
-- this is only called during the area selection phase on the client, not on the server.
-- to check this on the server, you have to check the area in the getErrors() function
-- note: this function definition is optional and can be omitted if it's not required
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function PrototypeCommand:isValidAreaSelection(ownerIndex, shipName, area, mouseCoordinates)

    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local x, y = entry:getCoordinates()
    local reach, canPassRifts, cooldown = entry:getHyperspaceProperties()

    local d = distance(vec2(x, y), vec2(mouseCoordinates.x, mouseCoordinates.y))

    return d > reach
end

-- returns the text that is shown in the tooltip while the player is selecting the area for the command
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function PrototypeCommand:getAreaSelectionTooltip(ownerIndex, shipName, area, valid)
    if valid then
        return "PrototypeCommand: Left-Click to select the Prototype Area"
    else
        return "PrototypeCommand: Invalid Location!"
    end
end

-- returns the configurable values for this command (if any).
-- variable naming should speak for itself, though you're free to do whatever you want in here.
-- config will only be used by the command itself and nothing else
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function PrototypeCommand:getConfigurableValues(ownerIndex, shipName)
    local values = { }

    -- value names here must match with values returned in ui:buildConfig() below
    values.duration = {displayName = "Duration", from = 1, to = 6, default = 2}
    values.efficiency = {displayName = "Efficiency", from = 0.1, to = 1, default = 0.8}
    values.yieldTick = {displayName = "Yield Tick", from = 5, to = 30, default = 10}

    return values
end

-- returns the predictable values for this command (if any).
-- variable naming should speak for itself, though you're free to do whatever you want in here.
-- config will only be used by the command itself and nothing else
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function PrototypeCommand:getPredictableValues()
    local values = { }

    values.yield = {displayName = "Ertrag"}
    values.pirateChance = {displayName = "Piratenangriff"}

    return values
end

-- calculate the predictions for the ship, area and config
-- gut feeling says that each config option change should always be reflected in the predictions if it impacts the behavior
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function PrototypeCommand:calculatePrediction(ownerIndex, shipName, area, config)
    local results = self:getPredictableValues()

    -- those are dummy calculations to show how it would work, roughly
    local yield = (area.analysis.sectors - area.analysis.unreachable) * 1000
    yield = yield * config.efficiency * config.duration

    results.yield.from = round(yield * 0.8)
    results.yield.to = round(yield)

    local pirateChance = SimulationUtility.calculateAttackProbability(ownerIndex, shipName, area, config.escorts, config.duration)
    results.pirateChance.value = pirateChance

    return results
end

function PrototypeCommand:generateAssessmentFromPrediction(prediction, captain, ownerIndex, shipName, area, config)

    -- please don't just copy this function. It's specific to the mine command.
    -- use it as a guidance, but don't just use the same sentences etc.

    local total = area.analysis.sectors - area.analysis.unreachable
    if total == 0 then return "In diesem Gebiet können wir nicht prototypisieren!" end

    local pirates = area.analysis.sectorsByFaction[0] or 0
    local attackChance = prediction.pirateChance.value
    local pirateSectorRatio = SimulationUtility.calculatePirateAttackSectorRatio(area)

    local resourceLines = {}
    if pirates / total >= 0.75 then
        table.insert(resourceLines, "Das Gebiet ist sehr ergiebig für Prototypen.")

    elseif pirates / total >= 0.45 then
        table.insert(resourceLines, "Das Gebiet ist ergiebig. Prototyp.")

    elseif pirates / total >= 0.05 then
        table.insert(resourceLines, "Das Gebiet ist mäßig ergiebig. Prototyp. Prototyp. Prototyp.")
    else
        table.insert(resourceLines, "Das Gebiet ist wenig ergiebig, dafür sicherer.  Prototyp. Prototyp. Prototyp.")
    end

    local pirateLines = SimulationUtility.getPirateAssessmentLines(pirateSectorRatio)
    local attackLines = SimulationUtility.getAttackAssessmentLines(attackChance)
    local underRadar, returnLines = SimulationUtility.getDisappearanceAssessmentLines(attackChance)

    local deliveries = {}

    if config.duration >= 1 then
        table.insert(deliveries, "Sie können etwa alle 30 Minuten eine Zwischenlieferung erwarten.")
        table.insert(deliveries, "Wir werden alle 30 Minuten eine Zwischenlieferung schicken.")
    end

    local rnd = Random(Seed(captain.name))

    return {
        randomEntry(rnd, resourceLines),
        randomEntry(rnd, pirateLines),
        randomEntry(rnd, attackLines),
        randomEntry(rnd, underRadar),
        randomEntry(rnd, returnLines),
        randomEntry(rnd, deliveries),
    }
end

-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function PrototypeCommand:buildUI(startPressedCallback, changeAreaPressedCallback, recallPressedCallback, configChangedCallback)
    local ui = {}
    ui.orderName = "Prototype"
    ui.icon = PrototypeCommand:getIcon()

    local size = vec2(650, 600)

    ui.window = GalaxyMap():createWindow(Rect(size))
    ui.window.caption = "Prototype Command"

    ui.commonUI = SimulationUtility.buildCommandUI(ui.window, startPressedCallback, changeAreaPressedCallback, recallPressedCallback, configChangedCallback, {configHeight = 60, changeAreaButton = true})

    -- configurable values
    local configValues = self:getConfigurableValues()

    local vsplitConfig = UIVerticalSplitter(ui.commonUI.configRect, 10, 0, 0.5)
    local vlist = UIVerticalLister(vsplitConfig.left, 10, 0)
    ui.window:createLabel(vlist:nextRect(15), configValues.duration.displayName .. ":", 12)
    ui.window:createLabel(vlist:nextRect(15), configValues.efficiency.displayName .. ":", 12)
    ui.window:createLabel(vlist:nextRect(15), configValues.yieldTick.displayName .. ":", 12)

    local vlist = UIVerticalLister(vsplitConfig.right, 10, 0)
    ui.durationSlider = ui.window:createSlider(vlist:nextRect(15), 1, 6, 5, "h", configChangedCallback)
    -- these two don't make sense gameplay-wise, please don't just copy them directly...
    ui.efficiencySlider = ui.window:createSlider(vlist:nextRect(15), 10, 100, 9, "%", configChangedCallback)
    ui.yieldTickSlider = ui.window:createSlider(vlist:nextRect(15), 5, 30, 5, "min", configChangedCallback)

    -- yields & issues
    local predictable = self:getPredictableValues()

    local vsplitYields = UIVerticalSplitter(ui.commonUI.predictionRect, 10, 0, 0.5)
    local vlist = UIVerticalLister(vsplitYields.left, 10, 0)
    ui.window:createLabel(vlist:nextRect(15), predictable.yield.displayName .. ":", 12)
    ui.window:createLabel(vlist:nextRect(15), predictable.pirateChance.displayName .. ":", 12)

    local vlist = UIVerticalLister(vsplitYields.right, 10, 0)
    ui.yieldLabel = ui.window:createLabel(vlist:nextRect(15), "", 12)
    ui.commonUI.attackChanceLabel = ui.window:createLabel(vlist:nextRect(15), "", 12)


    ui.clear = function(self, ownerIndex, shipName)
        self.commonUI:clear()

        self.yieldLabel.caption = ""
        self.commonUI.attackChanceLabel.caption = ""
    end

    -- used to fill values into the UI
    -- config == nil means fill with default values
    ui.refresh = function(self, ownerIndex, shipName, area, config)

        print ("refresh Protoype config")
        --printTable(area)

        self.commonUI:refresh(ownerIndex, shipName, area, config)

        if not config then
            -- no config: fill UI with default values, then build config, then use it to calculate yields
            local values = PrototypeCommand:getConfigurableValues(ownerIndex, shipName)

            -- use "setValueNoCallback" since we don't want to trigger "refreshPredictions()" while filling in default values
            self.durationSlider:setValueNoCallback(values.duration.default)
            self.efficiencySlider:setValueNoCallback(values.efficiency.default * 100)
            self.yieldTickSlider:setValueNoCallback(values.yieldTick.default)

            config = self:buildConfig()
        end

        self:refreshPredictions(ownerIndex, shipName, area, config)
    end

    -- gut feeling says that each config option change should always be reflected in the predictions if it impacts the behavior
    ui.refreshPredictions = function(self, ownerIndex, shipName, area, config)

        print ("refresh Protoype yields")
        -- printTable(area)

        local prediction = PrototypeCommand:calculatePrediction(ownerIndex, shipName, area, config)
        self:displayPrediction(prediction, config, ownerIndex)

        self.commonUI:refreshPredictions(ownerIndex, shipName, area, config, PrototypeCommand, prediction)
    end

    ui.displayPrediction = function(self, prediction, config, ownerIndex)
        self.yieldLabel.caption = string.format("%s¢ to %s¢", createMonetaryString(prediction.yield.from), createMonetaryString(prediction.yield.to))

        self.commonUI:setAttackChance(prediction.pirateChance.value)
    end

    -- used to build a config table for the command, based on values configured in the UI
    -- gut feeling says that each config option change should always be reflected in the predictions if it impacts the behavior
    ui.buildConfig = function(self)
        print ("build Prototype config")
        local config = {}

        config.duration = self.durationSlider.value
        config.efficiency = self.efficiencySlider.value / 100
        config.yieldTick = self.yieldTickSlider.value
        config.escorts = self.commonUI.escortUI:buildConfig()

        printTable(config)

        return config
    end

    -- optional; called whenever the command window was closed while the map is still visible
    ui.onWindowClosed = function(self)
        print ("Prototype window closed")
    end

    ui.setActive = function(self, active, description)
        self.commonUI:setActive(active, description)

        self.durationSlider.active = active
        self.efficiencySlider.active = active
        self.yieldTickSlider.active = active
    end

    ui.displayConfig = function(self, config, ownerIndex)
        self.durationSlider:setValueNoCallback(config.duration)
        self.efficiencySlider:setValueNoCallback(config.efficiency * 100)
        self.yieldTickSlider:setValueNoCallback(config.yieldTick)
    end

    return ui
end


return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
