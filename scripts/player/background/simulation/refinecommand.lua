package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/player/background/simulation/?.lua"

local CommandType = include ("commandtype")
local SimulationUtility = include ("simulationutility")
local CaptainUtility = include("captainutility")
local GatesMap = include ("gatesmap")
local SectorSpecifics = include("sectorspecifics")
include ("utility")
include ("merchantutility")
include ("stringutility")
include ("randomext")

local RefineCommand = {}
RefineCommand.__index = RefineCommand
RefineCommand.type = CommandType.Refine

local function new(ship, area, config)
    local command = setmetatable({
        -- all commands need these variables to function within the bg simulation framework
        -- type contains the CommandType of the command, required to restore
        type = CommandType.Refine,

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
    }, RefineCommand)

    command.data.runTime = 0
    command.data.duration = 600

    return command
end

-- all commands have the following functions, even if not listed here (added by Simulation script on command creation):
-- function RefineCommand:addYield(message, money, resources, items) end
-- function RefineCommand:finish() end
-- function RefineCommand:registerForAttack(coords, faction, timeOfAttack, message, arguments) end


function RefineCommand:initialize()
    local parent = getParentFaction()
    local prediction = self:calculatePrediction(parent.index, self.shipName, self.area, self.config)

    if prediction.error then
        return prediction.error, prediction.errorArgs
    end

    self.data.duration = prediction.duration
    self.data.yields = prediction.yields
end

function RefineCommand:onStart()
    local parent = getParentFaction()
    local entry = ShipDatabaseEntry(parent.index, self.shipName)
    entry:setStatusMessage("Refining"%_T)

    -- save starting position of command
    local startX, startY = entry:getCoordinates()
    self.data.startCoordinates = { x = startX, y = startY }
end

function RefineCommand:update(timeStep)

    self.data.runTime = self.data.runTime + timeStep

    if self.data.runTime >= self.data.duration then
        self:finish()
        return
    end

end

function RefineCommand:onAreaAnalysisStart(results, meta)

end

function RefineCommand:onAreaAnalysisSector(results, meta, x, y, details)

end

function RefineCommand:onAreaAnalysisFinished(results, meta)
    local owner = Galaxy():findFaction(meta.factionIndex)

    results.tax = 0.1

    -- check if there are friendly factions nearby
    for factionIndex, _ in pairs(results.sectorsByFaction) do

        -- only count map AI factions
        -- the mere presence of an ally should not lead to better prices
        if factionIndex > 0
                and owner.index ~= factionIndex
                and owner:getRelationStatus(factionIndex) ~= RelationStatus.War then
            local faction = Faction(factionIndex)

            if valid(faction) and faction.isAIFaction then
                local tax = getRefineTaxFactor(factionIndex, owner)

                -- tax at AI refineries is slightly better because, let's say the captain knows people
                tax = math.max(0.005, tax - 0.005)

                if tax < results.tax then
                    results.tax = tax
                end

                results.friendlySectorsFound = true
            end
        end
    end

    -- check if there are any owned or friendly (as in alliance) refineries nearby
    local factions = {owner}
    if owner.isPlayer and owner.alliance then
        table.insert(factions, owner.alliance)
    end

    -- check player and alliance
    for _, faction in pairs(factions) do

        local crafts = {faction:getShipNames()}
        for _, name in pairs(crafts) do

            -- first, check if it's a non-destroyed station
            if faction:getShipType(name) == EntityType.Station
                    and faction:getShipAvailability(name) == ShipAvailability.Available then

                -- check if it's in the area
                local x, y = faction:getShipPosition(name)
                if x >= meta.area.lower.x and x <= meta.area.upper.x
                        and y >= meta.area.lower.y and y <= meta.area.upper.y then

                    -- check if it's a refinery
                    local entry = ShipDatabaseEntry(faction.index, name)
                    if entry:getDocksEnabled() then
                        local minimumPopulation = entry:getScriptValue("minimum_population_fulfilled")
                        if minimumPopulation ~= false then -- explicitly check for 'false'
                            local scripts = entry:getScripts()

                            for _, script in pairs(scripts) do
                                if string.match(script, "data/scripts/entity/merchants/refinery.lua") then
                                    if faction.index == owner.index then
                                        results.ownedRefineryFound = true
                                    else
                                        results.friendlyRefineryFound = true
                                    end

                                    local tax = getRefineTaxFactor(faction.index, owner)
                                    if tax < results.tax then
                                        results.tax = tax
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

