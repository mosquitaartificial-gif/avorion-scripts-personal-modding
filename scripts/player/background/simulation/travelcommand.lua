package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/player/background/simulation/?.lua"

local CommandType = include ("commandtype")
local Balancing = include ("galaxy")
local SimulationUtility = include ("simulationutility")
local CaptainUtility = include ("captainutility")
local SectorSpecifics = include ("sectorspecifics")
include ("utility")
include ("stringutility")
include ("randomext")


local TravelCommand = {}
TravelCommand.__index = TravelCommand
TravelCommand.type = CommandType.Travel

local swiftnessSpeedFactors = {}
swiftnessSpeedFactors[0] = 0.2
swiftnessSpeedFactors[1] = 0.8
swiftnessSpeedFactors[2] = 1.0
swiftnessSpeedFactors[3] = 1.2

local swiftnessAttackFactors = {}
swiftnessAttackFactors[0] = 0.15
swiftnessAttackFactors[1] = 0.8
swiftnessAttackFactors[2] = 1.0
swiftnessAttackFactors[3] = 1.2

-- all commands need this kind of "new" to function within the bg simulation framework
-- it must be possible to call the command without any parameters to access some functionality
local function new(ship, area, config)
    local command = setmetatable({
        -- all commands need these variables to function within the bg simulation framework
        -- type contains the CommandType of the command, required to restore
        type = CommandType.Travel,

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
    }, TravelCommand)

    return command
end

-- all commands have the following functions, even if not listed here (added by Simulation script on command creation):
-- function TravelCommand:addYield(message, money, resources, items) end
-- function TravelCommand:finish() end
-- function TravelCommand:registerForAttack(coords, faction, timeOfAttack, message, arguments) end


-- you can return an error message here such as:
-- return "Command cannot initialize because %1% and %2% went wrong", {"Player", "Config"}
function TravelCommand:initialize()
    local parent = getParentFaction()
    local shipEntry = ShipDatabaseEntry(parent.index, self.shipName)
    local x, y = shipEntry:getCoordinates()
    if self.area.lower.x == x and self.area.lower.y == y then
        return "The ship is already in this sector."%_T
    end

    if #self.area.analysis.route <= 2 then
        return "This route is too short."%_T
    end

    local jumpRange, canPassRifts = shipEntry:getHyperspaceProperties()
    if jumpRange ~= self.area.analysis.values.jumpRange or canPassRifts ~= self.area.analysis.values.canPassRifts then
        return "Hyperspace properties changed since planning the route."%_T
    end

    local prediction = self:calculatePrediction(parent.index, self.shipName, self.area, self.config)

    self.data.origin = {x = x, y = y}
    self.data.destination = {x = self.area.lower.x, y = self.area.lower.y}
    self.data.travelTime = prediction.travelTime
    self.data.runTime = 0
end

-- this is the regularly called function to update the time passing while the command is running
-- timestep is typically a longer period, such as a minute
-- this function should be as lightweight as possible. best practice is to
-- only do count downs here and do all calculations during area analysis and initialization
function TravelCommand:update(timeStep)
    self.data.runTime = self.data.runTime + timeStep

    --print("runtime: " .. self.data.runTime .. ", travel time: " .. self.data.travelTime)
    if self.data.runTime >= self.data.travelTime then
        self:finish()
        return
    end
end

-- executed before an area analysis involving this type of command starts
-- return a table of sectors here to start a special analysis of those sectors instead of a rect
-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function TravelCommand:getAreaAnalysisSectors(results, meta)
    local shipEntry = ShipDatabaseEntry(meta.factionIndex, meta.shipName)

    local x, y = shipEntry:getCoordinates()
    local jumpRange, canPassRifts = shipEntry:getHyperspaceProperties()

    local origin = vec2(x, y)
    local destination = vec2(meta.area.lower.x, meta.area.lower.y)

    -- use tables, not vec2s since that might create issues when saving the results of the analysis to database
    results.origin = {x = origin.x, y = origin.y}
    results.destination = {x = destination.x, y = destination.y}

    -- save route in the area analysis so we have access to it later on
    local player, alliance
    local owner = Galaxy():findFaction(meta.factionIndex)
    if owner.isPlayer then
        player = owner
        alliance = player.alliance
    elseif owner.isAlliance then
        alliance = owner
    end

    results.route = calculateJumpPath(player, alliance, origin, destination, jumpRange, canPassRifts)

    results.values = {jumpRange = jumpRange, canPassRifts = canPassRifts}

    return results.route
