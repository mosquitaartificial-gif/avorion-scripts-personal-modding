package.path = package.path .. ";data/scripts/?.lua"

local EffectType = include("dlc/rift/sector/effects/environmentaleffecttype")
local SubsystemProtection = include ("dlc/rift/lib/subsystemprotection")
include("utility")

local EnvironmentalEffectUT = {}

EnvironmentalEffectUT.data = {}

EnvironmentalEffectUT.data[EffectType.MagneticInterferenceField] =
{
    icon = "data/textures/icons/magnetic-interference-field.png",
    maxIntensity = 3,
    color = ColorRGB(1, 1, 0),
    name = "Magnetic Interference Field /* sector environment */"%_T,
    detailedName = "Magnetic Interference Field, intensity ${intensity}"%_T,
    description = "The magnetic interference field of this sector impedes the internal processes in generators and electric circuits. Power generation is impaired."%_T,
    script = "internal/dlc/rift/sector/effects/magneticinterferencefieldeffect.lua",
    sortPriority = 3.3,
    isShipPrepared = function(ship, intensity)
        local energySystem = EnergySystem(ship)
        local generatedEnergy = energySystem.productionRate
        local usedEnergy = energySystem.requiredEnergy

        -- if values are changed here, also change in MagneticInterferenceFieldEffect.getFactor()
        -- keep a reserve of at leased 15% of used energy
        local usedWithBias = usedEnergy * 1.15
        local recommended = usedWithBias / (1 - (0.15 * intensity))

        if generatedEnergy < recommended then
            return "Energy generation too low (${energy} recommended)."%_t % {energy = toReadableValue(recommended, "W")}
        end

    end,
}

EnvironmentalEffectUT.data[EffectType.InertiaField] =
{
    icon = "data/textures/icons/inertia-field.png",
    maxIntensity = 3,
    color = ColorRGB(0.6, 1, 0),
    name = "Inertia Field /* sector environment */"%_T,
    detailedName = "Inertia Field, intensity ${intensity}"%_T,
    description = "The inertia field impedes the movement of mass and ensures that ships cannot accelerate as quickly. Xsotan do not seem to be affected by this field."%_T,
    script = "internal/dlc/rift/sector/effects/inertiafieldeffect.lua",
    sortPriority = 4.1,
    isShipPrepared = function(ship, intensity)
        local acceleration = Engine(ship).acceleration
        local maxVelocity = Engine(ship).maxVelocity
        -- return no error if maxVelocity can be reached in under 10s
        -- if values are changed here, also change in InertiaFieldEffect.getAccelerationFactor()
        if (acceleration * (1 - (0.15 * intensity))) / maxVelocity < 0.1 then
            return "More acceleration recommended."%_t
        end
    end,
}

EnvironmentalEffectUT.data[EffectType.HighEnergyPlasmaField] =
{
    icon = "data/textures/icons/high-energy-field.png",
    maxIntensity = 3,
    color = ColorRGB(0.1, 0.9, 0.4),
    name = "High Energy Plasma Field /* sector environment */"%_T,
    detailedName = "High Energy Plasma Field, intensity ${intensity}"%_T,
    description = "This high-energy plasma field naturally amplifies energy discharges. The damage of energy weapons is increased."%_T,
    script = "internal/dlc/rift/sector/effects/highenergyplasmafieldeffect.lua",
    sortPriority = 4.3,
}

EnvironmentalEffectUT.data[EffectType.LowEnergyPlasmaField] =
{
    icon = "data/textures/icons/low-energy-field.png",
    maxIntensity = 3,
    color = ColorRGB(0.4, 0.6, 0.1),
    name = "Low Energy Plasma Field /* sector environment */"%_T,
    detailedName = "Low Energy Plasma Field, intensity ${intensity}"%_T,
    description = "This low-energy plasma field naturally drains energy from discharges. The damage of energy weapons is decreased."%_T,
    script = "internal/dlc/rift/sector/effects/lowenergyplasmafieldeffect.lua",
    sortPriority = 4.2,
}

EnvironmentalEffectUT.data[EffectType.IonStorm] =
{
    icon = "data/textures/icons/ion-storm.png",
    maxIntensity = 3,
    color = ColorRGB(0.88, 0.5, 0.13),
    name = "Ion Storm /* sector environment */"%_T,
    detailedName = "Ion Storm, intensity ${intensity}"%_T,
    description = "There is an ion storm disrupting shield generators. Shields will discharge over time."%_T,
    script = "internal/dlc/rift/sector/effects/ionstormeffect.lua",
    sortPriority = 2.3,
}

