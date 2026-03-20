package.path = package.path .. ";data/scripts/lib/?.lua"
include("stringutility")
include("utility")
include("randomext")

--local ShipUtility = include("shiputility")

local distributions = {}
distributions[Difficulty.Insane] = {maxDist = 550, minDist = 150, from = 0, to = 1}
distributions[Difficulty.Hardcore] = {maxDist = 500, minDist = 150, from = 0, to = 0.8}
distributions[Difficulty.Expert] = {maxDist = 500, minDist = 50, from = 0, to = 0.6}
distributions[Difficulty.Veteran] = {maxDist = 450, minDist = 50, from = 0, to = 0.5}
distributions[Difficulty.Normal] = {maxDist = 430, minDist = 50, from = 0, to = 0.4}
distributions[Difficulty.Easy] = {maxDist = 430, minDist = 50, from = 0, to = 0.3}
distributions[Difficulty.Beginner] = {maxDist = 430, minDist = 50, from = 0, to = 0.25}

local level2Distributions = {}
level2Distributions[Difficulty.Insane] = {start = 400, percentage = 0.5}
level2Distributions[Difficulty.Hardcore] = {start = 400, percentage = 0.3}
level2Distributions[Difficulty.Expert] = {start = 400, percentage = 0.3}
level2Distributions[Difficulty.Veteran] = {start = 380, percentage = 0.3}
level2Distributions[Difficulty.Normal] = {start = 360, percentage = 0.3}
level2Distributions[Difficulty.Easy] = {start = 340, percentage = 0.3}
level2Distributions[Difficulty.Beginner] = {start = 320, percentage = 0.3}

local level3DistributionsOuter = {}
level3DistributionsOuter[Difficulty.Insane] = {start = 350, percentage = 0.075}
level3DistributionsOuter[Difficulty.Hardcore] = {start = 300, percentage = 0.05}
level3DistributionsOuter[Difficulty.Expert] = {start = 250, percentage = 0.05}
level3DistributionsOuter[Difficulty.Veteran] = {start = 210, percentage = 0.05}
level3DistributionsOuter[Difficulty.Normal] = {start = 180, percentage = 0.05}
level3DistributionsOuter[Difficulty.Easy] = {start = 150, percentage = 0}
level3DistributionsOuter[Difficulty.Beginner] = {start = 150, percentage = 0}

local level3DistributionsInner = {}
level3DistributionsInner[Difficulty.Insane] = {maxDist = 150, minDist = 0, from = 0.075, to = 0.3}
level3DistributionsInner[Difficulty.Hardcore] = {maxDist = 150, minDist = 0, from = 0, to = 0.25}
level3DistributionsInner[Difficulty.Expert] = {maxDist = 150, minDist = 0, from = 0, to = 0.25}
level3DistributionsInner[Difficulty.Veteran] = {maxDist = 150, minDist = 0, from = 0, to = 0.2}
level3DistributionsInner[Difficulty.Normal] = {maxDist = 150, minDist = 0, from = 0, to = 0.125}
level3DistributionsInner[Difficulty.Easy] = {maxDist = 150, minDist = 0, from = 0, to = 0.1}
level3DistributionsInner[Difficulty.Beginner] = {maxDist = 150, minDist = 0, from = 0, to = 0}


-- Resistance
local resiDistributions = {}
resiDistributions[Difficulty.Insane] = {maxDist = 370, minDist = 100, from = 0.4, to = 0.6}
resiDistributions[Difficulty.Hardcore] = {maxDist = 370, minDist = 100, from = 0.35, to = 0.55}
resiDistributions[Difficulty.Expert] = {maxDist = 370, minDist = 100, from = 0.35, to = 0.5}
resiDistributions[Difficulty.Veteran] = {maxDist = 370, minDist = 100, from = 0.2, to = 0.45}
resiDistributions[Difficulty.Normal] = {maxDist = 300, minDist = 100, from = 0.2, to = 0.4}
resiDistributions[Difficulty.Easy] = {maxDist = 300, minDist = 100, from = 0.1, to = 0.25}
resiDistributions[Difficulty.Beginner] = {maxDist = 300, minDist = 100, from = 0.1, to = 0.25}

local resistanceKinds = {
    DamageType.Physical,
    DamageType.Plasma,
    DamageType.Electric,
    DamageType.AntiMatter
}

local resistanceFactors = {}
resistanceFactors[0] = {maxDist = 370, minDist = 100, from = 0.75, to = 0.8}
resistanceFactors[1] = {maxDist = 370, minDist = 100, from = 0.80, to = 0.85}
resistanceFactors[2] = {maxDist = 370, minDist = 100, from = 0.85, to = 0.9}
resistanceFactors[3] = {maxDist = 370, minDist = 100, from = 0.9, to = 0.9}


-- Weakness
local weaknessProbability = 0.2
local durabilityIncrease = 0.5 -- weakness increases HP by 50 %
local weaknessFactor = 2 -- weakness increases damage by that type by 200 %

local weaknessKinds =
{
    DamageType.Energy,
    DamageType.Plasma,
    DamageType.Electric,
    DamageType.AntiMatter
}

