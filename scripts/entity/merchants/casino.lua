package.path = package.path .. ";data/scripts/entity/merchants/?.lua;"
package.path = package.path .. ";data/scripts/lib/?.lua;"
include ("stringutility")
local ConsumerGoods = include ("consumergoods")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Casino
Casino = include ("consumer")

Casino.consumerName = "Casino"%_t
Casino.consumerIcon = "data/textures/icons/pixel/casino.png"
Casino.consumedGoods = ConsumerGoods.Casino()

function Casino.initializationFinished()
    -- use the initilizationFinished() function on the client since in initialize() we may not be able to access Sector scripts on the client
    if onClient() then
        local ok, r = Sector():invokeFunction("radiochatter", "addSpecificLines", Entity().id.string,
        {
            "Oh no! I've lost my ship! I guess I'll have to walk home now."%_t,
            "What? Drunk? Me? Never."%_t,
            "Recreational gambling - the best in the sector!"%_t,
            "We offer over ${N3}0 different games!"%_t,
            "The first round is free!"%_t,
            "Come to our casino, we have the most modern games and you might even win!"%_t,
        })
    end
end
