package.path = package.path .. ";data/scripts/lib/?.lua"

include ("utility")
include ("plangeneratorbase")

GeneratorColors =
{
    IndustrialYellow = {r = 1, g = 0.65, b = 0.05},
    Darkest = {r = 0.2, g = 0.2, b = 0.2},
    Brightest = {r = 0.7, g = 0.7, b = 0.7},
    FarmColor1 = {r = 0.4, g = 0.3, b = 0.15},
    FarmColor2 = {r = 0.05, g = 0.1, b = 0.05},
    FarmColor3 = {r = 0.1, g = 0.3, b = 0.1},
    FarmColor4 = {r = 0.15, g = 0.25, b = 0.15},
}

fw = vec3(0, 0, 1)
bw = vec3(0, 0, -1)

up = vec3(0, 1, 0)
dn = vec3(0, -1, 0)

lf = vec3(1, 0, 0)
rg = vec3(-1, 0, 0)

-- forward
fwup = MatrixLookUp(fw, up)
fwdn = MatrixLookUp(fw, dn)
fwlf = MatrixLookUp(fw, lf)
fwrg = MatrixLookUp(fw, rg)

-- backward
bwup = MatrixLookUp(bw, up)
bwdn = MatrixLookUp(bw, dn)
bwlf = MatrixLookUp(bw, lf)
bwrg = MatrixLookUp(bw, rg)

-- up
upfw = MatrixLookUp(up, fw)
upbw = MatrixLookUp(up, bw)
uplf = MatrixLookUp(up, lf)
uprg = MatrixLookUp(up, rg)

-- down
dnfw = MatrixLookUp(dn, fw)
dnbw = MatrixLookUp(dn, bw)
dnlf = MatrixLookUp(dn, lf)
dnrg = MatrixLookUp(dn, rg)


-- left
lffw = MatrixLookUp(lf, fw)
lfbw = MatrixLookUp(lf, bw)
lfup = MatrixLookUp(lf, up)
lfdn = MatrixLookUp(lf, dn)

-- right
rgfw = MatrixLookUp(rg, fw)
rgbw = MatrixLookUp(rg, bw)
rgup = MatrixLookUp(rg, up)
rgdn = MatrixLookUp(rg, dn)


-- assign as ivecs now so they can be used for directions
fw = ivec3(fw.x, fw.y, fw.z)
bw = ivec3(bw.x, bw.y, bw.z)

up = ivec3(up.x, up.y, up.z)
dn = ivec3(dn.x, dn.y, dn.z)

lf = ivec3(lf.x, lf.y, lf.z)
rg = ivec3(rg.x, rg.y, rg.z)

function isPX(value) return value == "x" or value == "+x" or value == "px" end
function isNX(value) return value == "-x" or value == "nx" end

function isPY(value) return value == "y" or value == "+y" or value == "py" end
function isNY(value) return value == "-y" or value == "ny" end

function isPZ(value) return value == "z" or value == "+z" or value == "pz" end
function isNZ(value) return value == "-z" or value == "nz" end

function isX(value) return isPX(value) or isNX(value) end
function isY(value) return isPY(value) or isNY(value) end
function isZ(value) return isPZ(value) or isNZ(value) end

function getAxis(value)
    if isX(value) then return "x" end
    if isY(value) then return "y" end
    return "z"
end

function getStretchFactor(features, factor)
    factor = factor or 4

    local possible = {}
    for _, feature in pairs(OptionalFeatures) do
        possible[feature] = true
    end
    for _, feature in pairs(Features) do
        possible[feature] = true
    end

    local result = vec3(1)
    if features[VisualFeature.LongX] and possible[VisualFeature.LongX] then result.x = factor end
    if features[VisualFeature.LongY] and possible[VisualFeature.LongY] then result.y = factor end
    if features[VisualFeature.LongZ] and possible[VisualFeature.LongZ] then result.z = factor end

    return result
end

function switchBaseColors(random, settings, chance)
    if random:test(chance) then
        local a = settings.colors.base
        settings.colors.base = settings.colors.paint
        settings.colors.paint = a
    end
end

function sphere(part, parent, lower, upper, flags)

    flags = flags or {}

    local corner = flags.corner or BlockType.CornerHull
    local edge = flags.edge or BlockType.EdgeHull
    local specialEdge = BlockType.EdgeHull

    local xRingColor = flags.xRingColor
    local yRingColor = flags.yRingColor
    local zRingColor = flags.zRingColor


    if corner == BlockType.OuterCornerArmor or corner == BlockType.OuterCornerHull then
        specialEdge = BlockType.Hull
    end

    specialEdge = flags.specialEdge or specialEdge

    local blocks = { }
    blocks.root = parent

    local block = part:getBlock(parent)
    local s = block.box.size
    local l = lower or 0.5
    local u = upper or l
    local basicColor = flags.basicColor or block.color

    if type(s) == "number" then s = vec3(s) end
    if type(l) == "number" then l = vec3(l) end
    if type(u) == "number" then u = vec3(u) end


    blocks.top = part:block(blocks.root, "y", BlockType.Hull, vec3(s.x, u.y, s.z), xRingColor or zRingColor)
    blocks.bottom = part:block(blocks.root, "-y", BlockType.Hull, vec3(s.x, l.y, s.z), xRingColor or zRingColor)
    blocks.right = part:block(blocks.root, "-x", BlockType.Hull, vec3(l.x, s.y, s.z), yRingColor or zRingColor)
    blocks.left = part:block(blocks.root, "x", BlockType.Hull, vec3(u.x, s.y, s.z), yRingColor or zRingColor)
    blocks.front = part:block(blocks.root, "z", BlockType.Hull, vec3(s.x, s.y, u.z), yRingColor or xRingColor)
    blocks.back = part:block(blocks.root, "-z", BlockType.Hull, vec3(s.x, s.y, l.z), yRingColor or xRingColor)


    blocks.topLeft = part:block(blocks.left, "y", edge, vec3(u.x, u.y, s.z), zRingColor or basicColor, rgup)
    blocks.topRight = part:block(blocks.right, "y", edge, vec3(l.x, u.y, s.z), zRingColor or basicColor, lfup)

    blocks.bottomLeft = part:block(blocks.left, "-y", edge, vec3(u.x, l.y, s.z), zRingColor or basicColor, rgdn)
    blocks.bottomRight = part:block(blocks.right, "-y", edge, vec3(l.x, l.y, s.z), zRingColor or basicColor, lfdn)

    blocks.topFront = part:block(blocks.front, "y", edge, vec3(s.x, u.y, u.z), xRingColor or basicColor, bwup)
    blocks.topBack = part:block(blocks.back, "y", edge, vec3(s.x, u.y, l.z), xRingColor or basicColor, fwup)

    blocks.bottomFront = part:block(blocks.front, "-y", edge, vec3(s.x, l.y, u.z), xRingColor or basicColor, bwdn)
    blocks.bottomBack = part:block(blocks.back, "-y", edge, vec3(s.x, l.y, l.z), xRingColor or basicColor, fwdn)

    blocks.frontRight = part:block(blocks.front, "-x", specialEdge, vec3(l.x, s.y, u.z), yRingColor or basicColor, bwrg)
    blocks.backRight = part:block(blocks.back, "-x", specialEdge, vec3(l.x, s.y, l.z), yRingColor or basicColor, fwrg)

    blocks.frontLeft = part:block(blocks.front, "x", specialEdge, vec3(u.x, s.y, u.z), yRingColor or basicColor, bwlf)
    blocks.backLeft = part:block(blocks.back, "x", specialEdge, vec3(u.x, s.y, l.z), yRingColor or basicColor, fwlf)


    blocks.topBackLeft = part:block(blocks.backLeft, "y", corner, vec3(u.x, u.y, l.z), basicColor, rgup)
    blocks.topFrontLeft = part:block(blocks.frontLeft, "y", corner, vec3(u.x, u.y, u.z), basicColor, bwup)

    blocks.topBackRight = part:block(blocks.backRight, "y", corner, vec3(l.x, u.y, l.z), basicColor, fwup)
    blocks.topFrontRight = part:block(blocks.frontRight, "y", corner, vec3(l.x, u.y, u.z), basicColor, lfup)

    blocks.bottomFrontLeft = part:block(blocks.frontLeft, "-y", corner, vec3(u.x, l.y, u.z), basicColor, rgdn)
    blocks.bottomFrontRight = part:block(blocks.frontRight, "-y", corner, vec3(l.x, l.y, u.z), basicColor, bwdn)

    blocks.bottomBackLeft = part:block(blocks.backLeft, "-y", corner, vec3(u.x, l.y, l.z), basicColor, fwdn)
    blocks.bottomBackRight = part:block(blocks.backRight, "-y", corner, vec3(l.x, l.y, l.z), basicColor, lfdn)

    -- convenience
    local b = blocks
    blocks.frontBlocks = {b.front, b.topFront, b.bottomFront, b.frontRight, b.frontLeft, b.topFrontRight, b.topFrontLeft, b.bottomFrontRight, b.bottomFrontLeft}
    blocks.backBlocks = {b.back, b.topBack, b.bottomBack, b.backRight, b.backLeft, b.topBackRight, b.topBackLeft, b.bottomBackRight, b.bottomBackLeft}
    blocks.topBlocks = {b.top, b.topLeft, b.topRight, b.topFront, b.topBack, b.topBackLeft, b.topFrontLeft, b.topBackRight, b.topFrontRight}
    blocks.bottomBlocks = {b.bottom, b.bottomLeft, b.bottomRight, b.bottomFront, b.bottomBack, b.bottomBackLeft, b.bottomFrontLeft, b.bottomBackRight, b.bottomFrontRight}
    blocks.leftBlocks = {b.left, b.topLeft, b.bottomLeft, b.frontLeft, b.backLeft, b.topFrontLeft, b.topBackLeft, b.bottomFrontLeft, b.bottomBackLeft}
    blocks.rightBlocks = {b.right, b.topRight, b.bottomRight, b.frontRight, b.backRight, b.topFrontRight, b.topBackRight, b.bottomFrontRight, b.bottomBackRight}

    blocks.blocks = {b.top, b.bottom, b.left, b.right, b.front, b.back}
    blocks.edges = {b.topLeft, b.topRight, b.bottomLeft, b.bottomRight, b.topFront, b.topBack, b.bottomFront, b.bottomBack, b.frontRight, b.backRight, b.frontLeft, b.backLeft}
    blocks.corners = {b.topBackLeft, b.topFrontLeft, b.topBackRight, b.topFrontRight, b.bottomFrontLeft, b.bottomFrontRight, b.bottomBackLeft, b.bottomBackRight}

    blocks.topCorners = {b.topBackLeft, b.topFrontLeft, b.topBackRight, b.topFrontRight}
    blocks.bottomCorners = {b.bottomFrontLeft, b.bottomFrontRight, b.bottomBackLeft, b.bottomBackRight}
    blocks.leftCorners = {b.topBackLeft, b.topFrontLeft, b.bottomFrontLeft, b.bottomBackLeft}
    blocks.rightCorners = {b.topBackRight, b.topFrontRight, b.bottomFrontRight, b.bottomBackRight}
    blocks.frontCorners = {b.topFrontLeft, b.topFrontRight, b.bottomFrontLeft, b.bottomFrontRight}
    blocks.backCorners = {b.topBackLeft, b.topBackRight, b.bottomBackLeft, b.bottomBackRight}

    blocks.topEdges = {b.topLeft, b.topRight, b.topFront, b.topBack}
    blocks.bottomEdges = {b.bottomLeft, b.bottomRight, b.bottomFront, b.bottomBack}
    blocks.leftEdges = {b.bottomLeft, b.topLeft, b.frontLeft, b.backLeft}
    blocks.rightEdges = {b.bottomRight, b.topRight, b.frontRight, b.backRight}
    blocks.frontEdges = {b.frontRight, b.frontLeft, b.topFront, b.bottomFront}
    blocks.backEdges = {b.backRight, b.backLeft, b.topBack, b.bottomBack}

    blocks.xRing = {b.top, b.bottom, b.front, b.back, b.topFront, b.topBack, b.bottomFront, b.bottomBack}
    blocks.yRing = {b.front, b.back, b.left, b.right, b.frontRight, b.backRight, b.frontLeft, b.backLeft}
    blocks.zRing = {b.top, b.bottom, b.right, b.left, b.topLeft, b.topRight, b.bottomRight, b.bottomLeft}

    return blocks, blocks.root
end

