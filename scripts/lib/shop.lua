package.path = package.path .. ";data/scripts/lib/?.lua"

include ("galaxy")
include ("randomext")
include ("utility")
include ("stringutility")
include ("player")
include ("faction")
include ("merchantutility")
include ("callable")
include ("relations")
local SellableInventoryItem = include ("sellableinventoryitem")
local Dialog = include("dialogutility")

local PublicNamespace = {}

local Shop = {}
Shop.__index = Shop

-- time after which the special offer changes (in minutes)
Shop.specialOfferDuration = 20 * 60 + 1 -- small bias so it looks better when resetting

local function new()
    local instance = {}

    instance.ItemWrapper = SellableInventoryItem
    instance.tax = 0.2
    instance.priceRatio = 1.0
    instance.everythingCanBeBought = false
    instance.staticSeed = false

    -- UI
    instance.soldItemLines = {}
    instance.specialOfferUI = nil
    instance.specialOffer = {}

    instance.boughtItemLines = {}
    instance.buybackItemLines = {}

    instance.itemsPerPage = 13
    instance.pageLabel = nil

    instance.soldItems = {}
    instance.boughtItems = {}
    instance.buybackItems = {}

    instance.boughtItemsPage = 0
    instance.soldItemsPage = 0

    instance.guiInitialized = false

    instance.buyTab = nil
    instance.sellTab = nil
    instance.buyBackTab = nil

    return setmetatable(instance, Shop)
end

-- this function gets called on creation of the entity the script is attached to, on client and server
function Shop:initialize(title)

    local station = Entity()
    if onServer() then
        if title and station.title == "" then
            station.title = title
        end

        self:restock()
    else
        InteractionText().text = Dialog.generateStationInteractionText(station, random())
        self:requestItems()
    end
end

-- this function gets called on creation of the entity the script is attached to, on client only
-- AFTER initialize above
-- create all required UI elements for the client side
-- possible config options: {showSpecialOffer = true, showAmountBoxes = true, useSeparateSellTab = true}
function Shop:initUI(interactionCaption, windowCaption, tabCaption, tabIcon, config)
    config = config or {}
    -- set showSpecialOffer true by default
    if config.showSpecialOffer == nil then config.showSpecialOffer = true else config.showSpecialOffer = false end

    local menu = ScriptUI()

    if not self.shared.window then
        local size = vec2(900, 690)
        local res = getResolution()

        self.window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5));

        self.window.caption = windowCaption
        self.window.showCloseButton = 1
        self.window.moveable = 1

        -- create a tabbed window inside the main window
        self.tabbedWindow = self.window:createTabbedWindow(Rect(vec2(10, 10), size - 10))

        self.shared.window = self.window
        self.shared.tabbedWindow = self.tabbedWindow
    end

    self.window       = self.window       or self.shared.window
    self.tabbedWindow = self.tabbedWindow or self.shared.tabbedWindow

    if config.useSeparateSellTab then
        self.sellTab = self.tabbedWindow:createTab("Sell"%_t, "data/textures/icons/sell.png", "Sell Items"%_t)
        self:buildSellGui(self.sellTab, config)

        self.manageSellTab = true
    else
        if not self.shared.sellTab then
            -- create sell tab
            self.sellTab = self.tabbedWindow:createTab("Sell"%_t, "data/textures/icons/sell.png", "Sell Items"%_t)
            self:buildSellGui(self.sellTab, config)
            self.shared.sellTab = self.sellTab

            self.manageSellTab = true
        end
    end

    if not self.shared.buyBackTab then
        -- create buyback tab
        self.buyBackTab = self.tabbedWindow:createTab("Buyback"%_t, "data/textures/icons/buyback.png", "Buy Back Sold Items"%_t)
        self:buildBuyBackGui(self.buyBackTab)
        self.shared.buyBackTab = self.buyBackTab

        self.manageBuybackTab = true
    end

    -- registers the window for this script, enabling the default window interaction calls like onShowWindow(), renderUI(), etc.
    -- if the same window is registered more than once, an interaction option will only be shown for the first registration
    menu:registerWindow(self.shared.window, interactionCaption, 10);

    self.sellTab      = self.sellTab      or self.shared.sellTab
    self.buyBackTab   = self.buyBackTab   or self.shared.buyBackTab

    -- create buy tab
    self.buyTab = self.tabbedWindow:createTab("Buy"%_t, tabIcon, tabCaption)

    self:buildBuyGui(self.buyTab, config)

    self.tabbedWindow:moveTabToTheRight(self.sellTab)
    self.tabbedWindow:moveTabToTheRight(self.buyBackTab)

    self.guiInitialized = true

    self:requestItems()
end

function Shop:buildBuyGui(tab, config) -- client
    self:buildGui(tab, 0, config)
end

function Shop:buildSellGui(tab, config) -- client
    self:buildGui(tab, 1, config)
end

function Shop:buildBuyBackGui(tab) -- client
    self:buildGui(tab, 2)
end

