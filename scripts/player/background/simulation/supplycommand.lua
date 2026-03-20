package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/player/background/simulation/?.lua"

local CommandType = include ("commandtype")
local SimulationUtility = include ("simulationutility")
local CaptainUtility = include ("captainutility")
local TradingUtility = include ("tradingutility")
include ("utility")
include ("stringutility")
include ("goods")


local SupplyCommand = {}
SupplyCommand.__index = SupplyCommand
SupplyCommand.type = CommandType.Supply

-- all commands need this kind of "new" to function within the bg simulation framework
-- it must be possible to call the command without any parameters to access some functionality
local function new(ship, area, config)
    local command = setmetatable({
        -- all commands need these variables to function within the bg simulation framework
        -- type contains the CommandType of the command, required to restore
        type = CommandType.Supply,

        -- the ship that has the command
        shipName = ship,

        -- the area where the ship is doing its thing
        area = area,

        -- config that was given to the ship
        config = config,

        -- holds any data necessary to fulfill the command, that should be saved to database, eg. timers and so on
        -- this should only contain variables that can be saved to database (eg. returned in a secure()) call
        -- this will be automatically restored/secured
        data = {},

        -- will be set from external, only listed here for completeness' sake
        simulation = nil,
    }, SupplyCommand)

    command.finishOnNextUpdate = false

    return command
end

-- all commands have the following functions, even if not listed here (added by Simulation script on command creation):
-- function SupplyCommand:addYield(message, money, resources, items) end
-- function SupplyCommand:finish() end
-- function SupplyCommand:registerForAttack(coords, faction, timeOfAttack, message, arguments) end



-- you can return an error message here such as:
-- return "Command cannot initialize because %1% and %2% went wrong", {"Player", "Config"}
function SupplyCommand:initialize()

    local parent = getParentFaction()
    local prediction = self:calculatePrediction(parent.index, self.shipName, self.area, self.config)

    self.data.flights = prediction.flights

end

-- executed when the command starts for the first time (not when being restored)
-- do things like paying money in here and return errors when it's not possible because the player doesn't have enough money
-- you can return an error message here such as:
-- return "Command cannot start because %1% doesn't fulfill requirement '%2%'!", {"Player", "Money"}
-- calculate and register the command for an attack if necessary here
function SupplyCommand:onStart()

    local parent = getParentFaction()
    local entry = ShipDatabaseEntry(parent.index, self.shipName)
    entry:setStatusMessage("Supplying Stations"%_T)

    local firstFlight = self.data.flights[1]
    self.data.currentFlight = {index = 1, time = 0}

end

function SupplyCommand:nextFlight()
    local nextIndex = self.data.currentFlight.index + 1
    if nextIndex > #self.data.flights then
        nextIndex = 1
    end

    self.data.currentFlight = {index = nextIndex, time = 0}
    local flight = self.data.flights[nextIndex]

    local entry = ShipDatabaseEntry(getParentFaction().index, self.shipName)
    local x, y = flight.coords.from.x, flight.coords.from.y
    entry:setCoordinates(x, y)
end

function SupplyCommand:setRuntimeError(msg, ...)
    eprint(msg, ...)

    getParentFaction():sendChatMessage("", ChatMessageType.Error, msg, ...)
    self.finishOnNextUpdate = true

end

function SupplyCommand:querySectors(flight)

    local fx, fy = flight.coords.from.x, flight.coords.from.y
    Galaxy():keepOrGetSector(fx, fy, 90) -- keep in memory for at least 90 seconds to ensure that it won't be unloaded until the next simulation tick

    local tx, ty = flight.coords.to.x, flight.coords.to.y
    Galaxy():keepOrGetSector(tx, ty, 90) -- keep in memory for at least 90 seconds to ensure that it won't be unloaded until the next simulation tick

    -- if both sectors are not yet loaded, we can't initiate the transaction
    if not Galaxy():sectorLoaded(fx, fy) or not Galaxy():sectorLoaded(tx, ty) then
        return
    end

    return {x = fx, y = fy}, {x = tx, y = ty}
end

function SupplyCommand:initiateTransaction()

    local flight = self.data.flights[self.data.currentFlight.index]

    -- first step: collect data about the stations
    -- -> how much of what good...
    --    1. is there on the origin station
    --    2. is missing on the destination station
    --    3. can be delivered in one go?

    local code = [[
    package.path = package.path .. ";data/scripts/lib/?.lua"
    include("utility")
    include("stringutility")

    function run(origin, flight, faction, shipName)
        local ship = ShipDatabaseEntry(faction, shipName)
        if not valid(ship) then return end -- silently fail here since the command will be canceled anyway

        local stationName = flight.to
        if origin then stationName = flight.from end

        local station = Sector():getEntityByFactionAndName(faction, stationName)
        if not valid(station) then
            -- station disappearing is a fatal error
            -- report back to the command that something went wrong
            local msg = "Commander, we encountered an issue while supplying: Station '%s' has disappeared!"%_T
            invokeFactionFunction(faction, true, "background/simulation/simulation.lua", "invokeCommandFunction", shipName, "transactionError", msg, stationName)
            return
        end

        local result = {}

        for _, transported in pairs(flight.goods) do
            local script = transported.toScript
            if origin then script = transported.fromScript end

            local callError, stock, maxStock = station:invokeFunction(script, "getStock", transported.name)

            if callError ~= 0 then
                -- station script not responding correctly is a fatal error
                -- report back to the command that something went wrong
                local msg = "Commander, we encountered an issue while supplying: Station %s can't trade the goods!"%_T
                eprint("%s: %s: 'getStock()' call error %s %s", stationName, script, transported.name, callError)
                invokeFactionFunction(faction, true, "background/simulation/simulation.lua", "invokeCommandFunction", shipName, "transactionError", msg, stationName)
                return
            end

            table.insert(result, {name = transported.name, stock = stock, maxStock = maxStock})
        end

        local callback = "reportMaximumAcceptable"
        if origin then callback = "reportMaximumAvailable" end

        -- report back to the command that things went well
        invokeFactionFunction(faction, true, "background/simulation/simulation.lua", "invokeCommandFunction", shipName, callback, flight, result)
    end
    ]]

    -- find the coordinates of the stations
    local origin, destination = self:querySectors(flight)
    if not origin or not destination then return end

    -- self.transaction bcs we don't want the transaction to be saved to database on purpose
    self.transaction = self.transaction or {}
    self.transaction.goods = {}

    for _, good in pairs(flight.goods) do
        self.transaction.goods[good.name] = good.amount
    end

    -- start probing the two stations for their available and accepted goods
    local owner = getParentFaction()

    runSectorCode(origin.x, origin.y, true, code, "run", true, flight, owner.index, self.shipName)
    runSectorCode(destination.x, destination.y, true, code, "run", false, flight, owner.index, self.shipName)

    -- return true to signal that we successfully initiated the transaction
    return true
