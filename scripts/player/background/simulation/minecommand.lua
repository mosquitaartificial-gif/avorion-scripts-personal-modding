package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/player/background/simulation/?.lua"

local CommandType = include ("commandtype")
local GalaxyBalancing = include ("galaxy")
local SimulationUtility = include ("simulationutility")
local CaptainUtility = include ("captainutility")
local SectorSpecifics = include ("sectorspecifics")

include ("utility")
include ("stringutility")
include ("randomext")
include ("goods")


local MineCommand = {}
MineCommand.__index = MineCommand
MineCommand.type = CommandType.Mine

local function new(ship, area, config)
    local command = setmetatable({
        -- all commands need these variables to function within the bg simulation framework
        -- type contains the CommandType of the command, required to restore
        type = CommandType.Mine,

        -- the ship that has the command
        shipName = ship,

        -- the area where the ship is doing its thing
        area = area,

        -- config that was given to the ship
        config = config,

        -- holds any data necessary to fulfill the command, that should be saved to database, eg. timers and so on
        -- this should only contain variables that can be saved to database (eg. returned in a secure()) call
        -- this will be automatically restored/secured
        data = {},

        -- will be set from external, only listed here for completeness' sake
        simulation = nil,
    }, MineCommand)

    command.data.runTime = 0
    command.data.yieldCounter = 0

    return command
end

-- all commands have the following functions, even if not listed here (added by Simulation script on command creation):
-- function MineCommand:addYield(message, money, resources, items) end
-- function MineCommand:finish() end
-- function MineCommand:registerForAttack(coords, faction, timeOfAttack, message, arguments) end


function MineCommand:initialize()
    local parent = getParentFaction()
    local prediction = self:calculatePrediction(parent.index, self.shipName, self.area, self.config)
    self.data.prediction = prediction

    if prediction.error then
        return prediction.error, prediction.errorArgs
    end

    -- double-check that the configured duration is valid
    local configValues = self:getConfigurableValues(parent.index, self.shipName)
    self.config.duration = math.max(configValues.duration.from, math.min(configValues.duration.to, self.config.duration))

    self.data.yieldTime = 30 * 60
    if self.config.duration <= 1 then
        self.data.yieldTime = 15 * 60
    end

    -- calculate the amount of resources the command will yield
    local numYields = round(self.config.duration / (self.data.yieldTime / 3600))

    -- the first regular yields will give 75% of the final yield
    local smallWeight = 0.75
    local bigWeight = 1
    local weightSum = bigWeight + (numYields - 1) * smallWeight

    local smallFactor = smallWeight / weightSum
    local bigFactor = bigWeight / weightSum

    self.data.smallYield = {} -- the yield amount that is yielded every X time
    self.data.bigYield = {} -- the yield amount that is yielded at the end

    for i, yield in pairs(prediction.yields) do
        local amount = random():getFloat(yield.from, yield.to)

        -- round small/regular yields to hundreds, looks more realistic than an arbitrary number that's always the same
        self.data.smallYield[i] = round(amount * smallFactor / 10) * 10

        -- for the last big yield, that's not necessary
        self.data.bigYield[i] = amount * bigFactor
    end
end

function MineCommand:onStart()   
    -- set position from which ship is going to start
    local parent = getParentFaction()
    local entry = ShipDatabaseEntry(parent.index, self.shipName)
    local startX, startY = entry:getCoordinates()
    self.data.startCoordinates = { x = startX, y = startY }

    if self.data.prediction.attackLocation and not self.simulation.disableAttack then
        local time = random():getFloat(0.1, 0.75) * self.config.duration * 3600
        local location = self.data.prediction.attackLocation
        local x, y = location.x, location.y

        self:registerForAttack({x = x, y = y}, location.faction, time, "Your ship '%1%' is under attack in sector \\s(%2%:%3%)!"%_T, {self.shipName, x, y})
    end
end

function MineCommand:update(timeStep)
    self.data.runTime = self.data.runTime + timeStep
    self.data.yieldCounter = self.data.yieldCounter + timeStep

    if self.data.runTime >= self.config.duration * 3600 then
        self:finish()
        return
    end

    if self.data.yieldCounter >= self.data.yieldTime then
        -- add a variation of +0% to +2%
        local yield = table.deepcopy(self.data.smallYield)
        for i, amount in pairs(yield) do
            yield[i] = amount + amount * random():getFloat(0, 0.02)
        end

        self.data.yieldCounter = 0

        -- if this is the first yield, then yield all the ores that are already on the ship
        if self.data.runTime < self.data.yieldTime * 2 then
            local parent = getParentFaction()
            local entry = ShipDatabaseEntry(parent.index, self.shipName)
            local cargo, cargoBaySize = entry:getCargo()
            for good, amount in pairs(cargo) do
                local tags = good.tags
                local material = nil
                if tags.iron then
                    material = 1
                elseif tags.titanium then
                    material = 2
                elseif tags.naonite then
                    material = 3
                elseif tags.trinium then
                    material = 4
                elseif tags.xanion then
                    material = 5
                elseif tags.ogonite then
                    material = 6
                elseif tags.avorion then
                    material = 7
                end

                if material then
                    cargo[good] = nil

                    if tags.rich then
                        yield[material] = yield[material] + amount * 4
                    else
                        yield[material] = yield[material] + amount
                    end
                end
            end

            entry:setCargo(cargo)
        end

        local lines = {}
        table.insert(lines, "Commander, here's one installment of our yield!"%_t)
        table.insert(lines, "Commander, here's one shipment of our yield!"%_t)
        self:sendYield(randomEntry(lines), 0, yield)
    end

end

function MineCommand:sendYield(line, money, resources)
    if self.config.immediateDelivery then
        local parent = getParentFaction()
        parent:receive(line, money, unpack(resources))
    else
        self:addYield(line, money, resources)
    end
end

function MineCommand:onAreaAnalysisStart(results, meta)
    -- calculate material probabilities for both normal and safe mode
    results.materials = {}
    results.safeMaterials = {}
    for i = 1, NumMaterials() do
        results.materials[i] = 0
        results.safeMaterials[i] = 0
    end

    results.safeSectors = {}
    results.asteroids = 0
    results.safeAsteroids = 0

    -- use this as a cache for relation status to a specific faction
    -- this is so that we don't have to access the Player all the time which can be costly
    meta.statuses = {}
end

