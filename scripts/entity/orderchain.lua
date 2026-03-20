package.path = package.path .. ";data/scripts/lib/?.lua"

local OrderTypes = include ("ordertypes")
include ("callable")
include ("faction")
include ("entity")
include ("stringutility")
include ("utility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace OrderChain
OrderChain = {}

OrderChain.chain = {}
OrderChain.activeOrder = 0

-- test if the active order is currently executed
OrderChain.running = false

-- used to clear after finishing a chain
-- not possible by checking activeOrder for zero since the orders don't activate immediately
OrderChain.finished = false

-- count of orders which can already be executed when enchaining commands
OrderChain.executableOrders = 0

function OrderChain.getUpdateInterval()
    return 1
end

function OrderChain.initialize()
    if onServer() then
        local entity = Entity()
        entity:registerCallback("onCraftSeatEntered", "onCraftSeatEntered")
        entity:registerCallback("onAIStateChanged", "onAIStateChanged")
        entity:registerCallback("onJumpRouteCalculationStarted", "onJumpRouteCalculationStarted")
        entity:registerCallback("onSectorEntered", "onSectorEntered")

        local sector = Sector()
        if sector then
            sector:registerCallback("onEntityJump", "onEntityJump")
        end
    end
end

function OrderChain.onCraftSeatEntered(entityId, seat, playerIndex, firstPlayer)
    local controller = ControlUnit()
    if firstPlayer == true and not controller.autoPilotEnabled then
        OrderChain.updateAutoPilotStatus()
    end
end

function OrderChain.onAIStateChanged(entityId, newState)
    local entity = Entity()
    if entityId ~= entity.id then return end

    -- only check if it's the last order, and it wasn't one of the special orders
    if OrderChain.activeOrder >= #OrderChain.chain and #OrderChain.chain > 0
        and (newState == AIState.Idle or newState == AIState.Passive)
        and OrderChain.getListenToAIStateChange() then

        -- don't listen to callbacks while cleaning up
        entity:unregisterCallback("onAIStateChanged", "onAIStateChanged")
        OrderChain.clearAllOrders()
        OrderChain.orderCompleted()
        entity:registerCallback("onAIStateChanged", "onAIStateChanged")
    end
end

function OrderChain.onJumpRouteCalculationStarted()
    -- only the pilot can end up here - cancel all existing orders so that his last is done
    OrderChain.clearAllOrders()
end

function OrderChain.onEntityJump(shipId, x, y, sectorChangeType)
    if sectorChangeType ~= SectorChangeType.Jump then return end
    if ShipAI():getFollowTarget() ~= shipId then return end

    -- the ship we are escorting just jumped away
    -- check if we can follow immediately
    local engine = HyperspaceEngine()
    if not engine then return end

    for _, error in pairs({engine:getJumpErrors(x, y)}) do
        if error == JumpError.Blocked then return end
        if error == JumpError.OutOfReach then return end
        if error == JumpError.HyperspaceCooldown then return end
        -- ignore JumpError.WrongDirection
    end

    if not Galaxy():areAllies(Faction().index, Entity(shipId).factionIndex) then return end

    engine:jump(x, y)
end

function OrderChain.onSectorEntered(shipId)
    local sector = Sector()
    sector:registerCallback("onEntityJump", "onEntityJump")
end

function OrderChain.getListenToAIStateChange()
    -- if active Order is one that uses script we don't want to listen to every AI state change
    for index, name in pairs(Entity():getScripts()) do
        if string.match(name, "data/scripts/entity/ai/") then
            return false
        end
    end

    return true
end

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function OrderChain.interactionPossible(playerIndex, option)
    -- check for permissions
    callingPlayer = Player().index
    if not checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FlyCrafts) then
        return false
    end

    -- drone can't activate auto pilot
    if Entity().type == EntityType.Drone then
        return false
    end

    -- check whether the interacted entity is flown by the player
    local player = Player()
    local playerPiloted = not player.craft or (Entity().index == player.craftIndex)
    if playerPiloted and option == 0 then
        OrderChain.refreshOnlyWithCaptainOrderButtons()
        return true
    elseif not playerPiloted and option == 1 then
        OrderChain.refreshOnlyWithCaptainOrderButtons()
        return true
    end
end

function OrderChain.getIcon()
    return "data/textures/icons/robot.png"
end

function OrderChain.getControlAction()
    return ControlAction.ScriptQuickAccess3
end

local onlyWithCaptainOrderButtons = {}
-- deactivates order buttons of orders that require a captain if necessary
function OrderChain.refreshOnlyWithCaptainOrderButtons()
    local active = false

    local entity = Entity()
    if entity and entity:getCaptain() then
        active = true
    end

    for _, button in pairs(onlyWithCaptainOrderButtons) do
        button.active = active
        if not active then
            button.tooltip = "Only available with a captain!"%_t
        else
            button.tooltip = nil
        end
    end
end

-- create all required UI elements for the client side
function OrderChain.initUI()
    OrderChain.makeAutoPilotWindow()
    OrderChain.makeCraftOrdersWindow()
end

function OrderChain.makeAutoPilotWindow()
    local window = OrderChain.makeWindow(300, 405, "Autopilot"%_t, "Autopilot"%_t)
    local rect = Rect(window.size)
    local splitter = UIArbitraryHorizontalSplitter(rect, 10, 10, 15 --[[line]], 55, 95, 110 --[[line]], 150, 190, 230, 280, 330, 345 --[[line]], 385)

    -- line with caption
    OrderChain.createBrokenLineWithCaption(window, splitter:partition(0), "Simple Orders"%_t)

    -- simple orders
    local button = window:createButton(splitter:partition(1), "Refine Ores"%_t, "onUserRefineOresOrder")
    button.textSize = 14

    local button = window:createButton(splitter:partition(2), "Guard This Position"%_t, "onUserGuardPositionOrder")
    button.textSize = 14

    -- line with caption
    OrderChain.createBrokenLineWithCaption(window, splitter:partition(3), "Advanced Orders"%_t)

    -- advanced orders
    local button = window:createButton(splitter:partition(4), "Mine Sector"%_t, "onUserMineOrder")
    button.textSize = 14
    table.insert(onlyWithCaptainOrderButtons, button)
    button = window:createButton(splitter:partition(5), "Salvage Sector"%_t, "onUserSalvageOrder")
    button.textSize = 14
    table.insert(onlyWithCaptainOrderButtons, button)
    button = window:createButton(splitter:partition(6), "Repair All"%_t, "onUserRepairOrder")
    button.textSize = 14
    table.insert(onlyWithCaptainOrderButtons, button)
    button = window:createButton(splitter:partition(7), "Attack All Enemies"%_t, "onUserAttackEnemiesOrder")
    button.textSize = 14
    table.insert(onlyWithCaptainOrderButtons, button)
    button = window:createButton(splitter:partition(8), "Patrol Sector"%_t, "onUserPatrolOrder")
    button.textSize = 14
    table.insert(onlyWithCaptainOrderButtons, button)

    -- line without caption
    local lineRect = splitter:partition(9)
    local middle = ((lineRect.upper.y - lineRect.lower.y) / 2)
    local lineFrom = vec2(lineRect.lower.x + 10, lineRect.lower.y + middle)
    local lineTo = vec2(lineRect.upper.x - 10, lineRect.upper.y - middle)
    window:createLine(lineFrom, lineTo)

    -- always active stop
    window:createButton(splitter:partition(10), "Stop"%_t, "onUserPassiveOrder")