end

function SupplyCommand:reportMaximumAvailable(flight, available)

    -- we only get stock and maxStock back, and have to find out how many are available at the destination station
    for _, good in pairs(available) do
        local amount = self.transaction.goods[good.name]
        if amount then
            amount = math.min(amount, good.stock)
            self.transaction.goods[good.name] = amount
        end
    end

    self.transaction.availableReceived = true
    self:tryExecutingTransaction(flight)
end

function SupplyCommand:reportMaximumAcceptable(flight, acceptable)

    -- we only get stock and maxStock back, and have to find out how many are acceptable by the destination station
    for _, good in pairs(acceptable) do
        local amount = self.transaction.goods[good.name]
        if amount then
            amount = math.min(amount, good.maxStock - good.stock)
            self.transaction.goods[good.name] = amount
        end
    end

    self.transaction.acceptableReceived = true
    self:tryExecutingTransaction(flight)
end

function SupplyCommand:tryExecutingTransaction(flight)

    -- only continue if acceptable and available wares were received
    if not self.transaction.acceptableReceived or not self.transaction.availableReceived then
        return
    end

    local hasGoodsToTransport = false
    for name, amount in pairs(self.transaction.goods) do
        if amount > 0 then
            hasGoodsToTransport = true
            break
        end
    end

    if not hasGoodsToTransport then
        self.transaction = nil
        return
    end


    local removeCode = [[
    package.path = package.path .. ";data/scripts/lib/?.lua"
    include("utility")
    include("stringutility")

    function run(flight, stationName, goods, faction, shipName)
        local ship = ShipDatabaseEntry(faction, shipName)
        if not valid(ship) then return end -- silently fail here since the command will be canceled anyway

        local station = Sector():getEntityByFactionAndName(faction, stationName)
        if not valid(station) then
            -- report back to the command that something went wrong
            local msg = "Commander, we encountered an issue while supplying: Station '%s' has disappeared!"%_T

            invokeFactionFunction(faction, true, "background/simulation/simulation.lua", "invokeCommandFunction", shipName, "transactionError", msg, stationName)
            return
        end

        local removed = {}
        local cargoBay = CargoBay(station)

        for name, amount in pairs(goods) do
            local before = cargoBay:getNumCargos(name)
            cargoBay:removeCargo(name, amount)

            local after = cargoBay:getNumCargos(name)
            removed[name] = before - after
        end

        invokeFactionFunction(faction, true, "background/simulation/simulation.lua", "invokeCommandFunction", shipName, "transactionGoodsRemoved", flight, removed)
    end
    ]]

    -- find the coordinates of the stations
    local origin, destination = self:querySectors(flight)
    if not origin or not destination then return end

    -- start probing the two stations for their available and accepted goods
    local owner = getParentFaction()

    runSectorCode(origin.x, origin.y, true, removeCode, "run", flight, flight.from, self.transaction.goods, owner.index, self.shipName)

    -- since we're doing a fire-and-forget transaction, we can delete the transaction now, the rest will sort itself out
    self.transaction = nil
end

-- this is called once the goods were removed from the origin station
-- so in this function we add the goods to the destination station
function SupplyCommand:transactionGoodsRemoved(flight, removed)

    local addCode = [[
    package.path = package.path .. ";data/scripts/lib/?.lua"
    include("goods")
    include("randomext")
    include("utility")
    include("stringutility")

    function run(flight, stationName, goodsToAdd, faction, shipName)
        local ship = ShipDatabaseEntry(faction, shipName)
        if not valid(ship) then return end -- silently fail here since the command will be canceled anyway

        local station = Sector():getEntityByFactionAndName(faction, stationName)
        if not valid(station) then
            -- report back to the command that something went wrong
            local msg = "Commander, we encountered an issue while supplying: Station '%s' has disappeared!"%_T

            invokeFactionFunction(faction, true, "background/simulation/simulation.lua", "invokeCommandFunction", shipName, "transactionError", msg, stationName)
            return
        end

        -- IMPORTANT: it's possible that goods are overdelivered, when multiple ships fly the same route
        -- since the "acceptable-amount" responses will be done and returned all at the same time
        -- so when a station only has room for 50 more, but there are 3 ships, each will try to haul 50
        -- to combat this, we check how many goods could actually be added and send the rest back home
        local notAdded = {}
        local cargoBay = CargoBay(station)

        for name, amount in pairs(goodsToAdd) do
            local good = goods[name]
            if not good then return end

            local before = cargoBay:getNumCargos(name)

            cargoBay:addCargo(good:good(), amount)

            local after = cargoBay:getNumCargos(name)
            local added = after - before
            local remaining = amount - added
            if remaining > 0 then
                notAdded[name] = remaining
            end
        end

        invokeFactionFunction(faction, true, "background/simulation/simulation.lua", "invokeCommandFunction", shipName, "transactionGoodsDelivered", flight, goodsToAdd, notAdded)


        -- spawn the ship into the sector as eye candy
        -- the ship will be deleted after a few seconds to restore the correct state
        local owner = Galaxy():findFaction(faction)

        -- find a position to put the craft
        local position = Matrix()
        local box = owner:getShipBoundingBox(shipName)

        -- try putting the ship at a dock
        local docks = DockingPositions(station)
        local dockIndex = docks:getFreeDock()
        if dockIndex then
            local dock = docks:getDockingPosition(dockIndex)
            local pos = vec3(dock.position.x, dock.position.y, dock.position.z)
            local dir = vec3(dock.direction.x, dock.direction.y, dock.direction.z)

            pos = station.position:transformCoord(pos)
            dir = station.position:transformNormal(dir)

            pos = pos + dir * (math.max(box.size.z, box.size.x) / 2 + 20)

            local up = station.position.up
            local right = normalize(cross(dir, up))

            position = MatrixLookUpPosition(right, up, pos)
        else
            -- if all docks are occupied, place it near the station
            -- use the same orientation as the station
            position = station.orientation

            local sphere = station:getBoundingSphere()
            position.translation = sphere.center + random():getDirection() * (sphere.radius + length(box.size) / 2 + 50);
        end

        owner:createCraftFromShipInfo(shipName, position)
    end
    ]]

    -- find the coordinates of the stations
    local origin, destination = self:querySectors(flight)
    if not origin or not destination then return end

    -- assign the goods to the receiving station
    local owner = getParentFaction()

    runSectorCode(destination.x, destination.y, true, addCode, "run", flight, flight.to, removed, owner.index, self.shipName)
