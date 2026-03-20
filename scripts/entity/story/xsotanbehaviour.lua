package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("randomext")
Balancing = include("galaxy")
local RiftMissionUT = include("dlc/rift/lib/riftmissionutility")
local CaptainClass = include("captainclass")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace XsotanBehaviour
XsotanBehaviour = {}

local provoked = nil

if onServer() then

function XsotanBehaviour.initialize()
    Sector():registerCallback("onTorpedoLaunched", "onSetToAggressive")
    Sector():registerCallback("onStartFiring", "onSetToAggressive")
    Sector():registerCallback("onDestroyed", "onXsotanDestroyed")
    Entity():registerCallback("onDestroyed", "onSelfDestroyed")
    Entity():registerCallback("onCollision", "onCollision")

    XsotanBehaviour.despawnSoon()
end

function XsotanBehaviour.despawnSoon()
    -- they don't despawn inside the ring
    local x, y = Sector():getCoordinates()
    if Balancing_InsideRing(x, y) then return end
    if Entity():getValue("xsotan_no_despawn") then return end

    -- don't despawn in rifts
    if Galaxy():sectorInRift(x, y) then return end

    provoked = false
    deferredCallback(60 + math.random() * 4, "tryDespawn")
end

function XsotanBehaviour.tryDespawn()
    if Entity():getValue("xsotan_no_despawn") then return end

    if provoked then
        XsotanBehaviour.despawnSoon()
    else
        Entity():addScriptOnce("deletejumped.lua")
    end
end

function XsotanBehaviour.onSetToAggressive(entityId)
    local entity = Entity(entityId)
    if not valid(entity) then return end

    local entityFaction = entity.factionIndex or 0
    if entityFaction <= 0 then return end

    local shipAI = ShipAI()
    for _, id in pairs({shipAI:getRegisteredFriendFactions()}) do
        if id == entityFaction then
            return
        end
    end

    local self = Entity()
    if entityFaction ~= self.factionIndex then
        shipAI:registerEnemyFaction(entityFaction)
    end

    provoked = true
end

function XsotanBehaviour.onCollision(selfId, other, dmgA, dmgB, steererA, steererB)
    XsotanBehaviour.onSetToAggressive(steererB)
end

function XsotanBehaviour.onXsotanDestroyed(destroyedId, lastDamageInflictor)
    local entity = Entity(lastDamageInflictor)
    if not entity then return end

    local entityFaction = entity.factionIndex or 0
    if entityFaction <= 0 then return end

    local self = Entity()
    if entityFaction ~= self.factionIndex then
        ShipAI():registerEnemyFaction(entityFaction)
    end

    provoked = true
end

function XsotanBehaviour.onSelfDestroyed()
    local sector = Sector()
    local x, y = sector:getCoordinates()
    local position = vec2(x, y)

    if length2(position) < Balancing.BlockRingMin2 then
        if random():getInt(1, 3) == 1 then

            local entity = Entity()
            sector:dropUpgrade(
                entity.translationf,
                nil,
                nil,
                SystemUpgradeTemplate("data/scripts/systems/wormholeopener.lua", Rarity(RarityType.Rare), Seed(0)))
        end
    end

    XsotanBehaviour.tryDropResearchData()
end

function XsotanBehaviour.tryDropResearchData()
    local sector = Sector()
    local x, y = sector:getCoordinates()

    if not Galaxy():sectorInRift(x, y) then return end

    local entity = Entity()
    if entity:getValue("xsotan_no_research_data") then return end

    local good = RiftMissionUT.getRiftDataGood()

    for _, player in pairs({sector:getPlayers()}) do
        if random():test(0.15) then

            local dropped = 1
            local ships = {sector:getEntitiesByFaction(player.index)}
            for _, ship in pairs(ships) do
                if ship.type == EntityType.Ship then
                    local crew = CrewComponent(ship)
                    if crew and crew:hasCaptain(CaptainClass.Scientist) then
                        dropped = 3
                        break
                    end
                end
            end

            for i = 1, dropped do
                sector:dropCargo(entity.translationf, player, nil, good, 0, 1)
            end
        end
    end
end


end
