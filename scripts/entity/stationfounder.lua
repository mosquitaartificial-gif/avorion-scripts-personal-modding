package.path = package.path .. ";data/scripts/lib/?.lua"
include ("galaxy")
include ("utility")
include ("faction")
include ("productions")
include ("stringutility")
include ("goods")
include ("defaultscripts")
include ("merchantutility")
include ("callable")
include ("reconstructionutility")
include ("defaultscripts")
include ("randomext")
include ("relations")
local ConsumerGoods = include ("consumergoods")
local PlanGenerator = include ("plangenerator")
local ShipFounding = include ("shipfounding")
local Dialog = include("dialogutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace StationFounder
StationFounder = {}

StationFounder.productionsByButton = {}
StationFounder.stationsByButton = {}
StationFounder.selectedProduction = {}
StationFounder.selectedStation = nil
StationFounder.priceFactor = 1

StationFounder.warnWindow = nil
StationFounder.warnWindowLabel = nil

StationFounder.calculateConsumerValue = function(collected)
    local sum = 0

    for _, name in pairs(collected) do
        local good = goods[name]
        if good then
            sum = sum + good.price
        end
    end

    local base = 4000000

    return base + round(math.sqrt(sum * 2500) / 10) * 8000
end

StationFounder.stations =
{
    {
        name = "Biotope"%_t,
        tooltip = "The population on this station buys and consumes a range of organic goods. These goods can be picked up for free by the owner of the station. Attracts NPC traders."%_t,
        scripts = {{script = "data/scripts/entity/merchants/biotope.lua"}},
        getPrice = function()
            return StationFounder.calculateConsumerValue({"Food", "Food Bar", "Fungus", "Wood", "Glass", "Sheep", "Cattle", "Wheat", "Corn", "Rice", "Vegetable", "Water", "Coal"})
        end
    },
    {
        name = "Casino"%_t,
        tooltip = "The population on this station buys and consumes a range of luxury goods. These goods can be picked up for free by the owner of the station. Attracts NPC traders."%_t,
        scripts = {{script = "data/scripts/entity/merchants/casino.lua"}},
        getPrice = function()
            return StationFounder.calculateConsumerValue({"Beer", "Wine", "Liquor", "Food", "Luxury Food", "Water", "Medical Supplies"})
        end
    },
    {
        name = "Habitat"%_t,
        tooltip = "The population on this station buys and consumes a range of common day-to-day goods. These goods can be picked up for free by the owner of the station. Attracts NPC traders."%_t,
        scripts = {{script = "data/scripts/entity/merchants/habitat.lua"}},
        getPrice = function()
            return StationFounder.calculateConsumerValue({"Beer", "Wine", "Liquor", "Food", "Tea", "Luxury Food", "Spices", "Vegetable", "Fruit", "Cocoa", "Coffee", "Wood", "Meat", "Water"})
        end
    },
    {
        name = "Equipment Dock"%_t,
        tooltip = "Buys and sells subsystems, turrets and fighters. The owner of the equipment dock gets 20% of the money of every transaction, as well as cheaper prices."%_t .. "\n\n" ..
                  "The population on this station buys and consumes a range of technological goods. These goods can be picked up for free by the owner of the station. Attracts NPC traders."%_t,
        scripts = {
            {script = "data/scripts/entity/merchants/equipmentdock.lua"},
            {script = "data/scripts/entity/merchants/turretmerchant.lua"},
            {script = "data/scripts/entity/merchants/fightermerchant.lua"},
            {script = "data/scripts/entity/merchants/torpedomerchant.lua"},
            {script = "data/scripts/entity/merchants/utilitymerchant.lua"},
            {script = "data/scripts/entity/merchants/consumer.lua", args = {"Equipment Dock"%_t, unpack(ConsumerGoods.EquipmentDock())}},
        },
        getPrice = function()
            return 20000000 +
                StationFounder.calculateConsumerValue({"Equipment Dock"%_t, unpack(ConsumerGoods.EquipmentDock())})
        end
    },
    {
        name = "Fighter Factory"%_t,
        tooltip = "Produces custom fighters. The owner of the factory gets 20% of the money of every transaction, as well as cheaper prices."%_t,
        scripts = {{script = "data/scripts/entity/merchants/fighterfactory.lua"}},
        price = 30000000
    },
    -- {
    --     name = "Headquarters"%_t,
    --     tooltip = "Can be used as headquarters for an alliance. [Not yet implemented.]"%_t,
    --     scripts = {{script = "data/scripts/entity/merchants/headquarters.lua"}},
    --     price = 5000000
    -- },
    {
        name = "Research Station"%_t,
        tooltip = "Subsystems and turrets can be researched here to get better subsystems and turrets."%_t .. "\n\n" ..
                  "The population of this station buys and consumes a range of science goods. These goods can be picked up for free by the owner of the station. Attracts NPC traders."%_t,
        scripts = {
            {script = "data/scripts/entity/merchants/researchstation.lua"},
            {script = "data/scripts/entity/merchants/consumer.lua", args = {"Research Station"%_t, unpack(ConsumerGoods.ResearchStation())}},
        },
        getPrice = function()
            return 4000000 +
                    StationFounder.calculateConsumerValue({"Research Station"%_t, unpack(ConsumerGoods.ResearchStation())})
        end
    },
    {
        name = "Travel Hub"%_t,
        tooltip = "Provides boosts for traveling."%_t .. "\n\n" ..
                  "The population of this station buys and consumes a range of science goods. These goods can be picked up for free by the owner of the station. Attracts NPC traders."%_t,
        scripts = {
            {script = "data/scripts/entity/merchants/travelhub.lua"},
            {script = "data/scripts/entity/merchants/consumer.lua", args = {"Travel Hub"%_t, unpack(ConsumerGoods.TravelHub())}},
        },
        getPrice = function()
            return 4000000 +
                    StationFounder.calculateConsumerValue({"Research Station"%_t, unpack(ConsumerGoods.ResearchStation())})
        end
    },
    {
        name = "Resource Depot"%_t,
        tooltip = "Sells and buys resources such as Iron or Titanium and the like. The owner gets 20% of every transaction, as well as cheaper prices."%_t,
        scripts = {{script = "data/scripts/entity/merchants/resourcetrader.lua"}},
        price = 12500000
    },
    {
        name = "Smuggler's Market"%_t,
        tooltip = "Sells and buys stolen and other illegal goods. The owner gets 20% of every transaction, as well as cheaper prices."%_t,
        scripts = {{script = "data/scripts/entity/merchants/smugglersmarket.lua"}},
        price = 20000000
    },
    {
        name = "Trading Post"%_t,
        tooltip = "Sells and buys a random range of goods. The owner gets 20% of every transaction, as well as cheaper prices. Attracts NPC traders."%_t,
        scripts = {{script = "data/scripts/entity/merchants/tradingpost.lua"}},
        price = 20000000
    },
    {
        name = "Turret Factory"%_t,
        tooltip = "Produces customized turrets and sells turret parts for high prices. The owner gets 20% of every transaction, as well as cheaper prices."%_t,
        scripts = {
            {script = "data/scripts/entity/merchants/turretfactory.lua"},
            {script = "data/scripts/entity/merchants/turretfactoryseller.lua", args = {"Turret Factory"%_t, unpack(ConsumerGoods.TurretFactory())}}

        },
        price = 25000000
    },
    {
        name = "Military Outpost"%_t,
        tooltip = "Provides combat missions to players."%_t .. "\n\n" ..
                  "The population on this station buys and consumes a range of military goods. These goods can be picked up for free by the owner of the station. Attracts NPC traders."%_t,
        scripts = {
            {script = "data/scripts/entity/merchants/militaryoutpost.lua"},
            {script = "data/scripts/entity/merchants/consumer.lua", args = {"Military Outpost"%_t, unpack(ConsumerGoods.MilitaryOutpost())}},
        },
        getPrice = function()
            return StationFounder.calculateConsumerValue({"Military Outpost"%_t, unpack(ConsumerGoods.MilitaryOutpost())})
        end
    },

    {
        name = "Shipyard"%_t,
        tooltip = "Builds ships. The owner gets the production fee paid by other players. Production fee is free for the owner of the shipyard."%_t .. "\n\n" ..
                  "The population on this station buys and consumes a range of technological goods. These goods can be picked up for free by the owner of the station. Attracts NPC traders."%_t,
        scripts = {
            {script = "data/scripts/entity/merchants/shipyard.lua"},
            {script = "data/scripts/entity/merchants/repairdock.lua"},
            {script = "data/scripts/entity/merchants/consumer.lua", args = {"Shipyard"%_t, unpack(ConsumerGoods.Shipyard())}},
        },
        getPrice = function()
            return 2000000 +
                    StationFounder.calculateConsumerValue({"Shipyard"%_t, unpack(ConsumerGoods.Shipyard())})
        end
    },
    {
        name = "Repair Dock"%_t,
        tooltip = "Repairs ships. The owner gets 20% of every transaction, as well as cheaper prices."%_t .. "\n\n" ..
                  "The population on this station buys and consumes a range of technological goods. These goods can be picked up for free by the owner of the station. Attracts NPC traders."%_t,
        scripts = {
            {script = "data/scripts/entity/merchants/repairdock.lua"},
            {script = "data/scripts/entity/merchants/consumer.lua", args = {"Repair Dock"%_t, unpack(ConsumerGoods.RepairDock())}},
        },
        getPrice = function()
            return 2000000 +
                    StationFounder.calculateConsumerValue({"Repair Dock"%_t, unpack(ConsumerGoods.RepairDock())})
        end
    },
}

-- if this function returns false, the script will not be listed in the interaction window on the client,
-- even though its UI may be registered
--
function StationFounder.interactionPossible(playerIndex, option)

    if checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FoundStations) then
        return true, ""
    end

    return false
