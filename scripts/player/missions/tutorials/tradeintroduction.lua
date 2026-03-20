package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("utility")
include("stringutility")
include("callable")
include("structuredmission")
MissionUT = include("missionutility")

--mission.tracing = true

abandon = nil
mission.data.autoTrackMission = true
mission.data.brief = "The Rules of the Trade"%_T
mission.data.title = "The Rules of the Trade"%_T
mission.data.icon = "data/textures/icons/graduate-cap.png"
mission.data.priority = 5
mission.data.goodsBought = 0
mission.data.pricePaid = 0
mission.data.goodsSold = 0
mission.data.priceReceived = 0

mission.data.description = {}
mission.data.description[1] = "The Adventurer wants to teach you about trading."%_T
mission.data.description[2] = {text = "Read the Adventurer's mail"%_T, bulletPoint = true, fulfilled = false}
mission.data.description[3] = {text = "Make sure your ship has at least 100 cargo space"%_T, bulletPoint = true, fulfilled = false, visible = false}
mission.data.description[4] = {text = "Buy 100 Energy Cells"%_T, bulletPoint = true, fulfilled = false, visible = false}
mission.data.description[5] = {text = "(optional) Buy them for less than ¢40 per unit"%_T, bulletPoint = true, fulfilled = false, visible = false}
mission.data.description[6] = {text = "Sell the 100 Energy Cells to another station"%_T, bulletPoint = true, fulfilled = false, visible = false}
mission.data.description[7] = {text = "(optional) Sell them for more than ¢55 per unit"%_T, bulletPoint = true, fulfilled = false, visible = false}

mission.phases[1] = {}
mission.phases[1].onBeginServer = function()
    local player = Player()
    local mail = Mail()
    mail.text = Format("Hi there,\n\nI hope your recent experiences with those pirates haven't put you off traveling across the Galaxy! There are also peaceful ways that allow you to get ahead.\n\nYou should try trading!\n\nMost stations buy or sell trading goods, but not all of them have the same prices, they depend on the supply and demand in the area. You should always make sure to buy goods cheaply and then sell them somewhere else for a higher price to make a profit!\n\nTry it by buying some Energy Cells. They are a very common good and they come in handy when you want to use a Travel Hub!\n\nGreetings,\n%1%"%_T, getAdventurerName())
    mail.header = "Profit Incoming /* Mail Subject */"%_T
    mail.sender = Format("%1%, the Adventurer"%_T, getAdventurerName())
    mail.id = "Trade_Tutorial"
    player:addMail(mail)
end
mission.phases[1].playerCallbacks =
{
    {
        name = "onMailRead",
        func = function(playerIndex, mailIndex, mailId)
            if mailId == "Trade_Tutorial" then
                setPhase(2)
            end
        end
    }
}
mission.phases[1].showUpdateOnEnd = true

mission.phases[2] = {}
mission.phases[2].onBegin = function()
    mission.data.description[2].fulfilled = true
    mission.data.description[3].visible = true
end
mission.phases[2].updateClient = function()
    if not Hud().mailWindowVisible then
        Player():sendCallback("onShowEncyclopediaArticle", "Trading")
    end
end
mission.phases[2].updateServer = function()
    -- See if player has enough cargo space
    local player = Player()
    local craft = player.craft
    if not craft then return end

    if craft.freeCargoSpace and craft.freeCargoSpace > 100 then
        mission.data.description[3].fulfilled = true
        mission.data.description[4].visible = true
        mission.data.description[5].visible = true
        nextPhase()
    end
end
mission.phases[2].showUpdateOnEnd = true

mission.phases[3] = {}
mission.phases[3].updateClient = function()
    -- in case mission went to phase 3 while mail window was still open (because ship already had required cargo space), try to open encyclopedia here
    if not Hud().mailWindowVisible then
        Player():sendCallback("onShowEncyclopediaArticle", "Trading")
    end
end
mission.phases[3].updateServer = function(timestep)
    if mission.data.goodsBought >= 100 then
        mission.data.description[4].fulfilled = true
        mission.data.description[5].fulfilled = true
        mission.data.description[6].visible = true
        mission.data.description[7].visible = true
        nextPhase()
    end
end
mission.phases[3].playerCallbacks =
{
    {
        name = "onTradingManagerSellToPlayer",
        func = function(goodName, amount, price)
            if goodName == "Energy Cell" then
                mission.data.goodsBought = mission.data.goodsBought + amount
                mission.data.pricePaid = mission.data.pricePaid + price
            end
        end
    }
}
mission.phases[3].showUpdateOnEnd = true

mission.phases[4] = {}
mission.phases[4].updateServer = function(timestep)
    if mission.data.goodsSold >= 100 then
        sendReward()
        accomplish()
    end
end
mission.phases[4].playerCallbacks =
{
    {
        name = "onTradingManagerBuyFromPlayer",
        func = function(goodName, amount, price)
            if goodName == "Energy Cell" then
                mission.data.goodsSold = mission.data.goodsSold + amount
                mission.data.priceReceived = mission.data.priceReceived + price
            end
        end
    }
}

function sendReward()
    local sentenceAboutProfit = "Sadly, it seems like you didn't make much profit, but I'm sure you will get the hang of it sooner or later."%_T
    local buyPricePerUnit = mission.data.pricePaid / mission.data.goodsBought
    local sellPricePerUnit = mission.data.priceReceived / mission.data.goodsSold

    if buyPricePerUnit < 40 and sellPricePerUnit > 55 then
        sentenceAboutProfit = "You made some good profit! It seems like you've got a knack for this and you should keep it up."%_T
    elseif buyPricePerUnit < 40 then
        sentenceAboutProfit = "You bought the goods for a good price, but you could have sold them for more. The next time you trade, you should pay better attention to supply and demand."%_T
    elseif sellPricePerUnit > 55 then
        sentenceAboutProfit = "You sold the goods for a good price but you could have bought them cheaper somewhere else. The next time you trade, you should pay better attention to supply and demand."%_T
    end

    local player = Player()
    local mail = Mail()
    mail.header = "Successful Trade /* Mail Subject */"%_T
    mail.text = Format("Hi there,\n\nCongratulations, you've taken your first steps towards becoming a trader. %1% Here's a Trading Subsystem to help you find more trading opportunities. With this, unlimited wealth is just a few flights away! There are many more valuable goods than Energy Cells that will allow you to make much higher profits. If you want to improve your profit, buy and sell goods directly at factories and mines. I hope you'll remember me and this little gift when you're rich!\n\nGreetings,\n%2% /* %1% is a full sentence on how much profit the player made */"%_T, sentenceAboutProfit, getAdventurerName())
    mail.sender = Format("%1%, the Adventurer"%_T, getAdventurerName())
    mail.money = 10000

    local item = SystemUpgradeTemplate("data/scripts/systems/tradingoverview.lua", Rarity(RarityType.Rare), Seed(1))
    mail:addItem(item)

    player:addMail(mail)
    player:setValue("tutorial_trading_accomplished", true) -- set this here, so that player can't repeat mission after receiving reward
end

function getAdventurerName()
    local player = Player()
    local faction = Galaxy():getNearestFaction(player:getHomeSectorCoordinates())
    local language = faction:getLanguage()
    language.seed = Server().seed
    return language:getName()
end