end

function OrderChain.makeCraftOrdersWindow()
    local window = OrderChain.makeWindow(300, 470, "Craft Orders"%_t, "Orders"%_t)
    local rect = Rect(window.size)
    local splitter = UIArbitraryHorizontalSplitter(rect, 10, 10, 15 --[[line]], 55, 95, 135, 175, 190 --[[line]], 230, 275, 315, 355, 395, 410 --[[line]], 450)

    -- line with caption
    OrderChain.createBrokenLineWithCaption(window, splitter:partition(0), "Simple Orders"%_t)

    -- simple orders
    local button = window:createButton(splitter:partition(1), "Refine Ores"%_t, "onUserRefineOresOrder")
    button.textSize = 14

    local button = window:createButton(splitter:partition(2), "Escort Me"%_t, "onUserEscortOrder")
    button.textSize = 14

    local button = window:createButton(splitter:partition(3), "Repair Me"%_t, "onUserRepairEntityOrder")
    button.textSize = 14
    local button = window:createButton(splitter:partition(4), "Guard This Position"%_t, "onUserGuardPositionOrder")
    button.textSize = 14

    -- line with caption
    OrderChain.createBrokenLineWithCaption(window, splitter:partition(5), "Advanced Orders"%_t)

    -- advanced orders
    button = window:createButton(splitter:partition(6), "Mine Sector"%_t, "onUserMineOrder")
    button.textSize = 14
    table.insert(onlyWithCaptainOrderButtons, button)
    button = window:createButton(splitter:partition(7), "Salvage Sector"%_t, "onUserSalvageOrder")
    button.textSize = 14
    table.insert(onlyWithCaptainOrderButtons, button)
    button = window:createButton(splitter:partition(8), "Repair All"%_t, "onUserRepairOrder")
    button.textSize = 14
    table.insert(onlyWithCaptainOrderButtons, button)
    button = window:createButton(splitter:partition(9), "Attack All Enemies"%_t, "onUserAttackEnemiesOrder")
    button.textSize = 14
    table.insert(onlyWithCaptainOrderButtons, button)
    button = window:createButton(splitter:partition(10), "Patrol Sector"%_t, "onUserPatrolOrder")
    button.textSize = 14
    table.insert(onlyWithCaptainOrderButtons, button)

    -- line without caption
    local lineRect = splitter:partition(11)
    local middle = ((lineRect.upper.y - lineRect.lower.y) / 2)
    local lineFrom = vec2(lineRect.lower.x + 10, lineRect.lower.y + middle)
    local lineTo = vec2(lineRect.upper.x - 10, lineRect.upper.y - middle)
    local line = window:createLine(lineFrom, lineTo)
    line.color = ColorRGB(0.35, 0.35, 0.35)

    -- always active stop
    window:createButton(splitter:partition(12), "Stop"%_t, "onUserPassiveOrder")
end

function OrderChain.createBrokenLineWithCaption(window, rect, caption)
    local lineSplit = UIArbitraryVerticalSplitter(rect, 0, 0, 80, rect.upper.x - 90, rect.upper.x)

    local leftRect = lineSplit:partition(0)
    local middle = ((leftRect.upper.y - leftRect.lower.y) / 2)
    local lineFrom = vec2(leftRect.lower.x + 10, leftRect.lower.y + middle)
    local lineTo = vec2(leftRect.upper.x, leftRect.upper.y - middle)

    local line = window:createLine(lineFrom, lineTo)
    line.color = ColorRGB(0.35, 0.35, 0.35)

    local rightRect = lineSplit:partition(2)
    local middle = ((rightRect.upper.y - rightRect.lower.y) / 2)
    local lineFrom = vec2(rightRect.lower.x, rightRect.lower.y + middle)
    local lineTo = vec2(rightRect.upper.x - 20, rightRect.upper.y - middle)

    local line = window:createLine(lineFrom, lineTo)
    line.color = ColorRGB(0.35, 0.35, 0.35)

    local label = window:createLabel(rect, caption, 12)
    label:setCenterAligned()
    label.color = ColorRGB(0.8, 0.8, 0.8)
end

function OrderChain.makeWindow(sizeX, sizeY, caption, shortCaption)
    local size = vec2(sizeX, sizeY)
    local res = getResolution()
    local menu = ScriptUI()

    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    local shortCaption = shortCaption or "Orders"%_t
    menu:registerWindow(window, shortCaption, 2)

    window.caption = caption or "Craft Orders"%_t
    window.showCloseButton = 1
    window.moveable = 1

    return window
end

function OrderChain.secure()
    return {chain = OrderChain.chain, activeOrder = OrderChain.activeOrder, finished = OrderChain.finished}
end

function OrderChain.restore(data)
    OrderChain.chain = data.chain
    OrderChain.activeOrder = data.activeOrder
    OrderChain.finished = data.finished

    if not data.finished and data.activeOrder > 0 then
        OrderChain.running = true
        OrderChain.executableOrders = #OrderChain.chain
    end

    if not OrderChain.checkOrdersValid() then
        -- invalid order found: clear orders so that ship doesn't look busy
        -- due to compatibility for older versions it can happen that orders are no longer existing
        eprint("Error: Invalid order found. Terminating order chain!")
        OrderChain.clearAllOrders()
    end

    OrderChain.activateOrder()
end

function OrderChain.checkOrdersValid()
    for _, order in pairs(OrderChain.chain) do
        local orderTypeFound = false
        for _, index in pairs(OrderType) do
            if index == order.action then
                orderTypeFound = true
                break
            end
        end

        if not orderTypeFound then
            return false
        end
    end

    return true
end

