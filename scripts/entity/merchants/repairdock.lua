package.path = package.path .. ";data/scripts/lib/?.lua"
include ("galaxy")
include ("utility")
include ("faction")
include ("randomext")
include ("stringutility")
include ("callable")
include ("merchantutility")
include ("reconstructionutility")
include ("relations")
local Dialog = include("dialogutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace RepairDock
RepairDock = {}
RepairDock.tax = 0.2
RepairDock.scroll = 1
RepairDock.interactionThreshold = -30000

local window = nil
local tabbedWindow = nil
local repairTab = nil
local kitsTab = nil
local reconstructionTab = nil
local planDisplayer = nil
local repairButton = nil
local creditsOnlyComboBox = nil

local costLabel = nil
local moneyCostLabels = nil
local materialCostLabels = nil

local priceDescriptionLabel1
local reconstructionPriceLabel
local reconstructionButton

local buyKitNameCombo
local buyKitPriceLabel
local buyKitAmountLabel
local buyKitButton

local reconstructionLines = {}
local notReconstructionSiteTowingLabel
local reconstructionSiteTowingLabel

-- if this function returns false, the script will not be listed in the interaction window on the client,
-- even though its UI may be registered
function RepairDock.interactionPossible(playerIndex, option)
    return CheckFactionInteraction(playerIndex, RepairDock.interactionThreshold)
end

-- this function gets called on creation of the entity the script is attached to, on client and server
function RepairDock.initialize()
    local station = Entity()

    if station.title == "" then
        station.title = "Repair Dock /* Station Title*/"%_t
    end

    if onClient() and EntityIcon().icon == "" then
        EntityIcon().icon = "data/textures/icons/pixel/repair.png"
        InteractionText(station.index).text = Dialog.generateStationInteractionText(station, random())
    end

    if onServer() then
        RepairDock.setAsRespawnSite()

        Sector():registerCallback("onPlayerEntered", "onPlayerEntered")
    end
end

-- this function gets called on creation of the entity the script is attached to, on client only
-- AFTER initialize above
-- create all required UI elements for the client side
function RepairDock.initUI()

    local res = getResolution()
    local size = vec2(600, 600)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5));
    menu:registerWindow(window, "Repair Dock /* Interaction Title*/"%_t, 9);

    window.caption = "Repair Dock /* Station Title*/"%_t
    window.showCloseButton = 1
    window.moveable = 1

    tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 10), size - vec2(10, 10)))
    local tab = tabbedWindow:createTab("", "data/textures/icons/repair.png", "Repair your ship"%_t)
    repairTab = tab


    local costLister = UIVerticalLister(Rect(tab.size), 0, 0)
    costLabel = tab:createLabel(costLister:nextRect(20), "Repair Costs:"%_t, 13)
    costLabel.font = FontType.SciFi

    local rect = costLister:nextRect(20)
    local captionLabel = tab:createLabel(rect, "¢"%_t, 13)
    captionLabel.font = FontType.SciFi
    local valueLabel = tab:createLabel(Rect(rect.lower + vec2(100, 0), rect.upper), "", 13)
    valueLabel.font = FontType.SciFi
    moneyCostLabels = {captionLabel = captionLabel, valueLabel = valueLabel}

    materialCostLabels = {}
    for i = 1, NumMaterials() do
        local material = Material(i - 1)
        local rect = costLister:nextRect(16)
        local captionLabel = tab:createLabel(rect, "", 13)
        captionLabel.font = FontType.SciFi

        local valueLabel = tab:createLabel(Rect(rect.lower + vec2(100, 0), rect.upper), "", 13)
        valueLabel.font = FontType.SciFi

        table.insert(materialCostLabels, {captionLabel = captionLabel, valueLabel = valueLabel})
    end

    local hsplit = UIHorizontalSplitter(Rect(tab.size), 0, 0, 1.0)
    hsplit.topSize = 30
    local hsplitBottom = UIHorizontalSplitter(hsplit.bottom, 10, 0, 1.0)
    hsplitBottom.bottomSize = 40

    planDisplayer = tab:createPlanDisplayer(hsplitBottom.top)
    planDisplayer.showStats = 0

    local vsplitComboBox = UIVerticalSplitter(hsplit.top, 10, 0, 0.6)
    vsplitComboBox:setPadding(0, 0, 5, 0)

    creditsOnlyComboBox = tab:createValueComboBox(vsplitComboBox.right, "onCreditsOnlyComboChanged")
    creditsOnlyComboBox:addEntry(false, "Credits + Materials"%_t)
    creditsOnlyComboBox:addEntry(true, "Credits Only"%_t)
    repairButton = tab:createButton(hsplitBottom.bottom, "Repair /* Action */"%_t, "onRepairButtonPressed")


    -- setting of Reconstruction Site
    local tab = tabbedWindow:createTab("", "data/textures/icons/reconstruction-token.png", "")
    kitsTab = tab

    local hsplit = UIHorizontalSplitter(Rect(tab.size), 10, 0, 0.73)

    local lister = UIVerticalLister(hsplit.top, 5, 0)

    for i = 0, 1 do
        local rect = lister:nextRect(30)

        local vsplit = UIArbitraryVerticalSplitter(rect, 5, 0, 200, 350, 400)

        if i == 1 then
            buyKitNameCombo = tab:createValueComboBox(vsplit:partition(0), "onShipNameSelected")
            tab:createFrame(Rect(vsplit:partition(0).topRight, vsplit:partition(2).bottomRight))

            buyKitButton = tab:createButton(vsplit:partition(3), "Buy Kit"%_t, "onBuyKitButtonPressed")
            buyKitButton.textSize = 14
        end

        vsplit:setMargin(10, 10, 3, 3)
        vsplit:setPadding(10, 10, 10, 10)

        local nameLabel = tab:createLabel(vsplit:partition(0), "", 13)
        local priceLabel = tab:createLabel(vsplit:partition(1), "10.000.000.000", 13)
        local amountLabel = tab:createLabel(vsplit:partition(2), "1", 13)

        nameLabel:setLeftAligned()
        priceLabel:setLeftAligned()
        amountLabel:setLeftAligned()

        if i > 0 then
            buyKitPriceLabel = priceLabel
            buyKitAmountLabel = amountLabel
        else
            nameLabel.caption = "CRAFT"%_t
            priceLabel.caption = "¢"
            amountLabel.caption = "KITS"%_t
        end
    end

    -- explanation for Reconstruction Kits
    local rect = lister:nextRect(10)
    local rect = lister:nextRect(10)
    tab:createLine(rect.topLeft, rect.topRight)

    lister.margin = 5
    priceDescriptionLabel1 = tab:createLabel(lister:nextRect(20), "Reconstruction Kit: Allows quick reconstruction of a destroyed ship or station from its wreckage."%_t, 12)
    priceDescriptionLabel1.fontSize = 12
    priceDescriptionLabel1.wordBreak = true
    priceDescriptionLabel1.color = ColorRGB(0.4, 1.0, 0.4)
    priceDescriptionLabel1:setCenterAligned()

    -- setting of reconstruction site
    local splitter = UIHorizontalSplitter(hsplit.bottom, 10, 0, 0.5)
    splitter.bottomSize = 40
    tab:createLine(hsplit.top.bottomLeft, hsplit.top.bottomRight)

    setReconstructionSiteButton = tab:createButton(splitter.bottom, "Use as Reconstruction Site /* Action */"%_t, "onUseReconstructionSiteButtonPressed")

    local lister = UIVerticalLister(splitter.top, 10, 5)

    local label = tab:createLabel(lister:nextRect(60), "Reconstruction Site Bonuses:\n- Tow ships from anywhere in the galaxy\n- Repair & Tow for free\n- Switch to this sector from the Galaxy Map"%_t, 12)
    label.fontSize = 12
    label.wordBreak = true

    local rect = lister:nextRect(25)

    reconstructionPriceLabel = tab:createLabel(rect.topLeft, "Price: "%_t, 12)


    -- reconstruction of ships
    local tab = tabbedWindow:createTab("", "data/textures/icons/reconstruct-ship.png", "")
    reconstructionTab = tab

    local hsplit = UIHorizontalSplitter(Rect(tab.size), 10, 0, 0.75)

    local lister = UIVerticalLister(hsplit.top, 5, 0)

    for i = 0, 10 do
        local rect = lister:nextRect(30)

        local vsplit = UIArbitraryVerticalSplitter(rect, 5, 0, 220, 365, 400)
        local frame = tab:createFrame(Rect(vsplit:partition(0).topLeft, vsplit:partition(2).bottomRight))

        local button = tab:createButton(vsplit:partition(3), "Tow"%_t, "onReconstructButtonPressed")
        button.textSize = 14

        local iconRect = vsplit:partition(2)
        iconRect.size = iconRect.size - 4
        local icon = tab:createPicture(iconRect, "data/textures/icons/alliance.png")
        icon.isIcon = true
        icon.color = ColorRGB(0.7, 0.7, 0.7)
        icon.tooltip = "Alliance Ship"%_t

        vsplit:setMargin(10, 10, 3, 3)
        vsplit:setPadding(10, 10, 10, 10)

        local nameLabel = tab:createLabel(vsplit:partition(0), "Ship 123", 13)
        local priceLabel = tab:createLabel(vsplit:partition(1), "10.000", 13)

        nameLabel:setLeftAligned()
        priceLabel:setLeftAligned()

        if i > 0 then
            local line = {nameLabel = nameLabel, priceLabel = priceLabel, frame = frame, button = button, icon = icon}
            table.insert(reconstructionLines, line)

            line.hide = function(self)
                self.nameLabel:hide()
                self.priceLabel:hide()
                self.frame:hide()
                self.button:hide()
                self.icon:hide()
            end

            line.show = function(self)
                self.nameLabel:show()
                self.priceLabel:show()
                self.frame:show()
                self.button:show()
                self.icon:show()
            end
        else
            nameLabel.caption = "SHIP"%_t
            priceLabel.caption = "PRICE"%_t
            button:hide()
            icon:hide()
            frame:hide()
        end
    end

    tab:createLine(hsplit.top.bottomLeft, hsplit.top.bottomRight)

    local lister = UIVerticalLister(hsplit.bottom, 10, 5)

    local label = tab:createLabel(lister:nextRect(40), "Towing: brings a ship's wreckage into this sector and quickly reassembles it. Your ship may be in need of some repairs afterwards."%_t, 12)
    label.fontSize = 12
    label.wordBreak = true

    local rect = lister:nextRect(40)
    notReconstructionSiteTowingLabel = tab:createLabel(rect, "Will only tow ships that were destroyed or lost in a 50 sector radius (exception: Reconstruction Site)."%_t, 12)
    notReconstructionSiteTowingLabel.fontSize = 12
    notReconstructionSiteTowingLabel.wordBreak = true
    notReconstructionSiteTowingLabel:setCenterAligned();

    reconstructionSiteTowingLabel = tab:createLabel(rect, "This is your reconstruction site. You can tow destroyed or lost ships to this place from anywhere in the galaxy. For free!"%_t, 12)
    reconstructionSiteTowingLabel.fontSize = 12
    reconstructionSiteTowingLabel.wordBreak = true
    reconstructionSiteTowingLabel:setCenterAligned();
    reconstructionSiteTowingLabel.color = ColorRGB(0.4, 1.0, 0.4)

