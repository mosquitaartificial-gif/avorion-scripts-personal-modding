package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/player/background/?.lua"

local CommandFactory = include("simulation/commandfactory")
local SimulationUtility = include ("simulation/simulationutility")
local PassageMap = include ("passagemap")
local CommandType = include ("commandtype")
include("data/scripts/player/map/common")
include("callable")
include("stringutility")
include("utility")
include("goods")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace MapCommands
MapCommands = {}

if onServer() then
function MapCommands.initialize()
    Player():addScriptOnce("data/scripts/player/map/maproutes.lua")
    Player():addScriptOnce("data/scripts/player/map/mapcommandareas.lua")
    Player():addScriptOnce("data/scripts/player/map/mapsectoricons.lua")  -- ← agregar esto
end
end

local lastOrderInfos = {}

local OrderButtonType =
{
    Undo = 1,
    Loop = 2,
    Patrol = 3,
    Attack = 4,
    Repair = 5,
    Stop = 6,
    Recall = 7,
}

local orders = {}

-- ship list
local shipList =
{
    shipsContainer = nil,
    ordersContainer = nil,

    -- orders
    orderButtons = {},

    craftPortraits = {},
    playerShipPortraits = {},
    allianceShipPortraits = {},
    listedPortraits = {},
    selectedPortraits = {},

    doubleClickTimer = nil,

    scrollUpButton = nil,
    scrollDownButton = nil,
    frame = nil,
    portraitContextMenu = nil,

    scrollPosition = 0,
    scrollOffset = 0.0,
    maxVisibleShips = 10,
    numVisiblePortraits = 0,

    stationsVisibleButton = nil,
    offscreenShipsVisibleButton = nil,
    backgroundShipsVisibleButton = nil,
    stationsVisible = true,
    offscreenShipsVisible = false,
    backgroundShipsVisible = true,
}

MapCommands.shipList = shipList

-- background commands
local backgroundCommandInterfaces = {}
local orderWindows = {}
local areaSelection = nil
local currentBackgroundCommandWindow = nil
local recallConfirmationWindow = nil
local commandWindowRefreshTimeCounter = 0
local passageMap = nil
local lastVisibleOrderInterface = nil

-- misc
local rectSelection = nil
local inputHints = {}
local contextSensitiveRMB = nil

-- ui config
local padding = 10 -- general padding
local orderPadding = 10 -- padding between command buttons
local orderDiameter = 40 -- diameter of command buttons

local barOffset = vec2(60, 60)
local arrowHeight = 30
local barIconHeight = 40
local checkboxHeight = 20

local portraitHeight = 60
local portraitWidth = 120

if onClient() then

function MapCommands.initialize()
    local player = Player()
    player:registerCallback("onShowGalaxyMap", "onShowGalaxyMap")
    player:registerCallback("onHideGalaxyMap", "onHideGalaxyMap")
    player:registerCallback("onShipOrderInfoUpdated", "onPlayerShipOrderInfoChanged")
    player:registerCallback("onShipPositionUpdated", "onPlayerShipSectorChanged")
    player:registerCallback("onGalaxyMapUpdate", "onGalaxyMapUpdate")

    player:registerCallback("onGalaxyMapMouseDown", "onGalaxyMapMouseDown")
    player:registerCallback("onGalaxyMapMouseUp", "onGalaxyMapMouseUp")
    player:registerCallback("onGalaxyMapMouseMove", "onGalaxyMapMouseMove")
    player:registerCallback("onGalaxyMapKeyboardEvent", "onGalaxyMapKeyboardEvent")
    player:registerCallback("onGalaxyMapKeyboardDown", "onGalaxyMapKeyboardDown")

    player:registerCallback("onMapRenderAfterLayers", "onMapRenderAfterLayers")

    -- reduce order button size for small resolutions
    if getResolution().y < 860 then
        orderPadding = 5
        orderDiameter = 35
    end

    MapCommands.initUI()
end

