package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("randomext")
include ("utility")
include ("stringutility")
include ("defaultscripts")
local SectorFighterGenerator = include("sectorfightergenerator")
local SectorTurretGenerator = include ("sectorturretgenerator")
local UpgradeGenerator = include ("upgradegenerator")
local ShipUtility = include ("shiputility")
local PlanGenerator = include ("plangenerator")
include("weapontype")

local Xsotan = {}

function Xsotan.getFaction()
    local name = "The Xsotan"%_T

    local galaxy = Galaxy()
    local faction = galaxy:findFaction(name)
    if faction == nil then
        faction = galaxy:createFaction(name, 0, 0)
        faction.initialRelations = -100000
        faction.initialRelationsToPlayer = 0
        faction.staticRelationsToPlayers = true

        for trait, value in pairs(faction:getTraits()) do
            faction:setTrait(trait, 0) -- completely neutral / unknown
        end
    end

    faction.initialRelationsToPlayer = 0
    faction.staticRelationsToPlayers = true
    faction.homeSectorUnknown = true

    return faction
end

function Xsotan.applyCenterBuff(craft)
    local sector = Sector()
    if not sector then
        print ("no sector")
        return
    end

    local x, y = sector:getCoordinates()
    if not Balancing_InsideRing(x, y) then return end
    if Galaxy():sectorInRift(x, y) then return end

    local min = Balancing_GetBlockRingMin()
    local distance = length(vec2(x, y))
    local factor = 1 - (distance / min) -- from 0 (ring) to 1 (center)
    factor = math.min(1.0, math.max(0.0, factor)) -- clamp to between 0 and 1 just to be sure

    local upscale = 1.25 + (factor * 1.25) -- from 1.25 (ring) to 2.5 (center)

    craft.damageMultiplier = craft.damageMultiplier * upscale
end

function Xsotan.applyDamageBuff(craft)
    local sector = Sector()

    local factor = sector:getValue("xsotan_damage") or 1
    if factor ~= 1 then
        craft.damageMultiplier = craft.damageMultiplier * factor
    end
end

function Xsotan.getClassification(strength)
    local classifications = {}
    classifications[1] = {volume = 1.00, damage = 1.0, weapon = WeaponType.ChainGun, name = "Scout /* ship title */"%_T}
    classifications[2] = {volume = 1.25, damage = 1.5, weapon = WeaponType.Laser, name = "Hunter /* ship title */"%_T}
    classifications[3] = {volume = 1.50, damage = 1.5, weapon = WeaponType.Bolter, name = "Corvette /* ship title */"%_T}
    classifications[4] = {volume = 1.75, damage = 2.0, weapon = WeaponType.PulseCannon, name = "Frigate /* ship title */"%_T}
    classifications[5] = {volume = 1.75, damage = 2.5, weapon = WeaponType.PlasmaGun, name = "Cruiser /* ship title */"%_T}
    classifications[6] = {volume = 2.00, damage = 3.0, weapon = WeaponType.RailGun, name = "Destroyer /* ship title */"%_T}
    classifications[7] = {volume = 2.00, damage = 3.5, weapon = WeaponType.LightningGun, name = "Battleship /* ship title */"%_T}

    local sector = Sector()
    if not strength then strength = Sector():getValue("xsotan_strength") end

    if not strength then
        local x, y = sector:getCoordinates()
        local distFromCenter = length(vec2(x, y))
        strength = round(lerp(distFromCenter, 500, 0, 1, 7))
    end

    local classification = strength
    local offsetProbabilities = {}
    offsetProbabilities[1] = 0.35
    offsetProbabilities[0] = 0.5
    offsetProbabilities[-1] = 0.35
    offsetProbabilities[-2] = 0.2

    local offset = selectByWeight(random(), offsetProbabilities)
    classification = classification + offset
    if classification < 1 then classification = 1 end
    if classification > #classifications then classification = #classifications end

    return classifications[classification]
end

function Xsotan.getShipVolume()
    local sector = Sector()
    local volume = Balancing_GetSectorShipVolume(sector:getCoordinates())
    local modifier = sector:getValue("xsotan_volume") or 1

    return volume * modifier
end

function Xsotan.addTurrets(ship, weaponType, rarityType, numTurrets, dropTurretsOnDesctruction)
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false
    local x, y = Sector():getCoordinates()

    local turret
    if weaponType then
        turret = generator:generate(x, y, 0, Rarity(rarityType), weaponType, nil)
    else
        turret = generator:generateArmed(x, y, 0, Rarity(rarityType))
    end

    local numTurrets = numTurrets or math.max(2, Balancing_GetEnemySectorTurrets(x, y) * 0.75)
    ShipUtility.addTurretsToCraft(ship, turret, numTurrets)
end

function Xsotan.addFighters(ship, numFightersToAdd)
    local hangar = Hangar(ship.index)
    hangar:addSquad("Alpha")
    hangar:addSquad("Beta")
    hangar:addSquad("Gamma")

    local generator = SectorFighterGenerator()
    generator.factionIndex = Xsotan.getFaction()
    local x, y = Sector():getCoordinates()

    local numFighters = 0
    for squad = 0, 2 do
        local fighter = generator:generateArmed(x, y)
        for i = 1, 7 do
            hangar:addFighter(squad, fighter)

            numFighters = numFighters + 1
            if numFighters >= numFightersToAdd then break end
        end

        if numFighters >= numFightersToAdd then break end
    end
end

