package.path = package.path .. ";data/scripts/lib/?.lua"

include ("stringutility")
include ("callable")
include ("utility")
local Dialog = include ("dialogutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace worldbossbeacon
worldbossbeacon = {}

local data = {}

function worldbossbeacon.initialize(beacon)
    if onServer() then
        if beacon then
            Entity().title = beacon.title
            data.interactionText = beacon.interactionText
            data.args = beacon.args
        end

        Sector():registerCallback("onEntityEntered", "onEntityEntered")
        worldbossbeacon.setAsFriendEntity()
    end

    if onClient() then
        worldbossbeacon.sync()
        Player():registerCallback("onPreRenderHud", "onPreRenderHud")
    end
end

function worldbossbeacon.onEntityEntered(shipId)
    local shipAI = ShipAI(shipId)
    if shipAI then
        shipAI:registerFriendEntity(Entity().id)
    end
end

-- set beacon as friend entity, as it is at war with players
-- but we don't want autoturrets and fighters on defend to attack it
function worldbossbeacon.setAsFriendEntity()
    local selfId = Entity().id

    local ships = {Sector():getEntitiesByComponent(ComponentType.ShipAI)}
    for _, ship in pairs(ships) do
        local shipAI = ShipAI(ship)
        if shipAI then
            shipAI:registerFriendEntity(selfId)
        end
    end
end

function worldbossbeacon.interactionPossible(playerIndex, option)
    return true
end

function worldbossbeacon.initUI()
    ScriptUI():registerInteraction("[Read]"%_t, "onReadPressed", -1)
end

function worldbossbeacon.onReadPressed()
    ScriptUI():showDialog(Dialog.empty()) -- this stops dialog jump cut between interaction dialogs

    local ok, dialog = Sector():invokeFunction("data/scripts/sector/worldbosses/", "getBeaconDialog")
    if ok == 0 then
        ScriptUI():interactShowDialog(dialog, true)
    end
end

function worldbossbeacon.onPreRenderHud()
    local player = Player()
    if not player then return end

    if player.state == PlayerStateType.BuildCraft or player.state == PlayerStateType.BuildTurret or player.state == PlayerStateType.PhotoMode then return end

    if os.time() % 2 == 0 then
        local renderer = UIRenderer()
        renderer:renderEntityTargeter(Entity(), ColorRGB(1, 1, 1));
        renderer:display()
    end
end

function worldbossbeacon.onSync()
    InteractionText().text = (data.interactionText or "") % data.args
end

function worldbossbeacon.sync(data_in)
    if onServer() then
        broadcastInvokeClientFunction("sync", data)
    else
        if data_in then
            data = data_in
            worldbossbeacon.onSync()
        else
            invokeServerFunction("sync")
        end
    end
end
callable(worldbossbeacon, "sync")
