package.path = package.path .. ";data/scripts/lib/?.lua"

local Galaxy = include("galaxy")
local CommandType = include("data/scripts/player/background/simulation/commandtype")
include("stringutility")
include("utility")
include("callable")


-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace PlayerProfile
PlayerProfile = {}
local self = PlayerProfile

self.data = {}
self.data.unlocked = {}


local selectionKeys = {}
local connectionKeys = {}

local selection

local milestoneSize = 60


local itemCollected

if onClient() then

function PlayerProfile.initialize()
    local playerWindow = PlayerWindow()
    self.tab = playerWindow:createTab("Player Profile"%_t, "data/textures/icons/player.png", "Player Profile"%_t)
    playerWindow:moveTabToPosition(self.tab, 0)
    playerWindow:selectTab(0)

    self.tab:createFrame(Rect(self.tab.size))

    selection = self.tab:createSelection(Rect(self.tab.size), 1)
    selection.entriesHighlightable = false
    selection.entriesSelectable = false
    selection.showScrollBar = true
    selection:setShowScrollArrows(true, true, 1.5)
    selection:setFieldSize(40)

    local milestones = PlayerProfile.getMilestones()

    local rects = {}
    local i = 0

    for name, milestone in pairs(milestones) do
        local key = ivec2(0, i); i = i + 1;
        rects[key] = Rect(milestone.position, milestone.position + milestoneSize)

        selectionKeys[name] = key
    end

    -- do connections last so the milestone tooltips aren't covered by them
    for name, milestone in pairs(milestones) do
        for _, connection in pairs(milestone.connections or {}) do
            local key = ivec2(0, i); i = i + 1;
            rects[key] = Rect(connection.lower, connection.upper)

            connectionKeys[connection.id] = key
        end
    end

    selection:setCustomRects(rects)

    PlayerProfile.sync()
end

function PlayerProfile.refresh()
    local milestones = PlayerProfile.getMilestones()
    local inserted = {}

    selection:clear()

    for name, milestone in pairs(milestones) do

        if self.data.unlocked[name] then
            local item = SelectionItem()
            item.texture = milestone.icon
            item.borderColor = Color(milestone.color)
            item.backgroundColor = Color(milestone.color)
            item.borderGlow = true
            item.tooltip = milestone.tooltip

            selection:add(item, selectionKeys[name])
            inserted[name] = true

            -- add all locked successors
            for _, successor in pairs(milestone.successors or {}) do
                if not self.data.unlocked[successor] then
                    if not milestones[successor].alwaysVisible and not inserted[successor] then
                        local milestone = milestones[successor]
                        local item = SelectionItem()
                        item.texture = milestone.lockedIcon or ""
                        item.tooltip = milestone.tooltip

                        selection:add(item, selectionKeys[successor])
                        inserted[successor] = true
                    end
                end
            end

            -- add all connections originating from this milestone
            for _, connection in pairs(milestone.connections or {}) do
                local item = SelectionItem()
                item.texture = connection.texture or ""
                item.backdrop = false
                selection:add(item, connectionKeys[connection.id])
            end

        elseif milestone.alwaysVisible then
            if milestone.masked then
                local item = SelectionItem()
                item.texture = "data/textures/icons/milestones/question-mark-locked.png"

                selection:add(item, selectionKeys[name])
                inserted[name] = true
            else
                local item = SelectionItem()
                item.texture = milestone.lockedIcon or ""
                item.tooltip = milestone.tooltip

                selection:add(item, selectionKeys[name])
                inserted[name] = true
            end

            -- add all connections originating from this milestone, but as "locked" variant
            for _, connection in pairs(milestone.connections or {}) do
                local item = SelectionItem()
                item.texture = connection.lockedTexture
                item.backdrop = false
                selection:add(item, connectionKeys[connection.id])
            end
        end

    end

    -- show
    for name, milestone in pairs(milestones) do
        if not inserted[name] then
            selection:addEmpty(selectionKeys[name])
        end
    end

end

function PlayerProfile.notifyUnlock(id)
    local milestones = PlayerProfile.getMilestones()
    local milestone = milestones[id]

    if milestone then
        Hud():displayNotification("Milestone Unlocked: ${description}"%_t % {description = milestone.tooltip}, milestone.color, milestone.icon, milestone.color, false, 80, 0.01)
        playSound("interface/milestone-unlocked", SoundType.UI, 0.5)
    end
end

end

if onServer() then

function PlayerProfile.getUpdateInterval(timeStep)
    return 1
end

function PlayerProfile.initialize()
    local player = Player()

    player:registerCallback("onSectorArrivalConfirmed", "onSectorArrivalConfirmed")
    player:registerCallback("onCraftChanged", "onCraftChanged")
    player:registerCallback("onAsteroidClaimed", "onAsteroidClaimed")
    player:registerCallback("onMineFounded", "onMineFounded")
    player:registerCallback("onItemResearched", "onItemResearched")
    player:registerCallback("onBackgroundCommandStarted", "onBackgroundCommandStarted")
    player:registerCallback("onRefineryResourcesTaken", "onRefineryResourcesTaken")
    player:registerCallback("onRelationStatusChanged", "onRelationStatusChanged")
    player:registerCallback("onStashOpened", "onStashOpened")
    player:registerCallback("onEncyclopediaRepairDockRead", "onEncyclopediaRepairDockRead")
    player:registerCallback("onWreckageReassembled", "onWreckageReassembled")
    player:registerCallback("onItemAdded", "onItemAdded")
    player:registerCallback("onReconstructionKitUsed", "onReconstructionKitUsed")
    player:registerCallback("onIzzyMet", "onIzzyMet")
    player:registerCallback("onAsteroidShieldBossDestroyed", "onAsteroidShieldBossDestroyed")
    player:registerCallback("onLaserBossDestroyed", "onLaserBossDestroyed")
    player:registerCallback("onBigAIDestroyed", "onBigAIDestroyed")
    player:registerCallback("onCorruptedAIDestroyed", "onCorruptedAIDestroyed")
    player:registerCallback("onJumperBossDestroyed", "onJumperBossDestroyed")
    player:registerCallback("onXsotanSwarmDefeated", "onXsotanSwarmDefeated")
    player:registerCallback("onContainerCracked", "onContainerCracked")
    player:registerCallback("onStickOfDoomDestroyed", "onStickOfDoomDestroyed")

    local sector = Sector()
    sector:registerCallback("onWaveEncounterFinished", "onWaveEncounterFinished")
    sector:registerCallback("onBoardingSuccessful", "onBoardingSuccessful")

end

function PlayerProfile.unlock(milestoneId)
    local before = self.data.unlocked[milestoneId]
    self.data.unlocked[milestoneId] = true

    if not before then

        local milestones = PlayerProfile.getMilestones()
        local milestone = milestones[milestoneId]
        if milestone then
            -- print("Unlocked milestone: %s", milestoneId)
            local player = Player()
            if Server():isOnline(player.index) then
                invokeClientFunction(player, "notifyUnlock", milestoneId)
            end
        else
            eprint("Tried to unlock milestone '%s' which doesn't exist", milestoneId)
        end

        PlayerProfile.sync()
    end
end

function PlayerProfile.resetMilestones() -- for testing and debugging
    self.data.unlocked = {}
    PlayerProfile.sync()
end

function PlayerProfile.unlockAllMilestones() -- for testing and debugging
    local milestones = PlayerProfile.getMilestones()
    for name, milestone in pairs(milestones) do

        self.data.unlocked[name] = true
    end

    printTable(self.data.unlocked)

    PlayerProfile.sync()
end

function PlayerProfile.isUnlocked(milestoneId)
    return self.data.unlocked[milestoneId]
end

