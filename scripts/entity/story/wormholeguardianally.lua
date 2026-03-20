
package.path = package.path .. ";data/scripts/lib/?.lua"

include ("stringutility")
include ("callable")

function interactionPossible(playerIndex, option)
   return true
end

function initUI()
    ScriptUI():registerInteraction("Attack the Guardian!"%_t, "onAttackGuardian")
    ScriptUI():registerInteraction("Attack the small ships!"%_t, "onAttackShips")
end


function getAlliedShips()
    local allies = {Sector():getEntitiesByScript("entity/story/wormholeguardianally.lua")}
    local guardian = Sector():getEntitiesByScript("entity/story/wormholeguardian.lua")

    return allies, guardian
end

function initialize()

    if onServer() then
        local allies = {Sector():getEntitiesByScript("entity/story/wormholeguardianally.lua")}

        local self = Entity()
        local selfAI = ShipAI()

        for _, ally in pairs(allies) do

            if self.index == ally.index then goto continue end

            ShipAI(ally):registerFriendFaction(self.factionIndex)
            selfAI:registerFriendFaction(ally.factionIndex)

            ::continue::
        end
    end

end

function onAttackGuardian()

    if onClient() then
        invokeServerFunction("onAttackGuardian")
        return
    end

    local allies, guardian = getAlliedShips()
    if not guardian then return end

    for _, ally in pairs(allies) do

        for index, name in pairs(ally:getScripts()) do
            if string.match(name, "data/scripts/entity/ai/") then
                ally:removeScript(index)
            end
        end

        local ai = ShipAI(ally)
        ai:setAttack(guardian)
        ai:registerEnemyEntity(guardian.id)
    end

end
callable(nil, "onAttackGuardian")

function onAttackShips()

    if onClient() then
        invokeServerFunction("onAttackShips")
        return
    end

    local allies, guardian = getAlliedShips()
    if not guardian then return end

    for _, ally in pairs(allies) do
        ally:addScript("data/scripts/entity/ai/patrol.lua")
        ShipAI(ally.index):registerFriendEntity(guardian.id)
    end

end
callable(nil, "onAttackShips")