function OrderChain.updateServer(timeStep)

    local entity = Entity()
    local hasPilot = entity:getPilotIndices()
    if hasPilot then
        ShipAI():setStatusMessage("[PLAYER] /* ship AI status*/"%_T, {})

        -- clean up potentially wrong or old orders after autopilot was stopped
        local controller = ControlUnit()
        if controller and not ControlUnit().autoPilotEnabled then
            -- check if we're not currently enchaining
            if #OrderChain.chain == 0 then
                OrderChain.clearAllOrders()
                return
            end
        end
    end

    if not OrderChain.running then
        -- setting this every tick is a safeguard against other potential issues
        -- setting the status is efficient enough to not send updates if nothing changed
        ShipAI():setStatusMessage("Idle /* ship AI status */"%_T, {})
        return
    end

    if OrderChain.activeOrder == 0 then return end

    local currentOrder = OrderChain.chain[OrderChain.activeOrder]
    local orderFinished = false

    if currentOrder.action == OrderType.Jump then
        if OrderChain.jumpOrderFinished(currentOrder.x, currentOrder.y) then
            orderFinished = true
        end
    elseif currentOrder.action == OrderType.Mine then
        if OrderChain.mineOrderFinished(currentOrder.persistent) then
            orderFinished = true
        end
    elseif currentOrder.action == OrderType.Salvage then
        if OrderChain.salvageOrderFinished(currentOrder.persistent) then
            orderFinished = true
        end
    elseif currentOrder.action == OrderType.Loop then
        orderFinished = true
    elseif currentOrder.action == OrderType.Aggressive then
        if OrderChain.aggressiveOrderFinished() then
            orderFinished = true
        end
--    elseif currentOrder.action == OrderType.Patrol then
--         cannot finish
--    elseif currentOrder.action == OrderType.Escort then
--         cannot finish
    elseif currentOrder.action == OrderType.AttackCraft then
        if OrderChain.attackCraftOrderFinished(currentOrder.targetId) then
            orderFinished = true
        end
    elseif currentOrder.action == OrderType.FlyThroughWormhole then
        if OrderChain.flyThroughWormholeOrderFinished(currentOrder.x, currentOrder.y) then
            orderFinished = true
        end
--    elseif currentOrder.action == OrderType.FlyToPosition then
--         cannot finish
--    elseif currentOrder.action == OrderType.GuardPosition then
--         cannot finish
    elseif currentOrder.action == OrderType.RefineOres then
        if OrderChain.refineOresOrderFinished(currentOrder.x, currentOrder.y) then
            orderFinished = true
        end
    elseif currentOrder.action == OrderType.Board then
        if OrderChain.boardingOrderFinished() then
            orderFinished = true
        end
    elseif currentOrder.action == OrderType.RepairTarget then
        if OrderChain.repairTargetOrderFinished(currentOrder.targetId) then
            orderFinished = true
        end
    elseif currentOrder.action == OrderType.Repair then
        if OrderChain.repairOrderFinished() then
            orderFinished = true
        end
    elseif currentOrder.action == OrderType.DockToStation then
        if OrderChain.dockOrderFinished() then
            orderFinished = true
        end
    end

    if orderFinished then
        if OrderChain.executableOrders > OrderChain.activeOrder then
            -- activate next order
            OrderChain.activeOrder = OrderChain.activeOrder + 1
            OrderChain.activateOrder()
        elseif #OrderChain.chain > OrderChain.activeOrder then
            -- set running back to false when no executable order is in the chain
            OrderChain.running = false
        else
            -- end of chain reached
            OrderChain.activeOrder = 0
            OrderChain.finished = true
            OrderChain.disableAutopilot()

            ShipAI():setStatusMessage("Idle /* ship AI status */"%_T, {})
        end

        OrderChain.updateShipOrderInfo()
    end
end

