package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("galaxy")
include ("stringutility")
include ("randomext")
local PlanGenerator = include ("plangenerator")
local ShipUtility = include ("shiputility")
local SectorTurretGenerator = include ("sectorturretgenerator")
local UpgradeGenerator = include ("upgradegenerator")
local SectorFighterGenerator = include("sectorfightergenerator")


local PirateGenerator = {}

function PirateGenerator.getScaling()
    local scaling = Sector().numPlayers

    if scaling == 0 then scaling = 1 end
    return scaling
end


function PirateGenerator.createScaledOutlaw(position)
    local scaling = PirateGenerator.getScaling()
    return PirateGenerator.create(position, 1.2 * scaling, "Outlaw"%_T)
end

function PirateGenerator.createScaledBandit(position)
    local scaling = PirateGenerator.getScaling()
    return PirateGenerator.create(position, 1.2 * scaling, "Bandit"%_T)
end

function PirateGenerator.createScaledPirate(position)
    local scaling = PirateGenerator.getScaling()
    return PirateGenerator.create(position, 1.4 * scaling, "Pirate"%_T)
end

function PirateGenerator.createScaledMarauder(position)
    local scaling = PirateGenerator.getScaling()
    return PirateGenerator.create(position, 1.6 * scaling, "Marauder"%_T)
end

function PirateGenerator.createScaledDisruptor(position)
    local scaling = PirateGenerator.getScaling()
    return PirateGenerator.create(position, 1.6 * scaling, "Disruptor"%_T)
end

function PirateGenerator.createScaledRaider(position)
    local scaling = PirateGenerator.getScaling()
    return PirateGenerator.create(position, 3.0 * scaling, "Raider"%_T)
end

function PirateGenerator.createScaledCarrier(position)
    local scaling = PirateGenerator.getScaling()
    return PirateGenerator.create(position, 6.0 * scaling, "Pirate Carrier"%_T)
end

function PirateGenerator.createScaledRavager(position)
    if random():test(0.2) then
        return PirateGenerator.createScaledCarrier(position)
    end

    local scaling = PirateGenerator.getScaling()
    return PirateGenerator.create(position, 6.0 * scaling, "Ravager"%_T)
end

function PirateGenerator.createScaledBoss(position)
    local scaling = PirateGenerator.getScaling()
    return PirateGenerator.create(position, 25.0 * scaling, "Pirate Mothership"%_T)
end

function PirateGenerator.createScaledLootGoon(position)
    local scaling = PirateGenerator.getScaling()
    return PirateGenerator.create(position, 2.0 * scaling, "Pirate Loot Transporter"%_T)
end


function PirateGenerator.createOutlaw(position)
    return PirateGenerator.create(position, 1.2, "Outlaw"%_T)
end

function PirateGenerator.createBandit(position)
    return PirateGenerator.create(position, 1.2, "Bandit"%_T)
end

function PirateGenerator.createPirate(position)
    return PirateGenerator.create(position, 1.4, "Pirate"%_T)
end

function PirateGenerator.createMarauder(position)
    return PirateGenerator.create(position, 1.6, "Marauder"%_T)
end

function PirateGenerator.createDisruptor(position)
    return PirateGenerator.create(position, 1.6, "Disruptor"%_T)
end

function PirateGenerator.createRaider(position)
    return PirateGenerator.create(position, 6.0, "Raider"%_T)
end

function PirateGenerator.createCarrier(position)
    return PirateGenerator.create(position, 6.0, "Pirate Carrier"%_T)
end

function PirateGenerator.createRavager(position)
    if random():test(0.2) then
        return PirateGenerator.createCarrier(position)
    end

    return PirateGenerator.create(position, 6.0, "Ravager"%_T)
end

function PirateGenerator.createBoss(position)
    return PirateGenerator.create(position, 25.0, "Pirate Mothership"%_T)
end

function PirateGenerator.createLootGoon(position)
    return PirateGenerator.create(position, 2.0, "Pirate Loot Transporter"%_T)
end

function PirateGenerator.create(position, volumeFactor, title)
    position = position or Matrix()
    local x, y = Sector():getCoordinates()
    PirateGenerator.pirateLevel = PirateGenerator.pirateLevel or Balancing_GetPirateLevel(x, y)

    local faction = Galaxy():getPirateFaction(PirateGenerator.pirateLevel)

    local volume = Balancing_GetSectorShipVolume(x, y) * volumeFactor;

    local plan = nil
    if title == "Pirate Carrier" then
        plan = PlanGenerator.makeCarrierPlan(faction, volume)
    else
        plan = PlanGenerator.makeShipPlan(faction, volume)
    end

    local ship = Sector():createShip(faction, "", plan, position)

    PirateGenerator.addPirateEquipment(ship, title)

    ship.crew = ship.idealCrew
    ship.shieldDurability = ship.shieldMaxDurability

    return ship
end

function PirateGenerator.getPirateFaction()
    local x, y = Sector():getCoordinates()
    PirateGenerator.pirateLevel = PirateGenerator.pirateLevel or Balancing_GetPirateLevel(x, y)
    return Galaxy():getPirateFaction(PirateGenerator.pirateLevel)
end

