
package.path = package.path .. ";data/scripts/entity/merchants/?.lua;"
package.path = package.path .. ";data/scripts/lib/?.lua;"

include ("galaxy")
include ("utility")
include ("faction")
include ("player")
include ("randomext")
include ("stringutility")
include ("callable")
local SellableInventoryItem = include ("sellableinventoryitem")
local SectorTurretGenerator = include ("sectorturretgenerator")
local Dialog = include("dialogutility")
include("weapontypeutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace ResearchStation
ResearchStation = {}

local AutoResearchMode =
{
    OnlySameTurretsAndSubsystems = 1,
    OnlySameTurrets = 2,
    OnlySameBlueprints = 3,
    OnlySameSubsystems = 4,
    AnyTurrets = 5,
    AnyBlueprints = 6,
    AnySubsystems = 7,
    AnyCombination = 8,
}

local researchButton
local openAutoResearchButton
local autoResearchUI = {}
local numCompletedAutoResearchIterations = 0
local activeAutoResearchMode = nil

ResearchStation.interactionThreshold = -30000
ResearchStation.autoResearchEnabled = false

function ResearchStation.initialize()
    if onClient() and EntityIcon().icon == "" then
        EntityIcon().icon = "data/textures/icons/pixel/research.png"
        InteractionText().text = Dialog.generateStationInteractionText(Entity(), random())
    end
end

function ResearchStation.interactionPossible(playerIndex, option)
    return CheckFactionInteraction(playerIndex, ResearchStation.interactionThreshold)
end

function ResearchStation.initUI()

    local res = getResolution()
    local size = vec2(800, 600)

    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))

    window.caption = "Research /* station title */"%_t
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "Research"%_t, 10);

    local hsplit = UIHorizontalSplitter(Rect(window.size), 10, 10, 0.4)

    -- lower half of window

    inventory = window:createInventorySelection(hsplit.bottom, 11)
    inventory:setShowScrollArrows(true, true, 1.0)

    inventory.dragFromEnabled = 1
    inventory.onClickedFunction = "onInventoryClicked"
    inventory:setAdditionalHints("[RMB] Select Item"%_t)

    local vsplit = UIVerticalSplitter(hsplit.top, 10, 10, 0.4)

    -- upper half of window

    local hlistPadding = 10
    local hlistInStartOut = UIHorizontalLister(hsplit.top, hlistPadding, 0)
    local buttonSize = 50
    local remainingWidth = hlistInStartOut.inner.width - buttonSize - 2 * hlistPadding
    local inColumnWidth = remainingWidth * 0.6
    local outColumnWidth = remainingWidth - inColumnWidth

    -- upper half: left column (input)

    local hsplitleft = UIHorizontalSplitter(hlistInStartOut:nextRect(inColumnWidth), 10, 10, 0.5)

    hsplitleft.padding = 6
    local rect = hsplitleft.top
    rect.width = 220
    required = window:createSelection(rect, 3)

    local rect = hsplitleft.bottom
    rect.width = 150
    optional = window:createSelection(rect, 2)

    for _, sel in pairs({required, optional}) do
        sel.dropIntoEnabled = 1
        sel.entriesSelectable = 0
        sel.onReceivedFunction = "onRequiredReceived"
        sel.onDroppedFunction = "onRequiredDropped"
        sel.onClickedFunction = "onRequiredClicked"
    end

    -- upper half: middle column (buttons)

    local hsplitStartButtons = UIHorizontalSplitter(hlistInStartOut:nextRect(buttonColumnWidth), 10, 50, 0.5)

    local rect = hsplitStartButtons.top
    rect.size = vec2(buttonSize, buttonSize)
    researchButton = window:createButton(rect, "", "onClickResearch")
    researchButton.tooltip = "Research"%_t
    researchButton.icon = "data/textures/icons/play.png"

    local rect = hsplitStartButtons.bottom
    rect.size = vec2(40)
    openAutoResearchButton = window:createButton(rect, "", "onOpenAutoResearchClicked")

    -- upper half: right column (output)

    local rect = hlistInStartOut:nextRect(outColumnWidth)
    rect.size = vec2(70, 70)
    results = window:createSelection(rect, 1)
    results.entriesSelectable = 0
    results.dropIntoEnabled = 0
    results.dragFromEnabled = 0

    -- auto research window

    local window = menu:createWindow(Rect(vec2(250, 110)))
    window.transparency = 0.1
    autoResearchUI.window = window
    window:center()
    window:hide()

    window.showCloseButton = true
    window.closeableWithEscape = true
    window.moveable = true
    window.caption = "Auto Research"%_t

    local vlist = UIVerticalLister(Rect(window.size), 10, 10)

    local combo = window:createValueComboBox(vlist:nextRect(25), "")
    autoResearchUI.modeComboBox = combo
    combo:addEntry(AutoResearchMode.OnlySameTurretsAndSubsystems, "Same Item Types"%_t)
    combo:addEntry(AutoResearchMode.OnlySameTurrets, "Same Turrets"%_t)
    combo:addEntry(AutoResearchMode.OnlySameBlueprints, "Same Turret-Blueprints"%_t)
    combo:addEntry(AutoResearchMode.OnlySameSubsystems, "Same Subsystems"%_t)
    combo:addEntry(AutoResearchMode.AnyTurrets, "Any Turrets"%_t)
    combo:addEntry(AutoResearchMode.AnyBlueprints, "Any Turret-Blueprints"%_t)
    combo:addEntry(AutoResearchMode.AnySubsystems, "Any Subsystems"%_t)
    combo:addEntry(AutoResearchMode.AnyCombination, "Any Combination"%_t)

    local rect = vlist:nextRect(50)
    rect.width = rect.height

    local startAutoResearchButton = window:createButton(rect, "", "onAutoResearchUIStartClicked")
    startAutoResearchButton.icon = "data/textures/icons/auto-research-start.png"
    startAutoResearchButton.tooltip = "Auto-Research Trash Items"%_t

    -- initialize state

    ResearchStation.setAutoResearchEnabled(false)
