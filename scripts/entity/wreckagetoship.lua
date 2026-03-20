package.path = package.path .. ";data/scripts/lib/?.lua"

include("defaultscripts")
include("faction")
include("stringutility")
include("utility")
include("callable")

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function interactionPossible(playerIndex, option)

    local player = Player(playerIndex)
    local self = Entity()

    local craft = player.craft
    if craft == nil then return false end

    local dist = craft:getNearestDistance(self)

    if dist < 20 then
        return true
    end

    return false, "You're not close enough to claim the object."%_t
end

function initialize()
    Entity():setValue("valuable_object", RarityType.Exotic)
end

-- create all required UI elements for the client side
function initUI()
    InteractionText().text = "This wreckage looks like it's still functional."%_t
    ScriptUI():registerInteraction("Repair"%_t, "onRepair", 5)
end

function onRepair()
    invokeServerFunction("repair")
end

function repair()
    -- transform into a normal ship
    if not interactionPossible(callingPlayer) then
        print ("no interaction possible")
        return
    end

    local faction, ship, player = getInteractingFaction(callingPlayer)
    if not faction then return end

    local wreckage = Entity()
    local plan = wreckage:getMovePlan()

    -- set an empty plan, this will both delete the entity and avoid collisions with the ship
    -- that we're creating at this exact position
    wreckage:setPlan(BlockPlan())

    local sector = Sector()
    local ship = sector:createShip(faction, wreckage.name, plan, wreckage.position)

    ship:setValue("valuable_object", nil)

    AddDefaultShipScripts(ship)
    SetBoardingDefenseLevel(ship)

    -- send callback that wreckage is repaired
    local player = Player(callingPlayer)
    local info = makeCallbackSenderInfo(ship)
    sector:sendCallback("onWreckageReassembled", info, player.index)
    player:sendCallback("onWreckageReassembled", info)

    terminate()
end
callable(nil, "repair")
