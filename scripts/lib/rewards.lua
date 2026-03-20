package.path = package.path .. ";data/scripts/lib/?.lua"
include ("randomext")
include ("stringutility")
include ("relations")
SectorTurretGenerator = include ("sectorturretgenerator")
UpgradeGenerator = include ("upgradegenerator")

local Rewards = {}

local messages1 =
{
    "Thank you."%_T,
    "Thank you so much."%_T,
    "We thank you."%_T,
    "Thank you for helping us."%_T,
}

local messages2 =
{
    "You have our endless gratitude."%_T,
    "We have transferred a reward to your account."%_T,
    "We have a reward for you."%_T,
    "Please take this as a sign of our gratitude."%_T,
}

function Rewards.standard(player, faction, msg, money, reputation, turret, system)
    -- give payment to players who participated
    if msg then
        player:sendChatMessage(faction.name, 0, msg)
    else
        player:sendChatMessage(faction.name, 0, "%1% %2%", messages1[random():getInt(1, #messages1)], messages2[random():getInt(1, #messages2)])
    end
    player:receive("Received a reward of %1% Credits."%_T, money)
    changeRelations(player, faction, reputation, nil)

    local x, y = Sector():getCoordinates()
    local object

    if system and random():getFloat() < 0.5 then
        local generator = UpgradeGenerator()
        generator.minRarity = Rarity(RarityType.Exceptional)
        if player.isPlayer and player.ownsBlackMarketDLC then
            generator.blackMarketUpgradesEnabled = true
        end

        if player.isPlayer and player.ownsIntoTheRiftDLC then
            generator.intoTheRiftUpgradesEnabled = true
        end

        object = generator:generateSectorSystem(x, y, Rarity(RarityType.Uncommon))
    elseif turret then
        local generator = SectorTurretGenerator()
        generator.minRarity = Rarity(RarityType.Exceptional)

        object = InventoryTurret(generator:generate(x, y))
    end

    if object then player:getInventory():addOrDrop(object) end

end

return Rewards
