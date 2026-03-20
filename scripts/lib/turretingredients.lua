package.path = package.path .. ";data/scripts/lib/?.lua"

include("weapontype")

local StatChanges =
{
    Percentage = 1,
    Flat = 2,
}

local TurretIngredients = {}
TurretIngredients.StatChanges = StatChanges

TurretIngredients[WeaponType.ChainGun] =
{
    {name = "Servo",            amount = 15,    investable = 10,    minimum = 3, rarityFactor = 0.75,   weaponStat = "fireRate", investFactor = 0.3, changeType = StatChanges.Percentage},
    {name = "Steel Tube",       amount = 6,     investable = 7,                                         weaponStat = "reach", investFactor = 0.4, changeType = StatChanges.Percentage},
    {name = "Ammunition S",     amount = 5,     investable = 10,    minimum = 1,                        weaponStat = "damage", investFactor = 0.4, changeType = StatChanges.Percentage},
    {name = "Steel",            amount = 5,     investable = 10,    minimum = 3},
    {name = "Aluminum",         amount = 7,     investable = 5,     minimum = 3},
    {name = "Lead",             amount = 10,    investable = 10,    minimum = 1},
}

TurretIngredients[WeaponType.PointDefenseChainGun] =
{
    {name = "Servo",            amount = 17,    investable = 8,     minimum = 10, rarityFactor = 0.75,  weaponStat = "fireRate", investFactor = 0.3, changeType = StatChanges.Percentage},
    {name = "Steel Tube",       amount = 8,     investable = 5,                                         weaponStat = "reach", investFactor = 0.4, changeType = StatChanges.Percentage},
    {name = "Ammunition S",     amount = 5,     investable = 5,     minimum = 1,                        weaponStat = "damage", investFactor = 0.4, changeType = StatChanges.Percentage},
    {name = "Steel",            amount = 3,     investable = 7,     minimum = 3},
    {name = "Aluminum",        amount = 7,     investable = 5,     minimum = 3},
    {name = "Lead",             amount = 10,    investable = 10,    minimum = 1},
}

TurretIngredients[WeaponType.Bolter] =
{
    {name = "Servo",                amount = 15,    investable = 8,     minimum = 5,    rarityFactor = 0.75, weaponStat = "fireRate", investFactor = 1.0, changeType = StatChanges.Percentage},
    {name = "High Pressure Tube",   amount = 1,     investable = 3,                     weaponStat = "reach", investFactor = 0.4, changeType = StatChanges.Percentage},
    {name = "Ammunition M",         amount = 5,     investable = 10,    minimum = 1,    weaponStat = "damage", investFactor = 0.1, changeType = StatChanges.Percentage},
    {name = "Explosive Charge",     amount = 2,     investable = 4,     minimum = 1,    weaponStat = "damage", investFactor = 0.3, changeType = StatChanges.Percentage},
    {name = "Steel",                amount = 5,     investable = 10,    minimum = 3,},
    {name = "Aluminum",            amount = 7,     investable = 5,     minimum = 3,},
}

TurretIngredients[WeaponType.Laser] =
{
    {name = "Laser Head",           amount = 4,    investable = 4,              weaponStat = "damage", investFactor = 0.1, changeType = StatChanges.Percentage },
    {name = "Laser Compressor",     amount = 2,    investable = 2,              weaponStat = "damage", investFactor = 0.3, changeType = StatChanges.Percentage },
    {name = "High Capacity Lens",   amount = 2,    investable = 4,              weaponStat = "reach", investFactor = 1.0, changeType = StatChanges.Percentage},
    {name = "Laser Modulator",      amount = 2,    investable = 4,  minimum = 2,},
    {name = "Power Unit",           amount = 5,    investable = 3,  minimum = 3, turretStat = "maxHeat", investFactor = 0.75, changeType = StatChanges.Percentage},
    {name = "Steel",                amount = 5,    investable = 10, minimum = 3,},
    {name = "Crystal",              amount = 2,    investable = 10, minimum = 1,},
}

