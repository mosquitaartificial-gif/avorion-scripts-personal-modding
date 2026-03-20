package.path = package.path .. ";data/scripts/lib/?.lua"
include ("galaxy")
include ("utility")
include ("faction")
include ("randomext")
include ("callable")
include ("weapontype")
include ("stringutility")
include ("goods")
include ("reconstructionutility")
include ("weapontypeutility")
include ("relations")
local TurretIngredients = include("turretingredients")
local SellableInventoryItem = include("sellableinventoryitem")
local Dialog = include("dialogutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Scrapyard
Scrapyard = {}

Scrapyard.interactionThreshold = -30000
Scrapyard.licenses = {}
Scrapyard.illegalActions = {}
Scrapyard.allowedWreckages = {}
Scrapyard.dockedWreckages = {}

-- server
local licenses = Scrapyard.licenses
local illegalActions = Scrapyard.illegalActions
local allowedWreckages = Scrapyard.allowedWreckages
local dockedWreckages = Scrapyard.dockedWreckages

Scrapyard.maxDestructionCounter = 30
Scrapyard.entityDestructionCounter = Scrapyard.maxDestructionCounter

-- client
local tabbedWindow = nil
local planDisplayer = nil
local sellButton = nil
local sellWarningLabel = nil
local priceLabel1 = nil
local priceLabel2 = nil
local priceLabel3 = nil
local priceLabel4 = nil
local licenseDuration = 0
local uiMoneyValue = 0
local visible = false

-- turret tab
local inventory = nil
local scrapButton = nil
local goodsLabels = {}

-- if this function returns false, the script will not be listed in the interaction window on the client,
-- even though its UI may be registered
function Scrapyard.interactionPossible(playerIndex, option)
    return CheckFactionInteraction(playerIndex, Scrapyard.interactionThreshold)
end

function Scrapyard.restore(data)
    -- clear earlier data
    licenses = data.licenses or {}
    illegalActions = data.illegalActions or {}
    dockedWreckages = data.dockedWreckages or {}
end

function Scrapyard.secure()
    -- save licenses
    local data = {}
    data.licenses = licenses
    data.illegalActions = illegalActions
    data.dockedWreckages = dockedWreckages

    return data
end

-- this function gets called on creation of the entity the script is attached to, on client and server
function Scrapyard.initialize()

    if onServer() then
        local sector = Sector()
        sector:registerCallback("onHullHit", "onHullHit")
        sector:registerCallback("onEntityCreated", "onEntityCreated")
        sector:registerCallback("onDestroyed", "onEntityDestroyed")
        sector:registerCallback("onEntityDocked", "onEntityDocked")
        sector:registerCallback("onEntityUndocked", "onEntityUndocked")
        sector:registerCallback("onEntityJump", "onEntityJump")

        local station = Entity()
        if station.title == "" then
            station.title = "Scrapyard"%_t
        end

    end

    if onClient() and EntityIcon().icon == "" then
        EntityIcon().icon = "data/textures/icons/pixel/scrapyard_fat.png"
        InteractionText().text = Dialog.generateStationInteractionText(Entity(), random())
    end
end

function Scrapyard.initializationFinished()
    -- use the initilizationFinished() function on the client since in initialize() we may not be able to access Sector scripts on the client
    if onClient() then
        local ok, r = Sector():invokeFunction("radiochatter", "addSpecificLines", Entity().id.string,
        {
            "Get a salvaging license now and try your luck with the wreckages!"%_t,
            "Easy salvage, easy profit! Salvaging licenses for sale!"%_t,
            "I'd like to see something brand new for once."%_t,
            "Don't like your ship anymore? We'll turn it into scrap and even give you some Credits for it!"%_t,
            "Brand new offer: We now dismantle turrets into parts!"%_t,
            "We don't take any responsibility for any lost limbs while using the turret dismantler."%_t,
        })
    end
end

-- this function gets called on creation of the entity the script is attached to, on client only
-- AFTER initialize above
-- create all required UI elements for the client side
function Scrapyard.initUI()

    local res = getResolution()
    local size = vec2(700, 650)

    local menu = ScriptUI()
    local mainWindow = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    menu:registerWindow(mainWindow, "Scrapyard"%_t, 10)
    mainWindow.caption = "Scrapyard"%_t
    mainWindow.showCloseButton = 1
    mainWindow.moveable = 1

    -- create a tabbed window inside the main window
    tabbedWindow = mainWindow:createTabbedWindow(Rect(vec2(10, 10), size - 10))

    -- create a "Sell" tab inside the tabbed window
    local sellTab = tabbedWindow:createTab("Sell Ship"%_t, "data/textures/icons/sell-ship.png", "Sell your ship to the scrapyard."%_t)
    size = sellTab.size

    planDisplayer = sellTab:createPlanDisplayer(Rect(0, 0, size.x - 20, size.y - 60))
    planDisplayer.showStats = 0

    sellButton = sellTab:createButton(Rect(0, size.y - 40, 150, size.y), "Sell Ship"%_t, "onSellButtonPressed")
    sellWarningLabel = sellTab:createLabel(vec2(200, size.y - 30), "Warning! You will not get refunds for crews or turrets!"%_t, 15)
    sellWarningLabel.color = ColorRGB(1, 1, 0)

    -- create a second tab
    local salvageTab = tabbedWindow:createTab("Salvaging /*UI Tab title*/"%_t, "data/textures/icons/recycle-arrows.png", "Buy a salvaging license."%_t)
    size = salvageTab.size -- not really required, all tabs have the same size

    local textField = salvageTab:createTextField(Rect(0, 0, size.x, 50), "Buy a temporary salvaging license of maximum 60 minutes here. This license makes it legal to damage or mine wreckages in this sector."%_t)
    textField.padding = 7

    salvageTab:createButton(Rect(size.x - 210, 80, 200 + size.x - 210, 40 + 80), "Buy License"%_t, "onBuyLicenseButton1Pressed")
    salvageTab:createButton(Rect(size.x - 210, 130, 200 + size.x - 210, 40 + 130), "Buy License"%_t, "onBuyLicenseButton2Pressed")
    salvageTab:createButton(Rect(size.x - 210, 180, 200 + size.x - 210, 40 + 180), "Buy License"%_t, "onBuyLicenseButton3Pressed")
    salvageTab:createButton(Rect(size.x - 210, 230, 200 + size.x - 210, 40 + 230), "Buy License"%_t, "onBuyLicenseButton4Pressed")

    local fontSize = 18
    salvageTab:createLabel(vec2(15, 85), "5", fontSize)
    salvageTab:createLabel(vec2(15, 135), "15", fontSize)
    salvageTab:createLabel(vec2(15, 185), "30", fontSize)
    salvageTab:createLabel(vec2(15, 235), "60", fontSize)

    salvageTab:createLabel(vec2(60, 85), "Minutes"%_t, fontSize)
    salvageTab:createLabel(vec2(60, 135), "Minutes"%_t, fontSize)
    salvageTab:createLabel(vec2(60, 185), "Minutes"%_t, fontSize)
    salvageTab:createLabel(vec2(60, 235), "Minutes"%_t, fontSize)

    priceLabel1 = salvageTab:createLabel(vec2(200, 85),  "", fontSize)
    priceLabel2 = salvageTab:createLabel(vec2(200, 135), "", fontSize)
    priceLabel3 = salvageTab:createLabel(vec2(200, 185), "", fontSize)
    priceLabel4 = salvageTab:createLabel(vec2(200, 235), "", fontSize)

    timeLabel = salvageTab:createLabel(vec2(10, 310), "", fontSize)

    -- create a tab for dismantling turrets
    local turretTab = tabbedWindow:createTab("Turret Dismantling /*UI Tab title*/"%_t, "data/textures/icons/recycle-turret.png", "Dismantle turrets into goods."%_t)

    local hsplit = UIHorizontalSplitter(Rect(turretTab.size), 10, 0, 0.17)

    local lister = UIVerticalLister(hsplit.top, 10, 0)
    local vmsplit = UIVerticalMultiSplitter(lister:nextRect(30), 10, 0, 2)

    scrapButton = turretTab:createButton(vmsplit.left, "Dismantle"%_t, "onDismantleTurretPressed")
    scrapButton.active = false
    scrapButton.textSize = 14

    local scrapTrashButton = turretTab:createButton(vmsplit.right, "Dismantle Trash"%_t, "onDismantleTrashPressed")
    scrapTrashButton.textSize = 14

    inventory = turretTab:createInventorySelection(hsplit.bottom, 10)
    inventory.onSelectedFunction = "onTurretSelected"
    inventory.onDeselectedFunction = "onTurretDeselected"
    inventory:setShowScrollArrows(true, false, 1.0)

    turretTab:createFrame(lister.rect)

    lister:setMargin(10, 10, 10, 10)

    local hlister = UIHorizontalLister(lister.rect, 10, 10)

    for i = 1, 10 do
        local rect = hlister:nextRect(30)
        rect.height = rect.width

        local pic = turretTab:createPicture(rect, "data/textures/icons/rocket.png")
        pic:hide()
        pic.isIcon = true

        local label = turretTab:createLabel(rect.bottomRight - 5, "?", 10)
        label:hide()

        table.insert(goodsLabels, {icon = pic, label = label})
    end

    -- warn box
    local size = vec2(550, 230)
    local warnWindow = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    Scrapyard.warnWindow = warnWindow
    warnWindow.caption = "Confirm Dismantling"%_t
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
    Scrapyard.warnWindowLabel = warnWindowLabel
    warnWindowLabel.size = ihsplit.bottom.size
    warnWindowLabel:setTopAligned();
    warnWindowLabel.wordBreak = true
    warnWindowLabel.fontSize = 14


    local vsplit = UIVerticalSplitter(hsplit.bottom, 10, 0, 0.5)
    warnWindow:createButton(vsplit.left, "OK"%_t, "onConfirmButtonPress")
    warnWindow:createButton(vsplit.right, "Cancel"%_t, "onCancelButtonPress")
end

function Scrapyard.onSellButtonPressed()

    Scrapyard.warnWindowLabel.caption = "This action is irreversible."%_t .."\n\n" ..
    "Your ship will be dismantled and you will be returned to your drone."%_t .."\n\n" ..
    "You will not get refunds for crews or turrets!"%_t

    Scrapyard.warnWindow:show()
end


-- this function gets called whenever the ui window gets rendered, AFTER the window was rendered (client only)
function Scrapyard.renderUI()

    if tabbedWindow:getActiveTab().name == "Sell Ship"%_t then
        renderPrices(planDisplayer.lower + 20, "Ship Value:"%_t, uiMoneyValue, nil)
    end
end

-- this function gets called every time the window is shown on the client, ie. when a player presses F and if interactionPossible() returned 1
function Scrapyard.onShowWindow()
    visible = true

    local ship = Player().craft
    if not ship then return end

    -- get the plan of the player's ship
    local plan = ship:getFullPlanCopy()
    planDisplayer.plan = plan

    if ship.isDrone then
        sellButton.active = false
        sellWarningLabel:hide()
    else
        sellButton.active = true
        sellWarningLabel:show()
    end

    uiMoneyValue = Scrapyard.getShipValue(plan)

    -- licenses
    priceLabel1.caption = "¢${money}"%_t % {money = Scrapyard.getLicensePrice(Player(), 5)}
    priceLabel2.caption = "¢${money}"%_t % {money = Scrapyard.getLicensePrice(Player(), 15)}
    priceLabel3.caption = "¢${money}"%_t % {money = Scrapyard.getLicensePrice(Player(), 30)}
    priceLabel4.caption = "¢${money}"%_t % {money = Scrapyard.getLicensePrice(Player(), 60)}

    Scrapyard.getLicenseDuration()

    -- turrets
    inventory:fill(ship.factionIndex, InventoryItemType.Turret)

end

function Scrapyard.onDismantleTurretPressed()
    local selected = inventory.selected
    if selected then
        invokeServerFunction("dismantleInventoryTurret", selected.index)
    end
end

function Scrapyard.onDismantleTrashPressed()
    invokeServerFunction("dismantleTrash")
end

function Scrapyard.onTurretSelected()
    local selected = inventory.selected
    if not selected then return end
    if not selected.item then return end
    if selected.favorite then return end

    scrapButton.active = true

    local _, possible = Scrapyard.getTurretGoods(selected.item)

    for _, line in pairs(goodsLabels) do
        line.icon:hide()
        line.label:hide()
    end

    table.sort(possible, function(a, b) return a.name < b.name end)

    local i = 1
    for _, good in pairs(possible) do
        local line = goodsLabels[i]; i = i + 1
        line.icon:show()
        line.label:show()

        line.icon.picture = good.icon
        line.icon.tooltip = good:displayName(10)
    end
end

function Scrapyard.onTurretDeselected()
    scrapButton.active = false

    for _, line in pairs(goodsLabels) do
        line.icon:hide()
        line.label:hide()
    end
end

function Scrapyard.onTurretDismantled()
    local ship = Player().craft
    if not ship then return end

    inventory:fill(ship.factionIndex, InventoryItemType.Turret)
end

-- this function gets called every time the window is closed on the client
function Scrapyard.onCloseWindow()
    local station = Entity()
    displayChatMessage("Please, do come again."%_t, station.title, 0)

    visible = false
end


function Scrapyard.onConfirmButtonPress()
    invokeServerFunction("sellCraft")
    Scrapyard.warnWindow:hide()
end

function Scrapyard.onCancelButtonPress()
    Scrapyard.warnWindow:hide()
end

function Scrapyard.onBuyLicenseButton1Pressed()
    invokeServerFunction("buyLicense", 60 * 5)
end

function Scrapyard.onBuyLicenseButton2Pressed()
    invokeServerFunction("buyLicense", 60 * 15)
end

function Scrapyard.onBuyLicenseButton3Pressed()
    invokeServerFunction("buyLicense", 60 * 30)
end

function Scrapyard.onBuyLicenseButton4Pressed()
    invokeServerFunction("buyLicense", 60 * 60)
end


function Scrapyard.getUpdateInterval()
    return 1
end

-- this function gets called each tick, on client only
function Scrapyard.updateClient(timeStep)
    licenseDuration = licenseDuration - timeStep

    if visible then
        if licenseDuration > 0 then
            local time = createDigitalTimeString(licenseDuration)
            timeLabel.caption = "Remaining license time: ${time} Minutes"%_t % {time = time}
        else
            timeLabel.caption = "You don't have a valid license."%_t
        end
    end
end

function Scrapyard.transactionComplete()
    ScriptUI():stopInteraction()
end

function Scrapyard.getLicenseDuration()
    invokeServerFunction("sendLicenseDuration")
end

function Scrapyard.setLicenseDuration(duration)
    licenseDuration = duration
end


function Scrapyard.getLicensePrice(orderingFaction, minutes)

    local price = minutes * 150 * (1.0 + GetFee(Faction(), orderingFaction)) * Balancing_GetSectorRichnessFactor(Sector():getCoordinates())

    local discountFactor = 1.0
    if minutes > 5 then discountFactor = 0.93 end
    if minutes > 15 then discountFactor = 0.86 end
    if minutes > 40 then discountFactor = 0.80 end

    return round(price * discountFactor);

end

-- this function gets called each tick, on server only
function Scrapyard.updateServer(timeStep)

    local station = Entity()

    for factionIndex, actions in pairs(illegalActions) do
        actions = actions - 1
        if actions <= 0 then
            illegalActions[factionIndex] = nil
        else
            illegalActions[factionIndex] = actions
        end
    end

    for id, time in pairs(allowedWreckages) do
        time = time + timeStep
        if time > 30 then
            allowedWreckages[id] = nil
        else
            allowedWreckages[id] = time
        end
    end

    -- increase the counter for destruction "niceness"
    Scrapyard.entityDestructionCounter = Scrapyard.entityDestructionCounter + timeStep

    for factionIndex, time in pairs(licenses) do

        time = time - timeStep

        local faction = Faction(factionIndex)
        if not faction then goto continue end

        local here = false
        if faction.isAlliance then
            faction = Alliance(factionIndex)
        elseif faction.isPlayer then
            faction = Player(factionIndex)

            local px, py = faction:getSectorCoordinates()
            local sx, sy = Sector():getCoordinates()

            here = (px == sx and py == sy)
        end

        local doubleSend = false
        local msg = nil

        -- warn player if time is running out
        if time + 1 > 10 and time <= 10 then
            if here then
                msg = "Your salvaging license will run out in 10 seconds."%_t
            else
                msg = "Your salvaging license in %s will run out in 10 seconds."%_t
            end

            doubleSend = true
        end

        if time + 1 > 20 and time <= 20 then
            if here then
                msg = "Your salvaging license will run out in 20 seconds."%_t
            else
                msg = "Your salvaging license in %s will run out in 20 seconds."%_t
            end

            doubleSend = true
        end

        if time + 1 > 30 and time <= 30 then
            if here then
                msg = "Your salvaging license will run out in 30 seconds. Renew it and save yourself some trouble!"%_t
            else
                msg = "Your salvaging license in %s will run out in 30 seconds. Renew it and save yourself some trouble!"%_t
            end
        end

        if time + 1 > 60 and time <= 60 then
            if here then
                msg = "Your salvaging license will run out in 60 seconds. Renew it NOW and save yourself some trouble!"%_t
            else
                msg = "Your salvaging license in %s will run out in 60 seconds. Renew it NOW and save yourself some trouble!"%_t
            end
        end

        if time + 1 > 120 and time <= 120 then
            if here then
                msg = "Your salvaging license will run out in 2 minutes. Renew it immediately and save yourself some trouble!"%_t
            else
                msg = "Your salvaging license in %s will run out in 2 minutes. Renew it immediately and save yourself some trouble!"%_t
            end
        end

        if time < 0 then
            licenses[factionIndex] = nil

            if here then
                msg = "Your salvaging license has expired. You may no longer salvage in this area."%_t
            else
                msg = "Your salvaging license in %s has expired. You may no longer salvage in this area."%_t
            end
        else
            licenses[factionIndex] = time
        end

        if msg then
            local x, y = Sector():getCoordinates()
            local coordinates = "${x}:${y}" % {x = x, y = y}

            faction:sendChatMessage(station, 0, msg, coordinates)
            if doubleSend then
                faction:sendChatMessage(station, 2, msg, coordinates)
            end
        end

        ::continue::
    end

end

function Scrapyard.sellCraft()

    if not CheckFactionInteraction(callingPlayer, Scrapyard.interactionThreshold) then return end

    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.ModifyCrafts, AlliancePrivilege.SpendResources)
    if not buyer then return end

    -- don't allow selling drones, would be an infinite income source
    if ship.isDrone then return end

    player.craftIndex = Uuid()

    -- Create Wreckage
    local position = ship.position
    local plan = ship:getMovePlan();
    local name = ship.name

    -- remove the old craft
    Sector():deleteEntity(ship)

    -- create a wreckage in its place
    local moneyValue = Scrapyard.getShipValue(plan)

    local wreckageIndex = Sector():createWreckage(plan, position)

    buyer:setShipDestroyed(name, true)
    buyer:removeDestroyedShipInfo(name)

    removeReconstructionKits(buyer, name)

    buyer:receive(Format("Received %2% Credits for %1% from a scrapyard."%_T, ship.name, createMonetaryString(moneyValue)), moneyValue)

    invokeClientFunction(player, "transactionComplete")
