package.path = package.path .. ";data/scripts/lib/?.lua"
include ("utility")
include ("weapontypeutility")
local FighterUT = include ("fighterutility")



-- type
local valueWeights = {}
valueWeights[WeaponType.ChainGun] = 0.75
valueWeights[WeaponType.Bolter] = 0.6
valueWeights[WeaponType.PulseCannon] = 0.75

valueWeights[WeaponType.PointDefenseChainGun] = 1 -- low damage, this is to keep them in the loop a little
valueWeights[WeaponType.PointDefenseLaser] = 2 -- low damage, this is to keep them in the loop a little
valueWeights[WeaponType.AntiFighter] = 10 -- same as above, plus AOE damage vs. fighters

valueWeights[WeaponType.PlasmaGun] = 1
valueWeights[WeaponType.Laser] = 1

valueWeights[WeaponType.RocketLauncher] = 0.5 -- reasoning: slow projectiles, hard to hit
valueWeights[WeaponType.Cannon] = 0.75 -- hard to hit with them, not strong vs. shields
valueWeights[WeaponType.RailGun] = 1

valueWeights[WeaponType.LightningGun] = 0.65 -- electric damage is a drawback
valueWeights[WeaponType.TeslaGun] = 0.8 -- electric damage is a drawback, close range

valueWeights[WeaponType.RepairBeam] = 3 -- utility -> increased price
valueWeights[WeaponType.ForceGun] = 1

valueWeights[WeaponType.MiningLaser] = 1
valueWeights[WeaponType.RawMiningLaser] = 0.25 -- compensate the massive stone damage boost and effort necessary to mine with those
valueWeights[WeaponType.SalvagingLaser] = 1
valueWeights[WeaponType.RawSalvagingLaser] = 0.45 -- compensate additional refining effort


local rarityWeights = {}
rarityWeights[WeaponType.MiningLaser] = 0.5 -- rarity already affects these weapons a lot through efficiency etc.
rarityWeights[WeaponType.RawMiningLaser] = 0.5
rarityWeights[WeaponType.ForceGun] = 0.2
rarityWeights[WeaponType.PointDefenseChainGun] = 0.2
rarityWeights[WeaponType.PointDefenseLaser] = 0.2


local reachWeights = {}
reachWeights[WeaponType.SalvagingLaser] = 5 -- compensate low reach
reachWeights[WeaponType.RawSalvagingLaser] = 5 -- compensate low reach


function ArmedObjectPrice(object)

    local type = WeaponTypes.getTypeOfItem(object) or WeaponType.ChainGun

    local baseValue = object.dps / (0.5 + object.slots / 2) * 2
    local value = baseValue

    -- dps
    -- + shield / hull dmg multi -> +50% each
    -- multiplier of 1 is normal though - so substract 1
    value = value + baseValue * (object.shieldDamageMultiplier - 1) * 0.5
    value = value + baseValue * (object.hullDamageMultiplier - 1) * 0.5

    -- shield pen -> 100% -> doubled price (but only for hull damage, shield is irrelevant here)
    value = value + (baseValue * object.hullDamageMultiplier) * object.shieldPenetration

    -- bring mining beam damage up to par, only x0.25 since it's only vs. stone
    value = value + (baseValue * object.hullDamageMultiplier * object.stoneDamageMultiplier * 0.15)

    -- repair strength
    value = value + object.hullRepairRate / object.slots * 2.5
    value = value + object.shieldRepairRate / object.slots * 2.5

    -- force
    if type == WeaponType.ForceGun then
        value = value + object.holdingForce / 7500
    end

    -- reach
    value = value * object.reach * (reachWeights[type] or 1)

    -- efficiency
    local bestStoneEfficiency = math.max(object.stoneRawEfficiency, object.stoneRefinedEfficiency)
    value = value * (1 + bestStoneEfficiency * (1 + ((1.2 ^ object.material.value) - 1) * 5))

    local bestMetalEfficiency = math.max(object.metalRawEfficiency, object.metalRefinedEfficiency)
    value = value * (1 + bestMetalEfficiency * (1 + ((1.1 ^ object.material.value) - 1) * 3))

    -- rocket launchers gain value if they fire seeker rockets
    if object.seeker then value = value * 2 end

    value = value * valueWeights[type] or 1

    -- rarity
    local added = math.max(0, (object.rarity.value) * (rarityWeights[type] or 0.1))
    value = value + value * added

    value = math.max(value, 100)

    return value
