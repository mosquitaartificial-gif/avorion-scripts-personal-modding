package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
include ("randomext")
include ("utility")
local PirateGenerator = include ("pirategenerator")
local SectorTurretGenerator = include ("sectorturretgenerator")

local Swoks = {}

function Swoks.spawn(player, x, y)

    local function piratePosition()
        local pos = random():getVector(-1000, 1000)
        return MatrixLookUpPosition(-pos, vec3(0, 1, 0), pos)
    end

    local bossBeaten = Server():getValue("swoks_beaten") or 2
    local number = bossBeaten + 1

    -- spawn
    local boss = PirateGenerator.createBoss(piratePosition())
    boss:setTitle("Boss Swoks ${num}"%_T, {num = toRomanLiterals(number)})
    boss.dockable = false

    pirates = {}
    table.insert(pirates, boss)
    table.insert(pirates, PirateGenerator.createRaider(piratePosition()))
    table.insert(pirates, PirateGenerator.createRaider(piratePosition()))
    table.insert(pirates, PirateGenerator.createRavager(piratePosition()))
    table.insert(pirates, PirateGenerator.createRavager(piratePosition()))
    table.insert(pirates, PirateGenerator.createMarauder(piratePosition()))
    table.insert(pirates, PirateGenerator.createMarauder(piratePosition()))
    table.insert(pirates, PirateGenerator.createPirate(piratePosition()))
    table.insert(pirates, PirateGenerator.createPirate(piratePosition()))
    table.insert(pirates, PirateGenerator.createBandit(piratePosition()))
    table.insert(pirates, PirateGenerator.createBandit(piratePosition()))
    table.insert(pirates, PirateGenerator.createBandit(piratePosition()))

    -- adds legendary turret drop
    boss:registerCallback("onDestroyed", "onSwoksDestroyed")

    Loot(boss.index):insert(InventoryTurret(SectorTurretGenerator():generate(x, y, 0, Rarity(RarityType.Exotic))))
    Loot(boss.index):insert(SystemUpgradeTemplate("data/scripts/systems/teleporterkey3.lua", Rarity(RarityType.Legendary), Seed(1)))

    for _, pirate in pairs(pirates) do
        pirate:addScript("deleteonplayersleft.lua")

        if not player then break end
        local allianceIndex = player.allianceIndex
        local ai = ShipAI(pirate.index)
        ai:registerFriendFaction(player.index)
        if allianceIndex then
            ai:registerFriendFaction(allianceIndex)
        end
    end

    boss:addScript("story/swoks.lua")
    boss:addScriptOnce("internal/common/entity/background/legendaryloot.lua")
    boss:addScriptOnce("utility/buildingknowledgeloot.lua", Material(MaterialType.Titanium))
    boss:setValue("is_pirate", true)

    Boarding(boss).boardable = false
end

return Swoks
