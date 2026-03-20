package.path = package.path .. ";data/scripts/lib/?.lua"
include("stringutility")
include("callable")
include("faction")

Dialog = include ("dialogutility")

function interactionPossible(player)
    return true
end

function initialize()
    InteractionText(Entity().index).text = "Om..."%_t
end

function initUI()
    ScriptUI():registerInteraction("What's going on here?"%_t, "talkToLeader", 5)
end

function talkToLeader()
    ScriptUI():showDialog(normalDialog(), false)
end

function normalDialog()
    local dialog =
    {
        text = "Hush! We are in the middle of our ceremony."%_t,
        answers = {
            {
                answer = "I see, sorry."%_t
            },
            {
                answer = "It'll have to wait, I'm talking to you."%_t,
                onSelect = "startFight"
            }
        }
    }
    return dialog
end

function startFight()
    local entity = Entity()
    if onClient() then
        displayChatMessage(string.format("%s is attacking!"%_t, entity.title), "", 2)
        invokeServerFunction("startFight")
        return
    end

    local shipFaction = getInteractingFaction(callingPlayer)

    if shipFaction then
        Galaxy():setFactionRelations(Faction(entity.factionIndex), shipFaction, -100000)
        Galaxy():setFactionRelationStatus(Faction(entity.factionIndex), shipFaction, RelationStatus.War)
    end

    local sector = Sector()

    for _, cultist in pairs({sector:getEntitiesByFaction(entity.factionIndex)}) do
        if cultist:hasComponent(ComponentType.ShipAI) then
            ShipAI(cultist.index):setAggressive()
        end
    end

    sector:broadcastChatMessage(entity, ChatMessageType.Chatter, "Destroy the troublemaker!"%_T)

    sector:sendCallback("onCultistsStartAttack", entity.id, shipFaction)

    terminate()
end
callable(nil, "startFight")