function ring(part, parent, dir, lower, upper, flags)

    flags = flags or {}

    local edge = flags.edge or BlockType.EdgeHull
    local color = flags.color

    local blocks = { }
    blocks.root = parent

    local s = part:getBlock(parent).box.size
    local l = lower or 0.5
    local u = upper or l

    if type(s) == "number" then s = vec3(s) end
    if type(l) == "number" then l = vec3(l) end
    if type(u) == "number" then u = vec3(u) end

    local x, y, z
    if isX(dir) then
        x = true
    elseif isY(dir) then
        y = true
    elseif isZ(dir) then
        z = true
    end

    if x or z then blocks.top = part:block(blocks.root, "y", BlockType.Hull, vec3(s.x, u.y, s.z), color) end
    if x or z then blocks.bottom = part:block(blocks.root, "-y", BlockType.Hull, vec3(s.x, l.y, s.z), color) end
    if z or y then blocks.right = part:block(blocks.root, "-x", BlockType.Hull, vec3(l.x, s.y, s.z), color) end
    if z or y then blocks.left = part:block(blocks.root, "x", BlockType.Hull, vec3(u.x, s.y, s.z), color) end
    if x or y then blocks.front = part:block(blocks.root, "z", BlockType.Hull, vec3(s.x, s.y, u.z), color) end
    if x or y then blocks.back = part:block(blocks.root, "-z", BlockType.Hull, vec3(s.x, s.y, l.z), color) end

    if z then blocks.topLeft = part:block(blocks.left, "y", edge, vec3(u.x, u.y, s.z), color, rgup) end
    if z then blocks.topRight = part:block(blocks.right, "y", edge, vec3(l.x, u.y, s.z), color, lfup) end

    if z then blocks.bottomLeft = part:block(blocks.left, "-y", edge, vec3(u.x, l.y, s.z), color, rgdn) end
    if z then blocks.bottomRight = part:block(blocks.right, "-y", edge, vec3(l.x, l.y, s.z), color, lfdn) end

    if x then blocks.topFront = part:block(blocks.front, "y", edge, vec3(s.x, u.y, u.z), color, bwup) end
    if x then blocks.topBack = part:block(blocks.back, "y", edge, vec3(s.x, u.y, l.z), color, fwup) end

    if x then blocks.bottomFront = part:block(blocks.front, "-y", edge, vec3(s.x, l.y, u.z), color, bwdn) end
    if x then blocks.bottomBack = part:block(blocks.back, "-y", edge, vec3(s.x, l.y, l.z), color, fwdn) end

    if y then blocks.frontRight = part:block(blocks.front, "-x", edge, vec3(l.x, s.y, u.z), color, bwrg) end
    if y then blocks.backRight = part:block(blocks.back, "-x", edge, vec3(l.x, s.y, l.z), color, fwrg) end

    if y then blocks.frontLeft = part:block(blocks.front, "x", edge, vec3(u.x, s.y, u.z), color, bwlf) end
    if y then blocks.backLeft = part:block(blocks.back, "x", edge, vec3(u.x, s.y, l.z), color, fwlf) end

    -- convenience
    local b = blocks
    blocks.frontBlocks = {b.front, b.topFront, b.bottomFront, b.frontRight, b.frontLeft}
    blocks.backBlocks = {b.back, b.topBack, b.bottomBack, b.backRight, b.backLeft}
    blocks.topBlocks = {b.top, b.topLeft, b.topRight, b.topFront, b.topBack}
    blocks.bottomBlocks = {b.bottom, b.bottomLeft, b.bottomRight, b.bottomFront, b.bottomBack}
    blocks.leftBlocks = {b.left, b.topLeft, b.bottomLeft, b.frontLeft, b.backLeft}
    blocks.rightBlocks = {b.right, b.topRight, b.bottomRight, b.frontRight, b.backRight}

    blocks.blocks = {b.top, b.bottom, b.left, b.right, b.front, b.back}
    blocks.edges = {b.topLeft, b.topRight, b.bottomLeft, b.bottomRight, b.topFront, b.topBack, b.bottomFront, b.bottomBack, b.frontRight, b.backRight, b.frontLeft, b.backLeft}

    blocks.topEdges = {b.topLeft, b.topRight, b.topFront, b.topBack}
    blocks.bottomEdges = {b.bottomLeft, b.bottomRight, b.bottomFront, b.bottomBack}
    blocks.leftEdges = {b.bottomLeft, b.topLeft, b.frontLeft, b.backLeft}
    blocks.rightEdges = {b.bottomRight, b.topRight, b.frontRight, b.backRight}
    blocks.frontEdges = {b.frontRight, b.frontLeft, b.topFront, b.bottomFront}
    blocks.backEdges = {b.backRight, b.backLeft, b.topBack, b.bottomBack}

    return blocks, blocks.root
end

function smallHollowRing(part, parent, dir, factor, ringLength, flags)

    flags = flags or {}

    local dir = dir or "-z"
    local edge = flags.edge or BlockType.EdgeHull
    local color = flags.color

    local factor = factor or 1 -- the overall size, since the basic ring is not very big
    local ringWidth = factor * 1 or 1 -- has to stay in relation to factor or everything will get skewed
    local ringLength = ringLength or 1 -- the z to -z "length" of the ring (the width?)

    local blocks = { }
    blocks.root = parent

    blocks.center = part:block(blocks.root, "-z", BlockType.Hull, vec3(factor, factor, ringLength), color)
    blocks.topArmBottom = part:block(blocks.center, "y", BlockType.Hull, vec3(factor, 0.1, ringLength - (ringLength/2)), color)
    blocks.topArm = part:block(blocks.topArmBottom, "y", BlockType.Hull, vec3(factor, (2.5 * factor + ringWidth) - 0.2, ringLength - (ringLength/2)), color)
    blocks.topArmTop = part:block(blocks.topArm, "y", BlockType.Hull, vec3(factor, 0.1, ringLength - (ringLength/2)), color)

    blocks.top = part:block(blocks.topArmTop, "y", BlockType.Hull, vec3(2 * factor, ringWidth, ringLength), color)

    blocks.topLeftRingPart2 = part:block(blocks.top, "x", BlockType.EdgeHull, vec3(2 * factor, ringWidth, ringLength), color, rgup)
    blocks.topLeftRingPart3 = part:block(blocks.topLeftRingPart2, "-y", BlockType.EdgeHull, vec3(2 * factor, ringWidth, ringLength), color, lfdn)
    blocks.topLeftRingPart4 = part:block(blocks.topLeftRingPart3, "x", BlockType.EdgeHull, vec3(ringWidth, ringWidth, ringLength), color, rgup)
    blocks.topLeftRingPart5 = part:block(blocks.topLeftRingPart4, "-y", BlockType.EdgeHull, vec3(ringWidth, 2 * factor, ringLength), color, lfdn)
    blocks.topLeftRingPart6 = part:block(blocks.topLeftRingPart5, "x", BlockType.EdgeHull, vec3(ringWidth, 2 * factor, ringLength), color, rgup)
    blocks.left = part:block(blocks.topLeftRingPart6, "-y", BlockType.Hull, vec3(ringWidth, 2 * factor, ringLength), color)

    -- bottom left quarter
    blocks.bottomLeftRingPart2 = part:block(blocks.left, "-y", BlockType.EdgeHull, vec3(ringWidth, 2 * factor, ringLength), color, rgdn)
    blocks.bottomLeftRingPart3 = part:block(blocks.bottomLeftRingPart2, "-x", BlockType.EdgeHull, vec3(ringWidth, 2 * factor, ringLength), color, lfup)
    blocks.bottomLeftRingPart4 = part:block(blocks.bottomLeftRingPart3, "-y", BlockType.EdgeHull, vec3(ringWidth, ringWidth, ringLength), color, rgdn)
    blocks.bottomLeftRingPart5 = part:block(blocks.bottomLeftRingPart4, "-x", BlockType.EdgeHull, vec3(2 * factor, ringWidth, ringLength), color, lfup)
    blocks.bottomLeftRingPart6 = part:block(blocks.bottomLeftRingPart5, "-y", BlockType.EdgeHull, vec3(2 * factor, ringWidth, ringLength), color, rgdn)
    blocks.bottom = part:block(blocks.bottomLeftRingPart6, "-x", BlockType.Hull, vec3(2 * factor, ringWidth, ringLength), color)

    -- bottom right quarter
    blocks.bottomRightRingPart2 = part:block(blocks.bottom, "-x", BlockType.EdgeHull, vec3(2 * factor, ringWidth, ringLength), color, lfdn)
    blocks.bottomRightRingPart3 = part:block(blocks.bottomRightRingPart2, "y", BlockType.EdgeHull, vec3(2 * factor, ringWidth, ringLength), color, rgup)
    blocks.bottomRightRingPart4 = part:block(blocks.bottomRightRingPart3, "-x", BlockType.EdgeHull, vec3(ringWidth, ringWidth, ringLength), color, lfdn)
    blocks.bottomRightRingPart5 = part:block(blocks.bottomRightRingPart4, "y", BlockType.EdgeHull, vec3(ringWidth, 2 * factor, ringLength), color, rgup)
    blocks.bottomRightRingPart6 = part:block(blocks.bottomRightRingPart5, "-x", BlockType.EdgeHull, vec3(ringWidth, 2 * factor, ringLength), color, lfdn)
    blocks.right = part:block(blocks.bottomRightRingPart6, "y", BlockType.Hull, vec3(ringWidth, 2 * factor, ringLength), color)

    -- top right quarter
    blocks.topRightRingPart2 = part:block(blocks.top, "-x", BlockType.EdgeHull, vec3(2 * factor, ringWidth, ringLength), color, lfup)
    blocks.topRightRingPart3 = part:block(blocks.topRightRingPart2, "-y", BlockType.EdgeHull, vec3(2 * factor, ringWidth, ringLength), color, rgdn)
    blocks.topRightRingPart4 = part:block(blocks.topRightRingPart3, "-x", BlockType.EdgeHull, vec3(ringWidth, ringWidth, ringLength), color, lfup)
    blocks.topRightRingPart5 = part:block(blocks.topRightRingPart4, "-y", BlockType.EdgeHull, vec3(ringWidth, 2 * factor, ringLength), color, rgdn)
    blocks.topRightRingPart6 = part:block(blocks.topRightRingPart5, "-x", BlockType.EdgeHull, vec3(ringWidth, 2 * factor, ringLength), color, lfup)

    return blocks, blocks.root
end

function smallHollowHalfRing(part, parent, dir, factor, ringLength, flags)

    flags = flags or {}

    local dir = dir or "-z"
    local edge = flags.edge or BlockType.EdgeHull
    local color = flags.color

    local factor = factor or 1 -- the overall size, since the basic ring is not very big
    local ringWidth = factor * 1 or 1 -- has to stay in relation to factor or everything will get skewed
    local ringLength = ringLength or 1 -- the z to -z "length" of the ring (the width?)

    local blocks = { }
    blocks.root = parent

    blocks.center = part:block(blocks.root, "-z", BlockType.Hull, vec3(factor, factor, ringLength), color)
    blocks.topArmBottom = part:block(blocks.center, "y", BlockType.Hull, vec3(factor, 0.1, ringLength - (ringLength/2)), color)
    blocks.topArm = part:block(blocks.topArmBottom, "y", BlockType.Hull, vec3(factor, (2.5 * factor + ringWidth) - 0.2, ringLength - (ringLength/2)), color)
    blocks.topArmTop = part:block(blocks.topArm, "y", BlockType.Hull, vec3(factor, 0.1, ringLength - (ringLength/2)), color)

    blocks.top = part:block(blocks.topArmTop, "y", BlockType.Hull, vec3(2 * factor, ringWidth, ringLength), color)

    blocks.topLeftRingPart2 = part:block(blocks.top, "x", BlockType.EdgeHull, vec3(2 * factor, ringWidth, ringLength), color, rgup)
    blocks.topLeftRingPart3 = part:block(blocks.topLeftRingPart2, "-y", BlockType.EdgeHull, vec3(2 * factor, ringWidth, ringLength), color, lfdn)
    blocks.topLeftRingPart4 = part:block(blocks.topLeftRingPart3, "x", BlockType.EdgeHull, vec3(ringWidth, ringWidth, ringLength), color, rgup)
    blocks.topLeftRingPart5 = part:block(blocks.topLeftRingPart4, "-y", BlockType.EdgeHull, vec3(ringWidth, 2 * factor, ringLength), color, lfdn)
    blocks.topLeftRingPart6 = part:block(blocks.topLeftRingPart5, "x", BlockType.EdgeHull, vec3(ringWidth, 2 * factor, ringLength), color, rgup)
    blocks.left = part:block(blocks.topLeftRingPart6, "-y", BlockType.Hull, vec3(ringWidth, 2 * factor, ringLength), color)

    -- top right quarter
    blocks.topRightRingPart2 = part:block(blocks.top, "-x", BlockType.EdgeHull, vec3(2 * factor, ringWidth, ringLength), color, lfup)
    blocks.topRightRingPart3 = part:block(blocks.topRightRingPart2, "-y", BlockType.EdgeHull, vec3(2 * factor, ringWidth, ringLength), color, rgdn)
    blocks.topRightRingPart4 = part:block(blocks.topRightRingPart3, "-x", BlockType.EdgeHull, vec3(ringWidth, ringWidth, ringLength), color, lfup)
    blocks.topRightRingPart5 = part:block(blocks.topRightRingPart4, "-y", BlockType.EdgeHull, vec3(ringWidth, 2 * factor, ringLength), color, rgdn)
    blocks.topRightRingPart6 = part:block(blocks.topRightRingPart5, "-x", BlockType.EdgeHull, vec3(ringWidth, 2 * factor, ringLength), color, lfup)

    blocks.right = part:block(blocks.topRightRingPart6, "-y", BlockType.Hull, vec3(ringWidth, 2 * factor, ringLength), color)

    return blocks, blocks.root
