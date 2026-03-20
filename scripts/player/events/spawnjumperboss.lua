package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("randomext")
local ShipGenerator = include("shipgenerator")
local ShipUtility = include ("shiputility")
local SectorTurretGenerator = include ("sectorturretgenerator")


-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace JumperBoss
JumperBoss = {}

function JumperBoss.spawnBoss(x, y)
    if not x and not y then
        x, y = Sector():getCoordinates()
    end

    -- no double spawning
    if Sector():getEntitiesByScript("entity/events/jumperboss.lua") then return end

    -- create ship
    local faction = JumperBoss.getFaction()
    local translation = random():getDirection() * 500
    local position = MatrixLookUpPosition(-translation, vec3(0, 1, 0), translation)
    local volume = Balancing_GetSectorShipVolume(Sector():getCoordinates()) * 30

    local boss = ShipGenerator.createShip(faction, postition, volume)

    -- remove shield if there is one
    local plan = Plan(boss.id)
    if not plan then return end
    local shieldBlocks = plan:getBlocksByType(BlockType.ShieldGenerator)
    for _, blockIndex in pairs(shieldBlocks) do
        plan:setBlockType(blockIndex, BlockType.Armor)
    end

    -- add turrets
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false

    local cannon = generator:generate(x, y, 0, Rarity(RarityType.Exceptional), WeaponType.Cannon)
    ShipUtility.addTurretsToCraft(boss, cannon, 3)

    local laser = generator:generate(x, y, 0, Rarity(RarityType.Exotic), WeaponType.Laser)
    ShipUtility.addTurretsToCraft(boss, laser, 2)

    local rocketLauncher = generator:generate(x, y, 0, Rarity(RarityType.Exceptional), WeaponType.RocketLauncher)
    ShipUtility.addTurretsToCraft(boss, rocketLauncher, 5)

    local pdc = generator:generate(x, y, 0, Rarity(RarityType.Exotic), WeaponType.PointDefenseChainGun)
    ShipUtility.addTurretsToCraft(boss, pdc, 2)

    -- add drops
    local randomRarityType = function()
        local rand = random():getInt(1, 10)
        if rand <= 2 then
            return RarityType.Legendary
        else
            return RarityType.Exotic
        end
    end

    Loot(boss.index):insert(InventoryTurret(generator:generate(x, y, 0, Rarity(randomRarityType()), WeaponType.Cannon)))
    Loot(boss.index):insert(InventoryTurret(generator:generate(x, y, 0, Rarity(randomRarityType()), WeaponType.Laser)))

    -- adds legendary turret drop
    boss:addScriptOnce("internal/common/entity/background/legendaryloot.lua")

    -- add properties
    boss.name = ""
    boss.title = "Fidget"%_T
    Boarding(boss).boardable = false
    boss.dockable = false
    boss:addScript("data/scripts/entity/events/jumperboss.lua")
    boss:addScript("deleteonplayersleft.lua")

    -- set boss aggressive immediately
    local bossAI = ShipAI(boss.id)
    local players = {Sector():getPlayers()}
    for _, player in pairs(players) do
        bossAI:registerEnemyFaction(player.index)
        if player.allianceIndex then
            bossAI:registerEnemyFaction(player.allianceIndex)
        end
    end

    bossAI:setAggressive()
end

function JumperBoss.getFaction()
    local name = "The Pariah"%_T
    local faction = Galaxy():findFaction(name)
    if faction == nil then
        faction = Galaxy():createFaction(name, 0, 0)
        faction.initialRelations = 0
        faction.initialRelationsToPlayer = 0
        faction.staticRelationsToPlayers = true
    end

    faction.initialRelationsToPlayer = 0
    faction.staticRelationsToPlayers = true
    faction.homeSectorUnknown = true

    return faction
end

return JumperBoss
