
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
include("goods")
include("refineutility")
local DockAI = include ("entity/ai/dock")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace AIRefine
AIRefine = {}

local partner
local status
local remainingTime

local noRefineryFoundTimer = 0

RefineAI = {
    DockAtStation = 1,
    WaitForProcessing = 2,
    CollectResources = 3
}

if onServer() then

function AIRefine.secure()
    local data = {status = status, partner = partner}

    DockAI.secure(data)

    return data
end

function AIRefine.restore(data)
    status = data.status
    partner = data.partner

    DockAI.restore(data)
end

function AIRefine.getUpdateInterval()
    return 1
end

function AIRefine.updateServer(timeStep)
    local craft = Entity()

    noRefineryFoundTimer = noRefineryFoundTimer - timeStep

    if not partner then
        -- are there any ores to refine?
        local ores, totalOres = getOreAmountsOnShip(craft)
        local scraps, totalScraps = getScrapAmountsOnShip(craft)
        local riftOres, totalRiftOres = getRiftOreAmountsOnShip(craft)

        if totalOres + totalScraps + totalRiftOres == 0 then
            -- nothing to refine

            -- find running refine job
            partner, remainingTime = AIRefine.findRefineryWithRunningJob()

            if not partner then
                AIRefine.sendError("You have nothing to refine."%_T, "Nothing to refine."%_T)
                AIRefine.finalize(true)
                return
            end

            status = RefineAI.WaitForProcessing

        else
            -- find best refinery
            partner = AIRefine.findRefinery()
            if not partner then
                if noRefineryFoundTimer <= 0 then
                    noRefineryFoundTimer = 10 * 60
                    AIRefine.sendError("Commander, we can't find a refinery in \\s(%s)."%_T, "No refinery found in sector %s."%_T)
                end

                return
            end

            status = RefineAI.DockAtStation
            DockAI.reset()
        end
    end

    local station = Sector():getEntity(partner)
    if not station then
        if noRefineryFoundTimer <= 0 then
            noRefineryFoundTimer = 10 * 60
            AIRefine.sendError("Commander, we can't find a refinery in \\s(%s)."%_T, "No refinery found in sector %s."%_T)
        end

        return
    end


    if status == RefineAI.DockAtStation then
        AIRefine.setShipStatusMessage("Refining Ores - Docking /* ship AI status */"%_T, {})

        local finished = function() status = RefineAI.WaitForProcessing end
        DockAI.updateDockingUndocking(timeStep, station, 1, AIRefine.startProcessing, finished, true --[[skip undocking--]])

    elseif status == RefineAI.WaitForProcessing then
        AIRefine.setShipStatusMessage("Refining Ores - Waiting for Processing /* ship AI status */"%_T, {})

        if remainingTime == nil then
            remainingTime = AIRefine.getRemainingTime(station)

            if remainingTime == nil then
                local ores, totalOres = getOreAmountsOnShip(craft)
                local scraps, totalScraps = getScrapAmountsOnShip(craft)
                local riftOres, totalRiftOres = getRiftOreAmountsOnShip(craft)

                if totalOres + totalScraps + totalRiftOres == 0 then
                    AIRefine.finalize(true)
                    return
                end

                -- resources remaining - restart
                partner = nil
                return
            end
        end

        remainingTime = remainingTime - timeStep

        if remainingTime <= 0 then
            status = RefineAI.CollectResources
            DockAI.reset()
        end

    elseif status == RefineAI.CollectResources then
        AIRefine.setShipStatusMessage("Refining Ores - Collecting Resources /* ship AI status */"%_T, {})

        local transaction = function(craft)
            station:invokeFunction("data/scripts/entity/merchants/refinery.lua", "onTakeAllPressed", craft.index)
        end

        local finish = function(craft)
            local ores, totalOres = getOreAmountsOnShip(craft)
            local scraps, totalScraps = getScrapAmountsOnShip(craft)
            local riftOres, totalRiftOres = getRiftOreAmountsOnShip(craft)

            if totalOres + totalScraps + totalRiftOres == 0 then
                AIRefine.finalize(true)
                return
            end

            -- resources remaining - restart
            partner = nil
            return
        end

        DockAI.updateDockingUndocking(timeStep, station, 1, transaction, finish)
    end
end

function AIRefine.finalize(notifyPlayer)
    -- job done, if we're here on autopilot we terminate it as well
    local entity = Entity()
    if notifyPlayer then
        entity:invokeFunction("orderchain.lua", "orderCompleted")
    end

    -- tell station we don't want to be moved anymore
    if partner ~= nil then
        local station = Sector():getEntity(partner)
        if station then
            local docks = DockingPositions(station)

            docks:stopPulling(entity)
            docks:stopPushing(entity)
        end
    end

    DockAI.reset()
    ShipAI():setPassive()
    terminate()
end

function AIRefine.sendError(chatMessage, errorMessage)
    local craft = Entity()
    local faction = Faction(craft.factionIndex)
    if faction then
        local x, y = Sector():getCoordinates()
        local coords = tostring(x) .. ":" .. tostring(y)

        faction:sendChatMessage(craft.name or "", ChatMessageType.Error, errorMessage, coords)
        faction:sendChatMessage(craft.name or "", ChatMessageType.Normal, chatMessage, coords)
    end
end

function AIRefine.findRefineryWithRunningJob()
    local craft = Entity()

    for _, station in pairs({Sector():getEntitiesByScript("data/scripts/entity/merchants/refinery.lua")}) do
        local ret, time = station:invokeFunction("data/scripts/entity/merchants/refinery.lua", "getRemainingJobDuration", craft.factionIndex)
        if ret == 0 then
            if time ~= nil then
                -- add small tolerance
                if time > 0 then time = time + 5 end

                return station.id.string, time
            end
        end
    end
end

function AIRefine.findRefinery()
    local craft = Entity()
    local shipFaction = Faction(craft.factionIndex)

    local best = {}

    for _, station in pairs({Sector():getEntitiesByScript("data/scripts/entity/merchants/refinery.lua")}) do
        local relations = shipFaction:getRelations(station.factionIndex)

        if best.relations == nil or relations > best.relations then
            if (station.numDockingPositions or 0) > 0 then
                best.relations = relations
                best.stationId = station.id
            end
        end
    end

    return best.stationId and best.stationId.string or nil
end

function AIRefine.getRemainingTime(station)
    local craft = Entity()

    local ret, time = station:invokeFunction("data/scripts/entity/merchants/refinery.lua", "getRemainingJobDuration", craft.factionIndex)
    if ret == 0 then
        if time ~= nil then
            -- add small tolerance
            if time > 0 then time = time + 5 end

            return time
        end
    end
end

function AIRefine.startProcessing(craft, station)
    local ores, totalOres = getOreAmountsOnShip(craft)
    local scraps, totalScraps = getScrapAmountsOnShip(craft)
    local riftOres, totalRiftOres = getRiftOreAmountsOnShip(craft)

    if totalOres + totalScraps + totalRiftOres == 0 then
        -- nothing to refine
        AIRefine.finalize(true)
        return
    end

    station:invokeFunction("data/scripts/entity/merchants/refinery.lua", "addJob", craft.index, ores, scraps, riftOres, true)

    remainingTime = nil
end

function AIRefine.setShipStatusMessage(msg, arguments)
    -- only set AI state if auto pilot inactive
    if not ControlUnit().autoPilotEnabled then
        local ai = ShipAI()
        ai:setStatusMessage(msg, arguments)
    end
end

end
