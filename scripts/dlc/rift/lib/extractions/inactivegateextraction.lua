package.path = package.path .. ";data/scripts/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"

local RiftObjects = include("dlc/rift/lib/riftobjects")
local MissionUT = include("missionutility")

local InactiveGateExtraction = {}
InactiveGateExtraction.__index = InactiveGateExtraction

local function new(type)
    local extraction = setmetatable({
        type = type,
        name = "Inactive Ancient Gate"%_T,
        icon = "data/textures/icons/inactive-gate-extraction.png",
        description = "An earlier expedition has discovered an ancient gate and a matching activator at the target position. Use these to return from the rift."%_t, -- used directly in Mission Board UI

        activatorInRange = false,
        activatorBatteryFound = false,
        isActive = false,
    }, InactiveGateExtraction)

    return extraction
end

function InactiveGateExtraction:initialize(missionData)
end

function InactiveGateExtraction:giveItemsToPlayer(player)
end

function InactiveGateExtraction:hasEquipment(player)
end

function InactiveGateExtraction:getDescriptions()
    local descriptions = {}
    descriptions[1] = {
        text = "Find an activator near the Ancient Gate and bring it there"%_T,
        bulletPoint = true,
        fulfilled = self.activatorInRange,
        visible = self.objectiveAccomplished,
    }

    descriptions[2] = {
        text = "Find a battery and connect it to the activator"%_T,
        bulletPoint = true,
        fulfilled = self.activatorBatteryFound,
        visible = self.activatorInRange,
    }

    descriptions[3] = {
        text = "Defend yourself while the ancient gate charges up"%_T,
        bulletPoint = true,
        fulfilled = self.isActive,
        visible = self.activatorBatteryFound,
    }

    descriptions[4] = {
        text = "Use the ancient gate to leave the rift"%_T,
        bulletPoint = true,
        fulfilled = self.extractionAccomplished,
        visible = self.isActive,
    }

    return descriptions
end

function InactiveGateExtraction:onRiftSectorEntered(missionData)
    if onClient() then return end

    -- spawn gate, activator and battery
    -- not spawned at a meaningful location yet
    local gatePosition = Matrix()
    gatePosition.translation = vec3(1000, 0, 0)


    local homeX = missionData.arguments.homeLocation.x
    local homeY = missionData.arguments.homeLocation.y
    RiftObjects.createInactiveGate(gatePosition, homeX, homeY)

    -- these objects are automatically created by the gate
    -- this is ok because they don't have a meaningful location yet
--    RiftObjects.createInactiveGateActivator(MatrixLookUpPosition(e.look, e.up, e.translationf + e.right * 500))
--    RiftObjects.createBattery(MatrixLookUpPosition(e.look, e.up, e.translationf - e.right * 500))
end

function InactiveGateExtraction:onMissionObjectiveAccomplished(missionData)
    self.objectiveAccomplished = true

    local activators = {Sector():getEntitiesByScript("inactivegateactivator.lua")}
    for _, object in pairs(activators) do
        object:setValue("highlight_color", MissionUT.getBasicMissionColor().html)
    end
end

function InactiveGateExtraction:onExtractionSuccessful(missionData)
    self.extractionAccomplished = true
end

function InactiveGateExtraction:updateSector(timeStep, timeLeft)
    local sector = Sector()
    local gate = sector:getEntitiesByScript("internal/dlc/rift/entity/riftobjects/inactivegate.lua")
    if not gate then return end

    local ok, active = gate:invokeFunction("internal/dlc/rift/entity/riftobjects/inactivegate.lua", "getIsActive")
    if ok == 0 then
        self.isActive = active
    end

    self.activatorInRange = false
    self.activatorBatteryFound = false

    local ret, activators = gate:invokeFunction("internal/dlc/rift/entity/riftobjects/inactivegate.lua", "getActivators")
    if ret == 0 then
        for id, _ in pairs(activators) do
            local activator = Entity(id)
            if activator then
                self.activatorInRange = true

                if activator:getValue("has_battery") then
                    self.activatorBatteryFound = true
                end
            end
        end
    end
end

function InactiveGateExtraction:adjustMissionConstraints(constraints)
    local modifier = 0

    -- docking block needed
    if not constraints["4a958817-d1e0-45ab-85c7-a7fd273529be"] then
        constraints["4a958817-d1e0-45ab-85c7-a7fd273529be"] = true
    end

    return constraints, modifier
end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
