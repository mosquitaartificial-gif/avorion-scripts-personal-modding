package.path = package.path .. ";data/scripts/lib/?.lua"

include ("galaxy")
include ("stringutility")
include ("randomext")
include ("callable")
include ("relations")
local Dialog = include ("dialogutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace PlayerControl
PlayerControl = {}

local data = {}
data.controlledByIndices = {}

function PlayerControl.interactionPossible(playerIndex)
    local faction = Faction()
    local player = Player()
    if player then player = player.craftFaction end

    if player and faction then
        local relation = player:getRelation(faction.index)
        if relation.status == RelationStatus.War then return false end
        if relation.level <= -80000 then return false end

        return true
    end

    return false
end

function PlayerControl.initUI()
    ScriptUI():registerInteraction("[Scan]"%_t, "onScanSelected");
end

function PlayerControl.onScanSelected()
    local player = Player()

    for _, index in pairs(data.controlledByIndices) do
        if player.index == index then
            local traderUI = ScriptUI()
            traderUI:showDialog(Dialog.empty())
            traderUI:interactShowDialog(PlayerControl.makeNotAgainDialog(), true)
            return -- don't allow double control
        end
    end

    local traderUI = ScriptUI()
    traderUI:showDialog(Dialog.empty())
    invokeServerFunction("onScanSelectedServer", player.index)
end

function PlayerControl.onScanSelectedServer(playerIndex)
    local bribe = PlayerControl.calculateBribe()
    local player = Player(playerIndex)

    local craft = player.craft
    if not craft then
        bribe = 0
    end

    -- check player ship dps
    local trader = Entity()
    local playerStrongEnough = true
    if trader and craft.firePower < (trader.firePower * 2) then
        playerStrongEnough = false
    end

    if bribe == 0 then
        -- no hit
        broadcastInvokeClientFunction("onNoHitDialog")
    else
        -- hit
        local license = random():test(0.1)
        if license then
            invokeClientFunction(player, "onHaveLicenseDialog")
        else
            if playerStrongEnough then
                invokeClientFunction(player, "onHitDialog", bribe)
            else
                invokeClientFunction(player, "onFirePowerTooLowDialog")
            end
        end
    end
end
callable(PlayerControl, "onScanSelectedServer")

function PlayerControl.onNoHitDialog()
    local traderUI = ScriptUI()
    traderUI:showDialog(Dialog.empty())
    traderUI:interactShowDialog(PlayerControl.makeControlDialogNoHit(), true)
end

function PlayerControl.onHaveLicenseDialog()
    local traderUI = ScriptUI()
    traderUI:showDialog(Dialog.empty())
    traderUI:interactShowDialog(PlayerControl.makeHaveLicenseDialog(), true)
end

function PlayerControl.onHitDialog(bribe)
    local traderUI = ScriptUI()
    traderUI:showDialog(Dialog.empty())
    traderUI:interactShowDialog(PlayerControl.makeControlDialogHit(bribe), true)
end

function PlayerControl.onFirePowerTooLowDialog()
    local traderUI = ScriptUI()
    traderUI:showDialog(Dialog.empty())
    traderUI:interactShowDialog(PlayerControl.makeControlFirePowerTooLow(), true)
end

function PlayerControl.onControlEnd()
    if onClient() then invokeServerFunction("onControlEnd") return end

    -- recalculate bribe on server so that server decides what happens next
    local bribe = PlayerControl.calculateBribe()
    local player = Player(callingPlayer)

    local craft = player.craft
    if not craft then
        bribe = 0
    end

    -- check player ship dps
    local trader = Entity()
    local playerStrongEnough = true
    if trader and craft.firePower < (trader.firePower * 2) then
        playerStrongEnough = false
    end

    if bribe == 0 then
        -- no hit
        PlayerControl.onControlEndNoHit()
    else
        -- hit
        if playerStrongEnough then
            PlayerControl.onControlEndHit(bribe)
        else
            PlayerControl.onControlEndNoHit() -- same penalty as no hit
        end
    end

    -- send callback
    player:sendCallback("onTraderScanned", Entity().id, bribe)

    -- remember player index
    table.insert(data.controlledByIndices, player.index)
    PlayerControl.sync()
end
callable(PlayerControl, "onControlEnd")

function PlayerControl.calculateBribe()
    -- determine if ship has illegal goods and calculate bribe
    -- only testing for illegal here, as only illegal goods are added in passingships.lua
    local cargoValue = 0
    for good, amount in pairs(Entity():getCargos()) do
        if good.illegal or good.stolen then
            cargoValue = cargoValue + amount * good.price
        end
    end

    return cargoValue * 0.25
end

-- Ship has illegal cargo
function PlayerControl.makeControlDialogHit(bribe)
    local d0_dialog = {}
    local d1_bribe = {}

    d0_dialog.text = "Leave us alone! We are transporting important goods."%_t
    d0_dialog.answers = {{answer = "And what about those highly 'unsuspicious' containers?"%_t, followUp = d1_bribe}}

    d1_bribe.text = "Maybe a small favor of ${bribe} Credits would help you understand the importance of them."%_t % {bribe = createMonetaryString(bribe)}
    d1_bribe.answers = {{answer = "Ahh, very important indeed. Have a good journey and stay out of trouble."%_t}}
    d1_bribe.onEnd = "onControlEnd"

    return d0_dialog
end

function PlayerControl.onControlEndHit(bribe)

    local playerFaction = Player(callingPlayer)
    local craft = playerFaction.craft
    if craft then
        playerFaction = getInteractingFactionByShip(craft.id, callingPlayer, AlliancePrivilege.AddResources)
    end

    if playerFaction then
        playerFaction:receive("Received bribe of %1% Credits."%_T, bribe)
    end
end

-- ship has no illegal cargo
function PlayerControl.makeControlDialogNoHit()
    local d0_dialog = {}

    d0_dialog.text = "Leave us alone! We are transporting important goods."%_t
    d0_dialog.answers = {{answer = "I see. Have a good journey and stay out of trouble."%_t}}
    d0_dialog.onEnd = "onControlEnd"

    return d0_dialog
end

function PlayerControl.onControlEndNoHit()
    -- Player loses relation to the controlled faction and the dominating faction
    local playerFaction = Player(callingPlayer)
    local craft = playerFaction.craft
    if craft then
        playerFaction = getInteractingFactionByShip(craft.id, callingPlayer, AlliancePrivilege.AddResources)
    end

    local aiFaction = Entity().factionIndex
    if playerFaction and aiFaction then
        changeRelations(aiFaction, playerFaction, -2500, RelationChangeType.GeneralIllegal, true, true, aiFaction)

        local sectorControllingFaction = Galaxy():getControllingFaction(Sector():getCoordinates())
        if sectorControllingFaction and aiFaction ~= sectorControllingFaction.index then
            -- additional relation loss with residing faction
            changeRelations(sectorControllingFaction, playerFaction, -2500, RelationChangeType.GeneralIllegal, true, true, sectorControllingFaction)
        end
    end
end

function PlayerControl.makeHaveLicenseDialog()
    local d0_dialog = {}

    d0_dialog.text = "Leave us alone! We have a license for this stuff."%_t
    d0_dialog.answers = {{answer = "I see. Have a good journey and stay out of trouble."%_t}}

    return d0_dialog
end

function PlayerControl.makeControlFirePowerTooLow()
    local d0_dialog = {}
    local d1_dialog = {}

    d0_dialog.text = "You're not strong enough. Why should we allow you to do anything?"%_t
    d0_dialog.onEnd = "onControlEnd"

    return d0_dialog
end


-- double control
function PlayerControl.makeNotAgainDialog()
    local d0_dialog = {}

    d0_dialog.text = "What? You again? Nah, I'm done with you."%_t

    return d0_dialog
end

function PlayerControl.restore(data_in)
    data = data_in
end

function PlayerControl.secure()
    return data
end

function PlayerControl.sync(data_in)
    if onServer() then
        invokeClientFunction(Player(callingPlayer), "sync", data)
        return
    else
        data = data_in
    end
end
