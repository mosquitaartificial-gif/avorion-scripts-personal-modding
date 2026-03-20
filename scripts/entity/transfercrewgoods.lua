package.path = package.path .. ";data/scripts/lib/?.lua"

local CaptainUtility = include("captainutility")
include("utility")
include("stringutility")
include("tooltipmaker")
include("callable")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace TransferCrewGoods
TransferCrewGoods = {}

-- crew
local playerTotalCrewBar = nil
local selfTotalCrewBar = nil

local playerCrewIcons = {}
local playerCrewBars = {}
local playerCrewButtons = {}
local playerCrewTextBoxes = {}
local selfCrewIcons = {}
local selfCrewBars = {}
local selfCrewButtons = {}
local selfCrewTextBoxes = {}

local crewmenByButton = {}
local crewmenByTextBox = {}

local playerCrewTextBoxByIndex = {}
local selfCrewTextBoxByIndex = {}

local playerTransferAllCrewButton = {}
local selfTransferAllCrewButton = {}

local playerCaptainUI = {}
local selfCaptainUI = {}

local playerPassengerSelection = nil
local selfPassengerSelection = nil

-- cargo
local playerTotalCargoBar = nil
local selfTotalCargoBar = nil

local playerCargoIcons = {}
local playerCargoBars = {}
local playerCargoButtons = {}
local playerCargoTextBoxes = {}
local selfCargoIcons = {}
local selfCargoBars = {}
local selfCargoButtons = {}
local selfCargoTextBoxes = {}

local playerCargoName = {}
local playerCargoTextBoxByIndex = {}
local selfCargoName = {}
local selfCargoTextBoxByIndex = {}

local playerTransferAllCargoButton = {}
local selfTransferAllCargoButton = {}

-- fighters
local playerFighterLabels = {}
local selfFighterLabels = {}
local playerFighterSelections = {}
local selfFighterSelections = {}
local isPlayerShipBySelection = {}
local squadIndexBySelection = {}

local playerTransferAllFightersButton = {}
local selfTransferAllFightersButton = {}

local cargosByButton = {}
local cargosByTextBox = {}

-- torpedoes
local playerTorpedoShafts = {}
local selfTorpedoShafts = {}

local playerTorpedoStorage
local selfTorpedoStorage

local torpedoShaftIndexBySelection = {}

-- misc
local textboxIndexByButton = {}

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function TransferCrewGoods.interactionPossible(playerIndex, option)

    local player = Player()
    local ship = Entity()
    local other = player.craft
    if not other then return false end

    if ship.index == other.index then
        return false
    end

    -- interaction with fighters does not work
    if ship.isFighter or other.isFighter then
        return false
    end

    -- interaction with drones does not work
    if ship.isDrone or other.isDrone then
        return false
    end

    local shipFaction = Faction()
    if not shipFaction then return false end

    if shipFaction.isPlayer then
        if shipFaction.index ~= playerIndex then
            return false
        end
    elseif shipFaction.isAlliance then
        if player.allianceIndex ~= shipFaction.index then
            return false
        end
    else
        return false
    end

    return true, ""
end

--function initialize()
--
--end

-- create all required UI elements for the client side
function TransferCrewGoods.initUI()

    local res = getResolution()
    local size = vec2(850, 635)

    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5));
    menu:registerWindow(window, "Transfer Crew/Cargo/Fighters"%_t);

    window.caption = "Transfer Crew, Cargo and Fighters"%_t
    window.showCloseButton = 1
    window.moveable = 1

    local tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 10), size - 10))

    TransferCrewGoods.createCrewTab(tabbedWindow)
    TransferCrewGoods.createCargoTab(tabbedWindow)
    TransferCrewGoods.createFightersTab(tabbedWindow)
    TransferCrewGoods.createTorpedoesTab(tabbedWindow)
end

