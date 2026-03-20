
package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")
include("stringutility")
local CaptainClass = include("captainclass")

local playerShip
local shipFaction
local illegal = false
local stolen = false
local suspicious = false
local dangerous = false

local availableLicenses = {}
local presentFactions = {}

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace BadCargo
BadCargo = {}

if onClient() then

function BadCargo.getUpdateInterval()
    return 3
end

function BadCargo.initialize()
    local player = Player()
    player:registerCallback("onShipChanged", "onShipChanged")
    player:registerCallback("onSectorChanged", "onSectorChanged")
    local entity = player.craft

    if valid(entity) then
        entity:registerCallback("onCargoChanged", "onCargoChanged")
        playerShip = entity.index

        BadCargo.updateShipFaction()
        shipFaction:registerCallback("onItemAdded", "onItemAdded")
        shipFaction:registerCallback("onItemRemoved", "onItemRemoved")

        BadCargo.updateAvailableLicenses()
        BadCargo.updatePresentFactions()
        BadCargo.updateCargos()
        BadCargo.updateLicenseCoverage()
    else
        playerShip = Uuid()
    end
end

function BadCargo.updateClient(timeStep)
    BadCargo.updatePresentFactions()
    BadCargo.updateCargos()
    BadCargo.updateLicenseCoverage()
end

function BadCargo.updateShipFaction()
    shipFaction = nil

    local ship = Sector():getEntity(playerShip)
    if not valid(ship) then return end

    local faction = Faction(ship.factionIndex)
    if not valid(faction) then return end

    if faction.isPlayer then
        shipFaction = Player(faction.index)
    elseif faction.isAlliance then
        shipFaction = Alliance(faction.index)
    end
end

function BadCargo.onShipChanged(playerIndex, craftIndex)
    local sector = Sector()
    local oldShip = sector:getEntity(playerShip)
    local oldFactionIndex

    if oldShip then
        oldShip:unregisterCallback("onCargoChanged", "onCargoChanged")
        oldFactionIndex = oldShip.factionIndex
    end

    playerShip = craftIndex
    local ship = sector:getEntity(craftIndex)
    if not ship then return end

    ship:registerCallback("onCargoChanged", "onCargoChanged")

    -- register to new inventory if faction index changed
    if ship.factionIndex ~= oldFactionIndex then
        local oldShipFaction = shipFaction
        BadCargo.updateShipFaction()

        if valid(oldShipFaction) then
            oldShipFaction:unregisterCallback("onItemAdded", "onItemAdded")
            oldShipFaction:unregisterCallback("onItemRemoved", "onItemRemoved")
        end

        if valid(shipFaction) then
            shipFaction:registerCallback("onItemAdded", "onItemAdded")
            shipFaction:registerCallback("onItemRemoved", "onItemRemoved")
        end

        BadCargo.updateAvailableLicenses()
    end

    BadCargo.updateCargos()
    BadCargo.updateLicenseCoverage()
end

function BadCargo.onSectorChanged()
    BadCargo.updateAvailableLicenses()
    BadCargo.updatePresentFactions()
    BadCargo.updateLicenseCoverage()
end

function BadCargo.onCargoChanged(entityIndex, delta, good)
    if delta < 0 then
        BadCargo.updateCargos()
        BadCargo.updateLicenseCoverage()
    else
        BadCargo.updateSingleCargo(good)
        BadCargo.updateLicenseCoverage()
    end
end

function BadCargo.onItemAdded(item, index, amount, amountBefore, tagsChanged)
    BadCargo.updateSingleLicense(shipFaction:getInventory():find(index))
    BadCargo.updateLicenseCoverage()
end

function BadCargo.onItemRemoved(item, index, amount, amountBefore, tagsChanged)
    BadCargo.updateAvailableLicenses()
    BadCargo.updateLicenseCoverage()
end

function BadCargo.updateCargos()
    illegal = false
    stolen = false
    suspicious = false
    dangerous = false

    local entity = Entity(playerShip)
    if not entity then return end
    if not entity:hasComponent(ComponentType.CargoBay) then return end

    for tradingGood, _ in pairs(entity:getCargos()) do
        if tradingGood.illegal then illegal = true end
        if tradingGood.stolen then stolen = true end
        if tradingGood.suspicious then suspicious = true end
        if tradingGood.dangerous then dangerous = true end
    end
end

function BadCargo.updateLicenseCoverage()
    local covered = BadCargo.checkLicenseCoverage()

    if covered or (not illegal and not stolen and not suspicious and not dangerous) or tablelength(presentFactions) == 0 then
        removeShipProblem("BadTradingGood", playerShip)
        return
    end

    local status = ""
    local color
    local icon = "data/textures/icons/crate.png"
    if not covered then
        local isDetectionPrevented, preventionDescription, preventionIcon, preventionColor = BadCargo.getDetectionPrevention()
        if isDetectionPrevented then
            status = preventionDescription
            color = preventionColor
            icon = preventionIcon or icon
        else
            status = "You might get in trouble if you don't get a transportation license."%_t
            color = ColorRGB(1, 0, 0)
        end
    end

    addShipProblem("BadTradingGood", playerShip, BadCargo.getBadCargosString() .. "\n" .. status, icon, color)
