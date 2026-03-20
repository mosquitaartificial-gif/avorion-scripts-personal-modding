package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("utility")
include ("stringutility")
include ("randomext")
include ("galaxy")
local AsteroidPlanGenerator = include ("asteroidplangenerator")
local FactionPacks = include ("factionpacks")
local StyleGenerator = include ("internal/stylegenerator.lua")

local StationStyleTypes =
{
    {script = "/factory.lua", factoryStyle = "Factory", subType = StationSubType.Factory},
    {script = "/factory.lua", factoryStyle = "Farm", subType = StationSubType.Farm},
    {script = "/factory.lua", factoryStyle = "Mine", subType = StationSubType.Mine},
    {script = "/factory.lua", factoryStyle = "Collector", subType = StationSubType.Collector},
    {script = "/factory.lua", factoryStyle = "SolarPowerPlant", subType = StationSubType.SolarPowerPlant},
    {script = "/factory.lua", factoryStyle = "Ranch", subType = StationSubType.Ranch},
    {script = "/factory.lua", subType = StationSubType.Factory},

    {script = "/shipyard.lua", subType = StationSubType.Shipyard},
    {script = "/repairdock.lua", subType = StationSubType.RepairDock},
    {script = "/resourcetrader.lua", subType = StationSubType.ResourceDepot},
    {script = "/tradingpost.lua", subType = StationSubType.TradingPost},
    {script = "/equipmentdock.lua", subType = StationSubType.EquipmentDock},
    {script = "/smugglersmarket.lua", subType = StationSubType.SmugglersMarket},
    {script = "/scrapyard.lua", subType = StationSubType.Scrapyard},

    {script = "/fighterfactory.lua", subType = StationSubType.FighterFactory},
    {script = "/turretfactory.lua", subType = StationSubType.TurretFactory},
    {script = "/turretfactorysupplier.lua", subType = StationSubType.TradingPost},

    {script = "/biotope.lua", subType = StationSubType.Biotope},
    {script = "/casino.lua", subType = StationSubType.Casino},
    {script = "/habitat.lua", subType = StationSubType.Habitat},
    {script = "/militaryoutpost.lua", subType = StationSubType.MilitaryOutpost},
    {script = "/headquarters.lua", subType = StationSubType.Headquarters},
    {script = "/researchstation.lua", subType = StationSubType.ResearchStation},
    {script = "/travelhub.lua", subType = StationSubType.TravelHub},
    {script = "/riftresearchcenter.lua", subType = StationSubType.RiftResearchCenter},

}




local PlanGenerator = {}

function findMaxBlock(plan, dimStr)

    local result
    local maximum = -math.huge
    for i = 0, plan.numBlocks - 1 do
        local block = plan:getNthBlock(i)

        local d = block.box.upper[dimStr]
        if d > maximum then
            result = block
            maximum = d
        end
    end

    return result
end

function findMinBlock(plan, dimStr)

    local result
    local minimum = math.huge
    for i = 0, plan.numBlocks - 1 do
        local block = plan:getNthBlock(i)

        local d = block.box.lower[dimStr]
        if d < minimum then
            result = block
            minimum = d
        end
    end

    return result
end

PlanGenerator.findMinBlock = findMinBlock
PlanGenerator.findMaxBlock = findMaxBlock

function PlanGenerator.selectMaterial(faction)
    local probabilities = Balancing_GetTechnologyMaterialProbability(faction:getHomeSectorCoordinates())
    local material = Material(getValueFromDistribution(probabilities))

    local sector = Sector()
    if sector then
        local x, y = sector:getCoordinates()
        local distFromCenter = length(vec2(x, y))

        if material.value == 6 and distFromCenter > Balancing_GetBlockRingMin() then
            material.value = 5
        end
    end

    return material
end

function PlanGenerator.getShipStyleDefaultName() return "Ship /* Craft classification */"%_T end
function PlanGenerator.getShipStyle(faction, styleName)
    styleName = styleName or PlanGenerator.getShipStyleDefaultName()

    local style = faction:getPlanStyle(styleName)
    if style then return style end

    local styleGenerator = StyleGenerator(faction.index)
    local style = styleGenerator:makeShipStyle(Seed(styleName))

    faction:addPlanStyle(styleName, style)

    return style
end

function PlanGenerator.getCarrierStyleDefaultName() return "Carrier /* Craft classification */"%_T end
function PlanGenerator.getCarrierStyle(faction, styleName)
    styleName = styleName or PlanGenerator.getCarrierStyleDefaultName()

    local style = faction:getPlanStyle(styleName)
    if style then return style end

    local styleGenerator = StyleGenerator(faction.index)
    local style = styleGenerator:makeCarrierStyle(Seed(styleName))

    faction:addPlanStyle(styleName, style)

    return style
end

function PlanGenerator.getFreighterStyleDefaultName() return "Freighter /* Craft classification */"%_T end
function PlanGenerator.getFreighterStyle(faction, styleName)
    styleName = styleName or PlanGenerator.getFreighterStyleDefaultName()

    local style = faction:getPlanStyle(styleName)
    if style then return style end

    local styleGenerator = StyleGenerator(faction.index)
    local style = styleGenerator:makeFreighterStyle(Seed(styleName))

    faction:addPlanStyle(styleName, style)

    return style
end

function PlanGenerator.getMinerStyleDefaultName() return "Miner /* Craft classification */"%_T end
function PlanGenerator.getMinerStyle(faction, styleName)
    styleName = styleName or PlanGenerator.getMinerStyleDefaultName()

    local style = faction:getPlanStyle(styleName)
    if style then return style end

    local styleGenerator = StyleGenerator(faction.index)
    local style = styleGenerator:makeMinerStyle(Seed(styleName))

    faction:addPlanStyle(styleName, style)

    return style
end

function PlanGenerator.getStationStyleDefaultName() return "Station /* Station classification, vanilla station in this case*/"%_T end
function PlanGenerator.getStationStyle(faction, styleName)
    styleName = styleName or PlanGenerator.getStationStyleDefaultName()

    local style = faction:getPlanStyle(styleName)
    if style then return style end

    local styleGenerator = StyleGenerator(faction.index)
    local style = styleGenerator:makeStationStyle(Seed(styleName), StationSubType[styleName])

    faction:addPlanStyle(styleName, style)

    return style