end
callable(Scrapyard, "sellCraft")

function Scrapyard.getShipValue(plan)
    local sum = plan:getMoneyValue()
    local resourceValue = {plan:getResourceValue()}

    for i, v in pairs (resourceValue) do
        sum = sum + Material(i - 1).costFactor * v * 10;
    end

    -- players only get money, and not even the full value.
    -- This is to avoid exploiting the scrapyard functionality by buying and then selling ships
    return sum * 0.75
end

function Scrapyard.buyLicense(duration)

    if not CheckFactionInteraction(callingPlayer, Scrapyard.interactionThreshold) then return end

    duration = duration or 0
    if duration <= 0 then return end

    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources)
    if not buyer then return end

    local currentDuration = licenses[buyer.index]
    local actualDurationBought = duration
    if currentDuration and (currentDuration + duration) > 60  * 60 then
        actualDurationBought = (60 * 60) - currentDuration -- player can't buy more than 60 minutes => and shouldn't pay for it either
        if actualDurationBought > duration then
            actualDurationBought = duration -- never add more than the player wants
        end
    end

    local price = Scrapyard.getLicensePrice(buyer, actualDurationBought / 60) -- minutes!
    if price < 0 then price = 0 end -- to make sure we don't accidentally give money to the player

    local station = Entity()

    local canPay, msg, args = buyer:canPay(price)
    if not canPay then
        player:sendChatMessage(station, 1, msg, unpack(args));
        return;
    end

    buyer:pay("Paid %1% Credits for a scrapyard license."%_T, price)

    -- register player's license
    licenses[buyer.index] = actualDurationBought

    -- send a message as response
    local minutes = licenses[buyer.index] / 60
    if not currentDuration then
        player:sendChatMessage(station, 0, "Thank you for choosing %1%'s salvage services. We have you listed as an licensee for the next %2% minutes."%_t, station.name, minutes);
    else
        licenses[buyer.index] = licenses[buyer.index] + currentDuration -- add up duration as we made sure above that it doesn't go above 60 min
        minutes = math.floor(licenses[buyer.index] / 60)

        player:sendChatMessage(station, 0, "Thank you for your continuing trust in us. We updated your salvaging license to %s minutes."%_t, minutes);
    end
    player:sendChatMessage(station, 0, "%s cannot be held responsible for any damage to ships or deaths caused by salvaging."%_t, Faction().name);

    Scrapyard.sendLicenseDuration()
