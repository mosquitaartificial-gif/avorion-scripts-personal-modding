package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("utility")
include ("stringutility")
include ("callable")
include ("galaxy")
include ("faction")
include ("randomext")
include ("structuredmission")


local MissionUT = include ("missionutility")
local AdventurerGuide = include ("story/adventurerguide")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local TorpedoGenerator = include ("torpedogenerator")

-- this mission doesn't show textual updates
mission.data.silent = true

-- disable event spawns for less confusion
mission.globalPhase = {}
mission.globalPhase.noPlayerEventsTargetSector = true
mission.globalPhase.updateServer = function()
    -- delete all resource loot so that we don't trigger encyclopedia popup during tutorial
    local sector = Sector()
    local loots = {sector:getEntitiesByType(EntityType.Loot)}
    for _, loot in pairs(loots) do
        if loot:getResourceLootAmount() ~= 0 then
            sector:deleteEntity(loot)
        end
    end
end

local timer = 0
mission.phases[1] = {}
mission.phases[1].updateServer = function(timestep)
    timer = timer + timestep
    if timer > 2 then
        nextPhase()
    end
end


mission.phases[2] = {}
mission.phases[2].onBeginServer = function()
    createPirates()
end

mission.phases[3] = {}
mission.phases[3].onBeginServer = function()
    local adventurer = Sector():getEntitiesByScript("data/scripts/entity/story/missionadventurer.lua")
    if not adventurer then print("Warning: This mission needs a mission adventurer present!") return end
    Sector():broadcastChatMessage(adventurer, ChatMessageType.Chatter, "There they are!"%_T)
    timer = 0
end
mission.phases[3].updateServer = function(timestep)
    timer = timer + timestep
    if timer > 4 then
        setPhase(4)
    end
end

local extraPiratesSpawned = 0
mission.phases[4] = {}
mission.phases[4].updateInterval = 1
mission.phases[4].updatePirateSpawning = function()
    local sector = Sector()
    local x, y = sector:getCoordinates()
    if not isHomeSector(x, y) and MissionUT.countPirates() <= 1 then
        -- we need more pirates, player is too good :D
        createPirates()
        extraPiratesSpawned = extraPiratesSpawned + 1

        if extraPiratesSpawned >= 1 then
            tryCreateTorpedoPirate()
        end

        local adventurer = sector:getEntitiesByScript("data/scripts/entity/story/missionadventurer.lua")
        if not adventurer then print("Warning: This mission needs a mission adventurer present!") return end
        sector:broadcastChatMessage(adventurer, ChatMessageType.Chatter, "Careful! More pirates!"%_T)
    end

    local playerShip = Player().craft
    if playerShip then
        if playerShip.durability / playerShip.maxDurability < 0.4 then
            tryCreateTorpedoPirate()
        end
    end
end
mission.phases[4].updateTorpedoShooting = function()
    local sector = Sector()

    -- find the pirate that should shoot the torpedo
    local shooter = sector:getEntitiesByScriptValue("tutorial_torpedo_pirate")
    if not shooter then return end

    -- only 1 torpedo at a time
    if sector:getEntitiesByType(EntityType.Torpedo) then return end

    fireTorpedoAtPlayer(shooter)
end
mission.phases[4].updateServer = function()
    mission.phases[4].updateTorpedoShooting()
    mission.phases[4].updatePirateSpawning()
end
mission.phases[4].playerEntityCallbacks = {}
mission.phases[4].playerEntityCallbacks[1] =
{
    name = "onTorpedoHit",
    func = function(objectIndex, shooterIndex, torpedoIndex)
        local playerShip = Player().craft
        if playerShip and objectIndex == playerShip.id then
            playerShip.durability = 0 -- destroy player instantly
        end
    end
}
mission.phases[4].onSectorEntered = function(x, y)
    if isHomeSector(x, y) then
        createAdventurer()
    end
end
mission.phases[4].onStartDialog = function()
    mission.data.custom.startedDialog = true
end


