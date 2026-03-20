package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/player/ui/encyclopedia/lib/?.lua"
package.path = package.path .. ";data/scripts/player/ui/encyclopedia/?.lua"

include("stringutility")
include("utility")
include("callable")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Encyclopedia
Encyclopedia = {}
local self = Encyclopedia

self.data = {}
self.data.shownPopUps = {}

if onClient() then

self.categories = {}
self.chapters = {}
self.articles = {}

self.titleLabel = nil
self.picture = nil
self.pictureLabel = nil
self.textField = nil
self.nextButton = nil
self.backButton = nil
self.originalRect = nil
self.tab = nil
self.tree = nil

function Encyclopedia.initialize()
    Player():registerCallback("onShowEncyclopediaArticle", "onShowEncyclopediaArticle")

    self.tab = PlayerWindow():createTab("Encyclopedia"%_t, "data/textures/icons/open-book.png", "Encyclopedia"%_t)

    local vsplit = UIVerticalSplitter (Rect(self.tab.size), 10, 0, 0.3)

    local lhsplit = UIHorizontalSplitter(vsplit.left, 10, 0, 0.5)
    lhsplit.topSize = 30

    self.searchTextBox = self.tab:createTextBox(lhsplit.top, "onSearchTextChanged")
    self.searchTextBox.backgroundText = "Search"%_t

    -- create the tree that will be filled with content
    self.tree = self.tab:createTree(lhsplit.bottom)
    self.fillTree()

    -- create the right side that will display the content
    local hsplit = UIHorizontalSplitter(vsplit.right, 30, 0, 0.5)
    hsplit.topSize = 20

    local hsplit2 = UIHorizontalSplitter(hsplit.bottom, 10, 0, 0.60)

    local hsplit3 = UIHorizontalSplitter(hsplit2.bottom, 10, 0, 0.5)
    hsplit3.bottomSize = 35

    hsplit.marginLeft = 10
    local titleRect = hsplit.top
    local textRect = hsplit3.top
    local buttonsRect = hsplit3.bottom

    self.titleLabel = self.tab:createLabel(titleRect, "Avorion Encyclopedia"%_t, 30)

    self.originalRect = hsplit2.top
    self.picture = self.tab:createPicture(self.originalRect, "data/textures/ui/mining_changes/mining-alpha.png")
    self.picture.flipped = true

    -- extra layer to show key binding
    self.pictureLabel = self.tab:createLabel(Rect(self.originalRect.lower + 25, self.originalRect.upper - 25), "Ctrl", 25)
    self.pictureLabel:setBottomLeftAligned()
    self.pictureLabel:hide()
    self.pictureLabel.layer = self.pictureLabel.layer + 4

    self.symbolLines = {}
    local slot = 0
    local lineHeight = 27 -- height of the individual line, also width of icon, since it is square
    for i = 1, 20 do
        local line = {}
        line.symbolFrame = self.tab:createFrame(Rect(self.originalRect.lower.x, self.originalRect.lower.y + slot, self.originalRect.upper.x, self.originalRect.lower.y + lineHeight + slot))
        line.symbolIcon = self.tab:createPicture(Rect(self.originalRect.lower.x + lineHeight, self.originalRect.lower.y + lineHeight + slot, self.originalRect.lower.x, self.originalRect.lower.y + slot), "")
        line.symbolLabel = self.tab:createLabel(Rect(self.originalRect.lower.x + 20 + lineHeight, self.originalRect.lower.y + 2 + slot, self.originalRect.upper.x, self.originalRect.lower.y + lineHeight + slot), "", 15)
        slot = slot + lineHeight + 10 -- last number is the distance between the lines
        table.insert(self.symbolLines, line)

        line.symbolFrame:hide()
        line.symbolIcon:hide()
        line.symbolLabel:hide()
    end

    -- background for text field
    self.backgroundBox = self.tab:createFrame(textRect)

    local text = "Welcome to the Avorion \\c(0d0)Encyclopedia\\c()! This is where you'll find information on a lot of Avorion's features.\n\nSimply select one of the \\c(0d0)categories\\c() on the left to get started!"%_t
    self.textField = self.tab:createTextField(textRect, text)
    self.textField.scrollable = true
    self.textField.font = FontType.Normal
    self.textField.fontSize = 14
    self.textField.fontColor = ColorRGB(0.7, 0.7, 0.7)

    local vsplit = UIVerticalMultiSplitter(buttonsRect, 10, 0, 3)
    self.backButton = self.tab:createButton(vsplit.left, "<", "onBackPressed")
    self.nextButton = self.tab:createButton(vsplit.right, ">", "onNextPressed")

    Encyclopedia.sync()
end