end

function ResearchStation.onOpenAutoResearchClicked()
    if activeAutoResearchMode then
        ResearchStation.setAutoResearchEnabled(false)
        return
    end

    autoResearchUI.window:show()
end

function ResearchStation.getUpdateInterval()
    return 30
end

function ResearchStation.updateServer(timeStep)

    ResearchStation.newsBroadcastInterval = 250
    ResearchStation.newsBroadcastCounter = (ResearchStation.newsBroadcastCounter or ResearchStation.newsBroadcastInterval - 20) + timeStep

    if ResearchStation.newsBroadcastCounter >= ResearchStation.newsBroadcastInterval then
        local texts =
        {
            "Completely random AI-supported research, it's basically a gamble!"%_t,
            "Feed objects to the research AI and see what crazy things it creates from them!"%_t,
            "Our research AI eats up objects and creates new ones based on the old ones - often better, sometimes worse!"%_t,
        }

        Sector():broadcastChatMessage(Entity(), ChatMessageType.Chatter, randomEntry(texts))
        ResearchStation.newsBroadcastCounter = 0
    end
end

function ResearchStation.initializationFinished()
    -- use the initilizationFinished() function on the client since in initialize() we may not be able to access Sector scripts on the client
    if onClient() then
        local lines = {
            "We remind all researchers to turn on the ventilation after finishing experiments."%_t,
            "Research for everyone."%_t,
            "Good news everyone!"%_t,
            "We will destroy everything you have if you want us to."%_t,
            "Get rid of your superfluous items and build new ones!"%_t,
            "Our researchers will offer you all capacities they have. They're being paid for that."%_t,
            "Make the best of your old things!"%_t,
            "Doing what we must because we can."%_t,
            "Completely random AI-supported research, it's basically a gamble!"%_t,
            "Feed objects to the research AI and see what crazy things it creates from them!"%_t,
            "Our research AI eats up objects and creates new ones - Often better, sometimes worse!"%_t,
        }

        if getLanguage() == "en" then
            -- these don't have translation markers on purpose
            table.insert(lines, "Don't you DARE hit that red button!")
        end

        local ok, r = Sector():invokeFunction("radiochatter", "addSpecificLines", Entity().id.string, lines)
    end
end

function ResearchStation.removeItemFromMainSelection(key)
    local item = inventory:getItem(key)
    if not item then return end

    if item.amount then
        item.amount = item.amount - 1
        if item.amount == 0 then item.amount = nil end
    end

    inventory:remove(key)

    if item.amount then
        inventory:add(item, key)
    end

end

