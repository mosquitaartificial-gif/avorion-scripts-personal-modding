
package.path = package.path .. ";data/scripts/systems/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("basesystem")
include ("randomext")
include ("utility")

-- optimization so that energy requirement doesn't have to be read every frame
FixedEnergyRequirement = true

function getNumBonusTurrets(seed, rarity, permanent)
    if permanent then
        return getNumTurrets(seed, rarity, permanent)
    end

    return 0
end

function getNumTurrets(seed, rarity, permanent)
    local turrets = math.max(1, rarity.value + 1)

    if permanent then turrets = turrets * 2 end

    return turrets
end

function onInstalled(seed, rarity, permanent)
    local turrets = getNumTurrets(seed, rarity, permanent)

    addMultiplyableBias(StatsBonuses.AutomaticTurrets, turrets)
end

function onUninstalled(seed, rarity, permanent)
end

function getName(seed, rarity)
    local turrets = getNumTurrets(seed, rarity, true)
    local ids = "I"

    return "Auto-Turret Control Subsystem ${ids}-TCS-${num}"%_t % {num = turrets, ids = ids}
end

function getBasicName()
    return "Turret Control Subsystem (Auto) /* generic name for 'Auto-Turret Control Subsystem ${ids}-TCS-${num}' */"%_t
end

function getIcon(seed, rarity)
    return "data/textures/icons/turret.png"
end

function getEnergy(seed, rarity, permanent)
    local num = getNumTurrets(seed, rarity, permanent)
    return num * 200 * 1000 * 1000 / (1.2 ^ rarity.value)
end

function getPrice(seed, rarity)
    local num = getNumTurrets(seed, rarity, true)
    local price = 5000 * num;
    return price * 2.5 ^ rarity.value
end

function getTooltipLines(seed, rarity, permanent)
    local turrets = getNumTurrets(seed, rarity, permanent)

    local texts = {}
    local bonuses = {}

    table.insert(texts, {ltext = "Auto-Turret Slots"%_t, rtext = "+" .. turrets, icon = "data/textures/icons/turret.png", boosted = permanent})
    table.insert(bonuses, {ltext = "Auto-Turret Slots"%_t, rtext = "+" .. getNumBonusTurrets(seed, rarity, true) - turrets, icon = "data/textures/icons/turret.png"})

    return texts, bonuses
end

function getDescriptionLines(seed, rarity, permanent)
    return
    {
        {ltext = "Independent Turret Control System"%_t, rtext = "", icon = ""},
        {ltext = "Adds slots for auto-fire turrets"%_t, rtext = "", icon = "data/textures/icons/nothing.png", fontType = FontType.Normal, lcolor = ColorRGB(0.7, 0.7, 0.7)}
    }
end

function getComparableValues(seed, rarity)
    local turrets = getNumTurrets(seed, rarity, false)
    local bonusTurrets = getNumBonusTurrets(seed, rarity, true)

    return
    {
        {name = "Auto-Turret Slots"%_t, key = "auto_slots", value = turrets, comp = UpgradeComparison.MoreIsBetter},
    },
    {
        {name = "Auto-Turret Slots"%_t, key = "auto_slots", value = bonusTurrets, comp = UpgradeComparison.MoreIsBetter},
    }
end
