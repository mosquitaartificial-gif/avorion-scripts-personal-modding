package.path = package.path .. ";data/scripts/lib/?.lua"

local PlanGenerator = include ("plangenerator")
local WeaponGenerator = include ("weapongenerator")
local FighterUT = include ("fighterutility")
include ("galaxy")
include ("randomext")
include ("weapontype")
include ("utility")

local FighterGenerator =  {}

function FighterGenerator.generateFighter(rand, type, dps, tech, material, rarity, factionIndex, emptyPlan)
    if type == nil then
        type = WeaponTypes.getRandom(rand)
    end

    local fighter = FighterGenerator.generateUnarmedFighter(rand, tech, material, rarity, factionIndex, emptyPlan)
    FighterGenerator.addWeapons(rand, type, dps, rarity, fighter, tech, material)

    return fighter
end

function FighterGenerator.addWeapons(rand, type, dps, rarity, fighter, tech, material)
    if type ~= WeaponType.AntiFighter then
        local weapon = WeaponGenerator.generateWeapon(rand, type, dps, tech, material, rarity)

        if weapon.holdingForce ~= 0 then weapon.holdingForce = weapon.holdingForce * 0.4 end

        fighter:addWeapon(weapon)
    end

    -- adjust fire rate of fighters so they don't slow down the simulation too much
    local weapons = {fighter:getWeapons()}
    fighter:clearWeapons()

    local baseVariation = rand:getFloat(1.0, 1.15)

    for _, weapon in pairs(weapons) do
        if weapon.isProjectile and weapon.fireRate > 2 then
            local old  = weapon.fireRate
            weapon.fireRate = rand:getFloat(1, 2)
            weapon.damage = weapon.damage * old / weapon.fireRate
            weapon.damage = weapon.damage * baseVariation
        end

        weapon.reach = math.min(weapon.reach, 350)

        fighter:addWeapon(weapon)
    end

    fighter:updateStaticStats()
end

function FighterGenerator.generateUnarmedFighter(rand, tech, material, rarity, factionIndex, emptyPlan)
    local fighter = FighterTemplate()

    local diameter = rand:getFloat(fighter.minFighterDiameter, fighter.maxFighterDiameter)
    local plan = nil
    if emptyPlan then
        plan = BlockPlan()
    else
        plan = PlanGenerator.makeFighterPlan(factionIndex, rand:createSeed(), material)

        local scale = diameter + lerp(diameter, fighter.minFighterDiameter, fighter.maxFighterDiameter, 0, 1.5)
        scale = scale / (plan.radius * 2)

        plan:scale(vec3(scale, scale, scale))
    end

    fighter.plan = plan

    local maxDurability = FighterUT.getMaxDurability(tech)

    fighter.durability = maxDurability * lerp(rarity.value, -1, 5, 0.2, 1.0) * rand:getFloat(0.9, 1) * math.pow(1.2, material.value)
    fighter.turningSpeed = rand:getFloat(1, 2.5)
    fighter.maxVelocity = rand:getFloat(30, 60)
    fighter.diameter = diameter

    if rand:test(0.2) then
        fighter.shield = maxDurability * rand:getFloat(0.25, 0.5)
    end

    return fighter
end


return FighterGenerator
