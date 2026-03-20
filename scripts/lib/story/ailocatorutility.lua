package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
local SectorSpecifics = include ("sectorspecifics")


-- namespace AILocatorUtility
AILocatorUtility = {}
local self = AILocatorUtility

self.coordinates = {x = 0, y = 0}
self.corruptedCoords = {x = 0, y = 0}
self.seed = nil
self.corruptedSeed = nil

if onServer() then

function AILocatorUtility.onLocationChanged(corrupted)
    -- calculate new location
    if corrupted then
        self.corruptedCoords.x, self.corruptedCoords.y = AILocatorUtility.getSector(corrupted)
    else
        self.coordinates.x, self.coordinates.y = AILocatorUtility.getSector(corrupted)
    end
end

function AILocatorUtility.getCoordinates(corrupted)

    local newSeed = AILocatorUtility.generateSeed(corrupted)
    if corrupted then
        if newSeed ~= self.corruptedSeed then
            self.corruptedSeed = newSeed
            AILocatorUtility.onLocationChanged(corrupted)
        end
    else
        if newSeed ~= self.seed then
            self.seed = newSeed
            AILocatorUtility.onLocationChanged(corrupted)
        end
    end

    if corrupted then
        return self.corruptedCoords.x, self.corruptedCoords.y
    else
        return self.coordinates.x, self.coordinates.y
    end
end

function AILocatorUtility.getSector(corrupted)

    local rand
    if corrupted then
        rand = Random(Seed(self.corruptedSeed))
    else
        rand = Random(Seed(self.seed))
    end

    local specs = SectorSpecifics()
    local coords = {}
    if corrupted then
        coords = specs.getShuffledCoordinates(rand, 0, 0, -135, 135)
    else
        coords = specs.getShuffledCoordinates(rand, 0, 0, -140, 140)
    end

    local x, y
    for _, coord in pairs(coords) do

        local regular, offgrid, blocked, home = specs:determineContent(coord.x, coord.y, Server().seed)

        if not regular and not blocked and not home and not offgrid then
            if coord.x ~= 0 or coord.y ~= 0
                    and coord.x ~= 9 and coord.y ~= 3 then
                x = coord.x
                y = coord.y
                break
            end
        end
    end

    return x, y
end

function AILocatorUtility.generateSeed(corrupted)

    local seed
    if corrupted then
        seed = (tostring(Server():getValue("corrupted_ai_kill_counter")) or "0") .. tostring(Server().seed)
    else
        seed = (tostring(Server():getValue("big_ai_kill_counter")) or "0") .. tostring(Server().seed)
    end

    return seed
end

function AILocatorUtility.restore(data_in)
    data = data_in
end

function AILocatorUtility.secure()
    return data
end

end

return AILocatorUtility
