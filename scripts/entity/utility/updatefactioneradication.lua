package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
local SectorSpecifics = include("sectorspecifics")
local FactionEradicationUtility = include("factioneradicationutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace UpdateFactionEradication
UpdateFactionEradication = {}

if onServer() then

function UpdateFactionEradication.initialize()
    Entity():registerCallback("onDestroyed", "onDestroyed")
end

function UpdateFactionEradication.onDestroyed()
    local faction = Faction()
    if not faction then return end
    if not faction.isAIFaction then return end
    if not Galaxy():isMapFaction(faction.index) then return end

    local sector = Sector()
    local currentX, currentY = sector:getCoordinates()
    local ownId = Entity().id

    -- this is the sector we are currently in
    for _, entity in pairs({sector:getEntitiesByFaction(faction.index)}) do
        if entity.type == EntityType.Station and entity.id ~= ownId and not sector:isEntitySetForDeletion(entity) then
            -- there is still a station other than the one that was destroyed just now in the sector -> not eradicated
            return
        end
    end

    asyncf("", "data/scripts/entity/utility/updatefactioneradication.lua", faction.index, currentX, currentY)
end

function UpdateFactionEradication.run(factionIndex, currentX, currentY)
    local faction = Faction(factionIndex)
    local hx, hy = faction:getHomeSectorCoordinates()

    local startX = math.max(-499, hx - 200)
    local endX = math.min(500, hx + 200)
    local startY = math.max(-499, hy - 200)
    local endY = math.min(500, hy + 200)

    local specs = SectorSpecifics()
    local seed = GameSeed()
    local galaxy = Galaxy()

    for x = startX, endX do
        for y = startY, endY do
            if x == currentX and y == currentY then
                -- this is the sector we are currently in
                -- it was already checked before the async was kicked off
                goto continue
            end

            local regular, offgrid, dust = specs.determineFastContent(x, y, seed)

            if regular or offgrid then
                local _, _, _, _, _, specsFactionIndex = specs:determineContent(x, y, seed)

                if factionIndex == specsFactionIndex then
                    -- does the faction have a sector that has never been visited? -> not eradicated
                    if not galaxy:sectorExists(x, y) then
                        return
                    end

                    local view = galaxy:getSectorView(x, y)
                    if view then
                        local numStations = view:getStationsByFaction()[factionIndex] or 0
                        -- does the faction still have stations in this sector? -> not eradicated
                        if numStations > 0 then return end
                    end
                end
            end

            ::continue::
        end
    end

    FactionEradicationUtility.setFactionEradicated(faction)
end

end