end


function PlanGenerator.makeAsyncFreighterPlan(callback, values, faction, volume, styleName, material, sync)
    local seed = math.random(0xffffffff)

    if not material then
        material = PlanGenerator.selectMaterial(faction)
    end

    local code = [[
        package.path = package.path .. ";data/scripts/lib/?.lua"
        package.path = package.path .. ";data/scripts/?.lua"

        local FactionPacks = include ("factionpacks")
        local PlanGenerator = include ("plangenerator")

        function run(styleName, seed, volume, material, factionIndex, ...)

            local faction = Faction(factionIndex)

            if not volume then
                volume = Balancing_GetSectorShipVolume(faction:getHomeSectorCoordinates());
                local deviation = Balancing_GetShipVolumeDeviation();
                volume = volume * deviation
            end

            local plan = FactionPacks.getFreighterPlan(faction, volume, material)
            if plan then return plan, ... end

            local style = PlanGenerator.getFreighterStyle(faction, styleName)
            local plan = GeneratePlanFromStyle(style, Seed(seed), volume, 5000, nil, material)

            return plan, ...
        end
    ]]

    if sync then
        return execute(code, styleName, seed, volume, material, faction.index)
    else
        values = values or {}
        async(callback, code, styleName, seed, volume, material, faction.index, unpack(values))
    end
end

function PlanGenerator.makeFreighterPlan(faction, volume, styleName, material)
    return PlanGenerator.makeAsyncFreighterPlan(nil, nil, faction, volume, styleName, material, true)
end

function PlanGenerator.makeAsyncMinerPlan(callback, values, faction, volume, styleName, material, sync)
    local seed = math.random(0xffffffff)

    if not material then
        material = PlanGenerator.selectMaterial(faction)
    end

    local code = [[
        package.path = package.path .. ";data/scripts/lib/?.lua"
        package.path = package.path .. ";data/scripts/?.lua"

        local FactionPacks = include ("factionpacks")
        local PlanGenerator = include ("plangenerator")

        function run(styleName, seed, volume, material, factionIndex, ...)

            local faction = Faction(factionIndex)

            if not volume then
                volume = Balancing_GetSectorShipVolume(faction:getHomeSectorCoordinates());
                local deviation = Balancing_GetShipVolumeDeviation();
                volume = volume * deviation
            end

            local plan = FactionPacks.getMinerPlan(faction, volume, material)
            if plan then return plan, ... end

            local style = PlanGenerator.getMinerStyle(faction, styleName)
            local plan = GeneratePlanFromStyle(style, Seed(seed), volume, 5000, 1, material)

            return plan, ...
        end
    ]]

    if sync then
        return execute(code, styleName, seed, volume, material, faction.index)
    else
        values = values or {}
        async(callback, code, styleName, seed, volume, material, faction.index, unpack(values))
    end
end

function PlanGenerator.makeMinerPlan(faction, volume, styleName, material)
    return PlanGenerator.makeAsyncMinerPlan(nil, nil, faction, volume, styleName, material, true)
end

function PlanGenerator.makeAsyncCarrierPlan(callback, values, faction, volume, styleName, material, sync)
    local seed = math.random(0xffffffff)

    if not material then
        material = PlanGenerator.selectMaterial(faction)
    end

    local code = [[
        package.path = package.path .. ";data/scripts/lib/?.lua"
        package.path = package.path .. ";data/scripts/?.lua"

        local FactionPacks = include ("factionpacks")
        local PlanGenerator = include ("plangenerator")

        function run(styleName, seed, volume, material, factionIndex, ...)

            local faction = Faction(factionIndex)
            if not volume then
                volume = Balancing_GetSectorShipVolume(faction:getHomeSectorCoordinates());
                local deviation = Balancing_GetShipVolumeDeviation();
                volume = volume * deviation
            end

            local plan = FactionPacks.getCarrierPlan(faction, volume, material)
            if plan then return plan, ... end

            local style = PlanGenerator.getCarrierStyle(faction, styleName)
            local plan = GeneratePlanFromStyle(style, Seed(seed), volume, 5000, nil, material)

            return plan, ...
        end
    ]]

    if sync then
        return execute(code, styleName, seed, volume, material, faction.index)
    else
        values = values or {}
        async(callback, code, styleName, seed, volume, material, faction.index, unpack(values))
    end
end

function PlanGenerator.makeCarrierPlan(faction, volume, styleName, material)
    return PlanGenerator.makeAsyncCarrierPlan(nil, nil, faction, volume, styleName, material, true)
end

function PlanGenerator.makeAsyncShipPlan(callback, values, faction, volume, styleName, material, sync)
    local seed = math.random(0xffffffff)

    if not material then
        material = PlanGenerator.selectMaterial(faction)
    end

    local code = [[
        package.path = package.path .. ";data/scripts/lib/?.lua"
        package.path = package.path .. ";data/scripts/?.lua"

        local FactionPacks = include ("factionpacks")
        local PlanGenerator = include ("plangenerator")

        function run(styleName, seed, volume, material, factionIndex, ...)

            local faction = Faction(factionIndex)
            if not volume then
                volume = Balancing_GetSectorShipVolume(faction:getHomeSectorCoordinates());
                local deviation = Balancing_GetShipVolumeDeviation();
                volume = volume * deviation
            end

            local plan = FactionPacks.getShipPlan(faction, volume, material)
            if plan then return plan, ... end

            local style = PlanGenerator.getShipStyle(faction, styleName)

            plan = GeneratePlanFromStyle(style, Seed(seed), volume, 6000, 1, material)
            return plan, ...
        end
    ]]

    if sync then
        return execute(code, styleName, seed, volume, material, faction.index)
    else
        values = values or {}
        async(callback, code, styleName, seed, volume, material, faction.index, unpack(values))
    end
end

function PlanGenerator.makeShipPlan(faction, volume, styleName, material)
    return PlanGenerator.makeAsyncShipPlan(nil, nil, faction, volume, styleName, material, true)
end

