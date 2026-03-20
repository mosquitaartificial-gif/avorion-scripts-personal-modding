

--if onClient() then

--function sync(data_in)
--    if data_in then
--        data = data_in
--    else
--        invokeServerFunction("sync")
--    end
--end

--else

--function sync()
--    if callingPlayer then
--        invokeClientFunction(Player(callingPlayer), "sync", data)
--    else
--        broadcastInvokeClientFunction("sync", data)
--    end
--end

--end

package.path = package.path .. ";data/scripts/lib/?.lua"
include ("callable")

function defineSyncFunction(dataName, namespace)
    namespace = namespace or _G

    if onClient() then
        namespace.sync = function(data_in)
            if data_in then
                namespace[dataName] = data_in
                if namespace.onSync then namespace.onSync() end
            else
                invokeServerFunction("sync")
            end
        end
    else
        namespace.sync = function()
            if callingPlayer then
                invokeClientFunction(Player(callingPlayer), "sync", namespace[dataName])
            else
                broadcastInvokeClientFunction("sync", namespace[dataName])
            end
        end

        -- the following comment is important for a unit test
        -- Dynamic Namespace namespace
        callable(namespace, "sync")
    end
end
