package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("stringutility")
include ("galaxy")
local ShipUtility = include("shiputility")
local PlanGenerator = include ("plangenerator")
local SectorTurretGenerator = include ("sectorturretgenerator")

local Yavana = {}

function Yavana.find()
    return Sector():getEntitiesByScriptValue("itr_yavana")
end

function Yavana.spawnOrFind(position)
    -- don't double-spawn
    local present = Yavana.find()
    if present then return present end

    position = position or Matrix()

    local faction = Yavana.getFaction()

    local sector = Sector()
    local x, y = sector:getCoordinates()

    -- yavana gets ship in ravager size
    local volume = Balancing_GetSectorShipVolume(x, y) * 6.0
    local material = Material(MaterialType.Trinium)
    local plan = PlanGenerator.makeShipPlan(faction, volume, nil, material)

    local ship = sector:createShip(faction, "", plan, position)

    -- with turrets of 50 sectors further to the center
    local direction = normalize(vec2(x, y))
    local dist = math.max(0, length(vec2(x, y)) - 50)
    local coordinates = direction * dist

    local turret = SectorTurretGenerator():generate(coordinates.x, coordinates.y, 0, Rarity(RarityType.Exceptional), WeaponType.RailGun)
    local numTurrets = Balancing_GetEnemySectorTurrets(coordinates.x, coordinates.y)
    ShipUtility.addTurretsToCraft(ship, turret, numTurrets)

    ship.title = "Yavana"%_T
    ship:addScript("deleteonplayersleft.lua")
    ship:setValue("no_attack_events", true)
    ship:setValue("itr_yavana", true)

    ship.shieldDurability = ship.shieldMaxDurability
    ship.crew = ship.idealCrew
    ship.invincible = true
    Boarding(ship).boardable = false
    ship.dockable = false

    return ship
end

function Yavana.getFaction()
    local name = "Lone Hunter"%_T
    local faction = Galaxy():findFaction(name)
    if faction == nil then
        faction = Galaxy():createFaction(name, 300, 0)
        faction.initialRelations = 100000
        faction.initialRelationsToPlayer = 100000
        faction.staticRelationsToPlayers = true
    end

    faction.initialRelationsToPlayer = 100000
    faction.staticRelationsToPlayers = true
    faction.homeSectorUnknown = true

    return faction
end

return Yavana
