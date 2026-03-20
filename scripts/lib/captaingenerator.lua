package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")
local CaptainUtility = include("captainutility")

local CaptainGenerator = {}
CaptainGenerator.__index = CaptainGenerator

local function new(seed)
    local obj = setmetatable({}, CaptainGenerator)
    obj:initialize(seed)
    return obj
end

function CaptainGenerator:initialize(seed)
    self.seed = seed or random():createSeed()
    if type(self.seed) == "number" or type(self.seed) == "string" then
        self.seed = Seed(self.seed)
    end

    self.random = Random(self.seed)
end


local opposingPerks = {}
local function addOpposingPerk(a, b)
    if not opposingPerks[a] then
        opposingPerks[a] = {}
    end

    if not opposingPerks[b] then
        opposingPerks[b] = {}
    end

    table.insert(opposingPerks[a], b)
    table.insert(opposingPerks[b], a)
end
addOpposingPerk(CaptainUtility.PerkType.Educated, CaptainUtility.PerkType.Uneducated)
addOpposingPerk(CaptainUtility.PerkType.Humble, CaptainUtility.PerkType.Greedy)
addOpposingPerk(CaptainUtility.PerkType.Reckless, CaptainUtility.PerkType.Careful)
addOpposingPerk(CaptainUtility.PerkType.Navigator, CaptainUtility.PerkType.Disoriented)
addOpposingPerk(CaptainUtility.PerkType.Stealthy, CaptainUtility.PerkType.Arrogant)
addOpposingPerk(CaptainUtility.PerkType.Cunning, CaptainUtility.PerkType.Harmless)
addOpposingPerk(CaptainUtility.PerkType.Noble, CaptainUtility.PerkType.Commoner)
addOpposingPerk(CaptainUtility.PerkType.Lucky, CaptainUtility.PerkType.Unlucky)
addOpposingPerk(CaptainUtility.PerkType.Intimidating, CaptainUtility.PerkType.Harmless)
addOpposingPerk = nil

local function removeItemsFromTable(table_in, items)
    for i, entry in pairs(table_in) do
        for _, entry2 in pairs(items) do
            if entry == entry2 then
                table.remove(table_in, i)
            end
        end
    end
end

-- generate a randomized captain from potentially given tier, level and classes
-- note: returns nil if parameters would lead to a faulty captain
function CaptainGenerator:generate(tier_in, level_in, primaryClass_in, secondaryClass_in)
    -- check inputs
    if self:checkParametersFaulty(tier_in, level_in, primaryClass_in, secondaryClass_in) then
        return nil
    end

    -- inputs are fine => produce captain
    local captain = Captain()

    local language = Language(self.random:createSeed())
    captain.name = language:getName()

    if random():test(0.5) then
        captain.genderId = CaptainGenderId.Male
    else
        captain.genderId = CaptainGenderId.Female
    end

    -- set tier
    captain.tier = tier_in or self.random:getInt(0, 3)

    -- set class or classes, under consideration of given classes
    captain.primaryClass = primaryClass_in or 0
    captain.secondaryClass = secondaryClass_in or 0


    if (captain.tier > 0 and captain.primaryClass == 0)
        or (captain.tier == 3 and captain.secondaryClass == 0) then

        captain.primaryClass, captain.secondaryClass = self:determineCaptainClasses(self.random, captain.tier, primaryClass_in)
    end

    -- determine possible perks
    local positive, negative, neutral = self:getPossiblePerks()

    -- remove perks forbidden by primary class
    if captain.primaryClass ~= 0 then
        local positiveToRemove, negativeToRemove, neutralToRemove = self:getImpossiblePerksOfClass(captain.primaryClass)
        removeItemsFromTable(positive, positiveToRemove)
        removeItemsFromTable(negative, negativeToRemove)
        removeItemsFromTable(neutral, neutralToRemove)
    end

    -- and for secondary class
    if captain.secondaryClass ~= 0 then
        local positiveToRemove, negativeToRemove, neutralToRemove = self:getImpossiblePerksOfClass(captain.secondaryClass)
        removeItemsFromTable(positive, positiveToRemove)
        removeItemsFromTable(negative, negativeToRemove)
        removeItemsFromTable(neutral, neutralToRemove)
    end

    -- select perks
    local perks = {}
    local numPositivePerks, numNegativePerks, numNeutralPerks = self:getNumPerksFromTier(self.random, captain.tier)

    local positivePerks = self:pickUniquePerks(positive, numPositivePerks, positive, negative, neutral)
    for _, entry in pairs(positivePerks) do
        table.insert(perks, entry)
    end

    local negativePerks = self:pickUniquePerks(negative, numNegativePerks, positive, negative, neutral)
    for _, entry in pairs(negativePerks) do
        table.insert(perks, entry)
    end

    local neutralPerks = self:pickUniquePerks(neutral, numNeutralPerks, positive, negative, neutral)
    for _, entry in pairs(neutralPerks) do
        table.insert(perks, entry)
    end

    captain:setPerks(perks)

    -- set level and experience
    captain.level = level_in or self:getLevelFromTier(self.random, captain.tier)
    captain.experience = 0
    CaptainUtility.setRequiredLevelUpExperience(captain)

    -- calculate salary from tier, classes and perks
    captain.salary = self:calculateSalary(captain)

    return captain