end

function RefineCommand:onRecall()

end

function RefineCommand:onFinish()

    local faction = getParentFaction()
    local entry = ShipDatabaseEntry(faction.index, self.shipName)

    -- take away ores and scrap metal
    local cargo, cargoBaySize = entry:getCargo()
    for good, amount in pairs(cargo) do
        local tags = good.tags
        local material = nil
        if tags.iron then
            material = 1
        elseif tags.titanium then
            material = 2
        elseif tags.naonite then
            material = 3
        elseif tags.trinium then
            material = 4
        elseif tags.xanion then
            material = 5
        elseif tags.ogonite then
            material = 6
        elseif tags.avorion then
            material = 7
        end

        if material and self.config.refined[material] then
            cargo[good] = nil
        end
    end

    entry:setCargo(cargo)

    local lines = {}
    table.insert(lines, "Here's the shipment, Commander!"%_t)
    table.insert(lines, "Mission completed, Commander, here's the shipment."%_t)

    self:addYield(randomEntry(lines), 0, self.data.yields)

    local captain = entry:getCaptain()
    if captain:hasClass(CaptainUtility.ClassType.Explorer) then
        self:onExplorerFinish(captain)
    end

    -- restore starting position of refine command
    if self.data.startCoordinates then
        local startX = self.data.startCoordinates.x
        local startY = self.data.startCoordinates.y
        entry:setCoordinates(startX, startY)
    end

    local x, y = entry:getCoordinates()
    faction:sendChatMessage(self.shipName, ChatMessageType.Information, "%1% has finished refining and is awaiting your next orders in \\s(%2%:%3%)."%_T, self.shipName, x, y)
end

function RefineCommand:onExplorerFinish(captain)

    local faction = getParentFaction()
    local specs = SectorSpecifics()
    local seed = Server().seed

    local notes = {}
    table.insert(notes, "Commander, I marked this sector on the map for you.\n\nRegards, Captain ${name}"%_T)
    table.insert(notes, "Commander, we discovered this sector that you didn't have on the map yet.\n\nRegards, Captain ${name}"%_T)
    table.insert(notes, "Discovered a sector here.\n\nRegards, Captain ${name}"%_T)
    table.insert(notes, "As a small courtesy, I explored this sector for you.\n\nRegards, Captain ${name}"%_T)

    local revealed = 0
    local gatesMap

    for _, coords in pairs(self.area.analysis.reachableCoordinates) do
        local x, y = coords.x, coords.y
        local regular, offgrid = specs.determineFastContent(x, y, seed)

        -- regular and offgrid can be changed into each other depending on central region or no man's space
        if not regular and not offgrid then goto continue end

        local regular, offgrid, blocked, home = specs:determineContent(x, y, seed)
        if not regular then goto continue end
        if blocked then goto continue end -- there can't be anything if the sector is blocked

        local view = faction:getKnownSector(x, y)
        if view then goto continue end -- don't override existing data

        view = SectorView()
        gatesMap = gatesMap or GatesMap(GameSeed())

        specs:initialize(x, y, seed)
        specs:fillSectorView(view, gatesMap, true)

        view.note = randomEntry(notes) % {name = captain.name}
        -- make sure that no new icons are created
        if view.tagIconPath == "" then view.tagIconPath = "data/textures/icons/nothing.png" end

        faction:addKnownSector(view)

        revealed = revealed + 1
        if revealed >= 5 then break end

        ::continue::
    end

end


function RefineCommand:onSecure()

end

function RefineCommand:onRestore()

end

function RefineCommand:getDescriptionText()
    local totalRuntime = self.data.duration
    local timeRemaining = round((totalRuntime - self.data.runTime) / 60) * 60
    local completed = round(self.data.runTime / totalRuntime * 100)

    return "Ship is refining resources.\n\nTime remaining: ${timeRemaining} (${completed} % done)."%_t, {timeRemaining = createReadableShortTimeString(timeRemaining), completed = completed}