function PlayerProfile.update(timeStep)
    local player = Player()
    local unlocked = self.data.unlocked

    local maxBuildable = player.maxBuildableMaterial
    if maxBuildable >= Material(MaterialType.Iron) then PlayerProfile.unlock("IronKnowledge") end
    if maxBuildable >= Material(MaterialType.Titanium) then PlayerProfile.unlock("TitaniumKnowledge") end
    if maxBuildable >= Material(MaterialType.Naonite) then PlayerProfile.unlock("NaoniteKnowledge") end
    if maxBuildable >= Material(MaterialType.Trinium) then PlayerProfile.unlock("TriniumKnowledge") end
    if maxBuildable >= Material(MaterialType.Xanion) then PlayerProfile.unlock("XanionKnowledge") end
    if maxBuildable >= Material(MaterialType.Ogonite) then PlayerProfile.unlock("OgoniteKnowledge") end
    if maxBuildable >= Material(MaterialType.Avorion) then PlayerProfile.unlock("AvorionKnowledge") end

    local materials = {player:getResources()}
    if materials[1] > 0 then PlayerProfile.unlock("IronCollected") end
    if materials[2] > 0 then PlayerProfile.unlock("TitaniumCollected") end
    if materials[3] > 0 then PlayerProfile.unlock("NaoniteCollected") end
    if materials[4] > 0 then PlayerProfile.unlock("TriniumCollected") end
    if materials[5] > 0 then PlayerProfile.unlock("XanionCollected") end
    if materials[6] > 0 then PlayerProfile.unlock("OgoniteCollected") end
    if materials[7] > 0 then PlayerProfile.unlock("AvorionCollected") end

    local craft = player.craft
    if craft and craft.type == EntityType.Ship then
        local sockets = ShipSystem(craft).numSockets

        if sockets >= 5 then PlayerProfile.unlock("BuildTitaniumSlotShip") end
        if sockets >= 6 then PlayerProfile.unlock("BuildNaoniteSlotShip") end
        if sockets >= 8 then PlayerProfile.unlock("BuildTriniumSlotShip") end
        if sockets >= 10 then PlayerProfile.unlock("BuildXanionSlotShip") end
        if sockets >= 12 then PlayerProfile.unlock("BuildOgoniteSlotShip") end
        if sockets >= 15 then PlayerProfile.unlock("BuildAvorionSlotShip") end

        if craft.maxCargoSpace > 0 then PlayerProfile.unlock("BuildCargoBay") end

        if not unlocked["BuildHangar"] then
            local hangar = Hangar(craft)
            if hangar and hangar.space > 0 then PlayerProfile.unlock("BuildHangar") end
        elseif not unlocked["TwoFullFighterSquads"] then

            local hangar = Hangar(craft)
            if hangar then
                local full = 0
                for i = 0, 9 do
                    if hangar:getSquadFighters(i) >= 12 then
                        full = full + 1
                    end
                end

                if full >= 2 then
                    PlayerProfile.unlock("TwoFullFighterSquads")
                end
            end
        end

        if not unlocked["BuildRMiningLaser"] then
            local turrets = {craft:getTurrets()}
            for _, turret in pairs(turrets) do
                local weapons = Weapons(turret)
                if weapons.stoneRawEfficiency > 0 then
                    PlayerProfile.unlock("BuildRMiningLaser")
                    break
                end
            end
        end

        if not unlocked["BuildRSalvagingLaser"] then
            local turrets = {craft:getTurrets()}
            for _, turret in pairs(turrets) do
                local weapons = Weapons(turret)
                if weapons.metalRawEfficiency > 0 then
                    PlayerProfile.unlock("BuildRSalvagingLaser")
                    break
                end
            end
        end

    end

    if not unlocked["ReconstructionSiteChanged"] then
        local hx, hy = player:getHomeSectorCoordinates()
        local rx, ry = player:getReconstructionSiteCoordinates()
        if hx ~= rx or hy ~= ry then
            PlayerProfile.unlock("ReconstructionSiteChanged")
        end
    end

    local ships = player.numShips
    if ships >= 2 then PlayerProfile.unlock("FleetOf2") end
    if ships >= 5 then PlayerProfile.unlock("FleetOf5") end
    if ships >= 10 then PlayerProfile.unlock("FleetOf10") end

    if not unlocked["FoundStation"] then
        local stations = player.numStations
        if stations >= 1 then PlayerProfile.unlock("FoundStation") end
    end

    if not unlocked["BeatTheWHG"] then
        if player:getValue("wormhole_guardian_destroyed") then PlayerProfile.unlock("BeatTheWHG") end
    end

    if not unlocked["MeetConvoy"] then
        PlayerProfile.convoyTick = (PlayerProfile.convoyTick or 0) + 1
        if PlayerProfile.convoyTick >= 10 then
            PlayerProfile.convoyTick = 0
            PlayerProfile.checkForConvoy()
        end
    end

    if player.ownsBlackMarketDLC then
        if player:getValue("family_1_accomplished") then PlayerProfile.unlock("MeetFamily") end
        if player:getValue("family_5_accomplished") then PlayerProfile.unlock("FinishFamily") end

        if player:getValue("commune_1_accomplished") then PlayerProfile.unlock("MeetCommune") end
        if player:getValue("commune_5_accomplished") then PlayerProfile.unlock("FinishCommune") end

        if player:getValue("cavaliers_1_accomplished") then PlayerProfile.unlock("MeetCavaliers") end
        if player:getValue("cavaliers_5_accomplished") then PlayerProfile.unlock("FinishCavaliers") end
    end

    -- we're doing an indirection via a variable itemCollected here to save performance
    -- it's not necessary to check each time an item is collected.
    -- a second after an item was collected will do the exact same thing and still cover all collected items
    if itemCollected then
        itemCollected = nil

        local inventory = player:getInventory()
        local upgrades = inventory:getItemsByType(InventoryItemType.SystemUpgrade)
        local foundOne

        for _, u in pairs(upgrades) do
            local upgrade = u.item
            if upgrade.rarity == Rarity(RarityType.Legendary) then
                if upgrade.script == "data/scripts/systems/teleporterkey1.lua" then
                    foundOne = true
                    PlayerProfile.unlock("FindXsotanArtifact1")
                elseif upgrade.script == "data/scripts/systems/teleporterkey2.lua" then
                    foundOne = true
                    PlayerProfile.unlock("FindXsotanArtifact2")
                elseif upgrade.script == "data/scripts/systems/teleporterkey3.lua" then
                    foundOne = true
                    PlayerProfile.unlock("FindXsotanArtifact3")
                elseif upgrade.script == "data/scripts/systems/teleporterkey4.lua" then
                    foundOne = true
                    PlayerProfile.unlock("FindXsotanArtifact4")
                elseif upgrade.script == "data/scripts/systems/teleporterkey5.lua" then
                    foundOne = true
                    PlayerProfile.unlock("FindXsotanArtifact5")
                elseif upgrade.script == "data/scripts/systems/teleporterkey6.lua" then
                    foundOne = true
                    PlayerProfile.unlock("FindXsotanArtifact6")
                elseif upgrade.script == "data/scripts/systems/teleporterkey7.lua" then
                    foundOne = true
                    PlayerProfile.unlock("FindXsotanArtifact7")
                elseif upgrade.script == "data/scripts/systems/teleporterkey8.lua" then
                    foundOne = true
                    PlayerProfile.unlock("FindXsotanArtifact8")
                end
            end
        end

        if foundOne then
            PlayerProfile.unlock("FindXsotanArtifact")
        end
    end

end

function PlayerProfile.onSectorArrivalConfirmed(playerIndex, x, y)
    local sector = Sector()
    sector:registerCallback("onWaveEncounterFinished", "onWaveEncounterFinished")
    sector:registerCallback("onBoardingSuccessful", "onBoardingSuccessful")

    if Balancing_InsideRing(x, y) then
        PlayerProfile.unlock("GetIntoTheCenter")
    end

    if x == 0 and y == 0 then
        PlayerProfile.unlock("GetToZeroZero")
    end

    if not self.data.unlocked["MeetConvoy"] then
        PlayerProfile.checkForConvoy()
    end
end

function PlayerProfile.onCraftChanged(id, previousId)
    local current = Entity(id)
    local previous = Entity(previousId)

    if previous then
        previous:unregisterCallback("onTorpedoLaunched", "onTorpedoLaunched")
        previous:unregisterCallback("onCaptainChanged", "onCaptainChanged")
    end

    if current then
        current:registerCallback("onTorpedoLaunched", "onTorpedoLaunched")
        current:registerCallback("onCaptainChanged", "onCaptainChanged")

        PlayerProfile.onCaptainChanged(id, current:getCaptain())
    end
