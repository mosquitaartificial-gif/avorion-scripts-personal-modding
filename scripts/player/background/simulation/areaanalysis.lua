
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/player/background/simulation/?.lua"

local CommandFactory = include ("commandfactory")
local SimulationUtility = include ("simulationutility")
local PassageMap = include ("passagemap")

function run(factionIndex, shipName, type, area, callingPlayer)
    print ("running area analysis")

    local command = CommandFactory.makeCommand(type)

    local results = {}
    results.sectorsByFaction = {}
    results.reachable = 0
    results.unreachable = 0
    results.sectors = 0
    results.reachableCoordinates = {}

    local galaxy = Galaxy()

    local meta = {}
    meta.factionIndex = factionIndex
    meta.faction = Galaxy():findFaction(factionIndex)
    meta.shipName = shipName
    meta.type = type
    meta.area = area
    meta.passageMap = PassageMap(Server().seed)
    meta.callingPlayer = callingPlayer

    local x, y = meta.faction:getShipPosition(shipName)
    area.origin = {x = x, y = y}

    -- clamp area
    area.lower.x = math.min(500, math.max(-499, area.lower.x))
    area.lower.y = math.min(500, math.max(-499, area.lower.y))
    area.upper.x = math.min(500, math.max(-499, area.upper.x))
    area.upper.y = math.min(500, math.max(-499, area.upper.y))

    -- give the command a chance to supply the area that should be analyzed
    local sectors
    if command.getAreaAnalysisSectors then
        sectors = command:getAreaAnalysisSectors(results, meta)

        -- make sure sectors are valid
        if sectors then
            for _, coord in pairs(sectors) do
                if coord.x < -499 or coord.x > 500 or coord.y < -499 or coord.y > 500 then
                    local str = "Error: invalid sector coordinates returned by getAreaAnalysisSectors()"
                    print(str)
                    printlog(str)
                    break
                end
            end
        end
    end


    local reachable
    if not sectors then
        -- only use flood fill if the area rect is used
        sectors = {}
        for x = area.lower.x, area.upper.x, 1 do
            for y = area.lower.y, area.upper.y, 1 do
                table.insert(sectors, {x = x, y = y})
            end
        end

        reachable = calculateReachableSectors(command, meta, sectors)
    else
        -- don't use flood fill if specific sectors are given, just use the passage map
        reachable = calculatePassageMapSectors(meta.passageMap, sectors)
    end

    meta.reachable = reachable

    -- do a start up callback to give the command a chance to do some initialisation
    if command.onAreaAnalysisStart then
        command:onAreaAnalysisStart(results, meta)
    end

    -- actual analysis
    for _, coord in pairs(sectors) do
        local x, y = coord.x, coord.y

        results.sectors = results.sectors + 1

        if not reachable[makeKey(x, y)] then
            results.unreachable = results.unreachable + 1
            goto continue
        end

        results.reachable = results.reachable + 1

        -- detect faction / no faction
        local faction = galaxy:getControllingFaction(x, y)
        if not faction then
            faction = galaxy:getLocalFaction(x, y)
        end

        local index = 0
        local isCentralArea
        if faction then
            index = faction.index
            isCentralArea = galaxy:isCentralFactionArea(x, y, index)
        end

        local sectorDetails = {x = x, y = y, faction = index, isCentralArea = isCentralArea}
        table.insert(results.reachableCoordinates, sectorDetails)

        results.sectorsByFaction[index] = (results.sectorsByFaction[index] or 0) + 1

        -- do a sector callback to give the command a chance to do some calculation
        if command.onAreaAnalysisSector then
            command:onAreaAnalysisSector(results, meta, x, y, sectorDetails)
        end

        ::continue::
    end

    local biggestFactionInArea = nil
    local numSectorsOfFaction = 0
    for faction, num in pairs(results.sectorsByFaction) do
        if faction  > 0 and num > numSectorsOfFaction then
            numSectorsOfFaction = num
            biggestFactionInArea = faction
        end
    end

    results.biggestFactionInArea = biggestFactionInArea

    -- do a finishing callback to give the command a chance to do some final calculations
    if command.onAreaAnalysisFinished then
        command:onAreaAnalysisFinished(results, meta)
    end

    return shipName, type, area, results, callingPlayer
end

function makeKey(x, y)
    return x * 10000 + y
end

function calculatePassageMapSectors(passageMap, sectors)
    local reachable = {}
    for _, coord in pairs(sectors) do
        local x, y = coord.x, coord.y
        reachable[makeKey(x, y)] = passageMap:passable(x, y)
    end

    return reachable
end

function calculateReachableSectors(command, meta, sectors)
    local shipEntry = ShipDatabaseEntry(meta.factionIndex, meta.shipName)
    if not valid(shipEntry) then
        return calculatePassageMapSectors(meta.passageMap, sectors)
    end

    local _, canPassRifts = shipEntry:getHyperspaceProperties()

    -- if the ship can pass rifts it can reach any passable sector
    -- if the ship isn't required in the area then there isn't always a starting point for the flood fill
    if canPassRifts or not command:isShipRequiredInArea(meta.factionIndex, meta.shipName) then
        return calculatePassageMapSectors(meta.passageMap, sectors)
    end

    -- potentially not all sectors in the area can be reached
    -- find the initial position of the ship
    local x, y = shipEntry:getCoordinates()
    local startPosition = {x = x, y = y}

    return SimulationUtility.calculateFloodFill(startPosition, meta.area, meta.passageMap)
end

function printDebugVisualization(reachable, area)
    print("reachability results:")
    local resultStr = ""
    for y = area.lower.y, area.upper.y do
        for x = area.lower.x, area.upper.x do
            local result = reachable[makeKey(x, y)]
            if result == true then
                resultStr = resultStr .. "."
            elseif result == false then
                resultStr = resultStr .. "#"
            else
                resultStr = resultStr .. "?"
            end
        end

        resultStr = resultStr .. "\n"
    end

    print(resultStr)
end
