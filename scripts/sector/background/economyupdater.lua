
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("callable")
local FactoryMap = include("factorymap")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace EconomyUpdater
EconomyUpdater = {}
local self = EconomyUpdater
self.supply = nil
self.demand = nil
self.sum = nil
self.waitingForRefresh = false

function EconomyUpdater.getUpdateInterval()
    if onClient() and not self.supply and not self.demand and not self.sum then
        return 5
    end

    return 300
end

function EconomyUpdater.initialize()
    self.map = FactoryMap()

    if onServer() then
        self.refresh()
        Sector():registerCallback("onEntityCreated", "onEntityCreated")
    end

    if onClient() then
        EconomyUpdater.requestData()
    end
end

function EconomyUpdater.updateClient(timeStep)
    if not self.supply and not self.demand and not self.sum then
        EconomyUpdater.requestData()
    end
end

function EconomyUpdater.updateServer(timeStep)
    self.refresh()
end

function EconomyUpdater.onEntityCreated(id)
    local entity = Entity(id)
    if not entity then return end

    if entity.type == EntityType.Station then
        self.scheduleRefresh()
    end
end

function EconomyUpdater.scheduleRefresh()
    if self.waitingForRefresh then return end
    self.waitingForRefresh = true

    deferredCallback(5, "deferredRefresh")
end

function EconomyUpdater.deferredRefresh()
    self.waitingForRefresh = false
    self.refresh()
end

function EconomyUpdater.refresh()
    self.map:refreshCurrentSector()

    local code = [[
    package.path = package.path .. ";data/scripts/lib/?.lua"
    package.path = package.path .. ";data/scripts/?.lua"

    local FactoryMap = include("factorymap")

    function run(x, y)
        local map = FactoryMap()
        local supply, demand, sum = map:getSupplyAndDemand(x, y)
        return supply, demand, sum
    end
    ]]

    local x, y = Sector():getCoordinates()
    async("onEconomyRefreshDone", code, x, y)
end

function EconomyUpdater.immediateRefresh()
    self.map:refreshCurrentSector()

    local x, y = Sector():getCoordinates()
    local supply, demand, sum = self.map:getSupplyAndDemand(x, y)
    self.supply = supply
    self.demand = demand
    self.sum = sum
end

function EconomyUpdater.onEconomyRefreshDone(supply, demand, sum)
    self.supply = supply
    self.demand = demand
    self.sum = sum

    broadcastInvokeClientFunction("setData", self.supply, self.demand)
end

function EconomyUpdater.requestData()
    if onClient() then
        invokeServerFunction("requestData")
        return
    end

    if callingPlayer and self.supply and self.demand then
        invokeClientFunction(Player(callingPlayer), "setData", self.supply, self.demand)
    end
end
callable(EconomyUpdater, "requestData")

function EconomyUpdater.setData(supply, demand)
    self.supply = supply or {}
    self.demand = demand or {}
    self.sum = {}

    local sum = self.sum
    for good, value in pairs(supply) do
        sum[good] = value
    end

    for good, value in pairs(demand) do
        sum[good] = (sum[good] or 0) - value
    end
end

function EconomyUpdater.getSupplyDemandPriceChange(good, ownSupplyType)
    if not self.sum then return 0 end

    local sum = self.sum[good]
    if not sum then return 0 end


    if ownSupplyType then
        local influence = self.map.SupplyInfluence[ownSupplyType] or 0
        if ownSupplyType == self.map.SupplyType.FactorySupply
                or ownSupplyType == self.map.SupplyType.FactoryDemand then
            influence = influence * 1.25
        end

        sum = sum - influence
    end

    return self.map:supplyToPriceChange(sum) or 0
end