function Xsotan.updateCrewAndBuffs(ship, applyCenterBuff, applyDamageBuff)
    ship.crew = ship.idealCrew
    ship.shieldDurability = ship.shieldMaxDurability

    if applyCenterBuff then
        Xsotan.applyCenterBuff(ship)
    end

    if applyDamageBuff then
        Xsotan.applyDamageBuff(ship)
    end
end

function Xsotan.addDefaultScriptsAndValues(ship)
    AddDefaultShipScripts(ship)

    ship:addScriptOnce("ai/patrol.lua")
    ship:addScriptOnce("story/xsotanbehaviour.lua")
    ship:addScriptOnce("utility/aiundockable.lua")
    ship:setValue("is_xsotan", true)

    Boarding(ship).boardable = false
end

function Xsotan.createShip(position, volumeFactor)
    position = position or Matrix()
    local volume = Xsotan.getShipVolume()

    volume = volume * (volumeFactor or 1)
    volume = volume * 0.5 -- xsotan ships aren't supposed to be very big

    local classification = Xsotan.getClassification()
    volume = volume * classification.volume

    local x, y = Sector():getCoordinates()
    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))
    local faction = Xsotan.getFaction()
    local plan = PlanGenerator.makeXsotanShipPlan(volume, material)
    local ship = Sector():createShip(faction, "", plan, position, EntityArrivalType.Jump)

    -- add turrets
    local weaponType = classification.weapon
    if random():test(0.1) then
        weaponType = nil -- some have random weapon type
    end

    Xsotan.addTurrets(ship, weaponType, RarityType.Common)

    ship:setTitle("${toughness}Xsotan ${ship}"%_T, {toughness = "", ship = classification.name})
    ship.damageMultiplier = ship.damageMultiplier * classification.damage

    Xsotan.updateCrewAndBuffs(ship, true, true)
    Xsotan.addDefaultScriptsAndValues(ship)

    return ship
end

function Xsotan.createCarrier(position, volumeFactor, fighters)
    position = position or Matrix()
    fighters = fighters or 30
    local volume = Xsotan.getShipVolume()

    volume = volume * (volumeFactor or 1)
    volume = volume * 1.5

    local x, y = Sector():getCoordinates()
    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))

    local faction = Xsotan.getFaction()
    local plan = PlanGenerator.makeXsotanCarrierPlan(volume, material)
    local ship = Sector():createShip(faction, "", plan, position, EntityArrivalType.Jump)

    -- add fighters
    Xsotan.addFighters(ship, fighters)

    -- add turrets
    local numTurrets = math.max(1, Balancing_GetEnemySectorTurrets(x, y) * 0.5)
    Xsotan.addTurrets(ship, nil, RarityType.Rare, numTurrets)

    ship.title = "Xsotan Cultivator"%_T
    Xsotan.updateCrewAndBuffs(ship, true, true)
    Xsotan.addDefaultScriptsAndValues(ship)

    return ship
end

function Xsotan.createQuantum(position, volumeFactor)
    position = position or Matrix()
    local volume = Xsotan.getShipVolume()

    volume = volume * (volumeFactor or 1)
    volume = volume * 0.5 -- xsotan ships aren't supposed to be very big

    local x, y = Sector():getCoordinates()
    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))
    local faction = Xsotan.getFaction()
    local plan = PlanGenerator.makeXsotanShipPlan(volume, material)
    local ship = Sector():createShip(faction, "", plan, position)

    -- add turrets
    Xsotan.addTurrets(ship, nil, RarityType.Rare)

    local name, type = ShipUtility.getMilitaryNameByVolume(ship.volume)
    ship:setTitle("${toughness}Quantum Xsotan ${ship}"%_T, {toughness = "", ship = name})
    Xsotan.updateCrewAndBuffs(ship, true, true)
    Xsotan.addDefaultScriptsAndValues(ship)

    ship:addScriptOnce("enemies/blinker.lua")
    ship.dockable = false

    return ship
end

function Xsotan.createDasher(position, volumeFactor)
    position = position or Matrix()
    local volume = Balancing_GetSectorShipVolume(Sector():getCoordinates())

    volume = volume * (volumeFactor or 5)
    volume = volume * 0.5 -- xsotan ships aren't supposed to be very big

    local x, y = Sector():getCoordinates()
    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))
    local faction = Xsotan.getFaction()
    local plan = PlanGenerator.makeXsotanShipPlan(volume, material)
    local ship = Sector():createShip(faction, "", plan, position)

    -- Xsotan have random turrets
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false

    local turret = generator:generateArmed(x, y, 0, Rarity(RarityType.Rare))
    local numTurrets = math.max(2, Balancing_GetEnemySectorTurrets(x, y) * 0.75)

    ShipUtility.addTurretsToCraft(ship, turret, numTurrets)

    local name, type = ShipUtility.getMilitaryNameByVolume(ship.volume)
    ship:setTitle("${toughness}Xsotan Dasher ${ship}"%_T, {toughness = "", ship = name})
    ship.crew = ship.idealCrew
    ship.shieldDurability = ship.shieldMaxDurability

    Xsotan.applyCenterBuff(ship)

    AddDefaultShipScripts(ship)

    ship:addScriptOnce("ai/patrol.lua")
    ship:addScriptOnce("story/xsotanbehaviour.lua")
    ship:addScriptOnce("internal/dlc/rift/entity/dasherxsotan.lua")
    ship:setValue("is_xsotan", true)

    Boarding(ship).boardable = false
    ship.dockable = false

    return ship
