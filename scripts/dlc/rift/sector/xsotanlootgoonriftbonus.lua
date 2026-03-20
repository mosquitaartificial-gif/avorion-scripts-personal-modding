package.path = package.path .. ";data/scripts/lib/?.lua"

local Xsotan = include("story/xsotan")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace XsotanLootGoonRiftBonus
XsotanLootGoonRiftBonus = {}

local xsotanFactionIndex = nil
local outstanding = 5
local timeSinceLastSpawn = 120

if onServer() then

function XsotanLootGoonRiftBonus.initialize()
    xsotanFactionIndex = Xsotan.getFaction().index

    Sector():registerCallback("onEntityCreated", "onEntityCreated")
end

function XsotanLootGoonRiftBonus.getUpdateInterval()
    return 10
end

function XsotanLootGoonRiftBonus.updateServer(timeStep)
    timeSinceLastSpawn = timeSinceLastSpawn + timeStep
end

function XsotanLootGoonRiftBonus.onEntityCreated(id)
    if timeSinceLastSpawn < 120 then return end

    local entity = Entity(id)
    if not valid(entity) then return end

    if entity.factionIndex == xsotanFactionIndex
            and entity.type == EntityType.Ship then

        timeSinceLastSpawn = 0
        outstanding = outstanding - 1

        local position = entity.position
        position.translation = position.translation + random():getDirection() * 200
        Xsotan.createLootGoon(position)
    end

    if outstanding <= 0 then terminate() end
end

end
