package.path = package.path .. ";data/scripts/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"

local SectorSpecifics = include("sectorspecifics")
local EnvironmentalEffectUT = include("dlc/rift/sector/effects/environmentaleffectutility")
local EnvironmentalEffectType = include("dlc/rift/sector/effects/environmentaleffecttype")
local BuildingKnowledgeUT = include("buildingknowledgeutility")
local Constraints = include("dlc/rift/lib/constraints")
local UpgradeGenerator = include ("upgradegenerator")
local SectorTurretGenerator = include("sectorturretgenerator")
local SubsystemProtection = include ("dlc/rift/lib/subsystemprotection")
local Extractions = include("dlc/rift/lib/extractions")

include ("randomext")
include ("goods")

local RiftMissionUT = {}


ThreatLevel =
{
    VeryLow = 1,
    Low = 2,
    Moderate = 3,
    Challenging = 4,
    VeryChallenging = 5,
    High = 6,
    VeryHigh = 7,
    Extraordinary = 8,
    Extreme = 9,
    DeathSentence = 10,
    Impossible = 11,
}

ThreatLevels = {}
ThreatLevels[ThreatLevel.VeryLow]           = {displayName = "Very Low /* mission difficulty */"%_T}
ThreatLevels[ThreatLevel.Low]               = {displayName = "Low /* mission difficulty */"%_T}
ThreatLevels[ThreatLevel.Moderate]          = {displayName = "Moderate /* mission difficulty */"%_T}
ThreatLevels[ThreatLevel.Challenging]       = {displayName = "Challenging /* mission difficulty */"%_T}
ThreatLevels[ThreatLevel.VeryChallenging]   = {displayName = "Very Challenging /* mission difficulty */"%_T}
ThreatLevels[ThreatLevel.High]              = {displayName = "High /* mission difficulty */"%_T}
ThreatLevels[ThreatLevel.VeryHigh]          = {displayName = "Very High /* mission difficulty */"%_T}
ThreatLevels[ThreatLevel.Extraordinary]     = {displayName = "Extraordinary /* mission difficulty */"%_T}
ThreatLevels[ThreatLevel.Extreme]           = {displayName = "Extreme /* mission difficulty */"%_T}
ThreatLevels[ThreatLevel.DeathSentence]     = {displayName = "Death Sentence /* mission difficulty */"%_T}
ThreatLevels[ThreatLevel.Impossible]        = {displayName = "Impossible /* mission difficulty */"%_T}

local colors = {
    vec3(1.0, 1.0, 0.1),
    vec3(0.8, 0.8, 0.2),
    vec3(0.8, 0.5, 0.1),
    vec3(0.7, 0.3, 0.1),
    vec3(0.5, 0.1, 0.1),
}

for i, level in pairs(ThreatLevels) do
    level.value = i
    local c = multilerp(i, ThreatLevel.VeryLow, ThreatLevel.Impossible, colors)
    level.color = ColorRGB(c.x, c.y, c.z)
end

function RiftMissionUT.getThreatLevelNames()
    return ThreatLevels
end

function RiftMissionUT.getThreatLevel(riftDepth, massModifier, extractionModifier, effectTierModifier, missionModifier)
    local massWeight = 1
    local extractionWeight = 2
    local effectWeight = 3
    local missionWeight = 1

    -- riftDepth is the main contributor to threat level
    -- riftDepth is grouped in sizes of 5
    -- riftDepth needs more impact on difficulty, so it's weighted with factor 1.5
    local threatScore = (riftDepth / 5) * 1.5

    -- massModifier is expected to be between -1 and 2
    -- reducing of mass makes the mission more difficult
    -- increasing of mass makes mission easier
    threatScore = threatScore + massModifier * massWeight

    -- extractionModifier is either 0 or 1
    -- is used when extraction makes mission more difficult
    -- has a medium impact on difficulty, so it's weighted with factor 2
    threatScore = threatScore + extractionModifier * extractionWeight

    -- effectTierModifier is either 0 or 1
    -- is used when an enviromental effect is increased
    -- has a huge impact on difficulty, so it's weighted with factor 3
    threatScore = threatScore + effectTierModifier * effectWeight

    -- missionModifier is a specific modifier, given by the mission
    -- values are expected to be between 0 and 2
    threatScore = threatScore + missionModifier * missionWeight

    -- calculate max value for level
    -- add up all modifiers with maximum values
    local maxScore = ((75 / 5) * 1.5) + (2 * massWeight) + (1 * extractionWeight) + (1 * effectWeight) + (2 * missionWeight)

    -- we want extreme to not only happen in edge cases, so we're lerping to slightly below max possible score
    local level = round(lerp(threatScore, 1, maxScore * 0.9, ThreatLevel.VeryLow, ThreatLevel.Impossible))

    level = math.max(math.min(level, ThreatLevel.Impossible), ThreatLevel.VeryLow)
    return level