function OrderChain.canEnchain(order)

    local last = OrderChain.chain[#OrderChain.chain]
    if not last then return true end

    if last.action == OrderType.Loop then
        OrderChain.sendError("Can't enchain anything after a loop."%_T)
        return false
    elseif last.action == OrderType.Patrol then
        OrderChain.sendError("Can't enchain anything after a patrol order."%_T)
        return false
    elseif last.action == OrderType.Escort then
        OrderChain.sendError("Can't enchain anything after an escort order."%_T)
        return false
    elseif last.action == OrderType.FlyToPosition then
        OrderChain.sendError("Can't enchain anything after a fly order."%_T)
        return false
    elseif last.action == OrderType.GuardPosition then
        OrderChain.sendError("Can't enchain anything after a guard order."%_T)
        return false
    elseif last.action == OrderType.Mine and last.persistent then
        OrderChain.sendError("Can't enchain anything after a persistent mine order."%_T)
        return false
    elseif last.action == OrderType.Salvage and last.persistent then
        OrderChain.sendError("Can't enchain anything after a persistent salvage order."%_T)
        return false
    end

    return true
end

function OrderChain.sendError(msg, ...)
    if callingPlayer then
        local player = Player(callingPlayer)
        player:sendChatMessage("", ChatMessageType.Error, msg, ...)
    end
end

function OrderChain.enchain(order)
    -- we only clear the finished order chain when setting a new order
    -- to keep as much data around as we can
    if OrderChain.finished then
        OrderChain.clear()
    end

    table.insert(OrderChain.chain, order)
    OrderChain.updateChain()
end

function OrderChain.updateChain()

    -- activate the next order if none is currently running and one is available
    if not OrderChain.running and OrderChain.executableOrders > OrderChain.activeOrder then
        OrderChain.running = true
        OrderChain.activeOrder = OrderChain.activeOrder + 1
        OrderChain.activateOrder()
    end

    OrderChain.updateShipOrderInfo()
end

function OrderChain.undoOrder(x, y)
    if onClient() then
        invokeServerFunction("undoOrder", x, y)
        return
    end

    if callingPlayer then
        local owner, _, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips)
        if not owner then return end
    end

    local chain = OrderChain.chain
    local i = OrderChain.activeOrder

    local active = #chain > 0 and not OrderChain.finished

    if active and i < #chain then
        OrderChain.chain[#OrderChain.chain] = nil
        if OrderChain.executableOrders > #OrderChain.chain then
            OrderChain.executableOrders = OrderChain.executableOrders - 1
        end

        OrderChain.updateChain()
    elseif active and i == #chain and chain[#chain].action == OrderType.Jump then
        OrderChain.clearAllOrders()
    else
        OrderChain.sendError("Cannot undo last order."%_T)
    end

end
callable(OrderChain, "undoOrder")

function OrderChain.onUserPassiveOrder()
    if onClient() then
        invokeServerFunction("onUserPassiveOrder")
        ScriptUI():stopInteraction()
        return
    end

    OrderChain.disableAutopilot()
    ShipAI():setPassive()
end
callable(OrderChain, "onUserPassiveOrder")

function OrderChain.onUserGuardPositionOrder(position)
    if onClient() then
        -- button callback sends button instead of position
        if atype(position) == "Button" then position = nil end

        if not position then
            position = Entity().translationf
        end

        invokeServerFunction("onUserGuardPositionOrder", position)
        ScriptUI():stopInteraction()
        return
    end

    OrderChain.clearAllOrders()
    OrderChain.addGuardPositionOrder(position)
    OrderChain.runOrders()
end
callable(OrderChain, "onUserGuardPositionOrder")

function OrderChain.onUserEscortOrder(index)
    if onClient() then
        -- button callback sends button instead of index
        if atype(index) == "Button" then index = nil end

        invokeServerFunction("onUserEscortOrder", index)
        ScriptUI():stopInteraction()
        return
    end

    if index == nil and callingPlayer then
        local ship = Player(callingPlayer).craft
        if ship == nil then return end
        index = ship.index
    end

    OrderChain.clearAllOrders()
    OrderChain.addEscortOrder(index)
    OrderChain.runOrders()
end
callable(OrderChain, "onUserEscortOrder")

function OrderChain.onUserAttackEntityOrder(index)
    if onClient() then
        invokeServerFunction("onUserAttackEntityOrder", index);
        return
    end

    OrderChain.clearAllOrders()
    OrderChain.addAttackCraftOrder(index)
    OrderChain.runOrders()
end
callable(OrderChain, "onUserAttackEntityOrder")

function OrderChain.onUserRepairEntityOrder(index)
    if onClient() then
        -- button callback sends button instead of index
        if atype(index) == "Button" then index = nil end

        invokeServerFunction("onUserRepairEntityOrder", index);
        ScriptUI():stopInteraction()
        return
    end

    if index == nil and callingPlayer then
        local ship = Player(callingPlayer).craft
        if ship == nil then return end
        index = ship.index
    end

    OrderChain.clearAllOrders()
    OrderChain.addRepairTargetOrder(index)
    OrderChain.runOrders()
end
callable(OrderChain, "onUserRepairEntityOrder")

function OrderChain.onUserRepairOrder()
    if onClient() then
        invokeServerFunction("onUserRepairOrder");
        ScriptUI():stopInteraction()
        return
    end

    -- we have no target, so we need a captain for this order
    if not checkCaptain() then return end

    OrderChain.clearAllOrders()
    OrderChain.addRepairOrder()
    OrderChain.runOrders()
end
callable(OrderChain, "onUserRepairOrder")

function OrderChain.onUserFlyToPositionOrder(pos)
    if onClient() then
        invokeServerFunction("onUserFlyToPositionOrder", pos);
        return
    end

    OrderChain.clearAllOrders()
    OrderChain.addFlyToPositionOrder(pos)
    OrderChain.runOrders()
end
callable(OrderChain, "onUserFlyToPositionOrder")

function OrderChain.onUserFlyThroughWormholeOrder(index)
    if onClient() then
        invokeServerFunction("onUserFlyThroughWormholeOrder", index);
        return
    end

    OrderChain.clearAllOrders()
    OrderChain.addFlyThroughWormholeOrder(index)
    OrderChain.runOrders()
end
callable(OrderChain, "onUserFlyThroughWormholeOrder")


function OrderChain.onUserAttackEnemiesOrder()
    if onClient() then
        invokeServerFunction("onUserAttackEnemiesOrder")
        ScriptUI():stopInteraction()
        return
    end

    -- we have no target, so we need a captain for this order
    if not checkCaptain() then return end

    local attackCivilShips = true
    local canFinish = false

    OrderChain.clearAllOrders()
    OrderChain.addAggressiveOrder(attackCivilShips, canFinish)
    OrderChain.runOrders()
end
callable(OrderChain, "onUserAttackEnemiesOrder")

function OrderChain.onUserPatrolOrder()
    if onClient() then
        invokeServerFunction("onUserPatrolOrder")
        ScriptUI():stopInteraction()
        return
    end

    -- we have no target, so we need a captain for this order
    if not checkCaptain() then return end

    OrderChain.clearAllOrders()
    OrderChain.addPatrolOrder()
    OrderChain.runOrders()
end
callable(OrderChain, "onUserPatrolOrder")

function OrderChain.onUserMineOrder(index)
    if onClient() then
        -- button callback sends button instead of index
        if atype(index) == "Button" then index = nil end

        invokeServerFunction("onUserMineOrder", index)
        ScriptUI():stopInteraction()
        return
    end

    if not index then
        -- we have no target, so we need a captain for this order
        if not checkCaptain() then return end
    end

    OrderChain.clearAllOrders()
    OrderChain.addMineOrder(true, index)
    OrderChain.runOrders()
end
callable(OrderChain, "onUserMineOrder")

function OrderChain.onUserSalvageOrder(index)
    if onClient() then
        -- button callback sends button instead of index
        if atype(index) == "Button" then index = nil end

        invokeServerFunction("onUserSalvageOrder", index)
        ScriptUI():stopInteraction()
        return
    end

    if not index then
        -- we have no target, so we need a captain for this order
        if not checkCaptain() then return end
    end

    OrderChain.clearAllOrders()
    OrderChain.addSalvageOrder(true, index)
    OrderChain.runOrders()
end
callable(OrderChain, "onUserSalvageOrder")

function OrderChain.onUserBoardEntityOrder(index)
    if onClient() then
        invokeServerFunction("onUserBoardEntityOrder", index)
        ScriptUI():stopInteraction()
        return
    end

    OrderChain.clearAllOrders()
    OrderChain.addBoardCraftOrder(index)
    OrderChain.runOrders()
end
callable(OrderChain, "onUserBoardEntityOrder")

function OrderChain.onUserRefineOresOrder()
    if onClient() then
        invokeServerFunction("onUserRefineOresOrder")
        ScriptUI():stopInteraction()
        return
    end

    OrderChain.clearAllOrders()
    OrderChain.addRefineOresOrder()
    OrderChain.runOrders()
end
callable(OrderChain, "onUserRefineOresOrder")

function OrderChain.onUserDockToStationOrder(index)
    if onClient() then
        invokeServerFunction("onUserDockToStationOrder", index);
        return
    end

    OrderChain.clearAllOrders()
    OrderChain.addDockToStationOrder(index)
    OrderChain.runOrders()
end
callable(OrderChain, "onUserDockToStationOrder")

function OrderChain.removeSpecialOrders()
    local entity = Entity()

    -- scripts using DockAI need to reset it before we can remove them
    local entity = Entity()
    entity:invokeFunction("ai/docktostation.lua", "finalize", false)
    entity:invokeFunction("ai/refineores.lua", "finalize", false)

    for index, name in pairs(entity:getScripts()) do
        if string.match(name, "data/scripts/entity/ai/") then
            entity:removeScript(index)
        end
    end
end

function OrderChain.canReceivePlayerOrder()
    -- this function is irrelevant when there is no calling player
    if not callingPlayer then return true end

    -- craft may receive a player order when it has a captain
    local craft = Entity()
    if craft:getCaptain() then return true end

    -- craft may receive a player order when it's in the same sector as the player
    local sector = Sector()
    local x, y = sector:getCoordinates()

    local player = Player(callingPlayer)
    local px, py = player:getSectorCoordinates()

    return x == px and y == py
end

function OrderChain.addJumpOrder(x, y)
    if onClient() then
        invokeServerFunction("addJumpOrder", x, y)
        return
    end


    -- this command needs a captain or a player as it changes sector
    local entity = Entity()
    local pilots = {entity:getPilotIndices()}
    if #pilots == 0 and not checkCaptain() then return end

    if callingPlayer then
        local player = Player(callingPlayer)
        local owner = checkEntityInteractionPermissions(entity, AlliancePrivilege.ManageShips)
        if not owner then
            player:sendChatMessage("", ChatMessageType.Error, "You don't have permission to do that."%_T)
            return
        end

        if not OrderChain.canReceivePlayerOrder() then return end

    end

    -- if we have a long distance destination clear it, because we now jump per map jumps
    for _, pilotIndex in pairs(pilots) do
        local pilot = Player(pilotIndex)
        if pilot and pilot.isPlayer then
            pilot:resetHyperspaceCalculation()
        end
    end

    local shipX, shipY = Sector():getCoordinates()

    for _, action in pairs(OrderChain.chain) do
        if action.action == OrderType.Jump or action.action == OrderType.FlyThroughWormhole then
            shipX = action.x
            shipY = action.y
        end
    end

    -- prefer jumping over wormholes / gates
    local jumpValid, error = entity:isJumpRouteValid(shipX, shipY, x, y)
    if jumpValid then
        local order = {action = OrderType.Jump, x = x, y = y}

        if OrderChain.canEnchain(order) then
            OrderChain.enchain(order)
        end
        return
    end

    -- jump not possible, if a player enqueued this, they might want the ship to fly through a wormhole / gate
    if not callingPlayer then return end

    local player = Player(callingPlayer)
    local sectorViewsToCheck = {}

    local view = player:getKnownSector(shipX, shipY)
    if view then
        table.insert(sectorViewsToCheck, view)
    end

    local alliance = Alliance()
    if alliance then
        local view = alliance:getKnownSector(shipX, shipY)
        if view then
            table.insert(sectorViewsToCheck, view)
        end
    end

    for _, sectorView in pairs(sectorViewsToCheck) do
        local wormholeDestinations = {sectorView:getWormHoleDestinations()}
        for _, dest in pairs(wormholeDestinations) do
            if dest.x == x and dest.y == y then
                local order = {action = OrderType.FlyThroughWormhole, x = x, y = y, gate = false}
                if OrderChain.canEnchain(order) then
                    OrderChain.enchain(order)
                end
                return
            end
        end

        local gateDestinations = {sectorView:getGateDestinations()}
        for _, dest in pairs(gateDestinations) do
            if dest.x == x and dest.y == y then
                local order = {action = OrderType.FlyThroughWormhole, x = x, y = y, gate = true}
                if OrderChain.canEnchain(order) then
                    OrderChain.enchain(order)
                end
                return
            end
        end
    end

    player:sendChatMessage("", ChatMessageType.Error, error)
end
callable(OrderChain, "addJumpOrder")

function OrderChain.addMineOrder(persistent, targetId)
    if callingPlayer then
        local owner, _, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips)
        if not owner then return end

        if not OrderChain.canReceivePlayerOrder() then return end
    end

    local index
    if targetId then
        if atype(targetId) == "string" then
            index = targetId
        else
            index = targetId.string
        end
    end

    local order = {action = OrderType.Mine, persistent = persistent, targetId = index}

    if OrderChain.canEnchain(order) then
        OrderChain.enchain(order)
    end