TurretIngredients[WeaponType.PointDefenseLaser] =
{
    {name = "Servo",                amount = 17,   investable = 8,  minimum = 10, rarityFactor = 0.75, weaponStat = "fireRate", investFactor = 0.3, changeType = StatChanges.Percentage},
    {name = "Laser Head",           amount = 2,    investable = 2,  minimum = 1, weaponStat = "damage", investFactor = 0.1, changeType = StatChanges.Percentage},
    {name = "Laser Compressor",     amount = 2,    investable = 1,              weaponStat = "damage", investFactor = 0.3, changeType = StatChanges.Percentage},
    {name = "High Capacity Lens",   amount = 2,    investable = 4,              weaponStat = "reach", investFactor = 1.0, changeType = StatChanges.Percentage},
    {name = "Laser Modulator",      amount = 2,    investable = 4, },
    {name = "Steel",                amount = 5,    investable = 10, minimum = 3,},
    {name = "Crystal",              amount = 2,    investable = 10, minimum = 1,},
}

TurretIngredients[WeaponType.PlasmaGun] =
{
    {name = "Plasma Cell",          amount = 8,    investable = 4,  minimum = 1,   weaponStat = "damage", investFactor = 0.4, changeType = StatChanges.Percentage},
    {name = "Energy Tube",          amount = 2,    investable = 6,  minimum = 1,    weaponStat = "reach", investFactor = 0.4, changeType = StatChanges.Percentage},
    {name = "Conductor",            amount = 5,    investable = 6,  minimum = 1,},
    {name = "Energy Container",     amount = 5,    investable = 6,  minimum = 1,},
    {name = "Power Unit",           amount = 5,    investable = 3,  minimum = 3,    turretStat = "maxHeat", investFactor = 0.75, changeType = StatChanges.Percentage},
    {name = "Steel",                amount = 4,    investable = 10, minimum = 3,},
    {name = "Crystal",              amount = 2,    investable = 10, minimum = 1,},
}

TurretIngredients[WeaponType.Cannon] =
{
    {name = "Servo",                amount = 15,   investable = 10, minimum = 5,  weaponStat = "fireRate", investFactor = 1.0, changeType = StatChanges.Percentage},
    {name = "Warhead",              amount = 5,    investable = 6,  minimum = 1,    weaponStat = "damage", investFactor = 0.4, changeType = StatChanges.Percentage},
    {name = "High Pressure Tube",   amount = 2,    investable = 6,  minimum = 1,    weaponStat = "reach", investFactor = 0.4, changeType = StatChanges.Percentage},
    {name = "Explosive Charge",     amount = 2,    investable = 6,  minimum = 1,    weaponStat = "damage", investFactor = 0.2, changeType = StatChanges.Percentage},
    {name = "Steel",                amount = 8,    investable = 10, minimum = 3,},
    {name = "Wire",                 amount = 5,    investable = 10, minimum = 3,},
}

TurretIngredients[WeaponType.RocketLauncher] =
{
    {name = "Servo",                amount = 15,   investable = 10, minimum = 5,  weaponStat = "fireRate", investFactor = 1.0, changeType = StatChanges.Percentage},
    {name = "Rocket",               amount = 5,    investable = 6,  minimum = 1,    weaponStat = "damage", investFactor = 0.4, changeType = StatChanges.Percentage},
    {name = "High Pressure Tube",   amount = 2,    investable = 6,  minimum = 1,    weaponStat = "reach", investFactor = 0.4, changeType = StatChanges.Percentage},
    {name = "Fuel",                 amount = 2,    investable = 6,  minimum = 1,    weaponStat = "reach", investFactor = 0.5, changeType = StatChanges.Percentage},
    {name = "Targeting Card",       amount = 5,    investable = 5,  minimum = 0,     weaponStat = "seeker", investFactor = 1, changeType = StatChanges.Flat},
    {name = "Steel",                amount = 8,    investable = 10, minimum = 3,},
    {name = "Wire",                 amount = 5,    investable = 10, minimum = 3,},
}

TurretIngredients[WeaponType.RailGun] =
{
    {name = "Servo",                amount = 15,   investable = 10, minimum = 6,   weaponStat = "fireRate", investFactor = 1.0, changeType = StatChanges.Percentage},
    {name = "Electromagnetic Charge",amount = 5,   investable = 6,  minimum = 1,   weaponStat = "damage", investFactor = 0.3, changeType = StatChanges.Percentage},
    {name = "Electro Magnet",       amount = 8,    investable = 10, minimum = 3,    weaponStat = "reach", investFactor = 0.3, changeType = StatChanges.Percentage},
    {name = "Gauss Rail",           amount = 5,    investable = 6,  minimum = 1,    weaponStat = "damage", investFactor = 0.3, changeType = StatChanges.Percentage},
    {name = "High Pressure Tube",   amount = 2,    investable = 6,  minimum = 1,    weaponStat = "reach",  investFactor = 0.3, changeType = StatChanges.Percentage},
    {name = "Steel",                amount = 5,    investable = 10, minimum = 3,},
    {name = "Copper",               amount = 2,    investable = 10, minimum = 1,},
}

