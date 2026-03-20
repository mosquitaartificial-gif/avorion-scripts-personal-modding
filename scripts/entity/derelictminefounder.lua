package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("entity/minefounder")
include ("reconstructionutility")
include ("callable")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace DerelictMineFounder
DerelictMineFounder = MineFounder
DerelictMineFounder.priceFactor = 0.5

function DerelictMineFounder.initUI()
    local res = getResolution()
    local size = vec2(650, 625)

    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))

    window.caption = "Rebuild Mine"%_t
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "Rebuild Mine"%_t, 5);

    local splitter = UIVerticalSplitter(Rect(vec2(), vec2(size.x, 60)), 10, 10, 0.5)
    splitter:setLeftQuadratic()
    local infoIcon = window:createPicture(splitter.left, "data/textures/icons/info.png")
    infoIcon.isIcon = true
    local infoLabel = window:createLabel(splitter.right, "The facilities in this station were destroyed in a boarding attack."%_t, 14)
    infoLabel:setLeftAligned()

    -- create a tabbed window inside the main window
    local tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 60), size - 10))

    -- create buy tab
    local buyTab = tabbedWindow:createTab("Basic"%_t, "data/textures/icons/bag.png", "Mines"%_t)
    MineFounder.buildGui({0}, buyTab)

    -- warn box
    local size = vec2(550, 290)
    local warnWindow = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    DerelictMineFounder.warnWindow = warnWindow
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
    DerelictMineFounder.warnWindowLabel = warnWindowLabel
    warnWindowLabel.size = ihsplit.bottom.size
    warnWindowLabel:setTopAligned();
    warnWindowLabel.wordBreak = true
    warnWindowLabel.fontSize = 14


    local vsplit = UIVerticalSplitter(hsplit.bottom, 10, 0, 0.5)
    warnWindow:createButton(vsplit.left, "OK"%_t, "onConfirmTransformationButtonPress")
    warnWindow:createButton(vsplit.right, "Cancel"%_t, "onCancelTransformationButtonPress")


end

function DerelictMineFounder.onFoundFactoryButtonPress(button)
    DerelictMineFounder.selectedProduction = DerelictMineFounder.productionsByButton[button.index]
    DerelictMineFounder.selectedStation = nil

    DerelictMineFounder.warnWindowLabel.caption = "This action is irreversible."%_t .."\n\n" ..
        "You're about to turn your mine into a ${factory}.\n"%_t % {factory = getTranslatedFactoryName(DerelictMineFounder.selectedProduction.production)} ..
        "Due to a systems change, all turrets will be removed from your station."%_t .. "\n\n" ..
        "Building a station expands your influence in this sector. Taking over a sector impacts your relations with the local faction."%_t

    DerelictMineFounder.warnWindow:show()
end

function DerelictMineFounder.onConfirmTransformationButtonPress(button)
    if not DerelictMineFounder.selectedProduction.goodName then return end
    if not DerelictMineFounder.selectedProduction.index then return end

    invokeServerFunction("foundFactory", DerelictMineFounder.selectedProduction.goodName, DerelictMineFounder.selectedProduction.index, name)
end
callable(DerelictMineFounder, "foundFactory")

function DerelictMineFounder.transformToStation(buyer, name)

    local ship = Entity()
    local player = Player(callingPlayer)

    local malusFactor, malusReason = ship:getMalusFactor()

    -- transform ship into station
    -- has to be at least 2 km from the nearest station
    local sector = Sector()

    local stations = {sector:getEntitiesByType(EntityType.Station)}
    local ownSphere = ship:getBoundingSphere()
    local minDist = 300
    local tooNear

    for _, station in pairs(stations) do
        if station.id ~= ship.id then
            local sphere = station:getBoundingSphere()

            local d = distance(sphere.center, ownSphere.center) - sphere.radius - ownSphere.radius
            if d < minDist then
                tooNear = true
                break
            end
        end
    end

    if tooNear then
        player:sendChatMessage("", 1, "You're too close to another station."%_t)
        return
    end

    local maxDist = 23000
    if distance(ownSphere.center, vec3(0, 0, 0)) > maxDist then
        player:sendChatMessage("", 1, "You're too far out to found a station."%_t)
        return
    end

    -- create the station
    -- get plan of ship
    local plan = ship:getMovePlan()
    local crew = ship.crew

    -- create station
    local desc = StationDescriptor()
    desc.factionIndex = ship.factionIndex
    desc:setMovePlan(plan)
    desc.position = ship.position
    desc.name = ship.name

    ship.name = ""

    local station = Sector():createEntity(desc)
    Physics(station).driftDecrease = 0.2

    AddDefaultStationScripts(station)
    SetBoardingDefenseLevel(station)

    -- move player from ship to station
    if player.craftIndex == ship.index then
        player.craftIndex = station.index
    end

    for i = 0, 20 do
        local upgrade = ShipSystem():getUpgrade(i)
        -- only drop permament upgrades here, because deleting the ship first changes
        -- block plan and drops all non-permanent ones
        if upgrade and ShipSystem():isPermanent(i) then
            Sector():dropUpgrade(ship.translationf, player, nil, upgrade)
        end
    end

    -- this will delete the ship and deactivate the collision detection so the ship doesn't interfere with the new station
    ship:setPlan(BlockPlan())

    buyer:setShipDestroyed("", true)
    buyer:removeDestroyedShipInfo("")

    removeReconstructionKits(buyer, name)

    -- assign all values of the ship
    -- crew
    station.crew = crew
    station.shieldDurability = ship.shieldDurability
    station:setMalusFactor(malusFactor, malusReason)

    -- add insurance
    station:addScriptOnce("insurance.lua")

    -- update sector contents, check if the sector's controlling faction changed
    Sector():invokeFunction("data/scripts/sector/background/sectorcontentsupdater.lua", "updateServer")

    return station
end

