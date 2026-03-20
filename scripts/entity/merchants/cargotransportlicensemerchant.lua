package.path = package.path .. ";data/scripts/lib/?.lua"
include ("utility")
include ("randomext")
include ("faction")
local ShopAPI = include ("shop")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace CargoTransportLicenseMerchant
CargoTransportLicenseMerchant = {}
CargoTransportLicenseMerchant = ShopAPI.CreateNamespace()

CargoTransportLicenseMerchant.interactionThreshold = 30000

local isInitialized = false

local function getNameByRarity(rarity)
    if rarity.value == 0 then
        return "Dangerous Cargo Transport License"%_t
    elseif rarity.value == 1 then
        return "Suspicious Cargo Transport License"%_t
    elseif rarity.value == 2 then
        return "Stolen Cargo Transport License"%_t
    elseif rarity.value == 3 then
        return "Illegal Cargo Transport License"%_t
    end
end

local function makeLicenseTooltip(item)
    local tooltip = Tooltip()

    tooltip.icon = item.icon
    tooltip.rarity = item.rarity

    local factionIndex = item:getValue("faction")
    local name = Faction(factionIndex).name

    local title = getNameByRarity(item.rarity)
    local description1 = "License for transporting special cargo"%_t
    local description2 = "Only valid in designated territory"%_t

    local headLineSize = 25
    local headLineFont = 15
    local line = TooltipLine(headLineSize, headLineFont)
    line.ctext = title
    line.ccolor = item.rarity.tooltipFontColor
    tooltip:addLine(line)
    tooltip:addLine(TooltipLine(18, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Dangerous Cargo"%_t
    line.rtext = "Yes"%_t
    line.rcolor = ColorRGB(0.3, 1.0, 0.3)
    line.icon = "data/textures/icons/crate.png"
    line.iconColor = ColorRGB(1.0, 1.0, 0.3)
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "Suspicious Cargo"%_t
    line.icon = "data/textures/icons/crate.png"
    line.iconColor = ColorRGB(1.0, 1.0, 0.3)
    if item.rarity.value >= 1 then
        line.rtext = "Yes"%_t
        line.rcolor = ColorRGB(0.3, 1.0, 0.3)
    else
        line.rtext = "No"%_t
        line.rcolor = ColorRGB(1.0, 0.3, 0.3)
    end
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "Stolen Cargo"%_t
    line.icon = "data/textures/icons/crate.png"
    line.iconColor = ColorRGB(1.0, 0.3, 1.0)
    if item.rarity.value >= 2 then
        line.rtext = "Yes"%_t
        line.rcolor = ColorRGB(0.3, 1.0, 0.3)
    else
        line.rtext = "No"%_t
        line.rcolor = ColorRGB(1.0, 0.3, 0.3)
    end
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "Illegal Cargo"%_t
    line.icon = "data/textures/icons/crate.png"
    line.iconColor = ColorRGB(1.0, 0.3, 0.3)
    if item.rarity.value >= 3 then
        line.rtext = "Yes"%_t
        line.rcolor = ColorRGB(0.3, 1.0, 0.3)
    else
        line.rtext = "No"%_t
        line.rcolor = ColorRGB(1.0, 0.3, 0.3)
    end
    tooltip:addLine(line)

    tooltip:addLine(TooltipLine(18, 14))


    local line = TooltipLine(18, 14)
    line.ltext = "Territory"%_t
    line.rtext = "${faction:" .. tostring(factionIndex) .. "}"
    tooltip:addLine(line)

    tooltip:addLine(TooltipLine(18, 14))
    tooltip:addLine(TooltipLine(18, 14))

    local dLine1 = TooltipLine(18, 14)
    dLine1.ltext = description1
    tooltip:addLine(dLine1)

    local dLine2 = TooltipLine(18, 14)
    dLine2.ltext = description2
    tooltip:addLine(dLine2)

    return tooltip
end

function createLicense(rarity, faction)
    local license = VanillaInventoryItem()
    if rarity.value == 0 then
        license.name = "Dangerous Cargo Transport License"%_t
        license.price = 100 * 1000
    elseif rarity.value == 1 then
        license.name = "Suspicious Cargo Transport License"%_t
        license.price = 500 * 1000
    elseif rarity.value == 2 then
        license.name = "Stolen Cargo Transport License"%_t
        license.price = 1000 * 1000
    elseif rarity.value == 3 then
        license.name = "Illegal Cargo Transport License"%_t
        license.price = 2000 * 1000
    end

    license.rarity = rarity
    license:setValue("subtype", "CargoLicense")
    license:setValue("isCargoLicense", true)
    license:setValue("faction", faction.index)
    license.icon = "data/textures/icons/crate.png"
    license.iconColor = rarity.color
    license:setTooltip(makeLicenseTooltip(license))

    return license
end

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function CargoTransportLicenseMerchant.interactionPossible(playerIndex, option)
    return CheckFactionInteraction(playerIndex, CargoTransportLicenseMerchant.interactionThreshold)
end

function CargoTransportLicenseMerchant.shop:addItems()
end

function CargoTransportLicenseMerchant.initialize()
    CargoTransportLicenseMerchant.shop:initialize("Trading Post"%_t)

    if onClient() and EntityIcon().icon == "" then
        EntityIcon().icon = "data/textures/icons/pixel/trade.png"
    end
end

function CargoTransportLicenseMerchant.updateServer()
    if isInitialized == false then
        local faction = Faction()

        if faction then
            isInitialized = true

            for i = 3, 0, -1 do
                local license = createLicense(Rarity(i), faction)
                CargoTransportLicenseMerchant.add(license, getInt(1, 2))
            end

        end
    end
end

function CargoTransportLicenseMerchant.initUI()
    CargoTransportLicenseMerchant.shop:initUI("Buy Cargo License"%_t, "Trading Post"%_t, "Cargo Transport Licenses"%_t, "data/textures/icons/crate.png")
    CargoTransportLicenseMerchant.shop.tabbedWindow:deactivateTab(CargoTransportLicenseMerchant.shop.sellTab)
    CargoTransportLicenseMerchant.shop.tabbedWindow:deactivateTab(CargoTransportLicenseMerchant.shop.buyBackTab)
end