end

function OrderChain.addSalvageOrder(persistent, targetId)
    if callingPlayer then
        local owner, _, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips)
        if not owner then return end

        if not OrderChain.canReceivePlayerOrder() then return end
    end

    local index
    if targetId then
        if atype(targetId) == "string" then
            index = targetId
        else
            index = targetId.string
        end
    end

    local order = {action = OrderType.Salvage, persistent = persistent, targetId = index}

    if OrderChain.canEnchain(order) then
        OrderChain.enchain(order)
    end
end

function OrderChain.addBoardCraftOrder(targetId)
    if checkBoardTarget() then
        if callingPlayer then
            local owner, _, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips)
            if not owner then return end

            if not OrderChain.canReceivePlayerOrder() then return end
        end

        local order = {action = OrderType.Board, targetId = targetId.string}

        if OrderChain.canEnchain(order) then
            OrderChain.enchain(order)
        end
    end
end

-- this is currently not being used, candidate for removal
function OrderChain.addLoop(a, b)
    if onClient() then
        invokeServerFunction("addLoop", a, b)
        return
    end

    if callingPlayer then
        local owner, _, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips)
        if not owner then return end

        if not OrderChain.canReceivePlayerOrder() then return end
    end

    local loopIndex
    if a and not b then
        -- interpret as action index
        loopIndex = a
    elseif a and b then
        -- interpret as coordinates
        local x, y = a, b
        local cx, cy = Sector():getCoordinates()
        local i = OrderChain.activeOrder
        local chain = OrderChain.chain

        if i == 0 then i = 1 end

        while i > 0 and i <= #chain do
            local current = chain[i]

            if cx == x and cy == y then
                loopIndex = i
                break
            end

            if current.action == OrderType.Jump then
                cx, cy = current.x, current.y
            end

            i = i + 1
        end

        if not loopIndex then
            OrderChain.sendError("Could not find any orders at %1%:%2%!"%_T, x, y)
        end
    end

    if not loopIndex or loopIndex == 0 or loopIndex > #OrderChain.chain then return end

    local order = {action = OrderType.Loop, loopIndex = loopIndex}

    if OrderChain.canEnchain(order) then
        OrderChain.enchain(order)
    end
end
callable(OrderChain, "addLoop")