end

function Xsotan.createSummoner(position, volumeFactor)
    position = position or Matrix()
    local volume = Xsotan.getShipVolume()

    volume = volume * (volumeFactor or 5)
    volume = volume * 0.5 -- xsotan ships aren't supposed to be very big

    local x, y = Sector():getCoordinates()
    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))
    local faction = Xsotan.getFaction()
    local plan = PlanGenerator.makeXsotanShipPlan(volume, material)
    local ship = Sector():createShip(faction, "", plan, position)

    -- Xsotan have random turrets
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false

    local turret = generator:generateArmed(x, y, 0, Rarity(RarityType.Rare))
    local numTurrets = math.max(2, Balancing_GetEnemySectorTurrets(x, y) * 0.75)

    ShipUtility.addTurretsToCraft(ship, turret, numTurrets)

    ship:setTitle("${toughness}Xsotan Summoner"%_T, {toughness = ""})
    ship.crew = ship.idealCrew
    ship.shieldDurability = ship.shieldMaxDurability

    Xsotan.applyCenterBuff(ship)
    Xsotan.applyDamageBuff(ship)

    AddDefaultShipScripts(ship)

    ship:addScriptOnce("ai/patrol.lua")
    ship:addScriptOnce("story/xsotanbehaviour.lua")
    ship:addScriptOnce("enemies/summoner.lua")
    ship:setValue("is_xsotan", true)

    Boarding(ship).boardable = false
    ship.dockable = false

    return ship
end

function Xsotan.createShielded(position, volumeFactor)
    position = position or Matrix()
    local volume = Xsotan.getShipVolume()

    volume = volume * (volumeFactor or 5)
    volume = volume * 0.5 -- xsotan ships aren't supposed to be very big

    local x, y = Sector():getCoordinates()
    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))
    if material.value < MaterialType.Naonite then material = Material(MaterialType.Naonite) end

    local faction = Xsotan.getFaction()
    local plan = PlanGenerator.makeXsotanShipPlan(volume, material)
    plan:addBlock(vec3(), vec3(1, 1, 1), plan.rootIndex, -1, ColorRGB(1, 1, 1), material, Matrix(), BlockType.ShieldGenerator, ColorNone())

    local ship = Sector():createShip(faction, "", plan, position)

    -- Xsotan have random turrets
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false

    local turret = generator:generateArmed(x, y, 0, Rarity(RarityType.Rare))
    local numTurrets = math.max(2, Balancing_GetEnemySectorTurrets(x, y) * 0.75)

    ShipUtility.addTurretsToCraft(ship, turret, numTurrets)

    local name, type = ShipUtility.getMilitaryNameByVolume(ship.volume)
    ship:setTitle("${toughness}Shielded Xsotan ${ship}"%_T, {toughness = "", ship = name})
    ship.crew = ship.idealCrew
    ship.shieldDurability = ship.shieldMaxDurability

    Xsotan.applyCenterBuff(ship)
    Xsotan.applyDamageBuff(ship)

    AddDefaultShipScripts(ship)

    ship:addScriptOnce("ai/patrol.lua")
    ship:addScriptOnce("story/xsotanbehaviour.lua")
    ship:addScriptOnce("internal/dlc/rift/entity/shieldedxsotan.lua")
    ship:setValue("is_xsotan", true)

    Boarding(ship).boardable = false
    ship.dockable = false

    return ship
end

function Xsotan.createMasterSummoner(position, volumeFactor)
    position = position or Matrix()
    local volume = Xsotan.getShipVolume()

    volume = volume * (volumeFactor or 5)
    volume = volume * 0.5 -- xsotan ships aren't supposed to be very big

    local x, y = Sector():getCoordinates()
    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))
    if material.value < MaterialType.Naonite then material = Material(MaterialType.Naonite) end

    local faction = Xsotan.getFaction()
    local plan = PlanGenerator.makeXsotanShipPlan(volume, material)
    plan:addBlock(vec3(), vec3(1, 1, 1), plan.rootIndex, -1, ColorRGB(1, 1, 1), material, Matrix(), BlockType.ShieldGenerator, ColorNone())

    local ship = Sector():createShip(faction, "", plan, position)

    -- Xsotan have random turrets
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false

    local turret = generator:generateArmed(x, y, 0, Rarity(RarityType.Rare))
    local numTurrets = math.max(2, Balancing_GetEnemySectorTurrets(x, y) * 0.75)

    ShipUtility.addTurretsToCraft(ship, turret, numTurrets)

    ship:setTitle("Xsotan Master Summoner"%_T, {})
    ship.crew = ship.idealCrew
    ship.shieldDurability = ship.shieldMaxDurability

    Xsotan.applyCenterBuff(ship)
    Xsotan.applyDamageBuff(ship)

    AddDefaultShipScripts(ship)

    ship:addScriptOnce("ai/patrol.lua")
    ship:addScriptOnce("story/xsotanbehaviour.lua")
    ship:addScriptOnce("internal/dlc/rift/entity/shieldedxsotansummoner.lua")
    ship:setValue("is_xsotan", true)

    Boarding(ship).boardable = false
    ship.dockable = false

    return ship
end

