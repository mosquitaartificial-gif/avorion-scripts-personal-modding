
function checkCaptain()
    local entity = Entity()

    if not checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FlyCrafts) then
        return false
    end

    if not entity:getCaptain() then
        local faction = Faction()
        if faction then
            local recipient = faction
            if faction.isAlliance then
                -- send error message only to player currently handling the ship
                recipient = Player(callingPlayer)
            end

            recipient:sendChatMessage("", ChatMessageType.Error, "Your ship needs a captain for that!"%_t)
        end

        return false
    end

    return true
end

function checkForPilot()
    local pilot = entity:getPilotIndices()
    if pilot then
        local faction = Faction()
        if faction then
            local recipient = faction
            if faction.isAlliance then
                -- send error message only to player currently handling the ship
                recipient = Player(callingPlayer)
            end

            recipient:sendChatMessage("", ChatMessageType.Error, "Can't assign orders: Ship %1% is piloted by a player!"%_t, entity.name or "")
        end

        return false
    end

    return true
end

function checkArmed()

    -- torpedoes always count as armament
    local launcher = TorpedoLauncher()
    if launcher and launcher.numTorpedoes > 0 then
        return true
    end

    local entity = Entity()

    -- check turrets
    if entity:getNumArmedTurrets() > 0 then
        return true
    end

    -- check fighters
    local hangar = Hangar()
    local squads = {hangar:getSquads()}

    for _, index in pairs(squads) do
        local category = hangar:getSquadMainWeaponCategory(index)
        if category == WeaponCategory.Armed then
            return true
        end
    end

    local faction = Faction(entity.factionIndex)
    if faction then
        local recipient = faction
        if faction.isAlliance and callingPlayer then
            -- send error message only to player currently handling the ship
            recipient = Player(callingPlayer)
        end

        recipient:sendChatMessage("", ChatMessageType.Error, "Your craft %s has no turrets or combat fighters!"%_T, entity.name)
    end

    return false
end

function checkHeal()
    local hangar = Hangar()
    local squads = {hangar:getSquads()}
    local repairFighters = false

    for _, index in pairs(squads) do
        local category = hangar:getSquadMainWeaponCategory(index)
        if category == WeaponCategory.Heal then
            repairFighters = true
        end
    end

    local entity = Entity()
    local turrets = {entity:getTurrets()}
    local repairWeapons = false
    for _, turret  in pairs(turrets) do
        local weapons = Weapons(turret)

        if weapons.category == WeaponCategory.Heal then
            repairWeapons = true
        end
    end

    if not repairFighters and not repairWeapons then
        local faction = Faction(Entity().factionIndex)
        if faction then
            local recipient = faction
            if faction.isAlliance then
                -- send error message only to player currently handling the ship
                recipient = Player(callingPlayer)
            end

            if recipient then
                recipient:sendChatMessage("", ChatMessageType.Error, "We need turrets or repair fighters to heal!"%_T)
            end
        end
        return false
    end

    return true
end

function checkBoardTarget(target)
    local canBoard, error = canBoard(Entity())

    if not canBoard and error then
        local faction = Faction(Entity().factionIndex)
        if faction then
            local recipient = faction
            if faction.isAlliance then
                -- send error message only to player currently handling the ship
                recipient = Player(callingPlayer)
            end

            local msg = "This craft cannot board others: %s"%_T
            recipient:sendChatMessage("", ChatMessageType.Error, msg, error)
        end

        return false
    end

    return true
end
