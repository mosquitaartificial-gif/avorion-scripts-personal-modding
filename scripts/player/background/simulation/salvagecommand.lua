package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/player/background/simulation/?.lua"

local CommandType = include ("commandtype")
local SimulationUtility = include ("simulationutility")
local CaptainUtility = include ("captainutility")
local SectorSpecifics = include ("sectorspecifics")
local SectorGenerator = include ("SectorGenerator")
local PlanGenerator = include ("plangenerator")

include ("galaxy")
include ("utility")
include ("stringutility")
include ("randomext")
include ("goods")


local SalvageCommand = {}
SalvageCommand.__index = SalvageCommand
SalvageCommand.type = CommandType.Salvage

local function new(ship, area, config)
    local command = setmetatable({
        -- all commands need these variables to function within the bg simulation framework
        -- type contains the CommandType of the command, required to restore
        type = CommandType.Salvage,

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
    }, SalvageCommand)

    command.data.runTime = 0
    command.data.yieldCounter = 0

    return command
end

-- all commands have the following functions, even if not listed here (added by Simulation script on command creation):
-- function SalvageCommand:addYield(message, money, resources, items) end
-- function SalvageCommand:finish() end
-- function SalvageCommand:registerForAttack(coords, faction, timeOfAttack, message, arguments) end


function SalvageCommand:initialize()
    local faction = getParentFaction()
    local prediction = self:calculatePrediction(faction.index, self.shipName, self.area, self.config)
    self.data.prediction = prediction

    if prediction.error then
        return prediction.error, prediction.errorArgs
    end

    -- double-check that the configured duration is valid
    local configValues = self:getConfigurableValues(faction.index, self.shipName)
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

    local items = random():getInt(prediction.items.from, prediction.items.to)
    self.data.intermediateItems = math.floor(items * smallFactor)
    self.data.finalItems = math.ceil(items * bigFactor)
end

function SalvageCommand:onStart()
    -- set position from which ship is going to start
    local parent = getParentFaction()
    local entry = ShipDatabaseEntry(parent.index, self.shipName)
    local startX, startY = entry:getCoordinates()
    self.data.startCoordinates = { x = startX, y = startY }

    if self.data.prediction.attackLocation then
        if self.simulation.disableAttack then return end -- for unit tests

        local time = random():getFloat(0.1, 0.75) * self.config.duration * 3600
        local location = self.data.prediction.attackLocation
        local x, y = location.x, location.y

        self:registerForAttack({x = x, y = y}, location.faction, time, "Your ship '%1%' is under attack in sector \\s(%2%:%3%)!"%_T, {self.shipName, x, y})
    end
end

function SalvageCommand:generateItems(amount)
    local items = {}

    local rarities = {}
    rarities[RarityType.Exceptional] = 0.02
    rarities[RarityType.Rare] = 0.05
    rarities[RarityType.Uncommon] = 0.25
    rarities[RarityType.Common] = 0.5
    rarities[RarityType.Petty] = 0.18

    for i = 1, amount do
        local item = {}

        item.x = random():getInt(self.area.lower.x, self.area.upper.x)
        item.y = random():getInt(self.area.lower.y, self.area.upper.y)
        item.seed = random():createSeed()
        item.rarity = selectByWeight(random(), rarities)

        if random():test(0.5) then
            items.turrets = items.turrets or {}
            table.insert(items.turrets, item)
        else
            items.subsystems = items.subsystems or {}
            table.insert(items.subsystems, item)
        end
    end

    return items
end

function SalvageCommand:update(timeStep)

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

        -- if this is the first yield, then yield all the metals & ores that are already on the ship
        if self.data.runTime < self.data.yieldTime * 2 then
            local faction = getParentFaction()
            local entry = ShipDatabaseEntry(faction.index, self.shipName)
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

        local money = yield[0]
        yield[0] = nil

        local items = self:generateItems(self.data.intermediateItems)

        local lines = {}
        table.insert(lines, "Commander, here's one installment of our yield!"%_t)
        table.insert(lines, "Commander, here's one shipment of our yield!"%_t)
        self:sendYield(randomEntry(lines), money, yield, items)
    end

end

function SalvageCommand:sendYield(line, money, resources, items)
    if self.config.immediateDelivery then
        local parent = getParentFaction()
        parent:receive(line, money, unpack(resources))
        self:addYield(line, 0, {}, items)
        self.simulation.takeYield(self.shipName)
    else
        self:addYield(line, money, resources, items)
    end
end

function SalvageCommand:onAreaAnalysisStart(results, meta)
    -- calculate material probabilities for both normal and safe mode
    results.materials = {}
    results.safeMaterials = {}
    for i = 1, NumMaterials() do
        results.materials[i] = 0
        results.safeMaterials[i] = 0
    end

    results.safeSectors = {}
    results.volume = 0
    results.safeVolume = 0
    results.wrecks = 0
    results.safeWrecks = 0

    -- use this as a cache for relation status to a specific faction
    -- this is so that we don't have to access the Player all the time which can be costly
    meta.statuses = {}
    meta.random = Random(Seed("salvage command seed " .. meta.area.lower.x .. "_" .. meta.area.lower.y))

end

