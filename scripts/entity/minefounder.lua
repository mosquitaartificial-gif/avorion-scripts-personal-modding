package.path = package.path .. ";data/scripts/lib/?.lua"
include ("galaxy")
include ("utility")
include ("faction")
include ("productions")
include ("goods")
include ("randomext")
include ("defaultscripts")
include ("stringutility")
include ("callable")
Dialog = include("dialogutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace MineFounder
MineFounder = {}
local self = MineFounder

MineFounder.productionsByButton = {}
MineFounder.selectedProduction = {}

MineFounder.warnWindow = {}
MineFounder.warnWindowLabel = {}
MineFounder.inputWindow = {}

-- if this function returns false, the script will not be listed in the interaction window on the client,
-- even though its UI may be registered
--
function MineFounder.interactionPossible(playerIndex, option)

    if checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FoundStations) then
        return true, ""
    end

    return false
end

function MineFounder.getIcon()
    return "data/textures/icons/flying-flag.png"
end


-- this function gets called on creation of the entity the script is attached to, on client and server
--function initialize()
--
--end

-- this function gets called on creation of the entity the script is attached to, on client only
-- AFTER initialize above
-- create all required UI elements for the client side
function MineFounder.initUI()
    local res = getResolution()
    local size = vec2(650, 575)

    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))

    window.caption = "Transform to Mine /*window title*/"%_t
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "Found Mine"%_t, 5);

    -- create a tabbed window inside the main window
    local tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 10), size - 10))

    -- create buy tab
    local buyTab = tabbedWindow:createTab("Mines"%_t, "data/textures/icons/bag.png", "Mines"%_t)

    MineFounder.buildGui({0}, buyTab)

    -- warn box
    local size = vec2(550, 230)
    self.warnWindow = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    self.warnWindow.caption = "Confirm Transformation"%_t
    self.warnWindow.showCloseButton = 1
    self.warnWindow.moveable = 1
    self.warnWindow.visible = false

    local hsplit = UIHorizontalSplitter(Rect(vec2(), self.warnWindow.size), 10, 10, 0.5)
    hsplit.bottomSize = 40

    self.warnWindow:createFrame(hsplit.top)

    local ihsplit = UIHorizontalSplitter(hsplit.top, 10, 10, 0.5)
    ihsplit.topSize = 20

    local label = self.warnWindow:createLabel(ihsplit.top.lower, "Warning"%_t, 16)
    label.size = ihsplit.top.size
    label.bold = true
    label.color = ColorRGB(0.8, 0.8, 0)
    label:setTopAligned();

    self.warnWindowLabel = self.warnWindow:createLabel(ihsplit.bottom.lower, "Text", 14)
    self.warnWindowLabel.size = ihsplit.bottom.size
    self.warnWindowLabel:setTopAligned();
    self.warnWindowLabel.wordBreak = true

    local vsplit = UIVerticalSplitter(hsplit.bottom, 10, 0, 0.5)
    self.warnWindow:createButton(vsplit.left, "OK"%_t, "onConfirmTransformationButtonPress")
    self.warnWindow:createButton(vsplit.right, "Cancel"%_t, "onCancelTransformationButtonPress")

    -- input window
    self.inputWindow = window:createInputWindow()
    self.inputWindow.onOKFunction = "onNameEntered"
    self.inputWindow.caption = "Mine Name"%_t
    self.inputWindow.textBox:forbidInvalidFilenameChars()
    self.inputWindow.textBox.maxCharacters = 35

end

