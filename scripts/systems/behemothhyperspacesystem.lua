package.path = package.path .. ";data/scripts/systems/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("basesystem")
include ("utility")
include ("randomext")

-- optimization so that energy requirement doesn't have to be read every frame
FixedEnergyRequirement = true
Unique = true

BoostingUpgrades = {}
BoostingUpgrades["data/scripts/systems/hyperspacebooster.lua"] = true
BoostingUpgrades["data/scripts/systems/valuablesdetector.lua"] = true
BoostingUpgrades["data/scripts/systems/tradingoverview.lua"] = true
BoostingUpgrades["data/scripts/systems/radarbooster.lua"] = true
BoostingUpgrades["internal/dlc/rift/systems/militarytcshyperspacehybrid.lua"] = true
BoostingUpgrades["internal/dlc/rift/systems/hypertradingsystem.lua"] = true
BoostingUpgrades["internal/dlc/rift/systems/energyhyperspaceboosterhybrid.lua"] = true
BoostingUpgrades["internal/dlc/rift/systems/militarytcsshieldhybrid.lua"] = true
BoostingUpgrades["internal/dlc/rift/systems/superscoutsystem.lua"] = true
BoostingUpgrades["internal/dlc/rift/systems/hypertradingsystem.lua"] = true

function countBoostingUpgrades()
    local counter = 0
    if isEntityScript() then
        for upgrade, permanent in pairs(ShipSystem():getUpgrades()) do
            if permanent and BoostingUpgrades[upgrade.script] then
                counter = counter + 1
            end
        end
    end

    return counter
end

function getBonuses(seed, rarity, permanent)
    math.randomseed(seed)

    local reach = 0
    local cdfactor = 0
    local efactor = 0
    local radar = 0

    cdfactor = 5 -- base value, in percent
    -- add flat percentage based on rarity
    cdfactor = cdfactor + (rarity.value + 1) * 2.5 -- add 0% (worst rarity) to +15% (best rarity)

    -- add randomized percentage, span is based on rarity
    cdfactor = cdfactor + math.random() * ((rarity.value + 1) * 2.5) -- add random value between 0% (worst rarity) and +15% (best rarity)
    cdfactor = -cdfactor / 100

    efactor = 5 -- base value, in percent
    -- add flat percentage based on rarity
    efactor = efactor + (rarity.value + 1) * 3 -- add 0% (worst rarity) to +18% (best rarity)

    -- add randomized percentage, span is based on rarity
    efactor = efactor + math.random() * ((rarity.value + 1) * 4) -- add random value between 0% (worst rarity) and +24% (best rarity)
    efactor = -efactor / 100

    radar = rarity.value + 2

    if permanent then
        reach = 2

        local upgrades = countBoostingUpgrades()
        reach = reach + upgrades * 2
        radar = radar + upgrades * 2
    else
        cdfactor = 0
    end

    return round(reach, 1), cdfactor, efactor, round(radar)
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
local key3
local key4

function applyBonuses(seed, rarity, permanent)
    if key1 then removeBonus(key1) end
    if key2 then removeBonus(key2) end
    if key3 then removeBonus(key3) end
    if key4 then removeBonus(key4) end

    local reach, cooldown, energy, radar = getBonuses(seed, rarity, permanent)

    key1 = addMultiplyableBias(StatsBonuses.HyperspaceReach, reach)
    key2 = addBaseMultiplier(StatsBonuses.HyperspaceCooldown, cooldown)
    key3 = addBaseMultiplier(StatsBonuses.HyperspaceChargeEnergy, energy)
    key4 = addMultiplyableBias(StatsBonuses.RadarReach, radar)
end

function getName(seed, rarity)
    local reach, cooldown, energy, radar = getBonuses(seed, rarity, true)

    local reachStr = ""
    if reach > 0 then
        reachStr = "R-" .. math.ceil(reach) .. " "
    end

    local type = "Behemoth Exploration Booster"%_t

    return "${reach}${type} /* ex: R-4 Behemoth Exploration Booster */"%_t % {reach = reachStr, type = type}
end

function getBasicName()
    return "Exploration Booster"%_t
end

function getIcon(seed, rarity)
    return "data/textures/icons/behemoth-hyperspace.png"
end

function getEnergy(seed, rarity, permanent)
    local reach, cdfactor, efactor, radar = getBonuses(seed, rarity, true)
    reach = 30
    return math.abs(cdfactor) * 2.5 * 1000 * 1000 * 1000 + reach * 125 * 1000 * 1000 + radar * 75 * 1000 * 1000
end