end

function SupplyCommand:transactionGoodsDelivered(flight, goodsToAdd, notAdded)

    local deliveredAmount = 0
    local deliveredName = ""
    for name, amount in pairs(goodsToAdd) do
        deliveredAmount = deliveredAmount + amount - (notAdded[name] or 0)
        deliveredName = name
    end

    -- don't send a chat message when nothing could be delivered
    if deliveredAmount > 0 then
        -- determine what exactly was delivered
        local goodName = "goods"%_T

        if tablelength(goodsToAdd) == 1 then
            local good = goods[deliveredName]
            if good then
                goodName = good:good():pluralForm(deliveredAmount)
            end
        end

        local stationName = flight.to

        getParentFaction():sendChatMessage("", ChatMessageType.Economy, "'%1%' delivered %2% %3% to station '%4%'."%_T, self.shipName, deliveredAmount, goodName, stationName)
    end

    -- if some goods were overdelivered by too many ships flying the same route, return the ones that were overdelivered
    -- this can, in theory, go slightly wrong as well, because the originating station could have produced new goods in those 3 frames that we did the transaction in
    -- this is highly unlikely though. even if it happens, only a miniscule amount would get lost
    self:retourSuperfluousGoods(flight, notAdded)
end

function SupplyCommand:retourSuperfluousGoods(flight, notAdded)

    local addCode = [[
    package.path = package.path .. ";data/scripts/lib/?.lua"
    include("goods")
    include("randomext")
    include("utility")

    function run(flight, stationName, goodsToAdd, faction, shipName)
        local ship = ShipDatabaseEntry(faction, shipName)
        if not valid(ship) then return end -- silently fail here since the command will be canceled anyway

        local station = Sector():getEntityByFactionAndName(faction, stationName)
        if not valid(station) then
            -- report back to the command that something went wrong
            local msg = "Commander, we encountered an issue while supplying: Station '%s' has disappeared!"%_T

            invokeFactionFunction(faction, true, "background/simulation/simulation.lua", "invokeCommandFunction", shipName, "transactionError", msg, stationName)
            return
        end

        local cargoBay = CargoBay(station)

        for name, amount in pairs(goodsToAdd) do
            local good = goods[name]
            if not good then return end

            cargoBay:addCargo(good:good(), amount)
        end
    end
    ]]

    -- find the coordinates of the stations
    local origin, destination = self:querySectors(flight)
    if not origin or not destination then return end

    -- assign the goods to the originating station
    local owner = getParentFaction()

    runSectorCode(origin.x, origin.y, true, addCode, "run", flight, flight.from, notAdded, owner.index, self.shipName)

end

function SupplyCommand:transactionError(msg, ...)
    self:setRuntimeError(msg, ...)
end


-- this is the regularly called function to update the time passing while the command is running
-- timestep is typically a longer period, such as a minute
-- this function should be as lightweight as possible. best practice is to
-- only do count downs here and do all calculations during area analysis and initialization
function SupplyCommand:update(timeStep)
    if self.finishOnNextUpdate then
        self:finish()
        return
    end

    local current = self.data.currentFlight
    local flight = self.data.flights[current.index]

    -- simulate flight
    if flight.goods then
        -- if the flight has goods to transport, we have different behavior since we need to dock and fetch/deliver
        -- increase flight counter once the goods were fetched from the "from" station
        current.time = current.time + timeStep

        -- deliver the goods once arrived
        if current.time >= flight.minutes * 60 then
            if self:initiateTransaction() then
                self:nextFlight()
            end
        end

    else
        -- if flight doesn't have a route it's a simple goto
        current.time = current.time + timeStep

        if current.time >= flight.minutes * 60 then
            self:nextFlight()
        end
    end

end

-- executed before an area analysis involving this type of command starts
-- return a table of sectors here to start a special analysis of those sectors instead of a rect
-- this will be called on a temporary instance of the command. all values written to "self" will not persist
-- note: See GotoCommand for an extensive example
function SupplyCommand:getAreaAnalysisSectors(results, meta)

end

-- executed when an area analysis involving this type of command starts
-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function SupplyCommand:onAreaAnalysisStart(results, meta)

end

-- executed when an area analysis involving this type of command is checking a specific sector
-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function SupplyCommand:onAreaAnalysisSector(results, meta, x, y)
    -- commenting this out since it's too annoying
    -- print ("Supply: onAreaAnalysisSector")

end