function MineFounder.buildGui(levels, tab)

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

    local entity = Entity()

    local usedProductions = {}
    local possibleProductions = {}

    for good, productions in pairs(productionsByGood) do

        for index, production in ipairs(productions) do -- ipairs keeps the array order

            if production.mine then

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
                local costsA = MineFounder.getFactoryCost(a.production)
                local costsB = MineFounder.getFactoryCost(b.production)
                return costsA < costsB
            end

            return nameA < nameB
        end

    table.sort(possibleProductions, comp)

    local count = 0
    for _, p in pairs(possibleProductions) do

        local index = p.index
        local production = p.production
        local result = goods[production.results[1].name];
        local factoryName = getTranslatedFactoryName(production)

        local padding = 10
        local height = 30
        local width = frame.size.x - padding * 4

        local lower = vec2(padding, padding + ((height + padding) * count))
        local upper = lower + vec2(width, height)

        local rect = Rect(lower, upper)

        local vsplit = UIVerticalSplitter(rect, 10, 0, 0.8)
        vsplit.rightSize = 150

        local button = frame:createButton(vsplit.right, "Transform"%_t, "onFoundFactoryButtonPress")
        button.textSize = 13
        button.bold = false

        frame:createFrame(vsplit.left)

        vsplit = UIVerticalSplitter(vsplit.left, 10, 7, 0.7)

        local label = frame:createLabel(vsplit.left.lower, factoryName, 14)
        label.size = vec2(vsplit.left.size.x, vsplit.left.size.y)
        label:setLeftAligned()

        local tooltip = "Produces:"%_t .. "\n"
        for i, result in pairs(production.results) do
            if i > 1 then tooltip = tooltip .. "\n" end
            tooltip = tooltip .. " - " .. result.name % _t
        end

        local first = 1
        for _, i in pairs(production.ingredients) do
            if first == 1 then
                tooltip = tooltip .. "\n\n".."Requires:"%_t
                first = 0
            end
            tooltip = tooltip .. "\n - " .. i.name % _t
        end
        label.tooltip = tooltip

        local costs = MineFounder.getFactoryCost(production) * (MineFounder.priceFactor or 1)

        local label = frame:createLabel(vsplit.right.lower, createMonetaryString(costs) .. " Cr", 14)
        label.size = vec2(vsplit.right.size.x, vsplit.right.size.y)
        label:setRightAligned()

        self.productionsByButton[button.index] = {goodName = result.name, factory = factoryName, index = index, production = production}

        count = count + 1
    end
end

function MineFounder.onFoundFactoryButtonPress(button)
    self.selectedProduction = self.productionsByButton[button.index]

    self.warnWindowLabel.caption = "This action is irreversible."%_t .. "\n\n" ..
        "You're about to transform your asteroid into a ${mine}."%_t % {mine = getTranslatedFactoryName(self.selectedProduction.production)} ..
        "\n\n" ..
        "Building a station expands your influence in this sector. Taking over a sector impacts your relations with the local faction."%_t

    self.warnWindowLabel.fontSize = 14

    self.warnWindow:show()
end

function MineFounder.onConfirmTransformationButtonPress(button)
    self.inputWindow:show("Please enter a name for your mine:"%_t)
end

function MineFounder.onNameEntered(window, name)
    if not self.selectedProduction.goodName then return end
    if not self.selectedProduction.index then return end

    invokeServerFunction("foundFactory", self.selectedProduction.goodName, self.selectedProduction.index, name)
end

function MineFounder.onCancelTransformationButtonPress(button)
    self.warnWindow:hide()
end

function MineFounder.checkIfLimitReached(buyer, player)
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