end

function PlayerProfile.onAsteroidClaimed()
    PlayerProfile.unlock("ClaimAsteroid")
end

function PlayerProfile.onMineFounded()
    PlayerProfile.unlock("FoundAMine")
end

function PlayerProfile.onItemResearched()
    PlayerProfile.unlock("Research")
end

function PlayerProfile.onRefineryResourcesTaken()
    PlayerProfile.unlock("RefineResources")
end

function PlayerProfile.onWaveEncounterFinished()
    PlayerProfile.unlock("WaveEncounterDone")
end

function PlayerProfile.onBoardingSuccessful(id, oldFactionIndex, newFactionIndex)
    if newFactionIndex == Player().index then
        PlayerProfile.unlock("BoardAShip")
    end
end

function PlayerProfile.onBackgroundCommandStarted(shipName, type)
    if type == CommandType.Supply then
        PlayerProfile.unlock("EstablishSupplyChain")
    end
end

function PlayerProfile.onTorpedoLaunched()
    PlayerProfile.unlock("TorpedoFired")
end

function PlayerProfile.onContainerCracked()
    PlayerProfile.unlock("ContainerCracked")
end

function PlayerProfile.onStickOfDoomDestroyed()
    PlayerProfile.unlock("BeatStickOfDoom")
end

function PlayerProfile.onCaptainChanged(entityId, captain)
    if not captain then return end

    PlayerProfile.unlock("EmployACaptain")

    if captain.tier >= 1 then PlayerProfile.unlock("EmployTier1Captain") end
    if captain.tier >= 2 then PlayerProfile.unlock("EmployTier2Captain") end
    if captain.tier >= 3 then PlayerProfile.unlock("EmployTier3Captain") end
end

function PlayerProfile.onStashOpened()
    PlayerProfile.unlock("StashOpened")
end

function PlayerProfile.onEncyclopediaRepairDockRead()
    PlayerProfile.unlock("EncyclopediaRead")
end

function PlayerProfile.onWreckageReassembled()
    PlayerProfile.unlock("ReassembleFunctionalWreckage")
end

function PlayerProfile.onAsteroidShieldBossDestroyed()
    PlayerProfile.unlock("BeatAsteroidShieldBoss")
end

function PlayerProfile.onLaserBossDestroyed()
    PlayerProfile.unlock("BeatLaserBoss")
end

function PlayerProfile.onBigAIDestroyed()
    PlayerProfile.unlock("BeatBigAIBoss")
end

function PlayerProfile.onCorruptedAIDestroyed()
    PlayerProfile.unlock("BeatCorruptedAIBoss")
end

function PlayerProfile.onJumperBossDestroyed()
    PlayerProfile.unlock("BeatJumperBoss")
end

function PlayerProfile.onXsotanSwarmDefeated()
    PlayerProfile.unlock("BeatXsotanPrecursorBoss")
end

function PlayerProfile.onReconstructionKitUsed()
    PlayerProfile.unlock("ReconstructionKitUsed")
end

function PlayerProfile.onItemAdded()
    itemCollected = true
end

function PlayerProfile.onIzzyMet()
    if Player().ownsBlackMarketDLC then
        PlayerProfile.unlock("MeetIzzy")
    end
end

function PlayerProfile.onRelationStatusChanged(playerIndex, factionIndex, status)
    local faction = Faction(factionIndex)
    if faction.isAIFaction and status == RelationStatus.Allies then
        PlayerProfile.unlock("AllyWithAIFaction")
    end
end

function PlayerProfile.checkForConvoy()
    for _, ship in pairs({Sector():getEntitiesByType(EntityType.Ship)}) do
        if ship:getValue("big_convoy_capital_ship") then
            PlayerProfile.unlock("MeetConvoy")
        end
    end
end

end