end
callable(Scrapyard, "buyLicense")

function Scrapyard.sendLicenseDuration()
    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources)
    if not buyer then return end

    local duration = licenses[buyer.index]

    if duration ~= nil then
        invokeClientFunction(Player(callingPlayer), "setLicenseDuration", duration)
    end
end
callable(Scrapyard, "sendLicenseDuration")

function Scrapyard.onEntityDestroyed(id)
    -- when an entity is destroyed, we don't count wreckages that are created for a few seconds
    local entity = Entity(id)
    if not entity then return end
    if not entity:hasComponent(ComponentType.WreckageCreator) then return end

    if entity.type == EntityType.Ship or entity.type == EntityType.Station then
        Scrapyard.entityDestructionCounter = 0
    end
end

function Scrapyard.onEntityCreated(id)
    -- only count wreckages that were created shortly after destruction of a relevant entity
    if Scrapyard.entityDestructionCounter >= Scrapyard.maxDestructionCounter then return end

    local entity = Entity(id)
    if entity.type == EntityType.Wreckage then
        allowedWreckages[id.string] = 0
    end
end

function Scrapyard.onHullHit(objectIndex, block, shootingCraftIndex, damage, position)
    -- don't count hits that were inflicted shortly after destruction of a relevant entity
    if Scrapyard.entityDestructionCounter < Scrapyard.maxDestructionCounter then return end

    local sector = Sector()
    local object = sector:getEntity(objectIndex)
    if object and object.isWreckage then
        local shooter = sector:getEntity(shootingCraftIndex)
        if shooter then
            local faction = Faction(shooter.factionIndex)
            if not faction.isAIFaction and licenses[faction.index] == nil then
                Scrapyard.unallowedDamaging(shooter, faction, damage)
            end
        end
    end
