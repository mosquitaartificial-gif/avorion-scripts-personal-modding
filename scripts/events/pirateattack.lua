
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("galaxy")
include ("randomext")
include ("stringutility")
include ("player")
include ("relations")
local Placer = include ("placer")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local UpgradeGenerator = include ("upgradegenerator")
local SectorTurretGenerator = include ("sectorturretgenerator")
local SpawnUtility = include ("spawnutility")
local EventUT = include ("eventutility")

local ships = {}
local reward = 0
local reputation = 0

local participants = {}

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace PirateAttack
PirateAttack = {}
PirateAttack.attackersGenerated = false

if onServer() then

function PirateAttack.secure()
    return {reward = reward, reputation = reputation, ships = ships}
end

function PirateAttack.restore(data)
    ships = data.ships
    reputation = data.reputation
    reward = data.reward
end

function PirateAttack.initialize()

    local sector = Sector()

    -- no pirate attacks at the very edge of the galaxy
    local x, y = sector:getCoordinates()
    if length(vec2(x, y)) > 560 then
        -- print ("Too far out for pirate attacks.")
        terminate()
        return
    end

    if not EventUT.attackEventAllowed() then
        terminate()
        return
    end

    ships = {}
    participants = {}
    reward = 0
    reputation = 0

    local generator = AsyncPirateGenerator(PirateAttack, PirateAttack.onPiratesGenerated)
    local faction = generator:getPirateFaction()
    local controller = Galaxy():getControllingFaction(x, y)
    if controller and controller.index == faction.index then
        terminate()
        return
    end

    -- create attacking ships
    local dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
    local up = vec3(0, 1, 0)
    local right = normalize(cross(dir, up))
    local pos = dir * 1000

    local attackType = getInt(1, 4)

    local distance = 50

    generator:startBatch()

    if attackType == 1 then
        reward = 2.0

        generator:createScaledRaider(MatrixLookUpPosition(-dir, up, pos))
        generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos + right * distance))
        generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos + right * -distance))

    elseif attackType == 2 then
        reward = 1.5

        generator:createScaledPirate(MatrixLookUpPosition(-dir, up, pos))
        generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos + right * distance))
        generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos + right * -distance))

    elseif attackType == 3 then
        reward = 1.5

        generator:createScaledPirate(MatrixLookUpPosition(-dir, up, pos))
        generator:createScaledPirate(MatrixLookUpPosition(-dir, up, pos + right * distance))
        generator:createScaledPirate(MatrixLookUpPosition(-dir, up, pos + right * -distance))
    else
        reward = 1.0

        generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos))
        generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos + right * distance))
        generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos + right * -distance))
        generator:createScaledOutlaw(MatrixLookUpPosition(-dir, up, pos + right * -distance * 2.0))
        generator:createScaledOutlaw(MatrixLookUpPosition(-dir, up, pos + right * distance * 2.0))
    end

    generator:endBatch()

    reputation = reward * 2000
    reward = reward * 10000 * Balancing_GetSectorRichnessFactor(sector:getCoordinates())

    sector:broadcastChatMessage("Server"%_t, 2, "Pirates are attacking the sector!"%_t)
    AlertAbsentPlayers(ChatMessageType.Warning, "Pirates are attacking sector \\s(%1%:%2%)!"%_t, sector:getCoordinates())
end

function PirateAttack.getUpdateInterval()
    return 5
end

function PirateAttack.onPiratesGenerated(generated)

    local speaker = nil
    for _, ship in pairs(generated) do
        if valid(ship) then -- this check is necessary because ships could get destroyed before this callback is executed
            ships[ship.index.string] = true
            ship:registerCallback("onDestroyed", "onShipDestroyed")
            ship:registerCallback("onSetForDeletion", "onShipDestroyed")
            speaker = ship
        end
    end

    -- add enemy buffs
    SpawnUtility.addEnemyBuffs(generated)

    -- resolve intersections between generated ships
    Placer.resolveIntersections(generated)

    PirateAttack.attackersGenerated = true

    if speaker then
        broadcastInvokeClientFunction("onPiratesGenerated", speaker.id.string)
    end
end

function PirateAttack.update(timeStep)

    if not PirateAttack.attackersGenerated then return end

    -- check if all ships are still there
    -- ships might have changed sector or deleted in another way, which doesn't trigger destruction callback
    local sector = Sector()
    for id, _ in pairs(ships) do
        local pirate = sector:getEntity(id)
        if pirate == nil then
            ships[id] = nil
        end
    end

    -- if not -> end event
    if tablelength(ships) == 0 then
        PirateAttack.endEvent()
    end
end

function PirateAttack.onShipDestroyed(shipIndex)
    ships[shipIndex.string] = nil

    local ship = Entity(shipIndex)
    local damagers = {ship:getDamageContributors()}
    for _, damager in pairs(damagers) do
        local faction = Faction(damager)
        if faction and (faction.isPlayer or faction.isAlliance) then
            participants[damager] = damager
        end
    end

end


function PirateAttack.endEvent()

    local faction = Galaxy():getLocalFaction(Sector():getCoordinates())
    if faction then

        local messages =
        {
            "Thank you for defeating those pirates. You have our endless gratitude."%_t,
            "We thank you for taking care of those ships. We have transferred a reward to your account."%_t,
            "Thank you for taking care of those pirates. We have transferred a reward to your account."%_t,
        }

        -- give payment to players/alliances who participated
        for _, participant in pairs(participants) do
            local participantFaction = Faction(participant)

            participantFaction:sendChatMessage(faction.name, 0, getRandomEntry(messages))
            participantFaction:receive("Received %1% Credits for defeating a pirate attack."%_T, reward)
            changeRelations(participantFaction, faction, reputation, RelationChangeType.CombatSupport, nil, nil, faction)

            local x, y = Sector():getCoordinates()
            local object

            if random():getFloat() < 0.5 then
                local generator = SectorTurretGenerator()
                generator.minRarity = Rarity(RarityType.Rare)

                object = InventoryTurret(generator:generate(x, y, 0))
            else
                local generator = UpgradeGenerator()
                generator.minRarity = Rarity(RarityType.Rare)

                object = generator:generateSectorSystem(x, y)
            end

            if object then participantFaction:getInventory():addOrDrop(object) end
        end
    end

    terminate()
end

end

if onClient() then

function PirateAttack.onPiratesGenerated(id)

    if getLanguage() == "en" then
        -- these don't have translation markers on purpose
        local lines = {
            "Eject all your cargo and we will spare you - hahaha just kidding. You're as good as dead.",
            "We'll give you fired rounds for your cargo. Sounds like an equivalent exchange to me.",
            "Kill 'em all, let their god sort them out!",
            "Maybe next time you'll pay our generous fee for protection.",
            "Don't save any ammo! The salvage will pay for it.",
            "Surrender or be destroyed!",
            "Is this really worth our time? It doesn't matter, we'd be idiots to pass up on free loot.",
            "Hah, they won't stand a chance.",
            "Do you think this is a game?",
        }

        local pirate = Entity(id)
        if valid(pirate) then
            displaySpeechBubble(pirate, randomEntry(lines))
        end
    end

end

end