function PlayerProfile.getMilestones()
    local milestones = {}

    local connectionIdCounter = 0
    function makeConnectionId()
        connectionIdCounter = connectionIdCounter + 1
        return connectionIdCounter
    end
    -- Note: Highlight of the icons was done with a 0.8 highlight in QuadRenderer::renderIcon()
    -- ##### MATERIALS GATHERED ##### --
    milestones.IronCollected =
    {
        position = vec2(55, 55),
        icon = "data/textures/icons/milestones/collected-iron.png",
        lockedIcon = "data/textures/icons/milestones/collected-iron-locked.png",
        color = Material(MaterialType.Iron).color,
        tooltip = "Collect Iron."%_t,
        alwaysVisible = true,
    }
    milestones.TitaniumCollected =
    {
        position = vec2(155, 55),
        icon = "data/textures/icons/milestones/collected-titanium.png",
        lockedIcon = "data/textures/icons/milestones/collected-titanium-locked.png",
        color = Material(MaterialType.Titanium).color,
        tooltip = "Collect Titanium."%_t,
        alwaysVisible = true,
    }
    milestones.NaoniteCollected =
    {
        position = vec2(255, 55),
        icon = "data/textures/icons/milestones/collected-naonite.png",
        lockedIcon = "data/textures/icons/milestones/collected-naonite-locked.png",
        color = Material(MaterialType.Naonite).color,
        tooltip = "Collect Naonite."%_t,
        alwaysVisible = true,
    }
    milestones.TriniumCollected =
    {
        position = vec2(355, 55),
        icon = "data/textures/icons/milestones/collected-trinium.png",
        lockedIcon = "data/textures/icons/milestones/collected-trinium-locked.png",
        color = Material(MaterialType.Trinium).color,
        tooltip = "Collect Trinium."%_t,
        alwaysVisible = true,
    }
    milestones.XanionCollected =
    {
        position = vec2(455, 55),
        icon = "data/textures/icons/milestones/collected-xanion.png",
        lockedIcon = "data/textures/icons/milestones/collected-xanion-locked.png",
        color = Material(MaterialType.Xanion).color,
        tooltip = "Collect Xanion."%_t,
        alwaysVisible = true,
    }
    milestones.OgoniteCollected =
    {
        position = vec2(555, 55),
        icon = "data/textures/icons/milestones/collected-ogonite.png",
        lockedIcon = "data/textures/icons/milestones/collected-ogonite-locked.png",
        color = Material(MaterialType.Ogonite).color,
        tooltip = "Collect Ogonite."%_t,
        alwaysVisible = true,
    }
    milestones.AvorionCollected =
    {
        position = vec2(655, 55),
        icon = "data/textures/icons/milestones/collected-avorion.png",
        lockedIcon = "data/textures/icons/milestones/collected-avorion-locked.png",
        color = Material(MaterialType.Avorion).color,
        tooltip = "Collect Avorion."%_t,
        alwaysVisible = true,
    }

    -- ##### BUILDING KNOWLEDGE ##### --
    milestones.IronKnowledge =
    {
        position = vec2(55, 155),
        icon = "data/textures/icons/milestones/iron-knowledge.png",
        lockedIcon = "data/textures/icons/milestones/iron-knowledge-locked.png",
        color = Material(MaterialType.Iron).color,
        tooltip = "Acquire building knowledge for Iron."%_t,
        successors = {"TitaniumKnowledge", "FleetOf2"},
        alwaysVisible = true,
        connections =
        {
            {id = makeConnectionId(), lower = vec2(115, 155), upper = vec2(155, 215), texture = "data/textures/ui/player-profile/iron-horizontal-connection.png", lockedTexture = "data/textures/ui/player-profile/horizontal-connection-locked.png"},
            {id = makeConnectionId(), lower = vec2(55, 215), upper = vec2(115, 415), texture = "data/textures/ui/player-profile/iron-long-bottom-right-connection.png", lockedTexture = "data/textures/ui/player-profile/long-bottom-right-connection-locked.png"},
        },
    }
    milestones.TitaniumKnowledge =
    {
        position = vec2(155, 155),
        icon = "data/textures/icons/milestones/titanium-knowledge.png",
        lockedIcon = "data/textures/icons/milestones/titanium-knowledge-locked.png",
        color = Material(MaterialType.Titanium).color,
        tooltip = "Acquire building knowledge for Titanium."%_t,
        alwaysVisible = true,
        successors = {"NaoniteKnowledge", "BuildTitaniumSlotShip"},
        connections =
        {
            {id = makeConnectionId(), lower = vec2(215, 155), upper = vec2(255, 215), texture = "data/textures/ui/player-profile/titanium-horizontal-connection.png", lockedTexture = "data/textures/ui/player-profile/horizontal-connection-locked.png"},
            {id = makeConnectionId(), lower = vec2(155, 215), upper = vec2(215, 315), texture = "data/textures/ui/player-profile/titanium-bottom-right-connection.png", lockedTexture = "data/textures/ui/player-profile/bottom-right-connection-locked.png"},
        },
    }
    milestones.NaoniteKnowledge =
    {
        position = vec2(255, 155),
        icon = "data/textures/icons/milestones/naonite-knowledge.png",
        lockedIcon = "data/textures/icons/milestones/naonite-knowledge-locked.png",
        color = Material(MaterialType.Naonite).color,
        tooltip = "Acquire building knowledge for Naonite."%_t,
        alwaysVisible = true,
        successors = {"TriniumKnowledge", "BuildNaoniteSlotShip"},
        connections =
        {
            {id = makeConnectionId(), lower = vec2(315, 155), upper = vec2(355, 215), texture = "data/textures/ui/player-profile/naonite-horizontal-connection.png", lockedTexture = "data/textures/ui/player-profile/horizontal-connection-locked.png"},
            {id = makeConnectionId(), lower = vec2(255, 215), upper = vec2(315, 315), texture = "data/textures/ui/player-profile/naonite-bottom-right-connection.png", lockedTexture = "data/textures/ui/player-profile/bottom-right-connection-locked.png"},
        },
    }
    milestones.TriniumKnowledge =
    {
        position = vec2(355, 155),
        icon = "data/textures/icons/milestones/trinium-knowledge.png",
        lockedIcon = "data/textures/icons/milestones/trinium-knowledge-locked.png",
        color = Material(MaterialType.Trinium).color,
        tooltip = "Acquire building knowledge for Trinium."%_t,
        alwaysVisible = true,
        successors = {"XanionKnowledge", "BuildTriniumSlotShip"},
        connections =
        {
            {id = makeConnectionId(), lower = vec2(415, 155), upper = vec2(455, 215), texture = "data/textures/ui/player-profile/trinium-horizontal-connection.png", lockedTexture = "data/textures/ui/player-profile/horizontal-connection-locked.png"},
            {id = makeConnectionId(), lower = vec2(355, 215), upper = vec2(415, 315), texture = "data/textures/ui/player-profile/trinium-bottom-right-connection.png", lockedTexture = "data/textures/ui/player-profile/bottom-right-connection-locked.png"},
        },
    }
    milestones.XanionKnowledge =
    {
        position = vec2(455, 155),
        icon = "data/textures/icons/milestones/xanion-knowledge.png",
        lockedIcon = "data/textures/icons/milestones/xanion-knowledge-locked.png",
        color = Material(MaterialType.Xanion).color,
        tooltip = "Acquire building knowledge for Xanion."%_t,
        alwaysVisible = true,
        successors = {"OgoniteKnowledge", "BuildXanionSlotShip"},
        connections =
        {
            {id = makeConnectionId(), lower = vec2(515, 155), upper = vec2(555, 215), texture = "data/textures/ui/player-profile/xanion-horizontal-connection.png", lockedTexture = "data/textures/ui/player-profile/horizontal-connection-locked.png"},
            {id = makeConnectionId(), lower = vec2(455, 215), upper = vec2(515, 315), texture = "data/textures/ui/player-profile/xanion-bottom-right-connection.png", lockedTexture = "data/textures/ui/player-profile/bottom-right-connection-locked.png"},
        },
    }
    milestones.OgoniteKnowledge =
    {
        position = vec2(555, 155),
        icon = "data/textures/icons/milestones/ogonite-knowledge.png",
        lockedIcon = "data/textures/icons/milestones/ogonite-knowledge-locked.png",
        color = Material(MaterialType.Ogonite).color,
        tooltip = "Acquire building knowledge for Ogonite."%_t,
        alwaysVisible = true,
        successors = {"AvorionKnowledge", "BuildOgoniteSlotShip"},
        connections =
        {
            {id = makeConnectionId(), lower = vec2(615, 155), upper = vec2(655, 215), texture = "data/textures/ui/player-profile/ogonite-horizontal-connection.png", lockedTexture = "data/textures/ui/player-profile/horizontal-connection-locked.png"},
            {id = makeConnectionId(), lower = vec2(555, 215), upper = vec2(615, 315), texture = "data/textures/ui/player-profile/ogonite-bottom-right-connection.png", lockedTexture = "data/textures/ui/player-profile/bottom-right-connection-locked.png"},
        },
    }
    milestones.AvorionKnowledge =
    {
        position = vec2(655, 155),
        icon = "data/textures/icons/milestones/avorion-knowledge.png",
        lockedIcon = "data/textures/icons/milestones/avorion-knowledge-locked.png",
        color = Material(MaterialType.Avorion).color,
        tooltip = "Acquire building knowledge for Avorion."%_t,
        alwaysVisible = true,
        successors = {"BuildAvorionSlotShip"},
        connections =
        {
            {id = makeConnectionId(), lower = vec2(655, 215), upper = vec2(715, 315), texture = "data/textures/ui/player-profile/avorion-bottom-right-connection.png", lockedTexture = "data/textures/ui/player-profile/bottom-right-connection-locked.png"},
        },
    }

    -- ##### BUILD X SLOTS SHIP ##### --
    milestones.BuildTitaniumSlotShip =
    {
        position = vec2(215, 255),
        icon = "data/textures/icons/milestones/titanium-slot-ship.png",
        lockedIcon = "data/textures/icons/milestones/titanium-slot-ship-locked.png",
        color = Material(MaterialType.Titanium).color,
        tooltip = "Build a ship with 5 subsystem sockets."%_t,
    }
    milestones.BuildNaoniteSlotShip =
    {
        position = vec2(315, 255),
        icon = "data/textures/icons/milestones/naonite-slot-ship.png",
        lockedIcon = "data/textures/icons/milestones/naonite-slot-ship-locked.png",
        color = Material(MaterialType.Naonite).color,
        tooltip = "Build a ship with 6 subsystem sockets."%_t,
    }
    milestones.BuildTriniumSlotShip =
    {
        position = vec2(415, 255),
        icon = "data/textures/icons/milestones/trinium-slot-ship.png",
        lockedIcon = "data/textures/icons/milestones/trinium-slot-ship-locked.png",
        color = Material(MaterialType.Trinium).color,
        tooltip = "Build a ship with 8 subsystem sockets."%_t,
    }
    milestones.BuildXanionSlotShip =
    {
        position = vec2(515, 255),
        icon = "data/textures/icons/milestones/xanion-slot-ship.png",
        lockedIcon = "data/textures/icons/milestones/xanion-slot-ship-locked.png",
        color = Material(MaterialType.Xanion).color,
        tooltip = "Build a ship with 10 subsystem sockets."%_t,
    }
    milestones.BuildOgoniteSlotShip =
    {
        position = vec2(615, 255),
        icon = "data/textures/icons/milestones/ogonite-slot-ship.png",
        lockedIcon = "data/textures/icons/milestones/ogonite-slot-ship-locked.png",
        color = Material(MaterialType.Ogonite).color,
        tooltip = "Build a ship with 12 subsystem sockets."%_t,
    }
    milestones.BuildAvorionSlotShip =
    {
        position = vec2(715, 255),
        icon = "data/textures/icons/milestones/avorion-slot-ship.png",
        lockedIcon = "data/textures/icons/milestones/avorion-slot-ship-locked.png",
        color = Material(MaterialType.Avorion).color,
        tooltip = "Build a ship with 15 subsystem sockets."%_t,
    }

    -- ##### BUILD X SHIPS ##### --
    milestones.FleetOf2 =
    {
        position = vec2(115, 355),
        icon = "data/textures/icons/milestones/fleet2.png",
        lockedIcon = "data/textures/icons/milestones/fleet2-locked.png",
        color = Rarity(RarityType.Common).color,
        tooltip = "Found a second ship."%_t,
        successors = {"FleetOf5"},
        connections =
        {
            {id = makeConnectionId(), lower = vec2(175, 355), upper = vec2(215, 415), texture = "data/textures/ui/player-profile/common-horizontal-connection.png", lockedTexture = "data/textures/ui/player-profile/horizontal-connection-locked.png"},
        },
    }
    milestones.FleetOf5 =
    {
        position = vec2(215, 355),
        icon = "data/textures/icons/milestones/fleet5.png",
        lockedIcon = "data/textures/icons/milestones/fleet5-locked.png",
        color = Rarity(RarityType.Rare).color,
        tooltip = "Build a flotilla of five ships."%_t,
        successors = {"FleetOf10"},
        connections =
        {
            {id = makeConnectionId(), lower = vec2(275, 355), upper = vec2(315, 415), texture = "data/textures/ui/player-profile/rare-horizontal-connection.png", lockedTexture = "data/textures/ui/player-profile/horizontal-connection-locked.png"},
        },
    }
    milestones.FleetOf10 =
    {
        position = vec2(315, 355),
        icon = "data/textures/icons/milestones/fleet10.png",
        lockedIcon = "data/textures/icons/milestones/fleet10-locked.png",
        color = Rarity(RarityType.Exotic).color,
        tooltip = "Build a fleet of ten ships."%_t,
    }

    -- ##### FOUND STATION ##### --
    milestones.ClaimAsteroid =
    {
        position = vec2(455, 355),
        icon = "data/textures/icons/milestones/claim-asteroid.png",
        lockedIcon = "data/textures/icons/milestones/claim-asteroid-locked.png",
        color = Rarity(RarityType.Common).color,
        tooltip = "Claim a big asteroid."%_t,
        alwaysVisible = true,
        successors = {"FoundAMine"},
        connections =
        {
            {id = makeConnectionId(), lower = vec2(455, 415), upper = vec2(515, 455), texture = "data/textures/ui/player-profile/common-vertical-connection.png", lockedTexture = "data/textures/ui/player-profile/vertical-connection-locked.png"},
        },
    }
    milestones.FoundAMine =
    {
        position = vec2(455, 455),
        icon = "data/textures/icons/milestones/found-mine.png",
        lockedIcon = "data/textures/icons/milestones/found-mine-locked.png",
        color = Rarity(RarityType.Rare).color,
        tooltip = "Found a mine on an asteroid."%_t,
    }

    milestones.FoundStation =
    {
        position = vec2(605, 355),
        icon = "data/textures/icons/milestones/found-station.png",
        lockedIcon = "data/textures/icons/milestones/found-station-locked.png",
        color = Rarity(RarityType.Rare).color,
        tooltip = "Found a station."%_t,
        alwaysVisible = true,
        successors = {"EstablishSupplyChain"},
        connections =
        {
            {id = makeConnectionId(), lower = vec2(605, 415), upper = vec2(665, 455), texture = "data/textures/ui/player-profile/rare-vertical-connection.png", lockedTexture = "data/textures/ui/player-profile/vertical-connection-locked.png"},
        },
    }
    milestones.EstablishSupplyChain =
    {
        position = vec2(605, 455),
        icon = "data/textures/icons/milestones/supply-chain.png",
        lockedIcon = "data/textures/icons/milestones/supply-chain-locked.png",
        color = Rarity(RarityType.Exceptional).color,
        tooltip = "Connect two of your factories using the supply command."%_t,
    }


    -- ##### TO THE CENTER ##### --
    milestones.GetIntoTheCenter =
    {
        position = vec2(55, 455),
        icon = "data/textures/icons/milestones/into-center.png",
        lockedIcon = "data/textures/icons/milestones/into-center-locked.png",
        color = Rarity(RarityType.Exceptional).color,
        tooltip = "Get into the center of the galaxy."%_t,
        alwaysVisible = true,
        successors = {"GetToZeroZero"},
        connections =
        {
            {id = makeConnectionId(), lower = vec2(115, 455), upper = vec2(155, 515), texture = "data/textures/ui/player-profile/exceptional-horizontal-connection.png", lockedTexture = "data/textures/ui/player-profile/horizontal-connection-locked.png"},
        },
    }
    milestones.GetToZeroZero =
    {
        position = vec2(155, 455),
        icon = "data/textures/icons/milestones/0-0.png",
        lockedIcon = "data/textures/icons/milestones/0-0-locked.png",
        color = Rarity(RarityType.Exotic).color,
        tooltip = "Reach sector (0:0)."%_t,
        successors = {"BeatTheWHG"},
        connections =
        {
            {id = makeConnectionId(), lower = vec2(215, 455), upper = vec2(255, 515), texture = "data/textures/ui/player-profile/exotic-horizontal-connection.png", lockedTexture = "data/textures/ui/player-profile/horizontal-connection-locked.png"},
        },
    }
    milestones.BeatTheWHG =
    {
        position = vec2(255, 455),
        icon = "data/textures/icons/milestones/destroy-guardian.png",
        lockedIcon = "data/textures/icons/milestones/destroy-guardian-locked.png",
        color = Rarity(RarityType.Legendary).color,
        tooltip = "Destroy the Xsotan Wormhole Guardian."%_t,
    }

    -- ##### INTRO MISSIONS ##### --
    milestones.BuildRMiningLaser =
    {
        position = vec2(755, 355),
        icon = "data/textures/icons/milestones/r-mining-laser.png",
        lockedIcon = "data/textures/icons/milestones/r-mining-laser-locked.png",
        color = Rarity(RarityType.Common).color,
        tooltip = "Add R-Mining lasers to your ship."%_t,
        alwaysVisible = true,
        successors = {"RefineResources"},
        connections =
        {
            {id = makeConnectionId(), lower = vec2(755, 415), upper = vec2(915, 455), texture = "data/textures/ui/player-profile/common-merge-to-two-left-connection.png", lockedTexture = "data/textures/ui/player-profile/merge-to-two-left-connection-locked.png"}
        },
    }
    milestones.BuildRSalvagingLaser =
    {
        position = vec2(855, 355),
        icon = "data/textures/icons/milestones/r-salvaging-laser.png",
        lockedIcon = "data/textures/icons/milestones/r-salvaging-laser-locked.png",
        color = Rarity(RarityType.Common).color,
        tooltip = "Add R-Salvaging lasers to your ship."%_t,
        alwaysVisible = true,
        successors = {"RefineResources"},
        connections =
        {
            {id = makeConnectionId(), lower = vec2(755, 415), upper = vec2(915, 455), texture = "data/textures/ui/player-profile/common-merge-to-two-right-connection.png", lockedTexture = "data/textures/ui/player-profile/merge-to-two-right-connection-locked.png"}
        },
    }
    milestones.RefineResources =
    {
        position = vec2(805, 455),
        icon = "data/textures/icons/milestones/refine-resources.png",
        lockedIcon = "data/textures/icons/milestones/refine-resources-locked.png",
        color = Rarity(RarityType.Uncommon).color,
        tooltip = "Refine some ores or scrap into resources."%_t,
    }

    milestones.BuildCargoBay =
    {
        position = vec2(155, 555),
        icon = "data/textures/icons/milestones/cargo-bay.png",
        lockedIcon = "data/textures/icons/milestones/cargo-bay-locked.png",
        color = Rarity(RarityType.Common).color,
        tooltip = "Add a cargobay to your ship."%_t,
        alwaysVisible = true,
    }

    milestones.StashOpened =
    {
        position = vec2(55, 555),
        icon = "data/textures/icons/milestones/stash-opened.png",
        lockedIcon = "data/textures/icons/milestones/stash-opened-locked.png",
        color = Rarity(RarityType.Rare).color,
        tooltip = "Open a hidden stash."%_t,
        alwaysVisible = true,
    }

    milestones.TorpedoFired =
    {
        position = vec2(255, 555),
        icon = "data/textures/icons/milestones/torpedo-fired.png",
        lockedIcon = "data/textures/icons/milestones/torpedo-fired-locked.png",
        color = Rarity(RarityType.Uncommon).color,
        tooltip = "Fire a torpedo."%_t,
        alwaysVisible = true,
    }

    milestones.WaveEncounterDone =
    {
        position = vec2(155, 655),
        icon = "data/textures/icons/milestones/clear-pirates.png",
        lockedIcon = "data/textures/icons/milestones/clear-pirates-locked.png",
        color = Rarity(RarityType.Uncommon).color,
        tooltip = "Clear a pirate sector."%_t,
        alwaysVisible = true,
    }

    -- ##### SINGLE MILESTONES ##### --
    milestones.AllyWithAIFaction =
    {
        position = vec2(255, 655),
        icon = "data/textures/icons/milestones/ally.png",
        lockedIcon = "data/textures/icons/milestones/ally-locked.png",
        color = Rarity(RarityType.Exceptional).color,
        tooltip = "Ally yourself with another faction."%_t,
        alwaysVisible = true,
    }

    milestones.Research =
    {
        position = vec2(355, 555),
        icon = "data/textures/icons/milestones/research.png",
        lockedIcon = "data/textures/icons/milestones/research-locked.png",
        color = Rarity(RarityType.Uncommon).color,
        tooltip = "Research an item."%_t,
        alwaysVisible = true,
    }

    milestones.EncyclopediaRead =
    {
        position = vec2(455, 555),
        icon = "data/textures/icons/milestones/encyclopedia.png",
        lockedIcon = "data/textures/icons/milestones/encyclopedia-locked.png",
        color = Rarity(RarityType.Common).color,
        tooltip = "Find and read the article about Repair Docks in the Avorion Encyclopedia."%_t,
        alwaysVisible = true,
    }

    milestones.ReconstructionSiteChanged =
    {
        position = vec2(555, 555),
        icon = "data/textures/icons/milestones/reconstruction-site.png",
        lockedIcon = "data/textures/icons/milestones/reconstruction-site-locked.png",
        color = Rarity(RarityType.Uncommon).color,
        tooltip = "Change your Reconstruction Site at a Repair Dock."%_t,
        alwaysVisible = true,
    }

    milestones.ReconstructionKitUsed =
    {
        position = vec2(455, 655),
        icon = "data/textures/icons/milestones/reconstruction-kit.png",
        lockedIcon = "data/textures/icons/milestones/reconstruction-kit-locked.png",
        color = Rarity(RarityType.Uncommon).color,
        tooltip = "Reconstruct your ship with a Reconstruction Kit."%_t,
        alwaysVisible = true,
    }

    milestones.ReassembleFunctionalWreckage =
    {
        position = vec2(355, 655),
        icon = "data/textures/icons/milestones/functional-wreckage.png",
        lockedIcon = "data/textures/icons/milestones/functional-wreckage-locked.png",
        color = Rarity(RarityType.Exotic).color,
        tooltip = "Find an abandoned ship and make it spaceworthy again."%_t,
        alwaysVisible = true,
    }

    milestones.ContainerCracked =
    {
        position = vec2(55, 655),
        icon = "data/textures/icons/milestones/crack-open-container.png",
        lockedIcon = "data/textures/icons/milestones/crack-open-container-locked.png",
        color = Rarity(RarityType.Exceptional).color,
        tooltip = "Crack open a container at a smuggler's outpost."%_t,
        alwaysVisible = true,
    }

    -- ##### CAPTAINS ##### --
    milestones.EmployACaptain =
    {
        position = vec2(155, 755),
        icon = "data/textures/icons/milestones/employ-captain.png",
        lockedIcon = "data/textures/icons/milestones/employ-captain-locked.png",
        color = Rarity(RarityType.Common).color,
        tooltip = "Employ a Captain on your ship."%_t,
        alwaysVisible = true,
        successors = {"EmployTier1Captain", "EmployTier2Captain", "EmployTier3Captain"},
        connections =
        {
            {id = makeConnectionId(), lower = vec2(55, 815), upper = vec2(315, 855), texture = "data/textures/ui/player-profile/common-split-to-three-connection.png", lockedTexture = "data/textures/ui/player-profile/split-to-three-connection-locked.png"},
        },
    }
    milestones.EmployTier1Captain =
    {
        position = vec2(55, 855),
        icon = "data/textures/icons/milestones/employ-captain-tier1.png",
        lockedIcon = "data/textures/icons/milestones/employ-captain-tier1-locked.png",
        color = Rarity(RarityType.Uncommon).color,
        tooltip = "Employ a tier 1 captain on your ship."%_t,
    }
    milestones.EmployTier2Captain =
    {
        position = vec2(155, 855),
        icon = "data/textures/icons/milestones/employ-captain-tier2.png",
        lockedIcon = "data/textures/icons/milestones/employ-captain-tier2-locked.png",
        color = Rarity(RarityType.Rare).color,
        tooltip = "Employ a tier 2 captain on your ship."%_t,
    }
    milestones.EmployTier3Captain =
    {
        position = vec2(255, 855),
        icon = "data/textures/icons/milestones/employ-captain-tier3.png",
        lockedIcon = "data/textures/icons/milestones/employ-captain-tier3-locked.png",
        color = Rarity(RarityType.Exceptional).color,
        tooltip = "Employ a tier 3 captain on your ship."%_t,
    }

    -- ##### HANGAR BUILDING ##### --
    milestones.BuildHangar =
    {
        position = vec2(805, 555),
        icon = "data/textures/icons/milestones/hangar.png",
        lockedIcon = "data/textures/icons/milestones/hangar-locked.png",
        color = Rarity(RarityType.Rare).color,
        alwaysVisible = true,
        tooltip = "Add a hangar to your ship."%_t,
        successors = {"TwoFullFighterSquads", "BoardAShip"},
        connections =
        {
            {id = makeConnectionId(), lower = vec2(755, 615), upper = vec2(915, 655), texture = "data/textures/ui/player-profile/rare-split-to-two-connection.png", lockedTexture = "data/textures/ui/player-profile/split-to-two-connection-locked.png"},
        },
    }
    milestones.TwoFullFighterSquads =
    {
        position = vec2(755, 655),
        icon = "data/textures/icons/milestones/two-squads.png",
        lockedIcon = "data/textures/icons/milestones/two-squads-locked.png",
        color = Rarity(RarityType.Rare).color,
        tooltip = "Have two full fighter squads on your ship."%_t,
    }
    milestones.BoardAShip =
    {
        position = vec2(855, 655),
        icon = "data/textures/icons/milestones/board-ship.png",
        lockedIcon = "data/textures/icons/milestones/board-ship-locked.png",
        color = Rarity(RarityType.Exceptional).color,
        tooltip = "Use boarders and boarding shuttles to board another ship or station."%_t,
    }


    -- ##### XSOTAN ARTIFACTS ##### --
    milestones.FindXsotanArtifact =
    {
        position = vec2(55, 955),
        icon = "data/textures/icons/milestones/any-xsotan-artifact.png",
        lockedIcon = "data/textures/icons/milestones/any-xsotan-artifact-locked.png",
        color = Rarity(RarityType.Legendary).color,
        alwaysVisible = true,
        tooltip = "Find a mysterious artifact."%_t,
        successors = {"FindXsotanArtifact1", "FindXsotanArtifact2","FindXsotanArtifact3","FindXsotanArtifact4","FindXsotanArtifact5","FindXsotanArtifact6","FindXsotanArtifact7","FindXsotanArtifact8"},
        connections =
        {
            {id = makeConnectionId(), lower = vec2(115, 955), upper = vec2(885, 1025), texture = "data/textures/ui/player-profile/legendary-artifact-connection.png", lockedTexture = "data/textures/ui/player-profile/artifact-connection-locked.png"},
        },
    }

    milestones.FindXsotanArtifact1 =
    {
        position = vec2(125, 1025),
        icon = "data/textures/icons/milestones/xsotan-artifact1.png",
        lockedIcon = "data/textures/icons/milestones/xsotan-artifact1-locked.png",
        color = Rarity(RarityType.Legendary).color,
        tooltip = "Find a Xsotan artifact with one scratch on it."%_t,
    }
    milestones.FindXsotanArtifact2 =
    {
        position = vec2(225, 1025),
        icon = "data/textures/icons/milestones/xsotan-artifact2.png",
        lockedIcon = "data/textures/icons/milestones/xsotan-artifact2-locked.png",
        color = Rarity(RarityType.Legendary).color,
        tooltip = "Find a Xsotan artifact with two scratches on it."%_t,
    }
    milestones.FindXsotanArtifact3 =
    {
        position = vec2(325, 1025),
        icon = "data/textures/icons/milestones/xsotan-artifact3.png",
        lockedIcon = "data/textures/icons/milestones/xsotan-artifact3-locked.png",
        color = Rarity(RarityType.Legendary).color,
        tooltip = "Find a Xsotan artifact with three scratches on it."%_t,
    }
    milestones.FindXsotanArtifact4 =
    {
        position = vec2(425, 1025),
        icon = "data/textures/icons/milestones/xsotan-artifact4.png",
        lockedIcon = "data/textures/icons/milestones/xsotan-artifact4-locked.png",
        color = Rarity(RarityType.Legendary).color,
        tooltip = "Find a Xsotan artifact with four scratches on it."%_t,
    }
    milestones.FindXsotanArtifact5 =
    {
        position = vec2(525, 1025),
        icon = "data/textures/icons/milestones/xsotan-artifact5.png",
        lockedIcon = "data/textures/icons/milestones/xsotan-artifact5-locked.png",
        color = Rarity(RarityType.Legendary).color,
        tooltip = "Find a Xsotan artifact with five scratches on it."%_t,
    }
    milestones.FindXsotanArtifact6 =
    {
        position = vec2(625, 1025),
        icon = "data/textures/icons/milestones/xsotan-artifact6.png",
        lockedIcon = "data/textures/icons/milestones/xsotan-artifact6-locked.png",
        color = Rarity(RarityType.Legendary).color,
        tooltip = "Find a Xsotan artifact with six scratches on it."%_t,
    }
    milestones.FindXsotanArtifact7 =
    {
        position = vec2(725, 1025),
        icon = "data/textures/icons/milestones/xsotan-artifact7.png",
        lockedIcon = "data/textures/icons/milestones/xsotan-artifact7-locked.png",
        color = Rarity(RarityType.Legendary).color,
        tooltip = "Find a Xsotan artifact with seven scratches on it."%_t,
    }
    milestones.FindXsotanArtifact8 =
    {
        position = vec2(825, 1025),
        icon = "data/textures/icons/milestones/xsotan-artifact8.png",
        lockedIcon = "data/textures/icons/milestones/xsotan-artifact8-locked.png",
        color = Rarity(RarityType.Legendary).color,
        tooltip = "Find a Xsotan artifact with eight scratches on it."%_t,
    }

    -- ##### BLACK MARKET ##### --
    milestones.MeetIzzy =
    {
        position = vec2(155, 1125),
        icon = "data/textures/icons/milestones/dlc-meet-izzy.png",
        lockedIcon = "data/textures/icons/milestones/dlc-meet-izzy-locked.png",
        color = Rarity(RarityType.Uncommon).color,
        alwaysVisible = true,
        tooltip = "[DLC: Black Market] Meet Izzy."%_t,
        successors = {"MeetFamily", "MeetCavaliers","MeetCommune"},
        connections =
        {
            {id = makeConnectionId(), lower = vec2(55, 1185), upper = vec2(315, 1225), texture = "data/textures/ui/player-profile/uncommon-split-to-three-connection.png", lockedTexture = "data/textures/ui/player-profile/split-to-three-connection-locked.png"},
        },
    }
    milestones.MeetFamily =
    {
        position = vec2(55, 1225),
        icon = "data/textures/icons/milestones/dlc-meet-family.png",
        lockedIcon = "data/textures/icons/milestones/dlc-meet-family-locked.png",
        color = Rarity(RarityType.Uncommon).color,
        tooltip = "[DLC: Black Market] Meet the Family."%_t,
        successors = {"FinishFamily"},
        connections =
        {
            {id = makeConnectionId(), lower = vec2(55, 1285), upper = vec2(115, 1325), texture = "data/textures/ui/player-profile/uncommon-vertical-connection.png", lockedTexture = "data/textures/ui/player-profile/vertical-connection-locked.png"},
        },
    }
    milestones.FinishFamily =
    {
        position = vec2(55, 1325),
        icon = "data/textures/icons/milestones/dlc-finish-family.png",
        lockedIcon = "data/textures/icons/milestones/dlc-finish-family-locked.png",
        color = Rarity(RarityType.Rare).color,
        tooltip = "[DLC: Black Market] Finish the Family storyline."%_t,
    }

    milestones.MeetCavaliers =
    {
        position = vec2(155, 1225),
        icon = "data/textures/icons/milestones/dlc-meet-cavaliers.png",
        lockedIcon = "data/textures/icons/milestones/dlc-meet-cavaliers-locked.png",
        color = Rarity(RarityType.Uncommon).color,
        tooltip = "[DLC: Black Market] Meet the Cavaliers."%_t,
        successors = {"FinishCavaliers"},
        connections =
        {
            {id = makeConnectionId(), lower = vec2(155, 1285), upper = vec2(215, 1325), texture = "data/textures/ui/player-profile/uncommon-vertical-connection.png", lockedTexture = "data/textures/ui/player-profile/vertical-connection-locked.png"},
        },
    }
    milestones.FinishCavaliers =
    {
        position = vec2(155, 1325),
        icon = "data/textures/icons/milestones/dlc-finish-cavaliers.png",
        lockedIcon = "data/textures/icons/milestones/dlc-finish-cavaliers-locked.png",
        color = Rarity(RarityType.Rare).color,
        tooltip = "[DLC: Black Market] Finish the Cavaliers storyline."%_t,
    }

    milestones.MeetCommune =
    {
        position = vec2(255, 1225),
        icon = "data/textures/icons/milestones/dlc-meet-commune.png",
        lockedIcon = "data/textures/icons/milestones/dlc-meet-commune-locked.png",
        color = Rarity(RarityType.Uncommon).color,
        tooltip = "[DLC: Black Market] Meet the Commune."%_t,
        successors = {"FinishCommune"},
        connections =
        {
            {id = makeConnectionId(), lower = vec2(255, 1285), upper = vec2(315, 1325), texture = "data/textures/ui/player-profile/uncommon-vertical-connection.png", lockedTexture = "data/textures/ui/player-profile/vertical-connection-locked.png"},
        },
    }
    milestones.FinishCommune =
    {
        position = vec2(255, 1325),
        icon = "data/textures/icons/milestones/dlc-finish-commune.png",
        lockedIcon = "data/textures/icons/milestones/dlc-finish-commune-locked.png",
        color = Rarity(RarityType.Rare).color,
        tooltip = "[DLC: Black Market] Finish the Commune storyline."%_t,
    }

    milestones.MeetConvoy =
    {
        position = vec2(355, 1125),
        icon = "data/textures/icons/milestones/meet-convoy.png",
        lockedIcon = "data/textures/icons/milestones/meet-convoy-locked.png",
        color = Rarity(RarityType.Exotic).color,
        alwaysVisible = true,
        masked = true,
        tooltip = "Meet the convoy that wants to fly to the center of the galaxy."%_t,
    }

    -- ##### BOSSES ##### --
    milestones.BeatAsteroidShieldBoss =
    {
        position = vec2(555, 1125),
        icon = "data/textures/icons/milestones/asteroid-shield-boss.png",
        lockedIcon = "data/textures/icons/milestones/asteroid-shield-boss-locked.png",
        color = Rarity(RarityType.Legendary).color,
        alwaysVisible = true,
        masked = true,
        tooltip = "Destroy Specimen 8055."%_t,
    }
    milestones.BeatBigAIBoss =
    {
        position = vec2(655, 1125),
        icon = "data/textures/icons/milestones/big-ai-boss.png",
        lockedIcon = "data/textures/icons/milestones/big-ai-boss-locked.png",
        color = Rarity(RarityType.Legendary).color,
        alwaysVisible = true,
        masked = true,
        tooltip = "Destroy the bigger version of The AI."%_t,
    }
    milestones.BeatCorruptedAIBoss =
    {
        position = vec2(755, 1125),
        icon = "data/textures/icons/milestones/corrupted-ai-boss.png",
        lockedIcon = "data/textures/icons/milestones/corrupted-ai-boss-locked.png",
        color = Rarity(RarityType.Legendary).color,
        alwaysVisible = true,
        masked = true,
        tooltip = "Destroy the corrupted version of The AI."%_t,
    }
    milestones.BeatStickOfDoom =
    {
        position = vec2(855, 1125),
        icon = "data/textures/icons/milestones/stick-of-doom.png",
        lockedIcon = "data/textures/icons/milestones/stick-of-doom-locked.png",
        color = Rarity(RarityType.Legendary).color,
        alwaysVisible = true,
        tooltip = "Call and destroy the Stick of Doom."%_t,
    }
    milestones.BeatJumperBoss =
    {
        position = vec2(555, 1225),
        icon = "data/textures/icons/milestones/jumper-boss.png",
        lockedIcon = "data/textures/icons/milestones/jumper-boss-locked.png",
        color = Rarity(RarityType.Legendary).color,
        alwaysVisible = true,
        masked = true,
        tooltip = "Destroy Fidget."%_t,
    }
    milestones.BeatLaserBoss =
    {
        position = vec2(655, 1225),
        icon = "data/textures/icons/milestones/laser-boss.png",
        lockedIcon = "data/textures/icons/milestones/laser-boss-locked.png",
        color = Rarity(RarityType.Legendary).color,
        alwaysVisible = true,
        masked = true,
        tooltip = "Destroy Project IHDTX."%_t,
    }
    milestones.BeatXsotanPrecursorBoss =
    {
        position = vec2(755, 1225),
        icon = "data/textures/icons/milestones/xsotan-precursor-boss.png",
        lockedIcon = "data/textures/icons/milestones/xsotan-precursor-boss-locked.png",
        color = Rarity(RarityType.Legendary).color,
        alwaysVisible = true,
        masked = true,
        tooltip = "Destroy the Xsotan Invasion Overseer."%_t,
    }

    -- ##### INTO THE RIFT ##### --
    milestones.IntoTheRift =
    {
        position = vec2(55, 1450),
        icon = "data/textures/icons/milestones/dlc-into-the-rift.png",
        lockedIcon = "data/textures/icons/milestones/dlc-into-the-rift-locked.png",
        color = Rarity(RarityType.Uncommon).color,
        alwaysVisible = true,
        connections =
        {
            {
                id = makeConnectionId(), lower = vec2(115, 1450), upper = vec2(885, 1550),
                texture = "data/textures/ui/player-profile/into-the-rift-connection.png",
                lockedTexture = "data/textures/ui/player-profile/into-the-rift-connection-locked.png"
            },
        },
        successors = {"IntoTheRiftStory", "RiftDepth75", "RiftDepth75SmallShip", "SaveAllScientists", "OverstayAfterTime", "RiftMissionMultiShips", "CoopRiftMission"},
        tooltip = "[DLC: Into The Rift] Enter a Rift."%_t,
    }
    milestones.RiftMissionMultiShips =
    {
        position = vec2(155, 1550),
        icon = "data/textures/icons/milestones/dlc-gang-up.png",
        lockedIcon = "data/textures/icons/milestones/dlc-gang-up-locked.png",
        color = Rarity(RarityType.Rare).color,
        alwaysVisible = false,
        tooltip = "[DLC: Into The Rift] Enter a Rift with 5 or more ships."%_t,
    }
    milestones.CoopRiftMission =
    {
        position = vec2(255, 1550),
        icon = "data/textures/icons/milestones/dlc-coop-rift.png",
        lockedIcon = "data/textures/icons/milestones/dlc-coop-rift-locked.png",
        color = Rarity(RarityType.Rare).color,
        alwaysVisible = false,
        tooltip = "[DLC: Into The Rift] Finish a Rift mission with a friend."%_t,
    }
    milestones.SaveAllScientists =
    {
        position = vec2(355, 1550),
        icon = "data/textures/icons/milestones/dlc-save-scientists.png",
        lockedIcon = "data/textures/icons/milestones/dlc-save-scientists-locked.png",
        color = Rarity(RarityType.Rare).color,
        alwaysVisible = false,
        masked = true,
        tooltip = "[DLC: Into The Rift] Save all the scientists."%_t,
    }
    milestones.IntoTheRiftStory =
    {
        position = vec2(455, 1550),
        icon = "data/textures/icons/milestones/dlc-into-the-rift-story.png",
        lockedIcon = "data/textures/icons/milestones/dlc-into-the-rift-story-locked.png",
        color = Rarity(RarityType.Exceptional).color,
        alwaysVisible = false,
        tooltip = "[DLC: Into The Rift] Finish the Into The Rift Storyline."%_t,
    }
    milestones.RiftDepth75 =
    {
        position = vec2(555, 1550),
        icon = "data/textures/icons/milestones/dlc-rift-depth-75.png",
        lockedIcon = "data/textures/icons/milestones/dlc-rift-depth-75-locked.png",
        color = Rarity(RarityType.Exotic).color,
        alwaysVisible = false,
        tooltip = "[DLC: Into The Rift] Finish a Rift with a depth of 75."%_t,
    }
    milestones.OverstayAfterTime =
    {
        position = vec2(655, 1550),
        icon = "data/textures/icons/milestones/dlc-overstay.png",
        lockedIcon = "data/textures/icons/milestones/dlc-overstay-locked.png",
        color = Rarity(RarityType.Legendary).color,
        alwaysVisible = false,
        tooltip = "[DLC: Into The Rift] Stay in a Rift for 15 Minutes after the swarm has arrived."%_t,
    }
    milestones.RiftDepth75SmallShip =
    {
        position = vec2(755, 1550),
        icon = "data/textures/icons/milestones/dlc-rift-depth-75-small-ship.png",
        lockedIcon = "data/textures/icons/milestones/dlc-rift-depth-75-small-ship-locked.png",
        color = Rarity(RarityType.Legendary).color,
        alwaysVisible = false,
        tooltip = "[DLC: Into The Rift] Finish a Rift with a depth of 75 in a single ship with 600kT mass or lower."%_t,
    }
    PlayerProfile.sanityCheck(milestones)

    return milestones