end

local function makeTier(tier, intensity)
    return {tier = tier, intensity = intensity}
end

local function tryIncreaseTier(oldTier, effectsByTier)
    -- increase the tier
    local newTier
    if oldTier == "B" then
        newTier = "G"
    elseif oldTier == "G" then
        newTier = "O"
    elseif oldTier == "O" then
        newTier = "R"
    end

    if not newTier then return false end

    -- check if there are still effects available for the new tier
    if #effectsByTier[newTier] == 0 then
        eprint("no effects for tier " .. newTier .. " left")
        return false
    end

    return true, newTier
end

function RiftMissionUT.getEnvironmentalEffects(riftDepth)
    if riftDepth < 1 or riftDepth > 75 then
        eprint("invalid rift depth given: " .. tostring(riftDepth))
        return {}
    end

    local effectsByDepth =
    {
        {makeTier("G", 1)}, -- rift depth 1
        {makeTier("G", 1)},
        {makeTier("G", 1)},
        {makeTier("G", 1), makeTier("B", 1)}, -- rift depth 4
        {makeTier("G", 1), makeTier("B", 1)},
        {makeTier("G", 1), makeTier("B", 1)},
        {makeTier("G", 1), makeTier("B", 2)}, -- rift depth 7
        {makeTier("G", 1), makeTier("B", 2)},
        {makeTier("G", 1), makeTier("B", 2)},
        {makeTier("G", 2), makeTier("G", 1)}, -- rift depth 10
        {makeTier("G", 2), makeTier("G", 1)},
        {makeTier("G", 2), makeTier("G", 1)},
        {makeTier("G", 2), makeTier("G", 1), makeTier("B", 1)}, -- rift depth 13
        {makeTier("G", 2), makeTier("G", 1), makeTier("B", 1)},
        {makeTier("G", 2), makeTier("G", 1), makeTier("B", 1)},
        {makeTier("G", 2), makeTier("G", 1), makeTier("B", 2)}, -- rift depth 16
        {makeTier("G", 2), makeTier("G", 1), makeTier("B", 2)},
        {makeTier("G", 2), makeTier("G", 1), makeTier("B", 2)},
        {makeTier("G", 2), makeTier("G", 1), makeTier("B", 3)}, -- rift depth 19
        {makeTier("G", 2), makeTier("G", 1), makeTier("B", 3)},
        {makeTier("G", 2), makeTier("G", 1), makeTier("B", 3)},
        {makeTier("O", 1), makeTier("G", 2), makeTier("G", 1)}, -- rift depth 22
        {makeTier("O", 1), makeTier("G", 2), makeTier("G", 1)},
        {makeTier("O", 1), makeTier("G", 2), makeTier("G", 1)},
        {makeTier("O", 1), makeTier("G", 2), makeTier("G", 1), makeTier("B", 1)}, -- rift depth 25
        {makeTier("O", 1), makeTier("G", 2), makeTier("G", 1), makeTier("B", 1)},
        {makeTier("O", 1), makeTier("G", 2), makeTier("G", 1), makeTier("B", 1)},
        {makeTier("O", 1), makeTier("G", 2), makeTier("G", 2)},                   -- rift depth 28
        {makeTier("O", 1), makeTier("G", 2), makeTier("G", 2)},
        {makeTier("O", 1), makeTier("G", 2), makeTier("G", 2)},
        {makeTier("O", 1), makeTier("G", 2), makeTier("G", 2), makeTier("B", 1)}, -- rift depth 31
        {makeTier("O", 1), makeTier("G", 2), makeTier("G", 2), makeTier("B", 1)},
        {makeTier("O", 1), makeTier("G", 2), makeTier("G", 2), makeTier("B", 1)},
        {makeTier("O", 1), makeTier("G", 3), makeTier("G", 2)},                   -- rift depth 34
        {makeTier("O", 1), makeTier("G", 3), makeTier("G", 2)},
        {makeTier("O", 1), makeTier("G", 3), makeTier("G", 2)},
        {makeTier("O", 1), makeTier("G", 3), makeTier("G", 2), makeTier("B", 1)}, -- rift depth 37
        {makeTier("O", 1), makeTier("G", 3), makeTier("G", 2), makeTier("B", 1)},
        {makeTier("O", 1), makeTier("G", 3), makeTier("G", 2), makeTier("B", 1)},
        {makeTier("O", 1), makeTier("G", 3), makeTier("G", 2), makeTier("B", 2)}, -- rift depth 40
        {makeTier("O", 1), makeTier("G", 3), makeTier("G", 2), makeTier("B", 2)},
        {makeTier("O", 1), makeTier("G", 3), makeTier("G", 2), makeTier("B", 2)},
        {makeTier("O", 2), makeTier("G", 2), makeTier("G", 2)},                   -- rift depth 43
        {makeTier("O", 2), makeTier("G", 2), makeTier("G", 2)},
        {makeTier("O", 2), makeTier("G", 2), makeTier("G", 2)},
        {makeTier("O", 2), makeTier("G", 2), makeTier("G", 2), makeTier("B", 1)}, -- rift depth 46
        {makeTier("O", 2), makeTier("G", 2), makeTier("G", 2), makeTier("B", 1)},
        {makeTier("O", 2), makeTier("G", 2), makeTier("G", 2), makeTier("B", 1)},
        {makeTier("O", 2), makeTier("G", 3), makeTier("G", 2)},                   -- rift depth 49
        {makeTier("O", 2), makeTier("G", 3), makeTier("G", 2)},
        {makeTier("O", 2), makeTier("G", 3), makeTier("G", 2)},
        {makeTier("O", 2), makeTier("G", 3), makeTier("G", 2), makeTier("B", 1)}, -- rift depth 52
        {makeTier("O", 2), makeTier("G", 3), makeTier("G", 2), makeTier("B", 1)},
        {makeTier("O", 2), makeTier("G", 3), makeTier("G", 2), makeTier("B", 1)},
        {makeTier("O", 2), makeTier("G", 3), makeTier("G", 2), makeTier("B", 2)}, -- rift depth 55
        {makeTier("O", 2), makeTier("G", 3), makeTier("G", 2), makeTier("B", 2)},
        {makeTier("O", 2), makeTier("G", 3), makeTier("G", 2), makeTier("B", 2)},
        {makeTier("R", 1), makeTier("O", 2), makeTier("G", 2)},                   -- rift depth 58
        {makeTier("R", 1), makeTier("O", 2), makeTier("G", 2)},
        {makeTier("R", 1), makeTier("O", 2), makeTier("G", 2)},
        {makeTier("R", 1), makeTier("O", 2), makeTier("G", 2), makeTier("B", 1)}, -- rift depth 61
        {makeTier("R", 1), makeTier("O", 2), makeTier("G", 2), makeTier("G", 1)}, -- rift depth 62
        {makeTier("R", 1), makeTier("O", 2), makeTier("G", 2), makeTier("G", 2)}, -- rift depth 63
        {makeTier("R", 1), makeTier("O", 3), makeTier("G", 2), makeTier("G", 1)}, -- rift depth 64
        {makeTier("R", 1), makeTier("O", 3), makeTier("G", 2), makeTier("G", 2)}, -- rift depth 65
        {makeTier("R", 1), makeTier("O", 3), makeTier("G", 3), makeTier("G", 2)}, -- rift depth 66
        {makeTier("R", 1), makeTier("O", 3), makeTier("G", 3), makeTier("G", 3)}, -- rift depth 67
        {makeTier("R", 2), makeTier("O", 3), makeTier("G", 2), makeTier("G", 1)}, -- rift depth 68
        {makeTier("R", 2), makeTier("O", 3), makeTier("G", 2), makeTier("G", 2)}, -- rift depth 69
        {makeTier("R", 2), makeTier("O", 3), makeTier("G", 3), makeTier("G", 2)}, -- rift depth 70
        {makeTier("R", 2), makeTier("O", 3), makeTier("G", 3), makeTier("G", 3)}, -- rift depth 71
        {makeTier("R", 3), makeTier("O", 3), makeTier("G", 2), makeTier("G", 1)}, -- rift depth 72
        {makeTier("R", 3), makeTier("O", 3), makeTier("G", 2), makeTier("G", 2)}, -- rift depth 73
        {makeTier("R", 3), makeTier("O", 3), makeTier("G", 3), makeTier("G", 2)}, -- rift depth 74
        {makeTier("R", 3), makeTier("O", 3), makeTier("G", 3), makeTier("G", 3)}, -- rift depth 75
    }

    local result = {}
    local effectsByTier = EnvironmentalEffectUT.getEffectsByTier()
    local forbiddenCombinations = EnvironmentalEffectUT.getForbiddenCombinations()

    local rand = random()
    local tierShouldIncrease = rand:test(0.5)
    local tierHasIncreased = false

    -- pick effects based on the tier
    for _, effect in pairs(effectsByDepth[riftDepth]) do
        local usedTier = effect.tier

        -- try to increase the tier
        if tierShouldIncrease and not tierHasIncreased then
            local ok, newTier = tryIncreaseTier(usedTier, effectsByTier)
            if ok then
                usedTier = newTier
                tierHasIncreased = true
            end
        end

        local index = rand:getInt(1, #effectsByTier[usedTier])
        local usedEffect = effectsByTier[usedTier][index]

        -- remove the used effect so it doesn't appear twice
        table.remove(effectsByTier[usedTier], index)

        -- remove all effects that can't be combined with the used effect
        local forbiddenEffects = forbiddenCombinations[usedEffect] or {}
        for tier, tierEffects in pairs(effectsByTier) do
            local allowedEffects = {}
            for _, tierEffect in pairs(tierEffects) do
                if not forbiddenEffects[tierEffect] then
                    table.insert(allowedEffects, tierEffect)
                end
            end

            effectsByTier[tier] = allowedEffects
        end

        -- add the effect with the given intensity
        result[usedEffect] = math.min(effect.intensity, EnvironmentalEffectUT.data[usedEffect].maxIntensity)
    end

    -- always add subspace distortion
    result[EnvironmentalEffectType.SubspaceDistortion] = riftDepth

    -- add xsotan buffs
    result[EnvironmentalEffectType.XsotanDurabilityBoost] = riftDepth
    result[EnvironmentalEffectType.XsotanDamageBoost] = riftDepth

    local difficultyModifier = 0
    if tierHasIncreased then
        difficultyModifier = 1
    end

    return result, difficultyModifier
end

function RiftMissionUT.getRegionalConstraints(x, y, riftDepth)
    -- values were found through analysis of generated Avorion ships
    -- these are the values for pirate-size ships (volume factor 1)
    local values = {4000, 5000, 6000, 10000, 18000, 26000, 33000, 40000, 48000, 57000, 67000}

    local dist = length(vec2(x, y))
    local massFactor = lerp(dist, 450, 0, 4, 16) -- scales mass up to ~1000 kT in the center (corresponds to a generated 12 socket Avorion ship)
    local mass = multilerp(dist, 500, 0, values) * massFactor * GameSettings().riftMassFactor
    local baseMass = mass

    -- allowed mass can vary by up to 40%
    local diffs = {}
    diffs[{change = 0.0, threat = 0}] = 1.0
    diffs[{change = 0.2, threat = -1}] = 0.66
    diffs[{change = -0.2, threat = 1}] = 0.66
    diffs[{change = 0.4, threat = -2}] = 0.175

    local diff = selectByWeight(random(), diffs)
    local threatModifier = diff.threat
    mass = mass + (mass * diff.change)

    if riftDepth then
        -- at lower rift depths, allowed mass constraint is relaxed by up to 50%
        mass = lerp(riftDepth, 1, 20, mass * 1.5, mass)
    end

    -- reducing possible mass feels very harsh to players
    -- adding possible mass feels less rewarding for the same proportions
    -- this is why we're giving those modifiers different impacts
    if threatModifier < 0 then
        threatModifier = threatModifier * 0.5
    end

    mass = round(mass / 100) * 100
    if mass > 100000 then
        mass = round(mass / 1000) * 1000
    end

    local constraints = {}
    constraints[Constraints.Type.MaxMass] = mass

    return constraints, threatModifier, baseMass
end

function RiftMissionUT.getRiftDataGood()
    return goods["Rift Research Data"]:good()
end

function RiftMissionUT.getRewardSpecs(riftDepth, massModifier, extractionModifier, effectTierModifier, threatLevel)
    local rare = RarityType.Rare
    local exceptional = RarityType.Exceptional
    local exotic = RarityType.Exotic
    local legendary = RarityType.Legendary

    local rewards =
    {
        {l = {rare}, r = {rare},                               p = 1,  up = {-0.6, 0.0}}, -- rift depth 1
        {l = {rare}, r = {rare},                               p = 1,  up = {-0.6, 0.1}},
        {l = {rare}, r = {rare},                               p = 1,  up = {-0.6, 0.2}},
        {l = {rare}, r = {rare},                               p = 1,  up = {-0.6, 0.3}},
        {l = {rare}, r = {rare},                               p = 1,  up = {-0.6, 0.4}},
        {l = {rare}, r = {rare},                               p = 1,  up = {-0.6, 0.5}},
        {l = {rare}, r = {rare},                               p = 1,  up = {-0.6, 0.5}},
        {l = {rare}, r = {rare}, turret = true,                p = 2,  up = {-0.5, 0.5}}, -- rift depth 8
        {l = {rare}, r = {rare}, turret = true,                p = 2,  up = {-0.4, 0.5}},
        {l = {rare}, r = {rare}, turret = true,                p = 2,  up = {-0.3, 0.5}},
        {l = {rare}, r = {rare}, turret = true,                p = 2,  up = {-0.2, 0.5}},
        {l = {rare}, r = {rare}, turret = true,                p = 2,  up = {-0.1, 0.5}},
        {l = {rare}, r = {rare}, turret = true,                p = 2,  up = {-0.0, 0.5}},
        {l = {rare, rare}, r = {exceptional}, rp = 1,          p = 3,  up = {-0.5, 0.5}}, -- rift depth 14
        {l = {rare, rare}, r = {exceptional}, rp = 1,          p = 3,  up = {-0.4, 0.5}},
        {l = {rare, rare}, r = {exceptional}, rp = 1,          p = 3,  up = {-0.3, 0.5}},
        {l = {rare, rare}, r = {exceptional}, rp = 1,          p = 3,  up = {-0.2, 0.5}},
        {l = {rare, rare}, r = {exceptional}, rp = 1,          p = 3,  up = {-0.1, 0.5}},
        {l = {rare, rare}, r = {exceptional}, rp = 1,          p = 3,  up = { 0.0, 0.5}},
        {l = {exceptional}, r = {exceptional},                 p = 5,  up = {-0.6, 0.5}}, -- rift depth 20
        {l = {exceptional}, r = {exceptional},                 p = 5,  up = {-0.5, 0.5}},
        {l = {exceptional}, r = {exceptional},                 p = 5,  up = {-0.4, 0.5}},
        {l = {exceptional}, r = {exceptional},                 p = 5,  up = {-0.3, 0.5}},
        {l = {exceptional}, r = {exceptional},                 p = 5,  up = {-0.2, 0.5}},
        {l = {exceptional}, r = {exceptional},                 p = 5,  up = {-0.1, 0.5}},
        {l = {exceptional}, r = {exceptional},                 p = 5,  up = {-0.0, 0.5}},
        {l = {exceptional}, r = {exceptional}, turret = true,  p = 6,  up = {-0.3, 0.5}}, -- rift depth 27
        {l = {exceptional}, r = {exceptional}, turret = true,  p = 6,  up = {-0.2, 0.5}},
        {l = {exceptional}, r = {exceptional}, turret = true,  p = 6,  up = {-0.5, 0.5}},
        {l = {exceptional}, r = {exceptional}, turret = true,  p = 6,  up = {-0.4, 0.5}},
        {l = {exceptional}, r = {exceptional}, turret = true,  p = 6,  up = {-0.3, 0.5}},
        {l = {exceptional}, r = {exceptional}, turret = true,  p = 6,  up = {-0.2, 0.5}},
        {l = {exceptional, exceptional}, r = {exotic}, rp = 1, p = 7,  up = {-0.5, 0.5}}, -- rift depth 33
        {l = {exceptional, exceptional}, r = {exotic}, rp = 1, p = 7,  up = {-0.4, 0.5}},
        {l = {exceptional, exceptional}, r = {exotic}, rp = 1, p = 7,  up = {-0.3, 0.5}},
        {l = {exceptional, exceptional}, r = {exotic}, rp = 1, p = 7,  up = {-0.2, 0.5}},
        {l = {exceptional, exceptional}, r = {exotic}, rp = 1, p = 7,  up = {-0.1, 0.5}},
        {l = {exceptional, exceptional}, r = {exotic}, rp = 1, p = 7,  up = {-0.0, 0.5}},
        {l = {exotic}, r = {exotic},                           p = 9,  up = {-0.6, 0.5}}, -- rift depth 39
        {l = {exotic}, r = {exotic},                           p = 9,  up = {-0.5, 0.5}},
        {l = {exotic}, r = {exotic},                           p = 9,  up = {-0.4, 0.5}},
        {l = {exotic}, r = {exotic},                           p = 9,  up = {-0.3, 0.5}},
        {l = {exotic}, r = {exotic},                           p = 9,  up = {-0.2, 0.5}},
        {l = {exotic}, r = {exotic},                           p = 9,  up = {-0.1, 0.5}},
        {l = {exotic}, r = {exotic},                           p = 9,  up = {-0.0, 0.5}},
        {l = {exotic}, r = {exotic}, turret = true,            p = 10, up = {-0.5, 0.5}}, -- rift depth 46
        {l = {exotic}, r = {exotic}, turret = true,            p = 10, up = {-0.4, 0.5}},
        {l = {exotic}, r = {exotic}, turret = true,            p = 10, up = {-0.3, 0.5}},
        {l = {exotic}, r = {exotic}, turret = true,            p = 10, up = {-0.2, 0.5}},
        {l = {exotic}, r = {exotic}, turret = true,            p = 10, up = {-0.1, 0.5}},
        {l = {exotic}, r = {exotic}, turret = true,            p = 10, up = {-0.0, 0.5}},
        {l = {exotic, exotic}, r = {legendary}, rp = 1,        p = 11, up = {-0.5, 0.5}}, -- rift depth 52
        {l = {exotic, exotic}, r = {legendary}, rp = 1,        p = 11, up = {-0.4, 0.5}},
        {l = {exotic, exotic}, r = {legendary}, rp = 1,        p = 11, up = {-0.3, 0.5}},
        {l = {exotic, exotic}, r = {legendary}, rp = 1,        p = 11, up = {-0.2, 0.5}},
        {l = {exotic, exotic}, r = {legendary}, rp = 1,        p = 11, up = {-0.1, 0.5}},
        {l = {exotic, exotic}, r = {legendary}, rp = 1,        p = 11, up = {-0.0, 0.5}},
        {l = {legendary}, r = {legendary},                     p = 13, up = {-0.6, 0.5}}, -- rift depth 58
        {l = {legendary}, r = {legendary},                     p = 13, up = {-0.5, 0.5}},
        {l = {legendary}, r = {legendary},                     p = 13, up = {-0.4, 0.5}},
        {l = {legendary}, r = {legendary},                     p = 13, up = {-0.3, 0.5}},
        {l = {legendary}, r = {legendary},                     p = 13, up = {-0.2, 0.5}},
        {l = {legendary}, r = {legendary},                     p = 13, up = {-0.1, 0.5}},
        {l = {legendary}, r = {legendary},                     p = 13, up = {-0.0, 0.5}},
        {l = {legendary}, r = {legendary}, turret = true,      p = 14, up = {-0.5, 0.5}}, -- rift depth 65
        {l = {legendary}, r = {legendary}, turret = true,      p = 14, up = {-0.4, 0.5}},
        {l = {legendary}, r = {legendary}, turret = true,      p = 14, up = {-0.3, 0.5}},
        {l = {legendary}, r = {legendary}, turret = true,      p = 14, up = {-0.2, 0.5}},
        {l = {legendary}, r = {legendary}, turret = true,      p = 14, up = {-0.1, 0.5}},
        {l = {legendary}, r = {legendary}, turret = true,      p = 14, up = {-0.0, 0.5}},
        {l = {legendary,exotic}, r = {legendary,exotic},       p = 15, up = {-0.5, 0.5}}, -- rift depth 71
        {l = {legendary,exotic}, r = {legendary,exotic},       p = 15, up = {-0.4, 0.5}},
        {l = {legendary,exotic}, r = {legendary,exotic},       p = 15, up = {-0.3, 0.5}},
        {l = {legendary,exotic}, r = {legendary,exotic},       p = 15, up = {-0.2, 0.5}},
        {l = {legendary,legendary}, r = {legendary,legendary}, p = 15, up = {-0.1, 0.5}}, -- rift depth 75
    }

    -- same as in getThreatLevel()
    local massWeight = 1
    local extractionWeight = 2
    local effectWeight = 3
    -- mission weight is omitted on purpose, mission type should not change the general reward
    -- missions can drop additional loot if they feel like it (Xsotan Boss)

    -- adjust rewards if threat level is modified to make it more rewarding for players to play difficult missions
    local riftDepthAdjustment = massModifier * massWeight -- mass modifier is between -1 and 2
                                + extractionModifier * extractionWeight -- extraction modifier is between 0 and 1
                                + effectTierModifier * effectWeight -- effect modifier is between 0 and 1

    -- to make reward/difficulty be more comprehensible, we cap rewards at certain difficulties
    local threatLevelCaps = {}
    threatLevelCaps[ThreatLevel.VeryLow]         = 13 -- "very low" won't get you an exceptional
    threatLevelCaps[ThreatLevel.Low]             = 19
    threatLevelCaps[ThreatLevel.Moderate]        = 26
    threatLevelCaps[ThreatLevel.Challenging]     = 32 -- "very challenging" is required for first exotic
    threatLevelCaps[ThreatLevel.VeryChallenging] = 38 -- "high" is required for exotic/exotic choice
    threatLevelCaps[ThreatLevel.High]            = 51 -- "very high" is required for first legendary
    threatLevelCaps[ThreatLevel.VeryHigh]        = 57
    threatLevelCaps[ThreatLevel.Extraordinary]   = 64
    threatLevelCaps[ThreatLevel.Extreme]         = 70
    threatLevelCaps[ThreatLevel.DeathSentence]   = 74 -- "impossible" is required for 2leg/2leg
    threatLevelCaps[ThreatLevel.Impossible]      = 75 -- this is where 2 legendary / 2 legendary are possible

    local cap = threatLevelCaps[threatLevel or 0] or 75
    riftDepth = math.min(cap, math.max(1, riftDepth + round(riftDepthAdjustment)))
    local reward = rewards[riftDepth]

    return reward
end

local rollProtection = function(p, up)
    local protection = p or 1
    if random():test(0.66) then
        if random():getFloat(up[1], up[2]) > 0 then
            protection = protection + 1
        else
            protection = protection - 1
        end
    end

    if protection < 1 then protection = 1 end
    if protection > 15 then protection = 15 end

    return protection
end

function RiftMissionUT.makeReward(x, y, rewardSpecs)
    local left = {}
    local right = {}
    local additional = {}

    local scripts = RiftMissionUT.getUpgradeScripts()
    local generator = UpgradeGenerator()

    local leftScript = nil

    -- left side
    for _, rarityType in pairs(rewardSpecs.l) do
        local protection = rollProtection(rewardSpecs.p, rewardSpecs.up)
        local script = randomEntry(scripts)
        local rarity = Rarity(rarityType)
        local seed = generator:getUpgradeSeed(x, y, script, rarity)
        seed = SubsystemProtection.adjustSeed(seed, protection)

        leftScript = script
        table.insert(left, SystemUpgradeTemplate(script, rarity, seed))
    end

    -- prevent same subsystem type on both sides of the reward
    if #rewardSpecs.r == 1 and #rewardSpecs.l == 1 then
        for i, availableScript in pairs(scripts) do
            if availableScript == leftScript then
                scripts[i] = scripts[#scripts]
                table.remove(scripts)
                break
            end
        end
    end

    -- right side
    for _, rarityType in pairs(rewardSpecs.r) do
        local protection = rollProtection(rewardSpecs.p + (rewardSpecs.rp or 0), rewardSpecs.up)

        local script = randomEntry(scripts)
        local rarity = Rarity(rarityType)
        local seed = generator:getUpgradeSeed(x, y, script, rarity)
        seed = SubsystemProtection.adjustSeed(seed, protection)

        table.insert(right, SystemUpgradeTemplate(script, rarity, seed))
    end

    -- additional turrets, if any
    if rewardSpecs.turret then
        local generator = SectorTurretGenerator()
        local rarity = Rarity(rewardSpecs.l[1] - 1)
        local turret = InventoryTurret(generator:generate(x, y, 0, rarity))

        table.insert(additional, turret)
    end

    return left, right, additional
end

function RiftMissionUT.getReward(x, y, riftDepth, massModifier, extractionModifier, effectTierModifier, threatLevel)
    local reward = RiftMissionUT.getRewardSpecs(riftDepth, massModifier, extractionModifier, effectTierModifier, threatLevel)
    return RiftMissionUT.makeReward(x, y, reward)
end

function RiftMissionUT.getUpgradeScripts()
    return {
        "internal/dlc/rift/systems/arbitrarytcsenergyhybrid.lua",
        "internal/dlc/rift/systems/militarytcshyperspacehybrid.lua",
        "internal/dlc/rift/systems/energyhyperspaceboosterhybrid.lua",
        "internal/dlc/rift/systems/energyshieldboosterhybrid.lua",
        "internal/dlc/rift/systems/hypertradingsystem.lua",
        "internal/dlc/rift/systems/interceptorhybrid.lua",
        "internal/dlc/rift/systems/militarytcsshieldhybrid.lua",
        "internal/dlc/rift/systems/miningcarrierhybrid.lua",
        "internal/dlc/rift/systems/overshield.lua",
        "internal/dlc/rift/systems/salvagingcarrierhybrid.lua",
        "internal/dlc/rift/systems/superscoutsystem.lua",
        "internal/dlc/rift/systems/combatcarrierhybrid.lua",
        "internal/dlc/rift/systems/shieldcarrierhybrid.lua",
    }
end

function RiftMissionUT.getDroppableHybridUpgrade(x, y, riftDepth, rarityOverride, threatLevel)
    local specs = RiftMissionUT.getRewardSpecs(riftDepth, 0, 0, 0, threatLevel)

    -- use the right side because its rarity is higher, we want to give out the best possible upgrade
    local rarity = Rarity(specs.r[1])
    if rarityOverride then rarity = rarityOverride end

    local script = randomEntry(RiftMissionUT.getUpgradeScripts())
    local seed = UpgradeGenerator():getUpgradeSeed(x, y, script, rarity)

    local protection = rollProtection(specs.p, specs.up)
    seed = SubsystemProtection.adjustSeed(seed, protection)

    return SystemUpgradeTemplate(script, rarity, seed)
end

function RiftMissionUT.showMissionAccomplished(brief, arguments)
    if onServer() then
        invokeClientFunction(Player(), "showMissionAccomplished", brief, arguments)
        return
    end

    displayMissionAccomplishedText("RIFT EXPEDITION SUCCESSFUL"%_t, (brief or "")%_t % arguments)
    playSound("interface/mission-accomplished", SoundType.UI, 1)
end

function RiftMissionUT.showMissionFailed(brief, arguments)
    if onServer() then
        invokeClientFunction(Player(), "showMissionFailed", brief, arguments)
        return
    end

    displayMissionAccomplishedText("RIFT EXPEDITION FAILED"%_t, (brief or "")%_t % arguments)
end

function RiftMissionUT.showMissionAbandoned(brief, arguments)
    if onServer() then
        invokeClientFunction(Player(), "showMissionAbandoned", brief, arguments)
        return
    end

    displayMissionAccomplishedText("RIFT EXPEDITION ABANDONED"%_t, (brief or "")%_t % arguments)
end

function RiftMissionUT.showMissionUpdated(brief, arguments)
    if onServer() then
        invokeClientFunction(Player(), "showMissionUpdated", brief, arguments)
        return
    end

    displayMissionAccomplishedText("RIFT EXPEDITION UPDATED"%_t, (brief or "")%_t % arguments)
end

function RiftMissionUT.showMissionStarted(brief, arguments)
    if onServer() then
        invokeClientFunction(Player(), "showMissionStarted", brief, arguments)
        return
    end

    displayMissionAccomplishedText("NEW RIFT EXPEDITION"%_t, (brief or "")%_t % arguments)
end

return RiftMissionUT