-- helper
function showDialog()
    if not mission.data.custom.adventurerId then print("Error: This mission needs a mission adventurer present!") return end
    local adventurer = Entity(mission.data.custom.adventurerId)
    local adventurerUI = ScriptUI(mission.data.custom.adventurerId)
    if not adventurer or not adventurerUI then print("Error: This mission needs a mission adventurer present!") return end

    adventurerUI:interactShowDialog(createDialog(), false)
    adventurer:invokeFunction("story/missionadventurer.lua", "setData", false, false, createDialog()) -- set in case player wants to repeat dialog
end

function removeTutorialShipInfo()
    if onClient() then
        invokeServerFunction("removeTutorialShipInfo")
        return
    end

    if not GameSettings().playTutorial then return end

    local player = Player(callingPlayer)
    player:removeDestroyedShipInfo(player.name .. "'s Ship")
end
callable(nil, "removeTutorialShipInfo")

function isHomeSector(x, y)
    local homeX, homeY = Player():getHomeSectorCoordinates()
    if x == homeX and y == homeY then
        return true
    end

    return false
end

function createAdventurer()
    local adventurer = AdventurerGuide.spawnOrFindMissionAdventurer(Player(), false, true)
    if not adventurer then
        setPhase(5) -- try again
        return
    end

    adventurer.invincible = true
    adventurer.dockable = false
    mission.data.custom.adventurerId = adventurer.id.string
    MissionUT.deleteOnPlayersLeft(adventurer)
    ShipAI(adventurer.id):setAggressive()
end

function createPirates()
    local dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
    local up = vec3(0, 1, 0)
    local pos = dir * 1000
    local right = normalize(cross(dir, up))

    local generator = AsyncPirateGenerator(nil, onPiratesCreated)

    generator:startBatch()
    for i = 1, 3 do
        generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos + right * i * 50))
    end
    generator:endBatch()
end

function tryCreateTorpedoPirate()

    local ship = Player().craft
    if not ship then return end

    local sector = Sector()
    local shooter = sector:getEntitiesByScriptValue("tutorial_torpedo_pirate")
    if shooter then return end

    local dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
    local up = vec3(0, 1, 0)
    local pos = ship.translationf + dir * 350

    local onCreated = function(ships)
        onPiratesCreated(ships)
        for _, pirate in pairs(ships) do
            pirate:setValue("tutorial_torpedo_pirate", true)
            MissionUT.deleteOnPlayersLeft(pirate)
            pirate.invincible = true
        end
    end

    local generator = AsyncPirateGenerator(nil, onCreated)

    generator:startBatch()
    generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos))
    generator:endBatch()
end

function onPiratesCreated(ships)
    if mission.internals.phaseIndex == 2 then
        setPhase(3)
    end

    for _, pirate in pairs(ships) do
        ShipAI(pirate.id):registerFriendFaction(mission.data.custom.adventurerId)
        pirate:removeScript("data/scripts/entity/utility/fleeondamaged.lua")
    end
end


local onDialogEnd = makeDialogServerCallback("onDialogEnd", 4, function()
    accomplish()
end)

local addIronKnowledge = makeDialogServerCallback("addIronKnowledge", 4, function()
    if not GameSettings().playTutorial then return end
    if not callingPlayer then return end

    local item = UsableInventoryItem("buildingknowledge.lua", Rarity(RarityType.Exotic), Material(MaterialType.Iron), callingPlayer)

    local player = Player(callingPlayer)
    player:getInventory():addOrDrop(item)
end)

