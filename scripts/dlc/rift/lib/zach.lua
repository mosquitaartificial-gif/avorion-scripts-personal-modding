package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("stringutility")
local ShipUtility = include("shiputility")

local Zach = {}

function Zach.find()
    local present = Sector():getEntitiesByScriptValue("itr_zach")
    return present
end

function Zach.spawnOrFind(position)

    -- don't double-spawn
    local present = Zach.find()
    if present then return present end

    position = position or Matrix()

    local faction = Zach.getFaction()

    local plan = LoadPlanFromFile("data/plans/zach.xml")
    plan:setMaterial(Material(MaterialType.Trinium))

    local ship = Sector():createShip(faction, "", plan, position)
    ShipUtility.addArmedTurretsToCraft(ship, 10)

    ship.title = "Zach"%_T
    ship:addScript("deleteonplayersleft.lua")
    ship:setValue("no_attack_events", true)
    ship:setValue("itr_zach", true)

    ship.shieldDurability = ship.shieldMaxDurability
    ship.crew = ship.idealCrew
    ship.invincible = true
    Boarding(ship).boardable = false
    ship.dockable = false

    return ship
end

function Zach.find()
    return Sector():getEntitiesByScriptValue("itr_zach")
end

function Zach.getFaction()
    local name = "Von Überstein"%_T
    local faction = Galaxy():findFaction(name)
    if faction == nil then
        faction = Galaxy():createFaction(name, 0, 0)
        faction.initialRelations = 100000
        faction.initialRelationsToPlayer = 100000
        faction.staticRelationsToPlayers = true
    end

    faction.initialRelationsToPlayer = 100000
    faction.staticRelationsToPlayers = true
    faction.homeSectorUnknown = true

    return faction
end

return Zach
