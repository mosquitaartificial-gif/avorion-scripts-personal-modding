package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("randomext")
local RiftObjects = include("dlc/rift/lib/riftobjects")
local PlanGenerator = include("plangenerator")
local CaptainClass = include("captainclass")
local MissionUT = include("missionutility")

function create(item, rarity, x, y)
    local rarity = Rarity(RarityType.Exceptional)

    -- target coords of wormhole that we need to give to generator script
    item:setValue("target_x", x)
    item:setValue("target_y", y)

    item.stackable = true
    item.depleteOnUse = true
    item.tradeable = false
    item.droppable = false
    item.missionRelevant = true
    item.price = 0
    item.rarity = rarity
    item:setValue("subtype", "WormholeGenerator")
    item:setValue("rift_mission_item", true)

    item.name = "Wormhole Generator"%_T
    item.icon = "data/textures/icons/wormhole-generator.png"
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
    line.ltext = "Deploys a wormhole generator at your position."%_T
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "Generator will start generation process immediately."%_T
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


function activate(item)

    -- check target location for wormhole valid
    local tx = item:getValue("target_x")
    local ty = item:getValue("target_y")
    if not tx or not ty then return false end

    -- check we're in a rift
    local player = Player()
    local x, y = Sector():getCoordinates()
    if not Galaxy():sectorInRift(x, y) then return false end

    -- spawn generator
    local position = player.craft.position
    local generatorPosition = copy(position)
    generatorPosition.pos = generatorPosition.pos + random():getDirection() * 50.0

    local faction = Galaxy():getNearestFaction(x, y)

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

    local plan = LoadPlanFromFile("data/plans/wormholegenerator.xml")
    plan:center()
    plan.accumulatingHealth = false

    desc.position = generatorPosition
    desc:setMovePlan(plan)
    desc.title = "Wormhole Generator"%_T
    desc.factionIndex = faction.index

    local physics = desc:getComponent(ComponentType.Physics)
    physics.driftDecrease = 1

    local generator = Sector():createEntity(desc)
    generator:addScript("internal/dlc/rift/entity/wormholegenerator.lua", tx, ty, hasScientist)
    generator.dockable = false
    generator.invincible = true
    generator:setValue("untransferrable", true)
    generator:setValue("sector_overview_color", MissionUT.getBasicMissionColor().html)
    generator:setValue("sector_overview_icon", "data/textures/icons/pixel/vortex.png")

    Sector():sendCallback("onExtractionWormholeGeneratorDeployed")

    return true
end