function PlanGenerator.makeFighterPlan(factionIndex, seed, material)
    if factionIndex then
        local plan = FactionPacks.getFighterPlan(factionIndex, nil, material)
        if plan then return plan end
    end

    local styleGenerator = StyleGenerator(factionIndex)
    local style = styleGenerator:makeFighterStyle(seed)
    local plan = GeneratePlanFromStyle(style, Seed(tostring(seed) .. "+1"), 5000, 200, nil, material)

    return plan
end

function PlanGenerator.makeCargoShuttlePlan(factionIndex, seed, material)
    local plan
    if factionIndex then
        plan = FactionPacks.getFighterPlan(factionIndex, nil, material)
    end

    if not plan then
        local styleGenerator = StyleGenerator(factionIndex)
        local style = styleGenerator:makeFighterStyle(seed)
        plan = GeneratePlanFromStyle(style, Seed(tostring(seed) .. "+1"), 5000, 200, nil, material)
    end

    local diameter = plan.radius * 2
    plan:scale(vec3(3.0 / diameter))

    local container = PlanGenerator.makeContainerPlan()

    local size = 0.95 / container.radius
    container:scale(vec3(size, size, size))
    container:displace(vec3(0, -0.7, 0))
    plan:addPlan(plan.rootIndex, container, container.rootIndex)

    plan:scale(vec3(diameter / 3.0))

    return plan
end

function PlanGenerator.makeCrewShuttlePlan(factionIndex, seed, material)
    local plan
    if factionIndex then
        plan = FactionPacks.getFighterPlan(factionIndex, nil, material)
    end

    if not plan then
        local styleGenerator = StyleGenerator(factionIndex)
        local style = styleGenerator:makeFighterStyle(seed)
        plan = GeneratePlanFromStyle(style, Seed(tostring(seed) .. "+1"), 5000, 200, nil, material)
    end

    local diameter = plan.radius * 2
    plan:scale(vec3(3.0 / diameter))

    local container = PlanGenerator.makeCrewQuartersPlan()

    local size = 0.95 / container.radius
    container:scale(vec3(size, size, size))

    local boundingBox = container:getBoundingBox()
    local minZ = boundingBox.lower.z
    local maxZ = boundingBox.upper.z

    for i = 0, plan.numBlocks - 1 do
        local block = plan:getNthBlock(i)
        if block.box.position.z >= 0 then
            container:addBlock(block.box.position + vec3(0, 0, maxZ), block.box.size, container.rootIndex, -1, block.color, block.material, block.orientation, block.blockIndex, block.secondaryColor)
        else
            container:addBlock(block.box.position + vec3(0, 0, minZ), block.box.size, container.rootIndex, -1, block.color, block.material, block.orientation, block.blockIndex, block.secondaryColor)
        end
    end

    plan:scale(vec3(diameter / 3.0))

    return container
end

function PlanGenerator.makeAsyncXsotanShipPlan(callback, values, volume, material, carrier)
    local seed = math.random(0xffffffff)

    local code = [[
        package.path = package.path .. ";data/scripts/lib/?.lua"
        package.path = package.path .. ";data/scripts/?.lua"

        local PlanGenerator = include ("plangenerator")
        local StyleGenerator = include ("internal/stylegenerator.lua")

        function run(seed, volume, material, carrier, ...)
            local styleGenerator = StyleGenerator(1337)
            local style
            if carrier then
                style = styleGenerator:makeXsotanCarrierStyle(seed)
            else
                style = styleGenerator:makeXsotanShipStyle(seed)
            end

            local plan = GeneratePlanFromStyle(style, Seed(seed), volume, 5000, nil, material)

            return plan, ...
        end
    ]]

    values = values or {}
    async(callback, code, seed, volume, material, carrier, unpack(values))
end

function PlanGenerator.makeXsotanShipPlan(volume, material)
    local styleGenerator = StyleGenerator(1337)

    local seed = math.random(0xffffffff)
    local style = styleGenerator:makeXsotanShipStyle(seed)
    local plan = GeneratePlanFromStyle(style, Seed(tostring(seed)), volume, 5000, nil, material)
    return plan
end

function PlanGenerator.makeXsotanCarrierPlan(volume, material)
    local styleGenerator = StyleGenerator(1337)

    local seed = math.random(0xffffffff)
    local style = styleGenerator:makeXsotanCarrierStyle(seed)
    local plan = GeneratePlanFromStyle(style, Seed(tostring(seed)), volume, 5000, nil, material)
    return plan
end

function PlanGenerator.determineStationStyleFromScriptArguments(scriptName, arg1)
    if not scriptName then return "Station" end

    local result = nil
    for _, style in pairs(StationStyleTypes) do

        if scriptName:ends(style.script) then
            if style.factoryStyle then
                if arg1 and style.factoryStyle == arg1.factoryStyle then
                    result = style.subType
                    break
                end
            else
                result = style.subType
                break
            end
        end
    end

    if not result then
        eprint("Warning: No station style found for " .. scriptName)
        result = StationSubType.Default
    end

    for k, v in pairs(StationSubType) do
        if v == result then return k end
    end

    return "Station"
end


function PlanGenerator.makeStationPlan(faction, styleName, seed, volume, material)
    seed = seed or math.random(0xffffffff)
    if not volume then
        volume = Balancing_GetSectorStationVolume(faction:getHomeSectorCoordinates())
        volume = volume * Balancing_GetStationVolumeDeviation()
    end

    material = material or PlanGenerator.selectMaterial(faction)

    local plan = FactionPacks.getStationPlan(faction, volume, material, styleName)
    if plan then return plan end

    local style = PlanGenerator.getStationStyle(faction, styleName)

    local plan = GeneratePlanFromStyle(style, Seed(seed), volume, 10000, nil, material)
    return plan, seed, volume, material
end

function PlanGenerator.makeBigAsteroidPlan(size, resources, material, iterations)
    return AsteroidPlanGenerator():makeBigAsteroidPlan(size, resources, material, iterations)
end

function PlanGenerator.makeSmallHiddenResourcesAsteroidPlan(size, material)
    return AsteroidPlanGenerator():makeSmallHiddenResourcesAsteroidPlan(size, material)
end

function PlanGenerator.makeSmallAsteroidPlan(size, resources, material, forceShape)
    return AsteroidPlanGenerator():makeSmallAsteroidPlan(size, resources, material, forceShape)
