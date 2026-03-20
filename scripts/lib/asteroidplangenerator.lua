
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("randomext")

local AsteroidPlanGenerator = {}
AsteroidPlanGenerator.__index = AsteroidPlanGenerator

local function new()
    local instance = setmetatable({}, AsteroidPlanGenerator)
    instance:setToDefaultStone()
    return instance
end

function AsteroidPlanGenerator:setToDefaultStone()
    self.Stone = BlockType.Stone
    self.StoneEdge = BlockType.StoneEdge
    self.StoneCorner = BlockType.StoneCorner
    self.StoneOuterCorner = BlockType.StoneOuterCorner
    self.StoneInnerCorner = BlockType.StoneInnerCorner
    self.StoneTwistedCorner1 = BlockType.StoneTwistedCorner1
    self.StoneTwistedCorner2 = BlockType.StoneTwistedCorner2
    self.StoneFlatCorner = BlockType.StoneFlatCorner
    self.RichStone = BlockType.RichStone
    self.RichStoneEdge = BlockType.RichStoneEdge
    self.RichStoneCorner = BlockType.RichStoneCorner
    self.RichStoneInnerCorner = BlockType.RichStoneInnerCorner
    self.RichStoneOuterCorner = BlockType.RichStoneOuterCorner
    self.RichStoneTwistedCorner1 = BlockType.RichStoneTwistedCorner1
    self.RichStoneTwistedCorner2 = BlockType.RichStoneTwistedCorner2
    self.RichStoneFlatCorner = BlockType.RichStoneFlatCorner
    self.SuperRichStone = BlockType.SuperRichStone
    self.SuperRichStoneEdge = BlockType.SuperRichStoneEdge
    self.SuperRichStoneCorner = BlockType.SuperRichStoneCorner
    self.SuperRichStoneInnerCorner = BlockType.SuperRichStoneInnerCorner
    self.SuperRichStoneOuterCorner = BlockType.SuperRichStoneOuterCorner
    self.SuperRichStoneTwistedCorner1 = BlockType.SuperRichStoneTwistedCorner1
    self.SuperRichStoneTwistedCorner2 = BlockType.SuperRichStoneTwistedCorner2
    self.SuperRichStoneFlatCorner = BlockType.SuperRichStoneFlatCorner

end

function AsteroidPlanGenerator:setToRiftStone()
    self.Stone = BlockType.RiftStone
    self.StoneEdge = BlockType.RiftStoneEdge
    self.StoneCorner = BlockType.RiftStoneCorner
    self.StoneOuterCorner = BlockType.RiftStoneOuterCorner
    self.StoneInnerCorner = BlockType.RiftStoneInnerCorner
    self.StoneTwistedCorner1 = BlockType.RiftStoneTwistedCorner1
    self.StoneTwistedCorner2 = BlockType.RiftStoneTwistedCorner2
    self.StoneFlatCorner = BlockType.RiftStoneFlatCorner
    self.RichStone = BlockType.RichRiftStone
    self.RichStoneEdge = BlockType.RichRiftStoneEdge
    self.RichStoneCorner = BlockType.RichRiftStoneCorner
    self.RichStoneInnerCorner = BlockType.RichRiftStoneInnerCorner
    self.RichStoneOuterCorner = BlockType.RichRiftStoneOuterCorner
    self.RichStoneTwistedCorner1 = BlockType.RichRiftStoneTwistedCorner1
    self.RichStoneTwistedCorner2 = BlockType.RichRiftStoneTwistedCorner2
    self.RichStoneFlatCorner = BlockType.RichRiftStoneFlatCorner
    self.SuperRichStone = BlockType.SuperRichRiftStone
    self.SuperRichStoneEdge = BlockType.SuperRichRiftStoneEdge
    self.SuperRichStoneCorner = BlockType.SuperRichRiftStoneCorner
    self.SuperRichStoneInnerCorner = BlockType.SuperRichRiftStoneInnerCorner
    self.SuperRichStoneOuterCorner = BlockType.SuperRichRiftStoneOuterCorner
    self.SuperRichStoneTwistedCorner1 = BlockType.SuperRichRiftStoneTwistedCorner1
    self.SuperRichStoneTwistedCorner2 = BlockType.SuperRichRiftStoneTwistedCorner2
    self.SuperRichStoneFlatCorner = BlockType.SuperRichRiftStoneFlatCorner