end

function PlayerProfile.sanityCheck(milestones)
    for name, milestone in pairs(milestones) do
        for _, successor in pairs(milestone.successors or {}) do
            if not milestones[successor] then
                eprint("PlayerProfile Milestone Successor Sanity Check Failed: '%s' has a successor '%s' that doesn't exist", name, successor)
            end
        end

        if milestone.successors and #milestone.successors > 0 then
            if not milestone.connections or #milestone.connections == 0 then
                eprint("PlayerProfile Milestone Successor Sanity Check Failed: '%s' has successors but no connections", name)
            end
        end

        if milestone.connections and #milestone.connections > 0 then
            if not milestone.successors or #milestone.successors == 0 then
                eprint("PlayerProfile Milestone Successor Sanity Check Failed: '%s' has connections but no successors", name)
            end
        end
    end
end

function PlayerProfile.sync(data_in)
    if onClient() then
        if not data_in then
            invokeServerFunction("sync")
        else
            self.data = data_in
            PlayerProfile.refresh()
        end
    else
        local player = Player()
        if Server():isOnline(player.index) then
            invokeClientFunction(player, "sync", self.data)
        end
    end
end
callable(PlayerProfile, "sync")

function PlayerProfile.restore(data)
    self.data = data
end

function PlayerProfile.secure()
    return self.data
end