end

function StationFounder.getIcon()
    return "data/textures/icons/flying-flag.png"
end


-- ship building menu items
local planDisplayer
local seedTextBox
local nameTextBox
local materialCombo
local volumeSlider
local scaleSlider

-- building ships
local seed = 0
local volume = 150
local scale = 1.0
local material
local preview
local redesign = false

-- this function gets called on creation of the entity the script is attached to, on client and server
function StationFounder.initialize(shipyardFaction)
    if shipyardFaction ~= nil and shipyardFaction.isAIFaction then
        StationFounder.factionIndex = shipyardFaction.index
    end


    local ship = Entity()

    if ship.title == "" then
        ship.title = "Station Founder"%_t
    end
end

-- this function gets called on creation of the entity the script is attached to, on client only
-- AFTER initialize above
-- create all required UI elements for the client side
function StationFounder.initUI()
    StationFounder.initSelectionUI()
    StationFounder.initEditUI()
end

function StationFounder.initSelectionUI()
    local res = getResolution()
    local size = vec2(650, 575)

    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))

    window.caption = "Transform"%_t
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "Found Station"%_t);

    -- create a tabbed window inside the main window
    local tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 10), size - 10))

    -- create buy tab
    local buyTab0 = tabbedWindow:createTab("Basic"%_t, "data/textures/icons/station.png", "Basic Factories"%_t)
    local buyTab1 = tabbedWindow:createTab("Low"%_t, "data/textures/icons/station.png", "Low Tech Factories"%_t)
    local buyTab2 = tabbedWindow:createTab("Advanced"%_t, "data/textures/icons/station.png", "Advanced Factories"%_t)
    local buyTab3 = tabbedWindow:createTab("High"%_t, "data/textures/icons/station.png", "High Tech Factories"%_t)
    local buyTab4 = tabbedWindow:createTab("Other Stations"%_t, "data/textures/icons/stars-stack.png", "Other Stations"%_t)

    StationFounder.buildMiscStationGui(buyTab4)
    StationFounder.buildFactoryGui({0}, buyTab0)
    StationFounder.buildFactoryGui({1, 2, 3}, buyTab1)
    StationFounder.buildFactoryGui({4, 5, 6}, buyTab2)
    StationFounder.buildFactoryGui({7, 8, 9}, buyTab3)

    -- warn box
    local size = vec2(550, 290)
    local warnWindow = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    StationFounder.warnWindow = warnWindow
    warnWindow.caption = "Confirm Transformation"%_t
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
    StationFounder.warnWindowLabel = warnWindowLabel
    warnWindowLabel.size = ihsplit.bottom.size
    warnWindowLabel:setTopAligned();
    warnWindowLabel.wordBreak = true
    warnWindowLabel.fontSize = 14


    local vsplit = UIVerticalSplitter(hsplit.bottom, 10, 0, 0.5)
    warnWindow:createButton(vsplit.left, "OK"%_t, "onConfirmTransformationButtonPress")
    warnWindow:createButton(vsplit.right, "Cancel"%_t, "onCancelTransformationButtonPress")
