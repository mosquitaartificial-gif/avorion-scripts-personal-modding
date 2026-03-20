package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
local SectorSpecifics = include ("sectorspecifics")

-- namespace LaserBossLocation
LaserBossLocation = {}
local self = LaserBossLocation

if onServer() then
    function LaserBossLocation.getSector()
        local rand = Random(Server().seed)
        local specs = SectorSpecifics()

        local coords = specs.getShuffledCoordinates(rand, 0, 0, -5, 5)
        local x, y
        for _, coord in pairs(coords) do

            local regular, offgrid, blocked, home = specs:determineContent(coord.x, coord.y, Server().seed)

            if not regular and not blocked and not home and not offgrid then
                if coord.x ~= 0 or coord.y ~= 0 then
                    x = coord.x
                    y = coord.y
                    break
                end
            end
        end

        return x, y
    end

    function LaserBossLocation.getCoordinate(coord)
        local x, y = LaserBossLocation.getSector()
        if coord == "y" then
            return y
        else
            return x
        end
    end
end

return LaserBossLocation
