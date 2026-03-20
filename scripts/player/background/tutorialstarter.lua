
package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")
include("stringutility")
include("callable")
include("persecutorutility")
local AdventurerGuide = include("story/adventurerguide")
local SectorTurretGenerator = include("sectorturretgenerator")
local MissionUT = include("missionutility")
local RecallDeviceUT = include("recalldeviceutility")
local BuildingKnowledgeUT = include("buildingknowledgeutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace TutorialStarter
TutorialStarter = {}

if onServer() then

-- this script should never be terminate()d!
function TutorialStarter.initialize()
    local player = Player()
    player:registerCallback("onItemAdded", "onItemAdded")
    player:registerCallback("onShipChanged", "onShipChanged")
    player:registerCallback("onSectorEntered", "onSectorEntered")
    player:registerCallback("onSectorArrivalConfirmed", "onSectorArrivalConfirmed")
    player:registerCallback("onReconstructionSiteChanged", "onReconstructionSiteChanged")
    player:registerCallback("onBuildingKnowledgeUnlocked", "onBuildingKnowledgeUnlocked")

    -- immediately give tutorial missions, if there's no tutorial to play
    if not GameSettings().playTutorial and not player:getValue("met_adventurer") then
        --> add spawn adventurer - he gives tutorial missions
        TutorialStarter.addSpawnAdventurerScript()
    end

    -- register important ship callbacks in case there is a ship
    local craft = player.craft
    if valid(craft) then
        craft:registerCallback("onPlanModifiedByBuilding", "onPlanModifiedByBuilding")
        craft:registerCallback("onCaptainChanged", "onCaptainChanged")
    end

    -- give player a recall device if they qualify for it
    if not RecallDeviceUT.hasRecallDevice(player) then
        if RecallDeviceUT.qualifiesForRecallDevice(player) then
            RecallDeviceUT.sendRecallDeviceMail(player)
        end
    end
end

function TutorialStarter.getUpdateInterval()
    return 40
end

function TutorialStarter.update()
    local player = Player()

    if BuildingKnowledgeUT.qualifiesForTitaniumKnowledgeMail(player) then
        BuildingKnowledgeUT.sendTitaniumMail(player)
    end

    if BuildingKnowledgeUT.qualifiesForNaoniteKnowledgeMail(player) then
        BuildingKnowledgeUT.sendNaoniteMail(player)
    end

    if TutorialStarter.playerQualifiesForStoryStart() then
        player:addScriptOnce("data/scripts/player/background/storyquestutility.lua")
    end
end

function TutorialStarter.playerQualifiesForStoryStart()
    local player = Player()

    if not GameSettings().storyline then
        return false
    end

    if player:getValue("story_completed") then
        return false
    end

    if player:hasScript("data/scripts/player/background/storyquestutility.lua") then
        return false
    end

    if TutorialStarter.countAccomplishedTutorials() >= 2 then
        return true
    end

    return false
end

function TutorialStarter.countAccomplishedTutorials()
    local player = Player()

    local accomplishedSet = {}
    accomplishedSet["tutorial_trading_accomplished"] = player:getValue("tutorial_trading_accomplished")
    accomplishedSet["tutorial_rmining_accomplished"] = player:getValue("tutorial_rmining_accomplished")
    accomplishedSet["tutorial_torpedoes_accomplished"] = player:getValue("tutorial_torpedoes_accomplished")
    accomplishedSet["tutorial_fighters_accomplished"] = player:getValue("tutorial_fighters_accomplished")
    accomplishedSet["tutorial_boarding_accomplished"] = player:getValue("tutorial_boarding_accomplished")
    accomplishedSet["tutorial_pirateraid_accomplished"] = player:getValue("tutorial_pirateraid_accomplished")
    accomplishedSet["tutorial_strategycommands_accomplished"] = player:getValue("tutorial_strategycommands_accomplished")

    local count = 0
    for key, value in pairs(accomplishedSet) do
        if value == true then
            count = count + 1
        end
    end

    return count
end

function TutorialStarter.onItemAdded(index, amount, amountBefore)

    local player = Player()
    local item = player:getInventory():find(index)

    if not item then return end

    if item.itemType == InventoryItemType.Turret then
        -- starting R-Mining?
        if player:getValue("met_adventurer") and not player:getValue("tutorial_rmining_accomplished") then
            if item.stoneRawEfficiency > 0 then
                player:addScriptOnce("data/scripts/player/missions/tutorials/rminingtutorial.lua")
            end
        end
    elseif item.itemType == InventoryItemType.SystemUpgrade then
        -- check if recall device will be granted
        if string.match(item.script, "data/scripts/systems/teleporterkey") then
            if not RecallDeviceUT.hasRecallDevice(player) then
                deferredCallback(15, "delayedSendDeviceMail")
            end
        end
    end
end

function TutorialStarter.onReconstructionSiteChanged(index)
    local player = Player()

    -- skip the "qualifies for device" check as the player always qualifies by changing the reconstruction site
    if not RecallDeviceUT.hasRecallDevice(player) then
        deferredCallback(15, "delayedSendDeviceMail")
    end
end

function TutorialStarter.delayedSendDeviceMail()
    local player = Player()

    -- skip the "qualifies for device" check as the player always qualifies by changing the reconstruction site
    if not RecallDeviceUT.hasRecallDevice(player) then
        RecallDeviceUT.sendRecallDeviceMail(player)
    end
end

function TutorialStarter.onPlanModifiedByBuilding(objectIndex)

    local player = Player()
    if not player:getValue("met_adventurer") then return end

    local craft = player.craft
    if not craft then return end
    local plan = Plan(craft)
    if not plan then return end

    if not player:getValue("tutorial_torpedoes_accomplished") and plan:getNumBlocks(BlockType.TorpedoLauncher) > 0 then
        player:addScriptOnce("data/scripts/player/missions/tutorials/torpedoestutorial.lua")
    end

    if not player:getValue("tutorial_fighters_accomplished") and plan:getNumBlocks(BlockType.Hangar) > 0 then
        player:addScriptOnce("data/scripts/player/missions/tutorials/fightertutorial.lua")
    end

    -- trading tutorial
    if not player:getValue("tutorial_trading_accomplished") and plan:getNumBlocks(BlockType.CargoBay) > 0 then
        player:addScriptOnce("data/scripts/player/missions/tutorials/tradeintroduction.lua")
    end
end

function TutorialStarter.onShipChanged(playerIndex, craftId)
    local craft = Entity(craftId)
    if not craft then return end
    craft:registerCallback("onPlanModifiedByBuilding", "onPlanModifiedByBuilding")
    craft:registerCallback("onCaptainChanged", "onCaptainChanged")
end

function TutorialStarter.onCaptainChanged(entityId, captain)
    if not captain then return end

    local player = Player()
    if not player:getValue("tutorial_strategycommands_accomplished") then
        player:addScriptOnce("data/scripts/player/missions/tutorials/strategymodetutorial.lua")
    end
end

-- // Building Knowledge // --
function TutorialStarter.onSectorArrivalConfirmed(playerIndex, x, y)
    local player = Player()
    local knowledge = BuildingKnowledgeUT.qualifiesForBuildingKnowledgeMission(player, x, y)
    if knowledge ~= 0 then
        BuildingKnowledgeUT.addBuildingKnowledgeMission(player, knowledge)
    end
end


-- // TUTORIALS // --
function TutorialStarter.onSectorEntered(playerIndex, x, y, sectorChangeType)
    local player = Player()
    if not player:getValue("met_adventurer") then return end

    -- warn player if he is advancing too fast
    local homeX, homeY = player:getHomeSectorCoordinates()
    local craft = player.craft
    if craft and not craft.isDrone
            and not player:getValue("progression_warning_received")
            and qualifiesForPersecution(craft) then

        local countJumps = (player:getValue("progression_warning_count") or 0) + 1
        player:setValue("progression_warning_count", countJumps)

        -- reset counter if we're at home sector or too close to the home sector
        -- use distance and reduce it by 10 sectors to get the adventurer to potentially spawn *before* actual persecution happens
        local distance = math.floor(length(vec2(x, y)))
        local px, py = distance - 10, 0

        if (homeX == x and homeY == y) or not sectorPersecutable(px, py) then
            player:setValue("progression_warning_count", 0)
        elseif player:getValue("progression_warning_count") > 2 then
            if AdventurerGuide.spawnProgressionWarningAdventurer(player) then
                player:setValue("progression_warning_received", true) -- player isn't forced into taking dialog
            end
        end
    end

    if Galaxy():sectorInRift(x, y) then return end

    local otherMissionLocations = MissionUT.getMissionLocations()
    if otherMissionLocations:contains(x, y) then return end -- don't start a tutorial if there's already a mission going on

    local distance2 = ((homeX - x) * (homeX - x)) + ((homeY - y) * (homeY - y))
    local distance = math.sqrt(distance2)


    -- found station tutorial -> waits on accomplish of strategy mode tutorial
    -- reconstruction mail -> not send in home sector
    if not player:getValue("tutorial_foundstation_accomplished")
            or not player:getValue("tutorial_reconstruction_mail_received") then

        local stations = {Sector():getEntitiesByType(EntityType.Station)}
        local shipyardPresent = false
        local repairDockPresent = false
        for _, station in pairs(stations) do
            local stationFaction = Faction(station.factionIndex)
            if not stationFaction then goto continue end

            local relations = Galaxy():getFactionRelations(player, stationFaction)

            if station:hasScript("data/scripts/entity/merchants/shipyard.lua") then
                -- check relations (we don't want to start station founder tutorial if station is hostile)
                if relations > -80000 then
                    shipyardPresent = true
                end
            end

            if station:hasScript("data/scripts/entity/merchants/repairdock.lua") then
                if relations > -80000 then
                    repairDockPresent = true
                end
            end

            ::continue::
        end


        if shipyardPresent
                and not player:getValue("tutorial_foundstation_accomplished")
                and player.money >= 10 * 1000 * 1000
                and player:getValue("tutorial_strategycommands_accomplished")
                and AdventurerGuide.canSpawn() then

            player:addScriptOnce("data/scripts/player/missions/tutorials/foundstationtutorial.lua")
        end

        if repairDockPresent
                and distance >= 40
                and not player:getValue("tutorial_reconstruction_mail_received") then

            local mail = Mail()
            mail.text = Format("Hello!\n\nI see that you’re starting out on your journey. Did you know that you'll be returned to the last friendly Repair Dock you visited if you get destroyed? You can also assign a Repair Dock as your Reconstruction Site, and tow and repair ships for free there. As a bonus, you'll be able to switch there from your Galaxy Map whenever you feel like it!\n\nTo do that, you must find a Repair Dock of a faction you have good relations to, and pay them a fee. This service is definitely on the more expensive side, but once you venture into dangerous territory it can be well worth it!\n\nGreetings,\n%1%"%_T, MissionUT.getAdventurerName())
            mail.header = "Reconstruction Site Service at Repair Docks /* Mail Subject */"%_T
            mail.sender = Format("%1%, the Adventurer"%_T, MissionUT.getAdventurerName())
            mail.id = "Tutorial_Reconstruction"
            player:addMail(mail)

            player:setValue("tutorial_reconstruction_mail_received", true)
        end
    end
end

function TutorialStarter.onBuildingKnowledgeUnlocked(material)
    if material == "Titanium" then
        local player = Player()
        if not player:getValue("tutorial_pirateraid_accomplished") and not player:hasScript("pirateraidmission.lua") then
            player:addScriptOnce("data/scripts/player/missions/tutorials/pirateraidmissionstarter.lua")
        end
    end
end

function TutorialStarter.checkDistance(x, y)
    local player = Player()
    if not player.craft then return false end
    local distReach = player.craft.hyperspaceJumpReach
    local distBarrier = math.sqrt((x*x)+(y*y)) - 150

    if distBarrier < 0 then return false end
    if distReach < distBarrier then return false end
    return true
end

end

-- Tutorial helper functions
function TutorialStarter.addTutorialMission(emergency, hireCrew)
    if onClient() then invokeServerFunction("addTutorialMission", emergency, hireCrew) return end

    if not GameSettings().playTutorial then return end

    if emergency then
        Player():addScriptOnce("data/scripts/player/missions/tutorials/tutorial_emergencycall.lua")
    end

    if hireCrew then
        Player():addScriptOnce("data/scripts/player/missions/tutorials/tutorial_hirecrew.lua")
    end
end
callable(TutorialStarter, "addTutorialMission")

function TutorialStarter.addSpawnAdventurerScript()
    if onClient() then invokeServerFunction("addSpawnAdventurerScript") return end

    if not GameSettings().playTutorial then
        -- multiplayer & singeplayer without tutorial: Adventurer should spawn on first jump
        -- player will meet adventurer next - adventurer adds tutorial quests - tutorial quests add story
        Player():addScriptOnce("data/scripts/player/story/spawnadventurer.lua", 0)
    else
        -- singleplayer after tutorial: Adventurer spawns after 30 min playtime on next jump
        -- player will meet adventurer next - adventurer adds tutorial quests - tutorial quests add story
        Player():addScriptOnce("data/scripts/player/story/spawnadventurer.lua")
    end
end
callable(TutorialStarter, "addSpawnAdventurerScript")

function TutorialStarter.onTutorialAccomplished(rewardPlayer)
    if onClient() then invokeServerFunction("onTutorialAccomplished", rewardPlayer) return end

    if not GameSettings().playTutorial then return end

    local player = Player()

    -- set value so that tutorial isn't started again
    player:setValue("played_tutorial", true);

    if rewardPlayer then
        -- give player reward so that he has no draw-back from playing the tutorial
        local x, y = Sector():getCoordinates()
        local generator = SectorTurretGenerator()
        generator.coaxialAllowed = false

        local turret = generator:generate(x, y, nil, Rarity(RarityType.Uncommon), WeaponType.ChainGun, Material(MaterialType.Iron))
        local turret2 = generator:generate(x, y, nil, Rarity(RarityType.Uncommon), WeaponType.MiningLaser, Material(MaterialType.Iron))

        local upgrade = SystemUpgradeTemplate("data/scripts/systems/arbitrarytcs.lua", Rarity(RarityType.Uncommon), Seed(1))

        -- send player mail with thanks
        local mail = Mail()
        mail.text = Format("Hello!\n\nThanks again for your help with those pirates. You should explore the galaxy on your own and use your newly learned skills to improve your ship. If I were you, I'd get my hands on some Titanium, like I said before. Remember to visit colonized sectors every now and then to keep up-to-date on what’s going on in the galaxy.\n\nI’m sure we’ll meet again some time!\n\nGreetings,\n%3%"%_T, x, y, MissionUT.getAdventurerName())
        mail.header = "Thank you! /* Mail Subject */"%_T
        mail.sender = Format("%1%, the Adventurer"%_T, MissionUT.getAdventurerName())
        mail.id = "Spawn_Adventurer"
        mail:addTurret(turret)
        mail:addTurret(turret)
        mail:addTurret(turret2)
        mail:addTurret(turret2)
        mail:addItem(upgrade)
        mail:setResources(7500)
        player:addMail(mail)
    end

    -- give player money and resources on lower difficulties that they would have gotten without tutorial
    -- independent on why tutorial ends!
    local settings = GameSettings()
    if settings.startingResources == -4 then -- -4 means quick start
        player:receive(250000, 25000, 15000)
    elseif settings.startingResources == Difficulty.Beginner then
        player:receive(50000, 5000)
    elseif settings.startingResources == Difficulty.Easy then
        player:receive(40000, 2000)
    elseif settings.startingResources == Difficulty.Normal then
        player:receive(30000)
    else
        player:receive(10000)
    end
end
callable(TutorialStarter, "onTutorialAccomplished")

function TutorialStarter.setUnTransferrable(bool_in)
    if onClient() then invokeServerFunction("setUnTransferrable", bool_in) return end

    if not GameSettings().playTutorial then return end

    local craft = Player().craft
    if not craft then return end

    if not callingPlayer then return end
    if bool_in and craft.factionIndex ~= callingPlayer then return end

    craft:setValue("untransferrable", bool_in)
end
callable(TutorialStarter, "setUnTransferrable")
