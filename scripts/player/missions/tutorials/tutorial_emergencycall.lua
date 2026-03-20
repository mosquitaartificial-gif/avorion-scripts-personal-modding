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

--mission.tracing = true

abandon = nil
-- mission data
mission.data.title = "Emergency Call"%_T
mission.data.brief = "Emergency Call"%_T
mission.data.icon = "data/textures/icons/graduate-cap.png"
mission.data.priority = 10

mission.data.description = {}
mission.data.description[1] = "You received an Emergency Call. Help the poor soul out."%_T
mission.data.description[2] = {text = "Add armed turrets to your ship"%_T, bulletPoint = true, fulfilled = false}
mission.data.description[3] = {text = "Go to the source of the emergency call"%_T, bulletPoint = true, fulfilled = false, visible = false}
mission.data.description[4] = {text = "Fight the pirates"%_T, bulletPoint = true, fulfilled = false, visible = false}


-- phases
-- disable event spawns for less confusion
mission.globalPhase = {}
mission.globalPhase.updateServer = function()
    local sector = Sector()
    local loots = {sector:getEntitiesByType(EntityType.Loot)}
    for _, loot in pairs(loots) do
        -- delete all resource loot so that we don't trigger encyclopedia popup during tutorial
        if loot:getResourceLootAmount() ~= 0 then
            sector:deleteEntity(loot)
        end
    end
end
mission.globalPhase.noBossEncountersTargetSector = true
mission.globalPhase.noPlayerEventsTargetSector = true
mission.globalPhase.noLocalPlayerEventsTargetSector = true

-- wait for player to equip
mission.phases[1] = {}
mission.phases[1].onBeginServer = function()
    local player = Player()
    player:sendChatMessage("Unknown"%_t, ChatMessageType.Normal, "Help! S.O.S.! We're under attack. Please .. CHRRK"%_T)
    player:sendChatMessage("", ChatMessageType.Information, "You have received a distress signal from an unknown source."%_T)

    local scripts = player:getScripts()
    for _, script in pairs(scripts) do
        if script == "data/scripts/player/missions/tutorials/tutorial_explaindestruction.lua" then
            player:removeScript("data/scripts/player/missions/tutorials/tutorial_explaindestruction.lua")
        end
    end
end
mission.phases[1].playerEntityCallbacks =
{
    {
        name = "onSystemsChanged",
        func = function(shipIndex)
            if not onServer() then return end

            local ship = Entity(shipIndex)
            for system, _ in pairs(ShipSystem(ship):getUpgrades()) do
                if system.script == "data/scripts/systems/arbitrarytcs.lua" then
                    setPhase(2)
                end
            end
        end
    }
}

mission.phases[2] = {}
mission.phases[2].onBeginServer = function()
    -- set target sector here already to avoid timing problems with tutorial reading location
    local x, y = Sector():getCoordinates()
    local coordsX, coordsY = MissionUT.getSector(x, y, 1, 2, false, false, false, false)
    mission.data.location = {x = coordsX, y = coordsY}
end
mission.phases[2].updateServer = function()
    -- check if player installs turrets
    local player = Player()
    if not player then return end
    local craft = player.craft
    if not craft then return end

    local countArmed = 0
    for _, turret in pairs({craft:getTurrets()}) do
        local weapons = Weapons(turret)

        if weapons.armed then
            countArmed = countArmed + 1
            if countArmed >= 3 then
                setPhase(3)
                return
            end
        end
    end
end

mission.phases[3] = {}
mission.phases[3].onBeginServer = function()
    mission.data.description[2].fulfilled = true
    mission.data.description[3].visible = true
end
mission.phases[3].onTargetLocationEntered = function()
    if onServer() then
        createAdventurerInPeril()
    end
end

mission.phases[4] = {}
mission.phases[4].onBeginServer = function()
    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true

    -- set adventurer attacking
    ShipAI(mission.data.custom.adventurerId):setAggressive()
end
mission.phases[4].updateServer = function()
    local player = Player()
    local ship = Player().craft
    if MissionUT.countPirates() == 0 then
        -- add follow-Up mission and accomplish
        ship.invincible = false
        nextPhase()
    else
        if ship and ship.durability <= ship.maxDurability * 0.2 then
            ship.invincible = true -- player obviously needs help, so we protect them
        end
    end
end

mission.phases[5] = {}
mission.phases[5].onBeginClient = function()
    createAndShowThanksDialog()
end


-- helper functions
function createAdventurerInPeril()
    local adventurer = AdventurerGuide.spawnOrFindMissionAdventurer(Player(), false, true)
    if not adventurer then setPhase(4) return end -- try again

    adventurer.invincible = true
    adventurer.dockable = false
    mission.data.custom.adventurerId = adventurer.id.string
    MissionUT.deleteOnPlayersLeft(adventurer)

    local generator = AsyncPirateGenerator(nil, onPiratesCreated)

    generator:startBatch()
    for i = 1, 2 do
        local dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
        local up = vec3(0, 1, 0)
        local pos = adventurer.translationf + dir * 300

        generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos))
    end
    generator:endBatch()
end

function onPiratesCreated()
    nextPhase()
end

local onDialogEnd = makeDialogServerCallback("onDialogEnd", 5, function()
    local player = Player()
    player:addScriptOnce("data/scripts/player/missions/tutorials/tutorial_explaindestruction.lua")
    accomplish()
end)

function createAndShowThanksDialog()

    local d0_Thanks = {}
    local d1_MyShip = {}
    local d2_UhOh = {}

    d0_Thanks.text = "Thank you so much for your help! You came just at the right moment!"%_t
    d0_Thanks.answers = {
        {answer = "No problem!"%_t, followUp = d1_MyShip},
        {answer = "Are you alright?"%_t, followUp = d1_MyShip}
    }

    d1_MyShip.text = "My ship is damaged, we should get out of here immediately. There might be more pirates around."%_t
    d1_MyShip.answers = {{answer ="Let's go then."%_t, followUp = d2_UhOh}}

    d2_UhOh.text = "Damn, my hyperspace engine seems to be jammed!\n\nA few kicks should do it, but my scanner shows more ships incoming.\n\nI guess, we'll have to fight first!"%_t
    d2_UhOh.answers = {{answer = "I'm ready."%_t}}
    d2_UhOh.onEnd = onDialogEnd

    local adventurer = Sector():getEntitiesByScript("data/scripts/entity/story/missionadventurer.lua")
    if not adventurer then
        invokeServerFunction("reset")
        return
    end

    local adventurerUI = ScriptUI(adventurer.id.string)
    adventurerUI:interactShowDialog(d0_Thanks, false)
end

function reset()
    if mission.internals.phaseIndex == 6 then
        mission.data.description[4].fulfilled = false
        mission.data.description[5].visible = false
        setPhase(4)
    end
end
callable(nil, "reset")
