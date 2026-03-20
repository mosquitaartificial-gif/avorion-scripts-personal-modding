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

local todo = nil

if onClient() then

self.craft = nil
self.scriptIndex = nil

self.supplyDemandData =
{
    coordinates = nil,
    running = false,
    data = nil,
    lastUpdated = nil,
}

local dataCollection = {}
local working = 0

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
    self.combo = self.container:createValueComboBox(Rect(500, 10, 750, 40), "onGoodSelected")
    self.combo:hide()

    self.combo2 = self.container:createValueComboBox(Rect(770, 10, 1000, 40), "onVisualizationSelected")
    self.combo2:addEntry("lerp_sum", "Lerp Sum: Blue -> Grey -> Green")
    self.combo2:addEntry("both", "RGB(Demand, Supply, 0)")
    self.combo2:addEntry("price", "-30% (cold) -> +30% (hot)")
    self.combo2:hide()
end

function EconomyInfo.refreshUI()

    local before = self.combo.selectedValue

    self.combo:clear()
    self.combo:addEntry(nil, " <Nothing> "%_T)
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

function EconomyInfo.updateClient(timeStep)
    if not GalaxyMap().visible then return end
    if not self.scriptIndex then return end

--    if self.getSupplyDemandUpdateRequired() then

--        local player = Player()
--        local craft = player.craft

--        local productions = self.getNearbyEconomy(craft)
--        if productions then
--            self.startAreaSupplyDemandCalculation(productions)
--        end
--    end

end

function EconomyInfo.updateMap()
    local map = GalaxyMap()
    map:clearCustomColors()
    map.showFactionLayer = true
    map.showCustomColorLayer = false

--    if not self.supplyDemandData.data then return end

    for _, data in pairs(dataCollection) do
        self.addToMap(data)
    end

end

