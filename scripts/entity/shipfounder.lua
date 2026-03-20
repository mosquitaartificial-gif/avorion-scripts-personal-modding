package.path = package.path .. ";data/scripts/lib/?.lua"
include ("defaultscripts")
include ("stringutility")
include ("utility")
include ("callable")
include ("reconstructionutility")
ShipFounding = include ("shipfounding")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace ShipFounder
ShipFounder = {}

local nameTextBox = nil
local allianceCheckBox = nil
local feeLabel = nil
local materialsLabel = nil
local includedCrewLabel = nil
local includedCrewAmountLabel = nil
local window = nil
local warningLabel = nil

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function ShipFounder.interactionPossible(playerIndex, option)
    local self = Entity()
    local player = Player(playerIndex)

    if self.factionIndex ~= player.index then return false end

    local craft = player.craft
    if craft == nil then return false end

    if self.index == craft.index then
        return true
    end

    return false, "Fly the craft to found a ship."%_t
end

function ShipFounder.getIcon()
    return "data/textures/icons/flying-flag.png"
end

-- create all required UI elements for the client side
function ShipFounder.initUI()

    local res = getResolution()
    local size = vec2(400, 300)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    window.caption = "Founding Ship"%_t
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "Found Ship"%_t);

    local hsplit = UIHorizontalSplitter(Rect(size), 10, 10, 0.5)
    hsplit.bottomSize = 40

    -- button at the bottom
    local button = window:createButton(hsplit.bottom, "OK"%_t, "onFoundButtonPress");
    button.textSize = 14

    -- name & type
    local hsplit2 = UIHorizontalSplitter(hsplit.top, 10, 0, 0.6)
    local lister = UIVerticalLister(hsplit2.top, 10, 0)

    local label = window:createLabel(Rect(), "Enter the name of the ship:"%_t, 14);
    label.centered = true
    label.wordBreak = true

    lister:placeElementTop(label)

    nameTextBox = window:createTextBox(Rect(), "")
    nameTextBox.maxCharacters = 35
    nameTextBox:forbidInvalidFilenameChars()
    lister:placeElementTop(nameTextBox)

    local rect = lister.rect
    local vsplit = UIVerticalSplitter(lister.rect, 10, 10, 0.85)

    warningPicture = window:createPicture(vsplit.right, "data/textures/icons/hazard-sign.png")
    warningPicture.isIcon = true
    warningPicture.color = ColorRGB(1, 0, 0)
    warningPicture.tooltip = "WARNING: Having many ships in many different sectors can cause lags, FPS drops and overall bad game performance.\nThis is highly dependent on your system."%_t

    allianceCheckBox = window:createCheckBox(Rect(), "Alliance Ship"%_t, "onAllianceCheckBoxChecked")
    allianceCheckBox.active = false
    allianceCheckBox.captionLeft = false
    lister:placeElementTop(allianceCheckBox)

    -- costs
    local lister = UIVerticalLister(hsplit2.bottom, 10, 0)
    local rect = lister:nextRect(20)
    local label = window:createLabel(rect, "Founding Fee: (?)"%_t, 14);
    label:setLeftAligned()
    label.tooltip = "Every ship costs a basic material founding fee. The more ships you own, the higher the material tier."%_t

    feeLabel = window:createLabel(rect, "", 14);
    feeLabel:setRightAligned()

    local rect = lister:nextRect(16)
    includedCrewLabel = window:createLabel(rect, "Included Crew: (?)"%_t, 14);

    includedCrewAmountLabel = window:createLabel(rect, "", 14);
    includedCrewAmountLabel:setRightAligned()

    window:createLine(hsplit2.top.bottomLeft, hsplit2.top.bottomRight)
end

function ShipFounder.onFoundButtonPress()
    name = nameTextBox.text
    invokeServerFunction("found", name, allianceCheckBox.checked, Hud().tutorialActive)
end


