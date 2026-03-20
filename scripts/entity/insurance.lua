package.path = package.path .. ";data/scripts/lib/?.lua"
include ("galaxy")
include ("utility")
include ("stringutility")
include ("faction")
include ("callable")
include ("reconstructionutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Insurance
Insurance = {}

Insurance.insuredValue = 0
Insurance.refundedValue = 0
Insurance.periodic = false

local mailHeader = "Loss Payment enclosed"%_T
local mailSender = "S.I.I. /* Abbreviation for Ship Insurance Intergalactical, must match with the email signature */"%_T

-- if this function returns false, the script will not be listed in the interaction window on the client,
-- even though its UI may be registered

function Insurance.interactionPossible(playerIndex, option)
    local factionIndex = Entity().factionIndex
    if factionIndex == playerIndex or factionIndex == Player().allianceIndex then
        return true, ""
    end

    return false
end

function Insurance.restore(values)
    Insurance.insuredValue = values.insuredValue or 0
    Insurance.refundedValue = values.refundedValue or 0
    Insurance.periodic = values.periodic or false

    if GameSettings().permaDestruction then
        local returned = math.floor(Insurance.insuredValue * 0.3)
        if returned > 0 then
            Faction():receive("Received %1% Credits: insurance reimbursement."%_T, returned)
            Insurance.insuredValue = 0
        end

        terminate()
    end
end

function Insurance.secure()
    return {
        insuredValue = Insurance.insuredValue,
        refundedValue = Insurance.refundedValue,
        periodic = Insurance.periodic,
    }
end

-- this function gets called on creation of the entity the script is attached to, on client and server
function Insurance.initialize()
    if onServer() then
        if not _restoring and GameSettings().permaDestruction then
            terminate()
            return
        end

        local entity = Entity()

        -- new: remove insurance from scripts and replace with a Reconstruction Token
        -- this is mainly for backwards compatibility, for when ships still had insurances
        if entity.type == EntityType.Ship then
            local faction = Faction()
            if faction and (faction.isPlayer or faction.isAlliance) then
                faction:getInventory():add(createReconstructionKit(entity))
            end
            terminate()
            return
        end

        entity:registerCallback("onDestroyed" , "onDestroyed")
        entity:registerCallback("onPlanModifiedByBuilding" , "onBuild")
        entity:registerCallback("onReconstructed" , "onReconstructed")
    end

end

-- this function gets called on creation of the entity the script is attached to, on client only
-- AFTER initialize above
-- create all required UI elements for the client side
function Insurance.initUI()
    local res = getResolution();
    local size = vec2(400, 330)

    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5));
    menu:registerWindow(window, "Insurance Plan"%_t);

    window.caption = "Insurance '${craft}'"%_t % {craft = Entity().name}
    window.showCloseButton = 1
    window.moveable = 1

    local hsplit = UIHorizontalSplitter(Rect(vec2(), size), 10, 10, 0.5)
    hsplit.bottomSize = 40

    window:createLabel(vec2(10, 10), "Ship Value"%_t, 15)
    window:createLabel(vec2(10, 30), "Insured Value"%_t, 15)
    window:createLabel(vec2(10, 50), "Refunded Value"%_t, 15)
    window:createLabel(vec2(10, 90), "Insurance Price"%_t, 15)
    window:createLabel(vec2(10, 110), "Paid"%_t, 15)
    window:createLabel(vec2(10, 140), "Still Due"%_t, 15)

    local w = 150
    shipValueLabel = window:createLabel(vec2(w, 10), "", 15)
    insuranceValueLabel = window:createLabel(vec2(w, 30), "", 15)
    insuredPercentageLabel = window:createLabel(vec2(w, 30), "", 15)
    refundedValueLabel = window:createLabel(vec2(w, 50), "", 15)
    priceLabel = window:createLabel(vec2(w, 90), "", 15)
    paidLabel = window:createLabel(vec2(w, 110), "", 15)
    paidPercentageLabel = window:createLabel(vec2(w, 110), "", 15)
    dueLabel = window:createLabel(vec2(w, 140), "", 15)

    for _, label in pairs({shipValueLabel, insuranceValueLabel, refundedValueLabel, priceLabel, paidLabel, dueLabel}) do
        label.size = vec2(150, 20)
        label:setRightAligned()
    end

    insuredPercentageLabel.size = vec2(240, 20)
    insuredPercentageLabel:setRightAligned()

    paidPercentageLabel.size = vec2(240, 20)
    paidPercentageLabel:setRightAligned()

    periodicCheckBox = window:createCheckBox(Rect(10, 190, size.x - 10, 210), "Automatic Payments"%_t, "onPeriodicPaymentsChecked")
    periodicCheckBox.tooltip =  "Automatically pays 10% of your Credits every few minutes\nas, long as you haven't fully paid for your insurance."%_t

    payButton = window:createButton(hsplit.bottom, "Buy Full Insurance"%_t, "onPayButtonPressed")

    shipValueLabel.tooltip = "This is your ship's value."%_t
    priceLabel.tooltip = "The price for the insurance of your ship (30% of its value)."%_t

    refundedValueLabel.tooltip = "On destruction, this much money will be refunded by your insurance."%_t
    insuranceValueLabel.tooltip = "The maximum value that your current insurance will cover."%_t
    paidPercentageLabel.tooltip = "The amount of money you have already paid."%_t

    local qFrame = window:createFrame(Rect(0, 0, 20, 20))
    local qLabel = window:createLabel(vec2(0, 0), " ?", 15)

    qFrame.position = qFrame.position + vec2(370, 220)
    qLabel.position = qFrame.position
    qLabel.size = vec2(20, 20)
    qLabel.tooltip =    "When destroyed, your ship's insurance will refund its value. The price is 30% of your ship's value.\n"%_t ..
                        "You can pay only a fraction of the insurance price, but then only the same fraction of your ship's value gets refunded.\n"%_t ..
                        "If you make your ship bigger, you will have to make further payments.\n"%_t ..
                        "If you make your ship smaller, you won't get money back that you already spent, but it stays invested and you won't have to pay twice."%_t

    commentLabel = window:createLabel(vec2(20, 240), "Your ship is not insured!"%_t, 15)
    commentLabel.centered = 1
    commentLabel.size = vec2(size.x - 40, 20)

