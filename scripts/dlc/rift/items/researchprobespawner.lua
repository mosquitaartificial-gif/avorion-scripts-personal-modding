package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("randomext")
local PlanGenerator = include("plangenerator")
local RiftObjects = include("dlc/rift/lib/riftobjects")

function create(item, rarity)
    item.stackable = true
    item.depleteOnUse = true
    item.tradeable = false
    item.droppable = false
    item.missionRelevant = true
    item.price = 0
    item.rarity = rarity
    item:setValue("rift_mission_item", true)

    item.name = "Xenos Research Probe"%_T
    item.icon = "data/textures/icons/satellite.png"
    local tooltip = Tooltip()
    tooltip.icon = item.icon
    tooltip.rarity = rarity

    local title = item.name
    local headLineSize = 25
    local headLineFontSize = 15
    local line = TooltipLine(headLineSize, headLineFontSize)
    line.ctext = title
    line.ccolor = rarity.tooltipFontColor
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Deploys a research probe at your position."%_T
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 15)
    line.ltext = "Depleted on Use"%_T
    line.lcolor = ColorRGB(1.0, 1.0, 0.3)
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 14)
    line.ltext = "Can be activated by the player"%_T
    tooltip:addLine(line)

    item:setTooltip(tooltip)

    return item
end

local placementRadiusLandmark = 1000 -- this value is mirrored in scoutsector.lua, both have to be changed!
local placementRadiusOtherProbe = 200

function activate(item)
    local player = Player()
    local craft = player.craft
    if not craft then return false end

    -- check conditions for spawning beacon
    -- and don't spawn if it's not possible
    for _, entity in pairs({Sector():getEntitiesByScriptValue("research_beacon")}) do
        if distance2(craft.translationf, entity.translationf) <= placementRadiusOtherProbe * placementRadiusOtherProbe then
            entity:invokeFunction("researchprobe.lua", "onTriedSpawningNewProbeTooClose", player)
            player:sendChatMessage("", ChatMessageType.Error, "Too close to another research probe!"%_T)
            return false
        end
    end

    local landmarkCloseEnough = false
    local locationValid = true
    for _, landmark in pairs({Sector():getEntitiesByScriptValue("riftsector_landmark")}) do
        if distance2(craft.translationf, landmark.translationf) <= placementRadiusLandmark * placementRadiusLandmark then
            local ok, valid = Sector():invokeFunction("scoutsector.lua", "isValidProbeLocation", landmark.id.string)
            locationValid = valid

            if locationValid then
                landmarkCloseEnough = true
                break
            end
        end
    end

    if not landmarkCloseEnough then
        if locationValid then
            player:sendChatMessage("", ChatMessageType.Error, "No interesting objects nearby!"%_T)
        end

        player:sendChatMessage("Rift Research Center"%_T, ChatMessageType.Normal, "This isn't the right place to set this up."%_T)
        return false
    end


    -- spawn the beacon
    local position = player.craft.position
    local beaconPosition = copy(position)
    beaconPosition.pos = beaconPosition.pos + random():getDirection() * 50.0

    local faction = RiftObjects.getFaction()

    local desc = EntityDescriptor()
    desc:addComponents(
       ComponentType.Plan,
       ComponentType.BspTree,
       ComponentType.Intersection,
       ComponentType.Asleep,
       ComponentType.DamageContributors,
       ComponentType.BoundingSphere,
       ComponentType.Durability,
       ComponentType.PlanMaxDurability,
       ComponentType.BoundingBox,
       ComponentType.Velocity,
       ComponentType.Physics,
       ComponentType.Scripts,
       ComponentType.ScriptCallback,
       ComponentType.Title,
       ComponentType.Owner,
       ComponentType.InteractionText,
       ComponentType.FactionNotifier
    )

    local plan = PlanGenerator.makeBeaconPlan()
    plan.accumulatingHealth = false

    desc.position = beaconPosition
    desc:setMovePlan(plan)
    desc.title = "Xenos Research Probe"%_T
    desc:setValue("research_beacon", true)
    desc.factionIndex = faction.index

    local beacon = Sector():createEntity(desc)
    local plan = Plan(beacon.id)
    plan.singleBlockDestructionEnabled = false

    beacon:addScript("internal/dlc/rift/entity/researchprobe.lua")
    beacon.dockable = false

    return true
end
