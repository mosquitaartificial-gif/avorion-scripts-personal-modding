package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("utility")
include("stringutility")
include("callable")
include("goods")
include("structuredmission")
include("weapontype")

mission.data.brief = "Ingredients List: Turret"%_T
mission.data.description = {}
mission.data.location = {}
local startMessageShown = false

function getMission(weaponPrefix, rarity, ingredients)

    local x, y = Sector():getCoordinates()
    mission.data.location = {x = x, y = y}

    mission.data.brief = {text = "Ingredients List: ${turret} Turret"%_T, arguments = {turret = weaponPrefix}}

    mission.data.custom.ingredients = ingredients

    mission.data.description[1] = {text = "Collect the following ingredients to build a ${rarity} ${turret} Turret."%_T, arguments = {turret = weaponPrefix, rarity = tostring(rarity)}}

    Player(callingPlayer):registerCallback("onShipChanged", "onShipChanged")
    local craft = Player(callingPlayer).craft
    if not craft then return end
    craft:registerCallback("onCargoChanged", "updateDescription")

    updateDescription()
end

function onRestore(data)
    Player(callingPlayer):registerCallback("onShipChanged", "onShipChanged")
    local craft = Player(callingPlayer).craft
    if not craft then return end
    craft:registerCallback("onCargoChanged", "updateDescription")
end

function onShipChanged(playerIndex, craftId)
    local craft = Entity(craftId)
    craft:registerCallback("onCargoChanged", "updateDescription")
    updateDescription()
end

function updateDescription()

    local bulletPoint = 1
    local craft = Player(callingPlayer).craft
    if not craft then return end

    local cargos = craft:getCargos()

    for _, ingredient in pairs(mission.data.custom.ingredients or {}) do

        if ingredient.amount == 0 then
            goto continue
        end

        local have = 0
        local needed = ingredient.amount
        bulletPoint = bulletPoint + 1
        local good = goods[ingredient.name]:good()

        for good, amount in pairs(cargos) do
            if ingredient.name == good.name then
                have = amount
                break
            end
        end

        mission.data.description[bulletPoint] = {text = "${good}: ${have}/${needed}"%_T, arguments = {good = good.name, have = have, needed = needed}, bulletPoint = true, fulfilled = false}

        ::continue::
    end

    sync()
end

--needed to prevent mission to show "MISSION STARTED" on begin
function showMissionStarted(text)
    if onClient() then
        if getTrackedMissionScriptIndex() == nil then
            setTrackThisMission()
            startMessageShown = true
            return
        end

        if not startMessageShown then
            invokeServerFunction("startMessage")
        end
    end
end

function startMessage()
    if not startMessageShown then
        Player(callingPlayer):sendChatMessage("Turret Factory"%_T, ChatMessageType.Normal, "A new ingredients list was added. You can track it from your missions log."%_T)
        startMessageShown = true
    end
end
callable(nil, "startMessage")

--needed to prevent mission to show "MISSION ABANDONED" if abandoned
function showMissionAbandoned(text)
end
