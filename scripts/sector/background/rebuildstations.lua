
package.path = package.path .. ";data/scripts/lib/?.lua;data/scripts/?.lua"

include("randomext")
local SectorSpecifics = include("sectorspecifics")
local FactionEradicationUtility = include("factioneradicationutility")
local SectorGenerator = include("SectorGenerator")
local FactoryPredictor = include("factorypredictor")
local Placer = include("placer")
local ConsumerGoods = include("consumergoods")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace RebuildStations
RebuildStations = {}

RebuildStations.updateTimer = 0
RebuildStations.specsInitialized = false
RebuildStations.specsFactionIndex = nil
RebuildStations.specsStations = {}
RebuildStations.missing = {}

if onServer() then

function RebuildStations.secure()
    return
    {
        updateTimer = RebuildStations.updateTimer,
        specsInitialized = RebuildStations.specsInitialized,
        specsFactionIndex = RebuildStations.specsFactionIndex,
        specsStations = RebuildStations.specsStations,
        missing = RebuildStations.missing
    }
end

function RebuildStations.restore(data)
    RebuildStations.updateTimer = data.updateTimer
    RebuildStations.specsInitialized = data.specsInitialized
    RebuildStations.specsFactionIndex = data.specsFactionIndex
    RebuildStations.specsStations = data.specsStations or {}
    RebuildStations.missing = data.missing or {}
end

function RebuildStations.onRestoredFromDisk(time)
    RebuildStations.updateServer(time)
end

function RebuildStations.getUpdateInterval()
    return 60
end

function RebuildStations.initialize()
    if onServer() then
        Sector():registerCallback("onRestoredFromDisk", "onRestoredFromDisk")
    end
end

function RebuildStations.updateServer(timeStep)
    local sector = Sector()

    if not RebuildStations.specsInitialized then
        RebuildStations.initializeSpecs(sector:getCoordinates())
        RebuildStations.specsInitialized = true
    end

    RebuildStations.updateTimer = RebuildStations.updateTimer + timeStep
    if RebuildStations.updateTimer < 10 * 60 then return end

    RebuildStations.updateTimer = 0

    if not random():test(0.2) and not RebuildStations.isUnitTestActive then
        return
    end

    if not RebuildStations.specsFactionIndex then
--        print("faction index is nil")
        return
    end

    -- gather data
    local currentContents = RebuildStations.getCurrentContents()

    -- update
    RebuildStations.updateConstruction(currentContents)
end