function TransferCrewGoods.createCrewTab(tabbedWindow)
    local crewTab = tabbedWindow:createTab("Crew"%_t, "data/textures/icons/crew.png", "Exchange Crew"%_t)

    local vSplit = UIVerticalSplitter(Rect(crewTab.size), 10, 0, 0.5)
    local lhSplit = UIHorizontalSplitter(vSplit.left, 10, 0, 0.15)
    local rhSplit = UIHorizontalSplitter(vSplit.right, 10, 0, 0.15)

    -- captain UI
    -- left side
    crewTab:createFrame(lhSplit.top)

    local cvSplit = UIVerticalSplitter(lhSplit.top, 10, 10, 0.5)
    cvSplit:setLeftQuadratic()
    playerCaptainUI.icon = crewTab:createCaptainIcon(cvSplit.left)

    local cvSplit = UIVerticalSplitter(cvSplit.right, 10, 0, 0.5)
    cvSplit:setRightQuadratic()
    local inner = UIOrganizer(cvSplit.right)
    inner:setMargin(20, 0, 10, 10)
    playerCaptainUI.transferButton = crewTab:createButton(inner.inner, "", "onTransferCaptainPressed")
    playerCaptainUI.transferButton.icon = "data/textures/icons/arrow-right2.png"

    local lister = UIVerticalLister(cvSplit.left, 8, 0)
    playerCaptainUI.nameLabel = crewTab:createLabel(Rect(), "Captain: Name", 14)
    lister:placeElementCenter(playerCaptainUI.nameLabel)

    lister.padding = 3
    playerCaptainUI.primaryClassLabel = crewTab:createLabel(Rect(), "Miner", 14)
    lister:placeElementCenter(playerCaptainUI.primaryClassLabel)
    playerCaptainUI.secondaryClassLabel = crewTab:createLabel(Rect(), "Scavenger", 14)
    lister:placeElementCenter(playerCaptainUI.secondaryClassLabel)

    -- right side
    crewTab:createFrame(rhSplit.top)

    local cvSplit = UIVerticalSplitter(rhSplit.top, 10, 10, 0.5)
    cvSplit:setLeftQuadratic()
    local inner = UIOrganizer(cvSplit.left)
    inner:setMargin(0, 20, 10, 10)
    selfCaptainUI.transferButton = crewTab:createButton(inner.inner, "", "onTransferCaptainPressed")
    selfCaptainUI.transferButton.icon = "data/textures/icons/arrow-left2.png"

    local cvSplit = UIVerticalSplitter(cvSplit.right, 10, 0, 0.5)
    cvSplit:setLeftQuadratic()
    selfCaptainUI.icon = crewTab:createCaptainIcon(cvSplit.left)

    local lister = UIVerticalLister(cvSplit.right, 8, 0)
    selfCaptainUI.nameLabel = crewTab:createLabel(Rect(), "Captain: Name", 14)
    lister:placeElementCenter(selfCaptainUI.nameLabel)

    lister.padding = 3
    selfCaptainUI.primaryClassLabel = crewTab:createLabel(Rect(), "Miner", 14)
    lister:placeElementCenter(selfCaptainUI.primaryClassLabel)
    selfCaptainUI.secondaryClassLabel = crewTab:createLabel(Rect(), "Scavenger", 14)
    lister:placeElementCenter(selfCaptainUI.secondaryClassLabel)

    for _, label in pairs({ playerCaptainUI.nameLabel, playerCaptainUI.primaryClassLabel, playerCaptainUI.secondaryClassLabel,
                            selfCaptainUI.nameLabel, selfCaptainUI.primaryClassLabel, selfCaptainUI.secondaryClassLabel}) do
        label.font = FontType.SciFi
    end

    local setCaptain = function(self, captain)
        if not captain then
            self.transferButton.active = false
            self.nameLabel.caption = ""
            self.primaryClassLabel.caption = ""
            self.secondaryClassLabel.caption = ""
        else
            self.transferButton.active = true
            self.nameLabel.caption = "Captain: ${name}"%_t % {name = captain.displayName}

            local allProperties = CaptainUtility.ClassProperties()
            local primary = allProperties[captain.primaryClass]

            self.primaryClassLabel.caption = primary.displayName
            self.primaryClassLabel.color = primary.primaryColor
            self.primaryClassLabel.tooltip = nil
            if primary.displayName ~= "" then
                self.primaryClassLabel.tooltip = primary.description
            end

            local secondary = allProperties[captain.secondaryClass]

            self.secondaryClassLabel.caption = secondary.displayName
            self.secondaryClassLabel.color = secondary.secondaryColor
            self.secondaryClassLabel.tooltip = nil
            if secondary.displayName ~= "" then
                self.secondaryClassLabel.tooltip = secondary.description
            end
        end

        self.icon:setCaptain(captain)
    end
    playerCaptainUI.setCaptain = setCaptain
    selfCaptainUI.setCaptain = setCaptain



    -- build crewmen UI
    local lhSplit = UIHorizontalSplitter(lhSplit.bottom, 10, 0, 0.75)
    local rhSplit = UIHorizontalSplitter(rhSplit.bottom, 10, 0, 0.75)

    local leftCrewRect = lhSplit.top
    local rightCrewRect = rhSplit.top

     -- have to use "size" here since the coordinates are relative and the UI would be displaced to the right otherwise
    local leftLister = UIVerticalLister(Rect(leftCrewRect.size), 10, 10)
    local rightLister = UIVerticalLister(Rect(rightCrewRect.size), 10, 10)

    leftLister.marginRight = 30
    rightLister.marginRight = 30

    -- margin for the icon
    leftLister.marginLeft = 35
    rightLister.marginRight = 60

    local leftFrame = crewTab:createScrollFrame(leftCrewRect)
    local rightFrame = crewTab:createScrollFrame(rightCrewRect)

    playerTransferAllCrewButton = leftFrame:createButton(Rect(), "Transfer All >>"%_t, "onPlayerTransferAllCrewPressed")
    leftLister:placeElementCenter(playerTransferAllCrewButton)

    selfTransferAllCrewButton = rightFrame:createButton(Rect(), "<< Transfer All"%_t, "onSelfTransferAllCrewPressed")
    rightLister:placeElementCenter(selfTransferAllCrewButton)

    playerTransferAllCrewButton.textSize = 14
    selfTransferAllCrewButton.textSize = 14

    playerTotalCrewBar = leftFrame:createNumbersBar(Rect())
    leftLister:placeElementCenter(playerTotalCrewBar)

    selfTotalCrewBar = rightFrame:createNumbersBar(Rect())
    rightLister:placeElementCenter(selfTotalCrewBar)

    for i = 1, CrewProfessionType.Number * 4 do

        local iconRect = Rect(leftLister.inner.topLeft - vec2(30, 0), leftLister.inner.topLeft + vec2(-5, 25))
        local rect = leftLister:placeCenter(vec2(leftLister.inner.width, 25))
        local vsplit = UIVerticalSplitter(rect, 10, 0, 0.85)
        local vsplit2 = UIVerticalSplitter(vsplit.left, 10, 0, 0.75)

        local icon = leftFrame:createPicture(iconRect, "")
        icon.isIcon = 1
        local button = leftFrame:createButton(vsplit.right, "", "onPlayerTransferCrewPressed")
        button.icon = "data/textures/icons/arrow-right2.png"

        local bar = leftFrame:createCrewBar(vsplit2.left)
        bar.visiblePerCategory = 3

        local box = leftFrame:createTextBox(vsplit2.right, "onPlayerTransferCrewTextEntered")
        button.textSize = 16
        box.allowedCharacters = "0123456789"
        box.text = "1"
        box.clearOnClick = true

        table.insert(playerCrewIcons, icon)
        table.insert(playerCrewButtons, button)
        table.insert(playerCrewBars, bar)
        table.insert(playerCrewTextBoxes, box)
        crewmenByButton[button.index] = i
        crewmenByTextBox[box.index] = i
        textboxIndexByButton[button.index] = box.index


        local iconRect = Rect(rightLister.inner.topRight - vec2(-5, 0), rightLister.inner.topRight + vec2(30, 25))
        local rect = rightLister:placeCenter(vec2(rightLister.inner.width, 25))
        local vsplit = UIVerticalSplitter(rect, 10, 0, 0.15)
        local vsplit2 = UIVerticalSplitter(vsplit.right, 10, 0, 0.25)

        local icon = rightFrame:createPicture(iconRect, "")
        icon.isIcon = 1
        local button = rightFrame:createButton(vsplit.left, "", "onSelfTransferCrewPressed")
        button.icon = "data/textures/icons/arrow-left2.png"
        local bar = rightFrame:createCrewBar(vsplit2.right)
        bar.visiblePerCategory = 3

        local box = rightFrame:createTextBox(vsplit2.left, "onSelfTransferCrewTextEntered")
        button.textSize = 16
        box.allowedCharacters = "0123456789"
        box.text = "1"
        box.clearOnClick = true

        table.insert(selfCrewIcons, icon)
        table.insert(selfCrewButtons, button)
        table.insert(selfCrewBars, bar)
        table.insert(selfCrewTextBoxes, box)
        crewmenByButton[button.index] = i
        crewmenByTextBox[box.index] = i
        textboxIndexByButton[button.index] = box.index
    end

    -- build passengers UI
    local lhSplit = UIHorizontalSplitter(lhSplit.bottom, 0, 0, 0.5)
    lhSplit.bottomSize = 15

    crewTab:createFrame(lhSplit.top)
    playerPassengerSelection = crewTab:createSelection(lhSplit.top, 8)

    local rhSplit = UIHorizontalSplitter(rhSplit.bottom, 0, 0, 0.5)
    rhSplit.bottomSize = 15

    crewTab:createFrame(rhSplit.top)
    selfPassengerSelection = crewTab:createSelection(rhSplit.top, 8)

    local label = crewTab:createLabel(Rect(lhSplit.bottom.topLeft, rhSplit.bottom.bottomRight), "[Drag & Drop / Shift Click] Transfer Passengers"%_t, 12)
    label:setCenterAligned()
    label.color = ColorRGB(0.5, 0.5, 0.5)

    playerPassengerSelection.dragFromEnabled = true
    playerPassengerSelection.dropIntoEnabled = true
    playerPassengerSelection.entriesSelectable = false

    selfPassengerSelection.dragFromEnabled = true
    selfPassengerSelection.dropIntoEnabled = true
    selfPassengerSelection.entriesSelectable = false

    selfPassengerSelection.onReceivedFunction = "onPassengerDropped"
    selfPassengerSelection.onClickedFunction = "onPassengerClicked"
    playerPassengerSelection.onReceivedFunction ="onPassengerDropped"
    playerPassengerSelection.onClickedFunction = "onPassengerClicked"
end

function TransferCrewGoods.onPassengerDropped(selectionIndex, fkx, fky, item, fromIndex, toIndex, tkx, tky)
    local selfToOther = (selectionIndex == playerPassengerSelection.index)
    invokeServerFunction("transferPassenger", item.passengerIndex, Player().craftIndex, selfToOther)
end

function TransferCrewGoods.onPassengerClicked(selectionIndex, fkx, fky, item, button)
    if Keyboard().shiftPressed then
        local selfToOther = (selectionIndex == selfPassengerSelection.index)

        invokeServerFunction("transferPassenger", item.passengerIndex, Player().craftIndex, selfToOther)
    end
end

function TransferCrewGoods.createCargoTab(tabbedWindow)
    local cargoTab = tabbedWindow:createTab("Cargo"%_t, "data/textures/icons/trade.png", "Exchange Cargo"%_t)

    local vSplit = UIVerticalSplitter(Rect(cargoTab.size), 10, 0, 0.5)

    -- have to use "left" twice here since the coordinates are relative and the UI would be displaced to the right otherwise
    local leftLister = UIVerticalLister(vSplit.left, 10, 10)
    local rightLister = UIVerticalLister(vSplit.left, 10, 10)

    leftLister.marginRight = 30
    rightLister.marginRight = 30

    -- margin for the icon
    leftLister.marginLeft = 35
    rightLister.marginRight = 60

    local leftFrame = cargoTab:createScrollFrame(vSplit.left)
    local rightFrame = cargoTab:createScrollFrame(vSplit.right)

    playerTransferAllCargoButton = leftFrame:createButton(Rect(), "/* Goods */Transfer All >>"%_t, "onPlayerTransferAllCargoPressed")
    leftLister:placeElementCenter(playerTransferAllCargoButton)

    selfTransferAllCargoButton = rightFrame:createButton(Rect(), "/* Goods */<< Transfer All"%_t, "onSelfTransferAllCargoPressed")
    rightLister:placeElementCenter(selfTransferAllCargoButton)

    playerTransferAllCargoButton.textSize = 14
    selfTransferAllCargoButton.textSize = 14

    playerTotalCargoBar = leftFrame:createNumbersBar(Rect())
    leftLister:placeElementCenter(playerTotalCargoBar)

    selfTotalCargoBar = rightFrame:createNumbersBar(Rect())
    rightLister:placeElementCenter(selfTotalCargoBar)

    for i = 1, 100 do

        local iconRect = Rect(leftLister.inner.topLeft - vec2(30, 0), leftLister.inner.topLeft + vec2(-5, 25))
        local rect = leftLister:placeCenter(vec2(leftLister.inner.width, 25))
        local vsplit = UIVerticalSplitter(rect, 10, 0, 0.85)
        local vsplit2 = UIVerticalSplitter(vsplit.left, 10, 0, 0.75)

        local icon = leftFrame:createPicture(iconRect, "")
        icon.isIcon = 1
        local button = leftFrame:createButton(vsplit.right, "", "onPlayerTransferCargoPressed")
        button.icon = "data/textures/icons/arrow-right2.png"
        local bar = leftFrame:createStatisticsBar(vsplit2.left, ColorInt(0xa0a0a0))
        local box = leftFrame:createTextBox(vsplit2.right, "onPlayerTransferCargoTextEntered")
        button.textSize = 16
        box.allowedCharacters = "0123456789"
        box.clearOnClick = true

        table.insert(playerCargoIcons, icon)
        table.insert(playerCargoButtons, button)
        table.insert(playerCargoBars, bar)
        table.insert(playerCargoTextBoxes, box)
        table.insert(playerCargoName, "")
        cargosByButton[button.index] = i
        cargosByTextBox[box.index] = i
        textboxIndexByButton[button.index] = box.index


        local iconRect = Rect(rightLister.inner.topRight - vec2(-5, 0), rightLister.inner.topRight + vec2(30, 25))
        local rect = rightLister:placeCenter(vec2(rightLister.inner.width, 25))
        local vsplit = UIVerticalSplitter(rect, 10, 0, 0.15)
        local vsplit2 = UIVerticalSplitter(vsplit.right, 10, 0, 0.25)

        local icon = rightFrame:createPicture(iconRect, "")
        icon.isIcon = 1
        local button = rightFrame:createButton(vsplit.left, "", "onSelfTransferCargoPressed")
        button.icon = "data/textures/icons/arrow-left2.png"
        local bar = rightFrame:createStatisticsBar(vsplit2.right, ColorInt(0xa0a0a0))
        local box = rightFrame:createTextBox(vsplit2.left, "onSelfTransferCargoTextEntered")
        button.textSize = 16
        box.allowedCharacters = "0123456789"
        box.clearOnClick = true

        table.insert(selfCargoIcons, icon)
        table.insert(selfCargoButtons, button)
        table.insert(selfCargoBars, bar)
        table.insert(selfCargoTextBoxes, box)
        table.insert(selfCargoName, "")
        cargosByButton[button.index] = i
        cargosByTextBox[box.index] = i
        textboxIndexByButton[button.index] = box.index
    end

