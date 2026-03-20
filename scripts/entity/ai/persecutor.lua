package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("persecutorutility")
include("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Persecutor
Persecutor = {};
local self = Persecutor

self.target = nil
self.playerEscapeSector = nil
self.allianceEscapeSector = nil
self.jumpTarget = nil
self.attacking = nil
self.jumpsDone = 0

function Persecutor.getUpdateInterval()
    return 3
end

function Persecutor.initialize()
    if onServer() and GameSettings().difficulty >= Difficulty.Normal then
        Sector():registerCallback("onEntityJump", "onEntityJump")
    end
end

function Persecutor.startAttacking()
    self.attacking = true
end

function Persecutor.onSectorChanged()
    self.target = nil
    self.playerEscapeSector = nil
    self.allianceEscapeSector = nil
    self.jumpTarget = nil

    if onServer() then
        Sector():registerCallback("onEntityJump", "onEntityJump")
    end

    if self.jumpsDone == 1 and Entity():getValue("persecutor_leader") then
        local texts =
        {
            "Did you really think you'd get rid of us that easily? We can track you!"%_T,
            "You can't just lose us that easily! We can track you!"%_T,
            "Your hyperdrive is nothing compared to ours and our tracker!"%_T,
            "You're not getting off that easily! Our tracker will always tell us where you are!"%_T,
        }

        Sector():broadcastChatMessage(Entity().translatedTitle, ChatMessageType.Normal, randomEntry(random(), texts))
    elseif self.jumpsDone == 3 and Entity():getValue("persecutor_leader") then
        Sector():broadcastChatMessage(Entity().translatedTitle, ChatMessageType.Normal, "This is starting to get tedious, maybe we should start looking for easier prey."%_T)
    elseif self.jumpsDone == 4 and Entity():getValue("persecutor_leader") then
        Sector():broadcastChatMessage(Entity().translatedTitle, ChatMessageType.Normal, "This will be the last time we jump after this clown - if we don't get this ship this time, we're out."%_T)
    end

    if (Sector():getValue("neutral_zone") or 0) == 1 then
        Sector():deleteEntityJumped(Entity())
    end
end

function Persecutor.findTarget()
    -- prefer ships flown by players
    local sector = Sector()
    local players = {sector:getPlayers()}
    if #players > 0 then
        for _, player in pairs(players) do
            local playerShip = sector:getEntity(player.craftIndex)
            if valid(playerShip) then
                return playerShip
            end
        end
    end

    -- find a ship based on a present faction
    local factions = {sector:getPresentFactions()}

    -- prefer ships of players
    for _, index in pairs(factions) do
        local faction = Faction(index)

        if faction and faction.isPlayer then
            local crafts = {sector:getEntitiesByFaction(index)}
            for _, craft in pairs(crafts) do
                if craft:hasComponent(ComponentType.Plan) then
                    return craft
                end
            end
        end
    end

    -- then ships of alliances
    for _, index in pairs(factions) do
        local faction = Faction(index)

        if faction and faction.isAlliance then
            local crafts = {sector:getEntitiesByFaction(index)}
            for _, craft in pairs(crafts) do
                if craft:hasComponent(ComponentType.Plan) then
                    return craft
                end
            end
        end
    end

end

function Persecutor.updateJumping(timeStep)

    self.jumpTimer = (self.jumpTimer or 0) + timeStep
    if self.jumpTimer < 30 then
        return
    end

    if self.jumpsDone < 4 and sectorPersecutable(self.jumpTarget.x, self.jumpTarget.y) then
        local entity = Entity()
        if entity:hasScript("entity/dialogs/encounters/persecutor.lua") then
            entity:removeScript("entity/dialogs/encounters/persecutor.lua")
        end

        Sector():transferEntity(Entity(), self.jumpTarget.x, self.jumpTarget.y, SectorChangeType.Jump)

    else
        Sector():deleteEntityJumped(Entity())
    end

    self.attacking = true
    self.jumpsDone = (self.jumpsDone or 0) + 1
    self.jumpTarget = nil
    self.jumpTimer = 0
end

function Persecutor.updateAttacking()
    -- attack target
    if valid(self.target) then
        ShipAI():setAttack(self.target)
    end
end

function Persecutor.updateTargetFinding()
    -- find a target
    if not valid(self.target) then
        self.target = self.findTarget()

        if self.target == nil then
            if self.playerEscapeSector then
                self.jumpTarget = self.playerEscapeSector
            elseif self.allianceEscapeSector then
                self.jumpTarget = self.allianceEscapeSector
            else
                -- no target could be found and no target was registered for escaping, delete self
                Sector():deleteEntityJumped(Entity())
                terminate()
            end
        end
    end
end

function Persecutor.updateServer(timeStep)
    if self.jumpTarget then
        self.updateJumping(timeStep)
    else
        -- find a target
        self.updateTargetFinding()

        if self.attacking then
            self.updateAttacking()
        end
    end
end

function Persecutor.onEntityJump(id, x, y)
    -- when entities jump away, try to follow them
    local entity = Sector():getEntity(id)

    if entity.playerOwned then
        self.playerEscapeSector = {x=x, y=y}
    elseif entity.allianceOwned then
        self.allianceEscapeSector = {x=x, y=y}
    end
end
