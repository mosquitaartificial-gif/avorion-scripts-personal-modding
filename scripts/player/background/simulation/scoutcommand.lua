package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/player/background/simulation/?.lua"

local CommandType = include("commandtype")
local SimulationUtility = include("simulationutility")
local CaptainUtility = include("captainutility")
local PassageMap = include("passagemap")
local GatesMap = include("gatesmap")
local SectorSpecifics = include("sectorspecifics")
local FactionsMap = include ("factionsmap")
include("utility")
include("randomext")


local ScoutCommand = {}
ScoutCommand.__index = ScoutCommand
ScoutCommand.type = CommandType.Scout

-- all commands need this kind of "new" to function within the bg simulation framework
-- it must be possible to call the command without any parameters to access some functionality
local function new(ship, area, config)
    local command = setmetatable({
        -- all commands need these variables to function within the bg simulation framework
        -- type contains the CommandType of the command, required to restore
        type = CommandType.Scout,

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
    }, ScoutCommand)

    command.data.runTime = 0

    return command
end

-- all commands have the following functions, even if not listed here (added by Simulation script on command creation):
-- function ScoutCommand:addYield(message, money, resources, items) end
-- function ScoutCommand:finish() end
-- function ScoutCommand:registerForAttack(coords, faction, timeOfAttack, message, arguments) end



-- you can return an error message here such as:
-- return "Command cannot initialize because %1% and %2% went wrong", {"Player", "Config"}
function ScoutCommand:initialize()
    local prediction = self:calculatePrediction(getParentFaction().index, self.shipName, self.area, self.config)
    self.data.duration = prediction.duration.value
    self.data.attackChance = prediction.attackChance.value
    self.data.attackLocation = prediction.attackLocation
end

-- this is the regularly called function to update the time passing while the command is running
-- timestep is typically a longer period, such as a minute
-- this function should be as lightweight as possible. best practice is to
-- only do count downs here and do all calculations during area analysis and initialization
function ScoutCommand:update(timeStep)

    self.data.runTime = self.data.runTime + timeStep

    if self.data.runTime >= self.data.duration then
        self:finish()
        return
    end
end

-- executed when an area analysis involving this type of command starts
-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function ScoutCommand:onAreaAnalysisStart(results, meta)
end

-- executed when an area analysis involving this type of command is checking a specific sector
-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function ScoutCommand:onAreaAnalysisSector(results, meta, x, y)
end

-- executed when an area analysis involving this type of command finished
-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function ScoutCommand:onAreaAnalysisFinished(results, meta)
end

-- executed when the command starts for the first time (not when being restored)
-- do things like paying money in here and return errors when it's not possible because the player doesn't have enough money
-- you can return an error message here such as:
-- return "Command cannot start because %1% doesn't fulfill requirement '%2%'!", {"Player", "Money"}
-- calculate and register the command for an attack if necessary here
function ScoutCommand:onStart()
    -- set position from which ship is going to start
    local parent = getParentFaction()
    local entry = ShipDatabaseEntry(parent.index, self.shipName)
    local startX, startY = entry:getCoordinates()
    self.data.startCoordinates = { x = startX, y = startY }

    if not self.simulation.disableAttack then -- for tests
        local location = self.data.attackLocation
        if location then
            local timeOfAttack = random():getFloat(0.1, 0.75) * self.data.duration

            local x = location.x
            local y = location.y
            self:registerForAttack({x = x, y = y}, location.faction, timeOfAttack, "Your ship '%1%' is under attack in sector \\s(%2%:%3%)!"%_t, {self.shipName, x, y})
        end
    end
end

function ScoutCommand:findEmptySector()
    local emptySectors = {}

    local seed = GameSeed()
    local specs = SectorSpecifics()
    local passageMap = PassageMap(seed)

    for _, coords in pairs(self.area.analysis.reachableCoordinates) do
        local regular, offgrid, dust = specs.determineFastContent(coords.x, coords.y, seed)
        if not regular and not offgrid then
            if passageMap:passable(coords.x, coords.y) then
                table.insert(emptySectors, {x = coords.x, y = coords.y})
            end
        end
    end

    if #emptySectors == 0 then return end

    local sector = randomEntry(emptySectors)
    return sector.x, sector.y
end