end

function StationFounder.initEditUI()
    local res = getResolution()
    local size = vec2(800, 600)

    local menu = ScriptUI()
    StationFounder.editWindow = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))

    StationFounder.editWindow.showCloseButton = 1
    StationFounder.editWindow.moveable = 1
    StationFounder.editWindow:hide()

    local container = StationFounder.editWindow:createContainer(Rect(vec2(0, 0), size));

    local vsplit = UIVerticalSplitter(Rect(vec2(0, 0), size), 10, 10, 0.5)
    vsplit:setRightQuadratic()

    local left = vsplit.left
    local right = vsplit.right

    container:createFrame(left);
    container:createFrame(right);

    local lister = UIVerticalLister(left, 10, 10)
    lister.padding = 20 -- add a higher padding as the slider texts might overlap otherwise

    scaleSlider = container:createSlider(Rect(), 20, 300, 280, "Scaling"%_t, "")
    scaleSlider.value = 100;
    scaleSlider.unit = "%"
    scaleSlider.onMouseUpChangedFunction = "updatePlan"
    lister:placeElementCenter(scaleSlider)

    volumeSlider = container:createSlider(Rect(), 200.0, 10000.0, 1000, "Volume"%_t, "");
    volumeSlider.onMouseUpChangedFunction = "updatePlan"
    lister:placeElementCenter(volumeSlider)
    lister.padding = 10 -- set padding back to normal

    -- create check boxes
    local l = container:createLabel(vec2(), "Seed"%_t, 14);
    l.size = vec2(0, 0)
    lister.padding = 0
    lister:placeElementCenter(l)
    lister.padding = 10

    -- make a seed text box with 2 quadratic buttons next to it
    local rect = lister:placeCenter(vec2(vsplit.left.width - 20, 30))
    local split = UIVerticalSplitter(rect, 5, 0, 0.5)
    split:setRightQuadratic();

    container:createButton(split.right, "-", "seedDecrease");

    local split = UIVerticalSplitter(split.left, 10, 0, 0.5)
    split:setRightQuadratic();

    container:createButton(split.right, "+", "seedIncrease");

    -- make the seed text box
    seedTextBox = container:createTextBox(split.left, "onSeedChanged");
    seedTextBox.text = seed

    materialCombo = container:createComboBox(Rect(), "onMaterialComboSelect");
    for i = 0, NumMaterials() - 1, 1 do
        materialCombo:addEntry(Material(i).name);
    end
    lister:placeElementCenter(materialCombo)

    -- check box for stats
    statsCheckBox = container:createCheckBox(Rect(), "Show Stats"%_t, "onStatsChecked")
    lister:placeElementCenter(statsCheckBox)
    statsCheckBox.checked = false

    lister:nextRect(230)

    -- button at the bottom
    local button = container:createButton(Rect(), "Transform"%_t, "onBuildButtonPress");
    local organizer = UIOrganizer(left)
    organizer.padding = 10
    organizer.margin = 10
    organizer:placeElementBottom(button)

    -- create the viewer
    planDisplayer = container:createPlanDisplayer(vsplit.right);
    planDisplayer.showStats = 0

    -- request the stlye of the faction
    invokeServerFunction("sendFactionInfo");
end

