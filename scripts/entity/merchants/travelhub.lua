package.path = package.path .. ";data/scripts/lib/?.lua"

include ("callable")
include ("stringutility")
include ("relations")
include ("faction")
include ("merchantutility")
include ("goods")
local Dialog = include("dialogutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace TravelHub
TravelHub = {}
TravelHub.interactionThreshold = 10000

local laserRefreshCounter = 0.0
local laserInterectionCounter = 0.0
local laserHitLastTick

local data = {}
data.booked = {}

local lasers = {}
local uis = {}

local requirements = { }
requirements[1] =
{
    distance = 7,
    money = 10000,
    goods = {
        {good = goods["Energy Cell"]:good(), amount = 5},
    }
}
requirements[2] =
{
    distance = 15,
    money = 30000,
    goods = {
        {good = goods["Energy Cell"]:good(), amount = 20},
    }
}
requirements[3] =
{
    distance = 25,
    money = 75000,
    goods = {
    {good = goods["Plasma Cell"]:good(), amount = 30},
    }
}
requirements[4] =
{
    distance = 50,
    money = 250000,
    goods = {
        {good = goods["Fusion Core"]:good(), amount = 10},
        {good = goods["Neutron Accelerator"]:good(), amount = 1},
        {good = goods["Proton Accelerator"]:good(), amount = 1},
        {good = goods["Electron Accelerator"]:good(), amount = 1},
    }
}

function TravelHub.interactionPossible(playerIndex, option)
    return CheckFactionInteraction(playerIndex, TravelHub.interactionThreshold)
end

function TravelHub.initialize()
    local station = Entity()

    if station.title == "" then
        station.title = "Travel Hub /* Station Title */"%_t
    end

    if onClient() and EntityIcon().icon == "" then
        EntityIcon().icon = "data/textures/icons/pixel/vortex.png"
        InteractionText(station.index).text = Dialog.generateStationInteractionText(station, random())
    end

    if onClient() then
        station:registerCallback("onBlockPlanChanged", "onBlockPlanChanged")
        TravelHub.onBlockPlanChanged()
    end
end

function TravelHub.initUI()
    local res = getResolution()
    local size = vec2(450, 600)

    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5));
    menu:registerWindow(window, "Travel Hub /* Interaction Title*/"%_t, 9);

    window.caption = "Travel Hub /* Station Title*/"%_t
    window.showCloseButton = 1
    window.moveable = 1

    local tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 10), size - vec2(10, 10)))
    local tab = tabbedWindow:createTab("", "data/textures/icons/vortex-i.png", "Economy Tier Travel Boost"%_t)
    TravelHub.buildTab(tab, 1)

    local tab = tabbedWindow:createTab("", "data/textures/icons/vortex-ii.png", "Tier II Travel Boost"%_t)
    TravelHub.buildTab(tab, 2)

    local tab = tabbedWindow:createTab("", "data/textures/icons/vortex-iii.png", "Tier III Travel Boost"%_t)
    TravelHub.buildTab(tab, 3)

    local tab = tabbedWindow:createTab("", "data/textures/icons/vortex-iv.png", "Tier IV Travel Boost"%_t)
    TravelHub.buildTab(tab, 4)

end

