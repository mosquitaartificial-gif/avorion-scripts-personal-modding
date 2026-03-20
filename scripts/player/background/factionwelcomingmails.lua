package.path = package.path .. ";data/scripts/lib/?.lua"

include("stringutility")
include("utility")
include("faction")
include ("randomext")


-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace FactionWelcomingMails
FactionWelcomingMails = {}

FactionWelcomingMails.delayTime = 30
local data = {sentMailByFactionIndex = {}}


if onServer() then

function FactionWelcomingMails.initialize()
    Player():registerCallback("onSectorEntered", "onSectorEntered")
end

function FactionWelcomingMails.onSectorEntered(playerIndex, x, y, sectorChangeType)
    local galaxy = Galaxy()
    local faction = galaxy:getControllingFaction(x, y)
    if not faction then return end
    if not faction.isAIFaction then return end

    -- make sure the controlling faction is a map faction
    if not galaxy:isMapFaction(faction.index) then return end

    -- make sure the mail isn't sent twice
    if data.sentMailByFactionIndex[faction.index] then return end

    -- don't send the mail for the local faction in the player's home sector
    if Player():getValue("start_ally") == faction.index then
        data.sentMailByFactionIndex[faction.index] = true
        return
    end

    for _, station in pairs({Sector():getEntitiesByType(EntityType.Station)}) do
        if station.factionIndex == faction.index then
            FactionWelcomingMails.triggerMail(faction.index)
            break
        end
    end
end

function FactionWelcomingMails.triggerMail(factionIndex)
    deferredCallback(FactionWelcomingMails.delayTime, "sendMail", factionIndex)
end

function FactionWelcomingMails.sendMail(factionIndex)
    if data.sentMailByFactionIndex[factionIndex] then return end

    local x, y = Sector():getCoordinates()
    local controllingFaction = Galaxy():getControllingFaction(x, y)
    if not controllingFaction then return end

    -- only send the mail when the player is still in that faction's territory after the delay time
    if controllingFaction.index ~= factionIndex then return end

    data.sentMailByFactionIndex[factionIndex] = true

    local mail = Mail()
    mail.text = FactionWelcomingMails.getMailText(controllingFaction)
    mail.header = FactionWelcomingMails.getMailHeader(controllingFaction)
    mail.sender = controllingFaction.unformattedName

    Player():addMail(mail)
end

function FactionWelcomingMails.getMailHeader(faction)
    local stateFormType = faction:getValue("state_form_type") or FactionStateFormType.Vanilla
    local archetype = StateFormToArchetype(stateFormType)

    local header = {}
    header[FactionArchetype.Vanilla] = "Automated Greetings /* Mail Subject */"%_T
    header[FactionArchetype.Traditional] = "Welcome to our Realm /* Mail Subject */"%_T
    header[FactionArchetype.Independent] = "Greetings, Stranger /* Mail Subject */"%_T
    header[FactionArchetype.Militaristic] = "Rules and Regulations /* Mail Subject */"%_T
    header[FactionArchetype.Religious] = "All Hail! /* Mail Subject */"%_T
    header[FactionArchetype.Corporate] = "Welcome /* Mail Subject */"%_T
    header[FactionArchetype.Alliance] = "Pleasure to Meet You /* Mail Subject */"%_T
    header[FactionArchetype.Sect] = "New Here? /* Mail Subject */"%_T

    return header[archetype]
end

function FactionWelcomingMails.getMailText(faction)
    local text = Format()

    local stateFormType = faction:getValue("state_form_type") or FactionStateFormType.Vanilla
    local archetype = StateFormToArchetype(stateFormType)

    local argumentIndex = 1

    -- add greeting
    text:add("%" .. argumentIndex .. "%", FactionWelcomingMails.getGreeting(archetype))
    argumentIndex = argumentIndex + 1

    -- add trait texts
    for trait, value in pairs(faction:getTraits()) do
        local traitText = FactionWelcomingMails.getTraitTexts(trait, value)
        if traitText then
            text:add("\n%" .. argumentIndex .. "%", traitText)
            argumentIndex = argumentIndex + 1
        end
    end

    -- add signature
    text:add("\n\n%" .. argumentIndex .. "%", FactionWelcomingMails.getValediction(archetype))
    argumentIndex = argumentIndex + 1

    return text
end

function FactionWelcomingMails.getGreeting(archetype)
    local greeting = {}
    greeting[FactionArchetype.Vanilla] = "Greetings.\n\nWelcome to our Territory."%_t
    greeting[FactionArchetype.Traditional] = "Greetings.\n\nAdmire our rich culture, with which our ancestors already achieved true greatness! Now that you are entering our domain for the first time, you can see for yourself and learn about our values."%_t
    greeting[FactionArchetype.Independent] = "Good day!\n\nInside the vastness of the galaxy we are the shining beacon of freedom and independence! We welcome you to our sectors and hope that we can be an example of a liberal society for you."%_t
    greeting[FactionArchetype.Militaristic] = "We salute you!\n\nUnited and strong, we defy all that stands in our way! Now that you are in our territory, you had better behave accordingly."%_t
    greeting[FactionArchetype.Religious] = "We send blessed greetings!\n\nMay the grace and enlightenment shine upon you. By entering our blessed realm, you too are now in a position to admire the work of enlightenment."%_t
    greeting[FactionArchetype.Corporate] = "Welcome!\n\nWe are known as an influential group in the galaxy and achieve the most profitable deals every day. By entering our domain, you accept our terms and conditions. We also ask you to abide by our policies."%_t
    greeting[FactionArchetype.Alliance] = "Greetings in the spirit of meeting and sharing.\n\nWe are convinced that you can achieve the most by working together. Therefore, we welcome you to our sectors and look forward to a good cooperation."%_t
    greeting[FactionArchetype.Sect] = "Greetings on behalf of each and every one of us!\n\nEnlightened and as one, we spread what is best for the galaxy. Now that you are in our territory, you can get an idea of what a perfect galaxy would look like."%_t

    return greeting[archetype]