StationFounder.redesignButtons = {}

function StationFounder.updateRedesignButtons()
    local factionName
    if StationFounder.factionIndex ~= nil then
        factionName = Faction(StationFounder.factionIndex).name
    end

    if StationFounder.editWindow then -- compatibility with derelict station founder
        StationFounder.editWindow.caption = string.format("%s Station Designer"%_t, factionName)
    end

    for _, redesignButton in pairs(StationFounder.redesignButtons) do
        if factionName then
            redesignButton.tooltip = string.format("Redesign by %s"%_t, factionName)
            redesignButton:show()
        else
            redesignButton:hide()
        end
    end
end

function StationFounder.buildMiscStationGui(tab)
    -- make levels a table with key == value

    -- create background
    local frame = tab:createScrollFrame(Rect(vec2(), tab.size))
    frame.scrollSpeed = 40
    frame.paddingBottom = 17


    local count = 0
    for index, station in pairs(StationFounder.stations) do

        local stationName = station.name

        local padding = 10
        local height = 30
        local width = frame.size.x - padding * 4

        local lower = vec2(padding, padding + ((height + padding) * count))
        local upper = lower + vec2(width, height)

        local rect = Rect(lower, upper)

        local vsplit = UIVerticalSplitter(rect, 10, 0, 0.8)
        vsplit.rightSize = 100

        local buttonSplit = UIVerticalSplitter(vsplit.right, 10, 0, 0.5)
        -- redesign
        local redesignButton = frame:createButton(buttonSplit.left, "", "onFoundStationButtonPressRedesign")
        redesignButton.icon = "data/textures/icons/wrench.png"
        table.insert(StationFounder.redesignButtons, redesignButton)

        -- transform directly
        local transformButton = frame:createButton(buttonSplit.right, "", "onFoundStationButtonPress")
        transformButton.icon = "data/textures/icons/checkmark.png"
        transformButton.tooltip = "Transform"%_t

        frame:createFrame(vsplit.left)

        vsplit = UIVerticalSplitter(vsplit.left, 10, 7, 0.7)

        local label = frame:createLabel(vsplit.left.lower, stationName, 14)
        label.size = vec2(vsplit.left.size.x, vsplit.left.size.y)
        label:setLeftAligned()

        label.tooltip = station.tooltip or ""

        local costs = StationFounder.getStationCost(station)

        local label = frame:createLabel(vsplit.right.lower, createMonetaryString(costs) .. " Cr"%_t, 14)
        label.size = vec2(vsplit.right.size.x, vsplit.right.size.y)
        label:setRightAligned()

        StationFounder.stationsByButton[transformButton.index] = index
        StationFounder.stationsByButton[redesignButton.index] = index

        count = count + 1
    end

end

function StationFounder.buildFactoryGui(levels, tab)

    -- make levels a table with key == value
    local l = {}
    for _, v in pairs(levels) do
        l[v] = v
    end
    levels = l

    -- create background
    local frame = tab:createScrollFrame(Rect(vec2(), tab.size))
    frame.scrollSpeed = 40
    frame.paddingBottom = 17

    local usedProductions = {}
    local possibleProductions = {}

    for good, productions in pairs(productionsByGood) do

        for index, production in ipairs(productions) do
            -- mines shouldn't be built just like that, they need asteroids
            if not production.mine then

                -- read data from production
                local result = goods[production.results[1].name];

                -- only insert if the level is in the list
                if good == production.results[1].name then
                    if levels[result.level] ~= nil and not usedProductions[production.index] then
                        usedProductions[production.index] = true
                        table.insert(possibleProductions, {production=production, index=index})
                    end
                end
            end
        end
    end

    local comp =
        function(a, b)
            local nameA = getTranslatedFactoryName(a.production)
            local nameB = getTranslatedFactoryName(b.production)

            if nameA == nameB then
                local costsA = getFactoryCost(a.production)
                local costsB = getFactoryCost(b.production)
                return costsA < costsB
            end

            return nameA < nameB
        end

    table.sort(possibleProductions, comp)

    local count = 0
    for _, p in pairs(possibleProductions) do

        local production = p.production
        local index = p.index

        local result = goods[production.results[1].name];
        local factoryName = getTranslatedFactoryName(production)

        local padding = 10
        local height = 30
        local width = frame.size.x - padding * 4

        local lower = vec2(padding, padding + ((height + padding) * count))
        local upper = lower + vec2(width, height)

        local rect = Rect(lower, upper)

        local vsplit = UIVerticalSplitter(rect, 10, 0, 0.8)
        vsplit.rightSize = 100

        local buttonSplit = UIVerticalSplitter(vsplit.right, 10, 0, 0.5)
        -- redesign
        local redesignButton = frame:createButton(buttonSplit.left, "", "onFoundFactoryButtonPressRedesign")
        redesignButton.icon = "data/textures/icons/wrench.png"
        table.insert(StationFounder.redesignButtons, redesignButton)

        -- transform directly
        local transformButton = frame:createButton(buttonSplit.right, "", "onFoundFactoryButtonPress")
        transformButton.icon = "data/textures/icons/checkmark.png"
        transformButton.tooltip = "Transform"%_t

        frame:createFrame(vsplit.left)

        vsplit = UIVerticalSplitter(vsplit.left, 10, 7, 0.7)

        local label = frame:createLabel(vsplit.left.lower, factoryName, 14)
        label.size = vec2(vsplit.left.size.x, vsplit.left.size.y)
        label:setLeftAligned()

        local tooltip = "Produces:\n"%_t
        for i, result in pairs(production.results) do
            if i > 1 then tooltip = tooltip .. "\n" end
            tooltip = tooltip .. " - " .. result.name%_t
        end


        local first = 1
        for _, i in pairs(production.ingredients) do
            if first == 1 then
                tooltip = tooltip .. "\n\n" .. "Requires:"%_t
                first = 0
            end
            tooltip = tooltip .. "\n - " .. i.name%_t
        end
        label.tooltip = tooltip

        local costs = getFactoryCost(production) * (StationFounder.priceFactor or 1)

        local label = frame:createLabel(vsplit.right.lower, createMonetaryString(costs) .. " Cr"%_t, 14)
        label.size = vec2(vsplit.right.size.x, vsplit.right.size.y)
        label:setRightAligned()


        StationFounder.productionsByButton[transformButton.index] = {goodName = result.name, factory=factoryName, index = index, production = production}
        StationFounder.productionsByButton[redesignButton.index] = {goodName = result.name, factory=factoryName, index = index, production = production}

        count = count + 1

    end
