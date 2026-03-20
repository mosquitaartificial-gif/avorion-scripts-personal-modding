package.path = package.path .. ";data/scripts/lib/?.lua"
include ("galaxy")

local FighterUT = {}

function FighterUT.getMaxDurability(tech)
    local distance = Balancing_GetSectorByTechLevel(tech)

    local hp0 = 1200
    local hp90 = 1000
    local hp150 = 800
    local hp250 = 550
    local hp400 = 250
    local hp500 = 200

    local maxDurability = 200
    if distance < 90 then
        maxDurability = lerp(distance, 0, 90, hp0, hp90)
    elseif distance < 150 then
        maxDurability = lerp(distance, 90, 150, hp90, hp150)
    elseif distance < 250 then
        maxDurability = lerp(distance, 150, 250, hp150, hp250)
    elseif distance < 400 then
        maxDurability = lerp(distance, 250, 400, hp250, hp400)
    elseif distance < 500 then
        maxDurability = lerp(distance, 400, 500, hp400, hp500)
    else
        maxDurability = 200
    end

    return maxDurability
end

function FighterUT.getProductionTime(tech, material, durability)
    local duration = 300

    -- actual assembly time is balanced to be at max 60min, see Hangar.cpp for assembly
    local maxTechDuration = 1650 / (Material(MaterialType.Avorion).strengthFactor / material.strengthFactor)
    duration = duration + lerp(tech, 1, 52, 0, maxTechDuration)

    local lowest = FighterUT.getMaxDurability(0) * 0.2
    local highest = FighterUT.getMaxDurability(52) * math.pow(1.2, MaterialType.Avorion)
    duration = duration + lerp(durability, lowest, highest, 0, 1650)

    return duration
end

return FighterUT
