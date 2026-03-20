
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("galaxy")
include ("randomext")
include ("player")
include ("faction")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace PassivePlayerAttackStarter
PassivePlayerAttackStarter = {}

if onServer() then

function PassivePlayerAttackStarter.initialize()
    local entityInfos = {}
    local player = Player()
    local galaxy = Galaxy()

    for _, name in pairs({player:getShipNames()}) do
        local info = {}
        local entry = ShipDatabaseEntry(player.index, name)
        if entry:getAvailability() == ShipAvailability.Available then
            local x, y = player:getShipPosition(name)
            if galaxy:sectorLoaded(x, y) and not galaxy:sectorInRift(x, y) then
                info = {x = x, y = y, name = name}
                -- add coordinates to table so that sectors with several stations end up in table more often, making attack more likely there
                table.insert(entityInfos, info)
            end
        end
    end

    if #entityInfos > 0 then
        -- find a random sector with player stations to be attacked
        local targetEntity = getRandomEntry(entityInfos)

        local spawnAttackers = [[
        function run(...)
            Sector():addScriptOnce("data/scripts/events/passiveplayerattack.lua", ...)
        end
        ]]

        if targetEntity then
            runSectorCode(targetEntity.x, targetEntity.y, true, spawnAttackers, "run", player.index, targetEntity.name)
        end
    end

    terminate()
end

end