function ResearchStation.addItemToMainSelection(item)
    if not item then return end
    if not item.item then return end

    if item.item.stackable then
        -- find the item and increase the amount
        for k, v in pairs(inventory:getItems()) do
            if v.item and v.item == item.item then
                v.amount = v.amount + 1

                inventory:remove(k)
                inventory:add(v, k)
                return
            end
        end

        item.amount = 1
    end

    -- when not found or not stackable, add it
    inventory:add(item)

end

function ResearchStation.moveItem(item, from, to, fkey, tkey)
    if not item then return end

    if from.index == inventory.index then -- move from inventory to a selection
        if item.favorite then return end

        -- first, move the item that might be in place back to the inventory
        if tkey then
            ResearchStation.addItemToMainSelection(to:getItem(tkey))
            to:remove(tkey)
        end

        ResearchStation.removeItemFromMainSelection(fkey)

        -- fix item amount, we don't want numbers in the upper selections
        item.amount = nil
        to:add(item, tkey)

    elseif to.index == inventory.index then
        -- move from selection to inventory
        ResearchStation.addItemToMainSelection(item)
        from:remove(fkey)
    end
end

function ResearchStation.onRequiredReceived(selectionIndex, fkx, fky, item, fromIndex, toIndex, tkx, tky)
    if not item then return end

    -- don't allow dragging from/into the left hand selections
    if fromIndex == optional.index or fromIndex == required.index then
        return
    end

    ResearchStation.moveItem(item, inventory, Selection(selectionIndex), ivec2(fkx, fky), ivec2(tkx, tky))

    ResearchStation.refreshButton()
    results:clear()
    results:addEmpty()
end

function ResearchStation.onRequiredClicked(selectionIndex, fkx, fky, item, button)
    if button == 3 or button == 2 then
        ResearchStation.moveItem(item, Selection(selectionIndex), inventory, ivec2(fkx, fky), nil)
        ResearchStation.refreshButton()
    end
end

function ResearchStation.onRequiredDropped(selectionIndex, kx, ky)
    local selection = Selection(selectionIndex)
    local key = ivec2(kx, ky)
    ResearchStation.moveItem(selection:getItem(key), Selection(selectionIndex), inventory, key, nil)
    ResearchStation.refreshButton()
end

function ResearchStation.onInventoryClicked(selectionIndex, kx, ky, item, button)

    if button == 2 or button == 3 then
        -- fill required first, then, once it's full, fill optional
        local items = required:getItems()
        if tablelength(items) < 3 then
            ResearchStation.moveItem(item, inventory, required, ivec2(kx, ky), nil)

            ResearchStation.refreshButton()
            results:clear()
            results:addEmpty()
            return
        end

        local items = optional:getItems()
        if tablelength(items) < 2 then
            ResearchStation.moveItem(item, inventory, optional, ivec2(kx, ky), nil)

            ResearchStation.refreshButton()
            results:clear()
            results:addEmpty()
            return
        end
    end
end

function ResearchStation.refreshButton()
    local requiredItems = required:getItems()
    researchButton.active = (tablelength(requiredItems) == 3)

    if tablelength(requiredItems) ~= 3 then
        researchButton.tooltip = "Place at least 3 items for research!"%_t
    else
        researchButton.tooltip = "Feed to Research AI"%_t
    end

    for _, items in pairs({requiredItems, optional:getItems()}) do
        for _, item in pairs(items) do
            if item.item
                and item.item.itemType ~= InventoryItemType.TurretTemplate
                and item.item.itemType ~= InventoryItemType.SystemUpgrade
                and item.item.itemType ~= InventoryItemType.Turret then

                researchButton.active = false
                researchButton.tooltip = "Invalid items in ingredients."%_t
            end
        end
    end

end

function ResearchStation.onCloseWindow()
    ResearchStation.setAutoResearchEnabled(false)
end

function ResearchStation.onShowWindow()
    required:clear()
    optional:clear()

    required:addEmpty()
    required:addEmpty()
    required:addEmpty()

    optional:addEmpty()
    optional:addEmpty()

    if results.numEntries == 0 then
        results:addEmpty()
    end

    ResearchStation.refreshButton()

    for i = 1, 50 do
        inventory:addEmpty()
    end

    local player = Player()
    local ship = player.craft
    local alliance = player.alliance

    if alliance and ship.factionIndex == player.allianceIndex then
        inventory:fill(alliance.index)
    else
        inventory:fill(player.index)
    end