function createDialog()
    local d0_IMSoSorry = {}
    local d1_LetMeTry = {}
    local d2_UhOh = {}
    local d3_LetMeTry = {}
    local d4_YouAreRight = {}
    local d5_Knowledge = {}
    local d6_First = {}


    d0_IMSoSorry.text = "I’m so sorry! I was desperate when I called for help.\n\nI didn’t think the one that came to my rescue was going to come in such a small ship.\n\nAre you alright?"%_t
    d0_IMSoSorry.answers = {
        {answer = "It’s your fault I lost my ship!"%_t, followUp = d1_LetMeTry},
        {answer = "I’ll be fine."%_t, followUp = d1_LetMeTry}
    }

    d1_LetMeTry.text = "But I’m sure you had a Reconstruction Kit?"%_t
    d1_LetMeTry.answers = {{answer ="What's that?"%_t, followUp = d2_UhOh}}

    d2_UhOh.text = "Oh no, that’s bad then.\n\nReconstruction Kits can be purchased at Repair Docks. They allow you to reconstruct your ship anywhere in case it gets destroyed.\n\nAs an alternative they also will tow your ship, but that's more expensive."%_t
    d2_UhOh.answers = {{answer = "So, what do I do now?"%_t, followUp = d3_LetMeTry}}

    d3_LetMeTry.text = "Let me make it up to you.\n\nSadly, I had to give all my money to those pirates so that they would let me go.\n\nSo I can't pay for them to tow your ship, but I'll think of something."%_t
    d3_LetMeTry.answers = {{answer = "Are you sure?"%_t, followUp = d4_YouAreRight}}

    d4_YouAreRight.text = "Yes, I insist, I'll get you your ship back. In the meantime, how about I tell you how to build your own ship from scratch!"%_t
    d4_YouAreRight.answers = {{answer = "How do I do that?"%_t, followUp = d5_Knowledge}}

    d5_Knowledge.text = "With this building knowledge, you can start using Iron for ship building. You'll have to read it first."%_t
    d5_Knowledge.onStart = addIronKnowledge
    d5_Knowledge.answers = {{answer = "Thanks."%_t, followUp = d6_First}}

    d6_First.text = "Then, you’re going to have to found a ship. The founding fee will be 500 iron.\n\nAfter you pay that, you will just need to think of a good name. Good luck!"%_t
    d6_First.answers = {{answer = "Thanks."%_t}}
    d6_First.onEnd = onDialogEnd

    return d0_IMSoSorry
end


local random = Random(Seed(151))
function fireTorpedoAtPlayer(shooter)
    local torpedoTemplate = generateTorpedo()

    local desc = TorpedoDescriptor()
    local torpedoAI = desc:getComponent(ComponentType.TorpedoAI)
    local torpedo = desc:getComponent(ComponentType.Torpedo)
    local velocity = desc:getComponent(ComponentType.Velocity)
    local owner = desc:getComponent(ComponentType.Owner)
    local flight = desc:getComponent(ComponentType.DirectFlightPhysics)
    local durability = desc:getComponent(ComponentType.Durability)

    -- get target
    local ships = {Sector():getEntitiesByType(EntityType.Ship)}
    local pShips = {}
    for _, p in pairs(ships) do
        if p.playerOwned then
            table.insert(pShips, p)
        end
    end

    local targetShip = randomEntry(random(), pShips)
    if not targetShip then return end

    torpedoAI.target = targetShip.id
    torpedo.intendedTargetFaction = targetShip.factionIndex

    -- set torpedo properties
    torpedoAI.driftTime = 1 -- can't be 0

    desc.position = shooter.position

    torpedo.shootingCraft = shooter.id
    torpedo.firedByAIControlledPlayerShip = false
    torpedo.collisionWithParentEnabled = false
    torpedo:setTemplate(torpedoTemplate)

    owner.factionIndex = shooter.factionIndex

    flight.drifting = true
    flight.maxVelocity = torpedoTemplate.maxVelocity
    flight.turningSpeed = torpedoTemplate.turningSpeed * 2 -- a bit more turning speed so that they hit even in close range

    velocity.velocityf = shooter.look * 10 -- "eject speed" that is then used to calculate fly speed

    durability.maximum = torpedoTemplate.durability
    durability.durability = torpedoTemplate.durability

    -- create torpedo
    Sector():createEntity(desc)
end

function generateTorpedo()
    local coords = {Sector():getCoordinates()}

    local generator = TorpedoGenerator()
    return generator:generate(coords.x, coords.y, 0, Rarity(RarityType.Exotic), random:getInt(1,10), random:getInt(1, 9))
end
