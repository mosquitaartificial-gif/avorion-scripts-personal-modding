package.path = package.path .. ";data/scripts/lib/?.lua"

include ("stringutility")
include ("callable")
local ShipUtility = include ("shiputility")

interacted = false

function interactionPossible(player)
    return not interacted
end

function getUpdateInterval()
    return 0.5
end

function initialize()

    -- add all players as friends while the dialog is still going on
    if onServer() then
        local players = {Sector():getPlayers()}
        for _, player in pairs(players) do
            local ai = ShipAI()
            ai:registerFriendFaction(player.index)
            if player.allianceIndex then
                ai:registerFriendFaction(player.allianceIndex)
            end
        end
        Entity():registerCallback("onDestroyed", "onDestroyed")
    end

end

function startAttacking()
    if onClient() then
        invokeServerFunction("startAttacking")
        registerBoss(Entity().index)
        return
    end

    local players = {Sector():getPlayers()}
    for _, player in pairs(players) do
        local ai = ShipAI()
        ai:registerEnemyFaction(player.index)
        if player.allianceIndex then
            ai:registerEnemyFaction(player.allianceIndex)
        end
    end

    ShipAI():setAggressive()
end
callable(nil, "startAttacking")

function makeDialog()
    local dialog = {}
    local noScientist = {}
    local attack = {}

    dialog.text = "Ha, this time we caught you red-handed! You're the one who has been destroying and stealing our equipment!"%_t
    dialog.answers = {
        {answer = "It was an accident!"%_t, text = "How can this be an accident? You destroyed some of our most valuable research satellites!"%_t, followUp = noScientist},
        {answer = "What equipment? All I can see is junk."%_t, text = "How dare you insult our research like this!"%_t, followUp = noScientist},
        {answer = "Who are you?"%_t, text = "We are members of the M.A.D. Science Association. Our latest research of the Xsotan energy systems has been groundbreaking!"%_t, followUp = noScientist},
        {answer = "Oops?"%_t, followUp = attack},
    }

    noScientist.text = "You are clearly not capable of any true scientific enlightenment."%_t
    noScientist.followUp = attack

    attack.text = "We don't need scavenger scum like you around here. In fact, we are pretty sure that the galaxy will be better off without you."%_t
    attack.followUp = {text = "Are you looking for the true power of pure energy?! We're going to show you what the potential of true energy is like!"%_t,
    followUp = {text = "Get ready to be melted, HaHaHaHaHa!"%_t, onEnd = "startAttacking"}}

    return dialog
end

function onDestroyed()
    local players = {Sector():getPlayers()}
    for _, player in pairs(players) do
        -- reset mission cooldown
        local runtime = Server().unpausedRuntime
        player:setValue("last_killed_scientist", runtime)
    end
end

function updateClient()
    if not interacted then
        local dialog = makeDialog()
        ScriptUI():interactShowDialog(dialog, false)
        interacted = true
    end
end

function updateServer()
    if Sector().numPlayers == 0 then
        Sector():deleteEntity(Entity())
    end
end