function MapCommands.initUI()

    -- ships frame
    local barContainer = GalaxyMap():createContainer()

    local res = getResolution()

    local offset = vec2(res.x - portraitWidth - 2 * padding - barOffset.x, barOffset.y)

    local arrowUpRect, arrowDownRect = Rect(), Rect()

    arrowUpRect.lower = offset + vec2(padding, 3 * padding + barIconHeight + checkboxHeight)
    arrowUpRect.upper = arrowUpRect.lower + vec2(portraitWidth, arrowHeight)
    shipList.scrollUpButton = barContainer:createButton(arrowUpRect, "", "onScrollUpButtonPressed")
    shipList.scrollUpButton.icon = "data/textures/icons/arrow-up2.png"

    shipList.maxVisibleShips = math.floor((res.y - 3 * portraitHeight + 3 * padding - 2 * arrowHeight - (barIconHeight + padding + checkboxHeight)) / (portraitHeight + padding))

    arrowDownRect.lower = offset + vec2(padding, shipList.maxVisibleShips * (portraitHeight + padding) + 4 * padding + arrowHeight + barIconHeight + checkboxHeight)
    arrowDownRect.upper = arrowDownRect.lower + vec2(portraitWidth, arrowHeight)
    shipList.scrollDownButton = barContainer:createButton(arrowDownRect, "", "onScrollDownButtonPressed")
    shipList.scrollDownButton.icon = "data/textures/icons/arrow-down2.png"

    local shipFrameRect = Rect()
    shipFrameRect.lower = vec2(res.x - portraitWidth - 2 * padding - barOffset.x, barOffset.y)
    shipFrameRect.upper = shipFrameRect.lower + vec2(portraitWidth + 2 * padding, 3 * padding + barIconHeight + checkboxHeight)
    shipList.frame = barContainer:createFrame(shipFrameRect)
    shipList.frame.catchAllMouseInput = true
    shipList.frame.layer = shipList.frame.layer - 1 -- the frame catches all input, make sure it is below other elements
    shipList.frame.backgroundColor = ColorARGB(0.5, 0.3, 0.3, 0.3)

    local shipListIconRect = Rect()
    shipListIconRect.lower = offset + vec2(portraitWidth / 2 - barIconHeight + padding, padding)
    shipListIconRect.upper = shipListIconRect.lower + vec2(barIconHeight * 2, barIconHeight)
    local shipListIcon = barContainer:createPicture(shipListIconRect, "data/textures/ui/fleet.png")
    shipListIcon.tooltip = "[CTRL A] Select all ships in the selected sector."%_t
    shipListIcon.isIcon = true

    local vsplit = UIVerticalMultiSplitter(shipFrameRect, 13, 10, 2)
    vsplit.marginTop = barIconHeight + padding

    stationsVisibleButton = barContainer:createButton(vsplit:partition(0), "", "onToggleStationsButtonPressed")
    stationsVisibleButton.hasFrame = false
    stationsVisibleButton.icon = "data/textures/icons/station.png"
    stationsVisibleButton.tooltip = "Show stations"%_t
    MapCommands.refreshButtonOverlays(stationsVisibleButton, shipList.stationsVisible)

    offscreenShipsVisibleButton = barContainer:createButton(vsplit:partition(1), "", "onToggleOffscreenButtonPressed")
    offscreenShipsVisibleButton.hasFrame = false
    offscreenShipsVisibleButton.icon = "data/textures/icons/eye.png"
    offscreenShipsVisibleButton.tooltip = "Show off-screen ships"%_t
    MapCommands.refreshButtonOverlays(offscreenShipsVisibleButton, shipList.offscreenShipsVisible)

    backgroundShipsVisibleButton = barContainer:createButton(vsplit:partition(2), "", "onToggleBGSButtonPressed")
    backgroundShipsVisibleButton.hasFrame = false
    backgroundShipsVisibleButton.icon = "data/textures/icons/background-simulation.png"
    backgroundShipsVisibleButton.tooltip = "Show ships on operations"%_t
    MapCommands.refreshButtonOverlays(backgroundShipsVisibleButton, shipList.backgroundShipsVisible)

    -- containers
    shipList.shipsContainer = GalaxyMap():createContainer()
    shipList.ordersContainer = GalaxyMap():createContainer()
    shipList.contextMenuContainer = GalaxyMap():createContainer()

    shipList.portraitContextMenu = shipList.contextMenuContainer:createContextMenu()

    -- buttons for orders
    orders = {}
    table.insert(orders, {tooltip = "Undo"%_t,              icon = "data/textures/icons/undo.png",              callback = "onUndoPressed",         type = OrderButtonType.Undo})
    table.insert(orders, {tooltip = "Patrol Sector"%_t,     icon = "data/textures/icons/back-forth.png",        callback = "onPatrolPressed",       type = OrderButtonType.Patrol})
    table.insert(orders, {tooltip = "Attack Enemies"%_t,    icon = "data/textures/icons/crossed-rifles.png",    callback = "onAggressivePressed",   type = OrderButtonType.Attack,      stationAllowed = true})
    table.insert(orders, {tooltip = "Repair"%_t,            icon = "data/textures/icons/health-normal.png",     callback = "onRepairPressed",       type = OrderButtonType.Repair})

    local commandSortIndex = {}
    commandSortIndex[CommandType.Prototype] = 1
    commandSortIndex[CommandType.Travel] = 2
    commandSortIndex[CommandType.Scout] = 3
    commandSortIndex[CommandType.Mine] = 4
    commandSortIndex[CommandType.Salvage] = 5
    commandSortIndex[CommandType.Refine] = 6
    commandSortIndex[CommandType.Procure] = 7
    commandSortIndex[CommandType.Sell] = 8
    commandSortIndex[CommandType.Trade] = 9
    commandSortIndex[CommandType.Supply] = 10
    commandSortIndex[CommandType.Expedition] = 11
    commandSortIndex[CommandType.Maintenance] = 12
    commandSortIndex[CommandType.Escort] = 13

    local sortedCommands = {}
    for type, _ in pairs(CommandFactory.getRegistry()) do
        table.insert(sortedCommands, type)
    end

    table.sort(sortedCommands, function(a, b) return commandSortIndex[a] < commandSortIndex[b] end)

    -- windows for special commands
    for _, type in pairs(sortedCommands) do
        local command
        if type ~= CommandType.Prototype then
            command = CommandFactory.makeCommand(type)
        end

        if not command or not command.buildUI then goto continue end

        command.mapCommands = MapCommands

        local windowButtonPressedCallback = command.type .. "_CommandButtonPressed"
        local areaSelectedCallback = command.type .. "_AreaSelected"
        local startPressedCallback = command.type .. "_StartButtonPressed"
        local changeAreaPressedCallback = command.type .. "_ChangeAreaButtonPressed"
        local onRecallPressedCallback = "onRecallPressed"
        local configChangedCallback = command.type .. "_ConfigChanged"

        local interface = {}
        interface.command = command
        interface.ui = command:buildUI(startPressedCallback, changeAreaPressedCallback, onRecallPressedCallback, configChangedCallback)
        interface.ui.current = {} -- this will be used to save the current area and config
        interface.ui.window:center()

        table.insert(orders, {tooltip = interface.ui.orderName, icon = interface.ui.icon, callback = windowButtonPressedCallback, type = command.type})

        -- function that is called when the round button of the command is pressed, after selecting the ship
        MapCommands[windowButtonPressedCallback] = function()
            -- hide all order windows
            for _, window in pairs(orderWindows) do
                window:hide()
            end

            -- deselect additional ships as they would cause error messages when player starts command
            local selectedPortrait
            for _, portrait in pairs(shipList.selectedPortraits) do
                if not selectedPortrait then
                    selectedPortrait = portrait
                else
                    portrait.portrait.selected = false
                end
            end

            if not selectedPortrait.portrait.available then
                -- show read-only ui for the active command
                local shipOwner = Galaxy():findFaction(selectedPortrait.owner)
                local ret, data, descriptionArgs = shipOwner:invokeFunction("data/scripts/player/background/simulation/simulation.lua", "getCommandUIData", selectedPortrait.name)
                if ret ~= 0 then return end

                local entry = ShipDatabaseEntry(selectedPortrait.owner, selectedPortrait.name)

                interface.ui:setActive(false, descriptionArgs)
                interface.ui.commonUI:setAreaStats(data.area)
                interface.ui.commonUI.escortUI:fillReadOnly(data.config.escorts)
                interface.ui:displayPrediction(data.prediction, data.config, selectedPortrait.owner)

                if valid(entry) then -- just to be sure. This should always work because the ship is in BGS
                    interface.ui:displayConfig(data.config, selectedPortrait.owner, entry)

                    local captain = entry:getCaptain()
                    if valid(captain) then
                        interface.ui.commonUI:setAssessment(captain, data.assessment, selectedPortrait.commandType)
                    end
                end

                interface.ui.window:show()
                return
            end

            -- start area selection
            if selectedPortrait then
                interface.ui.current.area = nil
                areaSelection = nil

                if command:isAreaFixed(selectedPortrait.owner, selectedPortrait.name) then
                    -- if the area is fixed, we can skip the whole area selection
                    local commandCallback = MapCommands[areaSelectedCallback]

                    -- the area that we're building here doesn't matter but we'll still do it for robustness' sake
                    local area = {}
                    area.lower = {}
                    area.upper = {}

                    local entry = ShipDatabaseEntry(selectedPortrait.owner, selectedPortrait.name)
                    local x, y = entry:getCoordinates()
                    local allowedSize = command:getAreaSize(selectedPortrait.owner, selectedPortrait.name)

                    local halfX = math.floor((allowedSize.x - 1) / 2)
                    local halfY = math.floor((allowedSize.y - 1) / 2)

                    area.lower.x = x - halfX
                    area.lower.y = y - halfY

                    area.upper.x = area.lower.x + allowedSize.x - 1 -- minus 1 because upper is inclusive
                    area.upper.y = area.lower.y + allowedSize.y - 1 -- minus 1 because upper is inclusive

                    commandCallback(area)
                    return
                end

                areaSelection = {}
                areaSelection.craftName = selectedPortrait.name
                areaSelection.craftOwner = selectedPortrait.owner

                areaSelection.cancelling = false
                areaSelection.commandCallback = MapCommands[areaSelectedCallback]
                areaSelection.command = command

                areaSelection.clampAreaToCraft = command:isShipRequiredInArea(selectedPortrait.owner, selectedPortrait.name)
                local sizes = {command:getAreaSize(selectedPortrait.owner, selectedPortrait.name)}

                local usedSize = MapCommands.nextUsedSize or 1
                local size = sizes[usedSize]
                MapCommands.nextUsedSize = nil

                areaSelection.areaSize = vec2(size.x, size.y)
            else
                areaSelection = nil
            end

        end

        -- function that is called after the area for the command was selected
        MapCommands[areaSelectedCallback] = function(area)
            local selected = MapCommands.getSelectedShips()
            local entry = ShipDatabaseEntry(selected.faction, selected.name)
            if not entry then return end

            interface.ui:clear(selected.faction, selected.name)
            interface.ui:setActive(true)

            currentBackgroundCommandWindow = interface.ui.window
            interface.ui.window:show()

            -- start the area analysis
            local x, y = entry:getCoordinates()

            interface.ui.current.area = nil
            MapCommands.startAreaAnalysis(selected.faction, selected.name, command.type, area)
        end

        -- function that is called when the "Start" button of the command is pressed
        MapCommands[startPressedCallback] = function()
            interface.ui.window:hide()

            local selected = MapCommands.getSelectedShips()
            local config = interface.ui:buildConfig()

            local shipOwner = Galaxy():findFaction(selected.faction)
            shipOwner:invokeFunction("data/scripts/player/background/simulation/simulation.lua",
                                     "startCommand",
                                     selected.name,
                                     interface.command.type,
                                     config)
        end

        -- function that is called when the "Change Area" button of the command is pressed
        MapCommands[changeAreaPressedCallback] = function()
            interface.ui.window:hide()

            MapCommands[windowButtonPressedCallback]()
        end

        MapCommands[onRecallPressedCallback] = MapCommands.onRecallPressed

        -- function that is called when the config of the command is changed
        MapCommands[configChangedCallback] = function()
            local selected = MapCommands.getSelectedShips()
            if not selected then return end

            -- don't handle configs of ships that are in BGS since their config can't change anyway
            -- usually map command UIs are refreshed periodically to keep UI up to date
            -- this is not necessary for non-available (ie. BGS) ships
            if not selected.available then return end

            if not interface.ui.current.area then return end

            local config = interface.ui:buildConfig()
            interface.ui:refreshPredictions(selected.faction, selected.name, interface.ui.current.area, config)
        end

        backgroundCommandInterfaces[type] = interface

        ::continue::
    end

    table.insert(orders, {tooltip = "Stop"%_t,              icon = "data/textures/icons/halt.png",              callback = "onStopPressed",         type = OrderButtonType.Stop,      stationAllowed = true})
    table.insert(orders, {tooltip = "Recall Ship"%_t,       icon = "data/textures/icons/arrow-left.png",        callback = "onRecallPressed",       type = OrderButtonType.Recall})

    shipList.orderButtons = {}
    for i, order in pairs(orders) do
        local button = shipList.ordersContainer:createRoundButton(Rect(), order.icon, order.callback)

        table.insert(shipList.orderButtons, button)
    end

    -- all windows
    for _, interface in pairs(backgroundCommandInterfaces) do
        table.insert(orderWindows, interface.ui.window)

        interface.ui.window.showCloseButton = true
        interface.ui.window.closeableWithEscape = true
        interface.ui.window.moveable = true
        interface.ui.window:hide()
    end


    -- input hints
    local size = vec2(1024, 16)
    local lower = vec2((res.x - size.x) * 0.5, res.y - size.y - 5)
    local rect = Rect(lower, lower + size)

    inputHints.container = GalaxyMap():createContainer(rect)
    inputHints.label = inputHints.container:createLabel(rect, "", 12)
    inputHints.label.outline = true
    inputHints.label.color = ColorRGB(0.6, 0.6, 0.6)
    inputHints.label:setBottomAligned()
    inputHints.label.fontSize = 12

    inputHints.texts = {}
    inputHints.texts[0] = "[WASD] Move Camera"%_t
    inputHints.texts[3] = "[CTRL] Select Multiple"%_t
    inputHints.texts[6] = "[MMB] Ping"%_t

    -- recall confirmation window
    MapCommands.buildRecallWindow()
    recallConfirmationWindow:hide()
end

function MapCommands.buildRecallWindow()
    local recallWindowSize = vec2(450, 165)
    recallConfirmationWindow = GalaxyMap():createWindow(Rect(recallWindowSize))
    recallConfirmationWindow.caption = "Confirm Recall"%_t
    recallConfirmationWindow.showCloseButton = true
    recallConfirmationWindow.closeableWithEscape = true
    recallConfirmationWindow.moveable = true
    recallConfirmationWindow:center()

    local hsplit = UIHorizontalSplitter(Rect(recallWindowSize), 10, 10, 0.7)
    local label = recallConfirmationWindow:createLabel(hsplit.top, "Are you sure? This will cancel any task the captain is working on at the moment.\n\nYour ship will reappear on the galaxy map and you will be able to assign a new task."%_t, 14)
    label.centered = true
    label.font = FontType.Normal
    label.wordBreak = true

    local vsplit = UIVerticalSplitter(hsplit.bottom, 10, 0, 0.5)
    recallConfirmationWindow:createButton(vsplit.left, "Recall"%_t, "onRecallConfirmed")
    recallConfirmationWindow:createButton(vsplit.right, "Cancel"%_t, "onRecallCanceled")

    return recallConfirmationWindow
end

function MapCommands.onGalaxyMapUpdate(timeStep)
    local relativeOffset = (shipList.scrollPosition - shipList.scrollOffset)
    if relativeOffset < 0 then
        relativeOffset = -math.sqrt(-relativeOffset)
    else
        relativeOffset = math.sqrt(relativeOffset)
    end

    if math.abs(relativeOffset) < timeStep * 10 then
        shipList.scrollOffset = shipList.scrollPosition
    else
        shipList.scrollOffset = shipList.scrollOffset + relativeOffset * timeStep * 10
    end

    MapCommands.updatePortraits(timeStep)
    MapCommands.updateShipList()
    MapCommands.updateOrderButtons()
    MapCommands.updateJumpRangeArea()
    MapCommands.updateLines()
    MapCommands.updateNotificationVisibility()
    MapCommands.updateAreaSelection()
    MapCommands.updateAreaHighlight()
    MapCommands.updateCommandWindowRefreshing(timeStep)

    MapCommands.updateInputHints()
    MapCommands.updateCursor()