function RebuildStations.getCurrentContents()
--    print("get current contents")

    local scripts =
    {
        {name = "biotopes",               path = "data/scripts/entity/merchants/biotope.lua"},
        {name = "casinos",                path = "data/scripts/entity/merchants/casino.lua"},
        {name = "equipmentDocks",         path = "data/scripts/entity/merchants/equipmentdock.lua"},
        -- mines are special factories
        {name = "factories",              path = "data/scripts/entity/merchants/factory.lua", doMineCheck = true},
        {name = "fighterFactories",       path = "data/scripts/entity/merchants/fighterfactory.lua"},
        {name = "habitats",               path = "data/scripts/entity/merchants/habitat.lua"},
        {name = "headquarters",           path = "data/scripts/entity/merchants/headquarters.lua"},
        {name = "militaryOutposts",       path = "data/scripts/entity/merchants/militaryoutpost.lua"},
        {name = "planetaryTradingPosts",  path = "data/scripts/entity/merchants/planetarytradingpost.lua"},
        {name = "researchStations",       path = "data/scripts/entity/merchants/researchstation.lua"},
        {name = "resourceDepots",         path = "data/scripts/entity/merchants/resourcetrader.lua"},
        {name = "scrapyards",             path = "data/scripts/entity/merchants/scrapyard.lua"},
        -- shipyards must come before repairDocks
        {name = "shipyards",              path = "data/scripts/entity/merchants/shipyard.lua"},
        {name = "repairDocks",            path = "data/scripts/entity/merchants/repairdock.lua"},
        {name = "smugglersMarkets",       path = "data/scripts/entity/merchants/smugglersmarket.lua"},
        {name = "tradingPosts",           path = "data/scripts/entity/merchants/tradingpost.lua"},
        {name = "turretFactories",        path = "data/scripts/entity/merchants/turretfactory.lua"},
        {name = "turretFactorySuppliers", path = "data/scripts/entity/merchants/turretfactorysupplier.lua"},
        {name = "travelHubs",             path = "data/scripts/entity/merchants/travelhub.lua"},
        {name = "riftResearchCenters",    path = "internal/dlc/rift/entity/riftresearchcenter.lua"},
    }

    local sector = Sector()
    local x, y = sector:getCoordinates()

    local data = {}
    data.stations = {}

    local stations = {sector:getEntitiesByType(EntityType.Station)}
    for _, station in pairs(stations) do
        if not station.aiOwned then goto continue end

        for _, script in pairs(scripts) do
            if station:hasScript(script.path) then
                local key = script.name

                if script.doMineCheck then
                    if station:getValue("factory_type") == "mine" then
                        key = "mines"
                    end
                end

                local factionStations = data.stations[station.factionIndex] or {}
                factionStations[key] = (factionStations[key] or 0) + 1
                data.stations[station.factionIndex] = factionStations
                break
            end
        end

        ::continue::
    end

    -- get controlling faction
    local view = Galaxy():getSectorView(x, y)
    if view then
        data.factionIndex = view.factionIndex
    end

    return data
end

function RebuildStations.updateConstruction(currentContent)
    local sector = Sector()
    local x, y = sector:getCoordinates()
    if not currentContent or not currentContent.stations then
--        print("content hasn't been gathered yet or is incomplete.")
        return
    end

    -- check the sector is still controlled by the original faction
    if currentContent.factionIndex and currentContent.factionIndex ~= RebuildStations.specsFactionIndex then
--        print("sector is now controlled by a different faction")
        return
    end

    if FactionEradicationUtility.isFactionEradicated(RebuildStations.specsFactionIndex) then
        return
    end

    local faction = Faction(RebuildStations.specsFactionIndex)
    if faction then
        local now = Server().unpausedRuntime
        local last = faction:getValue("rebuild_stations_timestamp")
        if last and now - last < 30 * 60 and not RebuildStations.isUnitTestActive then
            return
        end

        faction:setValue("rebuild_stations_timestamp", now)
    end

    if RebuildStations.factionHasConstructionSites() then
--        print("construction site found")
        RebuildStations.missing = {}
        return
    end

    local missing = RebuildStations.getMissingStations(currentContent.stations[RebuildStations.specsFactionIndex])
--    print("missing: " .. tablelength(missing) .. " entries for faction " .. tostring(RebuildStations.specsFactionIndex))
--    printTable(missing)

    -- update missing stations
    for type, amount in pairs(missing) do
        local missingStation = RebuildStations.missing[type] or {}

        -- increment counter of stations that were already missing last tick
        missingStation.counter = (missingStation.counter or 0) + 1
        missingStation.updated = true
        missingStation.amount = amount

        RebuildStations.missing[type] = missingStation
    end

    local constructionStarted = false
    for type, missingStation in pairs(RebuildStations.missing) do
        if not missingStation.updated then
            -- remove stations that were missing last tick, but not current tick
            RebuildStations.missing[type] = nil
            goto continue
        end

        if not constructionStarted and missingStation.counter >= 2 then
            if faction then
                -- don't spawn construction sites in a war zone, except in home sector
                local homeX, homeY = faction:getHomeSectorCoordinates()
                if sector:getValue("war_zone") == true and (x ~= homeX or y ~= homeY) then