end

function ResearchStation.checkRarities(items) -- items must not be more than 1 rarity apart
    local min = math.huge
    local max = -math.huge

    for _, item in pairs(items) do
        if item.rarity.value < min then min = item.rarity.value end
        if item.rarity.value > max then max = item.rarity.value end
    end

    if max - min <= 1 then
        return true
    end

    return false
end

function ResearchStation.getRarityProbabilities(items)

    local probabilities = {}

    -- for each item there is a 20% chance that the researched item has a rarity 1 better
    for _, item in pairs(items) do
        -- next rarity cannot exceed legendary
        local nextRarity = math.min(RarityType.Legendary, item.rarity.value + 1)

        local p = probabilities[nextRarity] or 0
        p = p + 0.2
        probabilities[nextRarity] = p
    end

    -- if the amount of items is < 5 then add their own rarities as a result as well
    if #items < 5 then
        local left = (1.0 - #items * 0.2)
        local perItem = left / #items

        for _, item in pairs(items) do
            local p = probabilities[item.rarity.value] or 0
            p = p + perItem
            probabilities[item.rarity.value] = p
        end
    end

    local sum = 0
    for _, p in pairs(probabilities) do
        sum = sum + p
    end

    return probabilities
end

function ResearchStation.getTypeProbabilities(items)
    local probabilities = {}

    for _, item in pairs(items) do
        local p = probabilities[item.itemType] or 0
        p = p + 1
        probabilities[item.itemType] = p
    end

    return probabilities
end

function ResearchStation.getWeaponProbabilities(items)
    local probabilities = {}
    local typesByIcons = getWeaponTypesByIcon()

    for _, item in pairs(items) do
        if item.itemType == InventoryItemType.Turret
            or item.itemType == InventoryItemType.TurretTemplate then

            local weaponType = WeaponTypes.getTypeOfItem(item)

            local p = probabilities[weaponType] or 0
            p = p + 1
            probabilities[weaponType] = p
        end
    end

    return probabilities
end

function ResearchStation.getWeaponMaterials(items)
    local probabilities = {}

    for _, item in pairs(items) do
        if item.itemType == InventoryItemType.Turret
            or item.itemType == InventoryItemType.TurretTemplate then

            local p = probabilities[item.material.value] or 0
            p = p + 1
            probabilities[item.material.value] = p
        end
    end

    return probabilities
end

function ResearchStation.getWeaponTech(items)
    local sum = 0
    local samples = 0

    for _, item in pairs(items) do
        if item.itemType == InventoryItemType.Turret
                or item.itemType == InventoryItemType.TurretTemplate then
            sum = sum + item.averageTech
            samples = samples + 1
        end
    end

    return math.ceil(sum / samples)
end

function ResearchStation.getSystemProbabilities(items)
    local probabilities = {}

    for _, item in pairs(items) do
        if item.itemType == InventoryItemType.SystemUpgrade then
            local p = probabilities[item.script] or 0
            p = p + 1
            probabilities[item.script] = p
        end
    end

    return probabilities
end


function ResearchStation.setAutoResearchEnabled(value)
    ResearchStation.autoResearchEnabled = value
    if value then
        openAutoResearchButton.icon = "data/textures/icons/auto-research-stop.png"
        openAutoResearchButton.tooltip = "Stop Auto-Research"%_t
        autoResearchUI.modeComboBox.active = false
        numCompletedAutoResearchIterations = 0
    else
        openAutoResearchButton.icon = "data/textures/icons/auto-research-start.png"
        openAutoResearchButton.tooltip = "Auto-Research Trash Items"%_t
        autoResearchUI.modeComboBox.active = true
        activeAutoResearchMode = nil
    end
end


function ResearchStation.onAutoResearchUIStartClicked()
    if activeAutoResearchMode then
        print("Auto Research is already active.")
        return
    end

    activeAutoResearchMode = autoResearchUI.modeComboBox.selectedValue
    ResearchStation.setAutoResearchEnabled(true)
    autoResearchUI.window:hide()

    ResearchStation.autoInputItems()
end

function ResearchStation.autoInputItems()
    optional:clear()
    optional:addEmpty()
    optional:addEmpty()
    required:clear()
    required:addEmpty()
    required:addEmpty()
    required:addEmpty()

    if not ResearchStation.autoResearchEnabled then return end

    local craft = Player().craft
    if not craft or not Entity():isInDockingArea(craft) then
        displayChatMessage("You must be docked to the station to research items."%_T, "", ChatMessageType.Error)
        ResearchStation.setAutoResearchEnabled(false)
        return
    end

    local itemGroup = ResearchStation.findAutoResearchGroup()
    if itemGroup then
        for _, itemInfo in ipairs(itemGroup) do
            ResearchStation.onInventoryClicked(inventory.index, itemInfo.x, itemInfo.y, itemInfo.slot, 2)
        end

        deferredCallback(0.05, "autoResearch")
    else
        if numCompletedAutoResearchIterations == 0 then
            displayChatMessage("Not enough trash items available for current auto research mode."%_t, "", ChatMessageType.Error)
        end

        ResearchStation.setAutoResearchEnabled(false)
    end
end

function ResearchStation.findAutoResearchGroup()
    local slots = inventory:getItems()
    local rarityOrder = {
        RarityType.Petty,
        RarityType.Common,
        RarityType.Uncommon,
        RarityType.Rare,
        RarityType.Exceptional,
        RarityType.Exotic,
        RarityType.Legendary
    }

    for _, lowerRarity in pairs(rarityOrder) do
        local possibleCombinations = {}

        -- we must not combine items more than one rarity apart
        for rarity = lowerRarity, lowerRarity + 1 do
            for key, slot in pairs(slots) do
                if slot.trash and slot.item.rarity.type == rarity then
                    local groupName = ResearchStation.getItemAutoResearchGroup(slot.item, activeAutoResearchMode)
                    if not groupName then goto continue end

                    if possibleCombinations[groupName] == nil then
                        possibleCombinations[groupName] = {}
                    end

                    for i = 1, (slot.amount or 1) do
                        table.insert(possibleCombinations[groupName],
                                {x = key.x, y = key.y, slot = slot})

                        if #possibleCombinations[groupName] >= 3 then
                            return possibleCombinations[groupName]
                        end
                    end
                end

                ::continue::
            end
        end
    end
end

function ResearchStation.getItemAutoResearchGroup(item, autoResearchMode)
    local itemType = item.itemType

    if itemType == InventoryItemType.SystemUpgrade then
        if autoResearchMode == AutoResearchMode.OnlySameTurretsAndSubsystems then
            return "Subsys#" .. item.script
        elseif autoResearchMode == AutoResearchMode.OnlySameTurrets then
            return nil
        elseif autoResearchMode == AutoResearchMode.OnlySameSubsystems then
            return "Subsys#" .. item.script
        elseif autoResearchMode == AutoResearchMode.OnlySameBlueprints then
            return nil
        elseif autoResearchMode == AutoResearchMode.AnyTurrets then
            return nil
        elseif autoResearchMode == AutoResearchMode.AnySubsystems then
            return "default"
        elseif autoResearchMode == AutoResearchMode.AnyBlueprints then
            return nil
        elseif autoResearchMode == AutoResearchMode.AnyCombination then
            return "default"
        end

    elseif itemType == InventoryItemType.TurretTemplate then
        if autoResearchMode == AutoResearchMode.OnlySameTurretsAndSubsystems then
            return "Blueprint#" .. item.weaponName
        elseif autoResearchMode == AutoResearchMode.OnlySameTurrets then
            return nil
        elseif autoResearchMode == AutoResearchMode.OnlySameSubsystems then
            return nil
        elseif autoResearchMode == AutoResearchMode.OnlySameBlueprints then
            return "Blueprint#" .. item.weaponName
        elseif autoResearchMode == AutoResearchMode.AnyTurrets then
            return nil
        elseif autoResearchMode == AutoResearchMode.AnySubsystems then
            return nil
        elseif autoResearchMode == AutoResearchMode.AnyBlueprints then
            return "default"
        elseif autoResearchMode == AutoResearchMode.AnyCombination then
            return "default"
        end

    elseif itemType == InventoryItemType.Turret then
        if autoResearchMode == AutoResearchMode.OnlySameTurretsAndSubsystems then
            return "Turret#" .. item.weaponName
        elseif autoResearchMode == AutoResearchMode.OnlySameTurrets then
            return "Turret#" .. item.weaponName
        elseif autoResearchMode == AutoResearchMode.OnlySameSubsystems then
            return nil
        elseif autoResearchMode == AutoResearchMode.OnlySameBlueprints then
            return nil
        elseif autoResearchMode == AutoResearchMode.AnyTurrets then
            return "default"
        elseif autoResearchMode == AutoResearchMode.AnySubsystems then
            return nil
        elseif autoResearchMode == AutoResearchMode.AnyBlueprints then
            return nil
        elseif autoResearchMode == AutoResearchMode.AnyCombination then
            return "default"
        end
    end

    -- ignore all other item types
end

function ResearchStation.autoResearch()
    if not ResearchStation.autoResearchEnabled then return end

    -- we assume that ResearchStation.autoInputItems() has setup valid preconditions
    ResearchStation.onClickResearch()
    numCompletedAutoResearchIterations = numCompletedAutoResearchIterations + 1

    deferredCallback(0.15, "autoInputItems")
end

function ResearchStation.onClickResearch()

    local items = {}
    local itemIndices = {}

    for _, item in pairs(required:getItems()) do
        if item.item then
            table.insert(items, item.item)

            local amount = itemIndices[item.index] or 0
            amount = amount + 1
            itemIndices[item.index] = amount
        end
    end
    for _, item in pairs(optional:getItems()) do
        if item.item then
            table.insert(items, item.item)

            local amount = itemIndices[item.index] or 0
            amount = amount + 1
            itemIndices[item.index] = amount
        end
    end

    local items = 0
    for idx, num in pairs(itemIndices) do
        items = items + num
    end

    if items >= 3 then
        invokeServerFunction("research", itemIndices)
    end
end

function ResearchStation.research(itemIndices)
    if not itemIndices then return end

    if not CheckFactionInteraction(callingPlayer, ResearchStation.interactionThreshold) then return end

    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources)
    if not buyer then return end

    -- check if the player has enough of the items
    local items = {}

    for index, amount in pairs(itemIndices) do
        local item = buyer:getInventory():find(index)
        local has = buyer:getInventory():amount(index)

        if not item or has < amount then
            player:sendChatMessage(Entity(), 1, "You don't have enough items!"%_t)
            return
        end

        for i = 1, amount do
            table.insert(items, item)
        end
    end

    if #items < 3 then
        player:sendChatMessage(Entity(), 1, "You need at least 3 items to do research!"%_t)
        return
    end

    local station = Entity()

    local errors = {}
    errors[EntityType.Station] = "You must be docked to the station to research items."%_T
    errors[EntityType.Ship] = "You must be closer to the ship to research items."%_T
    if not CheckPlayerDocked(player, station, errors) then
        return
    end

    local result = ResearchStation.transform(items)

    if result then
        for index, amount in pairs(itemIndices) do
            for i = 1, amount do
                buyer:getInventory():take(index)
            end
        end

        local inventory = buyer:getInventory()
        if not inventory:hasSlot(result) then
            buyer:sendChatMessage(station, ChatMessageType.Warning, "Your inventory is full (%1%/%2%). Your researched item was dropped."%_T, inventory.occupiedSlots, inventory.maxSlots)
        end

        inventory:addOrDrop(result)

        invokeClientFunction(player, "receiveResult", result)

        local senderInfo = makeCallbackSenderInfo(station)
        player:sendCallback("onItemResearched", senderInfo, ship.id, result)
        if buyer ~= player then
            buyer:sendCallback("onItemResearched", senderInfo, ship.id, result)
        end
        ship:sendCallback("onItemResearched", senderInfo, result)
        station:sendCallback("onItemResearched", senderInfo, ship.id, buyer.index, result)

    else
        buyer:sendChatMessage(station, ChatMessageType.Error, "Incapable of transforming these items."%_T)
    end