end

function smallHollowQuarterRing(part, parent, dir, factor, ringLength, flags)

    flags = flags or {}

    local dir = dir or "-z"
    local edge = flags.edge or BlockType.EdgeHull
    local color = flags.color

    local factor = factor or 1 -- the overall size, since the basic ring is not very big
    local ringWidth = factor * 1 or 1 -- has to stay in relation to factor or everything will get skewed
    local ringLength = ringLength or 1 -- the z to -z "length" of the ring (the width?)

    local blocks = { }
    blocks.root = parent

    blocks.center = part:block(blocks.root, "-z", BlockType.Hull, vec3(factor, factor, ringLength), color)
    blocks.topArmBottom = part:block(blocks.center, "y", BlockType.Hull, vec3(factor, 0.1, ringLength - (ringLength/2)), color)
    blocks.topArm = part:block(blocks.topArmBottom, "y", BlockType.Hull, vec3(factor, (2.5 * factor + ringWidth) - 0.2, ringLength - (ringLength/2)), color)
    blocks.topArmTop = part:block(blocks.topArm, "y", BlockType.Hull, vec3(factor, 0.1, ringLength - (ringLength/2)), color)

    blocks.top = part:block(blocks.topArmTop, "y", BlockType.Hull, vec3(2 * factor, ringWidth, ringLength), color)

    blocks.topLeftRingPart2 = part:block(blocks.top, "x", BlockType.EdgeHull, vec3(2 * factor, ringWidth, ringLength), color, rgup)
    blocks.topLeftRingPart3 = part:block(blocks.topLeftRingPart2, "-y", BlockType.EdgeHull, vec3(2 * factor, ringWidth, ringLength), color, lfdn)
    blocks.topLeftRingPart4 = part:block(blocks.topLeftRingPart3, "x", BlockType.EdgeHull, vec3(ringWidth, ringWidth, ringLength), color, rgup)
    blocks.topLeftRingPart5 = part:block(blocks.topLeftRingPart4, "-y", BlockType.EdgeHull, vec3(ringWidth, 2 * factor, ringLength), color, lfdn)
    blocks.topLeftRingPart6 = part:block(blocks.topLeftRingPart5, "x", BlockType.EdgeHull, vec3(ringWidth, 2 * factor, ringLength), color, rgup)
    blocks.left = part:block(blocks.topLeftRingPart6, "-y", BlockType.Hull, vec3(ringWidth, 2 * factor, ringLength), color)

    return blocks, blocks.root
end

function stationDiscRounded(part, parent, dir, edge, factor, ringLength, flags)

    flags = flags or {}

    local dir = dir or "-z"
    local edge = edge or "fw"
    if edge == "bw" or edge == "dn" then edge = "bw" else edge = "fw" end
    local color = flags.color

    local factor = factor or 1 -- the overall size, since the basic ring is not very big
    local ringWidth = factor * 1 or 1 -- has to stay in relation to factor or everything will get skewed
    local ringLength = ringLength or 1 -- the z to -z "length" of the ring (the width?)

    local blocks = { }
    blocks.root = parent

    blocks.center = part:block(blocks.root, "-z", BlockType.Hull, vec3(2 * factor, 2 * factor, ringLength), color)
    blocks.topArm = part:block(blocks.center, "y", BlockType.Hull, vec3(2 * factor, (2 * factor + ringWidth), ringLength), color)
    blocks.bottomArm = part:block(blocks.center, "-y", BlockType.Hull, vec3(2 * factor, (2 * factor + ringWidth), ringLength), color)
    blocks.leftArm = part:block(blocks.center, "x", BlockType.Hull, vec3((2 * factor + ringWidth), 2 * factor, ringLength), color)
    blocks.rightArm = part:block(blocks.center, "-x", BlockType.Hull, vec3((2 * factor + ringWidth), 2 * factor, ringLength), color)

    if edge == "fw" then
        blocks.top = part:block(blocks.topArm, "y", BlockType.EdgeHull, vec3(2 * factor, ringWidth, ringLength), color, fwup)
        blocks.topLeftRingPart2 = part:block(blocks.top, "x", BlockType.CornerHull, vec3(2 * factor, ringWidth, ringLength), color, fwlf)
        blocks.topLeftRingPart3 = part:block(blocks.topLeftRingPart2, "-y", BlockType.InnerCornerHull, vec3(2 * factor, ringWidth, ringLength), color, rgup)
        blocks.topLeftRingPart4 = part:block(blocks.topLeftRingPart3, "x", BlockType.CornerHull, vec3(ringWidth, ringWidth, ringLength), color, fwlf)
        blocks.topLeftRingPart5 = part:block(blocks.topLeftRingPart4, "-y", BlockType.InnerCornerHull, vec3(ringWidth, 2 * factor, ringLength), color, rgup)
        blocks.topLeftRingPart6 = part:block(blocks.topLeftRingPart5, "x", BlockType.CornerHull, vec3(ringWidth, 2 * factor, ringLength), color, fwlf)
        blocks.left = part:block(blocks.topLeftRingPart6, "-y", BlockType.EdgeHull, vec3(ringWidth, 2 * factor, ringLength), color, fwlf)
        blocks.topLeftInnerPart1 = part:block(blocks.topLeftRingPart3, "-y", BlockType.Hull, vec3(2 * factor, 2 * factor, ringLength), color)
        -- bottom left quarter
        blocks.bottomLeftRingPart2 = part:block(blocks.left, "-y", BlockType.CornerHull, vec3(ringWidth, 2 * factor, ringLength), color, fwdn)
        blocks.bottomLeftRingPart3 = part:block(blocks.bottomLeftRingPart2, "-x", BlockType.InnerCornerHull, vec3(ringWidth, 2 * factor, ringLength), color, fwdn)
        blocks.bottomLeftRingPart4 = part:block(blocks.bottomLeftRingPart3, "-y", BlockType.CornerHull, vec3(ringWidth, ringWidth, ringLength), color, fwdn)
        blocks.bottomLeftRingPart5 = part:block(blocks.bottomLeftRingPart4, "-x", BlockType.InnerCornerHull, vec3(2 * factor, ringWidth, ringLength), color, fwdn)
        blocks.bottomLeftRingPart6 = part:block(blocks.bottomLeftRingPart5, "-y", BlockType.CornerHull, vec3(2 * factor, ringWidth, ringLength), color, fwdn)
        blocks.bottom = part:block(blocks.bottomLeftRingPart6, "-x", BlockType.EdgeHull, vec3(2 * factor, ringWidth, ringLength), color, fwdn)
        blocks.bottomLeftInnerPart1 = part:block(blocks.bottomLeftRingPart5, "y", BlockType.Hull, vec3(2 * factor, 2 * factor, ringLength), color)

        -- bottom right quarter
        blocks.bottomRightRingPart2 = part:block(blocks.bottom, "-x", BlockType.CornerHull, vec3(2 * factor, ringWidth, ringLength), color, lfdn)
        blocks.bottomRightRingPart3 = part:block(blocks.bottomRightRingPart2, "y", BlockType.InnerCornerHull, vec3(2 * factor, ringWidth, ringLength), color, lfdn)
        blocks.bottomRightRingPart4 = part:block(blocks.bottomRightRingPart3, "-x", BlockType.CornerHull, vec3(ringWidth, ringWidth, ringLength), color, lfdn)
        blocks.bottomRightRingPart5 = part:block(blocks.bottomRightRingPart4, "y", BlockType.InnerCornerHull, vec3(ringWidth, 2 * factor, ringLength), color, lfdn)
        blocks.bottomRightRingPart6 = part:block(blocks.bottomRightRingPart5, "-x", BlockType.CornerHull, vec3(ringWidth, 2 * factor, ringLength), color, lfdn)
        blocks.right = part:block(blocks.bottomRightRingPart6, "y", BlockType.EdgeHull, vec3(ringWidth, 2 * factor, ringLength), color, fwrg)
        blocks.bottomRightInnerPart1 = part:block(blocks.bottomRightRingPart3, "y", BlockType.Hull, vec3(2 * factor, 2 * factor, ringLength), color)

        -- top right quarter
        blocks.topRightRingPart2 = part:block(blocks.top, "-x", BlockType.CornerHull, vec3(2 * factor, ringWidth, ringLength), color, fwup)
        blocks.topRightRingPart3 = part:block(blocks.topRightRingPart2, "-y", BlockType.InnerCornerHull, vec3(2 * factor, ringWidth, ringLength), color, fwup)
        blocks.topRightRingPart4 = part:block(blocks.topRightRingPart3, "-x", BlockType.CornerHull, vec3(ringWidth, ringWidth, ringLength), color, fwup)
        blocks.topRightRingPart5 = part:block(blocks.topRightRingPart4, "-y", BlockType.InnerCornerHull, vec3(ringWidth, 2 * factor, ringLength), color, fwup)
        blocks.topRightRingPart6 = part:block(blocks.topRightRingPart5, "-x", BlockType.CornerHull, vec3(ringWidth, 2 * factor, ringLength), color, fwup)

        blocks.topRightInnerPart1 = part:block(blocks.topRightRingPart3, "-y", BlockType.Hull, vec3(2 * factor, 2 * factor, ringLength), color)
    elseif edge == "bw" then
        blocks.top = part:block(blocks.topArm, "y", BlockType.EdgeHull, vec3(2 * factor, ringWidth, ringLength), color, bwup)
        blocks.topLeftRingPart2 = part:block(blocks.top, "x", BlockType.CornerHull, vec3(2 * factor, ringWidth, ringLength), color, bwup)
        blocks.topLeftRingPart3 = part:block(blocks.topLeftRingPart2, "-y", BlockType.InnerCornerHull, vec3(2 * factor, ringWidth, ringLength), color, bwup)
        blocks.topLeftRingPart4 = part:block(blocks.topLeftRingPart3, "x", BlockType.CornerHull, vec3(ringWidth, ringWidth, ringLength), color, bwup)
        blocks.topLeftRingPart5 = part:block(blocks.topLeftRingPart4, "-y", BlockType.InnerCornerHull, vec3(ringWidth, 2 * factor, ringLength), color, bwup)
        blocks.topLeftRingPart6 = part:block(blocks.topLeftRingPart5, "x", BlockType.CornerHull, vec3(ringWidth, 2 * factor, ringLength), color, bwup)
        blocks.left = part:block(blocks.topLeftRingPart6, "-y", BlockType.EdgeHull, vec3(ringWidth, 2 * factor, ringLength), color, bwlf)
        blocks.topLeftInnerPart1 = part:block(blocks.topLeftRingPart3, "-y", BlockType.Hull, vec3(2 * factor, 2 * factor, ringLength), color)

        -- bottom left quarter
        blocks.bottomLeftRingPart2 = part:block(blocks.left, "-y", BlockType.CornerHull, vec3(ringWidth, 2 * factor, ringLength), color, rgdn)
        blocks.bottomLeftRingPart3 = part:block(blocks.bottomLeftRingPart2, "-x", BlockType.InnerCornerHull, vec3(ringWidth, 2 * factor, ringLength), color, rgdn)
        blocks.bottomLeftRingPart4 = part:block(blocks.bottomLeftRingPart3, "-y", BlockType.CornerHull, vec3(ringWidth, ringWidth, ringLength), color, rgdn)
        blocks.bottomLeftRingPart5 = part:block(blocks.bottomLeftRingPart4, "-x", BlockType.InnerCornerHull, vec3(2 * factor, ringWidth, ringLength), color, rgdn)
        blocks.bottomLeftRingPart6 = part:block(blocks.bottomLeftRingPart5, "-y", BlockType.CornerHull, vec3(2 * factor, ringWidth, ringLength), color, rgdn)
        blocks.bottom = part:block(blocks.bottomLeftRingPart6, "-x", BlockType.EdgeHull, vec3(2 * factor, ringWidth, ringLength), color, bwdn)
        blocks.bottomLeftInnerPart1 = part:block(blocks.bottomLeftRingPart5, "y", BlockType.Hull, vec3(2 * factor, 2 * factor, ringLength), color)

        -- bottom right quarter
        blocks.bottomRightRingPart2 = part:block(blocks.bottom, "-x", BlockType.CornerHull, vec3(2 * factor, ringWidth, ringLength), color, bwdn)
        blocks.bottomRightRingPart3 = part:block(blocks.bottomRightRingPart2, "y", BlockType.InnerCornerHull, vec3(2 * factor, ringWidth, ringLength), color, bwdn)
        blocks.bottomRightRingPart4 = part:block(blocks.bottomRightRingPart3, "-x", BlockType.CornerHull, vec3(ringWidth, ringWidth, ringLength), color, bwdn)
        blocks.bottomRightRingPart5 = part:block(blocks.bottomRightRingPart4, "y", BlockType.InnerCornerHull, vec3(ringWidth, 2 * factor, ringLength), color, bwdn)
        blocks.bottomRightRingPart6 = part:block(blocks.bottomRightRingPart5, "-x", BlockType.CornerHull, vec3(ringWidth, 2 * factor, ringLength), color, bwdn)
        blocks.right = part:block(blocks.bottomRightRingPart6, "y", BlockType.EdgeHull, vec3(ringWidth, 2 * factor, ringLength), color, bwrg)
        blocks.bottomRightInnerPart1 = part:block(blocks.bottomRightRingPart3, "y", BlockType.Hull, vec3(2 * factor, 2 * factor, ringLength), color)

        -- top right quarter
        blocks.topRightRingPart2 = part:block(blocks.top, "-x", BlockType.CornerHull, vec3(2 * factor, ringWidth, ringLength), color, lfup)
        blocks.topRightRingPart3 = part:block(blocks.topRightRingPart2, "-y", BlockType.InnerCornerHull, vec3(2 * factor, ringWidth, ringLength), color, lfup)
        blocks.topRightRingPart4 = part:block(blocks.topRightRingPart3, "-x", BlockType.CornerHull, vec3(ringWidth, ringWidth, ringLength), color, lfup)
        blocks.topRightRingPart5 = part:block(blocks.topRightRingPart4, "-y", BlockType.InnerCornerHull, vec3(ringWidth, 2 * factor, ringLength), color, lfup)
        blocks.topRightRingPart6 = part:block(blocks.topRightRingPart5, "-x", BlockType.CornerHull, vec3(ringWidth, 2 * factor, ringLength), color, lfup)

        blocks.topRightInnerPart1 = part:block(blocks.topRightRingPart3, "-y", BlockType.Hull, vec3(2 * factor, 2 * factor, ringLength), color)
    end

    return blocks, blocks.root
