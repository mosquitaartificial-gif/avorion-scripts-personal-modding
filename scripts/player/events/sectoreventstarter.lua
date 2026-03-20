if onServer() then

function initialize(script, ...)
    Sector():addScriptOnce(script, ...)
    terminate()
end

end