end

-- "titanium" is actually just the shape - not necessarily the material
function PlanGenerator.makeTitaniumAsteroidPlan(size, material, flags)
    return AsteroidPlanGenerator():makeTitaniumAsteroidPlan(size, material, flags)
end

-- "Trinium" is actually just the shape - not necessarily the material
function PlanGenerator.makeTriniumAsteroidPlan(size, material, flags)
    return AsteroidPlanGenerator():makeTriniumAsteroidPlan(size, material, flags)
end

-- "xanion" is actually just the shape - not necessarily the material
function PlanGenerator.makeXanionAsteroidPlan(size, material, flags)
    return AsteroidPlanGenerator():makeXanionAsteroidPlan(size, material, flags)
end

-- "ogonite" is actually just the shape - not necessarily the material
function PlanGenerator.makeOgoniteAsteroidPlan(size, material, flags)
    return AsteroidPlanGenerator():makeOgoniteAsteroidPlan(size, material, flags)
end

-- "avorion" is actually just the shape - not necessarily the material
function PlanGenerator.makeAvorionAsteroidPlan(size, material, flags)
    return AsteroidPlanGenerator():makeAvorionAsteroidPlan(size, material, flags)
end

function PlanGenerator.makeDefaultAsteroidPlan(size, material, flags)
    return AsteroidPlanGenerator():makeDefaultAsteroidPlan(size, material, flags)
end

