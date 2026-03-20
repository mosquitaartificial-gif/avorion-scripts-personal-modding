
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("randomext")
include ("galaxy")
include ("stringutility")
include ("faction")
include ("callable")
include ("goods")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace CargoStash
CargoStash = {}
CargoStash.interactionDistance = 20

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function CargoStash.interactionPossible(playerIndex, option)

    local player = Player(playerIndex)
    local craft = player.craft
    if not craft then return false end

    local self = Entity()
    local dist = craft:getNearestDistance(self)
    if dist < CargoStash.interactionDistance then
        return true
    end

    return false
end

function CargoStash.initialize()
    Entity():setValue("valuable_object", RarityType.Exceptional)
end

-- create all required UI elements for the client side
function CargoStash.initUI()
    ScriptUI():registerInteraction("[Open]"%_t, "onOpenPressed", 8)
end

function CargoStash.dropMoney(faction)
    local x, y = Sector():getCoordinates()
    local money = 5000 * Balancing_GetSectorRewardFactor(x, y)

    Sector():dropBundle(Entity().translationf, faction, nil, money)
end

function CargoStash.dropTradingGoods(faction)
    local x, y = Sector():getCoordinates()
    local budget = 100000 * Balancing_GetSectorRewardFactor(x, y)
    local position = Entity().translationf

    local sortedGoods = {}
    for _, good in pairs(spawnableGoods) do
        table.insert(sortedGoods, good)
    end

    function goodsByPrice(a, b) return a.price > b.price end
    table.sort(sortedGoods, goodsByPrice)

    local candidates = {}
    for _, good in pairs(sortedGoods) do
        table.insert(candidates, good)
        if #candidates >= 10 then
            break
        end
    end

    local entry = randomEntry(random(), candidates)
    local good = entry:good()

    local num = math.max(1, math.floor(budget / good.price))

    local sector = Sector()
    sector:dropCargo(position, faction, nil, good, faction.index, num)

    -- use the rest of the budget for filler cargo
    local moneyValueDropped = num * good.price
    for i = 1, 5 do
        local entry = randomEntry(sortedGoods)
        local good = entry:good()

        local num = math.floor((budget - moneyValueDropped) / good.price)
        if num >= 1 then
            sector:dropCargo(position, faction, nil, good, faction.index, num)
            moneyValueDropped = moneyValueDropped + num * good.price
        end

        if moneyValueDropped > budget then
            break
        end
    end
end

function CargoStash.onOpenPressed()
    if onClient() then
        invokeServerFunction("onOpenPressed")
        return
    end

    local receiver, ship, player = getInteractingFaction(callingPlayer)
    if not receiver then return end

    local self = Entity()
    local dist = ship:getNearestDistance(self)
    if dist > CargoStash.interactionDistance then return end

    CargoStash.dropMoney(receiver)
    CargoStash.dropTradingGoods(receiver)

    -- terminate script and remove entity from object detection
    self:setValue("valuable_object", nil)
    terminate()
end
callable(CargoStash, "onOpenPressed")
