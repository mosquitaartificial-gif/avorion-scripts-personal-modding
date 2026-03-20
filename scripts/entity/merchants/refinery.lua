package.path = package.path .. ";data/scripts/lib/?.lua"
include("stringutility")
include("callable")
include("faction")
include("utility")
include("randomext")
include("merchantutility")
local Dialog = include("dialogutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Refinery
Refinery = {}

local runningJobs = {}
local finishedJobs = {}
local window

local lines = {}

local addAllButton
local refineButton
local takeButton
local remainingTimeLabel
local timeLeft = 0
local totalTime = 0
local progressBar
local taxLabel

local updatedClientFaction
local isInputActive
local isTakingActive
local uiInitialized

Refinery.interactionThreshold = -80000
Refinery.productionCapacity = 1.0

function Refinery.interactionPossible(playerIndex, option)
    return CheckFactionInteraction(playerIndex, Refinery.interactionThreshold)
end

function Refinery.getUpdateInterval()
    return 1
end

function Refinery.secure()
    return {runningJobs = runningJobs, finishedJobs = finishedJobs}
end

function Refinery.restore(data)
    if not data then return end

    runningJobs = data.runningJobs or {}
    finishedJobs = data.finishedJobs or {}

    -- backwards compatibility, jobs were saved as job.netOreAmounts, job.netScrapAmounts
    for _, jobs in pairs({runningJobs, finishedJobs}) do
        for _, job in pairs(jobs) do
            job.netYields = job.netYields or {}
            job.oresToRefine = job.oresToRefine or {}
            job.riftOresToRefine = job.riftOresToRefine or {}
            job.scrapsToRefine = job.scrapsToRefine or {}

            for i = 1, NumMaterials() do
                job.netYields[i] = job.netYields[i] or 0
                job.oresToRefine[i] = job.oresToRefine[i] or 0
                job.riftOresToRefine[i] = job.riftOresToRefine[i] or 0
                job.scrapsToRefine[i] = job.scrapsToRefine[i] or 0

                if job.netOreAmounts then job.netYields[i] = job.netYields[i] + job.netOreAmounts[i] or 0 end
                if job.netScrapAmounts then job.netYields[i] = job.netYields[i] + job.netScrapAmounts[i] or 0 end
            end

            job.netOreAmounts = nil
            job.netScrapAmounts = nil
        end
    end

end

function Refinery.initialize()
    local station = Entity()

    if station.title == "" then
        station.title = "Refinery"%_t
    end

    if onClient() and EntityIcon().icon == "" then
        EntityIcon().icon = "data/textures/icons/pixel/resources.png"
        InteractionText(station.index).text = Dialog.generateStationInteractionText(station, random())
    end

    if onServer() then
        Sector():registerCallback("onRestoredFromDisk", "onRestoredFromDisk")
        station:registerCallback("onBlockPlanChanged", "onBlockPlanChanged")
        Refinery.onBlockPlanChanged()
    end
end

function Refinery.onRestoredFromDisk(timeSinceLastSimulation)
    Refinery.updateServer(timeSinceLastSimulation)
end

function Refinery.updateClient(timeStep)
    local faction = Player().craftFaction
    if valid(faction) then
        if faction.index ~= updatedClientFaction then
            if uiInitialized then
                updatedClientFaction = faction.index

                Refinery.updateClientValues()
            end
        end
    end

    local icon = EntityIcon()

    if uiInitialized then
        if takeButton.active == true then
            icon.secondaryIcon = "data/textures/icons/pixel/resources.png"
            icon.secondaryIconColor = ColorRGB(0.4, 0.9, 0)
        elseif refineButton.active == false then
            icon.secondaryIcon = "data/textures/icons/pixel/resources.png"
            icon.secondaryIconColor = ColorRGB(0.5, 0.5, 0.5)
        else
            -- check if bulletin board wants to show its icon
            local ok = Entity():invokeFunction("bulletinboard.lua", "refreshIcon")
            if ok ~= 0 then
                icon.secondaryIcon = ""
            end
        end
    else
        if isTakingActive == true then
            icon.secondaryIcon = "data/textures/icons/pixel/resources.png"
            icon.secondaryIconColor = ColorRGB(0.4, 0.9, 0)
        elseif isInputActive == false then
            icon.secondaryIcon = "data/textures/icons/pixel/resources.png"
            icon.secondaryIconColor = ColorRGB(0.5, 0.5, 0.5)
        else
            -- check if bulletin board wants to show its icon
            local ok = Entity():invokeFunction("bulletinboard.lua", "refreshIcon")
            if ok ~= 0 then
                icon.secondaryIcon = ""
            end
        end
    end

    if remainingTimeLabel then
        if refineButton and refineButton.active == false then
            Refinery.updateRemainingTimeLabel(timeLeft - timeStep, totalTime)
        end
    end
end

function Refinery.updateServer(timeStep)
    -- send reminders about finished jobs
    for faction, job in pairs(finishedJobs) do
        job.reminderTime = (job.reminderTime or 0) + timeStep

        if job.reminderTime >= 10 * 60 then
            job.reminderTime = 0

            local f = Faction(faction)
            if f then
                f:sendChatMessage(Entity(), ChatMessageType.Normal, "Your refined resources can be picked up in \\s(%1%:%2%)."%_t, Sector():getCoordinates())
            end
        end
    end

    -- check for finished jobs
    for faction, job in pairs(runningJobs) do
        job.remainingTime = job.remainingTime - timeStep

        if job.remainingTime <= 0 then
            local finished = {}

            finished.netYields = job.netYields
            finished.oresToRefine = job.oresToRefine
            finished.riftOresToRefine = job.riftOresToRefine
            finished.scrapsToRefine = job.scrapsToRefine
            finished.totalTime = job.totalTime
            finished.tax = job.tax

            -- pay tax to station faction
            for material = 1, NumMaterials() do
                local taxAmount = job.riftOresToRefine[material] * 4 + job.oresToRefine[material] + job.scrapsToRefine[material] - job.netYields[material]

                if taxAmount > 0 then
                    Faction():receiveResource(Format("Received %1% %2% tax from refinery."%_t, taxAmount, Material(material - 1).name), Material(material - 1), taxAmount)
                end
            end

            finishedJobs[faction] = finished
            runningJobs[faction] = nil

            broadcastInvokeClientFunction("onJobFinished", faction)

            local f = Faction(faction)
            if f then
                f:sendChatMessage(Entity(), ChatMessageType.Normal, "We finished refining your ores. You can pick them up in \\s(%1%:%2%)."%_t, Sector():getCoordinates())
            end
        end
    end
end

function Refinery.addJob(craftIndex, oreAmounts, scrapAmounts, riftOreAmounts, noDockCheck)
    local faction, craft, player = getInteractingFactionByShip(craftIndex, callingPlayer, AlliancePrivilege.SpendItems)
    if not faction then return end

    if callingPlayer then noDockCheck = nil end

    local stationFaction = Faction()
    local relations = stationFaction:getRelations(faction.index)
    if relations < Refinery.interactionThreshold then
        if player then player:sendChatMessage(Entity(), ChatMessageType.Error, "Relations aren't good enough to refine!"%_t) end
        return
    end

    if runningJobs[faction.index] ~= nil then
        if player then player:sendChatMessage(Entity(), ChatMessageType.Error, "You already have a job running."%_t) end
        return
    end

    if finishedJobs[faction.index] ~= nil then
        if player then player:sendChatMessage(Entity(), ChatMessageType.Error, "You have refined resources that need to be picked up first."%_t) end
        return
    end

    local station = Entity()
    local errors = {}
    errors[EntityType.Station] = "You must be docked to the station to refine ores."%_T
    errors[EntityType.Ship] = "You must be closer to the ship to refine ores."%_T
    if not noDockCheck then
        if not CheckShipDocked(player, craft, station, errors) then return end
    end

    local empty, oreAmounts, scrapAmounts, riftOreAmounts = Refinery.removeGoodsToRefine(craft, oreAmounts, scrapAmounts, riftOreAmounts)
    if empty then return end

    local grossYields = Refinery.calculateYields(oreAmounts, scrapAmounts, riftOreAmounts)
    local taxFactor = Refinery.getTaxFactor(stationFaction.index, faction)
    local netYields = Refinery.applyTax(grossYields, taxFactor)

    local time = Refinery.getRefiningTime(oreAmounts, scrapAmounts, riftOreAmounts)
    runningJobs[faction.index] = {
        netYields = netYields,
        grossYields = grossYields,
        oresToRefine = oreAmounts,
        scrapsToRefine = scrapAmounts,
        riftOresToRefine = riftOreAmounts,
        remainingTime = time,
        totalTime = time,
        tax = taxFactor
    }

    Refinery.updateClientValues(craftIndex)
end
callable(Refinery, "addJob")

function Refinery.getRemainingJobDuration(factionIndex)
    if finishedJobs[factionIndex] ~= nil then
        return 0
    end

    if runningJobs[factionIndex] ~= nil then
        return runningJobs[factionIndex].remainingTime
    end
end
callable(Refinery, "getRemainingJobDuration")

function Refinery.calculateYields(ores, scraps, riftOres)
    local yields = {}

    for i = 1, NumMaterials() do
        yields[i] = (ores[i] or 0) + (scraps[i] or 0) + (riftOres[i] or 0) * 4
    end

    return yields
end

function Refinery.removeGoodsToRefine(craft, oreInput, scrapInput, riftOreInput)
    local ores = {}
    local riftOres = {}
    local scraps = {}

    for i = 1, NumMaterials() do
        ores[i] = 0
        scraps[i] = 0
        riftOres[i] = 0
    end

    local cargos = craft:getCargos()
    for good, amount in pairs(cargos) do
        if good.stolen then goto continue end

        local tags = good.tags

        local material = nil
        if tags.ore or tags.scrap then
            for i = 1, NumMaterials() do
                local m = Material(i-1)
                if tags[m.tag] then
                    material = m
                    break
                end
            end
        end

        if not material then goto continue end
        local i = material.value + 1

        if tags.rich and tags.ore then
            riftOres[i] = math.min(riftOreInput[i] or 0, amount)
            craft:removeCargo(good, riftOres[i])
        elseif tags.ore then
            ores[i] = math.min(oreInput[i] or 0, amount)
            craft:removeCargo(good, ores[i])
        elseif tags.scrap then
            scraps[i] = math.min(scrapInput[i] or 0, amount)
            craft:removeCargo(good, scraps[i])
        end

        ::continue::
    end

    local empty = true
    for i = 1, NumMaterials() do
        if ores[i] > 0 or scraps[i] > 0 or riftOres[i] > 0 then
            empty = false
            break
        end
    end

    return empty, ores, scraps, riftOres
end

function Refinery.getRefiningTime(oreAmounts, scrapAmounts, riftOreAmounts)
    local time = 0

    local maxProductionCapacity = 600000.0
    local timeFactor = lerp(Refinery.productionCapacity, 0, maxProductionCapacity, 1.0, 0.5)

    for material, amount in pairs(oreAmounts) do
        time = time + amount
    end

    for material, amount in pairs(riftOreAmounts) do
        time = time + amount
    end

    for material, amount in pairs(scrapAmounts) do
        time = time + amount
    end

    if time == 0 then return 0 end

    -- speed percentage from amount of assembly blocks is applied
    time = time * timeFactor

    return math.max(5, round(time / 2000))
end

function Refinery.onBlockPlanChanged(--[[entityId, allBlocks]])
    Refinery.productionCapacity = Plan():getStats().productionCapacity
end

function Refinery.getTaxFactor(stationFactionIndex, customerFaction)
    return getRefineTaxFactor(stationFactionIndex, customerFaction)
end

function Refinery.applyTax(amounts, taxFactor)
    local netYields = {}

    for material, amount in pairs(amounts) do
        local taxAmount = round(amount * taxFactor)
        netYields[material] = amount - taxAmount
    end

    return netYields
end

function Refinery.initUI()
    local res = getResolution()
    local size = vec2(800, 400)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(size))
    window.caption = "Refinery"%_t
    window.showCloseButton = true
    window.moveable = true
    window:center()

    menu:registerWindow(window, "Refine Raw Ores"%_t, 9)

    local vsplit = UIVerticalSplitter(Rect(window.size), 10, 10, 0.6)
    local vsplit2 = UIVerticalSplitter(vsplit.right, 10, 0, 0.5)
    local lLister = UIVerticalLister(vsplit.left, 10, 0)
    local rLister = UIVerticalLister(vsplit2.right, 10, 0)

    local leftHeadline = lLister:nextRect(30)

    local organizer = UIOrganizer(leftHeadline)
    organizer.marginLeft = 10

    local amountLabel = window:createLabel(organizer.inner, "ORES & SCRAP"%_t, 14)
    amountLabel:setLeftAligned()

    local rightHeadline = rLister:nextRect(30)
    local outputLabel = window:createLabel(rightHeadline, "OUTPUT"%_t, 14)
    outputLabel:setCenterAligned()

    for i = 1, NumMaterials() do
        local material = Material(i-1)
        local line = {material = material, ores = {}, scraps = {}, richOres = {}}

        local leftSide = lLister:nextRect(30)
        local rightSide = rLister:nextRect(30)

        local hLister = UIHorizontalLister(leftSide, 10, 0)

        local rect = hLister:nextQuadraticRect()
        line.oreIcon = window:createPicture(rect, "data/textures/icons/rock.png")
        line.oreIcon.isIcon = true
        line.oreIcon.color = material.color
        line.oreTextBox = window:createTextBox(hLister:nextRect(100), "onAmountEntered")
        line.oreTextBox.allowedCharacters = "0123456789"
        line.oreTextBox.text = "0"
        line.oreLabel = window:createLabel(rect, "", 12)
        line.oreLabel:setBottomRightAligned()
        line.oreLabel.outline = true
        hLister:nextRect(0)

        local rect = hLister:nextQuadraticRect()
        line.scrapIcon = window:createPicture(rect, "data/textures/icons/scrap-metal.png")
        line.scrapIcon.isIcon = true
        line.scrapIcon.color = material.color
        line.scrapTextBox = window:createTextBox(hLister:nextRect(100), "onAmountEntered")
        line.scrapTextBox.allowedCharacters = "0123456789"
        line.scrapTextBox.text = "0"
        line.scrapLabel = window:createLabel(rect, "", 12)
        line.scrapLabel:setBottomRightAligned()
        line.scrapLabel.outline = true
        hLister:nextRect(0)

        local rect = hLister:nextQuadraticRect()
        line.riftOreIcon = window:createPicture(rect, "data/textures/icons/rift-rock.png")
        line.riftOreIcon.isIcon = true
        line.riftOreIcon.color = material.color
        line.riftOreTextBox = window:createTextBox(hLister:nextRect(100), "onAmountEntered")
        line.riftOreTextBox.allowedCharacters = "0123456789"
        line.riftOreTextBox.text = "0"
        line.riftOreLabel = window:createLabel(rect, "", 12)
        line.riftOreLabel:setBottomRightAligned()
        line.riftOreLabel.outline = true

        window:createFrame(rightSide)
        line.outputLabel = window:createLabel(Rect(rightSide.lower, rightSide.upper - vec2(6, 0)), "0", 14)
        line.outputLabel:setRightAligned()

        line.show = function(self)
            self.oreIcon:show()
            self.oreTextBox:show()
            self.oreLabel:show()
            self.scrapIcon:show()
            self.scrapTextBox:show()
            self.scrapLabel:show()
            self.riftOreIcon:show()
            self.riftOreTextBox:show()
            self.riftOreLabel:show()
            self.outputLabel:show()
        end

        line.hide = function(self)
            self.oreIcon:hide()
            self.oreTextBox:hide()
            self.oreLabel:hide()
            self.scrapIcon:hide()
            self.scrapTextBox:hide()
            self.scrapLabel:hide()
            self.riftOreIcon:hide()
            self.riftOreTextBox:hide()
            self.riftOreLabel:hide()
            self.outputLabel:hide()
        end

        table.insert(lines, line)
    end

    -- refine button & progress bar
    local hsplit = UIHorizontalSplitter(vsplit2.left, 10, 20, 0.5)
    hsplit.marginTop = 150
    hsplit.marginBottom = 150

    refineButton = window:createButton(hsplit.top, "", "onRefinePressed")
    refineButton.icon = "data/textures/icons/play.png"
    refineButton.tooltip = "Start Refining"%_t

    local progressRect = hsplit.bottom
    window:createFrame(progressRect)
    progressBar = window:createProgressBar(progressRect, ColorRGB(0.25, 0.6, 0.9))
    remainingTimeLabel = window:createLabel(progressRect, "00:00", 14)
    remainingTimeLabel:setCenterAligned()

    -- footer
    local hsplit = UIHorizontalSplitter(Rect(window.size), 10, 10, 0.8)
    hsplit.bottomSize = 35
    local vmsplit = UIVerticalMultiSplitter(hsplit.bottom, 40, 0, 2)

    local taxSplitter = UIVerticalSplitter(vmsplit:partition(0), 10, 0, 0.5)
    taxSplitter:setLeftQuadratic()
    local helpIcon = window:createPicture(taxSplitter.left, "data/textures/icons/help.png")
    helpIcon.isIcon = true
    helpIcon.tooltip = "Refine ores and scrap metals to extract their resources.\nExtracted resources can be collected after processing.\nThe refinery keeps a small percentage depending on your relations."%_t

    local playerFaction = Player().craft.factionIndex
    local stationFaction = Faction()
    local taxFactor = Refinery.getTaxFactor(playerFaction, stationFaction)
    taxLabel = window:createLabel(taxSplitter.right, string.format("Refinery Tax: %.1f%%"%_t, round(taxFactor * 100)), 14)
    taxLabel:setLeftAligned()

    addAllButton = window:createButton(vmsplit:partition(1), "All"%_t, "onAddAllPressed")
    takeButton = window:createButton(vmsplit:partition(2), "Take"%_t, "onTakeAllPressed")

    -- gets activated when the current values are received from the server
    Refinery.setInputAmountsUIEnabled(false)
    Refinery.setTakeResourcesUIEnabled(false)

    uiInitialized = true
    Refinery.updateClientValues()