function TravelHub.buildTab(tab, tier)
    local requirement = requirements[tier]

    local ui = {tab = tab, tier = tier, requirement = requirement}
    uis[tier] = ui

    local hsplit = UIHorizontalSplitter(Rect(tab.size), 10, 0, 0.5)
    hsplit.bottomSize = 40

    local lister = UIVerticalLister(hsplit.top, 10, 0)

    -- top section
    tab:createLabel(lister:nextRect(20), "TIER ${tier} JUMP BOOST"%_t % {tier = toRomanLiterals(tier)}, 14)

    local rect = lister:nextRect(30)
    tab:createFrame(rect)

    local hlist = UIHorizontalLister(rect, 10, 0)
    hlist.marginLeft = 10
    hlist.marginRight = 10

    local label = tab:createLabel(hlist.inner, "Jump Distance"%_t, 14)
    label:setLeftAligned()
    label.tooltip = "Gain a one-time jump range boost for your next hyperspace jump."%_t
    local label = tab:createLabel(hlist.inner, "+" .. tostring(requirement.distance), 14)
    label:setRightAligned()
    label.color = ColorRGB(0.7, 0.7, 1.0)

    local rect = lister:nextRect(30)
    tab:createFrame(rect)

    local hlist = UIHorizontalLister(rect, 10, 5)
    hlist.marginLeft = 10
    ui.checkBox = tab:createCheckBox(hlist.inner, "Fleet Boost"%_t, "onFleetBoostChecked")
    ui.checkBox.tooltip = "Boost your entire fleet in the sector for double the price."%_t

    -- requirements
    lister:nextRect(0)
    tab:createLabel(lister:nextRect(20), "REQUIREMENTS"%_t, 14)

    -- credits
    local rect = lister:nextRect(30)
    tab:createFrame(rect)

    local hlist = UIHorizontalLister(rect, 10, 0)
    hlist.marginLeft = 10
    hlist.marginRight = 10

    local label = tab:createLabel(hlist.inner, "Credits"%_t, 14)
    label:setLeftAligned()
    ui.moneyLabel = tab:createLabel(hlist.inner, string.format("¢%s"%_t, createMonetaryString(requirement.money)), 14)
    ui.moneyLabel:setRightAligned()

    ui.goodsLabels = {}

    -- goods
    for _, required in pairs(requirement.goods) do
        local rect = lister:nextRect(30)
        tab:createFrame(rect)

        local hlist = UIHorizontalLister(rect, 10, 0)
        hlist.marginLeft = 10
        hlist.marginRight = 10

        local picture = tab:createPicture(hlist:nextQuadraticRect(), required.good.icon)
        picture.tooltip = required.good.displayDescription
        picture.isIcon = true

        local label = tab:createLabel(hlist.inner, required.good:displayName(required.amount), 14)
        label:setLeftAligned()
        local label = tab:createLabel(hlist.inner, required.amount, 14)
        label:setRightAligned()
        ui.goodsLabels[required.good.name] = label
    end

    local hsplit2 = UIHorizontalSplitter(hsplit.top, 10, 0, 0.5)
    hsplit2.bottomSize = 100
    tab:createFrame(hsplit2.bottom)
    local textField = tab:createTextField(hsplit2.bottom, "\\c(5af)How to:\\c() After booking, fly through the energy charge lines to activate the boost. You'll be charged when the boost is activated."%_t)
    textField.fontSize = 14
    textField.fontColor = ColorRGB(0.6, 0.6, 0.6)

    ui.button = tab:createButton(hsplit.bottom, "Book Boost"%_t, "onBookButtonPressed")
end

function TravelHub.onFleetBoostChecked(checkBox, checked)
    for _, ui in pairs(uis) do
        if ui.checkBox.index == checkBox.index then

            if checked then
                ui.moneyLabel.caption = string.format("¢%s"%_t, createMonetaryString(ui.requirement.money * 2))
                ui.button.caption = "Book Fleet Boost"%_t
            else
                ui.moneyLabel.caption = string.format("¢%s"%_t, createMonetaryString(ui.requirement.money))
                ui.button.caption = "Book Boost"%_t
            end

            for _, required in pairs(ui.requirement.goods) do
                if checked then
                    ui.goodsLabels[required.good.name].caption = required.amount * 2
                else
                    ui.goodsLabels[required.good.name].caption = required.amount
                end
            end

        end
    end
end

function TravelHub.onBookButtonPressed(button)
    for tier, ui in pairs(uis) do
        if ui.button.index == button.index then
            invokeServerFunction("bookBoost", tier, ui.checkBox.checked)
            return
        end
    end
end

function TravelHub.updateClient(timeStep)
    TravelHub.updateLaserFX()

    laserInterectionCounter = laserInterectionCounter + timeStep
    if laserInterectionCounter + timeStep >= 0.5 then
        laserInterectionCounter = laserInterectionCounter - 0.5
        TravelHub.updateLaserIntersection()
    end

end

function TravelHub.updateLaserFX()
    local center = vec3()
    for _, l in pairs(lasers) do
        center = center + l.block.box.position
    end

    local localCenter = center / #lasers

    local world = Entity().position
    local worldCenter = world:transformCoord(center)

    for _, l in pairs(lasers) do
        if not l.laser or not valid(l.laser) then
            local position = world:transformCoord(vec3(l.block.box.position))
            local laser = Sector():createLaser(position, worldCenter, ColorRGB(0.10, 0.20, 0.4), 3.0)

            laser.maxAliveTime = 2.0
            laser.animationSpeed = -3
            laser.collision = false
            laser.soundVolume = 0.05
            laser.soundMaxRadius = 400

            l.laser = laser
            l.from = l.block.box.position
            l.to = localCenter
        end

        l.laser.from = world:transformCoord(l.from)
        l.laser.to = world:transformCoord(l.to)
        l.laser.maxAliveTime = l.laser.aliveTime + 0.5
    end
end

function TravelHub.onBlockPlanChanged()
    for _, l in pairs(lasers) do
        if l.laser and valid(l.laser) then
            Sector():removeLaser(l.laser)
        end
    end

    lasers = {}

    -- find all blocks that are used to create lasers
    for _, type in pairs({BlockType.Glow, BlockType.GlowEdge}) do
        local glows = Plan():getBlocksByType(type)
        for _, blockIndex in pairs(glows) do
            local block = Plan():getBlock(blockIndex)

            if block.color.html == "ff6495ed" then
                table.insert(lasers, {block = block})
            end
        end
    end
