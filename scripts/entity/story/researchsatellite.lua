package.path = package.path .. ";data/scripts/lib/?.lua"

include("utility")
include("stringutility")
Scientist = include("story/scientist")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace ResearchSatellite
ResearchSatellite = {}


function ResearchSatellite.interactionPossible()
    return true
end

function ResearchSatellite.initialize()
    if onServer() then
        Entity():registerCallback("onDestroyed", "onDestroyed")
        Entity():addScriptOnce("entity/utility/radiochatter.lua", {
            "Research Status: distributed research log available. Please interact for log access."%_t,
            "Research Status: new lightning weapons still show no effect at all against stone blocks."%_t,
            "Research Status: even thin stone platings can make a ship completely immune to our superior lightning weaponry."%_t,
            "Research Status: our new lightning weapons still have no effect on stone. Luckily, nobody builds their ships out of stone."%_t,
            }, 45, 65, 5)
    end

    if onClient() and InteractionText() then
        InteractionText().text = "Energy & Lightning overload research simulations running.\n\nCheck logs for further information on research."%_t
    end


end

function ResearchSatellite.initUI()
    local random = Random(Sector().seed)

    local logs = {true, true, true, true}

    local amount = random:getInt(2, 3)
    for i = 1, amount do
        local index = random:getInt(1, 4)

        if logs[index] then
            logs[index] = nil
        else
            i = i - 1
        end
    end

    if logs[1] then ScriptUI():registerInteraction("Log Entry A2Tg4xaS"%_t, "onLogs1") end
    if logs[2] then ScriptUI():registerInteraction("Log Entry BKjgy85n"%_t, "onLogs2") end
    if logs[3] then ScriptUI():registerInteraction("Log Entry CAPne8xy"%_t, "onLogs3") end
    if logs[4] then ScriptUI():registerInteraction("Log Entry DP710sma"%_t, "onLogs4") end

end

function ResearchSatellite.onLogs1()
    ScriptUI():showDialog({text = "Distributed M.A.D. Log, Entry #A2Tg4xaS\nSimulation #59123.\n\nMassive power improvements over the last simulations. Still no reliable way to penetrate stone.\n\nMaybe shifting the phase could get us a little closer?"%_t})
end

function ResearchSatellite.onLogs2()
    ScriptUI():showDialog({text = "Distributed M.A.D. Log, Entry #BKjgy85n\nSimulation #32.\n\nFirst test runs on overloaded lightning guns are looking very promising.\n\nWith these new modified lightning guns we'll be able to reach unimaginable amounts of power.\n\nA few issues remain, the biggest being that we haven't found a way to penetrate non-conductors such as stone yet."%_t})
end

function ResearchSatellite.onLogs3()
    ScriptUI():showDialog({text = "Distributed M.A.D. Log, Entry #CAPne8xy\nSimulation #5123.\n\nThe modified lightning guns can now penetrate every material except stone.\n\nThis could be a problem. But so far we haven't found a way to [DATA CORRUPTED]"%_t})
end

function ResearchSatellite.onLogs4()
    ScriptUI():showDialog({text = "Distributed M.A.D. Log, Entry #DP710sma\nSimulation #78612.\n\nThe stone issue seems to be a structural problem linked to the architecture of lightning guns, so we can't get rid of it.\n\nUnfortunately, lightning guns are the only weapons that we can boost as much without overloading them.\n\nWe'll have to accept this weakness, but it won't be an issue.\n\nWho would ever be dumb enough to build their ships out of stone anyway? Ha!"%_t})
end

function ResearchSatellite.onDestroyed(...)
    -- all players in the sector get a scientist spawn counter
    local spawn

    for _, player in pairs({Sector():getPlayers()}) do
        local value = player:getValue("scientist_spawn") or 0
        value = value + 1

        if value <= 2 then
            Sector():broadcastChatMessage("Satellite"%_t, ChatMessageType.Warning, "An encrypted message was broadcasted from the destroyed satellite."%_t)
        end

        if value == 3 then
            Sector():broadcastChatMessage("Satellite"%_t, ChatMessageType.Warning, "A message was broadcasted from the destroyed satellite. It appears to be some kind of emergency signal."%_t)
        end

        if value == 4 then
            spawn = true
            value = 0
        end

        player:setValue("scientist_spawn", value)
    end

    if spawn then
        -- if any of the players present doesn't have a scientist cooldown, even if he isn't the one that has the correct scientist_spawn value, the scientist can spawn
        local runtime = Server().unpausedRuntime

        for _, player in pairs ({Sector():getPlayers()}) do
            local lastKilled = player:getValue("last_killed_scientist")
            if not lastKilled or runtime - lastKilled >= 30 * 60 then
                Scientist.spawn()
                return
            end
        end
    end
end


