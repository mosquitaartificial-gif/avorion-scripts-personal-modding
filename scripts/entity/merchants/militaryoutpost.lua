
package.path = package.path .. ";data/scripts/lib/?.lua;"
package.path = package.path .. ";data/scripts/?.lua;"

local Balancing = include ("galaxy")
local Dialog = include("dialogutility")
include ("stringutility")
include ("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace MilitaryOutpost
MilitaryOutpost = {}

function MilitaryOutpost.initialize()
    if onServer() and Entity().title == "" then
        Entity().title = "Military Outpost"%_t
    end

    if onClient() and EntityIcon().icon == "" then
        EntityIcon().icon = "data/textures/icons/pixel/military.png"
        InteractionText().text = Dialog.generateStationInteractionText(Entity(), random())
    end
end

function MilitaryOutpost.initializationFinished()
    -- use the initilizationFinished() function on the client since in initialize() we may not be able to access Sector scripts on the client
    if onClient() then
        local ok, r = Sector():invokeFunction("radiochatter", "addSpecificLines", Entity().id.string,
        {
            "Detected increased Xsotan activity in nearby sectors."%_t,
            "The scouts from ${R} have returned."%_t,
            "Many good men were lost that day."%_t,
            "We're looking for the heroes of tomorrow today!"%_t,
            "We always have well-paid offers for capable mercenaries."%_t,
            "If you need cash, check our bulletin board. We always have offers for capable people."%_t,
            "Join our army! It's fun!"%_t,
        })
    end
end


function MilitaryOutpost.getUpdateInterval()
    return 1
end
