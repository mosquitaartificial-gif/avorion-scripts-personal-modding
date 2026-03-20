
FactionEradicationUtility = {}

function FactionEradicationUtility.setFactionEradicated(faction)
    local eradicatedFactions = getGlobal("eradicated_factions") or {}
    if eradicatedFactions[faction.index] then
        printlog("faction " .. faction.name .. " is already eradicated")
        return
    end

    printlog("set faction " .. faction.name .. " eradicated")

    eradicatedFactions[faction.index] = true
    setGlobal("eradicated_factions", eradicatedFactions)

    -- send chat message
    local server = Server()
    server:broadcastChatMessage("", ChatMessageType.Information, "Faction '%1%' was completely eradicated from the galaxy."%_T, faction.baseName)
end

function FactionEradicationUtility.isFactionEradicated(factionIndex)
    local eradicatedFactions = getGlobal("eradicated_factions") or {}
    return eradicatedFactions[factionIndex]
end

return FactionEradicationUtility
