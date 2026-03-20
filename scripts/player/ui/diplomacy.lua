package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
include("utility")
include("callable")
include("relations")


local Diplomacy = {}
Diplomacy.allyNegotiationRelations = 95000

if onServer() then

function Diplomacy:getInteractingParties(factionIndex, allowInteractionWithPlayers)
    local actor, player = self.getUserFaction()
    if not actor or not player then
--        print("no actor")
        return
    end

    local faction = Faction(factionIndex)
    if not faction then
--        print("no faction")
        return
    end

    if (faction.isPlayer or faction.isAlliance) and not allowInteractionWithPlayers then
        player:sendChatMessage("", ChatMessageType.Error, "You can't negotiate relations with player factions."%_T)
        return
    end

    local relation = actor:getRelation(factionIndex)
    if not relation then
--        print("no relations")
        return
    end

    if relation.isStatic or faction.staticRelationsToPlayers or faction.staticRelationsToAll or
            faction:hasStaticRelationsToFaction(actor.index) or faction.alwaysAtWar then
--        print("static relations")
        player:sendChatMessage("", ChatMessageType.Error, "This faction won't negotiate with you."%_T)
        return
    end

    local eradicatedFactions = getGlobal("eradicated_factions") or {}
    if eradicatedFactions[faction.index] == true then
        player:sendChatMessage("", ChatMessageType.Error, "You can't negotiate with an eradicated faction"%_T)
        return
    end

    if actor.isAlliance and not actor:hasPrivilege(player.index, AlliancePrivilege.NegotiateRelations) then
        player:sendChatMessage("", ChatMessageType.Error, "You don't have alliance permissions to negotiate."%_T)
        return
    end

    return actor, player, faction, relation
end

function Diplomacy:setWarWithFaction(factionIndex)
    local actor, player, faction, relation = self:getInteractingParties(factionIndex, true)
    if not actor then return end

    if relation.status == RelationStatus.Allies then
        player:sendChatMessage("", ChatMessageType.Error, "You can't declare war on an ally."%_T)
        return
    elseif relation.status == RelationStatus.War then
        player:sendChatMessage("", ChatMessageType.Error, "You are already at war with this faction."%_T)
        return
    end

    if actor.isPlayer then
        if faction.isAlliance then
            faction = Alliance(faction.index)

            if faction and actor.allianceIndex == faction.index then
                -- check privilege
                if faction:hasPrivilege(player.index, AlliancePrivilege.NegotiateRelations) then
                    setRelationStatus(actor, faction, RelationStatus.War, true, true)
                    return
                else
                    player:sendChatMessage("", ChatMessageType.Error, "You don't have permissions to negotiate relations."%_t)
                    return
                end
            end
        end

    elseif actor.isAlliance then
        if faction.isPlayer then
            faction = Player(faction.index)

            if faction and faction.allianceIndex == actor.index then
                -- check privilege
                if actor:hasPrivilege(player.index, AlliancePrivilege.NegotiateRelations) then
                    setRelationStatus(actor, faction, RelationStatus.War, true, true)
                    return
                else
                    player:sendChatMessage("", ChatMessageType.Error, "You don't have permissions to negotiate relations."%_t)
                    return
                end
            end
        end
    end

    setRelationStatus(actor, faction, RelationStatus.War, true, true)
end

function Diplomacy:abandonAllianceWithFaction(factionIndex)
    local actor, player, faction, relation = self:getInteractingParties(factionIndex, true)
    if not actor then return end

    if relation.status ~= RelationStatus.Allies then
        player:sendChatMessage("", ChatMessageType.Error, "You are not allied with this faction."%_T)
        return
    end

    if actor.isPlayer then
        if faction.isAlliance then
            faction = Alliance(faction.index)

            if faction and actor.allianceIndex == faction.index then
                -- check privilege
                if faction:hasPrivilege(player.index, AlliancePrivilege.NegotiateRelations) then
                    setRelationStatus(actor, faction, RelationStatus.Neutral, true, true)
                    return
                else
                    player:sendChatMessage("", ChatMessageType.Error, "You don't have permissions to negotiate relations."%_t)
                    return
                end
            end
        end

    elseif actor.isAlliance then
        if faction.isPlayer then
            faction = Player(faction.index)

            if faction and faction.allianceIndex == actor.index then
                -- check privilege
                if actor:hasPrivilege(player.index, AlliancePrivilege.NegotiateRelations) then
                    setRelationStatus(actor, faction, RelationStatus.Neutral, true, true)
                    return
                else
                    player:sendChatMessage("", ChatMessageType.Error, "You don't have permissions to negotiate relations."%_t)
                    return
                end
            end
        end
    end

    setRelationStatus(actor, faction, RelationStatus.Neutral, true, true)
end

function Diplomacy:setCeasefireWithFaction(factionIndex)
    local actor, player, faction, relation = self:getInteractingParties(factionIndex, true)
    if not actor then return end

    if relation.status ~= RelationStatus.War then
        player:sendChatMessage("", ChatMessageType.Error, "You are not at war with this faction."%_T)
        return
    end

    -- this function is only for negotiations between a player and his own alliance
    if actor.isPlayer then
        if faction.isAlliance then
            faction = Alliance(faction.index)

            if faction and actor.allianceIndex == faction.index then
                -- check privilege
                if faction:hasPrivilege(player.index, AlliancePrivilege.NegotiateRelations) then
                    setRelationStatus(actor, faction, RelationStatus.Ceasefire, true, true)
                    return
                else
                    player:sendChatMessage("", ChatMessageType.Error, "You don't have permissions to negotiate relations."%_t)
                    return
                end
            end
        end

    elseif actor.isAlliance then
        if faction.isPlayer then
            faction = Player(faction.index)

            if faction and faction.allianceIndex == actor.index then
                -- check privilege
                if actor:hasPrivilege(player.index, AlliancePrivilege.NegotiateRelations) then
                    setRelationStatus(actor, faction, RelationStatus.Ceasefire, true, true)
                    return
                else
                    player:sendChatMessage("", ChatMessageType.Error, "You don't have permissions to negotiate relations."%_t)
                    return
                end
            end
        end
    end

    player:sendChatMessage("", ChatMessageType.Information, "Initiate a player trade to negotiate relations."%_t)
end

function Diplomacy:setAlliedWithFaction(factionIndex)
    local actor, player, faction, relation = self:getInteractingParties(factionIndex, true)
    if not actor then return end

    if relation.status ~= RelationStatus.Neutral and relation.status ~= RelationStatus.Ceasefire then
        player:sendChatMessage("", ChatMessageType.Error, "Only factions that are neutral to you can become allies."%_t)
        return
    end

    -- this function is only for negotiations between a player and his own alliance
    if actor.isPlayer then
        if faction.isAlliance then
            faction = Alliance(faction.index)

            if faction and actor.allianceIndex == faction.index then
                -- check privilege
                if faction:hasPrivilege(player.index, AlliancePrivilege.NegotiateRelations) then
                    setRelationStatus(actor, faction, RelationStatus.Allies, true, true)
                    return
                else
                    player:sendChatMessage("", ChatMessageType.Error, "You don't have permissions to negotiate relations."%_t)
                    return
                end
            end
        end

    elseif actor.isAlliance then
        if faction.isPlayer then
            faction = Player(faction.index)

            if faction and faction.allianceIndex == actor.index then
                -- check privilege
                if actor:hasPrivilege(player.index, AlliancePrivilege.NegotiateRelations) then
                    setRelationStatus(actor, faction, RelationStatus.Allies, true, true)
                    return
                else
                    player:sendChatMessage("", ChatMessageType.Error, "You don't have permissions to negotiate relations."%_t)
                    return
                end
            end
        end
    end

    player:sendChatMessage("", ChatMessageType.Information, "Initiate a player trade to negotiate relations."%_t)
end

function Diplomacy:negotiationPossible(type, player, faction, relation)
    if type == "tribute" then
        if relation.status ~= RelationStatus.Ceasefire and relation.status ~= RelationStatus.Neutral then
            return false, "You can't negotiate tribute when at war."%_T
        end

        if relation.level >= RelationChangeMaxCap[RelationChangeType.Tribute] then
            return false, "Relations with this faction can't be improved any further by paying tribute."%_T
        end

        return true
    elseif type == "ceasefire" then
        if relation.status ~= RelationStatus.War then
            return false, "You can only negotiate a ceasefire when at war."%_T
        end

        return true
    elseif type == "alliance" then
        if relation.status ~= RelationStatus.Neutral then
            return false, "Only factions that are neutral to you can become allies."%_T
        end

        local requiredLevel = self.allyNegotiationRelations + math.min(0, getStatusChangeThresholdOffset(faction))

        if relation.level < requiredLevel then
            return false, "Relations are not sufficient to start a negotiation."%_T
        end

        return true
    end

    return false, "Unknown negotiation type."%_T
end

function Diplomacy:getUpdatedPatience(player, faction, relation, oldPatience)
    local server = Server()
    if not server then return oldPatience end

    -- patience is restored over time
    if oldPatience then
        local patienceTimestampKey = "negotiation_patience_timestamp_" .. tostring(player.index)
        local patienceTimestamp = faction:getValue(patienceTimestampKey)
        if patienceTimestamp then
            local timePassed = math.max(0, server.unpausedRuntime - patienceTimestamp)
            return math.min(1, oldPatience + timePassed / 10 / 60) -- 10 minutes for full patience
        end
    end

    return oldPatience
end