function PlanGenerator.makeGatePlan(seed, color1, color2, color3)

    local r = random()
    local random = r

    if seed then random = Random(seed) end

    local bright = color1 or ColorRGB(0.5, 0.5, 0.5)
    local dark = color2 or ColorRGB(0.25, 0.25, 0.25)
    local colored = color3 or ColorHSV(random:getFloat(0, 360), random:getFloat(0.5, 0.7), random:getFloat(0.4, 0.6))
    local iron = Material()
    local orientation = Matrix()
    local block = BlockType.BlankHull
    local edge = BlockType.EdgeHull

    local slopes = random:getFloat() < 0.5 and true or false
    local lightLines = random:getFloat() < 0.35 and true or false
    local rings = false
    local rings2 = false
    local rings3 = false
    local bubbleLights = false
    local secondaryLine = random:getFloat() < 0.5 and true or false
    local secondaryArms = random:getFloat() < 0.35 and true or false

    if not lightLines then
        rings = random:getFloat() < 0.5 and true or false
        rings2 = random:getFloat() < 0.5 and true or false
    end

    if not slopes and not rings then
        rings3 = true
    end

    if not lightLines then
        bubbleLights = true
    end

    local segment = BlockPlan()

    -- make main arm
    -- create 2 possible thicknesses for the default blocks
    local t1 = random:getFloat(1.3, 1.75)
    local t2 = random:getFloat(0.75, 1.3)

    -- choose from the 2 thicknesses
    local ta =  t2
    local tb = random:getFloat() < 0.5 and t1 or t2
    local tc = random:getFloat() < 0.5 and t1 or t2

    local ca = random:getFloat() < 0.5 and bright or dark
    local cb = random:getFloat() < 0.5 and bright or dark
    local cc = random:getFloat() < 0.5 and bright or dark
    local cd = bright

    if not slopes then cd = colored end

    local root = segment:addBlock(vec3(0, 1 + 1, 0), vec3(ta, 2, ta), -1, -1, ca, iron, orientation, block, ColorNone())
    local a = root

    local b = segment:addBlock(vec3(0, 1 + 3, 0), vec3(tb, 2, tb), a, -1, cb, iron, orientation, block, ColorNone())
    local c = segment:addBlock(vec3(0, 1 + 5, 0), vec3(tc, 2, tc), b, -1, cc, iron, orientation, block, ColorNone())
    local d = segment:addBlock(vec3(0, 1 + 7, 0), vec3(2.5, 2.5, 2.5), c, -1, cd, iron, orientation, block, ColorNone())

    -- antennas front back
    -- segment:addBlock(vec3(0, 1 + 7, 2), vec3(0.2, 0.2, 2.5), last, -1, white, iron, orientation, block, ColorNone())
    -- segment:addBlock(vec3(0, 1 + 7, -2), vec3(0.2, 0.2, 2.5), last, -1, white, iron, orientation, block, ColorNone())

    -- antennas outside
    local antennas = random:getInt(2, 4)

    for i = 1, antennas do
        local p = random:getVector(-1, 1)
        local f = random:getFloat(0.25, 1.75)
        p.x = 0;

        local s = vec3(2.5, 0.05, 0.05) * f
        segment:addBlock(vec3(2 + s.x * 0.5 - 1, 1 + 7, 0) + p, s, last, -1, bright, iron, orientation, block, ColorNone())
    end

    if secondaryLine then
        segment:addBlock(vec3(1, 1 + 2.875, 0), vec3(0.5, 5.75, 0.5), a, -1, ca, iron, MatrixLookUp(vec3(0, 1, 0), vec3(0, 0, -1)), BlockType.Light, ColorNone())
    end

    if bubbleLights then
        segment:addBlock(vec3(0, 1 + 7, 1.5), vec3(0.75, 0.75, 2), d, -1, ca, iron, MatrixLookUp(vec3(0, 1, 0), vec3(0, 0, -1)), BlockType.Light, ColorNone())
        segment:addBlock(vec3(0, 1 + 7, -1.5), vec3(0.75, 0.75, 2), d, -1, ca, iron, MatrixLookUp(vec3(0, 1, 0), vec3(0, 0, 1)), BlockType.Light, ColorNone())
    end

    if rings then
        local h = 0.1

        segment:addBlock(vec3(0, 1 + 1, 0), vec3(ta, h, ta) + h, a, -1, ca, iron, orientation, block, ColorNone())
        segment:addBlock(vec3(0, 1 + 3, 0), vec3(tb, h, tb) + h, b, -1, cb, iron, orientation, block, ColorNone())
        segment:addBlock(vec3(0, 1 + 5, 0), vec3(tc, h, tc) + h, c, -1, cc, iron, orientation, block, ColorNone())
        segment:addBlock(vec3(0, 1 + 7, 0), vec3(2.5, h, 2.5) + h, d, -1, bright, iron, orientation, block, ColorNone())
    end

    if rings2 then
        local h = 0.1

        segment:addBlock(vec3(0, 1 + 1, 0), vec3(h, 2.5, ta) + h, a, -1, ca, iron, orientation, block, ColorNone())
        segment:addBlock(vec3(0, 1 + 3, 0), vec3(h, 2.5, tb) + h, b, -1, cb, iron, orientation, block, ColorNone())
        segment:addBlock(vec3(0, 1 + 5, 0), vec3(h, 2.5, tc) + h, c, -1, cc, iron, orientation, block, ColorNone())
        segment:addBlock(vec3(0, 1 + 7, 0), vec3(h, 2.5, 2.5) + h, d, -1, bright, iron, orientation, block, ColorNone())
    end

    if rings3 then
        local h = 0.5

        segment:addBlock(vec3(0, 1 + 1, 0), vec3(ta, h, ta) + h, a, -1, ca, iron, orientation, block, ColorNone())
        segment:addBlock(vec3(0, 1 + 3, 0), vec3(tb, h, tb) + h, b, -1, cb, iron, orientation, block, ColorNone())
        segment:addBlock(vec3(0, 1 + 5, 0), vec3(tc, h, tc) + h, c, -1, cc, iron, orientation, block, ColorNone())
    end

    if lightLines then
        local h = 0.05

        local block = BlockType.Glow
        local color = copy(colored)
        color.value = 1.0

        segment:addBlock(vec3(0, 1 + 1, 0), vec3(h, 2, ta) + h, a, -1, color, iron, orientation, block, ColorNone())
        segment:addBlock(vec3(0, 1 + 3, 0), vec3(h, 2, tb) + h, b, -1, color, iron, orientation, block, ColorNone())
        segment:addBlock(vec3(0, 1 + 5, 0), vec3(h, 2, tc) + h, c, -1, color, iron, orientation, block, ColorNone())

        if random:getFloat() < 0.5 then
            segment:addBlock(vec3(0, 1 + 7, 0), vec3(2.5, h, 2.5) + h, d, -1, color, iron, orientation, block, ColorNone())
        else
            segment:addBlock(vec3(0, 1 + 7, 0), vec3(h, 2.5, 2.5) + h, d, -1, color, iron, orientation, block, ColorNone())
        end
    end

    if slopes then
        -- slope segments
        local slopeWidth = random:getFloat(t1 + 0.1, 2.5) -- 2.0 to 2.5, but always smaller than the biggest last element
        local slopeColor = colored -- one of the 3
        local slopeHeight = random:getFloat(0.5, 1.5)
        local slopeDist = random:getFloat() < 0.15 and slopeHeight * 0.125 or random:getFloat(slopeHeight * 0.15, slopeHeight * 0.5)
        local slopeStart = random:getFloat(3.0, 5.0)

        local w = slopeWidth
        local hw = w * 0.5
        local h = slopeHeight
        local hh = h * 0.5
        local m1 = MatrixLookUp(vec3(1, 0, 0), vec3(0, 1, 0))
        local m2 = MatrixLookUp(vec3(-1, 0, 0), vec3(0, -1, 0))

        for p = slopeStart, 7, slopeDist * 2.0 do
            segment:addBlock(vec3(-hw * 0.5, p, 0), vec3(hw, hh, w), last, -1, slopeColor, iron, m1, edge, ColorNone())
            segment:addBlock(vec3(hw * 0.5, p + hh, 0), vec3(hw, hh, w), last, -1, slopeColor, iron, m1, edge, ColorNone())

            segment:addBlock(vec3(-hw * 0.5, p - hh, 0), vec3(hw, hh, w), last, -1, slopeColor, iron, m2, edge, ColorNone())
            segment:addBlock(vec3(hw * 0.5, p, 0), vec3(hw, hh, w), last, -1, slopeColor, iron, m2, edge, ColorNone())
        end
    end

    local arm = nil
    if secondaryArms then
        arm = copy(segment)
    end

    local size = vec3(2, 2, 2)
    local plan = BlockPlan()

    local root = plan:addBlock(vec3(0, 0, 0), vec3(20, 20, 0.1), -1, -1, bright, iron, orientation, BlockType.Portal, ColorNone())

    plan:addBlock(vec3(0, -10, 0), size, root, -1, bright, iron, orientation, block, ColorNone())
    plan:addBlock(vec3(0, 10, 0), size, root, -1, bright, iron, orientation, block, ColorNone())

    plan:addBlock(vec3(10, 0, 0), size, root, -1, bright, iron, orientation, block, ColorNone())
    plan:addBlock(vec3(-10, 0, 0), size, root, -1, bright, iron, orientation, block, ColorNone())

    -- default
    segment:displace(vec3(10, 0, 0))
    plan:addPlan(0, segment, 0)

    -- mirrored down
    segment:mirror(vec3(0, 1, 0), vec3(0, 0, 0))
    plan:addPlan(0, segment, 0)

    -- mirrored down other side
    segment:mirror(vec3(1, 0, 0), vec3(0, 0, 0))
    plan:addPlan(0, segment, 0)

    -- default other side
    segment:mirror(vec3(0, 1, 0), vec3(0, 0, 0))
    plan:addPlan(0, segment, 0)

    -- turned
    segment:rotate(vec3(0, 0, 1), 1)
    plan:addPlan(0, segment, 0)

    segment:mirror(vec3(1, 0, 0), vec3(0, 0, 0))
    plan:addPlan(0, segment, 0)

    segment:mirror(vec3(0, 1, 0), vec3(0, 0, 0))
    plan:addPlan(0, segment, 0)

    segment:mirror(vec3(1, 0, 0), vec3(0, 0, 0))
    plan:addPlan(0, segment, 0)

    if secondaryArms then
        if random:getFloat() < 0.5 then
            arm:rotate(vec3(0, 0, 1), 1)
            arm:displace(vec3(-10, 0, 0))
            plan:addPlan(0, arm, 0)

            arm:mirror(vec3(1, 0, 0), vec3(0, 0, 0))
            plan:addPlan(0, arm, 0)
        else
            arm:rotate(vec3(0, 0, 1), 1)
            arm:rotate(vec3(0, 1, 0), 1)

            arm:displace(vec3(-10, 0, 0))
            plan:addPlan(0, arm, 0)

            arm:mirror(vec3(1, 0, 0), vec3(0, 0, 0))
            plan:addPlan(0, arm, 0)

            if random:getFloat() < 0.5 then
                arm:mirror(vec3(0, 0, 1), vec3(0, 0, 0))
                plan:addPlan(0, arm, 0)

                arm:mirror(vec3(1, 0, 0), vec3(0, 0, 0))
                plan:addPlan(0, arm, 0)
            end

        end
    end

    local scale = 6
    plan:scale(vec3(scale, scale, scale))
    return plan
