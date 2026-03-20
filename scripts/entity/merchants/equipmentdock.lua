package.path = package.path .. ";data/scripts/lib/?.lua"
include ("utility")
include ("randomext")
include ("faction")
local ShopAPI = include ("shop")
local UpgradeGenerator = include("upgradegenerator")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace EquipmentDock
EquipmentDock = {}
EquipmentDock = ShopAPI.CreateNamespace()

EquipmentDock.rarityFactors = {}

EquipmentDock.rarityFactors[-1] = 1.0
EquipmentDock.rarityFactors[0] = 1.0
EquipmentDock.rarityFactors[1] = 1.0
EquipmentDock.rarityFactors[2] = 1.0
EquipmentDock.rarityFactors[3] = 1.0
EquipmentDock.rarityFactors[4] = 0.25   -- strongly reduced probability for normal high rarity equipment
EquipmentDock.rarityFactors[5] = 0      -- no legendaries in equipment dock

EquipmentDock.specialOfferRarityFactors = {}
EquipmentDock.specialOfferRarityFactors[-1] = 0.0
EquipmentDock.specialOfferRarityFactors[0] = 0.0
EquipmentDock.specialOfferRarityFactors[1] = 0.0
EquipmentDock.specialOfferRarityFactors[2] = 1.0
EquipmentDock.specialOfferRarityFactors[3] = 1.0
EquipmentDock.specialOfferRarityFactors[4] = 0.25
EquipmentDock.specialOfferRarityFactors[5] = 0.0

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function EquipmentDock.interactionPossible(playerIndex, option)
    return CheckFactionInteraction(playerIndex, -10000)
end

local function sortSystems(a, b)
    if a.rarity.value == b.rarity.value then
        if a.script == b.script then
            return a.price > b.price
        else
            return a.script < b.script
        end
    end

    return a.rarity.value > b.rarity.value
end

function EquipmentDock.shop:addItems()

    local systems = {}
    EquipmentDock.addStaticOffers(systems)

    local generator = UpgradeGenerator()
    local x, y = Sector():getCoordinates()
    local rarities = generator:getSectorRarityDistribution(x, y)

    for i, rarity in pairs(rarities) do
        rarities[i] = rarity * EquipmentDock.rarityFactors[i] or 1
    end

    local counter = 0
    while counter < 9 do
        local prototype = generator:generateSectorSystem(x, y, nil, rarities)

        local script = prototype.script
        local rarity = prototype.rarity
        local seed = generator:getUpgradeSeed(x, y, script, rarity)

        local system = SystemUpgradeTemplate(script, rarity, seed)

        -- only add "petty" upgrades with a 25% chance
        if system.rarity.value >= 0 or random():test(0.25) then
            table.insert(systems, system)
            counter = counter + 1
        end
    end

    table.sort(systems, sortSystems)

-- MOS --

    for _, system in pairs(systems) do
        EquipmentDock.shop:add(system, getInt(1, 2))
    end

-- MOS --

end

-- adds most commonly used upgrades
function EquipmentDock.addStaticOffers(systems)

    if not systems then return end

    local rarities = {RarityType.Common, RarityType.Uncommon}
    local rand = random()
    local possible =
    {
        "data/scripts/systems/arbitrarytcs.lua",
        "data/scripts/systems/energybooster.lua",
        "data/scripts/systems/hyperspacebooster.lua",
        "data/scripts/systems/radarbooster.lua",
        "data/scripts/systems/tradingoverview.lua",
    }

    for _, script in pairs(possible) do
        local rarity = randomEntry(rand, rarities)
        table.insert(systems, SystemUpgradeTemplate(script, Rarity(rarity), rand:createSeed()))
    end
end

-- sets the special offer that gets updated every 20 minutes
function EquipmentDock.shop:onSpecialOfferSeedChanged()
    local generator = UpgradeGenerator(EquipmentDock.shop:generateSeed())

    local x, y = Sector():getCoordinates()
    local rarities = generator:getSectorRarityDistribution(x, y)

    for i, rarity in pairs(rarities) do
        rarities[i] = rarity * EquipmentDock.specialOfferRarityFactors[i] or 1
    end

    local prototype = generator:generateSystem(nil, rarities)

    local script = prototype.script
    local rarity = prototype.rarity
    local seed = generator:getUpgradeSeed(x, y, script, rarity)

    EquipmentDock.shop:setSpecialOffer(SystemUpgradeTemplate(script, rarity, seed))
end

function EquipmentDock.initialize()

    local station = Entity()
    if station.title == "" then
        station.title = "Equipment Dock"%_t
    end

    EquipmentDock.shop:initialize(station.translatedTitle)

    if onClient() and EntityIcon().icon == "" then
        EntityIcon().icon = "data/textures/icons/pixel/sdwhite.png"
    end

    Entity():setValue("remove_permanent_upgrades", true)
end

function EquipmentDock.initUI()
    local station = Entity()
    EquipmentDock.shop:initUI("Trade Equipment"%_t, station.translatedTitle, "Subsystems"%_t, "data/textures/icons/bag_circuitry.png")
end

function EquipmentDock.initializationFinished()
    -- use the initilizationFinished() function on the client since in initialize() we may not be able to access Sector scripts on the client
    if onClient() then
        local ok, r = Sector():invokeFunction("radiochatter", "addSpecificLines", Entity().id.string,
        {
            "That's sold out, sorry."%_t,
            "Problems with pirates? No more with our weaponry!"%_t,
            "Equipment of all sorts, for a great price! No refunds."%_t,
            "No refunds."%_t,
            "Guns Guns Guns!"%_t,
            "Buy turrets! Your crew will thank you for it!"%_t,
            "Only the best turrets, subsystems and fighters!"%_t,
            "Show the Xsotan who's boss with our chain guns!"%_t,
            "Not enough resources? Get a mining laser and change that!"%_t,
            "Tired of being chronically unarmed? We're here for you!"%_t,
            "Our fighters are ready for you! Pilots not included."%_t,
            "Pilots not included."%_t,
            "Gunners not included."%_t,
        })
    end
end
