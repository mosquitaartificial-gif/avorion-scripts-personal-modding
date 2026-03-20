package.path = package.path .. ";data/scripts/lib/?.lua"

include("utility")
include("randomext")
include("faction")

local cCounter = 0
local function c()
    cCounter = cCounter + 1
    return cCounter
end

-- All relation change types. When you want to change relations and the type doesn't fit into any category, use 'nil'.
-- Using 'nil' in changeRelations() will not make the change be influenced by faction traits or characteristics.
-- If the relation change should be influenced by a faction trait but doesn't exist in the below list,
-- then a new RelationChangeType must most likely be introduced.
RelationChangeType =
{
    -- placeholder for 'nothing special happens', also used when 'nil' is passed
    Default = c(),

    -- bad combat
    CraftDestroyed = c(),
    ShieldsDamaged = c(),
    HullDamaged = c(),
    Boarding = c(),

    -- good combat
    CombatSupport = c(), -- when the player helps the AI faction out in combat

    -- illegal activities
    Smuggling = c(),
    Raiding = c(),
    GeneralIllegal = c(),

    -- commerce
    ServiceUsage = c(), -- ie. repair dock, shipyard, etc.
    ResourceTrade = c(), -- resources
    GoodsTrade = c(), -- goods & cargo
    EquipmentTrade = c(), -- upgrades and other items
    WeaponsTrade = c(), -- turrets, torpedoes and fighters
    Commerce = c(), -- everything else / general commerce

    -- other
    Tribute = c(),

}

RelationChangeNames = {}
RelationChangeNames[RelationChangeType.Default] = "Default"
RelationChangeNames[RelationChangeType.CraftDestroyed] = "CraftDestroyed"
RelationChangeNames[RelationChangeType.ShieldsDamaged] = "ShieldsDamaged"
RelationChangeNames[RelationChangeType.HullDamaged] = "HullDamaged"
RelationChangeNames[RelationChangeType.Boarding] = "Boarding"
RelationChangeNames[RelationChangeType.CombatSupport] = "CombatSupport"
RelationChangeNames[RelationChangeType.Smuggling] = "Smuggling"
RelationChangeNames[RelationChangeType.Raiding] = "Raiding"
RelationChangeNames[RelationChangeType.GeneralIllegal] = "GeneralIllegal"
RelationChangeNames[RelationChangeType.ServiceUsage] = "ServiceUsage"
RelationChangeNames[RelationChangeType.ResourceTrade] = "ResourceTrade"
RelationChangeNames[RelationChangeType.GoodsTrade] = "GoodsTrade"
RelationChangeNames[RelationChangeType.EquipmentTrade] = "EquipmentTrade"
RelationChangeNames[RelationChangeType.WeaponsTrade] = "WeaponsTrade"
RelationChangeNames[RelationChangeType.Commerce] = "Commerce"
RelationChangeNames[RelationChangeType.Tribute] = "Tribute"

RelationChangeMaxCap = {}
RelationChangeMaxCap[RelationChangeType.ServiceUsage] = 45000
RelationChangeMaxCap[RelationChangeType.ResourceTrade] = 45000
RelationChangeMaxCap[RelationChangeType.GoodsTrade] = 65000
RelationChangeMaxCap[RelationChangeType.EquipmentTrade] = 75000
RelationChangeMaxCap[RelationChangeType.WeaponsTrade] = 75000
RelationChangeMaxCap[RelationChangeType.Commerce] = 50000
RelationChangeMaxCap[RelationChangeType.Tribute] = 0

RelationChangeMinCap = {}
RelationChangeMinCap[RelationChangeType.Smuggling] = -75000
RelationChangeMinCap[RelationChangeType.GeneralIllegal] = -75000


function hardCapLoss(relations, delta, threshold)
    if not threshold then return delta end
    if delta > 0 then return delta end

    return -math.min(-delta, math.max(100, relations - threshold))
end

function hardCapGain(relations, delta, threshold)
    if not threshold then return delta end
    if delta < 0 then return delta end

    return math.min(delta, math.max(0, threshold - relations))
end

function softCapLoss(relations, delta, threshold)
    if not threshold then return delta end
    if delta > 0 then return delta end
    if relations <= threshold then return delta end

    return -math.min(-delta, relations - threshold)
end