end

function Refinery.onShowWindow(optionIndex)
    Refinery.updateClientValues()
end

function Refinery.onJobFinished(factionIndex)
    if window and window.visible then
        local craft = Player().craft
        if craft and craft.factionIndex == factionIndex then
            Refinery.updateClientValues()
        end
    end
end

function Refinery.updateRemainingTimeLabel(time, totalTimeIn)
    local time = math.max(0, time)
    totalTime = totalTimeIn

    -- calculate the total time if it isn't set -> preview
    if totalTime == nil then
        local ores = {}
        local scraps = {}
        local riftOres = {}

        for i, line in pairs(lines) do
            ores[i] = tonumber(line.oreTextBox.text) or 0
            scraps[i] = tonumber(line.scrapTextBox.text) or 0
            riftOres[i] = tonumber(line.riftOreTextBox.text) or 0
        end

        totalTime = Refinery.getRefiningTime(ores, scraps, riftOres)
        time = totalTime
    end

    progressBar.progress = 1 - time / totalTime
    timeLeft = math.ceil(time)

    if not remainingTimeLabel then return end

    local timeString = ""

    local minutes = math.floor(timeLeft / 60)
    local seconds = timeLeft - minutes * 60

    if minutes < 10 then timeString = timeString .. "0" end
    timeString = timeString .. minutes

    timeString = timeString .. ":"

    if seconds < 10 then timeString = timeString .. "0" end
    timeString = timeString .. seconds

    remainingTimeLabel.caption = timeString
