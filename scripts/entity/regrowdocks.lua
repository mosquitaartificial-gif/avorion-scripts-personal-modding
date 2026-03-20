
-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace RegrowDocks
RegrowDocks = {}

function RegrowDocks.getUpdateInterval()
    return 15 * 60
end

function RegrowDocks.initialize()

    if onServer() then
        RegrowDocks.regrow()
    end
end

function RegrowDocks.updateServer()
    RegrowDocks.regrow()
end


function RegrowDocks.regrow()
    local docks = DockingPositions()

    if not valid(docks) then return end
    if docks.numDockingPositions >= 2 then return end
    if not Entity().aiOwned then return end

    local plan = Plan()

    local highestZ = plan:getNthBlock(0)
    local lowestZ = highestZ
    local highestX = highestZ
    local lowestX = highestZ

    for i = 1, plan.numBlocks - 1 do
        local block = plan:getNthBlock(i)

        local box = block.box
        if box.upper.z > highestZ.box.upper.z then highestZ = block end
        if box.lower.z < lowestZ.box.lower.z then lowestZ = block end

        if box.upper.x > highestX.box.upper.x then highestX = block end
        if box.lower.x < lowestX.box.lower.x then lowestX = block end
    end

    if lowestZ.blockIndex ~= BlockType.Dock then
        RegrowDocks.placeDock(plan, lowestZ, vec3(0, 0, -1))
        return
    end

    if highestZ.blockIndex ~= BlockType.Dock then
        RegrowDocks.placeDock(plan, highestZ, vec3(0, 0, 1))
        return
    end

    if highestX.blockIndex ~= BlockType.Dock then
        RegrowDocks.placeDock(plan, highestX, vec3(1, 0, 0))
        return
    end

    if lowestX.blockIndex ~= BlockType.Dock then
        RegrowDocks.placeDock(plan, lowestX, vec3(-1, 0, 0))
        return
    end

end

function RegrowDocks.placeDock(plan, block, direction)
    local size = vec3(1, 1, 1)
    local position = block.box.center + (block.box.size * 0.5 * direction) + (size * 0.5 * direction)
    local orientation = MatrixLookUp(direction, vec3(0, 1, 0))
    plan:addBlock(position, size, block.index, -1, block.color, block.material, orientation, BlockType.Dock, ColorNone())
end