end

function MapCommands.updatePortraits(timeStep)

    local map = GalaxyMap()
    local galaxy = Galaxy()
    local selectedX, selectedY = map:getSelectedCoordinates()
    local resolution = getResolution()

    shipList.listedPortraits = {}

    -- refresh data in portraits
    for _, portrait in pairs(shipList.craftPortraits) do
        -- portraits are re-shown in update of the ship list
        portrait:hide()

        local entry = ShipDatabaseEntry(portrait.owner, portrait.name)

        -- filter broken & destroyed
        if not valid(entry) or entry:getAvailability() == ShipAvailability.Destroyed then
            map:resetHighlightedAreas()
            MapRoutes.clearRoute(portrait.owner, portrait.name)
            portrait.portrait.selected = false
            portrait.picture = nil
            portrait.onScreen = false
            goto continue
        end

        local availability = entry:getAvailability()

        -- filter stations
        portrait.entityType = entry:getEntityType()

        local x, y = entry:getCoordinates()

        portrait.escortRange = entry:getScriptValue("max_follow_jumprange")
        portrait.escortPassRifts = entry:getScriptValue("max_follow_passrifts")

        -- background ships should have their "location" in the center of their working area
        if availability == ShipAvailability.InBackground then
            local shipOwner = galaxy:findFaction(portrait.owner)
            local ok, area = shipOwner:invokeFunction("simulation.lua", "getAreaBounds", portrait.name)
            if area then
                -- calculate center sector and focus portrait on it
                x = area.lower.x + math.floor((area.upper.x - area.lower.x) / 2)
                y = area.lower.y + math.floor((area.upper.y - area.lower.y) / 2)
            end

            -- and show an icon of the current job
            local ok, description = shipOwner:invokeFunction("simulation.lua", "getDescription", portrait.name)
            if description then
                portrait.commandType = description.command
                if description.command then
                    local command = CommandFactory.makeCommand(description.command)
                    portrait.picture = command:getIcon()
                end

                local ok, text = shipOwner:invokeFunction("simulation.lua", "getDescriptionText", portrait.name)
                if ok == 0 and text then
                    portrait.backgroundDescription = text
                elseif description.text then
                    portrait.backgroundDescription = description.text % _t % (description.arguments or {})
                end
            end
        end

        portrait.coordinates = {x = x, y = y}
        portrait.portrait.inSector = (x == selectedX and y == selectedY and availability == ShipAvailability.Available)

        local oldAvailability = portrait.portrait.available
        portrait.portrait.available = (availability == ShipAvailability.Available)
        if galaxy:sectorInRift(x, y) then
            portrait.portrait.available = false
            portrait.inRift = true
            portrait.portrait.inSector = false
        end

        -- if availability changed from background to available we need to reset area highlight and lines
        if oldAvailability == false and portrait.portrait.available then
            map:resetHighlightedAreas()
            MapRoutes.clearRoute(portrait.owner, portrait.name)

            -- hide command windows if a selected ship became available
            if portrait.portrait.selected then
                for _, interface in pairs(backgroundCommandInterfaces) do
                    interface.ui.window:hide()
                end
            end
        end

        -- if availability changed from available to background we want to immediately update map highlights
        if oldAvailability == true and not portrait.portrait.available then
            MapCommands.highlightRunningCommandArea(portrait)
        end

        -- update order icon -> remove if no longer valid
        if portrait.portrait.available then
            if portrait.info and portrait.info.chain then
                local current = portrait.info.chain[portrait.info.currentIndex]
                if current then
                    portrait.picture = current.icon
                else
                    portrait.picture = nil
                end
            else
                -- no in-sector command, but available ship => icon can't be valid
                portrait.picture = nil
            end
        end

        local sx, sy = map:getCoordinatesScreenPosition(ivec2(portrait.coordinates.x, portrait.coordinates.y))
        portrait.onScreen = (sx >= 0 and sx <= resolution.x and sy >= 0 and sy <= resolution.x)

        -- filter off-screen, background and alliance entities and stations
        if not portrait.portrait.selected then  -- always show selected
            if not shipList.offscreenShipsVisible and not portrait.onScreen then
                goto continue
            end

            if not shipList.backgroundShipsVisible and not portrait.portrait.available then
                goto continue
            end

            if not shipList.stationsVisible and portrait.entityType == EntityType.Station then
                goto continue
            end

            if portrait.portrait.alliance and not map.showAllianceInfo then
                goto continue
            end
        end

        -- refresh tooltips and ship name colors (not on screen -> grey)
        local inSelectedSectorLine = "In Selected Sector"%_t
        local notVisibleLine = "Not on Screen"%_t

        if portrait.onScreen and portrait.portrait.available then

            portrait.portrait.fontColor = ColorRGB(1, 1, 1)

            if portrait.portrait.inSector then
                portrait.portrait.tooltip = inSelectedSectorLine
            else
                portrait.portrait.tooltip = nil
            end
        else
            portrait.portrait.fontColor = ColorRGB(0.5, 0.5, 0.5)

            if portrait.portrait.inSector then
                portrait.portrait.tooltip = inSelectedSectorLine .. "\n" .. notVisibleLine
            elseif not portrait.portrait.available then
                portrait.portrait.tooltip = portrait.backgroundDescription
            else
                portrait.portrait.tooltip = notVisibleLine
            end
        end

        table.insert(shipList.listedPortraits, portrait)

        ::continue::
    end

    MapCommands.updateSelectedPortraits()
end

