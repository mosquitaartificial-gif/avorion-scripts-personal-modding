package.path = package.path .. ";data/scripts/lib/?.lua"

include ("stringutility")
include ("utility")
include ("callable")
local FactoryPredictor = include ("factorypredictor")
local FactoryMap = include ("factorymap")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace EconomyInfo
EconomyInfo = {}
local self = EconomyInfo

-- Client starts a request when:
-- * no request is running
-- * AND
-- * sector has changed
-- * OR range has changed
-- * OR 60 seconds since the last request have passed
-- * OR no data is there


-- Server starts calculation when:
-- * no calculation is running
-- * AND
-- * sector has changed
-- * OR range has changed
-- * OR 60 seconds since the last calculation have passed
-- * OR no data is there


if onClient() then

self.supplyDemandData =
{
    data = nil,
    index = nil,

    coordinates = nil,
    running = false,
    lastUpdated = nil,
}


function EconomyInfo.getUpdateInterval()
    return 1
end

function EconomyInfo.initialize()
    local player = Player()
    player:registerCallback("onShowGalaxyMap", "onShowGalaxyMap")
    player:registerCallback("onHideGalaxyMap", "onHideGalaxyMap")

    self.initUI()
end


function EconomyInfo.initUI()
    local res = getResolution()

    self.container = GalaxyMap():createContainer(Rect(0, 0, res.x, res.y))
    self.combo = self.container:createValueComboBox(Rect(460, 10, 700, 40), "onGoodSelected")
    self.combo:hide()

    self.combo2 = self.container:createValueComboBox(Rect(710, 10, 1000, 40), "onVisualizationSelected")
    self.combo2:addEntry("price", "Price: -30% (cold) -> +30% (hot)"%_t)
    self.combo2:addEntry("lerp_sum", "Demand (cold) -> Supply (hot)"%_t)
    -- self.combo2:addEntry("both", "RGB(Demand, Supply, 1)")
    self.combo2:hide()
end

function EconomyInfo.refreshUI()

    local before = self.combo.selectedValue

    self.combo:clear()
    self.combo:addEntry(nil, " <No Good Selected> "%_t)
    self.combo:addEntry(nil, "")
    if not self.supplyDemandData.data or #self.supplyDemandData.data == 0 then
        self.combo:hide()
        self.combo2:hide()
        return
    end

    for _, name in pairs(self.supplyDemandData.index.sorted) do
        self.combo:addEntry(name, name % _t)
    end

    self.combo:setSelectedValueNoCallback(before)
    self.combo:show()
    self.combo2:show()
end

function EconomyInfo.disableUI()
    local map = GalaxyMap()
    map.showFactionLayer = true
    map.showCustomColorLayer = false

    self.combo:hide()
    self.combo2:hide()
end

function EconomyInfo.updateClient(timeStep)
    if not GalaxyMap().visible then return end

    if self.getSupplyDemandUpdateRequired() then
        self.requestNearbyEconomy()
    end

    if self.supplyDemandData.running then

    end
end

function EconomyInfo.updateMap()
    local map = GalaxyMap()
    map:clearCustomColors()
    map.showFactionLayer = true
    map.showCustomColorLayer = false

    if not self.supplyDemandData.data then return end

    self.addToMap(self.supplyDemandData)
end