end

-- executed when an area analysis involving this type of command starts
-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function TravelCommand:onAreaAnalysisStart(results, meta)
    -- cached to save performance
    meta.sectorSpecifics = SectorSpecifics()
    meta.selfFaction = Faction(meta.factionIndex)

    results.attackProbabilities = {}
    results.travelTimeFactors = {}
end

-- executed when an area analysis involving this type of command is checking a specific sector
-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function TravelCommand:onAreaAnalysisSector(results, meta, x, y, details)
    local attackProbability = self:calculateFactionAreaAttackProbability(x, y, meta.selfFaction, details)

    local timeFactor = 1
    local regular, offgrid = meta.sectorSpecifics.determineFastContent(x, y, GameSeed())
    if not regular and not offgrid then
        timeFactor = 1 / 3
    end

    table.insert(results.attackProbabilities, attackProbability)
    table.insert(results.travelTimeFactors, timeFactor)
end

function TravelCommand:calculateFactionAreaAttackProbability(x, y, selfFaction, details)
    local attackProbability = 0.5 -- no man's space
    if details.factionIndex and details.factionIndex ~= 0 then
        if selfFaction and selfFaction:getRelationStatus(details.factionIndex) == RelationStatus.War then
            if details.isCentralArea then
                attackProbability = 1 -- central faction area (at war)
            else
                attackProbability = 0.4 -- outer faction area (at war)
            end
        else
            if details.isCentralArea then
                attackProbability = 0 -- central faction area (not at war)
            else
                attackProbability = 0.3 -- outer faction area (not at war)
            end
        end
    end

    return attackProbability
end

-- executed when an area analysis involving this type of command finished
-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function TravelCommand:onAreaAnalysisFinished(results, meta)
    -- don't show reachable coordinates for the travel command on the map
    -- the exact route is hidden from the player
    for i, sector in pairs(results.reachableCoordinates) do
        sector.hidden = true
    end

    -- only the destination sector should be visible on the map
    table.insert(results.reachableCoordinates, {x = results.destination.x, y = results.destination.y, faction = 0})
end

-- executed when the command starts for the first time (not when being restored)
-- do things like paying money in here and return errors when it's not possible because the player doesn't have enough money
-- you can return an error message here such as:
-- return "Command cannot start because %1% doesn't fulfill requirement '%2%'!", {"Player", "Money"}
function TravelCommand:onStart()
    if not self.simulation.disableAttack then -- for unit tests
        local timeOfAttack, x, y, factionIndex = self:calculateAttack(getParentFaction().index, self.shipName, self.config, self.area)
--        print("time of attack: " .. tostring(timeOfAttack) .. ", sector (${x}:${y})"%{x=x, y=y} .. ", faction: " .. factionIndex)

        if timeOfAttack ~= nil then
            self:registerForAttack({x = x, y = y}, nil, timeOfAttack, "Your ship '%1%' is under attack in sector \\s(%2%:%3%)!"%_t, {self.shipName, x, y})
        end
    end
end

function TravelCommand:calculateAttack(ownerIndex, shipName, config, area)
    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local captain = entry:getCaptain()
    local attackProbability = self:calculateAttackProbability(ownerIndex, shipName, area, config, captain)

    if not random():test(attackProbability) then
        -- no attack, return nothing
        return
    end

    -- compute strength values that are independent of the current sector
    local strengthValues = self:calculateShipAndCaptainStrengthValues(ownerIndex, shipName, config.escorts)
    local probabilities = area.analysis.attackProbabilities

    local attackProbabilityWeights = {}
    for i = 2, #probabilities do
        local sector = area.analysis.reachableCoordinates[i]
        attackProbabilityWeights[i] = self:calculateAttackProbabilitySingleSector(sector.x, sector.y, probabilities[i], strengthValues, captain)
    end

    -- choose the sector where the attack happens
    local attackIndex = selectByWeight(random(), attackProbabilityWeights)

    -- calculate the time of attack
    local travelTimeFactors = area.analysis.travelTimeFactors
    local timeOfAttack = 0
    for i = 1, attackIndex do
        timeOfAttack = timeOfAttack + travelTimeFactors[i]
    end

    local timeFactor = self:calculateFixedTimeFactor(ownerIndex, shipName, config, captain)
    timeOfAttack = timeOfAttack * timeFactor

    local sector = area.analysis.reachableCoordinates[attackIndex]
    return timeOfAttack, sector.x, sector.y, sector.faction
