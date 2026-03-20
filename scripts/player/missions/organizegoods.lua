package.path = package.path .. ";data/scripts/lib/?.lua"

local Dialog = include ("dialogutility")
include ("mission")
include ("goods")
include ("randomext")
include ("relations")
include ("stringutility")
include ("callable")

-- this is the public interface for the game, for retrieving data and calling functions
function initialize(goodName, amount, stationIndex, cx, cy, reward)
    initMissionCallbacks()

    if onClient() then

        Player():registerCallback("onStartDialog", "onStartDialog")

        missionData.timeLeft = 0
        missionData.good = ""
        missionData.plural = ""
        missionData.amount = 0
        missionData.stationIndex = ""
        missionData.location = {x = 0, y = 0}
        missionData.sectorName = ""
        missionData.stationTitle = ""
        missionData.stationName = ""
        missionData.reward = 0
        missionData.fulfilled = false

        sync()

    else
        if not goodName then return end

        local g = goods[goodName]
        if not g then return end

        local station = Entity(stationIndex)

        missionData.timeLeft = 30 * 60
        missionData.good = g.name
        missionData.plural = g.plural
        missionData.amount = amount
        missionData.stationIndex = stationIndex.string
        missionData.targetIds = {stationIndex.string}
        missionData.location = {x = cx, y = cy}
        missionData.sectorName = Sector().name
        missionData.stationTitle = station.translatedTitle
        missionData.stationName = station.name
        missionData.reward = reward
        missionData.fulfilled = false
        missionData.brief = "Procure ${amount} ${plural}"%_t
        missionData.title = "Procure ${plural}"%_t
        missionData.justStarted = true
        missionData.autoTrackMission = true

    end
end

local interactedEntityIndex
function onStartDialog(entityId)
    if entityId == Uuid(missionData.stationIndex) and not missionData.fulfilled then
        interactedEntityIndex = entityId
        ScriptUI(entityId):addDialogOption("Deliver ${amount} ${plural}"%_t % missionData, "onDeliver")
    end
end

function onDeliver(craftIndex)
    if onClient() then
        ScriptUI(interactedEntityIndex):showDialog(Dialog.empty())

        invokeServerFunction("onDeliver", Player().craftIndex)
        return
    end

    if missionData.fulfilled then return end

    local station = Entity(missionData.stationIndex)
    local ship = Entity(craftIndex)
    local good = goods[missionData.good]
    good.stolen = false -- to make sure we don't count stolen goods
    local cargo = ship:getCargoAmount(good:good())
    local player = Player(callingPlayer)

    if cargo >= missionData.amount then

        if not station:isInDockingArea(ship) then
            invokeClientFunction(player, "onGoodsDelivered", 2)
            return
        end

        -- remove cargo, pay reward
        local shipFaction = Faction(ship.factionIndex)
        shipFaction:receive("Received %1% Credits for procuring goods in time."%_T, missionData.reward)
        ship:removeCargo(good:good(), missionData.amount)

        invokeClientFunction(player, "onGoodsDelivered", 0)

        -- don't terminate immediately, since this will close the dialog
        -- just set the timer to a few seconds so it will auto-terminate
        missionData.timeLeft = 5
        missionData.fulfilled = true

        -- improve relations
        local relationsChange = GetRelationChangeFromMoney(missionData.reward)
        changeRelations(shipFaction, Faction(station.factionIndex), relationsChange, RelationChangeType.GoodsTrade)
    else
        invokeClientFunction(player, "onGoodsDelivered", 1)
    end
end
callable(nil, "onDeliver")

function onGoodsDelivered(errorCode)

    local dialog = {}

    if errorCode == 0 then
        dialog.text = "Thank you. We have transferred the reward to your account."%_t
        missionData.fulfilled = true
        missionData.timeLeft = 3
    elseif errorCode == 1 then
        dialog.text = "There must have been a misunderstanding. You don't have the cargo."%_t
        dialog.followUp = {text = "Please return when you have the goods."%_t}
    elseif errorCode == 2 then
        dialog.text = "You will have to dock to deliver the goods."%_t
    end

--    ScriptUI(interactedEntityIndex):showDialog(nil)
    ScriptUI(interactedEntityIndex):showDialog(dialog)

    return 1
end


function update(timePassed)
    if missionData.timeLeft then
        missionData.timeLeft = missionData.timeLeft - timePassed
    end
end

function getUpdateInterval()
    return 1
end

function updateServer(timePassed)
    if missionData.timeLeft and missionData.timeLeft < 0 then

        if missionData.fulfilled then
            showMissionAccomplished()
        else
            showMissionFailed()
        end

        terminate()
    end
end

function getMissionDescription()

    -- if you set the title in the initialize, the title doesn't get translated into other languages
    if Entity(missionData.stationIndex) then
        local station = Entity(missionData.stationIndex)
        missionData.stationTitle = station.translatedTitle
    else
        missionData.stationTitle = "Station"%_t
    end

    missionData.timeLeftStr = plural_t("1 minute", "${i} minutes", math.floor(missionData.timeLeft / 60))

    if missionData.timeLeft < 60 then
        missionData.timeLeftStr = "< 1 minute"%_t
    end

return [[The ${stationTitle} ${stationName} in sector (${sectorName}) asked you for an urgent delivery of ${amount} ${plural}.

Upon delivering you will receive payment for the goods as well as a bonus.

Time Left: ${timeLeftStr}]]%_t % missionData

end

function onSync()
    local g = goods[missionData.good]
    if g then
        g = g:good()
        missionData.plural = g:displayName(missionData.amount)
    end
end