function Diplomacy:startNegotiation(type, factionIndex)
    local actor, player, faction, relation = self:getInteractingParties(factionIndex)
    if not actor then return end

    local result, error = self:negotiationPossible(type, actor, faction, relation)
    if result == false then
        player:sendChatMessage("", ChatMessageType.Error, error)
        return
    end

    local price, data = self:getNegotiationData(type, actor, faction, relation)

    local negotiationKey = "negotiation_type_" .. tostring(actor.index)
    local patienceKey = "negotiation_patience_" .. tostring(actor.index)
    local timestampKey = "negotiation_timestamp_" .. tostring(actor.index)
    local actionKey = "negotiation_timestamp_action_" .. tostring(actor.index)

    local timestamp = faction:getValue(timestampKey)
    local lastAction = faction:getValue(actionKey)
    local actionAllowed, timeRemaining = self:isActionAllowed(type, actor, faction, relation, timestamp, lastAction)
    if not actionAllowed then
        local timeArgs = createReadableTimeTable(timeRemaining)
        if timeArgs.hours > 0 then
            player:sendChatMessage("", ChatMessageType.Error, "The faction won't negotiate with you right now. Try again in an hour."%_T)
        elseif timeArgs.minutes > 2 then
            player:sendChatMessage("", ChatMessageType.Error, "The faction won't negotiate with you right now. Try again in %1% minutes."%_T, timeArgs.minutes)
        else
            player:sendChatMessage("", ChatMessageType.Error, "The faction won't negotiate with you right now. Try again in about 2 minutes."%_T, timeArgs.minutes)
        end
        invokeClientFunction(player, "onOfferRejected")
        return
    end

    local negotiationTypeBefore = faction:getValue(negotiationKey)
    faction:setValue(negotiationKey, type)

    local patience = faction:getValue(patienceKey)

    -- check if a new negotiation started and the client should clear its values
    local clearValues = false
    if not patience or negotiationTypeBefore ~= type then clearValues = true end

    -- patience is restored over time
    patience = self:getUpdatedPatience(actor, faction, relation, patience) or 1
    data.patience = patience

    invokeClientFunction(player, "showNegotiationWindow", clearValues, data)
end

function Diplomacy:receiveOffer(factionIndex, offer)
    local server = Server()
    if not server then return end

    local actor, player, faction, relation = self:getInteractingParties(factionIndex)
    if not actor then return end

    local negotiationKey = "negotiation_type_" .. tostring(actor.index)
    local patienceKey = "negotiation_patience_" .. tostring(actor.index)
    local patienceTimestampKey = "negotiation_patience_timestamp_" .. tostring(actor.index)
    local timestampKey = "negotiation_timestamp_" .. tostring(actor.index)
    local actionKey = "negotiation_timestamp_action_" .. tostring(actor.index)
    local type = faction:getValue(negotiationKey)

    -- the server is not aware of any ongoing negotiation -> return
    if not type then
        player:sendChatMessage("", ChatMessageType.Error, "There is no ongoing negotiation."%_T)
        invokeClientFunction(player, "onOfferRejected")
        return
    end

    local result, error = self:negotiationPossible(type, actor, faction, relation)
    if result == false then
        player:sendChatMessage("", ChatMessageType.Error, error)
        invokeClientFunction(player, "onOfferRejected")
        return
    end

    local timestamp = faction:getValue(timestampKey)
    local lastAction = faction:getValue(actionKey)
    local actionAllowed, timeRemaining = self:isActionAllowed(type, actor, faction, relation, timestamp, lastAction)
    if not actionAllowed then
        local timeArgs = createReadableTimeTable(timeRemaining)
        if timeArgs.hours > 0 then
            player:sendChatMessage("", ChatMessageType.Error, "The faction won't negotiate with you right now. Try again in an hour."%_T)
        elseif timeArgs.minutes > 2 then
            player:sendChatMessage("", ChatMessageType.Error, "The faction won't negotiate with you right now. Try again in %1% minutes."%_T, timeArgs.minutes)
        else
            player:sendChatMessage("", ChatMessageType.Error, "The faction won't negotiate with you right now. Try again in about 2 minutes."%_T, timeArgs.minutes)
        end

        invokeClientFunction(player, "onOfferRejected")
        return
    end

    local patience = faction:getValue(patienceKey)
    patience = self:getUpdatedPatience(actor, faction, relation, patience) or 1

    local offeredValue = 0
    for index, amount in pairs(offer) do
        if index == 1 then
            offeredValue = offeredValue + amount
        else
            offeredValue = offeredValue + amount * Material(index - 2).costFactor * 10
        end
    end

    offeredValue = math.floor(offeredValue)

    local canPay = actor:canPay(unpack(offer))

    local price, data = self:getNegotiationData(type, actor, faction, relation)

    self.responseMessages = self.responseMessages or
    {
        tribute = {
            belowMinimum = {"Do you think you can appease us with such cheap offers?"%_T, "This offer is ridiculous, are you trying to insult us?"%_T, "This is nothing but insulting! No."%_T, "This is insulting! That's not even the minimum of what we asked for!"%_T},
            aboveMaximum = {"We happily accept your offer."%_T},
            decline = {"This is not enough. You will have to invest more to gain our sympathy."%_T, "This is not enough. If you keep making such low offers, we will cancel negotiations."%_T, },
            accept = {"Thank you for your offer, we accept."%_T, "This is a reasonable offer, we accept."%_T},
            terminate = {"Enough is enough. These so-called tribute attempts are pathetic. Goodbye."%_T, "It seems that you're not taking this seriously. We decline."%_T},
            noMoney = {"Our bankers tell us that you don't even have enough funds to pay tribute."%_T},
        },
        ceasefire = {
            belowMinimum = {"This is insulting. No. We won't accept."%_T, "You can't be serious about that offer. Are you even trying?"%_T, "Do you think you can buy a ceasefire that cheaply?"%_T, "This is insulting! That's not even the minimum of what we asked for!"%_T},
            aboveMaximum = {"This is more than we expected. We accept your offer."%_T},
            decline = {"A ceasefire with us is worth more than that."%_T, "If you keep making such low offers, we will cancel negotiations."%_T, },
            accept = {"Thank you for your offer, we accept."%_T, "This is a reasonable offer, we accept."%_T, "This is an offer that we can agree upon. We accept."%_T},
            terminate = {"That's enough. These negotiations are ridiculous. Goodbye."%_T, "No more. You're clearly not actually interested in a ceasefire."%_T},
            noMoney = {"Our bankers tell us that you don't even have enough funds for that."%_T},
        },
        alliance = {
            belowMinimum = {"Please don't be so cheap. Our alliance is worth more than that."%_T, "You'll have to invest a lot more than that for an alliance."%_T, "No! An alliance with our faction is not bought that easily!"%_T},
            aboveMaximum = {"This is a very generous offer. We are gratefully accept."%_T},
            decline = {"Your offer is alright, but an alliance with our faction is worth more than that."%_T, "This is somewhat reasonable, but we think for an alliance you'll have to invest some more."%_T},
            accept = {"This is an offer that we can agree upon. We accept."%_T, "This is a reasonable offer, we accept."%_T, },
            terminate = {"These negotiations are going nowhere. We shall talk another time."%_T, "We don't think that you're serious about these negotiations. We're no longer interested."%_T},
            noMoney = {"I'm afraid you've made an error. It seems you don't have the funds for that offer."%_T},
        },
        unclear = {
            belowMinimum = {"You'll have to invest a lot more than that."%_T},
            aboveMaximum = {"This is a very generous offer. Thank you, we accept."%_T},
            decline = {"If you keep making such low offers, we will cancel negotiations."%_T,},
            accept = {"This is an offer that we can agree upon. We accept."%_T,},
            terminate = {"These negotiations are going nowhere. We shall talk another time."%_T,},
            noMoney = {"Our bankers tell us that you don't even have enough funds for that."%_T},
        },

    }

    local messages = self.responseMessages[type] or self.responseMessages.unclear

    local sender = NamedFormat("${name}-Ambassador", {name = faction.baseName})
    local responseMessage

--    print("offered: " .. offeredValue .. ", required: " .. price .. ", can pay: " .. tostring(canPay))
    if offeredValue < price or not canPay then
        -- use traits to get a factor between -0.25 and 0.25
        local traitFactor = (faction:getTrait("greedy") + faction:getTrait("honorable")) * 0.125
        local loss = 0.25 * (1 + traitFactor)

        responseMessage = randomEntry(messages.decline)

        if offeredValue < data.minRequired then
            responseMessage = randomEntry(messages.belowMinimum)
            loss = loss * 1.5
        end

        if not canPay then
            responseMessage = randomEntry(messages.noMoney)
        end

        patience = patience - loss

        if patience <= 0 then
--            print("no more patience")

            faction:setValue(negotiationKey, nil)
            faction:setValue(patienceKey, nil)
            faction:setValue(patienceTimestampKey, nil)
            faction:setValue(timestampKey, server.unpausedRuntime)
            faction:setValue(actionKey, type)

            invokeClientFunction(player, "onOfferRejected")

            responseMessage = randomEntry(messages.terminate)
            player:sendChatMessage(sender, ChatMessageType.Normal, responseMessage)
            return
        end

--        print("try again")
        faction:setValue(patienceKey, patience)
        faction:setValue(patienceTimestampKey, server.unpausedRuntime)

        data.patience = patience or 1
        invokeClientFunction(player, "showNegotiationWindow", false, data)

        player:sendChatMessage(sender, ChatMessageType.Normal, responseMessage)

        return
    end

--    print("success")
    actor:pay(unpack(offer))

    faction:setValue(negotiationKey, nil)
    faction:setValue(patienceKey, nil)
    faction:setValue(patienceTimestampKey, nil)
    faction:setValue(timestampKey, server.unpausedRuntime)
    faction:setValue(actionKey, type)

    self:onNegotiationSuccessful(type, actor, player, faction, relation, data)

    if offeredValue > data.maxRequired then
        responseMessage = randomEntry(messages.aboveMaximum)
    else
        responseMessage = randomEntry(messages.accept)
    end

    player:sendChatMessage(sender, ChatMessageType.Normal, responseMessage)
end