function EconomyInfo.addToMap(data)
    local map = GalaxyMap()

    local good = self.combo.selectedValue
    if not good then return end

    local visualization = self.combo2.selectedValue or "lerp_sum"

    local calculation = self.combo.selectedValue

    local colors = {}

    local locations = data.index.locations[good]
    if not locations then return end

    map.showFactionLayer = false
    map.showCustomColorLayer = true

    local fmap = FactoryMap()
    local sdLower, sdUpper = fmap:getSupplyDemandGradients()
    local pLower, pUpper = fmap:getPriceGradients()

    for _, i in pairs(locations) do
        local dataPoint = data.data[i]

        local x, y = dataPoint.coordinates.x, dataPoint.coordinates.y

        local supply = 0
        local demand = 0

        if dataPoint.supply then supply = dataPoint.supply[good] or 0 end
        if dataPoint.demand then demand = dataPoint.demand[good] or 0 end

        local color = vec3(demand / 75, supply / 75, 0)

        local sum = dataPoint.sum[good]

        if visualization == "lerp_sum" then
            color = lerp(sum, -75, 75, vec3(0, 0, 1), vec3(0, 1, 0))
            if sum > 0 then
                color = lerp(sum, 0, 75, vec3(0.5, 0.5, 0.5), vec3(0, 1, 0))
            else
                color = lerp(sum, -75, 0, vec3(0, 0, 1), vec3(0.5, 0.5, 0.5))
            end

            if sum == 0 then
                color = vec3(0.5, 0.5, 0.5)
            elseif sum > 0 then
                color = multilerp(sum, 0, 75, sdUpper)
            elseif sum < 0 then
                color = multilerp(sum, -75, 0, sdLower)
            end

        elseif visualization == "both" then
            color = vec3(demand / 75, supply / 75, 1)
        elseif visualization == "price" then

            local price = fmap:supplyToPriceChange(sum) * 100

            if price == 0 then
                color = vec3(0.5, 0.5, 0.5)
            elseif price > 0 then
                color = multilerp(price, 0, 30, pUpper)
            elseif price < 0 then
                color = multilerp(price, -30, 0, pLower)
            end
        end

        colors[ivec2(x, y)] = ColorARGB(0.3, color.x, color.y, color.z)
    end

    map:setCustomColors(colors)

end

function EconomyInfo.onShowGalaxyMap()
    local range = self.getBestEconomyOverviewRange()
    if range <= 1 then
        self.disableUI()
    end

    self.requestNearbyEconomy()
end

function EconomyInfo.onHideGalaxyMap()
end

function EconomyInfo.getSupplyDemandUpdateRequired()
    if self.supplyDemandData.running then return false end
    if not self.supplyDemandData.data then return true end
    if not self.supplyDemandData.coordinates then return true end

    local x, y = Sector():getCoordinates()
    if self.supplyDemandData.coordinates.x ~= x then return true end
    if self.supplyDemandData.coordinates.y ~= y then return true end

    local now = appTime()
    if not self.supplyDemandData.lastUpdated or now - self.supplyDemandData.lastUpdated > 60 then return true end

    return false
end