function Xsotan.createLongRange(position, volumeFactor)
    position = position or Matrix()
    local volume = Xsotan.getShipVolume()

    volume = volume * (volumeFactor or 1)
    volume = volume * 0.5 -- xsotan ships aren't supposed to be very big

    local x, y = Sector():getCoordinates()
    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))
    local faction = Xsotan.getFaction()
    local plan = PlanGenerator.makeXsotanShipPlan(volume, material)
    local ship = Sector():createShip(faction, "", plan, position, EntityArrivalType.Jump)

    -- Long Range Xsotan need turrets with high maximum range
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false

    local turret = generator:generate(x, y, 0, Rarity(), WeaponType.Cannon)
    local weapons = {turret:getWeapons()}
    turret:clearWeapons()
    for _, weapon in pairs(weapons) do
        weapon.reach = 1800
        turret:addWeapon(weapon)
    end

    turret.turningSpeed = 2.0
    turret.crew = Crew()

    local numTurrets = math.max(2, Balancing_GetEnemySectorTurrets(x, y) * 0.75)

    ShipUtility.addTurretsToCraft(ship, turret, numTurrets)

    local name, type = ShipUtility.getMilitaryNameByVolume(ship.volume)
    ship:setTitle("${toughness}Xsotan Bombardier ${ship}"%_T, {toughness = "", ship = name})
    ship.crew = ship.idealCrew
    ship.shieldDurability = ship.shieldMaxDurability
    ship:setDropsAttachedTurrets(false)

    Durability(ship).maxDurabilityFactor = 0.3

    Xsotan.applyCenterBuff(ship)
    Xsotan.applyDamageBuff(ship)

    AddDefaultShipScripts(ship)

    ship:addScriptOnce("ai/patrol.lua")
    ship:addScriptOnce("story/xsotanbehaviour.lua")
    ship:addScriptOnce("utility/aiundockable.lua")
    ship:setValue("is_xsotan", true)

    Boarding(ship).boardable = false
    ship.dockable = false

    return ship
end

function Xsotan.createShortRange(position, volumeFactor)
    position = position or Matrix()
    local volume = Xsotan.getShipVolume()

    volume = volume * (volumeFactor or 1)
    volume = volume * 0.5 -- xsotan ships aren't supposed to be very big

    local x, y = Sector():getCoordinates()
    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))
    local faction = Xsotan.getFaction()
    local plan = PlanGenerator.makeXsotanShipPlan(volume, material) -- Checken
    local ship = Sector():createShip(faction, "", plan, position, EntityArrivalType.Jump)

    -- Short Range Xsotan need turrets with short maximum range
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false

    local turret = generator:generate(x, y, 0, Rarity(), WeaponType.TeslaGun)
    local weapons = {turret:getWeapons()}
    turret:clearWeapons()
    for _, weapon in pairs(weapons) do
        weapon.reach = 250
        turret:addWeapon(weapon)
    end

    turret.turningSpeed = 2.0
    turret.crew = Crew()

    local numTurrets = math.max(2, Balancing_GetEnemySectorTurrets(x, y) * 0.75)

    ShipUtility.addTurretsToCraft(ship, turret, numTurrets)

    local name, type = ShipUtility.getMilitaryNameByVolume(ship.volume)
    ship:setTitle("${toughness}Xsotan Jostler ${ship}"%_T, {toughness = "", ship = name})
    ship.crew = ship.idealCrew
    ship.shieldDurability = ship.shieldMaxDurability
    ship:setDropsAttachedTurrets(false)

    Xsotan.applyCenterBuff(ship)
    Xsotan.applyDamageBuff(ship)

    AddDefaultShipScripts(ship)

    ship:addScriptOnce("ai/patrol.lua")
    ship:addScriptOnce("story/xsotanbehaviour.lua")
    ship:addScriptOnce("utility/aiundockable.lua")
    ship:setValue("is_xsotan", true)

    Boarding(ship).boardable = false
    ship.dockable = false

    return ship
end

function Xsotan.createLootGoon(position, volumeFactor)
    position = position or Matrix()
    local volume = Xsotan.getShipVolume()

    volume = volume * (volumeFactor or 2)
    volume = volume * 0.5 -- xsotan ships aren't supposed to be very big

    local x, y = Sector():getCoordinates()
    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))
    if material.value < MaterialType.Naonite then material = Material(MaterialType.Naonite) end

    local faction = Xsotan.getFaction()
    local plan = PlanGenerator.makeXsotanShipPlan(volume, material)
    plan:addBlock(vec3(), vec3(1, 1, 1), plan.rootIndex, -1, ColorRGB(1, 1, 1), material, Matrix(), BlockType.ShieldGenerator, ColorNone())

    local ship = Sector():createShip(faction, "", plan, position)

    -- Xsotan have random turrets
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false

    local turret = generator:generateArmed(x, y, 0, Rarity(RarityType.Rare))
    local numTurrets = math.max(2, Balancing_GetEnemySectorTurrets(x, y) * 0.75)

    ShipUtility.addTurretsToCraft(ship, turret, numTurrets)

    ship:setTitle("Xsotan Aggregator"%_T, {})
    ship.crew = ship.idealCrew
    ship.shieldDurability = ship.shieldMaxDurability

    Xsotan.applyCenterBuff(ship)
    Xsotan.applyDamageBuff(ship)

    AddDefaultShipScripts(ship)

    ship:addScriptOnce("ai/patrol.lua")
    ship:addScriptOnce("story/xsotanbehaviour.lua")
    ship:addScriptOnce("internal/dlc/rift/entity/xsotanlootgoon.lua")
    ship:setValue("is_xsotan", true)

    Boarding(ship).boardable = false
    ship.dockable = false

    return ship