function OrderChain.addAggressiveOrder(attackCivilShips, canFinish)
    if onClient() then
        invokeServerFunction("addAggressiveOrder", attackCivilShips, canFinish)
        return
    end

    if callingPlayer then
        local owner, _, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips)
        if not owner then return end

        if not OrderChain.canReceivePlayerOrder() then return end
    end

    -- station aggressive orders don't finish
    if Entity().type == EntityType.Station then canFinish = false end

    local order = {
        action = OrderType.Aggressive,
        attackCivilShips = attackCivilShips,
        canFinish = canFinish,
    }

    if OrderChain.canEnchain(order) then
        OrderChain.enchain(order)
    end
end
callable(OrderChain, "addAggressiveOrder")

function OrderChain.addPatrolOrder()
    if onClient() then
        invokeServerFunction("addPatrolOrder")
        return
    end

    if callingPlayer then
        local owner, _, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips)
        if not owner then return end

        if not OrderChain.canReceivePlayerOrder() then return end
    end

    local order = {action = OrderType.Patrol}

    if OrderChain.canEnchain(order) then
        OrderChain.enchain(order)
    end
end
callable(OrderChain, "addPatrolOrder")

function OrderChain.addEscortOrder(craftId, factionIndex, craftName)
    if callingPlayer then
        local owner, _, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips)
        if not owner then return end

        if not OrderChain.canReceivePlayerOrder() then return end
    end

    if not craftId then
        local sector = Sector()
        if not sector then return end

        local entity = sector:getEntityByFactionAndName(factionIndex, craftName)
        if not entity then return end

        craftId = entity.index
    end

    local entity = Entity(craftId)
    factionIndex = entity.factionIndex
    craftName = entity.name

    local order = {action = OrderType.Escort, craftId = craftId.string, factionIndex = factionIndex, craftName = craftName}

    if OrderChain.canEnchain(order) then
        OrderChain.enchain(order)
    end
end

function OrderChain.addAttackCraftOrder(targetId)
    if callingPlayer then
        local owner, _, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips)
        if not owner then return end

        if not OrderChain.canReceivePlayerOrder() then return end
    end

    local order = {action = OrderType.AttackCraft, targetId = targetId.string}

    if OrderChain.canEnchain(order) then
        OrderChain.enchain(order)
    end
end

function OrderChain.addRepairTargetOrder(targetId, factionIndex, craftName)
    if callingPlayer then
        local owner, _, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips)
        if not owner then return end

        if not OrderChain.canReceivePlayerOrder() then return end
    end

    if not targetId then
        local sector = Sector()
        if not sector then return end

        local entity = sector:getEntityByFactionAndName(factionIndex, craftName)
        if not entity then return end

        targetId = entity.index
    end

    local order = {action = OrderType.RepairTarget, targetId = targetId.string}

    if OrderChain.canEnchain(order) then
        OrderChain.enchain(order)
    end
end

function OrderChain.addDockToStationOrder(targetId)
    if callingPlayer then
        local owner, _, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips)
        if not owner then return end

        if not OrderChain.canReceivePlayerOrder() then return end
    end

    if not targetId then
        return
    end

    local order = {action = OrderType.DockToStation, targetId = targetId.string}

    if OrderChain.canEnchain(order) then
        OrderChain.enchain(order)
    end
end

function OrderChain.addRepairOrder()
    if onClient() then
        invokeServerFunction("addRepairOrder")
        return
    end

    if callingPlayer then
        local owner, _, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips)
        if not owner then return end

        if not OrderChain.canReceivePlayerOrder() then return end
    end

    local order = {action = OrderType.Repair}

    if OrderChain.canEnchain(order) then
        OrderChain.enchain(order)
    end
end
callable(OrderChain, "addRepairOrder")

function OrderChain.addFlyThroughWormholeOrder(targetId)
    if callingPlayer then
        local owner, _, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips)
        if not owner then return end

        if not OrderChain.canReceivePlayerOrder() then return end
    end

    local wormhole = WormHole(targetId)
    local position = Entity(targetId).translationf
    local x, y = wormhole:getTargetCoordinates();
    local order = {action = OrderType.FlyThroughWormhole, x = x, y = y, targetId = targetId.string, gate = true}

    if OrderChain.canEnchain(order) then
        OrderChain.enchain(order)
    end
end

function OrderChain.addFlyToPositionOrder(position)
    if callingPlayer then
        local owner, _, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips)
        if not owner then return end

        if not OrderChain.canReceivePlayerOrder() then return end
    end

    local order = {action = OrderType.FlyToPosition, px = position.x, py = position.y, pz = position.z}

    if OrderChain.canEnchain(order) then
        OrderChain.enchain(order)
    end
end

function OrderChain.addGuardPositionOrder(position)
    if callingPlayer then
        local owner, _, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips)
        if not owner then return end

        if not OrderChain.canReceivePlayerOrder() then return end
    end

    local order = {action = OrderType.GuardPosition, px = position.x, py = position.y, pz = position.z}

    if OrderChain.canEnchain(order) then
        OrderChain.enchain(order)
    end
end

function OrderChain.addRefineOresOrder()
    if callingPlayer then
        local owner, _, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips)
        if not owner then return end

        if not OrderChain.canReceivePlayerOrder() then return end
    end

    local order = {action = OrderType.RefineOres}

    if OrderChain.canEnchain(order) then
        OrderChain.enchain(order)
    end
end


function OrderChain.clearAllOrders()
    if onClient() then
        invokeServerFunction("clearAllOrders")
        return
    end

    if callingPlayer then
        local owner, _, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips)
        if not owner then return end
    end

    OrderChain.clear()
    OrderChain.removeSpecialOrders()
    OrderChain.updateChain()

    -- stop ship
    local controller = ControlUnit()
    if controller.autoPilotEnabled then
        controller.autoPilotEnabled = false
        controller:stopShip()
    end

    -- set ship to passive in case it has lingering AI orders
    local ai = ShipAI()
    if ai.state ~= AIState.Passive then
        ai:setPassive()
    end
end
callable(OrderChain, "clearAllOrders")

function OrderChain.runOrders()
    if onClient() then
        invokeServerFunction("runOrders")
        return
    end

    if callingPlayer then
        local owner, _, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips)
        if not owner then return end
    end

    OrderChain.executableOrders = #OrderChain.chain

    OrderChain.updateChain()
end
callable(OrderChain, "runOrders")

function OrderChain.disableAutopilot()
    if onClient() then
        invokeServerFunction("disableAutopilot")
        return
    end

    if callingPlayer then
        local owner, _, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FlyCrafts)
        if not owner then return end
    end

    local controller = ControlUnit()
    if controller then
        controller:stopShip()
    end

    OrderChain.clearAllOrders()
