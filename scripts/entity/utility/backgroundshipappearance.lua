package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/player/background/simulation/?.lua"

local CommandType = include ("commandtype")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace BackgroundShipAppearance
BackgroundShipAppearance = {}

local data = {}
local startHP = 0
local lowFrequencyUpdateTimer = 10

function BackgroundShipAppearance.initialize(faction)
    data.faction = faction

    if onServer() then
        local ship = Entity()

        if _restoring then
            Sector():deleteEntity(ship)
            return
        end

        ship:setValue("displayed_faction", faction)
        ship:registerCallback("onDestroyed", "onDestroyed")

        startHP = ship.durability

        Galaxy():registerCallback("onBackgroundShipDisappear", "onBackgroundShipDisappear")
    end

end

function BackgroundShipAppearance.getUpdateInterval()
    -- ship has to react immediately when background simulation is canceled
    return 0
end

function BackgroundShipAppearance.updateServer(timeStep)

    local ship = Entity()
    local owner = Galaxy():findFaction(data.faction)

    if not owner then
        Sector():deleteEntityJumped(ship)
        return
    end

    BackgroundShipAppearance.updateValidity(owner, ship)
    BackgroundShipAppearance.updateHP(owner, ship)

    lowFrequencyUpdateTimer = lowFrequencyUpdateTimer + timeStep
    if lowFrequencyUpdateTimer > 2 then

        BackgroundShipAppearance.updateRelations(owner, ship)
        BackgroundShipAppearance.updateCommandBehavior(owner, ship)
        BackgroundShipAppearance.updateChatter(owner, lowFrequencyUpdateTimer)

        lowFrequencyUpdateTimer = 0
    end
end

function BackgroundShipAppearance.updateValidity(owner, ship)
    local sector = Sector()

    -- if a ship is destroyed, delete the appearance
    local name = ship.name
    if owner:getShipAvailability(name) == ShipAvailability.Destroyed then
        sector:deleteEntity(ship)
        return
    end

    -- if the original appears, delete the appearance
    -- the appearance is usually replaced by the original anyway
    local original = sector:getEntityByFactionAndName(data.faction, ship.name)
    if original then
        sector:deleteEntity(ship) -- doesn't delete immediately, only at the end of the tick
        return
    end

    -- if the sectors don't match, delete (avoids duplicates)
    local x, y = sector:getCoordinates()
    local sx, sy = owner:getShipPosition(name)
    if x ~= sx or y ~= sy then
        sector:deleteEntityJumped(ship)
        return
    end

    -- if the ship is available, immediately sign it over
    if owner:getShipAvailability(name) == ShipAvailability.Available then
        BackgroundShipAppearance.signOverToOwner(owner, ship)
        return
    end

    -- no more players -> don't take up resources
    if sector.numPlayers == 0 then
        sector:deleteEntity(ship)
        return
    end
end

function BackgroundShipAppearance.updateHP(owner, ship)
    if ship.durability < startHP * 0.8 then
        owner:setShipAvailability(ship.name, ShipAvailability.Available)

        BackgroundShipAppearance.signOverToOwner(owner, ship)

        local x, y = Sector():getCoordinates()
        owner:sendChatMessage(ship, ChatMessageType.Warning, "Your ship '%1%' is under attack in sector \\s(%2%:%3%)!"%_T, ship.name, x, y)

        terminate()
    end
end

function BackgroundShipAppearance.updateRelations(owner, ship)

    local galaxy = Galaxy()
    local sector = Sector()
    local ownFaction = Faction()
    local factions = {sector:getPresentFactions()}

    for _, factionIndex in pairs(factions) do
        if factionIndex ~= ship.factionIndex then
            local others = Faction(factionIndex)
            galaxy:setFactionRelations(others, ownFaction, 75000, false, false)
            galaxy:setFactionRelationStatus(others, ownFaction, RelationStatus.Neutral, false, false)
        end
    end

    local ownAI = ShipAI()
    for _, enemy in pairs({sector:getEnemies(data.faction)}) do
        ownAI:registerEnemyEntity(enemy.id)
    end

    for _, friend in pairs({sector:getAllies(data.faction)}) do
        ownAI:registerFriendEntity(friend.id)
    end

end

function BackgroundShipAppearance.updateCommandBehavior(owner, ship)

    if data.command == CommandType.Escort then
        -- find ship to protect
        local toEscort
        for _, entity in pairs({Sector():getEntitiesByFaction(ship.factionIndex)}) do
            if entity.name == data.commandData.escortee and entity:getValue("displayed_faction") == data.faction then
                toEscort = entity
                break
            end
        end

        if not toEscort then
            ship:addScriptOnce("ai/patrolpeacefully.lua")
            return
        end

        if toEscort:hasScript("ai/mine.lua") and ship:getNumMiningTurrets() > 0 then
            ship:addScriptOnce("ai/mine.lua")
        elseif toEscort:hasScript("ai/salvage.lua") and ship:getNumSalvagingTurrets() > 0 then
            ship:addScriptOnce("ai/salvage.lua")
        else
            local ai = ShipAI()
            if ai.state ~= AIState.Escort then
                if toEscort then
                    ShipAI():setEscort(toEscort)
                end
            end
        end

    elseif data.command == CommandType.Mine then
        ship:addScriptOnce("ai/mine.lua")

    elseif data.command == CommandType.Salvage then
        ship:addScriptOnce("ai/salvage.lua")

    else
        ship:addScriptOnce("ai/patrolpeacefully.lua")
    end

