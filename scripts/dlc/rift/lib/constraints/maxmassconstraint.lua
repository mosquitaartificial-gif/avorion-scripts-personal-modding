
local MaxMassConstraint = {}
MaxMassConstraint.__index = MaxMassConstraint

local function new(type)
    local constraint = setmetatable({
        type = type,
        name = "Possible Mass"%_T,
        icon = "data/textures/icons/kilo-tons.png",
        sortPriority = -10,

        -- global constraint: this checks all candidates at the same time
        global = true,

        -- soft constraint: not being fulfilled won't block the start of the mission
        soft = true,

        description = "The scientists can move this many kilotons of mass into the rift."%_t,
    }, MaxMassConstraint)

    return constraint
end

function MaxMassConstraint:initialize(maxMass)
    self.maxMass = maxMass
end

function MaxMassConstraint:isFulfilled(crafts)
    -- since this is a soft constraint, this return value will only be used in the mission description
    -- always return 'false' to ensure the description for this constraint is never greyed out and crossed out
    return false
end

function MaxMassConstraint:getMissionDescription(candidates)
    local shipsByFaction = {}
    for _, craft in pairs(candidates) do
        local tbl = shipsByFaction[craft.factionIndex] or {}
        table.insert(tbl, craft)
        shipsByFaction[craft.factionIndex] = tbl
    end

    local maxKT = self.maxMass / 1000
    local ownKT = 0

    local checkFactionMass = function(shipsByFaction, factionIndex, withName)
        local ships = shipsByFaction[factionIndex] or {}

        local currentKT = 0
        for _, craft in pairs(ships) do
            currentKT = currentKT + craft.mass
        end

        currentKT = math.floor(currentKT / 100) / 10

        local perc = round((1 - maxKT / currentKT) * 100)

        local error = nil
        local args = nil
        local color = "\\c(dd5)"

        if perc >= 10 then
            color = "\\c(e85)"
        end

        if currentKT > maxKT then
            if withName then
                local name = ""

                local faction = Faction(factionIndex)
                if faction then name = faction.name end

                if #ships > 1 then
                    error, args = "${currentKT} / ${maxKT} kT mass (${ships} ships); ${perc}% of ship mass will be lost during teleport (${player})"%_T, {currentKT = currentKT, maxKT = maxKT, player = name, ships = #ships, perc = perc}
                else
                    error, args = "${currentKT} / ${maxKT} kT mass; ${perc}% of ship mass will be lost during teleport (${player})"%_T, {currentKT = currentKT, maxKT = maxKT, player = name, perc = perc}
                end
            else
                if #ships > 1 then
                    error, args = "${currentKT} / ${maxKT} kT mass (${ships} ships); ${perc}% of ship mass will be lost during teleport"%_T, {currentKT = currentKT, maxKT = maxKT, ships = #ships, perc = perc}
                else
                    error, args = "${currentKT} / ${maxKT} kT mass; ${perc}% of ship mass will be lost during teleport"%_T, {currentKT = currentKT, maxKT = maxKT, perc = perc}
                end
            end
        end

        return currentKT, error, args, color, #ships
    end

    local player = Player()
    local craftFactionIndex = player.index
    if player.craft and player.craft.allianceOwned then
        craftFactionIndex = player.craft.factionIndex
    end

    local ownKT, error, args, color, numShips = checkFactionMass(shipsByFaction, craftFactionIndex)
    if error then return error, args, color end

    for factionIndex, _ in pairs(shipsByFaction) do
        local withName = true
        local _, error, args, color = checkFactionMass(shipsByFaction, factionIndex, withName)

        if error then return error, args, color end
    end

    if numShips > 1 then
        return "${currentKT} / ${maxKT} kT mass (${ships} ships)"%_T, {currentKT = ownKT, maxKT = maxKT, ships = numShips}
    else
        return "${currentKT} / ${maxKT} kT mass"%_T, {currentKT = ownKT, maxKT = maxKT}
    end
end

function MaxMassConstraint:getUIValue()
    return self.maxMass / 1000
end

function MaxMassConstraint:getTooltipValue()
    return "${mass} kT"%_t % {mass = self.maxMass / 1000}
end

function MaxMassConstraint:getAdditionalTooltipLine()
    local player = Player()
    local craft = player.craft
    if not craft then return end
    if craft.type ~= EntityType.Ship then return end

    local values =
    {
        mass = math.floor(craft.mass / 100) / 10,
        percentOfMax = math.floor(craft.mass / self.maxMass * 100)
    }
    return "Current Ship: ${mass} kT (${percentOfMax}%)"%_t % values
end

function MaxMassConstraint:buildAdditionalDialog(missionData, candidates)
    local shipsByFaction = {}
    for _, craft in pairs(candidates) do
        local tbl = shipsByFaction[craft.factionIndex] or {}
        table.insert(tbl, craft)
        shipsByFaction[craft.factionIndex] = tbl
    end

    local maxKT = self.maxMass / 1000

    for factionIndex, ships in pairs(shipsByFaction) do
        local currentKT = 0
        for _, craft in pairs(ships) do
            currentKT = currentKT + craft.mass
        end

        currentKT = math.floor(currentKT / 100) / 10

        if currentKT > maxKT then
            local name = ""
            local faction = Faction(factionIndex)
            if faction then name = faction.name end

            local perc = round((1 - maxKT / currentKT) * 100)

            local dialog1 = {}
            dialog1.text = "${player}'s ships in the teleport area exceed the maximum amount of mass we can transport into the rift."%_t % {player = name}
                            .. "\n\n" .. "We can still start the teleport, but ${perc}% of your ship mass will get lost, and your ships could suffer heavy damage. Possibly to the point where you can't finish the mission. Do you still want to proceed?"%_t % {perc = perc}
            dialog1.answers =
            {
                {answer = "No."%_t},
                {answer = "Yes!"%_t}
            }

            return dialog1, dialog1.answers[2]
        end
    end
end

function MaxMassConstraint:onRiftSectorEntered(ships)

end

function MaxMassConstraint:onTeleportStarted(ships)
    local shipsByFaction = {}
    for _, craft in pairs(ships) do
        local tbl = shipsByFaction[craft.factionIndex] or {}
        table.insert(tbl, craft)
        shipsByFaction[craft.factionIndex] = tbl
    end

    local maxKT = self.maxMass / 1000

    for _, ships in pairs(shipsByFaction) do
        -- check the amount of mass that is to be teleported
        local currentKT = 0
        for _, craft in pairs(ships) do
            currentKT = currentKT + craft.mass
        end
        currentKT = math.floor(currentKT / 100) / 10

        -- if necessary, set durability malus to apply during teleport
        if currentKT > maxKT then
            local malus = maxKT / currentKT

            for _, ship in pairs(ships) do
                ship:invokeFunction("riftteleport.lua", "setMalus", malus)
            end
        end
    end
end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