end

function TravelHub.updateLaserIntersection()
    local playerCraft = Player().craft
    if not playerCraft then return end

    if playerCraft:hasScript("utility/jumprangeboost.lua") then return end

    local world = Entity().position
    local laserHit

    for _, l in pairs(lasers) do
        local from = world:transformCoord(l.from)
        local to = world:transformCoord(l.to)

        local ray = Ray(from, to - from)
        local entity, position = Sector():intersectBeamRay(ray, Entity().id, Entity().id)

        if entity and entity.id == playerCraft.id then
            laserHit = true

            if not laserHitLastTick then
                invokeServerFunction("buyBoost")
                break
            end
        end
    end

    laserHitLastTick = laserHit
end

function TravelHub.bookBoost(tier, fleet)
    if not callingPlayer then return end

    data.booked[callingPlayer] = {tier = tier, fleetBoost = fleet}

    local tier = toRomanLiterals(tier)
    local text = "Tier %1% Travel Boost booked. %2%"%_T
    local instructions = "Please fly through the energy lines to activate the boost. You will be charged once you cross them."%_t

    if fleet then
        text = "Tier %1% Travel Boost booked for all your ships in the sector. %2%"%_T
    end

    Player(callingPlayer):sendChatMessage(Entity(), ChatMessageType.Normal, text, tier, instructions)

end
callable(TravelHub, "bookBoost")


function TravelHub.detectHighestPossibleTier(buyer, ship)

    for _, tier in pairs({4, 3, 2, 1}) do
        local requirement = requirements[tier]

        -- enough money?
        if not buyer:canPay(requirement.money) then goto continue end

        -- goods on the ship?
        for _, required in pairs(requirement.goods) do
            local good = required.good
            local onShip = ship:getCargoAmount(good)

            if onShip < required.amount then
                goto continue
            end
        end

        if true then return tier end -- lua is so stupid
        ::continue::
    end

    return 0
end

function TravelHub.buyBoost()

    if not CheckFactionInteraction(callingPlayer, TravelHub.interactionThreshold) then return end

    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources)
    if not buyer then return end

    local stationFaction = Faction()
    local station = Entity()

    local relations = stationFaction:getRelations(buyer.index)
    if relations < TravelHub.interactionThreshold then return end

    if station:getNearestDistance(ship) >= 0.2 then return end

    -- if the player has already booked a boost then use that one
    local tier
    local fleetBoost

    if callingPlayer then
        local booked = data.booked[callingPlayer]
        if data.booked[callingPlayer] then
            tier = data.booked[callingPlayer].tier
            fleetBoost = data.booked[callingPlayer].fleetBoost

            data.booked[callingPlayer] = nil
        end
    end

    tier = tier or TravelHub.detectHighestPossibleTier(buyer, ship)
    tier = math.max(tier, 1)

    local requirement = requirements[tier]
    if not requirement then return end

    -- check if requirements are met
    if ship.freeCargoSpace == nil then return end

    local price = requirement.money
    if fleetBoost then price = price * 2 end

    if stationFaction.index == buyer.index then price = 0 end

    local canPay, msg, args = buyer:canPay(price)
    if not canPay then
        player:sendChatMessage(station, ChatMessageType.Error, msg, unpack(args))
        return
    end

    for _, required in pairs(requirement.goods) do
        local good = required.good
        local onShip = ship:getCargoAmount(good)

        local amount = required.amount
        if fleetBoost then amount = amount * 2 end

        if onShip < amount then
            player:sendChatMessage(station, ChatMessageType.Error, "You need %1% %2%! /* turns to 'You need 10 Energy Cells' or similar */"%_T, required.amount, good:displayName(required.amount))
            return
        end
    end

    -- remove goods from ship
    for _, required in pairs(requirement.goods) do
        local amount = required.amount
        if fleetBoost then amount = amount * 2 end

        ship:removeCargo(required.good, amount)
    end

    buyer:pay("Paid %1% credits for a hyperspace boost."%_T, price)
    stationFaction:receive(price)

    -- add the boost
    local ships = {ship}

    if fleetBoost then
        ships = {}
        for _, entity in pairs({Sector():getEntitiesByType(EntityType.Ship)}) do
            if entity.factionIndex == buyer.index then
                table.insert(ships, entity)
            end
        end
    end

    for _, ship in pairs(ships) do
        for index, script in pairs(ship:getScripts()) do
            if string.match(script, "utility/jumprangeboost.lua") then
                ship:removeScript(index)
            end
        end

        ship:addScript("utility/jumprangeboost.lua", requirement.distance or 5)
    end
end
callable(TravelHub, "buyBoost")

