package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("utility")
include("goods")
include("productions")
include("randomext")
local SectorSpecifics = include("sectorspecifics")
local ConsumerGoods = include("consumergoods")
local FactoryPredictor = include("factorypredictor")

--[[
 ---# TODO #---

 ---# DONE \o/ #---
# Use Cases:
- Auslesen von zukünftigen Fabriken
- Auslesen von aktuellen Fabriken
- Veränderung von aktuellen Fabriken
- Auslesen von nahen, aktuellen und zukünftigen Fabriken
- Auslesen von Nachfrage vs. Angebot

# Anforderungen:
- Deterministische Vorhersage von Fabriken auf Basis von:
-- Server Seed
-- Koordinaten
-- Sector Specifics
- Filtern von leeren Sektoren
- Filtern von Sektoren ohne Fabriken
- Regelmäßig Aktualisierung der aktuellen Verhältnisse
- Speicherung der aktuellen Verhältnisse
- Deterministische Vorhersage von Fabrik-Spezialisierung

]]

local assert = assert
local FactoryMap = {}
FactoryMap.__index = FactoryMap

local sectorSpecifics = SectorSpecifics()
local influenceRadius = 25 -- sectors within this distance are influenced by nearby factories

local SupplyType =
{
    FactorySupply = 1,
    FactoryDemand = 2,
    FactoryGarbage = 3,
    Consumer = 4,
    Seller = 5,
}

local SupplyInfluence = {}
SupplyInfluence[SupplyType.FactorySupply] = 10
SupplyInfluence[SupplyType.FactoryDemand] = -10
SupplyInfluence[SupplyType.FactoryGarbage] = 4
SupplyInfluence[SupplyType.Consumer] = -3
SupplyInfluence[SupplyType.Seller] = 3


local function new()

    local instance = setmetatable({}, FactoryMap)
    instance:initialize()
    instance.SupplyType = SupplyType
    instance.SupplyInfluence = SupplyInfluence
    instance.influenceRadius = influenceRadius

    return instance
end

function FactoryMap:supplyToPriceChange(supply)
    if supply == 0 then return 0 end

    supply = -supply
    if supply < 0 then return -self:supplyToPriceChange(supply) end

    if supply >= 75 then return 0.30 end
    if supply >= 50 then return lerp(supply, 50, 75, 0.25, 0.30) end
    if supply >= 25 then return lerp(supply, 25, 50, 0.175, 0.25) end
    if supply >= 12.5 then return lerp(supply, 12.5, 25, 0.125, 0.175) end
    if supply >= 5 then return lerp(supply, 5, 12.5, 0.075, 0.125) end

    return lerp(supply, 0, 5, 0.05, 0.075)
end

function FactoryMap:getSupplyDemandGradients()
    local lower = {
        vec3(94, 79, 162) / 255,
        vec3(73, 105, 174) / 255,
        vec3(54, 130, 186) / 255,
        vec3(71, 159, 179) / 255,
        vec3(89, 180, 170) / 255,
        vec3(142, 209, 164) / 255,
        vec3(183, 226, 161) / 255,
        vec3(230, 245, 152) / 255,
        vec3(244, 250, 174) / 255,
        vec3(255, 255, 190) / 255,
    }
    local upper = {
        vec3(255, 255, 190) / 255,
        vec3(254, 239, 140) / 255,
        vec3(253, 220, 80) / 255,
        vec3(253, 192, 40) / 255,
        vec3(250, 152, 0) / 255,
        vec3(245, 116, 0) / 255,
        vec3(228, 85, 0) / 255,
        vec3(194, 41, 0) / 255,
        vec3(158, 0, 0) / 255,
    }
    return lower, upper
end

function FactoryMap:getPriceGradients()
    local lower = {vec3(0.3, 0, 0.3), vec3(0.4, 0, 1), vec3(0, 0.7, 1), vec3(0, 1, 1), vec3(0.5, 1, 1), vec3(0, 0.5, 0)}
    local upper = {vec3(1, 1, 0.75), vec3(1, 1, 0.4), vec3(1, 1, 0),  vec3(1, 0.3, 0), vec3(0.6, 0, 0), }

    return lower, upper
end


function FactoryMap:initialize()
    self.seed = GameSeed()

    self.productionScripts = {
        "data/scripts/entity/merchants/factory.lua"
    }
    self.consumerScripts = {
        "data/scripts/entity/merchants/consumer.lua",
        "data/scripts/entity/merchants/habitat.lua",
        "data/scripts/entity/merchants/biotope.lua",
        "data/scripts/entity/merchants/casino.lua",
    }
    self.sellerScripts = {
        "data/scripts/entity/merchants/seller.lua",
--        "data/scripts/entity/merchants/turretfactoryseller.lua", -- turret factories are ignored since they're randomized and only "count" for needs of turret builders
    }

end

