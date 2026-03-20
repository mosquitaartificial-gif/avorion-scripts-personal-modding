package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("utility")
include ("stringutility")
include ("callable")
include ("galaxy")
include ("faction")
include("randomext")
include ("structuredmission")
MissionUT = include ("missionutility")

local AdventurerGuide = include ("story/adventurerguide")
local AsyncPirateGenerator = include("asyncpirategenerator")

-- this mission doesn't show textual updates and has no entry in player menu
mission.data.silent = true

local notSwitched = true
mission.phases[1] = {}
mission.phases[1].onBeginServer = function()
    createAdventurer()
end
mission.phases[1].updateClient = function()
    if notSwitched and Entity(mission.data.custom.adventurerId) then
        notSwitched = false
        setPhase(2)
    end
end

mission.phases[2] = {}
mission.phases[2].onBeginClient = function()
    showDialog()
end


-- helper
function showDialog()
    local adventurer = Entity(mission.data.custom.adventurerId)
    local adventurerUI = ScriptUI(mission.data.custom.adventurerId)
    if not adventurer then print("Error: This mission needs a mission adventurer present!") return end
    if not adventurerUI then print("Error: This mission needs a mission adventurer present!") return end

    adventurerUI:interactShowDialog(createDialog(), false)
    adventurer:invokeFunction("story/missionadventurer.lua", "setData", false, false, createDialog()) -- set in case player wants to repeat dialog
end

function createAdventurer()
    local adventurer = AdventurerGuide.spawnOrFindMissionAdventurer(Player(), false, true)
    if not adventurer then setPhase(1) return end -- try again
    adventurer.invincible = true
    adventurer.dockable = false
    mission.data.custom.adventurerId = adventurer.id.string
    MissionUT.deleteOnPlayersLeft(adventurer)
end


local onHireCrewExplanationEnd = makeDialogServerCallback("onHireCrewExplanationEnd", function()
    local adventurer = Entity(mission.data.custom.adventurerId)
    if adventurer then
        adventurer:addScriptOnce("data/scripts/entity/utility/delayeddelete.lua", 60)
    end

    accomplish()
end)

function createDialog()
    local d0_HiThere = {}
    local d0_Sorry = {}
    local d1_YouAreGoing = {}
    local d2_Yes = {}
    local d3_GoMineTitanium = {}
    local d4_TitaniumIsAwesome = {}

    d0_HiThere.text = "Hi there! You built yourself a new ship. Good job."%_t
    d0_HiThere.answers = {
        {answer = "It’s not as good as my old ship."%_t, followUp = d0_Sorry},
        {answer = "Yes, I’m quite proud of it."%_t, followUp = d1_YouAreGoing}
    }

    d0_Sorry.text = "I'm so sorry, I'll get you your ship back. I promise!"%_t
    d0_Sorry.followUp = d1_YouAreGoing

    d1_YouAreGoing.text = "You’re going to have to hire some crew. Most stations have unemployed crew members just waiting for somebody who wants to hire them. You should check it out."%_t
    d1_YouAreGoing.answers = {{answer ="Okay. How can I do this?"%_t, followUp = d2_Yes}}

    d2_Yes.text = "You will have to dock to the station. You can either do that manually or fly to one of the landing strips of the station and request them to pull you in with a tractor beam.\n\nThe landing strips are the straight lines of lights leading to the station."%_t
    d2_Yes.answers = {{answer = "I’ll try that."%_t, followUp = d3_GoMineTitanium}}

    d3_GoMineTitanium.text = "Oh, and one more thing.\n\nYou should be on the lookout for some Titanium asteroids. They're the ones with the different shape and white spots."%_t
    d3_GoMineTitanium.answers = {{answer = "Titanium, gotcha."%_t, followUp = d4_TitaniumIsAwesome}}

    d4_TitaniumIsAwesome.text = "Yes, it's amazing! It's light, more durable than Iron, and supports anti-matter technology so you can build energy generators out of it.\n\nI’ll be gone for now, I have some affairs of my own to take care off. But I’ll check in with you soon!"%_t
    d4_TitaniumIsAwesome.answers = {{answer = "Goodbye."%_t}}
    d4_TitaniumIsAwesome.onEnd = onHireCrewExplanationEnd

    return d0_HiThere
end