function Encyclopedia.onSearchTextChanged(textBox)
    Encyclopedia.fillTree()
end

function Encyclopedia.showEncyclopediaArticle(id)
    if not id then return end
    if not ClientSettings().encyclopediaPopUp then return end

    -- we need player to stop interacting here to ensure that encyclopedia doesn't appear behind station/ship script windows
    Player():stopInteracting()
    PlayerWindow():show()
    PlayerWindow():selectTab(self.tab)

    self.searchTextBox.text = ""
    Encyclopedia.fillTree()

    self.tree:selectById(id)
    self.refreshUI()
end

function Encyclopedia.getCurrentEntry()
    local index = self.tree.selectedIndex
    local result = self.categories[index]
    if not result then result = self.chapters[index] end
    if not result then result = self.articles[index] end

    return result
end

function Encyclopedia.getCurrentArticle()

    local entry = Encyclopedia.getCurrentEntry()
    if not entry then return nil end

    if entry.text then return entry end

    if entry.chapters then
        entry = entry.chapters[1]
    end
    if entry.text then return entry end

    -- check if entry has articles
    if entry.articles then
        entry = entry.articles[1]
    end
    if entry.text then return entry end

    return nil
end

function Encyclopedia.fillTreeCompletely()
    -- remember index, so that we can go on where we left off after updating tree
    local index = self.tree.selectedIndex

    -- clear tree and refill it
    self.tree:clear()
    self.tree:setLevelStyle(0, 30, 18)
    self.categories = {}
    self.chapters = {}
    self.articles = {}

    for _, category in pairs(Categories or {}) do

        if category.isUnlocked then
            if not category:isUnlocked() then
                goto continueCategory
            end
            category.unlocked = true
        end

        local hasContent = (category.text ~= nil)
        local categoryIndex = self.tree:add(nil, category.title, "onEntrySelected", hasContent, category.id)
        self.categories[categoryIndex] = category

        for _, chapter in pairs(category.chapters or {}) do

            if chapter.isUnlocked then
                if not chapter:isUnlocked() then
                    goto continueChapter
                end
                chapter.unlocked = true
            end

            local hasContent = (chapter.text ~= nil)
            local chapterIndex = self.tree:add(categoryIndex, chapter.title, "onEntrySelected", hasContent, chapter.id)
            self.chapters[chapterIndex] = chapter

            for _, article in pairs(chapter.articles or {}) do

                if article.isUnlocked then
                    if not article:isUnlocked() then
                        goto continueArticle
                    end

                    article.isUnlocked(article) -- call it to set combination texts
                    article.unlocked = true
                end

                local hasContent = (article.text ~= nil)
                local articleIndex = self.tree:add(chapterIndex, article.title, "onEntrySelected", hasContent, article.id)
                self.articles[articleIndex] = article

                ::continueArticle::
            end
            ::continueChapter::
        end
        ::continueCategory::
    end

    -- put saved index back
    self.tree.selectedIndex = index
end

function Encyclopedia.fillTreeFiltered(searchText)
    -- clear tree and refill it
    self.tree:clear()
    self.tree:setLevelStyle(0, 20, 14)
    self.categories = {}
    self.chapters = {}
    self.articles = {}

    local results = {}

    -- prepend any punctuation with a %; in detail: () captures, %p matches punctuation, %% is a %, %1 is replaced by the match
    searchText = string.gsub(searchText, "(%p)", "%%%1")
    searchText = string.lower(searchText)

    local elements = string.split(searchText, " ")

    function matches(article)
        if article.isUnlocked then
            if not article:isUnlocked() then
                return false
            end
            article.unlocked = true
        end

        local lowerTitle = string.lower(article.title or "")
        if string.match(lowerTitle, searchText) then return true end

        local lowerText = string.lower(article.text or "")
        if string.match(lowerText, searchText) then return true end

        if #elements > 1 then
            for _, text in pairs({lowerTitle, lowerText}) do
                local matches = 0
                for _, element in pairs(elements) do
                    if string.match(text, element) then matches = matches + 1 end
                end

                if matches == #elements then return true end
            end
        end

    end

    for _, category in pairs(Categories or {}) do

        if matches(category) then
            local hasContent = (category.text ~= nil)
            local categoryIndex = self.tree:add(nil, category.title, "onEntrySelected", hasContent, category.id)
            self.categories[categoryIndex] = category
        end

        for _, chapter in pairs(category.chapters or {}) do

            if matches(chapter) then
                local hasContent = (chapter.text ~= nil)
                local chapterIndex = self.tree:add(nil, chapter.title, "onEntrySelected", hasContent, chapter.id)
                self.chapters[chapterIndex] = chapter
            end

            for _, article in pairs(chapter.articles or {}) do

                if matches(article) then
                    local hasContent = (article.text ~= nil)
                    local articleIndex = self.tree:add(nil, article.title, "onEntrySelected", hasContent, article.id)
                    self.articles[articleIndex] = article
                end
            end
        end
    end