function Diplomacy:getNegotiationData(type, player, faction, relation)
    local x, y = faction:getHomeSectorCoordinates()
    local balancingFactor = Balancing_GetSectorRichnessFactor(x, y, 1000)
    local price = 0
    local data = nil

    if type == "tribute" then
        local relationImprovement = math.max(0, RelationChangeMaxCap[RelationChangeType.Tribute] - relation.level)
        relationImprovement = math.min(20000, relationImprovement)

        local multipliers = {careful = 1, generous = -1, greedy = 1, opportunistic = 1}
        local traitMultiplier = 1

        local minMultiplier = 1
        local maxMultiplier = 1
        for trait, multiplier in pairs(multipliers) do
            local value = faction:getTrait(trait)

            -- only use positve traits
            if value and value >= 0 then
                -- value is between 0 and 1
                -- multiplier is between -1 and 1
                -- traitMultiplier will be adjusted by a value between -0.1 and 0.1
                local delta = value * multiplier * 0.1
                traitMultiplier = traitMultiplier + delta
            end

            if multiplier > 0 then
                maxMultiplier = maxMultiplier + 0.1
            else
                minMultiplier = minMultiplier - 0.1
            end
        end

        -- after adding up all trait based multipliers, use traitMultiplier to adjust price
        price = relationImprovement / 2 * traitMultiplier * balancingFactor

        local minPrice = relationImprovement / 2 * minMultiplier * balancingFactor
        local maxPrice = relationImprovement / 2 * maxMultiplier * balancingFactor

        data =
        {
            factionIndex = faction.index,
            title = "Negotiate Relations"%_T,
            description = "Place an offer to improve your relations by ${amount} points."%_T,
            descriptionArgs =
            {
                baseAmount = relationImprovement,
                amount = createMonetaryString(math.floor(getCustomFactionRelationDelta(faction, relationImprovement, RelationChangeType.Tribute))),
            },

            minRequired = math.floor(minPrice / 1000) * 1000,
            maxRequired = math.ceil(maxPrice / 1000) * 1000,
        }
    elseif type == "ceasefire" then
        local multipliers = {peaceful = -1, aggressive = 1, careful = -1, brave = 1, greedy = 1, opportunistic = 1}
        local traitMultiplier = 1

        local minMultiplier = 1
        local maxMultiplier = 1
        for trait, multiplier in pairs(multipliers) do
            local value = faction:getTrait(trait)

            -- only use positve traits
            if value and value >= 0 then
                -- value is between 0 and 1
                -- multiplier is between -1 and 1
                -- traitMultiplier will be adjusted by a value between -0.1 and 0.1
                local delta = value * multiplier * 0.1
                traitMultiplier = traitMultiplier + delta
            end

            if multiplier > 0 then
                maxMultiplier = maxMultiplier + 0.1
            else
                minMultiplier = minMultiplier - 0.1
            end
        end

        -- after adding up all trait based multipliers, use traitMultiplier to adjust price
        price = 15000 * traitMultiplier * balancingFactor

        local minPrice = 15000 * minMultiplier * balancingFactor
        local maxPrice = 15000 * maxMultiplier * balancingFactor

        data =
        {
            factionIndex = faction.index,
            title = "Negotiate Ceasefire"%_T,
            description = "Place an Offer"%_T,
            descriptionArgs = {},

            minRequired = math.floor(minPrice / 1000) * 1000,
            maxRequired = math.ceil(maxPrice / 1000) * 1000,
        }
    elseif type == "alliance" then
        local multipliers = {peaceful = -1, aggressive = 1, generous = -1, greedy = 1, opportunistic = 1}
        local traitMultiplier = 1

        local minMultiplier = 1
        local maxMultiplier = 1
        for trait, multiplier in pairs(multipliers) do
            local value = faction:getTrait(trait)

            -- only use positve traits
            if value and value >= 0 then
                -- value is between 0 and 1
                -- multiplier is between -1 and 1
                -- traitMultiplier will be adjusted by a value between -0.1 and 0.1
                local delta = value * multiplier * 0.1
                traitMultiplier = traitMultiplier + delta
            end

            if multiplier > 0 then
                maxMultiplier = maxMultiplier + 0.1
            else
                minMultiplier = minMultiplier - 0.1
            end
        end

        -- after adding up all trait based multipliers, use traitMultiplier to adjust price
        price = 8000 * traitMultiplier * balancingFactor

        local minPrice = 8000 * minMultiplier * balancingFactor
        local maxPrice = 8000 * maxMultiplier * balancingFactor

        data =
        {
            factionIndex = faction.index,
            title = "Negotiate Alliance"%_T,
            description = "Place an Offer"%_T,
            descriptionArgs = {},

            minRequired = math.floor(minPrice / 1000) * 1000,
            maxRequired = math.ceil(maxPrice / 1000) * 1000,
        }
    end

    return round(price), data
end

function Diplomacy:isActionAllowed(type, player, faction, relation, timestamp, lastAction)
    local server = Server()
    if not server then return true end

    if type == "tribute" then
        if lastAction ~= "tribute" then return true end

        local remaining = math.ceil(math.max(0, timestamp + 60 * 60 - server.unpausedRuntime))
        return remaining == 0, remaining
    elseif type == "ceasefire" then
        -- current state is war
        -- check that war status was set more than 1h ago
        local changeKey = "statuschange_timestamp_" .. tostring(player.index)
        local changeTime = faction:getValue(changeKey)
        if changeTime then
            local remaining = math.ceil(math.max(0, changeTime + 60 * 60 - server.unpausedRuntime))
            if remaining > 0 then
                return remaining == 0, remaining
            end
        end

        if lastAction == "war" then
            local remaining = math.ceil(math.max(0, timestamp + 60 * 60 - server.unpausedRuntime))
            return remaining == 0, remaining
        end

        if lastAction == "ceasefire" then
            local remaining = math.ceil(math.max(0, timestamp + 15 * 60 - server.unpausedRuntime))
            return remaining == 0, remaining
        end

        return true
    elseif type == "alliance" then
        if lastAction ~= "alliance" then return true end

        local remaining = math.ceil(math.max(0, timestamp + 15 * 60 - server.unpausedRuntime))
        return remaining == 0, remaining
    end
end

function Diplomacy:onNegotiationSuccessful(type, actor, player, faction, relation, data)
    if type == "tribute" then
        changeRelations(actor, faction, data.descriptionArgs.baseAmount, RelationChangeType.Tribute, true, true, faction)
    elseif type == "ceasefire" then
        setRelationStatus(actor, faction, RelationStatus.Ceasefire, true, true)
    elseif type == "alliance" then
        setRelationStatus(actor, faction, RelationStatus.Allies, true, true)
    end

    invokeClientFunction(player, "onOfferSuccessful")
end

function Diplomacy:sendFactionMetadata()
    local actor, player = self.getUserFaction()
    if not actor then return end

    local eradicatedFactions = getGlobal("eradicated_factions") or {}
    invokeClientFunction(player, "showFactionMetadata", eradicatedFactions)
end

end



if onClient() then

local FilterMode =
{
    All = 1,
    Players = 2,
    Alliances = 3,
    AIFactions = 4,
}

local SortMode =
{
    NameAscending = 1,
    NameDescending = 2,
    StatusAscending = 3,
    StatusDescending = 4,
    RelationsAscending = 5,
    RelationsDescending = 6,
    DistanceAscending = 7,
}

Diplomacy.filterMode = FilterMode.All
Diplomacy.sortMode = SortMode.DistanceAscending

function Diplomacy:initialize()

    local tab = self.getParentWindow():createTab("Diplomacy"%_t, "data/textures/icons/shaking-hands.png", "Diplomacy"%_t)
    tab.onShowFunction = "onShowTab"
    self.tab = tab

    if self.isAttachedToAlliance then
        -- we must move to position 5 because there is a hidden tab: the found tab
        self.getParentWindow():moveTabToPosition(tab, 5)
    else
        self.getParentWindow():moveTabToPosition(tab, 3)
    end

    local user, player = self.getUserFaction()
    if user then
        self.getParentWindow():activateTab(self.tab)
        user:registerCallback("onRelationLevelChanged", "onRelationChanged")
        user:registerCallback("onRelationStatusChanged", "onRelationChanged")
    else
        self.getParentWindow():deactivateTab(self.tab)
    end

    if player and self.isAttachedToAlliance then
        player:registerCallback("onAllianceChanged", "onAllianceChanged")
    end

    -- for development