end

if onClient() then

function Refinery.updateClientValues(job, inputActive, takingActive)
    if job == nil then
        local craft = Player().craft
        if craft then
            for i = 1, NumMaterials() do
                local ore = Refinery.getOre(Material(i-1))
                local scrap = Refinery.getScrap(Material(i-1))
                local riftOre = Refinery.getRiftOre(Material(i-1))

                local line = lines[i]
                line.oreTextBox.text = math.min(tonumber(line.oreTextBox.text) or 0, craft:getCargoAmount(ore))
                line.scrapTextBox.text = math.min(tonumber(line.scrapTextBox.text) or 0, craft:getCargoAmount(scrap))
                line.riftOreTextBox.text = math.min(tonumber(line.riftOreTextBox.text) or 0, craft:getCargoAmount(riftOre))
            end
        end

        -- request data from the server
        invokeServerFunction("updateClientValues", Player().craftIndex)

    else
        if uiInitialized ~= true then
            isInputActive = inputActive
            isTakingActive = takingActive
            return
        end

        -- receive data from the server
        for i, amount in pairs(job.oresToRefine or {}) do
            lines[i].oreTextBox.text = amount
        end
        for i, amount in pairs(job.scrapsToRefine or {}) do
            lines[i].scrapTextBox.text = amount
        end
        for i, amount in pairs(job.riftOresToRefine or {}) do
            lines[i].riftOreTextBox.text = amount
        end
        for i, amount in pairs(job.netYields or {}) do
            lines[i].outputLabel.caption = amount
        end


        Refinery.updateRemainingTimeLabel(job.remainingTime or 0, job.totalTime)

        Refinery.setInputAmountsUIEnabled(inputActive)
        Refinery.setTakeResourcesUIEnabled(takingActive)

        -- update amount of ores on the ship
        Refinery.updateAmountOnShipLabels()

        if job.tax then
            taxLabel.caption = string.format("Refinery Tax: %.1f%%"%_t, round(job.tax * 100))
        else
            local playerFaction = Player().craft.factionIndex
            local stationFaction = Faction()
            local taxFactor = Refinery.getTaxFactor(playerFaction, stationFaction)
            taxLabel.caption = string.format("Refinery Tax: %.1f%%"%_t, round(taxFactor * 100))
        end
    end
