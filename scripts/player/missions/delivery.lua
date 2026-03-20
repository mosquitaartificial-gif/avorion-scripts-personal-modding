package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local Dialog = include ("dialogutility")
include ("stringutility")
include ("goods")
include ("randomext")
include ("mission")
include ("utility")
include ("relations")
include ("callable")
include ("galaxy")
local SectorSpecifics = include("sectorspecifics")


-- this is the public interface for the game, for retrieving data and calling functions
function initialize(goodName, amount, giverIndex, reward)
    if giverIndex then giverIndex = Uuid(giverIndex) end

    initMissionCallbacks()

    if onClient() then

        Player():registerCallback("onStartDialog", "onStartDialog")

        missionData.timeLeft = 0
        missionData.good = ""
        missionData.displayName = ""
        missionData.amount = 0
        missionData.location = {x = 0, y = 0}
        missionData.stationIndex = ""
        missionData.giverIndex = ""
        missionData.giverName = ""
        missionData.reward = 0
        missionData.fulfilled = 0

        sync()

    else
        -- if it's not being initialized from outside, skip initialization
        -- the script will be restored via restore()
        if not goodName then return end

        -- find a location to fly to
        -- this location must have stations
        local specs = SectorSpecifics()
        local x, y = Sector():getCoordinates()
        local coords = specs.getShuffledCoordinates(random(), x, y, 1, 25)
        local serverSeed = Server().seed
        local target = nil
        local destinations = specs.getRegularStationSectors()
        local giverInsideBarrier = Balancing_InsideRing(x, y)

        for _, coord in pairs(coords) do
            local regular, offgrid, blocked, home = specs:determineContent(coord.x, coord.y, serverSeed)
            if giverInsideBarrier == Balancing_InsideRing(coord.x, coord.y) then
                if regular or home then
                    specs:initialize(coord.x, coord.y, serverSeed)

                    if destinations[specs.generationTemplate.path] then
                        target = {x=coord.x, y=coord.y}
                        break
                    end
                end
            end
        end

        if not target then
            print ("no target location found!")
            terminate()
            return
        end


        local g = goods[goodName]

        local giver = Entity(giverIndex)
        local gx, gy = Sector():getCoordinates()

        missionData.timeLeft = 20 * 60
        missionData.good = g.name
        missionData.displayName = g:good():displayName(math.floor(amount))
        missionData.amount = math.floor(amount)
        missionData.giverIndex = giverIndex.string
        missionData.giverName = Sector().name .. " " .. giver.translatedTitle
        missionData.stationIndex = ""
        missionData.factionIndex = giver.factionIndex
        missionData.giverCoordinates = {x = gx, y = gy}
        missionData.location = {x = target.x, y = target.y}
        missionData.reward = reward
        missionData.fulfilled = 0
        missionData.brief = "Deliver ${amount} ${displayName}"%_t
        missionData.title = "Delivery: ${displayName}"%_t
        missionData.justStarted = true
        missionData.autoTrackMission = true
        missionData.targetIds = {}

        Player():sendChatMessage("Client"%_T, 0, [[Please deliver the goods to \s(%1%:%2%).]]%_t, target.x, target.y)
    end
end

local interactedEntityIndex
function onStartDialog(entityId)

    if entityId == Uuid(missionData.stationIndex) and missionData.fulfilled == 0 then
        interactedEntityIndex = entityId
        ScriptUI(entityId):addDialogOption("Deliver ${amount} ${displayName}"%_t % missionData, "onDeliver")
    end
end

function onDeliver(craftIndex)

    if onClient() then
        ScriptUI(interactedEntityIndex):showDialog(Dialog.empty())

        invokeServerFunction("onDeliver", Player().craftIndex)
        return
    end

    if missionData.fulfilled == 1 then return end

    local station = Entity(missionData.stationIndex)
    local ship = Entity(craftIndex)
    local good = goods[missionData.good]
    good.stolen = false -- delivered goods need to be not stolen
    local cargo = ship:getCargoAmount(good:good())
    local player = Player(callingPlayer)

    if cargo >= missionData.amount then

        if not station:isInDockingArea(ship) then
            invokeClientFunction(player, "onGoodsDelivered", 2)
            return
        end

        -- remove cargo, pay reward
        local shipFaction = Faction(ship.factionIndex)
        shipFaction:receive("Received %1% Credits for delivering cargo."%_T, missionData.reward)
        ship:removeCargo(good:good(), missionData.amount)

        invokeClientFunction(player, "onGoodsDelivered", 0)

        -- don't terminate immediately, since this will close the dialog
        -- just set the timer to a few seconds so it will auto-terminate
        missionData.timeLeft = 5
        missionData.fulfilled = 1

        -- improve relations
        local relationsChange = GetRelationChangeFromMoney(missionData.reward)
        if player.craft then
            changeRelations(player.craft.factionIndex, Faction(station.factionIndex), relationsChange, RelationChangeType.GoodsTrade)
        else
            changeRelations(player, Faction(station.factionIndex), relationsChange, RelationChangeType.GoodsTrade)
        end
    else
        invokeClientFunction(player, "onGoodsDelivered", 1)
    end