end

function FactionWelcomingMails.getTraitTexts(trait, value)
    local intValue = TraitToInt(value)

    if trait == "aggressive" then
        local texts = {}
        texts[-4] = "Our diplomats are ready to open negotiations at all times. War can never be the answer."%_t
        texts[-3] = texts[-4]
        texts[-2] = "We are open to negotiations. But if these fail, we are ready to defend ourselves."%_t
        texts[-1] = texts[-2]
        -- 0 is deliberately left out
        texts[1] = "War is simply the continuation of diplomacy by other means."%_t
        texts[2] = texts[1]
        texts[3] = "Diplomacy only slows down what can be done much faster with a strong military strike."%_t
        texts[4] = texts[3]

        return texts[intValue]
    end

    if trait == "brave" then
        local texts = {}
        texts[-4] = "We are very careful. If you put yourself in danger, you have to get out of it yourself."%_t
        texts[-3] = texts[-4]
        texts[-2] = "Our people don't believe in unnecessary risk. Especially when lives are at stake."%_t
        texts[-1] = texts[-2]
        -- 0 is deliberately left out
        texts[1] = "As long as there is a chance of success, we will face any challenge with courage!"%_t
        texts[2] = texts[1]
        texts[3] = "We face every danger and take up the fight whenever necessary."%_t
        texts[4] = texts[3]

        return texts[intValue]
    end

    if trait == "greedy" then
        local texts = {}
        texts[-4] = "Our people are modest. We have renounced too great material possessions and seek our welfare elsewhere."%_t
        texts[-3] = texts[-4]
        texts[-2] = "Money and goods are not too important to us. There are more pressing matters we want to focus on."%_t
        texts[-1] = texts[-2]
        -- 0 is deliberately left out
        texts[1] = "Buy and sell with us. We will find a reasonable price for everything. But don't think you can pull a fast one on us."%_t
        texts[2] = texts[1]
        texts[3] = "We are very much looking forward to doing business with you. Everyone knows that capitalism and the market can solve all problems."%_t
        texts[4] = texts[3]

        return texts[intValue]
    end

    if trait == "honorable" then
        local texts = {}
        texts[-4] = "We seize every opportunity that comes our way. That's the only way to make it in this galaxy."%_t
        texts[-3] = texts[-4]
        texts[-2] = "It's important not to pass up any opportunities, even if it means breaking the rules sometimes."%_t
        texts[-1] = texts[-2]
        -- 0 is deliberately left out
        texts[1] = "It takes rules that everyone abides by in order to coexist. We abide by our rules and promises."%_t
        texts[2] = texts[1]
        texts[3] = "Honor and rules are what make living together in this galaxy possible. Those who violate them are no longer allowed to be part of the community!"%_t
        texts[4] = texts[3]

        return texts[intValue]
    end

    if trait == "mistrustful" then
        local texts = {}
        texts[-4] = "Everyone is welcome here and we welcome every stranger with open arms."%_t
        texts[-3] = texts[-4]
        texts[-2] = "Here we also giving strangers a chance. But we are not blind to selfish intentions."%_t
        texts[-1] = texts[-2]
        -- 0 is deliberately left out
        texts[1] = "We keep a close eye on every stranger until their intentions are absolutely clear."%_t
        texts[2] = texts[1]
        texts[3] = "We know that everyone acts only for their own benefit and therefore trust no one!"%_t
        texts[4] = texts[3]

        return texts[intValue]
    end

    if trait == "forgiving" then
        local texts = {}
        texts[-4] = "Evil creatures are known by their deeds. He who harms us is our enemy!"%_t
        texts[-3] = texts[-4]
        texts[-2] = "We believe that mistakes should be consistently atoned for. Those who make mistakes have to live with the consequences."%_t
        texts[-1] = texts[-2]
        -- 0 is deliberately left out
        texts[1] = "We forgive mistakes, but mishaps are characterized by the fact that they are rare. Frequent accidents look intentional!"%_t
        texts[2] = texts[1]
        texts[3] = "If a mistake happens, we are ready to listen to all sides before making a hasty judgment. Accidents can happen to anyone!"%_t
        texts[4] = texts[3]

        return texts[intValue]
    end
end

function FactionWelcomingMails.getValediction(archetype)
    local valediction = {}
    valediction[FactionArchetype.Vanilla] = "Sincere regards"%_t
    valediction[FactionArchetype.Traditional] = "With honorable greetings"%_t
    valediction[FactionArchetype.Independent] = "May the galaxy be free from oppression!"%_t
    valediction[FactionArchetype.Militaristic] = "Our weapons are ready!"%_t
    valediction[FactionArchetype.Religious] = "Enlightenment be with you!"%_t
    valediction[FactionArchetype.Corporate] = "Here's to a profitable business!"%_t
    valediction[FactionArchetype.Alliance] = "We will be able to learn a lot from each other!"%_t
    valediction[FactionArchetype.Sect] = "For the good of the entire galaxy!"%_t

    return valediction[archetype]
end

function FactionWelcomingMails.secure()
    -- convert so it is efficient to store
    local dataToSecure = {}
    for index, _ in pairs(data.sentMailByFactionIndex) do
        table.insert(dataToSecure, index)
    end

    return dataToSecure
end

function FactionWelcomingMails.restore(dataIn)
    data.sentMailByFactionIndex = {}
    for _, index in pairs(dataIn) do
        data.sentMailByFactionIndex[index] = true
    end
end

end
