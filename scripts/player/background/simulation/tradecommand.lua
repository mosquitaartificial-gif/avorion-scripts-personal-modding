package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/player/background/simulation/?.lua"

local CommandType = include ("commandtype")
local FactoryMap = include ("factorymap")
local SimulationUtility = include ("simulationutility")
local CaptainUtility = include("captainutility")
local GatesMap = include ("gatesmap")
local SectorSpecifics = include("sectorspecifics")
include ("utility")
include ("stringutility")
include ("goods")


local TradeCommand = {}
TradeCommand.__index = TradeCommand
TradeCommand.type = CommandType.Trade

-- all commands need this kind of "new" to function within the bg simulation framework
local function new(ship, area, config)
    local command = setmetatable({
        -- all commands need these variables to function within the bg simulation framework
        -- type contains the CommandType of the command, required to restore
        type = CommandType.Trade,

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
    }, TradeCommand)

    command.data.runTime = 0
    command.data.flights = 0

    return command
end

-- all commands have the following functions, even if not listed here (added by Simulation script on command creation):
-- function TradeCommand:addYield(message, money, resources, items) end
-- function TradeCommand:finish() end
-- function TradeCommand:registerForAttack(coords, faction, timeOfAttack, message, arguments) end


function TradeCommand:initialize()
    local parent = getParentFaction()
    local prediction = self:calculatePrediction(parent.index, self.shipName, self.area, self.config)
    self.data.prediction = prediction
    self.data.moneyEarned = 0

    if prediction.error then
        return prediction.error, prediction.args or {}
    end

end

-- executed when the command starts for the first time (not when being restored)
function TradeCommand:onStart()
    local deposit = self.config.deposit or 0
    if deposit <= 0 then return "Error starting command."%_T end

    if self.data.prediction.transportedPerFlight <= 0 then
        return "We don't have enough cargo space to do that properly."%_T
    end

    local owner = getParentFaction()
    local canPay, error, args = owner:canPay(deposit)
    if not canPay then
        return error, args
    end

    -- the captain gets the deposit
    owner:pay(Format("Gave the captain of '%1%' a budget of %2% credits to fly a trade route."%_T, (self.shipName or "")), deposit)

    if self.data.prediction.attackLocation then
        if self.simulation.disableAttack then return end -- for unit tests

        local time = 0
        if self.data.prediction.flights.to > 1 then
            -- more than 1 flight: will be attacked some time in first or second flight
            time = random():getFloat(0.1, 0.85) * self.data.prediction.flightTime.value * 2
        else
            -- will be attacked some time in first (only) flight
            time = random():getFloat(0.1, 0.85) * self.data.prediction.flightTime.value
        end

        local location = self.data.prediction.attackLocation
        local x, y = location.x, location.y

        self:registerForAttack({x = x, y = y}, location.faction, time, "Your ship '%1%' is under attack in sector \\s(%2%:%3%)!"%_T, {self.shipName, x, y})
    end

    -- "deplete" the route for 2 minutes, this basically occupies it
    -- 2 minutes because BGS tick time is 60s so it's safely occupied until the next tick
    local route = self.data.prediction.route
    self:depleteRoute(route.from, route.to, route.name, 2 * 60)
end

function TradeCommand:update(timeStep)
    local owner = getParentFaction()
    local entry = ShipDatabaseEntry(owner.index, self.shipName)
    entry:setStatusMessage("Trading"%_T)

    self.data.runTime = self.data.runTime + timeStep

    if self.data.runTime >= self.data.prediction.flightTime.value then
        -- finished a flight
        self.data.runTime = self.data.runTime - self.data.prediction.flightTime.value
        self.data.flights = self.data.flights + 1

        -- money is a random value between from and to, but it's dividable by the amount transported per flight
        -- because little details rock
        local money = random():getInt(self.data.prediction.profitPerFlight.from, self.data.prediction.profitPerFlight.to)
        money = math.floor(money / self.data.prediction.transportedPerFlight) * self.data.prediction.transportedPerFlight
        self.data.moneyEarned = self.data.moneyEarned + money

        local finish = false
        local message = "We finished a shipment! Here's what we made."%_T

        if self.data.flights >= self.data.prediction.flights.to then
            -- we reached the maximum amount of doable flights - the trade route is now depleted for some time
            finish = true
            message = "Last shipment was delivered successfully. Here's what we made with it, plus the initial deposit. Thank you for your trust in me, Commander."%_T
            money = money + self.config.deposit
            self.data.moneyEarned = self.data.moneyEarned + money
        elseif self.data.flights >= 3 then
            -- not enough cargo space to fly the route fast enough - someone else made a big shipment and now we're sad
            if random():test(0.35) then
                finish = true
                message = "Here is what we made with the last shipment, plus the upfront payment, but we took too long. Someone else got the contract for the remaining goods. With a larger cargo bay, that could've been us."%_T
                money = money + self.config.deposit
                self.data.moneyEarned = self.data.moneyEarned + money
            end
        end

        self:addYield(message, money)

        if finish then
            local buyingFaction = self.area.analysis.biggestFactionInArea
            if buyingFaction then
                local relationsChange = GetRelationChangeFromMoney(self.data.moneyEarned) * 0.15 -- only a quarter of the usual relations because it was captain who did the trading
                changeRelations(getParentFaction(), buyingFaction, relationsChange, RelationChangeType.GoodsTrade)
            end

            self:finish()
            return
        end
    end

    -- move the ship to its correct location
    if self.data.runTime >= self.data.prediction.flightTime.value * 0.65 then
        local coords = self.data.prediction.route.to
        entry:setCoordinates(coords.x, coords.y)
    elseif self.data.runTime >= self.data.prediction.flightTime.value * 0.35 then
        local coords = self.data.prediction.route.from
        entry:setCoordinates(coords.x, coords.y)
    end

    -- "deplete" the route for 2 minutes, basically occupies it
    -- 2 minutes because BGS tick time is 60s so it's safely occupied until the next tick
    local route = self.data.prediction.route
    self:depleteRoute(route.from, route.to, route.name, 2 * 60)
end

