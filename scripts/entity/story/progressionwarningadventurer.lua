package.path = package.path .. ";data/scripts/lib/?.lua"


-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace ProgressionWarningAdventurer
ProgressionWarningAdventurer = {}

-- make the NPC talk to players
ProgressionWarningAdventurer = include("npcapi/singleinteraction")
include("stringutility")
include("callable")

-- the data variable is created by the singleinteraction.lua api
-- we can just add more variables and it will be saved in the database by the singleinteraction api.
local data = ProgressionWarningAdventurer.data

data.given = {}
data.hail = true
data.closeableDialog = false
data.globalInteractionKey = "progressionwarningadventurer"

function ProgressionWarningAdventurer.getDialog()
    return ProgressionWarningAdventurer.makeDialog()
end

function ProgressionWarningAdventurer.makeDialog()
    local d0_HeyYou = {}
    local d1_Danger = {}

    d0_HeyYou.text = "Hello!\n\nI'm surprised to see you venture this close to the center of the galaxy already."%_t
    d0_HeyYou.answers = {{answer = "Why?"%_t, followUp = d1_Danger}}

    d1_Danger.text = "Your ship is actually pretty small for this region.\n\nYou'll attract pirates and other scoundrels since you're an easy target for them.\n\nYou should turn back and build a bigger ship before venturing on."%_t
    d1_Danger.answers = {{answer ="Thank you for the warning."%_t}}
    d1_Danger.onEnd = "doneTalking"

    return d0_HeyYou
end

function ProgressionWarningAdventurer.doneTalking()
    if onClient() then invokeServerFunction("doneTalking") return end

    -- have adventurer despawn after a while
    local ship = Sector():getEntitiesByScript("data/scripts/entity/story/progressionwarningadventurer.lua")
    if ship then
        ship:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(6, 10))
    end

    terminate()
end
callable(ProgressionWarningAdventurer, "doneTalking")