end

function AsteroidPlanGenerator:makeBigAsteroidPlan(size, resources, material, iterations)

    iterations = iterations or 10

    local directions = {
        vec3(1, 0, 0), vec3(-1, 0, 0),
        vec3(0, 1, 0), vec3(0, -1, 0),
        vec3(0, 0, 1), vec3(0, 0, -1)
    }

    local plan = self:makeSmallAsteroidPlan(1.0, resources, material, true)

    local centers = {plan:getBlock(0)}

    for i = 1, iterations do

        local center = centers[getInt(1, #centers)]
        local dir = normalize(directions[getInt(1, 6)] + random():getDirection() * 0.5)

        -- make a plan and attach it to the selected center in the selected direction
        local other = self:makeSmallAsteroidPlan(getFloat(1.0, 1.5), resources, material, true)
        local otherCenter = other:getBlock(0)

        local box = other:getBoundingBox()

        local displacement = (center.box.size + box.size) * dir * 0.5
        other:displace(displacement)

        local index = plan:addPlan(center.index, other, otherCenter.index)

        table.insert(centers, plan:getBlock(index))

    end

    local scale = size / plan.radius
    plan:scale(vec3(scale, scale, scale))

    return plan
end

function AsteroidPlanGenerator:makeSmallHiddenResourcesAsteroidPlan(size, material)

    -- hidden super rich asteroid
    local flags = {}
    flags.center = self.RichStone
    if random():test(0.2) then flags.center = self.SuperRichStone end

    flags.border = self.Stone
    flags.edge = self.StoneEdge
    flags.corner = self.StoneCorner
    flags.to = 0.25

    return self:makeDefaultAsteroidPlan(size, material, flags)
end

function AsteroidPlanGenerator:makeSmallAsteroidPlan(size, resources, material, forceShape)

    local flags = {}
    if resources or forceShape then
        if resources then
            flags.center = self.RichStone
            flags.border = self.RichStone
            flags.edge = self.RichStoneEdge
            flags.corner = self.RichStoneCorner
        else
            flags.center = self.Stone
            flags.border = self.Stone
            flags.edge = self.StoneEdge
            flags.corner = self.StoneCorner
        end

        material = material or Material(0)

        if material.value == MaterialType.Iron then
            return self:makeDefaultAsteroidPlan(size, material, flags)
        elseif material.value == MaterialType.Titanium then
            return self:makeTitaniumAsteroidPlan(size, material, flags)
        elseif material.value == MaterialType.Naonite then
            flags.from = 1 / 3
            flags.to = 1 / 3

            flags.scaleFromX = 1
            flags.scaleFromY = 1
            flags.scaleFromZ = 1
            flags.scaleToX = 1
            flags.scaleToY = 1
            flags.scaleToZ = 1

            -- scale change to keep relatively similar to old style asteroids
            -- hand tuned
            local fairnessScale = 0.945

            return self:makeDefaultAsteroidPlan(size * fairnessScale, material, flags)
        elseif material.value == MaterialType.Trinium then
            return self:makeTriniumAsteroidPlan(size, material, flags)
        elseif material.value == MaterialType.Xanion then
            return self:makeXanionAsteroidPlan(size, material, flags)
        elseif material.value == MaterialType.Ogonite then
            return self:makeOgoniteAsteroidPlan(size, material, flags)
        elseif material.value == MaterialType.Avorion then
            return self:makeAvorionAsteroidPlan(size, material, flags)
        end
    end

    local flags = {}
    if random():test(0.2) then flags.center = self.StoneCorner end

    return self:makeDefaultAsteroidPlan(size, material, flags)
end

-- "titanium" is actually just the shape - not necessarily the material
function AsteroidPlanGenerator:makeTitaniumAsteroidPlan(size, material, flags)

    local center = flags.center or self.Stone
    local color = material.blockColor

    local part = PlanPart()

    local bsize = vec3(2, 15, 2)

    local root = part:block(-1, nil, center, bsize, color)

    local blocks = {root}
    for i = 1, 29 do
        local next = randomEntry(random(), blocks)
        local dir = random():getDirection() * vec3(20, 5, 20)

        local width = getFloat(1.8, 2.2)
        local height = getFloat(10, 25)
        local bsize = vec3(width, height, width)

        local new = part:block(next, dir, center, bsize, color)
        table.insert(blocks, new)
    end

    -- scale change to keep relatively similar to old style asteroids
    -- hand tuned
    local fairnessScale = 1.22

    local plan = part:getPlan()
    local r = size * 2.0 / plan.radius * fairnessScale -- increase scale to keep up in resources with the other asteroid shapes
    plan:scale(vec3(r))
    plan:setMaterial(material)

    return plan
end

-- "Trinium" is actually just the shape - not necessarily the material
function AsteroidPlanGenerator:makeTriniumAsteroidPlan(size, material, flags)

    local center = flags.center or self.Stone
    local color = material.blockColor

    local part = PlanPart()

    local bsize = vec3(1, 1, 1)

    local root = part:block(-1, nil, center, bsize, color)

    local function coordKey(coord) return string.format("%i_%i_%i", coord.x, coord.y, coord.z) end
    local directions = {"-x", "x", "-y", "y", "-z", "z"}
    local deltas = {}
    deltas["x"] = ivec3(1, 0, 0)
    deltas["y"] = ivec3(0, 1, 0)
    deltas["z"] = ivec3(0, 0, 1)
    deltas["-x"] = ivec3(-1, 0, 0)
    deltas["-y"] = ivec3(0, -1, 0)
    deltas["-z"] = ivec3(0, 0, -1)

    local blocks = {root}
    local coords = {}
    coords[root] = ivec3(0, 0, 0)

    local occupied = {}
    occupied[coordKey(coords[root])] = true

    for i = 1, 29 do
        -- find the next block
        local next = randomEntry(random(), blocks)
        local coord = coords[next]

        -- find the next usable direction
        local usable = {}
        for _, dir in pairs(directions) do
            local delta = deltas[dir]
            local newLocation = coord + delta

            if not occupied[coordKey(newLocation)] then
                table.insert(usable, dir)
            end
        end

        if #usable > 0 then
            local dir = randomEntry(random(), usable)
            local new = part:block(next, dir, center, bsize, color)

            table.insert(blocks, new)

            -- mark cell as occupied
            local delta = deltas[dir]
            local newLocation = coord + delta
            coords[new] = newLocation
            occupied[coordKey(newLocation)] = ture
        end
    end

    part:merge({})
    local remainingBlocks = 30 - part.numBlocks

    for i = 1, remainingBlocks do
        -- find the next block
        local next = randomEntry(random(), blocks)
        local coord = coords[next]

        -- find the next usable direction
        local usable = {}
        for _, dir in pairs(directions) do
            local delta = deltas[dir]
            local newLocation = coord + delta

            if not occupied[coordKey(newLocation)] then
                table.insert(usable, dir)
            end
        end

        if #usable > 0 then
            local size = bsize * getFloat(0.7, 1.2)
            local color = material.blockColor
            if random():test(0.3) then
                size = bsize * getFloat(0.4, 0.6)
            end
            if random():test(0.3) then
                color = ColorHSV(240 + random():getInt(-50, 0), random():getFloat(0.4, 0.7), random():getFloat(0.7, 0.9))
            end

            local dir = randomEntry(random(), usable)
            local new = part:block(next, dir, center, size, color)

            table.insert(blocks, new)

            -- mark cell as occupied
            local delta = deltas[dir]
            local newLocation = coord + delta
            coords[new] = newLocation
            occupied[coordKey(newLocation)] = ture
        end
    end

    -- scale change to keep relatively similar to old style asteroids
    -- hand tuned
    local fairnessScale = 1.1

    local plan = part:getPlan()
    local r = size * 2.0 / plan.radius * fairnessScale -- increase scale to keep up in resources with the other asteroid shapes
    plan:scale(vec3(r))
    plan:setMaterial(material)

    -- print ("blocks: " .. tostring(plan.numBlocks))

    return plan
end

-- "xanion" is actually just the shape - not necessarily the material
function AsteroidPlanGenerator:makeXanionAsteroidPlan(size, material, flags)

    local center = flags.center or self.Stone
    local edge = flags.edge or self.StoneEdge
    local color = material.blockColor

    local part = PlanPart()

    local fw = vec3(0, 0, 1)
    local bw = vec3(0, 0, -1)

    local lf = vec3(1, 0, 0)
    local rg = vec3(-1, 0, 0)

    -- left
    local lffw = MatrixLookUp(lf, fw)
    local lfbw = MatrixLookUp(lf, bw)

    -- right
    local rgfw = MatrixLookUp(rg, fw)
    local rgbw = MatrixLookUp(rg, bw)


    local h = 8
    local d = 2
    local w = 1.1547
    local bsize = vec3(w, h, d)

    local root = part:block(-1, nil, center, bsize, color)

    local sw = w / 2
    part:block(root, vec3(-w, 0, -0.5), edge, vec3(w / 2, h, d / 2), color, lfbw)
    part:block(root, vec3(-w, 0, 0.5), edge, vec3(w / 2, h, d / 2), color, lffw)
    part:block(root, vec3(w, 0, -0.5), edge, vec3(w / 2, h, d / 2), color, rgbw)
    part:block(root, vec3(w, 0, 0.5), edge, vec3(w / 2, h, d / 2), color, rgfw)

    local plan = part:getPlan()
    plan:center()
    local add = copy(plan)

    local row = random():test(0.5)

    for i = 1, 5 do
        local angle = i / 5 * math.pi * 2 + random():getFloat(-0.1, 0.1)

        local p
        if row then
            p = vec3(math.cos(angle), random():getFloat(-2, 2), math.sin(angle)) * d
        else
            p = vec3(math.cos(angle), random():getFloat(-3, 3), angle) * w
        end

        add:displace(p)
        plan:addPlan(0, add, 0)
        add:displace(-p)
    end


    -- scale change to keep relatively similar to old style asteroids
    -- hand tuned
    local fairnessScale = 1.28

    local r = size * 2.0 / plan.radius * fairnessScale -- increase scale to keep up in resources with the other asteroid shapes
    plan:scale(vec3(r))
    plan:setMaterial(material)
    plan:reassignParents("makeXanionAsteroidPlan")

    return plan
end

-- "ogonite" is actually just the shape - not necessarily the material
function AsteroidPlanGenerator:makeOgoniteAsteroidPlan(size, material, flags)

    local center = flags.center or self.Stone
    local edge = flags.edge or self.StoneEdge
    local color = material.blockColor

    local part = PlanPart()

    local fw = vec3(0, 0, 1)
    local bw = vec3(0, 0, -1)

    local lf = vec3(1, 0, 0)
    local rg = vec3(-1, 0, 0)

    -- left
    local lffw = MatrixLookUp(lf, fw)
    local lfbw = MatrixLookUp(lf, bw)

    -- right
    local rgfw = MatrixLookUp(rg, fw)
    local rgbw = MatrixLookUp(rg, bw)


    local h = random():getFloat(0.7, 1.0)
    local d = 2
    local w = 1.1547
    local bsize = vec3(w, h, d)

    local root = part:block(-1, nil, center, bsize, color)

    local sw = w / 2
    part:block(root, vec3(-w, 0, -0.5), edge, vec3(w / 2, h, d / 2), color, lfbw)
    part:block(root, vec3(-w, 0, 0.5), edge, vec3(w / 2, h, d / 2), color, lffw)
    part:block(root, vec3(w, 0, -0.5), edge, vec3(w / 2, h, d / 2), color, rgbw)
    part:block(root, vec3(w, 0, 0.5), edge, vec3(w / 2, h, d / 2), color, rgfw)

    local plan = part:getPlan()
    plan:center()
    local add = copy(plan)

    local y = 0
    for i = 1, 5 do
        local angle = i / 5 * math.pi * 2 + random():getFloat(-0.1, 0.1)

        local s = random():getFloat(0.75, 1.5)
        local sy = random():getFloat(0.8, 1.2)

        local p = vec3(math.cos(angle), 0, math.cos(angle)) * w
        y = y + 0.5
        p.y = y

        add:scale(vec3(s, sy, s))
        add:displace(p)
        plan:addPlan(0, add, 0)
        add:displace(-p)
        add:scale(vec3(1 / s, 1 / sy, 1 / s))
    end


    -- scale change to keep relatively similar to old style asteroids
    -- hand tuned
    local fairnessScale = 1.16

    local r = size * 2.0 / plan.radius * fairnessScale -- increase scale to keep up in resources with the other asteroid shapes
    plan:scale(vec3(r))
    plan:setMaterial(material)
    plan:reassignParents("makeOgoniteAsteroidPlan")

    return plan
end

-- "avorion" is actually just the shape - not necessarily the material
function AsteroidPlanGenerator:makeAvorionAsteroidPlan(size, material, flags)
    local center = flags.center or self.Stone
    local edge = flags.edge or self.StoneEdge
    local color = material.blockColor

    local part = PlanPart()

    local bsize = vec3(2, 8, 2)

    local root = part:block(-1, nil, center, bsize, color)

    local blocks = {root}
    while part.numBlocks <= 27 do
        local next = randomEntry(random(), blocks)
        local dir = random():getDirection() * vec3(4, 5, 4)

        local width = getFloat(1.8, 2.2)
        local height = getFloat(2, 10)
        local bsize = vec3(width, height, width)

        local new = part:block(next, dir, center, bsize, color)
        table.insert(blocks, new)

        local bsize = vec3(width, random():getFloat(2, 4), width)

        if random():test(0.8) then
            local f = 1.0; if random():test(0.2) then f = -1 end
            part:block(new, "y", edge, bsize, color, MatrixLookUp(vec3(-1 * f, 0, 0), vec3(0, 1, 0)))
        end

        if random():test(0.8) then
            local f = 1.0; if random():test(0.2) then f = -1 end
            part:block(new, "-y", edge, bsize, color, MatrixLookUp(vec3(1 * f, 0, 0), vec3(0, -1, 0)))
        end
    end

    -- scale change to keep relatively similar to old style asteroids
    -- hand tuned
    local fairnessScale = 1.355

    local plan = part:getPlan()
    local r = size * 2.0 / plan.radius * fairnessScale -- increase scale to keep up in resources with the other asteroid shapes
    plan:scale(vec3(r))
    plan:setMaterial(material)

    return plan
end

function AsteroidPlanGenerator:makeDefaultAsteroidPlan(size, material, flags)

    material = material or Material(0)
    flags = flags or {}

    local plan = BlockPlan()

    local color = material.blockColor

    local from = flags.from or 0.1
    local to = flags.to or 0.5

    local center = flags.center or self.Stone
    local border = flags.border or self.Stone
    local edge = flags.edge or self.StoneEdge
    local corner = flags.corner or self.StoneCorner

    local ls = vec3(getFloat(from, to), getFloat(from, to), getFloat(from, to))
    local us = vec3(getFloat(from, to), getFloat(from, to), getFloat(from, to))
    local s = vec3(1, 1, 1) - ls - us

    local hls = ls * 0.5
    local hus = us * 0.5
    local hs = s * 0.5

    local ci = plan:addBlock(vec3(0, 0, 0), s, -1, -1, color, material, Matrix(), center, ColorNone())

    -- top bottom
    plan:addBlock(vec3(0, hs.y + hus.y, 0), vec3(s.x, us.y, s.z), ci, -1, color, material, Matrix(), border, ColorNone())
    plan:addBlock(vec3(0, -hs.y - hls.y, 0), vec3(s.x, ls.y, s.z), ci, -1, color, material, Matrix(), border, ColorNone())

    -- left right
    plan:addBlock(vec3(hs.x + hus.x, 0, 0), vec3(us.x, s.y, s.z), ci, -1, color, material, Matrix(), border, ColorNone())
    plan:addBlock(vec3(-hs.x - hls.x, 0, 0), vec3(ls.x, s.y, s.z), ci, -1, color, material, Matrix(), border, ColorNone())

    -- front back
    plan:addBlock(vec3(0, 0, hs.z + hus.z), vec3(s.x, s.y, us.z), ci, -1, color, material, Matrix(), border, ColorNone())
    plan:addBlock(vec3(0, 0, -hs.z - hls.z), vec3(s.x, s.y, ls.z), ci, -1, color, material, Matrix(), border, ColorNone())


    -- top left right
    plan:addBlock(vec3(hs.x + hus.x, hs.y + hus.y, 0), vec3(us.x, us.y, s.z), ci, -1, color, material, MatrixLookUp(vec3(-1, 0, 0), vec3(0, 1, 0)), edge, ColorNone())
    plan:addBlock(vec3(-hs.x - hls.x, hs.y + hus.y, 0), vec3(ls.x, us.y, s.z), ci, -1, color, material, MatrixLookUp(vec3(1, 0, 0), vec3(0, 1, 0)), edge, ColorNone())

    -- top front back
    plan:addBlock(vec3(0, hs.y + hus.y, hs.z + hus.z), vec3(s.x, us.y, us.z), ci, -1, color, material, MatrixLookUp(vec3(0, 0, -1), vec3(0, 1, 0)), edge, ColorNone())
    plan:addBlock(vec3(0, hs.y + hus.y, -hs.z - hls.z), vec3(s.x, us.y, ls.z), ci, -1, color, material, MatrixLookUp(vec3(0, 0, 1), vec3(0, 1, 0)), edge, ColorNone())

    -- bottom left right
    plan:addBlock(vec3(hs.x + hus.x, -hs.y - hls.y, 0), vec3(us.x, ls.y, s.z), ci, -1, color, material, MatrixLookUp(vec3(-1, 0, 0), vec3(0, -1, 0)), edge, ColorNone())
    plan:addBlock(vec3(-hs.x - hls.x, -hs.y - hls.y, 0), vec3(ls.x, ls.y, s.z), ci, -1, color, material, MatrixLookUp(vec3(1, 0, 0), vec3(0, -1, 0)), edge, ColorNone())

    -- bottom front back
    plan:addBlock(vec3(0, -hs.y - hls.y, hs.z + hus.z), vec3(s.x, ls.y, us.z), ci, -1, color, material, MatrixLookUp(vec3(0, 0, -1), vec3(0, -1, 0)), edge, ColorNone())
    plan:addBlock(vec3(0, -hs.y - hls.y, -hs.z - hls.z), vec3(s.x, ls.y, ls.z), ci, -1, color, material, MatrixLookUp(vec3(0, 0, 1), vec3(0, -1, 0)), edge, ColorNone())

    -- middle left right
    plan:addBlock(vec3(hs.x + hus.x, 0, -hs.z - hls.z), vec3(us.x, s.y, ls.z), ci, -1, color, material, MatrixLookUp(vec3(-1, 0, 0), vec3(0, 0, -1)), edge, ColorNone())
    plan:addBlock(vec3(-hs.x - hls.x, 0, -hs.z - hls.z), vec3(ls.x, s.y, ls.z), ci, -1, color, material, MatrixLookUp(vec3(1, 0, 0), vec3(0, 0, -1)), edge, ColorNone())

    -- middle front back
    plan:addBlock(vec3(hs.x + hus.x, 0, hs.z + hus.z), vec3(us.x, s.y, us.z), ci, -1, color, material, MatrixLookUp(vec3(-1, 0, 0), vec3(0, 0, 1)), edge, ColorNone())
    plan:addBlock(vec3(-hs.x - hls.x, 0, hs.z + hus.z), vec3(ls.x, s.y, us.z), ci, -1, color, material, MatrixLookUp(vec3(1, 0, 0), vec3(0, 0, 1)), edge, ColorNone())


    -- top edges
    -- left right
    plan:addBlock(vec3(hs.x + hus.x, hs.y + hus.y, -hs.z - hls.z), vec3(us.x, us.y, ls.z), ci, -1, color, material, MatrixLookUp(vec3(-1, 0, 0), vec3(0, 1, 0)), corner, ColorNone())
    plan:addBlock(vec3(-hs.x - hls.x, hs.y + hus.y, -hs.z - hls.z), vec3(ls.x, us.y, ls.z), ci, -1, color, material, MatrixLookUp(vec3(1, 0, 0), vec3(0, 0, -1)), corner, ColorNone())

    -- front back
    plan:addBlock(vec3(hs.x + hus.x, hs.y + hus.y, hs.z + hus.z), vec3(us.x, us.y, us.z), ci, -1, color, material, MatrixLookUp(vec3(-1, 0, 0), vec3(0, 0, 1)), corner, ColorNone())
    plan:addBlock(vec3(-hs.x - hls.x, hs.y + hus.y, hs.z + hus.z), vec3(ls.x, us.y, us.z), ci, -1, color, material, MatrixLookUp(vec3(1, 0, 0), vec3(0, 1, 0)), corner, ColorNone())

    -- bottom edges
    -- left right
    plan:addBlock(vec3(hs.x + hus.x, -hs.y - hls.y, -hs.z - hls.z), vec3(us.x, ls.y, ls.z), ci, -1, color, material, MatrixLookUp(vec3(0, 0, 1), vec3(0, -1, 0)), corner, ColorNone())
    plan:addBlock(vec3(-hs.x - hls.x, -hs.y - hls.y, -hs.z - hls.z), vec3(ls.x, ls.y, ls.z), ci, -1, color, material, MatrixLookUp(vec3(1, 0, 0), vec3(0, -1, 0)), corner, ColorNone())

    -- front back
    plan:addBlock(vec3(hs.x + hus.x, -hs.y - hls.y, hs.z + hus.z), vec3(us.x, ls.y, us.z), ci, -1, color, material, MatrixLookUp(vec3(-1, 0, 0), vec3(0, -1, 0)), corner, ColorNone())
    plan:addBlock(vec3(-hs.x - hls.x, -hs.y - hls.y, hs.z + hus.z), vec3(ls.x, ls.y, us.z), ci, -1, color, material, MatrixLookUp(vec3(0, 0, -1), vec3(0, -1, 0)), corner, ColorNone())

    local scaleFromX = flags.scaleFromX or 0.3
    local scaleFromY = flags.scaleFromY or 0.3
    local scaleFromZ = flags.scaleFromZ or 0.3

    local scaleToX = flags.scaleToX or 1.5
    local scaleToY = flags.scaleToY or 1.5
    local scaleToZ = flags.scaleToZ or 1.5

    plan:scale(vec3(getFloat(scaleFromX, scaleToX), getFloat(scaleFromY, scaleToY), getFloat(scaleFromZ, scaleToZ)))

    local r = size * 2.0 / plan.radius
    plan:scale(vec3(r, r, r))

    plan.convex = true

    return plan
end

function AsteroidPlanGenerator:makeMonolithAsteroidPlan(size, material, flags)
    material = material or Material(0)
    flags = flags or {}

    local plan = BlockPlan()

    local color = material.blockColor
    local center = flags.center or self.Stone
    local matrix = Matrix()

    local function variedSize() return
        vec3(random():getFloat(1.0, 1.2),
             random():getFloat(1.0, 1.2),
             random():getFloat(0.7, 1.2))
    end

    local starters = {}
    table.insert(starters, plan:addBlock(vec3(1, 0, 0), variedSize(), 0, -1, color, material, matrix, center, ColorNone()))
    table.insert(starters, plan:addBlock(vec3(2, 0, 0), variedSize(), starters[1], -1, color, material, matrix, center, ColorNone()))
    table.insert(starters, plan:addBlock(vec3(3, 0, 0), variedSize(), starters[2], -1, color, material, matrix, center, ColorNone()))

    for x, starter in pairs(starters) do
        local previous = starter

        for i = 1, 9 do
            previous = plan:addBlock(vec3(x, 1 * i, 0), variedSize(), previous, -1, color, material, matrix, center, ColorNone())
        end
    end

    local r = size * 2.0 / plan.radius
    plan:scale(vec3(r, r, r))

    return plan
end

function AsteroidPlanGenerator:makeCuboidAsteroidPlan(size, material, flags)
    material = material or Material(0)
    flags = flags or {}

    local plan = BlockPlan()

    local color = material.blockColor
    local center = flags.center or self.Stone
    local matrix = Matrix()

    local function variedSize() return
        vec3(1 + random():getFloat(0, 0.3),
             1 + random():getFloat(0, 0.3),
             1 + random():getFloat(0, 0.3))
    end

    local starters = {}
    table.insert(starters, {x=1, z=1, b=plan:addBlock(vec3(1, 0, 1), variedSize(), 0, -1, color, material, matrix, center, ColorNone())})
    table.insert(starters, {x=2, z=1, b=plan:addBlock(vec3(2, 0, 1), variedSize(), starters[1], -1, color, material, matrix, center), ColorNone()})
    table.insert(starters, {x=3, z=1, b=plan:addBlock(vec3(3, 0, 1), variedSize(), starters[2], -1, color, material, matrix, center), ColorNone()})
    table.insert(starters, {x=1, z=2, b=plan:addBlock(vec3(1, 0, 2), variedSize(), starters[1], -1, color, material, matrix, center), ColorNone()})
    table.insert(starters, {x=2, z=2, b=plan:addBlock(vec3(2, 0, 2), variedSize(), starters[4], -1, color, material, matrix, center), ColorNone()})
    table.insert(starters, {x=3, z=2, b=plan:addBlock(vec3(3, 0, 2), variedSize(), starters[5], -1, color, material, matrix, center), ColorNone()})
    table.insert(starters, {x=1, z=3, b=plan:addBlock(vec3(1, 0, 3), variedSize(), starters[4], -1, color, material, matrix, center), ColorNone()})
    table.insert(starters, {x=2, z=3, b=plan:addBlock(vec3(2, 0, 3), variedSize(), starters[6], -1, color, material, matrix, center), ColorNone()})
    table.insert(starters, {x=3, z=3, b=plan:addBlock(vec3(3, 0, 3), variedSize(), starters[7], -1, color, material, matrix, center), ColorNone()})

    for _, starter in pairs(starters) do
        local previous = starter.b

        for i = 1, 2 do
            previous = plan:addBlock(vec3(starter.x, i, starter.z), variedSize(), previous, -1, color, material, matrix, center, ColorNone())
        end
    end

    local r = size * 2.0 / plan.radius
    plan:scale(vec3(r, r, r))

    return plan
end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