end

function stationDisc(part, parent, dir, factor, ringLength, flags)

    flags = flags or {}

    local dir = dir or "-z"
    local edge = flags.edge or BlockType.EdgeHull
    local color = flags.color

    local factor = factor or 1 -- the overall size, since the basic ring is not very big
    local ringWidth = factor * 1 or 1 -- has to stay in relation to factor or everything will get skewed
    local ringLength = ringLength or 1 -- the z to -z "length" of the ring (the width?)

    local blocks = { }
    blocks.root = parent

    blocks.center = part:block(blocks.root, "-z", BlockType.Hull, vec3(2 * factor, 2 * factor, ringLength), color)
    blocks.topArm = part:block(blocks.center, "y", BlockType.Hull, vec3(2 * factor, (2 * factor + ringWidth), ringLength), color)
    blocks.bottomArm = part:block(blocks.center, "-y", BlockType.Hull, vec3(2 * factor, (2 * factor + ringWidth), ringLength), color)
    blocks.leftArm = part:block(blocks.center, "x", BlockType.Hull, vec3((2 * factor + ringWidth), 2 * factor, ringLength), color)
    blocks.rightArm = part:block(blocks.center, "-x", BlockType.Hull, vec3((2 * factor + ringWidth), 2 * factor, ringLength), color)

    blocks.top = part:block(blocks.topArm, "y", BlockType.Hull, vec3(2 * factor, ringWidth, ringLength), color)

    blocks.topLeftRingPart2 = part:block(blocks.top, "x", BlockType.EdgeHull, vec3(2 * factor, ringWidth, ringLength), color, rgup)
    blocks.topLeftRingPart3 = part:block(blocks.topLeftRingPart2, "-y", BlockType.Hull, vec3(2 * factor, ringWidth, ringLength), color, lfdn)
    blocks.topLeftRingPart4 = part:block(blocks.topLeftRingPart3, "x", BlockType.EdgeHull, vec3(ringWidth, ringWidth, ringLength), color, rgup)
    blocks.topLeftRingPart5 = part:block(blocks.topLeftRingPart4, "-y", BlockType.Hull, vec3(ringWidth, 2 * factor, ringLength), color, lfdn)
    blocks.topLeftRingPart6 = part:block(blocks.topLeftRingPart5, "x", BlockType.EdgeHull, vec3(ringWidth, 2 * factor, ringLength), color, rgup)
    blocks.left = part:block(blocks.topLeftRingPart6, "-y", BlockType.Hull, vec3(ringWidth, 2 * factor, ringLength), color)

    blocks.topLeftInnerPart1 = part:block(blocks.topLeftRingPart3, "-y", BlockType.Hull, vec3(2 * factor, 2 * factor, ringLength), color)

    -- bottom left quarter
    blocks.bottomLeftRingPart2 = part:block(blocks.left, "-y", BlockType.EdgeHull, vec3(ringWidth, 2 * factor, ringLength), color, rgdn)
    blocks.bottomLeftRingPart3 = part:block(blocks.bottomLeftRingPart2, "-x", BlockType.Hull, vec3(ringWidth, 2 * factor, ringLength), color, lfup)
    blocks.bottomLeftRingPart4 = part:block(blocks.bottomLeftRingPart3, "-y", BlockType.EdgeHull, vec3(ringWidth, ringWidth, ringLength), color, rgdn)
    blocks.bottomLeftRingPart5 = part:block(blocks.bottomLeftRingPart4, "-x", BlockType.Hull, vec3(2 * factor, ringWidth, ringLength), color, lfup)
    blocks.bottomLeftRingPart6 = part:block(blocks.bottomLeftRingPart5, "-y", BlockType.EdgeHull, vec3(2 * factor, ringWidth, ringLength), color, rgdn)
    blocks.bottom = part:block(blocks.bottomLeftRingPart6, "-x", BlockType.Hull, vec3(2 * factor, ringWidth, ringLength), color)

    blocks.bottomLeftInnerPart1 = part:block(blocks.bottomLeftRingPart5, "y", BlockType.Hull, vec3(2 * factor, 2 * factor, ringLength), color)

    -- bottom right quarter
    blocks.bottomRightRingPart2 = part:block(blocks.bottom, "-x", BlockType.EdgeHull, vec3(2 * factor, ringWidth, ringLength), color, lfdn)
    blocks.bottomRightRingPart3 = part:block(blocks.bottomRightRingPart2, "y", BlockType.Hull, vec3(2 * factor, ringWidth, ringLength), color, rgup)
    blocks.bottomRightRingPart4 = part:block(blocks.bottomRightRingPart3, "-x", BlockType.EdgeHull, vec3(ringWidth, ringWidth, ringLength), color, lfdn)
    blocks.bottomRightRingPart5 = part:block(blocks.bottomRightRingPart4, "y", BlockType.Hull, vec3(ringWidth, 2 * factor, ringLength), color, rgup)
    blocks.bottomRightRingPart6 = part:block(blocks.bottomRightRingPart5, "-x", BlockType.EdgeHull, vec3(ringWidth, 2 * factor, ringLength), color, lfdn)
    blocks.right = part:block(blocks.bottomRightRingPart6, "y", BlockType.Hull, vec3(ringWidth, 2 * factor, ringLength), color)

    blocks.bottomRightInnerPart1 = part:block(blocks.bottomRightRingPart3, "y", BlockType.Hull, vec3(2 * factor, 2 * factor, ringLength), color)

    -- top right quarter
    blocks.topRightRingPart2 = part:block(blocks.top, "-x", BlockType.EdgeHull, vec3(2 * factor, ringWidth, ringLength), color, lfup)
    blocks.topRightRingPart3 = part:block(blocks.topRightRingPart2, "-y", BlockType.Hull, vec3(2 * factor, ringWidth, ringLength), color, rgdn)
    blocks.topRightRingPart4 = part:block(blocks.topRightRingPart3, "-x", BlockType.EdgeHull, vec3(ringWidth, ringWidth, ringLength), color, lfup)
    blocks.topRightRingPart5 = part:block(blocks.topRightRingPart4, "-y", BlockType.Hull, vec3(ringWidth, 2 * factor, ringLength), color, rgdn)
    blocks.topRightRingPart6 = part:block(blocks.topRightRingPart5, "-x", BlockType.EdgeHull, vec3(ringWidth, 2 * factor, ringLength), color, lfup)

    blocks.topRightInnerPart1 = part:block(blocks.topRightRingPart3, "-y", BlockType.Hull, vec3(2 * factor, 2 * factor, ringLength), color)

    return blocks, blocks.root
end


