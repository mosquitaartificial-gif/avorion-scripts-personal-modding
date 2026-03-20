package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("utility")
include("stringutility")
include("callable")
include("structuredmission")
MissionUT = include("missionutility")
local SectorTurretGenerator = include ("sectorturretgenerator")

-- mission.tracing = true

abandon = nil
mission.data.autoTrackMission = true
mission.data.playerShipOnly = true
mission.data.brief = "Let's Board!"%_T
mission.data.title = "Let's Board!"%_T
mission.data.description =
{
    "While you can build your own ships, you can also go ahead and simply take over someone else's ship. The Adventurer has some tips for best practices."%_T,
    {text = "Obtain Boarding Shuttles"%_T, bulletPoint = true, fulfilled = false},
    "These are a special fighter type that have pressurized chambers and can transport some crew."%_t,
    {text = "Obtain Boarders"%_T, bulletPoint = true, fulfilled = false},
    "These specially trained crew members can handle any resisting crew on your target."%_t,
    {text = "(optional) Obtain a Scanner Upgrade Subsystem"%_T, bulletPoint = true, fulfilled = false},
    "Scanner upgrades boost your scanners, so that they can tell you how well defended another ship is, as well as what is in its cargo bay. While this is not necessary to board another ship, it will come in handy in selecting your next target."%_t,
}
mission.data.icon = "data/textures/icons/graduate-cap.png"
mission.data.priority = 5

mission.phases[1] = {}
mission.phases[1].onBeginServer = function()
    Player():sendCallback("onShowEncyclopediaArticle", "Boarding")
end
mission.phases[1].sectorCallbacks =
{
    {
        name = "onBoardingSuccessful",
        func = function(entityId, oldFactionIndex, newFactionIndex)
            if onClient() then return end

            local player = Player()
            if not isInCorrectShip() then return end

            if newFactionIndex == player.index then
                sendReward()
                accomplish()
            end
        end
    }
}

function sendReward()
    local player = Player()
    local mail = Mail()
    mail.header = "Let's Board: You did it! /* Mail Subject */"%_T
    mail.text = Format("Hi there,\n\nSo you actually boarded another ship? I'm happy to see that this worked for you. I guess a little something as reward is in order - see the attachements.\n\nGreetings,\n%1%"%_T, getAdventurerName())
    mail.sender = Format("%1%, the Adventurer"%_T, getAdventurerName())
    mail.money = 100000

    player:addMail(mail)
    player:setValue("tutorial_boarding_accomplished", true) -- set this here, so that player can't repeat mission after receiving reward
end

function getAdventurerName()
    local player = Player()
    local faction = Galaxy():getNearestFaction(player:getHomeSectorCoordinates())
    local language = faction:getLanguage()
    language.seed = Server().seed
    return language:getName()
end