end

function Encyclopedia.fillTree()

    include("chapters/basics")
    include("chapters/exploring")
    include("chapters/building")
    include("chapters/resourcemanagement")
    include("chapters/craftmanagement")
    include("chapters/fleetmanagement")
    include("chapters/diplomacy")
    include("chapters/combat")
    include("chapters/trade")
    include("chapters/goodsglossary")
    include("chapters/production")
    include("chapters/coopmultiplayer")

    local searchText = string.trim(self.searchTextBox.text)

    if searchText == "" then
        Encyclopedia.fillTreeCompletely()
    else
        Encyclopedia.fillTreeFiltered(searchText)
    end

end

function Encyclopedia.onBackPressed()
    self.tree:selectPrevious()
    self.refreshUI()
end

function Encyclopedia.onNextPressed()
    self.tree:selectNext()
    self.refreshUI()
end

function Encyclopedia.onEntrySelected(index)
    self.tree.selectedIndex = index
    self.refreshUI()
end

function Encyclopedia.getUpdateInterval()
    return 1
end

function Encyclopedia.update(timeStep)

    -- check whether a new article is available
    local newUnlocked = false
    local entryToUnlock = nil
    for _, category in pairs(Categories or {}) do
        if category.isUnlocked then
            if not category.unlocked and category:isUnlocked() then
                newUnlocked = true
                entryToUnlock = category
                category.unlocked = true
            end
        end

        for _, chapter in pairs(category.chapters or {}) do
            if chapter.isUnlocked then
                if not chapter.unlocked and chapter:isUnlocked() then
                    newUnlocked = true
                    entryToUnlock = chapter
                    chapter.unlocked = true
                end
            end

            for _, article in pairs(chapter.articles or {}) do
                if article.isUnlocked then
                    if not article.unlocked then
                        if article:isUnlocked() then
                            newUnlocked = true
                            entryToUnlock = article
                            article.unlocked = true
                        end
                    end
                end
            end
        end
    end

    if newUnlocked then
        invokeServerFunction("sendChangeNotification", entryToUnlock)
        self.fillTree()
    end


    -- update currently viewed article
    local article = self.getCurrentArticle()
    if not article then return end

    if article.entries then -- so far, only "Symbols" in "Exploring" has this
        self.textField:hide()
        self.backgroundBox:hide()
        for i = 1, #article.entries do
            self.symbolLines[i].symbolFrame:show()
            self.symbolLines[i].symbolIcon:show()
            self.symbolLines[i].symbolLabel:show()
            self.symbolLines[i].symbolIcon.picture = article.entries[i][1]
            self.symbolLines[i].symbolLabel.caption = article.entries[i][2]
        end
    else
        self.textField:show()
        self.backgroundBox:show()
        for _, l in pairs(self.symbolLines) do
            l.symbolFrame:hide()
            l.symbolIcon:hide()
            l.symbolLabel:hide()
        end
    end

    if not article.pictures then return end

    local timePerFrame = 1 / (article.fps or 1)
    article.timer = (article.timer or 0) + timeStep
    if article.timer > timePerFrame then
        article.timer = article.timer - timePerFrame

        -- increase frame and update picture
        article.frame = (article.frame or 1) + 1
        if article.frame > #article.pictures then
            article.frame = 1
        end

        article.picture = article.pictures[article.frame]
        if type(article.picture) == "table" then
            if article.frame == 1 then
                self.picture.picture = article.picture.path
            else
                self.picture:fadeTo(article.picture.path, 0.4)
            end
            self.pictureLabel.caption = article.picture.caption
            self.pictureLabel.active = article.picture.showLabel
            self.pictureLabel:show()
        else
            if article.frame == 1 then
                self.picture.picture = article.picture
            else
                self.picture:fadeTo(article.picture, 0.4)
            end
            self.pictureLabel:hide()
        end

        self.picture.rect = Rect(self.originalRect.lower + self.tab.lower, self.originalRect.upper + self.tab.lower)
        self.picture:fitIntoRect()
    end

end