function rounded(part, parent, dir, lower, upper, flags)

    flags = flags or {}

    local block = part:getBlock(parent)

    local corner = flags.corner or BlockType.CornerHull

    local edge = flags.edge or BlockType.EdgeHull
    local color = flags.color or block.color

    local blocks = { }
    blocks.root = parent


    local s = block.box.size
    local l = lower or 0.5
    local u = upper or l

    if type(s) == "number" then s = vec3(s) end
    if type(l) == "number" then l = vec3(l) end
    if type(u) == "number" then u = vec3(u) end

    if isPX(dir) then
        blocks.top = part:block(blocks.root, "y", edge, vec3(s.x, u.y, s.z), color, rgup)
        blocks.bottom = part:block(blocks.root, "-y", edge, vec3(s.x, l.y, s.z), color, rgdn)
        blocks.front = part:block(blocks.root, "z", edge, vec3(s.x, s.y, u.z), color, rgfw)
        blocks.back = part:block(blocks.root, "-z", edge, vec3(s.x, s.y, l.z), color, rgbw)

        blocks.topFront = part:block(blocks.front, "y", corner, vec3(s.x, u.y, u.z), color, bwup)
        blocks.topBack = part:block(blocks.back, "y", corner, vec3(s.x, u.y, l.z), color, rgup)

        blocks.bottomFront = part:block(blocks.front, "-y", corner, vec3(s.x, l.y, u.z), color, rgdn)
        blocks.bottomBack = part:block(blocks.back, "-y", corner, vec3(s.x, l.y, l.z), color, fwdn)

    elseif isNX(dir) then
        blocks.top = part:block(blocks.root, "y", edge, vec3(s.x, u.y, s.z), color, lfup)
        blocks.bottom = part:block(blocks.root, "-y", edge, vec3(s.x, l.y, s.z), color, lfdn)
        blocks.front = part:block(blocks.root, "z", edge, vec3(s.x, s.y, u.z), color, lffw)
        blocks.back = part:block(blocks.root, "-z", edge, vec3(s.x, s.y, l.z), color, lfbw)

        blocks.topFront = part:block(blocks.front, "y", corner, vec3(s.x, u.y, u.z), color, lfup)
        blocks.topBack = part:block(blocks.back, "y", corner, vec3(s.x, u.y, l.z), color, fwup)

        blocks.bottomFront = part:block(blocks.front, "-y", corner, vec3(s.x, l.y, u.z), color, bwdn)
        blocks.bottomBack = part:block(blocks.back, "-y", corner, vec3(s.x, l.y, l.z), color, lfdn)

    elseif isPY(dir) then
        blocks.right = part:block(blocks.root, "-x", edge, vec3(l.x, s.y, s.z), color, lfup)
        blocks.left = part:block(blocks.root, "x", edge, vec3(u.x, s.y, s.z), color, rgup)
        blocks.front = part:block(blocks.root, "z", edge, vec3(s.x, s.y, u.z), color, bwup)
        blocks.back = part:block(blocks.root, "-z", edge, vec3(s.x, s.y, l.z), color, fwup)

        blocks.backLeft = part:block(blocks.left, "-z", corner, vec3(u.x, s.y, l.z), color, rgup)
        blocks.frontLeft = part:block(blocks.left, "z", corner, vec3(u.x, s.y, u.z), color, bwup)

        blocks.backRight = part:block(blocks.right, "-z", corner, vec3(l.x, s.y, l.z), color, fwup)
        blocks.frontRight = part:block(blocks.right, "z", corner, vec3(l.x, s.y, u.z), color, lfup)

    elseif isNY(dir) then
        blocks.right = part:block(blocks.root, "-x", edge, vec3(l.x, s.y, s.z), color, lfdn)
        blocks.left = part:block(blocks.root, "x", edge, vec3(u.x, s.y, s.z), color, rgdn)
        blocks.front = part:block(blocks.root, "z", edge, vec3(s.x, s.y, u.z), color, bwdn)
        blocks.back = part:block(blocks.root, "-z", edge, vec3(s.x, s.y, l.z), color, fwdn)

        blocks.backLeft = part:block(blocks.left, "-z", corner, vec3(u.x, s.y, l.z), color, fwdn)
        blocks.frontLeft = part:block(blocks.left, "z", corner, vec3(u.x, s.y, u.z), color, rgdn)

        blocks.backRight = part:block(blocks.right, "-z", corner, vec3(l.x, s.y, l.z), color, lfdn)
        blocks.frontRight = part:block(blocks.right, "z", corner, vec3(l.x, s.y, u.z), color, bwdn)
    elseif isPZ(dir) then

        blocks.top = part:block(blocks.root, "y", edge, vec3(s.x, u.y, s.z), color, bwup)
        blocks.bottom = part:block(blocks.root, "-y", edge, vec3(s.x, l.y, s.z), color, bwdn)
        blocks.right = part:block(blocks.root, "-x", edge, vec3(l.x, s.y, s.z), color, bwrg)
        blocks.left = part:block(blocks.root, "x", edge, vec3(u.x, s.y, s.z), color, bwlf)

        blocks.topLeft = part:block(blocks.left, "y", corner, vec3(u.x, u.y, s.z), color, bwup)
        blocks.topRight = part:block(blocks.right, "y", corner, vec3(l.x, u.y, s.z), color, lfup)

        blocks.bottomLeft = part:block(blocks.left, "-y", corner, vec3(u.x, l.y, s.z), color, rgdn)
        blocks.bottomRight = part:block(blocks.right, "-y", corner, vec3(l.x, l.y, s.z), color, bwdn)

    elseif isNZ(dir) then

        blocks.top = part:block(blocks.root, "y", edge, vec3(s.x, u.y, s.z), color, fwup)
        blocks.bottom = part:block(blocks.root, "-y", edge, vec3(s.x, l.y, s.z), color, fwdn)
        blocks.right = part:block(blocks.root, "-x", edge, vec3(l.x, s.y, s.z), color, fwrg)
        blocks.left = part:block(blocks.root, "x", edge, vec3(u.x, s.y, s.z), color, fwlf)

        blocks.topLeft = part:block(blocks.left, "y", corner, vec3(u.x, u.y, s.z), color, rgup)
        blocks.topRight = part:block(blocks.right, "y", corner, vec3(l.x, u.y, s.z), color, fwup)

        blocks.bottomLeft = part:block(blocks.left, "-y", corner, vec3(u.x, l.y, s.z), color, fwdn)
        blocks.bottomRight = part:block(blocks.right, "-y", corner, vec3(l.x, l.y, s.z), color, lfdn)

    end

    -- convenience
    local b = blocks
    blocks.frontBlocks = {b.front, b.topFront, b.bottomFront, b.frontRight, b.frontLeft}
    blocks.backBlocks = {b.back, b.topBack, b.bottomBack, b.backRight, b.backLeft}
    blocks.topBlocks = {b.top, b.topLeft, b.topRight, b.topFront, b.topBack}
    blocks.bottomBlocks = {b.bottom, b.bottomLeft, b.bottomRight, b.bottomFront, b.bottomBack}
    blocks.leftBlocks = {b.left, b.topLeft, b.bottomLeft, b.frontLeft, b.backLeft}
    blocks.rightBlocks = {b.right, b.topRight, b.bottomRight, b.frontRight, b.backRight}

    blocks.blocks = {b.top, b.bottom, b.left, b.right, b.front, b.back}
    blocks.edges = {b.topLeft, b.topRight, b.bottomLeft, b.bottomRight, b.topFront, b.topBack, b.bottomFront, b.bottomBack, b.frontRight, b.backRight, b.frontLeft, b.backLeft}

    blocks.topEdges = {b.topLeft, b.topRight, b.topFront, b.topBack}
    blocks.bottomEdges = {b.bottomLeft, b.bottomRight, b.bottomFront, b.bottomBack}
    blocks.leftEdges = {b.bottomLeft, b.topLeft, b.frontLeft, b.backLeft}
    blocks.rightEdges = {b.bottomRight, b.topRight, b.frontRight, b.backRight}
    blocks.frontEdges = {b.frontRight, b.frontLeft, b.topFront, b.bottomFront}
    blocks.backEdges = {b.backRight, b.backLeft, b.topBack, b.bottomBack}

    return blocks, blocks.root
end

function roundedSquareBase(part, parent, dir, lower, upper, flags)

    flags = flags or {}

    local block = part:getBlock(parent)

    local corner = flags.corner or BlockType.OuterCornerHull

    local edge = flags.edge or BlockType.EdgeHull
    local color = flags.color or block.color

    local blocks = { }
    blocks.root = parent


    local s = block.box.size
    local l = lower or 0.5
    local u = upper or l

    if type(s) == "number" then s = vec3(s) end
    if type(l) == "number" then l = vec3(l) end
    if type(u) == "number" then u = vec3(u) end

    if isPX(dir) then
        blocks.top = part:block(blocks.root, "y", edge, vec3(s.x, u.y, s.z), color, rgup)
        blocks.bottom = part:block(blocks.root, "-y", edge, vec3(s.x, l.y, s.z), color, rgdn)
        blocks.front = part:block(blocks.root, "z", edge, vec3(s.x, s.y, u.z), color, rgfw)
        blocks.back = part:block(blocks.root, "-z", edge, vec3(s.x, s.y, l.z), color, rgbw)

        blocks.topFront = part:block(blocks.front, "y", corner, vec3(s.x, u.y, u.z), color, dnlf)
        blocks.topBack = part:block(blocks.back, "y", corner, vec3(s.x, u.y, l.z), color, fwlf)
        blocks.bottomFront = part:block(blocks.front, "-y", corner, vec3(s.x, l.y, u.z), color, bwlf)
        blocks.bottomBack = part:block(blocks.back, "-y", corner, vec3(s.x, l.y, l.z), color, uplf)

    elseif isNX(dir) then
        blocks.top = part:block(blocks.root, "y", edge, vec3(s.x, u.y, s.z), color, lfup)
        blocks.bottom = part:block(blocks.root, "-y", edge, vec3(s.x, l.y, s.z), color, lfdn)
        blocks.front = part:block(blocks.root, "z", edge, vec3(s.x, s.y, u.z), color, lffw)
        blocks.back = part:block(blocks.root, "-z", edge, vec3(s.x, s.y, l.z), color, lfbw)

        blocks.topFront = part:block(blocks.front, "y", corner, vec3(s.x, u.y, u.z), color, bwrg)
        blocks.topBack = part:block(blocks.back, "y", corner, vec3(s.x, u.y, l.z), color, dnrg)
        blocks.bottomFront = part:block(blocks.front, "-y", corner, vec3(s.x, l.y, u.z), color, uprg)
        blocks.bottomBack = part:block(blocks.back, "-y", corner, vec3(s.x, l.y, l.z), color, fwrg)

    elseif isPY(dir) then
        blocks.right = part:block(blocks.root, "-x", edge, vec3(l.x, s.y, s.z), color, lfup)
        blocks.left = part:block(blocks.root, "x", edge, vec3(u.x, s.y, s.z), color, rgup)
        blocks.front = part:block(blocks.root, "z", edge, vec3(s.x, s.y, u.z), color, bwup)
        blocks.back = part:block(blocks.root, "-z", edge, vec3(s.x, s.y, l.z), color, fwup)

        blocks.backLeft = part:block(blocks.left, "-z", corner, vec3(u.x, s.y, l.z), color, rgup)
        blocks.frontLeft = part:block(blocks.left, "z", corner, vec3(u.x, s.y, u.z), color, bwup)
        blocks.backRight = part:block(blocks.right, "-z", corner, vec3(l.x, s.y, l.z), color, fwup)
        blocks.frontRight = part:block(blocks.right, "z", corner, vec3(l.x, s.y, u.z), color, lfup)

    elseif isNY(dir) then
        blocks.right = part:block(blocks.root, "-x", edge, vec3(l.x, s.y, s.z), color, lfdn)
        blocks.left = part:block(blocks.root, "x", edge, vec3(u.x, s.y, s.z), color, rgdn)
        blocks.front = part:block(blocks.root, "z", edge, vec3(s.x, s.y, u.z), color, bwdn)
        blocks.back = part:block(blocks.root, "-z", edge, vec3(s.x, s.y, l.z), color, fwdn)

        blocks.backLeft = part:block(blocks.left, "-z", corner, vec3(u.x, s.y, l.z), color, fwdn)
        blocks.frontLeft = part:block(blocks.left, "z", corner, vec3(u.x, s.y, u.z), color, rgdn)
        blocks.backRight = part:block(blocks.right, "-z", corner, vec3(l.x, s.y, l.z), color, lfdn)
        blocks.frontRight = part:block(blocks.right, "z", corner, vec3(l.x, s.y, u.z), color,bwdn)
    elseif isPZ(dir) then

        blocks.top = part:block(blocks.root, "y", edge, vec3(s.x, u.y, s.z), color, bwup)
        blocks.bottom = part:block(blocks.root, "-y", edge, vec3(s.x, l.y, s.z), color, bwdn)
        blocks.right = part:block(blocks.root, "-x", edge, vec3(l.x, s.y, s.z), color, bwrg)
        blocks.left = part:block(blocks.root, "x", edge, vec3(u.x, s.y, s.z), color, bwlf)

        blocks.topLeft = part:block(blocks.left, "y", corner, vec3(u.x, u.y, s.z), color, rgfw)
        blocks.topRight = part:block(blocks.right, "y", corner, vec3(l.x, u.y, s.z), color, dnfw)
        blocks.bottomLeft = part:block(blocks.left, "-y", corner, vec3(u.x, l.y, s.z), color, upfw)
        blocks.bottomRight = part:block(blocks.right, "-y", corner, vec3(l.x, l.y, s.z), color, lffw)

    elseif isNZ(dir) then

        blocks.top = part:block(blocks.root, "y", edge, vec3(s.x, u.y, s.z), color, fwup)
        blocks.bottom = part:block(blocks.root, "-y", edge, vec3(s.x, l.y, s.z), color, fwdn)
        blocks.right = part:block(blocks.root, "-x", edge, vec3(l.x, s.y, s.z), color, fwrg)
        blocks.left = part:block(blocks.root, "x", edge, vec3(u.x, s.y, s.z), color, fwlf)

        blocks.topLeft = part:block(blocks.left, "y", corner, vec3(u.x, u.y, s.z), color, dnbw)
        blocks.topRight = part:block(blocks.right, "y", corner, vec3(l.x, u.y, s.z), color, lfbw)
        blocks.bottomLeft = part:block(blocks.left, "-y", corner, vec3(u.x, l.y, s.z), color, rgbw)
        blocks.bottomRight = part:block(blocks.right, "-y", corner, vec3(l.x, l.y, s.z), color, upbw)

    end

    -- convenience
    local b = blocks

    blocks.edges = {b.top, b.bottom, b.front, b.back, b.right, b.left}
    blocks.corners = {b.topFront, b.topBack, b.bottomFront, b.bottomBack, b.backLeft, b.frontLeft, b.backRight, b.frontRight,
    b.topRight, b.topLeft, b.bottomLeft, b.bottomRight}


    return blocks, blocks.root
end

function sphere2(part, root)
    local sides = {}

    sides.px = cap2(part, root, "x", nil)
    sides.nx = cap2(part, root, "-x", nil)
    sides.py = cap2(part, root, "y", nil)
    sides.ny = cap2(part, root, "-y", nil)
    sides.pz = cap2(part, root, "z", nil)
    sides.nz = cap2(part, root, "-z", nil)

    return sides
end

function cap(part, parent, dir, height, flags)
    height = height or 0.5
    flags = flags or {}

    local b = part:getBlock(block)
    local s = b.box.size

    local bs = s * 0.5
    bs[getAxis(dir)] = height

    local new = part:block(parent, dir, b.blockIndex, bs)
    return rounded(part, new, dir, s * 0.25, s * 0.25, flags)
end

function cap2(part, parent, dir, height, flags)
    flags = flags or {}

    local d = "y"
    local axis, turns
    if isPX(dir) then
        axis, turns = "z", 1
    elseif isNX(dir) then
        axis, turns = "z", -1
    elseif isPZ(dir) then
        axis, turns = "x", -1
    elseif isNZ(dir) then
        axis, turns = "x", 1
    elseif isNY(dir) then
        d = "-y"
    end

    if axis and turns then
        part:rotate(axis, turns)
    end

    flags.corner = BlockType.OuterCornerHull
    local returned = cap(part, parent, d, height, flags)

    if axis and turns then
        part:rotate(axis, -turns)
    end

    return returned
