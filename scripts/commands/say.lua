package.path = package.path .. ";data/scripts/lib/?.lua"

function execute(sender, commandName, ...)
    local args = {...}

    local str = ""
    for i, v in pairs(args) do
        str = str .. v .. " "
    end

    Server():broadcastChatMessage("Server", ChatMessageType.ServerInfo, str)

    return 0, "", ""
end

function getDescription()
    return "Send chat message to all players on the server"
end

function getHelp()
    return "Send chat message to all players on the server. Usage: /say This is a test"
end