function Shop:buildGui(window, guiType, config) -- client
    config = config or {}

    local buttonCaption = ""
    local buttonCallback = ""

    local size = window.size
    local pos = window.lower

    local pictureX = 20
    local nameX = 60
    local favX = 455
    local materialX = 480
    local techX = 530
    local stockX = 590
    local priceX = 620
    local buttonX = 720
    local amountBoxX = buttonX

    if guiType == 0 then
        -- buying from the NPC
        buttonCaption = "Buy"%_t
        buttonCallback = "onBuyButtonPressed"

        self.playerCurrencyTypeLabel = window:createLabel(Rect(priceX - 200, size.y - 40, priceX - 10, size.y - 20), "", 14)
        self.playerCurrencyTypeLabel:setRightAligned()

        self.playerCurrencyAmountLabel = window:createLabel(Rect(buttonX - 100, size.y - 40, buttonX - 20, size.y - 20), "", 14)
        self.playerCurrencyAmountLabel:setRightAligned()

        local rect = Rect(buttonX - 5, size.y - 42, buttonX - 20, size.y - 20)
        rect.upper = rect.lower + vec2(24)
        self.playerCurrencyIcon = window:createPicture(rect, "")
        self.playerCurrencyIcon.isIcon = true

    elseif guiType == 1 then
        -- selling to the NPC
        buttonCaption = "Sell"%_t
        buttonCallback = "onSellButtonPressed"

        window:createButton(Rect(0, 50 + 35 * 15, 70, 80 + 35 * 15), "<", "onLeftButtonPressed")
        window:createButton(Rect(size.x - 70, 50 + 35 * 15, 60 + size.x - 60, 80 + 35 * 15), ">", "onRightButtonPressed")

        self.pageLabel = window:createLabel(vec2(10, 50 + 35 * 15), "", 18)
        self.pageLabel.lower = vec2(pos.x + 10, pos.y + 50 + 35 * 15)
        self.pageLabel.upper = vec2(pos.x + size.x - 70, pos.y + 75)
        self.pageLabel.centered = 1

        self.reverseSellOrderButton = window:createButton(Rect(pictureX, -2, pictureX + 30, 30), "", "onReverseOrderPressed")
        self.reverseSellOrderButton.hasFrame = false
        self.reverseSellOrderButton.icon = "data/textures/icons/up-down.png"
        self.reverseSellOrder = false

        self.showFavoritesButton = window:createButton(Rect(favX, 3, favX + 18, 3+18), "", "onShowFavoritesPressed")
        self.showFavoritesButton.hasFrame = false
        self.showFavoritesButton.icon = "data/textures/icons/round-star.png"
        self.showFavoritesButton.tooltip = "Show Favorited Items"%_t
        self.showFavoritesButton.overlayIcon = "data/textures/icons/cross-mark.png"
        self.showFavoritesButton.overlayIcon = ""
        self.showFavoritesButton.overlayIconColor = ColorRGB(1, 0.3, 0.3)
        self.showFavoritesButton.overlayIconPadding = 0
        self.showFavoritesButton.overlayIconSizeFactor = 1
        self.showFavorites = true

        local x = favX - 30
        self.showTurretsButton = window:createButton(Rect(x, 0, x + 21, 21), "", "onShowTurretsPressed")
        self.showTurretsButton.hasFrame = false
        self.showTurretsButton.icon = "data/textures/icons/turret.png"
        self.showTurretsButton.tooltip = "Show Turrets"%_t
        self.showTurretsButton.overlayIcon = "data/textures/icons/cross-mark.png"
        self.showTurretsButton.overlayIcon = ""
        self.showTurretsButton.overlayIconColor = ColorRGB(1, 0.3, 0.3)
        self.showTurretsButton.overlayIconPadding = 0
        self.showTurretsButton.overlayIconSizeFactor = 1
        self.showTurrets = true

        local x = favX - 60
        self.showBlueprintsButton = window:createButton(Rect(x, 0, x + 21, 21), "", "onShowBlueprintsPressed")
        self.showBlueprintsButton.hasFrame = false
        self.showBlueprintsButton.icon = "data/textures/icons/turret-blueprint.png"
        self.showBlueprintsButton.tooltip = "Show Blueprints"%_t
        self.showBlueprintsButton.iconColor = ColorRGB(0.35, 0.7, 1.0)
        self.showBlueprintsButton.overlayIcon = "data/textures/icons/cross-mark.png"
        self.showBlueprintsButton.overlayIcon = ""
        self.showBlueprintsButton.overlayIconColor = ColorRGB(1, 0.3, 0.3)
        self.showBlueprintsButton.overlayIconPadding = 0
        self.showBlueprintsButton.overlayIconSizeFactor = 1
        self.showBlueprints = true

        local x = favX - 90
        self.showUpgradesButton = window:createButton(Rect(x, 0, x + 21, 21), "", "onShowUpgradesPressed")
        self.showUpgradesButton.hasFrame = false
        self.showUpgradesButton.icon = "data/textures/icons/circuitry.png"
        self.showUpgradesButton.tooltip = "Show Subsystems"%_t
        self.showUpgradesButton.overlayIcon = "data/textures/icons/cross-mark.png"
        self.showUpgradesButton.overlayIcon = ""
        self.showUpgradesButton.overlayIconColor = ColorRGB(1, 0.3, 0.3)
        self.showUpgradesButton.overlayIconPadding = 0
        self.showUpgradesButton.overlayIconSizeFactor = 1
        self.showUpgrades = true

        local x = favX - 120
        self.showDefaultItemsButton = window:createButton(Rect(x, 0, x + 21, 21), "", "onShowDefaultItemsPressed")
        self.showDefaultItemsButton.hasFrame = false
        self.showDefaultItemsButton.icon = "data/textures/icons/satellite.png"
        self.showDefaultItemsButton.tooltip = "Show Items"%_t
        self.showDefaultItemsButton.overlayIcon = "data/textures/icons/cross-mark.png"
        self.showDefaultItemsButton.overlayIcon = ""
        self.showDefaultItemsButton.overlayIconColor = ColorRGB(1, 0.3, 0.3)
        self.showDefaultItemsButton.overlayIconPadding = 0
        self.showDefaultItemsButton.overlayIconSizeFactor = 1
        self.showDefaultItems = true

        if config.hideFilterButtons then
            self.reverseSellOrderButton.active = false
            self.reverseSellOrderButton:hide()

            self.showFavoritesButton.active = false
            self.showFavoritesButton:hide()
            self.showTurretsButton.active = false
            self.showTurretsButton:hide()
            self.showBlueprintsButton.active = false
            self.showBlueprintsButton:hide()
            self.showUpgradesButton.active = false
            self.showUpgradesButton:hide()
            self.showDefaultItemsButton.active = false
            self.showDefaultItemsButton:hide()
        end

    else
        buttonCaption = "Buy"%_t
        buttonCallback = "onBuybackButtonPressed"
    end

    if config.showAmountBoxes then
        materialX = materialX - 70
        techX = techX - 70
        stockX = stockX - 70
        priceX = priceX - 70
        amountBoxX = buttonX - 70
    end

    if config.hideMaterialLabel then
        techX = materialX
    end

    -- header
    local headerY = 0
    if guiType == 0 and config.showSpecialOffer then
        local specialOfferY = 60

        local special = {}
        special.label = window:createLabel(vec2(nameX, 30), "SPECIAL OFFER (30% OFF)"%_t, 18)
        special.label.color = ColorRGB(1.0, 1.0, 0.1)

        special.timeLeftLabel = window:createLabel(vec2(materialX - 60, 30), "??"%_t, 15)
        special.timeLeftLabel.color = ColorRGB(0.5, 0.5, 0.5)
        special.timeLabel = window:createLabel(vec2(priceX + 30, 30), "", 15)
        special.timeLabel.color = ColorRGB(0.5, 0.5, 0.5)

        special.icon = window:createPicture(Rect(pictureX, specialOfferY - 5, pictureX + 30, specialOfferY + 24), "")
        special.nameLabel = window:createLabel(vec2(nameX, specialOfferY), "", 15)
        special.materialLabel = window:createLabel(vec2(materialX, specialOfferY), "", 15)

        special.priceReductionLabel = window:createLabel(Rect(stockX, specialOfferY + 18, priceX + 85, specialOfferY + 20), "", 10)
        special.priceReductionLabel.color = ColorRGB(1, 1, 0)
        special.priceReductionLabel.caption = "${percentage} OFF!"%_t % {percentage = "30%"}
        special.priceReductionLabel:setTopRightAligned()

        special.stockLabel = window:createLabel(Rect(stockX, specialOfferY, priceX - 10, specialOfferY + 30), "", 15)
        special.stockLabel:setTopRightAligned()

        special.techLabel = window:createLabel(Rect(techX, specialOfferY, techX + 35, specialOfferY + 30), "", 15)
        special.techLabel:setTopRightAligned()

        special.priceLabel = window:createLabel(Rect(priceX, specialOfferY, amountBoxX - 20, specialOfferY + 30), "", 15)
        special.priceLabel:setTopRightAligned()

        special.button = window:createButton(Rect(buttonX, specialOfferY, 160 + buttonX, 30 + specialOfferY), "BUY NOW!"%_t, "onBuyButtonPressed")

        special.nameLabel.width = materialX - nameX
        special.nameLabel.shortenText = true
        special.icon.isIcon = 1
        special.button.maxTextSize = 15

        special.frame = window:createFrame(Rect(0, 25, buttonX - 10, 32 + specialOfferY))
        special.topFrame = window:createFrame(Rect(0, 23, buttonX - 10, 25))
        special.bottomFrame = window:createFrame(Rect(0, 32 + specialOfferY, buttonX - 10, 32 + specialOfferY + 2))
        special.leftFrame = window:createFrame(Rect(0, 25, 2, 32 + specialOfferY))
        special.rightFrame = window:createFrame(Rect(buttonX - 12, 25, buttonX - 10, 32 + specialOfferY))
        special.topFrame.backgroundColor = ColorARGB(0.4, 1.0, 1.0, 1.0)
        special.bottomFrame.backgroundColor = ColorARGB(0.4, 1.0, 1.0, 1.0)
        special.leftFrame.backgroundColor = ColorARGB(0.4, 1.0, 1.0, 1.0)
        special.rightFrame.backgroundColor = ColorARGB(0.4, 1.0, 1.0, 1.0)

        special.toSoldOut = function(self)
            special.icon:hide()
            special.nameLabel:hide()
            special.materialLabel:hide()
            special.priceLabel:hide()
            special.priceReductionLabel:hide()
            special.stockLabel:hide()
            special.button:hide()
            special.timeLeftLabel.caption = ""
            special.label.caption = "SOLD OUT!"%_t
        end

        special.show = function(self)
            special.icon:show()
            special.nameLabel:show()
            special.materialLabel:show()
            special.priceLabel:show()
            special.priceReductionLabel:show()
            special.stockLabel:show()
            special.button:show()
        end

        self.specialOfferUI = special

        headerY = 70
    end

    window:createLabel(vec2(nameX, 0), "NAME"%_t, 15)
    local materialLabel = window:createLabel(vec2(materialX, 0), "MAT"%_t, 15)
    if config.hideMaterialLabel then materialLabel:hide() end

    local techLabel = window:createLabel(Rect(techX, 0, stockX - 10, 30), "TECH"%_t, 15)
    techLabel:setTopAligned()
    local amountLabel = window:createLabel(Rect(stockX, 0, priceX - 10, 30), "#"%_t, 15)
    amountLabel:setTopRightAligned()
    self.currencyLabel = window:createLabel(Rect(priceX, 0, amountBoxX - 20, 30), "¢", 15)
    self.currencyLabel:setTopRightAligned()

    if guiType == 0 then
        self.buyHeadlineAmountLabel = amountLabel
    elseif guiType == 1 then
        self.sellHeadlineAmountLabel = amountLabel
    elseif guiType == 2 then
        self.buybackHeadlineAmountLabel = amountLabel
    end

    local y = 35

    if guiType == 1 then
        self.sellTrashButton = window:createButton(Rect(buttonX, 0 + headerY, 160 + buttonX, 30 + headerY), "Sell Trash"%_t, "onSellTrashButtonPressed")
        self.sellTrashButton.maxTextSize = 15
    end

    for i = 1, self.itemsPerPage do
        local yText = y + 6 + headerY

        local line = {}
        line.frame = window:createFrame(Rect(0, y + headerY, amountBoxX - 10, 30 + y + headerY))

        line.nameLabel = window:createLabel(vec2(nameX, yText), "", 14)

        line.priceLabel = window:createLabel(vec2(priceX, yText), "", 14)
        line.priceReductionLabel = window:createLabel(vec2(priceX + 40, yText + 18), "", 10)
        line.priceReductionLabel.color = ColorRGB(1, 1, 0)
        line.priceReductionLabel.caption = "${percentage} OFF!"%_t % {percentage = "30%"}

        line.favoriteIcon = window:createPicture(Rect(favX, yText, favX + 18, yText + 18), "")
        line.materialLabel = window:createLabel(vec2(materialX, yText), "", 14)
        line.techLabel = window:createLabel(Rect(techX, yText, stockX - 10, yText + 30), "", 14)
        line.techLabel:setTopAligned()
        line.stockLabel = window:createLabel(Rect(stockX, yText, priceX - 10, yText + 30), "", 14)
        line.stockLabel:setTopRightAligned()
        line.priceLabel = window:createLabel(Rect(priceX, yText, amountBoxX - 20, yText + 30), "", 14)
        line.priceLabel:setTopRightAligned()

        line.button = window:createButton(Rect(buttonX, y + headerY, 160 + buttonX, 30 + y + headerY), buttonCaption, buttonCallback)
        line.icon = window:createPicture(Rect(pictureX, yText - 5, 29 + pictureX, 29 + yText - 5), "")
        line.background = window:createFrame(Rect(pictureX - 1, yText - 6, 30 + pictureX, 29 + yText - 5))
        line.background.backgroundColor = ColorRGB(0.05, 0.3, 0.5)

        if config.showAmountBoxes then
            line.amountBox = window:createTextBox(Rect(amountBoxX, y + headerY, 60 + amountBoxX, 30 + y + headerY), "onAmountEntered")
            line.amountBox.allowedCharacters = "0123456789"
            line.amountBox.text = "1"
        end

        line.nameLabel.width = favX - nameX
        line.nameLabel.shortenText = true

        line.button.maxTextSize = 15
        line.icon.isIcon = true
        line.favoriteIcon.isIcon = true

        if guiType == 0 then
            table.insert(self.soldItemLines, line)

        elseif guiType == 1 then
            table.insert(self.boughtItemLines, line)

        elseif guiType == 2 then
            table.insert(self.buybackItemLines, line)
        end

        line.hide = function(self)
            self.frame:hide()
            self.nameLabel:hide()
            self.priceLabel:hide()
            self.priceReductionLabel:hide()
            self.materialLabel:hide()
            self.techLabel:hide()
            self.stockLabel:hide()
            self.button:hide()
            self.icon:hide()
            self.background:hide()
            self.favoriteIcon:hide()

            if self.amountBox then self.amountBox:hide() end
        end

        line.show = function(self)
            self.frame:show()
            self.nameLabel:show()
            self.priceLabel:show()
            self.materialLabel:show()
            self.techLabel:show()
            self.stockLabel:show()
            self.button:show()
            self.icon:show()

            if self.amountBox then self.amountBox:show() end
        end

        y = y + 35
    end

    -- paginación para la pestaña de compra (donde la ESTACIÓN VENDE)
    if guiType == 0 then
        local paginationY = y + headerY
        window:createButton(Rect(0, paginationY, 70, paginationY + 30), "<", "onBuyTabLeftPressed")
        window:createButton(Rect(size.x - 70, paginationY, size.x - 10, paginationY + 30), ">", "onBuyTabRightPressed")
        self.soldPageLabel = window:createLabel(vec2(10, paginationY), "", 18)
        self.soldPageLabel.lower = vec2(pos.x + 10, pos.y + paginationY)
        self.soldPageLabel.upper = vec2(pos.x + size.x - 70, pos.y + paginationY + 25)
        self.soldPageLabel.centered = 1
    end

