package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
local MissionUT = include("missionutility")

local BuildingKnowledgeUT = {}
BuildingKnowledgeUT.titaniumMailId = "building_knowledge_titanium"

function BuildingKnowledgeUT.getLocalKnowledgeMaterial(x, y)
    if not x or not y then
        local sector = Sector()
        x, y = sector:getCoordinates()
    end

    local distances = {}
    table.insert(distances, {material = MaterialType.Avorion, distance = 75})
    table.insert(distances, {material = MaterialType.Ogonite, distance = 145})
    table.insert(distances, {material = MaterialType.Xanion, distance = 210})
    table.insert(distances, {material = MaterialType.Trinium, distance = 290})
    table.insert(distances, {material = MaterialType.Naonite, distance = 360})
    table.insert(distances, {material = MaterialType.Titanium, distance = 420})

    local distance = length(vec2(x, y))

    local material = Material(MaterialType.Iron)
    for _, entry in pairs(distances) do
        if distance < entry.distance then
            material = Material(entry.material)
            break
        end
    end

    return material
end

function BuildingKnowledgeUT.getLocalKnowledge(x, y, playerIndex)
    local material = BuildingKnowledgeUT.getLocalKnowledgeMaterial(x, y)
    local item = UsableInventoryItem("buildingknowledge.lua", Rarity(RarityType.Exotic), material, playerIndex)

    return item, material
end

function BuildingKnowledgeUT.getSockets(material)
    local sockets = {}
    sockets[0] = 4
    sockets[1] = 5
    sockets[2] = 6
    sockets[3] = 8
    sockets[4] = 10
    sockets[5] = 12
    sockets[6] = 15

    return sockets[material.value] or sockets[1]
end

function BuildingKnowledgeUT.makeKnowledge(playerIndex, material)
    local item = UsableInventoryItem("buildingknowledge.lua", Rarity(RarityType.Exotic), material, playerIndex)

    return item
end

function BuildingKnowledgeUT.hasKnowledge(player, material)

    if player.maxBuildableMaterial >= material then return true end

    local items = player:getInventory():getItemsByType(InventoryItemType.UsableItem)
    for idx, slot in pairs(items) do
        local amount = slot.amount
        local item = slot.item

        -- we assume they're stackable, so we return here
        if item:getValue("subtype") == "BuildingKnowledge"
                and item:getValue("material") == material.value then

            return true, item, idx
        end
    end
end

function BuildingKnowledgeUT.qualifiesForTitaniumKnowledgeMail(player)
    local material = Material(MaterialType.Titanium)
    if player.maxBuildableMaterial >= material then return end

    -- check if there is still a mail lingering around with the titanium knowledge
    local mails = {player:getMailsById(BuildingKnowledgeUT.titaniumMailId)}
    for _, mail in pairs(mails) do
        -- we're always sending the item in that mail, so we don't have to check the actual item
        if mail.numItems > 0 then
            return
        end
    end

    -- check if the player has already got the knowledge
    local _, titanium = player:getResources()
    if titanium > 0 and not player.infiniteResources then
        return not BuildingKnowledgeUT.hasKnowledge(player, material)
    end
end

function BuildingKnowledgeUT.sendTitaniumMail(player)
    local mail = Mail()
    mail.text = Format("Hello!\n\nI see you found some Titanium! That's great, congratulations! Since I still feel like I'm in your debt, I'd like to give you this. I still have this from a few years ago and I'm sure it will help you out.\n\nGreetings,\n%1%"%_T, MissionUT.getAdventurerName())
    mail.header = "Titanium! /* Mail Subject */"%_T
    mail.sender = Format("%1%, the Adventurer"%_T, MissionUT.getAdventurerName())
    mail.id = BuildingKnowledgeUT.titaniumMailId

    local item = UsableInventoryItem("buildingknowledge.lua", Rarity(RarityType.Exotic), Material(MaterialType.Titanium), player.index)
    mail:addItem(item)

    player:addMail(mail)

end

function BuildingKnowledgeUT.qualifiesForNaoniteKnowledgeMail(player)
    local material = Material(MaterialType.Naonite)
    if player.maxBuildableMaterial >= material then return end

    -- check if player already received the hint
    if player:getValue("naonite_knowledge_mail_hint") then return end

    -- check if the player has already got the knowledge
    local _, _, naonite = player:getResources()
    if naonite > 0 and not player.infiniteResources then
        return not BuildingKnowledgeUT.hasKnowledge(player, material)
    end
end

function BuildingKnowledgeUT.sendNaoniteMail(player)
    local mail = Mail()
    mail.text = Format("Hello!\n\nAnd now you've got some Naonite! You're progressing well! Naonite is even better than Titanium, and not just because it's more durable. With Naonite, you can build shield generators!\n\nSadly, I don't have any more building knowledge that I could give you. You should try your luck with a shipyard in the Naonite area. Or maybe you can loot some from pirates with Naonite ships? They must have built them somehow!\n\nGreetings,\n%1%"%_T, MissionUT.getAdventurerName())
    mail.header = "Next Step: Naonite! /* Mail Subject */"%_T
    mail.sender = Format("%1%, the Adventurer"%_T, MissionUT.getAdventurerName())

    player:addMail(mail)
    player:setValue("naonite_knowledge_mail_hint", true)
end

function BuildingKnowledgeUT.qualifiesForBuildingKnowledgeMission(player, x, y)
    -- check if the player has already got the knowledge
    local localMaterial = BuildingKnowledgeUT.getLocalKnowledgeMaterial(x, y)
    if BuildingKnowledgeUT.hasKnowledge(player, localMaterial) then
        return 0
    end

    -- no mission for titanium and iron
    if localMaterial == Material(MaterialType.Iron) or localMaterial == Material(MaterialType.Titanium) then
        return 0
    end

    -- check if player already has a mission for this material
    for index, script in pairs(player:getScripts()) do
        if script == "data/scripts/player/missions/tutorials/buildingknowledgemission.lua" then
            local ok, missionKnowlegeType = player:invokeFunction(index, "getKnowledgeType")
            if ok and missionKnowlegeType == localMaterial.value then
                return 0
            end
        end
    end

    return localMaterial.value
end

function BuildingKnowledgeUT.addBuildingKnowledgeMission(player, materialType)
    local script = player:addScript("data/scripts/player/missions/tutorials/buildingknowledgemission.lua")
    player:invokeFunction(script, "setUsedBuildingKnowledge", materialType)
end

return BuildingKnowledgeUT
