package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
local BehemothUT = include("behemotheventutility")
local PlanGenerator = include ("plangenerator")
local ShipUtility = include ("shiputility")
local SectorTurretGenerator = include ("sectorturretgenerator")
local UpgradeGenerator = include ("upgradegenerator")
local SectorGenerator = include ("SectorGenerator")


-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace SpawnBehemoth
SpawnBehemoth = {}
local self = SpawnBehemoth

local data = {}

function SpawnBehemoth.initialize(quadrant)
    if onServer() then
        if quadrant then
            data.quadrant = quadrant
            self.createBehemoth()

            local text = self.getSightingMessage(quadrant)
            local x, y = Sector():getCoordinates()
            Server():broadcastChatMessage("", ChatMessageType.Warning, text, x, y)
        else
            local behemoth = Sector():getEntitiesByScriptValue("behemoth_boss")
            if not behemoth then
                terminate()
            end
        end
    end

end

function SpawnBehemoth.getUpdateInterval()
    return 0.5
end

function SpawnBehemoth.updateClient(timeStep)
    local behemoth = Sector():getEntitiesByScriptValue("behemoth_boss")
    if not behemoth then return end

    -- show boss health bar on the client
    registerBoss(behemoth.id)
end

-- Called by external behemoth event galaxy script
function SpawnBehemoth.finish()

    local sector = Sector()
    local behemoth = sector:getEntitiesByScriptValue("behemoth_boss")
    if not behemoth then
        -- if the behemoth can't be found, don't do anything and die
        terminate()
        return
    end

    -- despawn behemoth, if still there
    sector:deleteEntityJumped(behemoth)

    -- if there are players in the sector, we won't destroy anything since that would be immersion breaking
    local message
    if sector:getPlayers() then
        message = self.getFinishMessage(data.quadrant)
    else
        message = self.getFinishDestructionMessage(data.quadrant)

        local x, y = sector:getCoordinates()
        local generator = SectorGenerator(x, y)

        -- destroy everything
        local entities = {sector:getEntitiesByComponent(ComponentType.Owner)}
        for _, entity in pairs(entities) do
            if entity:getValue("behemoth_boss") then goto continue end

            if entity:hasComponent(ComponentType.Durability) then
                if entity.aiOwned then
                    local blockPlan = Plan(entity.id):getMove()
                    local wreckage = generator:createWreckage(nil, blockPlan)

                    entity:clearCargoBay()
                    sector:deleteEntity(entity)
                end
            else
                entity.factionIndex = 0
            end

            ::continue::
        end
    end

    local x, y = sector:getCoordinates()
    Server():broadcastChatMessage("", ChatMessageType.Warning, message, x, y)

    terminate()
end

function SpawnBehemoth.getBehemothSpawnPosition()

    local maxDist = 0
    for _, station in pairs({Sector():getEntitiesByType(EntityType.Station)}) do
        maxDist = math.max(maxDist, length(station.translationf))
    end

    maxDist = maxDist + 100

    local dir = normalize(random():getDirection() * vec3(1, 0, 1))
    local translation = dir * maxDist

    local look = cross(dir, vec3(0, 1, 0))

    return MatrixLookUpPosition(look, vec3(0, 1, 0), translation)
end

function SpawnBehemoth.createBehemoth()
    local position = self.getBehemothSpawnPosition()
    local faction = self.getFaction()

    local plan = LoadPlanFromFile(self.getBossFile(data.quadrant))
    local boss = Sector():createShip(faction, "", plan, position, EntityArrivalType.Jump)

    local numTurrets = math.max(1, Balancing_GetEnemySectorTurrets(150, 0))

    ShipUtility.addTurretsToCraft(boss, self.makeRailgunTurret(), numTurrets / 2, numTurrets / 2)
--    ShipUtility.addTurretsToCraft(boss, self.makePlasmaTurret(), numTurrets, numTurrets)
--    ShipUtility.addTurretsToCraft(boss, self.makeLaserTurret(), numTurrets, numTurrets)
    ShipUtility.addBossAntiTorpedoEquipment(boss)

    boss.title = self.getBossName(data.quadrant)
    boss.name = self.getBossName(data.quadrant)
    boss.crew = boss.idealCrew
    boss.shieldDurability = boss.shieldMaxDurability

    local upgrades =
    {
        {rarity = Rarity(RarityType.Legendary), amount = 2},
        {rarity = Rarity(RarityType.Exotic), amount = 3},
        {rarity = Rarity(RarityType.Exceptional), amount = 3},
        {rarity = Rarity(RarityType.Rare), amount = 5},
        {rarity = Rarity(RarityType.Uncommon), amount = 8},
        {rarity = Rarity(RarityType.Common), amount = 14},
    }

    local turrets =
    {
        {rarity = Rarity(RarityType.Legendary), amount = 2},
        {rarity = Rarity(RarityType.Exotic), amount = 3},
        {rarity = Rarity(RarityType.Exceptional), amount = 3},
        {rarity = Rarity(RarityType.Rare), amount = 5},
        {rarity = Rarity(RarityType.Uncommon), amount = 8},
        {rarity = Rarity(RarityType.Common), amount = 14},
    }

    local generator = UpgradeGenerator()
    for _, p in pairs(upgrades) do
        for i = 1, p.amount do
            Loot(boss):insert(generator:generateSectorSystem(150, 0, p.rarity))
        end
    end

    for _, p in pairs(turrets) do
        for i = 1, p.amount do
            Loot(boss):insert(InventoryTurret(SectorTurretGenerator():generate(150, 0, 0, p.rarity)))
        end
    end

    local upgrades = {}
    upgrades[1] = "data/scripts/systems/behemothmilitarytcs.lua"
    upgrades[2] = "data/scripts/systems/behemothciviltcs.lua"
    upgrades[3] = "data/scripts/systems/behemothcarriersystem.lua"
    upgrades[4] = "data/scripts/systems/behemothhyperspacesystem.lua"
    Loot(boss):insert(SystemUpgradeTemplate(upgrades[data.quadrant], Rarity(RarityType.Legendary), random():createSeed()))

    AddDefaultShipScripts(boss)

    -- adds legendary turret drop
    boss:addScriptOnce("internal/common/entity/background/legendaryloot.lua")
    boss:addScriptOnce("data/scripts/entity/background/behemothbehavior.lua")
    boss:addScriptOnce("utility/buildingknowledgeloot.lua")
    boss:setValue("behemoth_boss", true)

    Boarding(boss).boardable = false
    boss.dockable = false
    boss:setDropsAttachedTurrets(false)

    ShipAI(boss):setAggressive(true, false)

    boss.damageMultiplier = 130000 / boss.firePower

    return boss