end
callable(OrderChain, "disableAutopilot")


function OrderChain.updateShipOrderInfo()
    local entity = Entity()

    local owner = Galaxy():findFaction(entity.factionIndex)
    if owner and (owner.isPlayer or owner.isAlliance) then
        owner:setShipOrderInfo(entity.name, OrderChain.getOrderInfo())
    end
end

function OrderChain.getOrderInfo()
    local x, y = Sector():getCoordinates()

    local info = {}
    info.chain = {}
    info.currentIndex = OrderChain.activeOrder
    info.coordinates = {x=x, y=y}
    info.finished = OrderChain.finished

    for _, action in pairs(OrderChain.chain) do
        local newEntry = {}
        for key, value in pairs(action) do
            newEntry[key] = value
        end

        local orderInfo = OrderTypes[action.action]
        if orderInfo then
            newEntry.name = orderInfo.name
            newEntry.icon = orderInfo.icon
            newEntry.pixelIcon = orderInfo.pixelIcon
        else
            newEntry.name = "Unknown"%_T
            newEntry.icon = ""
            newEntry.pixelIcon = ""
        end

        table.insert(info.chain, newEntry)
    end

    return info
end

function OrderChain.activateOrder()
    if OrderChain.activeOrder == 0 or not OrderChain.running then return end

    local order = OrderChain.chain[OrderChain.activeOrder]
    if order.action == OrderType.Jump then
        OrderChain.activateJump(order.x, order.y)
    elseif order.action == OrderType.Mine then
        OrderChain.activateMine(order.targetId)
    elseif order.action == OrderType.Salvage then
        OrderChain.activateSalvage(order.targetId)
    elseif order.action == OrderType.Loop then
        OrderChain.activateLoop(order.loopIndex)
    elseif order.action == OrderType.Aggressive then
        OrderChain.activateAggressive(order.attackCivilShips, order.canFinish)
    elseif order.action == OrderType.Patrol then
        OrderChain.activatePatrol()
    elseif order.action == OrderType.Escort then
        OrderChain.activateEscort(order.craftId, order.factionIndex, order.craftName)
    elseif order.action == OrderType.AttackCraft then
        OrderChain.activateAttackCraft(order.targetId)
    elseif order.action == OrderType.FlyThroughWormhole then
        local wormholes = {Sector():getEntitiesByComponent(ComponentType.WormHole)}
        for _, wormholeEntity in pairs(wormholes) do
            local wormhole = WormHole(wormholeEntity)
            local wormholeX, wormholeY = wormhole:getTargetCoordinates()
            if wormholeX == order.x and wormholeY == order.y then
                OrderChain.activateFlyThroughWormhole(wormholeEntity.index)
                break
            end
        end
    elseif order.action == OrderType.FlyToPosition then
        OrderChain.activateFlyToPosition(order.px, order.py, order.pz)
    elseif order.action == OrderType.GuardPosition then
        OrderChain.activateGuardPosition(order.px, order.py, order.pz)
    elseif order.action == OrderType.RefineOres then
        OrderChain.activateRefineOres()
    elseif order.action == OrderType.Board then
        OrderChain.activateBoarding(order.targetId)
    elseif order.action == OrderType.RepairTarget then
        OrderChain.activateRepairTarget(order.targetId)
    elseif order.action == OrderType.Repair then
        OrderChain.activateRepair()
    elseif order.action == OrderType.DockToStation then
        OrderChain.activateDockToStation(order.targetId)
    end
end

function OrderChain.activateJump(x, y)
    -- check if jump destination is still valid
    local currentX, currentY = Sector():getCoordinates()
    local valid, error = HyperspaceEngine():isJumpRouteValid(currentX, currentY, x, y);
    if not valid then
        local entity = Entity()
        local faction = Faction(entity.factionIndex)
        faction:sendChatMessage(entity.name, ChatMessageType.Error, "Jump not possible. Terminating orders in \\s(%1%:%2%)."%_T, currentX, currentY)
        OrderChain.clearAllOrders()
        return
    end

    -- everything ok - start execution
    OrderChain.updateAutoPilotStatus()

    local shipAI = ShipAI()
    shipAI:setStatusMessage("Jumping to ${x}:${y} /* ship AI status */"%_T, {x=x, y=y})
    shipAI:setJump(x, y)
end

function OrderChain.activateMine(targetId)
    OrderChain.updateAutoPilotStatus()

    if targetId then
        Entity():addScriptOnce("ai/mine.lua", targetId, true)
    else
        Entity():addScriptOnce("ai/mine.lua")
    end

    return true
end

function OrderChain.activateSalvage(targetId)
    OrderChain.updateAutoPilotStatus()

    if targetId then
        Entity():addScriptOnce("ai/salvage.lua", targetId, true)
    else
        Entity():addScriptOnce("ai/salvage.lua")
    end

    return true
end

function OrderChain.activateLoop(loopIndex)
    if OrderChain.activeOrder == loopIndex then
        -- prevent infinite loops
        return
    end

    OrderChain.activeOrder = loopIndex
    OrderChain.activateOrder()
end

function OrderChain.activateAggressive(attackCivilShips, canFinish)
    if checkArmed() then
        OrderChain.updateAutoPilotStatus()

        local shipAI = ShipAI()
        shipAI:setStatusMessage("Attacking Enemies /* ship AI status*/"%_T, {})
        shipAI:setAggressive(attackCivilShips, canFinish)
        return true
    end
end

function OrderChain.activatePatrol()
    if checkArmed() then
        OrderChain.updateAutoPilotStatus()

        Entity():addScriptOnce("ai/patrol.lua")
        return true
    end
end

function OrderChain.activateEscort(craftId, factionIndex, craftName)
    local target = Sector():getEntity(craftId)

    if target then
        OrderChain.updateAutoPilotStatus()

        local shipAI = ShipAI()
        shipAI:setStatusMessage("Escorting ${name} /* ship AI status*/"%_T, {name = target.name})
        shipAI:setEscort(target)
        return true
    else
        Entity():addScript("background/restoreescortorder.lua", craftId, factionIndex, craftName)
    end
end

function OrderChain.activateAttackCraft(targetId)
    local target = Sector():getEntity(targetId)

    if checkArmed() and target then
        OrderChain.updateAutoPilotStatus()

        local shipAI = ShipAI()
        shipAI:setStatusMessage("Attacking ${name} /* ship AI status*/"%_T, {name = target.name})
        shipAI:setAttack(target)
        return true
    end
end

