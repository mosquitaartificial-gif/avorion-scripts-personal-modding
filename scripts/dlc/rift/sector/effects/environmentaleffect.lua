
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("callable")
local EnvironmentalEffectUT = include("dlc/rift/sector/effects/environmentaleffectutility")


EnvironmentalEffect = {}

function EnvironmentalEffect:initialize(data)
    if data then
        self.data = data
    end

    local data = EnvironmentalEffectUT.data[self.effectType]
    for key, value in pairs(data) do
        self[key] = value
    end

    if onClient() then
        invokeServerFunction("sync")
    end
end

function EnvironmentalEffect:sync(data)
    if onServer() then
        invokeClientFunction(Player(callingPlayer), "sync", self.data)
    else
        if data then
            self.data = data
        end

        self:refreshSectorProblem()
    end
end
callable(EnvironmentalEffect, "sync")

function EnvironmentalEffect:updateClientProtectionStatus()
    local craft = Player().craft
    if not craft then return false end

    local isProtected = craft:getValue("protected_from_environment")

    -- intensity must be synced to client before the ShipProblem is displayed, as it contains intensity
    if self.data.intensity and isProtected ~= self.lastProtectionStatus then
        self.lastProtectionStatus = isProtected
        self:refreshSectorProblem()
    end

    return isProtected
end

function EnvironmentalEffect:refreshSectorProblem()
    removeSectorProblem(self.name)

    if self:isSectorProblemVisible() then
        local tooltip = self.detailedName%_t .. "\n\n" .. self.description%_t
        local args = EnvironmentalEffectUT.getFormatArguments(self.effectType, self.data.intensity or 1)

        addSectorProblem(self.name, tooltip % args, self.icon, self.color)
    end
end

function EnvironmentalEffect:isSectorProblemVisible()
    return true
end

function EnvironmentalEffect:secure()
    return self.data
end

function EnvironmentalEffect:restore(data)
    self:initialize(data)
end

function EnvironmentalEffect:new()
    local instance = {}
    setmetatable(instance, self)
    self.__index = self
    instance.data = {}

    return instance
end

function EnvironmentalEffect.CreateNamespace(effectType)
    local instance = EnvironmentalEffect:new()
    instance.effectType = effectType

    local result = {instance = instance}

    result.initialize = function(...) return instance:initialize(...) end
    result.sync = function(...) return instance:sync(...) end
    result.secure = function(...) return instance:secure(...) end
    result.restore = function(...) return instance:restore(...) end

    -- Dynamic Namespace result
    callable(result, "sync")

    return result
end

return EnvironmentalEffect