EnvironmentalEffectUT.data[EffectType.IonInterference] =
{
    icon = "data/textures/icons/ion-interference.png",
    maxIntensity = 1,
    color = ColorRGB(1, 1, 0),
    name = "Ion Interference /* sector environment */"%_T,
    detailedName = "Ion Interference, intensity ${intensity}"%_T,
    description = "Ion interferences are disturbing shield generation in this area. Shields are not able to regenerate. It is advised to enter the rift with fully charged shields."%_T,
    script = "internal/dlc/rift/sector/effects/ioninterferenceeffect.lua",
    sortPriority = 3.4,
}

EnvironmentalEffectUT.data[EffectType.Radiation] =
{
    icon = "data/textures/icons/radioactive.png",
    maxIntensity = 3,
    color = ColorRGB(1, 1, 0),
    name = "Radiation /* sector environment */"%_T,
    detailedName = "Strong Cosmic Radiation, intensity ${intensity}"%_T,
    description = "Less effective workforces if shields are down, due to necessary measures against radiation sickness."%_T,
    script = "internal/dlc/rift/sector/effects/radiationeffect.lua",
    sortPriority = 3.2,
    isShipPrepared = function(ship, intensity)
        if ship.shieldMaxDurability > 0 then return end

        local crew = ship.crew
        if not crew then return end

        local minCrew = ship.idealCrew

        local workforce = {}
        for profession, amount in pairs(crew:getWorkforce()) do
            workforce[profession.value] = amount
        end

        local minWorkforce = {}
        for profession, amount in pairs(minCrew:getWorkforce()) do
            if profession.value ~= CrewProfessionType.None then
                minWorkforce[profession.value] = amount
            end
        end

        for profession, ideal in pairs(minWorkforce) do
            local workforce = workforce[profession]
            if ideal then
                -- if values are changed here, also change in RadiationEffect.getIntensityFactor()
                -- if values are changed here, also change in RadiatingAsteroidsEffect.getIntensityFactor()
                local reduced = workforce * (1 - 0.15 * intensity)
                if reduced < ideal then
                    return "Shields or more crew workforce recommended."%_t
                end
            end
        end
    end,
}

EnvironmentalEffectUT.data[EffectType.RadiatingAsteroids] =
{
    icon = "data/textures/icons/radioactive.png",
    maxIntensity = 3,
    intensityOffset = 3,
    color = ColorRGB(0.88, 0.5, 0.13),
    name = "Radiation /* sector environment */"%_T,
    detailedName = "Strong Cosmic Radiation, intensity ${intensity}"%_T,
    description = "Less effective workforces if shields are down, due to necessary measures against radiation sickness."%_T,
    script = "internal/dlc/rift/sector/effects/radiatingasteroidseffect.lua",
    sortPriority = 2.4,
    isShipPrepared = EnvironmentalEffectUT.data[EffectType.Radiation].isShipPrepared,
}

EnvironmentalEffectUT.data[EffectType.ShockwaveAnomalies] =
{
    icon = "data/textures/icons/shockwave-anomalies.png",
    maxIntensity = 3,
    color = ColorRGB(0.88, 0.5, 0.13),
    name = "Shockwave Anomalies /* sector environment */"%_T,
    detailedName = "Shockwave Anomalies, intensity ${intensity}"%_T,
    description = "Multiple shockwave anomalies have been detected. They might get unstable and discharge. Approach with caution."%_T,
    script = "internal/dlc/rift/sector/effects/shockwaveanomalieseffect.lua",
    sortPriority = 2.2,
}

EnvironmentalEffectUT.data[EffectType.LightningField] =
{
    icon = "data/textures/icons/lightning-field.png",
    maxIntensity = 3,
    color = ColorRGB(0.88, 0.5, 0.13),
    name = "Lightning Field /* sector environment */"%_T,
    detailedName = "Lightning Field, intensity ${intensity}"%_T,
    description = "In this electrically charged field shields and hull are frequently struck by lightning."%_T,
    script = "internal/dlc/rift/sector/effects/lightningfieldeffect.lua",
    sortPriority = 2.1,
}