end

-- this function gets called every time the window is shown on the client, ie. when a player presses F and if interactionPossible() returned 1
function Shop:onShowWindow()

    self.boughtItemsPage = 0
    self.soldItemsPage = 0

    self:updatePlayerItems()
    self:updateSellGui()
    self:updateBuyGui()
    self:updateBuybackGui()

    self.tabbedWindow:selectTab(self.buyTab)

    self:requestItems()
end

-- send a request to the server for the sold items
function Shop:requestItems() -- client
    self.soldItems = {}
    self.boughtItems = {}
    self.specialOffer.item = nil

    invokeServerFunction("sendItems")
end

-- send sold items to client
function Shop:sendItems() -- server
    self.specialOffer.remainingTime = self:getRemainingSpecialOfferTime()
    invokeClientFunction(Player(callingPlayer), "receiveSoldItems", self.soldItems, self.buybackItems, self.specialOffer)
end

function Shop:broadcastItems()
    self.specialOffer.remainingTime = self:getRemainingSpecialOfferTime()
    broadcastInvokeClientFunction("receiveSoldItems", self.soldItems, self.buybackItems, self.specialOffer)
end

function Shop:receiveSoldItems(sold, buyback, specialOffer) -- client

    self.soldItems = sold
    for i, v in pairs(self.soldItems) do
        local item = self.ItemWrapper(v.item)
        item.amount = v.amount

        self.soldItems[i] = item
    end    

    self.specialOffer.item = nil
    self.specialOffer.remainingTime = specialOffer.remainingTime

    if specialOffer and specialOffer.item then
        local item = self.ItemWrapper(specialOffer.item.item)
        item.amount = specialOffer.item.amount

        self.specialOffer.item = item
    end

    self.buybackItems = buyback
    for i, v in pairs(self.buybackItems) do
        local item = SellableInventoryItem(v.item)
        item.amount = v.amount

        self.buybackItems[i] = item
    end

    self:updatePlayerItems()
    self:updateSellGui()
    self:updateBuyGui()
    self:updateBuybackGui()
end

-- override this function if you need the functionality
function Shop:onSpecialOfferSeedChanged()
end