end

function Xsotan.createBuffer(position, volumeFactor)
    position = position or Matrix()
    local volume = Xsotan.getShipVolume()

    volume = volume * (volumeFactor or 2)
    volume = volume * 0.5 -- xsotan ships aren't supposed to be very big

    local x, y = Sector():getCoordinates()
    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))
    if material.value < MaterialType.Naonite then material = Material(MaterialType.Naonite) end

    local faction = Xsotan.getFaction()
    local plan = PlanGenerator.makeXsotanShipPlan(volume, material)
    plan:addBlock(vec3(), vec3(1, 1, 1), plan.rootIndex, -1, ColorRGB(1, 1, 1), material, Matrix(), BlockType.ShieldGenerator, ColorNone())

    local ship = Sector():createShip(faction, "", plan, position)

    -- Xsotan have random turrets
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false

    local turret = generator:generateArmed(x, y, 0, Rarity(RarityType.Rare))
    local numTurrets = math.max(2, Balancing_GetEnemySectorTurrets(x, y) * 0.75)

    ShipUtility.addTurretsToCraft(ship, turret, numTurrets)

    ship:setTitle("Xsotan Amplifier"%_T, {})
    ship.crew = ship.idealCrew
    ship.shieldDurability = ship.shieldMaxDurability

    Xsotan.applyCenterBuff(ship)
    Xsotan.applyDamageBuff(ship)

    AddDefaultShipScripts(ship)

    ship:addScriptOnce("ai/patrol.lua")
    ship:addScriptOnce("story/xsotanbehaviour.lua")
    ship:addScriptOnce("internal/dlc/rift/entity/xsotanbuffer.lua")
    ship:setValue("is_xsotan", true)

    Boarding(ship).boardable = false
    ship.dockable = false

    return ship
end

local function attachMax(plan, attachment, dimStr)
    local self = findMaxBlock(plan, dimStr)
    local other = findMinBlock(attachment, dimStr)

    plan:addPlanDisplaced(self.index, attachment, other.index, self.box.center - other.box.center)
end

local function attachMin(plan, attachment, dimStr)
    local self = findMinBlock(plan, dimStr)
    local other = findMaxBlock(attachment, dimStr)

    plan:addPlanDisplaced(self.index, attachment, other.index, self.box.center - other.box.center)
end


function Xsotan.createMasticator(position, volumeFactor)
    position = position or Matrix()

    local sector = Sector()
    local x, y = sector:getCoordinates()
    local volume = Xsotan.getShipVolume()

    volume = volume * (volumeFactor or 25)

    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))
    local faction = Xsotan.getFaction()
    local plan = PlanGenerator.makeXsotanShipPlan(volume, material)

    local originalBlockIndices = {}
    for _, index in pairs({plan:getBlockIndices()}) do
        originalBlockIndices[index] = true
    end

    -- attach masticator weapon
    local weaponPlan = LoadPlanFromString(loadInternalData("plans/xsotan-masticator-weapon.xml"))
    local scaleFactor = plan.radius / weaponPlan.radius / 6.5
    weaponPlan:scale(vec3(scaleFactor))
    attachMax(plan, weaponPlan, "z")

    local ship = sector:createShip(faction, "", plan, position, EntityArrivalType.Jump)

    -- make masticator weapon blocks indestructible
    local plan = Plan(ship)
    for _, index in pairs({plan:getBlockIndices()}) do
        if not originalBlockIndices[index] then
            plan:setBlockDamageFactor(index, 0)
        end
    end

    -- Xsotan have random turrets
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false

    local turret = generator:generateArmed(x, y, 0, Rarity())
    local numTurrets = math.max(2, Balancing_GetEnemySectorTurrets(x, y) * 0.75)

    ShipUtility.addTurretsToCraft(ship, turret, numTurrets)

    ship.crew = ship.idealCrew
    ship.shieldDurability = ship.shieldMaxDurability

    Xsotan.applyCenterBuff(ship)
    Xsotan.applyDamageBuff(ship)

    AddDefaultShipScripts(ship)

    ship.title = "Xsotan Masticator"%_T

    ship:addScriptOnce("story/xsotanbehaviour.lua")
    ship:addScriptOnce("utility/aiundockable.lua")
    ship:addScriptOnce("deleteonplayersleft.lua")
    ship:addScriptOnce("internal/dlc/rift/entity/xsotanmasticator.lua")
    -- this script is necessary so it can control the fighters that get spawned
    ship:addScriptOnce("internal/dlc/rift/entity/xsotanbreedermothership.lua")

    ship:setValue("is_xsotan", true)
    ship:setValue("xsotan_no_despawn", true)

    Loot(ship):insert(InventoryTurret(SectorTurretGenerator():generate(x, y, 0, Rarity(RarityType.Exotic))))
    Loot(ship):insert(InventoryTurret(SectorTurretGenerator():generate(x, y, 0, Rarity(RarityType.Exotic))))
    ship:addScriptOnce("internal/common/entity/background/legendaryloot.lua")

    Boarding(ship).boardable = false

    return ship
end


function Xsotan.createPlasmaTurret()
    local generator = SectorTurretGenerator(Seed(151))
    generator.coaxialAllowed = false

    local turret = generator:generate(0, 0, 0, Rarity(RarityType.Uncommon), WeaponType.PlasmaGun)
    local weapons = {turret:getWeapons()}
    turret:clearWeapons()
    for _, weapon in pairs(weapons) do
        weapon.reach = 600
        weapon.pmaximumTime = weapon.reach / weapon.pvelocity
        weapon.hullDamageMultiplier = 0.35
        turret:addWeapon(weapon)
    end

    turret.turningSpeed = 2.0
    turret.crew = Crew()

    return turret
