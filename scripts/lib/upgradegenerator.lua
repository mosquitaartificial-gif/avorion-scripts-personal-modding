
package.path = package.path .. ";data/scripts/systems/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("galaxy")
include ("randomext")
include ("utility")
local BMUpgradeGenerator = include ("internal/dlc/blackmarket/public/upgradegenerator")
local ITRUpgradeGenerator = include ("internal/dlc/rift/public/upgradegenerator")

local rand = nil

local scripts = {}

local function add(script, weight, distToCenter)
    local dist2ToCenter = nil
    if distToCenter then
        dist2ToCenter = distToCenter * distToCenter
    end
    scripts[script] = {weight = weight, dist2ToCenter = dist2ToCenter}
end

-- turrets and fighter
add("data/scripts/systems/arbitrarytcs.lua", 2.5)
add("data/scripts/systems/militarytcs.lua", 2)
add("data/scripts/systems/civiltcs.lua", 2)
add("data/scripts/systems/autotcs.lua", 2)
add("data/scripts/systems/fightersquadsystem.lua", 1, 310)

-- simple boosters
add("data/scripts/systems/batterybooster.lua", 1)
add("data/scripts/systems/cargoextension.lua", 1)
add("data/scripts/systems/energybooster.lua", 1)
add("data/scripts/systems/enginebooster.lua", 1)
add("data/scripts/systems/hyperspacebooster.lua", 1)
add("data/scripts/systems/radarbooster.lua", 1)
add("data/scripts/systems/shieldbooster.lua", 1, 380)
add("data/scripts/systems/lootrangebooster.lua", 1)
add("data/scripts/systems/scannerbooster.lua", 1)

-- special upgrades
add("data/scripts/systems/miningsystem.lua", 1)
add("data/scripts/systems/tradingoverview.lua", 1)
add("data/scripts/systems/valuablesdetector.lua", 1)
add("data/scripts/systems/shieldimpenetrator.lua", 1, 380)
add("data/scripts/systems/energytoshieldconverter.lua", 1, 380)
add("data/scripts/systems/transportersoftware.lua", 1, 235)
add("data/scripts/systems/velocitybypass.lua", 0.5)
add("data/scripts/systems/weaknesssystem.lua", 0.5)
add("data/scripts/systems/resistancesystem.lua", 0.5, 380)
add("data/scripts/systems/defensesystem.lua", 0.5, 310)
add("data/scripts/systems/excessvolumebooster.lua", 0.25, 75)

local UpgradeGenerator = {}
UpgradeGenerator.__index = UpgradeGenerator

local function new(seed)
    local obj = setmetatable({}, UpgradeGenerator)
    obj:initialize(seed)
    return obj
end

function UpgradeGenerator:initialize(seed)

    self.scripts = table.deepcopy(scripts)

    self.seed = seed or random():createSeed()
    if type(self.seed) == "number" or type(self.seed) == "string" then
        self.seed = Seed(self.seed)
    end

    self.random = Random(self.seed)
    self.minRarity = nil -- set to override the minimum possible rarity
    self.maxRarity = nil -- set to override the maximum possible rarity
end

function UpgradeGenerator:getDefaultRarityDistribution()
    local rarities = {}

    rarities[-1] = 24 -- petty
    rarities[0] = 48 -- common
    rarities[1] = 16 -- uncommon
    rarities[2] = 8 -- rare
    rarities[3] = 4 -- exceptional
    rarities[4] = 1 -- exotic
    rarities[5] = 0.1 -- legendary

    local difficulty = GameSettings().difficulty
    if difficulty >= 0 then
        rarities[5] = rarities[5] + (difficulty + 1) * 0.05 -- legendary: 0.15 at Veteran, 0.3 at Insane
        rarities[4] = rarities[4] + (difficulty + 1) * 0.5 -- exotic: 1.5 at Veteran, 3 at Insane
        rarities[3] = rarities[3] + (difficulty + 1) * 1 -- exceptional: 5 at Veteran, 8 at Insane
        rarities[2] = rarities[2] + (difficulty + 1) * 2 -- rare: 10 at Veteran, 16 at Insane
    end

    return rarities
end

function UpgradeGenerator:getSectorRarityDistribution(x, y)
    local rarities = self:getDefaultRarityDistribution()

    local f = length(vec2(x, y)) / (Balancing_GetDimensions() / 2) -- 0 (center) to 1 (edge) to ~1.5 (corner)

    -- we need to adjust drop rates for higher-tier upgrades in the outer regions since they don't have a tech level
    rarities[-1] = 4 + f * 20 -- 24 at edge, 4 in center
    rarities[0] = 4 + f * 44 -- 48 at edge, 4 in center
    rarities[1] = 8 + f * 8 -- 16 at edge, 8 in center

    rarities[3] = lerp(f, 0.3, 1.0, rarities[3], rarities[3] * 0.75)
    rarities[4] = lerp(f, 0.3, 1.0, rarities[4], rarities[4] * 0.5)
    rarities[5] = lerp(f, 0.3, 1.0, rarities[5], rarities[5] * 0.25)

    return rarities