-- namespace SpawnUtility
local SpawnUtility = {}

SpawnUtility.distributions = distributions
SpawnUtility.level2Distributions = level2Distributions
SpawnUtility.level3DistributionsOuter = level3DistributionsOuter
SpawnUtility.level3DistributionsInner = level3DistributionsInner

SpawnUtility.resiDistributions = resiDistributions
SpawnUtility.resistanceKinds = resistanceKinds
SpawnUtility.resistanceFactors = resistanceFactors

SpawnUtility.weaknessProbability = weaknessProbability
SpawnUtility.durabilityIncrease = durabilityIncrease
SpawnUtility.weaknessFactor = weaknessFactor
SpawnUtility.weaknessKinds = weaknessKinds

function SpawnUtility.getToughieChances(x, y)
    local distribution = {}
    local distToCenter = math.sqrt(x * x + y * y)
    local difficulty = GameSettings().difficulty

    local d = distributions[difficulty]
    local d2 = level2Distributions[difficulty]

    local result = {}
    result.level1 = lerp(distToCenter, d.maxDist, d.minDist, d.from, d.to)

    result.level2 = 0
    if distToCenter <= d2.start then result.level2 = d2.percentage end

    result.level3 = 0
    if distToCenter < 150 then
        local d3 = level3DistributionsInner[difficulty]
        result.level3 = lerp(distToCenter, d3.maxDist, d3.minDist, d3.from, d3.to)
    else
        local d3 = level3DistributionsOuter[difficulty]
        if distToCenter <= d3.start then result.level3 = d3.percentage end
    end

    return result
end

function SpawnUtility.determineShipAmount(numShips, portion)
    local result = numShips * portion

    local rest = result - math.floor(result)
    if random():test(rest) then result = result + 1 end

    return result
end

function SpawnUtility.applyToughnessBuffs(ships)
    local numShips = #ships
    local toughieChance = SpawnUtility.getToughieChances(Sector():getCoordinates())
    local totalToughies = SpawnUtility.determineShipAmount(numShips, toughieChance.level1)

    if totalToughies > 0 then
        local numLevel2Toughies = SpawnUtility.determineShipAmount(totalToughies, toughieChance.level2)
        local numLevel3Toughies = SpawnUtility.determineShipAmount(totalToughies, toughieChance.level3)
        local numLevel1Toughies = totalToughies - numLevel2Toughies - numLevel3Toughies

        local c = 1
        local level1Toughies = {}
        for i = 1, numLevel1Toughies do
            table.insert(level1Toughies, ships[c]); c = c + 1
        end

        local level2Toughies = {}
        for i = 1, numLevel2Toughies do
            table.insert(level2Toughies, ships[c]); c = c + 1
        end

        local level3Toughies = {}
        for i = 1, numLevel3Toughies do
            table.insert(level3Toughies, ships[c]); c = c + 1
        end

        shuffle(random(), level1Toughies)
        shuffle(random(), level2Toughies)
        shuffle(random(), level3Toughies)

        for _, ship in pairs(level1Toughies) do
            SpawnUtility.addToughness(ship, 1)
        end

        for _, ship in pairs(level2Toughies) do
            SpawnUtility.addToughness(ship, 2)
        end

        for _, ship in pairs(level3Toughies) do
            SpawnUtility.addToughness(ship, 3)
        end
    end
end



function SpawnUtility.getResistanceChances(x, y)
    local distToCenter = math.sqrt(x * x + y * y)
    local difficulty = GameSettings().difficulty
    local d = resiDistributions[difficulty]

    if distToCenter <= d.maxDist then
        local result = lerp(distToCenter, d.maxDist, d.minDist, d.from, d.to)
        return  result
    end

    return 0.0
end

function SpawnUtility.applyResistanceBuffs(ships)
    -- do this before calculating toughies! Toughies change their resistance factor
    local numShips = #ships
    local resiChance = SpawnUtility.getResistanceChances(Sector():getCoordinates())
    local numResiShips = SpawnUtility.determineShipAmount(numShips, resiChance)
    if numResiShips == 0 then return end

    local ships = table.deepcopy(ships)
    shuffle(random(), ships)

    -- use basic factor - toughies set that factor accordingly later
    local difficulty = GameSettings().difficulty
    local d = resistanceFactors[0]
    local flatFactor = (difficulty + 1) * 0.05
    local x, y = Sector():getCoordinates()
    local distToCenter = math.sqrt(x * x + y * y)
    local factor = lerp(distToCenter, d.maxDist, d.minDist, d.from, d.to)
    factor = factor + flatFactor

    local c = 1
    for i = 1, numResiShips do
        local ship = ships[c]
        if ship then
            local resistance = randomEntry(random(), resistanceKinds)
            SpawnUtility.addResistance(ship, resistance, factor) -- here factor needed
        end
        c = c + 1
    end
end