end

function TransferCrewGoods.createFightersTab(tabbedWindow)
    local fightersTab = tabbedWindow:createTab("Fighters"%_t, "data/textures/icons/fighter.png", "Exchange Fighters"%_t)

    local vSplit = UIVerticalSplitter(Rect(fightersTab.size), 10, 0, 0.5)
    local leftLister = UIVerticalLister(vSplit.left, 0, 0)
    local rightLister = UIVerticalLister(vSplit.right, 0, 0)

--    leftLister.marginLeft = 5
--    rightLister.marginLeft = 5

    playerTransferAllFightersButton = fightersTab:createButton(Rect(), "Transfer All >>"%_t, "onPlayerTransferAllFightersPressed")
    leftLister:placeElementCenter(playerTransferAllFightersButton)

    selfTransferAllFightersButton = fightersTab:createButton(Rect(), "<< Transfer All"%_t, "onSelfTransferAllFightersPressed")
    rightLister:placeElementCenter(selfTransferAllFightersButton)

    for i = 1, 10 do
        -- left side (player)
        local rect = leftLister:placeCenter(vec2(leftLister.inner.width, 18))
        local label = fightersTab:createLabel(rect, "", 14)
        table.insert(playerFighterLabels, label)

        local split = UIVerticalSplitter(leftLister:nextRect(35), 4, 0, 0.5)
        split.leftSize = 27 * 12 + 4 * 13
        local selection = fightersTab:createSelection(split.left, 12)
        selection.dropIntoEnabled = true
        selection.dragFromEnabled = true
        selection.entriesSelectable = false
        selection.onReceivedFunction = "onFighterReceived"
        selection.onClickedFunction = "onFighterClicked"
        selection.padding = 4

        table.insert(playerFighterSelections, selection)
        isPlayerShipBySelection[selection.index] = true
        squadIndexBySelection[selection.index] = i - 1

        local button = fightersTab:createButton(split.right, "", "onTransferSquadPressed")
        button.icon = "data/textures/icons/arrow-right2.png"
        button.tooltip = "Transfer Squad"%_t
        isPlayerShipBySelection[button.index] = true
        squadIndexBySelection[button.index] = i - 1

        -- right side (self)
        local rect = rightLister:placeCenter(vec2(rightLister.inner.width, 18))
        local label = fightersTab:createLabel(rect, "", 16)
        table.insert(selfFighterLabels, label)

        local split = UIVerticalSplitter(rightLister:nextRect(35), 4, 0, 0.5)
        split.leftSize = 27 * 12 + 4 * 13

--        local rect = rightLister:placeCenter(vec2(rightLister.inner.width, 35))
--        rect.upper = vec2(rect.lower.x + 376, rect.upper.y)
        local selection = fightersTab:createSelection(split.left, 12)
        selection.dropIntoEnabled = true
        selection.dragFromEnabled = true
        selection.entriesSelectable = false
        selection.onReceivedFunction = "onFighterReceived"
        selection.onClickedFunction = "onFighterClicked"
        selection.padding = 4

        table.insert(selfFighterSelections, selection)
        isPlayerShipBySelection[selection.index] = false
        squadIndexBySelection[selection.index] = i - 1

        local button = fightersTab:createButton(split.right, "", "onTransferSquadPressed")
        button.icon = "data/textures/icons/arrow-left2.png"
        button.tooltip = "Transfer Squad"%_t
        isPlayerShipBySelection[button.index] = false
        squadIndexBySelection[button.index] = i - 1
    end
end

function TransferCrewGoods.createTorpedoesTab(tabbedWindow)
    local torpedoesTab = tabbedWindow:createTab("Torpedoes"%_t, "data/textures/icons/missile-pod.png", "Exchange Torpedoes"%_t)

    local vSplit = UIVerticalSplitter(Rect(torpedoesTab.size), 10, 0, 0.5)

    torpedoesTab:createFrame(vSplit.left)
    torpedoesTab:createFrame(vSplit.right)

    TransferCrewGoods.createTorpedoesTabOneSide(torpedoesTab, vSplit.left, "data/textures/icons/arrow-right2.png", true)
    TransferCrewGoods.createTorpedoesTabOneSide(torpedoesTab, vSplit.right, "data/textures/icons/arrow-left2.png", false)
end

function TransferCrewGoods.createTorpedoesTabOneSide(torpedoesTab, rect, icon, isPlayerShip)
    local lister = UIVerticalLister(rect, 10, 10)
    torpedoesTab:createLabel(lister:nextRect(16), "Shafts"%_t % {i = i}, 16)

    local splitter = UIVerticalMultiSplitter(lister:nextRect(250), 5, 0, 9)

    for i = 1, 10 do
        local lister = UIVerticalLister(splitter:partition(i - 1), 10, 0)

        local shaftLabel = torpedoesTab:createLabel(lister:nextRect(16), i, 16)
        shaftLabel:setCenterAligned()

        local button = torpedoesTab:createButton(lister:nextQuadraticRect(), "", "onTransferShaftButtonPressed")
        button.icon = icon
        button.tooltip = "Transfer All Torpedoes of This Shaft"%_t

        isPlayerShipBySelection[button.index] = isPlayerShip
        torpedoShaftIndexBySelection[button.index] = i - 1

        local selection = torpedoesTab:createSelection(lister.rect, 1)
        isPlayerShipBySelection[selection.index] = isPlayerShip
        torpedoShaftIndexBySelection[selection.index] = i - 1

        selection.dropIntoEnabled = true
        selection.dragFromEnabled = true
        selection.entriesSelectable = false
        selection.onReceivedFunction = "onTorpedoReceived"
        selection.onClickedFunction = "onTorpedoClicked"
        selection:setShowScrollArrows(true, true, 1.0)

        selection.padding = 3

        if isPlayerShip then
            table.insert(playerTorpedoShafts, selection)
        else
            table.insert(selfTorpedoShafts, selection)
        end
    end

    torpedoesTab:createLabel(lister:nextRect(16), "Storage"%_t % {i = i}, 16)

    local button = torpedoesTab:createButton(lister:nextRect(35), "", "onTransferTorpedoStoragePressed")
    if isPlayerShip then
        button.caption = "Transfer >>"%_t
    else
        button.caption = "<< Transfer"%_t
    end
    isPlayerShipBySelection[button.index] = isPlayerShip

    local selection = torpedoesTab:createSelection(lister:nextRect(188), 10)
    isPlayerShipBySelection[selection.index] = isPlayerShip
    torpedoShaftIndexBySelection[selection.index] = -1

    selection.dropIntoEnabled = true
    selection.dragFromEnabled = true
    selection.entriesSelectable = false
    selection.onReceivedFunction = "onTorpedoReceived"
    selection.onClickedFunction = "onTorpedoClicked"
    selection:setShowScrollArrows(true, true, 1.0)

    selection.padding = 4

    if isPlayerShip then
        playerTorpedoStorage = selection
    else
        selfTorpedoStorage = selection
    end
end


