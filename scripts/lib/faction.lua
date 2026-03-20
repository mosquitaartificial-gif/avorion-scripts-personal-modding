package.path = package.path .. ";data/scripts/lib/?.lua"
include("stringutility")
include("utility")

-- this is so the script won't crash when executed in a context where there's no onServer() or onClient() function available -
-- naturally those functions should return false then
if not onServer then onServer = function() return false end end
if not onClient then onClient = function() return false end end

local i = 1; function c() i = i + 1; return i end
FactionStateFormType =
{
    Vanilla = c(),
    Emirate = c(),
    States = c(),
    Planets = c(),
    Kingdom = c(),
    Army = c(),
    Empire = c(),
    Clan = c(),
    Church = c(),
    Corporation = c(),
    Federation = c(),
    Collective = c(),
    Followers = c(),
    Organization = c(),
    Alliance = c(),
    Republic = c(),
    Commonwealth = c(),
    Dominion = c(),
    Syndicate = c(),
    Guild = c(),
    Buccaneers = c(),
    Conglomerate = c(),
}
i = 0

FactionArchetype =
{
    Vanilla = c(),
    Traditional = c(),
    Independent = c(),
    Militaristic = c(),
    Religious = c(),
    Corporate = c(),
    Alliance = c(),
    Sect = c(),
}

i = nil; c = nil

local archetypeByStateForm = {}
archetypeByStateForm[FactionStateFormType.Vanilla] = FactionArchetype.Vanilla
archetypeByStateForm[FactionStateFormType.Emirate] = FactionArchetype.Traditional
archetypeByStateForm[FactionStateFormType.States] = FactionArchetype.Independent
archetypeByStateForm[FactionStateFormType.Planets] = FactionArchetype.Independent
archetypeByStateForm[FactionStateFormType.Kingdom] = FactionArchetype.Traditional
archetypeByStateForm[FactionStateFormType.Army] = FactionArchetype.Militaristic
archetypeByStateForm[FactionStateFormType.Empire] = FactionArchetype.Traditional
archetypeByStateForm[FactionStateFormType.Clan] = FactionArchetype.Militaristic
archetypeByStateForm[FactionStateFormType.Church] = FactionArchetype.Religious
archetypeByStateForm[FactionStateFormType.Corporation] = FactionArchetype.Corporate
archetypeByStateForm[FactionStateFormType.Federation] = FactionArchetype.Alliance
archetypeByStateForm[FactionStateFormType.Collective] = FactionArchetype.Sect
archetypeByStateForm[FactionStateFormType.Followers] = FactionArchetype.Religious
archetypeByStateForm[FactionStateFormType.Organization] = FactionArchetype.Vanilla
archetypeByStateForm[FactionStateFormType.Alliance] = FactionArchetype.Alliance
archetypeByStateForm[FactionStateFormType.Republic] = FactionArchetype.Independent
archetypeByStateForm[FactionStateFormType.Commonwealth] = FactionArchetype.Alliance
archetypeByStateForm[FactionStateFormType.Dominion] = FactionArchetype.Independent
archetypeByStateForm[FactionStateFormType.Syndicate] = FactionArchetype.Corporate
archetypeByStateForm[FactionStateFormType.Guild] = FactionArchetype.Corporate
archetypeByStateForm[FactionStateFormType.Buccaneers] = FactionArchetype.Militaristic
archetypeByStateForm[FactionStateFormType.Conglomerate] = FactionArchetype.Corporate

function TraitToInt(value)
    return math.min(4, math.max(-4, round(value * 4)))
end

function StateFormToArchetype(stateFormType)
    return archetypeByStateForm[stateFormType] or FactionArchetype.Vanilla
end

-- number between 0 and 1 as percentage of the actual price
-- usually the price is calculated like this:
-- local price = 1000
-- local priceWithFee = price + price * fee
function GetFee(providingFaction, orderingFaction)

    if orderingFaction.index == providingFaction.index then return 0 end

    local percentage = 0;
    local relation = 0

    if onServer() then
        relation = providingFaction:getRelations(orderingFaction.index)
    else
        local player = Player()
        if providingFaction.index == player.index then
            relation = player:getRelations(orderingFaction.index)
        else
            relation = player:getRelations(providingFaction.index)
        end
    end

    percentage = 0.5 - relation / 200000;

    -- pay extra if relations are not good
    if relation < 0 then
        percentage = percentage * 1.5
    end

    return percentage
end

local overriddenRelationThreshold

function overrideRelationThreshold(threshold)
    overriddenRelationThreshold = threshold
end