end

function Xsotan.createLaserTurret()
    local generator = SectorTurretGenerator(Seed(152))
    generator.coaxialAllowed = false

    local turret = generator:generate(0, 0, 0, Rarity(RarityType.Exceptional), WeaponType.Laser)
    local weapons = {turret:getWeapons()}
    turret:clearWeapons()
    for _, weapon in pairs(weapons) do
        weapon.reach = 600
        weapon.blength = 600
        turret:addWeapon(weapon)
    end

    turret.turningSpeed = 2.0
    turret.crew = Crew()

    return turret
end

function Xsotan.createRailgunTurret()
    local turret = SectorTurretGenerator(Seed(153)):generate(0, 0, 0, Rarity(RarityType.Uncommon), WeaponType.RailGun, nil, false)
    local weapons = {turret:getWeapons()}
    turret:clearWeapons()
    for _, weapon in pairs(weapons) do
        weapon.reach = 1000
        turret:addWeapon(weapon)
    end

    turret.turningSpeed = 2.0
    turret.crew = Crew()

    return turret
end

function Xsotan.createGuardian(position, volumeFactor)
    position = position or Matrix()
    local volume = Xsotan.getShipVolume()

    volume = volume * (volumeFactor or 10)

    local x, y = Sector():getCoordinates()
    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(MaterialType.Avorion)
    local faction = Xsotan.getFaction()

    local plan = PlanGenerator.makeXsotanShipPlan(volume, material)
    local front = PlanGenerator.makeXsotanShipPlan(volume, material)
    local back = PlanGenerator.makeXsotanShipPlan(volume, material)
    local top = PlanGenerator.makeXsotanShipPlan(volume, material)
    local bottom = PlanGenerator.makeXsotanShipPlan(volume, material)
    local left = PlanGenerator.makeXsotanShipPlan(volume, material)
    local right = PlanGenerator.makeXsotanShipPlan(volume, material)
    local frontleft= PlanGenerator.makeXsotanShipPlan(volume, material)
    local frontright = PlanGenerator.makeXsotanShipPlan(volume, material)

    Xsotan.infectPlan(plan)
    Xsotan.infectPlan(front)
    Xsotan.infectPlan(back)
    Xsotan.infectPlan(top)
    Xsotan.infectPlan(bottom)
    Xsotan.infectPlan(left)
    Xsotan.infectPlan(right)
    Xsotan.infectPlan(frontleft)
    Xsotan.infectPlan(frontright)

    --
    attachMin(plan, back, "z")
    attachMax(plan, front, "z")
    attachMax(plan, front, "z")

    attachMin(plan, bottom, "y")
    attachMax(plan, top, "y")

    attachMin(plan, left, "x")
    attachMax(plan, right, "x")

    local self = findMaxBlock(plan, "z")
    local other = findMinBlock(frontleft, "x")
    plan:addPlanDisplaced(self.index, frontleft, other.index, self.box.center - other.box.center)

    local other = findMaxBlock(frontright, "x")
    plan:addPlanDisplaced(self.index, frontright, other.index, self.box.center - other.box.center)

    Xsotan.infectPlan(plan)
    local boss = Sector():createShip(faction, "", plan, position, EntityArrivalType.Jump)

    -- Xsotan have random turrets

    local numTurrets = math.max(1, Balancing_GetEnemySectorTurrets(x, y) / 2)

    ShipUtility.addTurretsToCraft(boss, Xsotan.createPlasmaTurret(), numTurrets, numTurrets)
    ShipUtility.addTurretsToCraft(boss, Xsotan.createLaserTurret(), numTurrets, numTurrets)
    ShipUtility.addTurretsToCraft(boss, Xsotan.createRailgunTurret(), numTurrets, numTurrets)
    ShipUtility.addBossAntiTorpedoEquipment(boss)

    boss.title = "Xsotan Wormhole Guardian"%_T
    boss.crew = boss.idealCrew
    boss.shieldDurability = boss.shieldMaxDurability

    local upgrades =
    {
        {rarity = Rarity(RarityType.Legendary), amount = 2},
        {rarity = Rarity(RarityType.Exotic), amount = 3},
        {rarity = Rarity(RarityType.Exceptional), amount = 3},
        {rarity = Rarity(RarityType.Rare), amount = 5},
        {rarity = Rarity(RarityType.Uncommon), amount = 8},
        {rarity = Rarity(RarityType.Common), amount = 14},
    }

    local turrets =
    {
        {rarity = Rarity(RarityType.Legendary), amount = 2},
        {rarity = Rarity(RarityType.Exotic), amount = 3},
        {rarity = Rarity(RarityType.Exceptional), amount = 3},
        {rarity = Rarity(RarityType.Rare), amount = 5},
        {rarity = Rarity(RarityType.Uncommon), amount = 8},
        {rarity = Rarity(RarityType.Common), amount = 14},
    }

    local generator = UpgradeGenerator()
    for _, p in pairs(upgrades) do
        for i = 1, p.amount do
            Loot(boss.index):insert(generator:generateSectorSystem(x, y, p.rarity))
        end
    end

    for _, p in pairs(turrets) do
        for i = 1, p.amount do
            Loot(boss.index):insert(InventoryTurret(SectorTurretGenerator():generate(x, y, 0, p.rarity)))
        end
    end

    Xsotan.applyCenterBuff(boss)
    Xsotan.applyDamageBuff(boss)

    AddDefaultShipScripts(boss)
    -- adds legendary turret drop
    boss:addScriptOnce("internal/common/entity/background/legendaryloot.lua")
    boss:addScriptOnce("utility/buildingknowledgeloot.lua")

    boss:addScriptOnce("story/wormholeguardian.lua")
    boss:addScriptOnce("story/xsotanbehaviour.lua")
    boss:setValue("is_xsotan", true)

    Boarding(boss).boardable = false
    boss.dockable = false
    boss:setDropsAttachedTurrets(false)

    return boss