end

else

function Refinery.updateClientValues(craftIndex)
    -- send data from server to client
    local faction, craft, player = getInteractingFactionByShip(craftIndex, callingPlayer)
    if not player then return end

    local runningJob = runningJobs[faction.index]
    if runningJob then
        inputActive = false
        takingActive = false
        invokeClientFunction(player, "updateClientValues", runningJob, inputActive, takingActive)
        return
    end

    local finishedJob = finishedJobs[faction.index]
    if finishedJob then
        inputActive = false
        takingActive = true
        invokeClientFunction(player, "updateClientValues", finishedJob, inputActive, takingActive)
        return
    end

    inputActive = true
    takingActive = false
    invokeClientFunction(player, "updateClientValues", {}, inputActive, takingActive)
end
callable(Refinery, "updateClientValues")

end

function Refinery.updateAmountOnShipLabels()
    for i, line in pairs(lines) do
        line.scraps[i] = 0
        line.ores[i] = 0
        line.richOres[i] = 0

        line.riftOreLabel.caption = ""
        line.oreLabel.caption = ""
        line.scrapLabel.caption = ""

        line.riftOreLabel.tooltip = nil
        line.oreLabel.tooltip = nil
        line.scrapLabel.tooltip = nil
    end

    local craft = Player().craft
    for good, amount in pairs(craft:getCargos()) do
        if good.stolen then goto continue end

        local tags = good.tags
        if tags.ore and tags.rich then
            for i, line in pairs(lines) do
                if tags[line.material.tag] then
                    line.riftOreLabel.caption = toReadableNumber(amount, 1)
                    line.riftOreLabel.tooltip = "${amount} ${good}\n\nRich Ore: Yield x4"%_t % {amount = createMonetaryString(amount), good = good:displayName(amount)}
                    line.richOres[i] = amount
                end
            end
        elseif tags.ore then
            for i, line in pairs(lines) do
                if tags[line.material.tag] then
                    line.oreLabel.caption = toReadableNumber(amount, 1)
                    line.oreLabel.tooltip = "${amount} ${good}"%_t % {amount = createMonetaryString(amount), good = good:displayName(amount)}
                    line.ores[i] = amount
                end
            end
        elseif tags.scrap then
            for i, line in pairs(lines) do
                if tags[line.material.tag] then
                    line.scrapLabel.caption = toReadableNumber(amount, 1)
                    line.scrapLabel.tooltip = "${amount} ${good}"%_t % {amount = createMonetaryString(amount), good = good:displayName(amount)}
                    line.scraps[i] = amount
                end
            end
        end

        ::continue::
    end