end

function split(part, block, dir, ratio)
    dir = dir or "y"
    ratio = ratio or 0.5

    local b = part:getBlock(block)
    local s = b.box.size
    local l = b.box.lower
    local u = b.box.upper
    local c = l + (u - l) * ratio

    if isY(dir) then
        part:transform(block, {lower = l, upper = vec3(u.x, c.y, u.z)})
        local newBlock = part:block(block, "+y", b.blockIndex, vec3(s.x, s.y * (1 - ratio), s.z), b.color, b.orientation)
        return {bottom = block, top = newBlock}
    elseif isX(dir) then
        part:transform(block, {lower = l, upper = vec3(c.x, u.y, u.z)})
        local newBlock = part:block(block, "+x", b.blockIndex, vec3(s.x * (1 - ratio), s.y, s.z), b.color, b.orientation)
        return {right = block, left = newBlock}
    elseif isZ(dir) then
        part:transform(block, {lower = l, upper = vec3(u.x, u.y, c.z)})
        local newBlock = part:block(block, "+z", b.blockIndex, vec3(s.x, s.y, s.z * (1 - ratio)), b.color, b.orientation)
        return {back = block, front = newBlock}
    end

end

function lightSplit(part, block, dir, ratio, flags)
    dir = dir or "y"
    ratio = ratio or 0.5
    flags = flags or {}
    local height = flags.lightWidth or 0.1

    local b = part:getBlock(block)
    local s = b.box.size
    local glowType = b.box.type
    if glowType == BoxType.Edge then
        glowType = BlockType.GlowEdge
    else
        glowType = BlockType.Glow
    end

    local glowColor = flags.color or initialSettings.colors.light

    if ratio >= 1.0 then
        local l = b.box.lower
        local u = b.box.upper
        local o

        if isY(dir) then
            part:transform(block, {upper = vec3(u.x, u.y - height, u.z)})
            o = part:block(block, "y", glowType, vec3(s.x, height, s.z), glowColor, b.orientation)
        elseif isX(dir) then
            part:transform(block, {upper = vec3(u.x - height, u.y, u.z)})
            o = part:block(block, "x", glowType, vec3(height, s.y, s.z), glowColor, b.orientation)
        elseif isZ(dir) then
            part:transform(block, {upper = vec3(u.x, u.y, u.z - height)})
            o = part:block(block, "z", glowType, vec3(s.x, s.y, height), glowColor, b.orientation)
        end

        return {lower = block, upper = o, root = block, block = block}
    elseif ratio <= 0.0 then
        local l = b.box.lower
        local u = b.box.upper
        local o

        if isY(dir) then
            part:transform(block, {lower = vec3(l.x, l.y + height, l.z)})
            o = part:block(block, "-y", glowType, vec3(s.x, height, s.z), glowColor, b.orientation)
        elseif isX(dir) then
            part:transform(block, {lower = vec3(l.x + height, l.y, l.z)})
            o = part:block(block, "-x", glowType, vec3(height, s.y, s.z), glowColor, b.orientation)
        elseif isZ(dir) then
            part:transform(block, {lower = vec3(l.x, l.y, l.z + height)})
            o = part:block(block, "-z", glowType, vec3(s.x, s.y, height), glowColor, b.orientation)
        end

        return {lower = o, upper = block, root = block, block = block}
    else
        local l, u
        if isY(dir) then
            part:transform(block, {size = vec3(s.x, height, s.z), type = glowType, color = glowColor})
            u = part:block(block, "+y", b.blockIndex, vec3(s.x, s.y * (1 - ratio) - height * 0.5, s.z), b.color, b.orientation)
            l = part:block(block, "-y", b.blockIndex, vec3(s.x, s.y * ratio - height * 0.5, s.z), b.color, b.orientation)
        elseif isX(dir) then
            part:transform(block, {size = vec3(height, s.y, s.z), type = glowType, color = glowColor})
            u = part:block(block, "+x", b.blockIndex, vec3(s.x * (1 - ratio) - height * 0.5, s.y, s.z), b.color, b.orientation)
            l = part:block(block, "-x", b.blockIndex, vec3(s.x * ratio - height * 0.5, s.y, s.z), b.color, b.orientation)

        elseif isZ(dir) then
            part:transform(block, {size = vec3(s.x, s.y, height), type = glowType, color = glowColor})
            u = part:block(block, "+z", b.blockIndex, vec3(s.x, s.y, s.z * (1 - ratio) - height * 0.5), b.color, b.orientation)
            l = part:block(block, "-z", b.blockIndex, vec3(s.x, s.y, s.z * ratio - height * 0.5), b.color, b.orientation)
        end

        return {lower = l, upper = u, root = block, block = block}
    end
end

--    flags:
--    colorSplit: 1 if colorSplit is wanted (only the middle is colored, you still have to specify the color in middleBlockColor)
--    lightSplit: 1 if lightSplit is wanted (works just like the old lightSplit, to change color of light, use middleBlockColor)
--    firstBlockType: a BlockType
--    middleBlockType: a BlockType
--    lastBlockType: a BlockType
--    firstBlockColor: a color
--    middleBlockColor: a color
--    lastBlockColor: a color
function doubleSplit(part, block, dir, ratio, centerWidth, flags)

    dir = dir or "y"
    ratio = ratio or 0.5
    splitType = splitType or nil
    flags = flags or {}
    local centerWidth = centerWidth or 1

    local b = part:getBlock(block)
    local s = b.box.size
    local boxType = b.box.type
    local originalColor = b.color

    -- you can give each block a custom BlockType and a custom color BUT you need to figure out yourself if you need an edge part
    local firstBlockType = flags.firstBlockType or b.blockIndex
    local middleBlockType = flags.middleBlockType or b.blockIndex
    local lastBlockType= flags.lastBlockType or b.blockIndex

    local firstBlockColor = flags.firstBlockColor or b.color
    local middleBlockColor = flags.middleBlockColor or b.color
    local lastBlockColor = flags.lastBlockColor or b.color

    local lightSplit = flags.lightSplit or 0
    local colorSplit = flags.colorSplit or 0

    if colorSplit == 1 then
        if boxType == BoxType.Edge then
            middleBlockType = BlockType.EdgeHull
        else
            middleBlockType = BlockType.Hull
        end

        firstBlockColor = b.color
        lastBlockColor = b.color
    end

    if lightSplit == 1 then
        if boxType == BoxType.Edge then
            middleBlockType = BlockType.GlowEdge
        else
            middleBlockType = BlockType.Glow
        end

        middleBlockColor = flags.middleBlockColor or initialSettings.colors.light
        firstBlockColor = b.color
        lastBlockColor = b.color
    end

    if ratio >= 1.0 then
        local l = b.box.lower
        local u = b.box.upper
        local o

        if isY(dir) then
            part:transform(block, {upper = vec3(u.x, u.y - centerWidth, u.z), index = firstBlockType, color = firstBlockColor})
            o = part:block(block, "y", middleBlockType, vec3(s.x, centerWidth, s.z), middleBlockColor, b.orientation)
        elseif isX(dir) then
            part:transform(block, {upper = vec3(u.x - centerWidth, u.y, u.z), index = firstBlockType, color = firstBlockColor})
            o = part:block(block, "x", middleBlockType, vec3(centerWidth, s.y, s.z), middleBlockColor, b.orientation)
        elseif isZ(dir) then
            part:transform(block, {upper = vec3(u.x, u.y, u.z - centerWidth), index = firstBlockType, color = firstBlockColor})
            o = part:block(block, "z", middleBlockType, vec3(s.x, s.y, centerWidth), middleBlockColor, b.orientation)
        end

        return {lower = block, upper = o, root = block, block = block}
    elseif ratio <= 0.0 then
        local l = b.box.lower
        local u = b.box.upper
        local o

        if isY(dir) then
            part:transform(block, {lower = vec3(l.x, l.y + centerWidth, l.z), index = lastBlockType, color = lastBlockColor})
            o = part:block(block, "-y", middleBlockType, vec3(s.x, centerWidth, s.z), middleBlockColor, b.orientation)
        elseif isX(dir) then
            part:transform(block, {lower = vec3(l.x + centerWidth, l.y, l.z), index = lastBlockType, color = lastBlockColor})
            o = part:block(block, "-x", middleBlockType, vec3(centerWidth, s.y, s.z), middleBlockColor, b.orientation)
        elseif isZ(dir) then
            part:transform(block, {lower = vec3(l.x, l.y, l.z + centerWidth), index = lastBlockType, color = lastBlockColor})
            o = part:block(block, "-z", middleBlockType, vec3(s.x, s.y, centerWidth), middleBlockColor, b.orientation)
        end

        return {lower = o, upper = block, root = block, block = block}
    else
        local l, u
        if isY(dir) then
            part:transform(block, {size = vec3(s.x, centerWidth, s.z), index = middleBlockType, color = middleBlockColor})
            u = part:block(block, "+y", firstBlockType, vec3(s.x, s.y * (1 - ratio) - centerWidth * 0.5, s.z), firstBlockColor, b.orientation)
            l = part:block(block, "-y", lastBlockType, vec3(s.x, s.y * ratio - centerWidth * 0.5, s.z), lastBlockColor, b.orientation)

        elseif isX(dir) then
            part:transform(block, {size = vec3(centerWidth, s.y, s.z), index = middleBlockType, color = middleBlockColor})
            u = part:block(block, "+x", firstBlockType, vec3(s.x * (1 - ratio) - centerWidth * 0.5, s.y, s.z), firstBlockColor, b.orientation)
            l = part:block(block, "-x", lastBlockType, vec3(s.x * ratio - centerWidth * 0.5, s.y, s.z), lastBlockColor, b.orientation)

        elseif isZ(dir) then
            part:transform(block, {size = vec3(s.x, s.y, centerWidth), index = middleBlockType, color = middleBlockColor})
            u = part:block(block, "+z", firstBlockType, vec3(s.x, s.y, s.z * (1 - ratio) - centerWidth * 0.5), firstBlockColor, b.orientation)
            l = part:block(block, "-z", lastBlockType, vec3(s.x, s.y, s.z * ratio - centerWidth * 0.5), lastBlockColor, b.orientation)
        end

        return {lower = l, upper = u, root = block, block = block}
    end
end

function windowPane(part, parent, dir, windowWidth, separatorWidth, windowHeight, numberOfWindows, flags)

    dir = dir or "y"
    windowWidth = windowWidth or 0.2 -- the width of the glow blocks
    separatorWidth = separatorWidth or 0.2 -- the width of the distance between the windows
    windowHeight = windowHeight or 0.4 -- the height of the windows
    numberOfWindows = numberOfWindows or 5 -- the number of windows
    -- we can only make panels with 3 or 5 windows for now
    if numberOfWindows <= 4 then numberOfWindows = 3 end
    if numberOfWindows > 4 then numberOfWindows = 5 end
    flags = flags or {}

    local blocks = { }
    blocks.root = parent

    local glowColor = flags.glowColor or initialSettings.colors.light
    local block = part:getBlock(parent)
    local color = flags.color or block.color
    local blockType = flags.blockType or BlockType.Glow

    local lengthXWindow
    local lengthYWindow
    local lengthZWindow
    local lengthXSeparator
    local lengthYSeparator
    local lengthZSeparator

    local stickOnDirectionLeft
    local stickOnDirectionRight

    if dir == "x" or dir == "-x" then
        lengthXSeparator = 0.01
        lengthYSeparator = windowHeight
        lengthZSeparator = separatorWidth
        lengthXWindow = 0.01
        lengthYWindow = windowHeight
        lengthZWindow = windowWidth
        stickOnDirectionLeft = "z"
        stickOnDirectionRight = "-z"
    end
    if dir == "y" or dir == "-y" then
        lengthXSeparator = separatorWidth
        lengthYSeparator = 0.01
        lengthZSeparator = windowHeight
        lengthXWindow = windowWidth
        lengthYWindow = 0.01
        lengthZWindow = windowHeight
        stickOnDirectionLeft = "x"
        stickOnDirectionRight = "-x"
    end
    if dir == "z" or dir == "-z" then
        lengthXSeparator = separatorWidth
        lengthYSeparator = windowHeight
        lengthZSeparator = 0.01
        lengthXWindow = windowWidth
        lengthYWindow = windowHeight
        lengthZWindow = 0.01
        stickOnDirectionLeft = "x"
        stickOnDirectionRight = "-x"
    end

    blocks.windowMiddle = part:block(blocks.root, dir, blockType, vec3(lengthXWindow, lengthYWindow, lengthZWindow), glowColor)
    blocks.windowLeft1 = part:block(blocks.windowMiddle, stickOnDirectionLeft, BlockType.Hull, vec3(lengthXSeparator, lengthYSeparator, lengthZSeparator), color)
    blocks.windowLeft2 = part:block(blocks.windowLeft1, stickOnDirectionLeft, blockType, vec3(lengthXWindow, lengthYWindow, lengthZWindow), glowColor)
    blocks.windowRight1 = part:block(blocks.windowMiddle, stickOnDirectionRight, BlockType.Hull, vec3(lengthXSeparator, lengthYSeparator, lengthZSeparator), color)
    blocks.windowRight2 = part:block(blocks.windowRight1, stickOnDirectionRight, blockType, vec3(lengthXWindow, lengthYWindow, lengthZWindow), glowColor)

    if numberOfWindows == 5 then
        blocks.windowLeft3 = part:block(blocks.windowLeft2, stickOnDirectionLeft, BlockType.Hull, vec3(lengthXSeparator, lengthYSeparator, lengthZSeparator), color)
        blocks.windowLeft4 = part:block(blocks.windowLeft3, stickOnDirectionLeft, blockType, vec3(lengthXWindow, lengthYWindow, lengthZWindow), glowColor)
        blocks.windowRight3 = part:block(blocks.windowRight2, stickOnDirectionRight, BlockType.Hull, vec3(lengthXSeparator, lengthYSeparator, lengthZSeparator), color)
        blocks.windowRight4 = part:block(blocks.windowRight3, stickOnDirectionRight, blockType, vec3(lengthXWindow, lengthYWindow, lengthZWindow), glowColor)
    end

    return blocks, blocks.root
