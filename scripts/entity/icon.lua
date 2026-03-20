package.path = package.path .. ";data/scripts/lib/?.lua"
include ("callable")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Icon
Icon = {}

Icon.icon = ""

function Icon.initialize(value)
    Icon.set(value)

    if onClient() then
        Icon.sync()
    end
end

function Icon.updateShipIcon()
    local entity = Entity()

    local owner = Galaxy():findFaction(entity.factionIndex)
    if owner and (owner.isPlayer or owner.isAlliance) then
        owner:setShipIcon(entity.name, Icon.icon)
    end
end

function Icon.set(value)
    Icon.icon = value or ""

    if onClient() then
        EntityIcon().icon = Icon.icon
    else
        broadcastInvokeClientFunction("sync", Icon.icon)
        Icon.updateShipIcon()
    end
end

function Icon.get()
    return Icon.icon
end

function Icon.secure()
    return {icon = Icon.icon}
end

function Icon.restore(data)
    Icon.icon = data.icon
end

function Icon.sync(data)
    if onClient() then
        if data then
            Icon.set(data)
        else
            invokeServerFunction("sync")
        end
    elseif callingPlayer then
        invokeClientFunction(Player(callingPlayer), "sync", Icon.icon)
        Icon.updateShipIcon()
    end
end
callable(Icon, "sync")