end

function Refinery.onAmountEntered(box)
    local maximum = 0
    for i, line in pairs(lines) do
        if line.oreTextBox.index == box.index then
            maximum = line.ores[i] or 0
            break
        end
        if line.scrapTextBox.index == box.index then
            maximum = line.scraps[i] or 0
            break
        end
        if line.riftOreTextBox.index == box.index then
            maximum = line.richOres[i] or 0
            break
        end
    end

    local enteredNumber = tonumber(box.text) or 0
    if enteredNumber > maximum then
        box.text = maximum
    end

    Refinery.refreshYieldsAndTime()
end

function Refinery.onRefinePressed(button)
    local oreAmounts = {}
    local scrapAmounts = {}
    local riftOreAmounts = {}

    for i, line in pairs(lines) do
        oreAmounts[i] = tonumber(line.oreTextBox.text) or 0
        scrapAmounts[i] = tonumber(line.scrapTextBox.text) or 0
        riftOreAmounts[i] = tonumber(line.riftOreTextBox.text) or 0
    end

    invokeServerFunction("addJob", Player().craftIndex, oreAmounts, scrapAmounts, riftOreAmounts)
end

function Refinery.refreshYieldsAndTime()
    for i, line in pairs(lines) do
        local total = tonumber(line.oreTextBox.text) or 0
        total = total + (tonumber(line.scrapTextBox.text) or 0)
        total = total + (tonumber(line.riftOreTextBox.text) or 0) * 4

        local playerFaction = Player().craft.factionIndex
        local stationFaction = Faction()
        local taxFactor = Refinery.getTaxFactor(playerFaction, stationFaction)

        local tax = round(total * taxFactor)
        total = total - tax

        line.outputLabel.caption = createMonetaryString(total)
    end

    Refinery.updateRemainingTimeLabel(0, nil)
