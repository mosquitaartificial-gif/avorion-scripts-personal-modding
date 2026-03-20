package.path = package.path .. ";data/scripts/lib/?.lua"

include ("randomext")
include ("utility")
include ("callable")
include ("player")
include ("stringutility")
include ("relations")
local Dialog = include ("dialogutility")
PassageMap = include ("passagemap")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace CivilShip
CivilShip = {}

local ThreatenState =
{
    Mock = 1,
    GiveUp = 2,
    Flee = 3,
    Attack = 4,
}

local threatenedState = {}
local willFlee = false

function CivilShip.interactionPossible(playerIndex, option)

    if option == 0 then
        local faction = Faction()
        local player = Player()
        if player then player = player.craftFaction end

        if player and faction then
            local relation = player:getRelation(faction.index)
            if relation.status == RelationStatus.War then return false end
            if relation.level <= -80000 then return false end

            return true
        else
            return false
        end

    elseif option == 1 then
        local ship = Entity()

        local cargos = ship:getCargos()

        if tablelength(cargos) == 0 then
            return false
        end
    end

    return true
end

function CivilShip.initialize()
    local entity = Entity()

    if onClient() then
        InteractionText(entity.index).text = Dialog.generateShipInteractionText(entity, random())
    else
        -- player/alliance ships should never run, since run == delete
        local faction = Faction()
        if faction and faction.isAIFaction then
            -- 50% chance that a civil ship will just run
            willFlee = math.random() > 0.5
        end
    end

end

function CivilShip.initUI()
    ScriptUI():registerInteraction("Where is your home sector?"%_t, "onWhereHomeSector", 2);
    ScriptUI():registerInteraction("Give me all your cargo!"%_t, "secondTake");
end


function CivilShip.onServerRespondedDumping()
    ScriptUI():interactShowDialog({text = "Dumping the cargo. I hope you're happy, you damn pirate."%_t})
end

function CivilShip.onServerRespondedMocking()

    local dialog = {}
    dialog.text = "Hahahahaha!"%_t
    dialog.answers = {
        {answer = "I'm serious!"%_t, followUp = {
            text = "And how are you planning on doing that?"%_t,
            answers = {
                {answer = "I'm going to destroy you!"%_t, text = "This is ridiculous. Go away."%_t},
                {answer = "Leave"%_t }
            }
        }},
        {answer = "Okay, sorry, wrong ship."%_t},
    }

    ScriptUI():interactShowDialog(dialog)

end

function CivilShip.onServerRespondedGiveUp()

    local dialog = {}
    dialog.text = "..."%_t
    dialog.followUp = {
        text = "Leave us alone!"%_t,
        answers = {
            {answer = "Dump your cargo or you'll be destroyed!"%_t, followUp = {
                text = "Please don't shoot! We will dump the cargo, but then you must leave us alone!"%_t,
                answers = {
                    {answer = "Dump your cargo and you will be spared."%_t, onSelect = "onInsistSelected"},
                    {answer = "If you cooperate, I might spare your lives."%_t, onSelect = "onInsistSelected"},
                    {answer = "I'm going to destroy you!"%_t, onSelect = "onInsistSelected"},
                    {answer = "On second thought, I don't need anything from you."%_t, text = "What kind of sick joke is this!?"%_t }
                }
            }},
            {answer = "Okay, sorry, wrong ship."%_t},
        }
    }

    ScriptUI():interactShowDialog(dialog)

end

function CivilShip.onServerRespondedFlee()
    ScriptUI():interactShowDialog({text = "We'll be out of here before you even get to us!"%_t})
end

function CivilShip.onServerRespondedNotImpressed()

    local dialog = {}
    dialog.text = "..."%_t
    dialog.followUp = {
        text = "You should leave."%_t,
        answers = {
            {answer = "Dump your cargo or you'll be destroyed!"%_t, followUp = {
                text = "I will not give up my cargo freely to some petty pirate!"%_t,
                answers = {
                    {answer = "So be it then!"%_t, onSelect = "onInsistSelected"},
                    {answer = "I'm going to destroy you!"%_t, onSelect = "onInsistSelected"},
                    {answer = "Oops, sorry, wrong ship, carry on!"%_t},
                }
            }},
            {answer = "Okay, sorry, wrong ship."%_t},
        }
    }

    ScriptUI():interactShowDialog(dialog)

end