end
callable(nil, "onDeliver")

function onGoodsDelivered(errorCode)

    local dialog = {}

    if errorCode == 0 then
        dialog.text = "Thank you. We returned your deposit and transferred the reward to your account."%_t
        missionData.fulfilled = 1
        missionData.timeLeft = 5
    elseif errorCode == 1 then
        dialog.text = "There must have been a misunderstanding, you don't have all the cargo. We need ${amount} ${good}."%_t % missionData
        dialog.followUp = {text = "Please return when you have the goods."%_t}
    elseif errorCode == 2 then
        dialog.text = "You will have to dock to deliver the goods."%_t
    end

    ScriptUI(interactedEntityIndex):showDialog(dialog)

    return 1
end


function update(timePassed)
    if missionData.timeLeft then
        local before = missionData.timeLeft
        missionData.timeLeft = missionData.timeLeft - timePassed

        if onServer() then
            if missionData.timeLeft <= 10 * 60 and before > 10 * 60 then
                local msg = "What are you doing? The client is waiting for their goods! Get them delivered!"%_t
                Player():sendChatMessage("Client"%_T, 0, msg)
            end
        end
    end
end

function getUpdateInterval()
    return 1
end

function updateServer(timePassed)

    local sector = Sector()
    local x, y = sector:getCoordinates()
    if missionData.location.x == x and missionData.location.y == y then
        local entity = sector:getEntity(missionData.stationIndex)

        if not entity and missionData.fulfilled == 0 then

            -- depending on whether we're in the target location or already returning, the mission should have the player return the cargo or fail
            if missionData.giverCoordinates.x == x and missionData.giverCoordinates.y == y then
                showMissionFailed()
                terminate()
            else
                startReturningCargo()
                Player():sendChatMessage("Client"%_T, 0, "Please return the cargo, we've updated your mission status."%_t)
            end
        end
    end

    if missionData.timeLeft < 0 then
        if missionData.fulfilled == 0 then
            local messages =
            {
                "Are you flying away with my goods? Thief! This will have consequences! You're fired!"%_t,
                "Where are you? You're late with your delivery! Someone else has delivered the goods to the client. You're fired!"%_t,
                "Great. My courier is somewhere in the galaxy and not to be found. The client was waiting for their delivery! You're fired!"%_t,
            }

            Player():sendChatMessage("Client"%_T, 0, messages[getInt(1, #messages)])
            changeRelations(Player(), Faction(missionData.factionIndex), -5000 - missionData.reward / 40.0, RelationChangeType.GeneralIllegal)

            showMissionFailed()
            terminate()
        else
            showMissionAccomplished()
            terminate()
        end
    end
end

function updateClient()
    local sector = Sector()
    local x, y = sector:getCoordinates()
    if x == missionData.location.x and y == missionData.location.y then
        if not missionData.stationTitle and missionData.stationIndex ~= "" then
            local entity = sector:getEntity(missionData.stationIndex)
            if entity then
                missionData.stationTitle = entity.translatedTitle
                missionData.stationName = entity.name

                displayChatMessage("Please deliver the cargo to the ${stationTitle} ${name}."%_t % {stationTitle = missionData.stationTitle, name = missionData.stationName}, "Client"%_t, 0)
            end
        end
    end
end

function onTargetLocationEntered(x, y)
    if missionData.stationIndex == "" then
        -- find a station
        local stations = {Sector():getEntitiesByType(EntityType.Station)}

        if #stations == 0 then
            -- no stations for some reason? -> return cargo
            startReturningCargo()
            Player():sendChatMessage("Client"%_T, 0, "It looks like the recipient has disappeared. Please return the cargo, we've updated your mission status."%_t)

            return
        else
            local station = stations[getInt(1, #stations)]

            missionData.stationIndex = station.index.string
            missionData.targetIds = {station.index.string}
        end

        sync()
    end
end

function startReturningCargo()
    missionData.stationIndex = missionData.giverIndex
    missionData.location = missionData.giverCoordinates
    missionData.targetIds = {missionData.stationIndex}
    sync()
end

function getMissionDescription()

    local timeLeft = plural_t("1 minute", "${i} minutes", math.floor(missionData.timeLeft / 60))

    if missionData.timeLeft < 60 then
        timeLeft = "< 1 minute"%_t
    end

    local client = ""
    if missionData.stationName then
        client = "The recipient is on the ${stationTitle} ${name}."%_t % {stationTitle = missionData.stationTitle, name = missionData.stationName}
    end

    local msg = "A client asked you to take care of an urgent delivery of ${amount} ${goods}.\n\n"%_t ..
        "The client expecting the goods is located at (${x}:${y}). "%_t..
        "${client}\n\n"%_t..
        "Time Left: ${time}"%_t

    local data = {client = client, amount = missionData.amount, goods = missionData.displayName, x = missionData.location.x, y = missionData.location.y, time = timeLeft}

    return msg % data
end


function onSync()
    local g = goods[missionData.good]
    if g then
        g = g:good()
        missionData.displayName = g:displayName(missionData.amount)
    end
end

function onRestore()
    if not missionData.location then
        terminate()
        return
    end
end