function Shop:updatePlayerItems() -- client only
    self.boughtItems = {}

    local player = Player()
    local ship = player.craft
    local items = {}
    local owner

    if ship and ship.factionIndex == player.allianceIndex then
        local alliance = player.alliance

        items = alliance:getInventory():getItems()
        owner = alliance
    else
        items = player:getInventory():getItems()
        owner = player
    end

    for index, slotItem in pairs(items) do
        local item = SellableInventoryItem(slotItem.item, index, owner)
        if item.sellable then
            table.insert(self.boughtItems, item)
        end
    end
end

function Shop:updateBoughtItem(index, stock) -- client

    if index and stock then
        for i, item in pairs(self.boughtItems) do
            if item.index == index then
                if stock > 0 then
                    item.amount = stock
                else
                    self.boughtItems[i] = nil
                    self:rebuildTables()
                end

                break
            end
        end
    else
        self:updatePlayerItems()
    end

    self:updateBuyGui()
end

-- update the buy tab (the tab where the STATION SELLS)
function Shop:updateSellGui() -- client

    if not self.guiInitialized then return end

    for _, line in pairs(self.soldItemLines) do
        line:hide()
    end

    if self.specialOfferUI then
        self.specialOfferUI:toSoldOut()
    end

    local faction = Faction()
    local buyer = Player()
    local playerCraft = buyer.craft

    if playerCraft and playerCraft.factionIndex == buyer.allianceIndex then
        buyer = buyer.alliance
    end

    if #self.soldItems == 0 then
        local topLine = self.soldItemLines[1]
        topLine.nameLabel:show()
        topLine.nameLabel.color = ColorRGB(1.0, 1.0, 1.0)
        topLine.nameLabel.bold = false
        topLine.nameLabel.caption = "We are completely sold out."%_t
    end

    -- paginación
    local numItems = #self.soldItems
    while self.soldItemsPage * self.itemsPerPage >= numItems and self.soldItemsPage > 0 do
        self.soldItemsPage = self.soldItemsPage - 1
    end
    local itemStart = self.soldItemsPage * self.itemsPerPage + 1
    local itemEnd   = math.min(numItems, itemStart + self.itemsPerPage - 1)

    if self.soldPageLabel then
        if numItems == 0 then
            self.soldPageLabel.caption = ""
        else
            self.soldPageLabel.caption = itemStart .. " - " .. itemEnd .. " / " .. numItems
        end
    end

    local uiIndex = 1
    for index = itemStart, itemEnd do
        local item = self.soldItems[index]
        if item == nil then break end

        local line = self.soldItemLines[uiIndex]
        line.soldItemIndex = index   -- guardamos el índice real para onBuyButtonPressed
        line:show()

        line.nameLabel.caption = item:getName()%_t
        line.nameLabel.color = item.rarity.color
        line.nameLabel.bold = false

        if item.material then
            line.materialLabel.caption = item.material.name
            line.materialLabel.color = item.material.color
        else
            line.materialLabel:hide()
        end

        if item.icon then
            line.icon.picture = item.icon
            line.icon.color = item.rarity.color
        end

        if item.displayedPrice then
            line.priceLabel.caption = item.displayedPrice
        else
            local price = self:getSellPriceAndTax(item.price, faction, buyer)
            line.priceLabel.caption = createMonetaryString(price)
        end

        if self.priceRatio < 1 then
            line.priceReductionLabel:show()
            line.priceReductionLabel.caption = "${percentage} OFF!"%_t % {percentage = tostring(round((1 - self.priceRatio) * 100)) .. "%"}
        elseif self.priceRatio > 1 then
            line.priceReductionLabel:show()
            line.priceReductionLabel.caption = "+${percentage}"%_t % {percentage = tostring(round((self.priceRatio - 1) * 100)) .. "%"}
        else
            line.priceReductionLabel:hide()
        end

        line.stockLabel.caption = item.amount
        line.techLabel.caption = item.tech or ""

        local msg, args = self:canBeBought(item, playerCraft, buyer)
        if msg then
            line.button.active = false
            line.button.tooltip = string.format(msg%_t, unpack(args or {}))
        else
            line.button.active = true
            line.button.tooltip = nil
        end

        uiIndex = uiIndex + 1
    end

    -- update the special offer frame
    local item = self.specialOffer.item
    if item then

        local specialUI = self.specialOfferUI
        specialUI:show()

        local special = self.specialOffer
        specialUI.nameLabel.caption = item.name%_t
        specialUI.nameLabel.color = item.rarity.color
        specialUI.nameLabel.bold = false

        if item.material then
            specialUI.materialLabel.caption = item.material.name
            specialUI.materialLabel.color = item.material.color
        else
            specialUI.materialLabel:hide()
        end

        if item.icon then
            specialUI.icon.picture = item.icon
            specialUI.icon.color = item.rarity.color
        end

        if item.amount then
            specialUI.stockLabel.caption = item.amount
        end

        specialUI.techLabel.caption = item.tech or ""

        specialUI.timeLeftLabel.caption = "LIMITED TIME OFFER!"%_t
        specialUI.label.caption = "SPECIAL OFFER: -30% OFF"%_t

        -- for now, specialPrice is just 70% of the regular price
        -- if this gets changed, it must be changed in <Shop:sellToPlayer> also!
        local price = self:getSellPriceAndTax(item.price, faction, buyer)
        local specialPrice = price * 0.7
        specialUI.priceLabel.caption = createMonetaryString(specialPrice)
        specialUI.priceReductionLabel.caption = "${percentage} OFF!"%_t % {percentage = "30%"}

        local msg, args = self:canBeBought(item, playerCraft, buyer)
        if msg then
            specialUI.button.active = false
            specialUI.button.tooltip = string.format(msg%_t, unpack(args or {}))
        else
            specialUI.button.active = true
            specialUI.button.tooltip = nil
        end
    end

    if self.onSellGuiUpdated then self:onSellGuiUpdated() end
end

-- update the sell tab (the tab where the STATION BUYS)
function Shop:updateBuyGui() -- client

    if not self.guiInitialized then return end
    if not self.manageSellTab then return end

    local visible = {}
    for _, item in pairs(self.boughtItems) do

        if not self.showFavorites then
            if item.item.favorite then goto continue end
        end
        if not self.showTurrets then
            if item.item.itemType == InventoryItemType.Turret then
                goto continue
            end
        end
        if not self.showBlueprints then
            if item.item.itemType == InventoryItemType.TurretTemplate then
                goto continue
            end
        end
        if not self.showUpgrades then
            if item.item.itemType == InventoryItemType.SystemUpgrade then
                goto continue
            end
        end
        if not self.showDefaultItems then
            if item.item.itemType == InventoryItemType.UsableItem
                    or item.item.itemType == InventoryItemType.VanillaItem then
                goto continue
            end
        end

        table.insert(visible, item)

        ::continue::
    end

    if self.reverseSellOrder then
        table.sort(visible, function(a, b) return SortSellableInventoryItems(b, a) end)
    else
        table.sort(visible, SortSellableInventoryItems)
    end

    local numDifferentItems = #visible

    while self.boughtItemsPage * self.itemsPerPage >= numDifferentItems do
        self.boughtItemsPage = self.boughtItemsPage - 1
    end

    if self.boughtItemsPage < 0 then
        self.boughtItemsPage = 0
    end

    for _, line in pairs(self.boughtItemLines) do
        line:hide()
        line.item = nil
    end

    local itemStart = self.boughtItemsPage * self.itemsPerPage + 1
    local itemEnd = math.min(numDifferentItems, itemStart + 14)

    local uiIndex = 1

    local faction = Faction()
    local buyer = Player()
    local playerCraft = buyer.craft

    if playerCraft and playerCraft.factionIndex == buyer.allianceIndex then
        buyer = buyer.alliance
    end

    if #visible == 0 then
        local topLine = self.boughtItemLines[1]
        topLine.nameLabel:show()
        topLine.nameLabel.color = ColorRGB(1.0, 1.0, 1.0)
        topLine.nameLabel.bold = false
        topLine.nameLabel.caption = "You have nothing you can sell here."%_t
    end

    for index = itemStart, itemEnd do

        local item = visible[index]
        if item == nil then break end

        local line = self.boughtItemLines[uiIndex]
        line:show()

        line.nameLabel.caption = item:getName()%_t
        line.nameLabel.color = item.rarity.color
        line.nameLabel.bold = false

        local price = self:getBuyPrice(item.price, faction, buyer)
        line.priceLabel.caption = createMonetaryString(price)

        if item.material then
            line.materialLabel.caption = item.material.name
            line.materialLabel.color = item.material.color
        else
            line.materialLabel:hide()
        end

        if item.icon then
            line.icon.picture = item.icon
            line.icon.color = item.rarity.color
        end

        if item.item.itemType == InventoryItemType.TurretTemplate then
            line.background:show()
            line.icon.color = ColorRGB(1, 1, 1)
        else
            line.background:hide()
        end

        if item.item.favorite then
            line.favoriteIcon:show()
            line.favoriteIcon.picture = "data/textures/icons/round-star.png"
            line.favoriteIcon.color = ColorRGB(1, 1, 0)
        elseif item.item.trash then
            line.favoriteIcon:show()
            line.favoriteIcon.picture = "data/textures/icons/trash-can.png"
            line.favoriteIcon.color = ColorRGB(0.6, 0.6, 0.6)
        else
            line.favoriteIcon:hide()
        end

        line.stockLabel.caption = item.amount
        line.techLabel.caption = item.tech or ""
        line.item = item

        uiIndex = uiIndex + 1
    end

    if itemEnd < itemStart then
        itemEnd = 0
        itemStart = 0
    end

    self.pageLabel.caption = itemStart .. " - " .. itemEnd .. " / " .. numDifferentItems

    if self.onBuyGuiUpdated then self:onBuyGuiUpdated() end
