package.path = package.path .. ";data/scripts/lib/?.lua"
include ("stringutility")
include ("callable")


local lines = nil
local description = nil
local bulletins = {}
local interactionThreshold = -80000

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace BulletinBoard
BulletinBoard = {}

BulletinBoard.bulletins = bulletins

function BulletinBoard.initialize()
    if onClient() then
        BulletinBoard.fetchData()
    end
end

function BulletinBoard.interactionPossible(playerIndex, option)
    return CheckFactionInteraction(playerIndex, interactionThreshold)
end

function BulletinBoard.initUI()
    local res = getResolution()
    local size = vec2(900, 605)

    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))

    window.caption = "${entity} Bulletin Board"%_t % {entity = (Entity().translatedTitle or "")%_t}
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "Bulletin Board"%_t, 4);

    local hsplit = UIHorizontalSplitter(Rect(size), 10, 10, 0.6)

    local lister = UIVerticalLister(hsplit.top, 7, 10)

    local vsplit = UIArbitraryVerticalSplitter(lister:placeCenter(vec2(lister.inner.width, 30)), 10, 5, 20, 445, 565)

    window:createLabel(vsplit:partition(1).lower, "DESCRIPTION"%_t, 15)
    window:createLabel(vsplit:partition(2).lower, "DIFFICULTY"%_t, 15)
    window:createLabel(vsplit:partition(3).lower, "REWARD"%_t, 15)

    lines = {}

    for i = 1, 8 do
        local rect = lister:placeCenter(vec2(lister.inner.width, 30))
        local vsplit = UIVerticalSplitter(rect, 10, 0, 0.85)

        local avsplit = UIArbitraryVerticalSplitter(vsplit.left, 10, 7, 22, 445, 565)

        local frame = window:createFrame(vsplit.left)

        local i = 0

        local iconRect = avsplit:partition(i)
        iconRect.size = iconRect.size + vec2(7, 7)

        local missionIcon = window:createPicture(iconRect, ""); i = i + 1
        missionIcon.isIcon = true

        local briefRect = avsplit:partition(i); i = i + 1

        local brief = window:createLabel(briefRect.lower, "", 14);
        brief.width = briefRect.width
        brief.shortenText = true

        local difficulty = window:createLabel(avsplit:partition(i).lower, "", 14); i = i + 1
        local reward = window:createLabel(avsplit:partition(i).lower, "", 14); i = i + 1
        local button = window:createButton(vsplit.right, "Accept"%_t, "onTakeButtonPressed")

        local hide = function(self)
            self.missionIcon:hide()
            self.brief:hide()
            self.difficulty:hide()
            self.reward:hide()
            self.button:hide()
        end

        local show = function(self)
            self.frame:show()
            self.missionIcon:show()
            self.brief:show()
            self.difficulty:show()
            self.reward:show()
            self.button:show()
        end

        local line = {frame = frame, missionIcon = missionIcon, brief = brief, difficulty = difficulty, reward = reward, button = button, hide = hide, show = show, selected = false}

        table.insert(lines, line)
    end

    window:createLine(hsplit.bottom.topLeft, hsplit.bottom.topRight)
    description = window:createTextField(hsplit.bottom, "")

    BulletinBoard.refreshUI()

    BulletinBoard.fetchData()
end

function BulletinBoard.onShowWindow()
    BulletinBoard.fetchData()
end

function BulletinBoard.onTakeButtonPressed(button)
    for _, line in pairs(lines) do
        if line.button.index == button.index then
            invokeServerFunction("acceptMission", line.bulletinIndex)
        end
    end
end

function BulletinBoard.updateUI()
    if not lines then return end

    for _, line in pairs(lines) do
        if line.frame.mouseOver then
            if line.selected then
                line.frame.backgroundColor = ColorARGB(0.5, 0.35, 0.35, 0.35)
            else
                line.frame.backgroundColor = ColorARGB(0.5, 0.15, 0.15, 0.15)
            end
        else
            if line.selected then
                line.frame.backgroundColor = ColorARGB(0.5, 0.25, 0.25, 0.25)
            else
                line.frame.backgroundColor = ColorARGB(0.5, 0, 0, 0)
            end
        end
    end

    if Mouse():mouseDown(1) then

        description.text = ""
        local displayed = BulletinBoard.getDisplayedBulletins()

        for i, line in pairs(lines) do
            line.selected = line.frame.mouseOver

            if line.selected and displayed[i] then
                description.text = BulletinBoard.getDescriptionOfLine(displayed[i])
            end
        end
    end
end

function BulletinBoard.fetchData()
    if onClient() then
        invokeServerFunction("fetchData")
        return
    end

    invokeClientFunction(Player(callingPlayer), "receiveData", bulletins)
end
callable(BulletinBoard, "fetchData")

function BulletinBoard.receiveData(bulletins_in)
    bulletins = bulletins_in

    BulletinBoard.refreshUI()
    BulletinBoard.refreshIcon()

end

function BulletinBoard.getDisplayedBulletins()
    local player = Player()

    local id = getSessionId()
    local random = Random(Seed(id.string .. Entity().id.string))

    local displayed = {}
    for i, bulletin in pairs(bulletins) do

        if bulletin.script == "internal/dlc/blackmarket/player/missions/intro/storyintromission1.lua"
                and (player:hasScript("intromission1.lua") or player:getValue("accomplished_intro_1")) then
            goto continue
        end

        if bulletin.BMDLCOwnersOnly and not player.ownsBlackMarketDLC then
            if random:test(0.95) then
                goto continue
            end
        end

        bulletin.bulletinIndex = i
        table.insert(displayed, bulletin)

        ::continue::
    end

    return displayed