function softCapGain(relations, delta, threshold)
    if not threshold then return delta end
    if delta < 0 then return delta end
    if relations >= threshold then return delta end

    return math.min(delta, threshold - relations)
end

function getInteractingFactions(a, b)
    local galaxy = Galaxy()

    if atype(a) == "string" then a = Entity(a) end
    if atype(a) == "Uuid" then a = Entity(a) end
    if atype(a) == "Entity" then a = a.factionIndex end
    if type(a) == "number" then a = Faction(a) end
    if not a then return end

    if atype(b) == "string" then b = Entity(b) end
    if atype(b) == "Uuid" then b = Entity(b) end
    if atype(b) == "Entity" then b = b.factionIndex end
    if type(b) == "number" then b = Faction(b) end
    if not b then return end

    -- is one of the two a player faction and the other an ai faction?
    local player -- we handle alliances and players the same in this case
    local ai
    if (a.isAlliance or a.isPlayer) and b.isAIFaction then
        if a.isAlliance then
            player = Alliance(a.index)
        else
            player = Player(a.index)
        end

        ai = b
    elseif (b.isAlliance or b.isPlayer) and a.isAIFaction then
        if b.isAlliance then
            player = Alliance(b.index)
        else
            player = Player(b.index)
        end

        ai = a
    end

    return a, b, ai, player
end

function findChatteringEntity(identifier)
    local chatterer = identifier

    if atype(chatterer) == "string" then return Entity(chatterer) end
    if atype(chatterer) == "Uuid" then return Entity(chatterer) end
    if atype(chatterer) == "Entity" then return chatterer end

    local factionIndex = nil

    if atype(chatterer) == "Faction" then factionIndex = chatterer.index end
    if type(chatterer) == "number" then factionIndex = chatterer end

    if factionIndex then
        local candidates = {}
        for _, entity in pairs({Sector():getEntitiesByComponent(ComponentType.Crew)}) do
            if entity:hasComponent(ComponentType.Plan) and entity.factionIndex == factionIndex then
                table.insert(candidates, entity)
            end
        end

        return randomEntry(candidates)
    end
end

function changeRelations(a, b, delta, changeType, notifyA, notifyB, chatterer)

    if not delta or delta == 0 then return end

    local a, b, ai, player = getInteractingFactions(a, b)
    if not a or not b then return end
    if a.isAIFaction and b.isAIFaction then return end
    if a.index == b.index then return end
    if a.alwaysAtWar or b.alwaysAtWar then return end
    if a.staticRelationsToAll or b.staticRelationsToAll then return end
    if a.staticRelationsToPlayers and (b.isPlayer or b.isAlliance) then return end
    if b.staticRelationsToPlayers and (a.isPlayer or a.isAlliance) then return end

    local galaxy = Galaxy()

    local relations = galaxy:getFactionRelations(a, b)
    local status = galaxy:getFactionRelationStatus(a, b)
    local newStatus

    if player and ai then
        -- just to make sure that a 'nil' won't cause crashes
        changeType = changeType or RelationChangeType.Default

        local statusChangeThresholdOffset = getStatusChangeThresholdOffset(ai)

