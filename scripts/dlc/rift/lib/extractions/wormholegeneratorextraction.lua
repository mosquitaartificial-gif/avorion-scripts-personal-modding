package.path = package.path .. ";data/scripts/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"

local Constraints = include("dlc/rift/lib/constraints")
include("callable")

local WormholeGeneratorExtraction = {}
WormholeGeneratorExtraction.__index = WormholeGeneratorExtraction

local function new(type)
    local extraction = setmetatable({
        type = type,
        name = "Wormhole Generator"%_T,
        icon = "data/textures/icons/wormhole-generator.png",
        script = "dlc/rift/items/wormholegeneratorspawner.lua",
        description = "Use a generator to create a wormhole leading out of the rift."%_t, -- used directly in Mission Board UI

        timeRemainingWarningByPlayer = {},
        isInitialized = false,
        wormholeGenerated = false,
        generatorDeployed = false,
    }, WormholeGeneratorExtraction)

    return extraction
end

function WormholeGeneratorExtraction:initialize(missionData)
    if missionData then
        self.homeCoords = missionData.arguments.homeLocation

        self:initializeDialogCallbacks(missionData)

        self.isInitialized = true
    end
end


function WormholeGeneratorExtraction:initializeDialogCallbacks(missionData)
    if onClient() then
        _G["WormholeGeneratorExtraction_onGiveGenerator"] = function()
            invokeServerFunction("WormholeGeneratorExtraction_onGiveGenerator")
        end
    else
        _G["WormholeGeneratorExtraction_onGiveGenerator"] = function()
            self:giveItemsToPlayer(Player())
        end

        callable(nil, "WormholeGeneratorExtraction_onGiveGenerator")
    end
end

function WormholeGeneratorExtraction:giveItemsToPlayer(player)
    local generatorItem = UsableInventoryItem(self.script, Rarity(RarityType.Exceptional), self.homeCoords.x, self.homeCoords.y)
    local inventory = player:getInventory()
    inventory:add(generatorItem)
end

function WormholeGeneratorExtraction:hasEquipment(player)
    for index, item in pairs(player:getInventory():getItemsByType(InventoryItemType.UsableItem)) do
        if item.item.script == self.script then
            return true
        end
    end
end

function WormholeGeneratorExtraction:getDescriptions()
    local descriptions = {}
    descriptions[1] = {
        text = "Use the Wormhole Generator from your inventory to generate a wormhole"%_T,
        bulletPoint = true,
        fulfilled = self.generatorDeployed,
        visible = self.objectiveAccomplished,
    }

    descriptions[2] = {
        text = "Wait for the wormhole to form"%_T,
        bulletPoint = true,
        fulfilled = self.wormholeGenerated,
        visible = self.generatorDeployed,
    }

    descriptions[3] = {
        text = "Fly through the wormhole to leave the rift"%_T,
        bulletPoint = true,
        fulfilled = self.extractionAccomplished,
        visible = self.wormholeGenerated,
    }

    return descriptions
end

function WormholeGeneratorExtraction:onRiftSectorEntered(missionData)
    local sector = Sector()
    _G["WormholeGeneratorExtraction_onItemActivated"] = function(entityId, x, y, targetX, targetY)
        self.generatorDeployed = true
    end
    sector:registerCallback("onExtractionWormholeGeneratorDeployed", "WormholeGeneratorExtraction_onItemActivated")

    _G["WormholeGeneratorExtraction_onWormholeGenerated"] = function(entityId, x, y, targetX, targetY)
        self.wormholeGenerated = true
    end
    sector:registerCallback("onExtractionWormholeGenerated", "WormholeGeneratorExtraction_onWormholeGenerated")

    _G["WormholeGeneratorExtraction_onCraftSeatEntered"] = function(entityId)
        local craft = Entity(entityId)
        if craft then
            craft:addScriptOnce("internal/dlc/rift/entity/extractionbutton.lua", self.bulletinPointText, self.icon, self.script)
        end
    end

    Sector():registerCallback("onCraftSeatEntered", "WormholeGeneratorExtraction_onCraftSeatEntered")

    local craft = Player().craft
    if craft then
        craft:addScriptOnce("internal/dlc/rift/entity/extractionbutton.lua", self.description, self.icon, self.script)
    end
end

function WormholeGeneratorExtraction:onMissionObjectiveAccomplished(missionData)
    self.objectiveAccomplished = true

    local craft = Player().craft
    if craft then
        craft:invokeFunction("internal/dlc/rift/entity/extractionbutton.lua", "setObjectiveAccomplished")
    end
end

function WormholeGeneratorExtraction:onExtractionSuccessful(missionData)
    self.extractionAccomplished = true
end

function WormholeGeneratorExtraction:updateSector(timeStep)

end

function WormholeGeneratorExtraction:adjustMissionConstraints(constraints)
    local modifier = 0
    return constraints, modifier
end

function WormholeGeneratorExtraction:buildAdditionalDialog(missionData)
    -- check player has rift ripcord
    if not self:hasEquipment(Player()) then
        local dialog1 = {}
        local dialog2 = {}

        dialog1.text = "What, my systems tell me you don't have the wormhole generator but you can't come back without."%_t
        dialog1.onEnd = "WormholeGeneratorExtraction_onGiveGenerator"
        dialog1.followUp = dialog2

        dialog2.text = "Here, I just transferred another one to you. Make sure not to lose it again."%_t
        dialog2.followUp = exitDialog

        return dialog1, dialog2
    end

end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
