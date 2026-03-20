package.path = package.path .. ";data/scripts/lib/?.lua"

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace ProtectionEnvironment
ProtectionEnvironment = {}

local activationRadius2 = 500 * 500

function ProtectionEnvironment.getUpdateInterval()
    return 1
end

function ProtectionEnvironment.initialize()
end

function ProtectionEnvironment.updateServer()
    local sector = Sector()

    -- gather all factions that can be protected
    local factions = {}
    for _, factionIndex in pairs({sector:getPresentFactions()}) do
        local faction = Faction(factionIndex)
        if faction and (faction.isPlayer or faction.isAlliance) then
            table.insert(factions, factionIndex)
        end
    end

    -- gather all crafts from these factions
    local candidates = {}
    for _, factionIndex in pairs(factions) do
        for _, craft in pairs({sector:getEntitiesByFaction(factionIndex)}) do
            candidates[craft.id.string] = craft
        end
    end

    -- check which crafts are protected
    for _, platform in pairs({sector:getEntitiesByScript("protectionplatform.lua")}) do
        local position = platform.translationf

        for id, craft in pairs(candidates) do
            if distance2(position, craft.translationf) <= activationRadius2 then
                -- this craft is protected
                craft:setValue("protected_from_environment", true)
                candidates[id] = nil
            end
        end
    end

    -- the remaining crafts are not protected
    for id, craft in pairs(candidates) do
        craft:setValue("protected_from_environment", nil)
    end
end

function ProtectionEnvironment.updateClient()
    local player = Player()
    local craft = player.craft
    if not craft then return end

    if craft:getValue("protected_from_environment") then
        addSectorProblem("ProtectionPlatform", "The ship is protected from environmental effects here."%_t, "data/textures/icons/protection-bubble.png", ColorRGB(0.1, 0.5, 0.9))
    else
        removeSectorProblem("ProtectionPlatform")
    end
end
