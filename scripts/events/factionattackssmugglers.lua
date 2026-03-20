
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("galaxy")
include ("randomext")

local AsyncShipGenerator = include("asyncshipgenerator")
local EventUT = include("eventutility")
local FactionEradicationUtility = include("factioneradicationutility")

local smugglerShips = {}
local smugglerFaction
local smugglersMarket
local attackersGenerated = false

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace FactionAttacksSmugglers
FactionAttacksSmugglers = {}

if onServer() then

function FactionAttacksSmugglers.secure()
    return {smugglerShips = smugglerShips}
end

function FactionAttacksSmugglers.restore(data)
    smugglerShips = data.smugglerShips
end

function FactionAttacksSmugglers.initialize()

    local sector = Sector()

    if not EventUT.attackEventAllowed() then
        terminate()
        return
    end

    -- find the smugglers in the sector
    local smugglerStations = {sector:getEntitiesByScript("data/scripts/entity/merchants/smugglersmarket.lua")}

    if #smugglerStations == 0 then
        return
    else
        smugglersMarket = smugglerStations[1]
        smugglerFaction = smugglersMarket.factionIndex
    end

    smugglerShips = {}

    for _, ship in pairs({sector:getEntitiesByType(EntityType.Ship)}) do
        if ship.factionIndex == smugglerFaction then
            smugglerShips[ship.id.string] = true
        end
    end

    FactionAttacksSmugglers.spawnDefenders()
end

function FactionAttacksSmugglers.spawnDefenders()
    local localFaction = Galaxy():getNearestFaction(x, y)
    if FactionEradicationUtility.isFactionEradicated(localFaction.index) then return end

    local numDefenders = 2
    local generator = AsyncShipGenerator(FactionAttacksSmugglers, FactionAttacksSmugglers.onDefendersGenerated)
    local volume = Balancing_GetSectorShipVolume(Sector():getCoordinates())

    generator:startBatch()

    for i = 1, numDefenders do
        local spawnPosition = smugglersMarket.position
        spawnPosition.pos = spawnPosition.pos + random():getDirection() * random():getFloat(50, 100)
        generator:createMilitaryShip(localFaction, FactionAttacksSmugglers.getSpawnPosition(spawnPosition, i))
        if i == 1 then
            generator:createDefender(localFaction, FactionAttacksSmugglers.getSpawnPosition(spawnPosition, i), volume)
        end
    end

    generator:endBatch()
end

function FactionAttacksSmugglers.getSpawnPosition(spawnPosition, index)
    local offset = spawnPosition.look * random():getFloat(300, 350)

    local rightSign = 1
    local upSign = 1
    if index % 2 == 0 then rightSign = -1 end
    if index > 2 then upSign = -1 end

    offset = offset + spawnPosition.right * random():getFloat(30, 100) * rightSign
    offset = offset + spawnPosition.up * random():getFloat(20, 100) * upSign
    return MatrixLookUpPosition(spawnPosition.look, -spawnPosition.up, spawnPosition.pos + offset)
end

function FactionAttacksSmugglers.onDefendersGenerated(generated)
    local speaker = nil
    for _, ship in pairs(generated) do
        if valid(ship) then -- this check is necessary because ships could get destroyed before this callback is executed
            local ai = ShipAI(ship)
            ai:setAggressive()
            ai:registerEnemyFaction(smugglerFaction)

            ship:setValue("smuggler_attacker", true)
            ship:addScriptOnce("data/scripts/entity/ai/patrol.lua")
            ship:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua") -- script gets terminated when all defenders are gone

            speaker = ship
        end
    end

    attackersGenerated = true

    if speaker then
        broadcastInvokeClientFunction("createDefenderChatterBegin", speaker.id.string)
    end
end

function FactionAttacksSmugglers.getUpdateInterval()
    return 15
end

function FactionAttacksSmugglers.update(timeStep)

    if not attackersGenerated then return end

    -- check if all smuggler ships are still there
    local sector = Sector()
    for id, _ in pairs(smugglerShips) do
        local smuggler = sector:getEntity(id)
        if smuggler == nil then
            smugglerShips[id] = nil
        end
    end

    -- if all smuggler ships were defeated: defenders won! (we don't care about the station)
    if tablelength(smugglerShips) == 0 then
        FactionAttacksSmugglers.handleSmugglersDefeated()
    end

    -- check if all defender ships are still there
    if not sector:getEntitiesByScriptValue("smuggler_attacker", true) then
        terminate()
    end
end

function FactionAttacksSmugglers.handleSmugglersDefeated()
    local defenderShips = {Sector():getEntitiesByScriptValue("smuggler_attacker")}
    for _, defender in pairs(defenderShips) do
        broadcastInvokeClientFunction("createDefenderChatterEnd", defender.id.string)
    end

    deferredCallback(8, "endEventSmugglersDefeated")
end

function FactionAttacksSmugglers.endEventSmugglersDefeated()
    local sector = Sector()
    local defenderShips = {sector:getEntitiesByScriptValue("smuggler_attacker")}
    for _, defender in pairs(defenderShips) do
        defender:addScriptOnce("deletejumped.lua")
    end

    terminate()
end

end

if onClient() then

function FactionAttacksSmugglers.createDefenderChatterBegin(id)

    local lines = {
        "We can't have smugglers in our sectors!"%_t,
        "Smugglers, in our sectors? Not with us!"%_t,
        "Smugglers, right under our noses! This ends now!"%_t,
        "By our honor, we'll make these sectors safe again!"%_t,
        "We swear by our honor, we'll punish all unlawful activities!"%_t,
    }

    local defender = Entity(id)
    if valid(defender) then
        displaySpeechBubble(defender, randomEntry(lines))
    end
end

function FactionAttacksSmugglers.createDefenderChatterEnd(id)

    local lines = {
        "We showed them!"%_t,
        "We made our sectors safe again!"%_t,
        "This will show those miscreants that they can't operate right under our noses!"%_t,
        "Lets go boys, we showed those smugglers!"%_t,
        "Our job is done here. We showed them!"%_t,
        "They learned that they shouldn't cross us!"%_t,
    }

    local defender = Entity(id)
    if valid(defender) then
        displaySpeechBubble(defender, randomEntry(lines))
    end
end

end
