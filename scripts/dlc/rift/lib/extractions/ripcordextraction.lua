
local RipcordExtraction = {}
RipcordExtraction.__index = RipcordExtraction

local function new(type)
    local extraction = setmetatable({
        type = type,
        name = "Rift Ripcord"%_T,
        icon = "data/textures/icons/rift-exit.png",
        script = "dlc/rift/items/ripcord.lua",
        description = "Activate the Rift Ripcord."%_t, -- used directly in Mission Board UI
        bulletinPointText = "Use the Rift Ripcord from your inventory to leave the rift"%_T,

        timeRemainingWarningByPlayer = {},
        isInitialized = false,
    }, RipcordExtraction)

    return extraction
end

function RipcordExtraction:initialize(missionData)
    if missionData then
        self.homeCoords = missionData.arguments.homeLocation

        self:initializeDialogCallbacks(missionData)

        self.isInitialized = true
    end
end

function RipcordExtraction:giveItemsToPlayer(player)
    local exitItem = UsableInventoryItem(self.script, Rarity(RarityType.Exceptional), self.homeCoords.x, self.homeCoords.y)
    local inventory = player:getInventory()
    inventory:add(exitItem)
end

function RipcordExtraction:hasEquipment(player)
    for index, item in pairs(player:getInventory():getItemsByType(InventoryItemType.UsableItem)) do
        if item.item.script == self.script then
            return true
        end
    end
end

function RipcordExtraction:getDescriptions()
    local descriptions = {
        {text = self.bulletinPointText, bulletPoint = true, fulfilled = self.extractionAccomplished, visible = self.objectiveAccomplished}
    }

    return descriptions
end

function RipcordExtraction:onRiftSectorEntered(missionData)
    _G["RipcordExtraction_onItemActivated"] = function(entityId, x, y, targetX, targetY)
        local craft = Player().craft
        if craft then
            local undockGarbage = true
            craft:addScriptOnce("internal/dlc/rift/entity/riftteleport.lua", "", 5, x, y, targetX, targetY, undockGarbage)
        end
    end

    Player():registerCallback("onRipcordActivated", "RipcordExtraction_onItemActivated")

    _G["RipcordExtraction_onCraftSeatEntered"] = function(entityId)
        local craft = Entity(entityId)
        if craft then
            craft:addScriptOnce("internal/dlc/rift/entity/extractionbutton.lua", self.bulletinPointText, self.icon, self.script)
        end
    end

    Sector():registerCallback("onCraftSeatEntered", "RipcordExtraction_onCraftSeatEntered")

    local craft = Player().craft
    if craft then
        craft:addScriptOnce("internal/dlc/rift/entity/extractionbutton.lua", self.bulletinPointText, self.icon, self.script)
    end
end

function RipcordExtraction:onMissionObjectiveAccomplished(missionData)
    self.objectiveAccomplished = true

    local craft = Player().craft
    if craft then
        craft:invokeFunction("internal/dlc/rift/entity/extractionbutton.lua", "setObjectiveAccomplished")
    end
end

function RipcordExtraction:onExtractionSuccessful(missionData)
    self.extractionAccomplished = true
end

function RipcordExtraction:initializeDialogCallbacks(missionData)
    if onClient() then
        _G["RipcordExtraction_onGiveRipcord"] = function()
            invokeServerFunction("RipcordExtraction_onGiveRipcord")
        end
    else
        _G["RipcordExtraction_onGiveRipcord"] = function()
            self:giveItemsToPlayer(Player())
        end

        callable(nil, "RipcordExtraction_onGiveRipcord")
    end
end

function RipcordExtraction:adjustMissionConstraints(constraints)
    -- no adjustment needed
    local modifier = 0
    return constraints, modifier
end

function RipcordExtraction:buildAdditionalDialog(missionData)
    -- check player has rift ripcord
    if not self:hasEquipment(Player()) then
        local dialog1 = {}
        local dialog2 = {}

        dialog1.text = string.format("What, my systems tell me you don't have the ${item} but you can't come back without."%_t % {item = self.name})
        dialog1.onEnd = "RipcordExtraction_onGiveRipcord"
        dialog1.followUp = dialog2

        dialog2.text = "Here, I just transferred another one to you. Make sure not to lose it again."%_t
        dialog2.followUp = exitDialog

        return dialog1, dialog2
    end
end

function RipcordExtraction:updateSector(timeStep)
end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