end

function RepairDock.initializationFinished()

    local specificLinesRepairDock = {}
    specificLinesRepairDock = {
        "Problems with docking? Scratches on the hull? We'll fix that for you."%_t,
        "Asteroid-fall damage on the windshield? We'll fix that for you."%_t,
        "Almost got destroyed by pirates? We'll fix that for you."%_t,
        "The Xsotan are really good for business. Just like pirates. But don't tell anyone I said that."%_t,
        "We're lucky that shields don't protect against asteroids. We'd be out of business if they did."%_t,
        "Destroyed by pirates? Our brand-new Towing Service is here for you!"%_t,
        "Destroyed by Xsotan? Our brand-new Towing Service is here for you!"%_t,
    }

    if getLanguage() == "en" then
        -- these don't have translation markers on purpose
        table.insert(specificLinesRepairDock, "What doesn't kill you, makes you stronger. But damn, those hull breaches are tedious to fix.")
        table.insert(specificLinesRepairDock, "Looks like you got into a fight. You should check our repair dock for repairs.")
    end

    -- use the initilizationFinished() function on the client since in initialize() we may not be able to access Sector scripts on the client
    if onClient() then
        local ok, r = Sector():invokeFunction("radiochatter", "addSpecificLines", Entity().id.string, specificLinesRepairDock)
    end