end

function StationFounder.updateClient(timeStep)
    StationFounder.updateShipProblem()
end

function StationFounder.updateShipProblem()
    local color = ColorRGB(1, 1, 0)
    local playerShip = Entity().index
    if not StationFounder.getNearDistanceOK() then
        addShipProblem("CantFoundStationHere", playerShip, "You can't found a station this close to another station."%_t, "data/textures/icons/station_x.png", color)
    elseif not StationFounder.getFarDistanceOK() then
        addShipProblem("CantFoundStationHere", playerShip, "You're too far out to found a station."%_t, "data/textures/icons/station_x.png", color)
    else
        removeShipProblem("CantFoundStationHere", playerShip)
    end
end

function StationFounder.onFoundFactoryButtonPressRedesign(button)
    -- get specific faction style for the chosen station type from the server
    invokeServerFunction("sendStationStyle", StationFounder.productionsByButton[button.index])
end

function StationFounder.sendStationStyle(selectedProduction, selectedStation)
    local faction = Faction(StationFounder.factionIndex)
    if not faction or not faction.isAIFaction then return end

    if selectedProduction then
        local production = productionsByGood[selectedProduction.goodName][selectedProduction.index]
        local styleName = PlanGenerator.determineStationStyleFromScriptArguments("data/scripts/entity/merchants/factory.lua", production)
        local style = PlanGenerator.getStationStyle(faction, styleName)

        invokeClientFunction(Player(callingPlayer), "receiveStationStyle", style, selectedProduction, nil)

    elseif selectedStation then
        local template = StationFounder.stations[selectedStation]
        local styleName = PlanGenerator.determineStationStyleFromScriptArguments(template.scripts[1].script)
        local style = PlanGenerator.getStationStyle(faction, styleName)

        invokeClientFunction(Player(callingPlayer), "receiveStationStyle", style, nil, selectedStation)
    end
end
callable(StationFounder, "sendStationStyle")

function StationFounder.receiveStationStyle(style, selectedProduction, selectedStation)
    StationFounder.selectedProduction = selectedProduction
    StationFounder.selectedStation = selectedStation
    StationFounder.style = style

    -- reload plan of current ship
    StationFounder.updatePlan()
    StationFounder.editWindow:show()
end

function StationFounder.onFoundFactoryButtonPress(button)
    StationFounder.selectedProduction = StationFounder.productionsByButton[button.index]
    StationFounder.selectedStation = nil

    redesign = false
    StationFounder.onWarnFinish(button)
end

function StationFounder.onFoundStationButtonPressRedesign(button)
    -- get specific faction style for the chosen station type from the server
    invokeServerFunction("sendStationStyle", nil, StationFounder.stationsByButton[button.index])
    if true then return end

    if StationFounder.factionIndex then
        StationFounder.selectedStation = StationFounder.stationsByButton[button.index]
        StationFounder.selectedProduction = nil

        -- reload plan of current ship
        StationFounder.updatePlan()
        StationFounder.editWindow:show()
    end
end

function StationFounder.onFoundStationButtonPress(button)
    StationFounder.selectedStation = StationFounder.stationsByButton[button.index]
    StationFounder.selectedProduction = nil

    redesign = false
    StationFounder.onWarnFinish(button)
end

function StationFounder.onBuildButtonPress(button)
    redesign = true
    StationFounder.editWindow:hide()
    StationFounder.onWarnFinish(button)
end

function StationFounder.onWarnFinish(button)
    if StationFounder.selectedProduction then
        StationFounder.warnWindowLabel.caption = "This action is irreversible."%_t .."\n\n" ..
            "You're about to transform your ship into a ${factory}.\n"%_t % {factory = getTranslatedFactoryName(StationFounder.selectedProduction.production)} ..
            "Your ship will become immobile and, if required, will receive production extensions.\n"%_t ..
            "Due to a systems change, all turrets will be removed from your station."%_t .. "\n\n" ..
            "Building a station expands your influence in this sector. Taking over a sector impacts your relations with the local faction."%_t
    elseif StationFounder.selectedStation then
        local template = StationFounder.stations[StationFounder.selectedStation]

        StationFounder.warnWindowLabel.caption = "This action is irreversible."%_t .."\n\n" ..
            "You're about to transform your ship into a ${stationName}.\n"%_t % {stationName = template.name} ..
            "Your ship will become immobile and, if required, will receive production extensions.\n"%_t ..
            "Due to a systems change, all turrets will be removed from your station."%_t .. "\n\n" ..
            "Building a station expands your influence in this sector. Taking over a sector impacts your relations with the local faction."%_t
    end

    StationFounder.warnWindow:show()
