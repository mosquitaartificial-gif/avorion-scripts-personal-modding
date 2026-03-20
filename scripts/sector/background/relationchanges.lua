
package.path = package.path .. ";data/scripts/lib/?.lua"

include ("utility")
include ("relations")
include ("stringutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace RelationChanges
RelationChanges = {}

if onServer() then

RelationChanges.LossByType = {}
RelationChanges.LossByType[EntityType.Fighter] = 1500
RelationChanges.LossByType[EntityType.Torpedo] = 0
RelationChanges.LossByType[EntityType.Ship] = 40000
RelationChanges.LossByType[EntityType.Station] = 100000
RelationChanges.LossByType[EntityType.Turret] = 500
RelationChanges.LossFallBack = 10000

RelationChanges.HullDamages = {}
RelationChanges.ShieldDamages = {}

function RelationChanges.getUpdateInterval()
    return 2
end

function RelationChanges.initialize()
    local sector = Sector()
    sector:registerCallback("onDestroyed", "onDestroyed")
    sector:registerCallback("onTurretDestroyed", "onTurretDestroyed")
    sector:registerCallback("onBoardersLand", "onBoardersLand")
    sector:registerCallback("onBoardingSuccessful", "onBoardingSuccessful")
    sector:registerCallback("onHullHit", "onHullHit")
    sector:registerCallback("onShieldHit", "onShieldHit")
    sector:registerCallback("onTorpedoHullHit", "onTorpedoHullHit")
    sector:registerCallback("onTorpedoShieldHit", "onTorpedoShieldHit")
    sector:registerCallback("onCollision", "onCollision")
end

function RelationChanges.onDestroyed(destroyedId, destroyerId)
    local victim = Sector():getEntity(destroyedId)
    if not victim then return end

    -- no relation losses for destruction of torpedoes
    if victim.type == EntityType.Torpedo then return end

    local destroyer = Sector():getEntity(destroyerId)
    if not destroyer then return end
    if not destroyer.factionIndex then return end
    if destroyer.factionIndex <= 0 then return end

    -- no relation losses when people destroy their own stuff
    if victim.factionIndex == destroyer.factionIndex then return end

    local contributorFactionIndices = {}
    contributorFactionIndices[destroyer.factionIndex] = true
    for _, index in pairs({victim:getDamageContributors()}) do
        contributorFactionIndices[index] = true
    end

    RelationChanges.applyDestructionConsequences(victim, destroyer.factionIndex, contributorFactionIndices)
    RelationChanges.applyWitnessConsequences(victim, destroyer.factionIndex, contributorFactionIndices)
end

function RelationChanges.onTurretDestroyed(turretId, shipId, destroyerId)
    local victim = Sector():getEntity(turretId)
    if not victim then return end

    local destroyer = Sector():getEntity(destroyerId)
    if not destroyer then return end
    if not destroyer.factionIndex then return end
    if destroyer.factionIndex <= 0 then return end
    -- no relation losses when people destroy their own stuff
    if victim.factionIndex == destroyer.factionIndex then return end

    -- for turrets, only direct consequences are applied
    RelationChanges.applyDestructionConsequences(victim, destroyer.factionIndex)
end

function RelationChanges.onBoardersLand(shipId, attackingFactionIndex, firstLanding)
    if not firstLanding then return end

    local victim = Sector():getEntity(shipId)
    if not victim then return end

    RelationChanges.applyBoardingConsequences(shipId, victim.factionIndex, attackingFactionIndex)

    RelationChanges.applyWitnessConsequences(victim, attackingFactionIndex, {})
end

function RelationChanges.onBoardingSuccessful(entityId, oldFactionIndex, newFactionIndex)
    RelationChanges.applyBoardingConsequences(entityId, oldFactionIndex, newFactionIndex)
end

function RelationChanges.onCollision(entityA, entityB, damageToA, damageToB, steererA, steererB)
    RelationChanges.onHullHit(entityA, nil, steererB, damageToA, nil)
    RelationChanges.onHullHit(entityB, nil, steererA, damageToB, nil)
end

function RelationChanges.onHullHit(entityId, blockIndex, shooterId, damage)
    RelationChanges.hullHitReputationLoss(entityId, blockIndex, shooterId, damage)
end

function RelationChanges.onTorpedoHullHit(entityId, blockIndex, shooterId, damage, torpedoId)
    RelationChanges.hullHitReputationLoss(entityId, blockIndex, shooterId, damage, torpedoId)
end

function RelationChanges.hullHitReputationLoss(entityId, blockIndex, shooterId, damage)
    local shooter = Entity(shooterId)
    if not shooter then return end
    if shooter.aiOwned then return end

    local index = shooter.factionIndex
    if not index or index <= 0 then return end

    local shooterFactionIndex = shooter.factionIndex
    local shooterFaction = Faction(shooterFactionIndex)
    if not shooterFaction then return end

    local victim = Entity(entityId)
    if not victim then return end
    if not victim.aiOwned then return end

    local victimFactionIndex = victim.factionIndex
    local victimFaction = Faction(victimFactionIndex)
    if not victimFaction then return end

    -- factions are unhappy when hull is damaged
    local percentage = (victim.durability or 1) / (victim.maxDurability or 1)

    if percentage < 0.7 and damage > 0 then
        if victimFaction.isAIFaction and (shooterFaction.isPlayer or shooterFaction.isAlliance) then
            local galaxy = Galaxy()

            if galaxy:getFactionRelationStatus(victimFaction, shooterFaction) == RelationStatus.Ceasefire then
                galaxy:setFactionRelationStatus(victimFaction, shooterFaction, RelationStatus.War, true, true)
            end
        end
    end

    local tbl = RelationChanges.HullDamages[victimFactionIndex]
    if not tbl then
        tbl = {}
        RelationChanges.HullDamages[victimFactionIndex] = tbl
    end

    -- or, in case the object is very small, scale by the damage
    local lossByDamage = damage * 5.0

    local shooterData = tbl[shooterFactionIndex] or {}

    local oldValue = shooterData.value or 0
    local newValue = math.max(-3000, oldValue - lossByDamage)

    shooterData.value = math.min(oldValue, newValue)
    shooterData.lastVictimId = entityId

    tbl[shooterFactionIndex] = shooterData
end

function RelationChanges.onShieldHit(entityId, shooterId, damage)
    RelationChanges.shieldHitReputationLoss(entityId, shooterId, damage)
end


function RelationChanges.onTorpedoShieldHit(entityId, shooterId, damage, torpedoId)
    RelationChanges.shieldHitReputationLoss(entityId, shooterId, damage, nil)
end

function RelationChanges.shieldHitReputationLoss(entityId, shooterId, damage)
    local shooter = Entity(shooterId)
    if not shooter then return end
    if shooter.aiOwned then return end

    local index = shooter.factionIndex
    if not index or index <= 0 then return end

    local shooterFactionIndex = shooter.factionIndex
    local shooterFaction = Faction(shooterFactionIndex)
    if not shooterFaction then return end

    local victim = Entity(entityId)
    if not victim then return end
    if not victim.aiOwned then return end

    local victimFactionIndex = victim.factionIndex
    local victimFaction = Faction(victimFactionIndex)
    if not victimFaction then return end

    local tbl = RelationChanges.ShieldDamages[victimFactionIndex]
    if not tbl then
        tbl = {}
        RelationChanges.ShieldDamages[victimFactionIndex] = tbl
    end

    -- factions are not that unhappy when shields are damaged (shit happens)
    local maxLossByPercentage = (RelationChanges.LossByType[victim.type] or RelationChanges.LossFallBack) * 0.025
    local lossByPercentage = damage / (victim.shieldMaxDurability or damage) * maxLossByPercentage

    -- or, in case the object is very small, scale by the damage
    local lossByDamage = damage * 0.5 * (1.0 - (victim.shieldDurability or 1) / (victim.shieldMaxDurability or 1 + 1))

    -- but never lose more than 500 per single incident
    local loss = math.min(500, math.min(lossByDamage, lossByPercentage))

    local shooterData = tbl[shooterFactionIndex] or {}
    shooterData.value = (shooterData.value or 0) - loss
    shooterData.lastVictimId = entityId

    tbl[shooterFactionIndex] = shooterData
end



function RelationChanges.applyDestructionConsequences(victim, aggressorFactionIndex, contributorFactionIndices)

    if not victim.aiOwned then return end

    local loss = RelationChanges.LossByType[victim.type] or 0
    if loss == 0 then return end

    local factionA = Faction(victim.factionIndex)
    if not factionA then return end

    local factionB = Faction(aggressorFactionIndex)
    if not factionB then return end

    changeRelations(factionA, factionB, -loss, RelationChangeType.CraftDestroyed, true, true, factionA)
end

function RelationChanges.applyBoardingConsequences(shipId, defendersFactionIndex, attackersFactionIndex)
    local entity = Sector():getEntity(shipId)

    local loss = 40000
    if entity.type == EntityType.Station then loss = 100000 end

    local factionA = Faction(defendersFactionIndex)
    if not factionA then return end

    local factionB = Faction(attackersFactionIndex)
    if not factionB then return end

    changeRelations(factionA, factionB, -loss, RelationChangeType.Boarding, true, true, factionA)
end

function RelationChanges.applyWitnessConsequences(victim, aggressorFactionIndex, contributorFactionIndices)

    if not victim then return end

    local victimFaction = victim.factionIndex
    if not victimFaction or victimFaction == -1 or victimFaction == 0 then return end

    local aggressorFaction = Faction(aggressorFactionIndex)
    if not aggressorFaction then return end

    -- find all factions that are present in the sector
    local witnessingCrafts = {Sector():getEntitiesByComponent(ComponentType.Crew)}
    local witnessingFactions = {}
    for _, entity in pairs(witnessingCrafts) do
        if entity.factionIndex and entity.factionIndex > 0 then
            witnessingFactions[entity.factionIndex] = 1
        end
    end

    -- secret contractors simply ignore whatever happens - they just look the other way
    local secretContractor = victim:getValue("secret_contractor")
    if secretContractor and type(secretContractor) == "number" then
        witnessingFactions[secretContractor] = nil
    end

    witnessingFactions[victim.factionIndex] = nil

    local civilShipNotificationSent = false

    -- walk over all witnessing factions and determine relations to victim ship
    for factionIndex, divider in pairs(witnessingFactions) do
        -- the faction is a third party who witnessed the destruction
        local faction = Faction(factionIndex)

        -- only react for AI Factions
        if faction and faction.isAIFaction then

            local relationToVictim = faction:getRelation(victimFaction)
            local change = 0

            if relationToVictim.level > 30000 or relationToVictim.level < -30000 then
                change = -relationToVictim.level / 50
                local relationsToKiller = faction:getRelations(aggressorFactionIndex)

                 -- getting disliked by a faction that already doesn't like you is easy
                 -- getting liked by a faction that already likes you takes more time
                if relationsToKiller < -30000 and change < 0 then change = change * 1.5 end
                if relationsToKiller > 30000 and change > 0 then change = change * 0.75 end

                -- modify the changes depending on faction properties
                local aggressive = faction:getTrait("aggressive") -- -0.5 to 1.5
                change = change + aggressive * 1500
            end

            if not contributorFactionIndices[factionIndex] then
                if victim:hasScript("civilship.lua") and relationToVictim.status ~= RelationStatus.War then
                    -- honorable factions won't like it that players attack civil ships
                    -- opportunistic factions don't care (it's not their own after all)
                    local honorDelta = math.max(0, 10000 + (20000 * faction:getTrait("honorable") or 0))
                    change = change - honorDelta

                    if honorDelta > 0 and aggressorFaction.isPlayer and not civilShipNotificationSent then
                        civilShipNotificationSent = true
                        Player(aggressorFactionIndex):sendChatMessage("", 2, "You attacked a civil ship. Relations with witnessing honorable factions worsened."%_t)
                    end
                end
            else
                -- relations can't worsen when the observing faction helped destroy the ship
                change = math.max(change / 2, 0)
            end

            -- relations can't worsen when the observing faction has really bad relations to the victim
            if relationToVictim.level < -70000 then
                change = math.max(change, 0)
            end

            -- using nil as change type since this relation change has already been determined in detail above
            changeRelations(aggressorFaction, faction, change, nil, true, true, faction)
        end
    end

end

function RelationChanges.updateServer(timeStep)

    for victimFactionIndex, shooters in pairs(RelationChanges.HullDamages) do
        for shooterFactionIndex, data in pairs(shooters) do
            changeRelations(victimFactionIndex, shooterFactionIndex, data.value, RelationChangeType.HullDamaged, true, true, data.lastVictimId)
        end
    end
    RelationChanges.HullDamages = {}

    for victimFactionIndex, shooters in pairs(RelationChanges.ShieldDamages) do
        for shooterFactionIndex, data in pairs(shooters) do
            changeRelations(victimFactionIndex, shooterFactionIndex, data.value, RelationChangeType.ShieldsDamaged, true, true, data.lastVictimId)
        end
    end
    RelationChanges.ShieldDamages = {}

end

end