end

-- this function gets called every time the window is shown on the client, ie. when a player presses F and if interactionPossible() returned 1
function RepairDock.onShowWindow()
    RepairDock.refreshUI()

    local ship = Player().craft
    if ship then
        buyKitNameCombo.selectedValue = ship.name
    end
end

function RepairDock.refreshUI()
    -- this could get called by the server at seemingly random times, so we must check that the UI was initialized
    if not window then return end

    -- repairing
    local withPlan = true
    RepairDock.refreshRepairUI(withPlan)

    -- reconstruction site & kits
    RepairDock.refreshReconstructionKits()

    if not GameSettings().reconstructionAllowed then
        tabbedWindow:deactivateTab(reconstructionTab)
    else
        -- reconstructing ships
        RepairDock.refreshReconstructionLines()
    end
end

function RepairDock.onCreditsOnlyComboChanged()
    local withPlan = false
    RepairDock.refreshRepairUI(withPlan)
end

function RepairDock.refreshRepairUI(withPlan)
    -- repair ship
    local player = Player()
    local buyer = player
    local ship = buyer.craft
    if ship.factionIndex == buyer.allianceIndex then
        buyer = buyer.alliance
        DebugInfo():log("RepairDock.onShowWindow Alliance")
    else
        DebugInfo():log("RepairDock.onShowWindow Player")
    end

    -- reset UI
    moneyCostLabels.valueLabel.caption = "-"

    for _, labels in pairs(materialCostLabels) do
        labels.captionLabel.visible = false
        labels.valueLabel.visible = false
    end

    -- get the plan of the player (or alliance)'s ship template
    local intact = buyer:getShipPlan(ship.name)
    planDisplayer.visible = (intact ~= nil)

    if not intact then
        repairButton.active = false
        repairButton.tooltip = nil
        return
    end

    -- get the plan of the player's ship
    local broken = ship:getFullPlanCopy()

    if withPlan then
        -- set to display
        planDisplayer:setPlans(broken, intact)
    end

    local moneyCost = 0
    local resourceCost = {}
    if creditsOnlyComboBox.selectedValue then
        moneyCost = RepairDock.getRepairMoneyCostAndTaxCreditsOnly(player, buyer, ship, intact, broken, ship.durability / ship.maxDurability)
    else
        moneyCost = RepairDock.getRepairMoneyCostAndTax(player, buyer, ship, intact, broken, ship.durability / ship.maxDurability)
        resourceCost = RepairDock.getRepairResourcesCost(player, buyer, ship, intact, broken, ship.durability / ship.maxDurability)
    end

    moneyCostLabels.valueLabel.caption = createMonetaryString(moneyCost)
    moneyCostLabels.valueLabel.color = ColorRGB(0.9, 0.9, 0.9)

    if RepairDock.isReconstructionSite() then
        moneyCostLabels.valueLabel.caption = "Free"%_t
        moneyCostLabels.valueLabel.color = ColorRGB(0.4, 1.0, 0.4)
    end

    -- ship counts as damaged (=> repair button is active) if repairs can be paid for
    local damaged = (moneyCost > 0)

    local l = 1
    for i, cost in pairs(resourceCost) do
        if cost > 0 then
            local material = Material(i - 1)
            materialCostLabels[l].captionLabel.caption = material.name
            materialCostLabels[l].captionLabel.visible = cost > 0
            materialCostLabels[l].captionLabel.color = material.color
            materialCostLabels[l].valueLabel.caption = createMonetaryString(cost)
            materialCostLabels[l].valueLabel.visible = cost > 0
            materialCostLabels[l].valueLabel.color = material.color

            damaged = true
            l = l + 1
        end
    end

    -- ship counts as damaged (=> repair button is active) if durability is not at max or block counts don't match
    if ship.durability < ship.maxDurability then damaged = true end
    if broken.numBlocks ~= intact.numBlocks then damaged = true end

    if damaged then
        repairButton.active = true
        repairButton.tooltip = nil
    else
        repairButton.active = false
        repairButton.tooltip = "Your ship is not damaged."%_t
    end
