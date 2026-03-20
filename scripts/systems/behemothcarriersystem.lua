
package.path = package.path .. ";data/scripts/systems/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("basesystem")
include ("utility")
include ("randomext")

-- optimization so that energy requirement doesn't have to be read every frame
FixedEnergyRequirement = true
Unique = true

productionIncrementPerBoostingUpgrade = 0.025

BoostingUpgrades = {}
BoostingUpgrades["data/scripts/systems/fightersquadsystem.lua"] = true
BoostingUpgrades["internal/dlc/rift/systems/miningcarrierhybrid.lua"] = true
BoostingUpgrades["internal/dlc/rift/systems/combatcarrierhybrid.lua"] = true
BoostingUpgrades["internal/dlc/rift/systems/salvagingcarrierhybrid.lua"] = true
BoostingUpgrades["internal/dlc/rift/systems/shieldcarrierhybrid.lua"] = true
BoostingUpgrades["data/scripts/systems/miningsystem.lua"] = true
BoostingUpgrades["data/scripts/systems/shieldbooster.lua"] = true
BoostingUpgrades["data/scripts/systems/shieldimpenetrator.lua"] = true
BoostingUpgrades["data/scripts/systems/energytoshieldconverter.lua"] = true
BoostingUpgrades["internal/dlc/rift/systems/energyshieldboosterhybrid.lua"] = true
BoostingUpgrades["internal/dlc/rift/systems/militarytcsshieldhybrid.lua"] = true
BoostingUpgrades["internal/dlc/rift/systems/overshield.lua"] = true


function getBonuses(seed, rarity, permanent)
    math.randomseed(seed)

    local squads = 1
    local production = 0

    if permanent then
        production = 0
    end

    return squads, production
end

function getNumBonusSquads(seed, rarity, permanent)
    local bonusSquads = 0
    if permanent then
        for upgrade, permanent in pairs(ShipSystem():getUpgrades()) do
            if permanent and BoostingUpgrades[upgrade.script] then
                bonusSquads = bonusSquads + 1
            end
        end
    end

    if bonusSquads > 9 then
        bonusSquads = 9
    end

    return bonusSquads
end

function getBonusProduction(seed, rarity, permanent)
    local bonusProduction = 0
    if permanent then
        for upgrade, permanent in pairs(ShipSystem():getUpgrades()) do
            if permanent and BoostingUpgrades[upgrade.script] then
                bonusProduction = bonusProduction + productionIncrementPerBoostingUpgrade
            end
        end
    end

    return bonusProduction
end

function onInstalled(seed, rarity, permanent)
    Entity():registerCallback("onSystemsChanged", "onSystemsChanged")

    applyBonuses(seed, rarity, permanent)
end

function onUninstalled(seed, rarity, permanent)
end

function onSystemsChanged()
    applyBonuses(getSeed(), getRarity(), getPermanent())
end

local key1
local key2

function applyBonuses(seed, rarity, permanent)
    if key1 then removeBonus(key1) end
    if key2 then removeBonus(key2) end

    local squads, production = getBonuses(seed, rarity, permanent)
    squads = squads + getNumBonusSquads(seed, rarity, permanent)
    production = production + getBonusProduction(seed, rarity, permanent)

    key1 = addMultiplyableBias(StatsBonuses.FighterSquads, squads)
    key2 = addBaseMultiplier(StatsBonuses.ProductionCapacity, production)
end

function getName(seed, rarity)
    local rnd = Random(Seed(seed))
    local serialNumber = makeSerialNumber(rnd, 4, "FCS-")

    return "Dozen-headed Behemoth ${serialNumber}"%_t % {serialNumber = serialNumber}
end

function getBasicName()
    return "Behemoth Carrier Subsystem /* generic name for 'Dozen-headed Behemoth ${serialNumber}' */"%_t
end

function getIcon(seed, rarity)
    return "data/textures/icons/behemoth-fighter.png"
end

function getEnergy(seed, rarity, permanent)
    local squads = 5
    return squads * 600 * 1000 * 1000 / (1.1 ^ rarity.value)
end

function getPrice(seed, rarity)
    local squads = 5

    local price = 25000 * (squads)
    return price * 1.5 ^ rarity.value
end

function getTooltipLines(seed, rarity, permanent)
    local squads, _ = getBonuses(seed, rarity, permanent)
    local _, production = getBonuses(seed, rarity, true)

    local texts = {}
    local bonuses = {}

    local bonusSquadsStr = "${from} to ${to} /* ex: 10 to 15 */"%_t % {from = "+0", to = "+9"}
    if isEntityScript() then
        local bonusSquads = getNumBonusSquads(seed, rarity, true)
        bonusSquadsStr = "+0"
        if permanent then
            squads = squads + bonusSquads
        end
    end

    local bonusProductionStr = "${from} to ${to} /* ex: 10 to 15 */"%_t % {from = "+0%", to = "+" .. (productionIncrementPerBoostingUpgrade * 100 * 14) .. "%"}
    if isEntityScript() then
        local bonusProduction = getBonusProduction(seed, rarity, true)
        production = production + bonusProduction

        bonusProductionStr = "+0%"
    end

    local speedupStr = (production * 100) .. "%"

    table.insert(texts, {ltext = "Fighter Squadrons"%_t, rtext = "+" .. squads, icon = "data/textures/icons/fighter.png", boosted = permanent})

    if permanent and production > 0 then
        table.insert(texts, {ltext = "Production Speedup"%_t, rtext = "+" .. speedupStr, icon = "data/textures/icons/gears.png", boosted = permanent})
    end

    table.insert(bonuses, {ltext = "Fighter Squadrons"%_t, rtext = bonusSquadsStr, icon = "data/textures/icons/fighter.png"})
    table.insert(bonuses, {ltext = "Production Speedup"%_t, rtext = bonusProductionStr, icon = "data/textures/icons/gears.png"})

    return texts, bonuses
end

function getDescriptionLines(seed, rarity, permanent)
    return
    {
        {ltext = "Behemoth Carrier Control System"%_t, rtext = "", icon = ""},
        {ltext = "Controls additional fighter squadrons (10 max)"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)},
        {ltext = "+${bonusSquads} squad and +${productionSpeedup} prod. speedup for each permanently installed:"%_t % {bonusSquads = "1", productionSpeedup = "2.5%"}, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)},
        {ltext = "  · " .. "Fighter Control System"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)},
        {ltext = "  · " .. "Shield System"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)},
        {ltext = "  · " .. "Mining System"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)},
    }
end

function getComparableValues(seed, rarity)
    local squads, production = getBonuses(seed, rarity, false)
    local bonusSquads = 9
    local bonusProduction = 14000

    return
    {
        {name = "Fighter Squadrons"%_t, key = "fighter_squads", value = squads, comp = UpgradeComparison.MoreIsBetter},
        {name = "Production Speedup"%_t, key = "production_capacity", value = production, comp = UpgradeComparison.MoreIsBetter},
    },
    {
        {name = "Fighter Squadrons"%_t, key = "fighter_squads", value = bonusSquads, comp = UpgradeComparison.MoreIsBetter},
        {name = "Production Speedup"%_t, key = "production_capacity", value = bonusProduction, comp = UpgradeComparison.MoreIsBetter},
    }
end