end

function Scrapyard.hasLicense(factionIndex)
    return licenses[factionIndex]
end

function Scrapyard.onEntityDocked(parentId, childId)
    local wreckage = Entity(childId)
    if not valid(wreckage) or not wreckage.isWreckage then return end

    Sector():broadcastChatMessage(Entity(), ChatMessageType.Normal, "Docking and stealing wreckages is not permitted!"%_T)

    changeRelations(Faction(), parentId, -2500, RelationChangeType.GeneralIllegal, nil, nil, Faction())

    dockedWreckages[childId.string] = true

    Scrapyard.cleanUpDockedWreckages()
end

function Scrapyard.onEntityUndocked(parentId, childId)
    dockedWreckages[childId.string] = nil

    Scrapyard.cleanUpDockedWreckages()
end

function Scrapyard.onEntityJump(id)
    if not dockedWreckages[id.string] then return end
    dockedWreckages[id.string] = nil
    Scrapyard.cleanUpDockedWreckages()

    local wreckage = Entity(id)
    if not valid(wreckage) or not wreckage.isWreckage then return end

    local parentId = wreckage.dockingParent
    if not parentId then return end

    changeRelations(Faction(), parentId, -10000, RelationChangeType.GeneralIllegal, nil, nil, Faction())
end

function Scrapyard.cleanUpDockedWreckages()
    for _, id in pairs(dockedWreckages) do
        if not valid(Entity(id)) then
            dockedWreckages[id] = nil
        end
    end