end

function RepairDock.refreshReconstructionKits()

    if RepairDock.isShipyardRepairDock() then
        tabbedWindow:deactivateTab(kitsTab)
        kitsTab.description = "Only available at Repair Docks, not Shipyards!"%_t
        return
    else
        tabbedWindow:activateTab(kitsTab)
        kitsTab.description = "Reconstruction Kits"%_t
    end

    local player = Player()
    local buyer = Galaxy():getPlayerCraftFaction()
    local ship = player.craft

    reconstructionPriceLabel.caption = "Price: ¢${money}"%_t % {money = createMonetaryString(RepairDock.getReconstructionSiteChangePrice())}

    if buyer.isAlliance then
        setReconstructionSiteButton.active = false
        setReconstructionSiteButton.tooltip = "Alliances don't have Reconstruction Sites."%_t
    elseif RepairDock.isReconstructionSite() then
        setReconstructionSiteButton.active = false
        setReconstructionSiteButton.tooltip = "This sector is already your Reconstruction Site."%_t
    elseif not CheckFactionInteraction(buyer.index, 60000) then
        setReconstructionSiteButton.active = false
        setReconstructionSiteButton.tooltip = "We only offer these kinds of services to people we have relations of at least 60,000 with."%_t
    else
        setReconstructionSiteButton.active = true
        setReconstructionSiteButton.tooltip = nil
    end

    local previous = buyKitNameCombo.selectedValue
    buyKitNameCombo:clear()

    buyKitNameCombo.active = GameSettings().reconstructionAllowed
    buyKitButton.active = GameSettings().reconstructionAllowed
    buyKitAmountLabel.active = GameSettings().reconstructionAllowed
    buyKitAmountLabel.caption = ""
    buyKitPriceLabel.active = GameSettings().reconstructionAllowed

    if GameSettings().reconstructionAllowed then
        local names = {buyer:getShipNames()}
        for _, name in pairs(names) do
            local kits = countReconstructionKits(player, name, buyer.index)
            local akits = 0

            local alliance = player.alliance
            if alliance then
                akits = countReconstructionKits(alliance, name, buyer.index)
            end

            if kits == 0 and akits == 0 then
                buyKitNameCombo:addEntry(name, name, ColorRGB(0.9, 0.9, 0.9))
            else
                buyKitNameCombo:addEntry(name, name, ColorRGB(0.5, 0.5, 0.5))
            end
        end

        if previous then
            buyKitNameCombo.selectedValue = previous
        end
        RepairDock.onShipNameSelected()

        buyKitButton.active = (#names > 0)

        local price = RepairDock.getReconstructionKitPrice(buyer)
        buyKitPriceLabel.caption = createMonetaryString(price)
        buyKitPriceLabel.color = ColorRGB(1, 1, 1)
        buyKitPriceLabel.tooltip = nil
    else
        buyKitAmountLabel.caption = "-"
        buyKitPriceLabel.caption = "-"
        buyKitButton.tooltip = nil
        priceDescriptionLabel1:hide()
    end
end

function RepairDock.onShipNameSelected()
    local name = buyKitNameCombo.selectedValue

    buyKitAmountLabel.caption = ""
    buyKitButton.active = (name ~= nil)
    if not name then return end

    local player = Player()
    local buyer = Galaxy():getPlayerCraftFaction()

    local kits = countReconstructionKits(player, name, buyer.index) or 0
    local akits = 0

    local alliance = player.alliance
    if alliance then
        akits = countReconstructionKits(alliance, name, buyer.index)
    end

    buyKitAmountLabel.caption = tostring(kits + akits)

    if akits > 0 then
        buyKitButton.active = false
        buyKitButton.tooltip = "Your alliance already owns a Reconstruction Kit for this ship."%_t
    elseif kits > 0 then
        buyKitButton.active = false
        buyKitButton.tooltip = "You already own a Reconstruction Kit for this ship."%_t
    else
        buyKitButton.active = true
        buyKitButton.tooltip = nil
    end
end

function RepairDock.refreshReconstructionLines()

    if RepairDock.isShipyardRepairDock() then
        tabbedWindow:deactivateTab(reconstructionTab)
        reconstructionTab.description = "Only available at Repair Docks, not Shipyards!"%_t
        return
    else
        tabbedWindow:activateTab(reconstructionTab)
        reconstructionTab.description = "Towing Service"%_t
    end

    local player = Player()
    local alliance = player.alliance

    local buyers = {}
    if alliance then
        local playerCraftFaction = Galaxy():getPlayerCraftFaction()

        if playerCraftFaction.index == alliance.index then
            buyers = {alliance, player}
        else
            buyers = {player, alliance}
        end
    else
        buyers = {player}
    end

    local scroll = RepairDock.scroll
    local s = 1
    local l = 1

    for _, buyer in pairs(buyers) do
        local shipNames = {buyer:getShipNames()}
        for _, name in pairs(shipNames) do

            if not buyer:getShipDestroyed(name) then goto continue end
            local line = reconstructionLines[l]

            local price, error = RepairDock.getTowingPrice(player, buyer, name)
            if not price then goto continue end

            line.priceLabel.caption = "¢${price}"%_t % {price = createMonetaryString(price)}
            line.button.tooltip = "Tow and reconstruct the ship in this sector"%_t

            line:show()
            line.shipName = name
            line.nameLabel.caption = name
            line.icon.visible = buyer.isAlliance
            line.allianceShip = buyer.isAlliance

            if error then
                line.button.active = false
                line.button.tooltip = error
            else
                line.button.active = true
                line.button.tooltip = nil
            end

            l = l + 1
            if l > #reconstructionLines then break end

            ::continue::
        end

        if l > #reconstructionLines then break end
    end

    for i = l, #reconstructionLines do
        reconstructionLines[i]:hide()
    end

    if RepairDock.isReconstructionSite(Player()) then
        reconstructionSiteTowingLabel:show()
        notReconstructionSiteTowingLabel:hide()
    else
        reconstructionSiteTowingLabel:hide()
        notReconstructionSiteTowingLabel:show()
    end
end

-- this function gets called every time the window is closed on the client
function RepairDock.onCloseWindow()
end

function RepairDock.onBuyKitButtonPressed()
    local name = buyKitNameCombo.selectedValue

    invokeServerFunction("buyKit", name)
end

function RepairDock.onReconstructButtonPressed(arg)
    -- find the matching button and thus name of the ship that should be reconstructed
    local name
    local allianceShip
    for _, line in pairs(reconstructionLines) do
        if line.button.index == arg.index then
            name = line.shipName
            allianceShip = line.allianceShip
            break
        end
    end

    if name then
        invokeServerFunction("reconstruct", name, allianceShip)
    end
end

function RepairDock.clientReconstruct(shipName)
    invokeServerFunction("reconstruct", shipName)
end

function RepairDock.onRepairButtonPressed()
    invokeServerFunction("repairCraft", creditsOnlyComboBox.selectedValue)
end

function RepairDock.onUseReconstructionSiteButtonPressed()
    invokeServerFunction("setAsReconstructionSite")
end

function RepairDock.transactionComplete()
    ScriptUI():stopInteraction()
end

function RepairDock.repairCraft(creditsOnly)
    if not CheckFactionInteraction(callingPlayer, RepairDock.interactionThreshold) then return end

    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources)
    if not buyer then return end

    local station = Entity()

    local dist = station:getNearestDistance(ship)
    if dist > 100 then
        player:sendChatMessage(station, 1, "You can't be more than 1km away to repair your ship."%_t)
        return
    end

    local canRepairError = canRepairInCurrentEnvironment(ship)
    if canRepairError ~= BuildError.BuildingOk then
        local messages = {}
        messages[BuildError.EnemiesNearby] = "You can't repair your ship while enemies are nearby."%_T
        messages[BuildError.UnderAttack] = "You can't repair your ship while enemies are nearby."%_T
        messages[BuildError.RecentlyDamaged] = "You were damaged recently."%_T

        local message = messages[canRepairError] or "You can't repair your ship right now."%_T
        player:sendChatMessage(station, 1, message)
        return
    end

    -- this function is executed on the server
    local perfectPlan = buyer:getShipPlan(ship.name)
    if not perfectPlan then return end

    local damagedPlan = ship:getFullPlanCopy()
    if not damagedPlan then return end

    local requiredMoney, tax
    local requiredResources = {0, 0, 0, 0, 0, 0, 0}

    if creditsOnly then
        requiredMoney, tax = RepairDock.getRepairMoneyCostAndTaxCreditsOnly(player, buyer, ship, perfectPlan, damagedPlan, ship.durability / ship.maxDurability)
    else
        requiredMoney, tax = RepairDock.getRepairMoneyCostAndTax(player, buyer, ship, perfectPlan, damagedPlan, ship.durability / ship.maxDurability)
        requiredResources = RepairDock.getRepairResourcesCost(player, buyer, ship, perfectPlan, damagedPlan, ship.durability / ship.maxDurability)
    end

    local canPay, msg, args = buyer:canPay(requiredMoney, unpack(requiredResources))

    if not canPay then
        player:sendChatMessage(station, 1, msg, unpack(args))
        return
    end

    receiveTransactionTax(station, tax)

    buyer:pay(requiredMoney, unpack(requiredResources))

    perfectPlan:resetDurability()
    ship:setMalusFactor(1.0, MalusReason.None)
    ship:setMovePlan(perfectPlan)
    ship.durability = ship.maxDurability

    -- re-apply turret designs
    local turretBases = TurretBases(ship)
    if turretBases then
        local turretDesigns = buyer:getShipTurretDesigns(ship.name)
        turretBases:setDesigns(turretDesigns)
    end

    -- re-add broken turrets
    buyer:restoreTurrets(ship)

    -- relations of the player to the faction owning the repair dock get better
    local relationsChange = GetRelationChangeFromMoney(requiredMoney)
    for i = 1, NumMaterials() do
        relationsChange = relationsChange + requiredResources[i] / 4
    end

    changeRelations(buyer, Faction(), relationsChange, RelationChangeType.ServiceUsage, nil, nil, station)

    invokeClientFunction(player, "refreshUI")
    invokeClientFunction(player, "transactionComplete")