EnvironmentalEffectUT.data[EffectType.AcidFog] =
{
    icon = "data/textures/icons/acid-fog.png",
    maxIntensity = 3,
    color = ColorRGB(1, 1, 0),
    name = "Acid Fog /* sector environment */"%_T,
    detailedName = "Acid Fog, intensity ${intensity}"%_T,
    description = "This acid fog corrodes exposed blocks below ${material}. These will suffer constant damage. Shields do not protect your ship against the acid fog."%_T,
    script = "internal/dlc/rift/sector/effects/acidfogeffect.lua",
    sortPriority = 3.1,
    safeMaterial = function(distanceToCenter)
        local material = Material(Balancing_GetHighestAvailableMaterialByProbability(distanceToCenter, 0, 0.3))
        return material
    end,
    isShipPrepared = function(ship, _, x, y)
        -- if half of the ship can be damaged by acid fog, it gets dangerous
        local plan = Plan(ship)
        local numBlocks = plan.numBlocks
        local recommended = Material(Balancing_GetHighestAvailableMaterialByProbability(x, y, 0.3))
        local safeMaterialValue = recommended.value

        local volumeDamageableBlocks = 0
        local volumeSafeBlocks = 0
        for i = 0, numBlocks - 1 do
            local block = plan:getNthBlock(i)
            if block.material.value >= safeMaterialValue then
                volumeSafeBlocks = volumeSafeBlocks + block.volume
            else
                volumeDamageableBlocks = volumeDamageableBlocks + block.volume
            end
        end

        if volumeDamageableBlocks > volumeSafeBlocks then
            return "Ship material vulnerable, ${material} or higher recommended."%_t % {material = recommended.name}
        end
    end,
}

EnvironmentalEffectUT.data[EffectType.XsotanBreeder] =
{
    icon = "data/textures/icons/xsotan-breeders.png",
    maxIntensity = 3,
    color = ColorRGB(0.75, 0.1, 0.1),
    name = "Xsotan Breeders /* sector environment */"%_T,
    detailedName = "Xsotan Breeders, intensity ${intensity}"%_T,
    description = "The area is full of Xsotan Breeders, that could wake up if there is too much activity."%_T,
    script = "internal/dlc/rift/sector/effects/xsotanbreederfield.lua",
    sortPriority = 1.3,
}

EnvironmentalEffectUT.data[EffectType.MineField] =
{
    icon = "data/textures/icons/minefield.png",
    maxIntensity = 3,
    color = ColorRGB(0.75, 0.1, 0.1),
    name = "Minefield /* sector environment */"%_T,
    detailedName = "Minefield, intensity ${intensity}"%_T,
    description = "There were mines detected in the area. It's advised to keep your distance. Mines don't trigger when approached very slowly."%_T,
    script = "internal/dlc/rift/sector/effects/minefield.lua",
    sortPriority = 1.1,
}

EnvironmentalEffectUT.data[EffectType.XsotanSwarm] =
{
    icon = "data/textures/icons/xsotan-swarm-effect.png",
    maxIntensity = 3,
    color = ColorRGB(0.75, 0.1, 0.1),
    name = "Xsotan Swarm /* sector environment */"%_T,
    detailedName = "Xsotan Swarm, intensity ${intensity}"%_T,
    description = "We are receiving strong subspace signals from this area. Be prepared for whole hordes of Xsotan!"%_t,
    script = "internal/dlc/rift/sector/effects/xsotanswarmeffect.lua",
    sortPriority = 1.2,
}

EnvironmentalEffectUT.data[EffectType.XsotanDamageBoost] =
{
    icon = "data/textures/icons/xsotan-turret-overload.png",
    maxIntensity = 75,
    color = ColorRGB(0.93, 0.17, 0.17),
    name = "Xsotan Turret Overload /* sector environment */"%_T,
    detailedName = "Xsotan Turret Overload, intensity ${intensity}"%_T,
    description = "Sensors show the Xsotan are overloading their weapons. They will deal more damage."%_T,
    script = "internal/dlc/rift/sector/effects/xsotandamageboosteffect.lua",
    hidden = true,
    sortPriority = 0,
}

EnvironmentalEffectUT.data[EffectType.XsotanDurabilityBoost] =
{
    icon = "data/textures/icons/xsotan-durability-boost.png",
    maxIntensity = 75,
    color = ColorRGB(0.4, 0, 0.2),
    name = "Xsotan Hull Hardening /* sector environment */"%_T,
    detailedName = "Xsotan Hull Hardening, intensity ${intensity}"%_T,
    description = "Measurements show that the Xsotan have a harder hull in this sector. This makes them more resilient. Bring enough firepower with you!"%_T,
    script = "internal/dlc/rift/sector/effects/xsotandurabilityboosteffect.lua",
    hidden = true,
    sortPriority = 0,
}

EnvironmentalEffectUT.data[EffectType.GravityAnomalies] =
{
    icon = "data/textures/icons/gravity-anomaly.png",
    maxIntensity = 3,
    color = ColorRGB(0.6, 1, 0),
    name = "Gravity Anomalies /* sector environment */"%_T,
    detailedName = "Gravity Anomalies, intensity ${intensity}"%_T,
    description = "Multiple gravity anomalies have been detected. They reel you in and spit you back out if you're not careful."%_T,
    script = "internal/dlc/rift/sector/effects/gravityanomalieseffect.lua",
    sortPriority = 4.4,
}