function TransferCrewGoods.getSortedCrewmen(entity)

    local sortedMembers = {}

    local crew = entity.crew
    if crew then
        for crewman, num in pairs(crew:getMembers()) do
            local entry = nil

            for _, e in pairs(sortedMembers) do
                if e.crewman.level == crewman.level
                        and e.crewman.specialist == crewman.specialist
                        and e.crewman.profession == crewman.profession then
                    e.num = e.num + num
                    entry = e
                end
            end

            if not entry then
                -- we want to ignore rank to show the crew members only grouped by level
                -- this is the more important info since ranks will get assigned automatically anyways
                -- also it keeps the UI clearer
                crewman.rank = CrewRank.None
                table.insert(sortedMembers, {crewman = crewman, num = num})
            end
        end
    end


    function compareCrewmen(pa, pb)
        local a = pa.crewman
        local b = pb.crewman

        if a.profession.value == b.profession.value then
            if a.specialist == b.specialist then
                return a.level > b.level
            else
                return (a.specialist and 1 or 0) > (b.specialist and 1 or 0)
            end
        else
            return a.profession.value < b.profession.value
        end
    end

    table.sort(sortedMembers, compareCrewmen)

    return sortedMembers
end

function TransferCrewGoods.refreshUI()
    local playerShip = Player().craft
    local ship = Entity()

    TransferCrewGoods.refreshCrewUI(playerShip, ship)
    TransferCrewGoods.refreshCargoUI(playerShip, ship)
    TransferCrewGoods.refreshFighterUI(playerShip, ship)
    TransferCrewGoods.refreshTorpedoesUI(playerShip, ship)
end

function TransferCrewGoods.refreshCrewUI(playerShip, ship)

    -- update captain info
    playerCaptainUI:setCaptain(playerShip:getCaptain())
    selfCaptainUI:setCaptain(ship:getCaptain())

    -- update crew info
    playerTotalCrewBar:clear()
    selfTotalCrewBar:clear()

    playerTotalCrewBar:setRange(0, playerShip.maxCrewSize)
    selfTotalCrewBar:setRange(0, ship.maxCrewSize)

    for _, icon in pairs(playerCrewIcons) do icon.visible = false end
    for _, icon in pairs(selfCrewIcons) do icon.visible = false end
    for _, bar in pairs(playerCrewBars) do bar.visible = false end
    for _, bar in pairs(selfCrewBars) do bar.visible = false end
    for _, button in pairs(playerCrewButtons) do button.visible = false end
    for _, button in pairs(selfCrewButtons) do button.visible = false end
    for _, box in pairs(playerCrewTextBoxes) do box.visible = false end
    for _, box in pairs(selfCrewTextBoxes) do box.visible = false end

    -- restore textbox values
    local amountByIndex = {}
    for crewIndex, index in pairs(playerCrewTextBoxByIndex) do
        table.insert(amountByIndex, crewIndex, playerCrewTextBoxes[index].text)
    end

    playerCrewTextBoxByIndex = {}

    local i = 1
    for _, p in pairs(TransferCrewGoods.getSortedCrewmen(playerShip)) do

        local crewman = p.crewman
        local num = p.num
        local caption = ""
        if not crewman.specialist then
            caption = "${profession}"%_t % {profession = crewman.profession:name(num)}
        else
            caption = "${profession} (Specialist level ${level})"%_t % {profession = crewman.profession:name(num), level = crewman.level}
        end
        playerTotalCrewBar:addEntry(num, caption, crewman.profession.color)

        local icon = playerCrewIcons[i]
        icon:show()
        icon.picture = crewman.profession.icon
        icon.tooltip = crewman.profession:name()

        local singleBar = playerCrewBars[i]
        singleBar.visible = true
        singleBar:setCrewmen(crewman, num)

        local button = playerCrewButtons[i]
        button.visible = true

        -- restore textbox value
        local box = playerCrewTextBoxes[i]
        if not box.isTypingActive then
            local index = p.crewman.profession.value * 4
            if p.crewman.specialist then index = index + p.crewman.level end
            local amount = TransferCrewGoods.clampNumberString(amountByIndex[index] or "1", num)
            table.insert(playerCrewTextBoxByIndex, index, i)

            box.visible = true
            if amount == "" then
                box.text = "1"
            else
                box.text = amount
            end
        end

        i = i + 1
    end

    -- restore textbox values
    local amountByIndex = {}
    for crewIndex, index in pairs(selfCrewTextBoxByIndex) do
        table.insert(amountByIndex, crewIndex, selfCrewTextBoxes[index].text)
    end

    selfCrewTextBoxByIndex = {}

    local i = 1
    for _, p in pairs(TransferCrewGoods.getSortedCrewmen(Entity())) do

        local crewman = p.crewman
        local num = p.num

        local caption = ""
        if not crewman.specialist then
            caption = "${profession}"%_t % {profession = crewman.profession:name(num)}
        else
            caption = "${profession} (Specialist level ${level})"%_t % {profession = crewman.profession:name(num), level = crewman.level}
        end
        selfTotalCrewBar:addEntry(num, caption, crewman.profession.color)

        local icon = selfCrewIcons[i]
        icon:show()
        icon.picture = crewman.profession.icon
        icon.tooltip = crewman.profession:name()

        local singleBar = selfCrewBars[i]
        singleBar.visible = true
        singleBar:setCrewmen(crewman, num)

        local button = selfCrewButtons[i]
        button.visible = true

        -- restore textbox value
        local box = selfCrewTextBoxes[i]
        if not box.isTypingActive then
            local index = p.crewman.profession.value * 4
            if p.crewman.specialist then index = index + p.crewman.level end

            local amount = TransferCrewGoods.clampNumberString(amountByIndex[index] or "1", num)
            table.insert(selfCrewTextBoxByIndex, index, i)

            box.visible = true
            if amount == "" then
                box.text = "1"
            else
                box.text = amount
            end
        end

        i = i + 1
    end

    playerPassengerSelection:clear()
    selfPassengerSelection:clear()

    for i, passenger in pairs({CrewComponent(playerShip):getPassengers()}) do
        local item = CaptainSelectionItem(passenger)
        item.passengerIndex = i - 1
        playerPassengerSelection:add(item)
    end

    for i, passenger in pairs({CrewComponent(ship):getPassengers()}) do
        local item = CaptainSelectionItem(passenger)
        item.passengerIndex = i - 1
        selfPassengerSelection:add(item)
    end

    playerPassengerSelection:fillWithEmptyRows()
    playerPassengerSelection:addEmptyRows(1)
    selfPassengerSelection:fillWithEmptyRows()
    selfPassengerSelection:addEmptyRows(1)
end

function TransferCrewGoods.refreshCargoUI(playerShip, ship)

    -- update cargo info
    playerTotalCargoBar:clear()
    selfTotalCargoBar:clear()

    playerTotalCargoBar:setRange(0, playerShip.maxCargoSpace)
    selfTotalCargoBar:setRange(0, ship.maxCargoSpace)

    -- restore textbox values
    local playerAmountByIndex = {}
    local selfAmountByIndex = {}
    for cargoName, index in pairs(playerCargoTextBoxByIndex) do
        playerAmountByIndex[cargoName] = playerCargoTextBoxes[index].text
    end
    for cargoName, index in pairs(selfCargoTextBoxByIndex) do
        selfAmountByIndex[cargoName] = selfCargoTextBoxes[index].text
    end

    playerCargoTextBoxByIndex = {}
    selfCargoTextBoxByIndex = {}

    for i, _ in pairs(playerCargoBars) do

        local icon = playerCargoIcons[i]
        local bar = playerCargoBars[i]
        local button = playerCargoButtons[i]
        local box = playerCargoTextBoxes[i]

        if i > playerShip.numCargos then
            icon:hide()
            bar:hide()
            button:hide()
            box:hide()
        else
            icon:show()
            bar:show()
            button:show()

            local good, amount = playerShip:getCargo(i - 1)
            local maxSpace = playerShip.maxCargoSpace
            playerCargoName[i] = good.name
            icon.picture = good.icon
            bar:setRange(0, maxSpace)
            bar.value = amount * good.size

            -- restore textbox value
            if not box.isTypingActive then
                local boxAmount = TransferCrewGoods.clampNumberString(playerAmountByIndex[good.name] or amount, amount)
                playerCargoTextBoxByIndex[good.name] = i
                box:show()
                if boxAmount == "" then
                    box.text = amount
                else
                    box.text = boxAmount
                end
            end

            local name = "${amount} ${good}"%_t % {amount = createMonetaryString(amount), good = good:displayName(amount)}
            bar.name = name
            playerTotalCargoBar:addEntry(amount * good.size, name, ColorInt(0xffa0a0a0))
        end

        local icon = selfCargoIcons[i]
        local bar = selfCargoBars[i]
        local button = selfCargoButtons[i]
        local box = selfCargoTextBoxes[i]

        if i > ship.numCargos then
            icon:hide()
            bar:hide()
            button:hide()
            box:hide()
        else
            icon:show()
            bar:show()
            button:show()

            local good, amount = ship:getCargo(i - 1)
            local maxSpace = ship.maxCargoSpace
            icon.picture = good.icon
            bar:setRange(0, maxSpace)
            bar.value = amount * good.size

            -- restore textbox value
            if not box.isTypingActive then
                local boxAmount = TransferCrewGoods.clampNumberString(selfAmountByIndex[good.name] or amount, amount)
                selfCargoTextBoxByIndex[good.name] = i
                box:show()
                if boxAmount == "" then
                    box.text = amount
                else
                    box.text = boxAmount
                end
            end

            local name = "${amount} ${good}"%_t % {amount = createMonetaryString(amount), good = good:displayName(amount)}
            bar.name = name
            selfTotalCargoBar:addEntry(amount * good.size, name, ColorInt(0xffa0a0a0))
        end
    end