function FactoryMap:makeKey(x, y)
    return "factory_map_" .. tostring(x) .. "_" .. tostring(y)
end

function FactoryMap:refreshCurrentSector()
    local sector = Sector()
    local x, y = sector:getCoordinates()

    -- find all productions
    local productions = {}
    for _, script in pairs(self.productionScripts) do
        local factories = {sector:getEntitiesByScript(script)}

        for _, factory in pairs(factories) do
--            print ("factory: " .. factory.translatedTitle)

            local ok, production = factory:invokeFunction(script, "getProduction")
            if ok == 0 and production then
                production.id = factory.id.string
                table.insert(productions, production)
            else
                print ("error: " .. tostring(ok) .. ", " .. tostring(production))
            end
        end
    end

    -- find all consumptions
    local consumptions = {}
    for _, script in pairs(self.consumerScripts) do
        local consumers = {sector:getEntitiesByScript(script)}

        for _, consumer in pairs(consumers) do
--            print ("consumer: " .. consumer.translatedTitle)

            local ok, consumedGoods = consumer:invokeFunction(script, "getConsumedGoods")
            if ok == 0 and consumedGoods then
                table.insert(consumptions, {id = consumer.id.string, goods = consumedGoods})
            else
                print ("error: " .. tostring(ok) .. ", " .. tostring(consumedGoods))
            end
        end
    end

    -- find all sold goods
    local sold = {}
    for _, script in pairs(self.sellerScripts) do
        local sellers = {sector:getEntitiesByScript(script)}

        for _, seller in pairs(sellers) do
--            print ("seller: " .. seller.translatedTitle)

            local ok, soldGoods = seller:invokeFunction(script, "getSellableGoods")
            if ok == 0 and soldGoods then
                table.insert(sold, {id = seller.id.string, goods = soldGoods})
            else
                print ("error: " .. tostring(ok) .. ", " .. tostring(soldGoods))
            end
        end
    end

    if #productions == 0 then productions = nil end
    if #consumptions == 0 then consumptions = nil end
    if #sold == 0 then sold = nil end

    local data = {consumptions = consumptions, sold = sold, productions = productions}

    -- instead of empty tables, just reset to nothing to save memory
    if not productions and not consumptions and not sold then data = nil end

    setGlobal(self:makeKey(x, y), data)
end

