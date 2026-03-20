
package.path = package.path .. ";data/scripts/systems/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("basesystem")
include ("utility")
include ("randomext")

-- optimization so that energy requirement doesn't have to be read every frame
FixedEnergyRequirement = true
Unique = true

BoostingUpgrades = {}
BoostingUpgrades["data/scripts/systems/civiltcs.lua"] = true
BoostingUpgrades["data/scripts/systems/autotcs.lua"] = true
BoostingUpgrades["data/scripts/systems/miningsystem.lua"] = true
BoostingUpgrades["internal/dlc/rift/systems/miningcarrierhybrid.lua"] = true
BoostingUpgrades["internal/dlc/rift/systems/salvagingcarrierhybrid.lua"] = true

function getNumBonusTurrets(seed, rarity, permanent)
    local counter = 0
    local bonus = 0
    if permanent then
        for upgrade, permanent in pairs(ShipSystem():getUpgrades()) do
            if permanent and BoostingUpgrades[upgrade.script] then
                counter = counter + 1
                if counter <= 4 then
                    bonus = bonus + 1
                elseif counter <= 8 then
                    bonus = bonus + 2
                elseif counter <= 12 then
                    bonus = bonus + 3
                else
                    bonus = bonus + 4
                end
            end
        end
    end

    return bonus
end

function getNumTurrets(seed, rarity, permanent)
    math.randomseed(seed)

    local turrets = 3
    if rarity.value >= RarityType.Exotic then turrets = turrets + 1 end
    if rarity.value >= RarityType.Legendary then turrets = turrets + 1 end

    local pdcs = math.floor(turrets)
    if not permanent then
        pdcs = 0
    end

    local autos = 0
    if permanent then
        autos = math.max(0, getInt(math.max(0, rarity.value - 1), turrets * 2 - 1))
    end

    return turrets, pdcs, autos
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

function applyBonuses(seed, rarity, permanent)
    if key1 then removeBonus(key1) end
    if key2 then removeBonus(key2) end
    if key3 then removeBonus(key3) end

    local turrets, pdcs, autos = getNumTurrets(seed, rarity, permanent)
    turrets = turrets + getNumBonusTurrets(seed, rarity, permanent)

    key1 = addMultiplyableBias(StatsBonuses.UnarmedTurrets, turrets)
    key2 = addMultiplyableBias(StatsBonuses.PointDefenseTurrets, pdcs)
    key3 = addMultiplyableBias(StatsBonuses.AutomaticTurrets, autos)
end

function getName(seed, rarity)
    local turrets, pdcs, autos = getNumTurrets(seed, rarity, true)

    local ids = "BC"
    if pdcs > 0 then ids = ids .. "D" end
    if autos > 0 then ids = ids .. "I" end

    return "Behemoth Civil Subsystem ${ids}-BTCS-${num}"%_t % {num = turrets + pdcs + autos, ids = ids}
end

function getBasicName()
    return "Behemoth Civil Subsystem /* generic name for 'Behemoth Civil Subsystem ${ids}-BTCS-${num}' */"%_t
end

function getIcon(seed, rarity)
    return "data/textures/icons/behemoth-turret-ctcs.png"
end

function getEnergy(seed, rarity, permanent)
    local turrets = 10
    return turrets * 200 * 1000 * 1000 / (1.2 ^ rarity.value)
end

function getPrice(seed, rarity)
    local turrets, _, _ = getNumTurrets(seed, rarity, false)
    local _, _, autos = getNumTurrets(seed, rarity, true)

    local price = 5000 * (turrets + autos * 0.5)
    return price * 2.5 ^ rarity.value
end

function getTooltipLines(seed, rarity, permanent)
    local turrets, _ = getNumTurrets(seed, rarity, permanent)
    local _, pdcs, autos = getNumTurrets(seed, rarity, true)

    local texts = {}
    local bonuses = {}

    local bonusTurretsStr = "${from} to ${to} /* ex: 10 to 15 */"%_t % {from = "+0", to = "+32"}
    if isEntityScript() then
        local bonusTurrets = getNumBonusTurrets(seed, rarity, true)
        bonusTurretsStr = "+" .. bonusTurrets
        if permanent then
            turrets = turrets + bonusTurrets
        end
    end

    table.insert(texts, {ltext = "Unarmed Turret Slots"%_t, rtext = "+" .. turrets, icon = "data/textures/icons/turret.png", boosted = permanent})
    if permanent then
        if pdcs > 0 then
            table.insert(texts, {ltext = "Defensive Turret Slots"%_t, rtext = "+" .. pdcs, icon = "data/textures/icons/turret.png", boosted = permanent})
        end

        if autos > 0 then
            table.insert(texts, {ltext = "Auto-Turret Slots"%_t, rtext = "+" .. autos, icon = "data/textures/icons/turret.png", boosted = permanent})
        end
    end

    table.insert(bonuses, {ltext = "Unarmed Turret Slots"%_t, rtext = bonusTurretsStr, icon = "data/textures/icons/turret.png"})
    if pdcs > 0 then
        table.insert(bonuses, {ltext = "Defensive Turret Slots"%_t, rtext = "+" .. pdcs, icon = "data/textures/icons/turret.png"})
    end
    if autos > 0 then
        table.insert(bonuses, {ltext = "Auto-Turret Slots"%_t, rtext = "+" .. autos, icon = "data/textures/icons/turret.png"})
    end

    return texts, bonuses
end

function getDescriptionLines(seed, rarity, permanent)
    return {
        {ltext = "Behemoth Turret Control System"%_t, rtext = "", icon = ""},
        {ltext = "Adds slots for unarmed turrets"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)},
        {ltext = "Additional slots for each permanently installed:"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)},
        {ltext = " · " .. "Independent Turret Control System"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)},
        {ltext = " · " .. "Civil Turret Control System"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)},
        {ltext = " · " .. "Mining System"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)},
        {ltext = "", rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)},
        {ltext = "+1 slot for each of the first ${systemAmount} systems"%_t % {systemAmount = "4"}, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)},
        {ltext = "+${slotAmount} slots for each of the next ${systemAmount} systems"%_t % {slotAmount = "2", systemAmount = "4"}, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)},
        {ltext = "+${slotAmount} slots for each of the next ${systemAmount} systems"%_t % {slotAmount = "3", systemAmount = "4"}, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)},
        {ltext = "+${slotAmount} slots for each of the next ${systemAmount} systems"%_t % {slotAmount = "4", systemAmount = "2"}, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)},
    }
end

function getComparableValues(seed, rarity)
    local turrets = getNumTurrets(seed, rarity, false)
    local bonusTurrets = 32
    local _, pdcs, autos = getNumTurrets(seed, rarity, true)

    return
    {
        {name = "Unarmed Turret Slots"%_t, key = "unarmed_slots", value = turrets, comp = UpgradeComparison.MoreIsBetter},
        {name = "Defensive Turret Slots"%_t, key = "pdc_slots", value = 0, comp = UpgradeComparison.MoreIsBetter},
        {name = "Auto-Turret Slots"%_t, key = "auto_slots", value = 0, comp = UpgradeComparison.MoreIsBetter},
    },
    {
        {name = "Unarmed Turret Slots"%_t, key = "unarmed_slots", value = bonusTurrets, comp = UpgradeComparison.MoreIsBetter},
        {name = "Defensive Turret Slots"%_t, key = "pdc_slots", value = pdcs, comp = UpgradeComparison.MoreIsBetter},
        {name = "Auto-Turret Slots"%_t, key = "auto_slots", value = autos, comp = UpgradeComparison.MoreIsBetter},
    }
end