end

function symbolSign(part, parent, dir, size, flags)

    dir = dir or "y"
    size = size or 1 -- the width and height of the sign

    flags = flags or {}

    local blocks = { }
    blocks.root = parent

    local block = part:getBlock(parent)
    local color1 = flags.color1 or GeneratorColors.Darkest
    local color2 = flags.color2 or block.color
    local blockType1 = flags.blockType or BlockType.Hull
    local blockType2 = flags.blockType or BlockType.EdgeHull

    if dir == "x" or dir == "-x" then
        blocks.baseBase = part:block(blocks.root, dir, blockType1, vec3(0.01, size * 1.1, size * 1.1), color1)
        blocks.base = part:block(blocks.baseBase, dir, blockType1, vec3(0.01, size, size), color2)
        blocks.splitBase = split(part, blocks.base, "y", 0.5)
        blocks.baseTop = split(part, blocks.splitBase.top, "z", 0.5)
        blocks.baseBottom = split(part, blocks.splitBase.bottom, "z", 0.5)
        blocks.baseTopFront = blocks.baseTop.front
        blocks.baseTopBack = blocks.baseTop.back
        blocks.baseBottomFront = blocks.baseBottom.front
        blocks.baseBottomBack = blocks.baseBottom.back

        blocks.symbolTopFront = part:block(blocks.baseTopFront, dir, blockType2, vec3(0.01, size/2, size/2), color1, bwdn)
        blocks.symbolTopBack = part:block(blocks.baseTopBack, dir, blockType2, vec3(0.01, size/2, size/2), color1, bwup)
        blocks.symbolBottomFront = part:block(blocks.baseBottomFront, dir, blockType2, vec3(0.01, size/2, size/2), color1, fwdn)
        blocks.symbolBottomBack = part:block(blocks.baseBottomBack, dir, blockType2, vec3(0.01, size/2, size/2), color1, fwup)
    end
    if dir == "y" or dir == "-y" then
        blocks.baseBase = part:block(blocks.root, dir, blockType1, vec3(size * 1.1, 0.01, size * 1.1), color1)
        blocks.base = part:block(blocks.baseBase, dir, blockType1, vec3(size, 0.01, size), color2)
        blocks.splitBase = split(part, blocks.base, "z", 0.5)
        blocks.baseFront = split(part, blocks.splitBase.front, "x", 0.5)
        blocks.baseBack = split(part, blocks.splitBase.back, "x", 0.5)
        blocks.baseFrontLeft = blocks.baseFront.left
        blocks.baseFrontRight = blocks.baseFront.right
        blocks.baseBackLeft = blocks.baseBack.left
        blocks.baseBackRight = blocks.baseBack.right

        blocks.symbolFrontLeft = part:block(blocks.baseFrontLeft, dir, blockType2, vec3(size/2, 0.01, size/2), color1, fwlf)
        blocks.symbolFrontRight = part:block(blocks.baseFrontRight, dir, blockType2, vec3(size/2, 0.01, size/2), color1, bwlf)
        blocks.symbolBackLeft = part:block(blocks.baseBackLeft, dir, blockType2, vec3(size/2, 0.01, size/2), color1, fwrg)
        blocks.symbolBackRight = part:block(blocks.baseBackRight, dir, blockType2, vec3(size/2, 0.01, size/2), color1, bwrg)
    end
    if dir == "z" or dir == "-z" then
        blocks.baseBase = part:block(blocks.root, dir, blockType1, vec3(size * 1.1, size * 1.1, 0.01), color1)
        blocks.base = part:block(blocks.baseBase, dir, blockType1, vec3(size, size, 0.01), color2)
        blocks.splitBase = split(part, blocks.base, "y", 0.5)
        blocks.baseTop = split(part, blocks.splitBase.top, "x", 0.5)
        blocks.baseBottom = split(part, blocks.splitBase.bottom, "x", 0.5)
        blocks.baseTopLeft = blocks.baseTop.left
        blocks.baseTopRight = blocks.baseTop.right
        blocks.baseBottomLeft = blocks.baseBottom.left
        blocks.baseBottomRight = blocks.baseBottom.right

        blocks.symbolTopLeft = part:block(blocks.baseTopLeft, dir, blockType2, vec3(size/2, size/2, 0.01), color1, lfup)
        blocks.symbolTopRight = part:block(blocks.baseTopRight, dir, blockType2, vec3(size/2, size/2, 0.01), color1, lfdn)
        blocks.symbolBottomLeft = part:block(blocks.baseBottomLeft, dir, blockType2, vec3(size/2, size/2, 0.01), color1, rgup)
        blocks.symbolBottomRight = part:block(blocks.baseBottomRight, dir, blockType2, vec3(size/2, size/2, 0.01), color1, rgdn)
    end

    return blocks, blocks.root
end

function symbolSign2(part, parent, dir, size, flags)

    dir = dir or "y"
    size = size or 1 -- the width and height of the sign

    flags = flags or {}

    local blocks = { }
    blocks.root = parent

    local block = part:getBlock(parent)
    local color1 = flags.color1 or GeneratorColors.Darkest
    local color2 = flags.color2 or block.color
    local blockType1 = flags.blockType or BlockType.Hull
    local blockType2 = flags.blockType or BlockType.EdgeHull

    if dir == "x" or dir == "-x" then
        blocks.baseBase = part:block(blocks.root, dir, blockType1, vec3(0.01, size, 0.01), color1)
        blocks.base = split(part, blocks.baseBase, "y", 0.5)

        blocks.symbolTopFront = part:block(blocks.base.top, "z", blockType2, vec3(0.01, size/2, size/2), color1, bwdn)
        blocks.symbolTopBack = part:block(blocks.base.top, "-z", blockType2, vec3(0.01, size/2, size/2), color1, bwup)
        blocks.symbolBottomFront = part:block(blocks.base.bottom, "z", blockType2, vec3(0.01, size/2, size/2), color1, fwdn)
        blocks.symbolBottomBack = part:block(blocks.base.bottom, "-z", blockType2, vec3(0.01, size/2, size/2), color1, fwup)
    end
    if dir == "y" or dir == "-y" then
        blocks.baseBase = part:block(blocks.root, dir, blockType1, vec3(0.01, 0.01, size), color1)
        blocks.base = split(part, blocks.baseBase, "z", 0.5)

        blocks.symbolFrontLeft = part:block(blocks.base.front, "x", blockType2, vec3(size/2, 0.01, size/2), color1, fwlf)
        blocks.symbolFrontRight = part:block(blocks.base.front, "-x", blockType2, vec3(size/2, 0.01, size/2), color1, bwlf)
        blocks.symbolBackLeft = part:block(blocks.base.back, "x", blockType2, vec3(size/2, 0.01, size/2), color1, fwrg)
        blocks.symbolBackRight = part:block(blocks.base.back, "-x", blockType2, vec3(size/2, 0.01, size/2), color1, bwrg)
    end
    if dir == "z" or dir == "-z" then
        blocks.baseBase = part:block(blocks.root, dir, blockType1, vec3(size, 0.01, 0.01), color1)
        blocks.base = split(part, blocks.baseBase, "x", 0.5)

        blocks.symbolTopLeft = part:block(blocks.base.left, "y", blockType2, vec3(size/2, size/2, 0.01), color1, lfup)
        blocks.symbolTopRight = part:block(blocks.base.right, "y", blockType2, vec3(size/2, size/2, 0.01), color1, lfdn)
        blocks.symbolBottomLeft = part:block(blocks.base.left, "-y", blockType2, vec3(size/2, size/2, 0.01), color1, rgup)
        blocks.symbolBottomRight = part:block(blocks.base.right, "-y", blockType2, vec3(size/2, size/2, 0.01), color1, rgdn)
    end

    return blocks, blocks.root
end