end

function BackgroundShipAppearance.signOverToOwner(owner, ship)
    owner = owner or Galaxy():findFaction(data.faction)
    ship = ship or Entity()

    ship:setValue("displayed_faction", nil)

    -- ships can only be removed from the ship list if destroyed
    -- ship has to be removed from the list before assigning the faction index because Owner component callbacks would create a copy
    owner:setShipDestroyed(ship.name, true)
    owner:removeDestroyedShipInfo(ship.name)

    ship.factionIndex = data.faction

    terminate()
end

function BackgroundShipAppearance.setCommandData(command, data_in)
    data.command = command
    data.commandData = data_in
end

function BackgroundShipAppearance.onBackgroundShipDisappear(factionIndex, name)
    local ship = Entity()
    if data.faction == factionIndex and ship.name == name then
        Sector():deleteEntityJumped(ship)
    end
end

function BackgroundShipAppearance.onDestroyed()
    local owner = Galaxy():findFaction(data.faction)
    local ship = Entity()

    owner:setShipDestroyed(ship.name, true)
end

local LinesByCommand = {}
LinesByCommand[CommandType.Scout] = {
"Checking surroundings."%_T,
"Scanning the sector."%_T,
"We should move on soon."%_T,
"So many things to see, so many sectors to explore!"%_T,
}
LinesByCommand[CommandType.Mine] = {
"We should check out that one over there next."%_T,
"I can't understand how anybody wouldn't love this job."%_T,
"I love the sound of stone being torn apart."%_T,
"I think I saw a nice asteroid field a few sectors back."%_T,
"You can trust me Commander. The next shipment will arrive soon."%_T,
}
LinesByCommand[CommandType.Salvage] = {
"We should check out that one over there next."%_T,
"I can't understand how anybody wouldn't love this job."%_T,
"The key to good salvage is following faction wars."%_T,
"I love the sound of metal being torn apart."%_T,
"I think I saw a nice wreckage field a few sectors back."%_T,
"Scrapyards are for greenhorns. Wreckage in unclaimed territory is the best."%_T,
"You can trust me Commander. The next shipment will arrive soon."%_T,
}
LinesByCommand[CommandType.Refine] = {
"My contact should respond soon and we'll get a better price."%_T,
"The shipment will be done soon."%_T,
}
LinesByCommand[CommandType.Procure] = {
"My contact should respond soon and we'll get a better price."%_T,
"We'll soon be done, Commander."%_T,
}
LinesByCommand[CommandType.Sell] = {
"My contact should respond soon and we'll get a better price."%_T,
"We'll soon be done, Commander."%_T,
}
LinesByCommand[CommandType.Expedition] = {
"This is exciting!"%_T,
"So many things to see, so many sectors to explore!"%_T,
"Hello, Commander! You wouldn't believe all the things you can see here!"%_T,
"Checking surroundings."%_T,
"We should move on soon."%_T,
}
LinesByCommand[CommandType.Maintenance] = {
"My contact should respond soon and we'll get a better price."%_T,
"We'll soon be done, Commander."%_T,
}

local GeneralLines = {}
table.insert(GeneralLines, "Really not a fan of being micromanaged, Commander."%_t)
table.insert(GeneralLines, "I feel like you don't trust me, Commander."%_t)
table.insert(GeneralLines, "Do you keep such close tabs on all your captains, Commander?"%_t)
table.insert(GeneralLines, "Oh, hey, Commander."%_t)
table.insert(GeneralLines, "Uh hello, Commander. Is there anything I can help you with?"%_t)
table.insert(GeneralLines, "I don't like being monitored at work, Commander."%_t)
table.insert(GeneralLines, "I though the deal was that I do the work while you do something else, Commander?"%_t)
table.insert(GeneralLines, "We should move on soon."%_t)
table.insert(GeneralLines, "So, I guess you enjoy monitoring my work, Commander?"%_t)
table.insert(GeneralLines, "Hey Commander. Making sure I'm doing everything right?"%_t)
table.insert(GeneralLines, "We should check out other sectors, soon."%_t)
table.insert(GeneralLines, "We should avoid staying in here for too long."%_t)


local chatterTimer = random():getFloat(0, 30)
local timesNoBubbles = 100

function BackgroundShipAppearance.updateChatter(owner, timeStep)

    chatterTimer = chatterTimer + timeStep
    if chatterTimer > 40 then
        chatterTimer = 0

        local bubbleChance = 1 - (1 / timesNoBubbles)

        if random():test(bubbleChance) then
            local lines = table.deepcopy(LinesByCommand[data.command or ""] or {})
            for _, line in pairs(GeneralLines) do
                table.insert(lines, line)
            end

            local sender = Entity()
            local captain = CrewComponent():getCaptain()
            owner:sendChatMessage(sender, ChatMessageType.Chatter, "Captain %1%: %2%"%_T, captain.name, randomEntry(lines))

            timesNoBubbles = 0
        else
            timesNoBubbles = timesNoBubbles + 1
        end

    end

end