end

function TravelCommand:calculateShipAndCaptainStrengthValues(ownerIndex, shipName, escorts)
    local travellingShips = {shipName}
    for _, escort in pairs(escorts or {}) do
        table.insert(travellingShips, escort)
    end

    local selfDps = 0
    local selfHP = 0
    local probabilityOffset = 0
    local probabilityFactor = 1

    local commodores = 0
    local recklessCaptains = 0
    local carefulCaptains = 0

    for _, name in pairs(travellingShips) do
        local entry = ShipDatabaseEntry(ownerIndex, name)
        if not entry then goto continue end

        local turretDps, fighterDps = entry:getDPSValues()
        local maxHP = entry:getDurabilityProperties()
        local maxShields = entry:getShields()

        local dps = turretDps + fighterDps
        local hp = maxHP + maxShields

        local captain = entry:getCaptain()
        if captain:hasPerk(CaptainUtility.PerkType.Noble) then
            dps = dps * 1.1
            hp = hp * 1.1
        end

        if captain:hasPerk(CaptainUtility.PerkType.Commoner) then
            dps = dps * 0.9
            hp = hp * 0.9
        end

        selfDps = selfDps + dps
        selfHP = selfHP + hp

        if captain:hasClass(CaptainUtility.ClassType.Commodore) then
            commodores = commodores + 1
            if commodores == 1 then
                probabilityOffset = probabilityOffset - 0.15
            else
                probabilityFactor = probabilityFactor * 0.85
            end
        end

        if captain:hasPerk(CaptainUtility.PerkType.Reckless) then
            recklessCaptains = recklessCaptains + 1
            if recklessCaptains == 1 then
                probabilityOffset = probabilityOffset + 0.05
            else
                probabilityFactor = probabilityFactor * 1.05
            end
        end

        if captain:hasPerk(CaptainUtility.PerkType.Stealthy) then
            local reduction = lerp(captain.level, 0, 5, 0.01, 0.06)
            probabilityFactor = probabilityFactor * (1 - reduction)
        end

        if captain:hasPerk(CaptainUtility.PerkType.Careful) then
            carefulCaptains = carefulCaptains + 1
            if carefulCaptains == 1 then
                probabilityOffset = probabilityOffset - 0.05
            else
                probabilityFactor = probabilityFactor * 0.95
            end
        end

        if captain:hasPerk(CaptainUtility.PerkType.Intimidating) then
            local reduction = lerp(captain.level, 0, 5, 0.01, 0.06)
            probabilityFactor = probabilityFactor * (1 - reduction)
        end

        if captain:hasPerk(CaptainUtility.PerkType.Arrogant) then
            local increase = lerp(captain.level, 0, 5, 0.06, 0.01)
            probabilityFactor = probabilityFactor * (1 + increase)
        end

        if captain:hasPerk(CaptainUtility.PerkType.Cunning) then
            local reduction = lerp(captain.level, 0, 5, 0.01, 0.06)
            probabilityFactor = probabilityFactor * (1 - reduction)
        end

        if captain:hasPerk(CaptainUtility.PerkType.Harmless) then
            local increase = lerp(captain.level, 0, 5, 0.06, 0.01)
            probabilityFactor = probabilityFactor * (1 + increase)
        end

        ::continue::
    end

    return
    {
        selfDps = selfDps,
        selfHP = selfHP,
        probabilityOffset = probabilityOffset,
        probabilityFactor = probabilityFactor,
        otherDamageFactor = GameSettings().damageMultiplier
    }
end

