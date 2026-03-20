package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("galaxy")
include ("faction")
include ("stringutility")
include ("callable")
local SectorSpecifics = include ("sectorspecifics")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Gate
Gate = {}

local base = 0
local gateReady

local dirs =
{
    {name = "E /*direction*/"%_T,    angle = math.pi * 2 * 0 / 16},
    {name = "ENE /*direction*/"%_T,  angle = math.pi * 2 * 1 / 16},
    {name = "NE /*direction*/"%_T,   angle = math.pi * 2 * 2 / 16},
    {name = "NNE /*direction*/"%_T,  angle = math.pi * 2 * 3 / 16},
    {name = "N /*direction*/"%_T,    angle = math.pi * 2 * 4 / 16},
    {name = "NNW /*direction*/"%_T,  angle = math.pi * 2 * 5 / 16},
    {name = "NW /*direction*/"%_T,   angle = math.pi * 2 * 6 / 16},
    {name = "WNW /*direction*/"%_T,  angle = math.pi * 2 * 7 / 16},
    {name = "W /*direction*/"%_T,    angle = math.pi * 2 * 8 / 16},
    {name = "WSW /*direction*/"%_T,  angle = math.pi * 2 * 9 / 16},
    {name = "SW /*direction*/"%_T,   angle = math.pi * 2 * 10 / 16},
    {name = "SSW /*direction*/"%_T,  angle = math.pi * 2 * 11 / 16},
    {name = "S /*direction*/"%_T,    angle = math.pi * 2 * 12 / 16},
    {name = "SSE /*direction*/"%_T,  angle = math.pi * 2 * 13 / 16},
    {name = "SE /*direction*/"%_T,   angle = math.pi * 2 * 14 / 16},
    {name = "ESE /*direction*/"%_T,  angle = math.pi * 2 * 15 / 16},
    {name = "E /*direction*/"%_T,    angle = math.pi * 2 * 16 / 16}
}

function Gate.getUpdateInterval()
    return 60 * 5
end

function Gate.setGateTitle()

    local x, y = Sector():getCoordinates()
    local tx, ty = WormHole():getTargetCoordinates()

    -- find "sky" direction to name the gate
    local ownAngle = math.atan2(ty - y, tx - x) + math.pi * 2
    if ownAngle > math.pi * 2 then ownAngle = ownAngle - math.pi * 2 end
    if ownAngle < 0 then ownAngle = ownAngle + math.pi * 2 end

    local dirString = ""
    local min = 3.0
    for _, dir in pairs(dirs) do

        local d = math.abs(ownAngle - dir.angle)
        if d < min then
            min = d
            dirString = dir.name
        end
    end

    local sectorName

    local view = Galaxy():getSectorView(tx, ty)
    if view and view.name then
        sectorName = view.name
    else
        local specs = SectorSpecifics(tx, ty, GameSeed())
        sectorName = specs.name
    end

    local entity = Entity()

    entity.title = "${dir} Gate to ${sector}"%_t
    entity:setTitleArguments({dir = dirString, sector = sectorName})
end

function Gate.initialize()

    local entity = Entity()
    local wormhole = WormHole()

    local tx, ty = wormhole:getTargetCoordinates()
    local x, y = Sector():getCoordinates()

    local d = distance(vec2(x, y), vec2(tx, ty))

    local cx = (x + tx) / 2
    local cy = (y + ty) / 2

    base = math.ceil(d * 30 * Balancing_GetSectorRichnessFactor(cx, cy))

    if onServer() then
        -- get callbacks for sector readiness
        entity:registerCallback("destinationSectorReady", "updateTooltip")

        if GameSettings().dockingRestrictions then
            entity.dockable = false
        else
            entity.dockable = true
        end

        Gate.updateTooltip()

        Gate.setGateTitle()
        entity:setValue("ai_no_attack", true)
    end

    if onClient() then
        invokeServerFunction("updateTooltip")
        entity:registerCallback("onSelected", "updateTooltip")

        if EntityIcon().icon == "" then
            EntityIcon().icon = "data/textures/icons/pixel/gate.png"
        end        

        Gate.soundSource = SoundSource("ambiences/gate1", entity.translationf, 300)
        Gate.soundSource.minRadius = 15
        Gate.soundSource.maxRadius = 300
        Gate.soundSource.volume = 1.0
        Gate.soundSource:play()

    end
end