function MapCommands.updateShipList(timeStep)
    if #shipList.craftPortraits == 0 then
        shipList.scrollUpButton.visible = false
        shipList.scrollDownButton.visible = false

        inputHints.texts[2] = nil
        inputHints.texts[4] = nil
        return
    end

    if #shipList.selectedPortraits > 0 then
        inputHints.texts[2] = "[CTRL 1-9] Assign Group"%_t
        inputHints.texts[4] = "[SPACE] Focus Selected"%_t
    else
        inputHints.texts[2] = nil
        inputHints.texts[4] = nil
    end

    -- sort ship list by name with ships in current sector at the top
    table.sort(shipList.listedPortraits, function(a, b)
        local aInside = a.portrait.inSector
        local bInside = b.portrait.inSector

        if aInside and not bInside then
            return true
        elseif not aInside and bInside then
            return false
        else
            return a.name < b.name
        end
    end)

    -- scrolling and scroll offset
    if shipList.scrollPosition > #shipList.listedPortraits - shipList.numVisiblePortraits then
        shipList.scrollPosition = math.max(#shipList.listedPortraits - shipList.numVisiblePortraits, 0)
    elseif shipList.scrollPosition < 0 then
        shipList.scrollPosition = 0
    end

    shipList.numVisiblePortraits = math.min(#shipList.listedPortraits, shipList.maxVisibleShips)

    local resolution = getResolution()
    local offset = vec2(resolution.x - portraitWidth - barOffset.x - padding, barOffset.y - portraitHeight + barIconHeight + 2 * padding + checkboxHeight)

    local shipScrollButtonsVisible = #shipList.listedPortraits > shipList.numVisiblePortraits
    shipList.scrollUpButton.visible = shipScrollButtonsVisible
    shipList.scrollDownButton.visible = shipScrollButtonsVisible
    if shipScrollButtonsVisible then
        shipList.scrollUpButton.active = shipList.scrollPosition ~= 0
        shipList.scrollDownButton.active =  shipList.scrollPosition < #shipList.listedPortraits - shipList.numVisiblePortraits
    end

    local shipFrameRect = Rect()

    shipFrameRect.lower = vec2(resolution.x - portraitWidth - 2 * padding - barOffset.x, barOffset.y)
    shipFrameRect.upper = shipFrameRect.lower + vec2(portraitWidth + 2 * padding, shipList.numVisiblePortraits * (portraitHeight + padding) + 3 * padding + barIconHeight + checkboxHeight)

    if #shipList.listedPortraits > shipList.maxVisibleShips then
        shipFrameRect.upper = shipFrameRect.upper + vec2(0, (arrowHeight + padding) * 2)
        offset.y = offset.y + arrowHeight + padding
    end

    shipList.frame.rect = shipFrameRect

    -- parameters of ship shrinking near top and bottom border of sidebar:

    -- the number of ship portraits displayed additionally when portraits are small
    -- fractions are allowed
    local additionalSmallCount = 0.9
    -- the maximum number of ships which can be displayed in smaller size
    -- should be larger than additionalSmallCount
    -- fractions are allowed
    local smallCount = 3

    for i, portrait in pairs(shipList.listedPortraits) do
        -- calculate the ship index as shown in the bar
        local shipIndex = i - shipList.scrollOffset
        if shipIndex < -additionalSmallCount or shipIndex > shipList.numVisiblePortraits + additionalSmallCount + 1 then
            portrait:hide()
            goto continue
        end

        portrait:show()

        local scale = 1.0
        local borderMin, borderMax, shipsBarBorderOffset

        if shipIndex < smallCount - additionalSmallCount + 1 then
            scale = (shipIndex + additionalSmallCount) / (smallCount + 1)
            shipsBarBorderOffset = shipList.scrollOffset
            borderMin, borderMax = 0.5, smallCount - additionalSmallCount + 1
        else
            -- same as shipIndex, but counted from bottom to top
            local shipBackIndex = shipList.numVisiblePortraits + 1 - shipIndex
            if shipBackIndex < smallCount - additionalSmallCount + 1 then
                scale = (shipBackIndex + additionalSmallCount) / (smallCount + 1)
                shipsBarBorderOffset = #shipList.listedPortraits - shipList.scrollOffset - shipList.numVisiblePortraits
                borderMin, borderMax = shipList.numVisiblePortraits + 0.5, shipList.numVisiblePortraits - smallCount + additionalSmallCount
            end
        end

        -- if scale smaller one, change ship index, which is used for offset
        if scale < 1.0 then
            -- square the scale for offset to avoid overlap
            local scaleOffset = scale * scale
            local offsetShipIndex = (1 - scaleOffset) * borderMin + scaleOffset * borderMax

            -- when there are no more ships above or below, show ships on top or bottom border in full size without offset
            if shipsBarBorderOffset and shipsBarBorderOffset < additionalSmallCount then
                -- this factor is used to blend between the default position and the shrink position
                local offsetFactor = 1 - shipsBarBorderOffset / additionalSmallCount
                -- this makes the growing and shrinking at the beginning smoother
                -- it's also necessary to ensure the portraits do not intersect the scrolling arrows
                offsetFactor = 1 - offsetFactor * offsetFactor
                scale = scale * offsetFactor + (1 - offsetFactor)
                shipIndex = shipIndex * (1 - offsetFactor) + offsetShipIndex * offsetFactor
            else
                shipIndex = offsetShipIndex
            end
        end

        local rect = Rect()
        local fullsize = vec2(portraitWidth, portraitHeight)
        local size = fullsize * vec2(1, scale)

        -- offset the portrait, so the scaling appears to be from center
        local sizeDelta = (fullsize - size) / 2
        rect.lower = vec2(0, shipIndex * (portraitHeight + padding)) + offset + sizeDelta
        rect.upper = rect.lower + size
        portrait.portrait.rect = rect
        portrait.portrait.fontSize = 14 * scale

        -- check for icon of current order
        local orderIcon = nil
        if portrait.picture and portrait.picture ~= "" then
            orderIcon = portrait.picture
        end

        -- if we have a player piloting the ship we want to show player icon instead of order icon
        portrait.playerPiloted = nil
        local ship = Player().craft
        if ship and portrait.name == ship.name and portrait.owner == ship.factionIndex then
            orderIcon = "data/textures/icons/player.png"
            portrait.playerPiloted = true
        end

        if orderIcon then
            -- location of order icon: top left corner of portrait
            -- Beware UICraftPortrait already uses:
            -- top center for group label
            -- top right corner for alliance icon
            -- bottom right corner for in-sector or not
            -- bottom left corner for name
            local iconPos = rect.topLeft - vec2(-15, -15)
            portrait.icon.rect = Rect(iconPos - vec2(13, 13), iconPos + vec2(13, 13))
            portrait.icon.picture = orderIcon
        else
            portrait.icon:hide()
        end

        ::continue::
    end
end

function MapCommands.updateOrderButtons()
    -- early return when no portraits exist
    if #shipList.selectedPortraits == 0 then
        MapCommands.hideOrderButtons()
        return
    end

    local cx, cy = GalaxyMap():getSelectedCoordinates()

    local enqueueing = MapCommands.isEnqueueing()
    if #shipList.selectedPortraits > 0 and enqueueing then
        local x, y = MapCommands.getLastLocationFromInfo(shipList.selectedPortraits[1].info)
        if x and y then
            cx, cy = x, y
        end
    end

    -- command buttons
    local visibleButtons = {}

    for i, button in pairs(shipList.orderButtons) do
        local add = true

        if orders[i].type == OrderButtonType.Stop then
            if MapCommands.isEnqueueing() then
                -- cannot enqueue a "stop"
                add = false
            end

            for _, portrait in pairs(shipList.selectedPortraits) do
                if not portrait.portrait.available then
                    -- can't stop unavailable ships, that's what the "recall" order is for
                    add = false
                end
            end

        elseif orders[i].type == OrderButtonType.Undo then
            -- cannot undo if there is nothing to undo
            local hasCommands = false

            for _, portrait in pairs(shipList.selectedPortraits) do
                if MapCommands.hasCommandToUndo(portrait.info) then
                    hasCommands = true
                    break
                end
            end

            if not hasCommands then
                add = false
            end

        elseif orders[i].type == OrderButtonType.Loop then
            -- cannot loop if there are no commands based in the selected sector
            local hasCommands = false

            if MapCommands.isEnqueueing() then
                for _, portrait in pairs(shipList.selectedPortraits) do
                    local commands = MapCommands.getCommandsFromInfo(portrait.info, cx, cy)
                    if #commands > 0 then
                        hasCommands = true
                        break
                    end
                end
            end

            if not hasCommands then
                add = false
            end

        elseif orders[i].type == OrderButtonType.Recall then
            for _, portrait in pairs(shipList.selectedPortraits) do
                if portrait.portrait.available then
                    add = false
                else
                    add = true
                end
            end
        end

        for _, portrait in pairs(shipList.selectedPortraits) do
            if not orders[i].stationAllowed then
                if portrait.entityType ~= EntityType.Ship then
                    add = false
                end
            end
        end

        for _, portrait in pairs(shipList.selectedPortraits) do
            if portrait.inRift then
                add = false
            end
        end

        if add then

            local error = nil
            if orders[i].type ~= OrderButtonType.Recall then
                local ship = Player().craft
                for _, portrait in pairs(shipList.selectedPortraits) do
                    if not portrait.portrait.available then
                        -- don't deactivate the button of the order that is currently being executed
                        if orders[i].type ~= portrait.commandType then
                            error = "Ship is busy!"%_t
                        end
                    end

                    if not portrait.captain then
                        error = "Ship doesn't have a captain!"%_t
                    end
                end
            end

            if not error then
                button.active = true
                button.tooltip = orders[i].tooltip
            else
                button.active = false
                button.tooltip = error
            end

            table.insert(visibleButtons, button)
        else
            button:hide()
        end
    end

    local resolution = getResolution()
    local offset = vec2(resolution.x - portraitWidth - 3 * padding - barOffset.x - orderDiameter - orderPadding, barOffset.y)

    for i, button in pairs(visibleButtons) do
        local rect = Rect()
        rect.lower = vec2(0, i * (orderDiameter + orderPadding)) + offset
        rect.upper = rect.lower + vec2(orderDiameter, orderDiameter)
        button.rect = rect

        button:show()
    end
end

function MapCommands.updateJumpRangeArea()
    local escortReach = 10000
    local escortPassRifts = false
    local reach = 10000
    local canPassRifts = true
    local x, y
    for _, portrait in pairs(shipList.selectedPortraits) do
        x = portrait.coordinates.x
        y = portrait.coordinates.y

        local shipOwner = Galaxy():findFaction(portrait.owner)

        local shipReach = shipOwner:getShipHyperspaceReach(portrait.name)
        canPassRifts = canPassRifts and shipOwner:getShipCanPassRifts(portrait.name)

        if shipReach and shipReach > 0 then
            reach = math.min(reach, shipReach)
        end

        escortReach = math.min(portrait.escortRange or escortReach, escortReach)
        escortPassRifts = portrait.escortPassRifts

        ::continue::
    end

    if #shipList.selectedPortraits == 0 then
        local playerCraft = Player().craft
        if playerCraft then
            local escortReach = playerCraft:getValue("max_follow_jumprange")

            if not escortReach then
                GalaxyMap():resetJumpRangeArea("own_ship_escort")
            else
                local x, y = Sector():getCoordinates()
                local escortPassRifts = playerCraft:getValue("max_follow_passrifts")

                GalaxyMap():setJumpRangeArea("own_ship_escort", ivec2(x, y), escortReach, escortPassRifts, true, ColorARGB(0.75, 0.5, 0.5, 1), true)
            end
        end
    end

    local map = GalaxyMap()

    if reach < 10000 then
        -- while enqueueing, move jump range area to the location that we'll be jumping from
        if MapCommands.isEnqueueing() then
            if #shipList.selectedPortraits > 0 then
                local ix, iy = MapCommands.getLastLocationFromInfo(shipList.selectedPortraits[1].info)
                if ix and iy then
                    x, y = ix, iy
                end
            end
        end

        if contextSensitiveRMB then
            local mx, my = GalaxyMap():getHoveredCoordinates()
            contextSensitiveRMB.inRange = distance(vec2(x, y), vec2(mx, my)) <= reach
        end

        map:setJumpRangeArea("other_jumprange", ivec2(x, y), reach, canPassRifts, true, ColorRGB(0.5, 1, 1), false)
    else
        map:resetJumpRangeArea("other_jumprange")
    end

    if escortReach and escortReach < 10000 then
        map:setJumpRangeArea("other_escort", ivec2(x, y), escortReach, escortPassRifts, true, ColorARGB(0.75, 0.5, 1, 1), true)
    else
        map:resetJumpRangeArea("other_escort")
    end
end

-- it's a set of selected portraits, used for quick lookup via maproutes.lua
local selectedPortraitsSet = {}

-- used in maproutes.lua
function MapCommands.isSelected(id)
    if selectedPortraitsSet[id] then
        return true
    else
        return false
    end
end

function MapCommands.updateSelectedPortraits()
    shipList.selectedPortraits = {}

    for _, portrait in pairs(shipList.craftPortraits) do
        local id = portrait.name .. "_" .. tostring(portrait.owner)
        if portrait.portrait.selected then

            table.insert(shipList.selectedPortraits, portrait)

            if not selectedPortraitsSet[id] then
                MapRoutes.onPortraitSelectionChanged(portrait, true)
                selectedPortraitsSet[id] = true
            end
        else
            if selectedPortraitsSet[id] then
                MapRoutes.onPortraitSelectionChanged(portrait, false)
                selectedPortraitsSet[id] = nil
            end
        end
    end
end

function MapCommands.updateLines()

    local galaxyMap = GalaxyMap()
    local selected = {}
    local hovered = {}
    selected.x, selected.y = galaxyMap:getSelectedCoordinates()
    hovered.x, hovered.y = galaxyMap:getHoveredCoordinates()

    for _, portrait in pairs(shipList.listedPortraits) do
        local id = portrait.name .. "_" .. tostring(portrait.owner)

        local sx, sy = galaxyMap:getCoordinatesScreenPosition(ivec2(portrait.coordinates.x, portrait.coordinates.y))

        portrait.line.dynamic = true
        portrait.line.from = vec2(sx, sy)
        portrait.line.to = portrait.portrait.lower + vec2(0, portrait.portrait.size.y * 0.5)
        portrait.line.visible = not portrait.inRift

        local lineColor = ColorARGB(0.2, 0.3, 0.3, 0.3)
        local frameColor = ColorRGB(0.3, 0.3, 0.3)

        if portrait.portrait.mouseOver or (portrait.coordinates.x == hovered.x and portrait.coordinates.y == hovered.y) then
            lineColor = ColorARGB(0.2, 1, 1, 1)
            frameColor = ColorRGB(0.5, 0.5, 0.5)
        end

        if portrait.coordinates.x == selected.x and portrait.coordinates.y == selected.y then
            lineColor = ColorARGB(0.2, 1, 1, 1)
        end

        if not portrait.portrait.available then
            if (MapCommandAreas and MapCommandAreas.isMouseOverArea(portrait.owner, portrait.name)) then
                lineColor = ColorARGB(0.5, 1, 1, 1)
                frameColor = ColorRGB(0.4, 0.5, 0.5)
            end
        end

        if portrait.portrait.selected then
            lineColor = ColorARGB(0.5, 1, 1, 1)
        end

        portrait.line.color = lineColor
        portrait.portrait.frameColor = frameColor

        ::continue::
    end

end

function MapCommands.updateAreaSelection()
    if not areaSelection then return end

    -- exit early in case the area selection ship is invalid
    local databaseEntry = ShipDatabaseEntry(areaSelection.craftOwner, areaSelection.craftName)
    if not databaseEntry then
        DebugInfo():log("owner, name", areaSelection.craftOwner, areaSelection.craftName)
        MapCommands.stopAreaSelection()
        return
    end

    local map = GalaxyMap()

    -- no ship or a different ship is selected -> disable area selection
    local selectedPortrait = MapCommands.getFirstSelectedPortrait()
    if not selectedPortrait
            or selectedPortrait.name ~= areaSelection.craftName
            or selectedPortrait.owner ~= areaSelection.craftOwner then
        MapCommands.stopAreaSelection()
        return
    end

    local mx, my = map:getCoordinatesAtScreenPosition(Mouse().position)

    -- calculate offset from the middle to the lower/upper corners of the area
    local lowerOffset = (areaSelection.areaSize - vec2(1, 1)) / 2
    lowerOffset.x = math.max(0, math.floor(lowerOffset.x))
    lowerOffset.y = math.max(0, math.floor(lowerOffset.y))

    local upperOffset = -lowerOffset + areaSelection.areaSize - vec2(1, 1)

    local craftCoordinates
    if areaSelection.clampAreaToCraft then
        -- clamp to craft's current sector
        craftCoordinates = vec2(selectedPortrait.coordinates.x, selectedPortrait.coordinates.y)

        mx = math.min(math.max(mx, craftCoordinates.x - lowerOffset.x), craftCoordinates.x + upperOffset.x)
        my = math.min(math.max(my, craftCoordinates.y - lowerOffset.y), craftCoordinates.y + upperOffset.y)
    end

    areaSelection.area =
    {
        lower = vec2(mx, my) - lowerOffset,
        upper = vec2(mx, my) + upperOffset
    }

    areaSelection.valid = true
    if areaSelection.command.isValidAreaSelection then
        areaSelection.valid = areaSelection.command:isValidAreaSelection(areaSelection.craftOwner, areaSelection.craftName, areaSelection.area, {x = mx, y = my})
    end

    if areaSelection.valid then
        local area = {}

        if not passageMap then
            passageMap = PassageMap(Seed(GameSettings().seed))
        end

        local reachable
        if areaSelection.clampAreaToCraft then
            -- visualize the area where the ship will do its thing
            local reach, canPassRifts, cooldown = databaseEntry:getHyperspaceProperties()

            if canPassRifts then
                reachable = SimulationUtility.calculatePassageMapFill(areaSelection.area, passageMap)
            else
                reachable = SimulationUtility.calculateFloodFill(craftCoordinates, areaSelection.area, passageMap)
            end
        else
            -- if the craft is not required to be in the starting area, we can't do a flood fill since there is not necessarily an origin point
            reachable = SimulationUtility.calculatePassageMapFill(areaSelection.area, passageMap)
        end

        for _, sector in pairs(reachable) do
            table.insert(area, {x = sector.x, y = sector.y, color = "32a0a0a0"})
        end

        map:setHighlightedSectors(area)
    else
        map:resetHighlightedAreas()
    end
end

function MapCommands.updateAreaHighlight()
    -- reset the highlight if no ship is selected
    if #shipList.selectedPortraits == 0 then
        GalaxyMap():resetHighlightedAreas()
    end

    -- hide the area when the command window is hidden
    if currentBackgroundCommandWindow and not currentBackgroundCommandWindow.visible then
        currentBackgroundCommandWindow = nil
        GalaxyMap():resetHighlightedAreas()
    end
end

function MapCommands.updateCommandWindowRefreshing(timeStep)
    commandWindowRefreshTimeCounter = commandWindowRefreshTimeCounter + timeStep
    if commandWindowRefreshTimeCounter >= 5 then
        commandWindowRefreshTimeCounter = 0

        local galaxy = Galaxy()

        for type, interface in pairs(backgroundCommandInterfaces) do
            if interface.ui.window.visible then
                local selected = MapCommands.getSelectedShips()
                if selected and interface.ui.current.area then
                    if selected.available then
                        -- refresh predictions
                        local config = interface.ui:buildConfig()
                        interface.ui:refreshPredictions(selected.faction, selected.name, interface.ui.current.area, config)
                    else

                        -- ship is in BGS, update only the remaining time
                        local shipOwner = galaxy:findFaction(selected.faction)
                        local ret, _, descriptionArgs = shipOwner:invokeFunction("data/scripts/player/background/simulation/simulation.lua", "getCommandUIData", selected.name)
                        if ret == 0 then
                            interface.ui.commonUI:setActive(false, descriptionArgs)
                        end
                    end
                end
            end
        end
    end

    if lastVisibleOrderInterface then
        if not lastVisibleOrderInterface.ui.window.visible then
            if lastVisibleOrderInterface.ui.onWindowClosed then
                lastVisibleOrderInterface.ui:onWindowClosed()
            end
        end

        lastVisibleOrderInterface = nil
    end

    for type, interface in pairs(backgroundCommandInterfaces) do
        if interface.ui.window.visible then
            lastVisibleOrderInterface = interface
        end
    end

end

function MapCommands.updateNotificationVisibility()

    local left = shipList.frame.rect.lower.x
    local right = shipList.frame.rect.upper.x
    local top = shipList.frame.rect.lower.y
    local bottom = shipList.frame.rect.upper.y

    for i, button in pairs(shipList.orderButtons) do
        if button.visible then
            left = math.min(left, button.rect.lower.x)
            bottom = math.max(bottom, button.rect.upper.y)
        end
    end

    left = left - 40
    bottom = bottom + 40

    local mouse = Mouse().position
    local inArea = mouse.x > left and mouse.x < right
                    and mouse.y > top and mouse.y < bottom

    Hud().notificationsVisible = not inArea
end

function MapCommands.updateInputHints()
    if Keyboard().shiftPressed then
        inputHints.texts[1] = "[SHIFT 1-9] Add to Selection"%_t
    else
        inputHints.texts[1] = "[1-9] Select Group"%_t
    end

    local ship = MapCommands.getSelectedShips()
    if ship then
        inputHints.texts[5] = nil
    else
        inputHints.texts[5] = "[RMB] More Options"%_t
    end

    local t = inputHints.texts

    local topLine = string.join({t[0], t[4], t[5], t[6]}, "     ")
    local bottomLine = string.join({t[1], t[2], t[3]}, "     ")

    inputHints.label.caption = string.join({topLine, bottomLine}, "\n")
end

function MapCommands.updateCursor()

    local hud = Hud()
    if MapCommands.isCommandWindowVisible() then
        hud:setCursor(nil)
        contextSensitiveRMB = nil
        return
    end

    if shipList.frame.mouseOver then
        hud:setCursor(nil)
        contextSensitiveRMB = nil
        return
    end

    if recallConfirmationWindow.visible and recallConfirmationWindow.mouseOver then
        hud:setCursor(nil)
        contextSensitiveRMB = nil
        return
    end

    for _, button in pairs(shipList.orderButtons) do
        if button.visible and button.mouseOver then
            hud:setCursor(nil)
            contextSensitiveRMB = nil
            return
        end
    end

    local selected = MapCommands.getFirstSelectedPortrait()
    if selected and selected.portrait.available then
        hud:setCursor("data/textures/cursors/ship-corner.png", 1, 1)
        contextSensitiveRMB = contextSensitiveRMB or {}
    else
        hud:setCursor(nil)
        contextSensitiveRMB = nil
    end

    if areaSelection then
        contextSensitiveRMB = nil
    end

end


function MapCommands.playOrderChainSound(name, info)
    -- remember last order index of each ship
    -- we must distinguish between 3 cases:
    -- * info.currentIndex increases (ie. a new order was selected, but not added) -> no sound
    -- * info.currentIndex remains the same, but length changes (ie. a new order was added) -> play sound
    -- * info.currentIndex remains the same, and number of orders is 1 (ie. a new order was added, after there were no orders (ie. first order)) -> play sound
    local lastOrderInfo = lastOrderInfos[name] or {chain = {}}
    lastOrderInfos[name] = info

    -- don't play a sound when orders are reset
    -- this avoids double playing as when not enchaining, orders are usually first reset and then reassigned
    if not info or #info.chain == 0 then return end

    local numOrdersChanged = #info.chain ~= #lastOrderInfo.chain
    local chainResetOrFirstOrder = (#info.chain == 1 and nextIndex == 1)

    local nextIndex = info.currentIndex

    if chainResetOrFirstOrder or numOrdersChanged then
        for _, portrait in pairs(shipList.craftPortraits) do
            if portrait.name == name and portrait.portrait.selected then
                playSound("interface/confirm_order", SoundType.UI, 0.35)
                break
            end
        end
    end

end


function MapCommands.hideOrderButtons()
    for _, button in pairs(shipList.orderButtons) do
        button:hide()
    end

    for _, window in pairs(orderWindows) do
        window:hide()
    end
end

function MapCommands.makePortraits(faction)
    if not valid(faction) then return end

    for i, name in pairs({faction:getShipNames()}) do
        if not faction:getShipDestroyed(name) then
            local portraitWrapper = MapCommands.getPortrait(faction, name)

            local x, y = faction:getShipPosition(name)
            portraitWrapper.coordinates = {x=x, y=y}
        end
    end
end

function MapCommands.makePortrait(faction, name)
    local portrait = shipList.shipsContainer:createCraftPortrait(Rect(), "onPortraitPressed")
    portrait.onRightClickedFunction = "onPortraitRightClicked"
    portrait.craftName = name
    portrait.alliance = faction.isAlliance

    local icon = shipList.shipsContainer:createPicture(Rect(), "")
    icon.flipped = true
    icon.isIcon = true
    icon:hide()

    local entry = ShipDatabaseEntry(faction.index, name)
    local line = shipList.shipsContainer:createLine(vec2(), vec2())

    local info = faction:getShipOrderInfo(name)
    local portraitWrapper = {
        portrait = portrait,
        info = info,
        icon = icon,
        line = line,
        name = name,
        owner = faction.index,
        captain = entry:getCaptain(),
        picture = MapCommands.getActionIconFromInfo(info)
    }

    portraitWrapper.hide = function(self)
        self.portrait:hide()
        self.icon:hide()
        self.line:hide()
    end

    portraitWrapper.show = function(self)
        self.portrait:show()
        self.line:show()
        self.icon:show()
    end

    table.insert(shipList.craftPortraits, portraitWrapper)

    return portraitWrapper
end

function MapCommands.selectCraftsInRect(lowerX, lowerY, upperX, upperY)
    if lowerX > upperX then
        lowerX, upperX = upperX, lowerX
    end

    if lowerY > upperY then
        lowerY, upperY = upperY, lowerY
    end

    for _, portrait in pairs(shipList.craftPortraits) do
        if portrait.portrait.available then
            if portrait.coordinates.x >= lowerX and portrait.coordinates.x <= upperX and portrait.coordinates.y >= lowerY and portrait.coordinates.y <= upperY then
                portrait.portrait.selected = true
            else
                portrait.portrait.selected = false
            end
        end
    end
end

function MapCommands.highlightRunningCommandArea(portrait)
    MapCommands.requestReachableSectors(portrait.owner, portrait.name)

    local shipOwner = Galaxy():findFaction(portrait.owner)
    local ok, area = shipOwner:invokeFunction("simulation.lua", "getAreaBounds", portrait.name)
    if ok ~= 0 or not area then
        return
    end

    local cx = area.lower.x + math.floor((area.upper.x - area.lower.x) / 2)
    local cy = area.lower.y + math.floor((area.upper.y - area.lower.y) / 2)

    -- mark area
    GalaxyMap():setHighlightedArea(vec2(area.lower.x, area.lower.y), vec2(area.upper.x, area.upper.y), "32a0a0a0")

    if area.lines and #area.lines > 0 then
        MapRoutes.setCustomRoute(portrait.owner, portrait.name, area.lines)
    end
end

function MapCommands.highlightReachableSectors(reachableCoordinates)
    local highlighted = {}
    local statuses = {}
    local player = Player()

    -- visualize the area where the ship will do its thing
    for _, sector in pairs(reachableCoordinates) do
        if sector.hidden then goto continue end

        local color = "32a0a0a0"
        if sector.faction > 0 then
            local status = statuses[sector.faction]
            if not status then
                status = player:getRelationStatus(sector.faction)
                statuses[sector.faction] = status
            end

            if status == RelationStatus.War then
                color = "32ff2020"
            else
                color = "3240ffff"
            end
        end

        table.insert(highlighted, {x = sector.x, y = sector.y, color = color})

        ::continue::
    end

    GalaxyMap():setHighlightedSectors(highlighted)
end

function MapCommands.receiveReachableSectors(owner, shipName, reachableCoordinates)
    local portrait = MapCommands.getPortrait(Galaxy():findFaction(owner), shipName)
    if not portrait then return end

    MapCommands.highlightReachableSectors(reachableCoordinates)
end

function MapCommands.clearOrders()
    local remoteNotLoaded = "That sector isn't loaded yet."%_t

    for _, portrait in pairs(shipList.craftPortraits) do
        if portrait.portrait.selected then
            invokeEntityFunction(portrait.coordinates.x, portrait.coordinates.y, remoteNotLoaded, {faction = portrait.owner, name = portrait.name}, "data/scripts/entity/orderchain.lua", "clearAllOrders")
        end
    end
end

function MapCommands.enqueueOrder(order, ...)
    -- area selection does not apply in this case, hide it
    MapCommands.stopAreaSelection()

    local remoteNotLoaded = "That sector isn't loaded yet."%_t

    for _, portrait in pairs(shipList.craftPortraits) do
        if portrait.portrait.selected and portrait.portrait.available then
            portrait.hasNewOrders = true
            invokeEntityFunction(portrait.coordinates.x, portrait.coordinates.y, remoteNotLoaded, {faction = portrait.owner, name = portrait.name}, "data/scripts/entity/orderchain.lua", order, ...)
        end
    end
end

function MapCommands.runOrders()
    local remoteNotLoaded = "That sector isn't loaded yet."%_t

    for _, portrait in pairs(shipList.craftPortraits) do
        if portrait.hasNewOrders then
            portrait.hasNewOrders = nil
            invokeEntityFunction(portrait.coordinates.x, portrait.coordinates.y, remoteNotLoaded, {faction = portrait.owner, name = portrait.name}, "data/scripts/entity/orderchain.lua", "runOrders")
        end
    end
end



function MapCommands.stopAreaSelection()
    if not areaSelection then return end

    areaSelection = nil
    GalaxyMap():resetHighlightedAreas()
end

function MapCommands.getPortrait(faction, name)
    if faction.isPlayer then
        if not shipList.playerShipPortraits[name] then
            shipList.playerShipPortraits[name] = MapCommands.makePortrait(faction, name)
        end
        return shipList.playerShipPortraits[name]
    else
        if not shipList.allianceShipPortraits[name] then
            shipList.allianceShipPortraits[name] = MapCommands.makePortrait(faction, name)
        end
        return shipList.allianceShipPortraits[name]
    end
end

function MapCommands.getFirstSelectedPortrait()
    return shipList.selectedPortraits[1]
end

function MapCommands.isEnqueueing()
    return Keyboard():keyPressed(KeyboardKey.LShift) or Keyboard():keyPressed(KeyboardKey.RShift)
end

function MapCommands.getSelectionGroup(player, index)
    local result = {}
    for ship, groupIndex in pairs(player:getSelectionGroup(index)) do
        if groupIndex == index then
            local names = result[ship.factionIndex] or {}
            names[ship.name] = true

            result[ship.factionIndex] = names
        end
    end

    return result
end

function MapCommands.getSelectedShips()
    local result = {}

    for _, portrait in pairs(shipList.craftPortraits) do
        if portrait.portrait.selected then
            table.insert(result, {faction = portrait.owner, name = portrait.name, available = portrait.portrait.available})
        end
    end

    return unpack(result)
end

function MapCommands.getActionIconFromInfo(info)
    if info then
        local current = info.chain[info.currentIndex]
        if current and current.icon then
            return current.icon
        end
    end
end

function MapCommands.getLastLocationFromInfo(info)
    if not info then return end
    if not info.chain then return end

    local i = #info.chain

    while i > 0 do
        local current = info.chain[i]
        local x, y = current.x, current.y

        if x and y then return x, y end

        i = i - 1
    end

end

function MapCommands.getCommandsFromInfo(info, x, y)
    if not info then return {} end
    if not info.chain then return {} end
    if not info.coordinates then return {} end

    local cx, cy = info.coordinates.x, info.coordinates.y
    local i = info.currentIndex

    if i == 0 then i = 1 end

    local result = {}
    while i > 0 and i <= #info.chain do
        local current = info.chain[i]

        if cx == x and cy == y then
            table.insert(result, current)
        end

        if current.action == OrderType.Jump or current.action == OrderType.FlyThroughWormhole then
            cx, cy = current.x, current.y
        end

        i = i + 1
    end

    return result
end

function MapCommands.hasCommandToUndo(info)
    if not info then return false end
    if not info.chain then return false end

    -- if it's not done (index == 0)
    -- and not currently doing the last order, we can still undo orders
    -- exception: jumps can still be undone
    local active = #info.chain > 0 and not info.finished
    if active and (info.currentIndex < #info.chain
            or info.chain[#info.chain].action == OrderType.Jump
            or info.chain[#info.chain].action == OrderType.FlyThroughWormhole) then
        return true
    end

    return false
end


function MapCommands.onPlayerShipOrderInfoChanged(name, info)
    if not info then return end

    -- update UI depending on new order info
    local portrait = shipList.playerShipPortraits[name]
    if portrait then
        portrait.info = info

        local current = info.chain[info.currentIndex]
        if current and current.icon then
            portrait.picture = current.icon
        else
            portrait.picture = nil
        end
    end

    MapCommands.playOrderChainSound(name, info)
end

function MapCommands.onAllianceShipOrderInfoChanged(name, info)
    -- update UI depending on new order info
    local portrait = shipList.allianceShipPortraits[name]
    if portrait then
        portrait.info = info

        local current = info.chain[info.currentIndex]
        if current and current.icon then
            portrait.picture = current.icon
        else
            portrait.picture = nil
        end
    end

    MapCommands.playOrderChainSound(name, info)
end

function MapCommands.onShipSectorChanged(portraitWrapper, x, y)
    -- if one of the moved ships is in the selected sector, update the sector
    portraitWrapper.coordinates = {x=x, y=y}

    if portraitWrapper.portrait.selected and portraitWrapper.portrait.inSector then
        local entry = ShipDatabaseEntry(portraitWrapper.owner, portraitWrapper.name)
        if valid(entry) and entry:getAvailability() == ShipAvailability.Available then
            GalaxyMap():setSelectedCoordinates(x, y)
        end
    end
end

function MapCommands.onPlayerShipSectorChanged(name, x, y)
    if shipList.playerShipPortraits[name] then
        MapCommands.onShipSectorChanged(shipList.playerShipPortraits[name], x, y)
    end
end

function MapCommands.onAllianceShipSectorChanged(name, x, y)
    if shipList.allianceShipPortraits[name] then
        MapCommands.onShipSectorChanged(shipList.allianceShipPortraits[name], x, y)
    end
end

function MapCommands.onGalaxyMapKeyboardEvent(key, pressed)
    if not pressed and (key == KeyboardKey.LShift or key == KeyboardKey.RShift) and not MapCommands.isEnqueueing() then
        MapCommands.runOrders()
    end

    local galaxyMap = GalaxyMap()

    if pressed and key == KeyboardKey._A and not MapCommands.isCommandWindowVisible() then
        local shift = Keyboard().shiftPressed
        if Keyboard().controlPressed then
            for _, portrait in pairs(shipList.craftPortraits) do
                if portrait.onScreen then
                    portrait.portrait.selected = not shift
                end
            end
        end
    end

    if pressed and (key == KeyboardKey._F or key == KeyboardKey.Space) then
        for _, portrait in pairs(shipList.selectedPortraits) do
            if portrait.coordinates and not portrait.inRift then
                galaxyMap:setSelectedCoordinates(portrait.coordinates.x, portrait.coordinates.y)
                galaxyMap:lookAtSmooth(portrait.coordinates.x, portrait.coordinates.y)
                break
            end
        end
    end

    -- handle selection groups
    local player = Player()
    if pressed and player then
        local groupIndex
        if key >= KeyboardKey._1 and key <= KeyboardKey._9 then
            groupIndex = key - KeyboardKey._1 + 1
        end

        if key == KeyboardKey._0 then
            groupIndex = 0
        end

        if groupIndex then
            if Keyboard().controlPressed then
                -- assign new group
                local group = {}
                for _, portrait in pairs(shipList.craftPortraits) do
                    if portrait.portrait.selected then
                        table.insert(group, {factionIndex = portrait.owner, name = portrait.name})
                    end
                end

                player:setSelectionGroup(groupIndex, group)

            elseif not MapCommands.isCommandWindowVisible() then
                -- select group, but not if a command window is visible
                local nameByFaction = MapCommands.getSelectionGroup(player, groupIndex)

                for _, portrait in pairs(shipList.craftPortraits) do
                    if nameByFaction[portrait.owner] and nameByFaction[portrait.owner][portrait.name] then
                        -- select the crafts that belong to group 'groupIndex'
                        portrait.portrait.selected = true
                    else
                        -- add to selection if shift is pressed, replace otherwise
                        if not Keyboard().shiftPressed then
                            portrait.portrait.selected = false
                        end
                    end
                end
            end
        end
    end
end

function MapCommands.onGalaxyMapKeyboardDown(key, repeating)
    local galaxyMap = GalaxyMap()

    if key == KeyboardKey.Escape then
        if areaSelection then
            galaxyMap:resetHighlightedAreas()
            areaSelection = nil
            return true
        end

        local shipDeselected
        for _, portrait in pairs(shipList.selectedPortraits) do
            portrait.portrait.selected = false
            shipDeselected = true
        end

        if shipDeselected then return true end
    end

end

function MapCommands.onGalaxyMapMouseDown(button, mx, my, cx, cy)
    if areaSelection then
        if button == MouseButton.Left then
            if areaSelection.valid then
                -- confirm area selection
                areaSelection.commandCallback(areaSelection.area)
                areaSelection = nil
            else
                if areaSelection.command.getAreaSelectionTooltip then
                    local errorMessage = areaSelection.command:getAreaSelectionTooltip(areaSelection.craftOwner, areaSelection.craftName, areaSelection.area, areaSelection.valid)
                    displayChatMessage(errorMessage, "", 1)
                end
            end
        elseif button == MouseButton.Right then
            -- cancel area selection
            GalaxyMap():resetHighlightedAreas()
            areaSelection.cancelling = true
        end

        return true
    end

    if button == MouseButton.Right and #shipList.selectedPortraits > 0 then
        -- consume right click if at least one craft is selected to prevent opening the context menu
        return true
    end

    if button == MouseButton.Left and not MapCommands.isCommandWindowVisible() then
        rectSelection = {mouseStart = {x = mx, y = my}, sectorStart = {x = cx, y = cy}}
    end

    return false
end

function MapCommands.onGalaxyMapMouseUp(button, mx, my, cx, cy, mapMoved)
    if areaSelection and areaSelection.cancelling then
        if not mapMoved then
            -- the user didn't move the map - stop area selection
            MapCommands.stopAreaSelection()

        else
            -- moving the map should not interfere with area selection - don't cancel
            areaSelection.cancelling = false
        end

        -- eat up one mouse up
        -- otherwise cancelling area selection by right click also issues a jump order
        return
    end

    if not shipList.frame.mouseOver then
        if button == MouseButton.Right and #shipList.selectedPortraits > 0 and not mapMoved then
            MapCommands.enqueueJump(cx, cy)
            return
        end
    end

    if button == MouseButton.Left and not MapCommands.isCommandWindowVisible() then
        if rectSelection then
            if math.abs(rectSelection.mouseStart.x - mx) > 1 or math.abs(rectSelection.mouseStart.y - my) > 1 then
                MapCommands.selectCraftsInRect(rectSelection.sectorStart.x, rectSelection.sectorStart.y, cx, cy)
                rectSelection = nil
                return
            end

            rectSelection = nil

            -- left mouse up on the map -> clear selection
            for _, portrait in pairs(shipList.craftPortraits) do
                portrait.portrait.selected = false
            end
        end
    end

end

function MapCommands.onGalaxyMapMouseMove(mx, my, dx, dy, dz)
    if shipList.frame.mouseOver and dz ~= 0 then
        shipList.scrollPosition = shipList.scrollPosition - dz
        return true
    end

    return false
end

function MapCommands.onMapRenderAfterLayers()
    if rectSelection then
        local renderer = UIRenderer()
        renderer:renderBorder(vec2(rectSelection.mouseStart.x, rectSelection.mouseStart.y), Mouse().position, ColorRGB(1, 1, 1), 0)
        renderer:display()
    end

    if areaSelection then
        local text = nil
        if areaSelection.command.getAreaSelectionTooltip then
            text = areaSelection.command:getAreaSelectionTooltip(areaSelection.craftOwner, areaSelection.craftName, areaSelection.area, areaSelection.valid)
        end

        if not text then
            if areaSelection.valid then
                text = "Left-Click to select the target area"%_t
            else
                text = "Invalid Location!"%_t
            end
        end

        local tooltip = Tooltip()
        local line = TooltipLine(13, 13)
        line.ltext = text
        tooltip:addLine(line)

        local renderer = TooltipRenderer(tooltip)

        local mx, my = GalaxyMap():getHoveredCoordinates()
        local sx, sy = GalaxyMap():getCoordinatesScreenPosition(ivec2(mx, my))

        renderer:drawMouseTooltip(vec2(sx, sy))
    end

    if contextSensitiveRMB then
        if contextSensitiveRMB.inRange then

            local playerPiloted
            for _, portrait in pairs(shipList.selectedPortraits) do
                if portrait.playerPiloted then
                    playerPiloted = true
                end
            end

            if not playerPiloted then
                local mx, my = GalaxyMap():getHoveredCoordinates()
                local sx, sy = GalaxyMap():getCoordinatesScreenPosition(ivec2(mx, my))

                local renderer = UIRenderer()
                renderer:renderPixelIcon(vec2(sx + 40, sy), ColorRGB(1, 1, 1), "data/textures/icons/pixel/right-mouse.png", nil, nil)
                renderer:display()

                local text = "Jump"%_t
                if MapCommands.isEnqueueing() then
                    text = text .. "   " .. "Enchaining"%_t
                else
                    text = text .. "   " .. "[SHIFT] Enchain"%_t
                end
                drawText(text, sx + 65, sy, ColorRGB(0.6, 0.6, 0.6), 14, false, false, 2)
            end
        end
    end
end

function MapCommands.onShowGalaxyMap()
    local player = Player()
    local alliance = player.alliance
    if alliance then
        alliance:registerCallback("onShipOrderInfoUpdated", "onAllianceShipOrderInfoChanged")
        alliance:registerCallback("onShipPositionUpdated", "onAllianceShipSectorChanged")
    end

    local x, y = GalaxyMap():getSelectedCoordinates()

    shipList.shipsContainer:clear()
    shipList.craftPortraits = {}
    shipList.playerShipPortraits = {}
    shipList.allianceShipPortraits = {}

    MapCommands.makePortraits(player)
    MapCommands.makePortraits(alliance)
end

function MapCommands.onHideGalaxyMap()
    MapCommands.runOrders()

    local hud = Hud()
    hud.notificationsVisible = true
    hud:setCursor(nil)
end

function MapCommands.onPortraitPressed(pressedPortrait)
    if MapCommands.isCommandWindowVisible() then return end

    if shipList.doubleClickTimer
            and shipList.doubleClickTimer.index == pressedPortrait.index
            and appTime() - shipList.doubleClickTimer.time < 0.5 then

        for _, portrait in pairs(shipList.craftPortraits) do
            if portrait.portrait.index == pressedPortrait.index and portrait.coordinates then
                local galaxyMap = GalaxyMap()

                if not portrait.inRift then
                    galaxyMap:setSelectedCoordinates(portrait.coordinates.x, portrait.coordinates.y)
                end
                galaxyMap:lookAtSmooth(portrait.coordinates.x, portrait.coordinates.y)

                pressedPortrait.selected = true

                -- reset doubleclick timer
                shipList.doubleClickTimer = nil

                MapCommands.highlightRunningCommandArea(portrait)
                return
            end
        end
    else
        -- start doubleclick timer
        shipList.doubleClickTimer = {
            index = pressedPortrait.index,
            time = appTime()
        }
    end

    local otherPortraitsSelected = false
    if not Keyboard().controlPressed then
        -- deselect all portraits
        for _, portrait in pairs(shipList.selectedPortraits) do
            if portrait.portrait.index ~= pressedPortrait.index then
                portrait.portrait.selected = false
                otherPortraitsSelected = true
            end
        end
    end

    if otherPortraitsSelected then
        pressedPortrait.selected = true
    else
        pressedPortrait.selected = not pressedPortrait.selected
    end

    if pressedPortrait.selected and not pressedPortrait.available then
        local wrapper = nil
        for _, portrait in pairs(shipList.craftPortraits) do
            if portrait.portrait.index == pressedPortrait.index then
                wrapper = portrait
                break
            end
        end

        MapCommands.highlightRunningCommandArea(wrapper)
    else
        GalaxyMap():resetHighlightedAreas()
    end
end

function MapCommands.onPortraitRightClicked(pressedPortrait)
    if MapCommands.isCommandWindowVisible() then return end

    local craftPortrait

    for _, portrait in pairs(shipList.craftPortraits) do
        if portrait.portrait.available and portrait.portrait.index == pressedPortrait.index and portrait.coordinates then
            craftPortrait = portrait
        end
    end

    if craftPortrait == nil then return end

    shipList.portraitContextMenu:clear()
    shipList.portraitContextMenu:addEntry("Focus"%_t, 1, "onFocusShipClicked")

    local x, y = Sector():getCoordinates()
    if craftPortrait.coordinates.x == x and craftPortrait.coordinates.y == y then
        shipList.portraitContextMenu:addEntry("Manage"%_t, 1, "onManageCraftClicked")
    end

    shipList.portraitContextMenu:addEntry(string.format("Switch to '%s'"%_t, craftPortrait.name), 1, "onSwitchToCraftClicked")
    shipList.portraitContextMenu:addEntry("Switch to Sector"%_t, 1, "onSwitchToSectorClicked")
    shipList.portraitContextMenu:show(Mouse().position, false)

    local player = Player()

    function MapCommands.onFocusShipClicked()
        GalaxyMap():lookAtSmooth(craftPortrait.coordinates.x, craftPortrait.coordinates.y)
    end

    function MapCommands.onManageCraftClicked()
        local craft = Sector():getEntityByFactionAndName(craftPortrait.owner, craftPortrait.name)
        if not craft then return end

        ShipWindow():show(craft.id)
        GalaxyMap():hide()
    end

    function MapCommands.onSwitchToCraftClicked()
        GalaxyMap():switchToCraft(craftPortrait.coordinates.x, craftPortrait.coordinates.y, craftPortrait.owner, craftPortrait.name);
    end

    function MapCommands.onSwitchToSectorClicked()
        GalaxyMap():switchToSector(craftPortrait.coordinates.x, craftPortrait.coordinates.y);
    end
end


function MapCommands.onStopPressed()
    -- clean up current highlights and routes
    local map = GalaxyMap()
    map:resetHighlightedAreas()

    for _, portrait in pairs({MapCommands.getSelectedShips()}) do
        MapRoutes.clearRoute(portrait.faction, portrait.name)
    end

    MapCommands.enqueueOrder("clearAllOrders")
end

function MapCommands.onScrollUpButtonPressed()
    shipList.scrollPosition = shipList.scrollPosition - 1
    if shipList.scrollPosition < 0 then shipList.scrollPosition = 0 end
end

function MapCommands.onScrollDownButtonPressed()
    shipList.scrollPosition = shipList.scrollPosition + 1
    local count = #shipList.listedPortraits - shipList.numVisiblePortraits
    if count < 0 then count = 0 end
    if shipList.scrollPosition > count then shipList.scrollPosition = count end
end

function MapCommands.onToggleStationsButtonPressed(button)
    shipList.stationsVisible = not shipList.stationsVisible
    MapCommands.refreshButtonOverlays(button, shipList.stationsVisible)
    MapCommands.syncShipListButtonStates()
end

function MapCommands.onToggleOffscreenButtonPressed(button)
    shipList.offscreenShipsVisible = not shipList.offscreenShipsVisible
    MapCommands.refreshButtonOverlays(button, shipList.offscreenShipsVisible)
    MapCommands.syncShipListButtonStates()
end

function MapCommands.onToggleBGSButtonPressed(button)
    shipList.backgroundShipsVisible = not shipList.backgroundShipsVisible
    MapCommands.refreshButtonOverlays(button, shipList.backgroundShipsVisible)
    MapCommands.syncShipListButtonStates()
end

function MapCommands.refreshButtonOverlays(button, enabled)
    if enabled then
        button.overlayIcon = ""
    else
        button.overlayIcon = "data/textures/icons/cross-mark.png"
        button.overlayIconAlignment = 5
        button.overlayIconColor = ColorRGB(1, 0.3, 0.3)
        button.overlayIconSizeFactor = 0.8
        button.overlayIconPadding = 0
    end
end

function MapCommands.onRecallPressed()
    -- show confirmation window
    recallConfirmationWindow:show()
end

function MapCommands.onRecallCanceled()
    recallConfirmationWindow:hide()
end

function MapCommands.onRecallConfirmed()
    -- recall selected ships
    for _, portrait in pairs(shipList.craftPortraits) do
        if portrait.portrait.selected and not portrait.portrait.available then
            local shipOwner = Galaxy():findFaction(portrait.owner)
            local ok = shipOwner:invokeFunction("simulation.lua", "recall", portrait.name)
        end
    end

    -- close window
    recallConfirmationWindow:hide()
end

function MapCommands.startAreaAnalysis(owner, shipName, commandType, area)
    -- alliance scripts run in a separate thread on the server (than the player scripts) and are not synced to the client
    -- we're using the player's simulation.lua as a proxy to forward requests to the alliance on the server
    local shipOwner = Galaxy():findFaction(owner)
    shipOwner:invokeFunction("data/scripts/player/background/simulation/simulation.lua", "startAreaAnalysis", shipName, commandType, area)
end

function MapCommands.onAreaAnalysisFinished(ownerIndex, shipName, commandType, area, results)

    local interface = backgroundCommandInterfaces[commandType]
    if not interface then return end

    if interface.ui.window.visible then
        area.analysis = results
        interface.ui.current.area = area
        interface.ui:refresh(ownerIndex, shipName, area, nil --[[ config is nil so UI gets reset to default values ]])

        MapCommands.highlightReachableSectors(area.analysis.reachableCoordinates)
    end
end

end -- onClient()

function MapCommands.syncShipListButtonStates(data)
    if data then
        shipList.stationsVisible = data.stationsVisible
        shipList.offscreenShipsVisible = data.offscreenShipsVisible
        shipList.backgroundShipsVisible = data.backgroundShipsVisible

        if onClient() then
            -- immediately set visual state as well
            MapCommands.refreshButtonOverlays(stationsVisibleButton, shipList.stationsVisible)
            MapCommands.refreshButtonOverlays(offscreenShipsVisibleButton, shipList.offscreenShipsVisible)
            MapCommands.refreshButtonOverlays(backgroundShipsVisibleButton, shipList.backgroundShipsVisible)
        end

        return
    end

    local data = {
        stationsVisible = shipList.stationsVisible,
        offscreenShipsVisible = shipList.offscreenShipsVisible,
        backgroundShipsVisible = shipList.backgroundShipsVisible
    }

    if onServer() then
        invokeClientFunction(Player(), "syncShipListButtonStates", data)
    else
        invokeServerFunction("syncShipListButtonStates", data)
    end
end
callable(MapCommands, "syncShipListButtonStates")

-- save shipList toggle buttons configuration
function MapCommands.secure()
    local data = {}
    data.stationsVisible = shipList.stationsVisible
    data.offscreenShipsVisible = shipList.offscreenShipsVisible
    data.backgroundShipsVisible = shipList.backgroundShipsVisible
    return data
end

function MapCommands.restore(data)
    shipList.stationsVisible = data.stationsVisible
    shipList.offscreenShipsVisible = data.offscreenShipsVisible
    shipList.backgroundShipsVisible = data.backgroundShipsVisible
    deferredCallback(3.0, "syncShipListButtonStates") -- wait for client to be here before trying to sync
end

if onServer() then

-- server gets a special interface here for testing
MapCommands.enqueueing = false
function MapCommands.isEnqueueing()
    return enqueueing
end

MapCommands.names = {}
function MapCommands.setNames(names)
    MapCommands.names = names or {}
end

function MapCommands.clearOrders()
    local player = Player()
    for _, name in pairs(MapCommands.names) do
        local x, y = player:getShipPosition(name)
        invokeEntityFunction(x, y, nil, {faction = player.index, name = name}, "data/scripts/entity/orderchain.lua", "clearAllOrders")
    end
end

function MapCommands.enqueueOrder(order, ...)
    local player = Player()
    for _, name in pairs(MapCommands.names) do
        local x, y = player:getShipPosition(name)
        invokeEntityFunction(x, y, nil, {faction = player.index, name = name}, "data/scripts/entity/orderchain.lua", order, ...)
    end
end

function MapCommands.runOrders()
    local player = Player()
    for _, name in pairs(MapCommands.names) do
        local x, y = player:getShipPosition(name)
        invokeEntityFunction(x, y, nil, {faction = player.index, name = name}, "data/scripts/entity/orderchain.lua", "runOrders")
    end
end

end


-- common for both client and server (mostly for testing)
function MapCommands.clearOrdersIfNecessary(clear)
    if clear == nil then
        if not MapCommands.isEnqueueing() then MapCommands.clearOrders() end
    elseif clear then
        MapCommands.clearOrders()
    end
end

function MapCommands.requestReachableSectors(owner, shipName)
    local shipOwner = Galaxy():findFaction(owner)
    if not shipOwner then return end

    shipOwner:invokeFunction("data/scripts/player/background/simulation/simulation.lua", "requestReachableSectors", shipName)
end

function MapCommands.enqueueJump(x, y)
    if MapCommands.isCommandWindowVisible() then return end

    -- don't enqueue jump orders for background ships
    local portrait = MapCommands.getFirstSelectedPortrait()
    if not portrait.portrait.available then return end

    MapCommands.clearOrdersIfNecessary()
    MapCommands.enqueueOrder("addJumpOrder", x, y)
    if not MapCommands.isEnqueueing() then MapCommands.runOrders() end
end

function MapCommands.onUndoPressed()
    if MapCommands.isCommandWindowVisible() then return end

    MapCommands.enqueueOrder("undoOrder", x, y)
end

function MapCommands.onPatrolPressed()
    if MapCommands.isCommandWindowVisible() then return end

    MapCommands.clearOrdersIfNecessary()
    MapCommands.enqueueOrder("addPatrolOrder")
    if not MapCommands.isEnqueueing() then MapCommands.runOrders() end
end

function MapCommands.onAggressivePressed()
    if MapCommands.isCommandWindowVisible() then return end

    local attackCivilShips = true
    local canFinish = false

    MapCommands.clearOrdersIfNecessary()
    MapCommands.enqueueOrder("addAggressiveOrder", attackCivilShips, canFinish)
    if not MapCommands.isEnqueueing() then MapCommands.runOrders() end
end

function MapCommands.onRepairPressed()
    if MapCommands.isCommandWindowVisible() then return end

    MapCommands.clearOrdersIfNecessary()
    MapCommands.enqueueOrder("addRepairOrder")
    if not MapCommands.isEnqueueing() then MapCommands.runOrders() end
end

-- this needs to be in common part of script because of Unit tests
function MapCommands.isCommandWindowVisible()
    for _, window in pairs(orderWindows) do
        if window.visible then return true end
    end

    return false
end
