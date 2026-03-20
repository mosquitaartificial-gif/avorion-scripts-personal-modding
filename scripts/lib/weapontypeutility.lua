package.path = package.path .. ";data/scripts/lib/?.lua"

include("stringutility")
include("utility")
include("weapontype")
local TurretGenerator = include("turretgenerator")

-- since there are no more exact weapon types in the finished weapons,
-- we have to gather the weapon types by their stats, such as icons
function getWeaponTypesByIcon()
    if weaponTypes then return weaponTypes end
    weaponTypes = {}

    local weapons = Balancing_GetWeaponProbability(0, 0)

    for weaponType, _ in pairs(weapons) do
        local turret = TurretGenerator.generateSeeded(Seed(1), weaponType, 15, 5, Rarity(RarityType.Common), Material(MaterialType.Iron))
        weaponTypes[turret.weaponIcon] = weaponType
    end

    return weaponTypes
end

function legacyDetectWeaponType(item)
    local legacyTypeByIcon = {}
    legacyTypeByIcon["data/textures/icons/minigun.png"] = WeaponType.ChainGun
--    legacyTypeByIcon["data/textures/icons/minigun.png"] = WeaponType.PointDefenseChainGun
    legacyTypeByIcon["data/textures/icons/laser-blast.png"] = WeaponType.Laser
--    legacyTypeByIcon["data/textures/icons/laser-blast.png"] = WeaponType.PointDefenseLaser
    legacyTypeByIcon["data/textures/icons/mining.png"] = WeaponType.MiningLaser
    legacyTypeByIcon["data/textures/icons/recycle.png"] = WeaponType.SalvagingLaser
    legacyTypeByIcon["data/textures/icons/tesla-turret.png"] = WeaponType.PlasmaGun
    legacyTypeByIcon["data/textures/icons/missile-swarm.png"] = WeaponType.RocketLauncher
    legacyTypeByIcon["data/textures/icons/hypersonic-bolt.png"] = WeaponType.Cannon
    legacyTypeByIcon["data/textures/icons/beam.png"] = WeaponType.RailGun
    legacyTypeByIcon["data/textures/icons/laser-heal.png"] = WeaponType.RepairBeam
    legacyTypeByIcon["data/textures/icons/sentry-gun.png"] = WeaponType.Bolter
    legacyTypeByIcon["data/textures/icons/lightning-branches.png"] = WeaponType.LightningGun
    legacyTypeByIcon["data/textures/icons/lightning-frequency.png"] = WeaponType.TeslaGun
    legacyTypeByIcon["data/textures/icons/echo-ripples.png"] = WeaponType.ForceGun
    legacyTypeByIcon["data/textures/icons/pulsecannon.png"] = WeaponType.PulseCannon
    legacyTypeByIcon["data/textures/icons/flak.png"] = WeaponType.AntiFighter

    local type = legacyTypeByIcon[item.weaponIcon]

    -- detect point defense weapons
    if item.damageType == DamageType.Fragments then
        if type == WeaponType.ChainGun then
            type = WeaponType.PointDefenseChainGun
        elseif type == WeaponType.Laser then
            type = WeaponType.PointDefenseLaser
        end
    end

    return type
end

function WeaponTypes.getTypeOfItem(item)
    local typesByIcons = getWeaponTypesByIcon()
    local weaponType = typesByIcons[item.weaponIcon]

    -- detect point defense weapon
    if item.damageType == DamageType.Fragments then
        if weaponType == WeaponType.Laser then
            weaponType = WeaponType.PointDefenseLaser
        end
    end

    -- detect raw mining
    if weaponType == WeaponType.RawMiningLaser then
        if item.stoneRawEfficiency == 0 then
            weaponType = WeaponType.MiningLaser
        end
    end

    -- detect raw salvaging
    if weaponType == WeaponType.RawSalvagingLaser then
        if item.metalRawEfficiency == 0 then
            weaponType = WeaponType.SalvagingLaser
        end
    end

    if weaponType == nil then
        weaponType = legacyDetectWeaponType(item)
    end

    return weaponType
end