end

function TransferCrewGoods.refreshFighterUI(playerShip, ship)
    -- update fighter info
    for _, label in pairs(playerFighterLabels) do label:hide() end
    for _, label in pairs(selfFighterLabels) do label:hide() end
    for _, selection in pairs(playerFighterSelections) do selection:hide() end
    for _, selection in pairs(selfFighterSelections) do selection:hide() end

    -- left side (player)
    local hangar = Hangar(playerShip.index)
    if hangar then
        local squads = {hangar:getSquads()}

        for _, squad in pairs(squads) do
            local label = playerFighterLabels[squad + 1]
            label.caption = hangar:getSquadName(squad)
            label:show()

            local selection = playerFighterSelections[squad + 1]
            selection:show()
            selection:clear()
            for i = 0, hangar:getSquadFighters(squad) - 1 do
                local fighter = hangar:getFighter(squad, i)

                local item = SelectionItem()
                item.texture = "data/textures/icons/fighter.png"
                item.borderColor = fighter.rarity.color
                item.value0 = squad
                item.value1 = i

                selection:add(item, i)
            end

            for i = hangar:getSquadFighters(squad), 11 do
                selection:addEmpty(i)
            end
        end
    end

    -- right side (self)
    local hangar = Hangar(ship.index)
    if hangar then
        local squads = {hangar:getSquads()}

        for _, squad in pairs(squads) do
            local label = selfFighterLabels[squad + 1]
            label.caption = hangar:getSquadName(squad)
            label:show()

            local selection = selfFighterSelections[squad + 1]
            selection:show()
            selection:clear()
            for i = 0, hangar:getSquadFighters(squad) - 1 do
                local fighter = hangar:getFighter(squad, i)

                local item = SelectionItem()
                item.texture = "data/textures/icons/fighter.png"
                item.borderColor = fighter.rarity.color
                item.value0 = squad
                item.value1 = i

                selection:add(item, i)
            end

            for i = hangar:getSquadFighters(squad), 11 do
                selection:addEmpty(i)
            end
        end
    end

end

function TransferCrewGoods.refreshTorpedoesUI(playerShip, ship)
    TransferCrewGoods.refreshTorpedoesUIOneSide(playerShip, playerTorpedoShafts, playerTorpedoStorage)
    TransferCrewGoods.refreshTorpedoesUIOneSide(ship, selfTorpedoShafts, selfTorpedoStorage)
end

function TransferCrewGoods.refreshTorpedoesUIOneSide(entity, torpedoShafts, torpedoStorage)
    for _, selection in pairs(torpedoShafts) do
        selection:clear()
    end

    torpedoStorage:clear()

    local torpedoes = TorpedoLauncher(entity)
    if not valid(torpedoes) then return end

    for shaftIndex = 0, 9 do
        local selection = torpedoShafts[shaftIndex + 1]
        selection:clear()

        for index = 0, torpedoes:getNumTorpedoes(shaftIndex) - 1 do
            local torpedo = torpedoes:getTorpedo(index, shaftIndex)

            local item = SelectionItem()
            item.value0 = index
            item.texture = torpedo.icon
            item.borderColor = torpedo.rarity.color
            selection:add(item)
        end
    end

    for index = 0, torpedoes:getNumTorpedoes(-1) - 1 do
        local torpedo = torpedoes:getTorpedo(index, -1)

        local item = SelectionItem()
        item.value0 = index
        item.texture = torpedo.icon
        item.borderColor = torpedo.rarity.color

        torpedoStorage:add(item)
    end
end

function TransferCrewGoods.clampNumberString(string, max)
    if string == "" then return "" end

    local num = tonumber(string)
    if not num then return "" end

    if num > max then num = max end

    return tostring(num)
end

function TransferCrewGoods.onPlayerTransferAllCrewPressed(button)
    invokeServerFunction("transferAllCrew", Player().craftIndex, false)
end

function TransferCrewGoods.onSelfTransferAllCrewPressed(button)
    invokeServerFunction("transferAllCrew", Player().craftIndex, true)
end

function TransferCrewGoods.onTransferCaptainPressed()
    invokeServerFunction("swapCaptains", Player().craftIndex)
end

function TransferCrewGoods.onPlayerTransferCrewPressed(button)
    -- transfer crew from player ship to self

    -- check which crew member type
    local crewmanIndex = crewmenByButton[button.index]
    if not crewmanIndex then return end

    -- get amount
    local textboxIndex = textboxIndexByButton[button.index]
    if not textboxIndex then return end

    local box = TextBox(textboxIndex)
    if not box then return end

    local amount = tonumber(box.text) or 0
    if amount == 0 then return end

    invokeServerFunction("transferCrew", crewmanIndex, Player().craftIndex, false, amount)
end

function TransferCrewGoods.onSelfTransferCrewPressed(button)
    -- transfer crew from self ship to player ship

    -- check which crew member type
    local crewmanIndex = crewmenByButton[button.index]
    if not crewmanIndex then return end

    -- get amount
    local textboxIndex = textboxIndexByButton[button.index]
    if not textboxIndex then return end

    local box = TextBox(textboxIndex)
    if not box then return end

    local amount = tonumber(box.text) or 0
    if amount == 0 then return end

    invokeServerFunction("transferCrew", crewmanIndex, Player().craftIndex, true, amount)
end

-- textbox text changed callbacks
function TransferCrewGoods.onPlayerTransferCrewTextEntered(textBox)
    local enteredNumber = tonumber(textBox.text)
    if enteredNumber == nil then
        enteredNumber = 0
    end

    local newNumber = enteredNumber

    -- get available amount
    local crewmanIndex = crewmenByTextBox[textBox.index]
    if not crewmanIndex then return end

    local sender = Entity(Player().craftIndex)

    local sorted = TransferCrewGoods.getSortedCrewmen(sender)
    local p = sorted[crewmanIndex]
    if not p then return end

    local maxAmount = p.num
    if newNumber > maxAmount then
        newNumber = maxAmount
    end

    if newNumber ~= enteredNumber then
        textBox.text = newNumber
    end
end

function TransferCrewGoods.onSelfTransferCrewTextEntered(textBox)
    local enteredNumber = tonumber(textBox.text)
    if enteredNumber == nil then
        enteredNumber = 0
    end

    local newNumber = enteredNumber

    -- get available amount
    local crewmanIndex = crewmenByTextBox[textBox.index]
    if not crewmanIndex then return end

    local sender = Entity()

    local sorted = TransferCrewGoods.getSortedCrewmen(sender)
    local p = sorted[crewmanIndex]
    if not p then return end

    local maxAmount = p.num
    if newNumber > maxAmount then
        newNumber = maxAmount
    end

    if newNumber ~= enteredNumber then
        textBox.text = newNumber
    end
end

function TransferCrewGoods.onPlayerTransferCargoTextEntered(textBox)
    local enteredNumber = tonumber(textBox.text)
    if enteredNumber == nil then
        enteredNumber = 0
    end

    local newNumber = enteredNumber

    -- get available amount
    local cargoIndex = cargosByTextBox[textBox.index]
    if not cargoIndex then return end

    local sender = Entity(Player().craftIndex)
    local _, maxAmount = sender:getCargo(cargoIndex - 1)

    maxAmount = maxAmount or 0

    if newNumber > maxAmount then
        newNumber = maxAmount
    end

    if newNumber ~= enteredNumber then
        textBox.text = newNumber
    end
end

function TransferCrewGoods.onSelfTransferCargoTextEntered(textBox)
    local enteredNumber = tonumber(textBox.text)
    if enteredNumber == nil then
        enteredNumber = 0
    end

    local newNumber = enteredNumber

    -- get available amount
    local cargoIndex = cargosByTextBox[textBox.index]
    if not cargoIndex then return end

    local sender = Entity()
    local good, maxAmount = sender:getCargo(cargoIndex - 1)
    maxAmount = maxAmount or 0

    if newNumber > maxAmount then
        newNumber = maxAmount
    end

    if newNumber ~= enteredNumber then
        textBox.text = newNumber
    end
end

function TransferCrewGoods.transferCrew(crewmanIndex, otherIndex, selfToOther, amount)
    local sender
    local receiver

    if selfToOther then
        sender = Entity()
        receiver = Entity(otherIndex)
    else
        sender = Entity(otherIndex)
        receiver = Entity()
    end

    local player = Player(callingPlayer)
    if not player then return end

    if not TransferCrewGoods.checkPermissionsAndDistance(player, sender, receiver) then return end

    local sorted = TransferCrewGoods.getSortedCrewmen(sender)

    local p = sorted[crewmanIndex]
    if not p then
        print("bad crewman")
        return
    end

    local crewman = p.crewman

    -- transfer
    for _, rank in pairs({CrewRank.None, CrewRank.Sergeant, CrewRank.Lieutenant, CrewRank.Colonel}) do
        crewman.rank = rank

        local removed = sender:removeCrew(amount, crewman) or 0
        if removed > 0 then
            receiver:addCrew(removed, crewman)
            amount = amount - removed

            if amount <= 0 then break end
        end
    end