function CivilShip.onServerRespondedAttacking()
    ScriptUI():interactShowDialog({text = "Leave or be destroyed!"%_t})
end

function CivilShip.secondTake()
    ScriptUI():showDialog(Dialog.empty())
    CivilShip.kidding() -- don't give relation penalty immediately
end

function CivilShip.onRaidSelected()
    invokeServerFunction("threaten")
end

function CivilShip.onInsistSelected()
    ScriptUI():showDialog(Dialog.empty())
    invokeServerFunction("insist")
end

function CivilShip.insist()
    if not callingPlayer then return end

    local state = threatenedState[callingPlayer]
    if not state then return end

    if state == ThreatenState.GiveUp then
        CivilShip.worsenRelations()
        CivilShip.worsenRelations()

        CivilShip.dumpCargo()

        invokeClientFunction(Player(callingPlayer), "onServerRespondedDumping")

        -- send emergency signal and call for help
        local sector = Sector()
        sector:broadcastChatMessage(Entity(), ChatMessageType.Chatter, "We're under attack! Help! Send out an emergency signal!"%_T)

        local x, y = sector:getCoordinates()

        -- send a message to all players in a 20 sector radius
        AlertNearbyPlayers(x, y, 20, function(player, sx, sy, shipName)
            if shipName then
                player:sendChatMessage(shipName, 0, "Commander, we received an emergency call from an unknown source in \\s(%1%:%2%)."%_t, x, y)
            else
                player:sendChatMessage("Unknown Source"%_T, 3, "You received an emergency call from an unknown source in \\s(%1%:%2%)."%_t, x, y)
            end
        end)

    elseif state == ThreatenState.Attack then
        CivilShip.worsenRelations()

        CivilShip.attackPlayer()

        invokeClientFunction(Player(callingPlayer), "onServerRespondedAttacking")
    end

    threatenedState[callingPlayer] = nil
end
callable(CivilShip, "insist")

function CivilShip.kidding()
    local dialog = {}
    dialog.text = "You're kidding, right?"%_t
    dialog.answers =
    {
        {answer = "No. Now give me all your cargo!"%_t, onSelect = "onRaidSelected"},
        {answer = "Sorry. Bad joke."%_t}
    }

    ScriptUI():interactShowDialog(dialog)
end

function CivilShip.threaten()
    if not callingPlayer then return end

    CivilShip.worsenRelations()

    threatenedState[callingPlayer] = nil

    -- evaluate strength of own ship vs strength of player
    local me = Entity()
    local player = Player(callingPlayer)
    local ship = player.craft

    local myDps = me.firePower
    local playerDps = ship.firePower

    local meDestroyed = me.durability / playerDps
    local playerDestroyed = ship.durability / myDps

    if myDps == 0 and meDestroyed / 60 > 2 then
        -- player can't do anything
        threatenedState[callingPlayer] = ThreatenState.Mock
        invokeClientFunction(player, "onServerRespondedMocking")

    elseif meDestroyed * 2.0 < playerDestroyed then
        -- "okay I'm dead"
        if willFlee == true then
            threatenedState[callingPlayer] = ThreatenState.Flee
            invokeClientFunction(player, "onServerRespondedFlee")
            deferredCallback(5, "flee")
        else
            threatenedState[callingPlayer] = ThreatenState.GiveUp
            invokeClientFunction(player, "onServerRespondedGiveUp")
        end

    elseif meDestroyed < playerDestroyed then
        -- "I might be in trouble"

        if willFlee == true then
            threatenedState[callingPlayer] = ThreatenState.Flee
            invokeClientFunction(player, "onServerRespondedFlee")
            deferredCallback(5, "flee")
        else
            if math.random() > 0.5 then
                threatenedState[callingPlayer] = ThreatenState.GiveUp
                invokeClientFunction(player, "onServerRespondedGiveUp")
            else
                threatenedState[callingPlayer] = ThreatenState.Attack
                invokeClientFunction(player, "onServerRespondedNotImpressed")
            end
        end

    elseif meDestroyed * 0.5 > playerDestroyed then
        -- "I will take you on!"
        invokeClientFunction(player, "onServerRespondedNotImpressed")
        threatenedState[callingPlayer] = ThreatenState.Attack

    elseif meDestroyed > playerDestroyed then
        -- "I might get out of this"
        invokeClientFunction(player, "onServerRespondedNotImpressed")
        threatenedState[callingPlayer] = ThreatenState.Attack
    end
end
callable(CivilShip, "threaten")