end

function Scrapyard.dismantleInventoryTurret(inventoryIndex)

    if not CheckFactionInteraction(callingPlayer, Scrapyard.interactionThreshold) then return end

    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendItems, AlliancePrivilege.TakeItems)
    if not buyer then return end

    local inventory = buyer:getInventory()
    local turret = inventory:find(inventoryIndex)
    if not turret or turret.itemType ~= InventoryItemType.Turret then return end

    local goods = Scrapyard.getTurretGoods(turret)

    local totalSize = 0
    for _, result in pairs(goods) do
        totalSize = totalSize + result.amount + result.good.size
    end

    local cargoBay = CargoBay(ship)
    if not cargoBay or cargoBay.freeSpace < totalSize then
        player:sendChatMessage(Entity(), ChatMessageType.Error, "Not enough cargo space for all dismantled goods!"%_T)
        return
    end

    inventory:take(inventoryIndex)

    for _, result in pairs(goods) do
        cargoBay:addCargo(result.good, result.amount)
    end

    invokeClientFunction(player, "onTurretDismantled")

end
callable(Scrapyard, "dismantleInventoryTurret")

function Scrapyard.dismantleTrash()

    if not CheckFactionInteraction(callingPlayer, Scrapyard.interactionThreshold) then return end

    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendItems, AlliancePrivilege.TakeItems)
    if not buyer then return end

    local inventory = buyer:getInventory()

    local items = buyer:getInventory():getItems()

    for inventoryIndex, slotItem in pairs(items) do

        local turret = slotItem.item
        if turret == nil then goto continue end
        if not turret.trash then goto continue end
        if turret.itemType ~= InventoryItemType.Turret then goto continue end

        local stop = false

        for i = 1, slotItem.amount do

            local goods = Scrapyard.getTurretGoods(turret)

            local totalSize = 0
            for _, result in pairs(goods) do
                totalSize = totalSize + result.amount + result.good.size
            end

            local cargoBay = CargoBay(ship)
            if not cargoBay or cargoBay.freeSpace < totalSize then
                player:sendChatMessage(Entity(), ChatMessageType.Error, "Not enough cargo space for all dismantled goods!"%_T)
                stop = true
                break
            end

            if inventory:take(inventoryIndex) then
                for _, result in pairs(goods) do
                    cargoBay:addCargo(result.good, result.amount)
                end
            end
        end

        if stop then break end

        ::continue::
    end

    invokeClientFunction(player, "onTurretDismantled")