--        print ("Relation Change: " .. delta .. " (".. RelationChangeNames[changeType] .. ")")

        delta, chatterMessage = getCustomFactionRelationDelta(ai, delta, changeType)

        -- cap reputation gain or loss to a maximum (ie. trading won't improve relations beyond a certain point)
        local uncappedDelta = delta
        if delta > 0 then
            delta = hardCapGain(relations, delta, RelationChangeMaxCap[changeType])
        elseif delta < 0 then
            delta = hardCapLoss(relations, delta, RelationChangeMinCap[changeType])
        end

        if status == RelationStatus.Neutral then
--            print ("Current Sqtatus: Neutral")

            -- Craft destruction and boarding are considered acts of war
            -- damaging shields and hull can be, too, but they must be handled with more context, so we can't handle them here
            if uncappedDelta < 0 then
                if changeType == RelationChangeType.CraftDestroyed
                        or changeType == RelationChangeType.Boarding
                        or changeType == RelationChangeType.Raiding then

                    -- if relations are this bad, war is declared
                    if relations + delta < (-80000 + statusChangeThresholdOffset) then
                        newStatus = RelationStatus.War
                    end
                end

                if changeType == RelationChangeType.HullDamaged then
                    -- doing something bad at -100k means war
                    if uncappedDelta < 0 and relations <= math.max(-100000, -100000 + statusChangeThresholdOffset) then
                        newStatus = RelationStatus.War
                    end
                end
            end

        elseif status == RelationStatus.Ceasefire then
--            print ("Current Status: Ceasefire")

            -- Craft destruction and boarding are considered acts of war
            -- damaging shields and hull can be, too, but they must be handled with more context, so we can't handle them here
            if uncappedDelta < 0
                    and (changeType == RelationChangeType.CraftDestroyed
                    or changeType == RelationChangeType.Boarding
                    or changeType == RelationChangeType.Raiding) then

                -- declare war
                newStatus = RelationStatus.War
            end

            -- a ceasefire turns to Neutral when relations become good enough
            if uncappedDelta > 0 and relations + delta > (-30000 + statusChangeThresholdOffset) then
                -- turn neutral
                newStatus = RelationStatus.Neutral
            end

            -- reaching -100k during ceasefire means war
            if uncappedDelta < 0 and relations + delta <= math.max(-100000, -100000 + statusChangeThresholdOffset) then
                newStatus = RelationStatus.War
            end

        elseif status == RelationStatus.War then
--            print ("Current Status: War")
            -- less gain when at war
            if uncappedDelta > 0 then delta = delta / 2 end

        elseif status == RelationStatus.Allies then
--            print ("Current Status: Allies")

            if changeType == RelationChangeType.Raiding or changeType == RelationChangeType.Boarding then
                -- raiding or boarding an allied ship will turn the pact to neutral
                newStatus = RelationStatus.Neutral
            else
                -- less loss when allied
                if uncappedDelta < 0 then delta = delta / 2 end

                -- also there are soft caps for losing reputation (if a big loss would go beyond the threshold, it's stopped by the threshold)
                delta = softCapLoss(relations, delta, 90000)
                delta = softCapLoss(relations, delta, 80000)

                if relations + delta < (75000 + statusChangeThresholdOffset) then
                    newStatus = RelationStatus.Neutral
                end
            end
        end

        if uncappedDelta < 0 and relations + delta < (-80000 + statusChangeThresholdOffset) then
            terminateReconstructionTreaty(ai, player)
        end

        if delta ~= 0 and status ~= RelationStatus.War and chatterMessage and chatterer and player.isPlayer then
            local chatteringEntity = findChatteringEntity(chatterer)
            if chatteringEntity then
                local x, y = Sector():getCoordinates()
                local px, py = player:getSectorCoordinates()

                if x == px and y == py then
                    player:addScriptOnce("background/reactionchattermemory.lua")
                    player:invokeFunction("reactionchattermemory.lua", "trySendChatter", chatteringEntity, changeType, chatterMessage)
                end
            end
        end
    end

    -- finally change relations and set a new status, if there is one
    galaxy:changeFactionRelations(a, b, delta, notifyA, notifyB)

    if newStatus and newStatus ~= status then
        setRelationStatus(a, b, newStatus, notifyA, notifyB)
    end
end

function setRelationStatus(a, b, status, notifyA, notifyB)
    local a, b, ai, player = getInteractingFactions(a, b)
    if a.isAIFaction and b.isAIFaction then return end

    local galaxy = Galaxy()
    local relations = galaxy:getFactionRelations(a, b)
    local statusBefore = galaxy:getFactionRelationStatus(a, b)

    if status == RelationStatus.War then
        -- war means no more reconstruction
        if player and ai then
            terminateReconstructionTreaty(ai, player)
        end
    elseif status == RelationStatus.Ceasefire then
        -- set to "neutral" immediately when relations go from "War, but many points" to "Ceasefire, but many points"
        if relations > -30000 then status = RelationStatus.Neutral end
    end

    if statusBefore ~= status then
        if player and ai then
            local key = "statuschange_timestamp_" .. tostring(player.index)
            ai:setValue(key, Server().unpausedRuntime)
        end

        galaxy:setFactionRelationStatus(a, b, status, notifyA, notifyB)

        if player and ai then
            if status == RelationStatus.War and player.isPlayer then
                -- send declaration of war per mail
                sendDeclarationOfWarMail(player, ai)
            end

            player:sendCallback("aiFactionDeclaredWar", ai.index)
        end
    end
end

function sendDeclarationOfWarMail(player, aiFaction)
    local baseText = "To %1%,\n\nThis is a declaration of war. The sender of this declaration and %1% are now officially at war with each other.\n\n%2%"%_T
    local stateForm = aiFaction:getValue("state_form_type") or FactionStateFormType.Vanilla

    local textByStateForm = {}
    textByStateForm[FactionStateFormType.Vanilla] = "Your actions force us to defend ourselves and our territory and we see no other option."%_t
    textByStateForm[FactionStateFormType.Organization] = "The freedom of our people is our most important asset. In order to continue to protect it from you, we are forced to take this step."%_t
    textByStateForm[FactionStateFormType.Emirate] = "Our task is to protect those over whom we rule. Your attacks against us force us to take this step."%_t
    textByStateForm[FactionStateFormType.Kingdom] = "Our king orders that your ships and stations are to be attacked on sight from now on."%_t
    textByStateForm[FactionStateFormType.Empire] = "Our advisors have come to the conclusion that your actions can now only be met with a show of arms."%_t
    textByStateForm[FactionStateFormType.States] = "War is the only logical consequence of your behavior towards our ships and stations."%_t
    textByStateForm[FactionStateFormType.Planets] = "Despite our hope for understanding, you have continued to cause us problems. The only remaining option is war."%_t
    textByStateForm[FactionStateFormType.Republic] = "The Senate has decided to no longer tolerate your actions. War is the logical consequence."%_t
    textByStateForm[FactionStateFormType.Dominion] = "Your attacks will no longer be tolerated. You reap what you sowed."%_t
    textByStateForm[FactionStateFormType.Army] = "From now on, we will answer your actions with force of arms. Do not expect mercy."%_t
    textByStateForm[FactionStateFormType.Clan] = "You challenged us and therefore now have to live with the consequences."%_t
    textByStateForm[FactionStateFormType.Buccaneers] = "We have tolerated your actions long enough. From now on our fleet will attack you without further warning."%_t
    textByStateForm[FactionStateFormType.Church] = "We have turned the other cheek long enough, from now on it's an eye for an eye!"%_t
    textByStateForm[FactionStateFormType.Followers] = "We can no longer tolerate your contempt for the prophecy. War is therefore the logical consequence."%_t
    textByStateForm[FactionStateFormType.Corporation] = "Due to your misconduct the board has unanimously decided to take this step."%_t
    textByStateForm[FactionStateFormType.Syndicate] = "To protect our economic interests we have to take this step."%_t
    textByStateForm[FactionStateFormType.Guild] = "Since you have repeatedly failed to cease your attacks despite our warnings, we feel compelled to back up our words with actions."%_t
    textByStateForm[FactionStateFormType.Conglomerate] = "Your actions restrict our ability to trade too much. To protect us, this is the only way."%_t
    textByStateForm[FactionStateFormType.Federation] = "Despite our hope for understanding, you have continued to cause us problems. We are left with only this step."%_t
    textByStateForm[FactionStateFormType.Alliance] = "You have exploited our patience long enough. Now you broke the camel's back. The consequence of this is war."%_t
    textByStateForm[FactionStateFormType.Commonwealth] = "We no longer see ourselves in a position to ignore your aggressiveness. This forces us to take this step."%_t
    textByStateForm[FactionStateFormType.Collective] = "You have repeatedly resisted the path of unity. We are now left only with the path of war."%_t

    local mail = Mail()
    mail.header = "Declaration of War"%_T
    mail.sender = aiFaction.unformattedName
    mail.text = Format(baseText, player.name, textByStateForm[stateForm])
    player:addMail(mail)
end

function getStatusChangeThresholdOffset(ai)
    local trusting = ai:getTrait("trusting")

    -- very trusting: less points required for relation changes
    -- very mistrustful: more points required for relation changes
    if trusting > 0.85 then
        return -10000
    elseif trusting > 0.5 then
        return -5000
    elseif trusting < -0.85 then
        return 10000
    elseif trusting < -0.5 then
        return 5000
    end

    return 0
end

function terminateReconstructionTreaty(ai, player)
    if player.isAlliance then return end

    local rx, ry = player:getReconstructionSiteCoordinates()
    local hx, hy = player:getHomeSectorCoordinates()

    if hx ~= rx or hy ~= ry then
        local reconstructionFaction = Galaxy():getControllingFaction(rx, ry)
        if reconstructionFaction and reconstructionFaction.index == ai.index then
            local hx, hy = player:getHomeSectorCoordinates()

            player:setReconstructionSiteCoordinates(hx, hy)

            local mail = Mail()
            mail.header = "Termination of Reconstruction Site"%_T
            mail.sender = ai.name
            mail.text = "Dear Ex-Customer,\n\nDue to recent, very concerning developments in the politics of our two factions, we were forced to terminate our mutual Reconstruction Agreement. Upon destruction, your drone will no longer be reconstructed at our Repair Dock.\nOnce relations between our two factions improve, you're welcome to sign another Reconstruction Site treaty. Don't be afraid to come back once you're welcome here again.\n\nBest wishes,\nRepair Dock Management"%_T
            player:addMail(mail)
        end
    end

end

RelationChangeMultipliers = {}
RelationChangeMultipliers[RelationChangeType.Default] = {}

RelationChangeMultipliers[RelationChangeType.CraftDestroyed] = {forgiving = 1, peaceful = -2, careful = -1}
RelationChangeMultipliers[RelationChangeType.ShieldsDamaged] = {forgiving = 1, careful = -1}
RelationChangeMultipliers[RelationChangeType.HullDamaged] = {forgiving = 1, peaceful = -2, careful = -1}
RelationChangeMultipliers[RelationChangeType.Boarding] = {forgiving = 1, peaceful = -2, careful = -1}

RelationChangeMultipliers[RelationChangeType.CombatSupport] = {peaceful = 2, aggressive = -1, careful = 1, honorable = 1}

RelationChangeMultipliers[RelationChangeType.Smuggling] = {forgiving = 1, careful = -1, generous = 1, greedy = -1, opportunistic = 1, honorable = -1, mistrustful = -1}
RelationChangeMultipliers[RelationChangeType.Raiding] = {forgiving = 1, peaceful = -2, careful = -1, greedy = -1, honorable = -1, mistrustful = -1}
RelationChangeMultipliers[RelationChangeType.GeneralIllegal] = {forgiving = 1, generous = 1, greedy = -1, honorable = -1, mistrustful = -1}

RelationChangeMultipliers[RelationChangeType.ServiceUsage] = {peaceful = 1, greedy = 1, brave = -1}
RelationChangeMultipliers[RelationChangeType.ResourceTrade] = {greedy = 1, brave = -1}
RelationChangeMultipliers[RelationChangeType.GoodsTrade] = {peaceful = 1, greedy = 1, brave = -1}
RelationChangeMultipliers[RelationChangeType.EquipmentTrade] = {peaceful = 1, greedy = 1, brave = -1}
RelationChangeMultipliers[RelationChangeType.WeaponsTrade] = {aggressive = 1, greedy = 1, brave = -1}
RelationChangeMultipliers[RelationChangeType.Commerce] = {peaceful = 1, greedy = 1, brave = -1}

RelationChangeMultipliers[RelationChangeType.Tribute] = {peaceful = 1, aggressive = -1, careful = -1, greedy = 2, mistrustful = -1}


RelationChangeChatters = {}
RelationChangeChatters[RelationChangeType.Default] = {} -- empty on purpose, nothing happens here

RelationChangeChatters[RelationChangeType.CraftDestroyed] = {}
RelationChangeChatters[RelationChangeType.CraftDestroyed][-2] = "We swear revenge for our fallen friends!"%_t
RelationChangeChatters[RelationChangeType.CraftDestroyed][-1] = "Your deeds will not be forgotten!"%_t
RelationChangeChatters[RelationChangeType.CraftDestroyed][1] = "There will be consequences!"%_t
RelationChangeChatters[RelationChangeType.CraftDestroyed][2] = "This will put a significant strain on our relationships!"%_t

RelationChangeChatters[RelationChangeType.ShieldsDamaged] = {}
RelationChangeChatters[RelationChangeType.ShieldsDamaged][-2] = "Cease fire immediately, you barbarian!"%_t
RelationChangeChatters[RelationChangeType.ShieldsDamaged][-1] = "Cease fire at once!"%_t
RelationChangeChatters[RelationChangeType.ShieldsDamaged][1] = "Hey, stop!"%_t
RelationChangeChatters[RelationChangeType.ShieldsDamaged][2] = "Watch where you're shooting!"%_t

RelationChangeChatters[RelationChangeType.HullDamaged] = {}
RelationChangeChatters[RelationChangeType.HullDamaged][-2] = "Cease fire at once or there will be consequences!"%_t
RelationChangeChatters[RelationChangeType.HullDamaged][-1] = "Cease fire at once!"%_t
RelationChangeChatters[RelationChangeType.HullDamaged][1] = "Hey, stop!"%_t
RelationChangeChatters[RelationChangeType.HullDamaged][2] = "Watch where you're shooting!"%_t

RelationChangeChatters[RelationChangeType.Boarding] = {}
RelationChangeChatters[RelationChangeType.Boarding][-2] = "Just don't think that anyone will want to deal with you again after this action!"%_t
RelationChangeChatters[RelationChangeType.Boarding][-1] = "How dare you? That's despicable."%_t
RelationChangeChatters[RelationChangeType.Boarding][1] = "This is going to have consequences for you!"%_t
RelationChangeChatters[RelationChangeType.Boarding][2] = "This boarding will have consequences for our relations."%_t

RelationChangeChatters[RelationChangeType.CombatSupport] = {}
RelationChangeChatters[RelationChangeType.CombatSupport][-2] = "We would have made it without your help. Thanks anyway."%_t
RelationChangeChatters[RelationChangeType.CombatSupport][-1] = "Thank you, but no help would have been needed."%_t
RelationChangeChatters[RelationChangeType.CombatSupport][1] = "It's good that you were there. We gladly accept help in combat."%_t
RelationChangeChatters[RelationChangeType.CombatSupport][2] = "Thank you for your assistance! In fights, any help is extremely welcome!"%_t

RelationChangeChatters[RelationChangeType.Smuggling] = {}
RelationChangeChatters[RelationChangeType.Smuggling][-2] = "Smuggler scum. That truly is the dregs of the population."%_t
RelationChangeChatters[RelationChangeType.Smuggling][-1] = "This dishonorable smuggling will have consequences for our relations!"%_t
RelationChangeChatters[RelationChangeType.Smuggling][1] = "Buy yourself a license so that something like this doesn't happen again."%_t
RelationChangeChatters[RelationChangeType.Smuggling][2] = "In the future, buy a license for these goods."%_t

RelationChangeChatters[RelationChangeType.Raiding] = {}
RelationChangeChatters[RelationChangeType.Raiding][-2] = "Lousy pirate scum!"%_t
RelationChangeChatters[RelationChangeType.Raiding][-1] = "Damn pirates. We won't just accept that!"%_t
RelationChangeChatters[RelationChangeType.Raiding][1] = "We will report your behavior. There will be consequences!"%_t
RelationChangeChatters[RelationChangeType.Raiding][2] = "Piracy is not accepted. There will be consequences!"%_t

RelationChangeChatters[RelationChangeType.GeneralIllegal] = {}
RelationChangeChatters[RelationChangeType.GeneralIllegal][-2] = "Criminals! Such misconduct is not accepted here."%_t
RelationChangeChatters[RelationChangeType.GeneralIllegal][-1] = "I'll report that. You'll have to do a lot of work to make up for that."%_t
RelationChangeChatters[RelationChangeType.GeneralIllegal][1] = "Stop this immediately, this is illegal! There will be consequences!"%_t
RelationChangeChatters[RelationChangeType.GeneralIllegal][2] = "Stop it, that's illegal!"%_t

RelationChangeChatters[RelationChangeType.ServiceUsage] = {}
RelationChangeChatters[RelationChangeType.ServiceUsage][-2] = "Well, business is business."%_t
RelationChangeChatters[RelationChangeType.ServiceUsage][-1] = "Thank you for using our service."%_t
RelationChangeChatters[RelationChangeType.ServiceUsage][1] = "Pleasure doing business with you. Goodbye!"%_t
RelationChangeChatters[RelationChangeType.ServiceUsage][2] = "It was a pleasure. We hope to see you here again soon!"%_t

RelationChangeChatters[RelationChangeType.ResourceTrade] = {}
RelationChangeChatters[RelationChangeType.ResourceTrade][-2] = "Resource trading can't be avoided, everyone knows that."%_t
RelationChangeChatters[RelationChangeType.ResourceTrade][-1] = "There is little credit in resource trade here."%_t
RelationChangeChatters[RelationChangeType.ResourceTrade][1] = "Pleasant to do peaceful business with you."%_t
RelationChangeChatters[RelationChangeType.ResourceTrade][2] = "We place a high value on peaceful resource transactions. Gladly again soon."%_t

RelationChangeChatters[RelationChangeType.GoodsTrade] = {}
RelationChangeChatters[RelationChangeType.GoodsTrade][-2] = "Trading goods is not a high priority for us. Thanks for the business anyway."%_t
RelationChangeChatters[RelationChangeType.GoodsTrade][-1] = "We have little regard for trading."%_t
RelationChangeChatters[RelationChangeType.GoodsTrade][1] = "We would be happy to trade goods peacefully with you even more often."%_t
RelationChangeChatters[RelationChangeType.GoodsTrade][2] = "Peaceful trade is the best! Come and see us again soon!"%_t

RelationChangeChatters[RelationChangeType.EquipmentTrade] = {}
RelationChangeChatters[RelationChangeType.EquipmentTrade][-2] = "Equipment trade does not have a good reputation here. But thanks for the business."%_t
RelationChangeChatters[RelationChangeType.EquipmentTrade][-1] = "We have little regard for equipment trading."%_t
RelationChangeChatters[RelationChangeType.EquipmentTrade][1] = "Pleasant to do peaceful business with you."%_t
RelationChangeChatters[RelationChangeType.EquipmentTrade][2] = "We place a high value on peaceful business. Gladly again soon."%_t

RelationChangeChatters[RelationChangeType.WeaponsTrade] = {}
RelationChangeChatters[RelationChangeType.WeaponsTrade][-2] = "Weapons trade does not have a good reputation here. But thanks for the business."%_t
RelationChangeChatters[RelationChangeType.WeaponsTrade][-1] = "We have little regard for weapon trading."%_t
RelationChangeChatters[RelationChangeType.WeaponsTrade][1] = "Thank you for doing business!"%_t
RelationChangeChatters[RelationChangeType.WeaponsTrade][2] = "Always a pleasure doing business with you. Trading weapons is honorable and important."%_t

RelationChangeChatters[RelationChangeType.Commerce] = {}
RelationChangeChatters[RelationChangeType.Commerce][-2] = "Being a trader is not held in high esteem in this area."%_t
RelationChangeChatters[RelationChangeType.Commerce][-1] = "It's hard to get a high reputation with trade here."%_t
RelationChangeChatters[RelationChangeType.Commerce][1] = "Thank you for doing business!"%_t
RelationChangeChatters[RelationChangeType.Commerce][2] = "It was a pleasure doing business with you. Hope to see you soon!"%_t

RelationChangeChatters[RelationChangeType.Tribute] = {}
RelationChangeChatters[RelationChangeType.Tribute][-2] = "Thanks for the tribute, but we still can't be bought."%_t
RelationChangeChatters[RelationChangeType.Tribute][-1] = "Thank you for your tribute."%_t
RelationChangeChatters[RelationChangeType.Tribute][1] = "Thank you, this tribute is appreciated."%_t
RelationChangeChatters[RelationChangeType.Tribute][2] = "Thank you for your tribute. We look forward to working with you!"%_t


function getCustomFactionRelationDelta(aiFaction, delta, changeType)
    local multipliers = RelationChangeMultipliers[changeType]
    if not multipliers then return end

    local amplifier = 0

    for trait, multiplier in pairs(multipliers) do
        local value = aiFaction:getTrait(trait)

        -- traits only kick in if they actually mean something
        if value and value > 0 then
            -- value is between 0 and 1
            -- multiplier is between -2 and 2
            -- in total, 'factor' can vary between -2x and 2x (x being the value below)
            local factor = value * multiplier * 0.25
            delta = delta + math.abs(delta) * factor

            amplifier = amplifier + value * multiplier
        end
    end

    local chatters = RelationChangeChatters[changeType]
    local chatterMessage = nil
    if chatters then
        local chatterIndex = math.min(2, math.max(-2, round(amplifier * 2)))
        chatterMessage = chatters[chatterIndex]
    end

    return delta, chatterMessage
end