end

function StationFounder.onConfirmTransformationButtonPress(button)
    if redesign then
        local seed = seedTextBox.text
        if StationFounder.selectedProduction then
            invokeServerFunction("foundFactory", StationFounder.selectedProduction.goodName, StationFounder.selectedProduction.index, seed, volume, scale, material)
        elseif StationFounder.selectedStation then
            invokeServerFunction("foundStation", StationFounder.selectedStation, seed, volume, scale, material)
        end
    else
        if StationFounder.selectedProduction then
            invokeServerFunction("foundFactory", StationFounder.selectedProduction.goodName, StationFounder.selectedProduction.index)
        elseif StationFounder.selectedStation then
            invokeServerFunction("foundStation", StationFounder.selectedStation)
        end
    end
end

function StationFounder.onCancelTransformationButtonPress(button)
    StationFounder.warnWindow:hide()
end

function StationFounder.checkIfLimitReached(buyer, player)
    local settings = GameSettings()
    local limit
    if buyer.isPlayer or buyer.isAlliance then
        limit = buyer.maxNumStations
    end

    if limit and limit >= 0 and buyer.numStations >= limit then
        player:sendChatMessage("", 1, "Maximum station limit for this faction (%s) of this server reached!"%_t, limit)
        return true
    end

    local sector = Sector()
    if settings.maximumStationsPerSector >= 0 then
        local stations = sector:getNumEntitiesByType(EntityType.Station)
        if stations >= settings.maximumStationsPerSector then
            player:sendChatMessage("", 1, "Maximum station limit for this sector (%s) of this server reached!"%_t, settings.maximumStationsPerSector)
            return true
        end
    end
end

function StationFounder.foundFactory(goodName, productionIndex, seed, volume, scale, material)
    if anynils(goodName, productionIndex) then return end

    local buyer, ship, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FoundStations)
    if not buyer then return end

    local faction = Faction(StationFounder.factionIndex)
    if not faction then
        player:sendChatMessage("", 1, "The production line you chose doesn't exist."%_t)
        return
    end

    if StationFounder.checkIfLimitReached(buyer, player) then return end

    local production = productionsByGood[goodName][productionIndex]

    if production == nil then
        player:sendChatMessage("", 1, "The production line you chose doesn't exist."%_t)
        return
    end

    local plan
    if seed and volume and scale and material then
        local styleName = PlanGenerator.determineStationStyleFromScriptArguments("data/scripts/entity/merchants/factory.lua", production)
        local style = PlanGenerator.getStationStyle(faction, styleName)

        plan = GeneratePlanFromStyle(style, Seed(seed), volume, 2000, 1, Material(material))
        plan:scale(vec3(scale, scale, scale))
    end

    -- check if player has enough money
    local cost = getFactoryCost(production) * (StationFounder.priceFactor or 1)

    local requiredMoney, fee = StationFounder.getRequiredMoney(plan, buyer)
    local requiredResources = StationFounder.getRequiredResources(plan, buyer)
    requiredMoney = requiredMoney + cost

    local canPay, msg, args = buyer:canPay(requiredMoney, unpack(requiredResources))
    if not canPay then
        player:sendChatMessage("Station Founder"%_t, 1, msg, unpack(args))
        return
    end

    -- preserve ship cargo
    local cargos = ship:getCargos()

    -- preserve hangar
    local hangar = Hangar()
    local squads = {}
    if hangar then
        for _, squadIndex in pairs({hangar:getSquads()}) do
            squads[squadIndex] = {name = hangar:getSquadName(squadIndex), blueprint = hangar:getBlueprint(squadIndex), fighters = {}}
            for fighterIndex = 0, hangar:getSquadFighters(squadIndex) - 1 do
                table.insert(squads[squadIndex].fighters, hangar:getFighter(squadIndex, fighterIndex))
            end
        end
    end

    local station = StationFounder.transformToStation(buyer, plan)
    if not station then return end

    if plan then
        factionReceiveTransactionTax(faction, fee)
    end
    buyer:pay("Paid %1% Credits to found a factory."%_T, requiredMoney, unpack(requiredResources))

    -- make a factory
    station:addScript("data/scripts/entity/merchants/factory.lua", "nothing")
    station:invokeFunction("factory", "setProduction", production, 1)

    station:setValue("factory_type", "factory")

    -- remove all cargo that might have been added by the factory script
    station:clearCargoBay()

    -- insert cargo of the ship that founded the station
    for good, amount in pairs(cargos) do
        station:addCargo(good, amount)
    end

    -- restore the hangar
    local hangar = Hangar(station)
    if hangar then
        for squadIndex, data in pairs(squads) do
            local temporaryIndex = hangar:addSquad(data.name)
            hangar:moveSquad(temporaryIndex, squadIndex)
            hangar:setBlueprint(squadIndex, data.blueprint)
            for _, fighter in pairs(data.fighters) do
                hangar:addFighter(squadIndex, fighter)
            end
        end
    end
end
callable(StationFounder, "foundFactory")

