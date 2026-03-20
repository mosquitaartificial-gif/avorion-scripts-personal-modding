
package.path = package.path .. ";data/scripts/systems/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("basesystem")
include ("randomext")
include ("utility")

-- optimization so that energy requirement doesn't have to be read every frame
FixedEnergyRequirement = true

function getNumBonusTurrets(seed, rarity, permanent)
    if permanent then
        return math.max(1, math.floor((rarity.value + 1) / 2))
    end

    return 0
end

function getNumTurrets(seed, rarity, permanent)
    math.randomseed(seed)

    local baseTurrets = math.max(1, rarity.value + 1)
    local turrets = baseTurrets + getNumBonusTurrets(seed, rarity, permanent)

    local pdcs = math.floor(baseTurrets / 2)
    if not permanent then
        pdcs = 0
    end

    local autos = 0
    if permanent then
        autos = math.max(0, getInt(math.max(0, rarity.value - 1), turrets - 1))
    end

    return turrets, pdcs, autos
end

function onInstalled(seed, rarity, permanent)
    local turrets, pdcs, autos = getNumTurrets(seed, rarity, permanent)

    addMultiplyableBias(StatsBonuses.UnarmedTurrets, turrets)
    addMultiplyableBias(StatsBonuses.PointDefenseTurrets, pdcs)
    addMultiplyableBias(StatsBonuses.AutomaticTurrets, autos)
end

function onUninstalled(seed, rarity, permanent)
end

function getName(seed, rarity)
    local turrets, pdcs, autos = getNumTurrets(seed, rarity, true)

    local ids = "C"
    if pdcs > 0 then ids = ids .. "D" end
    if autos > 0 then ids = ids .. "I" end

    return "Civil Turret Control Subsystem ${ids}-TCS-${num}"%_t % {num = turrets + pdcs + autos, ids = ids}
end

function getBasicName()
    return "Turret Control Subsystem (Civil) /* generic name for 'Civil Turret Control Subsystem ${ids}-TCS-${num}' */"%_t
end

function getIcon(seed, rarity)
    return "data/textures/icons/turret.png"
end

function getEnergy(seed, rarity, permanent)
    local turrets, pdcs, autos = getNumTurrets(seed, rarity, permanent)
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

    table.insert(texts, {ltext = "Unarmed Turret Slots"%_t, rtext = "+" .. turrets, icon = "data/textures/icons/turret.png", boosted = permanent})
    if permanent then
        if pdcs > 0 then
            table.insert(texts, {ltext = "Defensive Turret Slots"%_t, rtext = "+" .. pdcs, icon = "data/textures/icons/turret.png", boosted = permanent})
        end
        if autos > 0 then
            table.insert(texts, {ltext = "Auto-Turret Slots"%_t, rtext = "+" .. autos, icon = "data/textures/icons/turret.png", boosted = permanent})
        end
    end

    table.insert(bonuses, {ltext = "Unarmed Turret Slots"%_t, rtext = "+" .. getNumBonusTurrets(seed, rarity, true), icon = "data/textures/icons/turret.png"})
    if pdcs > 0 then
        table.insert(bonuses, {ltext = "Defensive Turret Slots"%_t, rtext = "+" .. pdcs, icon = "data/textures/icons/turret.png"})
    end
    if autos > 0 then
        table.insert(bonuses, {ltext = "Auto-Turret Slots"%_t, rtext = "+" .. autos, icon = "data/textures/icons/turret.png"})
    end

    return texts, bonuses
end

function getDescriptionLines(seed, rarity, permanent)
    return
    {
        {ltext = "Civil Turret Control System"%_t, rtext = "", icon = ""},
        {ltext = "Adds slots for unarmed turrets"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)}
    }
end

function getComparableValues(seed, rarity)
    local turrets = getNumTurrets(seed, rarity, false)
    local bonusTurrets = getNumBonusTurrets(seed, rarity, true)
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