end

function Xsotan.infectAsteroids()
    local x, y = Sector():getCoordinates()

    local dist = length(vec2(x, y))
    local toInfect = lerp(dist, 150, 50, 5, 250)
    local infected = {}
    local numInfected = 0

    local asteroids = {Sector():getEntitiesByType(EntityType.Asteroid)}
    shuffle(random(), asteroids)

    while numInfected < toInfect and #asteroids > 0 do

        -- pick a random asteroid
        local asteroid = asteroids[#asteroids]
        asteroids[#asteroids] = nil

        if not infected[asteroid.index.string] then

            -- find surroundings
            local current = {Sector():getEntitiesByLocation(Sphere(asteroid.translationf, 60))}
            table.insert(current, asteroid)

            -- infect it and surrounding asteroids
            for _, nextTarget in pairs(current) do
                if nextTarget.isAsteroid and not infected[nextTarget.index.string] then
                    local infectedAsteroid = Xsotan.infect(nextTarget, getInt(1, 2))

                    infected[infectedAsteroid.index.string] = true
                    numInfected = numInfected + 1
                end
            end
        end
    end

end

function Xsotan.createSmallInfectedAsteroid(position, level)
    level = level or 2

    local sector = Sector()
    local probabilities = Balancing_GetTechnologyMaterialProbability(sector:getCoordinates())
    local material = Material(getValueFromDistribution(probabilities))

    local size = getFloat(5, 15)
    local plan = PlanGenerator.makeSmallAsteroidPlan(size, resources, material)

    local addition = Xsotan.makeInfectAddition(vec3(size * 2.0, size * 0.5, size * 2.0), material, level)

    local desc = AsteroidDescriptor()
    desc:removeComponent(ComponentType.MineableMaterial)
    desc:addComponents(
        ComponentType.Owner,
        ComponentType.FactionNotifier,
        ComponentType.Title
    )

    plan:addPlan(plan.rootIndex, addition, 0)

    desc:setMovePlan(plan)
    desc.position = position
    desc.title = "Small Xsotan Breeder"%_t
    desc.factionIndex = Xsotan.getFaction().index

    return sector:createEntity(desc)
end

function Xsotan.infectPlan(plan)
    plan:center()

    local tree = PlanBspTree(plan)

    local height = plan:getBoundingBox().size.y

    local positions = {}

    for i = 0, 15 do

        local rad = getFloat(0, math.pi * 2)
        local hspread = height / getFloat(2.5, 3.5)

        for h = -hspread, hspread, 15 do
            local ray = Ray()
            ray.origin = vec3(math.sin(rad), 0, math.cos(rad)) * 100 + vec3(getFloat(10, 100), 0, getFloat(10, 100))
            ray.direction = -ray.origin

            ray.origin = ray.origin + vec3(0, h + getFloat(-7.5, 7.5), 0)

            local dir = normalize(ray.direction)

            local index, p = tree:intersectRay(ray, 0, 1)
            if index then
                table.insert(positions, {position = p + dir, index = index})
            end
        end
    end

    local material = plan.root.material

    for _, p in pairs(positions) do
        local addition = Xsotan.makeInfectAddition(vec3(15, 4, 15), material, 0)

        addition:scale(vec3(getFloat(0.5, 2.5), getFloat(0.9, 1.1), getFloat(0.5, 2.5)))
        addition:center()

        plan:addPlanDisplaced(p.index, addition, addition.rootIndex, p.position)
    end

end

function Xsotan.createBigInfectedAsteroid(position)
    local probabilities = Balancing_GetTechnologyMaterialProbability(Sector():getCoordinates())
    local material = Material(getValueFromDistribution(probabilities))

    local plan = PlanGenerator.makeBigAsteroidPlan(100, false, material)
    Xsotan.infectPlan(plan)

    local desc = AsteroidDescriptor()
    desc:removeComponent(ComponentType.MineableMaterial)
    desc:addComponents(
       ComponentType.Owner,
       ComponentType.FactionNotifier,
       ComponentType.Title
       )

    desc.title = "Big Xsotan Breeder"%_t
    desc.position = MatrixLookUpPosition(random():getDirection(), random():getDirection(), position)
    desc:setMovePlan(plan)
    desc.factionIndex = Xsotan.getFaction().index

    return Sector():createEntity(desc)
end

function Xsotan.makeInfectAddition(size, material, level)

    level = level or 0

    local color = ColorRGB(0.35, 0.35, 0.35)

    local ls = vec3(getFloat(0.1, 0.3), getFloat(0.1, 0.3), getFloat(0.1, 0.3))
    local us = vec3(getFloat(0.1, 0.3), getFloat(0.1, 0.3), getFloat(0.1, 0.3))
    local s = vec3(1, 1, 1) - ls - us

    local hls = ls * 0.5
    local hus = us * 0.5
    local hs = s * 0.5

    local center = BlockType.BlankHull
    local edge = BlockType.EdgeHull
    local corner = BlockType.CornerHull

    local plan = BlockPlan()
    local ci = plan:addBlock(vec3(0, 0, 0), s, -1, -1, color, material, Matrix(), center, ColorNone())

    -- top left right
    plan:addBlock(vec3(hs.x + hus.x, 0, 0), vec3(us.x, s.y, s.z), ci, -1, color, material, MatrixLookUp(vec3(-1, 0, 0), vec3(0, 1, 0)), edge, ColorNone())
    plan:addBlock(vec3(-hs.x - hls.x, 0, 0), vec3(ls.x, s.y, s.z), ci, -1, color, material, MatrixLookUp(vec3(1, 0, 0), vec3(0, 1, 0)), edge, ColorNone())

    -- top front back
    plan:addBlock(vec3(0, 0, hs.z + hus.z), vec3(s.x, s.y, us.z), ci, -1, color, material, MatrixLookUp(vec3(0, 0, -1), vec3(0, 1, 0)), edge, ColorNone())
    plan:addBlock(vec3(0, 0, -hs.z - hls.z), vec3(s.x, s.y, ls.z), ci, -1, color, material, MatrixLookUp(vec3(0, 0, 1), vec3(0, 1, 0)), edge, ColorNone())

    -- top edges
    -- left right
    plan:addBlock(vec3(hs.x + hus.x, 0, -hs.z - hls.z), vec3(us.x, s.y, ls.z), ci, -1, color, material, MatrixLookUp(vec3(-1, 0, 0), vec3(0, 1, 0)), corner, ColorNone())
    plan:addBlock(vec3(-hs.x - hls.x, 0, -hs.z - hls.z), vec3(ls.x, s.y, ls.z), ci, -1, color, material, MatrixLookUp(vec3(1, 0, 0), vec3(0, 0, -1)), corner, ColorNone())

    -- front back
    plan:addBlock(vec3(hs.x + hus.x, 0, hs.z + hus.z), vec3(us.x, s.y, us.z), ci, -1, color, material, MatrixLookUp(vec3(-1, 0, 0), vec3(0, 0, 1)), corner, ColorNone())
    plan:addBlock(vec3(-hs.x - hls.x, 0, hs.z + hus.z), vec3(ls.x, s.y, us.z), ci, -1, color, material, MatrixLookUp(vec3(1, 0, 0), vec3(0, 1, 0)), corner, ColorNone())

    plan:scale(size)

    local addition = copy(plan)
    addition:displace(vec3(size.x * 0.05, -size.y * getFloat(0.6, 0.9), size.z * 0.05))

    if level >= 1 then
        local displacement = vec3(
            size.x * getFloat(0.1, 0.2),
            0,
            size.z * getFloat(0.1, 0.2)
        )

        addition:addPlanDisplaced(addition.rootIndex, plan, 0, displacement)
    end
    if level >= 2 then
        local displacement = vec3(
            size.x * getFloat(0.2, 0.3),
            size.y * getFloat(0.6, 0.9),
            size.z * getFloat(0.2, 0.3)
        )

        addition:addPlanDisplaced(addition.rootIndex, plan, 0, displacement)
    end

    return addition
end

function Xsotan.infect(asteroid, level)

    local material = Plan(asteroid.index).root.material

    local size = asteroid.size
    size.y = size.y * 0.25

    local addition = Xsotan.makeInfectAddition(size, material, level)

    local desc = AsteroidDescriptor()
    desc:removeComponent(ComponentType.MineableMaterial)
    desc:addComponents(
       ComponentType.Owner,
       ComponentType.FactionNotifier,
       ComponentType.Title
    )

    local plan = asteroid:getMovePlan()
    plan:addPlan(plan.rootIndex, addition, 0)

    desc:setMovePlan(plan)
    desc.position = asteroid.position
    desc.title = "Small Xsotan Breeder"%_t
    desc.factionIndex = Xsotan.getFaction().index

    return Sector():replaceEntity(asteroid, desc)
end

function Xsotan.aggroShip(ship, factions)
    local shipAI = ShipAI(ship)
    if not shipAI then return end

    factions = factions or {Sector():getPresentFactions()}

    for _, factionIndex in pairs(factions) do
        if factionIndex > 0 and factionIndex ~= ship.factionIndex then
            shipAI:registerEnemyFaction(factionIndex)
        end
    end
end

function Xsotan.aggroAll()
    local faction = Xsotan.getFaction()
    local sector = Sector()

    local factions = {sector:getPresentFactions()}
    local xsotan = {sector:getEntitiesByFaction(faction.index)}

    for _, ship in pairs(xsotan) do
        Xsotan.aggroShip(ship, factions)
    end

end

function Xsotan.countXsotan()
    local faction = Xsotan.getFaction()
    return Sector():getNumEntitiesByFaction(faction.index)
end

function Xsotan.aggroXsotanBehavior()
    local faction = Xsotan.getFaction()
    local sector = Sector()

    local factions = {sector:getPresentFactions()}
    local xsotan = {sector:getEntitiesByScript("story/xsotanbehaviour.lua")}

    for _, ship in pairs(xsotan) do
        Xsotan.aggroShip(ship, factions)
    end

end

return Xsotan