function StationFounder.foundStation(selected, seed, volume, scale, material)
    if anynils(selected) then return end

    local buyer, ship, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FoundStations)
    if not buyer then return end

    local faction = Faction(StationFounder.factionIndex)
    if not faction then
        player:sendChatMessage("", 1, "The station you chose doesn't exist."%_t)
        return
    end

    if StationFounder.checkIfLimitReached(buyer, player) then return end

    local template = StationFounder.stations[selected]

    if template == nil then
        player:sendChatMessage("", 1, "The station you chose doesn't exist."%_t)
        return
    end

    local plan
    if seed and volume and scale and material then
        local styleName = PlanGenerator.determineStationStyleFromScriptArguments(template.scripts[1].script)
        local style = PlanGenerator.getStationStyle(faction, styleName)

        plan = GeneratePlanFromStyle(style, Seed(seed), volume, 2000, 1, Material(material))
        plan:scale(vec3(scale, scale, scale))
    end

    -- check if player has enough money
    local cost = StationFounder.getStationCost(template)

    local requiredMoney, fee = StationFounder.getRequiredMoney(plan, buyer)
    local requiredResources = StationFounder.getRequiredResources(plan, buyer)
    requiredMoney = requiredMoney + cost

    local canPay, msg, args = buyer:canPay(requiredMoney, unpack(requiredResources))
    if not canPay then
        player:sendChatMessage("Station Founder"%_t, 1, msg, unpack(args))
        return
    end

    -- preserve ship cargo
    local cargos = ship:getCargos()

    local station = StationFounder.transformToStation(buyer, plan)
    if not station then return end

    if plan then
        factionReceiveTransactionTax(faction, fee)
    end
    buyer:pay(Format("Paid %2% Credits to found a %1%."%_T, template.name), requiredMoney, unpack(requiredResources))

    -- make a factory
    for _, script in pairs(template.scripts) do
        local path = script.script
        local args = script.args or {}

        station:addScript(path, unpack(args))
    end

    -- remove all cargo that might have been added by scripts
    station:clearCargoBay()

    -- insert cargo of the ship that founded the station
    for good, amount in pairs(cargos) do
        station:addCargo(good, amount)
    end
end
callable(StationFounder, "foundStation")

function StationFounder.transformToStation(buyer, plan)

    local ship = Entity()
    local player = Player(callingPlayer)

    local malusFactor, malusReason = ship:getMalusFactor()

    -- transform ship into station
    -- has to be at least 2 km from the nearest station
    if not StationFounder.getNearDistanceOK() then
        player:sendChatMessage("", 1, "You're too close to another station."%_t)
        return
    end

    if not StationFounder.getFarDistanceOK() then
        player:sendChatMessage("", 1, "You're too far out to found a station."%_t)
        return
    end

    -- remove cargo to prevent it from being dropped as loot
    ship:clearCargoBay()

    -- create the station
    -- get plan of ship
    if not plan then
        plan = ship:getMovePlan()
    end
    local crew = ship.crew

    -- create station
    local desc = StationDescriptor()
    desc.factionIndex = ship.factionIndex
    desc:setMovePlan(plan)
    desc.position = ship.position
    desc.name = ship.name

    ship.name = ""

    local sector = Sector()
    local station = sector:createEntity(desc)
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
            sector:dropUpgrade(ship.translationf, player, nil, upgrade)
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
    station:invokeFunction("minimumpopulation", "fixStationIssues")

    -- callback on station creation finished
    local faction = Faction(buyer.index)
    local senderInfo = makeCallbackSenderInfo(Entity())
    faction:sendCallback("onTransformedToStation", senderInfo, station.id)

    sector:addScriptOnce("sector/traders.lua")
    sector:addScriptOnce("sector/passingships.lua")

    -- update sector contents, check if the sector's controlling faction changed
    sector:invokeFunction("data/scripts/sector/background/sectorcontentsupdater.lua", "updateServer")

    return station
end

function StationFounder.getNearDistanceOK()
    local sector = Sector()
    local ship = Entity()
    local player = Player(callingPlayer)

    local stations = {sector:getEntitiesByType(EntityType.Station)}
    local ownSphere = ship:getBoundingSphere()
    local minDist = 300
    local tooNear

    for _, station in pairs(stations) do
        if station.id ~= ship.id then
            local sphere = station:getBoundingSphere()

            local d = distance(sphere.center, ownSphere.center) - sphere.radius - ownSphere.radius
            if d < minDist then
                return false
            end
        end
    end

    return true
end

function StationFounder.getFarDistanceOK()
    local ship = Entity()
    local ownSphere = ship:getBoundingSphere()
    local maxDist = 23000
    if distance(ownSphere.center, vec3(0, 0, 0)) > maxDist then
        return false
    end

    return true
end

function StationFounder.getStationCost(station)
    return (station.price or station:getPrice()) * (StationFounder.priceFactor or 1)
end


-- this function gets called every time the window is closed on the client
function StationFounder.onCloseWindow()
    StationFounder.warnWindow:hide()

    if StationFounder.editWindow then -- compatibility with derelict station founder
        StationFounder.editWindow:hide()
    end
end

StationFounder.interactionThreshold = -30000

