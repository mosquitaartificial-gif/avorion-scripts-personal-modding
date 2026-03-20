local TorpedoUtility =  {}

local blue = ColorRGB(0.2, 0.2, 1.0)
local red = ColorRGB(1.0, 0.2, 0.2)
local yellow = ColorRGB(0.8, 0.8, 0.2)

TorpedoUtility.BodyType =
{
    Orca = 1,
    Hammerhead = 2,
    Stingray = 3,
    Ocelot = 4,
    Lynx = 5,
    Panther = 6,
    Osprey = 7,
    Eagle = 8,
    Hawk = 9,
}
local BodyType = TorpedoUtility.BodyType

TorpedoUtility.WarheadType =
{
    Nuclear = 1,
    Neutron = 2,
    Fusion = 3,
    Tandem = 4,
    Kinetic = 5,
    Ion = 6,
    Plasma = 7,
    Sabot = 8,
    EMP = 9,
    AntiMatter = 10,
}
local WarheadType = TorpedoUtility.WarheadType

TorpedoUtility.Bodies = {}
table.insert(TorpedoUtility.Bodies, {type = BodyType.Orca,        name = "Orca"%_T,        velocity = 1, agility = 1, stripes = 1, size = 1.0, reach = 4, color = blue})
table.insert(TorpedoUtility.Bodies, {type = BodyType.Hammerhead,  name = "Hammerhead"%_T,  velocity = 1, agility = 2, stripes = 2, size = 1.5, reach = 5, color = blue})
table.insert(TorpedoUtility.Bodies, {type = BodyType.Stingray,    name = "Stingray"%_T,    velocity = 1, agility = 3, stripes = 3, size = 2.5, reach = 6, color = blue})
table.insert(TorpedoUtility.Bodies, {type = BodyType.Ocelot,      name = "Ocelot"%_T,      velocity = 2, agility = 1, stripes = 1, size = 1.5, reach = 5, color = red})
table.insert(TorpedoUtility.Bodies, {type = BodyType.Lynx,        name = "Lynx"%_T,        velocity = 2, agility = 2, stripes = 2, size = 2.5, reach = 6, color = red})
table.insert(TorpedoUtility.Bodies, {type = BodyType.Panther,     name = "Panther"%_T,     velocity = 2, agility = 3, stripes = 3, size = 3.5, reach = 7, color = red})
table.insert(TorpedoUtility.Bodies, {type = BodyType.Osprey,      name = "Osprey"%_T,      velocity = 3, agility = 1, stripes = 1, size = 2.5, reach = 6, color = yellow})
table.insert(TorpedoUtility.Bodies, {type = BodyType.Eagle,       name = "Eagle"%_T,       velocity = 3, agility = 2, stripes = 2, size = 3.5, reach = 7, color = yellow})
table.insert(TorpedoUtility.Bodies, {type = BodyType.Hawk,        name = "Hawk"%_T,        velocity = 3, agility = 3, stripes = 3, size = 5.0, reach = 8, color = yellow})

TorpedoUtility.Warheads = {}
table.insert(TorpedoUtility.Warheads, {type = WarheadType.Nuclear,     name = "Nuclear"%_T,        hull = 1,     shield = 1,       size = 1.0, color = ColorRGB(0.8, 0.8, 0.8)})
table.insert(TorpedoUtility.Warheads, {type = WarheadType.Neutron,     name = "Neutron"%_T,        hull = 3,     shield = 1,       size = 1.0, color = ColorRGB(0.8, 0.8, 0.3)})
table.insert(TorpedoUtility.Warheads, {type = WarheadType.Fusion,      name = "Fusion"%_T,         hull = 1,     shield = 3,       size = 1.0, color = ColorRGB(1.0, 0.4, 0.1)})
table.insert(TorpedoUtility.Warheads, {type = WarheadType.Tandem,      name = "Tandem"%_T,         hull = 1.5,   shield = 2,       size = 1.5, color = ColorRGB(0.8, 0.2, 0.2), shieldAndHullDamage = true})
table.insert(TorpedoUtility.Warheads, {type = WarheadType.Kinetic,     name = "Kinetic"%_T,        hull = 2.5,   shield = 0.25,    size = 1.5, color = ColorRGB(0.7, 0.3, 0.7), damageVelocityFactor = true})
table.insert(TorpedoUtility.Warheads, {type = WarheadType.Ion,         name = "Ion"%_T,            hull = 0.25,  shield = 3,       size = 2.0, color = ColorRGB(0.2, 0.7, 1.0), energyDrain = true})
table.insert(TorpedoUtility.Warheads, {type = WarheadType.Plasma,      name = "Plasma"%_T,         hull = 1,     shield = 5,       size = 2.0, color = ColorRGB(0.2, 0.8, 0.2)})
table.insert(TorpedoUtility.Warheads, {type = WarheadType.Sabot,       name = "Sabot"%_T,          hull = 2,     shield = 0,       size = 3.0, color = ColorRGB(1.0, 0.1, 0.5), penetrateShields = true})
table.insert(TorpedoUtility.Warheads, {type = WarheadType.EMP,         name = "EMP"%_T,            hull = 0,     shield = 0.025,   size = 3.0, color = ColorRGB(0.3, 0.3, 0.9), deactivateShields = true})
table.insert(TorpedoUtility.Warheads, {type = WarheadType.AntiMatter,  name = "Anti-Matter"%_T,    hull = 8,     shield = 6,       size = 5.0, color = ColorRGB(0.2, 0.2, 0.2), storageEnergyDrain = 50000000})

TorpedoUtility.DamageTypes = {}
table.insert(TorpedoUtility.DamageTypes, {type = WarheadType.Nuclear, damageType = DamageType.Physical})
table.insert(TorpedoUtility.DamageTypes, {type = WarheadType.Neutron, damageType = DamageType.Physical})
table.insert(TorpedoUtility.DamageTypes, {type = WarheadType.Fusion, damageType = DamageType.Energy})
table.insert(TorpedoUtility.DamageTypes, {type = WarheadType.Tandem, damageType = DamageType.Physical})
table.insert(TorpedoUtility.DamageTypes, {type = WarheadType.Kinetic, damageType = DamageType.Physical})
table.insert(TorpedoUtility.DamageTypes, {type = WarheadType.Ion, damageType = DamageType.Energy})
table.insert(TorpedoUtility.DamageTypes, {type = WarheadType.Plasma, damageType = DamageType.Plasma})
table.insert(TorpedoUtility.DamageTypes, {type = WarheadType.Sabot, damageType = DamageType.Physical})
table.insert(TorpedoUtility.DamageTypes, {type = WarheadType.EMP, damageType = DamageType.Electric})
table.insert(TorpedoUtility.DamageTypes, {type = WarheadType.AntiMatter, damageType = DamageType.AntiMatter})


return TorpedoUtility