function FactoryMap:getProductionsMap(from, to)
    local result = {}

    for x = from.x, to.x do
        for y = from.y, to.y do
            local data = self:getData(x, y)
            if data and (data.productions or data.consumptions or data.sold) then
                result[#result + 1] = {coordinates = {x=x, y=y}, data = data}
            end
        end
    end

    return result
end

function FactoryMap:getSupplyAndDemand(x, y, productions)
    local supply = {}
    local demand = {}
    local sum = {}

    productions = productions or self:getProductionsMap({x = x - influenceRadius, y = y - influenceRadius}, {x = x + influenceRadius, y = y + influenceRadius})

    local radius2 = influenceRadius * influenceRadius
    local consumerRadius2 = radius2 * 0.25
    for _, data in pairs(productions) do

        -- is it in range?
        local coords = data.coordinates

        local dx = x - coords.x
        local dy = y - coords.y
        local d2 = dx * dx + dy * dy

        if d2 > radius2 then goto continue end

        local distance = math.sqrt(d2)
        local factor
        if distance < influenceRadius * 0.85 then
            factor = lerp(distance, 0, influenceRadius * 0.85, 1.25, 0.4)
        else
            factor = lerp(distance, influenceRadius * 0.85, influenceRadius, 0.4, 0.1)
        end

        -- add up productions
        if data.data.productions then
            for _, production in pairs(data.data.productions) do
                for _, good in pairs(production.ingredients) do
                    if good.optional == 0 then
                        demand[good.name] = (demand[good.name] or 0) + -SupplyInfluence[SupplyType.FactoryDemand] * factor
                    end
                end
                for _, good in pairs(production.results) do
                    supply[good.name] = (supply[good.name] or 0) + SupplyInfluence[SupplyType.FactorySupply] * factor
                end
                for _, good in pairs(production.garbages) do
                    supply[good.name] = (supply[good.name] or 0) + SupplyInfluence[SupplyType.FactoryGarbage] * factor
                end
            end
        end

        if d2 <= consumerRadius2 then
            local factor = lerp(distance, 0, influenceRadius * 0.5, 1.0, 0.0)

            if data.data.consumptions then
                for _, consumption in pairs(data.data.consumptions) do
                    for _, name in pairs(consumption.goods) do
                        demand[name] = (demand[name] or 0) + -SupplyInfluence[SupplyType.Consumer] * factor
                    end
                end
            end

            if data.data.sold then
                for _, sold in pairs(data.data.sold) do
                    for _, name in pairs(sold.goods) do
                        supply[name] = (supply[name] or 0) + SupplyInfluence[SupplyType.Seller] * factor
                    end
                end
            end
        end

        ::continue::
    end

    for good, value in pairs(supply) do
        sum[good] = value
    end

    for good, value in pairs(demand) do
        sum[good] = (sum[good] or 0) - value
    end

    return supply, demand, sum
end

function FactoryMap:getAreaSupplyAndDemand(lower, upper)
    local sx, sy = upper.x - lower.x, upper.y - lower.y
    sx = math.ceil(sx / 2)
    sy = math.ceil(sy / 2)

    local productions = self:getProductionsMap({x = lower.x - influenceRadius, y = lower.y - influenceRadius}, {x = upper.x + influenceRadius, y = upper.y + influenceRadius})
    local result = {}

    for cx = lower.x, upper.x do
        for cy = lower.y, upper.y do

            -- gather supply and demand for the sector in question
            local supply, demand, sum = self:getSupplyAndDemand(cx, cy, productions)

            if next(supply) ~= nil or next(demand) ~= nil or next(sum) ~= nil then
                table.insert(result, {coordinates = {x = cx, y = cy}, supply = supply, demand = demand, sum = sum})
            end

            ::continue::
        end
    end

    return result
end

function FactoryMap:getData(x, y)
    local key = self:makeKey(x, y)

    local data = getGlobal(key)
    if data then
        return data
    end

    return self:predictData(x, y)
end

function FactoryMap:predictData(x, y)

    local regular, offgrid, dust = sectorSpecifics.determineFastContent(x, y, self.seed)
    if not regular and not offgrid then return end

    sectorSpecifics:initialize(x, y, self.seed)

    if not sectorSpecifics.regular then return end
    if not sectorSpecifics.generationTemplate then return end

    local data = {}
    local contents = sectorSpecifics.generationTemplate.contents(x, y)
    data.productions = self:predictProductions(x, y, contents)
    data.consumptions = self:predictConsumptions(x, y, contents)
    data.sold = self:predictSellers(x, y, contents)

    return data
end

function FactoryMap:predictConsumptions(x, y, contents)

    local habitats = contents.habitats or 0
    local biotopes = contents.biotopes or 0
    local casinos = contents.casinos or 0
    local equipmentDocks = contents.equipmentDocks or 0
    local shipyards = contents.shipyards or 0
    local repairDocks = contents.repairDocks or 0
    local militaryOutposts = contents.militaryOutposts or 0
    local researchStations = contents.researchStations or 0
    local travelHubs = contents.travelHubs or 0
    local mines = contents.mines or 0

    local consumptions = {}

    for i = 1, habitats do
        table.insert(consumptions, {goods = ConsumerGoods.Habitat()})
    end
    for i = 1, biotopes do
        table.insert(consumptions, {goods = ConsumerGoods.Biotope()})
    end
    for i = 1, casinos do
        table.insert(consumptions, {goods = ConsumerGoods.Casino()})
    end
    for i = 1, equipmentDocks do
        table.insert(consumptions, {goods = ConsumerGoods.EquipmentDock()})
    end
    for i = 1, shipyards do
        table.insert(consumptions, {goods = ConsumerGoods.Shipyard()})
    end
    for i = 1, repairDocks do
        table.insert(consumptions, {goods = ConsumerGoods.RepairDock()})
    end
    for i = 1, militaryOutposts do
        table.insert(consumptions, {goods = ConsumerGoods.MilitaryOutpost()})
    end
    for i = 1, researchStations do
        table.insert(consumptions, {goods = ConsumerGoods.ResearchStation()})
    end
    for i = 1, travelHubs do
        table.insert(consumptions, {goods = ConsumerGoods.TravelHub()})
    end
    for i = 1, mines do
        table.insert(consumptions, {goods = ConsumerGoods.Mine()})
    end

    if #consumptions == 0 then return nil end

    return consumptions
end

function FactoryMap:predictSellers(x, y, contents)

    local turretFactories = contents.turretFactories or 0
    local turretFactorySuppliers = contents.turretFactorySuppliers or 0

    local consumptions = {}

    -- ignore turret factories and their suppliers due to massively inflated price and randomized selection
--    for i = 1, turretFactories do
--        table.insert(consumptions, {goods = ConsumerGoods.TurretFactory()})
--    end

    if #consumptions == 0 then return nil end

    return consumptions
end

function FactoryMap:predictProductions(x, y, contents)

    local factories = contents.factories or 0
    local mines = contents.mines or 0

    if factories == 0 and mines == 0 then return {} end

    local totalProductions = {}
    if factories > 0 then
        totalProductions = FactoryPredictor.generateFactoryProductions(x, y, factories)
    end

    if mines > 0 then
        local mineProductions = FactoryPredictor.generateMineProductions(x, y, mines)
        for _, mine in pairs(mineProductions) do
            table.insert(totalProductions, mine)
        end
    end

    if #totalProductions == 0 then return nil end

    return totalProductions
end


return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
