
if onServer() then

local alliance = Alliance()
alliance:addScriptOnce("data/scripts/player/background/simulation/simulation.lua")
alliance:addScriptOnce("data/scripts/player/background/simulation/shipappearances.lua")
alliance:addScriptOnce("data/scripts/player/background/lostships.lua")

if not alliance:getValue("gates2.0") then
    alliance:addScriptOnce("data/scripts/player/background/gatemapcompatibility.lua")
end

end