end
callable(Scrapyard, "dismantleTrash")









function Scrapyard.getTurretGoods(turret)
    local item = SellableInventoryItem(turret)
    local value = item.price * 0.1

    local weaponType = WeaponTypes.getTypeOfItem(turret)

    local gainable = table.deepcopy(TurretIngredients[weaponType]) or table.deepcopy(TurretIngredients[WeaponType.ChainGun])
    local usedGoods = {}

    table.insert(gainable, {name = "Scrap Metal"})
    table.insert(gainable, {name = "Servo"})

    for _, ingredient in pairs(gainable) do
        ingredient.good = goods[ingredient.name]:good()
        usedGoods[ingredient.good.name] = ingredient.good
    end

    local possibleGoods
    local result = {}
    result["Servo"] = 1

    for i = 1, (3 + turret.rarity.value) do

        -- remove all ingredients which, by themselves, would already be more expensive than the remaining value of the turret
        for k, ingredient in pairs(gainable) do
            if ingredient.good.price > value then
                gainable[k] = nil
            end
        end

        -- on first iteration, those goods are the ones that are technically possible
        if not possibleGoods then
            possibleGoods = {}

            local added = {}
            for k, ingredient in pairs(gainable) do
                if not added[ingredient.name] then
                    table.insert(possibleGoods, usedGoods[ingredient.name])
                    added[ingredient.name] = true
                end
            end

            if not added["Servo"] then
                table.insert(possibleGoods, usedGoods["Servo"])
            end
        end

        if tablelength(gainable) > 1 then
            local weights = {}

            for k, ingredient in pairs(gainable) do
                weights[ingredient.name] = (ingredient.amount or 0) + 2
            end
            local name = selectByWeight(random(), weights)

            local maxAmount = math.max(1, math.floor(value / usedGoods[name].price))
            local gained = math.min(maxAmount, 5)

            result[name] = (result[name] or 0) + gained

            value = value - usedGoods[name].price * gained
        else
            for _, ingredient in pairs(gainable) do
                local name = ingredient.name
                local amount = math.max(1, math.floor(value / usedGoods[name].price))

                result[name] = (result[name] or 0) + amount
                break
            end

            break
        end
    end

    for k, amount in pairs(result) do
        result[k] = {name = k, amount = amount, good = usedGoods[k]}
    end

    return result, possibleGoods
