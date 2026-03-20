package.path = package.path .. ";data/scripts/lib/?.lua"

include ("weapontype")
include ("inventoryitemprice")
local SectorTurretGenerator = include ("sectorturretgenerator")


local bars = {}
local mediumLabel = nil
local maxLabel = nil

local sortedWeaponTypes = {}
for name, type in pairs(WeaponType) do
    sortedWeaponTypes[#sortedWeaponTypes + 1] = {type = type, name = name}
end

table.sort(sortedWeaponTypes, function(a, b) return a.type < b.type end)


function BuildTurretAnalysisUI(tab)
    if true then return end

    local size = tab.size

    -- horizontal lines
    local hsplit = UIHorizontalSplitter(Rect(size), 10, 0, 1)
    hsplit.bottomSize = 40

    local hsplit2 = UIHorizontalSplitter(hsplit.top, 10, 0, 0.5)
    tab:createLine(hsplit2.top.topLeft, hsplit2.top.topRight)
    tab:createLine(hsplit2.bottom.topLeft, hsplit2.bottom.topRight)

    captionLabel = tab:createLabel(hsplit2.top.topLeft - vec2(0, 0), "blah" , 12)
    maxLabel = tab:createLabel(hsplit2.top.topRight - vec2(230, 0), "blah" , 12)
    mediumLabel = tab:createLabel(hsplit2.bottom.topRight - vec2(230, 0), "blah" , 12)

    local hlist = UIHorizontalLister(Rect(size), 10, 0)

    for _, typePair in pairs(sortedWeaponTypes) do

        local hsplit = UIHorizontalSplitter(hlist:nextRect(40), 10, 0, 1)
        hsplit.bottomSize = 40

        local name = typePair.name
        local type = typePair.type

        local bar = {}
        bars[type] = bar

        local turret = SectorTurretGenerator():generate(0, 150, 0, Rarity(), type)

        bar.weaponType = type

        bar.button = tab:createButton(hsplit.bottom, "", "")
        bar.button.icon = turret.weaponIcon
        bar.button.tooltip = name

        local color = ColorRGB(0.5, 0.5, 0.8)
        bar.rect = tab:createRect(hsplit.top, color)

        bar.highest = bar.rect.lower.y
        bar.lowest = bar.rect.upper.y

        bar.setValue = function(self, value)
            local lower = self.rect.lower
            lower.y = lerp(value, 0, 1, self.lowest, self.highest)
            self.rect.lower = lower
        end

        local rect = hsplit.top
        rect.size = rect.size * vec2(0.3, 1.0)

        bar.deviation = tab:createRect(rect, ColorRGB(0.5, 0.5, 0.5))

        bar.setDeviation = function(self, value)
            local dlower = self.deviation.lower
            local dupper = self.deviation.upper

            local blower = self.rect.lower

            local d = lerp(value, 0, 1, 0, self.lowest - self.highest)

            dlower.y = blower.y - d / 2
            dupper.y = blower.y + d / 2

            self.deviation.lower = dlower
            self.deviation.upper = dupper
        end

    end

    local data = calculateData()

    RefreshBars(data)
end


function calculateData()
    local data = {
        values = {},
        deviations = {},
        labels = {},
        colors = {},
        maximum = 20 * 1000 * 1000,
        caption = ""
    }

    data.maximum = 5 * 1000 * 1000
    local distance = 0

--    data.maximum = 3 * 1000 * 1000
--    local distance = 75

--    data.maximum = 2 * 1000 * 1000
--    local distance = 150

--    data.maximum = 1 * 1000 * 1000
--    local distance = 250

--    data.maximum = 500 * 1000
--    local distance = 350

--    data.maximum = 250 * 1000
--    local distance = 400

--    data.maximum = 150 * 1000
--    local distance = 450

--    local rarityType = RarityType.Legendary
    local rarityType = RarityType.Exotic
--    local rarityType = RarityType.Exceptional
--    local rarityType = RarityType.Rare
--    local rarityType = RarityType.Uncommon
--    local rarityType = RarityType.Common
--    local rarityType = RarityType.Petty
    local numSamples = 200


    data.caption = tostring(distance)

    local generator = SectorTurretGenerator()
    generator.maxVariations = 1000

    local totalAverage = 0
    local probabilities = Balancing_GetWeaponProbability(0, distance)

    for name, type in pairs(WeaponType) do

        local samples = {}

        for i = 1, numSamples do
            local turret = generator:generate(0, distance, 0, Rarity(rarityType), type)
            samples[i] = ArmedObjectPrice(turret) * 0.25
        end

        -- sum, average
        local sum = 0
        for _, value in pairs(samples) do
            if value == 0 then
                print ("ERROR: 0 price for " .. name)
            end

            sum = sum + value
        end

        if (probabilities[type] or 0) == 0 then sum = 0 end

        totalAverage = totalAverage + sum * (probabilities[type] or 0)

        local average = sum / #samples

        -- standard deviation
        local variance = 0
        for _, value in pairs(samples) do
            local diff = value - average
            variance = variance + (diff * diff)
        end

        if (probabilities[type] or 0) == 0 then variance = 0 end

        variance = variance / #samples
        local deviation = math.sqrt(variance)

        -- set all values
        data.values[type] = average
        data.deviations[type] = deviation
        data.labels[type] = "¢" .. createMonetaryString(average).. "\n" .. name
        data.colors[type] = Rarity(rarityType).color
    end

    totalAverage = totalAverage / (numSamples * 19)
    -- print ("total: " .. createMonetaryString(totalAverage))

    return data
end


function RefreshBars(data)

    for _, bar in pairs(bars) do
        bar:setValue(0.001)
    end

    if not data then return end

    local minimum = 0
    local maximum = 0

    if data.maximum then
        maximum = data.maximum
    else
        for type, value in pairs(data.values or {}) do
            if value > maximum then maximum = value end
        end
    end

    captionLabel.caption = data.caption or ""
    maxLabel.caption = "¢" .. createMonetaryString(maximum)
    mediumLabel.caption = "¢" .. createMonetaryString(maximum * 0.5)

    for type, value in pairs(data.values or {}) do
        local interpolated = lerp(value, minimum, maximum, 0.001, 1)

        local bar = bars[type]
        bar:setValue(interpolated)
        bar.rect.tooltip = tostring(value)
    end

    for type, value in pairs(data.deviations or {}) do
        local interpolated = lerp(value, minimum, maximum, 0.001, 1)

        local bar = bars[type]
        bar:setDeviation(interpolated)
    end

    for type, text in pairs(data.labels or {}) do
        local bar = bars[type]
        bar.rect.tooltip = text
    end

    for type, color in pairs(data.colors or {}) do
        local bar = bars[type]
        bar.rect.color = color or ColorRGB(0.5, 0.5, 0.8)
    end

end