function ShipFounder.foundShip(faction, player, name, tutorialActive)

    local limit = faction.maxNumShips

    if limit and limit >= 0 and faction.numShips >= limit then
        player:sendChatMessage("", 1, "Maximum ship limit for this faction (%s) of this server reached!"%_t, limit)
        return
    end

    if faction:ownsShip(name) then
        player:sendChatMessage("", 1, "You already have a ship called '%s'."%_t, name)
        return
    end

    local resources = ShipFounding.getNextShipCosts(faction)

    local ok, msg, args = faction:canPay(0, unpack(resources))
    if not ok then
        player:sendChatMessage("", 1, msg, unpack(args))
        return
    end

    -- resources must not contain any materials that can't be built
    local maxBuildable = player.maxBuildableMaterial

    local args = {}
    local material = Material()
    for i, amount in pairs(resources) do
        material = Material(i-1)

        if amount > 0 then
            args.amount = amount
            args.material = material.name
            break
        end
    end

    -- resources must not contain any materials that can't be built
    local maxBuildable = player.maxBuildableMaterial
    if material > maxBuildable then
        player:sendChatMessage("", 1, "You need building knowledge for %1% to found this ship."%_T, material.name)
        return
    end

    faction:pay("Paid ${amount} ${material} to found a ship."%_T % args, 0, unpack(resources))

    local self = Entity()

    local plan = BlockPlan()
    plan:addBlock(vec3(0, 0, 0), vec3(2, 2, 2), -1, -1, material.blockColor, material, Matrix(), BlockType.Hull, ColorNone())

    local ship = Sector():createShip(faction, name, plan, self.position);

    -- add base scripts
    AddDefaultShipScripts(ship)
    SetBoardingDefenseLevel(ship)

    -- add base crew
    if tutorialActive ~= true then
        local baseCrewAmount = ShipFounder.getBaseCrewAmount()
        ship:addCrew(baseCrewAmount, CrewMan(CrewProfession(CrewProfessionType.None), false, 1))
    end

    player.craft = ship

    local settings = GameSettings()
    if settings.difficulty <= Difficulty.Veteran and GameSettings().reconstructionAllowed then
        local kit = createReconstructionKit(ship)
        faction:getInventory():addOrDrop(kit, true)
    end

    return ship
end

function ShipFounder.onAllianceCheckBoxChecked()
    ShipFounder.refreshUI()
end

function ShipFounder.refreshUI()
    local resources
    local ships = 0

    local alliance = Player().alliance
    if allianceCheckBox.checked and alliance then
        resources, ships = ShipFounding.getNextShipCosts(alliance)
    else
        resources, ships = ShipFounding.getNextShipCosts(Player())
    end

    local amount = 500
    local material = Material(MaterialType.Naonite)

    for i, am in pairs(resources) do
        if am > 0 then
            amount = am
            material = Material(i-1)
            break
        end
    end

    feeLabel.caption = "${amount} ${material}"%_t % {amount = amount, material = material.name}
    feeLabel.color = material.color

    local baseCrewAmount = ShipFounder.getBaseCrewAmount()

    includedCrewAmountLabel.caption = "${amount}"%_t % {amount = baseCrewAmount}

    window.caption = "Founding Ship #${number}"%_t % {number = ships + 1}

    if Hud().tutorialActive then
        includedCrewAmountLabel.tooltip = "While in tutorial, you don't get crewmembers for free.\nDepending on the difficulty you're playing on, you will get a certain number of crew members whenever you found a ship."%_t
    else
        includedCrewAmountLabel.tooltip = "Depending on the difficulty you're playing on, you will get a certain number of crew members whenever you found a ship."%_t
    end

    if ships + 1 >= 25 then
        warningPicture:show()
    else
        warningPicture:hide()
    end

end

function ShipFounder.onShowWindow()

    local alliance = Alliance()

    if valid(alliance) then
        allianceCheckBox.active = true
    else
        allianceCheckBox.checked = false
        allianceCheckBox.active = false
    end

    ShipFounder.refreshUI()
end

function ShipFounder.getBaseCrewAmount()
    if onClient() then
        if Hud().tutorialActive then
            return 0
        end
    end

    if GameSettings().difficulty <= Difficulty.Normal then
        -- Easy and normal difficulties: add 4 crewmen for starters
        return 4
    elseif GameSettings().difficulty <= Difficulty.Veteran then
        -- up to veteran: add 2 crewmembers
        return 2
    end

    return 0
end

function ShipFounder.found(name, forAlliance, tutorialActive)

    if anynils(callingPlayer, name, forAlliance) then return end

    local player = Player(callingPlayer)

    if forAlliance then
        local alliance = player.alliance

        if not alliance then
            player:sendChatMessage("", 1, "You're not in an alliance."%_t)
            return
        end

        if not alliance:hasPrivilege(callingPlayer, AlliancePrivilege.FoundShips) then
            player:sendChatMessage("", 1, "You don't have permissions to found ships for your alliance."%_t)
            return
        end

        local ship = ShipFounder.foundShip(alliance, player, name, tutorialActive)

        if ship then
            ship:addScriptOnce("entity/claimalliance.lua")
        end
    else
        ShipFounder.foundShip(player, player, name, tutorialActive)
    end

end
callable(ShipFounder, "found")