end
callable(RepairDock, "repairCraft")

function RepairDock.reconstruct(shipName, allianceShip)

    if not CheckFactionInteraction(callingPlayer, RepairDock.interactionThreshold) then return end

    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.ManageShips, AlliancePrivilege.SpendItems)
    if not buyer then return end

    -- if we're requesting an alliance ship to be rebuilt and the buyer is a player, then switch the buyer to be the alliance instead
    if allianceShip == true and buyer.isPlayer and buyer.alliance then
        local alliance = buyer.alliance

        -- we still have to check for privileges
        local requiredPrivileges = {AlliancePrivilege.ManageShips, AlliancePrivilege.SpendItems}
        for _, privilege in pairs(requiredPrivileges) do
            if not alliance:hasPrivilege(callingPlayer, privilege) then
                player:sendChatMessage("", 1, "You don't have permission to do that in the name of your alliance."%_t)
                return
            end
        end

        buyer = player.alliance
    -- allicanceShip could be false or nil
    elseif not allianceShip and buyer.isAlliance then
        buyer = player
    end

    if RepairDock.isShipyardRepairDock() then
        player:sendChatMessage(Entity(), ChatMessageType.Error, "Shipyards don't offer these kinds of services."%_T)
        return
    end

    -- reconstructing stations is not possible
    if buyer:getShipType(shipName) ~= EntityType.Ship then
        player:sendChatMessage(Entity(), ChatMessageType.Error, "Can only reconstruct ships."%_T)
        return
    end

    if not GameSettings().reconstructionAllowed then
        player:sendChatMessage(Entity(), ChatMessageType.Error, "Reconstruction impossible."%_T)
        return
    end

    -- reconstructing non-destroyed ships is impossible
    if not buyer:getShipDestroyed(shipName) then
        player:sendChatMessage(Entity(), ChatMessageType.Error, "Ship wasn't destroyed."%_T)
        return
    end

    local price, error = RepairDock.getTowingPrice(player, buyer, shipName)
    if error then
        player:sendChatMessage(Entity(), ChatMessageType.Error, error)
        return
    end

    local canPay, msg, args = buyer:canPay(price)
    if not canPay then
        player:sendChatMessage(Entity(), ChatMessageType.Error, msg, unpack(args))
        return
    end

    buyer:pay("Paid %1% Credits to reconstruct a ship."%_T, price)

    -- find a position to put the craft
    local position = Matrix()
    local station = Entity()
    local box = buyer:getShipBoundingBox(shipName)

    -- try putting the ship at a dock
    local docks = DockingPositions(station)
    local dockIndex = docks:getFreeDock()
    if dockIndex then
        local dock = docks:getDockingPosition(dockIndex)
        local pos = vec3(dock.position.x, dock.position.y, dock.position.z)
        local dir = vec3(dock.direction.x, dock.direction.y, dock.direction.z)

        pos = station.position:transformCoord(pos)
        dir = station.position:transformNormal(dir)

        pos = pos + dir * (box.size.z / 2 + 10)

        local up = station.position.up

        position = MatrixLookUpPosition(-dir, up, pos)
    else
        -- if all docks are occupied, place it near the station
        -- use the same orientation as the station
        position = station.orientation

        local sphere = station:getBoundingSphere()
        position.translation = sphere.center + random():getDirection() * (sphere.radius + length(box.size) / 2 + 50);
    end

    local withMalus = true
    local entry = ShipDatabaseEntry(buyer.index, shipName)
    if entry:getScriptValue("lost_in_rift") then
        withMalus = false
    end

    local sx, sy = buyer:getShipPosition(shipName)
    local x, y = Sector():getCoordinates()

    local craft = buyer:restoreCraft(shipName, position, withMalus)
    if not craft then
        player:sendChatMessage(Entity(), ChatMessageType.Error, "Error reconstructing craft."%_t)
        return
    end

    CargoBay(craft):clear()
    craft:setValue("untransferrable", nil) -- tutorial could have broken this
    craft:setValue("lost_in_rift", nil) -- it's obviously no longer lost in a rift
    craft:setValue("left_in_rift", nil) -- it's obviously no longer left in a rift

    if ship.isDrone then
        player.craft = craft
        invokeClientFunction(player, "transactionComplete")
    end

    if Balancing_InsideRing(sx, sy) and not Balancing_InsideRing(x, y) then
        Sector():broadcastChatMessage(Entity(), ChatMessageType.Normal, "Towing & Reconstruction complete! Thanks to your instructions, we found the wormhole to the center. That was a wild ride!"%_t)
    else
        Sector():broadcastChatMessage(Entity(), ChatMessageType.Normal, "Towing & Reconstruction complete!"%_t)
    end

    Sector():broadcastChatMessage(Entity(), ChatMessageType.Normal, "We also offer very affordable repair services if you are interested!"%_t)

    invokeClientFunction(player, "refreshUI")