function OrderChain.activateFlyThroughWormhole(targetId)
    local target = Sector():getEntity(targetId)
    if target then
        OrderChain.updateAutoPilotStatus()

        local ship = Entity()
        -- remove old flythrougate if there's one - ship should only ever have one active at any given moment
        -- next gate orders will be attached later
        if ship:hasScript("ai/flythroughgate.lua") then
            ship:removeScript("ai/flythroughgate.lua")
        end

        if target:hasComponent(ComponentType.Plan) then
            -- gate
            ship:addScriptOnce("ai/flythroughgate.lua", targetId)
        else
            -- wormhole
            local shipAI = ShipAI()
            shipAI:setStatusMessage("Flying Through Wormhole /* ship AI status*/"%_T, {})
            shipAI:setFly(target.translationf, 0)
        end

        return true
    end
end

function OrderChain.activateFlyToPosition(px, py, pz)
    local position = vec3(px, py, pz)
    OrderChain.updateAutoPilotStatus()

    local shipAI = ShipAI()
    shipAI:setStatusMessage("Flying to Position /* ship AI status*/"%_T, {})
    shipAI:setFly(position, 0)
    return true
end

function OrderChain.activateGuardPosition(px, py, pz)
    if checkArmed() then
        local position = vec3(px, py, pz)
        OrderChain.updateAutoPilotStatus()

        local shipAI = ShipAI()
        shipAI:setStatusMessage("Guarding Position /* ship AI status*/"%_T, {})
        shipAI:setGuard(position)
        return true
    end
end

function OrderChain.activateRefineOres()
    OrderChain.updateAutoPilotStatus()

    Entity():addScriptOnce("ai/refineores.lua")
    return true
end

function OrderChain.activateBoarding(targetId)
    local target = Sector():getEntity(targetId)

    if target then
        OrderChain.updateAutoPilotStatus()

        local shipAI = ShipAI()
        shipAI:setStatusMessage("Board ${name} /* ship AI status*/"%_T, {name = target.name})
        shipAI:setBoard(target)
        return true
    end
end

function OrderChain.activateRepairTarget(targetId)
    local target = Sector():getEntity(targetId)

    if checkHeal() and target then
        OrderChain.updateAutoPilotStatus()

        local shipAI = ShipAI()
        shipAI:setStatusMessage("Repairing ${name} /* ship AI status*/"%_T, {name = target.name})
        shipAI:setRepairTarget(target)
        return true
    end
end

function OrderChain.activateRepair()
    if checkHeal() then
        OrderChain.updateAutoPilotStatus()

        local shipAI = ShipAI()
        shipAI:setStatusMessage("Repairing /* ship AI status */"%_T, {})
        shipAI:setRepair()
    end
end

function OrderChain.activateDockToStation(targetId)
    OrderChain.updateAutoPilotStatus()

    Entity():addScriptOnce("ai/docktostation.lua", targetId, true)
    return true
end


function OrderChain.jumpOrderFinished(targetX, targetY)
    local x, y = Sector():getCoordinates()

    if x == targetX and y == targetY then
        return true
    end

    return false
end

function OrderChain.mineOrderFinished(persistent)
    local entity = Entity()
    if not entity:hasScript("data/scripts/entity/ai/mine.lua") then
        return true
    end

    if persistent then return false end

    local ret, result = entity:invokeFunction("data/scripts/entity/ai/mine.lua", "canContinueHarvesting")
    if ret == 0 and result == true then return false end

    entity:removeScript("data/scripts/entity/ai/mine.lua")
    return true
end

function OrderChain.salvageOrderFinished(persistent)
    local entity = Entity()
    if not entity:hasScript("data/scripts/entity/ai/salvage.lua") then
        return true
    end

    if persistent then return false end

    local ret, result = entity:invokeFunction("data/scripts/entity/ai/salvage.lua", "canContinueHarvesting")
    if ret == 0 and result == true then return false end

    entity:removeScript("data/scripts/entity/ai/salvage.lua")
    return true
end

function OrderChain.aggressiveOrderFinished()
    if ShipAI().state ~= AIState.Aggressive then
        ShipAI():setPassive()
        return true
    end

    return false
end

function OrderChain.attackCraftOrderFinished(targetId)
    return Sector():getEntity(targetId) == nil
end

function OrderChain.flyThroughWormholeOrderFinished(x, y)
    local currentX, currentY = Sector():getCoordinates()
    if currentX == x and currentY == y then return true end

    return false
end

function OrderChain.refineOresOrderFinished(x, y)
    return not Entity():hasScript("data/scripts/entity/ai/refineores.lua")
end

function OrderChain.boardingOrderFinished()
    if ShipAI().state ~= AIState.Boarding then
        ShipAI():setPassive()
        return true
    end

    return false
end

function OrderChain.repairTargetOrderFinished(targetId)
    if ShipAI().state ~= AIState.RepairTarget then
        ShipAI():setPassive()
        return true
    end

    return false
end

function OrderChain.repairOrderFinished()
    if ShipAI().state ~= AIState.Repair then
        ShipAI():setPassive()
        return true
    end

    return false
end

function OrderChain.dockOrderFinished()
    return not Entity():hasScript("data/scripts/entity/ai/docktostation.lua")
end

function OrderChain.hasMoreOrders()
    if OrderChain.activeOrder < OrderChain.executableOrders then
        return true
    end

    return false
end

function OrderChain.clear()
    OrderChain.chain = {}
    OrderChain.activeOrder = 0
    OrderChain.executableOrders = 0
    OrderChain.running = false
    OrderChain.finished = false
end

if onServer() then

function OrderChain.updateAutoPilotStatus()
    local controller = ControlUnit()
    if not controller then return end

    local pilot = Entity():getPilotIndices()
    if pilot and not controller.autoPilotEnabled and OrderChain.running then
        controller.autoPilotEnabled = true
    elseif not pilot or not OrderChain.running then
        controller.autoPilotEnabled = false
    end
end

function OrderChain.orderCompleted()
    OrderChain.running = false
    OrderChain.updateAutoPilotStatus()

    -- stop ship spinning after completing order
    ControlUnit():stopShip()

    OrderChain.sendOrderCompletedMessage()
end

function OrderChain.sendOrderCompletedMessage()
    local entity = Entity()
    if entity.hasPilot then
        return
    end

    -- tell player in sector about it
    local faction = Faction(entity.factionIndex)
    if faction then
        for _, player in pairs({Sector():getPlayers()}) do
            if player.index == entity.factionIndex
                or (player.allianceIndex and player.allianceIndex == entity.factionIndex) then
                faction:sendChatMessage(entity.name, ChatMessageType.Normal, "Order completed. Awaiting new orders."%_T)
            end
        end
    end
end

end