end

function UpgradeGenerator:getBossLootRarityDistribution()
    local rarities = {}
    rarities[-1] = 0 -- petty
    rarities[0] = 0 -- common
    rarities[1] = 0 -- uncommon
    rarities[2] = 10 -- rare
    rarities[3] = 15 -- exceptional
    rarities[4] = 5 -- exotic
    rarities[5] = 1 -- legendary

    local difficulty = GameSettings().difficulty
    if difficulty == Difficulty.Veteran then
        rarities[3] = 15 -- exceptional
        rarities[2] = 5 -- rare
    elseif difficulty == Difficulty.Expert then
        rarities[3] = 10 -- exceptional
        rarities[2] = 3.3 -- rare
    elseif difficulty == Difficulty.Hardcore then
        rarities[3] = 6 -- exceptional
        rarities[2] = 2 -- rare
    elseif difficulty == Difficulty.Insane then
        rarities[3] = 5 -- exceptional
        rarities[2] = 0 -- rare
    end

    return rarities
end

function UpgradeGenerator:getSectorBossLootRarityDistribution(x, y)
    local rarities = self:getBossLootRarityDistribution()
    local d = length(vec2(x, y))

    rarities[4] = lerp(d, 450, 0, rarities[4], rarities[4] * 0.5) -- exotic: full at the edge, ca 2.5 at 0.0
    rarities[3] = lerp(d, 450, 0, rarities[3], rarities[3] * 0.25) -- exceptional: full at the edge, ca (1 - 3.5, depending on difficulty) at 0.0
    rarities[2] = lerp(d, 450, 150, rarities[2], rarities[2] * 0.0) -- rare: full at the edge, nothing inside barrier

    return rarities
end

function UpgradeGenerator:selectScript(x, y)

    -- we must sort the script selection first since a table with strings as keys is not deterministically sorted
    local all = {}
    local x = x or 0
    local y = y or 0
    local sectorDist2ToCenter = x * x + y * y

    for script, parameters in pairs(self.scripts) do
        local dist2ToCenter = 0
        dist2ToCenter = parameters.dist2ToCenter
        -- remove all scripts for subsystems that can not drop in this distance from center
        if not parameters.dist2ToCenter or sectorDist2ToCenter <= parameters.dist2ToCenter then
            table.insert(all, {script = script, weight = parameters.weight})
        end
    end

    if self.blackMarketUpgradesEnabled then
        BMUpgradeGenerator.addUpgrades(all)
    end

    if self.intoTheRiftUpgradesEnabled then
        ITRUpgradeGenerator.addUpgrades(all)
    end

    table.sort(all, function(a, b) return a.script < b.script end)

    local weights = {}
    for _, p in pairs(all) do
        table.insert(weights, p.weight)
    end

    local index = getValueFromDistribution(weights, self.random)
    local script = all[index].script

    return script
end

function UpgradeGenerator:getUpgradeSeed(x, y, script, rarity)

    -- reduce randomness:
    -- for every 15x15 quadrant, every upgrade type and every rarity, create a server-dependent selection of 5 seeds
    -- add an offset of 7 so the 0:0 quadrant is centered around 0:0
    local qx = math.floor(x + 7 / 15)
    local qy = math.floor(y + 7 / 15)

    if rarity.type >= RarityType.Exotic and self.random:test(0.5) then
        return self.random:createSeed(), qx, qy
    end

    local maxVariations = self.maxVariations or 4
    local seedString = tostring(GameSeed().int32) .. tostring(qx) .. tostring(qy) .. tostring(script) .. tostring(rarity.type) .. tostring(self.random:getInt(1, maxVariations))

    return Seed(seedString), qx, qy
end

function UpgradeGenerator:generateSectorSystem(x, y, rarity_in, rarities_in)
    local rarity = nil

    if rarities_in then
        rarity = getValueFromDistribution(rarities_in, self.random)
    else
        rarity = rarity_in or getValueFromDistribution(self:getSectorRarityDistribution(x, y), self.random)
    end

    if type(rarity) == "number" then rarity = Rarity(rarity) end

    if self.minRarity then
        if rarity < self.minRarity then rarity = self.minRarity end
    end
    if self.maxRarity then
        if rarity > self.maxRarity then rarity = self.maxRarity end
    end

    local script = self:selectScript(x, y)
    local seed = self:getUpgradeSeed(x, y, script, rarity)

    return SystemUpgradeTemplate(script, rarity, seed)
end

function UpgradeGenerator:generateSystem(rarity, rarities_in)

    if rarity == nil then
        local rarities = rarities_in or self:getDefaultRarityDistribution()
        rarity = getValueFromDistribution(rarities, self.random)
        if type(rarity) == "number" then rarity = Rarity(rarity) end
    end

    if self.minRarity then
        if rarity < self.minRarity then rarity = self.minRarity end
    end
    if self.maxRarity then
        if rarity > self.maxRarity then rarity = self.maxRarity end
    end

    local script = self:selectScript()
    local seed = self.random:createSeed()

    return SystemUpgradeTemplate(script, rarity, seed)
end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
