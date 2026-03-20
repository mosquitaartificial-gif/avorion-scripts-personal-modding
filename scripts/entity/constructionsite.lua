package.path = package.path .. ";data/scripts/lib/?.lua"
include ("defaultscripts")
include ("stringutility")
include ("utility")
include ("callable")
local PlanGenerator = include ("plangenerator")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace ConstructionSite
ConstructionSite = {}

ConstructionSite.data = {}

if onServer() then

function ConstructionSite.secure()
    return ConstructionSite.data
end

function ConstructionSite.restore(data)
    ConstructionSite.data = data
end

function ConstructionSite.onRestoredFromDisk(time)
    ConstructionSite.updateServer(time)
end

function ConstructionSite.getUpdateInterval()
    return 60
end

function ConstructionSite.initialize(planSeed, volume, material, scripts)
    ConstructionSite.data = {
        planSeed = planSeed,
        volume = volume,
        material = material,
        scripts = scripts, -- expected format: {{script = "foo", args = {"bar"}}, [...]}
    }

    if onServer() then
        Sector():registerCallback("onRestoredFromDisk", "onRestoredFromDisk")
    end
end

function ConstructionSite.updateServer(timeStep)
    ConstructionSite.timePassed = (ConstructionSite.timePassed or 0) + timeStep

    if ConstructionSite.timePassed >= 30 * 60 then
        ConstructionSite.finalizeConstruction()
    end
end

function ConstructionSite.finalizeConstruction()
    local entity = Entity()
    local faction = Faction()

    local scriptPath = nil
    for _, script in pairs(ConstructionSite.data.scripts) do
        scriptPath = script.script
        break
    end

    local plan = PlanGenerator.makeStationPlan(faction, scriptPath,
                                               ConstructionSite.data.planSeed,
                                               ConstructionSite.data.volume,
                                               ConstructionSite.data.material)

    local position = entity.position
    local name = entity.name
    local durabilityRatio = entity.durability / entity.maxDurability
    entity:setPlan(BlockPlan()) -- entity will be deleted as a result of this

    -- create finished station
    local station = Sector():createStation(faction, plan, position)
    station.durability = station.maxDurability * durabilityRatio

    for i, script in pairs(ConstructionSite.data.scripts) do
        station:addScript(script.script, unpack(script.args or {}))
    end

    AddDefaultStationScripts(station)
    SetBoardingDefenseLevel(station)

    station.crew = station.idealCrew

    Physics(station).driftDecrease = 0.2
end

end
