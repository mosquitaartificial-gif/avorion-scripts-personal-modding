package.path = package.path .. ";data/scripts/lib/?.lua"
local CaptainUtility = include ("captainutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace UncoverMineableMaterial
UncoverMineableMaterial = {}

function UncoverMineableMaterial.getUpdateInterval()
    return 5
end

function UncoverMineableMaterial.updateServer()
    local entity = Entity()

    -- miner captains uncover all hidden asteroid materials
    local captain = entity:getCaptain()
    if captain and captain:hasClass(CaptainUtility.ClassType.Miner) then
        entity:setValue("uncovered_mineable_material", MaterialType.Avorion)
        return
    end

    local highestMaterialLevel

    local miningScripts = {
        "data/scripts/systems/miningsystem.lua",
        "internal/dlc/rift/systems/miningcarrierhybrid.lua",
    }

    local system = ShipSystem()
    for upgrade, permanent in pairs(system:getUpgrades()) do
        for _, miningScript in pairs(miningScripts) do
            if upgrade.script == miningScript then
                local ret, materialLevel = entity:invokeFunction(miningScript, "getBonuses", upgrade.seed, upgrade.rarity, permanent)
                if ret == 0 then
                    if highestMaterialLevel == nil or materialLevel > highestMaterialLevel then
                        highestMaterialLevel = materialLevel
                    end
                end
            end
        end
    end

    entity:setValue("uncovered_mineable_material", highestMaterialLevel)

    if not highestMaterialLevel then
        terminate()
    end
end