-- executed when an area analysis involving this type of command finished
-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function SupplyCommand:onAreaAnalysisFinished(results, meta)

    local stations = {}

    local tradeScripts = TradingUtility.getTradeableScripts()
    local owner = Galaxy():findFaction(meta.factionIndex)

    for _, name in pairs({owner:getShipNames()}) do
        local entry = ShipDatabaseEntry(owner.index, name)

        if entry:getEntityType() == EntityType.Station then
            local scripts = entry:getScripts()

            local usableScripts = {}
            for i, script in pairs(scripts) do
                for _, tradeScript in pairs(tradeScripts) do
                    if string.ends(script, tradeScript) then
                        table.insert(usableScripts, i)
                    end
                end
            end

            if #usableScripts > 0 then
                local opportunities = {}

                local secured = entry:getSecuredScriptValues()

                for _, index in pairs(usableScripts) do
                    local script = scripts[index]
                    local values = secured[index]

                    local bought = {}
                    local sold = {}

                    local securedSold = values.soldGoods
                    if not securedSold and values.tradingData then
                        securedSold = values.tradingData.soldGoods
                    end

                    for _, good in pairs(securedSold or {}) do
                        table.insert(sold, good.name)
                    end

                    local securedBought = values.boughtGoods
                    if not securedBought and values.tradingData then
                        securedBought = values.tradingData.boughtGoods
                    end

                    for _, good in pairs(securedBought or {}) do
                        table.insert(bought, good.name)
                    end

                    table.insert(opportunities, {script = script, bought = bought, sold = sold})
                end

                table.insert(stations, {name = name, opportunities = opportunities})
            end
        end
    end

    results.stations = stations

end

-- executed when the ship is being recalled by the player
function SupplyCommand:onRecall()    

end

-- executed when the command is finished
function SupplyCommand:onFinish()
end

-- after this function was called, self.data will be read to be saved to database
function SupplyCommand:onSecure()

end

-- this is called after the command was recreated and self.data was assigned
function SupplyCommand:onRestore()

end

-- this is called when the beforehand calculated pirate or faction attack happens
-- called after notification of player and after attack script is added to the ship database entry
-- but before the ship and its escort is recalled from background
-- note: attackerFaction is nil in case of a pirate attack
function SupplyCommand:onAttacked(attackerFaction, x, y)

end

function SupplyCommand:getDescriptionText()
    return "Ship is supplying stations with goods."%_t
end

function SupplyCommand:getStatusMessage()
    return "Supplying stations /* ship AI status*/"%_T
end

-- returns the path to the icon that will be used in UI and on the galaxy map
function SupplyCommand:getIcon()
    return "data/textures/icons/supply-command.png"
end

-- returns the size of the area where the command is currently running
-- this is used to visualize where the command is running at the moment
function SupplyCommand:getAreaBounds()
    local lines = {}

    for _, flight in pairs(self.data.flights) do
        table.insert(lines, flight.coords)
    end

    return {lower = self.area.lower, upper = self.area.upper, lines = lines}
end

function SupplyCommand:getRecallError()
end