end

function RefineCommand:getStatusMessage()
    return "Refining Ores /* ship AI status*/"%_T
end

function RefineCommand:getIcon()
    return "data/textures/icons/refine-command.png"
end

function RefineCommand:getRecallError()
end

-- returns whether there are errors with the command, either in the config, or otherwise (ship has no mining turrets, not enough energy, player doesn't have enough money, etc.)
-- note: before this is called, there is already a preliminary check based on getConfigurableValues(), where values are clamped or default-set
function RefineCommand:getErrors(ownerIndex, shipName, area, config)
end


function RefineCommand:getAreaSize(ownerIndex, shipName)
    return {x = 31, y = 31}
end

function RefineCommand:getAreaBounds()
    return {lower = self.area.lower, upper = self.area.upper}
end

function RefineCommand:isAreaFixed(ownerIndex, shipName)
    return true
end

function RefineCommand:isShipRequiredInArea(ownerIndex, shipName)
    return true
end

function RefineCommand:getConfigurableValues(ownerIndex, shipName)
    local values = {}
    return values
end

function RefineCommand:getPredictableValues()
    local values = {}

    values.yields = {}
    for i = 1, NumMaterials() do
        local material = Material(i - 1)
        values.yields[i] = {displayName = material.name}
    end

    values.duration = {displayName = "Duration"%_t}
    values.tax = {displayName = "Refinery Tax"%_t}
    values.attackChance = {displayName = SimulationUtility.AttackChanceLabelCaption}

    return values
end

function RefineCommand:calculatePrediction(ownerIndex, shipName, area, config)
    local results = {}

    results.friendlySectorsFound = area.analysis.friendlySectorsFound
    results.friendlyRefineryFound = area.analysis.friendlyRefineryFound
    results.ownedRefineryFound = area.analysis.ownedRefineryFound

    local yields = {}
    results.yields = yields
    results.attackChance = 0
    results.tax = 0
    results.duration = 0

    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local captain = entry:getCaptain()

    local tax = area.analysis.tax
    if tax >= 0.005 then
        if captain:hasClass(CaptainUtility.ClassType.Miner) or captain:hasClass(CaptainUtility.ClassType.Scavenger) then
            tax = tax * 0.5
        end

        tax = math.max(0.005, tax)
    end

    if captain:hasPerk(CaptainUtility.PerkType.Noble) then
        tax = tax * CaptainUtility.getRefineTaxPerkImpact(captain, CaptainUtility.PerkType.Noble)
    end

    if captain:hasPerk(CaptainUtility.PerkType.Commoner) then
        tax = tax * CaptainUtility.getRefineTaxPerkImpact(captain, CaptainUtility.PerkType.Commoner)
    end

    if captain:hasPerk(CaptainUtility.PerkType.Gambler) then
        if tax > 0 then
            tax = tax + CaptainUtility.getRefineTaxPerkImpact(captain, CaptainUtility.PerkType.Gambler)
        end
    end

    if captain:hasPerk(CaptainUtility.PerkType.Connected) then
        if tax >= 0.005 then
            tax = math.max(0.005, tax + CaptainUtility.getRefineTaxPerkImpact(captain, CaptainUtility.PerkType.Connected))
        end
    end

    local cargo, cargoBaySize = entry:getCargo()

    for i = 1, NumMaterials() do
        yields[i] = 0
    end

    local oresToRefine = 0
    local oresOnBoard = false
    for good, amount in pairs(cargo) do
        local tags = good.tags
        local material = nil
        if tags.iron then
            material = 1
        elseif tags.titanium then
            material = 2
        elseif tags.naonite then
            material = 3
        elseif tags.trinium then
            material = 4
        elseif tags.xanion then
            material = 5
        elseif tags.ogonite then
            material = 6
        elseif tags.avorion then
            material = 7
        end

        if config then
            if material and config.refined[material] then
                if tags.rich then
                    yields[material] = (yields[material] or 0) + amount * 4 * (1.0 - tax)
                else
                    yields[material] = (yields[material] or 0) + amount * (1.0 - tax)
                end
                oresToRefine = oresToRefine + amount
            end
        end

        if material and amount > 0 then
            oresOnBoard = true
        end
    end

    if not oresOnBoard then
        results.error = "There are no ores or scrap metal on board the ship."%_T
        return results
    end

    if oresToRefine == 0 then
        results.error = "This operation won't yield anything."%_T
        return results
    end

    for i = 1, NumMaterials() do
        yields[i] = round(yields[i])
    end

    -- time taken for refining
    local oresPerSecond = 2000
    local baseDuration = 60 * 10

    results.duration = baseDuration

    if area.analysis.friendlyRefineryFound or area.analysis.ownedRefineryFound then
        results.duration = baseDuration / 2
        results.nearbyRefinery = true
    elseif not area.analysis.friendlySectorsFound then
        results.duration = baseDuration * 2
    end

    -- calculate increase in duration caused by having special cargo on board
    -- smuggler captains don't have to slow down when transporting special goods
    local specialGoodsFactor = 1
    local captain = entry:getCaptain()
    if not captain:hasClass(CaptainUtility.ClassType.Smuggler) then
        local stolenOrIllegal, dangerousOrSuspicious = SimulationUtility.getSpecialCargoCategories(cargo)

        -- merchant captains don't have to slow down when transporting dangerous or suspicious goods
        if captain:hasClass(CaptainUtility.ClassType.Merchant) then
            dangerousOrSuspicious = false
        end

        if stolenOrIllegal or dangerousOrSuspicious then
            specialGoodsFactor = 1.15
        end
    end

    results.duration = results.duration + (oresToRefine / oresPerSecond)
    results.duration = results.duration * specialGoodsFactor -- increase the duration when carrying special goods

    for _, perk in pairs({captain:getPerks()}) do
        results.duration = results.duration * (1 + CaptainUtility.getRefineTimePerkImpact(captain, perk))
    end

    -- remember tax for UI and unit test purposes
    results.tax = tax

    return results
end

function RefineCommand:generateAssessmentFromPrediction(prediction, captain, ownerIndex, shipName, area, config)

    local total = area.analysis.sectors - area.analysis.unreachable
    if total == 0 then return "" end

    local attackChance = prediction.attackChance
    local pirateSectorRatio = SimulationUtility.calculatePirateAttackSectorRatio(area)

    local refineLines = {}
    if area.analysis.friendlySectorsFound then
        table.insert(refineLines, "It should be possible to have the resources refined in this area."%_t)
        table.insert(refineLines, "I will look for a nearby refinery and have the resources refined."%_t)
    else
        table.insert(refineLines, "\\c(dd5)This is a sparsely populated area. We can have the resources refined, but it will take a little longer to find a suitable refinery.\\c()"%_t)
        table.insert(refineLines, "\\c(dd5)The area is not very densely populated. The search for a refinery will take a little longer than usual.\\c()"%_t)
        table.insert(refineLines, "\\c(dd5)I don't see any refineries in this remote area. I will find one eventually, but of course it will take a little longer.\\c()"%_t)
    end

    local friendlyLines = {}
    if area.analysis.friendlyRefineryFound or area.analysis.ownedRefineryFound then
        table.insert(friendlyLines, "We can save time and money and fly to a friendly refinery."%_t)        
        table.insert(friendlyLines, "There's a friendly refinery nearby, so that makes things easier."%_t)
        table.insert(friendlyLines, "With the friendly refinery nearby, we can save time and money."%_t)
    end

    -- cargo on board
    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local cargo = entry:getCargo()
    local stolenOrIllegal, dangerousOrSuspicious = SimulationUtility.getSpecialCargoCategories(cargo)
    local cargobayLines = SimulationUtility.getIllegalCargoAssessmentLines(stolenOrIllegal, dangerousOrSuspicious, captain)

    local pirateLines = {}
    pirateLines = SimulationUtility.getPirateAssessmentLines(pirateSectorRatio)

    local attackLines = SimulationUtility.getAttackAssessmentLines(attackChance)
    local underRadar, returnLines = SimulationUtility.getDisappearanceAssessmentLines(attackChance)

    local rnd = Random(Seed(captain.name))

    return {
        randomEntry(rnd, refineLines),
        randomEntry(rnd, friendlyLines),
        randomEntry(rnd, cargobayLines),
        randomEntry(rnd, pirateLines),
        randomEntry(rnd, attackLines),
        randomEntry(rnd, underRadar),
        randomEntry(rnd, returnLines),
    }
end

function RefineCommand:buildUI(startPressedCallback, changeAreaPressedCallback, recallPressedCallback, configChangedCallback)
    local ui = {}
    ui.orderName = "Refine"%_t
    ui.icon = RefineCommand:getIcon()

    local size = vec2(600, 560)

    ui.window = GalaxyMap():createWindow(Rect(size))
    ui.window.caption = "Refining Operation"%_t

    local settings = {areaHeight = 125, configHeight = 0, hideEscortUI = true}
    ui.commonUI = SimulationUtility.buildCommandUI(ui.window, startPressedCallback, changeAreaPressedCallback, recallPressedCallback, configChangedCallback, settings)

    -- this command has yields and config in the same section
    local predictable = self:getPredictableValues()

    local gsplit = UIGridSplitter(ui.commonUI.configRect, 5, 0, 2, 4)

    -- predictions:
    local vlist = UIVerticalLister(ui.commonUI.predictionRect, 5, 0)

    local vsplitYields = UIVerticalSplitter(vlist:nextRect(15), 5, 0, 0.65)
    local label = ui.window:createLabel(vsplitYields.left, predictable.attackChance.displayName .. ":", 12)
    label.tooltip = SimulationUtility.AttackChanceLabelTooltip

    ui.commonUI.attackChanceLabel = ui.window:createLabel(vsplitYields.right, "", 12)
    ui.commonUI.attackChanceLabel:setCenterAligned()

    local vsplitYields = UIVerticalSplitter(vlist:nextRect(15), 5, 0, 0.65)
    local label = ui.window:createLabel(vsplitYields.left, predictable.duration.displayName .. ":", 12)
    ui.durationLabel = ui.window:createLabel(vsplitYields.right, "", 12)
    ui.durationLabel:setCenterAligned()

    vsplitYields:setRightQuadratic()
    local rect = vsplitYields.right
    rect.size = rect.size + vec2(8, 8)
    ui.refineryIcon = ui.window:createPicture(rect, "data/textures/icons/station.png")
    ui.refineryIcon.isIcon = true
    ui.refineryIcon.color = ColorRGB(0.2, 1, 0.2)
    ui.refineryIcon.tooltip = "Friendly refinery in the area. Duration and refinery tax are reduced."%_t

    vlist:nextRect(5)

    local vsplitYields = UIVerticalSplitter(vlist:nextRect(15), 5, 0, 0.65)
    local label = ui.window:createLabel(vsplitYields.left, predictable.tax.displayName .. ":", 12)
    label.tooltip = "The best refinery tax for this captain in this area."%_t
    ui.taxLabel = ui.window:createLabel(vsplitYields.right, "", 12)
    ui.taxLabel:setCenterAligned()

    vlist:nextRect(5)

    ui.materialLines = {}
    for i = 1, NumMaterials() do
        local vsplit = UIVerticalSplitter(vlist:nextRect(18), 10, 0, 0.65)
        local vsplit2 = UIVerticalSplitter(vsplit.left, 10, 0, 0.5)
        vsplit2:setLeftQuadratic()

        local textLabel = ui.window:createLabel(vsplit2.right, predictable.yields[i].displayName, 12)
        local checkBox = ui.window:createCheckBox(vsplit2.left, "", configChangedCallback)
        local amountLabel = ui.window:createLabel(vsplit.right, "", 12)
        amountLabel:setCenterAligned()

        local material = Material(i - 1)
        amountLabel.color = material.color
        textLabel.color = material.color

        amountLabel:hide()
        textLabel:hide()

        ui.materialLines[i] = {checkBox = checkBox, amountLabel = amountLabel, textLabel = textLabel}
    end

    local hsplitBottom = UIHorizontalSplitter(Rect(size), 10, 10, 0.5)
    hsplitBottom.bottomSize = 40
    local vsplit = UIVerticalMultiSplitter(hsplitBottom.bottom, 10, 0, 3)

    ui.clear = function(self, shipName)
        self.commonUI:clear(shipName)

        for i = 1, NumMaterials() do
            self.materialLines[i].amountLabel.caption = ""
        end
    end

    -- used to fill values into the UI
    -- config == nil means fill with default values
    ui.refresh = function(self, ownerIndex, shipName, area, config)

        self.commonUI:refresh(ownerIndex, shipName, area, config)

        if not config then
            -- no config: fill UI with default values, then build config, then use it to calculate yields
            for _, line in pairs(self.materialLines) do
                line.checkBox:setCheckedNoCallback(true)
            end

            config = self:buildConfig()
        end

        self:refreshPredictions(ownerIndex, shipName, area, config)
    end

    -- gut feeling says that each config option change should always be reflected in the predictions if it impacts the behavior
    ui.refreshPredictions = function(self, ownerIndex, shipName, area, config)
        local prediction = RefineCommand:calculatePrediction(ownerIndex, shipName, area, config)
        self:displayPrediction(prediction, config, ownerIndex)

        self.commonUI:refreshPredictions(ownerIndex, shipName, area, config, RefineCommand, prediction)
    end

    ui.displayPrediction = function(self, prediction, config, ownerIndex)
        for i = 1, NumMaterials() do
            self.materialLines[i].amountLabel:hide()
            self.materialLines[i].textLabel:hide()
            self.materialLines[i].checkBox:hide()
        end

        local c = 1
        for i = 1, NumMaterials() do
            if prediction.yields[i] > 0 or not config.refined[i] then
                local material = Material(i - 1)

                self.materialLines[c].amountLabel:show()
                self.materialLines[c].textLabel:show()
                self.materialLines[c].checkBox:show()
                self.materialLines[c].checkBox:setCheckedNoCallback(config.refined[i])
                self.materialLines[c].material = material

                self.materialLines[c].amountLabel.caption = toReadableNumber(prediction.yields[i], 2)
                self.materialLines[c].textLabel.caption = material.name
                self.materialLines[c].textLabel.color = material.color
                self.materialLines[c].amountLabel.color = material.color

                self.materialLines[c].textLabel.strikethrough = not config.refined[i]
                self.materialLines[c].amountLabel.strikethrough = not config.refined[i]

                if not config.refined[i] then
                    self.materialLines[c].amountLabel.caption = "    "%_t
                end

                c = c + 1
            end
        end

        if c == 1 then
            self.materialLines[3].textLabel.color = ColorRGB(0.9, 0.9, 0.9)
            self.materialLines[3].textLabel.caption = "No Resources"%_t
            self.materialLines[3].textLabel:show()
        end

        self.commonUI:setAttackChance(prediction.attackChance)

        self.durationLabel.caption = "${minutes} min"%_t % {minutes = math.ceil(prediction.duration / 60)}
        self.refineryIcon.visible = prediction.nearbyRefinery
        self.taxLabel.caption = "${tax}%"%_t % {tax = round(prediction.tax * 100, 2)}
    end

    -- used to build a config table for the command, based on values configured in the UI
    -- gut feeling says that each config option change should always be reflected in the predictions if it impacts the behavior
    ui.buildConfig = function(self)
        local config = {}

        config.escorts = self.commonUI.escortUI:buildConfig()

        config.refined = {}
        for i = 1, NumMaterials() do
            config.refined[i] = true
        end

        for _, line in pairs(self.materialLines) do
            if line.material and line.checkBox.visible then
                config.refined[line.material.value + 1] = line.checkBox.checked
            end
        end

        return config
    end

    ui.setActive = function(self, active, description)
        self.commonUI:setActive(active, description)

        for i = 1, NumMaterials() do
            self.materialLines[i].checkBox.active = active
        end
    end

    ui.displayConfig = function(self, config, ownerIndex)
    end

    return ui
end


return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