end

-- update the sell tab (the tab where the STATION BUYS)
function Shop:updateBuybackGui() -- client

    if not self.guiInitialized then return end
    if not self.manageBuybackTab then return end

    for i, line in pairs(self.buybackItemLines) do line:hide() end

    local faction = Faction()
    local buyer = Player()
    local playerCraft = buyer.craft

    if playerCraft and playerCraft.factionIndex == buyer.allianceIndex then
        buyer = buyer.alliance
    end

    if #self.buybackItems == 0 then
        local topLine = self.buybackItemLines[1]
        topLine.nameLabel:show()
        topLine.nameLabel.color = ColorRGB(1.0, 1.0, 1.0)
        topLine.nameLabel.bold = false
        topLine.nameLabel.caption = "You haven't sold anything to this station."%_t
    end

    for index = 1, math.min(15, #self.buybackItems) do

        local item = self.buybackItems[index]
        local line = self.buybackItemLines[index]
        line:show()

        line.nameLabel.caption = item:getName()%_t
        line.nameLabel.color = item.rarity.color
        line.nameLabel.bold = false

        local price = self:getBuyPrice(item.price, faction, buyer)
        line.priceLabel.caption = createMonetaryString(price)

        if item.material then
            line.materialLabel.caption = item.material.name
            line.materialLabel.color = item.material.color
        else
            line.materialLabel:hide()
        end

        if item.icon then
            line.icon.picture = item.icon
            line.icon.color = item.rarity.color
        end

        if item.item.itemType == InventoryItemType.TurretTemplate then
            line.background:show()
            line.icon.color = ColorRGB(1, 1, 1)
        else
            line.background:hide()
        end

        line.stockLabel.caption = item.amount
        line.techLabel.caption = item.tech or ""
    end

    if self.onBuyBackGuiUpdated then self:onBuyBackGuiUpdated() end
end

function Shop:onLeftButtonPressed()
    self.boughtItemsPage = math.max(0, self.boughtItemsPage - 1)
    self:updateBuyGui()
end

function Shop:onRightButtonPressed()
    self.boughtItemsPage = self.boughtItemsPage + 1
    self:updateBuyGui()
end

function Shop:onBuyTabLeftPressed()
    self.soldItemsPage = math.max(0, self.soldItemsPage - 1)
    self:updateSellGui()
end

function Shop:onBuyTabRightPressed()
    self.soldItemsPage = self.soldItemsPage + 1
    self:updateSellGui()
end

function Shop:onAmountEntered(box)
end

function Shop:onBuyButtonPressed(button) -- client
    -- check if regular item (shop = 0) or special offer item (shop = 1) was bought
    local itemIndex = 0
    local specialOffer

    for i, line in pairs(self.soldItemLines) do
        if button.index == line.button.index then
            itemIndex = line.soldItemIndex or i  -- soldItemIndex = índice real al paginar
        end
    end

    if self.specialOfferUI then
        if button.index == self.specialOfferUI.button.index then
            itemIndex = 1
            specialOffer = true
        end
    end

    local amount = 1
    local line = self.soldItemLines[itemIndex]
    if line and line.amountBox then
        amount = tonumber(line.amountBox.text) or 0
    end

    invokeServerFunction("sellToPlayer", itemIndex, specialOffer, amount)
end

function Shop:onSellButtonPressed(button) -- client

    local itemIndex = nil
    for i, line in pairs(self.boughtItemLines) do
        if line.button.index == button.index then
            itemIndex = line.item.index
        end
    end

    if itemIndex then
        invokeServerFunction("buyFromPlayer", itemIndex)
    end
end

function Shop:onShowFavoritesPressed()
    self.showFavorites = not self.showFavorites
    if self.showFavorites then
        self.showFavoritesButton.overlayIcon = ""
    else
        self.showFavoritesButton.overlayIcon = "data/textures/icons/cross-mark.png"
    end

    self:updateBuyGui()
end

function Shop:onShowTurretsPressed()
    self.showTurrets = not self.showTurrets

    if self.showTurrets then
        self.showTurretsButton.overlayIcon = ""
    else
        self.showTurretsButton.overlayIcon = "data/textures/icons/cross-mark.png"
    end
    self:updateBuyGui()
end

function Shop:onShowBlueprintsPressed()
    self.showBlueprints = not self.showBlueprints

    if self.showBlueprints then
        self.showBlueprintsButton.overlayIcon = ""
    else
        self.showBlueprintsButton.overlayIcon = "data/textures/icons/cross-mark.png"
    end
    self:updateBuyGui()
end

function Shop:onShowDefaultItemsPressed()
    self.showDefaultItems = not self.showDefaultItems

    if self.showDefaultItems then
        self.showDefaultItemsButton.overlayIcon = ""
    else
        self.showDefaultItemsButton.overlayIcon = "data/textures/icons/cross-mark.png"
    end
    self:updateBuyGui()
end

function Shop:onShowUpgradesPressed()
    self.showUpgrades = not self.showUpgrades

    if self.showUpgrades then
        self.showUpgradesButton.overlayIcon = ""
    else
        self.showUpgradesButton.overlayIcon = "data/textures/icons/cross-mark.png"
    end
    self:updateBuyGui()
end

function Shop:onReverseOrderPressed()
    self.reverseSellOrder = not self.reverseSellOrder
    self:updateBuyGui()
end

function Shop:onSellTrashButtonPressed(button)
    invokeServerFunction("buyTrashFromPlayer")
end

function Shop:onBuybackButtonPressed(button) -- client
    local itemIndex = 0
    for i, line in pairs(self.buybackItemLines) do
        if button.index == line.button.index then
            itemIndex = i
        end
    end

    invokeServerFunction("sellBackToPlayer", itemIndex)
end

function Shop:restock()
    self.soldItems = {}
    self:addItems()
    self:onSpecialOfferSeedChanged()
    self:broadcastItems()

    self.previousSeed = self:generateSeed()
end

function Shop:add(item_in, amount)
    amount = amount or 1

    local item = self.ItemWrapper(item_in)

    item.name = item.name or ""
    item.price = item.price or 0
    item.amount = amount

    table.insert(self.soldItems, item)

    return item
end

function Shop:addFront(item_in, amount)
    local items = self.soldItems
    self.soldItems = {}

    local result = self:add(item_in, amount)

    for _, item in pairs(items) do
        table.insert(self.soldItems, item)
    end

    return result
end

function Shop:setSpecialOffer(item_in, amount)
    if item_in == nil then return end
    amount = amount or 1

    local item = self.ItemWrapper(item_in)

    item.name = item.name or ""
    item.price = item.price or 0
    item.amount = amount

    self.specialOffer.item = item

    return item
end

function Shop:setStaticSeed(value)
    self.staticSeed = value
end

function Shop:getRemainingSpecialOfferTime()
    return Shop.specialOfferDuration - (math.floor(Server().unpausedRuntime) % Shop.specialOfferDuration)
end

function Shop:updateClient(timeStep)
    if not self.guiInitialized then return end

    if self.specialOffer and self.specialOffer.remainingTime then
        self.specialOffer.remainingTime = math.max(0, self.specialOffer.remainingTime - timeStep)

        if self.specialOfferUI then
            self.specialOfferUI.timeLabel.caption = "${time}"%_t % {time = createDigitalTimeString(self.specialOffer.remainingTime)}
        end
    end
end

function Shop:getUpdateInterval()
    return 0.25
end

function Shop:updateServer()

    if self.previousSeed ~= self:generateSeed() then
        self:restock()
    end
end

function Shop:generateSeed()
    if self.staticSeed and self.previousSeed then
        return self.previousSeed
    else
        return Entity().index.string .. math.floor(Server().unpausedRuntime / Shop.specialOfferDuration) .. Server().sessionId.string
    end
end


function Shop:sellToPlayer(itemIndex, specialOffer, amount) -- server
    amount = amount or 1

    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources, AlliancePrivilege.AddItems)
    if not buyer then return end

    if self.relationThreshold then
        if not CheckFactionInteraction(callingPlayer, self.relationThreshold) then
            return
        end
    end

    local station = Entity()

    local item = self.soldItems[itemIndex]

    if specialOffer then
        item = self.specialOffer.item
    end

    if item == nil then
        player:sendChatMessage(station, 1, "Item to buy not found."%_t)
        return
    end

    -- limit the amount by what's available
    amount = math.min(item.amount, amount)
    if amount <= 0 then return end

    local msg = self:onSold(item, buyer, player)
    if msg then
        if msg == "" then msg = "Item can't be bought."%_T end

        player:sendChatMessage(station, 1, msg)
        return
    end

    local price = self:getSellPriceAndTax(item.price, Faction(), buyer) * amount
    if specialOffer then price = price * 0.7 end

    local canPay, msg, args = buyer:canPay(price)
    if not canPay then
        player:sendChatMessage(station, 1, msg, unpack(args))
        return
    end

    -- test the docking last so the player can know what he can buy from afar already
    local errors = {}
    errors[EntityType.Station] = "You must be docked to the station to buy items."%_T
    errors[EntityType.Ship] = "You must be closer to the ship to buy items."%_T
    if not CheckPlayerDocked(player, station, errors) then
        return
    end

    local msg, args = self:canBeBought(item, ship, buyer)
    if msg and msg ~= "" then
        player:sendChatMessage(station, 1, msg, unpack(args))
        return
    end

    local msg, args = item:boughtByPlayer(ship, amount)
    if msg and msg ~= "" then
        player:sendChatMessage(station, 1, msg, unpack(args))
        return
    end

    receiveTransactionTax(station, price * self.tax)
    if price > 0 then
        buyer:pay("Bought an item for %1% Credits."%_T, price)
    end

    -- remove item
    item.amount = item.amount - amount
    if item.amount == 0 then
        if specialOffer then
            self.specialOffer.item = nil
        else
            self.soldItems[itemIndex] = nil
        end

        self:rebuildTables()
    end

    local changeType = RelationChangeType.Commerce
    if item.getRelationChangeType then
        changeType = item:getRelationChangeType() or RelationChangeType.Commerce
    end

    changeRelations(buyer, Faction(), GetRelationChangeFromMoney(price), changeType, nil, nil, station)

    -- do a broadcast to all clients that the item is sold out/changed
    self:broadcastItems()