-- executed when the ship is being recalled by the player
function ScoutCommand:onRecall()
    -- only update the ship's coordinates if recall is NOT caused by an attack
    if not self.data.attack or self.data.attack.countDown > 0 then
        -- only pick new coordinates after a bit of time has passed
        -- otherwise you can use it to travel to semi-random sectors
        if self.data.runTime >= 2 * 60 then
            local x, y = self:findEmptySector()
            if x and y then
                local entry = ShipDatabaseEntry(getParentFaction().index, self.shipName)
                entry:setCoordinates(x, y)
            end
        end
    end

    local ratio = self.data.runTime / self.data.duration
    self:revealSectors(ratio * 0.8)
end

-- executed when the command is finished
function ScoutCommand:onFinish()
    self:revealSectors(1)

    local faction = getParentFaction()
    local entry = ShipDatabaseEntry(faction.index, self.shipName)

    -- restore starting position of scout command
    if self.data.startCoordinates then
        local startX = self.data.startCoordinates.x
        local startY = self.data.startCoordinates.y
        entry:setCoordinates(startX, startY)
    end

    -- return message
    local x, y = entry:getCoordinates()
    faction:sendChatMessage(self.shipName, ChatMessageType.Information, "%1% has finished scouting and is awaiting your next orders in \\s(%2%:%3%)."%_T, self.shipName, x, y)
end

