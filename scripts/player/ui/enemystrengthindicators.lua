package.path = package.path .. ";data/scripts/lib/?.lua"

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace EnemyStrengthIndicators
EnemyStrengthIndicators = {}
EnemyStrengthIndicators.iconRefreshRequired = nil
EnemyStrengthIndicators.updateTimer = 0

local lastDPS = -1

if onClient() then

function EnemyStrengthIndicators.initialize()
    local player = Player()
    local sector = Sector()
    local craft = player.craft

    player:registerCallback("onShipChanged", "onRefreshRequired")
    player:registerCallback("onSectorChanged", "onSectorChanged")
    player:registerCallback("onSectorArrivalConfirmed", "onSectorChanged")
    sector:registerCallback("onEntityCreated", "onRefreshRequired")
    sector:registerCallback("onPlanModifiedByBuilding", "onRefreshRequired")
end

function EnemyStrengthIndicators.onSectorChanged()
    local sector = Sector()
    sector:registerCallback("onEntityCreated", "onRefreshRequired")
    sector:registerCallback("onPlanModifiedByBuilding", "onRefreshRequired")
    EnemyStrengthIndicators.iconRefreshRequired = true
end

function EnemyStrengthIndicators.onRefreshRequired()
    EnemyStrengthIndicators.iconRefreshRequired = true
end

function EnemyStrengthIndicators.getUpdateInterval()
    return 0.5
end

function EnemyStrengthIndicators.updateClient(timeStep)
    EnemyStrengthIndicators.updateTimer = EnemyStrengthIndicators.updateTimer + timeStep

    local dps = EnemyStrengthIndicators.getOwnDPS()
    if lastDPS ~= dps then
        EnemyStrengthIndicators.iconRefreshRequired = true
        lastDPS = dps
    end

    if EnemyStrengthIndicators.updateTimer > 20 then EnemyStrengthIndicators.iconRefreshRequired = true end

    if EnemyStrengthIndicators.iconRefreshRequired then
        EnemyStrengthIndicators.updateShipIcons()

        -- reset updateTimer after updating the icons
        EnemyStrengthIndicators.updateTimer = 0
        EnemyStrengthIndicators.iconRefreshRequired = nil
    end

    EnemyStrengthIndicators.updateTimer = EnemyStrengthIndicators.updateTimer + 1
end

function EnemyStrengthIndicators.getOwnDPS()
    local player = Player()
    local craft = player.craft

    if not craft then return 0 end

    local selfFighterDps = 0

    local selfHangar = Hangar(craft.id)
    if selfHangar then
        selfFighterDps = selfHangar:getFighterDPS()
    end

    return craft.firePower + selfFighterDps
end

