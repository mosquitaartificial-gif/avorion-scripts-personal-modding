
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/player/background/simulation/?.lua"

local CommandFactory = {}

local CommandType = include ("commandtype")

local MineCommand = include ("minecommand")
local SalvageCommand = include ("salvagecommand")
local TravelCommand = include ("travelcommand")
local PrototypeCommand = include ("prototypecommand")
local EscortCommand = include ("escortcommand")
local ProcureCommand = include ("procurecommand")
local SellCommand = include ("sellcommand")
local RefineCommand = include ("refinecommand")
local MaintenanceCommand = include ("maintenancecommand")
local ScoutCommand = include ("scoutcommand")
local ProcureCommand = include ("procurecommand")
local SupplyCommand = include ("supplycommand")
local ExpeditionCommand = include ("expeditioncommand")
local TradeCommand = include ("tradecommand")

-- keep track of all commands here for automated creation
local registry = {}
registry[CommandType.Prototype] = PrototypeCommand
registry[CommandType.Travel] = TravelCommand
registry[CommandType.Scout] = ScoutCommand
registry[CommandType.Mine] = MineCommand
registry[CommandType.Salvage] = SalvageCommand
registry[CommandType.Refine] = RefineCommand
registry[CommandType.Procure] = ProcureCommand
registry[CommandType.Sell] = SellCommand
registry[CommandType.Supply] = SupplyCommand
registry[CommandType.Expedition] = ExpeditionCommand
registry[CommandType.Maintenance] = MaintenanceCommand
registry[CommandType.Trade] = TradeCommand
registry[CommandType.Escort] = EscortCommand

-- basically Factory pattern for commands
function CommandFactory.makeCommand(type, ...)

    local CommandClass = registry[type]
    if not CommandClass then
        eprint("Simulation Error: Command %s not found", type)
        return
    end

    local command = CommandClass(...) -- creates a new command instance

    return command
end

function CommandFactory.getCommandName(type)
    for name, tp in pairs(CommandType) do
        if type == tp then
            return name
        end
    end
end

function CommandFactory.getRegistry(type)
    return registry
end

return CommandFactory
