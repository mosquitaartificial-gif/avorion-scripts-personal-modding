package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
include ("randomext")
include ("utility")
include ("stringutility")
include ("galaxy")
include ("faction")
local SectorTurretGenerator = include ("sectorturretgenerator")
local ShipGenerator = include ("shipgenerator")
local ShipUtility = include("shiputility")
local PlanGenerator = include("plangenerator")
include("weapontype")


local Scientist = {}

function Scientist.createSatellite(position)
    local desc = EntityDescriptor()
    desc:addComponents(
       ComponentType.Plan,
       ComponentType.BspTree,
       ComponentType.Intersection,
       ComponentType.Asleep,
       ComponentType.DamageContributors,
       ComponentType.BoundingSphere,
       ComponentType.BoundingBox,
       ComponentType.Velocity,
       ComponentType.Physics,
       ComponentType.Scripts,
       ComponentType.ScriptCallback,
       ComponentType.Title,
       ComponentType.Owner,
       ComponentType.WreckageCreator,
       ComponentType.Durability,
       ComponentType.PlanMaxDurability,
       ComponentType.EnergySystem,
       ComponentType.InteractionText,
       ComponentType.Loot
       )


    local faction = Scientist.getFaction()
    local plan = PlanGenerator.makeStationPlan(faction)

    local s = 25 / plan:getBoundingSphere().radius
    plan:scale(vec3(s, s, s))
    plan.accumulatingHealth = true

    desc.position = position
    desc:setPlan(plan)
    desc.factionIndex = faction.index
    desc.title = "Energy Research Satellite"%_T


    local satellite = Sector():createEntity(desc)
    satellite:addScript("story/researchsatellite.lua")

    Loot(satellite.index):insert(SystemUpgradeTemplate("data/scripts/systems/energybooster.lua", Rarity(RarityType.Rare), random():createSeed()))
end


function Scientist.getFaction()
    local name = "The M.A.D. Science Association"%_T
    local faction = Galaxy():findFaction(name)

    if not faction then
        faction = Galaxy():createFaction(name, 240, 0)

        -- those dudes are completely neutral in the beginning
        faction.initialRelations = 0
        faction.initialRelationsToPlayer = 0

        SetFactionTrait(faction, "careful"%_T, "brave"%_T, 0.75)
        SetFactionTrait(faction, "opportunistic"%_T, "honorable"%_T, 1.0)
        SetFactionTrait(faction, "trusting"%_T, "mistrustful"%_T, -0.9)
    end

    faction.homeSectorUnknown = true

    return faction
end

function Scientist.createLightningTurret()

    -- create custom plasma turrets
    local generator = SectorTurretGenerator(Seed(150))
    generator.coaxialAllowed = false
    local turret = generator:generate(300, 0, 0, Rarity(RarityType.Common), WeaponType.LightningGun)
    local weapons = {turret:getWeapons()}
    turret:clearWeapons()
    for _, weapon in pairs(weapons) do
        weapon.damage = 50
        weapon.fireRate = 2
        weapon.reach = 1500
        weapon.accuracy = 0.99
        weapon.bwidth = 0 -- this is important to avoid shooting through blocks
        turret:addWeapon(weapon)
    end
    turret.turningSpeed = 2.0
    turret.crew = Crew()

    return turret

end

function Scientist.spawn()
    print ("spawning the scientist!")

    -- spawn
    local faction = Scientist.getFaction()
    local volume = Balancing_GetSectorShipVolume(faction:getHomeSectorCoordinates()) * 30

    local translation = random():getDirection() * 500
    local position = MatrixLookUpPosition(-translation, vec3(0, 1, 0), translation)


    local boss = ShipGenerator.createShip(faction, position, volume)
    local turret = Scientist.createLightningTurret()
    ShipUtility.addTurretsToCraft(boss, turret, 15, 15)

    boss.title = "Mobile Energy Lab"%_T
    boss.damageMultiplier = 1000

    ShipAI(boss.index):setAggressive()

    local x, y = Sector():getCoordinates()
    Loot(boss.index):insert(InventoryTurret(SectorTurretGenerator():generate(x, y, 0, Rarity(RarityType.Exotic))))
    Loot(boss.index):insert(SystemUpgradeTemplate("data/scripts/systems/teleporterkey7.lua", Rarity(RarityType.Legendary), Seed(1)))

    -- adds legendary turret drop
    boss:addScriptOnce("internal/common/entity/background/legendaryloot.lua")
    boss:addScriptOnce("utility/buildingknowledgeloot.lua")

    boss:addScript("story/scientist.lua")

    Boarding(boss).boardable = false
    boss.dockable = false

    print ("Scientist spawned!")

    -- send sector callback
    local senderInfo = makeCallbackSenderInfo(boss)
    Sector():sendCallback("onScientistSpawned", senderInfo)

    return boss
end


return Scientist
