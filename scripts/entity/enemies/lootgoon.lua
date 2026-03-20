package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")
include ("stringutility")
local SectorTurretGenerator = include("sectorturretgenerator")
local UpgradeGenerator = include ("upgradegenerator")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace LootGoon
LootGoon = {}

local deleteTime = 60
local runningAway = false

function LootGoon.initialize()
    if onServer() then
        local ship = Entity()

        ship:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
        local lines = LootGoon.getChatterLines()
        ship:addScriptOnce("data/scripts/entity/utility/radiochatter.lua", lines, 90, 120, random():getInt(30, 45))

        ship:registerCallback("onDamaged", "onDamaged")
        ship:registerCallback("onDestroyed", "onDestroyed")

        local goonLoot = Loot(ship.id)
        local x, y = Sector():getCoordinates()

        -- add turrets to loot
        local turrets = LootGoon.generateTurrets(x, y)
        for _, turret in pairs(turrets) do
            goonLoot:insert(turret)
        end

        -- add subsystems to loot
        local upgrades = LootGoon.generateUpgrades(x, y)
        for _, upgrade in pairs(upgrades) do
            goonLoot:insert(upgrade)
        end
    end
end

function LootGoon.getUpdateInterval()
    return 1
end

function LootGoon.onDamaged(entityId, damage, inflictor)
    -- start running away only once
    if not runningAway then
        Sector():broadcastChatMessage(Entity(), ChatMessageType.Chatter, "Our loot is in danger! We have to get out of here! We'll be safe in %1% seconds!"%_t, deleteTime)
        -- remove normal chatter to avoid casual lines while running away
        Entity():removeScript("radiochatter.lua")
        local position = Entity().position
        local shipAI = ShipAI()
        shipAI:setFlyLinear(position.look * 10000, 0)
        runningAway = true
    end
end

function LootGoon.onDestroyed()
    -- add money loot
    local money = 10000 * Balancing_GetSectorRewardFactor(x, y)
    Sector():dropBundle(Entity().translationf, nil, nil, money)
end

function LootGoon.updateServer(timeStep)
    local entity = Entity()
    -- delete one minute after getting damage
    if runningAway then
        deleteTime = deleteTime - timeStep
    end

    if deleteTime <= 30 and deleteTime + timeStep > 30 then
        Sector():broadcastChatMessage(Entity(), ChatMessageType.Chatter, "This piece of junk's Hyperspace Engine takes so long to activate! Hold off this thief for another %1% seconds!"%_t, math.ceil(deleteTime))
    elseif deleteTime <= 10 and deleteTime + timeStep > 10 then
        Sector():broadcastChatMessage(Entity(), ChatMessageType.Chatter, "Go, go, go! We're almost there! We're almost out of here!"%_t)
    elseif deleteTime <= 5 then
        Entity():addScriptOnce("deletejumped.lua")
    end
end

function LootGoon.generateTurrets(x, y)
    local turrets = {}
    -- amount is not the total amount but only for high rarities
    local amount = random():getInt(5, 6)
    local lowRarityAmount = amount * 2

    -- add high value turrets to loot
    for i = 1, amount do
        local rarities = {}
        -- one turret has higher rarity
        if i == amount then
            rarities[RarityType.Exceptional] = 1.5
            rarities[RarityType.Exotic] = 0.5
            rarities[RarityType.Legendary] = 0.25
        else
            rarities[RarityType.Uncommon] = 2
            rarities[RarityType.Rare] = 2
            rarities[RarityType.Exceptional] = 1
        end

        local rarity = selectByWeight(random(), rarities)
        local turret = InventoryTurret(SectorTurretGenerator():generate(x, y, 0, Rarity(rarity)))

        table.insert(turrets, turret)
    end

    -- add low value turrets to loot
    for i = 1, lowRarityAmount do
        local rarities = {}
        rarities[RarityType.Petty] = 0.5
        rarities[RarityType.Common] = 1
        rarities[RarityType.Uncommon] = 2

        local rarity = selectByWeight(random(), rarities)
        local turret = InventoryTurret(SectorTurretGenerator():generate(x, y, 0, Rarity(rarity)))

        table.insert(turrets, turret)
    end

    return turrets
end

function LootGoon.generateUpgrades(x, y)
    local upgrades = {}
    -- amount is not the total amount but only for high rarities
    local amount = random():getInt(3, 4)
    local lowRarityAmount = amount * 2

    -- add high value subsytems to loot
    for i = 1, amount do
        local rarities = {}
        -- one subsystem has higher rarity
        if i == amount then
            rarities[RarityType.Exceptional] = 1.5
            rarities[RarityType.Exotic] = 0.5
            rarities[RarityType.Legendary] = 0.25
        else
            rarities[RarityType.Uncommon] = 2
            rarities[RarityType.Rare] = 1
            rarities[RarityType.Exceptional] = 0.5
        end

        local rarity = selectByWeight(random(), rarities)
        local upgrade = UpgradeGenerator():generateSectorSystem(x, y, rarity)
        table.insert(upgrades, upgrade)
    end

    -- add low value subsytems to loot
    for i = 1, lowRarityAmount do
        local rarities = {}
        rarities[RarityType.Petty] = 0.5
        rarities[RarityType.Common] = 1
        rarities[RarityType.Uncommon] = 2

        local rarity = selectByWeight(random(), rarities)
        local upgrade = UpgradeGenerator():generateSectorSystem(x, y, rarity)
        table.insert(upgrades, upgrade)
    end

    return upgrades
end

function LootGoon.getChatterLines()
    local chatterLines =
    {
        "Finally we got some real loot."%_t,
        "Once we get home, everyone will get their share."%_t,
        "I've got to hide my treasure."%_t,
        "Relax, everyone gets some of the spoils."%_t,
        "If anything happens, we can always run away."%_t,
        "Juicy spoils and a good fight every once in a while. A pirate's life for me!"%_t,
    }

    return chatterLines
end