--    self.getParentWindow():selectTab(tab)

    local vsplit = UIVerticalSplitter(Rect(tab.size), 10, 0, 0.4)

    -- left side
    local leftSplit = UIHorizontalSplitter(vsplit.left, 10, 0, 0.5)
    leftSplit.topSize = 25

    local sortSplit = UIVerticalSplitter(leftSplit.top, 10, 0, 0.5)
    local filterCombo = tab:createValueComboBox(sortSplit.left, "onFilterComboSelected")
    filterCombo:addEntry(FilterMode.All, "All"%_t)
    filterCombo:addEntry(FilterMode.Players, "Players"%_t)
    filterCombo:addEntry(FilterMode.Alliances, "Alliances"%_t)
    filterCombo:addEntry(FilterMode.AIFactions, "AI Factions"%_t)

    local sortCombo = tab:createValueComboBox(sortSplit.right, "onSortComboSelected")
    sortCombo:addEntry(SortMode.DistanceAscending, "Distance (Ascending)"%_t)
    sortCombo:addEntry(SortMode.NameAscending, "Name (Ascending)"%_t)
    sortCombo:addEntry(SortMode.NameDescending, "Name (Descending)"%_t)
    sortCombo:addEntry(SortMode.StatusAscending, "Status (Ascending)"%_t)
    sortCombo:addEntry(SortMode.StatusDescending, "Status (Descending)"%_t)
    sortCombo:addEntry(SortMode.RelationsAscending, "Relations (Ascending)"%_t)
    sortCombo:addEntry(SortMode.RelationsDescending, "Relations (Descending)"%_t)

    self.factionListBox = tab:createListBoxEx(leftSplit.bottom)
    self.factionListBox.onSelectFunction = "onFactionSelected"
    self.factionListBox.columns = 3
    self.factionListBox:setColumnWidth(0, self.factionListBox.width - self.factionListBox.rowHeight * 2 - 10)
    self.factionListBox:setColumnWidth(1, self.factionListBox.rowHeight)
    self.factionListBox:setColumnWidth(1, self.factionListBox.rowHeight)

    -- right side
    local frame2 = tab:createFrame(vsplit.right)
    local rightLister = UIVerticalLister(vsplit.right, 10, 10)

    local container = tab:createContainer(Rect(tab.size))
    self.container = container

    -- targeter
    self.targeterCenter = vec2(vsplit.right.upper.x, vsplit.right.lower.y) + vec2(-16, 16) + vec2(-15, 15)
    self.targeters = {}

    for _, flipY in pairs({false, true}) do
        for _, flipX in pairs({false, true}) do
            local lower = self.targeterCenter
            if not flipX then lower = lower - vec2(16, 0) end
            if flipY then lower = lower - vec2(0, 16) end
            local targeter = container:createPicture(Rect(lower, lower + vec2(16, 16)), "data/textures/ui/indicator_neutral.png")
            targeter.flipped = flipY
            targeter.flippedX = flipX

            table.insert(self.targeters, targeter)
        end
    end

    local splitter = UIVerticalSplitter(rightLister:nextRect(30), 10, 0, 0.5)
    splitter:setLeftQuadratic()
    self.factionIcon = container:createPicture(splitter.left, "data/textures/icons/inventory.png")
    self.factionIcon.isIcon = true
    self.factionLabel = container:createLabel(splitter.right, "Faction Name", 20)
    self.factionLabel:setLeftAligned()

    local splitter = UIVerticalSplitter(rightLister:nextRect(20), 10, 0, 0.5)
    splitter:setLeftQuadratic()

    self.sectorIconButton = container:createButton(splitter.left, "", "onShowSectorPressed")
    self.sectorIconButton.icon = "data/textures/icons/position-marker.png"
    self.sectorIconButton.iconColor = ColorRGB(0.5, 0.5, 0.5)
    self.sectorIconButton.tooltip = "Show On Map"%_t
    self.sectorIconButton.hasFrame = false

    self.sectorButton = container:createButton(splitter.right, "", "onShowSectorPressed")
    self.sectorButton.tooltip = "Sector in which this faction can be found"%_t
    self.sectorButton.hasFrame = false

    self.sectorLabel = container:createLabel(splitter.right, "Unknown", 14)
    self.sectorLabel.color = ColorRGB(0.5, 0.5, 0.5)
    self.sectorLabel:setLeftAligned()

    container:createLabel(rightLister:nextRect(15), "Relations"%_t, 14)

    -- relation indicators
    local width = rightLister.inner.width
    local splits = {}
    local relations = {}
    local segments = {Relation():getSegments()}
    for i = 2, #segments do
        if i < #segments then
            table.insert(splits, (segments[i] + 100000) / 200000 * width)
        end

        local relation = Relation()
        relation.level = (segments[i - 1] + segments[i]) / 2
        table.insert(relations, {relation = relation, from = segments[i - 1], to = segments[i]})
    end

    local splitter = UIArbitraryVerticalSplitter(rightLister:nextRect(18), 5, 0, unpack(splits))

    self.relationLabels = {}
    for i, r in pairs(relations) do
        local relation = r.relation

        local frame = container:createFrame(splitter:partition(i - 1))
        local label = container:createLabel(splitter:partition(i - 1), string.upper(relation.description), 10)
        label:setCenterAligned()
        label.outline = true
        table.insert(self.relationLabels, {frame = frame, label = label})

        label.tooltip = string.format("%s <> %s", createMonetaryString(r.from), createMonetaryString(r.to))
    end

    -- bar
    self.relationBar = container:createStatisticsBar(rightLister:nextRect(25), ColorRGB(1, 1, 1))
    self.relationBar:setRange(-100000, 100000)

    -- status
    local width = rightLister.inner.width
    local splitter = UIArbitraryVerticalSplitter(rightLister:nextRect(64), 10, 0, width / 2 - 32 - 5, width / 2 + 32 + 5)

    local rect = splitter:partition(0)
    rect.height = 30
    self.declareWarButton = container:createButton(rect, "Declare War"%_t, "onDeclareWarPressed")
    self.declareWarButton.maxTextSize = 14
    self.cancelAllianceButton = container:createButton(rect, "Abandon Alliance"%_t, "onAbandonAlliancePressed")
    self.cancelAllianceButton.maxTextSize = 14

    self.statusIcon = container:createPicture(splitter:partition(1), "")
    self.statusIcon.isIcon = true

    local rect = splitter:partition(2)
    rect.height = 30
    self.negotiateCeaseFireButton = container:createButton(rect, "Negotiate Ceasefire"%_t, "onNegotiateCeaseFirePressed")
    self.negotiateCeaseFireButton.maxTextSize = 14
    self.tributeButton = container:createButton(rect, "Pay Tribute"%_t, "onPayTributePressed")
    self.tributeButton.maxTextSize = 14
    self.negotiateAllianceButton = container:createButton(rect, "Negotiate Alliance"%_t, "onNegotiateAlliancePressed")
    self.negotiateAllianceButton.maxTextSize = 14
    self.negotiateWithPlayerButton = container:createButton(rect, "Negotiate"%_t, "onNegotiateWithPlayerPressed")
    self.negotiateWithPlayerButton.maxTextSize = 14

    -- traits
    self.traitsLabel = container:createLabel(rightLister:nextRect(15), "Traits"%_t, 14)
    self.traits = container:createTextField(rightLister.rect, "Hallo Welt!")
    self.traits.fontSize = 14
    self.traits.font = FontType.Normal

    -- alliance emblem
    local emblemRect = rightLister.rect
    emblemRect.upper = vec2(emblemRect.lower.x + 10 + 256, emblemRect.upper.y - 10)
    emblemRect.lower = emblemRect.upper - vec2(256, 256)
    self.allianceEmblem = container:createAllianceEmblem(emblemRect, 0)
    self.allianceEmblem:hide()

    local emblemLabelRect = Rect()
    emblemLabelRect.lower = emblemRect.lower - vec2(0, 25)
    emblemLabelRect.upper = emblemRect.upper - vec2(0, 10 + 256)
    self.emblemLabel = container:createLabel(emblemLabelRect, "Emblem"%_t, 14)
    self.emblemLabel:hide()

    -- other
    self:buildNegotiationWindow(tab)
    self:buildConfirmationWindow(tab)

    self:refreshListBox()
    self.factionListBox:select(0)

end

function Diplomacy:onShowTab()
--    print("on show")
    if not valid(self.factionListBox) then return end

    local index = math.max(0, self.factionListBox.selected)
    self:refreshListBox()
    self.factionListBox:select(index)
end

function Diplomacy:onRelationChanged(factionIndex)
    if not valid(self.factionListBox) then return end

    local player = self.getUserFaction()
    if not player then return end

    local foundIndex = -1 -- invalid
    for i, relation in pairs(self.factions) do
        if relation.factionIndex == factionIndex then
            foundIndex = i - 1
            break
        end
    end

    if foundIndex ~= -1 then
        if foundIndex == self.factionListBox.selected then
--            print("update currently selected faction")
            self:onFactionSelected(foundIndex)
        else
--            print("update other faction")
            local newRelation = player:getRelation(factionIndex)
            self.factions[foundIndex + 1] = newRelation

            local faction = Faction(factionIndex)
            if not faction then return end

            self:updateRow(foundIndex, newRelation, faction)
        end
    else
--        print("new faction was added, update whole list")
        self:refreshListBox()
    end
end

function Diplomacy:onAllianceChanged(allianceIndex)
    local user = self.getUserFaction()
    if user then
        self.getParentWindow():activateTab(self.tab)
        user:registerCallback("onRelationLevelChanged", "onRelationChanged")
        user:registerCallback("onRelationStatusChanged", "onRelationChanged")
    else
        self.getParentWindow():deactivateTab(self.tab)
    end
end

function Diplomacy:onDelete()
    -- for development
    if self.negotiationUI and valid(self.negotiationUI.window) then self.negotiationUI.window:hide() end
    if self.confirmationUI and valid(self.confirmationUI.window) then self.confirmationUI.window:hide() end
end

function Diplomacy:buildNegotiationWindow(container)

    local window = container:createWindow(Rect(vec2(650, 390)))
    window.transparency = 0.1
    window.consumeAllEvents = true

    window:hide()

    self.negotiationUI = {}
    self.negotiationUI.window = window
    window.showCloseButton = true
    window.closeableWithEscape = true
    window.moveable = true
    window.caption = "Pay Tribute"%_t

    local lister = UIVerticalLister(Rect(window.size), 10, 10)
    self.negotiationUI.label = window:createLabel(lister:nextRect(20), "", 14)
    self.negotiationUI.label:setCenterAligned()

    self.negotiationUI.requiredLabel = window:createLabel(lister:nextRect(20), "Required Value:", 14)
    self.negotiationUI.requiredLabel:setCenterAligned()


    local rect = lister:nextRect(60)
    rect.height = 30
    rect.width = rect.width - 20
    window:createFrame(rect)
    self.negotiationUI.patienceBar = window:createProgressBar(rect, ColorRGB(1, 0, 0))
    local patienceLabel = window:createLabel(rect, "Patience"%_t, 14)
    patienceLabel:setCenterAligned()
    patienceLabel.outline = true

    local splitter = UIVerticalSplitter(lister:nextRect(170), 10, 0, 0.5)

    window:createFrame(splitter.left).backgroundColor = ColorARGB(0.3, 0, 0, 0)
    window:createFrame(splitter.right).backgroundColor = ColorARGB(0.3, 0, 0, 0)

    local leftSplitter = UIVerticalSplitter(splitter.left, 10, 10, 0.4)
    local rightSplitter = UIVerticalSplitter(splitter.right, 10, 10, 0.4)

    local leftLister = UIVerticalLister(leftSplitter.left, 10, 0)
    local rightLister = UIVerticalLister(leftSplitter.right, 10, 0)

    self.negotiationUI.fields = {}

    for i = 1, 4 do
        local label = window:createLabel(leftLister:nextRect(30), "Credits"%_t, 14)
        label.fontSize = 14
        label:setLeftAligned()

        if i > 1 then
            local material = Material(i - 2)
            label.caption = material.name
            label.color = material.color
        end

        local box = window:createTextBox(rightLister:nextRect(30), "onOfferChanged")
        box.allowedCharacters = "0123456789"
        box.maxCharacters = 13

        table.insert(self.negotiationUI.fields, {label = label, box = box})
    end

    local leftLister = UIVerticalLister(rightSplitter.left, 10, 0)
    local rightLister = UIVerticalLister(rightSplitter.right, 10, 0)
    for i = 1, 4 do
        local label = window:createLabel(leftLister:nextRect(30), "", 14)
        label.fontSize = 14
        label:setLeftAligned()

        local material = Material(i + 2)
        label.caption = material.name
        label.color = material.color

        local box = window:createTextBox(rightLister:nextRect(30), "onOfferChanged")
        box.allowedCharacters = "0123456789"
        box.maxCharacters = 13

        table.insert(self.negotiationUI.fields, {label = label, box = box})
    end

    local rect = lister:nextRect(20)
    window:createLabel(rect, "Your Offer:"%_t, 14)
    self.negotiationUI.offeredLabel = window:createLabel(rect, "", 14)
    self.negotiationUI.offeredLabel:setCenterAligned()

    local width = lister.inner.width
    local splitter = UIVerticalMultiSplitter(lister:nextRect(30), 10, 0, 2)

    local rect = splitter:partition(1)
    rect.width = rect.width + 40

    self.negotiationUI.offerButton = window:createButton(rect, "Offer"%_t, "onOfferPressed")
    self.negotiationUI.offerButton.maxTextSize = 14
end