function CivilShip.dumpCargo()
    local ship = Entity()
    local cargos = ship:getCargos()
    local playerCraft = Player(callingPlayer).craft

    for good, amount in pairs(cargos) do
        for i = 1, amount, 2 do
            Sector():dropCargo(ship.translationf, Faction(playerCraft.factionIndex), Faction(ship.factionIndex), good, ship.factionIndex, 2)
        end

        ship:removeCargo(good, amount)
    end
end

function CivilShip.worsenRelations(delta)
    delta = delta or -15000
    if delta > 0 then return end
    if not callingPlayer then return end

    local sector = Sector()
    local crafts = {sector:getEntitiesByComponent(ComponentType.Crew)}

    local factions = {}
    for _, entity in pairs(crafts) do
        -- only change relations to ai factions
        if entity.aiOwned then
            factions[entity.factionIndex] = 1
        end
    end

    local shipFaction = getInteractingFaction(callingPlayer)

    for factionIndex, _ in pairs(factions) do
        local faction = Faction(factionIndex)
        if faction then
            changeRelations(faction, shipFaction, delta, RelationChangeType.Raiding, true, true, faction)
        end
    end

    sector:invokeFunction("warzonecheck.lua", "increaseScore", 15)
end

function CivilShip.flee()
    willFlee = false

    -- don't delete player ships
    local faction = Faction()
    if faction and (faction.isPlayer or faction.isAlliance) then
        return
    end

    Entity():addScriptOnce("deletejumped.lua")
end

function CivilShip.attackPlayer()
    local player = Player(callingPlayer)

    local ai = ShipAI()
    ai:setPassiveShooting(1)
    ai:registerEnemyEntity(player.craftIndex)
end







function CivilShip.onWhereHomeSector()
    ScriptUI():showDialog(CivilShip.makeHomeSectorDialog())
end

function CivilShip.makeHomeSectorDialog()
    local entity = Entity()

    local faction = Faction(entity.factionIndex)
    if not faction then return {} end

    local x, y = faction:getHomeSectorCoordinates()

    local dialog = {}
    local name = faction.name
    if name:starts("The ") then name = name:sub(5) end

    if faction.homeSectorUnknown then
        dialog.text = "Why would I tell you that?"%_t
    else
        local passageMap = PassageMap(Seed(GameSettings().seed))
        if not passageMap:passable(x, y) then
            local answers =
            {
                "${name} Prime used to be at (${x}:${y}), before \"The Event\" that is."%_t,
                "It's such a tragedy. ${name} Prime was the pride of our faction until it was eaten up by a rift. Maybe one day there will be a way to travel to (${x}:${y}) once again."%_t,
                "I don't want to talk about it. (${x}:${y}) is no more."%_t
            }

            local i = Random(Seed(x * 318 + y * 65)):getInt(1, 3)
            dialog.text = answers[i] % {name = name, x = x, y = y}
        else
            local controllingFaction = Galaxy():getLocalFaction(x, y)
            if faction.index >= 2000000 and controllingFaction ~= faction.index then
                local controller = Faction(controllingFaction)
                if controller then
                    local x, y = controller:getHomeSectorCoordinates()
                    dialog.text = "${name} have taken over this territory. We don't have a governing home sector any more now.\n\nTheir home sector is at (${x}:${y})."%_t % {name = controller.translatedName, x = x, y = y}
                    dialog.onStart = "postHomeSector"
                else
                    dialog.text = "Ever since this other faction has taken over this territory, we don't really have a governing home sector any more.\n\nI don't know where their home sector is, sorry."%_t
                end
            else
                dialog.text = "${name} Prime is at (${x}:${y})."%_t % {name = name, x = x, y = y}
                dialog.onStart = "postHomeSector"
            end
        end
    end

    dialog.onEnd = "restart"

    return dialog
end

function CivilShip.postHomeSector()
    local faction = Faction()
    if not faction then return end

    local x, y = faction:getHomeSectorCoordinates()
    local controllingFaction = Galaxy():getLocalFaction(x, y)
    local controller = Faction(controllingFaction)
    if not controller then return end

    local x, y = controller:getHomeSectorCoordinates()

    local name = controller.name
    if name:starts("The ") then name = name:sub(5) end

    displayChatMessage("${factionName} Prime: \\s(${xCoord},${yCoord})"%_t % {factionName = name, xCoord = x, yCoord = y}, faction.name, 0)
end
