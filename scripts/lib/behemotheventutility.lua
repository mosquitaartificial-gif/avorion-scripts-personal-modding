package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")

local BehemothUT = {}


function BehemothUT.getQuadrantName(quadrant)
    if quadrant == 1 then
        return "North"%_t
    elseif quadrant == 2 then
        return "East"%_t
    elseif quadrant == 3 then
        return "South"%_t
    elseif quadrant == 4 then
        return "West"%_t
    end
end

return BehemothUT