end

function SpawnBehemoth.getFaction()
    local name = "Behemoths"%_T
    local faction = Galaxy():findFaction(name)
    if faction == nil then
        faction = Galaxy():createFaction(name, 150, 0)
        faction.initialRelations = -100000
        faction.initialRelationsToPlayer = -100000
        faction.staticRelationsToPlayers = true
    end

    faction.initialRelationsToPlayer = -100000
    faction.staticRelationsToPlayers = true
    faction.homeSectorUnknown = true

    return faction
end

function SpawnBehemoth.makeRailgunTurret()
    -- make custom railgun turrets
    local generator = SectorTurretGenerator(Seed(151))
    generator.coaxialAllowed = false

    local turret = generator:generate(150, 0, 0, Rarity(RarityType.Common), WeaponType.RailGun)
    local weapons = {turret:getWeapons()}
    turret:clearWeapons()
    for _, weapon in pairs(weapons) do
        weapon.reach = 8000
        weapon.blength = 8000
        weapon.bwidth = 4
        weapon.bauraWidth = 8
        weapon.fireDelay = weapon.fireDelay * random():getFloat(0.85, 1.15)
        turret:addWeapon(weapon)
    end

    turret.size = 8
    turret.turningSpeed = 0.25
    turret.crew = Crew()

    return turret
end

function SpawnBehemoth.getSightingMessage(quadrant)
    if quadrant == 1 then
        return "The Behemoth of the North has been sighted in \\s(%1%:%2%)!"%_t
    elseif quadrant == 2 then
        return "The Behemoth of the East has been sighted in \\s(%1%:%2%)!"%_t
    elseif quadrant == 3 then
        return "The Behemoth of the South has been sighted in \\s(%1%:%2%)!"%_t
    elseif quadrant == 4 then
        return "The Behemoth of the West has been sighted in \\s(%1%:%2%)!"%_t
    end
end

function SpawnBehemoth.getFinishMessage(quadrant)
    if quadrant == 1 then
        return "The Behemoth of the North has moved on."%_t
    elseif quadrant == 2 then
        return "The Behemoth of the East has moved on."%_t
    elseif quadrant == 3 then
        return "The Behemoth of the South has moved on."%_t
    elseif quadrant == 4 then
        return "The Behemoth of the West has moved on."%_t
    end
end

function SpawnBehemoth.getFinishDestructionMessage(quadrant)
    if quadrant == 1 then
        return "The Behemoth of the North has moved on from \\s(%1%:%2%) and left the sector in ruins!"%_t
    elseif quadrant == 2 then
        return "The Behemoth of the East has moved on from \\s(%1%:%2%) and left the sector in ruins!"%_t
    elseif quadrant == 3 then
        return "The Behemoth of the South has moved on from \\s(%1%:%2%) and left the sector in ruins!"%_t
    elseif quadrant == 4 then
        return "The Behemoth of the West has moved on from \\s(%1%:%2%) and left the sector in ruins!"%_t
    end
end

function SpawnBehemoth.getBossName(quadrant)
    if quadrant == 1 then
        return "Behemoth of the North"%_t
    elseif quadrant == 2 then
        return "Behemoth of the East"%_t
    elseif quadrant == 3 then
        return "Behemoth of the South"%_t
    elseif quadrant == 4 then
        return "Behemoth of the West"%_t
    end
end

function SpawnBehemoth.getBossFile(quadrant)
    if quadrant == 1 then
        return "data/plans/behemoth1.xml"
    elseif quadrant == 2 then
        return "data/plans/behemoth2.xml"
    elseif quadrant == 3 then
        return "data/plans/behemoth3.xml"
    elseif quadrant == 4 then
        return "data/plans/behemoth4.xml"
    end

    return "data/plans/behemoth3.xml"
end

function SpawnBehemoth.secure()
    return data
end

function SpawnBehemoth.restore(data_in)
    data = data_in
end