end

function BulletinBoard.refreshIcon()
    local containsStoryBulletin = false
    local displayed = BulletinBoard.getDisplayedBulletins()
    for _, bulletin in pairs(displayed) do
        if bulletin.script == "internal/dlc/blackmarket/player/missions/intro/storyintromission1.lua" then
            containsStoryBulletin = true
        end
    end

    if #displayed == 0 then
        EntityIcon().secondaryIcon = ""
    else
        if containsStoryBulletin then
            EntityIcon().secondaryIcon = "data/textures/icons/pixel/mission-white.png"
            EntityIcon().secondaryIconColor = ColorRGB(0.8, 0.4, 1) -- same color as blackmarket mask but slightly lighter for better contrast
        else
            EntityIcon().secondaryIcon = "data/textures/icons/pixel/mission.png"
            EntityIcon().secondaryIconColor = ColorRGB(1, 1, 1)
        end
    end

end

function BulletinBoard.refreshUI()
    if not lines then return end

    -- clear board
    for _, line in pairs(lines) do
        line:hide()
    end
    description.text = ""

    -- check which bulletins should be shown
    local player = Player()

    local id = getSessionId()
    local random = Random(Seed(id.string .. Entity().id.string))

    local displayed = BulletinBoard.getDisplayedBulletins()

    -- fill UI
    for i, bulletin in pairs(displayed) do
        local line = lines[i]
        if not line then break end

        line:show()

        line.bulletinIndex = bulletin.bulletinIndex
        line.missionIcon.picture = bulletin.icon or "data/textures/icons/basic-mission-marker.png"
        line.brief.caption = bulletin.brief%_t % bulletin.formatArguments
        line.difficulty.caption = bulletin.difficulty%_t % bulletin.formatArguments
        line.reward.caption = bulletin.reward%_t % bulletin.formatArguments

        if bulletin.BMDLCOwnersOnly and not player.ownsBlackMarketDLC then
            line.button.active = false
            line.button.tooltip = "This mission is only available for owners of the Black Market DLC."%_t
        else
            line.button.active = true
            line.button.tooltip = nil
        end

        if line.selected then
            description.text = BulletinBoard.getDescriptionOfLine(bulletin)
        end
    end

    -- if there are no bulletins to show, fill that in
    if #displayed == 0 then
        local line = lines[1]
        line:show()
        line.missionIcon.picture = "data/textures/icons/nothing.png"
        line.brief.caption = "No bulletins available!"%_t
        line.difficulty.caption = ""
        line.reward.caption = ""
        line.button:hide()
    end

end

function BulletinBoard.getDescriptionOfLine(bulletin)
    local translatedArguments = {}
    for k, v in pairs(bulletin.formatArguments or {}) do
        if atype(v) == "string" then
            translatedArguments[k] = GetLocalizedString(v)
        else
            translatedArguments[k] = v
        end
    end

    return (bulletin.description or bulletin.brief or "")%_t % translatedArguments
end

function BulletinBoard.postBulletin(bulletin_in)

    for _, bulletin in pairs(bulletins) do
        if bulletin.brief == bulletin_in.brief then
            return
        end
    end

    if bulletin_in.checkAccept then
        bulletin_in.checkAccept = assert(loadstring(bulletin_in.checkAccept))
    end

    if bulletin_in.onAccept then
        bulletin_in.onAccept = assert(loadstring(bulletin_in.onAccept))
    end

    table.insert(bulletins, bulletin_in)

    broadcastInvokeClientFunction("receiveData", bulletins)

    return #bulletins
end

-- key can be a string or an int
-- if it's a string it will be matched with the descriptions of the bulletins
-- if it's an int then the int is the index of the bulletin
function BulletinBoard.removeBulletin(key)
    local bulletin = bulletins[key]

    if not bulletin then
        for i, b in pairs(bulletins) do
            if b.brief == key then
                index = i
                bulletin = b
            end
        end
    else
        index = key
    end

    if not bulletin then return end

    bulletins[index] = nil

    local temp = bulletins
    bulletins = {}

    for _, bulletin in pairs(temp) do
        table.insert(bulletins, bulletin)
    end

    broadcastInvokeClientFunction("receiveData", bulletins)
end

function BulletinBoard.acceptMission(index)
    local bulletin = bulletins[index]
    if not bulletin then return end

    if not CheckFactionInteraction(callingPlayer, interactionThreshold) then return end

    local player = Player(callingPlayer)
    if bulletin.BMDLCOwnersOnly and not player.ownsBlackMarketDLC then
        player:sendChatMessage("Server", ChatMessageType.Error, "This mission is only available for owners of the Black Market DLC."%_T)
        return
    end

    if bulletin.checkAccept and bulletin.checkAccept(bulletin, player) == 0 then
        return
    end

    -- give the player a new mission
    player:addScript(bulletin.script, unpack(bulletin.arguments or {}))

    if bulletin.onAccept then bulletin.onAccept(bulletin, player) end

    BulletinBoard.removeBulletin(index)
end
callable(BulletinBoard, "acceptMission")

function BulletinBoard.addMission(script)
    local ok, bulletin = run(script, "getBulletin", Entity())

    if ok == 0 and bulletin then
        return BulletinBoard.postBulletin(bulletin)
    end
end

function BulletinBoard.getPostedBulletins()
    return bulletins
end
