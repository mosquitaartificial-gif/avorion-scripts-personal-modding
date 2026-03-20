package.path = package.path .. ";data/scripts/lib/?.lua"

include ("randomext")
local SectorGenerator = include ("SectorGenerator")
local Placer = include ("placer")
local SectorSpecifics = include("sectorspecifics")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace RespawnContainerField
RespawnContainerField = {}
local self = RespawnContainerField

self.data = {}

if onServer() then

function RespawnContainerField.respawn()
    local sector = Sector()

    -- delete containers
    for _, entity in pairs({sector:getEntities()}) do
        if RespawnContainerField.isDeletable(entity) then
            sector:deleteEntity(entity)
        end
    end

    local x, y = sector:getCoordinates()
    local specs = SectorSpecifics()
    specs:initialize(x, y, Seed(GameSettings().seed))

    if specs.generationTemplate then
        if string.match(specs.generationTemplate.path or "", "/massivecontainerfield") then

            local generator = SectorGenerator(x, y)
            for i = 1, 8 do
                generator:createContainerField(nil, nil, nil, nil, nil, 0)
            end

            generator:createContainerField(nil, nil, nil, nil, nil, 2)
            generator:createContainerField(nil, nil, nil, nil, nil, 1)

        elseif string.match(specs.generationTemplate.path or "", "/containerfield") then
            local generator = SectorGenerator(x, y)
            generator:createContainerField(nil, nil, nil, nil, nil, random():getInt(0, 1))
        end
    end

    Placer.resolveIntersections()

    sector:sendCallback("onContainersRespawned")
end

function RespawnContainerField.isDeletable(entity)
    -- don't delete docked containers
    if entity.dockingParent then return false end

    -- don't delete containers docked to objects
    if entity.factionIndex and entity.factionIndex > 0 then return false end

    -- in case it's a container -> return true
    if entity.type == EntityType.Container then return true end

    if entity.type == EntityType.None then
        if entity.title == "Container" then
            return true
        end
    end

    return false
end


function RespawnContainerField.secure()
    return self.data
end

function RespawnContainerField.restore(data_in)
    self.data = data_in

    local now = Server().unpausedRuntime
    if not self.data.lastRespawn then
        self.data.lastRespawn = now
    end

    if now - self.data.lastRespawn > 24 * 60 * 60 then
        RespawnContainerField.respawn()
        self.data.lastRespawn = now
    end
end

end
