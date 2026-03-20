
package.path = package.path .. ";data/scripts/lib/?.lua"

include("utility")

-- for each ship that has an escort in the sector, this script sets the smallest reach of all the escorts as a ScriptValue "max_follow_jumprange"
-- this is used in galaxy map to determine what the largest jump range is where all escorts can still follow

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace EscortJumpRanges
EscortJumpRanges = {}


function EscortJumpRanges.initialize()
end

function EscortJumpRanges.getUpdateInterval()
    return 1
end

function EscortJumpRanges.findMinimum(escorts, id)
    local allMyEscorts = {}
    local todo = {}

    for escort, hsData in pairs(escorts[id] or {}) do
        table.insert(todo, {id = escort, hsData = hsData})
    end

    while tablelength(todo) > 0 do
        local current = table.remove(todo)
        if allMyEscorts[current.id] then goto continue end

        allMyEscorts[current.id] = current.hsData

        for escort, hsData in pairs(escorts[current.id] or {}) do
            table.insert(todo, {id = escort, hsData = hsData})
        end

        ::continue::
    end

    local range = nil
    local passRifts = nil
    for id, hsData in pairs(allMyEscorts) do
        range = math.min(range or hsData.range, hsData.range)

        if passRifts == nil then passRifts = hsData.passRifts end
        if not hsData.passRifts then passRifts = false end
    end

    return range, passRifts
end

function EscortJumpRanges.updateServer(timeStep)

    -- build a table with a tree of all escorts in the sector
    local escorts = {}

    local entities = {Sector():getEntitiesByComponents(ComponentType.HyperspaceEngine, ComponentType.ShipAI)}
    for _, entity in pairs(entities) do
        if not entity.playerOrAllianceOwned then goto continue end

        local ai = ShipAI(entity)

        local target = ai:getFollowTarget()
        if not target then goto continue end

        local targetEntity = Entity(target)
        if not targetEntity then goto continue end
        if not Galaxy():areAllies(entity.factionIndex, targetEntity.factionIndex) then goto continue end

        local ships = escorts[target.string]
        if not ships then
            ships = {}
            escorts[target.string] = ships
        end

        ships[entity.id.string] = {range = entity.hyperspaceJumpReach, passRifts = entity.canPassRifts}

        ::continue::
    end

    for _, entity in pairs(entities) do
        local range, passRifts = EscortJumpRanges.findMinimum(escorts, entity.id.string)

        entity:setValue("max_follow_jumprange", range)
        entity:setValue("max_follow_passrifts", passRifts)
    end
end

