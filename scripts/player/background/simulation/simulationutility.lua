
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/player/background/simulation/?.lua"

local CaptainUtility = include ("captainutility")
local PassageMap = include ("passagemap")
local Placer = include ("placer")
include ("randomext")
include ("galaxy")

local SimulationUtility = {}

SimulationUtility.UsableError =
{
    Unavailable = 1,
    NotAShip = 2,
    NoCaptain = 3,
    BadCrew = 4,
    BadEnergy = 5,
    Damaged = 6,
    UnderAttack = 7,
}

SimulationUtility.AttackChanceLabelCaption = "Ambush Probability"%_t
SimulationUtility.AttackChanceLabelTooltip = "Probability of being attacked by pirates or an enemy faction during the operation. Stronger ships with more escorts are safer."%_t
                                              .. "\n\n" .. "Influenced by: Area, command duration, your ship's durability, shields, firepower, and escorts."%_t

function SimulationUtility.isShipUsable(ownerIndex, shipName, ignoredErrors)
    -- caveat: Some errors cannot be ignored as they don't make sense, such as Unavailable, NoCaptain or NotAShip
    ignoredErrors = ignoredErrors or {}

    local databaseEntry = ShipDatabaseEntry(ownerIndex, shipName)
    if not valid(databaseEntry) then
        -- eprint("not available!")
        return SimulationUtility.UsableError.Unavailable
    end

    -- ship must be available
    if databaseEntry:getAvailability() ~= ShipAvailability.Available then
        -- eprint("not available!")
        return SimulationUtility.UsableError.Unavailable
    end

    -- ship must not be in a rift
    local x, y = databaseEntry:getCoordinates()
    if Galaxy():sectorInRift(x, y) then
        -- eprint("not available!")
        return SimulationUtility.UsableError.Unavailable
    end

    -- ship must be a ship (not a station, etc.)
    if databaseEntry:getEntityType() ~= EntityType.Ship then
        -- eprint("not a ship!")
        return SimulationUtility.UsableError.NotAShip
    end

    -- ship must have a captain
    if not databaseEntry:getCaptain() then
        -- eprint("no captain!")
        return SimulationUtility.UsableError.NoCaptain
    end

    if not ignoredErrors[SimulationUtility.UsableError.BadCrew] then
        -- ship must have crew requirements fulfilled
        if not databaseEntry:getCrewRequirementsFulfilled() then
            -- eprint("crew requirements not fulfilled!")
            return SimulationUtility.UsableError.BadCrew
        end
    end

    if not ignoredErrors[SimulationUtility.UsableError.BadEnergy] then
        -- ship must have energy requirements fulfilled
        local requiredEnergy, producedEnergy = databaseEntry:getEnergyProperties()
        if requiredEnergy > producedEnergy then
            -- eprint("energy requirements not fulfilled!")
            return SimulationUtility.UsableError.BadEnergy
        end
    end

    if not ignoredErrors[SimulationUtility.UsableError.Damaged] then
        -- ship must have energy requirements fulfilled
        local maxHP, hpPercentage, malus, malusReason, damaged = databaseEntry:getDurabilityProperties()
        if damaged then
            -- eprint("ship is damaged!")
            return SimulationUtility.UsableError.Damaged
        end
    end

    if not ignoredErrors[SimulationUtility.UsableError.UnderAttack] then
        -- ship must not have impaired hyperspace engine (which means it's under attack)
        local range, canPassRifts, cooldown, impaired = databaseEntry:getHyperspaceProperties()
        if impaired then
            -- eprint("ship is under attack!")
            return SimulationUtility.UsableError.UnderAttack
        end

        local scripts = databaseEntry:getScripts()
        for _, name in pairs(scripts) do
            if string.match(name, "/piratesattackentity.lua")
                    or string.match(name, "/factionattackentity.lua") then
                return SimulationUtility.UsableError.UnderAttack
            end
        end
    end
end

function SimulationUtility.getUsableErrorAssessmentMessage(error)
    if error == SimulationUtility.UsableError.Unavailable then
        return "Ship not available."%_t
    elseif error == SimulationUtility.UsableError.NotAShip then
        return "This isn't a ship."%_t
    elseif error == SimulationUtility.UsableError.NoCaptain then
        return "Ship doesn't have a captain."%_t
    elseif error == SimulationUtility.UsableError.BadCrew then
        return "There are issues with the crew on the ship."%_t
    elseif error == SimulationUtility.UsableError.BadEnergy then
        return "The ship doesn't fulfill minimal energy requirements."%_t
    elseif error == SimulationUtility.UsableError.Damaged then
        return "The ship is too damaged."%_t
    elseif error == SimulationUtility.UsableError.UnderAttack then
        return "The ship is under attack!"%_t
    end
end

function SimulationUtility.getEscortErrorAssessmentMessage(error)
    if error == SimulationUtility.EscortError.Unavailable then
        return "Ship not available."%_t
    elseif error == SimulationUtility.EscortError.TooFarAway then
        return "Ship is too far away."%_t
    elseif error == SimulationUtility.EscortError.Unreachable then
        return "Ship can't reach this ship."%_t
    elseif error == SimulationUtility.EscortError.Unusable then
        return "There are issues with the ship."%_t
    end
end

SimulationUtility.EscortError =
{
    Unavailable = 1,
    TooFarAway = 2,
    Unreachable = 3,
    Unusable = 4,
}

function SimulationUtility.isShipUsableAsEscort(owner, escorter, escortee)
    if escorter == escortee then
        return SimulationUtility.EscortError.Unavailable
    end

    local sx, sy = owner:getShipPosition(escortee)

    if owner:getShipAvailability(escorter) ~= ShipAvailability.Available then
        return SimulationUtility.EscortError.Unavailable
    end

    local databaseEntry = ShipDatabaseEntry(owner.index, escorter)
    local reach, canPassRifts, cooldown = databaseEntry:getHyperspaceProperties()

    local ex, ey = databaseEntry:getCoordinates()

    if distance2(vec2(ex, ey), vec2(sx, sy)) > reach * reach then
        return SimulationUtility.EscortError.TooFarAway
    end

    if not canPassRifts then
        if Balancing_InsideRing(ex, ey) ~= Balancing_InsideRing(sx, sy) then
            return SimulationUtility.EscortError.Unreachable
        end
    end

    local usableError = SimulationUtility.isShipUsable(owner.index, escorter)
    if usableError then
        return SimulationUtility.EscortError.Unusable, usableError
    end

end

function SimulationUtility.buildCommandUI(window, startPressedCallback, changeAreaPressedCallback, recallPressedCallback, configChangedCallback, settings)
    settings = settings or {}

    local areaHeight = settings.areaHeight or 150
    local configHeight = settings.configHeight or 80
    local predictionHeight = settings.predictionHeight or 300
    local changeAreaButton = settings.changeAreaButton or false
    local changeAreaButtonIcon = settings.changeAreaButtonIcon or "data/textures/icons/change-area.png"
    local changeAreaButtonTooltip = settings.changeAreaButtonTooltip or "Choose a different area for the command"%_t

    local ui = {}

    local size = window.size

    local vlist = UIVerticalLister(Rect(size), 30, 20)
    ui.topRect = vlist:nextRect(areaHeight)
    ui.middleRect = vlist:nextRect(configHeight)
    ui.bottomRect = vlist.inner

    local vsplit = UIVerticalSplitter(ui.topRect, 10, 0, 0.55)
    local vsplitLeft = UIVerticalSplitter(vsplit.left, 10, 0, 0.5)

    -- area analysis
    local vlist = UIVerticalLister(vsplitLeft.left, 7, 0)
    ui.areaLabel3 = window:createLabel(vlist:nextRect(15), "Area:"%_t, 13)
    vlist:nextRect(15)
    window:createLabel(vlist:nextRect(15), "Unreachable:"%_t, 13)

    vlist:nextRect(1)
    window:createLabel(vlist:nextRect(15), "No Man's Space:"%_t, 13)
    window:createLabel(vlist:nextRect(15), "Outer Faction Area:"%_t, 13)
    window:createLabel(vlist:nextRect(15), "Central Faction Area:"%_t, 13)

    -- area analysis values
    local vlist = UIVerticalLister(vsplitLeft.right, 7, 0)
    ui.areaLabel = window:createLabel(vlist:nextRect(15), "", 13)
    ui.areaLabel2 = window:createLabel(vlist:nextRect(15), "", 13)
    ui.unreachableLabel = window:createLabel(vlist:nextRect(15), "", 13)

    vlist:nextRect(1)
    ui.noMansSpaceLabel = window:createLabel(vlist:nextRect(15), "", 13)
    ui.outerAreaLabel = window:createLabel(vlist:nextRect(15), "", 13)
    ui.centralAreaLabel = window:createLabel(vlist:nextRect(15), "", 13)

    -- escort
    ui.escortRect = vsplit.right
    ui.escortUI = SimulationUtility.buildEscortUI(window, ui.escortRect, configChangedCallback)

    if settings.hideEscortUI then
        ui.escortUI:setVisible(false)
    end

    -- separator
    local lineRect = Rect(ui.topRect.bottomLeft, ui.middleRect.topRight)
    window:createLine(vec2(lineRect.lower.x, lineRect.center.y), vec2(lineRect.upper.x, lineRect.center.y))

    -- config UI
    ui.configRect = copy(ui.middleRect)

    -- separator
    local lineRect = Rect(ui.middleRect.bottomLeft, ui.bottomRect.topRight)
    window:createLine(vec2(lineRect.lower.x, lineRect.center.y), vec2(lineRect.upper.x, lineRect.center.y))


    -- assessment
    local ahsplit = UIHorizontalSplitter(ui.bottomRect, 20, 0, 0.5)
    ahsplit.topSize = 30
    ui.assessmentLabel = window:createLabel(ahsplit.top, "", 16)
    ui.assessmentLabel:setCenterAligned()

    local qvsplit = UIVerticalSplitter(ahsplit.top, 10, 0, 0.5)
    qvsplit.marginRight = 0
    qvsplit:setRightQuadratic()


    local picture = window:createPicture(qvsplit.right, "data/textures/icons/help.png")
    picture.isIcon = true
    picture.tooltip = "You can mouse over the fields and captain for more details."%_t

    local vsplit = UIVerticalSplitter(ahsplit.bottom, 20, 0, 0.5)
    ui.assessmentRect = vsplit.left

    local chsplit = UIHorizontalSplitter(vsplit.left, 20, 0, 0.25)

    local captainRect = chsplit.top
    captainRect.height = captainRect.height + 30
    captainRect.width = captainRect.height
    ui.captainIcon = window:createCaptainIcon(captainRect)

    window:createFrame(chsplit.bottom)
    local inner = UIOrganizer(chsplit.bottom)
    inner.margin = 5
    ui.assessmentField = window:createTextField(inner.inner, "")
    ui.assessmentField.font = FontType.Normal
    ui.assessmentField.fontSize = 12
    ui.assessmentField.fontColor = ColorRGB(0.6, 0.6, 0.6)
    ui.assessmentField.italic = true
    ui.assessmentField.padding = 5

    -- prediction UI
    ui.predictionRect = vsplit.right

    -- start button
    local hsplitBottom = UIHorizontalSplitter(Rect(size), 10, 10, 0.5)
    hsplitBottom.bottomSize = 40
    local vsplit = UIVerticalMultiSplitter(hsplitBottom.bottom, 10, 0, 3)

    ui.startButton = window:createButton(vsplit.right, "Start /* Starts a ship's command */"%_t, startPressedCallback)

    local progressRect = Rect(vsplit:partition(2).lower, vsplit:partition(3).upper)
    ui.progressLabel = window:createLabel(progressRect, "", 16)
    ui.progressLabel:setRightAligned()

    local vsplitLowerLeft = UIVerticalSplitter(vsplit:partition(2), 0, 0, 0.5)
    vsplitLowerLeft:setLeftQuadratic()
    if changeAreaButton == true then
        ui.changeAreaButton = window:createButton(vsplitLowerLeft.left, "", changeAreaPressedCallback)
        ui.changeAreaButton.icon = changeAreaButtonIcon
        ui.changeAreaButton.tooltip = changeAreaButtonTooltip
    end

    ui.recallButton = window:createButton(vsplitLowerLeft.left, "", recallPressedCallback)
    ui.recallButton.icon = "data/textures/icons/arrow-left.png"
    ui.recallButton.tooltip = "Recall Ship"%_t

    ui.setAttackChance = function(self, attackChance)
        local attackPercentage = math.min(math.ceil(attackChance * 100), 100)

        self.attackChanceLabel.caption = string.format("%s%%", attackPercentage)

        if attackChance == 0 then
            self.attackChanceLabel.color = ColorRGB(0, 1, 0)
        else
            local color = lerp(attackChance, 0.0, 0.3, vec3(1, 1, 0), vec3(1, 0, 0))
            self.attackChanceLabel.color = ColorRGB(color.x, color.y, color.z)
        end
    end

    ui.clear = function(self, shipName)
        self.areaLabel.caption = ""
        self.areaLabel2.caption = ""
        self.unreachableLabel.caption = ""
        self.noMansSpaceLabel.caption = ""
        self.outerAreaLabel.caption = ""
        self.centralAreaLabel.caption = ""
        self.assessmentLabel.caption = ""
        self.assessmentField.text = ""
        self.captainIcon:hide()

        self.escortUI:clear()
    end

    ui.refresh = function(self, ownerIndex, shipName, area, config)
        self.escortUI:refresh(ownerIndex, shipName, area, config)

        self:setAreaStats(SimulationUtility.getAreaStats(area))
    end

    ui.setAreaStats = function(self, stats)
        self.areaLabel.caption = string.format("%d sectors"%_t, stats.numSectors)
        self.areaLabel2.caption = "[${lower.x}:${lower.y} to ${upper.x}:${upper.y}]"%_t % stats.area
        self.unreachableLabel.caption = string.format("%d sectors"%_t, stats.unreachableSectors)
        self.noMansSpaceLabel.caption = string.format("%d%%", stats.noMansSectors)
        self.outerAreaLabel.caption = string.format("%d%%", stats.outerSectors)
        self.centralAreaLabel.caption = string.format("%d%%", stats.centralSectors)
    end

    ui.refreshPredictions = function(self, ownerIndex, shipName, area, config, command, prediction)
        self.assessmentLabel.caption = "Captain's Assessment"%_t
        self.assessmentField.text = ""

        local error = nil

        local entry = ShipDatabaseEntry(ownerIndex, shipName)
        if valid(entry) then
            local captain = entry:getCaptain()

            if valid(captain) then
                local assessment = command:generateAssessmentFromPrediction(prediction, captain, ownerIndex, shipName, area, config)
                self:setAssessment(captain, assessment, command.type)
            else
                error = "No captain!"%_t
            end
        else
            error = "No captain!"%_t
        end

        -- check the regular detectable errors first since that's the order that the simulation.lua checks them as well
        if not error then
            local msg, args = command:getErrors(ownerIndex, shipName, area, config)
            if msg then
                error = Format(msg, unpack(args or {})):translated()
            end
        end

        -- check if there are any non-easily detectable errors that only start popping up in the prediction calculation
        if not error and prediction.error then
            error = Format(prediction.error, unpack(prediction.errorArgs or {})):translated()
        end

        -- check if the ship is usable
        if not error then
            local ignoredErrors = {}
            if command.getIgnoredErrors then
                ignoredErrors = command:getIgnoredErrors() or {}
            end

            error = SimulationUtility.getUsableErrorAssessmentMessage(SimulationUtility.isShipUsable(ownerIndex, shipName, ignoredErrors))
        end

        if error then
            error = "Commander, with all due respect, but I can't work like this. ${error}"%_t % {error = error}
            self.assessmentField.text = string.format("\"%s\""%_t, error)
            self.assessmentField.fontColor = ColorRGB(0.8, 0.4, 0.4)
            self.startButton.active = false
        else
            self.assessmentField.fontColor = ColorRGB(0.6, 0.6, 0.6)
            self.startButton.active = true
        end

    end

    ui.setAssessment = function(self, captain, assessment, commandType)
        self.assessmentLabel.caption = "Captain ${name}'s Assessment"%_t % {name = captain.displayName}

        local translatedAssessment = {}
        for _, line in pairs(assessment) do
            table.insert(translatedAssessment, line%_t)
        end

        self.assessmentField.text = string.format("\"%s\""%_t, string.join(translatedAssessment, " "))

        self.captainIcon:show()
        self.captainIcon:setCaptain(captain)

        local tooltip = CaptainUtility.makeTooltip(captain, commandType)
        self.captainIcon:setCustomTooltip(tooltip)
    end

    ui.setActive = function(self, active, description)
        if self.changeAreaButton then self.changeAreaButton.visible = active end
        self.startButton.visible = active

        self.progressLabel.visible = not active
        self.recallButton.visible = not active

        if description and description.timeRemaining and description.completed then
            self.progressLabel.caption = "${timeRemaining} remaining (${completed} % done)"%_t % description
        else
            self.progressLabel.caption = ""
        end
    end

    return ui
end

function SimulationUtility.getAreaStats(area)
    local sectors = area.analysis.sectors
    local unreachable = area.analysis.unreachable

    local uncontrolled = 0
    local centralSectors = 0
    local outerSectors = 0
    for _, sector in pairs(area.analysis.reachableCoordinates) do
        if sector.faction > 0 then
            if sector.isCentralArea then
                centralSectors = centralSectors + 1
            else
                outerSectors = outerSectors + 1
            end
        else
            uncontrolled = uncontrolled + 1
        end
    end

    local reachable = uncontrolled + outerSectors + centralSectors

    local noMansPercentage = round(uncontrolled / reachable * 100)
    local outerPercentage = round(outerSectors / reachable * 100)
    local centralPercentage = 100 - noMansPercentage - outerPercentage

    return
    {
        numSectors = sectors,
        area = {lower = area.lower, upper = area.upper, origin = area.origin},
        unreachableSectors = unreachable,
        noMansSectors = noMansPercentage,
        outerSectors = outerPercentage,
        centralSectors = centralPercentage,
    }
end

function SimulationUtility.buildEscortUI(window, rect, configChangedCallback)
    local ui = {}

    local hsplit = UIHorizontalSplitter(rect, 5, 0, 0.5)
    hsplit.topSize = 15

    ui.escortLabel = window:createLabel(hsplit.top, "Escorts / Support"%_t, 13)

    ui.escortList = window:createListBoxEx(hsplit.bottom)
    ui.escortList.columns = 3
    ui.escortList:setColumnWidth(0, 20)
    ui.escortList:setColumnWidth(1, 20)
    ui.escortList:setColumnWidth(2, rect.width - 40)
    ui.escortList.entriesSelectable = false

    ui.refresh = function(self, ownerIndex, shipName, area, config)
        self.escortList:clear()
        self.escortList.onChangedFunction = ""

        local entries = {}

        local owner = Galaxy():findFaction(ownerIndex)
        for _, escort in pairs({owner:getShipNames()}) do

            if escort == shipName then goto continue end

            local escortError, usableError = SimulationUtility.isShipUsableAsEscort(owner, escort, shipName)

            -- only skip if the craft is not a ship
            if usableError == SimulationUtility.UsableError.NotAShip then goto continue end

            local entry = ShipDatabaseEntry(ownerIndex, escort)
            if not valid(entry) then goto continue end
            if entry:getEntityType() ~= EntityType.Ship then goto continue end

            local listEntry = {}

            listEntry.icon = entry:getIcon()
            local title = entry:getTitle():translated()

            listEntry.name = escort
            listEntry.fullName = escort
            if title ~= "" then listEntry.fullName = title .. " - " .. listEntry.fullName end

            if usableError then
                listEntry.tooltip = SimulationUtility.getUsableErrorAssessmentMessage(usableError)
                listEntry.color = ColorRGB(0.5, 0.5, 0.5)
                listEntry.error = 1
            elseif escortError then
                listEntry.tooltip = SimulationUtility.getEscortErrorAssessmentMessage(escortError)
                listEntry.color = ColorRGB(0.5, 0.5, 0.5)
                listEntry.error = 1
            else
                listEntry.color = ColorRGB(0.9, 0.9, 0.9)
                listEntry.error = 0
            end

            table.insert(entries, listEntry)

            ::continue::
        end

        table.sort(entries, function(a, b)
            if a.error == b.error then
                return a.name < b.name
            end
            return a.error < b.error
        end)

        for _, entry in pairs(entries) do

            self.escortList:addRow(entry.name, "", entry.icon, entry.fullName)
            if entry.error > 0 then
                self.escortList:setEntryType(1, self.escortList.rows - 1, ListBoxEntryType.PixelIcon)
                self.escortList:setEntry(2, self.escortList.rows - 1, entry.fullName, false, false, entry.color)
            else
                self.escortList:setEntryType(0, self.escortList.rows - 1, ListBoxEntryType.CheckBox)
                self.escortList:setEntryType(1, self.escortList.rows - 1, ListBoxEntryType.PixelIcon)
                self.escortList:setEntry(2, self.escortList.rows - 1, entry.fullName, false, false, entry.color)
            end

            if entry.tooltip then
                self.escortList:setEntryTooltip(2, self.escortList.rows - 1, entry.tooltip)
            end
        end

        self.escortList.onChangedFunction = configChangedCallback
    end

    ui.buildConfig = function(self)
        local escorts = {}
        for i = 0, self.escortList.rows - 1 do
            local checked, _, _, _, value = self.escortList:getEntry(0, i)

            if checked ~= "" then
                table.insert(escorts, value)
            end
        end

        return escorts
    end

    ui.clear = function(self)
        self.escortList:clear()
    end

    ui.setVisible = function(self, visible)
        self.escortLabel.visible = visible
        self.escortList.visible = visible
    end

    ui.fillReadOnly = function(self, escorts)
        self.escortList:clear()
        for _, name in pairs(escorts) do
            self.escortList:addRow("", "", "", name)
        end
    end

    return ui
end

function SimulationUtility.calculateShortAttackProbability(ownerIndex, shipName, area, escorts)
    return SimulationUtility.calculateAttackProbability(ownerIndex, shipName, area, escorts, 0.5)
end

function SimulationUtility.calculatePirateAttackSectorRatio(area)
    local outerFactionAreaWeight = 0.4
    local noMansWeight = 1

    local noMansSector = {}
    local outerFactionSectors = {}

    for i, sector in pairs(area.analysis.reachableCoordinates) do
        if sector.faction == 0 then
            table.insert(noMansSector, sector)
        else
            if not sector.isCentralArea then
                table.insert(outerFactionSectors, sector)
            end
        end
    end

    local total = area.analysis.sectors - area.analysis.unreachable
    local ratio = (noMansWeight * #noMansSector + outerFactionAreaWeight * #outerFactionSectors) / total
    return ratio
end

function SimulationUtility.calculateAttackProbability(ownerIndex, shipName, area, escorts, hours, attackChanceModification)

    escorts = escorts or {}
    hours = hours or 1

    local centralFactionAreaWeight = 0
    local outerFactionAreaWeight = 0.4
    local noMansWeight = 1
    local centralFactionAreaWarWeight = 2
    local outerFactionAreaWarWeight = 0.8

    local galaxy = Galaxy()
    local owner = galaxy:findFaction(ownerIndex)

    -- stats of the own ships
    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local captain = entry:getCaptain()
    local turretDps, fighterDps = entry:getDPSValues()
    local maxHP = entry:getDurabilityProperties()
    local maxShields = entry:getShields()

    local selfDps = turretDps + fighterDps
    local selfHP = maxHP + maxShields

    if captain:hasPerk(CaptainUtility.PerkType.Noble) then
        selfDps = selfDps * CaptainUtility.getShipStrengthPerks(captain, CaptainUtility.PerkType.Noble)
        selfHP = selfHP * CaptainUtility.getShipStrengthPerks(captain, CaptainUtility.PerkType.Noble)
    end

    if captain:hasPerk(CaptainUtility.PerkType.Commoner) then
        selfDps = selfDps * CaptainUtility.getShipStrengthPerks(captain, CaptainUtility.PerkType.Commoner)
        selfHP = selfHP * CaptainUtility.getShipStrengthPerks(captain, CaptainUtility.PerkType.Commoner)
    end

    local commodores = 0
    local escortStrengths = {}

    for _, escort in pairs(escorts) do
        local entry = ShipDatabaseEntry(ownerIndex, escort)
        local captain = entry:getCaptain()

        if captain then
            local turretDps, fighterDps = entry:getDPSValues()
            local maxHP = entry:getDurabilityProperties()
            local maxShields = entry:getShields()

            local multiplier = 1
            if captain:hasPerk(CaptainUtility.PerkType.Noble) then
                multiplier = CaptainUtility.getShipStrengthPerks(captain, CaptainUtility.PerkType.Noble)
            end

            if captain:hasPerk(CaptainUtility.PerkType.Commoner) then
                multiplier = CaptainUtility.getShipStrengthPerks(captain, CaptainUtility.PerkType.Commoner)
            end

            local escortDps = (turretDps + fighterDps) * multiplier
            local escortHp = (maxHP + maxShields) * multiplier

            selfDps = selfDps + escortDps
            selfHP = selfHP + escortHp

            if captain:hasClass(CaptainUtility.ClassType.Commodore) then
                commodores = commodores + 1
            end

            escortStrengths[escort] = {dps = escortDps, hp = escortHp, dangerousSectors = 0}
        end
    end

    local sum = 0
    local samples = 0

    -- just use the general vicinity, this avoids having to do lookups (like faction home sectors) that must work on both client and server
    local x = math.floor(area.upper.x + area.lower.x) / 2
    local y = math.floor(area.upper.y + area.lower.y) / 2

    -- stats of the enemies in this area
    local otherHP = Balancing_GetSectorShipHP(x, y)
    local otherDps = Balancing_GetSectorWeaponDPS(x, y)
    otherDps = otherDps * Balancing_GetEnemySectorTurrets(x, y)
    otherDps = otherDps * GameSettings().damageMultiplier

    local sectorsByFaction = {}
    local sectorAttackWeights = {}
    for i, coords in pairs(area.analysis.reachableCoordinates) do
        local sectors = sectorsByFaction[coords.faction]
        if not sectors then
            sectors = {}
            sectorsByFaction[coords.faction] = sectors
        end

        table.insert(sectors, i)
    end

    for faction, sectors in pairs(sectorsByFaction) do
        for _, sectorIndex in pairs(sectors) do
            local sector = area.analysis.reachableCoordinates[sectorIndex]

            local weight = 0
            local dpsFactor = 1
            local hpFactor = 1.5
            local enemies = 5
            local timeToKillFactor = 0.75

            if faction == 0 then
                weight = noMansWeight
            else
                local status = owner:getRelationStatus(faction)
                if status == RelationStatus.War then
                    -- we're at war with the faction in the area, so they might attack us
                    if sector.isCentralArea then
                        weight = centralFactionAreaWarWeight
                    else
                        weight = outerFactionAreaWarWeight
                    end

                    hpFactor = 7.5
                    dpsFactor = 2

                    enemies = 5
                else
                    -- we're not at war with the faction in the area, so if we get attacked it's pirates
                    if sector.isCentralArea then
                        weight = centralFactionAreaWeight
                    else
                        weight = outerFactionAreaWeight
                    end
                end
            end

            local probability = 0

            -- probability calculation is only necessary if the weight of the area is > 0
            if weight > 0 then
                local otherHpThisSector = otherHP * hpFactor * enemies
                local otherDpsThisSector = otherDps * dpsFactor * enemies

                -- calculate how much time it would take for the own ships to kill the enemies, vs the other way around
                local timeToKill = otherHpThisSector / (selfDps + 10) -- it would take the ships this much time to kill the pirates
                local timeAlive = selfHP / (otherDpsThisSector + 0.01) -- they would get killed in this much time

                -- if it would take the pirates X% of the time or faster to kill the ships, the attack likelihood increases
                -- maximum likelihood of 100% is at "pirates would kill the ships 10x faster than the other way around"
                if timeAlive < timeToKill * timeToKillFactor then
                    probability = lerp(timeAlive, timeToKill * 0.1, timeToKill * timeToKillFactor, 1, 0)
                end

                -- also, check for each of the escorts to determine base strength
                for escort, data in pairs(escortStrengths) do
                    -- calculate how much time it would take for the own ships to kill the enemies, vs the other way around
                    local timeToKill = otherHpThisSector / (data.dps + 10) -- it would take the ships this much time to kill the pirates
                    local timeAlive = data.hp / (otherDpsThisSector + 0.01) -- they would get killed in this much time

                    -- if it would take the pirates X% of the time or faster to kill the ships, the attack likelihood increases
                    -- maximum likelihood of 100% is at "pirates would kill the ships 10x faster than the other way around"
                    if timeAlive < timeToKill * timeToKillFactor then
                        local probability = lerp(timeAlive, timeToKill * 0.1, timeToKill * timeToKillFactor, 1, 0)
                        if probability > 0.15 then
                            data.dangerousSectors = data.dangerousSectors + 1
                        end
                    end
                end

                -- attack probability is weighted based on the area we're in (ie. pirates less likely in faction territory)
                probability = probability * weight

                -- assign probability for each sector to be the one where the attack happens
                sectorAttackWeights[sectorIndex] = probability
            end

            -- calculate total sum, weighted by sectors for average attack probability
            sum = sum + probability
            samples = samples + 1
        end
    end

    -- calculate the total attack probability
    -- this is the probability that decides if there will be an attack AT ALL
    local attackProbability = 0
    local baseProbability = 0
    if samples > 0 then
        attackProbability = sum / samples
        baseProbability = hours * 0.03

        if captain:hasClass(CaptainUtility.ClassType.Commodore) then
            commodores = commodores + 1
        end

        for i = 1, commodores do
            baseProbability = baseProbability * 0.85
        end
    end

    -- reduce base attack chance for each escort ship that is strong enough to rather not be attacked in the area
    for escort, data in pairs(escortStrengths) do
        -- having less than 50% of sectors where the ship wouldn't get attacked means that it's strong enough to reduce base attack chance
        if data.dangerousSectors < samples / 2 then
            baseProbability = baseProbability * 0.75
        end
    end

    -- attack probability increases by 40% for every additional hour after the first
    -- it also decreases for shorter times
    attackProbability = attackProbability + (attackProbability * (hours - 1) * 0.4)
    attackProbability = math.max(baseProbability, attackProbability)

    -- apply captain perks and classes
    local baseAttackProbability = attackProbability

    if captain:hasClass(CaptainUtility.ClassType.Commodore) then
        attackProbability = attackProbability - 0.15
    end

    if captain:hasPerk(CaptainUtility.PerkType.Reckless) then
        if baseAttackProbability > 0 then
            attackProbability = attackProbability + CaptainUtility.getPerkAttackProbabilities(captain, CaptainUtility.PerkType.Reckless)
        end
    end

    if captain:hasPerk(CaptainUtility.PerkType.Stealthy) then
        attackProbability = attackProbability + CaptainUtility.getPerkAttackProbabilities(captain, CaptainUtility.PerkType.Stealthy)
    end

    if captain:hasPerk(CaptainUtility.PerkType.Intimidating) then
        attackProbability = attackProbability + CaptainUtility.getPerkAttackProbabilities(captain, CaptainUtility.PerkType.Intimidating)
    end

    if captain:hasPerk(CaptainUtility.PerkType.Cunning) then
        attackProbability = attackProbability + CaptainUtility.getPerkAttackProbabilities(captain, CaptainUtility.PerkType.Cunning)
    end

    if captain:hasPerk(CaptainUtility.PerkType.Arrogant) then
        if baseAttackProbability > 0 then
            attackProbability = attackProbability + CaptainUtility.getPerkAttackProbabilities(captain, CaptainUtility.PerkType.Arrogant)
        end
    end

    if captain:hasPerk(CaptainUtility.PerkType.Harmless) then
        if baseAttackProbability > 0 then
            attackProbability = attackProbability + CaptainUtility.getPerkAttackProbabilities(captain, CaptainUtility.PerkType.Harmless)
        end
    end

    if captain:hasPerk(CaptainUtility.PerkType.Careful) then
        attackProbability = attackProbability + CaptainUtility.getPerkAttackProbabilities(captain, CaptainUtility.PerkType.Careful)
    end

    attackProbability = math.max(baseProbability, attackProbability)

    if attackChanceModification then
        attackProbability = attackChanceModification(attackProbability, baseAttackProbability, baseProbability)
    end

    attackProbability = math.min(1.0, attackProbability)
    attackProbability = round(attackProbability, 2) -- round to 0.01's so that a displayed percentage of 0% is actually 0

    -- if there is a possibility for an attack, check if there will be an attack and choose a sector that qualifies for it
    local coords = nil
    if attackProbability > 0 and random():test(attackProbability) then
        local index = selectByWeight(random(), sectorAttackWeights)
        coords = area.analysis.reachableCoordinates[index]
    end

    return attackProbability, coords, sectorAttackWeights
end

local function makeKey(x, y)
    return x * 10000 + y
end

function SimulationUtility.calculatePassageMapFill(area, passageMap)
    local reachable = {}

    for x = area.lower.x, area.upper.x do
        for y = area.lower.y, area.upper.y do
            if passageMap:passable(x, y) then
                reachable[makeKey(x, y)] = {x = x, y = y}
            end
        end
    end

    return reachable
end

function SimulationUtility.calculateFloodFill(start, area, passageMap)
    passageMap = passageMap or PassageMap(Seed(GameSettings().seed))

    local reachable = {}
    local done = {}

    -- do the flood fill
    -- use table as a stack, inserting at and removing from the end are efficient
    local stack = {}
    table.insert(stack, start)
    local stackSize = 1
    while stackSize > 0 do
        local sector = table.remove(stack)
        stackSize = stackSize - 1

        local key = makeKey(sector.x, sector.y)
        if not done[key] then
            done[key] = true

            -- is the current sector reachable?
            if passageMap:passable(sector.x, sector.y) then
                reachable[key] = sector

                -- continue searching the surrounding sectors depth-first
                -- up
                if sector.y < area.upper.y then
                    table.insert(stack, {x = sector.x, y = sector.y + 1})
                    stackSize = stackSize + 1
                end
                -- down
                if sector.y > area.lower.y then
                    table.insert(stack, {x = sector.x, y = sector.y - 1})
                    stackSize = stackSize + 1
                end
                -- left
                if sector.x > area.lower.x then
                    table.insert(stack, {x = sector.x - 1, y = sector.y})
                    stackSize = stackSize + 1
                end
                -- right
                if sector.x < area.upper.x then
                    table.insert(stack, {x = sector.x + 1, y = sector.y})
                    stackSize = stackSize + 1
                end
            end
        end
    end

    return reachable
end

function SimulationUtility.getPirateAssessmentLines(pirateSectorRatio)

    local pirateLines = {}
    if pirateSectorRatio >= 0.75 then
        table.insert(pirateLines, "\\c(d93)However, the area is teeming with enemies.\\c()"%_t)
        table.insert(pirateLines, "\\c(d93)However, there are really a lot of hostile sectors here.\\c()"%_t)
        table.insert(pirateLines, "\\c(d93)However, this is enemy territory.\\c()"%_t)
    elseif pirateSectorRatio >= 0.45 then
        table.insert(pirateLines, "\\c(dd5)However, there is quite a lot of enemy activity here.\\c()"%_t)
        table.insert(pirateLines, "\\c(dd5)However, I fear that there are quite some enemy ships around here.\\c()"%_t)
    elseif pirateSectorRatio >= 0.25 then
        table.insert(pirateLines, "There is some enemy activity here."%_t)
    elseif pirateSectorRatio >= 0.1 then
        table.insert(pirateLines, "There is moderate enemy activity."%_t)
        table.insert(pirateLines, "There is some enemy activity here."%_t)
    elseif pirateSectorRatio >= 0.05 then
        table.insert(pirateLines, "There is little enemy activity here."%_t)
        table.insert(pirateLines, "The area here is well protected against enemy ships."%_t)
    elseif pirateSectorRatio > 0.0 then
        table.insert(pirateLines, "There is very little enemy activity here."%_t)
    else
        table.insert(pirateLines, "No detectable enemy activity."%_t)
        table.insert(pirateLines, "No enemies, as far as I can tell."%_t)
    end

    return pirateLines
end

function SimulationUtility.getAttackAssessmentLines(attackChance)

    local attackLines = {}
    if attackChance >= 0.95 then
        table.insert(attackLines, "\\c(d93)In this ship, we are a sitting duck for attackers. Ambush guaranteed. We definitely need a stronger ship or an escort!\\c()"%_t)
    elseif attackChance >= 0.50 then
        table.insert(attackLines, "\\c(d93)I'm estimating the chance of an ambush to be extremely high. I'd like to request a stronger ship or an escort!\\c()"%_t)
    elseif attackChance >= 0.20 then
        table.insert(attackLines, "\\c(dd5)I'm estimating the chance of an ambush on us to be quite high. I'd like to request a stronger ship or an escort.\\c()"%_t)
    elseif attackChance >= 0.10 then
        table.insert(attackLines, "Using a ship this weak seems risky. It is possible that we will be attacked."%_t)
    elseif attackChance >= 0.05 then
        table.insert(attackLines, "I don't like the situation here. There is a certain probability that we might be attacked."%_t)
    elseif attackChance > 0.0 then
        table.insert(attackLines, "I rate the chance of an ambush as low, but not zero."%_t)
    elseif attackChance == 0.0 then
        table.insert(attackLines, "We will not be attacked."%_t)
        table.insert(attackLines, "There's no chance of an ambush."%_t)
        table.insert(attackLines, "I'm sure we won't be attacked."%_t)
    end

    return attackLines
end

function SimulationUtility.getDisappearanceAssessmentLines(attackChance)

    attackChance = attackChance or 0

    local underRadar = {}
    if attackChance >= 0.10 then
        table.insert(underRadar, "We will maintain radio silence and stay under the radar so that we don't attract unwanted attention."%_t)
        table.insert(underRadar, "We'll cease communications for safety reasons and you won't be able to reach us until we're done."%_t)
    else
        table.insert(underRadar, "While conducting the operation I have full autonomy and responsibility over the ship and will not be available for you."%_t)
        table.insert(underRadar, "While we are away, I am taking full command of the ship and you won't be able to reach me."%_t)
        table.insert(underRadar, "To protect my trade secrets, you won't be able to reach me while I'm executing the command."%_t)
        table.insert(underRadar, "I guarantee the best performance possible, but for that I need the sole command over the ship. You won't be able to reach me until I have finished the command."%_t)
    end

    local returnLines = {}
    table.insert(returnLines, "I'll be in touch as soon as we're done."%_t)
    table.insert(returnLines, "I will get back to you when I have finished the command."%_t)

    return underRadar, returnLines
end

function SimulationUtility.getSpecialCargoCategories(cargo)
    local stolenOrIllegal = false
    local dangerousOrSuspicious = false

    for good, amount in pairs(cargo) do
        if good.illegal or good.stolen then
            stolenOrIllegal = true
            break
        elseif good.dangerous or good.suspicious then
            dangerousOrSuspicious = true
            -- no break here, illegal goods should always be detected
        end
    end

    return stolenOrIllegal, dangerousOrSuspicious
end

function SimulationUtility.getIllegalCargoAssessmentLines(stolenOrIllegal, dangerousOrSuspicious, captain)
    local result = {}

    if not stolenOrIllegal and not dangerousOrSuspicious then
        return result
    end

    -- add lines for delays
    if captain:hasClass(CaptainUtility.ClassType.Smuggler) then
        table.insert(result, "We should try to keep some of the goods on board well hidden. I'll take care of it."%_t)
        table.insert(result, "With these goods in the hold, I'm just the right person to avoid getting into trouble. A small sticker here, a wrong label there and everything is legal."%_t)
    elseif captain:hasClass(CaptainUtility.ClassType.Merchant) then
        if stolenOrIllegal then
            table.insert(result, "There are goods on the ship that I should not be associated with. We will have to bypass controls and that will take time."%_t)
            table.insert(result, "I can't run into a cargo inspection with these goods on board. We can avoid the controls, but it will take some time."%_t)
        else
            table.insert(result, "You don't have to worry about cargo inspections because of the questionable goods. I can take care of that."%_t)
            table.insert(result, "Thanks to my licenses, I won't have to dodge any inspections for the questionable goods."%_t)
        end
    else
        table.insert(result, "\\c(dd5)I just noticed that there are goods in the cargo hold here that I'd better not run into a cargo inspection with. I will avoid the controls, but it will take time.\\c()"%_t)
        table.insert(result, "\\c(dd5)With these questionable goods on board, I'll be slower because I'll have to dodge cargo inspections.\\c()"%_t)
        table.insert(result, "\\c(dd5)I still have goods on board that I shouldn't be caught with. As long as I have them on me, I have to avoid cargo inspections. That will take some time.\\c()"%_t)
    end

    return result
end

function SimulationUtility.getCaptainFaction()
    local name = "The Captains"%_T

    local galaxy = Galaxy()
    local faction = galaxy:findFaction(name)
    if faction == nil then
        faction = galaxy:createFaction(name, 0, 0)
    end

    faction.initialRelations = 100000
    faction.initialRelationsToPlayer = 100000
    faction.staticRelationsToPlayers = true
    faction.staticRelationsToAll = true
    faction.homeSectorUnknown = true
    faction:setTrait("invisible", 1)

    return faction
end

function SimulationUtility.spawnAppearance(owner, shipName)
    local captainFaction = SimulationUtility.getCaptainFaction()

    -- check if there is already an appearance of the ship
    for _, ship in pairs({Sector():getEntitiesByScriptValue("displayed_faction")}) do
        if ship.factionIndex == captainFaction.index then
            if ship:getValue("displayed_faction") == owner.index then
                if ship.name == shipName then
                    return ship
                end
            end
        end
    end

--    local x, y = Sector():getCoordinates()
--    print ("spawn appearance", owner.name, x, y, shipName)

    local ship = owner:createCraftFromShipInfo(shipName, Matrix(), captainFaction.index)
    ship:addScript("utility/backgroundshipappearance.lua", owner.index)
    Placer.resolveIntersections({ship})

    return ship
end

return SimulationUtility