function EconomyInfo.startAreaSupplyDemandCalculation(productions, x, y, radius)

    local code = [[
        package.path = package.path .. ";data/scripts/lib/?.lua"
        package.path = package.path .. ";data/scripts/?.lua"

        local FactoryMap = include ("factorymap")
        local PassageMap = include ("passagemap")

        function run(productions, x, y, radius)
            local map = FactoryMap()
            local passageMap = PassageMap(GameSeed())

            local radius2 = radius * radius

            local data = {}
            local index = {}

            for cx = x - radius, x + radius do
                for cy = y - radius, y + radius do
                    if not passageMap:passable(cx, cy) then goto continue end

                    -- is it in range?
                    local dx = x - cx
                    local dy = y - cy
                    local d2 = dx * dx + dy * dy

                    if d2 > radius2 then goto continue end

                    -- gather supply and demand for the sector in question
                    local supply, demand, sum = map:getSupplyAndDemand(cx, cy, productions)

                    if tablelength(supply) > 0 or tablelength(demand) > 0 or tablelength(sum) > 0 then
                        data[#data + 1] = {coordinates = {x=cx, y=cy}, supply = supply, demand = demand, sum = sum}
                    end

                    ::continue::
                end
            end

            -- create an index of the goods for easy and fast access
            index.available = {}
            index.locations = {}

            for i, entry in pairs(data) do
                for k, v in pairs(entry.sum) do
                    index.available[k] = true

                    local locations = index.locations[k] or {}
                    locations[#locations + 1] = i
                    index.locations[k] = locations
                end
            end

            local sorted = {}
            for entry, _ in pairs(index.available) do
                sorted[#sorted + 1] = {name = entry, translated = entry%_t}
            end

            table.sort(sorted, function(a, b) return a.translated < b.translated end)

            index.sorted = {}
            for i, entry in pairs(sorted) do
                index.sorted[i] = entry.name
            end

            return data, index
        end
    ]]

    async("onSupplyDemandCalculated", code, productions, x, y, radius)

    self.supplyDemandData.running = true

end

function EconomyInfo.onSupplyDemandCalculated(data, index)
--    print("onSupplyDemandCalculated")

    self.supplyDemandData.data = data
    self.supplyDemandData.index = index
    self.supplyDemandData.lastUpdated = appTime()
    self.supplyDemandData.running = false

    local x, y = Sector():getCoordinates()
    self.supplyDemandData.coordinates = {x = x, y = y}

    self.refreshUI()

    self.updateMap()
end

function EconomyInfo.onGoodSelected(comboBox, value, entryIndex)
    self.updateMap()
end
function EconomyInfo.onVisualizationSelected(comboBox, value, entryIndex)
    self.updateMap()
end

end -- if onClient() then


function EconomyInfo.getBestEconomyOverviewRange()
    local player = Player()
    if not player then return 0 end

    local craft = player.craft
    if not craft then return 0 end

    local scripts = craft:getScripts()
    if not scripts then return 0 end

    local best = 0
    for i, file in pairs(scripts) do
        if string.match(file, "/systems/tradingoverview.lua")
                or string.match(file, "/systems/hypertradingsystem.lua") then
            local ok, r = craft:invokeFunction(i, "getEconomyRange")
            if ok == 0 and r > best then
                best = r
            end
        end
    end

    return best
end


self.economyRequest =
{
    data = nil,

    coordinates = nil,
    running = false,
    lastUpdated = nil,
}

function EconomyInfo.onNearbyEconomyCalculated(productions, x, y, radius)
    local sx, sy = Sector():getCoordinates()
    if x ~= sx or y ~= sy then return end

    self.economyRequest.data = productions
    self.economyRequest.coordinates = {x = x, y = y}

    if onServer() then
        self.economyRequest.running = false

        local player = Player()
        if player then
            invokeClientFunction(player, "onNearbyEconomyCalculated", productions, x, y, radius - 25) -- 25 is the range of a factory
        end
    else
        local now = appTime()
        self.economyRequest.lastUpdated = now
        self.economyRequest.range = radius

        self.startAreaSupplyDemandCalculation(productions, x, y, radius)
    end
end

function EconomyInfo.getEconomyRequestData(x, y, range)
    local now = appTime()
    if not self.economyRequest.data then return end
    if not self.economyRequest.lastUpdated then return end
    if now - self.economyRequest.lastUpdated > 60 then return end

    if self.economyRequest.coordinates.x ~= x then return end
    if self.economyRequest.coordinates.y ~= y then return end

    if self.economyRequest.range ~= range then return end

    return self.economyRequest.data
end


function EconomyInfo.requestNearbyEconomy()

    if onClient() then

        -- try saving as much network traffic as possible, if we don't have to check, we won't do a server-call
        local range = self.getBestEconomyOverviewRange()
        if range <= 1 then return end

        local x, y = Sector():getCoordinates()

        -- check if there is still data thats no older than a minute
        -- try returning cached data
        local data = self.getEconomyRequestData(x, y, range)
        if data then
            self.startAreaSupplyDemandCalculation(data, x, y, range)
            return
        end

        -- if there is no current data, do a server invocation
        invokeServerFunction("requestNearbyEconomy")
        return
    end

    -- check we if we even have to start an async call
    local range = self.getBestEconomyOverviewRange()
    if range <= 1 then return end
    if self.economyRequest.running then return end

    local x, y = Sector():getCoordinates()

    -- check if there is still data that's no older than a minute
    -- try returning cached data
    local data = self.getEconomyRequestData(x, y, range)
    if data then
        self.onNearbyEconomyCalculated(data, x, y, range + 25)
        return
    end

    local code = [[
        package.path = package.path .. ";data/scripts/lib/?.lua"
        package.path = package.path .. ";data/scripts/?.lua"

        local FactoryMap = include ("factorymap")

        function run(x, y, radius)
            local map = FactoryMap()

            local from = {x = x - radius, y = y - radius}
            local to = {x = x + radius, y = y + radius}

            local productions = map:getProductionsMap(from, to)

            return productions, x, y, radius
        end
    ]]

    async("onNearbyEconomyCalculated", code, x, y, range + 25) -- 25 is the range of a factory

    local now = appTime()
    self.economyRequest.lastUpdated = now
    self.economyRequest.range = range
    self.economyRequest.running = true
end
callable(EconomyInfo, "requestNearbyEconomy")


