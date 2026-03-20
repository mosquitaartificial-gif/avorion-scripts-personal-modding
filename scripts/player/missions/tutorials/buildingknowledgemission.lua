package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")
local MissionUT = include("missionutility")
local BuildingKnowledgeUT = include("buildingknowledgeutility")

mission.data.brief = {text = "Building Knowledge: Tier ${tier} - ${material}"%_T}
mission.data.title = {text = "Building Knowledge: Tier ${tier} - ${material}"%_T}
mission.data.icon = "data/textures/icons/building-knowledge.png"
mission.data.priority = 8 -- higher than other tutorials, but not as high as story missions
mission.data.autoTrackMission = true

-- custom messages - this is not a true mission
mission.data.silent = true
local smallTextCollected = "Acquired"%_T
local smallTextUnlocked = "Unlocked"%_T
local customMessage = "BUILDING KNOWLEDGE"%_t
mission.data.custom.materialType = nil

mission.data.description = {}
-- careful: these are duplicated in updateDescription() for legacy purposes
mission.data.description[1] = {text = "Acquire Tier ${tier} Building Knowledge for ${material}:"%_T}
mission.data.description[2] = {text = "Fly closer to the center of the galaxy"%_T, bulletPoint = true, visible = false}
mission.data.description[3] = {text = "Fly further away from the center of the galaxy"%_T, bulletPoint = true, visible = false}
mission.data.description[4] = {text = "(optional) Clear a pirate sector"%_T, bulletPoint = true, visible = false}
mission.data.description[5] = {text = "(optional) Gain 65.000 reputation and buy it at a Shipyard"%_T, bulletPoint = true, visible = false}
mission.data.description[6] = {text = "(optional) Buy it for ores at a Resource Depot"%_T, bulletPoint = true, visible = false}
mission.data.description[7] = {text = "(optional) Buy it for a ridiculously high price at a Smuggler's Market"%_T, bulletPoint = true, visible = false}
mission.data.description[8] = {text = "Activate the Building Knowledge from your inventory"%_T, bulletPoint = true, visible = false}

local function getMissionText(materialType)
    local material = Material(materialType)

    return "Tier ${tier} - ${material}"%_t % {tier = toRomanLiterals(material.value + 1), material = material.name}
end

-- wait for material to be set
mission.phases[1] = {}

-- mission starts
mission.phases[2] = {}
mission.phases[2].onBeginClient = function()
    displayMissionAccomplishedText(customMessage, getMissionText(mission.data.custom.materialType))
end
mission.phases[2].updateServer = function()
    local player = Player()
    if mission.data.custom.materialType and BuildingKnowledgeUT.hasKnowledge(player, Material(mission.data.custom.materialType)) then
        -- we have it, but callback failed us
        updateDescription(3)
        setPhase(3)
    end
end
mission.phases[2].updateInterval = 10
mission.phases[2].onSectorArrivalConfirmed = function(player, x, y)
    updateDescription(2)
end
mission.phases[2].playerCallbacks = {}
mission.phases[2].playerCallbacks[1] =
{
    name = "onItemAdded",
    func = function(index)
        if onClient() then return end

        local player = Player()
        local inventory = player:getInventory()
        local item = inventory:find(index)

        if item and item.itemType == InventoryItemType.UsableItem and item:getValue("subtype") == "BuildingKnowledge" then
            if item:getValue("material") == mission.data.custom.materialType then
                invokeClientFunction(Player(), "showItemCollected", smallTextCollected)
                setPhase(3)
            end
        end
    end
}

mission.phases[3] = {}
mission.phases[3].onBeginServer = function()
    updateDescription(3)
end
mission.phases[3].updateServer = function()
    local player = Player()
    if player.maxBuildableMaterial.value >= mission.data.custom.materialType then
        invokeClientFunction(Player(), "showItemCollected", smallTextUnlocked)
        terminate() -- we accomplished our mission to get player the building knowledge
        return
    end

    if not BuildingKnowledgeUT.hasKnowledge(player, Material(mission.data.custom.materialType)) then
        -- knowledge got lost somehow => return to phase 2
        updateDescription(2)
        setPhase(2)
    end
end

-- set material
function setUsedBuildingKnowledge(knowledge)
    if onClient() then return end

    mission.data.custom.materialType = knowledge
    local materialName = Material(mission.data.custom.materialType).name
    mission.data.brief.arguments = {material = materialName, tier = toRomanLiterals(knowledge + 1)}
    mission.data.title.arguments = {material = materialName, tier = toRomanLiterals(knowledge + 1)}
    mission.data.description[1].arguments = {material = materialName, tier = toRomanLiterals(knowledge + 1)}
    updateDescription(2)
    sync() -- sync early to make absolutely sure client has correct values when showing new mission banner

    setPhase(2)
end

function showItemCollected(smallText)
    displayMissionAccomplishedText(customMessage % _t, "${missionText} ${status}"%_t % {missionText = getMissionText(mission.data.custom.materialType), status = smallText % _t})
end

function updateDescription(index)
    -- check player has new descriptions
    if #mission.data.description < 8 then
        mission.data.description[4] = {text = "(optional) Clear a pirate sector"%_T, bulletPoint = true, visible = false}
        mission.data.description[5] = {text = "(optional) Gain 65.000 reputation and buy it at a Shipyard"%_T, bulletPoint = true, visible = false}
        mission.data.description[6] = {text = "(optional) Buy it for ores at a Resource Depot"%_T, bulletPoint = true, visible = false}
        mission.data.description[7] = {text = "(optional) Buy it for a ridiculously high price at a Smuggler's Market"%_T, bulletPoint = true, visible = false}
        mission.data.description[8] = {text = "Activate the Building Knowledge from your inventory"%_T, bulletPoint = true, visible = false}
    end

    -- hide all descriptions
    for i = 2, #mission.data.description do
        mission.data.description[i].visible = false
        mission.data.description[i].fulfilled = false
    end

    if index <= 2 then
        -- check which descriptions to show
        local localMaterial = BuildingKnowledgeUT.getLocalKnowledgeMaterial(x, y)
        local localType = localMaterial.value
        local myType = mission.data.custom.materialType

        if localType < myType then
            -- too far out
            mission.data.description[2].visible = true

        elseif localType == myType then
            -- right place: show options
            for i = 4, 7 do
                mission.data.description[i].visible = true
            end

        else
            -- too far in
            mission.data.description[3].visible = true
        end
    elseif index == 3 then
        for i = 4, 7 do
            mission.data.description[i].visible = true
            mission.data.description[i].fulfilled = true
        end

        mission.data.description[8].visible = true
    end

    sync()
end

function getKnowledgeType()
    return mission.data.custom.materialType
end