function MineFounder.foundFactory(goodName, productionIndex, name)
    if anynils(goodName, productionIndex, name) then return end

    local buyer, asteroid, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FoundStations)
    if not buyer then return end

    if MineFounder.checkIfLimitReached(buyer, player) then return end

    -- don't allow empty names
    name = name or ""
    if name == "" then
        name = "${good} Mine"%_t % {good = goodName}
    end

    if buyer:ownsShip(name) then
        player:sendChatMessage("", 1, "You already own an object called ${name}."%_t % {name = name})
        return
    end

    DebugInfo():log("goodName: %s productionIndex: %s name: %s", tostring(goodName), tostring(productionIndex), tostring(name))
    local production = productionsByGood[goodName][productionIndex]

    if production == nil then
        player:sendChatMessage("", 1, "The production line you chose doesn't exist."%_t)
        return
    end

    -- check if player has enough money
    local cost = MineFounder.getFactoryCost(production) * (MineFounder.priceFactor or 1)
    local canPay, msg, args = buyer:canPay(cost)
    if not canPay then
        player:sendChatMessage("", 1, msg, unpack(args))
        return
    end

    local station = MineFounder.transformToStation(buyer, name)
    if not station then return end

    buyer:pay("Paid %1% Credits to found a mine."%_T, cost)

    -- make a factory
    station:addScript("data/scripts/entity/merchants/factory.lua", "nothing")

    station:invokeFunction("factory", "setProduction", production, 1)
    station:invokeFunction("factory", "updateTitle")

    station:setValue("factory_type", "mine")

    -- remove all goods from mine, it should start from scratch
    local stock, max = station:invokeFunction("factory", "getStock", goodName)
    station:invokeFunction("factory", "decreaseGoods", goodName, stock)

    -- remove all cargo that might have been added by the factory script
    for cargo, amount in pairs(station:getCargos()) do
        station:removeCargo(cargo, amount)
    end

    local sector = Sector()
    local x, y = sector:getCoordinates()
    player:sendCallback("onMineFounded", makeCallbackSenderInfo(station))
    if player ~= buyer then
        buyer:sendCallback("onMineFounded", makeCallbackSenderInfo(station))
    end

end
callable(MineFounder, "foundFactory")

function MineFounder.transformToStation(buyer, name)

    local asteroid = Entity()

    -- create the station
    -- get plan of asteroid
    local plan = asteroid:getMovePlan()

    -- this will delete the asteroid and deactivate the collision detection so the original asteroid doesn't interfere with the new station
    asteroid:setPlan(BlockPlan())

    -- create station
    local desc = StationDescriptor()
    desc.factionIndex = asteroid.factionIndex
    desc:setMovePlan(plan)
    desc.position = asteroid.position
    desc:addScriptOnce("data/scripts/entity/crewboard.lua")
    desc.name = name

    local sector = Sector()
    local station = sector:createEntity(desc)
    Physics(station).driftDecrease = 0.2

    AddDefaultStationScripts(station)
    SetBoardingDefenseLevel(station)

    sector:addScriptOnce("sector/traders.lua")
    sector:addScriptOnce("sector/passingships.lua")

    -- update sector contents, check if the sector's controlling faction changed
    sector:invokeFunction("data/scripts/sector/background/sectorcontentsupdater.lua", "updateServer")

    return station
end

function MineFounder.getFactoryCost(production)

    -- calculate the difference between the value of ingredients and results
    local ingredientValue = 0
    local resultValue = 0

    for _, ingredient in pairs(production.ingredients) do
        local good = goods[ingredient.name]
        ingredientValue = ingredientValue + good.price * ingredient.amount
    end

    for _, result in pairs(production.results) do
        local good = goods[result.name]
        resultValue = resultValue + good.price * result.amount
    end

    local diff = resultValue - ingredientValue

    local costs = 2500000 -- 2.5 mio minimum for a factory
    costs = costs + diff * 3500
    return costs
end

-- this functions gets called when the indicator of the station is rendered on the client
--function renderUIIndicator(px, py, size)
--
--end

-- this function gets called every time the window is shown on the client, ie. when a player presses F and if interactionPossible() returned 1
-- function onShowWindow()
--
-- end

---- this function gets called every time the window is closed on the client
function MineFounder.onCloseWindow()
    self.warnWindow:hide()
end

---- this function gets called each tick, on client and server
--function update(timeStep)
--
--end
--
---- this function gets called each tick, on client only
--function updateClient(timeStep)
--
--end
--
---- this function gets called each tick, on server only
--function updateServer(timeStep)
--
--end
--
---- this function gets called whenever the ui window gets rendered, AFTER the window was rendered (client only)
--function renderUI()
--
--end




