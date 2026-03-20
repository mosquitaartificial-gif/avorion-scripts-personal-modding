package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("galaxy")
include ("utility")
include ("defaultscripts")
include ("goods")
local PlanGenerator = include ("plangenerator")
local ShipUtility = include ("shiputility")
local SectorFighterGenerator = include("sectorfightergenerator")

local ShipGenerator = {}

function ShipGenerator.createShip(faction, position, volume)
    position = position or Matrix()
    volume = volume or Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation()

    local plan = PlanGenerator.makeShipPlan(faction, volume)
    local ship = Sector():createShip(faction, "", plan, position)

    ship.crew = ship.idealCrew
    ship.shieldDurability = ship.shieldMaxDurability

    AddDefaultShipScripts(ship)
    SetBoardingDefenseLevel(ship)

    return ship
end

function ShipGenerator.createDefender(faction, position)
    -- defenders should be a lot beefier than the normal ships
    local volume = Balancing_GetSectorShipVolume(faction:getHomeSectorCoordinates()) * 7.5

    local ship = ShipGenerator.createShip(faction, position, volume)
    local turrets = Balancing_GetEnemySectorTurrets(Sector():getCoordinates()) * 2 + 3
    turrets = turrets + turrets * math.max(0, faction:getTrait("careful") or 0) * 0.5

    ShipUtility.addArmedTurretsToCraft(ship, turrets)
    ship.crew = ship.idealCrew
    ship.title = ShipUtility.getMilitaryNameByVolume(ship.volume)
    ship.shieldDurability = ship.shieldMaxDurability
    ship.damageMultiplier = ship.damageMultiplier * 4

    ship:addScript("ai/patrol.lua")
    ship:addScript("antismuggle.lua")
    ship:setValue("is_armed", true)
    ship:setValue("is_defender", true)
    ship:setValue("npc_chatter", true)

    ship:addScript("icon.lua", "data/textures/icons/pixel/defender.png")

    return ship
end

function ShipGenerator.createCarrier(faction, position, fighters)
    -- carriers should be even beefier than the defenders
    position = position or Matrix()
    fighters = fighters or 10
    local volume = volume or Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation()

    local plan = PlanGenerator.makeCarrierPlan(faction, volume)
    local ship = Sector():createShip(faction, "", plan, position)

    ship.shieldDurability = ship.shieldMaxDurability

    -- add fighters
    local hangar = Hangar(ship.index)
    hangar:addSquad("Alpha")
    hangar:addSquad("Beta")
    hangar:addSquad("Gamma")

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


    ship.crew = ship.idealCrew

    local turrets = Balancing_GetEnemySectorTurrets(Sector():getCoordinates())

    ShipUtility.addArmedTurretsToCraft(ship, turrets)
    ship.crew = ship.idealCrew
    ship.title = ShipUtility.getMilitaryNameByVolume(ship.volume)

    ship:addScript("ai/patrol.lua")
    ship:setValue("is_armed", true)

    ship:addScript("icon.lua", "data/textures/icons/pixel/carrier.png")

    return ship
end

function ShipGenerator.createMilitaryShip(faction, position, volume)
    local ship = ShipGenerator.createShip(faction, position, volume)

    local turrets = Balancing_GetEnemySectorTurrets(Sector():getCoordinates())

    ShipUtility.addArmedTurretsToCraft(ship, turrets)
    ship.crew = ship.idealCrew
    ship.title = ShipUtility.getMilitaryNameByVolume(ship.volume)
    ship.shieldDurability = ship.shieldMaxDurability

    ship:setValue("is_armed", true)

    ship:addScript("icon.lua", "data/textures/icons/pixel/military-ship.png")

    return ship
end

function ShipGenerator.createTradingShip(faction, position, volume)
    local ship = ShipGenerator.createShip(faction, position, volume)

    if math.random() < 0.5 then
        local turrets = Balancing_GetEnemySectorTurrets(Sector():getCoordinates())

        ShipUtility.addArmedTurretsToCraft(ship, turrets)
    end

    ship.crew = ship.idealCrew
    ship.title = ShipUtility.getTraderNameByVolume(ship.volume)
    ship.shieldDurability = ship.shieldMaxDurability

    ship:addScript("civilship.lua")
    ship:addScript("dialogs/storyhints.lua")
    ship:setValue("is_civil", true)
    ship:setValue("is_trader", true)
    ship:setValue("npc_chatter", true)

    ship:addScript("icon.lua", "data/textures/icons/pixel/civil-ship.png")

    return ship
end

function ShipGenerator.createFreighterShip(faction, position, volume)
    position = position or Matrix()
    volume = volume or Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation()

    local plan = PlanGenerator.makeFreighterPlan(faction, volume)
    local ship = Sector():createShip(faction, "", plan, position)

    ship.shieldDurability = ship.shieldMaxDurability
    ship.crew = ship.idealCrew

    AddDefaultShipScripts(ship)

    if math.random() < 0.5 then
        local turrets = Balancing_GetEnemySectorTurrets(Sector():getCoordinates())

        ShipUtility.addArmedTurretsToCraft(ship, turrets)
    end

    ship.crew = ship.idealCrew
    ship.title = ShipUtility.getFreighterNameByVolume(ship.volume)

    ship:addScript("civilship.lua")
    ship:addScript("dialogs/storyhints.lua")
    ship:setValue("is_civil", true)
    ship:setValue("is_freighter", true)
    ship:setValue("npc_chatter", true)

    ship:addScript("icon.lua", "data/textures/icons/pixel/civil-ship.png")

    return ship
end

function ShipGenerator.createMiningShip(faction, position, volume)
    position = position or Matrix()
    volume = volume or Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation()

    local plan = PlanGenerator.makeMinerPlan(faction, volume)
    local ship = Sector():createShip(faction, "", plan, position)

    ship.shieldDurability = ship.shieldMaxDurability
    ship.crew = ship.idealCrew

    AddDefaultShipScripts(ship)

    local turrets = Balancing_GetEnemySectorTurrets(Sector():getCoordinates())

    ShipUtility.addUnarmedTurretsToCraft(ship, turrets)
    ship.crew = ship.idealCrew
    ship.title = ShipUtility.getMinerNameByVolume(ship.volume)
    ship.shieldDurability = ship.shieldMaxDurability

    ship:addScript("civilship.lua")
    ship:addScript("dialogs/storyhints.lua")
    ship:setValue("is_civil", true)
    ship:setValue("is_miner", true)
    ship:setValue("npc_chatter", true)

    ship:addScript("icon.lua", "data/textures/icons/pixel/civil-ship.png")

    return ship
end

return ShipGenerator
