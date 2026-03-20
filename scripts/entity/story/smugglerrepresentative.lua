package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("randomext")
include ("stringutility")
include ("callable")
SectorSpecifics = include ("sectorspecifics")
Balancing = include ("galaxy")

local interacted

function initialize()
    Entity().title = "Smuggler"%_t

    InteractionText().text = ""

    if onServer() then
        Sector():registerCallback("onPlayerEntered", "onPlayerEntered")
    end
end

function interactionPossible(playerIndex, option)
    return true
end

function initUI()
    ScriptUI():registerInteraction("Greetings"%_t, "onGreet")
end

function getUpdateInterval()
    return 1
end

function updateClient()
    local ship = Player().craft
    if not ship then return end

    if Player():hasScript("story/smugglerdelivery") then return end

    local self = Entity()
    local d = self:getNearestDistance(ship)

    if d < 100 and not interacted then
        interacted = true
        Player():startInteracting(self, "story/smugglerrepresentative", 0)
    end
end

function checkNoMissionCooldown()
    if onServer() then
        -- does the calling player have mission cooldown?
        local runtime = Server().unpausedRuntime
        local player = Player(callingPlayer)

        local lastKilled = player:getValue("last_killed_bottan")
        if not lastKilled or runtime - lastKilled >= 30 * 60 then
            return true
        end
    else
        -- can the local player take the mission?
        local runtime = Client().unpausedRuntime
        local player = Player()

        local lastKilled = player:getValue("last_killed_bottan")
        if not lastKilled or runtime - lastKilled >= 30 * 60 then
            return true
        end
    end
end

function onGreet()
    -- check if the player already has the mission or if he still has mission cooldown
    local player = Player()
    if player:hasScript("story/smugglerdelivery") or not checkNoMissionCooldown() then
        ScriptUI():showDialog({text = "[The ship isn't answering.]"%_t})
        return
    end

    local dialog = {}
    local good = {}
    local interested = {}
    local pity = {}

    local yes = {answer = "Yes."%_t, followUp = good}

    interested.text = "Does that mean you're interested?"%_t
    interested.answers = {
        yes,
        {answer = "On second thought, I think I'll pass."%_t, followUp = pity}
    }

    pity.text = "Pity. Would have been some good coin in it for you. Not to speak of the friends you would have made."%_t


    dialog.text = "Greetings. Interested in earning a lot of money for easy work?"%_t
    dialog.answers = {
        yes,
        {answer = "How much?"%_t, text = "About 500k to a million. Depends on how fast you are. And if you can get the job done."%_t, followUp = interested},
        {answer = "I don't want to do your dirty work."%_t, followUp = pity}
    }

    good.text = "Good. All you have to do is take this cargo and take it to the checkpoint I just sent you."%_t
    good.followUp = {text = "Should be as easy as pie."%_t, onEnd = "startMission"}

    local ship = Player().craft
    local freeSpace = ship.freeCargoSpace or 0

    if freeSpace < 1.0 then
        good.followUp = {text = "It looks like you don't have enough cargo space. Dump some of your cargo and come back then."%_t}
    end

    ScriptUI():showDialog(dialog)
end

function startMission()
    if onClient() then
        invokeServerFunction("startMission")
        return
    end

    if not checkNoMissionCooldown() then return end

    local player = Player(callingPlayer)

    local ship = player.craft
    local good = TradingGood("Goods"%_t, plural_t("Goods", "Goods", 1), "A container full of unknown goods you received from an unknown ship."%_t, "data/textures/icons/chlorine.png", 10, 1)
    good.suspicious = true
    good.tags = {mission_relevant = true}
    ship:addCargo(good, 1)

    local start = vec2(Sector():getCoordinates())
    local d = length(start)
    local dir = -normalize(start)
    local target = start + dir * 60 + vec2(random():getInt(-5, 5), random():getInt(-5, 5))

    local specs = SectorSpecifics()
    target = specs:findFreeSector(random(), math.floor(target.x), math.floor(target.y), 1, 20, Server().seed)

    -- make sure that the sector isn't inside the ring. if it is, find a random one that isn't in the ring, and increase the range with every try
    local distance = length(vec2(target.x, target.y))
    local range = 60
    while (distance <= Balancing.BlockRingMax + 1) do
        target = specs:findFreeSector(random(), math.floor(start.x), math.floor(start.y), range, range + 10, Server().seed)
        distance = length(vec2(target.x, target.y))

        range = range + 10
    end

    player:addScriptOnce("story/smugglerdelivery")
    player:invokeFunction("story/smugglerdelivery", "setLocation", target.x, target.y)

    player:sendChatMessage(Entity(), 0, "Deliver the goods to \\s(%1%:%2%)"%_t, target.x, target.y)

end
callable(nil, "startMission")

function onPlayerEntered(playerIndex)
    Galaxy():setFactionRelations(Faction(), Player(playerIndex), 0, false, false)
    Galaxy():setFactionRelationStatus(Faction(), Player(playerIndex), RelationStatus.Neutral, false, false)
end