end


function Scrapyard.unallowedDamaging(shooter, faction, damage)

    local pilots = {}

    if faction.isAlliance then
        for _, playerIndex in pairs({shooter:getPilotIndices()}) do
            local player = Player(playerIndex)

            if player then
                table.insert(pilots, player)
            end
        end

    elseif faction.isPlayer then
        table.insert(pilots, Player(faction.index))
    end

    local station = Entity()

    local actions = illegalActions[faction.index]
    if actions == nil then
        actions = 0
    end

    newActions = actions + damage

    for _, player in pairs(pilots) do
        if actions < 10 and newActions >= 10 then
            player:sendChatMessage(station, 0, "Salvaging or damaging wreckages in this sector is illegal. Please buy a salvaging license."%_t);
            player:sendChatMessage(station, 2, "You need a salvaging license for this sector."%_t);
        end

        if actions < 200 and newActions >= 200 then
            player:sendChatMessage(station, 0, "Salvaging wreckages in this sector is forbidden. Please buy a salvaging license."%_t);
            player:sendChatMessage(station, 2, "You need a salvaging license for this sector."%_t);
        end

        if actions < 500 and newActions >= 500 then
            player:sendChatMessage(station, 0, "Wreckages in this sector are the property of %s. Please buy a salvaging license."%_t, Faction().name);
            player:sendChatMessage(station, 2, "You need a salvaging license for this sector."%_t);
        end

        if actions < 1000 and newActions >= 1000 then
            player:sendChatMessage(station, 0, "Illegal salvaging will be punished by destruction. Buy a salvaging license or there will be consequences."%_t);
            player:sendChatMessage(station, 2, "You need a salvaging license for this sector."%_t);
        end

        if actions < 1500 and newActions >= 1500 then
            player:sendChatMessage(station, 0, "This is your last warning. If you do not stop salvaging without a license, you will be destroyed."%_t);
            player:sendChatMessage(station, 2, "You need a salvaging license for this sector."%_t);
        end

        if actions < 2000 and newActions >= 2000 then
            player:sendChatMessage(station, 0, "You have been warned. You will be considered an enemy of %s if you do not stop your illegal activities."%_t, Faction().name);
            player:sendChatMessage(station, 2, "You need a salvaging license for this sector."%_t);
        end
    end

    if newActions > 5 then
        changeRelations(Faction(), faction, -newActions / 100, RelationChangeType.GeneralIllegal, nil, nil, Faction())
    end

    illegalActions[faction.index] = newActions

end