function SpawnUtility.applyResistanceFactorBuff(ship, level, distToCenter)
    level = level or 0
    if not valid(ship) then return end

    local d = resistanceFactors[level]
    local difficulty = GameSettings().difficulty
    local flatFactor = (difficulty + 1) * 0.05
    local factor = lerp(distToCenter, d.maxDist, d.minDist, d.from, d.to) + flatFactor

    local shield = Shield(ship.id)
    local resistance = {shield:getResistance()}
    if resistance then
        SpawnUtility.addResistance(ships, resistance.type, resistance.factor)
    end
end


function SpawnUtility.applyWeaknessBuffs(ships)
    -- do this after Resistances, so that equal effects can be avoided
    local numShips = #ships
    local numWeaknessShips = SpawnUtility.determineShipAmount(numShips, weaknessProbability)
    if numWeaknessShips == 0 then return end

    local ships = table.deepcopy(ships)
    shuffle(random(), ships)

    local c = 1
    local resiShips = {}
    for i = 1, numWeaknessShips do
        local ship = ships[c]
        if not ship or not valid(ship) then goto continue end

        local shield = Shield(ship.id)
        local weakness = randomEntry(random(), weaknessKinds)

        if not shield then
            -- we can simply add weakness, as there is no resistance
            SpawnUtility.addWeakness(ship, weakness, weaknessFactor, durabilityIncrease)
            c = c + 1
        else
            local res = {shield:getResistance()}
            if res then
                if res[1] == weakness then
                    -- try a different entry
                    local old = weakness
                    while old == weakness do
                        weakness = randomEntry(random(), resistanceKinds)
                    end
                end
            end
            -- then add (newly) determined weakness
            SpawnUtility.addWeakness(ship, weakness, weaknessFactor, durabilityIncrease)
            c = c + 1
        end

        ::continue::
    end
end

-- apply
-- this function doesn't check on existing resistance or weakness types!
function SpawnUtility.addResistance(entity, damageType, factor)
    if not entity then return end

    local shield = Shield(entity.id)
    if not shield then return end

    shield:setResistance(damageType, factor)
end

function SpawnUtility.resetResistance(entity)
    if not entity then return end

    local shield = Shield(entity.id)
    if not shield then return end

    shield:resetResistance()
end

-- this function doesn't check on existing resistance or weakness types!
function SpawnUtility.addWeakness(entity, damageType, factor, hpFactor)
    if not entity then return end

    local durability = Durability(entity.id)
    if not durability then return end

    durability:setWeakness(damageType, factor)
    durability.maxDurabilityFactor = durability.maxDurabilityFactor + hpFactor
end

function SpawnUtility.resetWeakness(entity, hpFactor)
    if not entity then return end

    local durability = Durability(entity.id)
    if not durability then return end

    durability:resetWeakness()
    if not hpFactor then return end
    durability.maxDurabilityFactor = durability.maxDurabilityFactor - hpFactor
end

function SpawnUtility.addToughness(entity, level)
    if not entity or not valid(entity) then return end

    local hpFactor = 1
    local dmgFactor = 1

    if level == 1 then
        if entity.title then
            local titleArgs = entity:getTitleArguments()
            if titleArgs then
                titleArgs.toughness = "Tough "%_T
                entity:setTitleArguments(titleArgs)
            else
                entity.title = "Tough "%_T .. entity.title
            end
        end
        hpFactor = 1.5
        dmgFactor = 1.5
    elseif level == 2 then
        if entity.title then
            local titleArgs = entity:getTitleArguments()
            if titleArgs then
                titleArgs.toughness = "Savage "%_T
                entity:setTitleArguments(titleArgs)
            else
                entity.title = "Savage "%_T .. entity.title
            end
        end
        hpFactor = 2.25
        dmgFactor = 2
    elseif level == 3 then
        if entity.title then
            local titleArgs = entity:getTitleArguments()
            if titleArgs then
                titleArgs.toughness = "Hardcore "%_T
                entity:setTitleArguments(titleArgs)
            else
                entity.title = "Hardcore "%_T .. entity.title
            end
        end
        hpFactor = 3
        dmgFactor = 3
    end

    local durability = Durability(entity)
    if durability then durability.maxDurabilityFactor = (durability.maxDurabilityFactor or 0) + hpFactor end

    local shield = Shield(entity)
    if shield then shield.maxDurabilityFactor = (shield.maxDurabilityFactor or 0) + hpFactor end

    if dmgFactor ~= 1 then entity.damageMultiplier = (entity.damageMultiplier or 1) * dmgFactor end

    -- increase resistances if existing
    local x, y = Sector():getCoordinates()
    local distToCenter = math.sqrt(x * x + y * y)
    SpawnUtility.applyResistanceFactorBuff(entity, level, distToCenter)

end

function SpawnUtility.addEnemyBuffs(ships)

    -- apply Resistances
    SpawnUtility.applyResistanceBuffs(ships)
    -- then weaknesses - checks to not have same type of resistance and weakness on one ship
    SpawnUtility.applyWeaknessBuffs(ships)
    -- now apply toughness buffs, resi factors are increased if necessary
    SpawnUtility.applyToughnessBuffs(ships)

end


return SpawnUtility
