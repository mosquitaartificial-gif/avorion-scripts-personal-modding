package.path = package.path .. ";data/scripts/entity/merchants/?.lua;"
package.path = package.path .. ";data/scripts/lib/?.lua;"
include ("stringutility")
local ConsumerGoods = include ("consumergoods")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Biotope
Biotope = include ("consumer")

Biotope.consumerName = "Biotope"%_t
Biotope.consumerIcon = "data/textures/icons/pixel/biotope.png"
Biotope.consumedGoods = ConsumerGoods.Biotope()

function Biotope.initializationFinished()
    -- use the initilizationFinished() function on the client since in initialize() we may not be able to access Sector scripts on the client
    if onClient() then

        local lines = {
            "Our restaurants are open all the time for you."%_t,
            "Visit our parks. Only the best weather thanks to our latest software."%_t,
            "When have you last seen animals outside of a cage?"%_t,
            "Visit the biotope and get a home-picked apple! Included in the ticket price."%_t,
            "Visit us and get a home-picked apple."%_t,
            "We got all new squatels and kliefs! During a visit to the zoo you can have a look at them."%_t,
        }

        if getLanguage() == "en" then
            -- these don't have translation markers on purpose
            table.insert(lines, "Okay, who left the alpaca pen open all night? That's the second time this week.")
        end

        local ok, r = Sector():invokeFunction("radiochatter", "addSpecificLines", Entity().id.string, lines)
    end
end
