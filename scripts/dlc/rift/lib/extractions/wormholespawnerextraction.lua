include("callable")

local WormholeSpawnerExtraction = {}
WormholeSpawnerExtraction.__index = WormholeSpawnerExtraction

local function new(type)
    local extraction = setmetatable({
        type = type,
        name = "Wormhole Device"%_T,
        icon = "data/textures/icons/wormhole-spawner.png",
        script = "dlc/rift/items/extractionwormholespawner.lua",
        description = "Activate a Wormhole Device to open a wormhole out of a rift."%_t, -- used directly in Mission Board UI

        isInitialized = false,
        wormholeOpened = false,
    }, WormholeSpawnerExtraction)

    return extraction
end

function WormholeSpawnerExtraction:initialize(missionData)
    if missionData then
        self.homeCoords = missionData.arguments.homeLocation

        self:initializeDialogCallbacks(missionData)

        self.isInitialized = true
    end
end

function WormholeSpawnerExtraction:giveItemsToPlayer(player)
    local exitItem = UsableInventoryItem(self.script, Rarity(RarityType.Exceptional), self.homeCoords.x, self.homeCoords.y)
    local inventory = player:getInventory()
    inventory:add(exitItem)
end

function WormholeSpawnerExtraction:hasEquipment(player)
    for index, item in pairs(player:getInventory():getItemsByType(InventoryItemType.UsableItem)) do
        if item.item.script == self.script then
            return true
        end
    end
end

function WormholeSpawnerExtraction:getDescriptions()
    local descriptions = {}

    descriptions[1] =
    {
        text = "Use the Wormhole Device from your inventory to open a wormhole out of the rift"%_T,
        bulletPoint = true,
        fulfilled = self.wormholeOpened,
        visible = self.objectiveAccomplished,
    }

    descriptions[2] =
    {
        text = "Fly through the wormhole to leave the rift"%_T,
        bulletPoint = true,
        fulfilled = self.extractionAccomplished,
        visible = self.wormholeOpened,
    }

    return descriptions
end

function WormholeSpawnerExtraction:updateSector(timeStep)

end

function WormholeSpawnerExtraction:onRiftSectorEntered(missionData)
    _G["WormholeSpawnerExtraction_onItemActivated"] = function()
        self.wormholeOpened = true
    end

    Player():registerCallback("onExtractionWormholeDeviceActivated", "WormholeSpawnerExtraction_onItemActivated")

    _G["WormholeSpawnerExtraction_onCraftSeatEntered"] = function(entityId)
        local craft = Entity(entityId)
        if craft then
            craft:addScriptOnce("internal/dlc/rift/entity/extractionbutton.lua", self.bulletinPointText, self.icon, self.script)
        end
    end

    Sector():registerCallback("onCraftSeatEntered", "WormholeSpawnerExtraction_onCraftSeatEntered")

    local craft = Player().craft
    if craft then
        craft:addScriptOnce("internal/dlc/rift/entity/extractionbutton.lua", self.description, self.icon, self.script)
    end
end

function WormholeSpawnerExtraction:onMissionObjectiveAccomplished(missionData)
    self.objectiveAccomplished = true

    local craft = Player().craft
    if craft then
        craft:invokeFunction("internal/dlc/rift/entity/extractionbutton.lua", "setObjectiveAccomplished")
    end
end

function WormholeSpawnerExtraction:onExtractionSuccessful(missionData)
    self.extractionAccomplished = true
end

function WormholeSpawnerExtraction:initializeDialogCallbacks(missionData)
    if onClient() then
        _G["WormholeSpawnerExtraction_onGiveWormholeSpawner"] = function()
            invokeServerFunction("WormholeSpawnerExtraction_onGiveWormholeSpawner")
        end
    else
        _G["WormholeSpawnerExtraction_onGiveWormholeSpawner"] = function()
            self:giveItemsToPlayer(Player())
        end

        callable(nil, "WormholeSpawnerExtraction_onGiveWormholeSpawner")
    end
end

function WormholeSpawnerExtraction:adjustMissionConstraints(constraints)
    local modifier = 0
    return constraints, modifier
end

function WormholeSpawnerExtraction:buildAdditionalDialog(missionData)
    -- add giving of item to dialog if player doesn't have it
    if not self:hasEquipment(Player()) then
        local dialog1 = {}
        local dialog2 = {}

        dialog1.text = string.format("What, my systems tell me you don't have the ${item} but you can't come back without."%_t % {item = self.name})
        dialog1.onEnd = "WormholeSpawnerExtraction_onGiveWormholeSpawner"
        dialog1.followUp = dialog2

        dialog2.text = "Here, I just transferred another one to you. Make sure not to lose it again."%_t
        dialog2.followUp = exitDialog

        return dialog1, dialog2
    end
end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
