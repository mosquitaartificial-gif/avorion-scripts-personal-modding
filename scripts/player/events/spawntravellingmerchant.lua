
package.path = package.path .. ";data/scripts/lib/?.lua"

ShipGenerator = include ("shipgenerator")
NamePool = include ("namepool")
include ("randomext")
include ("stringutility")
local SectorSpecifics = include("sectorspecifics")

local merchants = {}
table.insert(merchants, {name = "Mobile Equipment Merchant"%_T, script = "data/scripts/entity/merchants/equipmentdock.lua"})
table.insert(merchants, {name = "Mobile Resource Merchant"%_T, script = "data/scripts/entity/merchants/resourcetrader.lua"})
table.insert(merchants, {name = "Mobile Merchant"%_T, script = "data/scripts/entity/merchants/tradingpost.lua"})
table.insert(merchants, {name = "Mobile Turret Merchant"%_T, script = "data/scripts/entity/merchants/turretmerchant.lua"})
table.insert(merchants, {name = "Mobile Planetary Merchant"%_T, script = "data/scripts/entity/merchants/planetarytradingpost.lua"})

if onServer() then

function initialize()
    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())

    local eradicatedFactions = getGlobal("eradicated_factions") or {}
    if eradicatedFactions[faction.index] == true then
        terminate()
        return
    end

    -- create the merchant
    local pos = random():getDirection() * 1500
    local matrix = MatrixLookUpPosition(normalize(-pos), vec3(0, 1, 0), pos)
    local ship = ShipGenerator.createFreighterShip(faction, matrix)

    ship:invokeFunction("icon.lua", "set", nil)
    ship:removeScript("icon.lua")

    local index = random():getInt(1, #merchants)
    local merchant = merchants[index]
    local argument

    -- planetary merchant possible?
    if merchant.script == "data/scripts/entity/merchants/planetarytradingpost.lua" then
        local x, y = Sector():getCoordinates()
        local specs = SectorSpecifics(x, y, Server().seed)
        local planets = {specs:generatePlanets()}

        if #planets == 0 then
            -- choose other merchant
            while merchant.script == "data/scripts/entity/merchants/planetarytradingpost.lua" do
                index = random():getInt(1, #merchants)
                merchant = merchants[index]
            end
        else
            argument = planets[1]
        end
    end

    ship.title = merchant.name
    ship:addScript(merchant.script, argument)
    ship:addScript("data/scripts/entity/merchants/travellingmerchant.lua")
    NamePool.setShipName(ship)

    if index == 1 and math.random() < 0.5 then
        ship:invokeFunction("equipmentdock", "setStaticSeed", true)
        ship:invokeFunction("equipmentdock", "setSpecialOffer", SystemUpgradeTemplate("data/scripts/systems/teleporterkey4.lua", Rarity(RarityType.Legendary), Seed(1)), 1)
    end

    Sector():broadcastChatMessage(ship, 0, "%1% %2% here. I'll be offering my services here for the next 15 minutes! Best merchandise in the quadrant!"%_T, ship.title, ship.name)

    terminate()
end

end
