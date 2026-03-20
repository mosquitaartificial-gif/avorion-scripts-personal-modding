package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/player/background/simulation/?.lua"

local CommandType = include ("commandtype")
include ("utility")
include ("stringutility")


local EscortCommand = {}
EscortCommand.__index = EscortCommand
EscortCommand.type = CommandType.Escort

-- all commands need this kind of "new" to function within the bg simulation framework
-- it must be possible to call the command without any parameters to access some functionality
local function new(ship, area, config)
    local command = setmetatable({
        -- all commands need these variables to function within the bg simulation framework
        -- type contains the CommandType of the command, required to restore
        type = CommandType.Escort,

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
    }, EscortCommand)

    return command
end

-- all commands have the following functions, even if not listed here (added by Simulation script on command creation):
-- function EscortCommand:addYield(message, money, resources, items) end
-- function EscortCommand:finish() end



-- you can return an error message here such as:
-- return "Command cannot initialize because %1% and %2% went wrong", {"Player", "Config"}
function EscortCommand:initialize()

end

function EscortCommand:update(timeStep)
    local faction = getParentFaction()
    if faction:getShipAvailability(self.config.escortedShip) ~= ShipAvailability.InBackground then
        self:finish()
    end
end

function EscortCommand:getAreaAnalysisSectors(results, meta)
end

function EscortCommand:onAreaAnalysisStart(results, meta)
end

function EscortCommand:onAreaAnalysisSector(results, meta, x, y)
end

function EscortCommand:onAreaAnalysisFinished(results, meta)
end

-- executed when the command starts for the first time (not when being restored)
-- do things like paying money in here and return errors when it's not possible because the player doesn't have enough money
-- you can return an error message here such as:
-- return "Command cannot start because %1% doesn't fulfill requirement '%2%'!", {"Player", "Money"}
function EscortCommand:onStart()

    local entry = ShipDatabaseEntry(getParentFaction().index, self.shipName)
    entry:setStatusMessage(NamedFormat("Escorting ${ship}"%_t, {ship = self.config.escortedShip}))
end

-- executed when the ship is being recalled by the player
function EscortCommand:onRecall()
    self.simulation.recall(self.config.escortedShip)
end

-- executed when the command is finished
function EscortCommand:onFinish()
    local faction = getParentFaction()
    local entry = ShipDatabaseEntry(faction.index, self.shipName)
    if valid(entry) then
        local x, y = faction:getShipPosition(self.config.escortedShip)
        if x and y then
            entry:setCoordinates(x, y)
        end
    end
end

-- after this function was called, self.data will be read to be saved to database
function EscortCommand:onSecure()
end

-- this is called after the command was recreated and self.data was assigned
function EscortCommand:onRestore()
end

function EscortCommand:getDescriptionText()
    return "The ship is escorting ship ${name}."%_T, {name = self.config.escortedShip}
end

function EscortCommand:getStatusMessage()
    return NamedFormat("Escorting ${name} /* ship AI status*/"%_T, {name = self.config.escortedShip})
end

function EscortCommand:getIcon()
    return "data/textures/icons/escort-command.png"
end

-- returns whether there are errors with the command, either in the config, or otherwise
-- (ship has no mining turrets, not enough energy, player doesn't have enough money, etc.)
-- this function is also executed on the client and used to grey out the "start" button so players know that their config is flawed
-- note: before this is called, there is already a preliminary check based on getConfigurableValues(),
-- where values are clamped or default-set
function EscortCommand:getErrors(shipName, area, config)
end

function EscortCommand:getRecallError()
end

-- returns the size of the area where the command will run
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function EscortCommand:getAreaSize(ownerIndex, shipName)
    return {x = 1, y = 1}
end

function EscortCommand:getAreaBounds()
    return nil
end

function EscortCommand:isAreaFixed(ownerIndex, shipName)
    return false
end

-- returns whether the command requires the ship to be inside the selected area
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function EscortCommand:isShipRequiredInArea(ownerIndex, shipName)
    return false
end

-- returns the configurable values for this command (if any).
-- variable naming should speak for itself, though you're free to do whatever you want in here.
-- config will only be used by the command itself and nothing else
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function EscortCommand:getConfigurableValues(ownerIndex, shipName)
    return {}
end

-- returns the predictable values for this command (if any).
-- variable naming should speak for itself, though you're free to do whatever you want in here.
-- config will only be used by the command itself and nothing else
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function EscortCommand:getPredictableValues()
    return {}
end

-- calculate the predictions for the ship, area and config
-- gut feeling says that each config option change should always be reflected in the predictions if it impacts the behavior
-- note: this may be called on a temporary instance of the command. all values written to "self" may not persist
function EscortCommand:calculatePrediction(shipName, area, config)
    return {}
end

-- this will be called on a temporary instance of the command. all values written to "self" will not persist
--function EscortCommand:buildUI(startPressedCallback, configChangedCallback)
--end


return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
