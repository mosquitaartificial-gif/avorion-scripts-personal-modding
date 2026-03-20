
-- This disables the part, so it's not created ingame. Remove to enable part.
if true then return end

package.path = package.path .. ";data/scripts/plangenerator/lib/?.lua"
package.path = package.path .. ";data/scripts/plangenerator/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"

-- mandatory base script for all parts
-- contains a topLevelGenerate() function that serves as a wrapper for generate() function below
-- topLevelGenerate() applies a few additional transformations and other utility things that are the same for all parts
include ("generator")

include ("utility")

-- see plangeneratorbase.lua for more detailed info on all PartTypes and VisualFeatures
-- Features contain all tags that the part will always support
-- Generator will filter parts based on style and their defined features
Features =
{
    PartType.Core,
    VisualFeature.Allround,
    VisualFeature.Medium,
    VisualFeature.SymmetryX,
    VisualFeature.SymmetryY,
    VisualFeature.SymmetryZ,
}
-- Features that can be enabled optionally, your part should support those
OptionalFeatures =
{
    VisualFeature.MirrorX,
    VisualFeature.Repeating,
}
-- TransformationFeatures define how the part can be transformed in order to be attached to a free connector
-- see enum TransformationFeatures in docs for full enum
TransformationFeatures =
{
    TransformationFeature.SingleRotationX,
    TransformationFeature.MirrorY,
}


-- main part, this function is called by the generator on creation of a new plan
-- to get deterministic results, use a random generator based on passed seed
-- Also see:
-- * PlanStyle docs
-- * PlanGenerationStage docs
-- settings: table with various settings about colors, shapes, etc. passed through from the style by the generator
function generate(seed, settings)
    -- feel free to use to get a good overview over settings passed
    -- printTable(settings)

    local random = Random(seed)
    local part = PlanPart() -- See PlanPart docs

    local size = settings.size

    -- create a block
    local root = part:block(-1, nil, BlockType.Hull, size, settings.colors.base)

    -- see generator.lua
    local r = ring(part, root, "y")

    -- create more blocks
    local front = part:block(r.front, "z", BlockType.Hull, size * vec3(1, 1, 0.5), settings.colors.base)
    local back = part:block(r.back, "-z", BlockType.Hull, size * vec3(1, 1, 0.5), settings.colors.base)

    -- add connectors, those will be used to attach parts during the generation process
    -- See PlanPart docs for detailed info
    part:connector(front, "z", {repeatable = true})
    part:connector(back, "-z", {repeatable = true})
    part:connector(root, "y")
    part:connector(root, "-y")
    part:connector(r.left, "x", {mirror = "x"})
    part:connector(r.right, "-x", {mirror = "x"})

    -- allrounder blocks will be transformed to whatever is necessary to make the ship work and flyable/steerable
    part.allrounders = {root, front, back}

    return part
end