end

function PlanGenerator.makeBeaconPlan(colors)
    local container = PlanGenerator.makeContainerPlan(colors)

    container:scale(vec3(0.5, 0.5, 2))

    local maxZ = findMaxBlock(container, "z")
    local minZ = findMinBlock(container, "z")

    container:addBlock(maxZ.box.position + vec3(0, 0, maxZ.box.size.z), maxZ.box.size, maxZ.index, -1, maxZ.color, maxZ.material, MatrixLookUp(vec3(1, 0, 0), vec3(0, 0, 1)), BlockType.Light, ColorNone())
    container:addBlock(minZ.box.position - vec3(0, 0, minZ.box.size.z), minZ.box.size, minZ.index, -1, minZ.color, minZ.material, MatrixLookUp(vec3(1, 0, 0), vec3(0, 0, -1)), BlockType.Light, ColorNone())

    return container
end

function PlanGenerator.makeContainerPlan(colors)
    return PlanGenerator.makeGenericContainerPlan(colors, BlockType.CargoBay)
end

function PlanGenerator.makeCrewQuartersPlan(colors)
    return PlanGenerator.makeGenericContainerPlan(colors, BlockType.Quarters)
end

function PlanGenerator.makeGenericContainerPlan(colors_in, blockType)
    local plan = BlockPlan()

    -- create root block
    local root = plan:addBlock(vec3(0, 0, 0), vec3(2, 2, 2), -1, -1, ColorRGB(1, 1, 1), Material(), Matrix(), blockType, ColorNone())
    local glowAdded = false

    local brightColor = getFloat(0.75, 1);
    local darkColor = getFloat(0.2, 0.6);

    local colors = colors_in
    if colors == nil then
        colors = {}
        table.insert(colors, ColorRGB(brightColor, brightColor, brightColor))
        table.insert(colors, ColorRGB(darkColor, darkColor, darkColor))
        table.insert(colors, ColorRGB(math.random(), math.random(), math.random()))
    end

    local color
    local glowColor = ColorRGB(1, 1, 1)

    -- maybe add to front, back, top, bottom
    if math.random() < 0.5 then
        local size = math.random() * 1.5 + 0.5 -- 0.5 to 2.0

        color = colors[math.random(1, 3)]
        glowColor.hue = colors[3].hue
        glowColor.saturation = 0.5
        glowColor.value = 1

        local sideBlock1 = plan:addBlock(vec3(0, 1 + size / 2, 0), vec3(size, size, size), root, -1, color, Material(), Matrix(), blockType, ColorNone())
        local sideBlock2 = plan:addBlock(vec3(0, -(1 + size / 2), 0), vec3(size, size, size), root, -1, color, Material(), Matrix(), blockType, ColorNone())

        -- add glow strips
        if math.random() < 0.5 then
            -- add anchor blocks for the glow strips
            local newPos = plan:getBlock(sideBlock1).box.position
            newPos.y = newPos.y + (size / 2 + 0.1)
            local anchorBlock1 = plan:addBlock(newPos, vec3(size - 0.4, 0.2, size), sideBlock1, -1, color, Material(), Matrix(), blockType, ColorNone())

            local newPos = plan:getBlock(sideBlock2).box.position
            newPos.y = newPos.y - (size / 2 + 0.1)
            local anchorBlock2 = plan:addBlock(newPos, vec3(size - 0.4, 0.2, size), sideBlock2, -1, color, Material(), Matrix(), blockType, ColorNone())

            -- add glow strips
            local newPos = plan:getBlock(anchorBlock1).box.position
            newPos.x = newPos.x + (size / 2 - 0.1)
            plan:addBlock(newPos, vec3(0.2, 0.2, size), anchorBlock1, -1, glowColor, Material(), Matrix(), BlockType.Glow, ColorNone())

            local newPos = plan:getBlock(anchorBlock1).box.position
            newPos.x = newPos.x - (size / 2 - 0.1)
            plan:addBlock(newPos, vec3(0.2, 0.2, size), anchorBlock1, -1, glowColor, Material(), Matrix(), BlockType.Glow, ColorNone())

            -- add glow strips
            local newPos = plan:getBlock(anchorBlock2).box.position
            newPos.x = newPos.x + (size / 2 - 0.1)
            plan:addBlock(newPos, vec3(0.2, 0.2, size), anchorBlock2, -1, glowColor, Material(), Matrix(), BlockType.Glow, ColorNone())

            local newPos = plan:getBlock(anchorBlock2).box.position
            newPos.x = newPos.x - (size / 2 - 0.1)
            plan:addBlock(newPos, vec3(0.2, 0.2, size), anchorBlock2, -1, glowColor, Material(), Matrix(), BlockType.Glow, ColorNone())

            glowAdded = true
        end
    end

    if math.random() < 0.2 then
        local size = math.random() * 1.5 + 0.5 -- 0.5 to 2.0

        color = colors[math.random(1, 3)]

        plan:addBlock(vec3(1 + size / 2, 0, 0), vec3(size, size, size), root, -1, color, Material(), Matrix(), blockType, ColorNone())
        plan:addBlock(vec3(-(1 + size / 2), 0, 0), vec3(size, size, size), root, -1, color, Material(), Matrix(), blockType, ColorNone())
    end

    -- now add to the sides
    local blockPairs = {}
    local pairsCounter = 0
    local added = 0
    local maxAdded = math.random() * 2.5 + 1.5 -- 1.5 to 4.0

    while added < maxAdded do
        local thickness;
        local size = math.random() * 1.0 + 1.5 -- 1.5 to 2.5

        if math.random() < 0.3 then
            thickness = math.random() * 0.2 + 0.1 -- 0.1 to 0.3
        else
            thickness = math.random() * 1.5 + 0.5 -- 0.5 to 2.0
        end

        color = colors[math.random(1, 3)]
        glowColor.hue = colors[3].hue
        glowColor.saturation = 0.5
        glowColor.value = 1

        local a = plan:addBlock(vec3(0, 0, added + thickness / 2), vec3(size, size, thickness), root, -1, color, Material(), Matrix(), blockType, ColorNone())
        local b = plan:addBlock(vec3(0, 0, -(added + thickness / 2)), vec3(size, size, thickness), root, -1, color, Material(), Matrix(), blockType, ColorNone())

        if thickness > 1.0 then
            table.insert(blockPairs, {a = a, b = b})
        end

        added = added + thickness
        pairsCounter = pairsCounter + 1

        -- add glow corners
        if math.random() < 0.4 and added > maxAdded and glowAdded == false and pairsCounter < 6 then
            if #blockPairs > 0 then
                -- add the center pieces for the corners
                local centerA = plan:addBlock(vec3(0, 0, added + 0.1), vec3(size - 0.4, size - 0.4, 0.2), blockPairs[#blockPairs].a, -1, color, Material(), Matrix(), blockType, ColorNone())
                local centerB = plan:addBlock(vec3(0, 0, -(added + 0.1)), vec3(size - 0.4, size - 0.4, 0.2), blockPairs[#blockPairs].b, -1, color, Material(), Matrix(), blockType, ColorNone())

                -- add the side pieces
                local newPos = plan:getBlock(centerA).box.position
                newPos.y = newPos.y + (size/2 - 0.1)
                local topA = plan:addBlock(newPos, vec3(size - 0.4, 0.2, 0.2), centerA, -1, color, Material(), Matrix(), blockType, ColorNone())

                local newPos = plan:getBlock(centerA).box.position
                newPos.y = newPos.y - (size/2 - 0.1)
                local bottomA = plan:addBlock(newPos, vec3(size - 0.4, 0.2, 0.2), centerA, -1, color, Material(), Matrix(), blockType, ColorNone())

                local newPos = plan:getBlock(centerA).box.position
                newPos.x = newPos.x - (size/2 - 0.1)
                plan:addBlock(newPos, vec3(0.2, size - 0.4, 0.2), centerA, -1, color, Material(), Matrix(), blockType, ColorNone())

                local newPos = plan:getBlock(centerA).box.position
                newPos.x = newPos.x + (size/2 - 0.1)
                plan:addBlock(newPos, vec3(0.2, size - 0.4, 0.2), centerA, -1, color, Material(), Matrix(), blockType, ColorNone())

                local newPos = plan:getBlock(centerB).box.position
                newPos.y = newPos.y + (size/2 - 0.1)
                local topB = plan:addBlock(newPos, vec3(size - 0.4, 0.2, 0.2), centerB, -1, color, Material(), Matrix(), blockType, ColorNone())

                local newPos = plan:getBlock(centerB).box.position
                newPos.y = newPos.y - (size/2 - 0.1)
                local bottomB = plan:addBlock(newPos, vec3(size - 0.4, 0.2, 0.2), centerB, -1, color, Material(), Matrix(), blockType, ColorNone())

                local newPos = plan:getBlock(centerB).box.position
                newPos.x = newPos.x - (size/2 - 0.1)
                plan:addBlock(newPos, vec3(0.2, size - 0.4, 0.2), centerB, -1, color, Material(), Matrix(), blockType, ColorNone())

                local newPos = plan:getBlock(centerB).box.position
                newPos.x = newPos.x + (size/2 - 0.1)
                plan:addBlock(newPos, vec3(0.2, size - 0.4, 0.2), centerB, -1, color, Material(), Matrix(), blockType, ColorNone())

                -- add the glow corners
                local newPos = plan:getBlock(topA).box.position
                newPos.x = newPos.x + (size/2 - 0.1)
                plan:addBlock(newPos, vec3(0.2, 0.2, 0.2), topA, -1, glowColor, Material(), Matrix(), BlockType.Glow, ColorNone())

                local newPos = plan:getBlock(topA).box.position
                newPos.x = newPos.x - (size/2 - 0.1)
                plan:addBlock(newPos, vec3(0.2, 0.2, 0.2), topA, -1, glowColor, Material(), Matrix(), BlockType.Glow, ColorNone())

                local newPos = plan:getBlock(bottomA).box.position
                newPos.x = newPos.x + (size/2 - 0.1)
                plan:addBlock(newPos, vec3(0.2, 0.2, 0.2), bottomA, -1, glowColor, Material(), Matrix(), BlockType.Glow, ColorNone())

                local newPos = plan:getBlock(bottomA).box.position
                newPos.x = newPos.x - (size/2 - 0.1)
                plan:addBlock(newPos, vec3(0.2, 0.2, 0.2), bottomA, -1, glowColor, Material(), Matrix(), BlockType.Glow, ColorNone())

                local newPos = plan:getBlock(topB).box.position
                newPos.x = newPos.x + (size/2 - 0.1)
                plan:addBlock(newPos, vec3(0.2, 0.2, 0.2), topB, -1, glowColor, Material(), Matrix(), BlockType.Glow, ColorNone())

                local newPos = plan:getBlock(topB).box.position
                newPos.x = newPos.x - (size/2 - 0.1)
                plan:addBlock(newPos, vec3(0.2, 0.2, 0.2), topB, -1, glowColor, Material(), Matrix(), BlockType.Glow, ColorNone())

                local newPos = plan:getBlock(bottomB).box.position
                newPos.x = newPos.x + (size/2 - 0.1)
                plan:addBlock(newPos, vec3(0.2, 0.2, 0.2), bottomB, -1, glowColor, Material(), Matrix(), BlockType.Glow, ColorNone())

                local newPos = plan:getBlock(bottomB).box.position
                newPos.x = newPos.x - (size/2 - 0.1)
                plan:addBlock(newPos, vec3(0.2, 0.2, 0.2), bottomB, -1, glowColor, Material(), Matrix(), BlockType.Glow, ColorNone())

                glowAdded = true
            end
        end
    end

    for i, blocks in pairs(blockPairs) do
        if math.random() < 0.3 and glowAdded == false then
            -- add x blocks
            local newWidth = math.random() * 0.3 + 0.7 -- 0.7 to 1.0
            local newThick = math.random() * 0.2 + 0.1 -- 0.1 to 0.3
            local newSize = vec3(newThick, newWidth, newWidth)

            -- block a
            local size = plan:getBlock(blocks.a).box.size

            -- +x
            local newPos = plan:getBlock(blocks.a).box.position
            newPos.x = newPos.x + (size.x / 2 + newSize.x / 2)
            local sideBlock1 = plan:addBlock(newPos, newSize, blocks.a, -1, ColorRGB(1, 1, 1), Material(), Matrix(), blockType, ColorNone())

            -- -x
            local newPos = plan:getBlock(blocks.a).box.position
            newPos.x = newPos.x - (size.x / 2 + newSize.x / 2)
            local sideBlock2 = plan:addBlock(newPos, newSize, blocks.a, -1, ColorRGB(1, 1, 1), Material(), Matrix(), blockType, ColorNone())


            -- block b
            local size = plan:getBlock(blocks.b).box.size

            -- +x
            local newPos = plan:getBlock(blocks.b).box.position
            newPos.x = newPos.x + (size.x / 2 + newSize.x / 2)
            local sideBlock3 = plan:addBlock(newPos, newSize, blocks.b, -1, ColorRGB(1, 1, 1), Material(), Matrix(), blockType, ColorNone())

            -- -x
            local newPos = plan:getBlock(blocks.b).box.position
            newPos.x = newPos.x - (size.x / 2 + newSize.x / 2)
            local sideBlock4 = plan:addBlock(newPos, newSize, blocks.b, -1, ColorRGB(1, 1, 1), Material(), Matrix(), blockType, ColorNone())


            -- add small glow blocks
            if math.random() < 0.5 then
                local newPos = plan:getBlock(sideBlock1).box.position
                newPos.x = newPos.x + 0.1
                plan:addBlock(newPos, vec3(0.2, 0.2, 0.5), sideBlock1, -1, glowColor, Material(), Matrix(), BlockType.Glow, ColorNone())

                local newPos = plan:getBlock(sideBlock2).box.position
                newPos.x = newPos.x - 0.1
                plan:addBlock(newPos, vec3(0.2, 0.2, 0.5), sideBlock2, -1, glowColor, Material(), Matrix(), BlockType.Glow, ColorNone())

                local newPos = plan:getBlock(sideBlock3).box.position
                newPos.x = newPos.x + 0.1
                plan:addBlock(newPos, vec3(0.2, 0.2, 0.5), sideBlock3, -1, glowColor, Material(), Matrix(), BlockType.Glow, ColorNone())

                local newPos = plan:getBlock(sideBlock4).box.position
                newPos.x = newPos.x - 0.1
                plan:addBlock(newPos, vec3(0.2, 0.2, 0.5), sideBlock4, -1, glowColor, Material(), Matrix(), BlockType.Glow, ColorNone())
            end
        end

        if math.random() < 0.3 and glowAdded == false then
            -- add x blocks
            local newWidth = getFloat(0.7, 1.0) -- 0.7 to 1.0
            local newThick = getFloat(0.1, 0.5) -- 0.1 to 0.5
            local newSize = vec3(newWidth, newThick, newWidth)

            -- block a
            local size = plan:getBlock(blocks.a).box.size

            -- +y
            local newPos = plan:getBlock(blocks.a).box.position
            newPos.y = newPos.y + (size.y / 2 + newSize.y / 2)
            local sideBlock1 = plan:addBlock(newPos, newSize, blocks.a, -1, ColorRGB(1, 1, 1), Material(), Matrix(), blockType, ColorNone())

            -- -y
            local newPos = plan:getBlock(blocks.a).box.position
            newPos.y = newPos.y - (size.y / 2 + newSize.y / 2)
            local sideBlock2 = plan:addBlock(newPos, newSize, blocks.a, -1, ColorRGB(1, 1, 1), Material(), Matrix(), blockType, ColorNone())


            -- block b
            local size = plan:getBlock(blocks.b).box.size

            -- +y
            local newPos = plan:getBlock(blocks.b).box.position
            newPos.y = newPos.y + (size.y / 2 + newSize.y / 2)
            local sideBlock3 = plan:addBlock(newPos, newSize, blocks.b, -1, ColorRGB(1, 1, 1), Material(), Matrix(), blockType, ColorNone())

            -- -y
            local newPos = plan:getBlock(blocks.b).box.position
            newPos.y = newPos.y - (size.y / 2 + newSize.y / 2)
            local sideBlock4 = plan:addBlock(newPos, newSize, blocks.b, -1, ColorRGB(1, 1, 1), Material(), Matrix(), blockType, ColorNone())


            -- add small glow blocks
            if math.random() < 0.5 then
                local newPos = plan:getBlock(sideBlock1).box.position
                newPos.y = newPos.y + 0.1
                plan:addBlock(newPos, vec3(0.2, 0.2, 0.5), sideBlock1, -1, glowColor, Material(), Matrix(), BlockType.Glow, ColorNone())

                local newPos = plan:getBlock(sideBlock2).box.position
                newPos.y = newPos.y - 0.1
                plan:addBlock(newPos, vec3(0.2, 0.2, 0.5), sideBlock2, -1, glowColor, Material(), Matrix(), BlockType.Glow, ColorNone())

                local newPos = plan:getBlock(sideBlock3).box.position
                newPos.y = newPos.y + 0.1
                plan:addBlock(newPos, vec3(0.2, 0.2, 0.5), sideBlock3, -1, glowColor, Material(), Matrix(), BlockType.Glow, ColorNone())

                local newPos = plan:getBlock(sideBlock4).box.position
                newPos.y = newPos.y - 0.1
                plan:addBlock(newPos, vec3(0.2, 0.2, 0.5), sideBlock4, -1, glowColor, Material(), Matrix(), BlockType.Glow, ColorNone())
            end
        end
    end

    local scale = getFloat(0.8, 1.3)
    plan:scale(vec3(scale, scale, scale))

    return plan
end


return PlanGenerator
