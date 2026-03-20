package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("entity/stationfounder")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace DerelictStationFounder
DerelictStationFounder = StationFounder
DerelictStationFounder.priceFactor = 0.5

function DerelictStationFounder.initUI()
    local res = getResolution()
    local size = vec2(650, 625)

    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))

    window.caption = "Rebuild Station"%_t
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "Rebuild Station"%_t, 5);

    local splitter = UIVerticalSplitter(Rect(vec2(), vec2(size.x, 60)), 10, 10, 0.5)
    splitter:setLeftQuadratic()
    local infoIcon = window:createPicture(splitter.left, "data/textures/icons/info.png")
    infoIcon.isIcon = true
    local infoLabel = window:createLabel(splitter.right, "The facilities in this station were destroyed in a boarding attack."%_t, 14)
    infoLabel:setLeftAligned()

    -- create a tabbed window inside the main window
    local tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 60), size - 10))

    -- create buy tab
    local buyTab0 = tabbedWindow:createTab("Basic"%_t, "data/textures/icons/station.png", "Basic Factories"%_t)
    local buyTab1 = tabbedWindow:createTab("Low"%_t, "data/textures/icons/station.png", "Low Tech Factories"%_t)
    local buyTab2 = tabbedWindow:createTab("Advanced"%_t, "data/textures/icons/station.png", "Advanced Factories"%_t)
    local buyTab3 = tabbedWindow:createTab("High"%_t, "data/textures/icons/station.png", "High Tech Factories"%_t)
    local buyTab4 = tabbedWindow:createTab("Other Stations"%_t, "data/textures/icons/stars-stack.png", "Other Stations"%_t)

    DerelictStationFounder.buildMiscStationGui(buyTab4)
    DerelictStationFounder.buildFactoryGui({0}, buyTab0)
    DerelictStationFounder.buildFactoryGui({1, 2, 3}, buyTab1)
    DerelictStationFounder.buildFactoryGui({4, 5, 6}, buyTab2)
    DerelictStationFounder.buildFactoryGui({7, 8, 9}, buyTab3)

    -- warn box
    local size = vec2(550, 290)
    local warnWindow = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    DerelictStationFounder.warnWindow = warnWindow
    warnWindow.caption = "Confirm Rebuilding"%_t
    warnWindow.showCloseButton = 1
    warnWindow.moveable = 1
    warnWindow.visible = false

    local hsplit = UIHorizontalSplitter(Rect(vec2(), warnWindow.size), 10, 10, 0.5)
    hsplit.bottomSize = 40

    warnWindow:createFrame(hsplit.top)

    local ihsplit = UIHorizontalSplitter(hsplit.top, 10, 10, 0.5)
    ihsplit.topSize = 20

    local label = warnWindow:createLabel(ihsplit.top.lower, "Warning"%_t, 16)
    label.size = ihsplit.top.size
    label.bold = true
    label.color = ColorRGB(0.8, 0.8, 0)
    label:setTopAligned();

    local warnWindowLabel = warnWindow:createLabel(ihsplit.bottom.lower, "Text"%_t, 14)
    DerelictStationFounder.warnWindowLabel = warnWindowLabel
    warnWindowLabel.size = ihsplit.bottom.size
    warnWindowLabel:setTopAligned();
    warnWindowLabel.wordBreak = true
    warnWindowLabel.fontSize = 14


    local vsplit = UIVerticalSplitter(hsplit.bottom, 10, 0, 0.5)
    warnWindow:createButton(vsplit.left, "OK"%_t, "onConfirmTransformationButtonPress")
    warnWindow:createButton(vsplit.right, "Cancel"%_t, "onCancelTransformationButtonPress")

    DerelictStationFounder.updateRedesignButtons()
end

function DerelictStationFounder.onFoundFactoryButtonPress(button)
    DerelictStationFounder.selectedProduction = DerelictStationFounder.productionsByButton[button.index]
    DerelictStationFounder.selectedStation = nil

    DerelictStationFounder.warnWindowLabel.caption = "This action is irreversible."%_t .."\n\n" ..
        "You're about to turn your station into a ${factory}.\n"%_t % {factory = getTranslatedFactoryName(DerelictStationFounder.selectedProduction.production)} ..
        "If required, it will receive production extensions.\n"%_t ..
        "Due to a systems change, all turrets will be removed from your station."%_t .. "\n\n" ..
        "Building a station expands your influence in this sector. Taking over a sector impacts your relations with the local faction."%_t

    DerelictStationFounder.warnWindow:show()
end

function DerelictStationFounder.onFoundStationButtonPress(button)
    DerelictStationFounder.selectedStation = DerelictStationFounder.stationsByButton[button.index]
    DerelictStationFounder.selectedProduction = nil

    local template =  DerelictStationFounder.stations[DerelictStationFounder.selectedStation]

    DerelictStationFounder.warnWindowLabel.caption = "This action is irreversible."%_t .."\n\n" ..
        "You're about to turn your station into a ${stationName}.\n"%_t % {stationName = template.name} ..
        "If required, it will receive production extensions.\n"%_t ..
        "Due to a systems change, all turrets will be removed from your station."%_t .. "\n\n" ..
        "Building a station expands your influence in this sector. Taking over a sector impacts your relations with the local faction."%_t

    DerelictStationFounder.warnWindow:show()
end
