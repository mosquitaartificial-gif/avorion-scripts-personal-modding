package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
include ("randomext")
include ("utility")
include ("stringutility")
SectorTurretGenerator = include ("sectorturretgenerator")
ShipUtility = include ("shiputility")
include("weapontype")

local AI = {}

function AI.getFaction()
    local faction = Galaxy():findFaction("The AI"%_T)
    if faction == nil then
        faction = Galaxy():createFaction("The AI"%_T, 300, 0)
        faction.initialRelations = 0
        faction.initialRelationsToPlayer = 0
        faction.staticRelationsToAll = true
    end

    faction.homeSectorUnknown = true

    return faction
end

function AI.addTurrets(boss, numTurrets)

    -- create custom plasma turrets
    local generator = SectorTurretGenerator(Seed(150))
    generator.coaxialAllowed = false
    local turret = generator:generate(300, 0, 0, Rarity(RarityType.Exceptional), WeaponType.PlasmaGun)
    local weapons = {turret:getWeapons()}
    turret:clearWeapons()
    for _, weapon in pairs(weapons) do
        weapon.damage = 15 / #weapons
        weapon.fireRate = 2
        weapon.reach = 1000
        weapon.pmaximumTime = weapon.reach / weapon.pvelocity
        weapon.pcolor = Material(2).color
        turret:addWeapon(weapon)
    end
    turret.crew = Crew()
    ShipUtility.addTurretsToCraft(boss, turret, numTurrets, numTurrets)

    ShipUtility.addBossAntiTorpedoEquipment(boss, numTurrets)

    boss:setDropsAttachedTurrets(false)

end

function AI.spawn(x, y)

    -- no double spawning
    if Sector():getEntitiesByScript("entity/story/aibehaviour.lua") then return end

    local faction = AI.getFaction()

    local plan = LoadPlanFromFile("data/plans/the_ai.xml")

    local s = 1.5
    plan:scale(vec3(s, s, s))
    plan.accumulatingHealth = false

    local pos = random():getVector(-1000, 1000)
    pos = MatrixLookUpPosition(-pos, vec3(0, 1, 0), pos)

    local boss = Sector():createShip(faction, "", plan, pos)

    boss.shieldDurability = boss.shieldMaxDurability
    boss.title = "The AI"%_T
    boss.name = ""
    boss.crew = boss.idealCrew
    boss:addScriptOnce("story/aibehaviour")
    boss:addScriptOnce("story/aidialog")
    boss:addScriptOnce("deleteonplayersleft")

    WreckageCreator(boss.index).active = false
    Loot(boss.index):insert(InventoryTurret(SectorTurretGenerator():generate(x, y, 0, Rarity(RarityType.Exotic))))
    Loot(boss.index):insert(InventoryTurret(SectorTurretGenerator():generate(x, y, 0, Rarity(RarityType.Exotic))))
    boss:addScriptOnce("internal/common/entity/background/legendaryloot.lua")
    boss:addScriptOnce("utility/buildingknowledgeloot.lua", Material(MaterialType.Naonite))

    -- create custom plasma turrets
    AI.addTurrets(boss, 25)

    Boarding(boss).boardable = false
    boss.dockable = false

    AI.checkForDrop()

    return boss
end

local lastAIPosition = nil
local lastSector = {}

function AI.checkForDrop()

    -- if it's the last one, then drop the key
    local faction = AI.getFaction()

    local all = {Sector():getEntitiesByScript("story/aibehaviour")}
    local aiPosition = nil

    -- make sure this is all happening in the same sector
    local x, y = Sector():getCoordinates()
    if lastSector.x ~= x or lastSector.y ~= y then
        -- this must be set in order to drop the loot
        -- if the sector changed, simply unset it
        lastAIPosition = nil
    end
    lastSector.x = x
    lastSector.y = y

    local aiPresent = false
    for _, entity in pairs(all) do
        aiPosition = entity.translationf
        aiPresent = true
        break
    end

    local dropped

    -- if there are no ais now but there have been before, drop the upgrade
    if aiPosition == nil and lastAIPosition ~= nil then
        local players = {Sector():getPlayers()}

        for _, player in pairs(players) do
            local upgradeLoots = {Sector():getEntitiesByComponent(ComponentType.SystemUpgradeLoot)}
            local drop = true
            for _, upgradeLoot in pairs(upgradeLoots) do
                local upgrade = SystemUpgradeLoot(upgradeLoot).upgrade
                if upgrade.script == "data/scripts/systems/teleporterkey6.lua" then
                    if player.index == upgradeLoot.reservedPlayer then
                        drop = false
                    end
                end
            end

            if drop then
                local system = SystemUpgradeTemplate("data/scripts/systems/teleporterkey6.lua", Rarity(RarityType.Legendary), Seed(1))
                Sector():dropUpgrade(lastAIPosition, player, nil, system)
                dropped = true
            end
        end
    end

    lastAIPosition = aiPosition

    return dropped, aiPresent
end


return AI