end
callable(RepairDock, "reconstruct")

function RepairDock.buyKit(shipName)

    if not CheckFactionInteraction(callingPlayer, RepairDock.interactionThreshold) then return end

    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources, AlliancePrivilege.AddItems)
    if not buyer then return end

    if not shipName and ship.isDrone then return end

    shipName = shipName or ship.name

    if RepairDock.isShipyardRepairDock() then
        player:sendChatMessage(Entity(), ChatMessageType.Error, "Shipyards don't offer these kinds of services."%_t)
        return
    end

    local kits = countReconstructionKits(buyer, shipName, buyer.index)
    if kits > 0 then
        if buyer.isAlliance then
            player:sendChatMessage(Entity(), ChatMessageType.Error, "Your alliance already owns a Reconstruction Kit for that ship."%_t)
        else
            player:sendChatMessage(Entity(), ChatMessageType.Error, "You already own a Reconstruction Kit for that ship."%_t)
        end
        return
    end

    local kit = UsableInventoryItem("data/scripts/items/reconstructionkit.lua", Rarity(RarityType.Exotic), buyer.index, shipName)
    local inventory = buyer:getInventory()
    if not inventory:hasSlot(kit) then
        player:sendChatMessage(Entity(), ChatMessageType.Error, "Your inventory is full (%1%/%2%)."%_T, inventory.occupiedSlots, inventory.maxSlots)
        return
    end

    local price = RepairDock.getReconstructionKitPrice(buyer)
    local canPay, msg, args = buyer:canPay(price)

    if not canPay then
        player:sendChatMessage(Entity(), ChatMessageType.Error, msg, unpack(args))
        return
    end

    buyer:pay("Paid %1% credits for a Reconstruction Kit."%_T, price)
    inventory:addOrDrop(kit)

    player:sendCallback("onShowEncyclopediaArticle", "ReconstructionKit")

    invokeClientFunction(player, "refreshUI")