TurretIngredients[WeaponType.RepairBeam] =
{
    {name = "Nanobot",              amount = 5,    investable = 6,  minimum = 1,      weaponStat = "hullRepair", investFactor = 0.4, changeType = StatChanges.Percentage},
    {name = "Transformator",        amount = 2,    investable = 6,  minimum = 1,    weaponStat = "shieldRepair", investFactor = 0.4, changeType = StatChanges.Percentage},
    {name = "Laser Modulator",      amount = 2,    investable = 5,  minimum = 0,    weaponStat = "reach", investFactor = 0.75, changeType = StatChanges.Percentage},
    {name = "Conductor",            amount = 2,    investable = 6,  minimum = 0,    turretStat = "energyIncreasePerSecond",  investFactor = -0.5, changeType = StatChanges.Percentage},
    {name = "Gold",                 amount = 3,    investable = 10, minimum = 1,},
    {name = "Steel",                amount = 8,    investable = 10, minimum = 3,},
}

TurretIngredients[WeaponType.MiningLaser] =
{
    {name = "Laser Compressor",     amount = 5,    investable = 6,  minimum = 1,    weaponStat = "damage", investFactor = 0.075, changeType = StatChanges.Percentage},
    {name = "Laser Modulator",      amount = 2,    investable = 4,  minimum = 0,    weaponStat = "stoneRefinedEfficiency", investFactor = 0.075, changeType = StatChanges.Flat },
    {name = "High Capacity Lens",   amount = 2,    investable = 6,  minimum = 0,    weaponStat = "reach", investFactor = 1.0, changeType = StatChanges.Percentage},
    {name = "Conductor",            amount = 5,    investable = 6,  minimum = 2,},
    {name = "Steel",                amount = 5,    investable = 10, minimum = 3,},
}

TurretIngredients[WeaponType.SalvagingLaser] =
{
    {name = "Laser Compressor",     amount = 5,    investable = 6,  minimum = 1,    weaponStat = "damage", investFactor = 0.4, changeType = StatChanges.Percentage},
    {name = "Laser Modulator",      amount = 2,    investable = 4,  minimum = 0,    weaponStat = "metalRefinedEfficiency", investFactor = 0.075, changeType = StatChanges.Flat },
    {name = "High Capacity Lens",   amount = 2,    investable = 6,  minimum = 0,    weaponStat = "reach", investFactor = 1.0, changeType = StatChanges.Percentage},
    {name = "Conductor",            amount = 5,    investable = 6,  minimum = 2,},
    {name = "Steel",                amount = 5,    investable = 10, minimum = 3,},
}

TurretIngredients[WeaponType.RawMiningLaser] =
{
    {name = "Laser Compressor",     amount = 5,    investable = 6,  minimum = 1,    weaponStat = "damage", investFactor = 0.075, changeType = StatChanges.Percentage},
    {name = "Laser Modulator",      amount = 2,    investable = 4,  minimum = 0,    weaponStat = "stoneRawEfficiency", investFactor = 0.075, changeType = StatChanges.Flat },
    {name = "High Capacity Lens",   amount = 2,    investable = 6,  minimum = 0,    weaponStat = "reach", investFactor = 1.0, changeType = StatChanges.Percentage},
    {name = "Conductor",            amount = 5,    investable = 6,  minimum = 2,},
    {name = "Steel",                amount = 5,    investable = 10, minimum = 3,},
}

TurretIngredients[WeaponType.RawSalvagingLaser] =
{
    {name = "Laser Compressor",     amount = 5,    investable = 6,  minimum = 1,    weaponStat = "damage", investFactor = 0.4, changeType = StatChanges.Percentage},
    {name = "Laser Modulator",      amount = 2,    investable = 4,  minimum = 0,    weaponStat = "metalRawEfficiency", investFactor = 0.075, changeType = StatChanges.Flat },
    {name = "High Capacity Lens",   amount = 2,    investable = 6,  minimum = 0,    weaponStat = "reach", investFactor = 1.0, changeType = StatChanges.Percentage},
    {name = "Conductor",            amount = 5,    investable = 6,  minimum = 2,},
    {name = "Steel",                amount = 5,    investable = 10, minimum = 3,},
}

