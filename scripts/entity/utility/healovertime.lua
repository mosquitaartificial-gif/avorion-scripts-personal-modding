package.path = package.path .. ";data/scripts/lib/?.lua"

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace HealOverTime
HealOverTime = {}

HealOverTime.data = {}
HealOverTime.data.toHeal = 0.2
HealOverTime.data.healStep = 100

if onServer() then

function HealOverTime.getUpdateInterval()
    return 0.2
end

function HealOverTime.initialize(percentageHP, time)
    percentageHP = percentageHP or 0.1
    time = time or 10

    HealOverTime.data.toHeal = Entity().maxDurability * percentageHP
    HealOverTime.data.healStep = HealOverTime.data.toHeal / time

    if Entity().durability == nil then
        terminate()
    end
end

function HealOverTime.update(timeStep)
    local healStep = math.min(HealOverTime.data.toHeal, HealOverTime.data.healStep * timeStep)
    if healStep <= 0 then
        terminate()
        return
    end

    HealOverTime.data.toHeal = HealOverTime.data.toHeal - healStep

    local entity = Entity()
    entity.durability = entity.durability + healStep
end

function HealOverTime.secure()
    return HealOverTime.data
end

function HealOverTime.restore(data_in)
    HealOverTime.data = data_in
end

end