end

function Shop:buyFromPlayer(itemIndex) -- server

    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.AddResources, AlliancePrivilege.SpendItems)
    if not buyer then return end

    local station = Entity()

    -- test the docking last so the player can know what he can buy from afar already
    local errors = {}
    errors[EntityType.Station] = "You must be docked to the station to sell items."%_T
    errors[EntityType.Ship] = "You must be closer to the ship to sell items."%_T
    if not CheckPlayerDocked(player, station, errors) then
        return
    end

    local iitem = buyer:getInventory():find(itemIndex)
    if iitem == nil then
        player:sendChatMessage(station, 1, "Item to sell not found."%_t)
        return
    end

    if iitem.favorite then
        player:sendChatMessage(station, 1, "Item is favorited."%_t)
        return
    end

    local item = SellableInventoryItem(iitem, itemIndex, buyer)
    item.amount = 1

    if not item.sellable then return end

    local msg, args = item:soldByPlayer(ship, 1)
    if msg and msg ~= "" then
        player:sendChatMessage(station, 1, msg, unpack(args))
        return
    end

    -- no transaction tax here since it could be abused by 2 players working together
    -- receiveTransactionTax(station, item.price * 0.25 * self.tax)
    local price = self:getBuyPrice(item.price, Faction(), buyer)
    buyer:receive("Sold an item for %1% Credits."%_T, price)

    -- insert the item into buyback list
    for i = 14, 1, -1 do
        self.buybackItems[i + 1] = self.buybackItems[i]
    end
    self.buybackItems[1] = item

    broadcastInvokeClientFunction("updateBoughtItem", item.index, item.amount - 1)
    self:broadcastItems()
end

function Shop:buyTrashFromPlayer() -- server

    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.AddResources, AlliancePrivilege.SpendItems)
    if not buyer then return end

    local station = Entity()

    -- test the docking last so the player can know what he can buy from afar already
    local errors = {}
    errors[EntityType.Station] = "You must be docked to the station to sell items."%_T
    errors[EntityType.Ship] = "You must be closer to the ship to sell items."%_T
    if not CheckPlayerDocked(player, station, errors) then
        return
    end

    local items = buyer:getInventory():getItems()

    for index, slotItem in pairs(items) do

        local iitem = slotItem.item
        if iitem == nil then goto continue end
        if not iitem.trash then goto continue end

        for i = 1, slotItem.amount do
            local item = SellableInventoryItem(iitem, index, buyer)
            item.amount = 1

            if not item.sellable then break end

            local msg, args = item:soldByPlayer(ship, 1)
            if msg and msg ~= "" then
                player:sendChatMessage(station, 1, msg, unpack(args))
                return
            end

            local price = self:getBuyPrice(item.price, Faction(), buyer)
            buyer:receive("Sold an item for %1% Credits."%_T, price)

            -- insert the item into buyback list
            for i = 14, 1, -1 do
                self.buybackItems[i + 1] = self.buybackItems[i]
            end
            self.buybackItems[1] = item

            table.insert(self.boughtItems, SellableInventoryItem(slotItem.item, index, owner))
        end

        ::continue::
    end

    broadcastInvokeClientFunction("updateBoughtItem")
    self:broadcastItems()
end