end


function FighterPrice(fighter)
    local value = ArmedObjectPrice(fighter)
    if value <= 0 then
        value = 100000
    end

    if fighter.type == FighterType.CrewShuttle then
        value = value + 40000
    end

    local baseValue = value * 0.125 -- this would be the price for a fighter with everything on absolute minimum

    -- the smaller the fighter, the more expensive
    local sizeFactor = lerp(fighter.diameter, 1, 2, 0.3, 0, true)
    sizeFactor = math.max(0, sizeFactor)

    -- durability
    local maxDurability = FighterUT.getMaxDurability(fighter.averageTech) * math.pow(1.2, fighter.material.value)
    local hpFactor = lerp(fighter.durability, 0, maxDurability, 0, 0.5, true)
    hpFactor = math.max(0, hpFactor)

    -- speed of 45 is median, above makes it more expensive, below makes it cheaper
    local speedFactor = lerp(fighter.maxVelocity, 30, 60, 0, 0.6, true)
    speedFactor = math.max(0, speedFactor)

    -- maneuverability of 1.75 is median, above makes it more expensive, below makes it cheaper
    local maneuverFactor = lerp(fighter.turningSpeed, 1, 2.5, 0, 0.6, true)
    maneuverFactor = math.max(0, maneuverFactor)

    local result = baseValue + (value * sizeFactor) + (value * hpFactor) + (value * speedFactor) + (value * maneuverFactor)
    result = round(result / 100) * 100
    result = math.max(result, 1000)

    return result
end

function TorpedoPrice(torpedo)

    -- print ("## price calculation for " .. torpedo.rarity.name .. " " .. torpedo.name)
    local value = 0

    -- primary stat: damage value, calculation is very similar to turrets
    local damageValue = (torpedo.hullDamage + torpedo.shieldDamage) * 0.5 -- use the average since usually only either one will be dealt
    damageValue = damageValue + torpedo.maxVelocity * torpedo.damageVelocityFactor * 0.75 -- don't weigh velocity damage as high since it depends on the situation
    if torpedo.shieldAndHullDamage then damageValue = damageValue * 2 end  -- in this case we deal both shield and hull damage -> re-increase price back to 100%

    local reachValue = torpedo.reach * 0.35

    value = value + damageValue * reachValue
    value = value / 15000  -- lower value since you can fire torpedoes only once

    -- penetration, value is two and a half times the normal value because penetration is very strong
    local penetrationValue = 0
    if torpedo.shieldPenetration then penetrationValue = value * 1.5 end
    value = value + penetrationValue

    -- EMP
    local empValue = 0
    if torpedo.shieldDeactivation then empValue = empValue + 15000 end
    if torpedo.energyDrain then empValue = empValue + 15000 end
    value = value + empValue

    -- durability
    local durabilityValue = torpedo.durability * 20
    value = value + durabilityValue

    local speedValue = value * torpedo.maxVelocity / 300 * 0.1
    value = value + speedValue

    -- maneuverability of 1 is median, above makes it more expensive, below makes it cheaper
    local maneuverValue = value * torpedo.turningSpeed * 0.25
    value = value + maneuverValue

    -- check for numerical errors that can occur by changing weapon stats to things like NaN or inf
    value = math.max(0, value)
    if value ~= value then value = 0 end
    if not (value > -math.huge and value < math.huge) then value = 0 end

    if value <= 0 then
        value = 100000
    end

    value = round(value / 100) * 100

    -- print ("damage + reach: " .. createMonetaryString(damageValue * reachValue * 0.001))
    -- print ("durability: " .. createMonetaryString(durabilityValue))
    -- print ("speed: " .. createMonetaryString(speedValue))
    -- print ("maneuver: " .. createMonetaryString(maneuverValue))
    -- print ("emp: " .. createMonetaryString(empValue))
    -- print ("penetration: " .. createMonetaryString(penetrationValue))
    -- print ("rarity: " .. createMonetaryString(rarityValue))
    -- print ("total: " .. createMonetaryString(value))
    -- print ("## end")

    return value
end