end

function Insurance.onShowWindow()
    invokeServerFunction("refreshUI")
end

function Insurance.refreshUI(insuredValueIn, refundedValueIn, periodicIn)

    if onServer() then
        if callingPlayer then
            invokeClientFunction(Player(callingPlayer), "refreshUI", Insurance.insuredValue, Insurance.refundedValue, Insurance.periodic)
        end
        return
    end

    Insurance.insuredValue = insuredValueIn or Insurance.insuredValue
    Insurance.refundedValue = refundedValueIn or Insurance.refundedValue
    Insurance.periodicIn = periodicIn or false

    local value = Insurance.getShipValue()
    local price = math.floor(value * 0.3)

    local due = math.max(0, math.floor(-(Insurance.insuredValue - value) * 0.3))
    local paid = math.floor(Insurance.insuredValue * 0.3)

    local percentage = math.floor(Insurance.insuredValue / value * 1000) / 10.0
    shipValueLabel.caption = "¢${price}"%_t % {price = createMonetaryString(value)}
    insuranceValueLabel.caption = "¢${price}"%_t % {price = createMonetaryString(Insurance.insuredValue)}
    refundedValueLabel.caption = "¢${price}"%_t % {price = createMonetaryString(refundedValueIn)}
    priceLabel.caption = "¢${price}"%_t % {price = createMonetaryString(price)}
    paidLabel.caption = "¢${price}"%_t % {price = createMonetaryString(paid)}
    dueLabel.caption = "¢${price}"%_t % {price = createMonetaryString(due)}

    insuredPercentageLabel.caption = tostring(percentage) .. "%"
    paidPercentageLabel.caption = tostring(percentage) .. "%"

    -- calculate the color of the percentage number
    local green = vec3(0, 1, 0)
    local yellow = vec3(1, 1, 0)
    local red = vec3(1, 0, 0)

    local c = ColorRGB(1, 1, 1)
    if percentage <= 50 then
        c = lerp(percentage, 0, 50, red, yellow)
    elseif percentage > 50 then
        c = lerp(percentage, 50, 100, yellow, green)
    end

    if Insurance.insuredValue > value then
        c = yellow
    end

    insuredPercentageLabel.color = ColorRGB(c.x, c.y, c.z)
    paidPercentageLabel.color = ColorRGB(c.x, c.y, c.z)
    commentLabel.color = ColorRGB(c.x, c.y, c.z)

    periodicCheckBox.checked = periodicIn



    if percentage == 0 then
        commentLabel.caption = "Your ship is not insured!"%_t
    elseif percentage > 0  then
        commentLabel.caption = string.format("Insured for %s%% of ship value!"%_t, percentage)
    end