function Diplomacy:showNegotiationWindow(clearValues, data)
    self.negotiationUI.factionIndex = data.factionIndex

    self.negotiationUI.window.caption = data.title%_t
    self.negotiationUI.label.caption = data.description%_t % data.descriptionArgs

    self.negotiationUI.requiredLabel.caption = "Required: ¢${min} - ¢${max}"%_t % {min = createMonetaryString(data.minRequired), max = createMonetaryString(data.maxRequired)}

    local patience = data.patience or 1
    self.negotiationUI.patienceBar.progress = patience
    self.negotiationUI.patienceBar.color = ColorRGB(0.8 - patience * 0.5, patience * 0.5 + 0.3, 0.3)


    if clearValues then
        for index, field in pairs(self.negotiationUI.fields) do
            field.box.text = "0"

            -- make sure the offer label is updated
            if index == #self.negotiationUI.fields then
                self:onOfferChanged(field.box)
            end
        end
    end

    self.negotiationUI.window:show()
end

function Diplomacy:buildConfirmationWindow(container)

    local window = container:createWindow(Rect(vec2(450, 124)))
    window.transparency = 0.1
    window.consumeAllEvents = true

    window:hide()

    self.confirmationUI = {}
    self.confirmationUI.window = window
    window.showCloseButton = true
    window.closeableWithEscape = true
    window.moveable = true
    window.caption = "Confirm Declaration of War"%_t

    local lister = UIVerticalLister(Rect(window.size), 10, 10)
    local splitter = UIVerticalSplitter(lister:nextRect(64), 10, 0, 0.5)
    splitter:setLeftQuadratic()
    local warningIcon = window:createPicture(splitter.left, "data/textures/icons/hazard-sign.png")
    warningIcon.isIcon = true
    warningIcon.color = ColorRGB(1, 1, 0)
    self.confirmationUI.field = window:createTextField(splitter.right, "Do you really want to declare war?"%_t)
    self.confirmationUI.field.fontSize = 14

    local splitter = UIVerticalSplitter(lister:nextRect(30), 10, 0, 0.5)
    self.confirmationUI.confirmButton = window:createButton(splitter.left, "Confirm"%_t, "onConfirmPressed")
    self.confirmationUI.cancelButton = window:createButton(splitter.right, "Cancel"%_t, "onCancelPressed")
end

function Diplomacy:showConfirmationWindow(title, description, callback, factionIndex)
--    print("show confirmation window")

    self.confirmationUI.window.caption = title
    self.confirmationUI.field.text = description
    self.confirmationUI.callback = callback
    self.confirmationUI.factionIndex = factionIndex

    self.confirmationUI.window:show()
end

function Diplomacy:onConfirmPressed()
--    print("confirm")
    if self.confirmationUI.callback then self.confirmationUI.callback(self, self.confirmationUI.factionIndex) end

    self.confirmationUI.window:hide()
end

function Diplomacy:onCancelPressed()
--    print("cancel")
    self.confirmationUI.window:hide()
end

function Diplomacy:onOfferChanged(box)
    local player = self.getUserFaction()
    if not player then return end

    local value = tonumber(box.text) or 0

    if tostring(value) ~= box.text then
        box.text = value
    end

    local totalValue = 0
    for index, field in pairs(self.negotiationUI.fields) do
        local value = tonumber(field.box.text) or 0

        if index == 1 then
            totalValue = totalValue + value
        else
            local material = Material(index - 2)
            totalValue = totalValue + value * material.costFactor * 10 -- see resourcetrader sellPrice
        end
    end

    totalValue = math.floor(totalValue)

    self.negotiationUI.offeredLabel.caption = "¢${value}"%_t % {value = createMonetaryString(totalValue)}
end

function Diplomacy:onOfferPressed()
--    print("offer")

    local offer = {}
    for index, field in pairs(self.negotiationUI.fields) do
        table.insert(offer, tonumber(field.box.text) or 0)
    end

    invokeServerFunction("receiveOffer", self.negotiationUI.factionIndex, offer)
end

function Diplomacy:onOfferSuccessful()
    self.negotiationUI.window:hide()

    -- update
    self:onFactionSelected(self.factionListBox.selected)
end

function Diplomacy:onOfferRejected()
    self.negotiationUI.window:hide()

    -- update
    self:onFactionSelected(self.factionListBox.selected)
end

function Diplomacy:getFilterFunction()
    if self.filterMode == FilterMode.Players then
        return function(faction)
            return faction.isPlayer
        end
    elseif self.filterMode == FilterMode.Alliances then
        return function(faction)
            return faction.isAlliance
        end
    elseif self.filterMode == FilterMode.AIFactions then
        return function(faction)
            if faction:getTrait("invisible") ~= 0 then return false end
            return faction.isAIFaction
        end
    end

    return function(faction)
        if faction:getTrait("invisible") ~= 0 then return false end
        return true
    end
end

function Diplomacy:getSortFunction()
    if self.sortMode == SortMode.NameAscending then
        return function(a, b)
            local factionA = Faction(a.factionIndex)
            local factionB = Faction(b.factionIndex)
            if not factionA then return end
            if not factionB then return end
            return string.lower(factionA.translatedName) < string.lower(factionB.translatedName)
        end
    elseif self.sortMode == SortMode.NameDescending then
        return function(a, b)
            local factionA = Faction(a.factionIndex)
            local factionB = Faction(b.factionIndex)
            if not factionA then return end
            if not factionB then return end
            return string.lower(factionA.translatedName) > string.lower(factionB.translatedName)
        end
    elseif self.sortMode == SortMode.StatusAscending then
        return function(a, b)
            if a.status == b.status then
                return a.level < b.level
            end

            return a.status < b.status
        end
    elseif self.sortMode == SortMode.StatusDescending then
        return function(a, b)
            if a.status == b.status then
                return a.level > b.level
            end

            return a.status > b.status
        end
    elseif self.sortMode == SortMode.RelationsAscending then
        return function(a, b)
            if a.level == b.level then
                return a.status < b.status
            end

            return a.level < b.level
        end
    elseif self.sortMode == SortMode.RelationsDescending then
        return function(a, b)
            if a.level == b.level then
                return a.status > b.status
            end

            return a.level > b.level
        end
    elseif self.sortMode == SortMode.DistanceAscending then
        local sector = Sector()
        local px, py = sector:getCoordinates()

        local presentFactions = {}
        for _, index in pairs({sector:getPresentFactions()}) do
            presentFactions[index] = true
        end

        return function(a, b)
            if not sector then return end

            local factionA = Faction(a.factionIndex)
            local factionB = Faction(b.factionIndex)
            if not factionA then return end
            if not factionB then return end

            -- factions that are present in the current sector come first, sorted by name
            if presentFactions[a.factionIndex] then
                if presentFactions[b.factionIndex] then
                    return string.lower(factionA.translatedName) < string.lower(factionB.translatedName)
                else
                    return true
                end
            else
                if presentFactions[b.factionIndex] then
                    return false
                end
            end

            -- put factions that the player doesn't know the location of at the bottom
            local locationUnknownA = self.factionsOnMap[a.factionIndex] == nil
            local locationUnknownB = self.factionsOnMap[b.factionIndex] == nil

            if locationUnknownA then
                if locationUnknownB then
                    return string.lower(factionA.translatedName) < string.lower(factionB.translatedName)
                else
                    return false
                end
            else
                if locationUnknownB then
                    return true
                end
            end

            local ax, ay = factionA:getHomeSectorCoordinates()
            local bx, by = factionB:getHomeSectorCoordinates()

            local distA2 = (px - ax) * (px - ax) + (py - ay) * (py - ay)
            local distB2 = (px - bx) * (px - bx) + (py - by) * (py - by)

            -- sort by distance
            return distA2 < distB2
        end
    end
end

function Diplomacy:getSortableFunction()
    if self.sortMode == SortMode.DistanceAscending then
        return function(relation, faction)
            if self.factionsOnMap[faction.index] then return true end

            local homeUnknown = faction.homeSectorUnknown
            if homeUnknown then return false end

            return self.factionsOnMap[faction.index] ~= nil
        end
    end
end

function Diplomacy:refreshFactionsOnMap()
    if not valid(self.factionListBox) then return end

    local player = self.getUserFaction()
    if not player then return end

    local sector = Sector()
    local x, y = sector:getCoordinates()
    local coords = vec2(x, y)

    local function insert(vx, vy, factionIndex, controlling)
        local faction = table.getOrInsert(self.factionsOnMap, factionIndex, {})

        local d2 = distance2(vec2(vx, vy), coords)

        if not faction.nearestPresentSector or d2 < faction.nearestPresentD2 then
            faction.nearestPresentSector = {x=vx, y=vy}
            faction.nearestPresentD2 = d2
        end

        if controlling then
            if not faction.nearestControllingSector or d2 < faction.nearestControllingD2 then
                faction.nearestControllingSector = {x=vx, y=vy}
                faction.nearestControllingD2 = d2
            end
        end
    end

    self.factionsOnMap = {}
    for _, view in pairs({player:getKnownSectors()}) do
        local vx, vy = view:getCoordinates()
        if view.factionIndex > 0 then
            insert(vx, vy, view.factionIndex, true)
        end

        for factionIndex, amount in pairs(view:getCraftsByFaction()) do
            if amount > 0 then
                insert(vx, vy, factionIndex)
            end
        end

        for factionIndex, amount in pairs(view:getShipsByFaction()) do
            if amount > 0 then
                insert(vx, vy, factionIndex)
            end
        end
    end

    for _, factionIndex in pairs({sector:getPresentFactions()}) do
        if factionIndex > 0 then
            insert(x, y, factionIndex)
        end
    end

end

function Diplomacy:refreshListBox()
    if not valid(self.factionListBox) then return end
    local player = self.getUserFaction()
    if not player then return end

    self.factionListBox:clear()

    local filterFunction = self:getFilterFunction()

    self.factions = {}
    for _, relation in pairs({player:getAllRelations()}) do
        local faction = Faction(relation.factionIndex)
        if faction then
            if filterFunction(faction) then
                table.insert(self.factions, relation)
            end
        end
    end

    self:refreshFactionsOnMap()

    local sortFunction = self:getSortFunction()
    if sortFunction then
        table.sort(self.factions, sortFunction)
    end

    for index, relation in pairs(self.factions) do
        local faction = Faction(relation.factionIndex)
        self.factionListBox:addRow()

        self:updateRow(index - 1, relation, faction)
    end

    self:requestFactionMetadata()

    self.factionListBox:clampScrollPosition()
end

