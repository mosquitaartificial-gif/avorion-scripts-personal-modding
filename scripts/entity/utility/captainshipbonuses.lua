package.path = package.path .. ";data/scripts/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"

local CaptainClass = include("captainclass")
local RiftMissionUT = include("dlc/rift/lib/riftmissionutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace CaptainShipBonuses
CaptainShipBonuses = {}


local highlightAsteroids
local highlightWreckages

local detectedAsteroids
local detectedWreckages
local detectedResearchData
local detectedScannables

local scientistInCommand

local inRift
local timeScientistInCommand = 0
local timeScientistInRift = 0

function CaptainShipBonuses.getUpdateInterval()
    return 1
end

function CaptainShipBonuses.initialize()
    local entity = Entity()
    entity:registerCallback("onCaptainChanged", "onCaptainChanged")

    if onServer() then
        entity:registerCallback("onSectorEntered", "onSectorEntered")
    end

    -- do a first change on initialization by pretending that the captain changed
    local captain = entity:getCaptain()
    CaptainShipBonuses.onCaptainChanged(entity.id, captain)
end

function CaptainShipBonuses.onCaptainChanged(entityId, captain)

    -- on change, reset everything and then give it back if appropriate
    local entity = Entity()
    entity:removeScriptBonuses()

    highlightAsteroids = nil
    highlightWreckages = nil
    scientistInCommand = nil

    detectedAsteroids = nil
    detectedWreckages = nil
    detectedResearchData = nil
    detectedScannables = nil

    if not captain then return end

    -- IMPORTANT: Changes to the following numbers must be adjusted in captainutility.lua makeTooltip() as well!
    -- Commodore gives +armed turrets
    if captain:hasClass(CaptainClass.Commodore) then
        entity:addMultiplyableBias(StatsBonuses.ArmedTurrets, 2)
        entity:addMultiplyableBias(StatsBonuses.AutomaticTurrets, 4)
    end

    -- Scavenger gives +unarmed turrets and detects valuable wreckages
    if captain:hasClass(CaptainClass.Scavenger) then
        entity:addMultiplyableBias(StatsBonuses.UnarmedTurrets, 2)
        highlightWreckages = true
    end

    -- Miner gives +mining turrets and detects hidden asteroids
    if captain:hasClass(CaptainClass.Miner) then
        entity:addMultiplyableBias(StatsBonuses.UnarmedTurrets, 2)
        highlightAsteroids = true

        entity:addScriptOnce("data/scripts/entity/utility/uncovermineablematerial.lua")
    end

    -- Explorer gives +hidden sector radar reach
    if captain:hasClass(CaptainClass.Explorer) then
        entity:addMultiplyableBias(StatsBonuses.HiddenSectorRadarReach, 3)
    end

    -- Daredevil gives +fire rate
    if captain:hasClass(CaptainClass.Daredevil) then
        entity:addBaseMultiplier(StatsBonuses.FireRate, 0.1)
    end

    if captain:hasClass(CaptainClass.Scientist) then
        scientistInCommand = true
    end

    -- Hunter spawns mini-bosses with loot while in rifts
    if captain:hasClass(CaptainClass.Hunter) then
        entity:addScriptOnce("internal/dlc/rift/entity/huntercaptainbehavior.lua")
    end
end

function CaptainShipBonuses.onSectorEntered(id, x, y)
    inRift = Galaxy():sectorInRift(x, y)

    if not inRift then
        timeScientistInRift = 0
        timeScientistInCommand = 0
    end
end

-- this checks if highlights should be rendered at the moment
function CaptainShipBonuses.isHighlighting()

    -- no highlights when in build mode
    local player = Player()
    if not player then return end
    if player.state == PlayerStateType.BuildCraft or player.state == PlayerStateType.BuildTurret or player.state == PlayerStateType.PhotoMode then return end

    -- only highlight when the local player is actually piloting the ship
    local ship = Entity()
    if player.craftIndex ~= ship.index then return end

    return highlightAsteroids or highlightWreckages or scientistInCommand
end

local scientistMessageSent

function CaptainShipBonuses.updateClient()
    -- asteroid & wreckage detection, this is done once per second
    if CaptainShipBonuses.isHighlighting() then
        -- we need this callback to render the indicators of the objects
        Player():registerCallback("onPreRenderHud", "onPreRenderHud")

        if highlightAsteroids then CaptainShipBonuses.detectAsteroids() end
        if highlightWreckages then CaptainShipBonuses.detectWreckages() end
        if scientistInCommand then CaptainShipBonuses.detectResearchData() end
    else
        Player():unregisterCallback("onPreRenderHud", "onPreRenderHud")
    end

    if scientistInCommand and not scientistMessageSent then
        local x, y = Sector():getCoordinates()
        if Galaxy():sectorInRift(x, y) then
            local ship = Entity()
            local captain = ship:getCaptain()

            -- need to show speech bubble in addition to chatter since otherwise it won't be visible
            local message = "Captain ${name}: Wonderful! I'll start collecting data right away. I must remain on the bridge though. We should also look out for data left behind by destroyed Xsotan."%_T
            displaySpeechBubble(ship, message % {name = captain.name})
            displayChatMessage(message % {name = captain.name}, "Captain ${name}" % {name = captain.name}, ChatMessageType.Chatter)

            scientistMessageSent = true
        end
    end

    if not scientistInCommand then
        scientistMessageSent = nil
    end

end

function CaptainShipBonuses.onPreRenderHud()
    -- indicator rendering, this is done every frame
    if CaptainShipBonuses.isHighlighting() then
        if highlightAsteroids then CaptainShipBonuses.renderAsteroidIndicators() end
        if highlightWreckages then CaptainShipBonuses.renderWreckageIndicators() end
        if scientistInCommand then CaptainShipBonuses.renderResearchDataIndicators() end
    end
end

function CaptainShipBonuses.detectAsteroids()
    local ship = Entity()

    local shipPos = ship.translationf
    local sphere = Sphere(shipPos, 350)
    local nearby = {Sector():getEntitiesByLocation(sphere)}
    local asteroids = {}

    -- detect all asteroids in range
    for _, entity in pairs(nearby) do
        if entity.type == EntityType.Asteroid then

            -- highlight asteroids with hidden resources
            local resources = entity:getMineableResources()
            if resources and resources > 0 then
                if not entity.isObviouslyMineable then
                    local d2 = distance2(entity.translationf, shipPos)
                    table.insert(asteroids, {material = material, asteroid = entity, distance = d2})
                end
            end
        end
    end

    -- sort by distance
    table.sort(asteroids, function(a, b)
        return a.distance < b.distance
    end)

    detectedAsteroids = asteroids
end

function CaptainShipBonuses.renderAsteroidIndicators()
    if not detectedAsteroids then return end

    -- display nearest 2
    local renderer = UIRenderer()

    for i = 1, math.min(#detectedAsteroids, 2) do
        local tuple = detectedAsteroids[i]
        if valid(tuple.asteroid) then
            local color = tuple.asteroid:getMineableMaterial().color
            renderer:renderEntityTargeter(tuple.asteroid, color);
            renderer:renderEntityArrow(tuple.asteroid, 30, 10, 250, color);
        end
    end

    renderer:display()
end

function CaptainShipBonuses.detectWreckages()
    local ship = Entity()

    local shipPos = ship.translationf
    local sphere = Sphere(shipPos, 500)
    local nearby = {Sector():getEntitiesByLocation(sphere)}
    local wreckages = {}

    -- detect all wreckages in range
    for _, entity in pairs(nearby) do
        if entity.type == EntityType.Wreckage then

            -- highlight wreckages that have at least 500 resources or cargo on board
            local resources = entity:getMineableResources()
            if ((resources or 0) >= 500) or (entity.numCargos > 0) then
                local d2 = distance2(entity.translationf, shipPos)
                table.insert(wreckages, {material = material, wreckage = entity, distance = d2})
            end
        end
    end

    -- sort by distance
    table.sort(wreckages, function(a, b)
        return a.distance < b.distance
    end)

    detectedWreckages = wreckages
end

function CaptainShipBonuses.renderWreckageIndicators()
    if not detectedWreckages then return end

    -- display nearest 2
    local renderer = UIRenderer()

    for i = 1, math.min(#detectedWreckages, 2) do
        local tuple = detectedWreckages[i]
        if valid(tuple.wreckage) then

            local color = ColorRGB(1, 1, 1)
            local mineableMaterial = tuple.wreckage:getMineableMaterial()
            if mineableMaterial then
                color = mineableMaterial.color
            end

            renderer:renderEntityTargeter(tuple.wreckage, color);
            renderer:renderEntityArrow(tuple.wreckage, 30, 10, 250, color);
        end
    end

    renderer:display()
end

function CaptainShipBonuses.detectResearchData()
    local ship = Entity()

    detectedScannables = nil
    detectedResearchData = nil

    local datas = {}

    -- detect all research data in range
    for _, entity in pairs({Sector():getEntitiesByComponent(ComponentType.CargoLoot)}) do
        local loot = CargoLoot(entity)
        if loot:matches("Rift Research Data") then
            table.insert(datas, entity)
        end
    end

    if #datas > 0 then detectedResearchData = datas end

    local scannables = {}

    -- detect all scannables in range
    local threshold2 = 1000 * 1000
    for _, entity in pairs({Sector():getEntitiesByScript("riftobjects/scannableobject.lua")}) do
        if distance2(entity.translationf, ship.translationf) < threshold2 then
            table.insert(scannables, entity)
        end
    end

    if #scannables > 0 then detectedScannables = scannables end
end

function CaptainShipBonuses.renderResearchDataIndicators()
    if detectedResearchData then
        local renderer = UIRenderer()
        local color = Rarity(RarityType.Rare).color

        for _, entity in pairs(detectedResearchData) do
            if valid(entity) then
                local indicator = TargetIndicator(entity)
                indicator.visuals = TargetIndicatorVisuals.Tilted
                indicator.color = color
                renderer:renderTargetIndicator(indicator);
            end
        end

        renderer:display()
    end

    if detectedScannables then
        local renderer = UIRenderer()
        local color = Rarity(RarityType.Rare).color

        for _, entity in pairs(detectedScannables) do
            if valid(entity) then
                local indicator = TargetIndicator(entity)
                indicator.color = color
                renderer:renderTargetIndicator(indicator);
            end
        end

        renderer:display()
    end
end

function CaptainShipBonuses.updateServer(timeStep)
    if scientistInCommand and inRift then
        timeScientistInCommand = timeScientistInCommand + timeStep
        timeScientistInRift = timeScientistInRift + timeStep

        local timeToCollect = 70
        local captain = Entity():getCaptain()
        timeToCollect = timeToCollect - (captain.level + captain.tier) * 5

        -- scientist only collects the first 20 minutes while in rift
        if timeScientistInCommand > timeToCollect and timeScientistInRift < 20 * 60 then
            timeScientistInCommand = 0

            local good = RiftMissionUT.getRiftDataGood()
            local added = CargoBay():addCargo(good, 1)
            if added == 0 then
                Sector():dropCargo(Entity().translationf, nil, nil, good, 0, 1)
            end
        end
    else
        timeScientistInCommand = 0
    end
end