--                    print("no construction sites in a war zone")

                else
                    constructionStarted = true

                    RebuildStations.spawnConstructionSite(faction, type)

                    RebuildStations.missing[type] = nil
                    goto continue
                end
            else
--                print("no construction capacity left")
            end
        end

        missingStation.updated = nil

        ::continue::
    end
end

function RebuildStations.initializeSpecs(x, y)
    local specs = SectorSpecifics(x, y, GameSeed())

    if not specs.regular then return end

    RebuildStations.specsFactionIndex = specs.factionIndex
    if specs.factionIndex and specs.generationTemplate then
        local initialContents = specs.generationTemplate.contents(x, y)
        RebuildStations.gatherLocalFactionStations(initialContents, specs.generationTemplate.path)
    end
end

function RebuildStations.gatherLocalFactionStations(initialContents, templatePath)
    local stations = {}
    stations.biotopes               = (initialContents.biotopes               or 0)
    stations.casinos                = (initialContents.casinos                or 0)
    stations.equipmentDocks         = (initialContents.equipmentDocks         or 0)
    stations.factories              = (initialContents.factories              or 0)
    stations.fighterFactories       = (initialContents.fighterFactories       or 0)
    stations.habitats               = (initialContents.habitats               or 0)
    stations.headquarters           = (initialContents.headquarters           or 0)
    stations.militaryOutposts       = (initialContents.militaryOutposts       or 0)
    stations.mines                  = (initialContents.mines                  or 0)
    stations.planetaryTradingPosts  = (initialContents.planetaryTradingPosts  or 0)
    stations.repairDocks            = (initialContents.repairDocks            or 0)
    stations.researchStations       = (initialContents.researchStations       or 0)
    stations.resourceDepots         = (initialContents.resourceDepots         or 0)
    stations.scrapyards             = (initialContents.scrapyards             or 0)
    stations.smugglersMarkets       = (initialContents.smugglersMarkets       or 0)
    stations.tradingPosts           = (initialContents.tradingPosts           or 0)
    stations.turretFactories        = (initialContents.turretFactories        or 0)
    stations.turretFactorySuppliers = (initialContents.turretFactorySuppliers or 0)
    stations.travelHubs             = (initialContents.travelHubs             or 0)
    stations.riftResearchCenters    = (initialContents.riftResearchCenters    or 0)

    -- don't add neighbor trading posts, only stations that belong to the original local faction are counted here

    -- don't add shipyards generated in piratestation sectors, they belong to pirates
    -- this is not actually required because pirate sectors are offgrid
    -- added for the sake of completeness
    if templatePath ~= "sectors/piratestation" then
        stations.shipyards = (initialContents.shipyards or 0)
    end

    RebuildStations.specsStations = stations
end

function RebuildStations.getMissingStations(contents)
    local missing = {}
    contents = contents or {}