function StationFounder.renderUI()
    if not StationFounder.editWindow then return end -- compatibility with derelict station founder
    if not StationFounder.editWindow.visible then return end

    local ship = Player().craft
    if not ship then return end

    local buyer = Faction(ship.factionIndex)
    if buyer.isAlliance then
        buyer = Alliance(buyer.index)
    elseif buyer.isPlayer then
        buyer = Player(buyer.index)
    end

    local planMoney = preview:getMoneyValue() - Plan():getMoneyValue()

    local planResources = {preview:getResourceValue()}

    for i, negativeResource in pairs{Plan():getResourceValue()} do
        planResources[i] = planResources[i] - negativeResource
    end

    local costs
    if StationFounder.selectedProduction then
        local production = productionsByGood[StationFounder.selectedProduction.goodName][StationFounder.selectedProduction.index]
        costs = getFactoryCost(production) * (StationFounder.priceFactor or 1)
    elseif StationFounder.selectedStation then
        local station = StationFounder.stations[StationFounder.selectedStation]
        costs = StationFounder.getStationCost(station) * (StationFounder.priceFactor or 1)
    end

    local fee
    if planMoney <= 0 then
        fee = 0
    else
        fee = planMoney * GetFee(Faction(StationFounder.factionIndex), buyer) * 2
    end

    local offset = 10
    offset = offset + renderPrices(planDisplayer.lower + vec2(10, offset), "Transform Costs"%_t, costs)
    offset = offset + renderPrices(planDisplayer.lower + vec2(10, offset), "Redesign Costs"%_t, planMoney, planResources, true)
    offset = offset + renderPrices(planDisplayer.lower + vec2(10, offset), "Fee"%_t, fee)

    offset = offset + 20
    offset = offset + renderPrices(planDisplayer.lower + vec2(10, offset), "Total"%_t, costs + planMoney + fee, planResources, true)
end

function StationFounder.updatePlan()
    -- just to make sure that the interface is completely created, this function is called during initialization of the GUI, and not everything may be constructed yet
    if materialCombo == nil then return end
    if planDisplayer == nil then return end
    if volumeSlider == nil then return end
    if scaleSlider == nil then return end

    -- retrieve all settings
    material = materialCombo.selectedIndex
    volume = volumeSlider.value
    scale = scaleSlider.value / 100
    if scale <= 0.1 then scale = 0.1 end

    local seed = seedTextBox.text

    if StationFounder.style == nil then
        preview = BlockPlan()
    else
        -- generate the preview plan
        preview = GeneratePlanFromStyle(StationFounder.style, Seed(seed), volume, 2000, 1, Material(material))
    end

    preview:scale(vec3(scale, scale, scale))

    -- set to display
    planDisplayer.plan = preview
end

function StationFounder.getRequiredMoney(plan, orderingFaction)
    if not plan then return 0, 0 end

    local requiredMoney = plan:getMoneyValue() - Plan():getMoneyValue();

    local fee
    if requiredMoney <= 0 then
        fee = 0
    else
        fee = requiredMoney * GetFee(Faction(StationFounder.factionIndex), orderingFaction) * 2
    end
    requiredMoney = requiredMoney + fee

    return requiredMoney, fee
end

function StationFounder.getRequiredResources(plan, orderingFaction)
    if not plan then return {} end

    local resources = {plan:getResourceValue()}

    for i, negativeResource in pairs{Plan():getResourceValue()} do
        resources[i] = resources[i] - negativeResource
    end

    return resources
end

function StationFounder.transactionComplete()
    ScriptUI():stopInteraction()
end

function StationFounder.seedDecrease()
    local number = tonumber(seed) or 0
    StationFounder.setSeed(number - 1)
end

function StationFounder.seedIncrease()
    local number = tonumber(seed) or 0
    StationFounder.setSeed(number + 1)
end

function StationFounder.setSeed(newSeed)
    seed = newSeed
    seedTextBox.text = seed
    StationFounder.updatePlan();
end

function StationFounder.onSeedChanged()
    StationFounder.setSeed(seedTextBox.text);
end

function StationFounder.onMaterialComboSelect()
    StationFounder.updatePlan();
end

function StationFounder.onStatsChecked(index, checked)
    if planDisplayer then
        planDisplayer.showStats = checked
    end
end

function StationFounder.receiveFactionInfo(factionIndex)
    StationFounder.factionIndex = factionIndex

    -- allow sector specific volume sizes for the station
    local faction = Faction(factionIndex)
    if valid(faction) then
        local value = Balancing_GetSectorStationVolume(faction:getHomeSectorCoordinates())
        volumeSlider.min = value * Balancing_GetStationVolumeDeviation(0)
        volumeSlider.max = value * Balancing_GetStationVolumeDeviation(1)
        volumeSlider.value = value * Balancing_GetStationVolumeDeviation(0.5)
    end

    StationFounder.updatePlan()
    StationFounder.updateRedesignButtons()
end

-- sends the faction which created the ship to the client
function StationFounder.sendFactionInfo()
    local player = Player(callingPlayer)
    invokeClientFunction(player, "receiveFactionInfo", StationFounder.factionIndex)
end
callable(StationFounder, "sendFactionInfo")

function StationFounder.restore(data)
    if data.factionIndex then
        -- only restore existing AI factions
        local faction = Faction(data.factionIndex)
        if faction and faction.isAIFaction then
            StationFounder.factionIndex = data.factionIndex
        else
            StationFounder.factionIndex = nil
        end
    end
end

function StationFounder.secure()
    if StationFounder.factionIndex then
        return {factionIndex = StationFounder.factionIndex}
    end
end