end
callable(ResearchStation, "research")

function ResearchStation.researchTest(...)
    local indices = {}

    for _, index in pairs({...}) do
        local amount = indices[index] or 0
        indices[index] = amount + 1
    end

    ResearchStation.research(indices)
end

function ResearchStation.receiveResult(result)
    results:clear()

    local item = InventorySelectionItem()
    item.item = result

    results:add(item)
    ResearchStation.onShowWindow()

    if item.item.itemType == InventoryItemType.Turret
            or item.item.itemType == InventoryItemType.TurretTemplate then
        playSound("interface/collect-turret", SoundType.UI, 0.2)
    elseif item.item.itemType == InventoryItemType.SystemUpgrade then
        playSound("interface/collect-upgrade", SoundType.UI, 0.2)
    end
end



function ResearchStation.cancelWithTooManyKeys(items)
    local keys = 0
    for _, item in pairs(items) do
        if item.itemType == InventoryItemType.SystemUpgrade and string.match(item.script, "systems/teleporterkey") then
            keys = keys + 1
        end
    end

    return keys >= 2
end

function ResearchStation.transformPatterns(items)
    -- key 2 upgrade
    local legendaryUpgrades = 0
    for _, item in pairs(items) do
        if item.itemType == InventoryItemType.SystemUpgrade and item.rarity.value == RarityType.Legendary then
            legendaryUpgrades = legendaryUpgrades + 1
        end
    end

    if legendaryUpgrades >= 3 then
        return SystemUpgradeTemplate("data/scripts/systems/teleporterkey2.lua", Rarity(RarityType.Legendary), Seed(1))
    end

    -- boss
    local exotics = 0
    local hackingUpgrades = 0
    local weaponTypes = ResearchStation.getWeaponProbabilities(items)

    for _, item in pairs(items) do
        if item.itemType == InventoryItemType.SystemUpgrade and string.match(item.script, "internal/dlc/blackmarket/systems/hackingupgrade.lua") then
            hackingUpgrades = hackingUpgrades + 1
        end

        if item.rarity.value >= RarityType.Exotic then
            exotics = exotics + 1
        end
    end

    if (weaponTypes[WeaponType.PointDefenseChainGun] or 0) > 0
            and (weaponTypes[WeaponType.Laser] or 0) > 0
            and (weaponTypes[WeaponType.LightningGun] or 0) > 0
            and (weaponTypes[WeaponType.RailGun] or 0) > 0
            and exotics > 0
            and hackingUpgrades > 0 then
        return UsableInventoryItem("internal/common/items/staffbosscaller.lua", Rarity(RarityType.Legendary))
    end

