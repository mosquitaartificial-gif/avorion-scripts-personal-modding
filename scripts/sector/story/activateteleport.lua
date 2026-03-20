
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("randomext")
local Balancing = include ("galaxy")
local PlanGenerator = include("plangenerator")
local SectorSpecifics = include("sectorspecifics")
local Placer = include("placer")
local Xsotan = include("story/xsotan")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace ActivateTeleport
ActivateTeleport = {}

local activationDistance = 150
local spawned

if onServer() then
function ActivateTeleport.getUpdateInterval()
    return 1
end
end

if onClient() then
function ActivateTeleport.getUpdateInterval()
    return 0
end
end

function ActivateTeleport.getTeleporters()
    if teleporters then return teleporters end

    teleporters = {}
    local entities = {Sector():getEntitiesByComponent(ComponentType.Scripts)}

    for _, entity in pairs(entities) do
        local teleporter = entity:getValue("teleporter")
        if teleporter then
            teleporters[teleporter] = entity
        end
    end

    return teleporters
end

if onServer() then

function ActivateTeleport.updateServer()

    -- if there's a wormhole, don't activate
    -- this is to prevent double activation
    local wormholes = {Sector():getEntitiesByComponent(ComponentType.EntityTransferrer)}
    if #wormholes > 0 then return end

    -- check if there's a player who already crossed, if yes -> enable automatically
    local players = {Sector():getPlayers()}
    for _, player in pairs(players) do
        if player:getValue("visited_center") then
            ActivateTeleport.activate(false)
            return
        end
    end

    -- get all entities that can have upgrades
    local entities = {Sector():getEntitiesByComponent(ComponentType.ShipSystem)}

    -- filter out all entities that don't have a teleporter key upgrade
    for i, entity in pairs(entities) do
        if entity:hasScript("teleporterkey") == false then
            entities[i] = nil
        end
    end

    local teleporters = ActivateTeleport.getTeleporters()
    local teleportersOccupied = 0

    -- check if positioning is correct
    for i, teleporter in pairs(teleporters) do
        if valid(teleporter) then
            local occupied

            for _, entity in pairs(entities) do
                if teleporter.index ~= entity.index then
                    local scriptName = string.format("teleporterkey%i.lua", i)

                    if entity:hasScript(scriptName) then
                        local d = teleporter:getNearestDistance(entity)
                        if d <= activationDistance then
                            occupied = true
                            break
                        end
                    end
                end
            end

            if occupied then
                teleportersOccupied = teleportersOccupied + 1
            end
        end
    end

    if teleportersOccupied == 8 then
        ActivateTeleport.activate(true)
    end
end

function ActivateTeleport.activate(withEnemies)
    local x, y = Sector():getCoordinates()
    local own = vec2(x, y)
    local d = length(own)

    local distanceInside = 5;

    -- find a free destination inside the ring
    local destination = nil
    while not destination do
        local d = own / d * (Balancing.BlockRingMin - distanceInside)

        local specs = SectorSpecifics()
        local target = specs:findFreeSector(random(), math.floor(d.x), math.floor(d.y), 1, distanceInside - 1, Server().seed)

        if target then
            destination = target
        else
            distanceInside = distanceInside + 1
        end
    end

    local desc = WormholeDescriptor()
    desc:addComponent(ComponentType.DeletionTimer)

    local cpwormhole = desc:getComponent(ComponentType.WormHole)
    cpwormhole.color = ColorRGB(1, 0, 0)
    cpwormhole:setTargetCoordinates(destination.x, destination.y)
    cpwormhole.visualSize = 100
    cpwormhole.passageSize = math.huge
    cpwormhole.oneWay = false

    desc:addScriptOnce("data/scripts/entity/wormhole.lua")

    local wormHole = Sector():createEntity(desc)

    DeletionTimer(wormHole.index).timeLeft = 35 * 60 -- open for 35 minutes

    if not spawned and withEnemies then
        spawned = true

        deferredCallback(6, "spawnEnemies", 3, 3)
        deferredCallback(30, "spawnEnemies", 5, 5)
        deferredCallback(60, "spawnEnemies", 3, 20)
        deferredCallback(90, "spawnEnemies", 2, 50)
    end
end

function ActivateTeleport.spawnEnemies(amount, scale)

    local enemies = {}
    for i = 1, amount do
        local enemy = Xsotan.createShip(Matrix(), scale)
        enemy:setValue("untransferrable", true)

        table.insert(enemies, enemy)
    end

    Placer.resolveIntersections(enemies)
end

end -- onServer()

local topLevelBlocks
local glowPositions = {}
local timeCount = 0
local lasers = {}

if onClient() then

function ActivateTeleport.updateClient(timeStep)

    timeCount = timeCount + timeStep
    while timeCount > 1.0 do
        ActivateTeleport.updateClientLowFq()
        timeCount = timeCount - 1.0
    end

    for _, position in pairs(glowPositions) do
        Sector():createGlow(position, random():getFloat(14, 18), ColorRGB(1.0, 0.2, 0.2))
    end
end


function ActivateTeleport.updateClientLowFq()
    glowPositions = {}

    -- get all entities that can have upgrades
    local entities = {Sector():getEntitiesByComponent(ComponentType.ShipSystem)}

    -- filter out all entities that don't have a teleporter key upgrade
    for i, entity in pairs(entities) do
        if entity:hasScript("teleporterkey") == false then
            entities[i] = nil
        end
    end

    local teleporters = ActivateTeleport.getTeleporters()

    if not topLevelBlocks then
        topLevelBlocks = {}

        for _, teleporter in pairs(teleporters) do
            local plan = Plan(teleporter.index)
            local block = PlanGenerator.findMinBlock(plan, "y")
            topLevelBlocks[teleporter.index.string] = block.box.center
        end
    end

    local teleportersOccupied = 0
    -- check if positioning is correct
    for i, teleporter in pairs(teleporters) do
        if valid(teleporter) then
            local occupied

            for _, entity in pairs(entities) do
                if teleporter.index ~= entity.index then
                    local scriptName = string.format("teleporterkey%i.lua", i)

                    if entity:hasScript(scriptName) then
                        local d = teleporter:getNearestDistance(entity)
                        if d <= activationDistance then
                            occupied = true
                            break
                        end
                    end
                end
            end

            if occupied then
                teleportersOccupied = teleportersOccupied + 1

                local position = topLevelBlocks[teleporter.index.string]
                position = teleporter.position:transformCoord(position)

                table.insert(glowPositions, position)
            end
        end
    end

    if teleportersOccupied == 8 then
        local wormholes = {Sector():getEntitiesByComponent(ComponentType.EntityTransferrer)}
        if #wormholes > 0 then return end

        if #lasers == 0 then
            local sector = Sector()
            for index, position in pairs(topLevelBlocks) do
                local teleporter = sector:getEntity(index)
                if teleporter then
                    local pos = teleporter.position:transformCoord(position)

                    local laser = sector:createLaser(pos, vec3(), ColorRGB(1, 0, 0), 15)
                    laser.collision = false
                    laser.maxAliveTime = 15

                    table.insert(lasers, laser)
                end
            end
        end
    else
        if #lasers > 0 then
            for _, laser in pairs(lasers) do
                if valid(laser) then
                    laser.maxAliveTime = 0.01
                end
            end
            lasers = {}
        end
    end

end

end -- onClient()

