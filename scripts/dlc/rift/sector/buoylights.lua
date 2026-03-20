package.path = package.path .. ";data/scripts/lib/?.lua"

include("stringutility")
include("callable")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace RiftBuoyLights
RiftBuoyLights = {}

local buoys = nil
local startBuoys = nil
local monoliths = nil

local refreshCounter = 0

function RiftBuoyLights.initialize()
    if onClient() then
        Player():registerCallback("onPostRenderIndicators", "onPostRenderIndicators")
    end
end

function RiftBuoyLights.updateClient(timeStep)
    refreshCounter = refreshCounter + timeStep

    -- gather buoys, if necessary
    if not buoys or refreshCounter > 5 then
        refreshCounter = 0

        local colors = {
            ColorRGB(1.0, 0.5, 0.5),
            ColorRGB(1.0, 0.7, 0.4),
            ColorRGB(0.8, 0.9, 0.2),
            ColorRGB(0.4, 0.9, 0.4),
            ColorRGB(0.2, 1.0, 1.0),
            ColorRGB(0.5, 0.7, 1.0),
            ColorRGB(0.9, 0.6, 0.9),
        }

        monoliths = {Sector():getEntitiesByScriptValue("riftsector_landmark")}
        local entities = {Sector():getEntitiesByScript("/buoy.lua")}
        buoys = {}
        startBuoys = {}

        for _, entity in pairs(entities) do
            local offset = entity:getValue("buoy_offset") or 0
            local path = (entity:getValue("buoy_path") or 0)
            local start = entity:getValue("buoy_start")
            local colorIndex = (path % #colors) + 1
            local color = colors[colorIndex]
            table.insert(buoys, {entity = entity, offset = offset, color = color, start = start})

            if start then
                local pathStarts = startBuoys[path]
                if not pathStarts then
                    pathStarts = {}
                    startBuoys[path] = pathStarts
                end

                table.insert(pathStarts, {entity = entity, color = color})
            end

        end
    end

    local sector = Sector()
    local time = appTime()
    for i, buoy in pairs(buoys) do
        local entity = buoy.entity

        if not valid(entity) then
            buoys[i] = nil
            goto continue
        end       

        local counter = (time + buoy.offset) % 5
        local size = 15
        if buoy.start then size = 30 end

        if counter < 0.5 then
            size = size + 30
        end

        sector:createGlow(entity.translationf, size, buoy.color)

        ::continue::
    end
end

function RiftBuoyLights.onPostRenderIndicators()
    if monoliths then
        local renderer = UIRenderer()
        local cameraPosition = Player().cameraEye

        -- find closest monolith, measure distances to start buoys from there
        local closestMonolith = nil
        local minDist = math.huge
        for _, monolith in pairs(monoliths) do
            if valid(monolith) then
                local dist = distance(cameraPosition, monolith.translationf)
                local alpha = lerp(dist, 20000, 25000, 0.6, 0)

                if alpha > 0 then
                    local indicator = TargetIndicator(monolith)

                    local color = ColorARGB(alpha, 1, 1, 1)
                    local icon = "data/textures/icons/pixel/monolith.png"
                    if monolith:getValue("visited") then
                        icon = "data/textures/icons/pixel/monolith-done.png"
                    end

                    renderer:renderCenteredPixelIcon(indicator.position, color, icon)
                end

                if dist < 1500 and dist < minDist then
                    minDist = dist
                    closestMonolith = monolith
                end
            end
        end

        if closestMonolith then
            local center = closestMonolith.translationf

            for _, starts in pairs(startBuoys) do
                local closest = nil
                local minDist = math.huge

                for _, buoy in pairs(starts) do
                    if valid(buoy.entity) then
                        local d2 = distance2(buoy.entity.translationf, center)
                        if d2 < 2500 * 2500 and d2 < minDist then
                            closest = buoy
                            minDist = d2
                        end
                    end
                end

                if closest then
                    renderer:renderEntityArrow(closest.entity, 10, 5, 250, closest.color, 0.1)
                end
            end
        end

        renderer:display()
    end
end