function Shop:sellBackToPlayer(itemIndex) -- server

    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources, AlliancePrivilege.AddItems)
    if not buyer then return end

    local station = Entity()

    local item = self.buybackItems[itemIndex]
    if item == nil then
        player:sendChatMessage(station, 1, "Item to buy not found."%_t)
        return
    end

    local price = self:getBuyPrice(item.price, Faction(), buyer)
    local canPay, msg, args = buyer:canPay(price)
    if not canPay then
        player:sendChatMessage(station, 1, msg, unpack(args))
        return
    end

    -- test the docking last so the player can know what he can buy from afar already
    local errors = {}
    errors[EntityType.Station] = "You must be docked to the station to buy items."%_T
    errors[EntityType.Ship] = "You must be closer to the ship to buy items."%_T
    if not CheckPlayerDocked(player, station, errors) then
        return
    end

    local msg, args = item:boughtByPlayer(ship)
    if msg and msg ~= "" then
        player:sendChatMessage(station, 1, msg, unpack(args))
        return
    end

    -- no transaction tax here since it could be abused by 2 players working together
    -- receiveTransactionTax(station, item.price * 0.25 * self.tax)

    buyer:pay("Bought back an item for %1% Credits."%_T, price)

    -- remove item
    item.amount = item.amount - 1
    if item.amount == 0 then
        self.buybackItems[itemIndex] = nil
        self:rebuildTables()
    end

    -- do a broadcast to all clients that the item is sold out/changed
    self:broadcastItems()
end

function Shop:onSold(item, buyer)
    -- use/override this function to modify an item before it's actually added to the buyer's inventory

    -- return "Error message" to show that something didn't work
end

function Shop:cycleTags(index)
    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendItems)
    if not buyer then return end

    local inventory = buyer:getInventory()
    local item = inventory:find(index)
    if not item then print ("no item") end

    local favorite = false
    local trash = false

    if item.favorite then
        trash = true
    elseif item.trash then
        -- no changes necessary
    else
        favorite = true
    end

    inventory:setItemTags(index, favorite, trash)

    invokeClientFunction(Player(callingPlayer), "updateBoughtItem")
end

function Shop:canBeBought(item, ship, buyer)
    local ai = Faction()
    if not ai or not ai.isAIFaction then return end
    if self.everythingCanBeBought then return end

    if buyer.isPlayer or buyer.isAlliance then
        local can, msg, args = item:canBeBought(buyer, ai)
        if not can then
            return msg, args
        end
    end
end

function Shop:rebuildTables() -- server + client
    -- rebuild sold table
    local temp = self.soldItems
    self.soldItems = {}
    for i, item in pairs(temp) do
        table.insert(self.soldItems, item)
    end

    local temp = self.boughtItems
    self.boughtItems = {}
    for i, item in pairs(temp) do
        table.insert(self.boughtItems, item)
    end

    local temp = self.buybackItems
    self.buybackItems = {}
    for i, item in pairs(temp) do
        table.insert(self.buybackItems, item)
    end
end

function Shop:onMouseEvent(key, pressed, x, y)
    if not pressed then return false end
    if not self.guiInitialized then return false end
    if not self.shared.window.visible then return false end
    if not self.tabbedWindow.visible then return false end


    if self.tabbedWindow:getActiveTab().index == self.buyTab.index then
        if not (Keyboard():keyPressed(KeyboardKey.LControl) or Keyboard():keyPressed(KeyboardKey.RControl)) then return false end

        for i, line in pairs(self.soldItemLines) do
            local frame = line.frame

            if self.soldItems[i] ~= nil then
                if frame.visible then

                    local l = frame.lower
                    local u = frame.upper

                    if x >= l.x and x <= u.x then
                    if y >= l.y and y <= u.y then
                        Player():sendChatMessage(self.soldItems[i].item)
                        return true
                    end
                    end
                end
            end
        end

        if self.specialOffer.item then
            local l = self.specialOfferUI.frame.lower
            local u = self.specialOfferUI.frame.upper

            if x >= l.x and x <= u.x then
            if y >= l.y and y <= u.y then
                Player():sendChatMessage(self.specialOffer.item.item)
            end
            end
        end

    elseif self.tabbedWindow:getActiveTab().index == self.sellTab.index then

        for i, line in pairs(self.boughtItemLines) do

            if line.item ~= nil then
                if Keyboard():keyPressed(KeyboardKey.LControl) or Keyboard():keyPressed(KeyboardKey.RControl) then
                    local frame = line.frame
                    if frame.visible then

                        local l = frame.lower
                        local u = frame.upper

                        if x >= l.x and x <= u.x then
                        if y >= l.y and y <= u.y then
                            Player():sendChatMessage(line.item.item)
                            return true
                        end
                        end
                    end
                else
                    local icon = line.favoriteIcon

                    local l = icon.lower
                    local u = icon.upper

                    if x >= l.x and x <= u.x then
                    if y >= l.y and y <= u.y then
                        invokeServerFunction("cycleTags", line.item.index)
                        return true
                    end
                    end
                end
            end
        end

    elseif self.tabbedWindow:getActiveTab().index == self.buyBackTab.index then
        if not (Keyboard():keyPressed(KeyboardKey.LControl) or Keyboard():keyPressed(KeyboardKey.RControl)) then return false end

        for i, line in pairs(self.buybackItemLines) do
            local frame = line.frame

            if self.buybackItems[i] ~= nil then
                if frame.visible then

                    local l = frame.lower
                    local u = frame.upper

                    if x >= l.x and x <= u.x then
                    if y >= l.y and y <= u.y then
                        Player():sendChatMessage(self.buybackItems[i].item)
                        return true
                    end
                    end
                end
            end
        end
    end
end

-- this function gets called whenever the ui window gets rendered, AFTER the window was rendered (client only)
function Shop:onKeyboardEvent(key, pressed)

    if not pressed then return false end
    if key ~= KeyboardKey._E then return false end
    if not self.guiInitialized then return false end
    if not self.shared.window.visible then return false end
    if not self.tabbedWindow.visible then return false end

    local mouse = Mouse().position

    if self.tabbedWindow:getActiveTab().index == self.buyTab.index then
        for i, line in pairs(self.soldItemLines) do
            local frame = line.frame
            local realItem = self.soldItems[line.soldItemIndex or i]

            if realItem ~= nil then
                if frame.visible then

                    local l = frame.lower
                    local u = frame.upper

                    if mouse.x >= l.x and mouse.x <= u.x then
                    if mouse.y >= l.y and mouse.y <= u.y then
                        Player():addComparisonItem(realItem.item)
                    end
                    end
                end
            end
        end

        if self.specialOffer.item then
            local l = self.specialOfferUI.frame.lower
            local u = self.specialOfferUI.frame.upper

            if mouse.x >= l.x and mouse.x <= u.x then
            if mouse.y >= l.y and mouse.y <= u.y then
                Player():addComparisonItem(self.specialOffer.item.item)
            end
            end
        end

    elseif self.tabbedWindow:getActiveTab().index == self.sellTab.index then

        for i, line in pairs(self.boughtItemLines) do
            local frame = line.frame

            if line.item ~= nil then
                if frame.visible then

                    local l = frame.lower
                    local u = frame.upper

                    if mouse.x >= l.x and mouse.x <= u.x then
                    if mouse.y >= l.y and mouse.y <= u.y then
                        Player():addComparisonItem(line.item.item)
                    end
                    end
                end
            end
        end

    elseif self.tabbedWindow:getActiveTab().index == self.buyBackTab.index then

        for i, line in pairs(self.buybackItemLines) do
            local frame = line.frame

            if self.buybackItems[i] ~= nil then
                if frame.visible then

                    local l = frame.lower
                    local u = frame.upper

                    if mouse.x >= l.x and mouse.x <= u.x then
                    if mouse.y >= l.y and mouse.y <= u.y then
                        Player():addComparisonItem(self.buybackItems[i].item)
                    end
                    end
                end
            end
        end

    end
end

