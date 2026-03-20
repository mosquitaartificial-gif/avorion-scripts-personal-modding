package.path = package.path .. ";data/scripts/?.lua"

local Extractions = {}

-- The existing UUIDs should NOT be changed
-- the order of the extractions in the table doesn't matter, feel free to sort/organize
-- UUIDs were generated using https://www.uuidgenerator.net/ (Version 4 UUID)
Extractions.Type =
{
    Ripcord = "ef36a71c-0c75-4f40-a284-a91d3cdced58",
    WormholeSpawner = "d5b78488-c891-4a68-be7e-e86e94cad996",
    WormholeGenerator = "b8938f2f-7497-4674-922f-960e7c8afc92",
    InactiveGate = "c8088db7-8973-43c0-9b39-11aaf0b5a5a9",
}

local RipcordExtraction = include("dlc/rift/lib/extractions/ripcordextraction")
local WormholeSpawnerExtraction = include("dlc/rift/lib/extractions/wormholespawnerextraction")
local WormholeGeneratorExtraction = include("dlc/rift/lib/extractions/wormholegeneratorextraction")
local InactiveGateExtraction = include("dlc/rift/lib/extractions/inactivegateextraction")

-- keep track of all commands here for automated creation
local registry = {}
registry[Extractions.Type.Ripcord] = RipcordExtraction
registry[Extractions.Type.WormholeSpawner] = WormholeSpawnerExtraction
registry[Extractions.Type.WormholeGenerator] = WormholeGeneratorExtraction
registry[Extractions.Type.InactiveGate] = InactiveGateExtraction

function Extractions.makeExtraction(type, ...)

    local ExtractionClass = registry[type]
    if not ExtractionClass then
        eprint("Error: Extraction type %s not found", type)
        return
    end

    return ExtractionClass(type, ...) -- creates a new extraction instance
end

function Extractions.getExtractionByDepth(riftDepth)
    local probabilities = {}
    -- probability of ripcord slowly reduces towards 35 (no longer available at all)
    probabilities[Extractions.Type.Ripcord] = lerp(riftDepth, 1, 35, 1, 0)

    -- wormhole spawner is available starting at 15, but only until 60
    if riftDepth >= 15 and riftDepth <= 37 then
        probabilities[Extractions.Type.WormholeSpawner] = lerp(riftDepth, 15, 37, 0, 1)
    end
    if riftDepth >= 38 and riftDepth <= 60 then
        probabilities[Extractions.Type.WormholeSpawner] = lerp(riftDepth, 37, 60, 1, 0)
    end

    -- wormhole generator can be available at depth 35, but only until 70
    if riftDepth >= 35 and riftDepth <= 65 then
        probabilities[Extractions.Type.WormholeGenerator] = lerp(riftDepth, 35, 65, 0, 1)
    end
    if riftDepth >= 66 and riftDepth <= 70 then
        probabilities[Extractions.Type.WormholeGenerator] = lerp(riftDepth, 65, 70, 1, 0)
    end

    -- inactive gate is available at depth 45
    -- starting at 70 only inactive gate is possible
    probabilities[Extractions.Type.InactiveGate] = lerp(riftDepth, 45, 75, 0, 1)

    local type = selectByWeight(random(), probabilities)
    return {type = type}
end

function Extractions.getRegistry()
    return registry
end

function Extractions.getExtractionTypes()
    return
    {
        Extractions.Type.Ripcord,
        Extractions.Type.WormholeSpawner,
        Extractions.Type.WormholeGenerator,
        Extractions.Type.InactiveGate,
    }
end

return Extractions