EnvironmentalEffectUT.data[EffectType.SubspaceDistortion] =
{
    icon = "data/textures/icons/subspace-distortion.png",
    maxIntensity = 100,
    color = ColorRGB(0.6, 0.6, 0.6),
    name = "Subspace Distortion /* sector environment */"%_T,
    detailedName = "Subspace Distortion, intensity ${intensity}"%_T,
    description = "This sector is deep in the subspace rifts. There are strong subspace distortions that will damage the ship unless protection against them is equipped."%_t,
    script = "internal/dlc/rift/sector/effects/subspacedistortioneffect.lua",
    sortPriority = -1,
    isShipPrepared = function(ship, intensity)
        local protection = SubsystemProtection.getProtection(ship)
        -- intensity difference of 5 is almost no problem
        if intensity - protection >= 5 then
            return "Not enough protection (${protection}/${intensity})."%_t % {protection = protection, intensity = intensity}
        end
    end,
}

function EnvironmentalEffectUT.addEffect(effectType, intensity)
    local data = EnvironmentalEffectUT.data[effectType]
    if not data then
        eprint("EnvironmentalEffectUT: data for effectType '" .. tostring(effectType) .. "' not found.")
        return
    end

    local sector = Sector()
    sector:removeScript(data.script)
    sector:addScriptOnce(data.script, {intensity = intensity})
end

function EnvironmentalEffectUT.postGeneration(effectType, specs)
    local data = EnvironmentalEffectUT.data[effectType]
    if not data then
        eprint("EnvironmentalEffectUT: data for effectType '" .. tostring(effectType) .. "' not found.")
        return
    end

    Sector():invokeFunction(data.script, "onObjectiveContentGenerated", specs)
end

function EnvironmentalEffectUT.removeAllEffects()
    local sector = Sector()
    for _, data in pairs(EnvironmentalEffectUT.data) do
        sector:removeScript(data.script)
    end
end

function EnvironmentalEffectUT.getDisplayedIntensity(effectType, intensity)
    if effectType == EffectType.AcidFog then
        -- acid fog has distance to center encoded in intensity value
        -- we need to calculate actual value first
        intensity = math.floor(intensity / 1000)
    end

    return intensity + (EnvironmentalEffectUT.data[effectType].intensityOffset or 0)
end

function EnvironmentalEffectUT.getFormatArguments(effectType, intensity, x, y)
    local data = {intensity = EnvironmentalEffectUT.getDisplayedIntensity(effectType, intensity)}

    if effectType == EffectType.AcidFog then
        -- acid fog has distance to center encoded in intensity value
        -- the distance is used to determine which material will be affected
        local distanceToCenter = intensity % 1000
        data.material = EnvironmentalEffectUT.data[EffectType.AcidFog].safeMaterial(distanceToCenter).name
    end

    return data
end

function EnvironmentalEffectUT.getDisplayedLevel(effectType, displayedIntensity)
    -- given intensity is return value of function getDisplayedIntensity
    if effectType == EffectType.SubspaceDistortion then
        return tostring(displayedIntensity)
    end

    return toRomanLiterals(displayedIntensity)
end

function EnvironmentalEffectUT.getEffectsByTier()
    local effects = {}
    -- blue tier
    effects["B"] =
    {
        EffectType.InertiaField,
        EffectType.LowEnergyPlasmaField,
        EffectType.HighEnergyPlasmaField,
        EffectType.GravityAnomalies,
    }
    -- green tier
    effects["G"] =
    {
        EffectType.MagneticInterferenceField,
        EffectType.Radiation,
        EffectType.AcidFog,
        EffectType.IonInterference,
    }
    -- orange tier
    effects["O"] =
    {
        EffectType.LightningField,
        EffectType.ShockwaveAnomalies,
        EffectType.IonStorm,
        EffectType.RadiatingAsteroids,
    }
    -- red tier
    effects["R"] =
    {
        EffectType.XsotanSwarm,
        EffectType.XsotanBreeder,
        EffectType.MineField,
    }

    return effects
end

function EnvironmentalEffectUT.getForbiddenCombinations()
    -- this table is temporary, optimized for ease of use
    local forbiddenCombinations = {}
    forbiddenCombinations[EffectType.LowEnergyPlasmaField] = {EffectType.HighEnergyPlasmaField}
    forbiddenCombinations[EffectType.Radiation] = {EffectType.RadiatingAsteroids}

    -- build the result table which is organized in a "map of sets" style
    -- and make combinations go both ways
    local result = {}
    for type1, forbidden in pairs(forbiddenCombinations) do
        for _, type2 in pairs(forbidden) do
            -- forbidden for type1: type2
            local tmp = result[type1] or {}
            tmp[type2] = true
            result[type1] = tmp

            -- forbidden for type2: type1
            tmp = result[type2] or {}
            tmp[type1] = true
            result[type2] = tmp
        end
    end

    return result
end

return EnvironmentalEffectUT