end

function CaptainGenerator:checkParametersFaulty(tier_in, level_in, primaryClass_in, secondaryClass_in)
    if not primaryClass_in and secondaryClass_in then
        eprint("Captain Generator: trying to set secondary but no primary class!")
        return true
    end

    if primaryClass_in and secondaryClass_in then
        if primaryClass_in == secondaryClass_in then
            eprint("Captain Generator: can't set secondary class to same as primary class!")
            return true
        end
    end

    if not self:classParameterValid(primaryClass_in) then
        eprint("Captain Generator: ".. primaryClass_in .." is not a valid class!")
        return true
    end

    if not self:classParameterValid(secondaryClass_in) then
        eprint("Captain Generator: ".. secondaryClass_in .." is not a valid class!")
        return true
    end

    if tier_in and (tier_in < 0 or tier_in > 3) then
        eprint("Captain Generator: tier must be within 0 to 3!")
        return true
    end

    if level_in and (level_in < 0 or level_in > 5) then
        eprint("Captain Generator: level must be within 0 to 5!")
        return true
    end

    return false
end

function CaptainGenerator:classParameterValid(class)
    if not class or (class == CaptainUtility.ClassType.None) then
        return true
    end

    local found = false
    for _, classType in pairs(CaptainUtility.ClassType) do
        if classType == class then
            found = true
            break
        end
    end

    return found
end

function CaptainGenerator:determineCaptainClasses(rand, tier, primaryClass)
    local primary = 0
    local secondary = 0

    if tier > 0 then
        local classes = {}
        for _, class in pairs(CaptainUtility.ClassType) do
            classes[class] = 1
        end

        classes[CaptainUtility.ClassType.None] = nil

        primary = primaryClass or selectByWeight(rand, classes)
        classes[primary] = nil

        if tier == 3 then
            secondary = selectByWeight(rand, classes)
        end

        return primary, secondary
    end
end

function CaptainGenerator:getPossiblePerks()
    -- positive
    local positive =
    {
        CaptainUtility.PerkType.Educated,
        CaptainUtility.PerkType.Humble,
        CaptainUtility.PerkType.Connected,
        CaptainUtility.PerkType.Navigator,
        CaptainUtility.PerkType.Stealthy,
        CaptainUtility.PerkType.MarketExpert,
        CaptainUtility.PerkType.Intimidating,
        CaptainUtility.PerkType.Lucky,
    }

    -- negative
    local negative =
    {
        CaptainUtility.PerkType.Uneducated,
        CaptainUtility.PerkType.Greedy,
        CaptainUtility.PerkType.Disoriented,
        CaptainUtility.PerkType.Gambler,
        CaptainUtility.PerkType.Addict,
        CaptainUtility.PerkType.Arrogant,
        CaptainUtility.PerkType.Unlucky,
    }

    -- neutral
    local neutral =
    {
        CaptainUtility.PerkType.Reckless,
        CaptainUtility.PerkType.Careful,
        CaptainUtility.PerkType.Cunning,
        CaptainUtility.PerkType.Harmless,
        CaptainUtility.PerkType.Noble,
        CaptainUtility.PerkType.Commoner,
    }

    return positive, negative, neutral
end

function CaptainGenerator:getImpossiblePerksOfClass(class)
    local positive = {}
    local negative = {}
    local neutral = {}

    if class == CaptainUtility.ClassType.Commodore then
        table.insert(neutral, CaptainUtility.PerkType.Careful)

    elseif class == CaptainUtility.ClassType.Smuggler then
        table.insert(neutral, CaptainUtility.PerkType.Noble)
        table.insert(negative, CaptainUtility.PerkType.Unlucky)

    elseif class == CaptainUtility.ClassType.Merchant then
        table.insert(neutral, CaptainUtility.PerkType.Noble)

    elseif class == CaptainUtility.ClassType.Miner then
        table.insert(neutral, CaptainUtility.PerkType.Noble)

    elseif class == CaptainUtility.ClassType.Scavenger then
        table.insert(neutral, CaptainUtility.PerkType.Noble)

    elseif class == CaptainUtility.ClassType.Explorer then
        table.insert(negative, CaptainUtility.PerkType.Disoriented)

    elseif class == CaptainUtility.ClassType.Daredevil then
        table.insert(negative, CaptainUtility.PerkType.Arrogant)
        table.insert(neutral, CaptainUtility.PerkType.Careful)

    elseif class == CaptainUtility.ClassType.Scientist then
        table.insert(negative, CaptainUtility.PerkType.Uneducated)

    elseif class == CaptainUtility.ClassType.Hunter then
        table.insert(neutral, CaptainUtility.PerkType.Harmless)

    end

    return positive, negative, neutral