function TradeCommand:makeTradeRouteKey(from, to, goodName)
    return string.format("depleted_trade_route_%s-%s_%s-%s_%s", from.x, from.y, to.x, to.y, goodName)
end

function TradeCommand:depleteRoute(from, to, goodName, time)
    time = time or 120 * 60

    -- a route is marked as depleted by setting a player/alliance value for that route
    -- value is the time the route will be available again
    local faction = getParentFaction()

    local key = self:makeTradeRouteKey(from, to, goodName)
    local reactivationTime = Server().unpausedRuntime + time
    faction:setValue(key, reactivationTime)
end

function TradeCommand:clearDepletedRoutes(faction)
    -- remove all markings for depletion if enough time has passed (2 hours)
    local values = faction:getValues()
    local now = Server().unpausedRuntime

    for key, value in pairs(values) do
        if string.match(key, "depleted_trade_route_") then
            if now > value then
                faction:setValue(key, nil)
            end
        end
    end

end

function TradeCommand:isRouteAvailable(faction, from, to, goodName)
    local key = self:makeTradeRouteKey(from, to, goodName)
    local now = Server().unpausedRuntime

    local reactivationTime = faction:getValue(key)
    if not reactivationTime then return true end

    return now > reactivationTime
end

-- executed when an area analysis involving this type of command starts
-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function TradeCommand:onAreaAnalysisStart(results, meta)
    local faction = Galaxy():findFaction(meta.factionIndex)
    self:clearDepletedRoutes(faction)

    local factoryMap = FactoryMap()

    meta.economy = factoryMap:getProductionsMap(meta.area.lower, meta.area.upper)
    meta.supplyAndDemand = factoryMap:getAreaSupplyAndDemand(meta.area.lower, meta.area.upper)
    meta.factoryMap = factoryMap

end

-- executed when an area analysis involving this type of command is checking a specific sector
-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function TradeCommand:onAreaAnalysisSector(results, meta, x, y)

end

