
if onServer() then

function callable(namespace, func)
    if namespace then
        namespace.Callable = namespace.Callable or {}
        namespace.Callable[func] = namespace[func]
    else
        Callable = Callable or {}
        Callable[func] = _G[func]
    end
end

rcall = callable

else

function callable() end

function rcall(namespace, func)
    namespace = namespace or _G

    namespace[func] = function(...)
        local values = {...}
        for i, value in pairs(values) do
            if not serializable(value) then
                values[i] = nil
            end
        end

        invokeServerFunction(func, unpack(values))
    end
end

end