function CheckFactionInteraction(playerIndex, relationThreshold, msg, checkMinimumPopulation)

    -- physical check: if the station has its docks disabled or the player is not in a craft -> not possible
    local docks = DockingPositions()
    if docks and not docks.docksEnabled then return false, "" end

    -- minimum population check
    if checkMinimumPopulation == nil then checkMinimumPopulation = true end -- do the check by default, only skip if it's explicitly 'false'
    if checkMinimumPopulation and MinimumPopulation and not MinimumPopulation.isFulfilled() then
        return false, "Station needs a minimum population of at least 30 crewmen (and quarters)."
    end

    local player = Player(playerIndex)

    local craft = player.craft
    if not craft then return false, "" end

    -- rest is relations checks
    local interactor = player
    if craft.factionIndex == player.allianceIndex then
        interactor = player.alliance
    end

    local stationFaction = Faction()
    if not stationFaction then
        return false, msg or "This station doesn't belong to anybody."%_t
    end

    -- alliance ships should always be able to interact with alliance-player stations
    if stationFaction.isPlayer then
        stationFaction = Player()

        if interactor.isAlliance and stationFaction.allianceIndex == interactor.index then
            return true
        end
    end

    -- player ships should always be able to interact with alliance-stations
    if stationFaction.index == player.allianceIndex then return true end

    if overriddenRelationThreshold then relationThreshold = overriddenRelationThreshold end

    local relation = interactor:getRelation(stationFaction.index)

    if relation.status == RelationStatus.War or relation.level < relationThreshold then
        return false, msg or "Our records say that we're not allowed to do business with you.\n\nCome back when your relations with our faction are better."%_t
    end

    return true
end

if onServer() then

-- return the interacting faction based on the ship the player is flying, and check if the player has certain permissions
function getInteractingFaction(callingPlayer, ...)
    local player = Player(callingPlayer)
    if not player then return end

    local ship = Sector():getEntity(player.craftIndex)
    if not ship then return end

    local alliance
    if ship.factionIndex == player.allianceIndex then
        alliance = player.alliance

        local requiredPrivileges = {...}
        for _, privilege in pairs(requiredPrivileges) do
            if not alliance:hasPrivilege(callingPlayer, privilege) then
                player:sendChatMessage("", 1, "You don't have permission to do that in the name of your alliance."%_t)
                return
            end
        end
    end

    local buyer
    if not alliance then
        buyer = player
    else
        buyer = alliance
    end

    return buyer, ship, player, alliance
end

-- return the interacting faction based on a given ship, and if there's a calling player, check for permissions
-- this is used when ai factions should be able to interact as well and when there's not necessarily a calling player
function getInteractingFactionByShip(shipIndex, callingPlayer, ...)

    local ship = Entity(shipIndex)
    if not ship then return end

    local buyer = Faction(ship.factionIndex)
    local alliance
    if buyer.isAlliance then
        alliance = Alliance(buyer.index)
    end

    local player
    if callingPlayer then
        player = Player(callingPlayer)
        if not player then return end

        if player.craftIndex ~= Uuid(shipIndex) then return end

        if ship.factionIndex == player.allianceIndex then
            local requiredPrivileges = {...}
            for _, privilege in pairs(requiredPrivileges) do
                if not alliance:hasPrivilege(callingPlayer, privilege) then
                    player:sendChatMessage("", 1, "You don't have permission to do that in the name of your alliance."%_t)
                    return
                end
            end
        end
    end

    if alliance then
        buyer = alliance
    end

    return buyer, ship, player, alliance
end


-- check if the calling player has permissions to do things with the given entity
function checkEntityInteractionPermissions(craft, ...)
    if not craft then return end

    if callingPlayer == nil then
        if craft.allianceOwned then
            local alliance = Alliance(craft.factionIndex)
            return alliance, craft, nil, alliance
        else
            local player = Player(craft.factionIndex)
            return player, craft, player
        end
    end

    local player = Player(callingPlayer)
    if not player then return end

    local alliance
    local owner
    if craft.factionIndex and craft.factionIndex == player.allianceIndex then
        -- if the entity belongs to the player's alliance, then check for any given privileges
        alliance = player.alliance

        local requiredPrivileges = {...}
        for _, privilege in pairs(requiredPrivileges) do
            if not alliance:hasPrivilege(callingPlayer, privilege) then
                player:sendChatMessage("", 1, "You don't have permission to do that in the name of your alliance."%_t)
                return
            end
        end

        owner = alliance

    elseif craft.factionIndex == player.index then
        -- players can do whatever they want with their own entities
        owner = player
    else
        player:sendChatMessage("", 1, "You don't have permission to do that."%_t)
        return
    end

    return owner, craft, player, alliance

end


function SetFactionTrait(faction, trait, contrary, value)
    local a = value
    local b = -a

    faction:setTrait(trait, a)
    faction:setTrait(contrary, b)
end

end


if onClient() then

-- check if the calling player has permissions to do things with the given entity
function checkEntityInteractionPermissions(craft, ...)

    if not craft then return end

    local player = Player()
    if not player then return end

    local alliance
    local owner
    if craft.factionIndex == player.allianceIndex then
        -- if the entity belongs to the player's alliance, then check for any given privileges
        alliance = player.alliance

        local requiredPrivileges = {...}
        for _, privilege in pairs(requiredPrivileges) do
            if not alliance:hasPrivilege(player.index, privilege) then
                return
            end
        end

        owner = alliance

    elseif craft.factionIndex == player.index then
        -- players can do whatever they want with their own entities
        owner = player
    else
        return
    end

    return owner, craft, player, alliance

end

end
