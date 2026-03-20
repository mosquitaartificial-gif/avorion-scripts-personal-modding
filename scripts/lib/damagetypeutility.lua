package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("stringutility")

function getDamageTypeName(dmgType)
    if dmgType == DamageType.AntiMatter then return "Anti Matter /* Damage Type */"%_t
    elseif dmgType == DamageType.Electric then return "Electric /* Damage Type */"%_t
    elseif dmgType == DamageType.Energy then return "Energy /* Damage Type */"%_t
    elseif dmgType == DamageType.Fragments then return "Fragments /* Damage Type */"%_t
    elseif dmgType == DamageType.Physical then return "Physical /* Damage Type */"%_t
    elseif dmgType == DamageType.Plasma then return "Plasma /* Damage Type */"%_t
    else return "None /* Damage Type */"%_t end
end

function getDamageTypeColor(dmgType)
    if dmgType == DamageType.AntiMatter then return ColorRGB(0.8, 0.3, 1.0)
    elseif dmgType == DamageType.Electric then return ColorRGB(0.3, 0.4, 1.0)
    elseif dmgType == DamageType.Energy then return ColorRGB(0.5, 0.9, 1.0)
    elseif dmgType == DamageType.Fragments then return ColorRGB(1.0, 1.0, 1.0)
    elseif dmgType == DamageType.Physical then return ColorRGB(1.0, 0.6, 0.0)
    elseif dmgType == DamageType.Plasma then return ColorRGB(0.5, 0.9, 0.2)
    else return ColorRGB(1.0, 1.0, 1.0) end
end

function getDamageTypeIcon(dmgType)
    if dmgType == DamageType.AntiMatter then return "data/textures/icons/james-bond-aperture.png"
    elseif dmgType == DamageType.Electric then return "data/textures/icons/lightning-trio.png"
    elseif dmgType == DamageType.Energy then return "data/textures/icons/sinusoidal-beam.png"
    elseif dmgType == DamageType.Fragments then return "data/textures/icons/squib.png"
    elseif dmgType == DamageType.Physical then return "data/textures/icons/screen-impact-round.png"
    elseif dmgType == DamageType.Plasma then return "data/textures/icons/plasma-bolt.png"
    else return "data/textures/icons/screen-impact.png" end
end
