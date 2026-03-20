
package.path = package.path .. ";data/scripts/lib/?.lua"
local FactionEradicationUtility = include("factioneradicationutility")
local SpawnUtility = include("spawnutility")
local SectorGenerator = include("SectorGenerator")
local ShipGenerator = include("shipgenerator")
local SectorSpecifics = include("sectorspecifics")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace RespawnDefenders
RespawnDefenders = {}


local defenderFactionIndex
local numDefenders
local specialHandling
local missingLastTick
local updateTimer

function RespawnDefenders.secure()
    return
    {
        defenderFactionIndex = defenderFactionIndex,
        numDefenders = numDefenders,
        specialHandling = specialHandling,
        missingLastTick = missingLastTick,
        updateTimer = updateTimer,
    }
end

function RespawnDefenders.restore(data)
    defenderFactionIndex = data.defenderFactionIndex
    numDefenders = data.numDefenders
    specialHandling = data.specialHandling
    missingLastTick = data.missingLastTick
    updateTimer = data.updateTimer
end



function RespawnDefenders.getUpdateInterval()
    return 60
end

function RespawnDefenders.onRestoredFromDisk(time)
    RespawnDefenders.updateServer(time)
end



function RespawnDefenders.initialize()
    if onServer() then
        Sector():registerCallback("onRestoredFromDisk", "onRestoredFromDisk")
    end
end

function RespawnDefenders.setDefenders(factionIndex, amount, special)
    -- get the faction and amount of defenders from outside of this script
    defenderFactionIndex = factionIndex or 0
    numDefenders = amount or 0
    specialHandling = special

--    print("set defenders: faction " .. defenderFactionIndex .. ", numDefenders: " .. numDefenders)
end

function RespawnDefenders.calculateSectorDefenders()
    -- get the faction and amount of defenders from the sector's generation script
    local x, y = Sector():getCoordinates()
    local specs = SectorSpecifics(x, y, GameSeed())
--    print("template: " .. tostring(specs.generationTemplate))

    local defenderFactionIndex, numDefenders, special
    if specs.generationTemplate then
        local contents = specs.generationTemplate.contents(x, y)

        if specs.generationTemplate.getDefenders then
            defenderFactionIndex, numDefenders, special = specs.generationTemplate.getDefenders(contents, specs.generationSeed, x, y)
        end
    end

    RespawnDefenders.setDefenders(defenderFactionIndex, numDefenders, special)


--    print("calculate sector [" .. x .. ";" .. y .. "] defenders: faction " .. tostring(defenderFactionIndex) .. ", numDefenders: " .. tostring(numDefenders))
end

function RespawnDefenders.hasStations(defenderFactionIndex)
    local stations = {Sector():getEntitiesByType(EntityType.Station)}

    for _, station in pairs(stations) do
        if station.factionIndex == defenderFactionIndex then
            return true
        end
    end

    return false
end

function RespawnDefenders.updateServer(timeStep)
    if numDefenders == 0 then return end
    if defenderFactionIndex == 0 then return end

    -- actually tick once every 15 minutes
    local updateInterval = 15 * 60

    updateTimer = (updateTimer or 0) + timeStep
    if updateTimer < updateInterval then return end
    updateTimer = updateTimer - updateInterval

    local sector = Sector()
    if not sector then return end

    -- initialize values?
    if numDefenders == nil or defenderFactionIndex == nil then
        RespawnDefenders.calculateSectorDefenders()

        if numDefenders == 0 then return end
        if defenderFactionIndex == 0 then return end
    end

    if FactionEradicationUtility.isFactionEradicated(defenderFactionIndex) then
        return
    end

    -- no respawning of defenders when there are no stations left
    if not RespawnDefenders.hasStations(defenderFactionIndex) then
        return
    end

    -- count current defenders
    local numCurrentDefenders = 0
    for _, defender in pairs({sector:getEntitiesByScriptValue("is_defender", true)}) do
        if defender.factionIndex == defenderFactionIndex then
            numCurrentDefenders = numCurrentDefenders + 1
        end
    end

    if updateTimer >= updateInterval then
        -- the last update was at least 2 * updateInterval ago
        -- respawn defenders right away
        updateTimer = 0
        missingLastTick = math.max(missingLastTick or 0, numDefenders - numCurrentDefenders)
    end

    local faction
    local respawnAmount = 0
    if missingLastTick and missingLastTick > 0 then
        faction = Faction(defenderFactionIndex)
        if not faction then
--            print("faction doesn't exist")
            return
        end

        respawnAmount =  missingLastTick
    end

    if respawnAmount > 0 then
        -- respawn defenders
        local ships = {}

--        print("generate " .. respawnAmount .. " defenders")
        local generator = SectorGenerator(sector:getCoordinates())

        for i = 1, respawnAmount do
            local ship = ShipGenerator.createDefender(faction, generator:getPositionInSector())
            table.insert(ships, ship)

            if specialHandling == "noAntiSmuggle" then
--                print("no anti smuggle")
                ship:removeScript("antismuggle.lua")
            end
        end

        if specialHandling == "addEnemyBuffs" then
--            print("add enemy buffs")
            SpawnUtility.addEnemyBuffs(ships)
        end

        missingLastTick = nil
        return
    end

    missingLastTick = numDefenders - numCurrentDefenders

--    print("missing defenders: " .. tostring(missingLastTick))


    if missingLastTick <= 0 then missingLastTick = nil end
end
