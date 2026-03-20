package.path = package.path .. ";data/scripts/lib/?.lua"


-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Adventurer1
Adventurer1 = {}

-- make the NPC talk to players
Adventurer1 = include("npcapi/singleinteraction")
include("stringutility")
include("callable")

-- the data variable is created by the singleinteraction.lua api
-- we can just add more variables and it will be saved in the database by the singleinteraction api.
local data = Adventurer1.data

data.given = {}
data.hail = false
data.closeableDialog = false
data.globalInteractionKey = "adventurer1"

function Adventurer1.getDialog()
    return Adventurer1.makeDialog()
end

function Adventurer1.makeDialog()
    local d0_HeyYou = {}
    local d1_ICould = {}
    local d2_ImOnA = {}
    local d3_Well = {}
    local d4_ImTrying = {}
    local d5_Great = {}
    local d6_HaveThis = {}

    d0_HeyYou.text = "Hello!\n\nIt's a pleasure to meet you again. Sorry again for your ship, I am still working on your compensation.\n\nAs I can see you are operating on your own instead of working for a big faction. We should work together and show them that they're not as great as they think. Will you help me?"%_t
    d0_HeyYou.answers = {{answer = "How can I help?"%_t, followUp = d1_ICould}}
    d0_HeyYou.onStart = "onMeetAdventurer"

    d1_ICould.text = "You seem like someone who just gets back up whenever they are beaten down.\n\nI was looking for someone like you, actually."%_t
    d1_ICould.answers = {{answer ="What for?"%_t, followUp = d2_ImOnA}}

    d2_ImOnA.text = "I’m on a research mission. I want to find out where the Xsotan are coming from. What do you know about the Xsotan?"%_t
    d2_ImOnA.answers = {{answer = "Not much."%_t, followUp = d3_Well}}

    d3_Well.text = "Well, you probably know that they are the scourge of the galaxy, an alien race that is attacking innocent ships and stations?"%_t
    d3_Well.answers = {{answer = "Okay."%_t, followUp = d4_ImTrying}}
    d3_Well.answers = {{answer = "Sure..."%_t, followUp = d4_ImTrying}}

    d4_ImTrying.text = "I’m trying to find out where they come from and if there is any way to stop them.\n\nOnce you’ve built yourself a good ship, would you like to help me?"%_t
    d4_ImTrying.answers = {
        {answer = "Yes!"%_t, followUp = d5_Great},
        {answer = "Uuh..."%_t, followUp = d5_Great},
    }

    d5_Great.text = "Great! You know what?\n\nI can tell you're a brand new captain. Here ..."%_t
    d5_Great.followUp = d6_HaveThis
    d5_Great.onEnd = "givePlayerGoodie"

    d6_HaveThis.text = "Have this! It's a subsystem for your ship.\n\nIt allows your scanners to scan for mass in distant sectors.\n\nIt basically finds hidden sectors for you! They'll show up as yellow blips on the Galaxy Map.\n\nMaybe you'll find something good! Just be careful, there are pirates everywhere in those off-grid sectors.\n\nWe’ll see each other once you made it further towards the center!"%_t
    d6_HaveThis.answers = {{answer = "Thank you."%_t}}

    return d0_HeyYou
end

function Adventurer1.initUI()
    ScriptUI():registerInteraction("Greet"%_t, "onGreet")
end

function Adventurer1.onGreet()
    ScriptUI():showDialog(Adventurer1.makeDialog(), false)
end

function Adventurer1.onMeetAdventurer()
    if onClient() then
        invokeServerFunction("onMeetAdventurer")
        return
    end

    Player(callingPlayer):setValue("met_adventurer", true)
end
callable(Adventurer1, "onMeetAdventurer")

function Adventurer1.givePlayerGoodie()
    if onClient() then
        invokeServerFunction("givePlayerGoodie")
        return
    end

    if data.given[callingPlayer] then return end
    data.given[callingPlayer] = true

    local player = Player(callingPlayer)
    player:getInventory():addOrDrop(SystemUpgradeTemplate("data/scripts/systems/radarbooster.lua", Rarity(1), Seed(124)))
end
callable(Adventurer1, "givePlayerGoodie")

