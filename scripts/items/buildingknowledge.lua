package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("utility")
include("stringutility")
local BuildingKnowledgeUT = include("buildingknowledgeutility")


function getName(material)
    local names = {}
    names[0] = "Building Knowledge Tier I"%_t
    names[1] = "Building Knowledge Tier II"%_t
    names[2] = "Building Knowledge Tier III"%_t
    names[3] = "Building Knowledge Tier IV"%_t
    names[4] = "Building Knowledge Tier V"%_t
    names[5] = "Building Knowledge Tier VI"%_t
    names[6] = "Building Knowledge Tier VII"%_t

    return names[material.value] or names[1]
end

function getPrevious(material)
    local names = {}
    names[1] = "Requires Tier I knowledge about Iron."%_t
    names[2] = "Requires Tier II knowledge about Titanium."%_t
    names[3] = "Requires Tier III knowledge about Naonite."%_t
    names[4] = "Requires Tier IV knowledge about Trinium."%_t
    names[5] = "Requires Tier V knowledge about Xanion."%_t
    names[6] = "Requires Tier VI knowledge about Ogonite."%_t

    return names[material.value] or names[1]
end

function getPrice(material)
    local prices = {}
    prices[0] = 50000
    prices[1] = 250000
    prices[2] = 750000
    prices[3] = 1500000
    prices[4] = 3000000
    prices[5] = 5000000
    prices[6] = 10000000

    return prices[material.value] or prices[1]
end

function create(item, rarity, material, playerIndex)

    if type(material) == "number" then material = Material(material) end

    local name = getName(material)
    local sockets = BuildingKnowledgeUT.getSockets(material)

    item.stackable = false
    item.depleteOnUse = true
    item.name = name
    item.price = getPrice(material)
    item.icon = "data/textures/icons/building-knowledge.png"
    item.rarity = rarity
    item:setValue("subtype", "BuildingKnowledge")
    item:setValue("material", material.value)
    item:setValue("sockets", sockets)
    item:setValue("unsellable", true)
    if playerIndex then
        item.boundFaction = playerIndex
    end
    item.droppable = false

    local tooltip = Tooltip()
    tooltip.icon = item.icon
    tooltip.borderColor = material.color

    local title = name

    local headLineSize = 25
    local headLineFontSize = 15
    local line = TooltipLine(headLineSize, headLineFontSize)
    line.ctext = title
    line.ccolor = material.color
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 14)
    line.ltext = "Material"%_t
    line.rtext = material.name
    line.lcolor = material.color
    line.rcolor = material.color
    line.icon = "data/textures/icons/metal-bar.png"
    line.iconColor = material.color
    tooltip:addLine(line)

    local settings = GameSettings()
    if not settings.unlimitedProcessingPower then
        local line = TooltipLine(20, 14)
        line.ltext = "Subsystem Sockets"%_t
        line.rtext = sockets
        line.icon = "data/textures/icons/circuitry.png"
        line.iconColor = ColorRGB(0.8, 0.8, 0.8)
        tooltip:addLine(line)
    end

    if playerIndex then
        local line = TooltipLine(20, 14)
        line.ltext = "Bound Player"%_t
        line.rtext = "${faction:"..playerIndex.."}"
        line.icon = "data/textures/icons/player.png"
        line.iconColor = ColorRGB(0.8, 0.8, 0.8)
        tooltip:addLine(line)
    end

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 14)
    line.ltext = "Unlocks building with a new material."%_t
    tooltip:addLine(line)

    if not settings.unlimitedProcessingPower then
        local line = TooltipLine(20, 14)
        line.ltext = "Increases buildable ship size."%_t
        tooltip:addLine(line)
    end

    if material.value > 0 then
        local line = TooltipLine(20, 14)
        line.ltext = getPrevious(material)
        tooltip:addLine(line)
    end

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 15)
    line.ltext = "Depleted on Use"%_t
    line.lcolor = ColorRGB(1.0, 1.0, 0.3)
    tooltip:addLine(line)

    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 14)
    line.ltext = "Can be activated by the player"%_t
    tooltip:addLine(line)

    tooltip.price = getPrice(material) * 0.25

    item:setTooltip(tooltip)

    return item
end

function activate(item)

    local player = Player()

    if player.index ~= item.boundFaction then
        return false
    end

    local unlockedMaterial = Material(item:getValue("material") or 0)

    local buildable = player.maxBuildableMaterial
    if unlockedMaterial.value >= 2 and unlockedMaterial.value - buildable.value >= 2 then
        Player():sendChatMessage("", ChatMessageType.Error, "Requires building knowledge about %s."%_T, Material(unlockedMaterial.value - 1).name)
        return false
    end

    if unlockedMaterial.value > buildable.value then
        player.maxBuildableMaterial = unlockedMaterial
    end

    local unlockedSockets = item:getValue("sockets") or 5
    if player.maxBuildableSockets > 0 and unlockedSockets > player.maxBuildableSockets then
        player.maxBuildableSockets = unlockedSockets
    end

    player:sendChatMessage("", ChatMessageType.Information, "You've unlocked the ability to build %s blocks! /* You've unlocked the ability to build Titanium blocks. */"%_T, unlockedMaterial.name)
    player:sendCallback("onBuildingKnowledgeUnlocked", unlockedMaterial.name)

    if unlockedMaterial.value >= 1 then
        player:sendCallback("onShowEncyclopediaArticle", "BuildingKnowledge")
    end

    return true
end
