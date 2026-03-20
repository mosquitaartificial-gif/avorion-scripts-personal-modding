package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
include("randomext")
local SectorSpecifics = include ("sectorspecifics")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace BehemothEvent
BehemothEvent = {}
local self = BehemothEvent

local data = {}
self.data = data -- for write-access in tests
data.countDown = 60 * 60 -- first time after 1 hour
data.quadrantIndex = 1
data.quadrantOrder = {1, 2, 3, 4}

function BehemothEvent.initialize()
    local random = Random(Seed(GameSettings().seed))
    shuffle(random(), data.quadrantOrder)
end

function BehemothEvent.hasPlayerStations(galaxy, x, y)

    local view = galaxy:getSectorView(x, y)
    if not view then return false end

    for index, stations in pairs(view:getStationsByFaction()) do
        if stations > 0 and galaxy:playerFactionExists(index) then
            return true
        end
    end

    return false
end

function BehemothEvent.calculateNextAttackedSector()
    local rand = Random(Seed(GameSettings().seed .. data.quadrantIndex))
    local x = 50
    local y = 0

    local quadrant = data.quadrantOrder[(data.quadrantIndex % 4) + 1]
    if quadrant == 1 then
        y = rand:getInt(180, 500)
        x = rand:getInt(-(y - 30), y - 30)
    elseif quadrant == 2 then
        x = rand:getInt(180, 500)
        y = rand:getInt(-(x - 30), x - 30)
    elseif quadrant == 3 then
        y = rand:getInt(180, 500)
        x = rand:getInt(-(y - 30), y - 30)
        y = -y
    elseif quadrant == 4 then
        x = rand:getInt(180, 500)
        y = rand:getInt(-(x - 30), x - 30)
        x = -x
    end

    local galaxy = Galaxy()

    -- find a sector with ai faction stations
    local specs = SectorSpecifics()
    local coordList = specs.getShuffledCoordinates(rand, x, y, 0, 20)
    for _, coord in pairs(coordList) do
        local regular = specs:determineContent(coord.x, coord.y, GameSeed())
        if regular then
            -- but without player stations
            if not self.hasPlayerStations(galaxy, coord.x, coord.y) then
                -- when a script is specified, test for the script
                local subspecs = SectorSpecifics(coord.x, coord.y, GameSeed())
                if subspecs.generationTemplate then
                    local contents = subspecs.generationTemplate.contents(coord.x, coord.y)
                    if (contents.stations or 0) > 0 then
                        return coord, quadrant
                    end
                end
            end
        end
    end

    return {x = x, y = y}, quadrant
end

function BehemothEvent.moveToNextQuadrant()
    data.quadrantIndex = data.quadrantIndex + 1
end

function BehemothEvent.update(timeStep)    
    if not GameSettings().behemothEvents then
        return
    end

    -- only start counting down after at least 2h of playtime in the galaxy have passed
    if Server().runtime >= 2 * 60 * 60 then
        data.countDown = data.countDown - timeStep
    end

    if data.countDown <= 0 then
        local galaxy = Galaxy()

        if data.currentlyAttackedSector then
            local coords = data.currentlyAttackedSector.coords

            if not galaxy:sectorLoaded(coords.x, coords.y) then
                galaxy:loadSector(coords.x, coords.y)
            else
                local code = [[
                    function run()
                        Sector():invokeFunction("data/scripts/sector/background/spawnbehemoth.lua", "finish")
                    end
                ]]

                runSectorCode(coords.x, coords.y, true, code, "run")

                data.currentlyAttackedSector = nil
                data.countDown = 2 * 60 * 60 -- next attack after 2h

                self.moveToNextQuadrant()
            end
        else
            local coords, quadrant = self.calculateNextAttackedSector()

            -- try spawning the behemoth
            if not galaxy:sectorLoaded(coords.x, coords.y) then
                galaxy:loadSector(coords.x, coords.y)
            else
                local code = [[
                    function run()
                        Sector():addScriptOnce("data/scripts/sector/background/spawnbehemoth.lua", ${quadrant})
                    end
                ]] % {quadrant = quadrant}

                runSectorCode(coords.x, coords.y, true, code, "run")

                data.currentlyAttackedSector = {}
                data.currentlyAttackedSector.coords = coords
                data.currentlyAttackedSector.quadrant = quadrant
                data.countDown = 20 * 60 -- now players have 20 minutes to go there and fight the boss

                Galaxy():sendCallback("onBehemothAttackStart", quadrant, coords.x, coords.y)
            end
        end
    end

end

function BehemothEvent.secure()
    return data
end

function BehemothEvent.restore(data_in)
    data = data_in
    self.data = data

    data.quadrantIndex = data.quadrantIndex or 1
    data.quadrantOrder = data.quadrantOrder or {1, 2, 3, 4}
end