function Encyclopedia.refreshUI()

    local entry = self.getCurrentEntry()
    local currentArticle = self.getCurrentArticle()

    if currentArticle then
        if currentArticle.entries then
            self.textField:hide()
            self.backgroundBox:hide()
            for i = 1, #currentArticle.entries do
                self.symbolLines[i].symbolFrame:show()
                self.symbolLines[i].symbolIcon:show()
                self.symbolLines[i].symbolLabel:show()
                self.symbolLines[i].symbolIcon.picture = currentArticle.entries[i][1]
                self.symbolLines[i].symbolLabel.caption = currentArticle.entries[i][2]
            end
        else
            self.textField:show()
            self.backgroundBox:show()
            for _, l in pairs(self.symbolLines) do
                l.symbolFrame:hide()
                l.symbolIcon:hide()
                l.symbolLabel:hide()
            end
        end

        if currentArticle.pictures then
            if type(currentArticle.pictures[1]) == "table" then
                currentArticle.picture = currentArticle.pictures[1].path
                self.pictureLabel.caption = currentArticle.pictures[1].caption
                self.pictureLabel.active = currentArticle.pictures[1].showLabel
                self.pictureLabel:show()
            else
                currentArticle.picture = currentArticle.pictures[1]
                self.pictureLabel:hide()
            end
            currentArticle.frame = 1
            currentArticle.timer = 0
        elseif currentArticle.picture then
            if type(currentArticle.picture) == "table" then
                self.pictureLabel.caption = currentArticle.picture.caption
                self.pictureLabel.active = currentArticle.picture.showLabel
                self.pictureLabel:show()
            else
                self.pictureLabel:hide()
            end
        end

        self.titleLabel.caption = currentArticle.title or entry.title or ""
        self.picture.picture = currentArticle.picture or ""
        self.textField.text = currentArticle.text or ""

        self.picture.rect = Rect(self.originalRect.lower + self.tab.lower, self.originalRect.upper + self.tab.lower)
        self.picture:fitIntoRect()
        self.picture:show()

        if currentArticle.unlockEncyclopediaMilestone then
            invokeServerFunction("unlockEncyclopediaMilestone")
        end
    else
        self.titleLabel.caption = ""
        self.picture:hide()
        self.pictureLabel:hide()
        self.textField.text = ""
    end

end

end

function Encyclopedia.deferredShowEncyclopediaArticle(id)
    deferredCallback(2.0, "onShowEncyclopediaArticle", id)
end

function Encyclopedia.onShowEncyclopediaArticle(id)
    if not id then return end

    if self.data.shownPopUps[id] then return end

    if onServer() then
        invokeClientFunction(Player(), "showEncyclopediaArticle", id)
        Encyclopedia.rememberPopUp(id)
    else
        invokeServerFunction("rememberPopUp", id)
        Encyclopedia.showEncyclopediaArticle(id)
    end
end

function Encyclopedia.checkIfInFight()
    local player = Player()
    local craft = player.craft
    if not craft then return false end

    local engine = HyperspaceEngine(player.craft)
    if not engine then return false end

    -- distorted hyperspace engine means the craft is under attack
    return engine.distorted
end

function Encyclopedia.sync(data_in)
    if onClient() then
        if data_in then
            self.data = data_in
        else
            invokeServerFunction("sync")
        end
    else
        invokeClientFunction(Player(callingPlayer), "sync", self.data)
    end
end
callable(Encyclopedia, "sync")

if onServer() then

function Encyclopedia.initialize()
    Player():registerCallback("onShowEncyclopediaArticle", "onShowEncyclopediaArticle")
end

function Encyclopedia.rememberPopUp(id)
    -- only allow the player themselves to change the variables
    if callingPlayer and callingPlayer ~= Player().index then return end

    self.data.shownPopUps = self.data.shownPopUps or {}

    if not self.data.shownPopUps[id] then
        self.data.shownPopUps[id] = true
        Encyclopedia.sync()
    end
end
callable(Encyclopedia, "rememberPopUp")

function Encyclopedia.clearRememberedPopUps()
    self.data.shownPopUps = {}
    Encyclopedia.sync()

    -- this serves as some kind of feedback that the reset worked
    print ("Cleared all remembered Pop-Ups of Encylopedia")
end

function Encyclopedia.secure()
    return self.data
end

function Encyclopedia.restore(data_in)
    self.data = data_in or {}
    self.data.shownPopUps = self.data.shownPopUps or {}
end

function Encyclopedia.unlockEncyclopediaMilestone()
    Player():sendCallback("onEncyclopediaRepairDockRead")
end
callable(Encyclopedia, "unlockEncyclopediaMilestone")

function Encyclopedia.setValue(name)
    Player():setValue("encyclopedia_"..name, true)
end
callable(Encyclopedia, "setValue")

function Encyclopedia.sendChangeNotification(entry)
    if entry then
        Player():sendChatMessage("Encyclopedia", ChatMessageType.Information, "New entry in Encyclopedia unlocked: %s"%_T, entry.title)
    end
end
callable(Encyclopedia, "sendChangeNotification")

end