TurretIngredients[WeaponType.ForceGun] =
{
    {name = "Force Generator",      amount = 5,    investable = 3,  minimum = 1,    weaponStat = "holdingForce", investFactor = 0.4, changeType = StatChanges.Percentage},
    {name = "Energy Tube",          amount = 2,    investable = 6,  minimum = 1,    weaponStat = "reach", investFactor = 1.0, changeType = StatChanges.Percentage},
    {name = "Conductor",            amount = 10,   investable = 6,  minimum = 2,},
    {name = "Steel",                amount = 7,    investable = 10, minimum = 3,},
    {name = "Zinc",                 amount = 3,    investable = 10, minimum = 3,},
}

TurretIngredients[WeaponType.TeslaGun] =
{
    {name = "Industrial Tesla Coil",amount = 5,    investable = 6,  minimum = 1,    weaponStat = "damage", investFactor = 0.4, changeType = StatChanges.Percentage},
    {name = "Electromagnetic Charge",amount = 2,   investable = 4,  minimum = 1,    weaponStat = "reach", investFactor = 0.3, changeType = StatChanges.Percentage },
    {name = "Energy Inverter",      amount = 2,    investable = 4,  minimum = 1,},
    {name = "Conductor",            amount = 5,    investable = 6,  minimum = 2,},
    {name = "Power Unit",           amount = 5,    investable = 3,  minimum = 3, turretStat = "maxHeat", investFactor = 0.75, changeType = StatChanges.Percentage},
    {name = "Copper",               amount = 5,    investable = 10, minimum = 3,},
    {name = "Energy Cell",          amount = 5,    investable = 10, minimum = 3,},
}

TurretIngredients[WeaponType.LightningGun] =
{
    {name = "Military Tesla Coil",  amount = 5,    investable = 6,  minimum = 1,    weaponStat = "damage", investFactor = 0.45, changeType = StatChanges.Percentage},
    {name = "High Capacity Lens",   amount = 2,    investable = 4,  minimum = 1,    weaponStat = "reach", investFactor = 0.2, changeType = StatChanges.Percentage },
    {name = "Electromagnetic Charge",amount = 2,   investable = 4,  minimum = 1,},
    {name = "Conductor",            amount = 5,    investable = 6,  minimum = 2,},
    {name = "Power Unit",           amount = 5,    investable = 3,  minimum = 3,    turretStat = "maxHeat", investFactor = 0.75, changeType = StatChanges.Percentage},
    {name = "Copper",               amount = 5,    investable = 10, minimum = 3,},
    {name = "Energy Cell",          amount = 5,    investable = 10, minimum = 3,},
}

TurretIngredients[WeaponType.PulseCannon] =
{
    {name = "Servo",                amount = 8,    investable = 8,  minimum = 3, rarityFactor = 0.75,   weaponStat = "fireRate", investFactor = 0.3, changeType = StatChanges.Percentage},
    {name = "Steel Tube",           amount = 6,    investable = 7,                                      weaponStat = "reach", investFactor = 0.4, changeType = StatChanges.Percentage},
    {name = "Ammunition S",         amount = 5,    investable = 10,  minimum = 1,                       weaponStat = "damage", investFactor = 0.4, changeType = StatChanges.Percentage},
    {name = "Steel",                amount = 5,    investable = 10, minimum = 4},
    {name = "Copper",               amount = 5,    investable = 10, minimum = 3,},
    {name = "Energy Cell",          amount = 3,    investable = 5,  minimum = 2,},
}

TurretIngredients[WeaponType.AntiFighter] =
{
    {name = "Servo",                amount = 17,    investable = 8,     minimum = 10, rarityFactor = 0.75,  weaponStat = "fireRate", investFactor = 0.3, changeType = StatChanges.Percentage },
    {name = "High Pressure Tube",   amount = 1,     investable = 3,                                         weaponStat = "reach", investFactor = 0.5, changeType = StatChanges.Percentage},
    {name = "Ammunition M",         amount = 5,     investable = 5,     minimum = 1,                        weaponStat = "damage", investFactor = 0.2, changeType = StatChanges.Percentage},
    {name = "Explosive Charge",     amount = 2,     investable = 4,     minimum = 1,                        weaponStat = "damage", investFactor = 0.4, changeType = StatChanges.Percentage},
    {name = "Steel",                amount = 5,     investable = 10,    minimum = 3,},
    {name = "Aluminum",            amount = 7,     investable = 5,     minimum = 3,},
}

return TurretIngredients