end

function BadCargo.getDetectionPrevention()
    local craft = Player().craft
    if not craft then return false end

    if craft:hasScript("internal/dlc/blackmarket/entity/utility/preventcargodetection.lua") then
        local ret, description, icon = craft:invokeFunction("internal/dlc/blackmarket/entity/utility/preventcargodetection.lua", "getDescription")
        if ret == 0 then
            return true, description, icon, ColorRGB(1, 1, 0)
        end
    end

    if craft:hasScript("internal/dlc/blackmarket/systems/cargodetectionscrambler.lua") then
        return true, "You can use your scrambler in an inspection."%_t
    end

    return false
end

function BadCargo.detectScrambler()
    local craft = Player().craft
    if not craft then return false, false end

    if craft:hasScript("internal/dlc/blackmarket/entity/utility/preventcargodetection.lua") then
        return true, false
    end

    if craft:hasScript("internal/dlc/blackmarket/systems/cargodetectionscrambler.lua") then
        return false, true
    end
end

function BadCargo.updateSingleCargo(tradingGood)
    if not tradingGood then return end

    if tradingGood.illegal then illegal = true end
    if tradingGood.stolen then stolen = true end
    if tradingGood.suspicious then suspicious = true end
    if tradingGood.dangerous then dangerous = true end
end

function BadCargo.updateAvailableLicenses()
    availableLicenses = {}

    if not valid(shipFaction) then return end

    local vanillaItems = shipFaction:getInventory():getItemsByType(InventoryItemType.VanillaItem)
    for _, p in pairs(vanillaItems) do
        local item = p.item

        if item:getValue("isCargoLicense") == true then
            local faction = item:getValue("faction")

            local currentLevel = availableLicenses[faction]
            if currentLevel == nil or item.rarity.value > currentLevel then
                availableLicenses[faction] = item.rarity.value
            end
        end
    end
end

function BadCargo.updateSingleLicense(item)
    if item.itemType ~= InventoryItemType.VanillaItem then return end
    if not item:getValue("isCargoLicense") then return end

    local faction = item:getValue("faction")

    local currentLevel = availableLicenses[faction]
    if currentLevel == nil or item.rarity.value > currentLevel then
        availableLicenses[faction] = item.rarity.value
    end
end

function BadCargo.getBadCargosString()
    local problems = {}

    -- ordered from lowest to highest level
    if dangerous then table.insert(problems, "dangerous /* used in a sentence like 'you have dangerous[, suspicious[ and illegal]] goods in your cargo bay' */"%_t) end
    if suspicious then table.insert(problems, "suspicious /* used in a sentence like 'you have dangerous[, suspicious[ and illegal]] goods in your cargo bay' */"%_t) end
    if stolen then table.insert(problems, "stolen /* used in a sentence like 'you have dangerous[, suspicious[ and illegal]] goods in your cargo bay' */"%_t) end
    if illegal then table.insert(problems, "illegal /* used in a sentence like 'you have dangerous[, suspicious[ and illegal]] goods in your cargo bay' */"%_t) end

    return string.format("You have %s goods in your cargo bay!"%_t, enumerate(problems))
end

function BadCargo.updatePresentFactions()
    presentFactions = {}
    for _, entity in pairs({Sector():getEntitiesByScript("data/scripts/entity/antismuggle.lua")}) do
        presentFactions[entity.factionIndex] = true
    end

    local x, y = Sector():getCoordinates()
    local controllerIndex = Galaxy():getControllingFaction(x, y)

    if controllerIndex and controllerIndex >= 2000000 then
        presentFactions[controllerIndex] = true
    end

end

function BadCargo.checkLicenseCoverage()
    local requiredLevel = -1
    if dangerous then requiredLevel = 0 end
    if suspicious then requiredLevel = 1 end
    if stolen then requiredLevel = 2 end
    if illegal then requiredLevel = 3 end

    local player = Player()
    craft = player.craft
    if not craft then return end

    local captain = craft:getCaptain()
    if captain then
        if captain:hasClass(CaptainClass.Smuggler) then return true end
        if requiredLevel <= 1 and captain:hasClass(CaptainClass.Merchant) then return true end
    end

    for faction, _ in pairs(presentFactions) do

        if valid(shipFaction) then -- might not yet be there on load
            local relation = shipFaction:getRelation(faction)
            if valid(relation) then
                if relation.status == RelationStatus.Allies then goto continue end
                if relation.level >= 80000 and requiredLevel == 0 then goto continue end
            end
        end

        if not availableLicenses[faction] then
            return false
        end

        if availableLicenses[faction] < requiredLevel then
            return false
        end

        ::continue::
    end

    return true
end

end