local function multilerp(factor, from, to, values)
    factor = (factor - from) / (to - from)
    if factor > 1 then factor = 1 end
    if factor < 0 then factor = 0 end

    if #values == 0 then return nil end
    if #values == 1 then return values[1] end

    factor = factor * (#values - 1) + 1
    for i = 2, #values do
        local prev = i - 1
        if factor >= prev and factor < i then
            return lerp(factor, prev, i, values[prev], values[i])
        end
    end

    return values[#values]
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
        elseif visualization == "both" then
            color = vec3(demand / 75, supply / 75, 0)
        elseif visualization == "price" then

            local price = fmap:supplyToPriceChange(sum) * 100

            if price == 0 then
                color = vec3(0.5, 0.5, 0.5)
            elseif price > 0 then
                color = multilerp(price, 0, 30, {vec3(0, 0.5, 0), vec3(0, 1, 0), vec3(1, 1, 0), vec3(1, 0, 0), vec3(1, 1, 1), })
            elseif price < 0 then
                color = multilerp(price, -30, 0, {vec3(0.3, 0, 0.3), vec3(1, 0, 1), vec3(0, 0, 1), vec3(0, 1, 1), vec3(0, 0.5, 0)})
            end

        end

        colors[ivec2(x, y)] = ColorARGB(0.4, color.x, color.y, color.z)
    end

    map:setCustomColors(colors)

end

function EconomyInfo.onShowGalaxyMap()
    local player = Player()

    self.craft = player.craft
    self.scriptIndex = self.getBestTradingOverviewScript(self.craft)

    if not self.scriptIndex then return end

    if not todo then
        local x, y = Sector():getCoordinates()
        todo = {}

        for ix = -5, 5 do
        for iy = -5, 5 do
            table.insert(todo, {x = x + ix * 50, y = y + iy * 50})
        end
        end

        table.sort(todo, function(a, b)
            local da = distance2(vec2(a.x, a.y), vec2(x, y))
            local db = distance2(vec2(b.x, b.y), vec2(x, y))

            return da < db
        end)
    end

    self.requestNearbyEconomy()
    self.requestNearbyEconomy()
    self.requestNearbyEconomy()
    self.requestNearbyEconomy()
    self.requestNearbyEconomy()
    self.requestNearbyEconomy()
--    self.craft:invokeFunction(self.scriptIndex, "requestNearbyEconomy")


--    self.showSpecializationAreas()
end

function EconomyInfo.onHideGalaxyMap()
    self.craft = nil
    self.scriptIndex = nil
end

function EconomyInfo.getNearbyEconomy(craft)
    local ok, productions = craft:invokeFunction("systems/tradingoverview.lua", "getNearbyEconomy")
    if ok == 0 and productions then
        return productions
    end

    local ok, productions = craft:invokeFunction("systems/hypertradingsystem.lua", "getNearbyEconomy")
    if ok == 0 and productions then
        return productions
    end
end

function EconomyInfo.getSupplyDemandUpdateRequired()
    if self.supplyDemandData.running then return false end
    if not self.supplyDemandData.data then return true end
    if not self.supplyDemandData.coordinates then return true end

    local x, y = Sector():getCoordinates()
    if self.supplyDemandData.coordinates.x ~= x then return true end
    if self.supplyDemandData.coordinates.y ~= y then return true end

    local now = appTime()
    if not self.supplyDemandData.lastUpdated or now - self.supplyDemandData.lastUpdated > 6000000000 then return true end

    return false
end

function EconomyInfo.startAreaSupplyDemandCalculation(productions, x, y)

--        x, y = Sector():getCoordinates()

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
--                print ("from: %s, to: %s, at: %s", x - radius, x + radius, cx)

                for cy = y - radius, y + radius do
                    if not passageMap:passable(cx, cy) then goto continue end

                    -- is it in range?
                    local dx = x - cx
                    local dy = y - cy
                    local d2 = dx * dx + dy * dy

--                    if d2 > radius2 then goto continue end

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
--                print ("%s of %s", i, #data)
                for k, v in pairs(entry.sum) do
                    index.available[k] = true

                    local locations = index.locations[k] or {}
                    locations[#locations + 1] = i
                    index.locations[k] = locations
                end
            end

            index.sorted = {}
            for entry, _ in pairs(index.available) do
                index.sorted[#index.sorted + 1] = entry
            end

            table.sort(index.sorted)

            return data, index
        end
    ]]

    async("onSupplyDemandCalculated", code, productions, x, y, 25)

    self.supplyDemandData.running = true

end

function EconomyInfo.onSupplyDemandCalculated(data, index)
--    print("onSupplyDemandCalculated")

    dataCollection[#dataCollection + 1] = {data = data, index = index}
    self.requestNearbyEconomy()

    self.supplyDemandData.data = data
    self.supplyDemandData.index = index
    self.supplyDemandData.lastUpdated = appTime()
    self.supplyDemandData.running = false

    local x, y = Sector():getCoordinates()
    self.supplyDemandData.coordinates = {x = x, y = y}

    self.refreshUI()
    self.addToMap({data = data, index = index})
end

function EconomyInfo.onGoodSelected(comboBox, value, entryIndex)
    self.updateMap()
end
function EconomyInfo.onVisualizationSelected(comboBox, value, entryIndex)
    self.updateMap()
end

function EconomyInfo.getBestTradingOverviewScript(craft)
    local scripts = craft:getScripts()

    local rarity
    local best
    for i, file in pairs(scripts) do
        if string.match(file, "/systems/tradingoverview.lua")
                or string.match(file, "/systems/hypertradingsystem.lua") then
            local ok, r = craft:invokeFunction(i, "getRarity")
            if ok == 0 and (not rarity or r > rarity) then
                rarity = r
                best = i
            end
        end
    end

    return best
end



-- debugging
function EconomyInfo.showSpecializationAreas()

    local map = GalaxyMap()
    map:clearCustomColors()

    map.showFactionLayer = false
    map.showCustomColorLayer = true

    local specialColors = {}
    specialColors[0] = ColorARGB(0.5, 1, 0, 0)
    specialColors[1] = ColorARGB(0.5, 1, 1, 0)
    specialColors[2] = ColorARGB(0.5, 0, 1, 0)
    specialColors[3] = ColorARGB(0.5, 0, 0, 1)

    local colors = {}
    for x = -400, -200 do
    for y = -200, 200 do
        local specialization, cx, cy = FactoryPredictor.getLocalSpecialization(x, y)

        if specialization then
            colors[ivec2(x, y)] = specialColors[specialization]
        end
    end
    end

    map:setCustomColors(colors)
end



end



function EconomyInfo.onNearbyEconomyCalculated(productions, x, y, callingPlayer)
--    local sx, sy = Sector():getCoordinates()
--    if x ~= sx or y ~= sy then return end

    if onServer() then
--        print ("onNearbyEconomyCalculated")

        local player = Player(callingPlayer)
        if player then
            invokeClientFunction(player, "onNearbyEconomyCalculated", productions, x, y)
        end
    else
        self.startAreaSupplyDemandCalculation(productions, x, y)
    end
end

function EconomyInfo.requestNearbyEconomy(x, y)

    if onClient() then
        if not todo or #todo == 0 then return end

        local coords = todo[1]
        table.remove(todo, 1)

        invokeServerFunction("requestNearbyEconomy", coords.x, coords.y)
        return
    end

--    print ("requesting %i %i", x, y)

    local code = [[
        package.path = package.path .. ";data/scripts/lib/?.lua"
        package.path = package.path .. ";data/scripts/?.lua"

        local FactoryMap = include ("factorymap")

        function run(x, y, radius)
            local map = FactoryMap()

            local from = {x = x - radius, y = y - radius}
            local to = {x = x + radius, y = y + radius}

            local productions = map:getProductionsMap(from, to)

            return productions, x, y
        end
    ]]

    async("onNearbyEconomyCalculated", code, x, y, 50)
end
callable(EconomyInfo, "requestNearbyEconomy")


