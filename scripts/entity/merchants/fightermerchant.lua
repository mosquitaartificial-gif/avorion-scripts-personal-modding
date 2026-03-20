package.path = package.path .. ";data/scripts/lib/?.lua"
include ("galaxy")
include ("utility")
include ("randomext")
include ("faction")
include ("sellableinventoryitem")
include ("stringutility")
local SectorFighterGenerator = include("sectorfightergenerator")
local Dialog = include("dialogutility")
local ShopAPI = include ("shop")
local SellableFighter = include ("sellablefighter")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace FighterMerchant
FighterMerchant = {}
FighterMerchant = ShopAPI.CreateNamespace()

FighterMerchant.interactionThreshold = -30000

-- if this function returns false, the script will not be listed in the interaction window on the client,
-- even though its UI may be registered
function FighterMerchant.interactionPossible(playerIndex, option)
    local player = Player(playerIndex)
    local ship = player.craft
    if not ship then return false end
    if not ship:hasComponent(ComponentType.Hangar) then return false end

    return CheckFactionInteraction(playerIndex, FighterMerchant.interactionThreshold)
end

local function comp(a, b)
    local ta = a.fighter;
    local tb = b.fighter;

    if ta.type == tb.type then
        if ta.rarity.value == tb.rarity.value then
            if ta.material.value == tb.material.value then
                return ta.weaponPrefix < tb.weaponPrefix
            else
                return ta.material.value > tb.material.value
            end
        else
            return ta.rarity.value > tb.rarity.value
        end
    else
        return ta.type < tb.type
    end
end

function FighterMerchant.shop:addItems()

    local station = Entity()

    if station.title == "" then
        station.title = "Fighter Merchant"%_t
    end

    -- create all fighters
    local allFighters = {}

    local generator = SectorFighterGenerator()
    for i = 1, 9 do
        local x, y = Sector():getCoordinates()
        local fighter = generator:generate(x, y)

        local pair = {}
        pair.fighter = fighter
        pair.amount = 5

        if fighter.rarity.value == RarityType.Exceptional then
            pair.amount = getInt(5, 8)
        elseif fighter.rarity.value == RarityType.Rare then
            pair.amount = getInt(8, 10)
        elseif fighter.rarity.value == RarityType.Uncommon then
            pair.amount = getInt(8, 12)
        elseif fighter.rarity.value == RarityType.Common then
            pair.amount = getInt(8, 12)
        end

        table.insert(allFighters, pair)
    end

    for i = 1, 3 do
        local fighter = generator:generateCrewShuttle(Sector():getCoordinates())

        local pair = {}
        pair.fighter = fighter
        pair.amount = getInt(8, 12)

        table.insert(allFighters, pair)
    end

    table.sort(allFighters, comp)

    for _, pair in pairs(allFighters) do
        FighterMerchant.shop:add(pair.fighter, pair.amount)
    end
end

-- sets the special offer that gets updated every 20 minutes
function FighterMerchant.shop:onSpecialOfferSeedChanged()
    local generator = SectorFighterGenerator(FighterMerchant.shop:generateSeed())

    local x, y = Sector():getCoordinates()
    local rarities = generator:getSectorRarityDistribution(x, y)

    rarities[-1] = 0
    rarities[0] = 0
    rarities[1] = 0
    rarities[4] = rarities[4] * 0.25 -- strongly reduced probability for normal high rarity equipment
    rarities[5] = 0 -- no legendaries in equipment dock

    generator.rarities = rarities

    local specialFighter = generator:generate(Sector():getCoordinates())

    local amount = getInt(4, 6)

    FighterMerchant.shop:setSpecialOffer(specialFighter, amount)
end

function FighterMerchant.onShowWindow()
    if FighterMerchant.getShowTab() then
        FighterMerchant.shop.tabbedWindow:activateTab(FighterMerchant.shop.buyTab)
    else
        FighterMerchant.shop.tabbedWindow:deactivateTab(FighterMerchant.shop.buyTab)
    end
end

function FighterMerchant.getShowTab()
    local hangar = Hangar(Player().craft)
    if hangar and hangar.space > 0 then return true end

    local x, y = Sector():getCoordinates()
    local probability = Balancing_GetSingleMaterialProbability(x, y, MaterialType.Trinium)

    return probability > 0
end

function FighterMerchant.initialize()
    FighterMerchant.shop:initialize("Fighter Merchant"%_t)

    if onClient() and EntityIcon().icon == "" then
        EntityIcon().icon = "data/textures/icons/pixel/fighter.png"
    end
end

function FighterMerchant.initUI()
    FighterMerchant.shop:initUI("Trade Equipment"%_t, "Fighter Merchant"%_t, "Fighters"%_t, "data/textures/icons/bag_fighter.png")
end

FighterMerchant.shop.ItemWrapper = SellableFighter
FighterMerchant.shop.SortFunction = comp



