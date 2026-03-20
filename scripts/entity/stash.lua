
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("randomext")
include ("galaxy")
include ("stringutility")
include ("faction")
include ("callable")
local UpgradeGenerator = include ("upgradegenerator")
local SectorTurretGenerator = include ("sectorturretgenerator")
local BuildingKnowledgeUT = include("buildingknowledgeutility")

local data = {}
data.empty = false

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function interactionPossible(playerIndex, option)

    local player = Player(playerIndex)
    local self = Entity()

    local craft = player.craft
    if craft == nil then return false end

    local dist = craft:getNearestDistance(self)

    if dist < 20.0 then
        return true
    end

    return false, "You're not close enough to open the object."%_t
end

function initialize(empty)
    local entity = Entity()

    if entity.title == "" then entity.title = "Smuggler's Cache"%_t end

    entity:setValue("valuable_object", RarityType.Exceptional)
    data.empty = empty or false
end

-- create all required UI elements for the client side
function initUI()

    local res = getResolution()
    local size = vec2(800, 600)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(vec2(0, 0), vec2(0, 0)))

    menu:registerWindow(window, "[Open]"%_t, 5);
end

function onShowWindow()
    invokeServerFunction("claim")
    ScriptUI():stopInteraction()
end

function receiveMoney(faction)

    local x, y = Sector():getCoordinates()
    local money = 20000 * Balancing_GetSectorRewardFactor(x, y)

    Sector():dropBundle(Entity().translationf, faction, nil, money)
end

function receiveTurret(faction)

    local x, y = Sector():getCoordinates()

    local generator = SectorTurretGenerator()
    generator.minRarity = Rarity(RarityType.Exceptional)
    if random():getFloat() < 0.3 then
        generator.minRarity = Rarity(RarityType.Rare)
    end

    local turret = generator:generate(x, y, 0)
    Sector():dropTurret(Entity().translationf, faction, nil, turret)
end

function receiveUpgrade(faction)

    local x, y = Sector():getCoordinates()

    local generator = UpgradeGenerator()
    generator.minRarity = Rarity(RarityType.Exceptional)
    if random():getFloat() < 0.3 then
        generator.minRarity = Rarity(RarityType.Rare)
    end

    if faction.isPlayer and faction.ownsBlackMarketDLC then
        generator.blackMarketUpgradesEnabled = true
    end

    if faction.isPlayer and faction.ownsIntoTheRiftDLC then
        generator.intoTheRiftUpgradesEnabled = true
    end

    local upgrade = generator:generateSectorSystem(x, y)
    Sector():dropUpgrade(Entity().translationf, faction, nil, upgrade)
end

function receiveBuildingKnowledge(faction)
    local x, y = Sector():getCoordinates()
    local material = BuildingKnowledgeUT.getLocalKnowledgeMaterial(x, y)
    local item = BuildingKnowledgeUT.makeKnowledge(faction.index, material)

    local loot = Sector():dropUsableItem(Entity().translationf, faction, nil, item)
    loot.reservationTime = 60 * 60
end

function checkForLaserBossHint()
    -- if stash is inside barrier and player defeated guardian (aka has laser boss spawn script),
    -- it can contain a hint for the location of the laser boss
    local x, y = Sector():getCoordinates()
    local distToCenter = math.sqrt(x * x + y * y)
    if distToCenter < 150 then
        local player = Player(callingPlayer)
        if player:hasScript("spawnlaserboss.lua") then
            player:invokeFunction("spawnlaserboss.lua", "getHint")
        end
    end
end

function claim()

    local receiver, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.AddItems, AlliancePrivilege.AddResources)
    if not receiver then return end

    local entity = Entity()
    local dist = ship:getNearestDistance(entity)
    if dist > 20.0 then
        player:sendChatMessage("", ChatMessageType.Error, "You're not close enough to open the object."%_t)
        return
    end

    local sector = Sector()

    if not data.empty then
        receiveMoney(receiver)

        if random():getFloat() < 0.5 then
            receiveTurret(receiver)
        else
            receiveUpgrade(receiver)
        end

        if random():getFloat() < 0.5 then
            if random():getFloat() < 0.5 then
                receiveTurret(receiver)
            else
                receiveUpgrade(receiver)
            end
        end

        if random():getFloat() < 0.05 then
            local item = UsableInventoryItem("unbrandedreconstructionkit.lua", Rarity(RarityType.Legendary))
            sector:dropUsableItem(entity.translationf, receiver, nil, item)
        elseif random():getFloat() < 0.05 then
            local item = UsableInventoryItem("jumperbosscaller.lua", Rarity(RarityType.Legendary))
            sector:dropUsableItem(entity.translationf, receiver, nil, item)
        end

        -- small chance to drop building knowledge
        if random():getFloat() < 1 / 20 then
            receiveBuildingKnowledge(player)
        end

        checkForLaserBossHint()
    end

    -- send callback that stash is opened
    local player = Player(callingPlayer)
    sector:sendCallback("onStashOpened", entity.id, player.index)
    player:sendCallback("onStashOpened", entity.id, player.index)
    entity:sendCallback("onStashOpened", entity.id, player.index)

    -- terminate script and remove entity from object detection
    terminate()
    entity:setValue("valuable_object", nil)
end
callable(nil, "claim")

function setEmpty(value)
    data.empty = value
end

function secure()
    return data
end

function restore(data_in)
    data = data_in
end




