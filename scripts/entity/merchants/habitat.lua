package.path = package.path .. ";data/scripts/lib/?.lua;data/scripts/entity/merchants/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua;"
include ("stringutility")
local ConsumerGoods = include ("consumergoods")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Habitat
Habitat = include ("consumer")

Habitat.consumerName = "Habitat"%_t
Habitat.consumerIcon = "data/textures/icons/pixel/habitat.png"
Habitat.consumedGoods = ConsumerGoods.Habitat()


function Habitat.initializationFinished()
    -- use the initilizationFinished() function on the client since in initialize() we may not be able to access Sector scripts on the client
    if onClient() then
        local ok, r = Sector():invokeFunction("radiochatter", "addSpecificLines", Entity().id.string,
        {
            "No private visits for block ${R} today."%_t,
            "Apartment inspections will begin shortly after the wake-up signal."%_t,
            "The bad news: In areas ${R} and ${LN2} the warm water isn't working today. The good news: cold showers wake you up and increase productivity!"%_t,
            "Today's job offers: habitat command is looking for ${N} doctors and ${N2} plumbers."%_t,
            "We're asking all residents to dry their clothes only in the designated areas."%_t,
        })
    end
end