function Gate.onDelete()
    if valid(Gate.soundSource) then Gate.soundSource:terminate() end
end

function Gate.updateTooltip(ready)

    if onServer() then
        -- on the server, check if the sector is ready,
        -- then invoke client sided tooltip update with the ready variable
--        Gate.updateFaction()
        local entity = Entity()
        Gate.setGateTitle()

        local transferrer = EntityTransferrer(entity.index)

        ready = transferrer.sectorReady

        if not callingPlayer then
            broadcastInvokeClientFunction("updateTooltip", ready);
        else
            invokeClientFunction(Player(callingPlayer), "updateTooltip", ready)
        end
    else
        if type(ready) == "boolean" then
            gateReady = ready
        end

        -- on the client, calculate the fee and update the tooltip
        local user = Player()
        local ship = Sector():getEntity(user.craftIndex)

        -- during login/loading screen it's possible that the player still has to be placed in his drone, so ship is nil
        if not ship then return end

        local shipFaction = Faction(ship.factionIndex)
        if shipFaction then
            user = shipFaction
        end

        local fee = math.ceil(base * Gate.factor(Faction(), user))
        local tooltip = EntityTooltip(Entity().index)
        tooltip:setDisplayTooltip(0, "Fee"%_t, "¢${fee}"%_t % {fee = tostring(fee)})

        if not gateReady or Hud().tutorialActive then -- always show not ready if tutorial is active, as player can't travel via gate
            tooltip:setDisplayTooltip(1, "Status"%_t, "Not Ready"%_t)
        else
            tooltip:setDisplayTooltip(1, "Status"%_t, "Ready"%_t)
        end
    end
end
callable(Gate, "updateTooltip")

function Gate.updateFaction()

    if onServer() then
        local wormhole = WormHole()
        local tx, ty = wormhole:getTargetCoordinates()
        local targetFaction = Galaxy():getControllingFaction(tx, ty)

        if targetFaction then
            Entity().factionIndex = targetFaction.index
            Gate.updateTooltip()
        end
    end
end

function Gate.updateServer()
    Gate.updateFaction()
end

function Gate.factor(providingFaction, orderingFaction)

    if not providingFaction or not orderingFaction then return 0 end
    if orderingFaction.index == providingFaction.index then return 0 end

    local relation = 0

    relation = providingFaction:getRelations(orderingFaction.index)

    local factor = relation / 100000 -- -1 to 1

    factor = factor + 1.0 -- 0 to 2
    factor = 2.0 - factor -- 2 to 0

    -- pay extra if relations are not good
    if relation < 0 then
        factor = factor * 1.5
    end

    return factor
end

function Gate.canTransfer(index)

    local sector = Sector()
    local ship = sector:getEntity(index)
    local faction = Faction(ship.factionIndex)
    local x, y = sector:getCoordinates()

    -- unowned objects and AI factions can always pass
    if not faction or faction.isAIFaction then
        return 1
    end

    -- when a craft has no pilot then the owner faction must pay
    local pilotIndex = ship:getPilotIndices()
    local buyer, player
    if pilotIndex then
        buyer, _, player = getInteractingFaction(pilotIndex, AlliancePrivilege.SpendResources)

        if not buyer then return 0 end
    else
        buyer = faction
        if faction.isPlayer then
            player = Player(faction.index)
        end
    end


    local fee = math.ceil(base * Gate.factor(buyer, Faction()))
    local canPay, msg, args = buyer:canPay(fee)

    if not canPay then
        if player then
            if player.isPlayer then
                msgRed = "<Gate Control \\s(%1%:%2%)> You need %3% more Credits to pay passage fee."%_T
            else
                msgRed = "<Gate Control \\s(%1%:%2%)> Your alliance needs %3% more Credits to pay passage fee."%_T
            end

            player:sendChatMessage("Gate Control"%_t, ChatMessageType.Error, msgRed, x, y, unpack(args))
        end

        return 0
    end

    if player and ship.name then
        player:sendChatMessage("Gate Control"%_t, 3, "You paid %1% Credits: passage fee for the ship '%2%'."%_t, fee, ship.name)
        buyer:pay(Format("Paid %2% Credits: gate passage fee for the ship '%1%'."%_T, (ship.name or "")), fee)
    else
        buyer:pay("Paid %1% Credits: gate passage fee"%_T, fee)
    end

    return 1
end