function MineCommand:onAreaAnalysisSector(results, meta, x, y, details)
    local probabilities = GalaxyBalancing.GetMaterialProbability(x, y)
    for i, probability in pairs(probabilities) do
        results.materials[i+1] = results.materials[i+1] + probability
    end

    -- find out if the sector is dangerous and only calculate the materials if it isn't
    local factionIndex = details.faction
    local dangerous = (factionIndex == 0) -- it's dangerous if it's no-man's-space

    if not dangerous then
        -- it's dangerous if it's controlled by a faction we're at war with
        local status = meta.statuses[factionIndex]
        if status == nil then
            status = meta.faction:getRelationStatus(factionIndex)
            meta.statuses[factionIndex] = status
        end

        dangerous = (status == RelationStatus.War)
    end

    local view = meta.faction:getKnownSector(x, y)
    if view then
        local asteroids = (view.numAsteroids or 0)
        local mineable = asteroids * 0.05 * GameSettings().resourceAsteroidFactor -- approx. this many asteroids are mineable per field

        if factionIndex ~= 0 then
            if details.isCentralArea then
                mineable = mineable * 0.2 -- in central area, 20% of asteroids are mineable
            else
                mineable = mineable * 0.5 -- in non-central area, 50% of asteroids are mineable
            end
        end

        results.asteroids = results.asteroids + mineable

        if not dangerous then
            results.safeAsteroids = results.safeAsteroids + mineable
        end
    end

    -- if it's not dangerous, it qualifies for safe mode materials
    if not dangerous then
        for i, probability in pairs(probabilities) do
            results.safeMaterials[i+1] = results.safeMaterials[i+1] + probability
        end

        table.insert(results.safeSectors, #results.reachableCoordinates)
    end
end

function MineCommand:onAreaAnalysisFinished(results, meta)
    for i = 1, NumMaterials() do
        if results.reachable > 0 then
            results.materials[i] = results.materials[i] / results.reachable
        end

        if #results.safeSectors > 0 then
            results.safeMaterials[i] = results.safeMaterials[i] / #results.safeSectors
        end
    end
end

function MineCommand:onRecall()
    local parent = getParentFaction()
    local entry = ShipDatabaseEntry(parent.index, self.shipName)

    -- at least 35% of the time to the yield must have passed,
    -- so you can't send a ship off and recall it immediately and gain resources
    local minimumRequiredTimePassed = 0.35 -- percent
    local minResourcesGained = 0.2 -- percent
    local maxResourcesGained = 0.95 -- percent

    if self.data.yieldCounter > self.data.yieldTime * minimumRequiredTimePassed then

        -- add an intermediate yield
        local yield = {}
        for i, amount in pairs(self.data.smallYield) do
            yield[i] = lerp(self.data.yieldCounter, self.data.yieldTime * minimumRequiredTimePassed, self.data.yieldTime, amount * minResourcesGained, amount * maxResourcesGained)
        end

        -- restore ship with ores on board if r-mining was active
        if self.data.prediction.properties.rawMining then
            local properties = self.data.prediction.properties
            local cargo, cargoBaySize = entry:getCargo()
            local occupied = 0

            -- check how much room there is in the cargo bay
            for good, amount in pairs(cargo) do
                occupied = occupied + good.size * amount
            end

            -- calculate the composition of the ores based on what we're collecting
            local total = 0
            local rawYield = {}

            for i, amount in pairs(yield) do
                local ores = amount * properties.materials[i].rawEfficiencyWeight
                rawYield[i] = ores
                yield[i] = amount - ores

                total = total + ores
            end

            -- maximum amount of ores that can be added (max: half of free cargo bay)
            -- ensure that there is not more ore than should be able to be added
            local maxOres = (cargoBaySize - occupied) / 2 / goods["Iron Ore"].size -- all ores have the same size, doesn't matter which one we choose here
            if total > 0 and total > maxOres then
                local shrink = maxOres / total
                for i, amount in pairs(rawYield) do
                    rawYield[i] = amount * shrink
                end
            end

            -- add the raw portion to the cargo bay
            for i, amount in pairs(rawYield) do
                local good

                if i == 1 then good = goods["Iron Ore"]:good()
                elseif i == 2 then good = goods["Titanium Ore"]:good()
                elseif i == 3 then good = goods["Naonite Ore"]:good()
                elseif i == 4 then good = goods["Trinium Ore"]:good()
                elseif i == 5 then good = goods["Xanion Ore"]:good()
                elseif i == 6 then good = goods["Ogonite Ore"]:good()
                elseif i == 7 then good = goods["Avorion Ore"]:good()
                end

                if good and amount > 0 then
                    cargo[good] = amount
                end
            end

            entry:setCargo(cargo)
        end

        -- add the refined portion as a normal yield
        -- explicitly use "addYield" and not "sendYield" because the message contains important info
        self:addYield("Commander, unfortunately we could not complete the operation. Here is what we have mined so far!"%_t, 0, yield)
    end

end

function MineCommand:onAttacked()

end

function MineCommand:onFinish()    
    local faction = getParentFaction()
    local entry = ShipDatabaseEntry(faction.index, self.shipName)
    local captain = entry:getCaptain()

    if captain:hasClass(CaptainUtility.ClassType.Explorer) then
        self:onExplorerFinish(captain)
    end

    local lines = {}
    table.insert(lines, "Mission completed, Commander, here is the final yield."%_t)
    table.insert(lines, "Commander, this is the last shipment!"%_t)
    self:sendYield(randomEntry(lines), 0, self.data.bigYield)

    -- restore starting position of mine command
    if self.data.startCoordinates then
        local startX = self.data.startCoordinates.x
        local startY = self.data.startCoordinates.y
        entry:setCoordinates(startX, startY)
    end

    -- return message
    local x, y = entry:getCoordinates()
    faction:sendChatMessage(self.shipName, ChatMessageType.Information, "%1% has finished mining and is awaiting your next orders in \\s(%2%:%3%)."%_T, self.shipName, x, y)
end

function MineCommand:isRevealableAsteroidField(script)
    if script == "sectors/asteroidfield" then return true end
    if script == "sectors/asteroidfieldminer" then return true end
    if script == "sectors/pirateasteroidfield" then return true end
    if script == "sectors/defenderasteroidfield" then return true end
    if script == "sectors/smallasteroidfield" then return true end
    if script == "sectors/wreckageasteroidfield" then return true end
end

function MineCommand:onExplorerFinish(captain)

    local faction = getParentFaction()
    local specs = SectorSpecifics()
    local seed = Server().seed

    local notes = {}
    table.insert(notes, "Commander, there's an asteroid field in this sector.\n\nRegards, Captain ${name}"%_T)
    table.insert(notes, "Commander, we discovered an asteroid field here.\n\nRegards, Captain ${name}"%_T)
    table.insert(notes, "Asteroid field here.\n\nRegards, Captain ${name}"%_T)
    table.insert(notes, "This sector contains an asteroid field.\n\nRegards, Captain ${name}"%_T)

    local revealed = 0

    for _, coords in pairs(self.area.analysis.reachableCoordinates) do
        local x, y = coords.x, coords.y
        local regular, offgrid = specs.determineFastContent(x, y, seed)

        -- regular and offgrid can be changed into each other depending on central region or no man's space
        if offgrid or regular then

            local regular, offgrid, blocked, home = specs:determineContent(x, y, seed)
            if not blocked and offgrid then

                local view = faction:getKnownSector(x, y)
                if not view then

                    specs:initialize(x, y, seed)
                    if self:isRevealableAsteroidField(specs:getScript()) then

                        view = SectorView()
                        view:setCoordinates(x, y)
                        view.note = NamedFormat(randomEntry(notes), {name = captain.name})
                        -- make sure that no new icons are created
                        if view.tagIconPath == "" then view.tagIconPath = "data/textures/icons/nothing.png" end

                        faction:addKnownSector(view)

                        revealed = revealed + 1
                        if revealed >= 3 then break end
                    end
                end
            end
        end
    end

end

function MineCommand:onSecure()

end

function MineCommand:onRestore()
    self.data.yieldTime = self.data.yieldTime or 30 * 60
end

function MineCommand:getDescriptionText()
    local totalRuntime = self.config.duration * 3600
    local timeRemaining = round((totalRuntime - self.data.runTime) / 60) * 60
    local completed = round(self.data.runTime / totalRuntime * 100)

    return "Ship is mining resources.\n\nTime remaining: ${timeRemaining} (${completed} % done)."%_T, {timeRemaining = createReadableShortTimeString(timeRemaining), completed = completed}
end

function MineCommand:getStatusMessage()
    return "Mining /* ship AI status*/"%_T
end

function MineCommand:getIcon()
    return "data/textures/icons/mine-command.png"
end

function MineCommand:getRecallError()
end

-- returns whether there are errors with the command, either in the config, or otherwise (ship has no mining turrets, not enough energy, player doesn't have enough money, etc.)
-- note: before this is called, there is already a preliminary check based on getConfigurableValues(), where values are clamped or default-set
function MineCommand:getErrors(ownerIndex, shipName, area, config)
    -- if there are no errors, just return
    local properties = self:getMiningProperties(ownerIndex, shipName)

    if not properties.refinedMining and not properties.rawMining then
        if properties.noStartPositions then
            return "No start positions for fighters!"%_t
        elseif properties.missingSquadSubsystems then
            return "Not enough squad control subsystems for fighters!"%_t
        elseif properties.notEnoughPilots then
            return "Not enough pilots for all fighters!"%_t
        end

        return "The ship has no mining equipment!"%_t
    end

    if area.analysis.reachable == 0 then
        return "There are no sectors that we can mine in!"%_t
    end

    local nonFactionSectors = area.analysis.sectorsByFaction[0] or 0
    if config.safeMode and area.analysis.reachable == nonFactionSectors then
        return "There are no sectors that we can mine in!"%_t
    end

    if not properties.turretSlotsFulfilled then
        return "Not enough turret slots for all turrets!"%_t
    end
end

function MineCommand:getAreaSize(ownerIndex, shipName)
    return {x = 15, y = 15}
end

function MineCommand:getAreaBounds()
    return {lower = self.area.lower, upper = self.area.upper}
end

function MineCommand:isShipRequiredInArea(ownerIndex, shipName)
    return true
end

function MineCommand:isAreaFixed(ownerIndex, shipName)
    return false
end

function MineCommand:getConfigurableValues(ownerIndex, shipName)
    local values = {}

    local minDuration = 0.5
    local maxDuration = 2
    if ownerIndex and shipName then
        local entry = ShipDatabaseEntry(ownerIndex, shipName)
        local captain = entry:getCaptain()
        if captain:hasClass(CaptainUtility.ClassType.Miner) then
            maxDuration = maxDuration + 0.5 + captain.tier + captain.level * 0.5
        end
    end

    -- value names here must match with values returned in ui:buildConfig() below
    values.duration = {displayName = "Duration"%_t, from = minDuration, to = maxDuration, default = 1}
    values.safeMode = {displayName = "Safe Mode"%_t, default = false}
    values.immediateDelivery = {displayName = "Immediate Delivery"%_t, default = false}

    return values
end

function MineCommand:getPredictableValues()
    local values = {}

    values.yields = {}
    for i = 1, NumMaterials() do
        local material = Material(i - 1)
        values.yields[i] = {displayName = material.name}
    end

    values.attackChance = {displayName = SimulationUtility.AttackChanceLabelCaption}

    return values
end

function MineCommand:getMiningProperties(ownerIndex, shipName)
    -- this collects the ship's capabilities to mine asteroids of different materials
    -- for each asteroid material, the efficiencies and DPS might be different, due to different material turrets and (R-)mining turrets
    local properties = {}
    local materials = {}

    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local turrets = entry:getTurrets()
    local hangar = entry:getLightweightHangar()

    local allMiners = {}
    local crew = entry:getCrew()

    local pilotWorkforce = 0
    for profession, workforce in pairs(crew:getWorkforce()) do
        if profession.value == CrewProfessionType.Pilot then
            pilotWorkforce = workforce
            break
        end
    end

    for _, squad in pairs(hangar) do
        local squadFighters = {squad:getFighters()}
        for _, fighter in pairs(squadFighters) do
            -- don't use pilots for fighters that can't salvage
            if fighter.stoneRefinedEfficiency > 0 or fighter.stoneRawEfficiency > 0 then
                if not entry:getFighterStartRequirementsFulfilled() then
                    properties.noStartPositions = true
                    goto continue
                end

                if not entry:getFighterSquadRequirementsFulfilled() then
                    properties.missingSquadSubsystems = true
                    goto continue
                end

                if pilotWorkforce <= 0 then
                    properties.notEnoughPilots = true
                    goto continue
                end

                pilotWorkforce = pilotWorkforce - 1
                table.insert(allMiners, fighter)
            end

            ::continue::
        end
    end

    for turret, _ in pairs(turrets) do
        table.insert(allMiners, turret)
    end

    properties.cargoSpace = entry:getFreeCargoSpace()
    properties.startingOres = 0

    local cargo = entry:getCargo()
    for good, amount in pairs(cargo) do
        local tags = good.tags
        if tags.ore or tags.scrap then
            properties.cargoSpace = properties.cargoSpace + good.size * amount
            properties.startingOres = properties.startingOres + amount
        end
    end

    local fighters = 0
    for _, obj in pairs(allMiners) do
        if obj.stoneRefinedEfficiency > 0 or obj.stoneRawEfficiency > 0 then
            if obj.__avoriontype == "FighterTemplate" then
                fighters = fighters + 1
            end
        end
    end

    properties.highestRarityMiningSystem = nil
    for subsystem, _ in pairs(entry:getSystems()) do
        if subsystem.script == "data/scripts/systems/miningsystem.lua"
                or subsystem.script == "internal/dlc/rift/systems/miningcarrierhybrid.lua" then
            properties.highestRarityMiningSystem = math.max(properties.highestRarityMiningSystem or 0, subsystem.rarity.value)
        end
    end

    -- find out properties for each material
    for i = 1, NumMaterials() do
        local minedMaterial = Material(i - 1)
        local materialProperties = {}

        -- basic: all 0
        materialProperties.refinedEfficiency = 0
        materialProperties.refinedEfficiencyWeight = 0
        materialProperties.rawEfficiency = 0
        materialProperties.rawEfficiencyWeight = 0
        materialProperties.dps = 0

        local refiningSum = 0
        local refiningDps = 0.01

        local rawSum = 0
        local rawDps = 0.01
        local dps = 0

        for _, turret in pairs(allMiners) do
            local laserMaterial = turret.material

            -- if the turret can't mine the material, skip it
            if GalaxyBalancing.MineableBy(minedMaterial, laserMaterial) then
                -- refined & raw efficiencies are collected, weighted by their DPS
                if turret.stoneRefinedEfficiency > 0 then
                    refiningSum = refiningSum + turret.stoneRefinedEfficiency * turret.dps
                    refiningDps = refiningDps + turret.dps

                    properties.refinedMining = true
                end

                if turret.stoneRawEfficiency > 0 then
                    rawSum = rawSum + turret.stoneRawEfficiency * turret.dps
                    rawDps = rawDps + turret.dps

                    properties.rawMining = true
                end

                if turret.stoneRefinedEfficiency > 0 or turret.stoneRawEfficiency > 0 then
                    -- dps is just collected
                    dps = dps + turret.dps * turret.stoneDamageMultiplier * GalaxyBalancing.GetMaterialDamageFactor(laserMaterial, minedMaterial)
                end
            end
        end

        -- depending on the DPS it's more likely for raw/refining lasers to do the last hit, resulting in refined or raw resources
        -- this is represented by a weight towards that kind of laser
        if refiningDps > 0 then
            materialProperties.refinedEfficiency = refiningSum / refiningDps
        end
        if rawDps > 0 then
            materialProperties.rawEfficiency = rawSum / rawDps
        end

        if (refiningDps + rawDps) > 0 then
            materialProperties.refinedEfficiencyWeight = refiningDps / (refiningDps + rawDps)
            materialProperties.rawEfficiencyWeight = rawDps / (refiningDps + rawDps)
        end

        -- just take the DPS
        materialProperties.dps = dps

        materials[i] = materialProperties
    end

    properties.materials = materials
    properties.fighters = fighters
    properties.turretSlotsFulfilled = entry:getTurretSlotRequirementsFulfilled()

    return properties
end

function MineCommand:calculateTimeToMineAsteroid(dps, material)

    -- average durability of a normal asteroid in the game
    local durabilities = {}
    durabilities[MaterialType.Iron] = 28500
    durabilities[MaterialType.Titanium] = 43800
    durabilities[MaterialType.Naonite] = 64500
    durabilities[MaterialType.Trinium] = 99000
    durabilities[MaterialType.Xanion] = 145000
    durabilities[MaterialType.Ogonite] = 220000
    durabilities[MaterialType.Avorion] = 326000

    local hp = durabilities[material] or durabilities[MaterialType.Iron]

    local baseTime = 5 -- for things like aiming at the various blocks, turrets moving, collecting resources, etc.
    local mineTime = hp / dps

    return baseTime + mineTime
end

function MineCommand:calculateGatheredResources(properties)
    local resourcesPerAsteroid = 3850 -- average yield of a normal asteroid in the game

    local refined = properties.refinedEfficiency * properties.refinedEfficiencyWeight * resourcesPerAsteroid
    local raw = properties.rawEfficiency * properties.rawEfficiencyWeight * resourcesPerAsteroid

    return refined, raw
end

function MineCommand:calculatePrediction(ownerIndex, shipName, area, config)

    -- times to do things
    local timeToFly = 25 -- estimation, time to fly between asteroids
    local timeToFindField = 120 -- estimation, time it takes to find the next asteroid field
    local timeToTravelRefine = 180 -- estimation, time it takes to fly to a refinery and return (without refining)

    local asteroidsPerField = 20 -- every this many asteroids it takes some time to fly to a new asteroid field
    local asteroidsPerGroup = 8 -- every this many asteroids it takes slightly longer to fly to the next asteroid
    local captainCut = 0.1 -- captain takes 10% of the yield
    local hourlyBonus = 0.005 -- each hour of duration increases the yield by 0.5%, so it doesn't just scale linearly -> encourage players to send captains away longer

    -- weigh by free play settings
    local resourceAsteroidFactor = GameSettings().resourceAsteroidFactor
    if resourceAsteroidFactor > 1 then
        timeToFly = lerp(resourceAsteroidFactor, 1, 5, 25, 5)
        asteroidsPerField = lerp(resourceAsteroidFactor, 1, 5, 20, 100)
    elseif resourceAsteroidFactor < 1 then
        timeToFly = lerp(resourceAsteroidFactor, 1, 0.1, 25, 250)
        asteroidsPerField = lerp(resourceAsteroidFactor, 1, 0.1, 20, 2)
    end

    local centralFactionSectorWeight = 0.15
    local outerFactionSectorWeight = 0.5
    local nonFactionSectorWeight = 1.0
    local oresRefinedPerSecond = 2000
    local maxCarriableOres = 5 * 60 * oresRefinedPerSecond -- refine time of 5 minutes
    local refineryTax = 0.08 -- refining takes up 8% of the ores

    local simultaneousPerFighters = 6 -- can mine one more asteroid per 6 fighters
    local maxSimultaneous = 13 -- can mine this many asteroids at the same time

    local time = config.duration * 3600 -- duration in hours to time in seconds

    local results = self:getPredictableValues()
    local properties = self:getMiningProperties(ownerIndex, shipName)
    results.properties = properties
    results.attackChance.value = 0
    results.averageTimeToMine = 30

    for i = 1, NumMaterials() do
        local yield = results.yields[i]
        yield.to = 0
        yield.from = 0
    end

    if not properties.rawMining and not properties.refinedMining then
        if properties.noStartPositions then
            results.error = "No start positions for fighters!"%_t
        elseif properties.missingSquadSubsystems then
            results.error = "Not enough squad control subsystems for fighters!"%_t
        elseif properties.notEnoughPilots then
            results.error = "Not enough pilots for all fighters!"%_t
        else
            results.error = "The ship has no mining equipment!"%_T
        end

        return results
    end

    -- if we carry so much ore that refining would take over 80% of the time to mine, we abort
    -- player should issue a refine command instead
    local maxStartingOres = time * oresRefinedPerSecond * 0.8
    if properties.startingOres > maxStartingOres then
        results.error = "There's so much ore or scrap metal on board that refining it would take more time than the entire mining operation!"%_t
        return results
    end

    if area.analysis.reachable == 0 then
        results.error = "There are no sectors that we can mine in this area!"%_t
        return results
    end

    -- efficiency based on current area
    local nonFactionSectors = area.analysis.sectorsByFaction[0] or 0
    local centralFactionSectors = 0
    local outerFactionSectors = 0
    for _, sector in pairs(area.analysis.reachableCoordinates) do
        if sector.faction ~= 0 then
            if sector.isCentralArea then
                centralFactionSectors = centralFactionSectors + 1
            else
                outerFactionSectors = outerFactionSectors + 1
            end
        end
    end

    local materials = area.analysis.materials
    local discoveredAsteroids = area.analysis.asteroids or 0
    local attackChanceModification = nil

    -- safe mode means that only faction sectors will be visited to avoid attacks at all costs
    -- but also faction sectors with factions we're at war with will be avoided as well
    if config.safeMode then
        outerFactionSectorWeight = outerFactionSectorWeight / 3
        centralFactionSectorWeight = centralFactionSectorWeight / 1.5

        materials = area.analysis.safeMaterials
        discoveredAsteroids = area.analysis.safeAsteroids or 0
        nonFactionSectors = 0

        centralFactionSectors = 0
        outerFactionSectors = 0
        for _, sectorIndex in pairs(area.analysis.safeSectors) do
            local sector = area.analysis.reachableCoordinates[sectorIndex]
            if sector.faction ~= 0 then
                if sector.isCentralArea then
                    centralFactionSectors = centralFactionSectors + 1
                else
                    outerFactionSectors = outerFactionSectors + 1
                end
            end
        end

        attackChanceModification = function(attackProbability, baseAttackProbability, baseProbability)
            if attackProbability < 0.1 then return 0 end

            return attackProbability * 0.1
        end
    end

    -- attackLocation gets predicted on the client as well, but that doesn't matter since the value is not reliable
    -- the prediction that counts is the one that's happening on the server on start of the command
    -- which is completely random. so that's safe and can't be exploited
    results.attackChance.value, results.attackLocation = SimulationUtility.calculateAttackProbability(ownerIndex, shipName, area, config.escorts, config.duration, attackChanceModification)

    if (nonFactionSectors + centralFactionSectors + outerFactionSectors) <= 0 then
        results.error = "There are no sectors that we can mine in this area!"%_t
        return results
    end

    local efficiency = (nonFactionSectors * nonFactionSectorWeight + centralFactionSectors * centralFactionSectorWeight + outerFactionSectors * outerFactionSectorWeight) /
            (nonFactionSectors + centralFactionSectors + outerFactionSectors)

    local areaBoost = math.min(0.75, round(discoveredAsteroids / 15) / 100)
    efficiency = math.min(1, efficiency + areaBoost)

    -- add a boost for mining system installed
    if properties.highestRarityMiningSystem then
        efficiency = lerp((properties.highestRarityMiningSystem + 2) * 2, 0, 100, efficiency, 1)
    end

    local ore = goods["Iron Ore"] -- all ores have the same size, doesn't matter which one we choose here
    local maxOres = math.min(maxCarriableOres, properties.cargoSpace / ore.size)

    if properties.rawMining and maxOres <= 1000 then
        results.error = "There isn't enough space in our cargo bay for more ores!"%_t
        return results
    end

    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local captain = entry:getCaptain()

    if captain:hasPerk(CaptainUtility.PerkType.Navigator) then -- navigator finds a new sector faster
        timeToFindField = timeToFindField + CaptainUtility.getMiningPerkImpact(captain, CaptainUtility.PerkType.Navigator)
    end

    if captain:hasPerk(CaptainUtility.PerkType.Reckless) then -- reckless captain just jumps into sectors without caring -> faster
        timeToFindField = timeToFindField + CaptainUtility.getMiningPerkImpact(captain, CaptainUtility.PerkType.Reckless)
    end

    if captain:hasPerk(CaptainUtility.PerkType.Careful) then -- careful captain takes longer to find a sector they deem secure
        timeToFindField = timeToFindField + CaptainUtility.getMiningPerkImpact(captain, CaptainUtility.PerkType.Careful)
    end

    if captain:hasPerk(CaptainUtility.PerkType.Disoriented) then -- disoriented captain doesn't remember where they went
        timeToFindField = timeToFindField + CaptainUtility.getMiningPerkImpact(captain, CaptainUtility.PerkType.Disoriented)
    end

    if captain:hasPerk(CaptainUtility.PerkType.Addict) then -- addict takes longer for everything due to their sickness
        timeToFindField = timeToFindField + CaptainUtility.getMiningPerkImpact(captain, CaptainUtility.PerkType.Addict)
    end

    if captain:hasPerk(CaptainUtility.PerkType.Commoner) then -- commoner knows how to talk to people and thus reduce refinery tax
        refineryTax = refineryTax * CaptainUtility.getMiningPerkImpact(captain, CaptainUtility.PerkType.Commoner)
    end

    if captain:hasPerk(CaptainUtility.PerkType.Noble) then -- noble looks like money and will always have to pay a higher refinery tax
        refineryTax = refineryTax * CaptainUtility.getMiningPerkImpact(captain, CaptainUtility.PerkType.Noble)
    end

    if captain:hasPerk(CaptainUtility.PerkType.Connected) then -- connected knows everybody and can call in favors to reduce refinery tax
        refineryTax = refineryTax * CaptainUtility.getMiningPerkImpact(captain, CaptainUtility.PerkType.Connected)
    end

    if captain:hasClass(CaptainUtility.ClassType.Miner) then -- Miner knows where to find proper asteroid fields
        asteroidsPerField = asteroidsPerField + 30
    end

    asteroidsPerField = asteroidsPerField + discoveredAsteroids / 100
    timeToFindField = timeToFindField - discoveredAsteroids / 100

    -- cap at 30s
    timeToFindField = math.max(30, timeToFindField)

    -- area efficiency influences the time it takes to find fields and asteroids
    timeToFly = timeToFly / efficiency
    timeToFindField = timeToFindField / efficiency

    local gatheredResources = {}
    for i = 1, NumMaterials() do
        gatheredResources[i] = 0
    end

    local asteroidsMined = 0
    local asteroidsRemainingInField = asteroidsPerField
    local asteroidsRemainingInGroup = asteroidsPerGroup
    local currentOres = properties.startingOres

    -- Take care here, simultaneous ONLY AFFECTS FLYING. For everything else, all other rules still apply.
    -- Mining 6 asteroids at the same time still requires damaging the 6 asteroids with the current DPS
    local simultaneousAsteroids = math.min(maxSimultaneous, 1 + math.floor(properties.fighters / simultaneousPerFighters))
    local simultaneousCounter = simultaneousAsteroids

    -- for a fixed prediction it's necessary to have a static random number generator for deterministic numbers
    local random = Random(Seed(12039810293))

    -- if raw mining is enabled, the ship must go refine at the end
    -- to keep things simple, we'll remove the refining time at the beginning
    if properties.rawMining then
        time = time - (maxCarriableOres * 0.5 / oresRefinedPerSecond)
        time = time - timeToTravelRefine
    end

    -- find an asteroid field
    time = time - timeToFindField
    local totalTimesRefined = 0

    while time > 0 do

        -- 'locate' an asteroid
        local material = getValueFromDistribution(materials, random)
        local materialProperties = properties.materials[material]

        -- check if we can and want mine it
        if materialProperties.dps > 0 and config.collected[material - 1] then

            -- fly to the asteroid, but if we can mine several asteroids simultaneously through fighters, we don't take up time to fly to the next one
            simultaneousCounter = simultaneousCounter - 1
            if simultaneousCounter <= 0 then
                simultaneousCounter = simultaneousAsteroids

                -- time to fly to the asteroid
                time = time - timeToFly
            end

            -- every X asteroids it takes some more time to fly to the next one
            if asteroidsRemainingInGroup <= 0 then
                asteroidsRemainingInGroup = asteroidsRemainingInGroup + asteroidsPerGroup
                time = time - timeToFly
            end

            -- mine the asteroid
            local timeToMine = self:calculateTimeToMineAsteroid(materialProperties.dps, material)
            time = time - timeToMine

            local refined, ores = self:calculateGatheredResources(materialProperties)

            -- for ores, only count ores that the ship can carry
            local before = currentOres
            currentOres = math.min(currentOres + ores, maxOres)
            local oresGained = currentOres - before

            gatheredResources[material] = gatheredResources[material] + refined + oresGained * (1 - refineryTax) -- refinery tax
        end

        -- if the cargo bay is full, refine
        if currentOres > 0 and currentOres >= maxOres then
            -- measure times it's necessary to refine
            totalTimesRefined = totalTimesRefined + 1

            time = time - (currentOres / oresRefinedPerSecond)
            currentOres = 0
            time = time - timeToTravelRefine
        end

        asteroidsMined = asteroidsMined + 1
        asteroidsRemainingInGroup = asteroidsRemainingInGroup - 1
        asteroidsRemainingInField = asteroidsRemainingInField - 1

        -- every X asteroids, find a new field
        if asteroidsRemainingInField <= 0 then
            asteroidsRemainingInField = asteroidsRemainingInField + asteroidsPerField
            time = time - timeToFindField
        end
    end

    if currentOres > 0 then
        -- measure time it takes to collect until refining is necessary
        totalTimesRefined = totalTimesRefined + 1
    end

    local captainBonus = 0.0
    if captain:hasClass(CaptainUtility.ClassType.Miner) then
        captainBonus = 0.25
    end

    -- calculate reduction in yield caused by having special cargo on board
    -- smuggler captains don't have to slow down when transporting special goods
    local specialGoodsFactor = 1
    if not captain:hasClass(CaptainUtility.ClassType.Smuggler) then
        local stolenOrIllegal, dangerousOrSuspicious = SimulationUtility.getSpecialCargoCategories(entry:getCargo())

        -- merchant captains don't have to slow down when transporting dangerous or suspicious goods
        if captain:hasClass(CaptainUtility.ClassType.Merchant) then
            dangerousOrSuspicious = false
        end

        if stolenOrIllegal or dangerousOrSuspicious then
            specialGoodsFactor = 0.85
        end
    end

    for i = 1, NumMaterials() do
        -- each hour of duration slightly increases the amount, so it doesn't just scale linearly
        -- this should encourage players to send their captains away for a longer time
        gatheredResources[i] = gatheredResources[i] + gatheredResources[i] * (config.duration - 1) * hourlyBonus

        -- captain bonus
        gatheredResources[i] = gatheredResources[i] + (gatheredResources[i] * captainBonus)

        -- captain takes a cut
        gatheredResources[i] = gatheredResources[i] * (1.0 - captainCut)

        if captain:hasPerk(CaptainUtility.PerkType.Gambler) then
            gatheredResources[i] = gatheredResources[i] * (1.0 + CaptainUtility.getMiningPerkImpact(captain, CaptainUtility.PerkType.Gambler))
        end

        -- final yield
        local yield = results.yields[i]
        yield.to = round(gatheredResources[i] * specialGoodsFactor) -- reduce the yield when carrying special goods
        yield.from = round(yield.to * 0.8)
    end

    -- calculate efficiencies
    -- area efficiency
    local total = nonFactionSectors + centralFactionSectors + outerFactionSectors
    local nonFaction = round((nonFactionSectors * nonFactionSectorWeight) / total * 100)
    local outer = round((outerFactionSectors * outerFactionSectorWeight) / total * 100)
    local central = round((centralFactionSectors * centralFactionSectorWeight) / total * 100)
    local uncoveredAsteroids = round(areaBoost * 100)

    uncoveredAsteroids = math.min(100 - (nonFaction + outer + central), uncoveredAsteroids)
    results.areaEfficiency = math.min(100, nonFaction + outer + central + uncoveredAsteroids)

    -- boost for mining system installed
    local upgrade = 0
    if properties.highestRarityMiningSystem then
        upgrade = round(efficiency * 100) - results.areaEfficiency
    end

    results.areaEfficiency = math.min(100, results.areaEfficiency + upgrade)
    results.areaEfficiencyBreakdown = {
        nonFaction = nonFaction,
        outer = outer,
        central = central,
        asteroids = uncoveredAsteroids,
        upgrade = upgrade,
        total = total
    }

    -- mining speed
    local averageTimeToMine = 0
    for material, weight in pairs(materials) do
        if weight > 0 then
            local materialProperties = properties.materials[material]
            if materialProperties.dps > 0 then
                local timeToMine = self:calculateTimeToMineAsteroid(materialProperties.dps, material)
                averageTimeToMine = averageTimeToMine + timeToMine * weight
            end
        end
    end

    results.speedEfficiency = lerp(averageTimeToMine, 90, 6, 0.01, 1)

    -- efficiency for cargo is trickier
    if properties.rawMining then
        if totalTimesRefined == 1 or maxOres >= maxCarriableOres then
            -- if we only have to refine once, we're doing perfectly
            -- same if we're carrying the maximum possible amount
            results.cargoEfficiency = 1
        else
            -- efficiency is determined by the amount of time that is lost by potentially avoidable refine trips
            local lostTime = (totalTimesRefined - 1) * timeToTravelRefine
            results.cargoEfficiency = lerp(lostTime, 0, config.duration * 3600, 1.0, 0.0)
        end
    end

    if properties.fighters > 0 then
        results.parallelEfficiency = lerp(simultaneousAsteroids, 0, maxSimultaneous, 0, 1)
    end

    -- yields from escorts
    if config.escorts and #config.escorts > 0 then
        local subConfig = table.deepcopy(config)
        subConfig.escorts = nil

        for _, otherName in pairs(config.escorts) do
            local prediction = self:calculatePrediction(ownerIndex, otherName, area, subConfig)

            for i = 1, NumMaterials() do
                results.yields[i].from = results.yields[i].from + prediction.yields[i].from
                results.yields[i].to = results.yields[i].to + prediction.yields[i].to
            end
        end
    end

    local hasYields = false
    for i = 1, NumMaterials() do
        if results.yields[i].from > 0 then
            hasYields = true
            break
        end
    end

    if not hasYields then
        results.error = "This mining operation won't yield any resources!"%_t
    end

    return results
end

function MineCommand:generateAssessmentFromPrediction(prediction, captain, ownerIndex, shipName, area, config)

    -- please don't just copy this function. It's specific to the mine command.
    -- use it as a guidance, but don't just use the same sentences etc.

    local total = area.analysis.sectors - area.analysis.unreachable
    if total == 0 then return "We can't mine in this area!"%_t end

    local attackChance = prediction.attackChance.value
    local pirateSectorRatio = SimulationUtility.calculatePirateAttackSectorRatio(area)

    local resourceLines = {}
    if pirateSectorRatio >= 0.75 then
        table.insert(resourceLines, "The area is very rich in asteroids. We will be able to collect a lot of resources here."%_t)
    elseif pirateSectorRatio >= 0.45 then
        table.insert(resourceLines, "The area is rich in asteroids. We will be able to collect quite some resources here."%_t)
    elseif pirateSectorRatio >= 0.05 then
        table.insert(resourceLines, "\\c(dd5)The area doesn't contain many asteroid fields. We might not be able to collect many resources here.\\c()"%_t)
    else
        table.insert(resourceLines, "\\c(dd5)We won't be able to find many resources here, but the area seems quite safe. We'll see what we can do.\\c()"%_t)
    end

    -- cargo on board
    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local cargo = entry:getCargo()
    local stolenOrIllegal, dangerousOrSuspicious = SimulationUtility.getSpecialCargoCategories(cargo)
    local cargobayLines = SimulationUtility.getIllegalCargoAssessmentLines(stolenOrIllegal, dangerousOrSuspicious, captain)

    local pirateLines = {}
    if config.safeMode then
        resourceLines = {}

        table.insert(resourceLines, "\\c(dd5)We will not make a single hyperspace jump into pirate territory. We will be safer that way, but less productive. We will see what we can find.\\c()"%_t)
        table.insert(pirateLines, "There is no pirate activity that we can detect."%_t)
    else
        pirateLines = SimulationUtility.getPirateAssessmentLines(pirateSectorRatio)
    end

    local attackLines = SimulationUtility.getAttackAssessmentLines(attackChance)
    local underRadar, returnLines = SimulationUtility.getDisappearanceAssessmentLines(attackChance)

    if attackChance < 0.1 then
        -- add mine command specific line
        table.insert(underRadar, "You won't be able to reach us while we are out mining. If you had all my knowledge about hidden asteroid fields, you wouldn't need me anymore."%_t)
    end

    local fighterLines = {}
    if prediction.properties.noStartPositions then
        table.insert(fighterLines, "\\c(d93)We won't be able to use our fighters, since we have no start positions!\\c()"%_t)
    elseif prediction.properties.missingSquadSubsystems then
        table.insert(fighterLines, "\\c(d93)We won't be able to use our fighters, since we don't have enough squad control subsystems!\\c()"%_t)
    elseif prediction.properties.notEnoughPilots then
        table.insert(fighterLines, "\\c(d93)We won't be able to use all fighters, since we don't have enough pilots!\\c()"%_t)
    end

    local deliveries = {}
    if config.duration <= 1 then
        table.insert(deliveries, "Expect a shipment every 15 minutes."%_t)
        table.insert(deliveries, "We will send you a shipment every 15 minutes."%_t)
    else
        table.insert(deliveries, "Expect a shipment every 30 minutes."%_t)
        table.insert(deliveries, "We will send you a shipment every 30 minutes."%_t)
    end

    local rnd = Random(Seed(captain.name))
    return {
        randomEntry(rnd, resourceLines),
        randomEntry(rnd, cargobayLines),
        randomEntry(rnd, fighterLines),
        randomEntry(rnd, pirateLines),
        randomEntry(rnd, attackLines),
        randomEntry(rnd, underRadar),
        randomEntry(rnd, returnLines),
        randomEntry(rnd, deliveries),
    }
end

function MineCommand:buildUI(startPressedCallback, changeAreaPressedCallback, recallPressedCallback, configChangedCallback)
    local ui = {}
    ui.orderName = "Mine"%_t
    ui.icon = MineCommand:getIcon()

    local size = vec2(650, 620)

    ui.window = GalaxyMap():createWindow(Rect(size))
    ui.window.caption = "Mining Operation"%_t

    ui.commonUI = SimulationUtility.buildCommandUI(ui.window, startPressedCallback, changeAreaPressedCallback, recallPressedCallback, configChangedCallback, {areaHeight = 130, configHeight = 40, changeAreaButton = true})

    -- configurable values
    local configValues = self:getConfigurableValues()

    local vsplitConfig = UIVerticalSplitter(ui.commonUI.configRect, 30, 0, 0.55)

    local vsplitSliderTime = UIVerticalSplitter(vsplitConfig.left, 20, 10, 0.25)
    local timeLabel = ui.window:createLabel(vsplitSliderTime.left, configValues.duration.displayName .. ":", 13)
    timeLabel:setRightAligned()

    local vSliderSplit = UIVerticalSplitter(vsplitSliderTime.right, 10, 0, 0.8)
    ui.durationSlider = ui.window:createSlider(vSliderSplit.left, 1, 4, 3, "", configChangedCallback)
    ui.durationSlider.showValue = false
    ui.durationLabel = ui.window:createLabel(vSliderSplit.right, "", 13)
    ui.durationLabel:setCenterAligned()

    local hsplit = UIHorizontalSplitter(vsplitConfig.right, 10, 0, 0.5)
    hsplit.marginLeft = 40
    hsplit.marginRight = 40
    ui.safeModeCheckBox = ui.window:createCheckBox(hsplit.top, configValues.safeMode.displayName, configChangedCallback)
    ui.safeModeCheckBox.captionLeft = true
    ui.safeModeCheckBox.tooltip = "The captain avoids dangerous sectors, such as those with pirate activity. However, these contain more resources."%_t
    ui.safeModeCheckBox.fontSize = 13

    ui.immediateDeliveryCheckBox = ui.window:createCheckBox(hsplit.bottom, configValues.immediateDelivery.displayName, configChangedCallback)
    ui.immediateDeliveryCheckBox.captionLeft = true
    ui.immediateDeliveryCheckBox.tooltip = "Send deliveries directly to your account."%_t
    ui.immediateDeliveryCheckBox.fontSize = 13

    -- yields & issues
    local predictable = self:getPredictableValues()
    local vlist = UIVerticalLister(ui.commonUI.predictionRect, 2, 0)
    local vsplitYields = UIVerticalSplitter(vlist:nextRect(15), 5, 0, 0.65)

    local label = ui.window:createLabel(vsplitYields.left, predictable.attackChance.displayName .. ":", 12)
    label.tooltip = SimulationUtility.AttackChanceLabelTooltip
    ui.commonUI.attackChanceLabel = ui.window:createLabel(vsplitYields.right, "", 12)
    ui.commonUI.attackChanceLabel:setCenterAligned()
    ui.commonUI.attackChanceLabel.tooltip = SimulationUtility.AttackChanceLabelTooltip

    local vsplitYields = UIVerticalSplitter(vlist:nextRect(15), 5, 0, 0.65)
    ui.window:createLabel(vsplitYields.left, "Delivery Interval:"%_t, 12)
    ui.yieldTimeLabel = ui.window:createLabel(vsplitYields.right, "30 min"%_t, 12)
    ui.yieldTimeLabel:setCenterAligned()

    vlist:nextRect(5)

    local vsplitYields = UIVerticalSplitter(vlist:nextRect(15), 5, 0, 0.65)
    ui.window:createLabel(vsplitYields.left, "Area:"%_t, 12)
    ui.areaEfficiencyLabel = ui.window:createLabel(vsplitYields.right, "90%"%_t, 12)
    ui.areaEfficiencyLabel:setCenterAligned()
    vsplitYields:setRightQuadratic()

    local rect = vsplitYields.right
    rect.size = rect.size + vec2(5, 5)
    ui.subsystemIcon = ui.window:createPicture(rect, "data/textures/icons/circuitry.png")
    ui.subsystemIcon.tooltip = "Additional bonus from Mining Subsystem. Mining Subsystems help most when used in areas with few resources."%_t
    ui.subsystemIcon.isIcon = true

    local vsplitYields = UIVerticalSplitter(vlist:nextRect(15), 5, 0, 0.65)
    ui.window:createLabel(vsplitYields.left, "Damage Efficiency:"%_t, 12)
    ui.speedLabel = ui.window:createLabel(vsplitYields.right, "90%"%_t, 12)
    ui.speedLabel:setCenterAligned()

    local vsplitYields = UIVerticalSplitter(vlist:nextRect(15), 5, 0, 0.65)
    ui.window:createLabel(vsplitYields.left, "Cargo Space:"%_t, 12)
    ui.cargoBayLabel = ui.window:createLabel(vsplitYields.right, "80%"%_t, 12)
    ui.cargoBayLabel:setCenterAligned()

    local vsplitYields = UIVerticalSplitter(vlist:nextRect(15), 5, 0, 0.65)
    ui.window:createLabel(vsplitYields.left, "Simultaneous Mining:"%_t, 12)
    ui.parallelLabel = ui.window:createLabel(vsplitYields.right, "15%"%_t, 12)
    ui.parallelLabel:setCenterAligned()
    ui.parallelLabel.tooltip = "Simultaneous Mining: The ship is able to mine several asteroids at the same time using mining fighters."%_t

    vlist:nextRect(5)

    ui.materialLines = {}
    for i = 1, NumMaterials() do
        local vsplit = UIVerticalSplitter(vlist:nextRect(18), 5, 0, 0.65)
        local vsplit2 = UIVerticalSplitter(vsplit.left, 10, 0, 0.5)
        vsplit2:setLeftQuadratic()

        local textLabel = ui.window:createLabel(vsplit2.right, predictable.yields[i].displayName, 12)
        local checkBox = ui.window:createCheckBox(vsplit2.left, "", configChangedCallback)
        local amountLabel = ui.window:createLabel(vsplit.right, "", 12)
        amountLabel:setCenterAligned()

        local material = Material(i - 1)
        amountLabel.color = material.color
        textLabel.color = material.color

        amountLabel:hide()
        textLabel:hide()

        ui.materialLines[i] = {checkBox = checkBox, amountLabel = amountLabel, textLabel = textLabel}
    end

    ui.clear = function(self, shipName)
        self.commonUI:clear(shipName)

        for i = 1, NumMaterials() do
            self.materialLines[i].amountLabel.caption = ""
        end

        self.areaEfficiencyLabel.caption = ""
        self.subsystemIcon:hide()
        self.speedLabel.caption = ""
        self.yieldTimeLabel.caption = ""
        self.cargoBayLabel.caption = ""
        self.parallelLabel.caption = ""
    end

    -- used to fill values into the UI
    -- config == nil means fill with default values
    ui.refresh = function(self, ownerIndex, shipName, area, config)

        self.commonUI:refresh(ownerIndex, shipName, area, config)

        if not config then
            -- no config: fill UI with default values, then build config, then use it to calculate yields
            local values = MineCommand:getConfigurableValues(ownerIndex, shipName)

            -- use "setValueNoCallback" since we don't want to trigger "refreshPredictions()" while filling in default values
            self.durationSlider:setMinNoCallback(values.duration.from * 2)
            self.durationSlider:setMaxNoCallback(values.duration.to * 2)
            self.durationSlider:setNumSegmentsNoCallback((values.duration.to - values.duration.from) * 2)
            self.durationSlider:setValueNoCallback(values.duration.default * 2)
            self.safeModeCheckBox:setCheckedNoCallback(values.safeMode.default)
            self.immediateDeliveryCheckBox:setCheckedNoCallback(values.immediateDelivery.default)

            for _, line in pairs(self.materialLines) do
                line.checkBox:setCheckedNoCallback(true)
            end

            config = self:buildConfig()
        end

        self:refreshPredictions(ownerIndex, shipName, area, config)
    end

    -- gut feeling says that each config option change should always be reflected in the predictions if it impacts the behavior
    ui.refreshPredictions = function(self, ownerIndex, shipName, area, config)
        local prediction = MineCommand:calculatePrediction(ownerIndex, shipName, area, config)
        self:displayPrediction(prediction, config, ownerIndex)

        self.commonUI:refreshPredictions(ownerIndex, shipName, area, config, MineCommand, prediction)
    end

    ui.displayPrediction = function(self, prediction, config, ownerIndex)
        self.durationLabel.caption = string.format("%s h"%_t, config.duration)

        for i = 1, NumMaterials() do
            self.materialLines[i].amountLabel:hide()
            self.materialLines[i].textLabel:hide()
            self.materialLines[i].checkBox:hide()
        end

        for i = 1, NumMaterials() do
            if prediction.yields[i].from > 0 or prediction.yields[i].to > 0 or not config.collected[i-1] then
                local material = Material(i - 1)

                self.materialLines[i].amountLabel:show()
                self.materialLines[i].textLabel:show()
                self.materialLines[i].checkBox:show()
                self.materialLines[i].material = material

                self.materialLines[i].amountLabel.caption = string.format("%s - %s", toReadableNumber(prediction.yields[i].from, 1), toReadableNumber(prediction.yields[i].to, 1))
                self.materialLines[i].textLabel.caption = material.name
                self.materialLines[i].textLabel.color = material.color
                self.materialLines[i].amountLabel.color = material.color

                self.materialLines[i].textLabel.strikethrough = not config.collected[i-1]
                self.materialLines[i].amountLabel.strikethrough = not config.collected[i-1]

                if not config.collected[i-1] then
                    self.materialLines[i].amountLabel.caption = "    "%_t
                end
            end
        end

        if prediction.speedEfficiency then
            self.speedLabel.caption = tostring(math.floor(prediction.speedEfficiency * 100)) .. "%"
            self.speedLabel.tooltip = "Damage Efficiency: More fire power, more asteroids! But this doesn't scale up endlessly. Any ship will eventually reach the point where flying and navigating takes longer than mining."%_t

            local colors = {vec3(1.0, 0.4, 0.1), vec3(0.9, 0.9, 0.2), vec3(0.2, 0.9, 0.2)}
            local color = multilerp(prediction.speedEfficiency, 0, 0.9, colors)
            self.speedLabel.color = ColorRGB(color.x, color.y, color.z)
        end

        if prediction.areaEfficiency then
            self.areaEfficiencyLabel.caption = prediction.areaEfficiency .. "%"

            local tooltip = "No Man's Space yields the most resources per sector while Central Faction Areas yield the least."%_t
            local total = prediction.areaEfficiencyBreakdown.total

            local breakdown = {}
            if prediction.areaEfficiencyBreakdown.nonFaction > 0 then
                table.insert(breakdown, "- No Man's Space: +${value}%"%_t % {value = prediction.areaEfficiencyBreakdown.nonFaction})
            end

            if prediction.areaEfficiencyBreakdown.outer > 0 then
                table.insert(breakdown, "- Outer Faction Area: +${value}%"%_t % {value = prediction.areaEfficiencyBreakdown.outer})
            end

            if prediction.areaEfficiencyBreakdown.central > 0 then
                table.insert(breakdown, "- Central Faction Area: +${value}%"%_t % {value = prediction.areaEfficiencyBreakdown.central})
            end

            if prediction.areaEfficiencyBreakdown.asteroids > 0 then
                table.insert(breakdown, "- Discovered Asteroid Fields: +${value}%"%_t % {value = prediction.areaEfficiencyBreakdown.asteroids})
            end

            if prediction.areaEfficiencyBreakdown.upgrade > 0 then
                table.insert(breakdown, "- Mining Subsystem: +${value}%"%_t % {value = prediction.areaEfficiencyBreakdown.upgrade})
            end

            if #breakdown > 0 then
                tooltip = tooltip .. "\n\n" .. "Yields in this area:"%_t .. "\n" .. string.join(breakdown, "\n")
            end

            self.areaEfficiencyLabel.tooltip = tooltip

            -- add yellow twice to stay yellow longer
            local colors = {vec3(1.0, 0.4, 0.1), vec3(0.9, 0.9, 0.2), vec3(0.9, 0.9, 0.2), vec3(0.2, 0.9, 0.2)}
            local color = multilerp(prediction.areaEfficiency, 15, 85, colors)
            self.areaEfficiencyLabel.color = ColorRGB(color.x, color.y, color.z)
        end

        if prediction.properties.highestRarityMiningSystem then
            self.subsystemIcon:show()
            self.subsystemIcon.color = Rarity(prediction.properties.highestRarityMiningSystem).color
        end

        if config.duration <= 1 then
            self.yieldTimeLabel.caption = "15 min"%_t
        else
            self.yieldTimeLabel.caption = "30 min"%_t
        end

        if prediction.cargoEfficiency then
            local percent = math.floor(prediction.cargoEfficiency * 100)
            self.cargoBayLabel.caption = tostring(percent) .. "%"
            self.cargoBayLabel.strikethrough = false

            local lost = 100 - percent
            if lost == 0 then
                self.cargoBayLabel.tooltip = nil
            elseif lost == 100 then
                self.cargoBayLabel.tooltip = "The ship doesn't have any free cargo space."%_t
            else
                self.cargoBayLabel.tooltip = "Cargo Space: The ship has to waste ${percent}% of its time flying to refineries."%_t % {percent = lost}
            end

            local colors = {vec3(1.0, 0.4, 0.1), vec3(0.9, 0.9, 0.2), vec3(0.2, 0.9, 0.2)}
            local color = multilerp(prediction.cargoEfficiency, 0, 0.9, colors)
            self.cargoBayLabel.color = ColorRGB(color.x, color.y, color.z)
        else
            self.cargoBayLabel.caption = "    "
            self.cargoBayLabel.strikethrough = true
            self.cargoBayLabel.tooltip = nil
            self.cargoBayLabel.color = ColorRGB(0.9, 0.9, 0.9)
        end

        if prediction.parallelEfficiency then
            self.parallelLabel.caption = tostring(math.floor(prediction.parallelEfficiency * 100)) .. "%"
            self.parallelLabel.strikethrough = false

            local colors = {vec3(1.0, 0.4, 0.1), vec3(0.9, 0.9, 0.2), vec3(0.2, 0.9, 0.2)}
            local color = multilerp(prediction.parallelEfficiency, 0, 0.9, colors)
            self.parallelLabel.color = ColorRGB(color.x, color.y, color.z)
        else
            self.parallelLabel.caption = "    "
            self.parallelLabel.strikethrough = true
            self.parallelLabel.color = ColorRGB(0.9, 0.9, 0.9)
        end

        self.commonUI:setAttackChance(prediction.attackChance.value)
    end

    -- used to build a config table for the command, based on values configured in the UI
    -- gut feeling says that each config option change should always be reflected in the predictions if it impacts the behavior
    ui.buildConfig = function(self)
        local config = {}

        config.duration = self.durationSlider.value / 2
        config.safeMode = self.safeModeCheckBox.checked
        config.immediateDelivery = self.immediateDeliveryCheckBox.checked
        config.escorts = self.commonUI.escortUI:buildConfig()

        config.collected = {}
        for i = 1, NumMaterials() do
            config.collected[i-1] = true
        end

        for _, line in pairs(self.materialLines) do
            if line.material and line.checkBox.visible then
                config.collected[line.material.value] = line.checkBox.checked
            end
        end

        return config
    end

    ui.setActive = function(self, active, description)
        self.commonUI:setActive(active, description)

        self.durationSlider.active = active
        self.safeModeCheckBox.active = active
        self.immediateDeliveryCheckBox.active = active

        for i = 1, NumMaterials() do
            self.materialLines[i].checkBox.active = active
        end
    end

    ui.displayConfig = function(self, config, ownerIndex)
        self.durationSlider:setValueNoCallback(config.duration * 2)
        self.safeModeCheckBox:setCheckedNoCallback(config.safeMode)
        self.immediateDeliveryCheckBox:setCheckedNoCallback(config.immediateDelivery)

        for material, checked in pairs(config.collected) do
            self.materialLines[material + 1].checkBox:setCheckedNoCallback(checked)
        end
    end

    return ui
end


return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