end

function ResearchStation.transform(items)

    -- protect players from themselves
    if ResearchStation.cancelWithTooManyKeys(items) then return end

    -- check if there is a predetermined pattern
    local patternResult = ResearchStation.transformPatterns(items)
    if patternResult then
        return patternResult
    end

    if not ResearchStation.checkRarities(items) then
        if callingPlayer then
            local player = Player(callingPlayer)
            player:sendChatMessage(Entity(), 1, "Your items cannot be more than one rarity apart!"%_t)
        end
        return
    end

    local result
    local rarities = ResearchStation.getRarityProbabilities(items)
    local types = ResearchStation.getTypeProbabilities(items, "type")

    local itemType = selectByWeight(random(), types)
    local rarity = Rarity(selectByWeight(random(), rarities))

    if itemType == InventoryItemType.Turret
        or itemType == InventoryItemType.TurretTemplate then

        local weaponTypes = ResearchStation.getWeaponProbabilities(items)
        local materials = ResearchStation.getWeaponMaterials(items)
        local weaponTech = ResearchStation.getWeaponTech(items)

        local weaponType = selectByWeight(random(), weaponTypes)
        local material = Material(selectByWeight(random(), materials))

        local x, y = Sector():getCoordinates()
        local selfTech = Balancing_GetTechLevel(x, y)

        local tech = math.min(selfTech, weaponTech + 10)

        if itemType == InventoryItemType.TurretTemplate then
            -- turret blueprints with tech > 50 can't be used by players
            tech = math.min(tech, 50)
        else
            tech = math.min(tech, 52)
        end

        local x, y = Balancing_GetSectorByTechLevel(tech)

        local generator = SectorTurretGenerator()
        generator.maxVariations = 10
        result = generator:generate(x, y, -5, rarity, weaponType, material)

        if itemType == InventoryItemType.Turret then
            result = InventoryTurret(result)
        end

    elseif itemType == InventoryItemType.SystemUpgrade then
        local scripts = ResearchStation.getSystemProbabilities(items)

        local script = selectByWeight(random(), scripts)

        result = SystemUpgradeTemplate(script, rarity, random():createSeed())
    end

    return result
end