function spike(part, parent, dir, size, spikeHeight, flags)

    dir = dir or "y"
    size = size or vec3(1, 1, 1) -- the width and height of the sign
    spikeHeight = spikeHeight or 1

    flags = flags or {}

    local blocks = { }
    blocks.root = parent

    local block = part:getBlock(parent)
    local color1 = flags.color1 or block.color
    local color2 = flags.color2 or block.color
    local blockType1 = flags.blockType or BlockType.Hull
    local blockType2 = flags.blockType or BlockType.CornerHull

    if dir == "x" then
        blocks.base = part:block(blocks.root, dir, blockType1, vec3(0.01, size.y, size.z), color1)
        blocks.split = split(part, blocks.base, "z", 0.5)
        blocks.frontBlocks = split(part, blocks.split.front, "y", 0.5)
        blocks.backBlocks = split(part, blocks.split.back, "y", 0.5)

        blocks.frontTopSpike = part:block(blocks.frontBlocks.top, dir, blockType2, vec3(spikeHeight, size.z/2, size.z/2), color2, dnlf)
        blocks.frontBottomSpike = part:block(blocks.frontTopSpike, "-y", blockType2, vec3(spikeHeight, size.z/2, size.z/2), color1, bwlf)
        blocks.backTopSpike = part:block(blocks.frontTopSpike, "-z", blockType2, vec3(spikeHeight, size.z/2, size.z/2), color2, fwlf)
        blocks.backBottomSpike = part:block(blocks.backTopSpike, "-y", blockType2, vec3(spikeHeight, size.z/2, size.z/2), color1, uplf)

        blocks.base = part:merge({blocks.frontBlocks.top, blocks.frontBlocks.bottom, blocks.backBlocks.top, blocks.backBlocks.bottom})
    end
    if dir == "-x" then
        blocks.base = part:block(blocks.root, dir, blockType1, vec3(0.01, size.y, size.z), color1)
        blocks.split = split(part, blocks.base, "z", 0.5)
        blocks.frontBlocks = split(part, blocks.split.front, "y", 0.5)
        blocks.backBlocks = split(part, blocks.split.back, "y", 0.5)

        blocks.frontTopSpike = part:block(blocks.frontBlocks.top, dir, blockType2, vec3(spikeHeight, size.z/2, size.z/2), color2, bwrg)
        blocks.frontBottomtSpike = part:block(blocks.frontTopSpike, "-y", blockType2, vec3(spikeHeight, size.z/2, size.z/2), color1, uprg)
        blocks.backTopSpike = part:block(blocks.frontTopSpike, "-z", blockType2, vec3(spikeHeight, size.z/2, size.z/2), color2, dnrg)
        blocks.backBottomSpike = part:block(blocks.backTopSpike, "-y", blockType2, vec3(spikeHeight, size.z/2, size.z/2), color1, lfdn)

        blocks.base = part:merge({blocks.frontBlocks.top, blocks.frontBlocks.bottom, blocks.backBlocks.top, blocks.backBlocks.bottom})
    end
    if dir == "y" then
        blocks.base = part:block(blocks.root, dir, blockType1, vec3(size.x, 0.01, size.z), color1)
        blocks.split = split(part, blocks.base, "z", 0.5)
        blocks.frontBlocks = split(part, blocks.split.front, "x", 0.5)
        blocks.backBlocks = split(part, blocks.split.back, "x", 0.5)

        blocks.frontLeftSpike = part:block(blocks.frontBlocks.left, dir, blockType2, vec3(size.x/2, spikeHeight, size.z/2), color2, dnlf)
        blocks.frontRightSpike = part:block(blocks.frontLeftSpike, "-x", blockType2, vec3(size.x/2, spikeHeight, size.z/2), color1, bwrg)
        blocks.backLeftSpike = part:block(blocks.frontLeftSpike, "-z", blockType2, vec3(size.x/2, spikeHeight, size.z/2), color2, fwlf)
        blocks.backRightSpike = part:block(blocks.frontRightSpike, "-z", blockType2, vec3(size.x/2, spikeHeight, size.z/2), color1, dnrg)

        blocks.base = part:merge({blocks.frontBlocks.left, blocks.frontBlocks.right, blocks.backBlocks.left, blocks.backBlocks.right})
    end
    if dir == "-y" then
        blocks.base = part:block(blocks.root, dir, blockType1, vec3(size.x, 0.01, size.z), color1)
        blocks.split = split(part, blocks.base, "z", 0.5)
        blocks.frontBlocks = split(part, blocks.split.front, "x", 0.5)
        blocks.backBlocks = split(part, blocks.split.back, "x", 0.5)

        blocks.frontLeftSpike = part:block(blocks.frontBlocks.left, dir, blockType2, vec3(size.x/2, spikeHeight, size.z/2), color2, rgdn)
        blocks.frontRightSpike = part:block(blocks.frontLeftSpike, "-x", blockType2, vec3(size.x/2, spikeHeight, size.z/2), color1, uprg)
        blocks.backLeftSpike = part:block(blocks.frontLeftSpike, "-z", blockType2, vec3(size.x/2, spikeHeight, size.z/2), color2, uplf)
        blocks.backRightSpike = part:block(blocks.frontRightSpike, "-z", blockType2, vec3(size.x/2, spikeHeight, size.z/2), color1, lfdn)

        blocks.base = part:merge({blocks.frontBlocks.left, blocks.frontBlocks.right, blocks.backBlocks.left, blocks.backBlocks.right})
    end
    if dir == "z" then
        blocks.base = part:block(blocks.root, dir, blockType1, vec3(size.x, size.y, 0.01), color1)
        blocks.split = split(part, blocks.base, "x", 0.5)
        blocks.leftBlocks = split(part, blocks.split.left, "y", 0.5)
        blocks.rightBlocks = split(part, blocks.split.right, "y", 0.5)

        blocks.topLeftSpike = part:block(blocks.leftBlocks.top, dir, blockType2, vec3(size.x/2, size.x/2, spikeHeight), color2, dnlf)
        blocks.topRightSpike = part:block(blocks.topLeftSpike, "-x", blockType2, vec3(size.x/2, size.x/2, spikeHeight), color1, bwrg)
        blocks.bottomLeftSpike = part:block(blocks.topLeftSpike, "-y", blockType2, vec3(size.x/2, size.x/2, spikeHeight), color2, bwlf)
        blocks.bottomRightSpike = part:block(blocks.bottomLeftSpike, "-x", blockType2, vec3(size.x/2, size.x/2, spikeHeight), color1, uprg)

        blocks.base = part:merge({blocks.leftBlocks.left, blocks.leftBlocks.right, blocks.rightBlocks.left, blocks.rightBlocks.right})
    end
    if dir == "-z" then
        blocks.base = part:block(blocks.root, dir, blockType1, vec3(size.x, size.y, 0.01), color1)
        blocks.split = split(part, blocks.base, "x", 0.5)
        blocks.leftBlocks = split(part, blocks.split.left, "y", 0.5)
        blocks.rightBlocks = split(part, blocks.split.right, "y", 0.5)

        blocks.topLeftSpike = part:block(blocks.leftBlocks.top, dir, blockType2, vec3(size.x/2, size.x/2, spikeHeight), color2, fwlf)
        blocks.topRightSpike = part:block(blocks.topLeftSpike, "-x", blockType2, vec3(size.x/2, size.x/2, spikeHeight), color1, dnrg)
        blocks.bottomLeftSpike = part:block(blocks.topLeftSpike, "-y", blockType2, vec3(size.x/2, size.x/2, spikeHeight), color2, uplf)
        blocks.bottomRightSpike = part:block(blocks.bottomLeftSpike, "-x", blockType2, vec3(size.x/2, size.x/2, spikeHeight), color1, lfdn)

        blocks.base = part:merge({blocks.leftBlocks.left, blocks.leftBlocks.right, blocks.rightBlocks.left, blocks.rightBlocks.right})
    end

    return blocks, blocks.root
end

-- some defaults for error safety
Type = Type or PartType.Core
Features = Features or {}
OptionalFeatures = OptionalFeatures or {}
TransformationFeatures = TransformationFeatures or {}
generate = generate or function() return PlanPart() end

initialSettings = {}

function topLevelGenerate(seed, settings)
    -- settings.features contains:
    -- * ALL features of file's 'Feature' list
    -- * Additional features added through Style's 'additionalFeatures'
    -- * Additional features added through Stage's 'additionalFeatures'
    initialSettings = table.deepcopy(settings)
    local part = generate(seed, settings)

    applyVisualFeatures(part, seed, settings)
    applyTransformationFeatures(part, seed, settings)
    applyConnectorSettings(part, seed, settings)
    applyTopologicalFeatures(part, seed, settings)
    applyTransformations(part, seed, settings)
    applyScaling(part, seed, settings)

    return part
end

function applyVisualFeatures(part, seed, settings)
    local featureList = {}
    for feature, enabled in pairs(settings.features) do
        if enabled then
            table.insert(featureList, feature)
        end
    end

    for _, feature in pairs(Features) do
        table.insert(featureList, feature)
    end

    if settings.additionalFeatures then
        for _, feature in pairs(settings.additionalFeatures) do
            table.insert(featureList, feature)
        end
    end

    part.features = featureList
end

function applyTransformationFeatures(part, seed, settings)
    -- filter / add transformations
    local usedTransformationFeatures = table.deepcopy(TransformationFeatures)

    if settings.additionalTransformations then
        for _, tf in pairs(settings.additionalTransformations) do
            table.insert(usedTransformationFeatures, tf)
        end
    end

    if settings.transformationWhitelist then
        local allowed = {}
        for _, tf in pairs(settings.transformationWhitelist) do
            allowed[tf] = true
        end

        local temp = usedTransformationFeatures
        usedTransformationFeatures = {}
        for _, feature in pairs(temp) do
            if allowed[feature] then
                table.insert(usedTransformationFeatures, feature)
            end
        end
    end

    if settings.transformationBlacklist and #settings.transformationBlacklist > 0 then
        local forbidden = {}
        for _, tf in pairs(settings.transformationBlacklist) do
            forbidden[tf] = true
        end

        local temp = usedTransformationFeatures
        usedTransformationFeatures = {}
        for _, feature in pairs(temp) do
            if not forbidden[feature] then
                table.insert(usedTransformationFeatures, feature)
            end
        end
    end

    part.transformationFeatures = usedTransformationFeatures

end

function applyConnectorSettings(part, seed, settings)
    -- apply direction white/blacklist
    local directionWhitelist = settings.directionWhitelist or {}
    if directionWhitelist and #directionWhitelist > 0 then
        local allowed = {}
        for _, dir in pairs(directionWhitelist) do
            if isPX(dir) then allowed["x"] = true; allowed["+x"] = true; allowed["px"] = true; end
            if isPY(dir) then allowed["y"] = true; allowed["+y"] = true; allowed["py"] = true; end
            if isPZ(dir) then allowed["z"] = true; allowed["+z"] = true; allowed["pz"] = true; end

            if isNX(dir) then allowed["-x"] = true; allowed["nx"] = true; end
            if isNY(dir) then allowed["-y"] = true; allowed["ny"] = true; end
            if isNZ(dir) then allowed["-z"] = true; allowed["nz"] = true; end
        end

        for _, connector in pairs(part:getConnectors()) do
            if not allowed[connector.direction] then
                part:erase(connector.block, connector.direction)
            end
        end
    end

    local directionBlacklist = settings.directionBlacklist or {}
    if directionBlacklist and #directionBlacklist > 0 then
        local forbidden = {}
        for _, dir in pairs(directionBlacklist) do
            if isPX(dir) then forbidden["x"] = true; forbidden["+x"] = true; forbidden["px"] = true; end
            if isPY(dir) then forbidden["y"] = true; forbidden["+y"] = true; forbidden["py"] = true; end
            if isPZ(dir) then forbidden["z"] = true; forbidden["+z"] = true; forbidden["pz"] = true; end

            if isNX(dir) then forbidden["-x"] = true; forbidden["nx"] = true; end
            if isNY(dir) then forbidden["-y"] = true; forbidden["ny"] = true; end
            if isNZ(dir) then forbidden["-z"] = true; forbidden["nz"] = true; end
        end

        for _, connector in pairs(part:getConnectors()) do
            if forbidden[connector.direction] then
                part:erase(connector.block, connector.direction)
            end
        end
    end

    if settings.featureWhitelist and #settings.featureWhitelist > 0 then
        for _, connector in pairs(part:getConnectors()) do
            local flags = connector.flags
            flags.featureWhitelist = settings.featureWhitelist
            part:setConnectorFlags(connector.block, connector.direction, flags)
        end
    end

    if settings.featureBlacklist and #settings.featureBlacklist > 0 then
        for _, connector in pairs(part:getConnectors()) do
            local flags = connector.flags
            flags.featureBlacklist = settings.featureBlacklist
            part:setConnectorFlags(connector.block, connector.direction, flags)
        end
    end

    if settings.enforcedMirror then
        for _, connector in pairs(part:getConnectors()) do
            local flags = connector.flags
            flags.mirror = settings.enforcedMirror
            part:setConnectorFlags(connector.block, connector.direction, flags)
        end
    end
end

function applyTopologicalFeatures(part, seed, settings)
    local optional = {}
    local enabled = {}
    for _, feature in pairs(OptionalFeatures) do
        optional[feature] = true
        enabled[feature] = true
    end

    for _, feature in pairs(Features) do
        enabled[feature] = true
    end


    -- mirroring comfort: if mirroring along an axis is an optional, unset feature, it gets disabled automatically
    if optional[VisualFeature.MirrorX] and not settings.features[VisualFeature.MirrorX] then
        for _, connector in pairs(part:getConnectors()) do
            local flags = connector.flags
            if flags.mirror and isX(flags.mirror) then
                flags.mirror = nil
                part:setConnectorFlags(connector.block, connector.direction, flags)
            end
        end
    end

    if optional[VisualFeature.MirrorY] and not settings.features[VisualFeature.MirrorY] then
        for _, connector in pairs(part:getConnectors()) do
            local flags = connector.flags
            if flags.mirror and isY(flags.mirror) then
                flags.mirror = nil
                part:setConnectorFlags(connector.block, connector.direction, flags)
            end
        end
    end

    if optional[VisualFeature.MirrorZ] and not settings.features[VisualFeature.MirrorZ] then
        for _, connector in pairs(part:getConnectors()) do
            local flags = connector.flags
            if flags.mirror and isZ(flags.mirror) then
                flags.mirror = nil
                part:setConnectorFlags(connector.block, connector.direction, flags)
            end
        end
    end

    if optional[VisualFeature.Repeating] and not settings.features[VisualFeature.Repeating] then
        for _, connector in pairs(part:getConnectors()) do
            local flags = connector.flags
            if flags.repeatable then
                flags.repeatable = nil
                part:setConnectorFlags(connector.block, connector.direction, flags)
            end
        end
    end

    -- if a part is an End part, remove all connectors after the first one
    if settings.features[VisualFeature.End] then
        local first = true;
        for _, connector in pairs(part:getConnectors()) do
            if not connector.flags.inOnly then
                if not first then
                    part:erase(connector.block, connector.direction)
                end
                first = false
            end
        end
    end

    local symmetries = {}
    if enabled[VisualFeature.SymmetryX] then table.insert(symmetries, "x") end
    if enabled[VisualFeature.SymmetryY] then table.insert(symmetries, "y") end
    if enabled[VisualFeature.SymmetryZ] then table.insert(symmetries, "z") end

    part.symmetries = symmetries

end

function applyTransformations(part, seed, settings)
    if not settings.transformations then return end
    if #settings.transformations == 0 then return end

    local transformations = {}
    for key, value in pairs(settings.transformations) do
        transformations[key] = value.probability or 1
    end

    local random = Random(Seed(settings.factionSeed .. "_transformation" .. tostring(seed)))
    local index = getValueFromDistribution(transformations, random)
    if not index then return end

    local transformation = settings.transformations[index]
    if not transformation then return end

    if transformation.rotation then
        part:rotate(transformation.axis, transformation.rotation)
    elseif transformation.mirror then
        part:mirror(transformation.axis)
    end
end

function applyScaling(part, seed, settings)
    if not settings.scale then return end

    if type(settings.scale) == "table" then
        part:scale(vec3(settings.scale.x or 1, settings.scale.y or 1, settings.scale.z or 1))
    elseif type(settings.scale) == "number" then
        part:scale(vec3(settings.scale))
    end
end