end

function Refinery.onAddAllPressed()
    Refinery.updateAmountOnShipLabels()

    local craft = Player().craft
    for good, amount in pairs(craft:getCargos()) do
        if good.stolen then goto continue end

        local tags = good.tags
        if tags.ore and tags.rich then
            for i, line in pairs(lines) do
                if tags[line.material.tag] then
                    line.riftOreTextBox.text = amount
                end
            end
        elseif tags.ore then
            for i, line in pairs(lines) do
                if tags[line.material.tag] then
                    line.oreTextBox.text = amount
                end
            end
        elseif tags.scrap then
            for i, line in pairs(lines) do
                if tags[line.material.tag] then
                    line.scrapTextBox.text = amount
                end
            end
        end

        ::continue::
    end

    Refinery.refreshYieldsAndTime()
end

function Refinery.onTakeAllPressed(craftIndex)
    if onClient() then
        invokeServerFunction("onTakeAllPressed", Player().craftIndex)

        for _, line in pairs(lines) do
            line.oreTextBox.text = 0
            line.scrapTextBox.text = 0
            line.riftOreTextBox.text = 0
            line.outputLabel.caption = 0
        end

        return
    end

    local faction, craft, player = getInteractingFactionByShip(craftIndex, callingPlayer, AlliancePrivilege.AddResources)
    if not faction then return end

    local finished = finishedJobs[faction.index]
    if finished == nil then
        if player then
            player:sendChatMessage(Entity(), ChatMessageType.Error, "There is nothing to take."%_t)
        end

        return
    end

    local materials = {}

    for i = 1, NumMaterials() do
        local amount = finished.netYields[i] or 0

        materials[i] = amount

        if amount > 0 then
            faction:receiveResource(Format("Received %1% %2% from refinery."%_t, amount, Material(i - 1).name), Material(i - 1), amount)
        end
    end

    local senderInfo = makeCallbackSenderInfo(Entity())
    if player then
        player:sendCallback("onRefineryResourcesTaken", senderInfo, craft.id, materials)
    end
    if player ~= faction then
        faction:sendCallback("onRefineryResourcesTaken", senderInfo, craft.id, materials)
    end
    craft:sendCallback("onRefineryResourcesTaken", senderInfo, materials)
    Entity():sendCallback("onRefineryResourcesTaken", senderInfo, craft.id, faction.index, materials)

    finishedJobs[faction.index] = nil

    Refinery.updateClientValues(craftIndex)