function TravelCommand:calculateAttackProbabilitySingleSector(x, y, probability, strengthValues, captain)
    -- see persecutorutility.lua, modified because we don't have access to the entity here
    local otherHP = Balancing_GetSectorShipHP(x, y)
    local otherDps = Balancing_GetSectorWeaponDPS(x, y)
    otherDps = otherDps * Balancing_GetEnemySectorTurrets(x, y)
    otherDps = otherDps * strengthValues.otherDamageFactor

    local timeAlive = strengthValues.selfHP / (otherDps + 0.01)
    local timeToKill = otherHP / (strengthValues.selfDps + 10)

    local strengthFactor = lerp(timeAlive, timeToKill * 0.1, timeToKill * 0.5, 1, 0)
    probability = probability * strengthFactor

    return math.min(1, math.max(0, probability))
end

-- executed when the ship is being recalled by the player
function TravelCommand:onRecall()
    -- don't update the ship's coordinates if an attack is happening
    if self.data.attack and self.data.attack.countDown < 0 then return end

    local ownerIndex = getParentFaction().index
    local entry = ShipDatabaseEntry(ownerIndex, self.shipName)
    local captain = entry:getCaptain()

    -- calculate normalizedRunTime to be comparable to the values in travelTimeFactors
    local normalizedRunTime = self.data.runTime / self:calculateFixedTimeFactor(ownerIndex, self.shipName, self.config, captain)

    local index = 1
    for i, timeFactor in pairs(self.area.analysis.travelTimeFactors) do
        if normalizedRunTime < timeFactor then
            -- not enough time has passed to jump to the next sector
            index = i
            break
        end

        normalizedRunTime = normalizedRunTime - timeFactor
    end

    local location = self.area.analysis.route[index]
    entry:setCoordinates(location.x, location.y)
end

-- executed when the command is finished
function TravelCommand:onFinish()
    local faction = getParentFaction()
    local entry = ShipDatabaseEntry(faction.index, self.shipName)
    local numSectors = #self.area.analysis.route
    local lastSector = self.area.analysis.route[numSectors]
    entry:setCoordinates(lastSector.x, lastSector.y)

    faction:sendChatMessage(self.shipName, ChatMessageType.Information, "%1% has reached its destination and is awaiting your next orders in \\s(%2%:%3%)."%_T, self.shipName, lastSector.x, lastSector.y)
end

-- after this function was called, self.data will be read to be saved to database
function TravelCommand:onSecure()
end

-- this is called after the command was recreated and self.data was assigned
function TravelCommand:onRestore()
end

-- this is called when the beforehand calculated pirate or faction attack happens
-- called after notification of player and after attack script is added to the ship database entry
-- but before the ship and its escort is recalled from background
-- note: attackerFaction is nil in case of a pirate attack
function TravelCommand:onAttacked(attackerFaction, x, y)
end

function TravelCommand:getDescriptionText()
    local timeRemaining = math.ceil((self.data.travelTime - self.data.runTime) / 60) * 60
    local completed = math.floor(self.data.runTime / self.data.travelTime * 100)
    return "Travelling to (${x}:${y}).\n\nTime remaining: ${timeRemaining} (${completed} % done)."%_T,
            {x = self.area.lower.x, y = self.area.lower.y, timeRemaining = createReadableShortTimeString(timeRemaining), completed = completed}
end

function TravelCommand:getStatusMessage()
    return NamedFormat("Travelling to (${x}:${y}) /* ship AI status*/"%_T, {x = self.area.lower.x, y = self.area.lower.y})
end

function TravelCommand:getIcon()
    return "data/textures/icons/travel-command.png"
end

function TravelCommand:getRecallError()
end