-- this function gets called whenever the ui window gets rendered, AFTER the window was rendered (client only)
function Shop:renderUI()
    if not self.tabbedWindow.mouseOver then return end

    local mouse = Mouse().position

    if self.tabbedWindow:getActiveTab().index == self.buyTab.index then
        for i, line in pairs(self.soldItemLines) do
            local frame = line.frame
            local realItem = self.soldItems[line.soldItemIndex or i]

            if realItem ~= nil then
                if frame.visible then

                    local l = frame.lower
                    local u = frame.upper

                    if mouse.x >= l.x and mouse.x <= u.x then
                    if mouse.y >= l.y and mouse.y <= u.y then
                        local renderer = TooltipRenderer(realItem:getTooltip())
                        renderer:drawMouseTooltip(Mouse().position)
                    end
                    end
                end
            end
        end

        if self.specialOffer.item then
            local l = self.specialOfferUI.frame.lower
            local u = self.specialOfferUI.frame.upper

            if mouse.x >= l.x and mouse.x <= u.x then
            if mouse.y >= l.y and mouse.y <= u.y then
                local renderer = TooltipRenderer(self.specialOffer.item:getTooltip())
                renderer:drawMouseTooltip(Mouse().position)
            end
            end
        end

    elseif self.tabbedWindow:getActiveTab().index == self.sellTab.index then

        for i, line in pairs(self.boughtItemLines) do
            local frame = line.frame

            if line.item ~= nil then
                if frame.visible then

                    local l = frame.lower
                    local u = frame.upper

                    if mouse.x >= l.x and mouse.x <= u.x then
                    if mouse.y >= l.y and mouse.y <= u.y then
                        local renderer = TooltipRenderer(line.item:getTooltip())
                        renderer:drawMouseTooltip(Mouse().position)
                    end
                    end
                end
            end
        end

    elseif self.tabbedWindow:getActiveTab().index == self.buyBackTab.index then

        for i, line in pairs(self.buybackItemLines) do
            local frame = line.frame

            if self.buybackItems[i] ~= nil then
                if frame.visible then

                    local l = frame.lower
                    local u = frame.upper

                    if mouse.x >= l.x and mouse.x <= u.x then
                    if mouse.y >= l.y and mouse.y <= u.y then
                        local renderer = TooltipRenderer(self.buybackItems[i]:getTooltip())
                        renderer:drawMouseTooltip(Mouse().position)
                    end
                    end
                end
            end
        end

    end
end

function Shop:getSellPriceAndTax(price, stationFaction, buyerFaction)
    price = price * self.priceRatio

    local taxAmount = round(price * self.tax)

    if stationFaction and buyerFaction and stationFaction.index == buyerFaction.index then
        price = price - taxAmount
        -- don't pay out for the second time
        taxAmount = 0
    end

    return price, taxAmount
end

function Shop:getBuyPrice(price, stationFaction, buyerFaction)
    -- buying items from players yields no tax income for the buying station
    return price * 0.25 -- must be adjusted in tooltipmaker.lua as well!
end

function Shop:getNumSoldItems()
    return tablelength(self.soldItems)
end

function Shop:getNumBuybackItems()
    return tablelength(self.buybackItems)
end

function Shop:getSoldItemPrice(index)
    return self.soldItems[index].price
end

function Shop:getSoldItems()
    return self.soldItems
end

function Shop:getSpecialOffer()
    return self.specialOffer
end

function Shop:getTax()
    return self.tax
end

PublicNamespace.CreateShop = setmetatable({new = new}, {__call = function(_, ...) return new(...) end})

function PublicNamespace.CreateNamespace()
    local result = {}

    local shop = PublicNamespace.CreateShop()

    shop.shared = PublicNamespace
    result.shop = shop
    result.onShowWindow = function(...) return shop:onShowWindow(...) end
    result.sendItems = function(...) return shop:sendItems(...) end
    result.receiveSoldItems = function(...) return shop:receiveSoldItems(...) end
    result.sellToPlayer = function(...) return shop:sellToPlayer(...) end
    result.buyFromPlayer = function(...) return shop:buyFromPlayer(...) end
    result.buyTrashFromPlayer = function(...) return shop:buyTrashFromPlayer(...) end
    result.sellBackToPlayer = function(...) return shop:sellBackToPlayer(...) end
    result.updateBoughtItem = function(...) return shop:updateBoughtItem(...) end
    result.onLeftButtonPressed = function(...) return shop:onLeftButtonPressed(...) end
    result.onRightButtonPressed = function(...) return shop:onRightButtonPressed(...) end
    result.onBuyTabLeftPressed = function(...) return shop:onBuyTabLeftPressed(...) end
    result.onBuyTabRightPressed = function(...) return shop:onBuyTabRightPressed(...) end
    result.onAmountEntered = function(...) return shop:onAmountEntered(...) end
    result.onBuyButtonPressed = function(...) return shop:onBuyButtonPressed(...) end
    result.onSellButtonPressed = function(...) return shop:onSellButtonPressed(...) end
    result.onSellTrashButtonPressed = function(...) return shop:onSellTrashButtonPressed(...) end
    result.onShowFavoritesPressed = function(...) return shop:onShowFavoritesPressed(...) end
    result.onShowTurretsPressed = function(...) return shop:onShowTurretsPressed(...) end
    result.onShowBlueprintsPressed = function(...) return shop:onShowBlueprintsPressed(...) end
    result.onShowUpgradesPressed = function(...) return shop:onShowUpgradesPressed(...) end
    result.onShowDefaultItemsPressed = function(...) return shop:onShowDefaultItemsPressed(...) end
    result.onReverseOrderPressed = function(...) return shop:onReverseOrderPressed(...) end
    result.cycleTags = function(...) return shop:cycleTags(...) end
    result.onBuybackButtonPressed = function(...) return shop:onBuybackButtonPressed(...) end
    result.renderUI = function(...) return shop:renderUI(...) end
    result.onMouseEvent = function(...) return shop:onMouseEvent(...) end
    result.onKeyboardEvent = function(...) return shop:onKeyboardEvent(...) end
    result.add = function(...) return shop:add(...) end
    result.restock = function(...) return shop:restock(...) end

    result.setSpecialOffer = function(...) return shop:setSpecialOffer(...) end
    result.onSpecialOfferSeedChanged = function(...) return shop:onSpecialOfferSeedChanged(...) end
    result.calculateSeed = function (...) return shop:calculateSeed(...) end
    result.generateSeed = function (...) return shop:generateSeed(...) end
    result.setStaticSeed = function(...) return shop:setStaticSeed(...) end
    result.updateClient = function(...) return shop:updateClient(...) end
    result.updateServer = function(...) return shop:updateServer(...) end

    result.getUpdateInterval = function(...) return shop:getUpdateInterval(...) end
    result.updateSellGui = function(...) return shop:updateSellGui(...) end
    result.broadcastItems = function(...) return shop:broadcastItems(...) end
    result.addFront = function(...) return shop:addFront(...) end
    result.getBuyPrice = function(...) return shop:getBuyPrice(...) end
    result.getNumSoldItems = function() return shop:getNumSoldItems() end
    result.getNumBuybackItems = function() return shop:getNumBuybackItems() end
    result.getSoldItemPrice = function(...) return shop:getSoldItemPrice(...) end
    result.getBoughtItemPrice = function(...) return shop:getBoughtItemPrice(...) end
    result.getTax = function() return shop:getTax() end
    result.getSoldItems = function() return shop:getSoldItems() end
    result.getSpecialOffer = function() return shop:getSpecialOffer() end

    -- the following comment is important for a unit test
    -- Dynamic Namespace result
    callable(result, "buyFromPlayer")
    callable(result, "buyTrashFromPlayer")
    callable(result, "sellBackToPlayer")
    callable(result, "sellToPlayer")
    callable(result, "cycleTags")
    callable(result, "sendItems")
    callable(result, "generateSeed")
    callable(result, "updateServer")
    callable(result, "onSpecialOfferSeedChanged")

    return result
end

return PublicNamespace