end
callable(Refinery, "onTakeAllPressed")

function Refinery.setInputAmountsUIEnabled(bool)
    addAllButton.active = bool
    refineButton.active = bool

    for _, line in pairs(lines) do
        line.oreTextBox.editable = bool
        line.scrapTextBox.editable = bool
        line.riftOreTextBox.editable = bool
    end
end

function Refinery.setTakeResourcesUIEnabled(bool)
    takeButton.active = bool

    for _, line in pairs(lines) do
        line.outputLabel.active = bool
    end
end

function Refinery.getOre(material)
    if material.value == 0 then return goods["Iron Ore"]:good()
    elseif material.value == 1 then return goods["Titanium Ore"]:good()
    elseif material.value == 2 then return goods["Naonite Ore"]:good()
    elseif material.value == 3 then return goods["Trinium Ore"]:good()
    elseif material.value == 4 then return goods["Xanion Ore"]:good()
    elseif material.value == 5 then return goods["Ogonite Ore"]:good()
    else return goods["Avorion Ore"]:good()
    end
end

function Refinery.getScrap(material)
    if material.value == 0 then return goods["Scrap Iron"]:good()
    elseif material.value == 1 then return goods["Scrap Titanium"]:good()
    elseif material.value == 2 then return goods["Scrap Naonite"]:good()
    elseif material.value == 3 then return goods["Scrap Trinium"]:good()
    elseif material.value == 4 then return goods["Scrap Xanion"]:good()
    elseif material.value == 5 then return goods["Scrap Ogonite"]:good()
    else return goods["Scrap Avorion"]:good()
    end
end

function Refinery.getRiftOre(material)
    if material.value == 0 then return goods["Rift Iron Ore"]:good()
    elseif material.value == 1 then return goods["Rift Titanium Ore"]:good()
    elseif material.value == 2 then return goods["Rift Naonite Ore"]:good()
    elseif material.value == 3 then return goods["Rift Trinium Ore"]:good()
    elseif material.value == 4 then return goods["Rift Xanion Ore"]:good()
    elseif material.value == 5 then return goods["Rift Ogonite Ore"]:good()
    else return goods["Rift Avorion Ore"]:good()
    end
end
