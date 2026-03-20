
package.path = package.path .. ";data/scripts/systems/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("basesystem")
include ("utility")
include ("randomext")

-- optimization so that energy requirement doesn't have to be read every frame
FixedEnergyRequirement = true

function getNumBonusTurrets(seed, rarity, permanent)
    if permanent then
        return math.max(1, math.floor(rarity.value / 2))
    end

    return 0
end

function getNumTurrets(seed, rarity, permanent)
    math.randomseed(seed)

    local turrets = math.max(1, rarity.value) + getNumBonusTurrets(seed, rarity, permanent)

    local autos = 0
    if permanent then
        autos = math.max(0, getInt(math.max(0, rarity.value - 2), turrets - 1))
    end

    return turrets, autos
end

function onInstalled(seed, rarity, permanent)
    local turrets, autos = getNumTurrets(seed, rarity, permanent)

    addMultiplyableBias(StatsBonuses.ArbitraryTurrets, turrets)
    addMultiplyableBias(StatsBonuses.AutomaticTurrets, autos)
end

function onUninstalled(seed, rarity, permanent)
end

function getName(seed, rarity)
    local turrets, autos = getNumTurrets(seed, rarity, true)

    local ids = "A"
    if autos > 0 then ids = ids .. "I" end

    return "Turret Control Subsystem ${ids}-TCS-${num}"%_t % {num = turrets + autos, ids = ids}
end

function getBasicName()
    return "Turret Control Subsystem (Arbitrary) /* generic name for 'Turret Control Subsystem ${ids}-TCS-${num}' */"%_t
end

function getIcon(seed, rarity)
    return "data/textures/icons/turret.png"
end

function getEnergy(seed, rarity, permanent)
    local turrets, autos = getNumTurrets(seed, rarity, permanent)
    return turrets * 350 * 1000 * 1000 / (1.1 ^ rarity.value)
end

function getPrice(seed, rarity)
    local turrets, _ = getNumTurrets(seed, rarity, false)
    local _, autos = getNumTurrets(seed, rarity, true)

    local price = 7500 * (turrets + autos * 0.5);
    return price * 2.5 ^ rarity.value
end

function getTooltipLines(seed, rarity, permanent)
    local turrets, _ = getNumTurrets(seed, rarity, permanent)
    local _, autos = getNumTurrets(seed, rarity, true)

    local texts = {}
    local bonuses = {}

    table.insert(texts, {ltext = "Arbitrary Turret Slots"%_t, rtext = "+" .. turrets, icon = "data/textures/icons/turret.png", boosted = permanent})
    if permanent then
        if autos > 0 then
            table.insert(texts, {ltext = "Auto-Turret Slots"%_t, rtext = "+" .. autos, icon = "data/textures/icons/turret.png", boosted = permanent})
        end
    end

    table.insert(bonuses, {ltext = "Arbitrary Turret Slots"%_t, rtext = "+" .. getNumBonusTurrets(seed, rarity, true), icon = "data/textures/icons/turret.png"})

    if autos > 0 then
        table.insert(bonuses, {ltext = "Auto-Turret Slots"%_t, rtext = "+" .. autos, icon = "data/textures/icons/turret.png"})
    end

    return texts, bonuses
end

function getDescriptionLines(seed, rarity, permanent)
    return
    {
        {ltext = "All-round Turret Control System"%_t, rtext = "", icon = ""},
        {ltext = "Adds slots for any turrets"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)},
    }
end

function getComparableValues(seed, rarity)
    local turrets = getNumTurrets(seed, rarity, false)
    local bonusTurrets = getNumBonusTurrets(seed, rarity, true)
    local _, autos = getNumTurrets(seed, rarity, true)

    return
    {
        {name = "Arbitrary Turret Slots"%_t, key = "arbitrary_slots", value = turrets, comp = UpgradeComparison.MoreIsBetter},
        {name = "Auto-Turret Slots"%_t, key = "auto_slots", value = 0, comp = UpgradeComparison.MoreIsBetter},
    },
    {
        {name = "Arbitrary Turret Slots"%_t, key = "arbitrary_slots", value = bonusTurrets, comp = UpgradeComparison.MoreIsBetter},
        {name = "Auto-Turret Slots"%_t, key = "auto_slots", value = autos, comp = UpgradeComparison.MoreIsBetter},
    }
end
