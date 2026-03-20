package.path = package.path .. ";data/scripts/lib/?.lua"

local BuildingKnowledgeUT = include("buildingknowledgeutility")
include("stringutility")

function execute(sender, commandName, ...)
    local args = {...}

    local id = args[1] or ""
    local mat = string.lower(args[2] or "iron")

    local player = Galaxy():findPlayer(id)
    if not player then
        return 1, "", "Player with id '" .. id .. "' not found"
    end

    local knowledge

    local reset = false
    if mat == "reset" then
        mat = "iron"
        reset = true
    end

    if mat == "iron" then
        mat = Material(MaterialType.Iron)
    elseif mat == "titanium" then
        mat = Material(MaterialType.Titanium)
    elseif mat == "naonite" then
        mat = Material(MaterialType.Naonite)
    elseif mat == "trinium" then
        mat = Material(MaterialType.Trinium)
    elseif mat == "xanion" then
        mat = Material(MaterialType.Xanion)
    elseif mat == "ogonite" then
        mat = Material(MaterialType.Ogonite)
    elseif mat == "avorion" then
        mat = Material(MaterialType.Avorion)
    else
        return 1, "", "Unknown material: '" .. mat .. "'"
    end

    local item = UsableInventoryItem("buildingknowledge.lua", Rarity(RarityType.Exotic), mat, player.index)

    if reset then
        player.maxBuildableMaterial = Material(MaterialType.Iron)
        player.maxBuildableSockets = item:getValue("sockets") or 4

        Player():sendChatMessage("", ChatMessageType.Information, "Your building knowledge has been reset."%_T)
    else
        player:getInventory():add(item, true)
    end

    return 0, "", ""
end

function getDescription()
    return "Gives building knowledge to a player or resets it."
end

function getHelp()
    return "Usage: /knowledge [player] [material/reset]"
end
