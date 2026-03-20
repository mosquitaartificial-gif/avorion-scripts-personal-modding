local EventUT = {}

function EventUT.attackEventAllowed()
    local sector = Sector()

    if sector:getValue("neutral_zone") then
        -- print ("No attack events in neutral zones.")
        return false
    end

    local players = {sector:getPlayers()}
    if #players == 0 then
        -- print ("No attack events in sectors without players")
        return false
    end

    local x, y = sector:getCoordinates()
    for _, player in pairs(players) do
        local hx, hy = player:getHomeSectorCoordinates()
        if hx == x and hy == y and player.playtime < 30 * 60 then
            -- print ("Player's playtime is below 30 minutes (%is), cancelling pirate attack.", player.playtime)
            return false
        end
    end

    if sector:getEntitiesByScriptValue("no_attack_events") then
        -- print ("an entity prevented an attack")
        return false
    end

    return true
end

function EventUT.persecutorEventAllowed()
    local sector = Sector()
    local x, y = sector:getCoordinates()

    if sector:getValue("neutral_zone") then
        -- print ("No attack events in neutral zones.")
        return false
    end

    if sector:getEntitiesByScriptValue("no_attack_events") then
        -- print ("an entity prevented an attack")
        return false
    end

    return true
end

function EventUT.getHeadhunterFaction(x, y)
    local name = "The Galactic Bounty Hunters Guild"%_T

    local galaxy = Galaxy()
    local faction = galaxy:findFaction(name)
    if faction == nil then
        faction = galaxy:createFaction(name, 0, 0)
        faction.initialRelations = 0
        faction.initialRelationsToPlayer = 0
        faction.staticRelationsToPlayers = true

        SetFactionTrait(faction, "aggressive"%_T, "peaceful"%_T, 0.6)
        SetFactionTrait(faction, "careful"%_T, "brave"%_T, 0.75)
        SetFactionTrait(faction, "greedy"%_T, "generous"%_T, 0.75)
        SetFactionTrait(faction, "opportunistic"%_T, "honorable"%_T, 1.0)
    end

    faction.initialRelationsToPlayer = 0
    faction.staticRelationsToPlayers = true
    faction.homeSectorUnknown = true

    -- set home sector to wherever it's needed to avoid head hunters being completely over the top
    faction:setHomeSectorCoordinates(x, y)

    return faction
end

return EventUT
