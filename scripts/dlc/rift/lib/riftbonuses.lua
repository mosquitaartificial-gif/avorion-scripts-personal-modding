package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
include("randomext")
local RiftObjects = include("dlc/rift/lib/riftobjects")

local RiftBonuses = {}

-- The existing UUIDs should NOT be changed
-- the order of the bonuses in the table doesn't matter, feel free to sort/organize
-- UUIDs were generated using https://www.uuidgenerator.net/ (Version 4 UUID)
RiftBonuses.Type =
{
    Resources = "8c0e0ca2-bb40-4108-866a-d87d05a510d4",
    Salvage = "5687d646-f19b-4695-8337-5c2f18696f42",
    WeaponChamber = "5b2ac568-4293-4d4d-b0cb-1cfbb25c85d2",
    LootGoons = "f70436dc-77e7-4d9d-b311-19f4f221afb5",
    Scannables = "3aa3d5d4-9f04-416b-937e-06418d488176",
}

RiftBonuses[RiftBonuses.Type.Resources] = {
    icon = "data/textures/icons/rift-bonus-ores.png",
    name = "Miner's Heaven"%_t,
    description = "Bring your Mining Lasers, preferrably R-Mining Lasers! Lots of rich asteroids detected."%_t,
    preGeneration = function(specs)
        for i, lm in pairs(specs.landmarks) do
            lm.resourceChance = math.max(0.5, lm.resourceChance or 0.5)
        end
    end,
    postGeneration = function(specs) end,
}

RiftBonuses[RiftBonuses.Type.Salvage] = {
    icon = "data/textures/icons/rift-bonus-salvage.png",
    name = "Salvage-O-Rama"%_t,
    description = "Bring your Salvaging Lasers! Lots of large wreckages detected."%_t,
    preGeneration = function(specs)
        for i, lm in pairs(specs.landmarks) do
            lm.stationWreckages = lm.stationWreckages or {}

            local wreckages = random():getInt(1, 2)
            for j = 1, wreckages do
                local stationWreckage = lm.location + random():getDirection() * random():getFloat(400, 1000)
                table.insert(lm.stationWreckages, stationWreckage)
            end
        end
    end,
    postGeneration = function(specs) end,
}

RiftBonuses[RiftBonuses.Type.LootGoons] = {
    icon = "data/textures/icons/rift-bonus-loot.png",
    name = "Aggregator Aggregation"%_t,
    description = "Get prepared for a bunch of Xsotan hoarders."%_t,
    preGeneration = function(specs) end,
    postGeneration = function(specs)
        Sector():addScriptOnce("dlc/rift/sector/xsotanlootgoonriftbonus.lua")
    end,
}

RiftBonuses[RiftBonuses.Type.WeaponChamber] = {
    icon = "data/textures/icons/rift-bonus-cargo.png",
    name = "Weapon Chamber"%_t,
    description = "According to our records, there should be an old weapons chamber in this sector. It might be worth keeping your eyes open for it."%_t,
    preGeneration = function(specs) end,
    postGeneration = function(specs)
        -- always spawn the weapon chamber at landmark 2: not immediately at the start, but close by
        local center = specs.landmarks[math.min(2, #specs.landmarks)].location
        local location = center + random():getDirection() * 500
        RiftObjects.createWeaponChamber(translate(Matrix(), location))

        -- spawn the switches at other locations
        local switchLocations = {3, 4, 5, 6}
        shuffle(switchLocations)

        if #specs.landmarks == 5 then
            switchLocations = {3, 4, 5}
        elseif #specs.landmarks == 4 then
            switchLocations = {1, 3, 4}
        elseif #specs.landmarks == 3 then
            switchLocations = {1, 2, 3}
        end

        for i = 1, 3 do
            local landmarkIndex = math.min(switchLocations[i], #specs.landmarks)
            local center = specs.landmarks[landmarkIndex].location
            local location = center + random():getDirection() * random():getFloat(500, 1000)

            -- create switch
            RiftObjects.createWeaponChamberSwitch(translate(Matrix(), location))

            -- create battery
            local batteryLocation = location
            -- spawn the first battery so close to the switch that it will dock automatically
            -- the others are spawned at a small distance
            if i ~= 1 then
                batteryLocation = batteryLocation + random():getDirection() * random():getFloat(500, 1000)
            end

            RiftObjects.createBattery(translate(Matrix(), batteryLocation))
        end
    end,
}

RiftBonuses[RiftBonuses.Type.Scannables] = {
    icon = "data/textures/icons/rift-bonus-scan.png",
    name = "Information Rich Space"%_t,
    description = "In this sector there are many unexplored scannable objects."%_t,
    preGeneration = function(specs) end,
    postGeneration = function(specs)
        local treasures = {}

        for _, collection in pairs({specs.landmarks, specs.paths, specs.secrets}) do
            for _, poi in pairs(collection) do
                for _, treasure in pairs(poi.treasures) do
                    table.insert(treasures, treasure)
                end

                if poi.location then
                    table.insert(treasures, poi.location)
                end
            end
        end

        shuffle(treasures)

        for i = 1, math.ceil(#treasures * 0.75) do
            local location = treasures[i] + random():getDirection() * 100
            if random():test(0.9) then
                RiftObjects.createSmallScannableObject(translate(Matrix(), location))
            else
                RiftObjects.createBigScannableObject(translate(Matrix(), location))
            end
        end
    end,
}

function RiftBonuses.applyPreGeneration(specs, bonuses)
    for _, bonusType in pairs(bonuses) do
        local bonus = RiftBonuses[bonusType]
        bonus.preGeneration(specs)
    end
end

function RiftBonuses.applyPostGeneration(specs, bonuses)
    for _, bonusType in pairs(bonuses) do
        local bonus = RiftBonuses[bonusType]
        bonus.postGeneration(specs)
    end
end

function RiftBonuses.getBonuses(threatLevel)
    local probability = lerp(threatLevel, 2, 7, 0.025, 0.5)
    if random():test(probability) then
        local all = {}
        for name, id in pairs(RiftBonuses.Type) do
            table.insert(all, id)
        end

        return {randomEntry(all)}
    end

    return {}
end

return RiftBonuses
