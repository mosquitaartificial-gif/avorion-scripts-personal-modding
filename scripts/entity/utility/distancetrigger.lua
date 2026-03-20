
-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace DistanceTrigger
DistanceTrigger = {}

local data = {}
local nearby = {}

function DistanceTrigger.initialize(data_in)
    data = data_in or {}
    data.radius = data.radius or 1000
end

function DistanceTrigger.getUpdateInterval()
    return 0.5
end

function DistanceTrigger.updateServer(timeStep)
    if not data.onEnteredCallback then
        eprint("distancetrigger: no callback set, terminating")
        terminate()
        return
    end

    -- check for entities nearby
    local self = Entity()
    local sector = Sector()

    local newNearby = {}
    for _, entity in pairs({sector:getEntitiesByLocation(Sphere(self.translationf, data.radius))}) do
        -- there is a check for player/alliance ships since this script is intended to be a mission-trigger script
        -- if this behavior is unwanted in the future, we should add filtering functionality, but until then I decided to do it this way
        if entity.playerOrAllianceOwned then
            local id = entity.id.string
            newNearby[id] = true

            if not nearby[id] then
                local ownId = self.id.string
                self:sendCallback(data.onEnteredCallback, ownId, id)
                sector:sendCallback(data.onEnteredCallback, ownId, id)

                if data.singleUseTrigger then
                    terminate()
                    return
                end
            end
        end
    end

    nearby = newNearby
end

function DistanceTrigger.secure()
    return data
end

function DistanceTrigger.restore(data_in)
    data = data_in
end