function EnemyStrengthIndicators.updateShipIcons()

    local player = Player()
    local craft = player.craft

    if not craft then return end

    local selfHangar = Hangar(craft.id)
    local selfFighterDps = 0

    if selfHangar then
        selfFighterDps = selfHangar:getFighterDPS()
    end

    -- count fighter dps only half as they can get destoyed and need to reach the enemy
    local selfDps = craft.firePower + selfFighterDps / 2
    local selfHP = craft.maxDurability + (craft.shieldMaxDurability or 0)

    local craftFaction = Faction(craft.factionIndex)

    for _, entity in pairs({Sector():getEntitiesByComponent(ComponentType.Turrets)}) do
        local indicator = EntityIcon(entity)

        -- player and alliance entities don't need an strength indicator
        -- when the player is in the drone, everything is dangerous
        if entity.factionIndex == player.index or entity.factionIndex == player.allianceIndex or craft.isDrone then
            indicator.dangerIcon = ""
            indicator.dangerIconVisible = false
            goto continue
        end

        local otherHangar = Hangar(entity.id)
        local otherFighterDps = 0

        if otherHangar then
            otherFighterDps = otherHangar:getFighterDPS()
        end

        -- count fighter dps only half as they can get destoyed and need to reach the enemy
        local otherDps = entity.firePower + otherFighterDps / 2
        local otherHP = entity.maxDurability + (entity.shieldMaxDurability or 0)

        -- entities without weapons or fighters pose no threat to the player
        if otherDps == 0 then
            indicator.dangerIcon = ""
            indicator.dangerIconVisible = false
            goto continue
        end

        local relation = craftFaction:getRelations(entity.factionIndex)
        local alwaysVisible = EnemyStrengthIndicators.getDangerIconAlwaysVisible(relation, entity, craft)
        if not alwaysVisible then
            if relation >= -30000 then
                indicator.dangerIcon = ""
                indicator.dangerIconVisible = false
                goto continue
            end
        end

        local timeAlive = selfHP / (otherDps + 0.01)
        local timeToKill = otherHP / (selfDps + 10.0)

        -- the enemy strength considers that the player has to deal with multiple enemies, as enemies almost never show up alone
        -- it is also considered that the player uses superior tactics

        -- very strong opponent, against whom the player will have a very hard time without help from other ships
        -- players should consider leaving instead of fighting
        if timeAlive < timeToKill * 0.1 then
            indicator.dangerIcon = "data/textures/icons/pixel/enemy-strength-indicators/skull.png"
            -- same color as in war
            indicator.dangerIconColor = ColorRGB(0.8, 0.2, 0.2)
        -- strong enemy that will take some skill and tactics to defeat
        -- player should be cautious when engaging this enemy
        elseif timeAlive >= timeToKill * 0.1 and timeAlive < timeToKill * 0.3 then
            indicator.dangerIcon = "data/textures/icons/pixel/enemy-strength-indicators/enemy-strength-3.png"
            -- same color as 'in war' as well, to make it better distinguishable from strength 2
            indicator.dangerIconColor = ColorRGB(0.8, 0.2, 0.2)
        -- enemy is stronger than the player
        -- player should focus to this enemy first, to avoid taking too much damage while dealing with the remaining (weaker) enemies
        elseif timeAlive >= timeToKill * 0.3 and timeAlive < timeToKill * 0.6 then
            indicator.dangerIcon = "data/textures/icons/pixel/enemy-strength-indicators/enemy-strength-2.png"
            -- same color as ceasefire
            indicator.dangerIconColor = ColorRGB(1.0, 0.5, 0.0)
        -- enemy is about the same strength as the player
        -- player should kill this enemy first if all other enemies are weaker
        elseif timeAlive >= timeToKill * 0.6 and timeAlive < timeToKill * 1.25 then
            indicator.dangerIcon = "data/textures/icons/pixel/enemy-strength-indicators/enemy-strength-1.png"
            -- same color as bad relations
            indicator.dangerIconColor = ColorRGB(1.0, 1.0, 0.0)
        else
            indicator.dangerIcon = ""
        end

        indicator.dangerIconVisible = alwaysVisible

        ::continue::
    end
end

function EnemyStrengthIndicators.getDangerIconAlwaysVisible(relation, potentialEnemyShip, playerShip)

    -- pirates are always hostile and pose a potential threat
    if potentialEnemyShip:getValue("is_pirate") then
        return true
    -- xsotan are always hostile and pose a potential threat
    elseif potentialEnemyShip:getValue("is_xsotan") then
        return true
    -- if the relations of a factions is bad, the danger icon is visible to warn the players before they engage
    elseif relation < -50000 then
        return true
    -- defenders are the strongest faction ships and players are warned earlier
    elseif potentialEnemyShip:getValue("is_defender") and relation <= -30000 then
        return true
    -- ships that are enemies of the player are marked even if their faction won't show it, as these ships are hostile towards the player
    else
        local shipAI = ShipAI(playerShip)
        if shipAI and shipAI:isEnemy(potentialEnemyShip) then
            return true
        end
    end

    return false
end

end