end
callable(TransferCrewGoods, "transferCrew")

function TransferCrewGoods.transferAllCrew(otherIndex, selfToOther)
    local sender
    local receiver

    if selfToOther then
        sender = Entity()
        receiver = Entity(otherIndex)
    else
        sender = Entity(otherIndex)
        receiver = Entity()
    end

    local player = Player(callingPlayer)
    if not player then return end

    if not TransferCrewGoods.checkPermissionsAndDistance(player, sender, receiver) then return end

    local crew = sender.crew
    if not crew then return end

    for crewman, num in pairs(crew:getMembers()) do
        -- transfer
        sender:removeCrew(num, crewman)
        receiver:addCrew(num, crewman)
    end
end
callable(TransferCrewGoods, "transferAllCrew")

function TransferCrewGoods.swapCaptains(otherIndex)
    local a = Entity()
    local b = Entity(otherIndex)

    local player = Player(callingPlayer)
    if not player then return end

    if not TransferCrewGoods.checkPermissionsAndDistance(player, a, b) then return end

    local captainA = a:getCaptain()
    local captainB = b:getCaptain()

    a:setCaptain(captainB)
    b:setCaptain(captainA)
end
callable(TransferCrewGoods, "swapCaptains")

function TransferCrewGoods.transferPassenger(passengerIndex, otherIndex, selfToOther)
    local sender
    local receiver

    if selfToOther then
        sender = Entity()
        receiver = Entity(otherIndex)
    else
        sender = Entity(otherIndex)
        receiver = Entity()
    end

    local player = Player(callingPlayer)
    if not player then return end

    if not TransferCrewGoods.checkPermissionsAndDistance(player, sender, receiver) then return end

    local sender = CrewComponent(sender)
    local receiver = CrewComponent(receiver)

    local passengers = {sender:getPassengers()}
    local passenger = passengers[passengerIndex + 1]

    if passenger then
        sender:removePassenger(passengerIndex)
        receiver:addPassenger(passenger)
    end
end
callable(TransferCrewGoods, "transferPassenger")

function TransferCrewGoods.onPlayerTransferAllCargoPressed(button)
    invokeServerFunction("transferAllCargo", Player().craftIndex, false)
end

function TransferCrewGoods.onSelfTransferAllCargoPressed(button)
    invokeServerFunction("transferAllCargo", Player().craftIndex, true)
end

function TransferCrewGoods.onPlayerTransferCargoPressed(button)
    -- transfer cargo from player ship to self

    -- check which cargo
    local cargo = cargosByButton[button.index]
    if cargo == nil then return end

    -- get amount
    local textboxIndex = textboxIndexByButton[button.index]
    if not textboxIndex then return end

    local box = TextBox(textboxIndex)
    if not box then return end

    local amount = tonumber(box.text) or 0
    if amount == 0 then return end

    invokeServerFunction("transferCargo", cargo - 1, Player().craftIndex, false, amount)
end

function TransferCrewGoods.onSelfTransferCargoPressed(button)
    -- transfer cargo from self to player ship

    -- check which cargo
    local cargo = cargosByButton[button.index]
    if cargo == nil then return end

    -- get amount
    local textboxIndex = textboxIndexByButton[button.index]
    if not textboxIndex then return end

    local box = TextBox(textboxIndex)
    if not box then return end

    local amount = tonumber(box.text) or 0
    if amount == 0 then return end

    invokeServerFunction("transferCargo", cargo - 1, Player().craftIndex, true, amount)
end


function TransferCrewGoods.transferCargo(cargoIndex, otherIndex, selfToOther, amount)
    local sender
    local receiver

    if selfToOther then
        sender = Entity()
        receiver = Entity(otherIndex)
    else
        sender = Entity(otherIndex)
        receiver = Entity()
    end

    local player = Player(callingPlayer)
    if not player then return end

    if not TransferCrewGoods.checkPermissionsAndDistance(player, sender, receiver) then return end

    -- get the cargo
    local good, availableAmount = sender:getCargo(cargoIndex)

    -- make sure sending ship has the cargo
    if not good or not availableAmount then return end
    amount = math.min(amount, availableAmount)

    -- make sure receiving ship has enough space
    if receiver.freeCargoSpace < good.size * amount then
        player:sendChatMessage("", 1, "Not enough space on the other craft."%_t)
        return
    end

    -- transfer
    sender:removeCargo(good, amount)
    receiver:addCargo(good, amount)

    invokeClientFunction(player, "refreshUI")
end
callable(TransferCrewGoods, "transferCargo")

function TransferCrewGoods.transferAllCargo(otherIndex, selfToOther)
    local sender
    local receiver

    if selfToOther then
        sender = Entity()
        receiver = Entity(otherIndex)
    else
        sender = Entity(otherIndex)
        receiver = Entity()
    end

    local player = Player(callingPlayer)
    if not player then return end

    if not TransferCrewGoods.checkPermissionsAndDistance(player, sender, receiver) then return end

    -- get the cargo
    local cargos = sender:getCargos()
    local cargoTransferred = false

    for good, amount in pairs(cargos) do
        -- make sure receiving ship has enough space
        if receiver.freeCargoSpace < good.size * amount then
            -- transfer as much as possible
            amount = math.floor(receiver.freeCargoSpace / good.size)

            if amount == 0 then
                player:sendChatMessage("", 1, "Not enough space on the other craft."%_t)
                break;
            end
        end

        -- transfer
        sender:removeCargo(good, amount)
        receiver:addCargo(good, amount)
        cargoTransferred = true
    end

    if cargoTransferred then
        invokeClientFunction(player, "refreshUI")
    end
end
callable(TransferCrewGoods, "transferAllCargo")

function TransferCrewGoods.onPlayerTransferAllFightersPressed(button)
    invokeServerFunction("transferAllFighters", Player().craftIndex, Entity().index)
end

function TransferCrewGoods.onSelfTransferAllFightersPressed(button)
    invokeServerFunction("transferAllFighters", Entity().index, Player().craftIndex)
end

function TransferCrewGoods.onFighterReceived(selectionIndex, fkx, fky, item, fromIndex, toIndex, tkx, tky)
    if not item then return end

    local sender
    if isPlayerShipBySelection[fromIndex] then
        sender = Player().craftIndex
    else
        sender = Entity().index
    end

    local receiver
    if isPlayerShipBySelection[toIndex] then
        receiver = Player().craftIndex
    else
        receiver = Entity().index
    end

    local squad = item.value0
    local index = item.value1
    local receiverSquad = squadIndexBySelection[toIndex]

    if receiverSquad == squad and fromIndex == toIndex then return end

    invokeServerFunction("transferFighter", sender, squad, index, receiver, receiverSquad)
end

function TransferCrewGoods.onFighterClicked(selectionIndex, x, y, item, button)
    if button ~= 3 then return end
    if not item then return end

    local sender
    local receiver
    if isPlayerShipBySelection[selectionIndex] then
        sender = Player().craftIndex
        receiver = Entity().index
    else
        sender = Entity().index
        receiver = Player().craftIndex
    end

    local squad = item.value0
    local index = item.value1

    invokeServerFunction("transferFighter", sender, squad, index, receiver, squad)
end

function TransferCrewGoods.transferFighter(sender, squad, index, receiver, receiverSquad)
    if not onServer() then return end

    local player = Player(callingPlayer)
    if not player then return end

    local senderEntity = Entity(sender)
    local receivingEntity = Entity(receiver)
    if not TransferCrewGoods.checkPermissionsAndDistance(player, senderEntity, receivingEntity) then return end

    local senderHangar = Hangar(sender)
    if not senderHangar then
        player:sendChatMessage("", 1, "Missing hangar."%_t)
        return
    end
    local receiverHangar = Hangar(receiver)
    if not receiverHangar then
        player:sendChatMessage("", 1, "Missing hangar."%_t)
        return
    end

    local fighter = senderHangar:getFighter(squad, index)
    if not fighter then
        return
    end

    if sender ~= receiver and receiverHangar.freeSpace < fighter.volume then
        player:sendChatMessage("", 1, "Not enough space in hangar."%_t)
        return
    end

    if receiverHangar:getSquadFreeSlots(receiverSquad) == 0 then
        receiverSquad = nil

        -- find other squad
        local receiverSquads = {receiverHangar:getSquads()}

        for _, newSquad in pairs(receiverSquads) do
            if receiverHangar:fighterTypeMatchesSquad(fighter, newSquad) then
                if receiverHangar:getSquadFreeSlots(newSquad) > 0 then
                    receiverSquad = newSquad
                    break
                end
            end
        end

        if receiverSquad == nil then
            if #receiverSquads < receiverHangar.maxSquads then
                receiverSquad = receiverHangar:addSquad("New Squad"%_t)
            else
                player:sendChatMessage("", 1, "Not enough space in squad."%_t)
            end
        end

    end

    if receiverHangar:getSquadFreeSlots(receiverSquad) > 0 then
        if receiverHangar:fighterTypeMatchesSquad(fighter, receiverSquad) then
            senderHangar:removeFighter(index, squad)
            receiverHangar:addFighter(receiverSquad, fighter)
        else
            player:sendChatMessage("", 1, "The fighter type doesn't match the squad type."%_t)
        end
    end

    invokeClientFunction(player, "refreshUI")