-- executed when an area analysis involving this type of command finished
-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function TradeCommand:onAreaAnalysisFinished(results, meta)

    results.routes = {}
    results.ignoredBadRelationSectors = 0

    local entry = ShipDatabaseEntry(meta.factionIndex, meta.shipName)
    if not valid(entry) then return end

    local captain = entry:getCaptain()
    if not captain:hasClass(CaptainUtility.ClassType.Merchant) then return end

    local owner = Galaxy():findFaction(meta.factionIndex)
    local factoryMap = meta.factoryMap

    local supplyDemand = {}
    for _, data in pairs(meta.supplyAndDemand) do
        supplyDemand[makeKey(data.coordinates.x, data.coordinates.y)] = data
    end

    local factionDetails = {}
    for _, data in pairs(results.reachableCoordinates) do
        factionDetails[makeKey(data.x, data.y)] = data
    end

    local available = {}
    for _, economyData in pairs(meta.economy) do
        local key = makeKey(economyData.coordinates.x, economyData.coordinates.y)

        -- ignore unreachable sectors
        if not meta.reachable[key] then goto continue end

        -- ignore sectors with bad relations
        local details = factionDetails[key]
        if not details or details.faction == 0 then goto continue end
        if owner:getRelationStatus(details.faction) == RelationStatus.War then
            results.ignoredBadRelationSectors = results.ignoredBadRelationSectors + 1
            goto continue
        end

        -- make sure the sector is revealed for the faction (including stations)
        local view = owner:getKnownSector(economyData.coordinates.x, economyData.coordinates.y)

        -- if the player's view is insufficient, check if the alliance knows more
        -- note: reverse is not necessary because all member sector knowledge is automatically added to the alliance
        if not view or view.numStations <= 0 then
            if owner.isPlayer then
                local alliance = owner.alliance
                if alliance then
                    view = alliance:getKnownSector(economyData.coordinates.x, economyData.coordinates.y)
                end
            end
        end

        if not view or view.numStations <= 0 then
             goto continue
        end

        -- find cheapest and most expensive
        local sold = {}
        local bought = {}

        for _, production in pairs(economyData.data.productions or {}) do
            for _, good in pairs(production.ingredients) do
                bought[good.name] = true
            end
            for _, good in pairs(production.results) do
                sold[good.name] = true
            end
            for _, good in pairs(production.garbages) do
                sold[good.name] = true
            end
        end

        for _, consumption in pairs(economyData.data.consumptions or {}) do
            for _, name in pairs(consumption.goods) do
                bought[name] = true
            end
        end

        for _, offer in pairs(economyData.data.sold or {}) do
            for _, name in pairs(offer.goods) do
                sold[name] = true
            end
        end

        for name, _ in pairs(sold) do available[name] = available[name] or {} end
        for name, _ in pairs(bought) do available[name] = available[name] or {} end

        local supplyDemandData = supplyDemand[key]

        -- analyze the data and find out the best prices for the goods
        for name, _ in pairs(sold) do
            local supply = supplyDemandData.sum[name]
            if not supply then goto continueSold end

            local change = factoryMap:supplyToPriceChange(supply)

            local lowest = available[name].lowest
            if not lowest or change < lowest then
                available[name].lowest = change
                available[name].lowestCoords = economyData.coordinates
            end

            ::continueSold::
        end

        -- analyze the data and find out the best prices for the goods
        for name, _ in pairs(bought) do
            local supply = supplyDemandData.sum[name]
            if not supply then goto continueBought end

            local change = factoryMap:supplyToPriceChange(supply)

            local highest = available[name].highest
            if not highest or change > highest then
                available[name].highest = change
                available[name].highestCoords = economyData.coordinates
            end

            ::continueBought::
        end

        ::continue::
    end

    local routes = {}
    for name, opportunity in pairs(available) do
        if opportunity.lowest and opportunity.highest then
            local lowest = round(math.max(opportunity.lowest, -0.2), 2)
            local highest = round(math.min(opportunity.highest, 0.2), 2)

            if lowest < highest then
                local good = goods[name]
                local profit = round(good.price * (highest - lowest))
                if profit > 0 then
                    if self:isRouteAvailable(owner, opportunity.lowestCoords, opportunity.highestCoords, name) then
                        table.insert(routes, {
                            name = name,
                            lowest = lowest,
                            highest = highest,
                            profit = profit,
                            profitPerSize = profit / good.size,
                            from = opportunity.lowestCoords,
                            to = opportunity.highestCoords,
                        })
                    end
                end
            end
        end
    end

    -- now use different "best routes"
    results.routes = {}

    -- highest single good profit
    -- we sort to end for easy removal
    table.sort(routes, function(a, b)
        if a.profit == b.profit then
            return a.name < b.name
        end

        return a.profit < b.profit
    end)

    if #routes > 0 then
        table.insert(results.routes, routes[#routes])
        table.remove(routes)
    end

    -- highest profit per volume
    -- we sort to end for easy removal
    table.sort(routes, function(a, b) return a.profitPerSize < b.profitPerSize end)

    if #routes > 0 then
        table.insert(results.routes, routes[#routes])
        table.remove(routes)
    end

    -- highest single margin
    -- we sort to end for easy removal
    table.sort(routes, function(a, b)
        local marginA = a.highest - a.lowest
        local marginB = b.highest - b.lowest
        return marginA < marginB
    end)

    if #routes > 0 then
        table.insert(results.routes, routes[#routes])
        table.remove(routes)
    end

    -- finally, highest single good profit again
    -- we sort to end for easy removal
    table.sort(routes, function(a, b) return a.profit < b.profit end)

    if #routes > 0 then
        table.insert(results.routes, routes[#routes])
        table.remove(routes)
    end

    table.sort(results.routes, function(a, b)
        if a.profit == b.profit then
            return a.name < b.name
        end
        return a.profit > b.profit
    end)

    -- printTable(results.routes)
end

-- executed when the ship is being recalled by the player
function TradeCommand:onRecall()

    local depletionTime = 0

    -- depending on when the ship is being recalled ...
    if self.data.runTime >= self.data.prediction.flightTime.value * 0.35 then
        -- ... have cargo on board and return the rest of the deposit
        local owner = getParentFaction()
        local entry = ShipDatabaseEntry(owner.index, self.shipName)

        local cargo = entry:getCargo()
        local good = goods[self.config.goodName]:good()
        cargo[good] = self.data.prediction.transportedPerFlight

        entry:setCargo(cargo)

        -- these goods must be paid for, subtract the price from the deposit
        -- calculate price of goods, see calculatePrediction
        local entry = ShipDatabaseEntry(owner.index, self.shipName)
        local captain = entry:getCaptain()

        local buyPrice = good.price * (1 + self.data.prediction.route.lowest)
        local salePrice = good.price * (1 + self.data.prediction.route.highest)

        for _, perk in pairs({captain:getPerks()}) do
            local factor = 1 + CaptainUtility.getTradeBuyPricePerkImpact(captain, perk)
            buyPrice = buyPrice * factor

            local factor = 1 + CaptainUtility.getTradeSellPricePerkImpact(captain, perk)
            salePrice = salePrice * factor
        end

        buyPrice = math.floor(buyPrice)
        salePrice = math.ceil(salePrice)

        -- make sure that buy price is at least 1 less than sell price
        buyPrice = math.min(buyPrice, salePrice - 1)

        local remainingDeposit = math.max(0, self.config.deposit - buyPrice * self.data.prediction.transportedPerFlight)

        self:addYield("We're back. I spent the deposit on the goods, they are in our cargo bay. With us canceling, the contract was assigned to someone else. The trade route is unavailable for now."%_T, remainingDeposit)

        depletionTime = math.min(120 * 60, 20 * 60 + self.data.flights * 40 * 60)
    else
        -- ... or return the deposit completely and show up with nothing
        if self.data.flights > 0 then
            self:addYield("We're back. We haven't gotten around to buying the shipment yet, so here's the full deposit back. With us canceling, the contract was assigned to someone else. The trade route is unavailable for now."%_T, self.config.deposit)
            depletionTime = math.min(120 * 60, self.data.flights * 40 * 60)
        else
            self:addYield("We're back. We haven't gotten around to buying the shipment yet, so here's the full deposit back."%_T, self.config.deposit)
        end
    end

    -- depletionTime can be 0 which is wanted behavior, the route should be freed on recall if nothing happened yet
    local route = self.data.prediction.route
    self:depleteRoute(route.from, route.to, route.name, depletionTime)
end

function TradeCommand:onAttacked()
end

-- executed when the command is finished
function TradeCommand:onFinish()
    local owner = getParentFaction()
    local entry = ShipDatabaseEntry(owner.index, self.shipName)
    local captain = entry:getCaptain()

    if captain:hasClass(CaptainUtility.ClassType.Explorer) then
        self:onExplorerFinish(captain)
    end

    local route = self.data.prediction.route
    self:depleteRoute(route.from, route.to, route.name)

    -- send chat message that ship is finished
    local x, y = entry:getCoordinates()
    owner:sendChatMessage(self.shipName, ChatMessageType.Information, "%1% has finished the trade contract and is awaiting your next orders in \\s(%2%:%3%)."%_T, self.shipName, x, y)
end

function TradeCommand:onExplorerFinish(captain)
    local faction = getParentFaction()
    local specs = SectorSpecifics()
    local seed = Server().seed

    local notes = {}
    table.insert(notes, "Commander, I marked this sector on the map for you.\n\nRegards, Captain ${name}"%_T)
    table.insert(notes, "Commander, we discovered this sector that you didn't have on the map yet.\n\nRegards, Captain ${name}"%_T)
    table.insert(notes, "Discovered a sector here.\n\nRegards, Captain ${name}"%_T)
    table.insert(notes, "As a small courtesy, I explored this sector for you.\n\nRegards, Captain ${name}"%_T)

    local revealed = 0
    local gatesMap

    for _, coords in pairs(self.area.analysis.reachableCoordinates) do
        local x, y = coords.x, coords.y
        local regular, offgrid = specs.determineFastContent(x, y, seed)

        if not regular then goto continue end

        local regular, offgrid, blocked, home = specs:determineContent(x, y, seed)
        if blocked then goto continue end -- there can't be anything if the sector is blocked

        local view = faction:getKnownSector(x, y)
        if view then goto continue end -- don't override existing data

        view = SectorView()
        gatesMap = gatesMap or GatesMap(GameSeed())

        specs:initialize(x, y, seed)
        specs:fillSectorView(view, gatesMap, true)

        view.note = NamedFormat(randomEntry(notes), {name = captain.name})

        -- make sure that no new icons are created
        if view.tagIconPath == "" then view.tagIconPath = "data/textures/icons/nothing.png" end

        faction:addKnownSector(view)

        revealed = revealed + 1
        if revealed >= 5 then break end

        ::continue::
    end
end

-- after this function was called, self.data will be read to be saved to database
function TradeCommand:onSecure()
end

-- this is called after the command was recreated and self.data was assigned
function TradeCommand:onRestore()
    self.data.moneyEarned = self.data.moneyEarned or 0
end

function TradeCommand:getAreaSize(ownerIndex, shipName)
    return {x = 17, y = 17}, {x = 29, y = 11}, {x = 11, y = 29}
end

function TradeCommand:getAreaBounds()
    return {lower = self.area.lower, upper = self.area.upper}
end

function TradeCommand:isAreaFixed(ownerIndex, shipName)
    return false
end

function TradeCommand:isShipRequiredInArea(ownerIndex, shipName)
    return true
end

function TradeCommand:getIcon()
    return "data/textures/icons/crate.png"
end

function TradeCommand:getDescriptionText()
    local totalRuntime = self.data.prediction.flightTime.value
    local timeRemaining = round((totalRuntime - self.data.runTime) / 60)
    local completed = round(self.data.runTime / totalRuntime * 100)

    local flight = self.data.flights + 1
    local maxFlights = self.data.prediction.flights.to

    local values = {
        timeRemaining = createReadableShortTimeString(timeRemaining * 60),
        completed = completed,
        flight = flight,
        maxFlights = maxFlights,
    }

    return "The ship is flying a trade route.\n\nFlight ${flight}/${maxFlights}. Flight time remaining: ${timeRemaining} (${completed} % done)."%_T, values
end

function TradeCommand:getStatusMessage()
    return "Trading"%_t
end

function TradeCommand:getRecallError()
end

-- returns whether the config sent by a client has errors
-- note: before this is called, there is already a preliminary check based on getConfigurableValues(), where values are clamped or default-set
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function TradeCommand:getErrors(ownerIndex, shipName, area, config)

    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local captain = entry:getCaptain()
    if not captain:hasClass(CaptainUtility.ClassType.Merchant) then
        return "I don't know enough about trading. You should task a merchant to do this job."%_T
    end

    if entry:getFreeCargoSpace() == 0 then
        return "Not enough cargo space!"%_t, {}
    end

    if tablelength(area.analysis.routes) == 0 then
        return "No routes found in the area. We should explore more sectors."%_T
    end

    if not config.goodName or config.goodName == "" then
        return "No route selected."%_T
    end

    -- check that config.goodName is actually a good
    local good = goods[config.goodName]
    if not good then
        return "No route selected."%_T -- generic error as this should not happen
    end

    -- check whether faction has enough money
    local owner = Galaxy():findFaction(ownerIndex)

    if owner.isAlliance then
        -- uses the local player (when on client) or callingPlayer (when on server), depending on what's correct
        -- in case this is called on the server, in an alliance context, without a callingPlayer, Player() will return nil and the if won't be entered
        -- that's okay since we wouldn't even know what player to check privileges for anyway
        local player = Player(callingPlayer)
        if player then
            if not owner:hasPrivilege(player.index, AlliancePrivilege.SpendResources) then
                return "You don't have permission to pay with alliance funds!"%_T, {}
            end
        end
    end

    local canPay, msg, args = owner:canPay(config.deposit)
    if not canPay then
        return msg, args
    end
end

-- returns the configurable values for this command (if any).
-- variable naming should speak for itself, though you're free to do whatever you want in here.
-- config will only be used by the command itself and nothing else
-- this may be called on a temporary instance of the command. all values written to "self" may not persist
function TradeCommand:getConfigurableValues(ownerIndex, shipName)
    return {}
end

-- returns the predictable values for this command (if any).
-- variable naming should speak for itself, though you're free to do whatever you want in here.
-- config will only be used by the command itself and nothing else
-- this may be called on a temporary instance of the command. all values written to "self" may not persist
function TradeCommand:getPredictableValues()
    local values = { }

    values.attackChance = {displayName = SimulationUtility.AttackChanceLabelCaption, value = 0}
    values.flightTime = {displayName = "Flight Time"%_t, value = 0}
    values.flights = {displayName = "Flights"%_t, from = 0, to = 0}
    values.profitPerFlight  = {displayName = "Profit / Flight"%_t, from = 0, to = 0}
    values.maxAvailable = {displayName = "Goods Total"%_t, value = 0}

    return values
end

local function getMaxValueOfRoute(route)
    local bestRichness = math.max(Balancing_GetSectorRichnessFactor(route.from.x, route.from.y, 150.0), Balancing_GetSectorRichnessFactor(route.to.x, route.to.y, 150.0))
    bestRichness = bestRichness - 0.5

    return 250 * 1000 * bestRichness
end

local function getMaxGoodsOfRoute(route)
    local good = goods[route.name]:good()

    local maxValue = getMaxValueOfRoute(route)
    local maxAvailable = math.min(25000, maxValue / good.price)

    local seed = string.format("%s_%s_%s_%s_%s_%s", GameSettings().seed.string, route.from.x, route.from.y, route.to.x, route.to.y, route.name)
    local random = Random(Seed(seed))

    local fluctuation = random:getFloat(0.3, 1.0) * random:getFloat(0.3, 1.0)
    maxAvailable = maxAvailable * fluctuation

    if maxAvailable < 100 then
        maxAvailable = math.ceil(maxAvailable / 10) * 10
    elseif maxAvailable < 500 then
        maxAvailable = math.ceil(maxAvailable / 50) * 50
    else
        maxAvailable = math.ceil(maxAvailable / 100) * 100
    end

    return maxAvailable
end

-- calculate the predictions for the ship, area and config
-- gut feeling says that each config option change should always be reflected in the predictions if it impacts the behavior
-- this may be called on a temporary instance of the command. all values written to "self" may not persist
function TradeCommand:calculatePrediction(ownerIndex, shipName, area, config)
    local prediction = self:getPredictableValues()

    prediction.transportedPerFlight = 0

    local route = nil

    for _, r in pairs(area.analysis.routes) do
        if r.name == config.goodName then
            route = r
            break
        end
    end

    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local captain = entry:getCaptain()
    if not captain:hasClass(CaptainUtility.ClassType.Merchant) then
        prediction.error = "I don't know enough about trading. You should task a merchant to do this job."%_T
        return prediction
    end

    if tablelength(area.analysis.routes) == 0 then
        prediction.error = "No routes found in the area. We should explore more sectors."%_T
        return prediction
    end

    if not route then
        prediction.error = "No route selected."%_T
        return prediction
    end

    prediction.route = route

    prediction.freeCargoSpace = entry:getFreeCargoSpace()
    local range = entry:getHyperspaceProperties()

    local good = goods[route.name]:good()
    local maxTransportable = math.floor(prediction.freeCargoSpace / good.size)

    local buyPrice = good.price * (1 + route.lowest)
    local salePrice = good.price * (1 + route.highest)

    for _, perk in pairs({captain:getPerks()}) do
        local factor = 1 + CaptainUtility.getTradeBuyPricePerkImpact(captain, perk)
        buyPrice = buyPrice * factor

        local factor = 1 + CaptainUtility.getTradeSellPricePerkImpact(captain, perk)
        salePrice = salePrice * factor
    end

    buyPrice = math.floor(buyPrice)
    salePrice = math.ceil(salePrice)

    -- make sure that buy price is at least 1 less than sell price
    buyPrice = math.min(buyPrice, salePrice - 1)

    -- available goods (ie. number of doable flights)
    local maxAvailable = getMaxGoodsOfRoute(route)
    prediction.maxAvailable.value = maxAvailable

    -- profit per delivery
    local transportedPerFlight = math.min(maxTransportable, math.floor(config.deposit / buyPrice))
    transportedPerFlight = math.min(maxAvailable, transportedPerFlight) -- can't transport more than there is

    if transportedPerFlight == 0 then
        prediction.error = "Not enough cargo space!"%_T
        return prediction
    end

    local flights = math.ceil(maxAvailable / transportedPerFlight)
    if flights > 1 then
        transportedPerFlight = math.ceil(maxAvailable / flights)
    end

    prediction.transportedPerFlight = transportedPerFlight
    prediction.profitPerFlight.to = transportedPerFlight * (salePrice - buyPrice)
    prediction.profitPerFlight.from = math.ceil(prediction.profitPerFlight.to * 0.9)

    prediction.flights.to = math.ceil(maxAvailable / transportedPerFlight)
    prediction.flights.from = prediction.flights.to

    if prediction.flights.to > 3 then
        prediction.flights.from = 3
        prediction.flights.to = math.ceil(maxAvailable / transportedPerFlight)
    end

    -- flight time
    local routeLength = distance(vec2(route.from.x, route.from.y), vec2(route.to.x, route.to.y)) * 1.3
    local jumps = math.ceil(routeLength / range)

    prediction.flightTime.value = 720 + jumps * 60

    local cargo = entry:getCargo()
    local stolenOrIllegal, dangerousOrSuspicious = SimulationUtility.getSpecialCargoCategories(cargo)

    local immuneToStolen = captain:hasClass(CaptainUtility.ClassType.Smuggler)

    local slowdown = 1
    if stolenOrIllegal and not immuneToStolen then slowdown = 1.15 end

    prediction.flightTime.value = prediction.flightTime.value * slowdown

    for _, perk in pairs({captain:getPerks()}) do
        local factor = 1 + CaptainUtility.getTradeTimePerkImpact(captain, perk)
        prediction.flightTime.value = prediction.flightTime.value * factor
    end

    -- take at least 5 minutes
    prediction.flightTime.value = prediction.flightTime.value + 300

    -- attack chance increases with more time away, we use this as an amplifier for valuable cargo
    -- starting at 100k, going up to 200k (scaled by sector richness), attack chance increases to what it would be when sending the ship away for 3 hours
    local threshold = 100000 * Balancing_GetSectorRichnessFactor(route.from.x, route.from.y, 40)
    local hours = lerp(config.deposit, threshold, threshold * 2, 1, 3)
    prediction.attackChance.value, prediction.attackLocation = SimulationUtility.calculateAttackProbability(ownerIndex, shipName, area, config.escorts, hours)

    return prediction
end

function TradeCommand:generateAssessmentFromPrediction(prediction, captain, ownerIndex, shipName, area, config)
    local total = area.analysis.sectors - area.analysis.unreachable
    if total == 0 then return "" end

    local attackChance = prediction.attackChance.value
    local pirateSectorRatio = SimulationUtility.calculatePirateAttackSectorRatio(area)

    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local captain = entry:getCaptain()
    local cargo = entry:getCargo()

    local contractLines = {}
    table.insert(contractLines, "We'll fulfill the contract for this trade route."%_t)
    table.insert(contractLines, "Looks like a profitable contract for this trade route."%_t)

    local flightsLines = {}
    if prediction.flights.to > 10 then
        table.insert(flightsLines, "\\c(d93)We have to do a lot of flights and probably can't fulfill the entire contract. The customer will eventually get impatient and use someone else.\\c()"%_t)
        table.insert(flightsLines, "\\c(d93)That's probably too many flights. The customer will probably give the contract to someone else at some point.\\c()"%_t)
    elseif prediction.flights.to > 5 then
        table.insert(flightsLines, "\\c(dd5)But be careful, Commander, with too many flights, the customer will eventually get impatient and pass the contract on to someone else.\\c()"%_t)
        table.insert(flightsLines, "\\c(dd5)We have to fly a few times. There is definitely a chance that we will lose the contract in the meantime because the customer gets impatient.\\c()"%_t)
    elseif prediction.flights.to > 3 then
        table.insert(flightsLines, "That's a few flights. There is a small chance that the customer will get impatient and give the contract to someone else."%_t)
        table.insert(flightsLines, "We have to fly a few times. There is a small chance that the customer will get impatient and we will lose the contract."%_t)
    else
        table.insert(flightsLines, "We do not have to fly often. With so few flights, the customer should not get impatient."%_t)
        table.insert(flightsLines, "That is only a few flights. It should be fast and the customer will not get impatient."%_t)
    end

    local stolenOrIllegal, dangerousOrSuspicious = SimulationUtility.getSpecialCargoCategories(cargo)
    local cargobayLines = SimulationUtility.getIllegalCargoAssessmentLines(stolenOrIllegal, dangerousOrSuspicious, captain)

    local pirateLines = SimulationUtility.getPirateAssessmentLines(pirateSectorRatio)
    local attackLines = SimulationUtility.getAttackAssessmentLines(attackChance)
    local underRadar, returnLines = SimulationUtility.getDisappearanceAssessmentLines(attackChance)

    local rnd = Random(Seed(captain.name))

    return {
        randomEntry(rnd, contractLines),
        randomEntry(rnd, flightsLines),
        randomEntry(rnd, pirateLines),
        randomEntry(rnd, attackLines),
        randomEntry(rnd, cargobayLines),
        randomEntry(rnd, underRadar),
        randomEntry(rnd, returnLines),
    }
end

-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function TradeCommand:buildUI(startPressedCallback, changeAreaPressedCallback, recallPressedCallback, configChangedCallback)
    local ui = {}

    ui.orderName = "Trade"%_t
    ui.icon = TradeCommand:getIcon()

    local size = vec2(660, 700)

    ui.window = GalaxyMap():createWindow(Rect(size))
    ui.window.caption = "Trading Contract"%_t

    ui.commonUI = SimulationUtility.buildCommandUI(ui.window, startPressedCallback, changeAreaPressedCallback, recallPressedCallback, configChangedCallback, {areaHeight = 130, configHeight = 210, changeAreaButton = true})

    -- configurable values
    local vlist = UIVerticalLister(ui.commonUI.configRect, 5, 5)
    local rect = vlist:nextRect(15)
    rect.lower = rect.lower - vec2(0, 10)

    local hlist = UIHorizontalLister(rect, 5, 5)

    local label = ui.window:createLabel(hlist:nextRect(220), "Trade Route Contracts"%_t, 13)
    hlist:nextRect(20) -- for icon
    local label = ui.window:createLabel(hlist:nextRect(65), "¢", 13)
    label.tooltip = "Regular price for this good"%_t
    label:setRightAligned()
    local label = ui.window:createLabel(hlist:nextRect(40), "%", 13)
    label.tooltip = "Price margin of the route"%_t
    label:setRightAligned()
    local label = ui.window:createLabel(hlist:nextRect(50), "min"%_t, 12)
    label.tooltip = "Best deviation for the purchase price in the area"%_t
    label:setRightAligned()
    local label = ui.window:createLabel(hlist:nextRect(35), "max"%_t, 12)
    label.tooltip = "Best deviation for the selling price in the area"%_t
    label:setRightAligned()
    local label = ui.window:createLabel(hlist:nextRect(80), "#", 12)
    label.tooltip = "Transportable in a single flight"%_t
    label:setRightAligned()
    local label = ui.window:createLabel(hlist.inner, "¢/u", 12)
    label.tooltip = "Profit per single good"%_t
    label:setRightAligned()

    ui.routeLines = {}
    for i = 1, 4 do
        local line = {}
        local rect = vlist:nextRect(30)
        line.frame = ui.window:createFrame(rect)

        local hlist = UIHorizontalLister(rect, 5, 5)

        line.check = ui.window:createCheckBox(hlist:nextRect(220), "", "TradeCommand_onRouteChecked")
        line.check.captionLeft = false
        line.check.fontSize = 13

        local rect = hlist:nextQuadraticRect()
        rect.size = rect.size + 6
        line.icon = ui.window:createPicture(rect, "")
        line.icon.isIcon = true

        line.priceLabel = ui.window:createLabel(hlist:nextRect(65), "", 13)
        line.priceLabel:setRightAligned()
        line.marginLabel = ui.window:createLabel(hlist:nextRect(40), "", 13)
        line.marginLabel:setRightAligned()
        line.lowestLabel = ui.window:createLabel(hlist:nextRect(50), "", 12)
        line.lowestLabel:setRightAligned()
        line.lowestLabel.color = ColorRGB(0.6, 0.6, 0.6)
        line.highestLabel = ui.window:createLabel(hlist:nextRect(35), "", 12)
        line.highestLabel:setRightAligned()
        line.highestLabel.color = ColorRGB(0.6, 0.6, 0.6)
        line.carriableLabel = ui.window:createLabel(hlist:nextRect(80), "", 13)
        line.carriableLabel:setRightAligned()
        line.profitLabel = ui.window:createLabel(hlist.inner, "", 13)
        line.profitLabel:setRightAligned()
        line.totalQuantityLabel = ui.window:createLabel(hlist.inner, "", 13)
        line.totalQuantityLabel:setRightAligned()

        line.hide = function(self)
            line.frame:hide()
            line.icon:hide()
            line.check:hide()
            line.lowestLabel:hide()
            line.highestLabel:hide()
            line.carriableLabel:hide()
            line.priceLabel:hide()
            line.marginLabel:hide()
            line.profitLabel:hide()
            line.totalQuantityLabel:hide()
        end
        line.show = function(self)
            line.frame:show()
            line.icon:show()
            line.check:show()
            line.lowestLabel:show()
            line.highestLabel:show()
            line.carriableLabel:show()
            line.priceLabel:show()
            line.marginLabel:show()
            line.profitLabel:show()
            line.totalQuantityLabel:show()
        end

        table.insert(ui.routeLines, line)
    end

    self.mapCommands.TradeCommand_onRouteChecked = function(checkBox)
        local line = nil
        for _, l in pairs(ui.routeLines) do
            if l.check.index ~= checkBox.index then
                l.check:setCheckedNoCallback(false)
            else
                line = l
            end
        end

        if not line then return end

        local good = line.good

        local position = ui.depositSlider.sliderPosition
        ui.depositSlider:setValueNoCallback(0)
        ui.depositSlider.min = line.minAmount
        ui.depositSlider.max = line.maxAmount
        ui.depositSlider.segments = line.maxAmount - line.minAmount

        ui.depositSlider:setValueNoCallback(math.ceil(lerp(position, 0, 1, line.minAmount, line.maxAmount)))

        self.mapCommands[configChangedCallback]()
    end

    local rect = vlist:nextRect(50)
    local vsplit = UIVerticalMultiSplitter(rect, 20, 10, 2)
    ui.depositDescriptionLabel = ui.window:createLabel(vsplit.left, "Down Payment"%_t, 13)
    ui.depositDescriptionLabel:setRightAligned()
    ui.depositSlider = ui.window:createSlider(vsplit:partition(1), 0, 10, 10, "", configChangedCallback)
    ui.depositSlider.showValue = false
    ui.depositLabel = ui.window:createLabel(vsplit.right, "¢123.021"%_t, 13)
    ui.depositLabel:setLeftAligned()
    ui.depositLabel.tooltip = "Credits you need to give the captain in advance to buy the goods.\nThey will return everything they don't spend."%_t

    -- yields & issues
    local predictable = self:getPredictableValues()
    local vlist = UIVerticalLister(ui.commonUI.predictionRect, 5, 0)

    -- attack chance
    local tooltip = SimulationUtility.AttackChanceLabelTooltip
    local vsplit0 = UIVerticalSplitter(vlist:nextRect(20), 0, 0, 0.6)
    local label = ui.window:createLabel(vsplit0.left, predictable.attackChance.displayName .. ":", 12)
    label.tooltip = tooltip
    ui.commonUI.attackChanceLabel = ui.window:createLabel(vsplit0.right, "", 12)
    ui.commonUI.attackChanceLabel:setRightAligned()
    ui.commonUI.attackChanceLabel.tooltip = tooltip

    -- amount of goods to transport
    local tooltip = "Total quantity of goods to be transported for this contract"%_t
    local vsplit2 = UIVerticalSplitter(vlist:nextRect(15), 0, 0, 0.6)
    local label = ui.window:createLabel(vsplit2.left, predictable.maxAvailable.displayName .. ":", 12)
    label.tooltip = tooltip
    ui.totalQuantityLabel = ui.window:createLabel(vsplit2.right, "", 12)
    ui.totalQuantityLabel.tooltip = tooltip
    ui.totalQuantityLabel:setRightAligned()

    -- profit
    local tooltip = "Profit per shipment for this route"%_t
    local vsplit2 = UIVerticalSplitter(vlist:nextRect(15), 0, 0, 0.6)
    local label = ui.window:createLabel(vsplit2.left, predictable.profitPerFlight.displayName .. ":", 12)
    label.tooltip = tooltip
    ui.profitLabel = ui.window:createLabel(vsplit2.right, "", 12)
    ui.profitLabel.tooltip = tooltip
    ui.profitLabel:setRightAligned()

    -- single flight duration
    local vsplit1 = UIVerticalSplitter(vlist:nextRect(15), 0, 0, 0.6)
    local label = ui.window:createLabel(vsplit1.left, predictable.flightTime.displayName .. ":", 12)
    ui.flightTimeLabel = ui.window:createLabel(vsplit1.right, "", 12)
    ui.flightTimeLabel:setRightAligned()

    -- flights
    local tooltip = "The trade route can be flown this many times until the contract is fulfilled. If fulfillment requires too many flights, the contract may be given to someone else after a few deliveries."%_t
    local vsplit1 = UIVerticalSplitter(vlist:nextRect(15), 0, 0, 0.6)
    local label = ui.window:createLabel(vsplit1.left, predictable.flights.displayName .. ":", 12)
    label.tooltip = tooltip
    ui.flightsLabel = ui.window:createLabel(vsplit1.right, "", 12)
    ui.flightsLabel:setRightAligned()
    ui.flightsLabel.tooltip = tooltip

    -- custom change area buttons
    -- make them similar to the existing button, just move them to the right
    local rect = ui.commonUI.changeAreaButton.rect
    local offset = vec2(rect.size.x + 10, 0)
    rect.lower = rect.lower + offset
    rect.upper = rect.upper + offset

    ui.changeAreaButton2 = ui.window:createButton(rect, "", "TradeCommand_reselectVertical")
    ui.changeAreaButton2.icon = "data/textures/icons/change-area-vertical.png"
    ui.changeAreaButton2.tooltip = "Choose a different area for the command"%_t

    rect.lower = rect.lower + offset
    rect.upper = rect.upper + offset

    ui.changeAreaButton3 = ui.window:createButton(rect, "", "TradeCommand_reselectHorizontal")
    ui.changeAreaButton3.icon = "data/textures/icons/change-area-horizontal.png"
    ui.changeAreaButton3.tooltip = "Choose a different area for the command"%_t

    self.mapCommands.TradeCommand_reselectVertical = function()
        self.mapCommands.nextUsedSize = 3
        self.mapCommands[changeAreaPressedCallback]()
    end

    self.mapCommands.TradeCommand_reselectHorizontal = function()
        self.mapCommands.nextUsedSize = 2
        self.mapCommands[changeAreaPressedCallback]()
    end

    ui.clear = function(self, shipName)
        self.commonUI:clear(shipName)

        for _, line in pairs(self.routeLines) do
            line.check:setCheckedNoCallback(false)
            line:hide()
        end

        self.depositDescriptionLabel:hide()
        self.depositSlider:setSliderPositionNoCallback(0.5)
        self.depositSlider:hide()
        self.depositLabel:hide()

        self.profitLabel.caption = string.format("¢%s"%_t, 0)
        self.totalQuantityLabel.caption = string.format("¢%s"%_t, 0)
        self.flightTimeLabel.caption = "0 min"

        self.commonUI.attackChanceLabel.caption = ""
    end

    -- used to fill values into the UI
    -- config == nil means fill with default values
    ui.refresh = function(self, ownerIndex, shipName, area, config)
        self.commonUI:refresh(ownerIndex, shipName, area, config)

        local entry = ShipDatabaseEntry(ownerIndex, shipName)
        local freeCargoSpace = entry:getFreeCargoSpace()

        for i = 1, math.min(#self.routeLines, #area.analysis.routes) do
            local line = self.routeLines[i]
            local route = area.analysis.routes[i]

            local good = goods[route.name]:good()
            local maxAvailable = getMaxGoodsOfRoute(route)
            local maximum = math.min(maxAvailable, math.floor(freeCargoSpace / good.size))

            line.good = good
            line.maxAmount = maximum
            line.minAmount = math.max(1, math.floor(math.min(maxAvailable * 0.1, freeCargoSpace * 0.1 / good.size)))
            line.minPrice = math.ceil(good.price * (1 + route.lowest))

            line:show()
            line.check.caption = good:displayName(100)
            line.icon.picture = good.icon
            line.lowestLabel.caption = string.format("%+d%%", round(route.lowest * 100, 1))
            line.highestLabel.caption = string.format("%+d%%", round(route.highest * 100, 1))
            line.priceLabel.caption = "¢${money}"%_t % {money = createMonetaryString(good.price)}
            line.marginLabel.caption = string.format("%+d%%", round(route.highest * 100, 1) - round(route.lowest * 100, 1))
            line.profitLabel.caption = "¢${money}"%_t % {money = createMonetaryString(route.profit)}
            line.carriableLabel.caption = maximum

            self.depositSlider:show()
            self.depositDescriptionLabel:show()
            self.depositLabel:show()

            line.check.active = maximum > 0

            if maximum == 0 then line.check:setCheckedNoCallback(false) end
        end

        if not config then
            -- no config: fill UI with default values, then build config, then use it to calculate yields
            self.depositSlider:setSliderPositionNoCallback(0.5)

            if self.routeLines[1].check.visible then
                self.routeLines[1].check.checked = true
            end

            config = self:buildConfig()
        end

        self.depositLabel.caption = "¢${money}"%_t % {money = createMonetaryString(config.deposit or 0)}

        self:refreshPredictions(ownerIndex, shipName, area, config)
    end

    -- each config option change should always be reflected in the predictions if it impacts the behavior
    ui.refreshPredictions = function(self, ownerIndex, shipName, area, config)
        local prediction = TradeCommand:calculatePrediction(ownerIndex, shipName, area, config)
        self:displayPredictionHelper(prediction, config, ownerIndex)

        self.commonUI:refreshPredictions(ownerIndex, shipName, area, config, TradeCommand, prediction)
    end

    -- this function is shared for two uses: for configuring the command and for displaying the running command (read only)
    ui.displayPredictionHelper = function(self, prediction, config, ownerIndex)
        self.depositLabel.caption = "¢${money}"%_t % {money = createMonetaryString(config.deposit or 0)}

        self.flightTimeLabel.caption = createReadableShortTimeString(math.ceil(prediction.flightTime.value / 60) * 60)

        if prediction.flights.from == prediction.flights.to then
            self.flightsLabel.caption = toReadableNumber(prediction.flights.to, 1)
        else
            self.flightsLabel.caption = string.format("%s - %s", toReadableNumber(prediction.flights.from, 1), toReadableNumber(prediction.flights.to, 1))
        end
        self.profitLabel.caption = string.format("¢%s - ¢%s", toReadableNumber(prediction.profitPerFlight.from, 1), toReadableNumber(prediction.profitPerFlight.to, 1))
        self.totalQuantityLabel.caption = tostring(prediction.maxAvailable.value)

        self.commonUI:setAttackChance(prediction.attackChance.value)
    end

    -- fill in read only values when displaying the running command
    ui.displayPrediction = function(self, prediction, config, ownerIndex)
        self:displayPredictionHelper(prediction, config, ownerIndex)

        local good = goods[prediction.route.name]:good()
        local maximum = math.floor(prediction.freeCargoSpace / good.size)

        local line = self.routeLines[1]
        line.check.caption = good:displayName(100)
        line.icon.picture = good.icon
        line.lowestLabel.caption = string.format("%+d%%", round(prediction.route.lowest * 100, 1))
        line.highestLabel.caption = string.format("%+d%%", round(prediction.route.highest * 100, 1))
        line.priceLabel.caption = "¢${money}"%_t % {money = createMonetaryString(good.price)}
        line.marginLabel.caption = string.format("%+d%%", round(prediction.route.highest * 100, 1) - round(prediction.route.lowest * 100, 1))
        line.profitLabel.caption = "¢${money}"%_t % {money = createMonetaryString(prediction.route.profit)}
        line.carriableLabel.caption = maximum
    end

    -- used to build a config table for the command, based on values configured in the UI
    -- gut feeling says that each config option change should always be reflected in the predictions if it impacts the behavior
    ui.buildConfig = function(self)
        local config = {}

        config.escorts = self.commonUI.escortUI:buildConfig()

        local line = nil
        for _, l in pairs(self.routeLines) do
            if l.check.checked then
                line = l
            end
        end

        if line then
            config.goodName = line.good.name
            config.deposit = self.depositSlider.value * line.minPrice
            config.maxDeposit = self.depositSlider.max * line.minPrice
        end

        return config
    end

    ui.setActive = function(self, active, description)
        self.commonUI:setActive(active, description)

        self.changeAreaButton2.visible = active
        self.changeAreaButton3.visible = active

        self.depositSlider.active = active

        for i = 1, 4 do
            self.routeLines[i].check.active = active
        end
    end

    ui.displayConfig = function(self, config, ownerIndex)
        -- show only the chosen trade route contract
        self.routeLines[1]:show()
        for i = 2, 4 do
            self.routeLines[i]:hide()
        end

        self.routeLines[1].check:setCheckedNoCallback(true)

        self.depositSlider:setMaxNoCallback(config.maxDeposit)
        self.depositSlider:setValueNoCallback(config.deposit)
    end

    return ui
end


return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
