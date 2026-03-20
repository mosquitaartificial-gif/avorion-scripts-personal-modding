
-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace WreckageCleanUp
WreckageCleanUp = {}

local maxWreckages = 150

function WreckageCleanUp.getUpdateInterval()
    return 15
end

function WreckageCleanUp.updateServer()

    local wreckages = {}
    local numWreckages = 0

    for _, wreckage in pairs({Sector():getEntitiesByType(EntityType.Wreckage)}) do
        local timer = DeletionTimer(wreckage)

        if valid(timer) and timer.enabled then
            table.insert(wreckages, {wreckage = wreckage, timeLeft = timer.timeLeft})
            numWreckages = numWreckages + 1
        end
    end

    if numWreckages > maxWreckages then
        table.sort(wreckages, function(a, b) return a.timeLeft < b.timeLeft end)

        local sector = Sector()
        local toRemove = numWreckages - maxWreckages
        for i = 1, toRemove do
            sector:deleteEntity(wreckages[i].wreckage)
        end
    end
end