end
callable(TransferCrewGoods, "transferFighter")

function TransferCrewGoods.onTransferSquadPressed(button)
    local squadIndex = squadIndexBySelection[button.index]
    if squadIndex == nil then
--        print("invalid squad index")
        return
    end

    if isPlayerShipBySelection[button.index] then
        invokeServerFunction("transferSquad", Player().craftIndex, Entity().index, squadIndex)
    else
        invokeServerFunction("transferSquad", Entity().index, Player().craftIndex, squadIndex)
    end
end

function TransferCrewGoods.transferSquad(sourceId, targetId, squadIndex)
    if not onServer() then return end

    local player = Player(callingPlayer)
    if not player then return end

    if not TransferCrewGoods.checkPermissionsAndDistance(player, sourceId, targetId) then return end

    local senderHangar = Hangar(sourceId)
    local receiverHangar = Hangar(targetId)
    if not valid(senderHangar) or not valid(receiverHangar) then
        player:sendChatMessage("", 1, "Missing hangar."%_t)
        return
    end

    local senderSquads = {senderHangar:getSquads()}
    local receiverSquads = {receiverHangar:getSquads()}
    local missingSquads = {}

    if senderHangar:getSquadFighters(squadIndex) == 0 then
--        print("no fighters in this squad")
        return
    end

    local targetSquad
    for _, rSquad in pairs(receiverSquads) do
        if rSquad == squadIndex then
            targetSquad = rSquad
            break
        end
    end

    if not targetSquad then
        targetSquad = receiverHangar:addSquad(senderHangar:getSquadName(squadIndex))
    end

    local fighterTransferred = false

    for i = 0, senderHangar:getSquadFighters(squadIndex) - 1 do
        local fighter = senderHangar:getFighter(squadIndex, 0)
        if not fighter then
--            print("fighter is nil")
            break
        end

        -- check squad type
        if not receiverHangar:fighterTypeMatchesSquad(fighter, targetSquad) then
            if not fighterTransferred then
                player:sendChatMessage("", 1, "The fighter type doesn't match the squad type."%_t)
            end

            break
        end

        -- check squad space
        if receiverHangar:getSquadFreeSlots(targetSquad) == 0 then
            if not fighterTransferred then
                player:sendChatMessage("", 1, "Not enough space in squad."%_t)
            end

            break
        end
        -- check hangar space
        if receiverHangar.freeSpace < fighter.volume then
            if not fighterTransferred then
                player:sendChatMessage("", 1, "Not enough space in hangar."%_t)
            end

            break
        end

        -- transfer
        senderHangar:removeFighter(0, squadIndex)
        receiverHangar:addFighter(targetSquad, fighter)
        fighterTransferred = true
    end

    if fighterTransferred then
        invokeClientFunction(player, "refreshUI")
    end
end
callable(TransferCrewGoods, "transferSquad")

function TransferCrewGoods.transferAllFighters(sender, receiver)
    if not onServer() then return end

    local player = Player(callingPlayer)
    if not player then return end

    local senderEntity = Entity(sender)
    local receivingEntity = Entity(receiver)
    if not TransferCrewGoods.checkPermissionsAndDistance(player, senderEntity, receivingEntity) then return end

    local senderHangar = Hangar(sender)
    if not senderHangar then
        player:sendChatMessage("", 1, "Missing hangar."%_t)
        return
    end
    local receiverHangar = Hangar(receiver)
    if not receiverHangar then
        player:sendChatMessage("", 1, "Missing hangar."%_t)
        return
    end

    local senderSquads = {senderHangar:getSquads()}
    local receiverSquads = {receiverHangar:getSquads()}
    local missingSquads = {}

    for _, squad in pairs(senderSquads) do
        if senderHangar:getSquadFighters(squad) > 0 then
            local targetSquad

            for _, rSquad in pairs(receiverSquads) do
                if rSquad == squad then
                    targetSquad = rSquad
                    break
                end
            end

            if not targetSquad then
                targetSquad = receiverHangar:addSquad(senderHangar:getSquadName(squad))
            end

            for i = 0, senderHangar:getSquadFighters(squad) - 1 do

                local fighter = senderHangar:getFighter(squad, 0)
                if not fighter then
--                    print("fighter is nil")
                    return
                end

                -- check squad type
                if not receiverHangar:fighterTypeMatchesSquad(fighter, targetSquad) then
                    player:sendChatMessage("", 1, "The fighter type doesn't match the squad type."%_t)
                    break
                end

                -- check squad space
                if receiverHangar:getSquadFreeSlots(targetSquad) == 0 then
                    player:sendChatMessage("", 1, "Not enough space in squad."%_t)
                    break
                end
                -- check hangar space
                if receiverHangar.freeSpace < fighter.volume then
                    player:sendChatMessage("", 1, "Not enough space in hangar."%_t)
                    return
                end

                -- transfer
                senderHangar:removeFighter(0, squad)
                receiverHangar:addFighter(targetSquad, fighter)
            end
        end
    end

    invokeClientFunction(player, "refreshUI")
end
callable(TransferCrewGoods, "transferAllFighters")


function TransferCrewGoods.onTransferShaftButtonPressed(button)
    local shaftIndex = torpedoShaftIndexBySelection[button.index]
    if shaftIndex == nil then
--        print("invalid shaft index")
        return
    end

    if isPlayerShipBySelection[button.index] then
        invokeServerFunction("transferShaft", Player().craftIndex, Entity().index, shaftIndex)
    else
        invokeServerFunction("transferShaft", Entity().index, Player().craftIndex, shaftIndex)
    end
end

function TransferCrewGoods.onTransferTorpedoStoragePressed(button)
    if isPlayerShipBySelection[button.index] then
        invokeServerFunction("transferShaft", Player().craftIndex, Entity().index, -1)
    else
        invokeServerFunction("transferShaft", Entity().index, Player().craftIndex, -1)
    end
end

function TransferCrewGoods.transferShaft(sourceId, targetId, shaftIndex)
    if not onServer() then return end

    local player = Player(callingPlayer)
    if not player then return end

    if not TransferCrewGoods.checkPermissionsAndDistance(player, sourceId, targetId) then return end

    local sourceLauncher = TorpedoLauncher(sourceId)
    local targetLauncher = TorpedoLauncher(targetId)
    if not valid(sourceLauncher) or not valid(targetLauncher) then return end

    local torpedoesChanged = false

    for index = sourceLauncher:getNumTorpedoes(shaftIndex) - 1, 0, -1 do
        local torpedo = sourceLauncher:getTorpedo(index, shaftIndex)
        if not valid(torpedo) then
--            print("torpedo not found")
            break
        end

        if not targetLauncher:addTorpedo(torpedo, shaftIndex) then
--            print("failed to add torpedo")
            if torpedoesChanged == false then
                if shaftIndex == -1 then
                    player:sendChatMessage("", ChatMessageType.Error, "Not enough free torpedo storage."%_t)
                else
                    player:sendChatMessage("", ChatMessageType.Error, "Not enough free space in torpedo shaft %1%."%_t, shaftIndex + 1)
                end
            end

            break
        end

        torpedoesChanged = true
        sourceLauncher:removeTorpedo(index, shaftIndex)
    end

    if torpedoesChanged then
        invokeClientFunction(player, "refreshUI")
    end
end
callable(TransferCrewGoods, "transferShaft")

function TransferCrewGoods.onTorpedoReceived(selectionIndex, fkx, fky, item, fromIndex, toIndex, tkx, tky)
    if not valid(item) then return end
    if fromIndex == nil or toIndex == nil then
--        print("from or to is nil")
        return
    end

    local source
    local target

    if isPlayerShipBySelection[fromIndex] then
        source = Player().craftIndex
    else
        source = Entity().index
    end

    if isPlayerShipBySelection[toIndex] then
        target = Player().craftIndex
    else
        target = Entity().index
    end

    if not source or not target then
--        print("no source or target")
        return
    end

    local sourceShaftIndex = torpedoShaftIndexBySelection[fromIndex]
    local targetShaftIndex = torpedoShaftIndexBySelection[toIndex]
    if sourceShaftIndex == nil or targetShaftIndex == nil then return end

    invokeServerFunction("transferTorpedo", source, target, sourceShaftIndex, targetShaftIndex, item.value0)
end

function TransferCrewGoods.onTorpedoClicked(selectionIndex, x, y, item, button)
    if button ~= 3 then return end
    if not valid(item) then return end

    local shaftIndex = torpedoShaftIndexBySelection[selectionIndex]
    if shaftIndex == nil then
