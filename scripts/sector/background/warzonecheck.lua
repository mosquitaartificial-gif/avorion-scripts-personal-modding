
package.path = package.path .. ";data/scripts/lib/?.lua"

include ("utility")
include ("stringutility")
include ("randomext")
include ("player")
include("factioneradicationutility")
local AsyncShipGenerator = include("asyncshipgenerator")
local SpawnUtility = include ("spawnutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace WarZoneCheck
WarZoneCheck = {}

-- on destruction of some specific objects (ships, stations, etc) a "war zone score" is increased
-- when the score reaches a threshold, the sector is declared a war zone by a station in the sector
-- the score decays over time (1 point per minute), but every time it's increased it doesn't decay for at least 60 minutes
-- the score cannot reach more than 100
-- once the score decays below a certain threshold, the sector is deemed peaceful again
-- war zones can only be declared in sectors with stations
-- a war zone makes civil ships (transporters, traders, etc) avoid the sector (ie. they won't spawn)
-- when a war zone is declared, a fleet of support ships is spawned by the faction controlling the sector
-- above fleet will despawn once the sector is considered peaceful again

local self = WarZoneCheck
self.data = {}

self.data.score = 0 -- war score that leads to the sector being declared a war zone
self.data.warZoneThreshold = 60 -- a score of 60 or higher makes the sector a war zone
self.data.pacefulThreshold = 40 -- a score of 40 or lower turns the sector back into a normal zone
self.data.maxScore = 100 -- maximum number of score

self.data.noDecayTime = 60 * 60 -- 1 hour until score starts decaying
self.data.noDecayTimer = 0

self.reinforcementsRequested = 0


if onServer() then

function WarZoneCheck.getUpdateInterval()
    return 60
end

function WarZoneCheck.initialize()
    local sector = Sector()
    sector:registerCallback("onDestroyed", "onDestroyed")
    sector:registerCallback("onBoardingSuccessful", "onBoardingSuccessful")
    sector:registerCallback("onRestoredFromDisk", "onRestoredFromDisk")
    sector:registerCallback("onPlayerArrivalConfirmed", "onPlayerArrivalConfirmed")
end

function WarZoneCheck.updateServer(timeStep)
    -- while the timer is running, no decay happens
    self.data.noDecayTimer = math.max(0, self.data.noDecayTimer - timeStep)

    if self.data.noDecayTimer == 0 then
        -- decay the war zone score now that everything is peaceful again
        -- this code relies on update ticks of 1 minute
        WarZoneCheck.decreaseScore(1)
    end
end

function WarZoneCheck.declareWarZone()
    local sector = Sector()
    local wasWarZoneBefore = sector:getValue("war_zone")

    -- make the sector a war zone
    sector:setValue("war_zone", true)

    self.data.noDecayTimer = self.data.noDecayTime -- declaration of war zone: this sector will stay a war zone for some time
    self.data.score = math.max(self.data.score, self.data.warZoneThreshold) -- declaration of war zone: increase sector's score to avoid inconsistency

    if not wasWarZoneBefore then
        WarZoneCheck.callOutWarZone()

        -- call in reinforcements
        deferredCallback(5, "spawnReinforcements")
    end
end

function WarZoneCheck.undeclareWarZone()
    local sector = Sector()

    -- if this is not a war zone, don't do anything
    if not sector:getValue("war_zone") then return end

    sector:setValue("war_zone", nil)
    self.data.score = math.min(self.data.score, self.data.pacefulThreshold) -- declaration of war zone: increase sector's score to avoid inconsistency

    WarZoneCheck.callOutPeaceZone()

    -- reinforcements are no longer necessary
    deferredCallback(5, "despawnReinforcements")

end

function WarZoneCheck.increaseScore(amount)

    self.data.score = math.min(self.data.maxScore, self.data.score + amount)

    -- score increase: this sector will stay a war zone for some time
    self.data.noDecayTimer = self.data.noDecayTime

    if self.data.score >= self.data.warZoneThreshold then
        WarZoneCheck.declareWarZone()
    end

end

function WarZoneCheck.getTimeUntilNoLongerWarzone()
    local minutes = math.ceil(self.data.noDecayTimer / 60)
    minutes = minutes + self.data.score
    return minutes
end

function WarZoneCheck.decreaseScore(amount)
    self.data.score = math.max(0, self.data.score - amount)

    if self.data.score <= self.data.pacefulThreshold then
        WarZoneCheck.undeclareWarZone()
    end
end

function WarZoneCheck.spawnReinforcements()

    -- safeguard: if there are already reinforcements for some reason, don't spawn new ones
    if Sector():getEntitiesByScriptValue("war_zone_reinforcement") then return end

    -- to spawn reinforcements, sector must be controlled by an AI faction
    local x, y = Sector():getCoordinates()
    local faction = Galaxy():getControllingFaction(x, y)
    if not faction or not faction.isAIFaction then return end

    if FactionEradicationUtility.isFactionEradicated(faction.index) then return end

    local onGenerated = function(ships)
        for _, ship in pairs(ships) do
            ship:setValue("war_zone_reinforcement", true)
        end

        -- add enemy buffs
        SpawnUtility.addEnemyBuffs(ships)
    end

    local generator = AsyncShipGenerator(WarZoneCheck, onGenerated)

    -- let the backup spawn behind the station
    local dir = random():getDirection()
    local pos = dir * 1500
    local up = vec3(0, 1, 0)
    local look = -dir
    local right = normalize(cross(dir, up))

    generator:startBatch()
    generator:createDefender(faction, MatrixLookUpPosition(look, up, pos))
    generator:createDefender(faction, MatrixLookUpPosition(look, up, pos + right * 100))
    generator:createDefender(faction, MatrixLookUpPosition(look, up, pos + right * 200))
    generator:createDefender(faction, MatrixLookUpPosition(look, up, pos + right * 300))
    generator:createDefender(faction, MatrixLookUpPosition(look, up, pos - right * 100))
    generator:createDefender(faction, MatrixLookUpPosition(look, up, pos - right * 200))
    generator:createDefender(faction, MatrixLookUpPosition(look, up, pos - right * 300))

    generator:endBatch()

    -- for unit tests
    WarZoneCheck.reinforcementsRequested = 7
end

function WarZoneCheck.despawnReinforcements()
    local sector = Sector()
    local reinforcements = {Sector():getEntitiesByScriptValue("war_zone_reinforcement")}

    for _, ship in pairs(reinforcements) do
        ship:addScriptOnce("deletejumped.lua")
    end
end

function WarZoneCheck.callOutWarZone()
    local sector = Sector()
    sector:broadcastChatMessage("Witness"%_T, ChatMessageType.Normal, "This sector is unsafe! We have to warn people! Notify everyone!"%_T)

    local warzoneText = "Due to turmoils, this sector has been called out as a Hazard Zone.\nCivilian ships, traders and freighters will avoid this sector until peace has returned."%_T
    local nearbyText = "Sector \\s(%1%:%2%) has been called out as a Hazard Zone."%_T

    local x, y = sector:getCoordinates()
    AlertNearbyPlayers(x, y, 20, function(player, sx, sy, shipName)
        -- don't notify if it's only through a ship
        if shipName then return end

        if sx == x and sy == y then
            player:sendChatMessage("Hazard Zone"%_T, ChatMessageType.Warning, warzoneText)
        else
            player:sendChatMessage("Hazard Zone"%_T, ChatMessageType.Warning, nearbyText, x, y)
        end
    end)
end

function WarZoneCheck.onPlayerArrivalConfirmed(playerIndex)
    local player = Player(playerIndex)

    if Sector():getValue("war_zone") == true then
        local minutes = WarZoneCheck.getTimeUntilNoLongerWarzone()
        if minutes == 0 then minutes = 1 end

        local msg = "You have entered a Hazard Zone.\nCivilian ships, traders and freighters avoid this sector until peace has returned (~%1% minutes remaining). Trade and economy are massively impaired here."%_T
        player:sendChatMessage("", ChatMessageType.Warning, msg, minutes)
    end

end

function WarZoneCheck.callOutPeaceZone()
    local sector = Sector()
    local settled = "The sector is no longer considered a Hazard Zone. Traders and freighters will return to the sector."%_T
    sector:broadcastChatMessage("", ChatMessageType.Normal, settled)

end

function WarZoneCheck.onDestroyed(destroyedId, destroyerId)

    local victim = Entity(destroyedId)
    if not victim then return end

    if victim:getValue("is_pirate") then return end
    if victim:getValue("is_xsotan") then return end
    if victim:getValue("is_persecutor") then return end
    if not victim.type == EntityType.Fighter then return end
    if not victim.type == EntityType.Drone then return end
    if not victim:hasComponent(ComponentType.Plan) then return end
    if not victim:hasComponent(ComponentType.Durability) then return end

    local factor = 1

    -- don't overpunish players who already lost ships/stations by immediately calling out a warzone
    if victim.playerOwned or victim.allianceOwned then
        factor = 0.2
    end

    if victim.isStation then
        WarZoneCheck.increaseScore(100 * factor)
    else
        if Sector():getNumEntitiesByType(EntityType.Station) == 0 then return end

        local destroyer = Entity(destroyerId)
        if destroyer then
            -- less influence from pirates and xsotan
            if destroyer:getValue("is_pirate") then factor = math.min(factor, 0.25) end
            if destroyer:getValue("is_xsotan") then factor = math.min(factor, 0.25) end
            if destroyer:getValue("is_persecutor") then factor = math.min(factor, 0.25) end

            if destroyer.playerOwned or destroyer.allianceOwned then
                -- weigh player factions normally
                WarZoneCheck.increaseScore(40 * factor)
            else
                -- weigh AI factions less for increased influence of players
                WarZoneCheck.increaseScore(10 * factor)
            end
        end
    end

end

function WarZoneCheck.onBoardingSuccessful(id, oldFactionIndex, newFactionIndex)

    local victim = Entity(id)
    if victim:getValue("is_pirate") then return end
    if victim:getValue("is_xsotan") then return end

    local factor = 1

    -- don't overpunish players who already lost ships/stations by immediately calling out a warzone
    local oldFaction = Faction(oldFactionIndex)
    if oldFaction and (oldFaction.isPlayer or oldFaction.isAlliance) then
        factor = 0.2
    end

    if victim.isStation then
        WarZoneCheck.increaseScore(100 * factor)
    else
        if Sector():getNumEntitiesByType(EntityType.Station) == 0 then return end

        local faction = Faction(newFactionIndex)
        if faction.isPlayer or faction.isAlliance then
            -- weigh player factions normally
            WarZoneCheck.increaseScore(40 * factor)
        else
            -- weigh AI factions less for increased influence of players
            WarZoneCheck.increaseScore(10 * factor)
        end
    end
end

function WarZoneCheck.onRestoredFromDisk(timeSinceLastSimulation)

    if timeSinceLastSimulation > self.data.maxScore * 60 + self.data.noDecayTime then
        -- if more time passed than is necessary for things to go back to normal,
        -- then we can just reset the sector instead of simulating everything
        WarZoneCheck.undeclareWarZone()

        self.data.score = 0
        self.data.noDecayTimer = 0
    else
        for i = 1, timeSinceLastSimulation / 60 do
            WarZoneCheck.updateServer(60)
        end
    end

end

function WarZoneCheck.restore(data_in)
    self.data = data_in
end

function WarZoneCheck.secure()
    return self.data
end

end
