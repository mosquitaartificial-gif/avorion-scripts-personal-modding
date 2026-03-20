package.path = package.path .. ";data/scripts/lib/?.lua"

include ("utility")

if onServer() then

local code = nil
local time = 10

function initialize(timeIn, codeIn)
    if not _restoring then
        if timeIn and codeIn then
            time = timeIn
            code = codeIn
            deferredCallback(time, "executeCode")
        else
            eprint("DelayedExecute: time or code is nil")
            terminate()
        end
    end
end

function executeCode()
    execute(code)
    terminate()
end

function secure()
    return {time = time, code = code}
end

function restore(data)
    time = data.time
    code = data.code
    deferredCallback(time, "executeCode")
end

end