function getPrice(seed, rarity)
    local reach, _, efactor, radar = getBonuses(seed, rarity, false)
    local _, cdfactor, _, _ = getBonuses(seed, rarity, true)
    local price = math.abs(cdfactor) * 100 * 350 + math.abs(efactor) * 100 * 250 + reach * 3000 + radar * 450
    return price * 2.5 ^ rarity.value
end

function getTooltipLines(seed, rarity, permanent)

    local texts = {}
    local bonuses = {}
    local reach, _, efactor, radar = getBonuses(seed, rarity, permanent)
    local baseReach, _, _, baseRadar = getBonuses(seed, rarity, false)
    local betterReach, cdfactor, _, betterRadar = getBonuses(seed, rarity, true)

    local jumpRangeBonusStr = string.format("%+g", betterReach - baseReach)
    local radarRangeBonusStr = string.format("%+i", betterRadar - baseRadar)

    if not isEntityScript() then
        jumpRangeBonusStr = "+2 to +30"%_t
        radarRangeBonusStr = "+0 to +28"%_t
    end

    if reach ~= 0 then
        table.insert(texts, {ltext = "Jump Range"%_t, rtext = string.format("%+g", reach), icon = "data/textures/icons/star-cycle.png", boosted = permanent})
    end
    if betterReach ~= 0 then
        table.insert(bonuses, {ltext = "Jump Range"%_t, rtext = jumpRangeBonusStr, icon = "data/textures/icons/star-cycle.png", boosted = permanent})
    end

    if radar ~= 0 then
        table.insert(texts, {ltext = "Radar Range"%_t, rtext = string.format("%+i", radar), icon = "data/textures/icons/radar-sweep.png", boosted = permanent})
        table.insert(bonuses, {ltext = "Radar Range"%_t, rtext = radarRangeBonusStr, icon = "data/textures/icons/radar-sweep.png", boosted = permanent})
    end

    if cdfactor ~= 0 then
        if permanent then
            table.insert(texts, {ltext = "Hyperspace Cooldown"%_t, rtext = string.format("%+i%%", round(cdfactor * 100)), icon = "data/textures/icons/hourglass.png", boosted = permanent})
        end
        table.insert(bonuses, {ltext = "Hyperspace Cooldown"%_t, rtext = string.format("%+i%%", round(cdfactor * 100)), icon = "data/textures/icons/hourglass.png", boosted = permanent})
    end

    if efactor ~= 0 then
        table.insert(texts, {ltext = "Hyperspace Charge Energy"%_t, rtext = string.format("%+i%%", round(efactor * 100)), icon = "data/textures/icons/electric.png"})
    end

    if #bonuses == 0 then bonuses = nil end

    return texts, bonuses
end

function getDescriptionLines(seed, rarity, permanent)
    return
    {
        {ltext = "Behemoth Exploration System"%_t, rtext = "", icon = ""},
        {ltext = "+${rangeBonus} jump & radar range for each permanently installed:"%_t % {rangeBonus = "2"}, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)},
        {ltext = "  · " .. "Hyperspace System"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)},
        {ltext = "  · " .. "Radar System"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)},
        {ltext = "  · " .. "Object Detection System"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)},
        {ltext = "  · " .. "Trading System"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)},
        {ltext = ""},
        {ltext = "To infinity and beyond!"%_t, lcolor = ColorRGB(1, 0.5, 0.5)},
    }
end

function getComparableValues(seed, rarity)

    local base = {}
    local bonus = {}

    for _, p in pairs({{base, false}, {bonus, true}}) do
        local values = p[1]
        local permanent = p[2]

        local reach, cdfactor, efactor, radar = getBonuses(seed, rarity, permanent)

        if permanent then
            radar = rarity.value + 14 * 2
            reach = 14 * 2
        end

        if reach ~= 0 then
            table.insert(values, {name = "Jump Range"%_t, key = "jump_range", value = round(reach * 100), comp = UpgradeComparison.MoreIsBetter})
        end

        if radar ~= 0 then
            table.insert(values, {name = "Radar Range"%_t, key = "radar_range", value = round(radar * 100), comp = UpgradeComparison.MoreIsBetter})
        end

        if cdfactor ~= 0 then
            table.insert(values, {name = "Hyperspace Cooldown"%_t, key = "hs_cooldown", value = round(cdfactor * 100), comp = UpgradeComparison.LessIsBetter})
        end

        if efactor ~= 0 then
            table.insert(values, {name = "Hyperspace Charge Energy"%_t, key = "recharge_energy", value = round(efactor * 100), comp = UpgradeComparison.LessIsBetter})
        end
    end

    return base, bonus
end