end
callable(RepairDock, "buyKit")

function RepairDock.setAsReconstructionSite()
    local player = Player(callingPlayer)

    if RepairDock.isShipyardRepairDock() then
        player:sendChatMessage(Entity(), ChatMessageType.Error, "Shipyards don't offer these kinds of services."%_t)
        return
    end

    if RepairDock.isReconstructionSite(player) then
        player:sendChatMessage(Entity(), ChatMessageType.Error, "This sector is already your Reconstruction Site."%_t)
        return
    end

    local x, y = Sector():getCoordinates()
    if Galaxy():sectorInRift(x, y) then
        player:sendChatMessage(Entity(), ChatMessageType.Error, "This is impossible."%_t)
        return
    end

    if not CheckFactionInteraction(callingPlayer, 60000) then
        player:sendChatMessage(Entity(), ChatMessageType.Normal, "We only offer these kinds of services to people we have relations of at least 60,000 with."%_t)
        player:sendChatMessage("", ChatMessageType.Error, "Your relations with that faction aren't good enough."%_t)
        return
    end

    local requiredMoney = RepairDock.getReconstructionSiteChangePrice()

    local ok, msg, args = player:canPay(requiredMoney)
    if not ok then
        player:sendChatMessage(Entity(), ChatMessageType.Error, msg, unpack(args))
        return
    end

    player:pay("Paid %1% Credits to set a new Reconstruction Site."%_T, requiredMoney)

    player:setReconstructionSiteCoordinates(x, y)

    player:sendCallback("onReconstructionSiteChanged", player.index)

    invokeClientFunction(player, "refreshUI")
end
callable(RepairDock, "setAsReconstructionSite")

function RepairDock.onPlayerEntered()
    RepairDock.setAsRespawnSite()
end

function RepairDock.setAsRespawnSite()
    if RepairDock.isShipyardRepairDock() then return end

    local players = {Sector():getPlayers()}
    local x, y = Sector():getCoordinates()

    if Galaxy():sectorInRift(x, y) then return end

    local faction = Faction()

    for _, player in pairs(players) do
        if faction:getRelationStatus(player.index) ~= RelationStatus.War then
            player:setRespawnSiteCoordinates(x, y)
        end
    end
end

function RepairDock.getRepairResourcesCost(player, orderingFaction, ship, perfectPlan, damagedPlan, durabilityPercentage)
    -- towing is free at reconstruction site
    if RepairDock.isReconstructionSite(player) then
        return {0, 0, 0, 0, 0, 0, 0}
    end

    -- value of blockplan template
    local templateValue = {perfectPlan:getUndamagedResourceValue()}
    -- value of player's craft blockplan
    local craftValue = {damagedPlan:getUndamagedResourceValue()}
    local diff = {}

    -- calculate difference
    for i = 1, NumMaterials() do
        local value = 0
        value = templateValue[i] - craftValue[i]
        value = value + templateValue[i] * (1.0 - durabilityPercentage)
        value = value / 2
        value = value * RepairDock.getRepairFactor()

        table.insert(diff, i, value)
    end

    return diff
end

function RepairDock.getRepairMoneyCostAndTax(player, orderingFaction, ship, perfectPlan, damagedPlan, durabilityPercentage)
    -- towing is free at reconstruction site
    if RepairDock.isReconstructionSite(player) then
        return 0, 0
    end

    local malus, reason = ship:getMalusFactor()
    local value = perfectPlan:getUndamagedMoneyValue() - damagedPlan:getUndamagedMoneyValue();

    value = value + perfectPlan:getMoneyValue() * (1.0 - durabilityPercentage)
    value = value / 2

    if not reason or reason ~= MalusReason.Boarding then
        fee = RepairDock.getRepairFactor() + GetFee(Faction(), orderingFaction)
    else
        fee = 1 + GetFee(Faction(), orderingFaction)
    end

    local price = value * fee
    local tax = round(price * RepairDock.tax)

    if Faction().index == orderingFaction.index then
        price = price - tax
        -- don't pay out for the second time
        tax = 0
    end

    return price, tax
end