function SalvageCommand:onAreaAnalysisSector(results, meta, x, y, details)
    local probabilities = Balancing_GetMaterialProbability(x, y)
    for i, probability in pairs(probabilities) do
        results.materials[i+1] = results.materials[i+1] + probability
    end

    local shipVolume = Balancing_GetSectorShipVolume(x, y)
    local deviation = Balancing_GetShipVolumeDeviation(meta.random:getFloat())
    results.volume = results.volume + shipVolume * deviation

    -- find out if the sector is dangerous and only calculate the materials if it isn't
    local factionIndex = details.faction
    local dangerous = (factionIndex == 0) -- it's dangerous if it's no-man's-space

    -- it's dangerous if it's controlled by a faction we're at war with
    if not dangerous then
        local status = meta.statuses[factionIndex]
        if status == nil then
            status = meta.faction:getRelationStatus(factionIndex)
            meta.statuses[factionIndex] = status
        end

        dangerous = (status == RelationStatus.War)
    end

    local view = meta.faction:getKnownSector(x, y)
    if view then
        local wrecks = (view.numWrecks or 0)
        results.wrecks = results.wrecks + wrecks

        if not dangerous then
            if details.isCentralArea then
                results.safeWrecks = results.safeWrecks + wrecks
            else
                results.safeWrecks = results.safeWrecks + wrecks / 2
            end
        end
    end

    -- if it's not dangerous, it qualifies for safe mode materials
    if not dangerous then
        for i, probability in pairs(probabilities) do
            results.safeMaterials[i+1] = results.safeMaterials[i+1] + probability
        end

        table.insert(results.safeSectors, #results.reachableCoordinates)
        results.safeVolume = results.safeVolume + shipVolume * deviation
    end
end

function SalvageCommand:onAreaAnalysisFinished(results, meta)
    if results.reachable > 0 then
        for i = 1, NumMaterials() do
            results.materials[i] = results.materials[i] / results.reachable
        end

        results.volume = results.volume / results.reachable
    end

    if #results.safeSectors > 0 then
        for i = 1, NumMaterials() do
            results.safeMaterials[i] = results.safeMaterials[i] / #results.safeSectors
        end

        results.safeVolume = results.safeVolume / #results.safeSectors
    end
end

function SalvageCommand:onRecall()
    -- at least 35% of the time to the yield must have passed,
    -- so you can't send a ship off and recall it immediately and gain resources
    local minimumRequiredTimePassed = 0.35 -- percent
    local minResourcesGained = 0.2 -- percent
    local maxResourcesGained = 0.95 -- percent

    local faction = getParentFaction()
    local entry = ShipDatabaseEntry(faction.index, self.shipName)
    local cargo, cargoBaySize = entry:getCargo()

    if self.data.yieldCounter > self.data.yieldTime * minimumRequiredTimePassed then

        -- add an intermediate yield
        local yield = {}
        for i, amount in pairs(self.data.smallYield) do
            yield[i] = lerp(self.data.yieldCounter, self.data.yieldTime * minimumRequiredTimePassed, self.data.yieldTime, amount * minResourcesGained, amount * maxResourcesGained)
        end

        local money = yield[0]
        yield[0] = nil

        -- restore ship with scrap metal on board if r-salvaging was active
        if self.data.prediction.properties.rawSalvaging then
            local properties = self.data.prediction.properties
            local occupied = 0

            -- check how much room there is in the cargo bay
            for good, amount in pairs(cargo) do
                occupied = occupied + good.size * amount
            end

            -- calculate the composition of the metals based on what we're collecting
            local total = 0
            local rawYield = {}

            for i, amount in pairs(yield) do
                local metals = amount * properties.materials[i].rawEfficiencyWeight
                rawYield[i] = metals
                yield[i] = amount - metals

                total = total + metals
            end

            -- maximum amount of metals that can be added (max: half of free cargo bay)
            -- ensure that there is not more scrap metal than should be able to be added
            local maxMetals = (cargoBaySize - occupied) / 2 / goods["Scrap Iron"].size -- all scrap metals have the same size, doesn't matter which one we choose here
            if total > 0 and total > maxMetals then
                local shrink = maxMetals / total
                for i, amount in pairs(rawYield) do
                    rawYield[i] = amount * shrink
                end
            end

            -- add the raw portion to the cargo bay
            for i, amount in pairs(rawYield) do
                local good

                if i == 1 then good = goods["Scrap Iron"]:good()
                elseif i == 2 then good = goods["Scrap Titanium"]:good()
                elseif i == 3 then good = goods["Scrap Naonite"]:good()
                elseif i == 4 then good = goods["Scrap Trinium"]:good()
                elseif i == 5 then good = goods["Scrap Xanion"]:good()
                elseif i == 6 then good = goods["Scrap Ogonite"]:good()
                elseif i == 7 then good = goods["Scrap Avorion"]:good()
                end

                if good and amount > 0 then
                    cargo[good] = amount
                end
            end
        end

        -- add the refined portion as a normal yield
        -- explicitly use "addYield" and not "sendYield" because the message contains important info
        self:addYield("Commander, unfortunately we could not complete the operation. Here is what we have salvaged so far!"%_t, money, yield)
    end

    -- add found goods
    self:makeFoundCargos(cargo)
    entry:setCargo(cargo)
end

function SalvageCommand:onAttacked()

end

function SalvageCommand:onFinish()
    local faction = getParentFaction()
    local entry = ShipDatabaseEntry(faction.index, self.shipName)
    local captain = entry:getCaptain()

    if captain:hasClass(CaptainUtility.ClassType.Explorer) then
        self:onExplorerFinish(captain)
    end

    local lines = {}
    table.insert(lines, "Mission completed, Commander, here is the final yield."%_t)
    table.insert(lines, "Commander, this is the last shipment!"%_t)

    local yield = table.deepcopy(self.data.bigYield)
    local money = yield[0]
    yield[0] = nil
    local items = self:generateItems(self.data.finalItems)
    self:sendYield(randomEntry(lines), money, self.data.bigYield, items)

    -- add found goods
    local cargo, cargoBaySize = entry:getCargo()
    self:makeFoundCargos(cargo)
    entry:setCargo(cargo)

    -- restore starting position of salvage command
    if self.data.startCoordinates then
        local startX = self.data.startCoordinates.x
        local startY = self.data.startCoordinates.y
        entry:setCoordinates(startX, startY)
    end

    -- return message
    local x, y = entry:getCoordinates()
    faction:sendChatMessage(self.shipName, ChatMessageType.Information, "%1% has finished salvaging and is awaiting your next orders in \\s(%2%:%3%)."%_T, self.shipName, x, y)
end

function SalvageCommand:isRevealableWreckageField(script)
    if script == "sectors/stationwreckage" then return true end
    if script == "sectors/wreckagefield" then return true end
    if script == "sectors/wreckageasteroidfield" then return true end
end

function SalvageCommand:onExplorerFinish(captain)

    local faction = getParentFaction()
    local specs = SectorSpecifics()
    local seed = Server().seed

    local notes = {}
    table.insert(notes, "Commander, there's a bunch of wreckages in this sector.\n\nRegards, Captain ${name}"%_T)
    table.insert(notes, "Commander, we discovered what looks like an old battlefield here.\n\nRegards, Captain ${name}"%_T)
    table.insert(notes, "Wreckage field here.\n\nRegards, Captain ${name}"%_T)
    table.insert(notes, "Found some lucrative salvage in this sector.\n\nRegards, Captain ${name}"%_T)
    table.insert(notes, "It looks like a fight happened here. Might be worth looking into for salvage.\n\nRegards, Captain ${name}"%_T)

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
                    if self:isRevealableWreckageField(specs:getScript()) then

                        view = SectorView()
                        view:setCoordinates(x, y)
                        view.note = NamedFormat(randomEntry(notes), {name = captain.name})

                        -- make sure that no new icons are created
                        if view.tagIconPath == "" then view.tagIconPath = "data/textures/icons/nothing.png" end

                        faction:addKnownSector(view)

                        -- only highlight a single sector per operation
                        return
                    end
                end
            end
        end
    end
end

function SalvageCommand:makeFoundCargos(cargos)

    for _, cargo in pairs (self.data.prediction.cargos) do
        if self.data.runTime > cargo.time then
            local good = goods[cargo.name]:good()
            cargos[good] = cargo.amount
        end
    end

    return cargos
end

function SalvageCommand:onSecure()

end

function SalvageCommand:onRestore()
    self.data.yieldTime = self.data.yieldTime or 30 * 60
end

function SalvageCommand:getDescriptionText()
    local totalRuntime = self.config.duration * 3600
    local timeRemaining = round((totalRuntime - self.data.runTime) / 60) * 60
    local completed = round(self.data.runTime / totalRuntime * 100)

    return "Ship is salvaging wreckages for resources.\n\nTime remaining: ${timeRemaining} (${completed} % done)."%_T, {timeRemaining = createReadableShortTimeString(timeRemaining), completed = completed}
end

function SalvageCommand:getStatusMessage()
    return "Salvaging /* ship AI status*/"%_T
end

function SalvageCommand:getIcon()
    return "data/textures/icons/salvage-command.png"
end

function SalvageCommand:getRecallError()
end

-- returns whether there are errors with the command, either in the config, or otherwise (ship has no salvaging turrets, not enough energy, player doesn't have enough money, etc.)
-- note: before this is called, there is already a preliminary check based on getConfigurableValues(), where values are clamped or default-set
function SalvageCommand:getErrors(ownerIndex, shipName, area, config)
    -- if there are no errors, just return
    local properties = self:getSalvagingProperties(ownerIndex, shipName)

    if not properties.refinedSalvaging and not properties.rawSalvaging and not properties.armedSalvaging then
        if properties.noStartPositions then
            return "No start positions for fighters!"%_t
        elseif properties.missingSquadSubsystems then
            return "Not enough squad control subsystems for fighters!"%_t
        elseif properties.notEnoughPilots then
            return "Not enough pilots for all fighters!"%_t
        end

        return "The ship has no salvaging equipment!"%_t
    end

    if area.analysis.reachable == 0 then
        return "There are no sectors to salvage in!"%_t
    end

    local nonFactionSectors = area.analysis.sectorsByFaction[0] or 0
    if config.safeMode and area.analysis.reachable == nonFactionSectors then
        return "There are no sectors to salvage in!"%_t
    end

    if not properties.turretSlotsFulfilled then
        return "Not enough turret slots for all turrets!"%_t
    end
end


function SalvageCommand:getAreaSize(ownerIndex, shipName)
    return {x = 15, y = 15}
end

function SalvageCommand:getAreaBounds()
    return {lower = self.area.lower, upper = self.area.upper}
end

function SalvageCommand:isAreaFixed(ownerIndex, shipName)
    return false
end

function SalvageCommand:isShipRequiredInArea(ownerIndex, shipName)
    return true
end

function SalvageCommand:getConfigurableValues(ownerIndex, shipName)
    local values = {}

    local minDuration = 0.5
    local maxDuration = 2
    if ownerIndex and shipName then
        local entry = ShipDatabaseEntry(ownerIndex, shipName)
        local captain = entry:getCaptain()
        if captain:hasClass(CaptainUtility.ClassType.Scavenger) then
            maxDuration = maxDuration + 0.5 + captain.tier + captain.level * 0.5
        end
    end

    -- value names here must match with values returned in ui:buildConfig() below
    values.duration = {displayName = "Duration"%_t, from = minDuration, to = maxDuration, default = 1}
    values.safeMode = {displayName = "Safe Mode"%_t, default = false}
    values.immediateDelivery = {displayName = "Immediate Delivery"%_t, default = false}

    return values
end

function SalvageCommand:getPredictableValues()
    local values = {}

    values.yields = {}
    values.yields[0] = {displayName = "Credits"%_t}

    for i = 1, NumMaterials() do
        local material = Material(i - 1)
        values.yields[i] = {displayName = material.name}
    end

    values.attackChance = {displayName = SimulationUtility.AttackChanceLabelCaption}
    values.items = {displayName = "Items"%_t}

    return values
end

function SalvageCommand:getSalvagingProperties(ownerIndex, shipName)
    -- this collects the ship's capabilities to salvage wreckages of different materials
    -- for each collected material, the efficiencies and DPS might be different, due to different material turrets and (R-)salvaging turrets
    local properties = {}
    local materials = {}

    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local turrets = entry:getTurrets()
    local hangar = entry:getLightweightHangar()

    local allCandidates = {}
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
            if fighter.metalRefinedEfficiency > 0 or fighter.metalRawEfficiency > 0 or fighter.armed then
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
                table.insert(allCandidates, fighter)
            end

            ::continue::
        end
    end

    for turret, _ in pairs(turrets) do
        table.insert(allCandidates, turret)
    end

    properties.cargoSpace = entry:getFreeCargoSpace()
    properties.startingMetals = 0

    local cargo = entry:getCargo()
    for good, amount in pairs(cargo) do
        local tags = good.tags
        if tags.ore or tags.scrap then
            properties.cargoSpace = properties.cargoSpace + good.size * amount
            properties.startingMetals = properties.startingMetals + amount
        end
    end

    local fighters = 0
    for _, obj in pairs(allCandidates) do
        if obj.metalRefinedEfficiency > 0
                or obj.metalRawEfficiency > 0
                or obj.armed then
            if obj.__avoriontype == "FighterTemplate" then
                fighters = fighters + 1
            end
        end
    end

    local atLeastOneSalvagingLaser = false
    local atLeastOneGun = false

    -- find out properties for each material
    for i = 1, NumMaterials() do
        local collectedMaterial = Material(i - 1)
        local materialProperties = {}

        -- basic: all 0
        materialProperties.refinedEfficiency = 0
        materialProperties.refinedEfficiencyWeight = 0
        materialProperties.rawEfficiency = 0
        materialProperties.rawEfficiencyWeight = 0
        materialProperties.dps = 0

        local refiningSum = 0
        local refiningDps = 0

        local rawSum = 0
        local rawDps = 0
        local dps = 0

        local armedDps = 0

        for _, turret in pairs(allCandidates) do
            local laserMaterial = turret.material

            if turret.metalRefinedEfficiency > 0 or turret.metalRawEfficiency > 0 then
                -- it's a salvaging turret
                -- if the turret can't mine the material, skip it
                if Balancing_MineableBy(collectedMaterial, laserMaterial) then
                    -- refined & raw efficiencies are collected, weighted by their DPS
                    if turret.metalRefinedEfficiency > 0 then
                        refiningSum = refiningSum + turret.metalRefinedEfficiency * turret.dps
                        refiningDps = refiningDps + turret.dps

                        properties.refinedSalvaging = true
                    end

                    if turret.metalRawEfficiency > 0 then
                        rawSum = rawSum + turret.metalRawEfficiency * turret.dps
                        rawDps = rawDps + turret.dps

                        properties.rawSalvaging = true
                    end

                    if turret.metalRefinedEfficiency > 0 or turret.metalRawEfficiency > 0 then
                        -- dps is just collected
                        dps = dps + turret.dps * Balancing_GetMaterialDamageFactor(laserMaterial, collectedMaterial)
                    end
                end
            elseif turret.armed then
                -- it's an armed turret
                armedDps = armedDps + turret.dps
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

            atLeastOneSalvagingLaser = true
        elseif armedDps > 0 then
            -- when the ship has no salvaging equipment for a material it falls back to its armed turrets
            local dropChance = 0.4
            local efficiency = 0.02

            materialProperties.refinedEfficiency = dropChance * efficiency
            materialProperties.rawEfficiency = dropChance * efficiency

            materialProperties.refinedEfficiencyWeight = 0.1
            materialProperties.rawEfficiencyWeight = 0.9

            atLeastOneGun = true

            dps = armedDps
        end

        -- just take the DPS
        materialProperties.dps = dps

        materials[i] = materialProperties
    end

    if not atLeastOneSalvagingLaser and atLeastOneGun then
        properties.armedSalvaging = true
        properties.rawSalvaging = true
    end

    properties.materials = materials
    properties.fighters = fighters
    properties.turretSlotsFulfilled = entry:getTurretSlotRequirementsFulfilled()

    return properties
end

function SalvageCommand:calculateTimeToSalvageWreckage(volume, dps, material)

    -- average durability of a normal wreckage in the game, per 1 volume
    -- calculated via SalvageCommand:volumeAndHPAnalysis(shipSamples)
    local hpPerVolume = 3.22

    local hp = hpPerVolume * volume * Material(material-1).strengthFactor
    local salvageTime = hp / dps

    -- for things like aiming at the various blocks, turrets moving, collecting resources, etc.
    -- increases with volume of the wreckage since more complex wreckages take longer to scrap (it's not like they're a single block)
    local complexityTime = 6 + volume / 200

    return complexityTime + salvageTime, complexityTime
end

function SalvageCommand:calculateGatheredResources(volume, properties, material)
    -- average resources of a normal wreckage in the game, per 1 volume
    -- calculated via SalvageCommand:volumeAndHPAnalysis(shipSamples)
    local resourcesPerVolume = 13.87

    local resourcesPerWreckage = resourcesPerVolume * volume -- average yield of a normal wreckage in the game

    local refined = properties.refinedEfficiency * properties.refinedEfficiencyWeight * resourcesPerWreckage
    local raw = properties.rawEfficiency * properties.rawEfficiencyWeight * resourcesPerWreckage
    local credits = resourcesPerWreckage * Material(material - 1).costFactor * 0.1

    return refined, raw, credits
end

function SalvageCommand:calculatePrediction(ownerIndex, shipName, area, config)

    -- times to do things
    local timeToFly = 25 -- estimation, time to fly between wreckages
    local timeToFindSector = 180 -- estimation, time it takes to find the next wreckage sector
    local timeToTravelRefine = 300 -- estimation, time it takes to fly to a refinery, dock, undock and return (without refining)

    local wreckagesPerField = 6 -- every this many wreckages it takes some time to fly to a new wreckage sector
    local captainCut = 0.1 -- captain takes 10% of the yield
    local hourlyBonus = 0.005 -- each hour of duration increases the yield by 1%, so it doesn't just scale linearly -> encourage players to send captains away longer

    -- weigh by free play settings
    local resourceWreckageFactor = GameSettings().resourceWreckageFactor
    if resourceWreckageFactor > 1 then
        timeToFly = lerp(resourceWreckageFactor, 1, 5, 25, 5)
        wreckagesPerField = lerp(resourceWreckageFactor, 1, 5, 6, 36)
    elseif resourceWreckageFactor < 1 then
        timeToFly = lerp(resourceWreckageFactor, 1, 0.1, 25, 250)
        wreckagesPerField = lerp(resourceWreckageFactor, 1, 0.1, 6, 1)
    end

    local centralFactionSectorWeight = 0.15
    local outerFactionSectorWeight = 0.4
    local nonFactionSectorWeight = 1.0
    local metalsRefinedPerSecond = 2000
    local maxCarriableMetals = 5 * 60 * metalsRefinedPerSecond -- refine time of 5 minutes
    local refineryTax = 0.08 -- refining takes up 8% of the scrap metals

    local simultaneousPerFighters = 6 -- can salvage one more wreckage per 6 fighters
    local maxSimultaneous = 8 -- can salvage this many wreckage at the same time, wreckages are rather spread out usually

    local totalTime = config.duration * 3600 -- duration in hours to time in seconds

    local x = (area.upper.x + area.lower.x) / 2
    local y = (area.upper.y + area.lower.y) / 2

    local generator = SectorGenerator(x, y)
    local cargoChance = generator.chanceForGoodsInWreckage
    local strippedChance = 1.0 - generator.chanceForUnstrippedWreckage
    local strippedDiminishing = 0.2 -- stripped wreckages only have 20% of their initial value

    local results = self:getPredictableValues()
    local properties = self:getSalvagingProperties(ownerIndex, shipName)
    results.properties = properties
    results.attackChance.value = 0
    results.averageTimeToSalvage = 60

    results.yields[0].from = 0
    results.yields[0].to = 0

    for i = 1, NumMaterials() do
        local yield = results.yields[i]
        yield.to = 0
        yield.from = 0
    end

    results.items = {from = 0, to = 0}
    results.cargos = {}

    if not properties.rawSalvaging and not properties.refinedSalvaging then
        if properties.noStartPositions then
            results.error = "No start positions for fighters!"%_t
        elseif properties.missingSquadSubsystems then
            results.error = "Not enough squad control subsystems for fighters!"%_t
        elseif properties.notEnoughPilots then
            results.error = "Not enough pilots for all fighters!"%_t
        else
            results.error = "The ship has no salvaging equipment!"%_T
        end

        return results
    end

    -- if we carry so much scrap metal that refining would take over 80% of the time to salvage, we abort
    -- player should issue a refine command instead
    local maxstartingMetals = totalTime * metalsRefinedPerSecond * 0.8
    if properties.startingMetals > maxstartingMetals then
        results.error = "There's so much ore or scrap metal on board that refining it would take more time than the entire salvage operation!"%_t
        return results
    end

    if area.analysis.reachable == 0 then
        results.error = "There are no sectors to salvage in in this area!"%_t
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
    local averageVolume = area.analysis.volume
    local discoveredWrecks = area.analysis.wrecks or 0
    local attackChanceModification = nil

    -- safe mode means that only faction sectors will be visited to avoid attacks at all costs
    -- but also faction sectors with factions we're at war with will be avoided as well
    if config.safeMode then
        outerFactionSectorWeight = outerFactionSectorWeight / 3
        centralFactionSectorWeight = centralFactionSectorWeight / 1.5

        materials = area.analysis.safeMaterials
        discoveredWrecks = area.analysis.safeWrecks or 0
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

        averageVolume = area.analysis.safeVolume

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
        results.error = "There are no sectors to salvage in in this area!"%_t
        return results
    end

    local efficiency = (nonFactionSectors * nonFactionSectorWeight + centralFactionSectors * centralFactionSectorWeight + outerFactionSectors * outerFactionSectorWeight) /
            (nonFactionSectors + centralFactionSectors + outerFactionSectors)

    local areaBoost = math.min(0.2, round(discoveredWrecks / 50) / 100)
    efficiency = math.min(1, efficiency + areaBoost)

    local metal = goods["Scrap Iron"] -- all scrap metals have the same size, doesn't matter which one we choose here
    local maxScrapMetal = math.min(maxCarriableMetals, properties.cargoSpace / metal.size)

    if properties.rawSalvaging and maxScrapMetal <= 2000 then
        results.error = "There isn't enough space in our cargo bay for more scrap metal!"%_t
        return results
    end

    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local captain = entry:getCaptain()

    if captain:hasPerk(CaptainUtility.PerkType.Navigator) then -- navigator finds a new sector faster
        timeToFindSector = timeToFindSector + CaptainUtility.getSalvagingPerkImpact(captain, CaptainUtility.PerkType.Navigator)
    end

    if captain:hasPerk(CaptainUtility.PerkType.Reckless) then -- reckless captain just jumps into sectors without caring -> faster
        timeToFindSector = timeToFindSector + CaptainUtility.getSalvagingPerkImpact(captain, CaptainUtility.PerkType.Reckless)
    end

    if captain:hasPerk(CaptainUtility.PerkType.Careful) then -- careful captain takes longer to find a sector they deem secure
        timeToFindSector = timeToFindSector + CaptainUtility.getSalvagingPerkImpact(captain, CaptainUtility.PerkType.Careful)
    end

    if captain:hasPerk(CaptainUtility.PerkType.Disoriented) then -- disoriented captain doesn't remember where they went
        timeToFindSector = timeToFindSector + CaptainUtility.getSalvagingPerkImpact(captain, CaptainUtility.PerkType.Disoriented)
    end

    if captain:hasPerk(CaptainUtility.PerkType.Addict) then -- addict takes longer for everything due to their sickness
        timeToFindSector = timeToFindSector + CaptainUtility.getSalvagingPerkImpact(captain, CaptainUtility.PerkType.Addict)
    end

    if captain:hasPerk(CaptainUtility.PerkType.Commoner) then -- commoner knows how to talk to people and thus reduce refinery tax
        refineryTax = refineryTax * CaptainUtility.getSalvagingPerkImpact(captain, CaptainUtility.PerkType.Commoner)
    end

    if captain:hasPerk(CaptainUtility.PerkType.Noble) then -- noble looks like money and will always have to pay a higher refinery tax
        refineryTax = refineryTax * CaptainUtility.getSalvagingPerkImpact(captain, CaptainUtility.PerkType.Noble)
    end

    if captain:hasPerk(CaptainUtility.PerkType.Connected) then -- connected knows everybody and can call in favors to reduce refinery tax
        refineryTax = refineryTax * CaptainUtility.getSalvagingPerkImpact(captain, CaptainUtility.PerkType.Connected)
    end

    -- cap at 30s
    timeToFindSector = math.max(30, timeToFindSector)
    -- cap at 10s
    timeToFly = math.max(10, timeToFly)

    -- area efficiency influences the time it takes to find wreckages
    timeToFindSector = timeToFindSector / efficiency
    timeToFly = timeToFly / efficiency

    local gatheredResources = {}
    for i = 0, NumMaterials() do
        gatheredResources[i] = 0
    end

    local cargos = {}
    local cargoSpaceForGoods = properties.cargoSpace
    local cargoSpaceOccupiedByGoods = 0
    local cargoWreckageCounter = 0.5

    -- Take care here, simultaneous ONLY AFFECTS FLYING. For everything else, all other rules still apply.
    -- Salvaging 6 wrecks at the same time still requires damaging the 6 wrecks with the current DPS
    local simultaneousWreckages = math.min(maxSimultaneous, 1 + math.floor(properties.fighters / simultaneousPerFighters))
    local simultaneousCounter = simultaneousWreckages

    -- for a fixed prediction it's necessary to have a static random number generator for deterministic numbers
    -- there is also the need for a second RNG so that wreckage material probability is always deterministic
    local random = Random(Seed("random_salvage" .. tostring(x) .. "_" .. tostring(y) .. captain.name))

    local time = totalTime

    -- if raw salvaging is enabled, the ship must go refine at the end
    -- to keep things simple, we'll remove the refining time at the beginning
    if properties.rawSalvaging then
        time = time - (maxCarriableMetals * 0.5 / metalsRefinedPerSecond)
        time = time - timeToTravelRefine

        -- cargo space available for salvaged goods is only half if we're doing raw salvaging
        -- we have to keep space for scrap metal
        cargoSpaceForGoods = cargoSpaceForGoods / 2
    end

    local captainResourcesBonus = 0.0
    local captainMoneyBonus = 0.0
    local captainItemBonus = 0.0
    local captainCargoBonus = 0.0
    if captain:hasClass(CaptainUtility.ClassType.Scavenger) then
        captainResourcesBonus = 0.1
        captainMoneyBonus = 0.5
        captainItemBonus = 0.25
        captainCargoBonus = 0.25

        wreckagesPerField = wreckagesPerField + 7 * efficiency
    end

    -- init simulation
    local wreckagesSalvaged = 0
    local wreckagesRemainingInField = wreckagesPerField
    local currentScrap = properties.startingMetals
    local totalTimesRefined = 0

    -- find a wreckage field
    time = time - timeToFindSector
    while time > 0 do

        -- 'locate' a wreck
        -- fly to the wreck, but if we can salvage several wrecks simultaneously through fighters, we don't take up time to fly to the next one
        simultaneousCounter = simultaneousCounter - 1
        if simultaneousCounter <= 0 then
            simultaneousCounter = simultaneousWreckages

            -- time to fly to the wreck
            time = time - timeToFly
        end

        -- many wreckages have already been stripped for parts and won't yield much
        local stripped = random:test(strippedChance)

        -- salvage the wreck
        -- wrecks are made up of various materials, to have a more evened out income from salvaging
        for material, weight in pairs(materials) do
            local materialProperties = properties.materials[material]

            -- check if we can and want to salvage the material
            if weight > 0 and materialProperties.dps > 0 and config.collected[material - 1] then

                local timeToSalvage = self:calculateTimeToSalvageWreckage(averageVolume * weight, materialProperties.dps, material)
                time = time - timeToSalvage

                local refined, scrap, credits = self:calculateGatheredResources(averageVolume * weight, materialProperties, material)
                if stripped then -- many wreckages have already been stripped for parts and won't yield many resources
                    refined = refined * strippedDiminishing
                    scrap = scrap * strippedDiminishing
                    credits = credits * strippedDiminishing
                end

                -- money can just be accumulated
                gatheredResources[0] = gatheredResources[0] + credits

                -- for scrap metal, only count scrap metal that the ship can carry
                local before = currentScrap
                currentScrap = math.min(currentScrap + scrap, maxScrapMetal)
                local scrapGained = currentScrap - before

                gatheredResources[material] = gatheredResources[material] + refined + scrapGained * (1 - refineryTax) -- refinery tax

                -- the sum of the material weights is 1, so this makes sense
                wreckagesSalvaged = wreckagesSalvaged + weight
            end
        end

        -- for things like aiming at the various blocks, turrets moving, collecting resources, etc.
        local baseTime = 15
        time = time - baseTime

        -- increase cargo wreckage counter and collect cargo of the wreckage if there is any
        -- increasing the counter instead of rolling a dice leads to more stable results
        cargoWreckageCounter = cargoWreckageCounter + cargoChance
        if cargoWreckageCounter > 1.0 then
            cargoWreckageCounter = cargoWreckageCounter - 1.0

            local maxVolume = math.min(100, cargoSpaceForGoods)
            local maxValue = random:getInt(500, 3000) * Balancing_GetSectorRichnessFactor(x, y)
            maxValue = maxValue + maxValue * captainCargoBonus

            local good = randomEntry(random, uncomplicatedSpawnableGoods)
            local amount = math.floor(math.min(maxValue / good.price, maxVolume / good.size))

            table.insert(cargos, {time = totalTime - time, name = good.name, amount = amount})

            cargoSpaceForGoods = cargoSpaceForGoods - amount * good.size
            cargoSpaceOccupiedByGoods = cargoSpaceOccupiedByGoods + amount * good.size

            maxScrapMetal = math.min(maxCarriableMetals, (properties.cargoSpace - cargoSpaceOccupiedByGoods) / metal.size)
        end


        -- if the cargo bay is full, refine
        if currentScrap > 0 and currentScrap >= maxScrapMetal then
            -- measure times it's necessary to refine
            totalTimesRefined = totalTimesRefined + 1

            time = time - (currentScrap / metalsRefinedPerSecond)
            currentScrap = 0
            time = time - timeToTravelRefine
        end

        wreckagesRemainingInField = wreckagesRemainingInField - 1

        -- every X wrecks, find a new field
        if wreckagesRemainingInField <= 0 then
            wreckagesRemainingInField = wreckagesRemainingInField + wreckagesPerField
            time = time - timeToFindSector
        end
    end

    if currentScrap > 0 then
        -- measure times it's necessary to refine
        totalTimesRefined = totalTimesRefined + 1
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

    for i = 0, NumMaterials() do
        -- each hour of duration slightly increases the amount, so it doesn't just scale linearly
        -- this should encourage players to send their captains away for a longer time
        gatheredResources[i] = gatheredResources[i] + gatheredResources[i] * (config.duration - 1) * hourlyBonus

        -- captain bonus
        local bonus = captainResourcesBonus
        if i == 0 then bonus = captainMoneyBonus end
        gatheredResources[i] = gatheredResources[i] + (gatheredResources[i] * bonus)

        -- captain takes a cut
        gatheredResources[i] = gatheredResources[i] * (1.0 - captainCut)

        if captain:hasPerk(CaptainUtility.PerkType.Gambler) then
            local gamblerReduction = 0.1 -- reduction of 10%
            gatheredResources[i] = gatheredResources[i] * (1.0 - gamblerReduction)
        end

        -- final yield
        local yield = results.yields[i]
        yield.to = round(gatheredResources[i] * specialGoodsFactor) -- reduce the yield when carrying special goods
        yield.from = round(yield.to * 0.8)
    end

    local maxVolume = Balancing_GetSectorShipVolume(0, 0)
    local items = math.floor(wreckagesSalvaged * 1.25 * math.min(1, averageVolume / maxVolume))
    items = math.min(items, 15 * config.duration)
    items = items + (items * captainItemBonus)
    items = items * specialGoodsFactor -- reduce the yield when carrying special goods

    results.items = {from = math.floor(items * 0.75), to = items}

    results.cargos = cargos

    -- calculate efficiencies
    -- area efficiency
    local total = nonFactionSectors + centralFactionSectors + outerFactionSectors
    local nonFaction = round((nonFactionSectors * nonFactionSectorWeight) / total * 100)
    local outer = round((outerFactionSectors * outerFactionSectorWeight) / total * 100)
    local central = round((centralFactionSectors * centralFactionSectorWeight) / total * 100)
    local uncoveredWrecks = round(areaBoost * 100)
    uncoveredWrecks = math.min(100 - (nonFaction + outer + central), uncoveredWrecks)

    results.areaEfficiency = nonFaction + outer + central
    results.areaEfficiencyBreakdown = {
        nonFaction = nonFaction,
        outer = outer,
        central = central,
        wrecks = uncoveredWrecks,
        total = total
    }

    -- salvaging speed
    local averageTimeToSalvage = 0
    local maximumAchievable = 0
    for material, weight in pairs(materials) do
        if weight > 0 then
            local materialProperties = properties.materials[material]
            if materialProperties.dps > 0 then
                local timeToSalvage, complexityTime = self:calculateTimeToSalvageWreckage(averageVolume * weight, materialProperties.dps, material)
                averageTimeToSalvage = averageTimeToSalvage + timeToSalvage
                maximumAchievable = maximumAchievable + complexityTime
            end
        end
    end

    results.speedEfficiency = lerp(averageTimeToSalvage, 180, maximumAchievable + 5, 0.01, 1)

    -- efficiency for cargo is trickier
    if properties.rawSalvaging then
        if totalTimesRefined == 1 or maxScrapMetal >= maxCarriableMetals then
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
        results.parallelEfficiency = lerp(simultaneousWreckages, 0, maxSimultaneous, 0, 1)
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

            results.items.from = results.items.from + prediction.items.from
            results.items.to = results.items.to + prediction.items.to
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
        results.error = "This salvage operation won't yield any resources!"%_t
    end

    return results
end

function SalvageCommand:generateAssessmentFromPrediction(prediction, captain, ownerIndex, shipName, area, config)

    -- please don't just copy this function. It's specific to the salvage command.
    -- use it as a guidance, but don't just use the same sentences etc.

    local total = area.analysis.sectors - area.analysis.unreachable
    if total == 0 then return "There is nothing to salvage in this area!"%_t end

    local pirateSectorRatio = SimulationUtility.calculatePirateAttackSectorRatio(area)
    local attackChance = prediction.attackChance.value

    local resourceLines = {}
    if pirateSectorRatio >= 0.75 then
        table.insert(resourceLines, "There are a lot of wrecks in this area. We will be able to recover a lot of resources here."%_t)
    elseif pirateSectorRatio >= 0.45 then
        table.insert(resourceLines, "There are quite some wrecks here. We will be able to salvage some resources."%_t)
    elseif pirateSectorRatio >= 0.05 then
        table.insert(resourceLines, "\\c(dd5)There are few wrecks in this area. We may not find too much here.\\c()"%_t)
    else
        table.insert(resourceLines, "\\c(d93)Because this area is safer, there are very few wrecks here. We will have to see what we can find.\\c()"%_t)
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

    local armedLines = {}
    if prediction.properties.armedSalvaging then
        table.insert(armedLines, "\\c(d93)For salvaging, we will use our weapons. That works, but real salvaging lasers would be much more efficient.\\c()"%_t)
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

    local attackLines = SimulationUtility.getAttackAssessmentLines(attackChance)
    local underRadar, returnLines = SimulationUtility.getDisappearanceAssessmentLines(attackChance)

    local rnd = Random(Seed(captain.name))

    return {
        randomEntry(rnd, resourceLines),
        randomEntry(rnd, cargobayLines),
        randomEntry(rnd, armedLines),
        randomEntry(rnd, fighterLines),
        randomEntry(rnd, pirateLines),
        randomEntry(rnd, attackLines),
        randomEntry(rnd, underRadar),
        randomEntry(rnd, returnLines),
        randomEntry(rnd, deliveries),
    }
end

function SalvageCommand:buildUI(startPressedCallback, changeAreaPressedCallback, recallPressedCallback, configChangedCallback)
    local ui = {}
    ui.orderName = "Scrap"%_t
    ui.icon = SalvageCommand:getIcon()

    local size = vec2(600, 670)

    ui.window = GalaxyMap():createWindow(Rect(size))
    ui.window.caption = "Salvaging Operation"%_t

    ui.commonUI = SimulationUtility.buildCommandUI(ui.window, startPressedCallback, changeAreaPressedCallback, recallPressedCallback, configChangedCallback, {areaHeight = 130, configHeight = 40, changeAreaButton = true})

    -- this command has yields and config in the same section
    local configValues = self:getConfigurableValues()
    local predictable = self:getPredictableValues()

--    local hsplitConfig = UIHorizontalSplitter(ui.commonUI.configRect, 10, 10, 0.15)

    local vsplitConfig = UIVerticalSplitter(ui.commonUI.configRect, 30, 00, 0.55)

    local vsplitSliderTime = UIVerticalSplitter(vsplitConfig.left, 20, 0, 0.25)
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
    ui.immediateDeliveryCheckBox.tooltip = "Send resources directly to your account."%_t
    ui.immediateDeliveryCheckBox.fontSize = 13

    -- yields
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

    local vsplitYields = UIVerticalSplitter(vlist:nextRect(15), 5, 0, 0.65)
    ui.window:createLabel(vsplitYields.left, "Damage Efficiency:"%_t, 12)
    ui.speedLabel = ui.window:createLabel(vsplitYields.right, "90%"%_t, 12)
    ui.speedLabel:setCenterAligned()

    local vsplitYields = UIVerticalSplitter(vlist:nextRect(15), 5, 0, 0.65)
    ui.window:createLabel(vsplitYields.left, "Cargo Space:"%_t, 12)
    ui.cargoBayLabel = ui.window:createLabel(vsplitYields.right, "80%"%_t, 12)
    ui.cargoBayLabel:setCenterAligned()

    local vsplitYields = UIVerticalSplitter(vlist:nextRect(15), 5, 0, 0.65)
    ui.window:createLabel(vsplitYields.left, "Simultaneous Salvaging:"%_t, 12)
    ui.parallelLabel = ui.window:createLabel(vsplitYields.right, "15%"%_t, 12)
    ui.parallelLabel:setCenterAligned()
    ui.parallelLabel.tooltip = "Simultaneous Salvaging: The ship is able to salvage several wrecks at the same time using fighters."%_t

    vlist:nextRect(5)

    local vsplitMoney = UIVerticalSplitter(vlist:nextRect(15), 10, 0, 0.65)
    ui.window:createLabel(vsplitMoney.left, predictable.yields[0].displayName .. ":", 12)
    ui.moneyLabel = ui.window:createLabel(vsplitMoney.right, "", 12)
    ui.moneyLabel:setCenterAligned()

    local vsplitItems = UIVerticalSplitter(vlist:nextRect(15), 10, 0, 0.65)
    local hlistItems = UIHorizontalLister(vsplitItems.left, 5, 0)
    local icon1 = ui.window:createPicture(hlistItems:nextQuadraticRect(), "data/textures/icons/turret.png")
    local icon2 = ui.window:createPicture(hlistItems:nextQuadraticRect(), "data/textures/icons/circuitry.png")
    local icon3 = ui.window:createPicture(hlistItems:nextQuadraticRect(), "data/textures/icons/turret.png")
    local icon4 = ui.window:createPicture(hlistItems:nextQuadraticRect(), "data/textures/icons/circuitry.png")

    icon2.color = Rarity(RarityType.Uncommon).color
    icon3.color = Rarity(RarityType.Rare).color
    icon4.color = Rarity(RarityType.Exceptional).color

    for _, icon in pairs({icon1, icon2, icon3, icon4}) do
        icon.isIcon = true
    end

    ui.itemsLabel = ui.window:createLabel(vsplitItems.right, "", 12)
    ui.itemsLabel:setCenterAligned()

    local vsplitItems = UIVerticalSplitter(vlist:nextRect(15), 10, 0, 0.65)
    local hlistItems = UIHorizontalLister(vsplitItems.left, 5, 0)
    local icon1 = ui.window:createPicture(hlistItems:nextQuadraticRect(), "data/textures/icons/crate.png")

    icon1.isIcon = true

    ui.cargoLabel = ui.window:createLabel(vsplitItems.right, "?", 12)
    ui.cargoLabel:setCenterAligned()

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
            local values = SalvageCommand:getConfigurableValues(ownerIndex, shipName)

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
        local prediction = SalvageCommand:calculatePrediction(ownerIndex, shipName, area, config)
        self:displayPrediction(prediction, config, ownerIndex)

        self.commonUI:refreshPredictions(ownerIndex, shipName, area, config, SalvageCommand, prediction)
    end

    ui.displayPrediction = function(self, prediction, config, ownerIndex)
        self.durationLabel.caption = string.format("%s h"%_t, config.duration)

        self.moneyLabel.caption = string.format("¢%s - ¢%s", toReadableNumber(prediction.yields[0].from, 1), toReadableNumber(prediction.yields[0].to, 1))
        self.itemsLabel.caption = string.format("%s - %s", toReadableNumber(prediction.items.from, 0), toReadableNumber(prediction.items.to, 0))

        for i = 1, NumMaterials() do
            self.materialLines[i].amountLabel:hide()
            self.materialLines[i].textLabel:hide()
            self.materialLines[i].checkBox:hide()
        end

        local c = 1
        for i = 1, NumMaterials() do
            if prediction.yields[i].from > 0 or prediction.yields[i].to > 0 or not config.collected[i-1] then
                local material = Material(i - 1)

                self.materialLines[c].amountLabel:show()
                self.materialLines[c].textLabel:show()
                self.materialLines[c].checkBox:show()
                self.materialLines[c].checkBox:setCheckedNoCallback(config.collected[i - 1])
                self.materialLines[c].material = material

                self.materialLines[c].amountLabel.caption = string.format("%s - %s", toReadableNumber(prediction.yields[i].from, 1), toReadableNumber(prediction.yields[i].to, 1))
                self.materialLines[c].textLabel.caption = material.name
                self.materialLines[c].textLabel.color = material.color
                self.materialLines[c].amountLabel.color = material.color

                self.materialLines[c].textLabel.strikethrough = not config.collected[i-1]
                self.materialLines[c].amountLabel.strikethrough = not config.collected[i-1]

                if not config.collected[i-1] then
                    self.materialLines[c].amountLabel.caption = "    "
                end

                c = c + 1
            end
        end

        if c == 1 then
            self.materialLines[3].textLabel.color = ColorRGB(0.9, 0.9, 0.9)
            self.materialLines[3].textLabel.caption = "No salvaging possible"%_t
            self.materialLines[3].textLabel:show()
        end

        if prediction.speedEfficiency then
            self.speedLabel.caption = tostring(math.floor(prediction.speedEfficiency * 100)) .. "%"
            self.speedLabel.tooltip = "Damage Efficiency: More fire power, more salvaging! But this doesn't scale up endlessly. Any ship will eventually reach the point where flying and navigating takes longer than salvaging."%_t

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

            if prediction.areaEfficiencyBreakdown.wrecks > 0 then
                table.insert(breakdown, "- Discovered Wrecks: +${value}%"%_t % {value = prediction.areaEfficiencyBreakdown.wrecks})
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
    end

    return ui
end

-- this is an analysis that checks how big wreckages are usually and how much HP they have (HP are independent of material)
-- these values are then used in above estimations to keep them fast (we don't want to generate ships each time we run the prediction calculation)
function SalvageCommand:volumeAndHPAnalysis(shipSamples)
    shipSamples = shipSamples or 100

    local distances = {550, 500, 450, 400, 350, 300, 250, 200, 150, 100, 50, 0}

    -- using trinium since that has most block types available
    -- material doesn't make a difference for the harvest factor of blocks
    local material = Material(MaterialType.Trinium)

    local durabilityPerVolumeAverages = {}
    local harvestablePerVolumeAverages = {}

    for _, distance in pairs(distances) do
        local x = math.floor(math.sqrt(distance * distance / 2))
        local y = x

        print ("### At %i:%i, Distance: %i ###", x, y, distance)

        for r = 1, 5 do
            print ("run #%i, generating ships ...", r)

            local volume = 0
            for i = 1, 10000 do
                local shipVolume = Balancing_GetSectorShipVolume(x, y)
                local deviation = Balancing_GetShipVolumeDeviation(random():getFloat())
                volume = volume + shipVolume * deviation
            end

            volume = volume / 10000


            local harvestableAvg = 0
            local durabilityAvg = 0
            for k = 1, shipSamples do
                local faction = Galaxy():getNearestFaction(random():getInt(-450, 450), random():getInt(-450, 450))

                local style = nil
                if k % 2 == 0 then
                    style = PlanGenerator.getShipStyle(faction)
                else
                    style = PlanGenerator.getFreighterStyle(faction)
                end

                local plan = GeneratePlanFromStyle(style, random():createSeed(), volume, 5000, nil, material)

                local sum = 0
                for i = 0, plan.numBlocks - 1 do
                    local block = plan:getNthBlock(i)

                    sum = sum + block.harvestableResources
                end

                harvestableAvg = harvestableAvg + sum
                durabilityAvg = durabilityAvg + plan.durability / material.strengthFactor

            end

            harvestableAvg = harvestableAvg / shipSamples
            durabilityAvg = durabilityAvg / shipSamples

            table.insert(harvestablePerVolumeAverages, harvestableAvg / volume)
            table.insert(durabilityPerVolumeAverages, durabilityAvg / volume)

            print("volume: " .. math.floor(volume))
            print("harvestable avg: " .. math.floor(harvestableAvg))
            print("durability avg: " .. math.floor(durabilityAvg))
            print("harvestable / volume: " .. round(harvestableAvg / volume, 2))
            print("durability / volume: " .. round(durabilityAvg / volume, 2))
            print("")
        end
    end

    local totalHarvestable = 0
    local totalDurability = 0

    for _, value in pairs(harvestablePerVolumeAverages) do
        totalHarvestable = totalHarvestable + value
    end

    for _, value in pairs(durabilityPerVolumeAverages) do
        totalDurability = totalDurability + value
    end

    totalHarvestable = totalHarvestable / #harvestablePerVolumeAverages
    totalDurability = totalDurability / #durabilityPerVolumeAverages

    print ("total harvestable / volume avg: %d", round(totalHarvestable, 2))
    print ("total durability / volume avg: %d", round(totalDurability, 2))

end


return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