-- returns whether there are errors with the command, either in the config, or otherwise
-- (ship has no mining turrets, not enough energy, player doesn't have enough money, etc.)
-- this function is also executed on the client and used to grey out the "start" button so players know that their config is flawed
-- note: before this is called, there is already a preliminary check based on getConfigurableValues(),
-- where values are clamped or default-set
function SupplyCommand:getErrors(ownerIndex, shipName, area, config)

    local prediction = self:calculatePrediction(ownerIndex, shipName, area, config)

    if prediction.notEnoughCargoSpace then
        return "We don't have enough cargo space to do that properly!"%_t
    end

    if #config.routes > 0 and #prediction.flights == 0 then
        return "There are no supply routes that we could fly!"%_t
    end

    if #config.routes <= 0  then
        return "We need a route between two different sectors."%_t
    end

    -- check faction can pay needed money
    local faction = Galaxy():findFaction(ownerIndex)
    if faction.isAlliance and callingPlayer then
        if not faction:hasPrivilege(callingPlayer, AlliancePrivilege.ManageStations) then
            return "You don't have permission to manage alliance stations!"%_t
        end
    end

    -- if there are no errors, just return
    return
end

-- returns the size of the area where the command will run
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function SupplyCommand:getAreaSize(ownerIndex, shipName)
    return {x = 1, y = 1} -- doesn't really matter for this command
end

-- returns whether the command requires the ship to be inside the selected area
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function SupplyCommand:isShipRequiredInArea(ownerIndex, shipName)
    return false
end

-- returns whether the command has a fixed area. if yes, the area will be calculated with the ship in the middle
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function SupplyCommand:isAreaFixed(ownerIndex, shipName)
    return true
end

-- returns the text that is shown in the tooltip while the player is selecting the area for the command
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function SupplyCommand:getAreaSelectionTooltip(ownerIndex, shipName, area, valid)
    return ""
end

-- returns the configurable values for this command (if any).
-- variable naming should speak for itself, though you're free to do whatever you want in here.
-- config will only be used by the command itself and nothing else
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function SupplyCommand:getConfigurableValues(ownerIndex, shipName)
    local values = { }

    return values
end

-- returns the predictable values for this command (if any).
-- variable naming should speak for itself, though you're free to do whatever you want in here.
-- config will only be used by the command itself and nothing else
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function SupplyCommand:getPredictableValues()
    local values = { }

    values.attackChance = {displayName = SimulationUtility.AttackChanceLabelCaption}
    values.loopTime = {displayName = "Loop Time"%_t}

    return values
end

function SupplyCommand:adjustFlightTime(minutes, captain, slowdown)

    minutes = minutes * slowdown

    if captain:hasPerk(CaptainUtility.PerkType.Reckless) then
        minutes = minutes * (1 - lerp(captain.level, 0, 5, 0.05, 0.17))
    end

    if captain:hasPerk(CaptainUtility.PerkType.Navigator) then
        minutes = minutes * (1 - lerp(captain.level, 0, 5, 0.01, 0.12))
    end

    if captain:hasPerk(CaptainUtility.PerkType.Careful) then
        minutes = minutes * (1 + lerp(captain.level, 0, 5, 0.15, 0.03))
    end

    if captain:hasPerk(CaptainUtility.PerkType.Disoriented) then
        minutes = minutes * (1 + lerp(captain.level, 0, 5, 0.12, 0.01))
    end

    if captain:hasPerk(CaptainUtility.PerkType.Addict) then
        minutes = minutes * (1 + lerp(captain.level, 0, 5, 0.12, 0.01))
    end

    return math.ceil(minutes)
end

-- calculate the predictions for the ship, area and config
-- gut feeling says that each config option change should always be reflected in the predictions if it impacts the behavior
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function SupplyCommand:calculatePrediction(ownerIndex, shipName, area, config)
    local prediction = self:getPredictableValues()

    local flights = {}
    local ship = ShipDatabaseEntry(ownerIndex, shipName)
    local captain = ship:getCaptain()

    -- calculate slowdown by bad cargo on the ship
    local cargo = ship:getCargo()
    local stolenOrIllegal, dangerousOrSuspicious = SimulationUtility.getSpecialCargoCategories(cargo)

    local immuneToStolen = captain:hasClass(CaptainUtility.ClassType.Smuggler)
    local immuneToDangerous = captain:hasClass(CaptainUtility.ClassType.Smuggler) or captain:hasClass(CaptainUtility.ClassType.Merchant)

    local slowdown = 1
    if stolenOrIllegal and not immuneToStolen then slowdown = 1.15 end
    if dangerousOrSuspicious and not immuneToDangerous then slowdown = 1.15 end

    local cargoSpace = ship:getFreeCargoSpace()
    local range = ship:getHyperspaceProperties()
    prediction.freeCargoSpace = cargoSpace

    for i, route in pairs(config.routes) do
        if route.from == route.to then goto continue end
        if #route.transportable == 0 then goto continue end

        local seller = ShipDatabaseEntry(ownerIndex, route.from)
        local buyer = ShipDatabaseEntry(ownerIndex, route.to)

        local ox, oy = seller:getCoordinates()
        local dx, dy = buyer:getCoordinates()

        if ox == dx and oy == dy then goto continue end
        if self:blockedByRing(ship, seller) then goto continue end
        if self:blockedByRing(ship, buyer) then goto continue end

        local routeLength = distance(vec2(ox, oy), vec2(dx, dy)) * 1.3
        local jumps = math.ceil(routeLength / range)
        local timePerJump = 45
        local minutes = math.ceil(jumps * timePerJump / 60)
        minutes = self:adjustFlightTime(minutes, captain, slowdown)
        minutes = minutes + 4 -- assume 1 minute for docking & undocking each (must both dock & undock per station)

        -- calculate how much of each transportable good can be carried
        local transported = {}
        local available = cargoSpace / #route.transportable
        for _, transportable in pairs(route.transportable) do
            local good = goods[transportable.name]
            if good then
                local amount = math.floor(available / good.size)

                if amount > 0 then
                    table.insert(transported,
                        {
                            name = transportable.name,
                            amount = amount,
                            fromScript = transportable.fromScript,
                            toScript = transportable.toScript,
                        }
                    )
                else
                    prediction.notEnoughCargoSpace = true
                end
            end
        end

        if #transported == 0 then goto continue end

        table.insert(flights, {minutes = minutes, coords = {from = {x=ox, y=oy}, to = {x=dx, y=dy}}, from = route.from, to = route.to, goods = transported})

        -- calculate flight time to next route
        local next = i + 1
        if next > #config.routes then next = 1 end

        local nextRoute = config.routes[next]
        local nextSeller = ShipDatabaseEntry(ownerIndex, nextRoute.from)

        local ox, oy = dx, dy
        local dx, dy = nextSeller:getCoordinates()

        local routeLength = distance(vec2(ox, oy), vec2(dx, dy)) * 1.3
        local jumps = math.ceil(routeLength / range)
        local timePerJump = 45
        local minutes = math.ceil(jumps * timePerJump / 60)
        minutes = self:adjustFlightTime(minutes, captain, slowdown)

        table.insert(flights, {minutes = minutes, coords = {from = {x=ox, y=oy}, to = {x=dx, y=dy}}, from = route.to, to = nextRoute.from})

        ::continue::
    end

    prediction.flights = flights
    prediction.loopTime.value = 0

    for _, time in pairs(flights) do
        prediction.loopTime.value = prediction.loopTime.value + time.minutes
    end

    prediction.attackChance = 0

    return prediction
end

function SupplyCommand:generateAssessmentFromPrediction(prediction, captain, ownerIndex, shipName, area, config)

    local supplyLines = {}
    table.insert(supplyLines, "We'll supply those stations, no problem. This shouldn't be a hard thing to do."%_t)

    local underRadar = {}
    table.insert(underRadar, "While conducting the operation I have full autonomy and responsibility over the ship and will not be available for you."%_t)
    table.insert(underRadar, "While we are away, I am taking full command of the ship and you won't be able to reach me."%_t)
    table.insert(underRadar, "I guarantee the best performance possible, but for that I need the sole command over the ship. You won't be able to reach me until I have finished the command."%_t)

    -- cargo on board
    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local cargo = entry:getCargo()
    local stolenOrIllegal, dangerousOrSuspicious = SimulationUtility.getSpecialCargoCategories(cargo)
    local cargobayLines = SimulationUtility.getIllegalCargoAssessmentLines(stolenOrIllegal, dangerousOrSuspicious, captain)

    local returnLines = {}
    table.insert(returnLines, "We will carry out the command until something goes wrong or you call us back."%_t)
    table.insert(returnLines, "I will supply the stations until you call me back."%_t)

    local rnd = Random(Seed(captain.name))
    return {
        randomEntry(rnd, supplyLines),
        randomEntry(rnd, underRadar),
        randomEntry(rnd, cargobayLines),
        randomEntry(rnd, returnLines),
    }
end

-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function SupplyCommand:buildUI(startPressedCallback, changeAreaPressedCallback, recallPressedCallback, configChangedCallback)
    local ui = {}
    ui.orderName = "Supply Factories"%_t
    ui.icon = SupplyCommand:getIcon()
    ui.mapCommands = self.mapCommands

    local size = vec2(650, 600)

    ui.window = GalaxyMap():createWindow(Rect(size))
    ui.window.caption = "Supply Operation"%_t

    local settings = {areaHeight = 125, configHeight = 150, hideEscortUI = true}
    ui.commonUI = SimulationUtility.buildCommandUI(ui.window, startPressedCallback, changeAreaPressedCallback, recallPressedCallback, configChangedCallback, settings)

    -- configurable values
    local configValues = self:getConfigurableValues()
    local configRect = ui.commonUI.configRect

    local vlist = UIVerticalLister(configRect, 10, 0)

    ui.supplyLines = {}
    for i = 1, 5 do
        local rect = vlist:nextRect(20)
        local vmsplit = UIVerticalMultiSplitter(rect, 10, 0, 2)

        local fromCombo = ui.window:createValueComboBox(vmsplit.left, configChangedCallback)
        local toCombo = ui.window:createValueComboBox(vmsplit.right, configChangedCallback)

        local inner = vmsplit:partition(1)
        inner.size = inner.size + 10
        local splits = 4
        local vimsplit = UIVerticalMultiSplitter(inner, 5, 0, splits)
        vimsplit.marginLeft = 25
        vimsplit.marginRight = 25
        local icons = {}
        for j = 0, splits - 1 do
            local image = ui.window:createPicture(vimsplit:partition(j), "data/textures/icons/crate.png")
            image.isIcon = true
            image:hide()
            table.insert(icons, image)
        end

        local arrow = ui.window:createPicture(vimsplit:partition(splits), "data/textures/icons/arrow-right.png")
        arrow.isIcon = true

        table.insert(ui.supplyLines, {fromCombo = fromCombo, toCombo = toCombo, icons = icons, arrow = arrow})
    end

    -- yields & issues
    local predictable = self:getPredictableValues()

    local vlist = UIVerticalLister(ui.commonUI.predictionRect, 5, 0)
    vlist:nextRect(20)

    local vsplitYields = UIVerticalSplitter(vlist:nextRect(15), 5, 0, 0.65)

    local label = ui.window:createLabel(vsplitYields.left, predictable.attackChance.displayName .. ":", 12)
    label.tooltip = SimulationUtility.AttackChanceLabelTooltip
    ui.commonUI.attackChanceLabel = ui.window:createLabel(vsplitYields.right, "", 12)
    ui.commonUI.attackChanceLabel:setCenterAligned()

    local vsplitYields = UIVerticalSplitter(vlist:nextRect(15), 5, 0, 0.65)
    local label = ui.window:createLabel(vsplitYields.left, "Free Cargo Space:"%_t, 12)
    ui.cargoSpaceLabel = ui.window:createLabel(vsplitYields.right, "", 12)
    ui.cargoSpaceLabel:setCenterAligned()

    local vsplitYields = UIVerticalSplitter(vlist:nextRect(15), 5, 0, 0.65)
    local label = ui.window:createLabel(vsplitYields.left, "Runtime:"%_t, 12)
    local label = ui.window:createLabel(vsplitYields.right, "Indefinite"%_t, 12)
    label:setCenterAligned()

    local vsplitYields = UIVerticalSplitter(vlist:nextRect(15), 5, 0, 0.65)
    local label = ui.window:createLabel(vsplitYields.left, predictable.loopTime.displayName .. ":", 12)
    ui.loopTimeLabel = ui.window:createLabel(vsplitYields.right, "", 12)
    ui.loopTimeLabel:setCenterAligned()

    ui.loopTimeTooltipDisplayer = ui.window:createTooltipDisplayer(vsplitYields.right)

    ui.clear = function(self, shipName)
        self.commonUI:clear(shipName)

        for i = 1, 5 do
            self.supplyLines[i].toCombo:clear()
            self.supplyLines[i].fromCombo:clear()
        end

        for i = 2, 5 do
            self.supplyLines[i].toCombo:hide()
            self.supplyLines[i].fromCombo:hide()
            self.supplyLines[i].arrow:hide()

            for _, icon in pairs(self.supplyLines[i].icons) do
                icon:hide()
            end
        end
    end

    -- used to fill values into the UI
    -- config == nil means fill with default values
    ui.refresh = function(self, ownerIndex, shipName, area, config)
        self.commonUI:refresh(ownerIndex, shipName, area, config)

        if not config then
            -- no config: fill UI with default values, then build config, then use it to calculate yields
            local values = SupplyCommand:getConfigurableValues(ownerIndex, shipName)

            config = self:buildConfig()
        end

        self:refreshPredictions(ownerIndex, shipName, area, config)
    end

    -- gut feeling says that each config option change should always be reflected in the predictions if it impacts the behavior
    ui.refreshPredictions = function(self, ownerIndex, shipName, area, config)

        SupplyCommand:refreshComboBoxes(self, ownerIndex, shipName, area, config)

        local prediction = SupplyCommand:calculatePrediction(ownerIndex, shipName, area, config)
        self:displayPrediction(prediction, config, ownerIndex)

        self.commonUI:refreshPredictions(ownerIndex, shipName, area, config, SupplyCommand, prediction)

        if #config.routes == 0 then
            self.commonUI.startButton.active = false
        end

        if MapRoutes then
            local lines = {}
            for _, flight in pairs(prediction.flights) do
                table.insert(lines, flight.coords)
            end

            MapRoutes.setCustomRoute(ownerIndex, shipName, lines)
            self.lastRouteData = {ownerIndex = ownerIndex, shipName = shipName}
        end
    end

    ui.displayPrediction = function(self, prediction, config, ownerIndex)
        self.cargoSpaceLabel.caption = math.floor(prediction.freeCargoSpace)
        self.loopTimeLabel.caption = "${minutes} min"%_t % {minutes = prediction.loopTime.value}

        local loopTimeTooltip = nil
        if #prediction.flights > 0 then
            loopTimeTooltip = Tooltip()
            loopTimeTooltip.rarity = Rarity(RarityType.Petty)

            for i, flight in pairs(prediction.flights) do
                if flight.minutes == 0 then goto continue end

                local from = ShipDatabaseEntry(ownerIndex, flight.from)
                local to = ShipDatabaseEntry(ownerIndex, flight.to)

                local fromStr = from.name
                local title = from:getTitle():translated()
                if title ~= "" then fromStr = "${title} ${name}"%_t % {title = title, name = fromStr} end

                local toStr = to.name
                local title = to:getTitle():translated()
                if title ~= "" then toStr = "${title} ${name}"%_t % {title = title, name = toStr} end

                local line = TooltipLine(16, 13)
                line.fontType = FontType.Normal
                line.ltext = fromStr
                line.ctext = "->"
                line.ccolor = ColorRGB(0.8, 0.8, 0.8)
                line.rtext = toStr
                if not flight.goods then
                    line.lcolor = ColorRGB(0.5, 0.5, 0.5)
                    line.rcolor = ColorRGB(0.5, 0.5, 0.5)
                    line.backgroundColor = ColorRGB(0.5, 0.5, 0.5)
                    line.icon = "data/textures/icons/nothing.png"
                else
                    line.icon = "data/textures/icons/crate.png"
                    line.iconColor = ColorRGB(0.9, 0.9, 0.9)
                end
                loopTimeTooltip:addLine(line)


                local line = TooltipLine(14, 11)
                line.fontType = FontType.Normal
                line.ctext = "${minutes} min"%_t % flight
                line.ccolor = ColorRGB(0.5, 0.5, 0.5)
                line.icon = "data/textures/icons/nothing.png"
                loopTimeTooltip:addLine(line)

                ::continue::
            end
        end

        ui.loopTimeTooltipDisplayer:setTooltip(loopTimeTooltip)

        local i = 1
        for _, flight in pairs(prediction.flights) do
            if not flight.goods then goto continue end

            for j = 1, math.min(#flight.goods, #ui.supplyLines[i].icons) do
                local icon = ui.supplyLines[i].icons[j]
                local transportable = flight.goods[j]

                if icon and transportable then
                    local good = goods[transportable.name]

                    if good then
                        icon:show()
                        icon.picture = good.icon
                        icon.tooltip = "${amount} ${name} /* resolves to '41 Energy Cells' or '1 Mining Robot', plural form is already taken care of here */"%_t % {amount = transportable.amount, name = good:good():displayName(transportable.amount)}
                    end
                end
            end

            ui.supplyLines[i].arrow:show()

            i = i + 1

            ::continue::
        end

        self.commonUI:setAttackChance(prediction.attackChance)
    end

    -- used to build a config table for the command, based on values configured in the UI
    -- gut feeling says that each config option change should always be reflected in the predictions if it impacts the behavior
    ui.buildConfig = function(self)
        local config = {}

        config.escorts = self.commonUI.escortUI:buildConfig()

        config.routes = {}
        for i = 1, 5 do
            local from = ui.supplyLines[i].fromCombo.selectedValue
            local to = ui.supplyLines[i].toCombo.selectedValue
            local transportable = ui.supplyLines[i].transportable

            if ui.supplyLines[i].fromCombo.visible and ui.supplyLines[i].toCombo.visible then
                if from and to and transportable then
                    config.routes[i] = {from = from, to = to, transportable = transportable}
                end
            end
        end

        return config
    end

    -- optional; called whenever the command window was closed while the map is still visible
    ui.onWindowClosed = function(self)
        if MapRoutes and self.lastRouteData then
            MapRoutes.clearRoute(self.lastRouteData.ownerIndex, self.lastRouteData.shipName)
        end
    end

    ui.setActive = function(self, active, description)
        self.commonUI:setActive(active, description)

        for i = 1, 5 do
            ui.supplyLines[i].fromCombo.active = active
            ui.supplyLines[i].toCombo.active = active
        end
    end

    ui.displayConfig = function(self, config, ownerIndex)
        for i = 1, 5 do
            ui.supplyLines[i].fromCombo.visible = false
            ui.supplyLines[i].fromCombo:clear()
            ui.supplyLines[i].toCombo.visible = false
            ui.supplyLines[i].toCombo:clear()
            ui.supplyLines[i].arrow.visible = false

            for _, icon in pairs(ui.supplyLines[i].icons) do
                icon.visible = false
            end
        end

        for i, route in pairs(config.routes) do
            local fromEntry = ShipDatabaseEntry(ownerIndex, route.from)
            local toEntry = ShipDatabaseEntry(ownerIndex, route.to)

            if not fromEntry or not toEntry then goto continue end

            local fromStr = route.from
            local title = fromEntry:getTitle():translated()
            if title ~= "" then fromStr = "${title} - ${name}"%_t % {title = title, name = route.from} end

            ui.supplyLines[i].fromCombo.visible = true
            ui.supplyLines[i].fromCombo:addEntry(route.from, fromStr)

            local toStr = route.to
            local title = toEntry:getTitle():translated()
            if title ~= "" then toStr = "${title} - ${name}"%_t % {title = title, name = route.to} end

            ui.supplyLines[i].toCombo.visible = true
            ui.supplyLines[i].toCombo:addEntry(route.to, toStr)

            ::continue::
        end
    end

    return ui
end

function SupplyCommand:detectDeliverableStations(ownerIndex, from, analysis)

    local fromStation = ShipDatabaseEntry(ownerIndex, from.name)
    if not valid(fromStation) then return {} end

    local fx, fy = fromStation:getCoordinates()

    local deliverableStations = {}
    for _, station in pairs(analysis.stations) do
        if station.name == from.name then goto continue end

        local toStation = ShipDatabaseEntry(ownerIndex, station.name)
        if not valid(toStation) then goto continue end

        local tx, ty = toStation:getCoordinates()
        if fx == tx and fy == ty then goto continue end

        -- check if the station buys anything that the other one sells
        local transportable = {}

        -- all goods of all scripts in "from" ...
        for _, fromOpportunity in pairs(from.opportunities) do
            for _, good in pairs(fromOpportunity.sold) do

                -- .. should be checked against all goods of all scripts in "to"
                for _, toOpportunity in pairs(station.opportunities) do
                    for _, bought in pairs(toOpportunity.bought) do

                        -- when there's a match a good is transportable from "from" to "station"
                        if good == bought then
                            table.insert(transportable, {name = good, fromScript = fromOpportunity.script, toScript = toOpportunity.script})
                        end
                    end
                end
            end
        end

        if #transportable > 0 then
            table.insert(deliverableStations, {station = station, transportable = transportable})
        end

        ::continue::
    end

    return deliverableStations
end

function SupplyCommand:blockedByRing(ship, station)
    local reach, canPassRifts, cooldown = ship:getHyperspaceProperties()

    if canPassRifts then return false end

    local shipInRing = Balancing_InsideRing(ship:getCoordinates())
    local stationInRing = Balancing_InsideRing(station:getCoordinates())

    return shipInRing ~= stationInRing
end

function SupplyCommand:refreshComboBoxes(ui, ownerIndex, shipName, area, config)

    local ship = ShipDatabaseEntry(ownerIndex, shipName)
    local x, y = ship:getCoordinates()

    for i = 1, 5 do
        ui.supplyLines[i].transportable = nil
    end

    for i = 1, 5 do
        -- remember scroll positions
        local scrollPositionFrom = ui.supplyLines[i].fromCombo.scrollPosition
        local scrollPositionTo = ui.supplyLines[i].toCombo.scrollPosition

        -- reset the line
        ui.supplyLines[i].fromCombo:show()
        ui.supplyLines[i].toCombo:show()

        ui.supplyLines[i].arrow:hide()
        for _, icon in pairs(ui.supplyLines[i].icons) do
            icon:hide()
        end

        -- fill the left combo box with all nearby stations
        local valueFrom = ui.supplyLines[i].fromCombo.selectedValue
        ui.supplyLines[i].fromCombo:clear()

        if i > 1 then
            ui.supplyLines[i].fromCombo:addEntry(nil, "")
        end

        local unusable = {}
        local usable = {}
        for _, station in pairs(area.analysis.stations) do
            local hasSoldGoods = false

            for _, opportunity in pairs(station.opportunities) do
                if opportunity.sold and #opportunity.sold > 0 then
                    hasSoldGoods = true
                end
            end

            if hasSoldGoods then
                local stationEntry = ShipDatabaseEntry(ownerIndex, station.name)

                if not self:blockedByRing(ship, stationEntry) then
                    table.insert(usable, {station = station.name, text = stationEntry:getTitle():translated() .. " - " .. station.name})
                else
                    table.insert(unusable, stationEntry:getTitle():translated() .. " - " .. station.name)
                end
            end
        end

        table.sort(usable, function(a, b) return a.text < b.text end)
        table.sort(unusable, function(a, b) return a < b end)

        for _, p in pairs(usable) do
            ui.supplyLines[i].fromCombo:addEntry(p.station, p.text)
        end

        for _, str in pairs(unusable) do
            ui.supplyLines[i].fromCombo:addEntry(nil, str, ColorRGB(0.3, 0.3, 0.3))
        end

        if scrollPositionFrom ~= 0 then
            ui.supplyLines[i].fromCombo.scrollPosition = scrollPositionFrom
        end

        if valueFrom then
            ui.supplyLines[i].fromCombo:setSelectedValueNoCallback(valueFrom)
        end

        local seller = nil
        for _, station in pairs(area.analysis.stations) do
            if station.name == valueFrom then
                seller = station
            end
        end

        -- find out where the goods can be delivered to
        local valueTo = ui.supplyLines[i].toCombo.selectedValue
        ui.supplyLines[i].toCombo:clear()

        local receivers = nil
        if seller then
            receivers = SupplyCommand:detectDeliverableStations(ownerIndex, seller, area.analysis)

            local usable = {}
            local unusable = {}
            for _, receiver in pairs (receivers) do
                local station = receiver.station
                local stationEntry = ShipDatabaseEntry(ownerIndex, station.name)

                if not self:blockedByRing(ship, stationEntry) then
                    table.insert(usable, {station = station.name, text = stationEntry:getTitle():translated() .. " - " .. station.name})
                else
                    table.insert(unusable, stationEntry:getTitle():translated() .. " - " .. station.name)
                end
            end

            table.sort(usable, function(a, b) return a.text < b.text end)
            table.sort(unusable, function(a, b) return a < b end)
            for _, p in pairs(usable) do
                ui.supplyLines[i].toCombo:addEntry(p.station, p.text)
            end

            for _, str in pairs(unusable) do
                ui.supplyLines[i].toCombo:addEntry(nil, str, ColorRGB(0.3, 0.3, 0.3))
            end
        end

        if scrollPositionTo ~= 0 then
            ui.supplyLines[i].toCombo.scrollPosition = scrollPositionTo
        end

        if valueTo then
            ui.supplyLines[i].toCombo:setSelectedValueNoCallback(valueTo)
        end

        if seller and receivers and ui.supplyLines[i].toCombo.selectedValue then
            local selected = ui.supplyLines[i].toCombo.selectedValue

            for _, receiver in pairs(receivers) do
                if selected == receiver.station.name then
                    ui.supplyLines[i].transportable = receiver.transportable
                end
            end
        end

        if not ui.supplyLines[i].fromCombo.selectedValue or not ui.supplyLines[i].toCombo.selectedValue then
            break
        end
    end

    local updatedConfig = ui:buildConfig()
    config.routes = updatedConfig.routes

end



return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