--    print("specs:")
--    printTable(RebuildStations.specsStations)
--    print("contents:")
--    printTable(contents)

    missing.biotopes               = math.max(0, (RebuildStations.specsStations.biotopes or 0)               - (contents.biotopes               or 0))
    missing.casinos                = math.max(0, (RebuildStations.specsStations.casinos or 0)                - (contents.casinos                or 0))
    missing.equipmentDocks         = math.max(0, (RebuildStations.specsStations.equipmentDocks or 0)         - (contents.equipmentDocks         or 0))
    missing.factories              = math.max(0, (RebuildStations.specsStations.factories or 0)              - (contents.factories              or 0))
    missing.fighterFactories       = math.max(0, (RebuildStations.specsStations.fighterFactories or 0)       - (contents.fighterFactories       or 0))
    missing.habitats               = math.max(0, (RebuildStations.specsStations.habitats or 0)               - (contents.habitats               or 0))
    missing.headquarters           = math.max(0, (RebuildStations.specsStations.headquarters or 0)           - (contents.headquarters           or 0))
    missing.militaryOutposts       = math.max(0, (RebuildStations.specsStations.militaryOutposts or 0)       - (contents.militaryOutposts       or 0))
    missing.mines                  = math.max(0, (RebuildStations.specsStations.mines or 0)                  - (contents.mines                  or 0))
    missing.planetaryTradingPosts  = math.max(0, (RebuildStations.specsStations.planetaryTradingPosts or 0)  - (contents.planetaryTradingPosts  or 0))
    missing.repairDocks            = math.max(0, (RebuildStations.specsStations.repairDocks or 0)            - (contents.repairDocks            or 0))
    missing.researchStations       = math.max(0, (RebuildStations.specsStations.researchStations or 0)       - (contents.researchStations       or 0))
    missing.resourceDepots         = math.max(0, (RebuildStations.specsStations.resourceDepots or 0)         - (contents.resourceDepots         or 0))
    missing.scrapyards             = math.max(0, (RebuildStations.specsStations.scrapyards or 0)             - (contents.scrapyards             or 0))
    missing.smugglersMarkets       = math.max(0, (RebuildStations.specsStations.smugglersMarkets or 0)       - (contents.smugglersMarkets       or 0))
    missing.tradingPosts           = math.max(0, (RebuildStations.specsStations.tradingPosts or 0)           - (contents.tradingPosts           or 0))
    missing.turretFactories        = math.max(0, (RebuildStations.specsStations.turretFactories or 0)        - (contents.turretFactories        or 0))
    missing.turretFactorySuppliers = math.max(0, (RebuildStations.specsStations.turretFactorySuppliers or 0) - (contents.turretFactorySuppliers or 0))
    missing.shipyards              = math.max(0, (RebuildStations.specsStations.shipyards or 0)              - (contents.shipyards              or 0))
    missing.travelHubs             = math.max(0, (RebuildStations.specsStations.travelHubs or 0)             - (contents.travelHubs             or 0))
    missing.riftResearchCenters    = math.max(0, (RebuildStations.specsStations.riftResearchCenters or 0)    - (contents.riftResearchCenters    or 0))

    -- clear empty entries
    for field, amount in pairs(missing) do
        if amount <= 0 then
            missing[field] = nil
        end
    end

    return missing
end

function RebuildStations.factionHasConstructionSites()
    for _, entity in pairs({Sector():getEntitiesByScript("data/scripts/entity/constructionsite.lua")}) do
        if entity.factionIndex == RebuildStations.specsFactionIndex then
            return true
        end
    end

    return false
end