function Diplomacy:updateRow(index, relation, faction)
    local color = relation.color
    local sortableFunction = self:getSortableFunction()
    if sortableFunction then
        if not sortableFunction(relation, faction) then
            color = ColorRGB(color.r * 0.5, color.g * 0.5, color.b * 0.5)
        end
    end

    if self.eradicatedFactions and self.eradicatedFactions[faction.index] == true then
        color = ColorRGB(1, 0.3, 0.3)
    end

    self.factionListBox:setEntry(0, index, faction.translatedName, false, false, color)

    if self.eradicatedFactions and self.eradicatedFactions[relation.factionIndex] == true then
        self.factionListBox:setEntry(1, index, "data/textures/icons/cross-mark.png", false, false, ColorRGB(1, 0.3, 0.3))
        self.factionListBox:setEntryType(1, index, ListBoxEntryType.Icon)
    else
        self.factionListBox:setEntry(1, index, "", false, false, ColorRGB(1, 1, 1))
    end

    if relation.status == RelationStatus.Neutral then
        self.factionListBox:setEntry(2, index, "", false, false, Color())
    else
        self.factionListBox:setEntry(2, index, self:getStatusIcon(relation.status), false, false, relation.color)
    end

    self.factionListBox:setEntryType(1, index, ListBoxEntryType.Icon)
    self.factionListBox:setEntryType(2, index, ListBoxEntryType.Icon)
end

function Diplomacy:requestFactionMetadata()
    local factions = {}
    for index, relation in pairs(self.factions) do
        table.insert(factions, index)
    end

    invokeServerFunction("sendFactionMetadata", factions)
end

function Diplomacy:showFactionMetadata(eradicatedFactions)
    self.eradicatedFactions = eradicatedFactions

    for index, relation in pairs(self.factions) do
        if eradicatedFactions[relation.factionIndex] == true then
            self.factionListBox:setEntry(1, index - 1, "data/textures/icons/cross-mark.png", false, false, ColorRGB(1, 0.3, 0.3))
            self.factionListBox:setEntryType(1, index - 1, ListBoxEntryType.Icon)
        end
    end
end

function Diplomacy:getStatusIcon(status)
    if status == RelationStatus.War then
        return "data/textures/icons/crossed-rifles.png"
    elseif status == RelationStatus.Ceasefire then
        return "data/textures/icons/ceasefire.png"
    elseif status == RelationStatus.Neutral then
        return "data/textures/icons/shaking-hands.png"--"data/textures/icons/peace-dove.png"
    elseif status == RelationStatus.Allies then
        return "data/textures/icons/condor-emblem.png"
    end
end