-- this function also covers pirates created in asyncpirategenerator.lua
function PirateGenerator.addPirateEquipment(craft, title)

    local drops = 0

    local x, y = Sector():getCoordinates()

    local turretGenerator = SectorTurretGenerator()
    local turretRarities = turretGenerator:getSectorRarityDistribution(x, y)

    local upgradeGenerator = UpgradeGenerator()
    local upgradeRarities = upgradeGenerator:getSectorRarityDistribution(x, y)


    if title == "Outlaw" then
        ShipUtility.addMilitaryEquipment(craft, 0.8, 0)
        -- this pirate has potential for cowardice
        if random():test(0.3) then craft:addScriptOnce("utility/fleeondamaged.lua") end
    elseif title == "Bandit" then
        ShipUtility.addMilitaryEquipment(craft, 1, 0)
        -- this pirate has potential for cowardice
        if random():test(0.3) then craft:addScriptOnce("utility/fleeondamaged.lua") end
    elseif title == "Pirate" then
        ShipUtility.addMilitaryEquipment(craft, 1, 0)
        -- this pirate has potential for cowardice
        if random():test(0.2) then craft:addScriptOnce("utility/fleeondamaged.lua") end
    elseif title == "Marauder" then
        local type = random():getInt(1, 3)
        if type == 1 then
            ShipUtility.addDisruptorEquipment(craft)
        elseif type == 2 then
            ShipUtility.addArtilleryEquipment(craft)
        elseif type == 3 then
            ShipUtility.addCIWSEquipment(craft)
        end
    elseif title == "Disruptor" then
        local type = random():getInt(1, 2)
        if type == 1 then
            ShipUtility.addDisruptorEquipment(craft)
        elseif type == 2 then
            ShipUtility.addCIWSEquipment(craft)
        end
    elseif title == "Raider" then
        local type = random():getInt(1, 3)
        if type == 1 then
            ShipUtility.addDisruptorEquipment(craft)
        elseif type == 2 then
            ShipUtility.addPersecutorEquipment(craft)
        elseif type == 3 then
            ShipUtility.addTorpedoBoatEquipment(craft)
        end

        drops = random():getInt(0, 1)
        turretRarities[-1] = 0 -- no petty turrets
        turretRarities[0] = 0 -- no common turrets
        turretRarities[1] = 0 -- no uncommon turrets
        turretRarities[5] = 0 -- no legendary (additional) turrets

        upgradeRarities[-1] = 0 -- no petty upgrades
        upgradeRarities[0] = 0 -- no common upgrades
        upgradeRarities[1] = 0 -- no uncommon upgrades
        upgradeRarities[5] = 0 -- no legendary (additional) upgrades

    elseif title == "Ravager" then
        local type = random():getInt(1, 2)
        if type == 1 then
            ShipUtility.addArtilleryEquipment(craft)
        elseif type == 2 then
            ShipUtility.addPersecutorEquipment(craft)
        end

        drops = 1
        turretRarities[-1] = 0 -- no petty turrets
        turretRarities[0] = 0 -- no common turrets
        turretRarities[1] = 0 -- no uncommon turrets

        upgradeRarities[-1] = 0 -- no petty upgrades
        upgradeRarities[0] = 0 -- no common upgrades
        upgradeRarities[1] = 0 -- no uncommon

    elseif title == "Pirate Mothership" then
        local type = random():getInt(1, 2)
        if type == 1 then
            ShipUtility.addCarrierEquipment(craft)
        elseif type == 2 then
            ShipUtility.addFlagShipEquipment(craft)
        end
        ShipUtility.addBossAntiTorpedoEquipment(craft)

        drops = 2
        turretRarities[-1] = 0 -- no petty turrets
        turretRarities[0] = 0 -- no common turrets
        turretRarities[1] = 0 -- no uncommon turrets

        upgradeRarities[-1] = 0 -- no petty upgrades
        upgradeRarities[0] = 0 -- no common upgrades
        upgradeRarities[1] = 0 -- no uncommon upgrades

        -- add fighters for carriers
    elseif title == "Pirate Carrier" then

        local hangar = Hangar(craft)

        if hangar.space > 0 then
            ShipUtility.addCarrierEquipment(craft)

            hangar:addSquad("Alpha")
            hangar:addSquad("Beta")
            hangar:addSquad("Gamma")

            local faction = Faction(craft.factionIndex)
            local fighters = 15 + GameSettings().difficulty * 5
            local numFighters = 0
            local generator = SectorFighterGenerator()
            generator.factionIndex = faction.index

            for squad = 0, 2 do
                local fighter = generator:generateArmed(faction:getHomeSectorCoordinates())
                for i = 1, 7 do
                    hangar:addFighter(squad, fighter)

                    numFighters = numFighters + 1
                    if numFighters >= fighters then break end
                end

                if numFighters >= fighters then break end
            end
        else
            title = "Ravager"

            ShipUtility.addPersecutorEquipment(craft)
        end

        drops = 1
        turretRarities[-1] = 0 -- no petty turrets
        turretRarities[0] = 0 -- no common turrets
        turretRarities[1] = 0 -- no uncommon turrets

        upgradeRarities[-1] = 0 -- no petty upgrades
        upgradeRarities[0] = 0 -- no common upgrades
        upgradeRarities[1] = 0 -- no uncommon

    elseif title == "Pirate Loot Transporter" then
        craft:addScriptOnce("data/scripts/entity/enemies/lootgoon.lua")
    else
        ShipUtility.addMilitaryEquipment(craft, 1, 0)
    end

    if craft.numTurrets == 0 then
        ShipUtility.addMilitaryEquipment(craft, 1, 0)
    end

    turretGenerator.rarities = turretRarities
    for i = 1, drops do
        if random():test(0.5) then
            Loot(craft):insert(upgradeGenerator:generateSectorSystem(x, y, nil, upgradeRarities))
        else
            Loot(craft):insert(InventoryTurret(turretGenerator:generate(x, y)))
        end
    end

    ShipAI(craft.index):setAggressive()
    craft:setTitle("${toughness}${title}", {toughness = "", title = title})
    craft.shieldDurability = craft.shieldMaxDurability

    craft:setValue("is_pirate", true)
end


return PirateGenerator