function RebuildStations.spawnConstructionSite(faction, type)
--    print("build station: " .. type)

    local x, y = Sector():getCoordinates()
    local scripts

    if type == "biotopes" then
        scripts = {{script = "data/scripts/entity/merchants/biotope.lua"}}
    elseif type == "casinos" then
        scripts = {{script = "data/scripts/entity/merchants/casino.lua"}}
    elseif type == "equipmentDocks" then
        scripts = {
            {script = "data/scripts/entity/merchants/equipmentdock.lua"},
            {script = "data/scripts/entity/merchants/turretmerchant.lua"},
            {script = "data/scripts/entity/merchants/fightermerchant.lua"},
            {script = "data/scripts/entity/merchants/utilitymerchant.lua"},
            {script = "data/scripts/entity/merchants/consumer.lua", args = {"Equipment Dock"%_t, unpack(ConsumerGoods.EquipmentDock())}},
            {script = "data/scripts/entity/addarmedturrets.lua"}
        }

        if x * x + y * y < 380 * 380 then
            table.insert(scripts, {script = "data/scripts/entity/merchants/torpedomerchant.lua"})
        end
    elseif type == "factories" then
        local productions = FactoryPredictor.generateFactoryProductions(x, y, RebuildStations.specsStations.factories, false)
        scripts = {{script = "data/scripts/entity/merchants/factory.lua", args = {productions[random():getInt(1, #productions)]}}}
    elseif type == "fighterFactories" then
        scripts = {
            {script = "data/scripts/entity/merchants/fighterfactory.lua"},
            {script = "data/scripts/entity/merchants/fightermerchant.lua"}
        }
    elseif type == "habitats" then
        scripts = {{script = "data/scripts/entity/merchants/habitat.lua"}}
    elseif type == "headquarters" then
        scripts = {
            {script = "data/scripts/entity/merchants/headquarters.lua"},
            {script = "data/scripts/entity/addarmedturrets.lua"}
        }
    elseif type == "militaryOutposts" then
        scripts = {
            {script = "data/scripts/entity/merchants/militaryoutpost.lua"},
            {script = "data/scripts/entity/merchants/consumer.lua", args = {"Military Outpost"%_t, unpack(ConsumerGoods.MilitaryOutpost())}},
            {script = "data/scripts/entity/addarmedturrets.lua"}
        }
    elseif type == "mines" then
        local productions = FactoryPredictor.generateMineProductions(x, y, RebuildStations.specsStations.mines)
        scripts = {{script = "data/scripts/entity/merchants/factory.lua", args = {productions[random():getInt(1, #productions)]}}}
    elseif type == "planetaryTradingPosts" then
        local specs = SectorSpecifics(x, y, GameSeed())
        local planets = {specs:generatePlanets()}
        scripts = {{script = "data/scripts/entity/merchants/planetarytradingpost.lua", planets[1]}}
    elseif type == "repairDocks" then
        scripts = {
            {script = "data/scripts/entity/merchants/repairdock.lua"},
            {script = "data/scripts/entity/merchants/consumer.lua", args = {"Repair Dock"%_t, unpack(ConsumerGoods.RepairDock())}},
        }
    elseif type == "researchStations" then
        scripts = {
            {script = "data/scripts/entity/merchants/researchstation.lua"},
            {script = "data/scripts/entity/merchants/consumer.lua", args = {"Research Station"%_t, unpack(ConsumerGoods.ResearchStation())}},
        }
    elseif type == "travelHubs" then
        scripts = {
            {script = "data/scripts/entity/merchants/travelhub.lua"},
            {script = "data/scripts/entity/merchants/consumer.lua", args = {"Travel Hub"%_t, unpack(ConsumerGoods.TravelHub())}},
        }
    elseif type == "resourceDepots" then
        scripts = {{script = "data/scripts/entity/merchants/resourcetrader.lua"}}
    elseif type == "scrapyards" then
        scripts = {{script = "data/scripts/entity/merchants/scrapyard.lua"}}
    elseif type == "smugglersMarkets" then
        scripts = {
            {script = "data/scripts/entity/merchants/smugglersmarket.lua"},
            {script = "data/scripts/entity/merchants/tradingpost.lua"}}
    elseif type == "tradingPosts" then
        scripts = {{script = "data/scripts/entity/merchants/tradingpost.lua"}}
    elseif type == "turretFactories" then
        scripts = {
            {script = "data/scripts/entity/merchants/turretfactory.lua"},
            {script = "data/scripts/entity/merchants/turretfactoryseller.lua", args = {"Turret Factory"%_t, unpack(ConsumerGoods.TurretFactory())}}
        }
    elseif type == "turretFactorySuppliers" then
        scripts = {{script = "data/scripts/entity/merchants/turretfactorysupplier.lua"}}
    elseif type == "shipyards" then
        scripts = {
            {script = "data/scripts/entity/merchants/shipyard.lua"},
            {script = "data/scripts/entity/merchants/repairdock.lua"},
            {script = "data/scripts/entity/merchants/consumer.lua", args = {"Shipyard"%_t, unpack(ConsumerGoods.Shipyard())}},
        }
    end

    if not scripts then return end

    local generator = SectorGenerator(Sector():getCoordinates())
    generator:createStationConstructionSite(faction, scripts)
    Placer.resolveIntersections()
end

end