end

function CaptainGenerator:getNumPerksFromTier(rand, tier)
    local numPositivePerks, numNegativePerks, numNeutralPerks = 0

    if tier == 0 then
        numNegativePerks = rand:getInt(0, 2)
        if numNegativePerks >= 1 then
            numPositivePerks = numNegativePerks
            numNeutralPerks = 0
        else
            numPositivePerks = rand:getInt(0, 1)
            numNeutralPerks = rand:getInt(1, 2)
        end

    elseif tier == 1 then
        numPositivePerks = rand:getInt(1, 2)
        numNegativePerks = rand:getInt(0, 1)
        numNeutralPerks = rand:getInt(1, 2)

    elseif tier == 2 then
        numPositivePerks = rand:getInt(2, 3)
        numNegativePerks = 0
        numNeutralPerks = rand:getInt(0, 2)

    else
        numPositivePerks = rand:getInt(2, 4)
        numNegativePerks = 0
        numNeutralPerks = rand:getInt(1, 2)
    end

    return numPositivePerks, numNegativePerks, numNeutralPerks
end

function CaptainGenerator:calculateSalary(captain)
    -- base values
    local baseSalary = 15000
    local classFactor = 10000
    local negativePerkFactor = 2000
    local positivePerkFactor = 2500
    local levelFactor = lerp(captain.level, 0, 5, 1, 2)

    -- count classes
    local numClasses = 0
    if captain.primaryClass ~= 0 then
        numClasses = numClasses + 1
    end

    if captain.secondaryClass ~= 0 then
        numClasses = numClasses + 1
    end

    -- count perks
    local numPositivePerks, numNegativePerks = self:getNumCaptainPerks(captain)

    -- calculate salary
    local salary = baseSalary

    -- add class influence
    salary = salary + (classFactor * numClasses)

    -- negative perk influence
    salary = salary - (negativePerkFactor * numNegativePerks)

    -- positive perk influence
    salary = salary + (positivePerkFactor * numPositivePerks)

    -- level influence
    salary = salary * levelFactor

    -- perks humble and greedy influence salary
    if captain:hasPerk(CaptainUtility.PerkType.Humble) then
        salary = salary * 0.9
    elseif captain:hasPerk(CaptainUtility.PerkType.Greedy) then
        salary = salary * 1.1
    end

    return round(salary / 100) * 100
end

local function convertTableToSet(source)
    local result = {}
    for _, item in pairs(source) do
        result[item] = true
    end

    return result
end

function CaptainGenerator:getNumCaptainPerks(captain)
    local numPositivePerks = 0
    local numNegativePerks = 0
    local numNeutralPerks = 0

    local positive, negative, neutral = self:getPossiblePerks()
    positiveSet = convertTableToSet(positive)
    negativeSet = convertTableToSet(negative)
    neutralSet = convertTableToSet(neutral)

    local perks = {captain:getPerks()}
    for _, perk in pairs(perks) do
        if positiveSet[perk] then
            numPositivePerks = numPositivePerks + 1
        end

        if negativeSet[perk] then
            numNegativePerks = numNegativePerks + 1
        end

        if neutralSet[perk] then
            numNeutralPerks = numNeutralPerks + 1
        end
    end

    return numPositivePerks, numNegativePerks, numNeutralPerks
end

function CaptainGenerator:pickUniquePerks(source, numEntries, positive, negative, neutral)
    local result = {}
    for i = 1, numEntries do
        local entry = randomEntry(self.random, source)
        table.insert(result, entry)

        -- remove taken perk so that it can't be used twice
        removeItemsFromTable(source, {entry})

        -- remove perk and opposing perks from other tables
        local opposites = opposingPerks[entry] or {}

        for _, opposite in pairs(opposites) do
            removeItemsFromTable(positive, {opposite, entry})
            removeItemsFromTable(negative, {opposite, entry})
            removeItemsFromTable(neutral, {opposite, entry})
        end
    end

    return result
end

-- vanilla generator will only produce captains of max level 2
function CaptainGenerator:getLevelFromTier(rand, tier)
    if tier == 0 or tier == 1 then
        return 0
    elseif tier == 2 then
        return rand:getInt(0, 1)
    else
        return rand:getInt(1, 2)
    end
end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
