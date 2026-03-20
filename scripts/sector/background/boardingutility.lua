
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("defaultscripts")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace BoardingUtility
BoardingUtility = {}

local forbidden = {}
forbidden["data/scripts/entity/antismuggle.lua"] = true
forbidden["data/scripts/entity/blocker.lua"] = true
forbidden["data/scripts/entity/civilship.lua"] = true
forbidden["data/scripts/entity/claim.lua"] = true
forbidden["data/scripts/entity/claimalliance.lua"] = true
forbidden["data/scripts/entity/deleteonplayersleft.lua"] = true
forbidden["data/scripts/entity/utility/fleeondamaged.lua"] = true
forbidden["data/scripts/entity/deletejumped.lua"] = true
forbidden["data/scripts/entity/removeinvincibilityonsectorchanged.lua"] = true
forbidden["data/scripts/sector/factionwar/temporarydefender.lua"] = true

if onServer() then

function BoardingUtility.initialize()
    local sector = Sector()
    sector:registerCallback("onBoardingSuccessful", "onBoardingSuccessful")
end

function BoardingUtility.onBoardingSuccessful(id, oldFactionIndex, newFactionIndex)
    local newFaction = Faction(newFactionIndex)
    if not newFaction then return end

    -- only update scripts if a player now owns the craft
    if not newFaction.isAIFaction then
        local entity = Entity(id)

        BoardingUtility.updateScripts(entity)
        BoardingUtility.clearScriptValues(entity)

        entity.damageMultiplier = 1.0
        entity.dockable = true

        local cargoBay = CargoBay(id)
        if cargoBay then
            cargoBay.fixedSize = false
        end

        local ai = ShipAI(entity)
        if ai then
            ai:clearFriendFactions()
            ai:clearEnemyFactions()
            ai:clearFriendEntities()
            ai:clearEnemyEntities()
        end

        local shield = Shield(id)
        if shield then
            shield:resetResistance()
            shield.maxDurabilityFactor = 1.0
        end

        local durability = Durability(id)
        if durability then
            durability:resetWeakness()
            durability.invincibility = 0.0
            durability.maxDurabilityFactor = 1.0
        end
    end

end

function BoardingUtility.clearScriptValues(entity)
    entity:clearValues()
end

function BoardingUtility.updateScripts(entity)
--    print("update scripts")

    for index, name in pairs(entity:getScripts()) do
        if string.match(name, "data/scripts/entity/ai/") or
                string.match(name, "data/scripts/entity/dialogs/") or
                string.match(name, "data/scripts/entity/story/") or
                string.match(name, "data/scripts/entity/utility/") or
                string.match(name, "rift/entity/") or
                string.match(name, "blackmarket/entity/") or
                string.match(name, "data/scripts/entity/merchants/") then

--            print("removing script '" .. name .. "'")
            entity:removeScript(index)

        elseif forbidden[name] then
--            print("removing script  '" .. name .. "'")
            entity:removeScript(index)
        end
    end

    if entity.type == EntityType.Ship then
        AddDefaultShipScripts(entity)
    elseif entity.type == EntityType.Station then
        AddDefaultStationScripts(entity)
        SetBoardingDefenseLevel(entity)

        local type = entity:getValue("factory_type")
        if type and type == "mine" then
            entity:addScript("data/scripts/entity/derelictminefounder.lua")
        else
            entity:addScript("data/scripts/entity/derelictstationfounder.lua")
        end
    end
end

end