end
callable(Insurance, "refreshUI")

function Insurance.onPayButtonPressed()
    invokeServerFunction("insure")
end

function Insurance.onPeriodicPaymentsChecked(checkbox, value)
    if onClient() then
        invokeServerFunction("onPeriodicPaymentsChecked", nil, value)
    end

    if onServer() then
        if not checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations) then
            return
        end
    end

--    print ("periodic payments: %s", tostring(value))

    Insurance.periodic = value

end
callable(Insurance, "onPeriodicPaymentsChecked")

-- this function is meant to be called from outside to immediately insure an entity
-- called by shipyard for example
function Insurance.internalInsure()
    if callingPlayer then return end

    local value = Insurance.getShipValue()

    Insurance.insuredValue = value
    Insurance.refundedValue = value
end

function Insurance.insure()

    local value = Insurance.getShipValue()

    -- don't do anything if the insured value is bigger than the actual ship value
    if Insurance.insuredValue > value then return end

    local buyer, craft, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations)
    if not buyer then return end

    local due = math.max(0, math.floor(-(Insurance.insuredValue - value) * 0.3))

    local canPay, msg, args = buyer:canPay(due)
    if not canPay then
        Insurance.sendError(player, msg, unpack(args))
        return
    end

    buyer:pay("Paid %1% Credits for ship insurance."%_T, due)
    Insurance.insuredValue = value
    Insurance.refundedValue = value

    Insurance.refreshUI()
end
callable(Insurance, "insure")

function Insurance.insurePartial()

    local value = Insurance.getShipValue()

    -- don't do anything if the insured value is bigger than the actual ship value
    if Insurance.insuredValue > value then return end

    local due = math.max(0, math.floor(-(Insurance.insuredValue - value) * 0.3))
    if due == 0 then
        -- if nothing is due, adjust the insuredValue to the actual ship value, to reach the exact 100%
        if Insurance.insuredValue < value then
            Insurance.insuredValue = value
            Insurance.refundedValue = value

            Insurance.refreshUI()
        end
        return
    end

    local buyer = Faction()
    local toPay = math.floor(buyer.money * 0.1)

    toPay = math.min(due, toPay)

    buyer:pay("Paid %1% Credits for ship insurance."%_T, toPay)

    Insurance.insuredValue = math.floor(Insurance.insuredValue + toPay / 0.3)
    Insurance.refundedValue = Insurance.insuredValue

    if toPay > 0 and buyer.isPlayer then
        Insurance.sendInfo(Player(buyer.index), "You paid %1% Credits for %2%'s insurance."%_t, toPay, Entity().name)
    end

    Insurance.refreshUI()
end

