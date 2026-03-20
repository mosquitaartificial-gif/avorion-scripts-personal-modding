package.path = package.path .. ";data/scripts/lib/?.lua"

local BuildingKnowledgeUT = include("buildingknowledgeutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace BuildingKnowledgeLoot
BuildingKnowledgeLoot = {}

if onServer() then

BuildingKnowledgeLoot.maximum = MaterialType.Avorion

function BuildingKnowledgeLoot.initialize(maximum)
    Entity():registerCallback("onDestroyed", "onDestroyed")

    if maximum then
        if type(maximum) == "number" then
            BuildingKnowledgeLoot.maximum = maximum
        else
            BuildingKnowledgeLoot.maximum = maximum.value
        end
    end
end

function BuildingKnowledgeLoot.onDestroyed()

    local entity = Entity()
    local sector = Sector()

    local players = {}
    for _, player in pairs({entity:getDamageContributorPlayers()}) do
        players[player] = true
    end

    for _, player in pairs({sector:getPlayers()}) do
        players[player.index] = true
    end

    local x, y = Sector():getCoordinates()
    local material = BuildingKnowledgeUT.getLocalKnowledgeMaterial(x, y)

    -- check that dropped material isn't higher than it should be
    if BuildingKnowledgeLoot.maximum then
        material = Material(math.min(material.value, BuildingKnowledgeLoot.maximum))
    end

    for index, _ in pairs(players) do
        local player = Galaxy():findFaction(index)
        if player and not BuildingKnowledgeUT.hasKnowledge(player, material) then
            local item = BuildingKnowledgeUT.makeKnowledge(player.index, material)

            local loot = Sector():dropUsableItem(entity.translationf, player, nil, item)
            loot.reservationTime = 60 * 60
        end
    end

end

function BuildingKnowledgeLoot.secure()
    return {maximum = BuildingKnowledgeLoot.maximum}
end

function BuildingKnowledgeLoot.restore(data)
    BuildingKnowledgeLoot.maximum = data.maximum
end

end