function RepairDock.getRepairMoneyCostAndTaxCreditsOnly(player, orderingFaction, ship, perfectPlan, damagedPlan, durabilityPercentage)
    local price, tax = RepairDock.getRepairMoneyCostAndTax(player, orderingFaction, ship, perfectPlan, damagedPlan, durabilityPercentage)
    local resources = RepairDock.getRepairResourcesCost(player, orderingFaction, ship, perfectPlan, damagedPlan, durabilityPercentage)
    local materialsPrice = 0

    -- price of materials is handled the same way as if repair dock was a resource depot and you were buying the materials directly from it
    local percentage = getMaterialBuyingPriceFactor(Faction(), orderingFaction.index)

    for i = 1, NumMaterials() do
        materialsPrice = materialsPrice + (10 * Material(i - 1).costFactor * resources[i])
    end

    price = price + (materialsPrice * percentage * 1.1) -- but materials are a bit more expensive when bought at repair dock (10% more)
    tax = round(price * RepairDock.tax)

    return price, tax
end

function RepairDock.getUpdateInterval()
    return 30
end

function RepairDock.updateServer(timeStep)
    if RepairDock.isShipyardRepairDock() then return end
end

function RepairDock.isReconstructionSite(player)
    player = player or Player()
    local x, y = Sector():getCoordinates()
    local rx, ry = player:getReconstructionSiteCoordinates()

    return x == rx and y == ry
end

function RepairDock.getTowingBasePrice(faction)
    local price = 25000
    price = math.min(price, faction.money / 4) -- price is either 25% of the player's money or 25000 credits, whichever is lower
    price = math.floor(price / 1000) * 1000 -- round down to 1000's
    price = math.max(price, 1000) -- it's at least 1000 credits
    return price
end

function RepairDock.getTowingPrice(player, buyer, name)
    local type = buyer:getShipType(name)
    if type ~= EntityType.Ship then return end

    -- towing is free at reconstruction site
    if RepairDock.isReconstructionSite(player) then
        return 0
    end

    local price = RepairDock.getTowingBasePrice(player, buyer)
    local x, y = Sector():getCoordinates()
    local sx, sy = buyer:getShipPosition(name)

    local maxDistance = 50
    if distance(vec2(x, y), vec2(sx, sy)) > maxDistance then
        return price, "Too far away! Only available for Reconstruction Site subscribers."%_t
    end

    return price
end

function RepairDock.getReconstructionKitPrice(faction)
    local towingPrice = RepairDock.getTowingBasePrice(faction)

    -- price is either half of the towing price or 10000 credits, whichever is lower
    local price = math.min(10000, towingPrice)
    price = math.floor(price / 1000) * 1000 -- round down to 1000's
    price = math.max(price, 1000) -- it's at least 1000 credits

    return price
end

function RepairDock.getReconstructionSiteChangePrice()
    local x, y = Sector():getCoordinates()

    local d = length(vec2(x, y))

    local factor = 1.0 + (1.0 - math.min(1, d / 450)) * 50

    local price = factor * 50000

    -- round to 1000's
    price = round(price / 1000) * 1000

    return price
end

function RepairDock.getRepairFactor()
    -- Repairing at a repair dock only costs 50% compared to building mode
    return 0.5
end

function RepairDock.isShipyardRepairDock()
    return Entity():hasScript("shipyard.lua")
end

function RepairDock.reconstructionPossible(player, buyer, shipName)

    if player and buyer and shipName then
        if RepairDock.isShipyardRepairDock() then
            return false, 0
        end

        if buyer:getShipType(shipName) ~= EntityType.Ship then
            return false, 0
        end

        local price, error = RepairDock.getTowingPrice(player, buyer, shipName)
        if error then
            return false, 0
        end

        if buyer.money >= price then
            return true, price
        end

        return false, price
    else
        if RepairDock.isShipyardRepairDock() then
            return false
        end

        return true
    end
end

-- functions required for internal unit tests, can be ignored
function RepairDock.getRepairMoneyCostAndTaxTest()
    local player = Player(callingPlayer)
    local ship = player.craft
    local buyer = Faction(ship.factionIndex)

    if buyer.isPlayer then
        buyer = Player(buyer.index)
    elseif buyer.isAlliance then
        buyer = Alliance(buyer.index)
    end

    local perfectPlan = buyer:getShipPlan(ship.name)
    local damagedPlan = ship:getFullPlanCopy()

    return RepairDock.getRepairMoneyCostAndTax(player, buyer, ship, perfectPlan, damagedPlan, ship.durability / ship.maxDurability)
end

function RepairDock.getRepairResourcesCostTest()
    local player = Player(callingPlayer)
    local ship = player.craft
    local buyer = Faction(ship.factionIndex)

    if buyer.isPlayer then
        buyer = Player(buyer.index)
    elseif buyer.isAlliance then
        buyer = Alliance(buyer.index)
    end

    local perfectPlan = buyer:getShipPlan(ship.name)
    local damagedPlan = ship:getFullPlanCopy()

    local resources = RepairDock.getRepairResourcesCost(player, buyer, ship, perfectPlan, damagedPlan, ship.durability / ship.maxDurability)

    for i = 1, NumMaterials() do
        resources[i] = resources[i] or 0
    end

    return unpack(resources)
end

function RepairDock.getRepairMoneyCostAndTaxCreditsOnlyTest()
    local player = Player(callingPlayer)
    local ship = player.craft
    local buyer = Faction(ship.factionIndex)

    if buyer.isPlayer then
        buyer = Player(buyer.index)
    elseif buyer.isAlliance then
        buyer = Alliance(buyer.index)
    end

    local perfectPlan = buyer:getShipPlan(ship.name)
    local damagedPlan = ship:getFullPlanCopy()

    return RepairDock.getRepairMoneyCostAndTaxCreditsOnly(player, buyer, ship, perfectPlan, damagedPlan, ship.durability / ship.maxDurability)
end
