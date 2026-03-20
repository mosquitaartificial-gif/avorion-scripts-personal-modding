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
mission.data.brief = "R-Mining Job"%_T
mission.data.title = "R-Mining Job"%_T
mission.data.icon = "data/textures/icons/graduate-cap.png"
mission.data.priority = 5
mission.data.description =
{
    "The Adventurer wants you to test out your new R-Mining Lasers."%_T,
    {text = "Install R-Mining Lasers"%_T, bulletPoint = true, fulfilled = false}
}

mission.data.custom.goNextOne = true
mission.data.custom.goNextTwo = true
mission.data.custom.goNextThree = true

mission.phases[1] = {}
mission.phases[1].onBeginServer = function()
    local player = Player()
    local mail = Mail()
    mail.text = Format("Hi there,\n\nI've heard that you found an R-Mining Laser! R-Mining Lasers are fantastic. They're somewhat old-school style mining: You mine the ores from asteroids and have the refining done at stations. That's way more efficient than having the Mining Laser do it.\n\nCheck it out yourself - install your new R-Mining Laser on the ship and follow the list of steps that I'll send to you. If you learn to use them properly, I'll see what else I can do for you.\n\nGreetings,\n%1%"%_T, getAdventurerName())
    mail.header = "R-Mining Lasers Instructions /* Mail Subject */"%_T
    mail.sender = Format("%1%, the Adventurer"%_T, getAdventurerName())
    player:addMail(mail)
end

mission.phases[1].updateServer = function()
    -- check if player installs the R-Turret
    -- update Description if so

    local player = Player()
    if not player then return end
    local craft = player.craft
    if not craft then return end

    for _, turret in pairs({craft:getTurrets()}) do
        local weapons = Weapons(turret)

        if weapons.stoneRawEfficiency > 0 then
            mission.data.description[2].fulfilled = true
            mission.data.description[3] = {text = "Add 250 or more cargo space to your ship"%_T, bulletPoint = true, fulfilled = false}
            if mission.data.custom.goNextOne then nextPhase() end
            mission.data.custom.goNextOne = false

            Player():sendCallback("onShowEncyclopediaArticle", "RMining")
        end
    end
end
mission.phases[1].showUpdateOnEnd = true

mission.phases[2] = {}
mission.phases[2].updateServer = function()
    -- See if player has enough cargo space
    -- if yes -> send player off to collect ore
    local player = Player()
    local craft = player.craft
    if not craft then return end

    if craft.freeCargoSpace and craft.freeCargoSpace > 250 then
        mission.data.description[3].fulfilled = true
        mission.data.description[4] = {text = "Collect 7500 Titanium Ore"%_T, bulletPoint = true, fulfilled = false}
        if mission.data.custom.goNextTwo then nextPhase() end
        mission.data.custom.goNextTwo = false
    end
end
mission.phases[2].showUpdateOnEnd = true

mission.phases[3] = {}
mission.phases[3].updateServer = function()
    -- See if player has enough ore in cargo
    -- if yes -> send player to refine
    local player = Player()
    local craft = player.craft
    if not craft then return end

    local cargos = craft:findCargos("Titanium Ore")
    if not cargos then return end

    for _, cargo in pairs(cargos) do
        if cargo > 7500 then
            mission.data.description[4].fulfilled = true
            mission.data.description[5] = {text = "Refine Ores at a Resource Depot"%_T, bulletPoint = true, fulfilled = false}
            if mission.data.custom.goNextThree then nextPhase() end
            mission.data.custom.goNextThree = false
        end
    end
end
mission.phases[3].showUpdateOnEnd = true

mission.phases[4] = {}
mission.phases[4].playerCallbacks = {}
mission.phases[4].playerCallbacks[1] =
{
    name = "onRefineryResourcesTaken",
    func = function(senderInfo, craftID, materials) onRefineryResourcesTaken(senderInfo, craftID, materials) end
}

function sendReward()
    local player = Player()
    local mail = Mail()
    mail.header = "R-Mining Job: Well done! /* Mail Subject */"%_T

    mail.text = Format("Hi there,\n\nAs I can see, everything worked very fine, indeed. I'm happy to see that you learned so quickly how to use R-Mining Lasers. Let me give you two of mine, to help on your journey. Some day we'll travel over the Barrier.\n\nGreetings,\n%1%"%_T, getAdventurerName())
    mail.sender = Format("%1%, the Adventurer"%_T, getAdventurerName())

    local x, y = Sector():getCoordinates()
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false
    local turret = generator:generate(x, y, 0, Rarity(RarityType.Rare), WeaponType.RawMiningLaser, Material(MaterialType.Titanium))

    mail:addTurret(turret)
    mail:addTurret(turret)
    player:addMail(mail)
    player:setValue("tutorial_rmining_accomplished", true) -- set this here, so that player can't repeat mission after receiving reward
end

function onRefineryResourcesTaken(senderInfo, craftID, materials)
    if not materials then return end
    if materials[2] > 5000 then
        sendReward()
        accomplish()
    end
end

function getAdventurerName()
    local player = Player()
    local faction = Galaxy():getNearestFaction(player:getHomeSectorCoordinates())
    local language = faction:getLanguage()
    language.seed = Server().seed
    return language:getName()
end