-- returns whether there are errors with the command, either in the config, or otherwise
-- (ship has no mining turrets, not enough energy, player doesn't have enough money, etc.)
-- this function is also executed on the client and used to grey out the "start" button so players know that their config is flawed
-- note: before this is called, there is already a preliminary check based on getConfigurableValues(),
-- where values are clamped or default-set
function TravelCommand:getErrors(ownerIndex, shipName, area, config)
end


-- returns the size of the area where the command will run
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function TravelCommand:getAreaSize(ownerIndex, shipName)
    return {x = 1, y = 1}
end

-- returns the size of the area where the command is currently running
-- this is used to visualize where the command is running at the moment
-- we want to emphasize the captain's autonomy, so we don't show the current position but the destination
function TravelCommand:getAreaBounds()
    local line = {from = self.area.analysis.route[1], to = self.area.lower}
    return {lower = self.area.lower, upper = self.area.upper, lines = {line}}
end

function TravelCommand:isAreaFixed(ownerIndex, shipName)
    return false
end

-- returns whether the command requires the ship to be inside the selected area
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function TravelCommand:isShipRequiredInArea(ownerIndex, shipName)
    return false
end

-- returns whether the current selection on the galaxy map is acceptable
-- this is only necessary if there are any special cases outside the normal area selection
-- this is only called during the area selection phase on the client, not on the server.
-- to check this on the server, you have to check the area in the getErrors() function
-- note: this function definition is optional and can be omitted if it's not required
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function TravelCommand:isValidAreaSelection(ownerIndex, shipName, area, mouseCoordinates, passageMap)
    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local x, y = entry:getCoordinates()
    local reach, canPassRifts, cooldown = entry:getHyperspaceProperties()
    local d = distance(vec2(x, y), vec2(mouseCoordinates.x, mouseCoordinates.y))

    -- don't allow travel commands to sectors that are reachable with one jump
    if d <= reach and Galaxy():jumpRouteUnobstructed(x, y, mouseCoordinates.x, mouseCoordinates.y) then
        return false
    end

    -- don't allow travel commands to sectors that are directly reachable with one gate or wormhole
    local owner = Galaxy():findFaction(ownerIndex)
    local sectorView = owner:getKnownSector(x, y)
    if not sectorView and owner.isPlayer then
        if owner.alliance then
            sectorView = owner.alliance:getKnownSector(x, y)
        end
    end

    if sectorView then
        for _, coords in pairs({sectorView:getGateDestinations()}) do
            if coords.x == mouseCoordinates.x and coords.y == mouseCoordinates.y then return false end
        end

        for _, coords in pairs({sectorView:getWormHoleDestinations()}) do
            if coords.x == mouseCoordinates.x and coords.y == mouseCoordinates.y then return false end
        end
    end

    return true
end

-- returns the text that is shown in the tooltip while the player is selecting the area for the command
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function TravelCommand:getAreaSelectionTooltip(ownerIndex, shipName, area, valid)
    if valid then
        return "Left-Click: Select destination"%_t
    else
        return "Destination can be reached with a single jump!"%_t
    end
end

-- returns the configurable values for this command (if any).
-- variable naming should speak for itself, though you're free to do whatever you want in here.
-- config will only be used by the command itself and nothing else
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function TravelCommand:getConfigurableValues(ownerIndex, shipName)
    local values = { }

    -- value names here must match with values returned in ui:buildConfig() below
    values.swiftness = {displayName = "Swiftness"%_t, from = 0, to = 3, default = 2}

    return values
end

-- returns the predictable values for this command (if any).
-- variable naming should speak for itself, though you're free to do whatever you want in here.
-- config will only be used by the command itself and nothing else
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function TravelCommand:getPredictableValues()
    local values = { }

    values.attackChance = {displayName = SimulationUtility.AttackChanceLabelCaption}
    values.distance = {displayName = "Distance"%_t}
    values.travelTime = {displayName = "Travel Time"%_t}

    return values
end

function TravelCommand:calculateAttackProbability(ownerIndex, shipName, area, config, captain)
    local result = 1
    local probabilities = area.analysis.attackProbabilities

    -- compute strength values that are independent of the current sector
    local strengthValues = self:calculateShipAndCaptainStrengthValues(ownerIndex, shipName, config.escorts)

    -- skip the starting sector
    for i = 2, #probabilities do
        local sector = area.analysis.route[i]
        result = result * (1 - self:calculateAttackProbabilitySingleSector(sector.x, sector.y, probabilities[i], strengthValues, captain))
    end

    result = 1 - result

    result = result * strengthValues.probabilityFactor
    result = result + strengthValues.probabilityOffset

    -- higher swiftness means higher attack probability
    local swiftnessFactor = swiftnessAttackFactors[config.swiftness] or 1
    result = result * swiftnessFactor

    --print("attack probability: " .. result)

    return math.min(1, math.max(0, result))
end

function TravelCommand:calculateFixedTimeFactor(ownerIndex, shipName, config, captain)
    local balancingFactor = 1
    local swiftnessFactor = swiftnessSpeedFactors[config.swiftness] or 1

    local shipEntry = ShipDatabaseEntry(ownerIndex, shipName)
    local _, _, hyperspaceCooldown = shipEntry:getHyperspaceProperties()

    -- ship will have to spend at least 17s in each sector, that's 7 more than the fastest possible hyperspace cooldown allows
    local result = math.max(hyperspaceCooldown, 17) * balancingFactor / swiftnessFactor

    -- smuggler captains don't have to slow down when transporting special goods
    if not captain:hasClass(CaptainUtility.ClassType.Smuggler) then
        local stolenOrIllegal, dangerousOrSuspicious = SimulationUtility.getSpecialCargoCategories(shipEntry:getCargo())

        -- merchant captains don't have to slow down when transporting dangerous or suspicious goods
        if captain:hasClass(CaptainUtility.ClassType.Merchant) then
            dangerousOrSuspicious = false
        end

        if stolenOrIllegal or dangerousOrSuspicious then
            result = result * 1.15
        end
    end

    if captain:hasClass(CaptainUtility.ClassType.Explorer) then
        local explorerSpeedup = 0.1
        result = result * (1 - explorerSpeedup)
    end

    for _, perk in pairs({captain:getPerks()}) do
        result = result * (1 + CaptainUtility.getTravelPerkImpact(captain, perk))
    end

    return result
end

-- calculate the predictions for the ship, area and config
-- gut feeling says that each config option change should always be reflected in the predictions if it impacts the behavior
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function TravelCommand:calculatePrediction(ownerIndex, shipName, area, config)
    local results = self:getPredictableValues()

    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local captain = entry:getCaptain()

    local attackProbability = self:calculateAttackProbability(ownerIndex, shipName, area, config, captain)
    results.attackChance.value = attackProbability

    results.distance, results.travelTime = self:calculateTravelStats(ownerIndex, shipName, area.analysis, config, captain)

    return results
end

function TravelCommand:calculateTravelStats(ownerIndex, shipName, analysis, config, captain)
    local distance = 0
    local travelTime = 0

    local route = analysis.route
    local travelTimeFactors = analysis.travelTimeFactors
    for i = 1, #route - 1 do
        -- calculate distance
        local a = route[i]
        local b = route[i + 1]
        local dx = b.x - a.x
        local dy = b.y - a.y
        distance = distance + math.sqrt(dx * dx + dy * dy)

        -- calculate travel time
        -- the time for the last sector is not included because there is no jump after it
        travelTime = travelTime + travelTimeFactors[i]
    end

    travelTime = travelTime * self:calculateFixedTimeFactor(ownerIndex, shipName, config, captain)

    --print("travel time: " .. travelTime)

    return distance, travelTime
end

-- this will be called on a temporary instance of the command. all values written to "self" will not persist
function TravelCommand:buildUI(startPressedCallback, changeAreaPressedCallback, recallPressedCallback, configChangedCallback)
    local ui = {}
    ui.orderName = "Travel"%_t
    ui.icon = TravelCommand:getIcon()

    local size = vec2(620, 550)

    ui.window = GalaxyMap():createWindow(Rect(size))
    ui.window.caption = "Travel"%_t

    local settings =
    {
        configHeight = 15,
        changeAreaButton = true,
        changeAreaButtonIcon = "data/textures/icons/change-area-travel.png",
        changeAreaButtonTooltip = "Choose a different destination"%_t
    }
    ui.commonUI = SimulationUtility.buildCommandUI(ui.window, startPressedCallback, changeAreaPressedCallback, recallPressedCallback, configChangedCallback, settings)

    -- configurable values
    local configValues = self:getConfigurableValues()

    local splitter = UIVerticalMultiSplitter(ui.commonUI.configRect, 20, 0, 2)
    local label = ui.window:createLabel(splitter:partition(0), configValues.swiftness.displayName .. ":", 12)
    label:setRightAligned()
    label.tooltip = "Take a faster route that is more risky."%_t
    ui.swiftnessSlider = ui.window:createSlider(splitter:partition(1), configValues.swiftness.from, configValues.swiftness.to, 3, "", configChangedCallback)
    ui.swiftnessSlider.showValue = false
    ui.swiftnessLabel = ui.window:createLabel(splitter:partition(2), "", 12)

    -- yields & issues
    local predictable = self:getPredictableValues()

    local vlist = UIVerticalLister(ui.commonUI.predictionRect, 5, 0)
    local vsplitYields = UIVerticalSplitter(vlist:nextRect(15), 5, 0, 0.65)

    ui.assessmentLabel = ui.window:createLabel(vlist:nextRect(20), "", 12)

    -- attack chance
    local vsplitYields = UIVerticalSplitter(vlist:nextRect(15), 5, 0, 0.65)
    local label = ui.window:createLabel(vsplitYields.left, predictable.attackChance.displayName .. ":", 12)
    label.tooltip = SimulationUtility.AttackChanceLabelTooltip .. "\n\n" .. "Note: Traveling through even a small but dangerous area can increase attack chance dramatically!"%_t
    ui.commonUI.attackChanceLabel = ui.window:createLabel(vsplitYields.right, "", 12)
    ui.commonUI.attackChanceLabel:setRightAligned()

    -- distance
    local vsplitYields = UIVerticalSplitter(vlist:nextRect(15), 5, 0, 0.65)
    ui.window:createLabel(vsplitYields.left, predictable.distance.displayName .. ":", 12)
    ui.distanceLabel = ui.window:createLabel(vsplitYields.right, "", 12)
    ui.distanceLabel:setRightAligned()

    -- travel time
    local vsplitYields = UIVerticalSplitter(vlist:nextRect(15), 5, 0, 0.65)
    ui.window:createLabel(vsplitYields.left, predictable.travelTime.displayName .. ":", 12)
    ui.travelTimeLabel = ui.window:createLabel(vsplitYields.right, "", 12)
    ui.travelTimeLabel:setRightAligned()


    -- override simulationutility - minor re-phrasing
    ui.commonUI.setAreaStats = function(self, stats)
        self.areaLabel3.caption = "Route:"%_t
        self.areaLabel.caption = string.format("about %d sectors"%_t, stats.numSectors)
        self.areaLabel2.caption = string.format("(${x1}:${y1}) to (${x2}:${y2})"%_t % {x1 = stats.area.origin.x, y1 = stats.area.origin.y, x2 = stats.area.upper.x, y2 = stats.area.upper.y})
        self.noMansSpaceLabel.caption = string.format("%d%%", stats.noMansSectors)
        self.outerAreaLabel.caption = string.format("%d%%", stats.outerSectors)
        self.centralAreaLabel.caption = string.format("%d%%", stats.centralSectors)
        self.unreachableLabel.caption = string.format("%d%%", stats.unreachableSectors)
    end


    ui.clear = function(self, shipName)
        self.commonUI:clear(shipName)

        self.swiftnessLabel.caption = ""
        self.commonUI.attackChanceLabel.caption = ""
        self.distanceLabel.caption = ""
        self.travelTimeLabel.caption = ""
        ui.commonUI.assessmentField.text = string.format("\"%s\""%_t, "Calculating route..."%_t)
    end

    -- used to fill values into the UI
    -- config == nil means fill with default values
    ui.refresh = function(self, ownerIndex, shipName, area, config)
        self.commonUI:refresh(ownerIndex, shipName, area, config)

        if not config then
            -- no config: fill UI with default values, then build config, then use it to calculate yields
            local values = TravelCommand:getConfigurableValues(ownerIndex, shipName)

            -- use "setValueNoCallback" since we don't want to trigger "refreshPredictions()" while filling in default values
            self.swiftnessSlider:setValueNoCallback(values.swiftness.default)
            self.swiftnessLabel.caption = TravelCommand:getSwiftnessName(self.swiftnessSlider.value)

            config = self:buildConfig()
        end

        self:refreshPredictions(ownerIndex, shipName, area, config)
    end

    -- gut feeling says that each config option change should always be reflected in the predictions if it impacts the behavior
    ui.refreshPredictions = function(self, ownerIndex, shipName, area, config)
        local prediction = TravelCommand:calculatePrediction(ownerIndex, shipName, area, config)

        self:displayPrediction(prediction, config, ownerIndex)

        self.commonUI:refreshPredictions(ownerIndex, shipName, area, config, TravelCommand, prediction)

        if MapRoutes then
            local line = {from = area.analysis.route[1], to = area.lower}
            MapRoutes.setCustomRoute(ownerIndex, shipName, {line})
            self.lastRouteData = {ownerIndex = ownerIndex, shipName = shipName}
        end
    end

    ui.displayPrediction = function(self, prediction, config, ownerIndex)
        self.swiftnessLabel.caption = TravelCommand:getSwiftnessName(self.swiftnessSlider.value)

        self.commonUI:setAttackChance(prediction.attackChance.value)

        self.distanceLabel.caption = tostring(round(prediction.distance)) .. " sectors"%_t
        self.travelTimeLabel.caption = createReadableShortTimeString(math.ceil(prediction.travelTime / 60) * 60)
    end

    -- used to build a config table for the command, based on values configured in the UI
    -- gut feeling says that each config option change should always be reflected in the predictions if it impacts the behavior
    ui.buildConfig = function(self)
        local config = {}
        config.swiftness = self.swiftnessSlider.value

        config.escorts = self.commonUI.escortUI:buildConfig()

        return config
    end

    ui.onWindowClosed = function(self)
        if MapRoutes and self.lastRouteData then
            MapRoutes.clearRoute(self.lastRouteData.ownerIndex, self.lastRouteData.shipName)
        end
    end

    ui.setActive = function(self, active, description)
        self.commonUI:setActive(active, description)

        self.swiftnessSlider.active = active
    end

    ui.displayConfig = function(self, config, ownerIndex)
        self.swiftnessSlider:setValueNoCallback(config.swiftness)
    end

    return ui
end

function TravelCommand:generateAssessmentFromPrediction(prediction, captain, ownerIndex, shipName, area, config)
    local travelTimeLines = {}
    if prediction.travelTime > 20 * 60 then
        table.insert(travelTimeLines, "We will be traveling for a long time."%_t)
        table.insert(travelTimeLines, "It's a very long journey."%_t)
    elseif prediction.travelTime > 10 * 60 then
        table.insert(travelTimeLines, "This trip will take a while."%_t)
        table.insert(travelTimeLines, "We will be traveling for a good while."%_t)
    elseif prediction.travelTime > 5 * 60 then
        table.insert(travelTimeLines, "The destination is only a short distance away."%_t)
    else
        table.insert(travelTimeLines, "I will reach the destination soon."%_t)
        table.insert(travelTimeLines, "Reaching the destination will take very little time."%_t)
    end

    local attackLines = SimulationUtility.getAttackAssessmentLines(prediction.attackChance.value)
    local underRadar, returnLines = SimulationUtility.getDisappearanceAssessmentLines(prediction.attackChance.value)

    -- cargo on board
    local entry = ShipDatabaseEntry(ownerIndex, shipName)
    local captain = entry:getCaptain()
    local cargo = entry:getCargo()
    local stolenOrIllegal, dangerousOrSuspicious = SimulationUtility.getSpecialCargoCategories(cargo)
    local cargobayLines = SimulationUtility.getIllegalCargoAssessmentLines(stolenOrIllegal, dangerousOrSuspicious, captain)

    local rnd = Random(Seed(captain.name))
    return {
        randomEntry(rnd, travelTimeLines),
        randomEntry(rnd, attackLines),
        randomEntry(rnd, cargobayLines),
        randomEntry(rnd, underRadar),
        randomEntry(rnd, returnLines),
    }
end

function TravelCommand:getSwiftnessName(swiftness)
    if swiftness == 0 then
        return "stealthy"%_t
    elseif swiftness == 1 then
        return "slow"%_t
    elseif swiftness == 2 then
        return "moderate"%_t
    else
        return "fast"%_t
    end
end


return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