-- determines the exact value of the ship counting both credit- and resourcevalues
function Insurance.getShipValue()
    local entity = Entity()

    local resourceValues = {entity:getUndamagedPlanResourceValue()};
    local sum = entity:getUndamagedPlanMoneyValue();

    for i, v in pairs(resourceValues) do
        sum = sum + Material(i - 1).costFactor * v * 10;
    end
    return math.floor(sum);
end

-- called whenever the blockplan is changed by building
function Insurance.onBuild(objectIndex, blockIndex)

    -- the maximum payment players get back is the worth of the ship or what they've already paid for
    -- this means that when blocks are removed, the returned value sinks, and players can't refund this money
    Insurance.refundedValue = math.min(Insurance.getShipValue(), Insurance.insuredValue)
end

-- called whenever the entity is reconstructed
function Insurance.onReconstructed(craftId, playerIndex)
    -- reset insurance on reconstruction since the loss payment will have been sent
    Insurance.insuredValue = 0
    Insurance.refundedValue = 0
end

-- if ship is destroyed this function is called
function Insurance.onDestroyed(index, lastDamageInflictor)
    if Insurance.refundedValue == 0 then return end

    local faction = Faction()
    if not faction then return end

    local ship = Entity()

    -- don't pay if the faction destroyed his ship by himself
    local damagers = {ship:getDamageContributors()}
    if #damagers == 1 and damagers[1] == faction.index then
        Insurance.sendInfo(faction, "Insurance fraud detected. You won't receive any payments for %s."%_t, ship.name)
        return
    end

    if faction.isPlayer then
        local player = Player(faction.index)

        local mail = Mail()
        mail.header = mailHeader
        mail.sender = mailSender

        local text
        if GameSettings().permaDestruction then
            mail.money = math.floor(Insurance.refundedValue * 0.3)

            text = [[Dear %1%,

We have received notice of the destruction of your craft '%2%'. Very unfortunate!
What is even more unfortunate, is that it appears as if there was an error in our transaction system.
We can only reimburse the amount of money you paid us, not the full sum for your ship.

The contract for your craft '%2%' is now fulfilled. We hope we can be of future service to you.

Best wishes,
Ship Insurance Intergalactical
]]%_t
        else
            mail.money = Insurance.refundedValue

            text = [[Dear %1%,

We have received notice of the destruction of your craft '%2%'. Very unfortunate!
As you are insured at our company you shall receive enclosed the sum insured with us as a loss payment.
The contract for your craft '%2%' is now fulfilled. We hope we can be of future service to you.

Best wishes,
Ship Insurance Intergalactical
]]%_t
        end

        mail.text = Format(text, player.name, ship.name)

        player:addMail(mail)
    else
        faction:receive(Format("Received insurance refund for %1%: %2% Credits."%_T, ship.name), Insurance.refundedValue)
    end
end

function Insurance.sendError(faction, msg, ...)
    if faction.isPlayer then
        local player = Player(faction.index)
        player:sendChatMessage("S.I.I."%_t, 1, msg, ...)
    end
end

function Insurance.sendInfo(faction, msg, ...)
    if faction.isPlayer then
        local player = Player(faction.index)
        player:sendChatMessage("S.I.I."%_t, 3, msg, ...)
    end
end

function Insurance.getUpdateInterval()
    local minutes = 5
    return minutes * 60
end

-- this function gets called each tick, on server only
function Insurance.updateServer(timeStep)
    if Insurance.periodic and Insurance.insuredValue < Insurance.getShipValue() then
        Insurance.insurePartial()
    end
end

---- this function gets called whenever the ui window gets rendered, AFTER the window was rendered (client only)
--function renderUI()
--
--end

function Insurance.getValues()
    if onClient() then return end

    return {
        insuredValue = Insurance.insuredValue,
        refundedValue = Insurance.refundedValue,
        periodic = Insurance.periodic
    }
end