function Diplomacy:getRelationSegment(level)
    local relation = Relation()
    local segments = {relation:getSegments()}

    for i, segment in pairs(segments) do
        if level < segment then
            relation.level = (segments[i - 1] + segments[i]) / 2
            return i - 1, relation
        end
    end

    relation.level = (segments[#segments - 1] + segments[#segments]) / 2
    return 5, relation
end

function Diplomacy:onFilterComboSelected(comboBox, item, index)
    self.filterMode = item
    self:refreshListBox()
end

function Diplomacy:onSortComboSelected(comboBox, item, index)
    self.sortMode = item
    self:refreshListBox()
end

function Diplomacy:onShowSectorPressed()
    local index = self.factionListBox.selected
    if index < 0 then return end

    local relation = self.factions[index + 1]
    if not relation then return end

    local faction = Faction(relation.factionIndex)
    if not faction then return end

    local x, y = self:findNearestDiscoveredSector(relation.factionIndex)
    if not x or not y then return end

    GalaxyMap():show(x, y)
end

function Diplomacy:onFactionSelected(index)
    local actor, player = self.getUserFaction()
    if index < 0 or not actor then
        self.container:hide()
        return
    end

    local oldRelation = self.factions[index + 1]
    if not oldRelation then
        self.container:hide()
        return
    end

    -- refresh relation
    local relation = actor:getRelation(oldRelation.factionIndex)
    self.factions[index + 1] = relation

    local faction = Faction(relation.factionIndex)
    if not faction then
        self.container:hide()
        return
    end

    self.container:show()

    -- refresh list entry
    self:updateRow(index, relation, faction)

    if faction.isPlayer then
        self.factionIcon.picture = "data/textures/icons/player.png"
    elseif faction.isAlliance then
        self.factionIcon.picture = "data/textures/icons/alliance.png"
    else
        self.factionIcon.picture = "data/textures/icons/inventory.png"
    end

    if self.eradicatedFactions and self.eradicatedFactions[faction.index] == true then
        self.factionLabel.caption = "${name} [Eradicated]"%_t % {name = faction.translatedName}
        self.factionLabel.color = ColorRGB(1, 0.5, 0.5)
    else
        self.factionLabel.caption = faction.translatedName
        self.factionLabel.color = ColorRGB(0.9, 0.9, 0.9)
    end
    self:updateTargeter(relation)

    local sx, sy = self:findNearestDiscoveredSector(relation.factionIndex)
    if not sx or not sy then
        self.sectorLabel.caption = "Unknown Location /* location on map*/"%_t
        self.sectorLabel.color = ColorRGB(0.5, 0.5, 0.5)

        self.sectorIconButton.iconColor = ColorRGB(0.5, 0.5, 0.5)
        self.sectorIconButton.tooltip = nil
        self.sectorButton.tooltip = nil
    else
        self.sectorLabel.caption = "${x} : ${y}" % {x = sx, y = sy}
        self.sectorLabel.color = ColorRGB(0.9, 0.9, 0.9)

        self.sectorIconButton.iconColor = ColorRGB(0, 1, 0)
        self.sectorIconButton.tooltip = "Show On Map"%_t
        self.sectorButton.tooltip = "Sector in which this faction can be found"%_t
    end

    self.relationBar:setValue(relation.level, string.format("Relations: %d"%_t, relation.level), relation.color)

    local relationIndex, relationSegment = self:getRelationSegment(relation.level)
    for i, elements in pairs(self.relationLabels) do
        if i == relationIndex then
            elements.frame.backgroundColor = relationSegment.color
            elements.label.color = ColorRGB(1, 1, 1)
        else
            elements.frame.backgroundColor = ColorRGB(0.3, 0.3, 0.3)
            elements.label.color = ColorRGB(0.5, 0.5, 0.5)
        end
    end

    -- status
    local color = relation.color
    if relation.status == RelationStatus.Neutral then color = ColorRGB(1, 1, 1) end

    self.statusIcon.picture = self:getStatusIcon(relation.status)
    self.statusIcon.color = color
    self.statusIcon.tooltip = relation.translatedStatus

    -- status buttons
    self.declareWarButton.visible = (relation.status == RelationStatus.Ceasefire or relation.status == RelationStatus.Neutral)
    self.cancelAllianceButton.visible = (relation.status == RelationStatus.Allies)

    -- check if the selected faction is connected to the actor
    local allianceMemberOrOwnAllianceSelected = false
    if faction.isPlayer and actor.isAlliance then
        local faction = Player(faction.index)

        if faction and faction.allianceIndex == actor.index then
            allianceMemberOrOwnAllianceSelected = true
        end

    elseif faction.isAlliance and actor.isPlayer then
        local actor = Player(actor.index)

        if actor and faction.index == actor.allianceIndex then
            allianceMemberOrOwnAllianceSelected = true
        end
    end

    local staticRelations = relation.isStatic or faction.alwaysAtWar

    if not allianceMemberOrOwnAllianceSelected and (faction.isPlayer or faction.isAlliance) and (actor.isPlayer or actor.isAlliance) then
        -- non-related faction selected, show general button
        self.negotiateWithPlayerButton.visible = true

        self.negotiateCeaseFireButton.visible = false
        self.tributeButton.visible = false
        self.negotiateAllianceButton.visible = false
    else
        self.negotiateWithPlayerButton.visible = false

        self.negotiateCeaseFireButton.visible = (relation.status == RelationStatus.War)
        if relation.level >= RelationChangeMaxCap[RelationChangeType.Tribute] or allianceMemberOrOwnAllianceSelected then
            self.tributeButton.visible = false
        else
            self.tributeButton.visible = (relation.status == RelationStatus.Ceasefire or relation.status == RelationStatus.Neutral)
        end

        local requiredLevel = self.allyNegotiationRelations + math.min(0, getStatusChangeThresholdOffset(faction))
        if not faction.homeSectorUnknown and (not staticRelations) and relation.level >= RelationChangeMaxCap[RelationChangeType.Tribute] or allianceMemberOrOwnAllianceSelected then
            -- you can always set ally status for your own alliance
            self.negotiateAllianceButton.visible = (relation.status == RelationStatus.Neutral)

            -- show the "Negotiate Alliance" button as early as possible, but disable it
            if relation.level >= requiredLevel then
                self.negotiateAllianceButton.active = true
                self.negotiateAllianceButton.tooltip = nil
            else
                self.negotiateAllianceButton.active = false
                self.negotiateAllianceButton.tooltip = "Relations of ${relations} required"%_t % {relations = createMonetaryString(requiredLevel)}
            end
        else
            self.negotiateAllianceButton.visible = false
        end
    end

    self.declareWarButton.active = self.declareWarButton.visible and not staticRelations
    self.cancelAllianceButton.active = self.cancelAllianceButton.visible and not staticRelations
    self.negotiateCeaseFireButton.active = self.negotiateCeaseFireButton.visible and not staticRelations
    self.tributeButton.active = self.tributeButton.visible and not staticRelations
    self.negotiateWithPlayerButton.active = self.negotiateWithPlayerButton.visible and not staticRelations

    self:updateTraits(faction)

    if faction.isAlliance then
        self.allianceEmblem.allianceIndex = faction.index
        self.allianceEmblem:show()
        self.emblemLabel:show()
    else
        self.allianceEmblem:hide()
        self.emblemLabel:hide()
    end
end

function Diplomacy:updateTargeter(relation)
    local path = ""
    local offset = 0
    if relation.status == RelationStatus.War then
        path = "data/textures/ui/indicator_war.png"
        offset = 10
    elseif relation.status == RelationStatus.Ceasefire then
        path = "data/textures/ui/indicator_ceasefire.png"
        offset = 4
    elseif relation.status == RelationStatus.Neutral then
        path = "data/textures/ui/indicator_neutral.png"
        offset = 1
    elseif relation.status == RelationStatus.Allies then
        path = "data/textures/ui/indicator_allies.png"
        offset = 1
    end

    local size = offset + 8

    for i, targeter in pairs(self.targeters) do
        targeter.picture = path
        targeter.color = relation.color

        local factorX = (i % 2 == 1) and -1 or 1
        local factorY = (i >= 3) and -1 or 1
        targeter.center = self.tab.lower + self.targeterCenter + vec2(factorX * size, factorY * size)
    end
end

function Diplomacy:updateTraits(faction)
    local text
    local player = Player()

    if faction.isPlayer then
        text = "\\c(777)This is another player. A good way to get to know them is the chat window :)\\c()"%_t
    elseif faction.isAlliance and player.allianceIndex ~= faction.index then
        text = "\\c(777)This is another player alliance. A good way to get to know them is the chat window :)\\c()"%_t
    elseif faction.isAlliance and player.allianceIndex == faction.index then
        text = "\\c(777)This is your alliance.\\c()"%_t
    elseif faction.isAIFaction then
        if faction.name ~= "The Cavaliers" and faction.name ~= "The Commune" and faction.name ~= "The Family" and faction.homeSectorUnknown then
            text = "\\c(777)Not much is known about this faction.\\c()"%_t
        else
            local traits = {
                "peaceful", "aggressive", "careful", "brave", "generous", "greedy", "opportunistic", "honorable", "trusting", "mistrustful"
            }

            if faction.name == "The Cavaliers" or faction.name == "The Commune" or faction.name == "The Family" then
                traits = {
                    "traditional", "revolutionary", "authoritarian", "tolerant", "violent", "gentle", "conservative", "progressive", "shady", "reputable",
                }
            end

            for _, trait in pairs(traits) do
                local value = faction:getTrait(trait) or 0
                if value >= 0.25 then
                    local name = self:getTraitName(trait, value)
                    local descriptions = self:getTraitDescriptions(trait, value)
                    if name then
                        if text then
                            text = text .. "\n"
                        else
                            text = ""
                        end

                        text = text .. "\\c()" .. name .. "\\c(777)"

                        if #descriptions > 0 then
                            for _, description in pairs(descriptions) do
                                text = text .. "\n- " .. description
                            end
                        end

                        text = text .. "\n"

                    end
                end
            end
        end
    else
        text = "\\c(777)Not much is known about this faction.\\c()"%_t
    end

    if not text then
        self.traitsLabel:hide()
        text = ""
    else
        self.traitsLabel:show()
    end

    self.traits.text = text
end

function Diplomacy:getTraitName(trait, value)
    if value < 0.25 then return end

    local percentage = round(value * 4) / 4 * 100

    return "${trait} (${percentage}%)"%_t % {trait = string.firstToUpper(trait%_t), percentage = percentage}
end

function Diplomacy:getTraitDescriptions(trait, value)
    local descriptions = {}

    if trait == "peaceful" then
        table.insert(descriptions, "Tend to send fewer reinforcements when supporting allies"%_t) -- reinforcementstransmitter
        if value > 0.5 then
            table.insert(descriptions, "Much greater loss of reputation when attacked"%_t) -- relations.lua
            table.insert(descriptions, "Much greater increase in reputation through combat support"%_t) -- relations.lua
            table.insert(descriptions, "Greater increase in reputation by commerce (exception: weapons) & tribute"%_t) -- relations.lua
        end
        table.insert(descriptions, "Less cost when negotiating ceasefires and alliances"%_t) -- diplomacy

    elseif trait == "aggressive" then
        table.insert(descriptions, "Tend to send more reinforcements when supporting allies"%_t) -- reinforcementstransmitter

        if value >= 0.85 then
            table.insert(descriptions, "Chance of wars with neighboring factions"%_t) -- initfactionwar
        end

        if value > 0.5 then
            table.insert(descriptions, "Less loss of reputation when attacked"%_t) -- relations.lua
            table.insert(descriptions, "Greater increase in reputation when trading weapons"%_t) -- relations.lua
            table.insert(descriptions, "Increased cost when negotiating ceasefires and alliances"%_t) -- diplomacy
        end

    elseif trait == "careful" then
        table.insert(descriptions, "Increased range when scanning cargo transports"%_t) -- antismuggle
        table.insert(descriptions, "Military ships are more heavily armed"%_t) -- asyncshipgenerator

        table.insert(descriptions, "Stronger security on ships"%_t) -- defaultscripts
        if value > 0.5 then
            table.insert(descriptions, "Greater loss of reputation when attacked"%_t) -- relations.lua
        end

    elseif trait == "brave" then
        table.insert(descriptions, "Send more reinforcements when supporting allies"%_t) -- reinforcementstransmitter

        if value > 0.5 then
            table.insert(descriptions, "Less increase in reputation by commerce"%_t) -- relations.lua
        end

    elseif trait == "generous" then
        if value > 0.5 then
            table.insert(descriptions, "Lower fines and less reputation loss for doing something illegal"%_t) -- relations.lua, antismuggle, scrapyard
        else
            table.insert(descriptions, "Lower fines for doing something illegal"%_t) -- relations.lua, antismuggle, scrapyard
        end
        table.insert(descriptions, "More patience during negotiations"%_t) -- diplomacy
        if value > 0.5 then
            table.insert(descriptions, "Lowered cost for tribute and when negotiating alliances"%_t) -- diplomacy
        end

    elseif trait == "greedy" then
        table.insert(descriptions, "Higher fines when doing something illegal"%_t) -- antismuggle
        if value > 0.5 then
            table.insert(descriptions, "Greater increase in reputation by commerce and tribute"%_t) -- relations.lua
        end
        table.insert(descriptions, "Less patience during negotiations"%_t) -- diplomacy
        if value > 0.5 then
            table.insert(descriptions, "Increased cost when negotiating ceasefires and alliances"%_t) -- diplomacy
        end

    elseif trait == "opportunistic" then
        if value > 0.5 then
            table.insert(descriptions, "Less reputation loss for doing something illegal"%_t) -- relations.lua
            table.insert(descriptions, "No reputation loss when witnessing attacks on helpless ships"%_t) -- relationchanges
            table.insert(descriptions, "Increased cost for tribute, negotiating alliances and ceasefires"%_t) -- diplomacy
        else
            table.insert(descriptions, "Less reputation loss when witnessing attacks on helpless ships"%_t) -- relationchanges
        end
        table.insert(descriptions, "More patience during negotiations"%_t) -- diplomacy

    elseif trait == "honorable" then
        table.insert(descriptions, "Tend to send more reinforcements when supporting allies"%_t) -- reinforcementstransmitter
        if value > 0.5 then
            table.insert(descriptions, "Greater loss of reputation when doing something illegal"%_t) -- relations.lua
        end
        table.insert(descriptions, "Greater loss of reputation when witnessing attacks on helpless ships"%_t) -- relationchanges
        table.insert(descriptions, "Less patience during negotiations"%_t) -- diplomacy

    elseif trait == "trusting" then
        table.insert(descriptions, "Alliance negotiations require less reputation than usual"%_t) -- relations
        table.insert(descriptions, "Treaties are terminated later when relations worsen"%_t) -- relations

    elseif trait == "mistrustful" then
        if value > 0.5 then
            table.insert(descriptions, "Greater loss of reputation when doing something illegal"%_t) -- relations.lua
            table.insert(descriptions, "Lower increase in reputation through tribute"%_t) -- relations.lua
        end
        table.insert(descriptions, "Decreased willingness to negotiate"%_t) -- diplomacy
        table.insert(descriptions, "Alliance negotiations require more reputation than usual"%_t) -- diplomacy
        table.insert(descriptions, "Treaties are terminated earlier when relations worsen"%_t) -- relations.lua

    elseif trait == "forgiving" then
        table.insert(descriptions, "Less reputation loss when attacked"%_t) -- relationchanges
        table.insert(descriptions, "Less reputation loss when doing something illegal"%_t) -- relationchanges


    -- traits for syndicates
    elseif trait == "traditional" then
        -- family
        if value > 0.5 then
            table.insert(descriptions, "Uses the current situation to their advantage"%_t)
            table.insert(descriptions, "Wants to keep the everything running"%_t)
        end

    elseif trait == "revolutionary" then
        -- cavaliers
        if value > 0 and value <= 0.5 then
            table.insert(descriptions, "Are discontent with the current power distribution"%_t)
            table.insert(descriptions, "Want a new order under their own supreme rule"%_t)
        end
        -- commune
        if value > 0.5 then
            table.insert(descriptions, "Is discontent with the current power distribution"%_t)
            table.insert(descriptions, "Wants to establish a galaxy-wide rule by the people instead of the factions"%_t)
        end

    elseif trait == "authoritarian" then
        -- family
        if value > 0 and value <= 0.5 then
            table.insert(descriptions, "Is structured with a clear hierarchy"%_t)
            table.insert(descriptions, "Every member is free to follow their own business"%_t)
        end
        -- cavaliers
        if value > 0.5 then
            table.insert(descriptions, "Is structured with a clear hierarchy"%_t)
            table.insert(descriptions, "Command and obedience is the most important form of communication"%_t)
        end

    elseif trait == "tolerant" then
        -- commune
        table.insert(descriptions, "Is structured with a clear hierarchy"%_t)
        table.insert(descriptions, "Every member is free to follow their own business"%_t)

    elseif trait == "violent" then
        -- family
        if value > 0 and value <= 0.5 then
            table.insert(descriptions, "Violence is used primarily to underline threats"%_t)
            table.insert(descriptions, "Business is getting harder if there is too much brutality"%_t)
        end
        -- cavaliers
        if value > 0.5 then
            table.insert(descriptions, "Violence is part of their culture"%_t)
            table.insert(descriptions, "The strong will rule over the weak"%_t)
        end

    elseif trait == "gentle" then
        -- commune
        table.insert(descriptions, "They win the hearts of their followers with kindness"%_t)
        table.insert(descriptions, "Violence is only used for self-defense"%_t)

    elseif trait == "conservative" then
        -- family
        if value > 0 and value <= 0.5 then
            table.insert(descriptions, "New trends are not beeing followed"%_t)
            table.insert(descriptions, "A change that opens new opportunites is always welcome"%_t)
        end
        -- cavaliers
        if value > 0.5 then
            table.insert(descriptions, "Honor and valor are the basics on which they are build"%_t)
            table.insert(descriptions, "The deprivation of honor is one of the harshest punishments"%_t)
        end

    elseif trait == "progressive" then
        -- commune
        table.insert(descriptions, "The old order must be abolished"%_t)
        table.insert(descriptions, "Every inhabitant of the galaxy has a right to be heard"%_t)

    elseif trait == "shady" then
        -- cavaliers and commune
        if value > 0 and value <= 0.5 then
            table.insert(descriptions, "Members try to stay unknown"%_t)
            table.insert(descriptions, "Some of the work still needs to be done in public"%_t)
        end
        -- family
        if value > 0.5 then
            table.insert(descriptions, "An extensive network of corrupt officials is the basis of their power"%_t)
            table.insert(descriptions, "They pull the strings behind the curtains"%_t)
        end

    elseif trait == "reputable" then
        -- no syndicate is reputable
        table.insert(descriptions, "No syndicate is reputable"%_t)


    end

    return descriptions
end

function Diplomacy:getAllianceEmblem()
    return self.allianceEmblem
end

function Diplomacy:findNearestDiscoveredSector(factionIndex)
    local player = self.getUserFaction()
    if not player then return end

    local faction = self.factionsOnMap[factionIndex]
    if not faction then return end

    if faction.nearestControllingSector then
        return faction.nearestControllingSector.x, faction.nearestControllingSector.y
    end
    if faction.nearestPresentSector then
        return faction.nearestPresentSector.x, faction.nearestPresentSector.y
    end
end

function Diplomacy:onPayTributePressed()
--    print("pay tribute")
    local index = self.factionListBox.selected
    if index < 0 then return end

    local relation = self.factions[index + 1]
    if not relation then return end

    invokeServerFunction("startNegotiation", "tribute", relation.factionIndex)
end

function Diplomacy:onDeclareWarPressed()
--    print("declare war!")
    local index = self.factionListBox.selected
    if index < 0 then return end

    local relation = self.factions[index + 1]
    if not relation then return end

    local faction = Faction(relation.factionIndex)
    if not faction then return end

    local description = "Do you really want to declare war against ${faction}?"%_t % {faction = faction.translatedName}
    self:showConfirmationWindow("Confirm Declaration of War"%_t, description, self.onDeclareWarConfirmed, relation.factionIndex)
end

function Diplomacy:onDeclareWarConfirmed(factionIndex)
    invokeServerFunction("setWarWithFaction", factionIndex)
end

function Diplomacy:onAbandonAlliancePressed()
--    print("abandon alliance!")
    local index = self.factionListBox.selected
    if index < 0 then return end

    local relation = self.factions[index + 1]
    if not relation then return end

    local faction = Faction(relation.factionIndex)
    if not faction then return end

    local description = "Do you really no longer want to be allied with ${faction}?"%_t % {faction = faction.translatedName}
    self:showConfirmationWindow("Confirm Abandoning Allies"%_t, description, self.onAbandonAllianceConfirmed, relation.factionIndex)
end

function Diplomacy:onAbandonAllianceConfirmed(factionIndex)
    invokeServerFunction("abandonAllianceWithFaction", factionIndex)
end

function Diplomacy:onNegotiateCeaseFirePressed()
--    print("negotiate ceasefire!")
    local index = self.factionListBox.selected
    if index < 0 then return end

    local relation = self.factions[index + 1]
    if not relation then return end

    -- check if the selected faction is connected to the actor
    local faction = Faction(relation.factionIndex)
    local actor = self.getUserFaction()
    if faction and actor then
        if faction.isPlayer and actor.isAlliance then
            local faction = Player(faction.index)

            if faction and faction.allianceIndex == actor.index then
                invokeServerFunction("setCeasefireWithFaction", faction.index)
                return
            end

        elseif faction.isAlliance and actor.isPlayer then
            local actor = Player(actor.index)

            if actor and faction.index == actor.allianceIndex then
                invokeServerFunction("setCeasefireWithFaction", faction.index)
                return
            end
        end
    end

    invokeServerFunction("startNegotiation", "ceasefire", relation.factionIndex)
end

function Diplomacy:onNegotiateAlliancePressed()
--    print("negotiate alliance!")
    local index = self.factionListBox.selected
    if index < 0 then return end

    local relation = self.factions[index + 1]
    if not relation then return end

    -- check if the selected faction is connected to the actor
    local faction = Faction(relation.factionIndex)
    local actor = self.getUserFaction()
    if faction and actor then
        if faction.isPlayer and actor.isAlliance then
            local faction = Player(faction.index)

            if faction and faction.allianceIndex == actor.index then
                invokeServerFunction("setAlliedWithFaction", faction.index)
                return
            end

        elseif faction.isAlliance and actor.isPlayer then
            local actor = Player(actor.index)

            if actor and faction.index == actor.allianceIndex then
                invokeServerFunction("setAlliedWithFaction", faction.index)
                return
            end
        end
    end

    invokeServerFunction("startNegotiation", "alliance", relation.factionIndex)
end

function Diplomacy:onNegotiateWithPlayerPressed()
    local index = self.factionListBox.selected
    if index < 0 then return end

    local relation = self.factions[index + 1]
    if not relation then return end

    local actor, player = self.getUserFaction()
    if not actor then return end

    local faction = Faction(relation.factionIndex)
    if not faction then return end

    if faction.isAlliance then
        displayChatMessage("Use the Player Trade Window to negotiate with Alliances."%_t, "", 3)
        return
    end

    local message = "/trade \"" .. faction.index .. "\""
    if actor.isAlliance then
        message = message .. " 1"
    else
        message = message .. " 0"
    end

    player:sendChatMessage(message)
end

end

function Diplomacy:new()
    local object = {}
    setmetatable(object, self)
    self.__index = self

    return object
end

function Diplomacy.CreateNamespace()
    local instance = Diplomacy:new()
    local result = {instance = instance}

    if onServer() then
        result.getInteractingParties =      function(...) return instance:getInteractingParties(...) end
        result.setWarWithFaction =          function(...) return instance:setWarWithFaction(...) end
        result.abandonAllianceWithFaction = function(...) return instance:abandonAllianceWithFaction(...) end
        result.setCeasefireWithFaction =    function(...) return instance:setCeasefireWithFaction(...) end
        result.setAlliedWithFaction =       function(...) return instance:setAlliedWithFaction(...) end
        result.negotiationPossible =        function(...) return instance:negotiationPossible(...) end
        result.getUpdatedPatience =         function(...) return instance:getUpdatedPatience(...) end
        result.startNegotiation =           function(...) return instance:startNegotiation(...) end
        result.receiveOffer =               function(...) return instance:receiveOffer(...) end
        result.getNegotiationData =         function(...) return instance:getNegotiationData(...) end
        result.isActionAllowed =            function(...) return instance:isActionAllowed(...) end
        result.onNegotiationSuccessful =    function(...) return instance:onNegotiationSuccessful(...) end
        result.sendFactionMetadata =        function(...) return instance:sendFactionMetadata(...) end

        -- the following comment is important for a unit test
        -- Dynamic Namespace result
        callable(result, "setWarWithFaction")
        callable(result, "abandonAllianceWithFaction")
        callable(result, "setCeasefireWithFaction")
        callable(result, "setAlliedWithFaction")
        callable(result, "startNegotiation")
        callable(result, "receiveOffer")
        callable(result, "sendFactionMetadata")
    end

    if onClient() then
        result.initialize =                   function(...) return instance:initialize(...) end
        result.onShowTab =                    function(...) return instance:onShowTab(...) end
        result.onRelationChanged =            function(...) return instance:onRelationChanged(...) end
        result.onAllianceChanged =            function(...) return instance:onAllianceChanged(...) end
        result.onDelete =                     function(...) return instance:onDelete(...) end
        result.buildNegotiationWindow =       function(...) return instance:buildNegotiationWindow(...) end
        result.showNegotiationWindow =        function(...) return instance:showNegotiationWindow(...) end
        result.buildConfirmationWindow =      function(...) return instance:buildConfirmationWindow(...) end
        result.showConfirmationWindow =       function(...) return instance:showConfirmationWindow(...) end
        result.onConfirmPressed =             function(...) return instance:onConfirmPressed(...) end
        result.onCancelPressed =              function(...) return instance:onCancelPressed(...) end
        result.onOfferChanged =               function(...) return instance:onOfferChanged(...) end
        result.onOfferPressed =               function(...) return instance:onOfferPressed(...) end
        result.onOfferSuccessful =            function(...) return instance:onOfferSuccessful(...) end
        result.onOfferRejected =              function(...) return instance:onOfferRejected(...) end
        result.getFilterFunction =            function(...) return instance:getFilterFunction(...) end
        result.getSortFunction =              function(...) return instance:getSortFunction(...) end
        result.getSortableFunction =          function(...) return instance:getSortableFunction(...) end
        result.refreshListBox =               function(...) return instance:refreshListBox(...) end
        result.refreshFactionsOnMap =         function(...) return instance:refreshFactionsOnMap(...) end
        result.updateRow =                    function(...) return instance:updateRow(...) end
        result.getStatusIcon =                function(...) return instance:getStatusIcon(...) end
        result.getRelationSegment =           function(...) return instance:getRelationSegment(...) end
        result.onFilterComboSelected =        function(...) return instance:onFilterComboSelected(...) end
        result.onSortComboSelected =          function(...) return instance:onSortComboSelected(...) end
        result.onShowSectorPressed =          function(...) return instance:onShowSectorPressed(...) end
        result.onFactionSelected =            function(...) return instance:onFactionSelected(...) end
        result.updateTargeter =               function(...) return instance:updateTargeter(...) end
        result.showFactionMetadata =          function(...) return instance:showFactionMetadata(...) end
        result.findNearestDiscoveredSector =  function(...) return instance:findNearestDiscoveredSector(...) end
        result.onPayTributePressed =          function(...) return instance:onPayTributePressed(...) end
        result.onDeclareWarPressed =          function(...) return instance:onDeclareWarPressed(...) end
        result.onDeclareWarConfirmed =        function(...) return instance:onDeclareWarConfirmed(...) end
        result.onAbandonAlliancePressed =     function(...) return instance:onAbandonAlliancePressed(...) end
        result.onAbandonAllianceConfirmed =   function(...) return instance:onAbandonAllianceConfirmed(...) end
        result.onNegotiateCeaseFirePressed =  function(...) return instance:onNegotiateCeaseFirePressed(...) end
        result.onNegotiateAlliancePressed =   function(...) return instance:onNegotiateAlliancePressed(...) end
        result.onNegotiateWithPlayerPressed = function(...) return instance:onNegotiateWithPlayerPressed(...) end
        result.getAllianceEmblem =            function(...) return instance:getAllianceEmblem(...) end
    end

    return result
end

return Diplomacy