function ScoutCommand:revealSectors(ratio)
    local specs = SectorSpecifics()
    local seed = GameSeed()
    local faction = getParentFaction()
    local gatesMap = GatesMap(GameSeed())
    local galaxy = Galaxy()

    local entry = ShipDatabaseEntry(faction.index, self.shipName)
    local captain = entry:getCaptain()
    local captainNoteTemplate = "${captainNote} ${captainName}"%_T
    local captainNote = "Uncovered by captain"%_T

    local revealOffgridSectors = true
    local offgridSectorsToReveal = {}

    local captainIsExplorer = captain:hasClass(CaptainUtility.ClassType.Explorer)

    if captainIsExplorer then
        revealOffgridSectors = true
        local specialNoteLines =
        {
            "There is something abnormal and possibly dangerous here."%_t,
            "I have not seen anything like this before. Caution!"%_t,
            "There is something strange in this sector. Be careful!"%_t,
        }
        offgridSectorsToReveal["sectors/ancientgates"] = specialNoteLines
        offgridSectorsToReveal["sectors/asteroidshieldboss"] = specialNoteLines
        offgridSectorsToReveal["sectors/cultists"] = specialNoteLines
        offgridSectorsToReveal["sectors/lonewormhole"] = specialNoteLines
        offgridSectorsToReveal["sectors/researchsatellite"] = specialNoteLines
        offgridSectorsToReveal["sectors/resistancecell"] = specialNoteLines
        offgridSectorsToReveal["sectors/teleporter"] = specialNoteLines
        offgridSectorsToReveal["sectors/worldboss"] = specialNoteLines

        local containerNoteLines =
        {
            "Containers are stored in this sector."%_t,
            "We found a container field in this sector."%_t,
            "There is a container field in this sector."%_t,
        }
        offgridSectorsToReveal["sectors/containerfield"] = containerNoteLines
        offgridSectorsToReveal["sectors/massivecontainerfield"] = containerNoteLines
    end

    if captainIsExplorer or captain:hasClass(CaptainUtility.ClassType.Smuggler) then
        revealOffgridSectors = true
        local smugglerNoteLines =
        {
            "Smugglers hide here."%_t,
            "There are smugglers hanging around here."%_t,
            "Smugglers use this sector as their hideout."%_t,
        }
        offgridSectorsToReveal["sectors/smugglerhideout"] = smugglerNoteLines
    end

    if captainIsExplorer or captain:hasClass(CaptainUtility.ClassType.Miner) then
        revealOffgridSectors = true
        local asteroidNoteLines =
        {
            "There are asteroids here."%_t,
            "We found an asteroid field in this sector."%_t,
            "We found asteroids here."%_t,
            "There are asteroids in this sector."%_t,
        }
        offgridSectorsToReveal["sectors/asteroidfield"] = asteroidNoteLines
        offgridSectorsToReveal["sectors/pirateasteroidfield"] = asteroidNoteLines
        offgridSectorsToReveal["sectors/defenderasteroidfield"] = asteroidNoteLines
        offgridSectorsToReveal["sectors/asteroidfieldminer"] = asteroidNoteLines
        offgridSectorsToReveal["sectors/smallasteroidfield"] = asteroidNoteLines
        offgridSectorsToReveal["sectors/wreckageasteroidfield"] = asteroidNoteLines
    end

    if captainIsExplorer or captain:hasClass(CaptainUtility.ClassType.Scavenger) then
        revealOffgridSectors = true
        local wreckageNoteLines =
        {
            "There are wrecks in this sector."%_t,
            "We found wrecks in this sector."%_t,
            "This sector contains wrecks."%_t,
        }
        offgridSectorsToReveal["sectors/functionalwreckage"] = wreckageNoteLines
        offgridSectorsToReveal["sectors/stationwreckage"] = wreckageNoteLines
        offgridSectorsToReveal["sectors/wreckageasteroidfield"] = wreckageNoteLines
        offgridSectorsToReveal["sectors/wreckagefield"] = wreckageNoteLines
    end

    if captainIsExplorer or captain:hasClass(CaptainUtility.ClassType.Daredevil) then
        revealOffgridSectors = true
        local pirateNoteLines =
        {
            "There are pirates hiding here."%_t,
            "We saw pirates in this sector."%_t,
            "This sector is infested with pirates."%_t,
        }
        offgridSectorsToReveal["sectors/pirateasteroidfield"] = pirateNoteLines
        offgridSectorsToReveal["sectors/piratefight"] = pirateNoteLines
        offgridSectorsToReveal["sectors/piratestation"] = pirateNoteLines

        local xsotanNoteLines =
        {
            "There are Xsotan here."%_t,
            "We saw Xsotan in this sector."%_t,
            "Don't go here if you don't like Xsotan."%_t,
        }
        offgridSectorsToReveal["sectors/xsotanasteroids"] = xsotanNoteLines
        offgridSectorsToReveal["sectors/xsotantransformed"] = xsotanNoteLines
        offgridSectorsToReveal["sectors/xsotanbreeders"] = xsotanNoteLines
    end

    local sectorsToReveal = {}
    local gameTime = Server().unpausedRuntime
    local factionsMap = nil

    for _, coords in pairs(self.area.analysis.reachableCoordinates) do
        local x = coords.x
        local y = coords.y
        local regular, offgrid = specs.determineFastContent(x, y, seed)

        -- also uncover home sectors of factions
        if not regular and not offgrid then
            factionsMap = factionsMap or FactionsMap(seed)
            local fx = factionsMap.factions[x]
            if fx and fx[y] then
                regular = true
                offgrid = false
            end
        end

        if regular or (revealOffgridSectors and offgrid) then
            specs:initialize(x, y, seed)

            if not specs.blocked then
                local revealThisSector = true
                local offgridSectorNote

                if specs.offgrid then
                    -- only offgrid sectors that have a note are revealed
                    -- which offgrid sector has a note is determined based on the captain class
                    local sectorNotes = offgridSectorsToReveal[specs.generationTemplate.path]
                    if sectorNotes then
                        offgridSectorNote = randomEntry(sectorNotes)
                    else
                        revealThisSector = false
                    end
                end

                if revealThisSector then
                    local view = faction:getKnownSector(x, y) or SectorView()

                    if not view.visited and not view.hasContent and not string.match(view.note.text, "${sectorNote}") then
                        specs:fillSectorView(view, gatesMap, true)
                        view.timeStamp = gameTime

                        if view.note.empty then
                            local text = ""
                            local arguments = {}
                            if offgridSectorNote then
                                text = "${sectorNote}"
                                arguments.sectorNote = offgridSectorNote
                            end

                            if self.config.addCaptainsNote then
                                if text ~= "" then text = text .. "\n" end

                                text = text .. captainNoteTemplate
                                arguments.captainNote = captainNote
                                arguments.captainName = captain.name
                            end

                            view.note = NamedFormat(text, arguments)

                            -- make sure that no new icons are created
                            if view.tagIconPath == "" then view.tagIconPath = "data/textures/icons/nothing.png" end
                        end

                        table.insert(sectorsToReveal, view)
                    end
                end
            end
        end
    end

    shuffle(sectorsToReveal)

    local numSectorsToReveal = math.floor(#sectorsToReveal * ratio)
    for index, view in pairs(sectorsToReveal) do
        if index > numSectorsToReveal then break end

        faction:addKnownSector(view)
    end
end

-- after this function was called, self.data will be read to be saved to database
function ScoutCommand:onSecure()
end

-- this is called after the command was recreated and self.data was assigned
function ScoutCommand:onRestore()
end

-- this is called when the beforehand calculated pirate or faction attack happens
-- called after notification of player and after attack script is added to the ship database entry
-- but before the ship and its escort is recalled from background
-- note: attackerFaction is nil in case of a pirate attack
function ScoutCommand:onAttacked(attackerFaction, x, y)
end

function ScoutCommand:getDescriptionText()
    local timeRemaining = math.ceil((self.data.duration - self.data.runTime) / 60) * 60
    local completed = math.floor(self.data.runTime / self.data.duration * 100)
    return "Scouting the area.\n\nTime remaining: ${timeRemaining} (${completed} % done)."%_T, {timeRemaining = createReadableShortTimeString(timeRemaining), completed = completed}
end

function ScoutCommand:getStatusMessage()
    return "Scouting /* ship AI status*/"%_T
end

-- returns the path to the icon that will be used in UI and on the galaxy map
function ScoutCommand:getIcon()
    return "data/textures/icons/scout-command.png"
end

function ScoutCommand:getRecallError()
end

-- returns whether there are errors with the command, either in the config, or otherwise
-- (ship has no mining turrets, not enough energy, player doesn't have enough money, etc.)
-- this function is also executed on the client and used to grey out the "start" button so players know that their config is flawed
-- note: before this is called, there is already a preliminary check based on getConfigurableValues(),
-- where values are clamped or default-set
function ScoutCommand:getErrors(ownerIndex, shipName, area, config)
    -- if there are no errors, just return
    return
end

-- returns the size of the area where the command will run
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function ScoutCommand:getAreaSize(ownerIndex, shipName)
    return {x = 21, y = 21}
end

-- returns the size of the area where the command is currently running
-- this is used to visualize where the command is running at the moment
function ScoutCommand:getAreaBounds()
    return {lower = self.area.lower, upper = self.area.upper}
end

-- returns whether the command requires the ship to be inside the selected area
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function ScoutCommand:isShipRequiredInArea(ownerIndex, shipName)
    return true
end

-- returns whether the command has a fixed area. if yes, the area will be calculated with the ship in the middle
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function ScoutCommand:isAreaFixed(ownerIndex, shipName)
    return false
end

function ScoutCommand:getAreaSelectionTooltip(ownerIndex, shipName, area, valid)
    return "Left-Click to select the area to scout"%_t
end

-- returns the configurable values for this command (if any).
-- variable naming should speak for itself, though you're free to do whatever you want in here.
-- config will only be used by the command itself and nothing else
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function ScoutCommand:getConfigurableValues(ownerIndex, shipName)
    local values = { }

    -- value names here must match with values returned in ui:buildConfig() below
    values.addCaptainsNote = {displayName = "Add captain's notes"%_t, default = true}

    return values
end

-- returns the predictable values for this command (if any).
-- variable naming should speak for itself, though you're free to do whatever you want in here.
-- config will only be used by the command itself and nothing else
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function ScoutCommand:getPredictableValues()
    local values = { }

    values.attackChance = {displayName = SimulationUtility.AttackChanceLabelCaption}
    values.duration = {displayName = "Duration"%_t}
    values.revealsOffgrid = {displayName = "Hidden Mass Sectors"%_t}

    return values
end

-- calculate the predictions for the ship, area and config
-- gut feeling says that each config option change should always be reflected in the predictions if it impacts the behavior
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function ScoutCommand:calculatePrediction(ownerIndex, shipName, area, config)
    local results = self:getPredictableValues()

    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local captain = entry:getCaptain()

    -- calculate duration
    local duration = area.analysis.reachable / 25

    -- calculate perk influence on duration
    if captain:hasPerk(CaptainUtility.PerkType.Reckless) then
        duration = duration * (1 + CaptainUtility.getScoutPerkImpact(captain, CaptainUtility.PerkType.Reckless))
    end

    if captain:hasPerk(CaptainUtility.PerkType.Navigator) then
        duration = duration * (1 + CaptainUtility.getScoutPerkImpact(captain, CaptainUtility.PerkType.Navigator))
    end

    if captain:hasPerk(CaptainUtility.PerkType.Careful) then
        duration = duration * (1 + CaptainUtility.getScoutPerkImpact(captain, CaptainUtility.PerkType.Careful))
    end

    if captain:hasPerk(CaptainUtility.PerkType.Disoriented) then
        duration = duration * (1 + CaptainUtility.getScoutPerkImpact(captain, CaptainUtility.PerkType.Disoriented))
    end

    if captain:hasPerk(CaptainUtility.PerkType.Addict) then
        duration = duration * (1 + CaptainUtility.getScoutPerkImpact(captain, CaptainUtility.PerkType.Addict))
    end

    -- smuggler captains don't have to slow down when transporting special goods
    if not captain:hasClass(CaptainUtility.ClassType.Smuggler) then
        local stolenOrIllegal, dangerousOrSuspicious = SimulationUtility.getSpecialCargoCategories(entry:getCargo())

        -- merchant captains don't have to slow down when transporting dangerous or suspicious goods
        if captain:hasClass(CaptainUtility.ClassType.Merchant) then
            dangerousOrSuspicious = false
        end

        if stolenOrIllegal or dangerousOrSuspicious then
            duration = duration * 1.15
        end
    end

    results.duration.value = math.ceil(duration * 60) -- convert minutes to seconds
    results.attackChance.value, results.attackLocation = SimulationUtility.calculateAttackProbability(ownerIndex, shipName, area, config.escorts, duration / 60 / 60) -- convert seconds to hours

    results.revealsOffgrid.value = 0 -- none

    if captain:hasClass(CaptainUtility.ClassType.Explorer) then
        results.revealsOffgrid.value = 2 -- all
    elseif captain:hasClass(CaptainUtility.ClassType.Smuggler) or
            captain:hasClass(CaptainUtility.ClassType.Miner) or
            captain:hasClass(CaptainUtility.ClassType.Scavenger) or
            captain:hasClass(CaptainUtility.ClassType.Daredevil) then
        results.revealsOffgrid.value = 1 -- some

        results.revealsOffgrid.primaryClass = captain.primaryClass
        results.revealsOffgrid.secondaryClass = captain.secondaryClass
    end

    return results
end

function ScoutCommand:generateAssessmentFromPrediction(prediction, captain, ownerIndex, shipName, area, config)
    local total = area.analysis.sectors - area.analysis.unreachable
    if total == 0 then return "We can't discover anything in this area!"%_t end

    -- cargo on board
    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local captain = entry:getCaptain()
    local cargo = entry:getCargo()
    local stolenOrIllegal, dangerousOrSuspicious = SimulationUtility.getSpecialCargoCategories(cargo)
    local cargobayLines = SimulationUtility.getIllegalCargoAssessmentLines(stolenOrIllegal, dangerousOrSuspicious, captain)

    local attackChance = prediction.attackChance.value
    local pirateSectorRatio = SimulationUtility.calculatePirateAttackSectorRatio(area)

    local pirateLines = SimulationUtility.getPirateAssessmentLines(pirateSectorRatio)
    local attackLines = SimulationUtility.getAttackAssessmentLines(attackChance)
    local underRadar, returnLines = SimulationUtility.getDisappearanceAssessmentLines(attackChance)

    local rnd = Random(Seed(captain.name))

    return {
        "We'll scout the area."%_t,
        randomEntry(rnd, cargobayLines),
        randomEntry(rnd, pirateLines),
        randomEntry(rnd, attackLines),
        randomEntry(rnd, underRadar),
        randomEntry(rnd, returnLines),
    }
end

-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function ScoutCommand:buildUI(startPressedCallback, changeAreaPressedCallback, recallPressedCallback, configChangedCallback)
    local ui = {}
    ui.orderName = "Scout"%_t
    ui.icon = ScoutCommand:getIcon()

    local size = vec2(600, 550)

    ui.window = GalaxyMap():createWindow(Rect(size))
    ui.window.caption = "Scout Operation"%_t

    ui.commonUI = SimulationUtility.buildCommandUI(ui.window, startPressedCallback, changeAreaPressedCallback, recallPressedCallback, configChangedCallback, {configHeight = 15, changeAreaButton = true})

    -- configurable values
    local configValues = self:getConfigurableValues()

    local padder = UIOrganizer(ui.commonUI.configRect)
    padder.marginLeft = 150
    padder.marginRight = 150
    ui.addCaptainsNoteCheckBox = ui.window:createCheckBox(padder.inner, configValues.addCaptainsNote.displayName, configChangedCallback)
    ui.addCaptainsNoteCheckBox.tooltip = "Mark newly discovered sectors on the map with a note from the captain."%_t
    ui.addCaptainsNoteCheckBox.fontSize = 13

    -- yields & issues
    local predictable = self:getPredictableValues()
    local vlist = UIVerticalLister(ui.commonUI.predictionRect, 5, 0)
    vlist.marginTop = 50

    -- attack chance
    local vsplitYields = UIVerticalSplitter(vlist:nextRect(15), 5, 0, 0.65)
    local label = ui.window:createLabel(vsplitYields.left, predictable.attackChance.displayName .. ":", 12)
    label.tooltip = SimulationUtility.AttackChanceLabelTooltip
    ui.commonUI.attackChanceLabel = ui.window:createLabel(vsplitYields.right, "", 12)
    ui.commonUI.attackChanceLabel:setRightAligned()

    -- duration
    local vsplitYields = UIVerticalSplitter(vlist:nextRect(15), 5, 0, 0.65)
    ui.window:createLabel(vsplitYields.left, predictable.duration.displayName .. ":", 12)
    ui.durationLabel = ui.window:createLabel(vsplitYields.right, "", 12)
    ui.durationLabel:setRightAligned()

    -- reveals offgrid sectors
    local rect = vlist:nextRect(15)

    ui.window:createLabel(rect, predictable.revealsOffgrid.displayName .. ":", 12)
    ui.revealsOffgridLabel = ui.window:createLabel(rect, "", 12)
    ui.revealsOffgridLabel:setRightAligned()


    ui.clear = function(self, shipName)
        self.commonUI:clear(shipName)
    end

    -- used to fill values into the UI
    -- config == nil means fill with default values
    ui.refresh = function(self, ownerIndex, shipName, area, config)
        self.commonUI:refresh(ownerIndex, shipName, area, config)

        if not config then
            -- no config: fill UI with default values, then build config, then use it to calculate yields
            local values = ScoutCommand:getConfigurableValues(ownerIndex, shipName)

            -- use "setValueNoCallback" since we don't want to trigger "refreshPredictions()" while filling in default values
            ui.addCaptainsNoteCheckBox:setCheckedNoCallback(values.addCaptainsNote.default)

            config = self:buildConfig()
        end

        self:refreshPredictions(ownerIndex, shipName, area, config)
    end

    -- gut feeling says that each config option change should always be reflected in the predictions if it impacts the behavior
    ui.refreshPredictions = function(self, ownerIndex, shipName, area, config)
        local prediction = ScoutCommand:calculatePrediction(ownerIndex, shipName, area, config)
        self:displayPrediction(prediction, config, ownerIndex)

        self.commonUI:refreshPredictions(ownerIndex, shipName, area, config, ScoutCommand, prediction)
    end

    ui.displayPrediction = function(self, prediction, config, ownerIndex)
        self.commonUI:setAttackChance(prediction.attackChance.value)

        self.durationLabel.caption = createReadableShortTimeString(math.ceil(prediction.duration.value / 60) * 60)

        if prediction.revealsOffgrid.value == 2 then
            self.revealsOffgridLabel.caption = "All"%_t
            self.revealsOffgridLabel.tooltip = "This captain will reveal all hidden mass sectors in the area."%_t
        elseif prediction.revealsOffgrid.value == 1 then
            self.revealsOffgridLabel.caption = "Some"%_t
            self.revealsOffgridLabel.tooltip = "This captain will reveal some hidden mass sectors in the area."%_t

            local revealed = {}
            for _, class in pairs({prediction.revealsOffgrid.primaryClass, prediction.revealsOffgrid.secondaryClass}) do
                if class == CaptainUtility.ClassType.Scavenger then table.insert(revealed, "Wreckages"%_t) end
                if class == CaptainUtility.ClassType.Daredevil then table.insert(revealed, "Pirates"%_t) end
                if class == CaptainUtility.ClassType.Miner then table.insert(revealed, "Asteroids"%_t) end
                if class == CaptainUtility.ClassType.Smuggler then table.insert(revealed, "Smugglers"%_t) end
            end

            if #revealed > 0 then
                self.revealsOffgridLabel.caption = string.join(revealed, ", ")
            end
        else
            self.revealsOffgridLabel.caption = "None"%_t
            self.revealsOffgridLabel.tooltip = "This captain won't reveal any hidden mass sectors in the area."%_t
        end
    end

    -- used to build a config table for the command, based on values configured in the UI
    -- gut feeling says that each config option change should always be reflected in the predictions if it impacts the behavior
    ui.buildConfig = function(self)
        local config = {}

        config.addCaptainsNote = self.addCaptainsNoteCheckBox.checked
        config.escorts = self.commonUI.escortUI:buildConfig()

        return config
    end

    ui.setActive = function(self, active, description)
        self.commonUI:setActive(active, description)

        self.addCaptainsNoteCheckBox.active = active
    end

    ui.displayConfig = function(self, config, ownerIndex)
        self.addCaptainsNoteCheckBox:setCheckedNoCallback(config.addCaptainsNote)
    end

    return ui
end


return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