--        print("no source")
        return
    end

    if isPlayerShipBySelection[selectionIndex] then
        invokeServerFunction("transferTorpedo", Player().craftIndex, Entity().index, shaftIndex, shaftIndex, item.value0)
    else
        invokeServerFunction("transferTorpedo", Entity().index, Player().craftIndex, shaftIndex, shaftIndex, item.value0)
    end
end

function TransferCrewGoods.transferTorpedo(sourceId, targetId, sourceShaftIndex, targetShaftIndex, torpedoIndex)
    if not onServer() then return end

    local player = Player(callingPlayer)
    if not player then return end

    if not TransferCrewGoods.checkPermissionsAndDistance(player, sourceId, targetId) then return end

    local sourceLauncher = TorpedoLauncher(sourceId)
    local targetLauncher = TorpedoLauncher(targetId)
    if not valid(sourceLauncher) or not valid(targetLauncher) then return end

    local torpedo = sourceLauncher:getTorpedo(torpedoIndex, sourceShaftIndex)
    if not valid(torpedo) then
--        print("torpedo not found")
        return
    end

    if not targetLauncher:addTorpedo(torpedo, targetShaftIndex) then
        if targetShaftIndex == -1 then
            player:sendChatMessage("", ChatMessageType.Error, "Not enough free torpedo storage."%_t)
        else
            player:sendChatMessage("", ChatMessageType.Error, "Not enough free space in torpedo shaft %1%."%_t, targetShaftIndex + 1)
        end

        return
    end

    sourceLauncher:removeTorpedo(torpedoIndex, sourceShaftIndex)
    invokeClientFunction(player, "refreshUI")
end
callable(TransferCrewGoods, "transferTorpedo")

function TransferCrewGoods.checkPermissionsAndDistance(player, source, target)
    if source.__avoriontype == "Uuid" then
        source = Entity(source)
    end

    if target.__avoriontype == "Uuid" then
        target = Entity(target)
    end

    if not valid(source) or not valid(target) then
        return false
    end

    if source.factionIndex ~= callingPlayer and source.factionIndex ~= player.allianceIndex then
        player:sendChatMessage("", ChatMessageType.Error, "You don't own this craft."%_t)
        return false
    end

    -- only transfer for ships that aren't in background simulation
    local owner = Galaxy():findFaction(source.factionIndex)
    if owner then
        if owner:getShipAvailability(source.name) ~= ShipAvailability.Available then return false end
    end

    -- check permissions
    if not checkEntityInteractionPermissions(source, AlliancePrivilege.ManageShips) then return false end
    if not checkEntityInteractionPermissions(target, AlliancePrivilege.ManageShips) then return false end

    -- check distance
    if source:getNearestDistance(target) > math.max(20, math.max(source.transporterRange, target.transporterRange)) then
        player:sendChatMessage("", ChatMessageType.Error, "You're too far away."%_t)
        return false
    end

    return true
end

-- this function gets called every time the window is shown on the client, ie. when a player presses F
function TransferCrewGoods.onShowWindow()
    local player = Player()
    local ship = Entity()
    local other = player.craft
    local _, playerAmount = other:getCargo(other.numCargos - 1)
    local _, selfAmount = ship:getCargo(ship.numCargos - 1)


    ship:registerCallback("onCrewChanged", "onCrewChanged")
    ship:registerCallback("onCaptainChanged", "onCrewChangedRefreshUI")
    ship:registerCallback("onPassengerAdded", "onCrewChangedRefreshUI")
    ship:registerCallback("onPassengerRemoved", "onCrewChangedRefreshUI")
    ship:registerCallback("onPassengersRemoved", "onCrewChangedRefreshUI")
    other:registerCallback("onCrewChanged", "onCrewChanged")
    other:registerCallback("onCaptainChanged", "onCrewChangedRefreshUI")
    other:registerCallback("onPassengerAdded", "onCrewChangedRefreshUI")
    other:registerCallback("onPassengerRemoved", "onCrewChangedRefreshUI")
    other:registerCallback("onPassengersRemoved", "onCrewChangedRefreshUI")

    -- set all textboxes to default values
    for _, box in pairs(playerCrewTextBoxes) do
        box.text = "1"
    end
    for _, box in pairs(selfCrewTextBoxes) do
        box.text = "1"
    end
    for _, box in pairs(playerCargoTextBoxes) do
        box.text = playerAmount
    end
    for _, box in pairs(selfCargoTextBoxes) do
        box.text = selfAmount
    end

    TransferCrewGoods.refreshUI()
end

-- this function gets called every time the window is shown on the client, ie. when a player presses F
function TransferCrewGoods.onCloseWindow()
    local player = Player()
    local ship = Entity()
    local other = player.craft

    ship:unregisterCallback("onCrewChanged", "onCrewChanged")
    ship:unregisterCallback("onCaptainChanged", "onCrewChangedRefreshUI")
    ship:unregisterCallback("onPassengerAdded", "onCrewChangedRefreshUI")
    ship:unregisterCallback("onPassengerRemoved", "onCrewChangedRefreshUI")
    ship:unregisterCallback("onPassengersRemoved", "onCrewChangedRefreshUI")

    if other then
        other:unregisterCallback("onCrewChanged", "onCrewChanged")
        other:unregisterCallback("onCaptainChanged", "onCrewChangedRefreshUI")
        other:unregisterCallback("onPassengerAdded", "onCrewChangedRefreshUI")
        other:unregisterCallback("onPassengerRemoved", "onCrewChangedRefreshUI")
        other:unregisterCallback("onPassengersRemoved", "onCrewChangedRefreshUI")
    end
end

function TransferCrewGoods.onCrewChanged(id, delta, profession)
    if delta and profession then
        local playerShip = Player().craft
        local ship = Entity()

        TransferCrewGoods.refreshCrewUI(playerShip, ship)
    end
end

function TransferCrewGoods.onCrewChangedRefreshUI()
    local playerShip = Player().craft
    local ship = Entity()

    TransferCrewGoods.refreshCrewUI(playerShip, ship)
end

-- this function will be executed every frame both on the server and the client
--function update(timeStep)
--end
--
---- this function will be executed every frame on the client only
--function updateClient(timeStep)
--end
--
---- this function will be executed every frame on the server only
--function updateServer(timeStep)
--end
--
---- this function will be executed every frame on the client only
---- use this for rendering additional elements to the target indicator of the object
--function renderUIIndicator(px, py, size)
--end
--
---- this function will be executed every frame on the client only
---- use this for rendering additional elements to the interaction menu of the target craft
function TransferCrewGoods.renderUI()
    local activeSelection
    for _, selection in pairs(playerFighterSelections) do
        if selection.mouseOver then
            activeSelection = selection
            break
        end
    end

    if not activeSelection then
        for _, selection in pairs(selfFighterSelections) do
            if selection.mouseOver then
                activeSelection = selection
                break
            end
        end
    end

    if activeSelection then
        local mousePos = Mouse().position
        local key = activeSelection:getMouseOveredKey()
        if key.y ~= 0 then return end
        if key.x < 0 then return end

        local entity
        if isPlayerShipBySelection[activeSelection.index] then
            entity = Player().craftIndex
        else
            entity = Entity().index
        end

        if not entity then return end

        local hangar = Hangar(entity)
        if not hangar then return end

        local fighter = hangar:getFighter(squadIndexBySelection[activeSelection.index], key.x)
        if not fighter then return end

        local renderer = TooltipRenderer(makeFighterTooltip(fighter))
        renderer:drawMouseTooltip(mousePos)

        return
    end

    -- torpedoes
    for _, selection in pairs(playerTorpedoShafts) do
        if selection.mouseOver then
            activeSelection = selection
            break
        end
    end

    if not activeSelection then
        if playerTorpedoStorage.mouseOver then
            activeSelection = playerTorpedoStorage
        end
    end

    if not activeSelection then
        for _, selection in pairs(selfTorpedoShafts) do
            if selection.mouseOver then
                activeSelection = selection
                break
            end
        end
    end

    if not activeSelection then
        if selfTorpedoStorage.mouseOver then
            activeSelection = selfTorpedoStorage
        end
    end


    if activeSelection then
        local mousePos = Mouse().position
        local key = activeSelection:getMouseOveredKey()
        if key.x < 0 or key.y < 0 then return end

        local entity
        if isPlayerShipBySelection[activeSelection.index] then
            entity = Player().craftIndex
        else
            entity = Entity().index
        end

        if not entity then return end

        local launcher = TorpedoLauncher(entity)
        if not launcher then return end

--        print("index: " .. tostring(key.x + key.y * activeSelection.maxHorizontalEntries))
        local torpedo = launcher:getTorpedo(key.x + key.y * activeSelection.maxHorizontalEntries, torpedoShaftIndexBySelection[activeSelection.index])
        if not torpedo then return end

        local renderer = TooltipRenderer(makeTorpedoTooltip(torpedo))
        renderer:drawMouseTooltip(mousePos)

        return
    end
end
