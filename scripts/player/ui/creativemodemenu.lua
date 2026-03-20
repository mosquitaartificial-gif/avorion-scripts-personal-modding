package.path = package.path .. ";data/scripts/lib/?.lua"

include("callable")
include("randomext")
include("weapontype")
local UpgradeGenerator = include("upgradegenerator")
local SectorFighterGenerator = include("sectorfightergenerator")
local TorpedoGenerator = include("torpedogenerator")
local CaptainGenerator = include("captaingenerator")
local SectorTurretGenerator = include("sectorturretgenerator")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace CreativeModeMenu
CreativeModeMenu = {}


function CreativeModeMenu.initialize()
    if not GameSettings().creativeModeCommandCenter then
        terminate()
        return
    end

    if onClient() then
        CreativeModeMenu.tab = ShipWindow():createTab("Creative Mode"%_t, "data/textures/icons/round-star.png", "Creative Mode Command Center"%_t)
        local tab = CreativeModeMenu.tab

        local lister = UIVerticalLister(Rect(tab.size), 10, 0)
        tab:createLabel(lister:nextRect(30), "Creative Mode Command Center"%_t, 28):setCenterAligned()

        local splitter = UIVerticalMultiSplitter(lister.rect, 10, 0, 3)

        local leftSplitter = UIHorizontalSplitter(splitter:partition(0), 10, 0, 0.5)
        leftSplitter.topSize = 410
        tab:createFrame(leftSplitter.top)
        tab:createFrame(Rect(leftSplitter.bottom.lower, vec2(leftSplitter.bottom.upper.x, leftSplitter.bottom.lower.y + 124)))


        local lister = UIVerticalLister(leftSplitter.top, 10, 10)
        local red = ColorRGB(1, 0.2, 0.2)

        -- crew
        tab:createLabel(lister:nextRect(20), "Crew"%_t, 20):setCenterAligned()

        local split = UIVerticalMultiSplitter(lister:nextRect(30), 10, 0, 3)
        CreativeModeMenu.createIconButton(tab, Rect(split:partition(0).topLeft, split:partition(2).bottomRight), "data/textures/icons/crew.png", "Add Crew /* Button */"%_t, "onAddCrewPressed")
        CreativeModeMenu.createIconButton(tab, split:partition(3), "data/textures/icons/captain.png", "Add Captain /* Button */"%_t, "onAddCaptainPressed")


        local split = UIVerticalMultiSplitter(lister:nextRect(30), 10, 0, 3)
        CreativeModeMenu.createIconButton(tab, split:partition(0), "data/textures/icons/helmet.png", "Add Pilots"%_t, "onAddPilotsPressed")
        CreativeModeMenu.createIconButton(tab, split:partition(1), "data/textures/icons/security.png", "Add Security"%_t, "onAddSecurityPressed")
        CreativeModeMenu.createIconButton(tab, split:partition(2), "data/textures/icons/bolter-gun.png", "Add Boarders"%_t, "onAddBoardersPressed")
        local button = CreativeModeMenu.createIconButton(tab, split:partition(3), "data/textures/icons/cross-mark.png", "Clear"%_t, "onClearCrewPressed")
        button.iconColor = red

--        lister:nextRect(10)

        -- guns, systems
        tab:createLabel(lister:nextRect(20), "Guns 'n' Systems"%_t, 20):setCenterAligned()
        local split = UIVerticalMultiSplitter(lister:nextRect(30), 10, 0, 3)
        local button = CreativeModeMenu.createIconButton(tab, split:partition(3), "data/textures/icons/cross-mark.png", "Clear Inventory"%_t, "onClearInventoryPressed")
        local split = UIVerticalMultiSplitter(Rect(split:partition(0).lower, split:partition(2).upper), 10, 0, 1)
        CreativeModeMenu.createIconButton(tab, split:partition(0), "data/textures/icons/turret.png", "Guns Guns Guns"%_t, "onAddGunsPressed")
        CreativeModeMenu.createIconButton(tab, split:partition(1), "data/textures/icons/circuitry.png", "Gimme Systems"%_t, "onAddSystemsPressed")
        button.iconColor = red

--        lister:nextRect(10)

        -- fighters
        tab:createLabel(lister:nextRect(20), "Fighters"%_t, 20):setCenterAligned()
        local split = UIVerticalMultiSplitter(lister:nextRect(30), 10, 0, 3)
        local rect = Rect(split:partition(0).lower, split:partition(1).upper)
        CreativeModeMenu.createIconButton(tab, split:partition(2), "data/textures/icons/mining.png", "Add Mining Fighters"%_t, "onMiningFightersPressed")
        CreativeModeMenu.createIconButton(tab, split:partition(3), "data/textures/icons/rock.png", "Add R-Mining Fighters"%_t, "onRMiningFightersPressed")

        local split = UIVerticalMultiSplitter(lister:nextRect(30), 10, 0, 3)
        rect.upper = split:partition(1).upper
        CreativeModeMenu.createIconButton(tab, rect, "data/textures/icons/fighter.png", "Add Armed Fighters"%_t, "onArmedFightersPressed")
        CreativeModeMenu.createIconButton(tab, split:partition(2), "data/textures/icons/recycle-arrows.png", "Add Salvaging Fighters"%_t, "onSalvagingFightersPressed")
        CreativeModeMenu.createIconButton(tab, split:partition(3), "data/textures/icons/scrap-metal.png", "Add R-Salvaging Fighters"%_t, "onRSalvagingFightersPressed")

        local split = UIVerticalMultiSplitter(lister:nextRect(30), 10, 0, 2)
        CreativeModeMenu.createIconButton(tab, split:partition(0), "data/textures/icons/repair.png", "Add Repair Fighters"%_t, "onAddRepairFightersPressed")
        CreativeModeMenu.createIconButton(tab, split:partition(1), "data/textures/icons/crew.png", "Add Boarding Shuttles"%_t, "onAddCrewShuttlesPressed")
        local button = CreativeModeMenu.createIconButton(tab, split:partition(2), "data/textures/icons/cross-mark.png", "Clear Hangar"%_t, "onClearHangarPressed")
        button.iconColor = red

--        lister:nextRect(10)

        -- torpedoes
        tab:createLabel(lister:nextRect(20), "Torpedoes"%_t, 20):setCenterAligned()
        local split = UIVerticalMultiSplitter(lister:nextRect(30), 10, 0, 3)
        local rect = Rect(split:partition(0).lower, split:partition(2).upper)
        CreativeModeMenu.createIconButton(tab, rect, "data/textures/icons/missile-pod.png", "Add Torpedoes"%_t, "onAddTorpedoesPressed")
        local button = CreativeModeMenu.createIconButton(tab, split:partition(3), "data/textures/icons/cross-mark.png", "Clear Torpedoes"%_t, "onClearTorpedoesPressed")
        button.iconColor = red

--        lister:nextRect(10)

        local lister = UIVerticalLister(leftSplitter.bottom, 10, 10)

        -- relations
        tab:createLabel(lister:nextRect(24), "Relations"%_t, 24):setCenterAligned()
        local split = UIVerticalMultiSplitter(lister:nextRect(30), 10, 0, 3)
        local relation = Relation()
        local button = CreativeModeMenu.createIconButton(tab, split:partition(0), "data/textures/icons/condor-emblem.png", "Ally"%_t, "onAllyPressed")
        relation.status = RelationStatus.Allies
        button.iconColor = relation.color
        local button = CreativeModeMenu.createIconButton(tab, split:partition(1), "data/textures/icons/shaking-hands.png", "Neutral"%_t, "onNeutralPressed")
        relation.status = RelationStatus.Neutral
        button.iconColor = relation.color
        local button = CreativeModeMenu.createIconButton(tab, split:partition(2), "data/textures/icons/ceasefire.png", "Ceasefire"%_t, "onCeasefirePressed")
        relation.status = RelationStatus.Ceasefire
        button.iconColor = relation.color
        local button = CreativeModeMenu.createIconButton(tab, split:partition(3), "data/textures/icons/crossed-rifles.png", "War"%_t, "onWarPressed")
        relation.status = RelationStatus.War
        button.iconColor = relation.color

        local split = UIVerticalMultiSplitter(lister:nextRect(30), 10, 0, 1)
        CreativeModeMenu.createIconButton(tab, split:partition(0), "data/textures/icons/arrow-up2.png", "Like"%_t, "onLikePressed")
        CreativeModeMenu.createIconButton(tab, split:partition(1), "data/textures/icons/arrow-down2.png", "Dislike"%_t, "onDislikePressed")


        -- goods
        local sortedGoods = {}
        for name, good in pairs(goods) do
            table.insert(sortedGoods, good)
        end

        function goodsByName(a, b) return a.name < b.name end
        table.sort(sortedGoods, goodsByName)


        local bigColumnIndex = 0
        local columnIndex = 0

        local rect = Rect(splitter:partition(1).lower, splitter:partition(3).upper)
        tab:createFrame(rect)
        local lister = UIVerticalLister(rect, 10, 10)

        local split = UIVerticalSplitter(lister:nextRect(20), 10, 0, 0.7)
        tab:createLabel(split.left, "Cargo"%_t, 20):setCenterAligned()
        CreativeModeMenu.stolenCargoCheckBox = tab:createCheckBox(split.right, "Mark as Stolen"%_t, "onStolenCargoChecked")

        local firstLetter
        local splitCount = 14
        local split = UIVerticalMultiSplitter(lister:nextRect(30), 10, 0, splitCount)
        for _, good in pairs(sortedGoods) do
            local first = string.sub(good.name, 1, 1)

            if first ~= firstLetter then
                tab:createLabel(split:partition(columnIndex), first, 20):setCenterAligned()
                columnIndex = columnIndex + 1
                if columnIndex > splitCount then
                    columnIndex = 0
                    split = UIVerticalMultiSplitter(lister:nextRect(30), 10, 0, splitCount)
                end
            end

            firstLetter = first

            CreativeModeMenu.createIconButton(tab, split:partition(columnIndex), good.icon, good.name, "onGoodsButtonPressed")
            columnIndex = columnIndex + 1
            if columnIndex > splitCount then
                columnIndex = 0
                split = UIVerticalMultiSplitter(lister:nextRect(30), 10, 0, splitCount)
            end
        end

        -- add clear cargo button
        if columnIndex == splitCount then
            split = UIVerticalMultiSplitter(lister:nextRect(30), 10, 0, splitCount)
        end

        local button = CreativeModeMenu.createIconButton(tab, split:partition(splitCount), "data/textures/icons/cross-mark.png", "Clear Cargo"%_t, "onClearCargoPressed")
        button.iconColor = red
    end
end

function CreativeModeMenu.getManagedCraft()
    if not CreativeModeMenu.managedCraftId then return end

    local craft = Entity(CreativeModeMenu.managedCraftId)
    if not craft then return end

    local player = Player()

    if craft.factionIndex == player.index then
        return craft
    elseif craft.factionIndex == player.allianceIndex then
        local alliance = player.alliance

        local requiredPrivileges = {AlliancePrivilege.ManageShips}
        for _, privilege in pairs(requiredPrivileges) do
            if not alliance:hasPrivilege(player.index, privilege) then
                player:sendChatMessage("", 1, "You don't have permission to do that in the name of your alliance."%_t)
                return
            end
        end

        return craft
    end
end

function CreativeModeMenu.updateClient(timeStep)
    if CreativeModeMenu.tab and CreativeModeMenu.tab.visible then
        CreativeModeMenu.setManagedCraft(ShipWindow().craftId)
    end
end

function CreativeModeMenu.setManagedCraft(id)
    if onClient() then
        invokeServerFunction("setManagedCraft", id)
        -- no return
    end

    CreativeModeMenu.managedCraftId = id
end
callable(CreativeModeMenu, "setManagedCraft")

function CreativeModeMenu.createIconButton(tab, rect, icon, tooltip, callback)
    local button = tab:createButton(rect, "", callback)
    button.icon = icon
    button.tooltip = tooltip

    return button
end

function CreativeModeMenu.onStolenCargoChecked()
end

function CreativeModeMenu.onAddCrewPressed()
    if onClient() then
        invokeServerFunction("onAddCrewPressed")
        return
    end

    local craft = CreativeModeMenu.getManagedCraft()
    if not craft then return end

    local minCrew = craft.idealCrew
    if not minCrew then return end

    local captain = craft:getCaptain()
    if captain then
        minCrew:setCaptain(captain)
    end

    craft.crew = minCrew
end
callable(CreativeModeMenu, "onAddCrewPressed")

function CreativeModeMenu.onAddCaptainPressed()
    if onClient() then
        invokeServerFunction("onAddCaptainPressed")
        return
    end

    local craft = CreativeModeMenu.getManagedCraft()
    if not craft then return end

    local generator = CaptainGenerator()
    craft:setCaptain(generator:generate())
end
callable(CreativeModeMenu, "onAddCaptainPressed")

function CreativeModeMenu.onAddPilotsPressed()
    if onClient() then
        invokeServerFunction("onAddPilotsPressed")
        return
    end

    local craft = CreativeModeMenu.getManagedCraft()
    if not craft then return end

    local crew = craft.crew
    if not valid(crew) then return end

    crew:add(10, CrewMan(CrewProfessionType.Pilot))
    craft.crew = crew
end
callable(CreativeModeMenu, "onAddPilotsPressed")

function CreativeModeMenu.onAddSecurityPressed()
    if onClient() then
        invokeServerFunction("onAddSecurityPressed")
        return
    end

    local craft = CreativeModeMenu.getManagedCraft()
    if not craft then return end

    local crew = craft.crew
    if not valid(crew) then return end

    crew:add(10, CrewMan(CrewProfessionType.Security))
    craft.crew = crew
end
callable(CreativeModeMenu, "onAddSecurityPressed")

function CreativeModeMenu.onAddBoardersPressed()
    if onClient() then
        invokeServerFunction("onAddBoardersPressed")
        return
    end

    local craft = CreativeModeMenu.getManagedCraft()
    if not craft then return end

    local crew = craft.crew
    if not valid(crew) then return end

    crew:add(10, CrewMan(CrewProfessionType.Attacker))
    craft.crew = crew
end
callable(CreativeModeMenu, "onAddBoardersPressed")

function CreativeModeMenu.onClearCrewPressed()
    if onClient() then
        invokeServerFunction("onClearCrewPressed")
        return
    end

    local craft = CreativeModeMenu.getManagedCraft()
    if not craft then return end

    craft.crew = Crew()
end
callable(CreativeModeMenu, "onClearCrewPressed")

function CreativeModeMenu.onAddGunsPressed()
    if onClient() then
        invokeServerFunction("onAddGunsPressed")
        return
    end

    local craft = CreativeModeMenu.getManagedCraft()
    if not craft then return end

    local craftFaction = Faction(craft.factionIndex)

    local x, y = Sector():getCoordinates()
    local rand = Random(Seed(tostring(random():getInt())))

    for j = 1, 10 do
        -- we want all types of turrets
        -- -> use a random type without adhering to galaxy distribution
        local type = WeaponTypes.getRandom(rand)
        local turret = SectorTurretGenerator():generate(x, y, nil, nil, type, nil)
        craftFaction:getInventory():add(InventoryTurret(turret))
    end
end
callable(CreativeModeMenu, "onAddGunsPressed")

function CreativeModeMenu.onAddSystemsPressed()
    if onClient() then
        invokeServerFunction("onAddSystemsPressed")
        return
    end

    local craft = CreativeModeMenu.getManagedCraft()
    if not craft then return end

    local craftFaction = Faction(craft.factionIndex)

    local generator = UpgradeGenerator()

    local player = Player()
    if player.ownsBlackMarketDLC then
        generator.blackMarketUpgradesEnabled = true
    end
    if player.ownsIntoTheRiftDLC then
        generator.intoTheRiftUpgradesEnabled = true
    end

    for i = 1, 10 do
        local upgrade = generator:generateSystem()
        craftFaction:getInventory():add(upgrade)
    end
end
callable(CreativeModeMenu, "onAddSystemsPressed")

function CreativeModeMenu.onClearInventoryPressed()
    if onClient() then
        invokeServerFunction("onClearInventoryPressed")
        return
    end

    local craft = CreativeModeMenu.getManagedCraft()
    if not craft then return end

    local craftFaction = Faction(craft.factionIndex)
    craftFaction:getInventory():clear()
end
callable(CreativeModeMenu, "onClearInventoryPressed")



function CreativeModeMenu.addFighterSquad(weaponType, squadName)
    local x, y = Sector():getCoordinates()
    local fighter = SectorFighterGenerator():generate(x, y, nil, nil, weaponType)

    CreativeModeMenu.addFighters(fighter, squadName)
end

function CreativeModeMenu.addFighters(fighter, squadName)
    squadName = squadName or "Script Squad"

    local craft = CreativeModeMenu.getManagedCraft()
    if not craft then return end

    local hangar = Hangar(craft.id)
    if not valid(hangar) then return end

    local squad = hangar:addSquad(squadName)
    if squad == -1 then return end

    hangar:setBlueprint(squad, fighter)

    for i = hangar:getSquadFighters(squad), hangar:getSquadMaxFighters(squad) - 1 do
        if hangar.freeSpace < fighter.volume then return end

        hangar:addFighter(squad, fighter)
    end
end

function CreativeModeMenu.onArmedFightersPressed()
    if onClient() then
        invokeServerFunction("onArmedFightersPressed")
        return
    end

    CreativeModeMenu.addFighterSquad(WeaponType.RailGun, "Railgun Squad")
end
callable(CreativeModeMenu, "onArmedFightersPressed")

function CreativeModeMenu.onMiningFightersPressed()
    if onClient() then
        invokeServerFunction("onMiningFightersPressed")
        return
    end

    CreativeModeMenu.addFighterSquad(WeaponType.MiningLaser, "Mining Squad")
end
callable(CreativeModeMenu, "onMiningFightersPressed")

function CreativeModeMenu.onRMiningFightersPressed()
    if onClient() then
        invokeServerFunction("onRMiningFightersPressed")
        return
    end

    CreativeModeMenu.addFighterSquad(WeaponType.RawMiningLaser, "R-Mining Squad")
end
callable(CreativeModeMenu, "onRMiningFightersPressed")

function CreativeModeMenu.onSalvagingFightersPressed()
    if onClient() then
        invokeServerFunction("onSalvagingFightersPressed")
        return
    end

    CreativeModeMenu.addFighterSquad(WeaponType.SalvagingLaser, "Salvaging Squad")
end
callable(CreativeModeMenu, "onSalvagingFightersPressed")

function CreativeModeMenu.onRSalvagingFightersPressed()
    if onClient() then
        invokeServerFunction("onRSalvagingFightersPressed")
        return
    end

    CreativeModeMenu.addFighterSquad(WeaponType.RawSalvagingLaser, "R-Salvaging Squad")
end
callable(CreativeModeMenu, "onRSalvagingFightersPressed")

function CreativeModeMenu.onAddRepairFightersPressed()
    if onClient() then
        invokeServerFunction("onAddRepairFightersPressed")
        return
    end

    CreativeModeMenu.addFighterSquad(WeaponType.RepairBeam, "Repair Squad")
end
callable(CreativeModeMenu, "onAddRepairFightersPressed")

function CreativeModeMenu.onAddCrewShuttlesPressed()
    if onClient() then
        invokeServerFunction("onAddCrewShuttlesPressed")
        return
    end

    local x, y = Sector():getCoordinates()
    local fighter = SectorFighterGenerator():generateCrewShuttle(x, y)
    CreativeModeMenu.addFighters(fighter, "Attacker Squad")
end
callable(CreativeModeMenu, "onAddCrewShuttlesPressed")

function CreativeModeMenu.onClearHangarPressed()
    if onClient() then
        invokeServerFunction("onClearHangarPressed")
        return
    end

    local craft = CreativeModeMenu.getManagedCraft()
    if not craft then return end

    local hangar = Hangar(craft.id)
    if not valid(hangar) then return end

    hangar:clear()
end
callable(CreativeModeMenu, "onClearHangarPressed")

function CreativeModeMenu.onAddTorpedoesPressed()
    if onClient() then
        invokeServerFunction("onAddTorpedoesPressed")
        return
    end

    local craft = CreativeModeMenu.getManagedCraft()
    if not craft then return end

    local launcher = TorpedoLauncher(craft.id)
    if not valid(launcher) then return end

    local shafts = {launcher:getShafts()}

    -- fill all present squads
    for _, shaft in pairs(shafts) do
        local torpedo = TorpedoGenerator():generate(x, y)

        for i = 1, 10 do
            launcher:addTorpedo(torpedo, shaft)
        end
    end

    for j = 1, 10 do
        local torpedo = TorpedoGenerator():generate(x, y)

        for i = 1, 5 do
            launcher:addTorpedo(torpedo)
        end
    end
end
callable(CreativeModeMenu, "onAddTorpedoesPressed")

function CreativeModeMenu.onClearTorpedoesPressed()
    if onClient() then
        invokeServerFunction("onClearTorpedoesPressed")
        return
    end

    local craft = CreativeModeMenu.getManagedCraft()
    if not craft then return end

    local launcher = TorpedoLauncher(craft.id)
    if not valid(launcher) then return end

    launcher:clear()
end
callable(CreativeModeMenu, "onClearTorpedoesPressed")



function CreativeModeMenu.getRelationFactions()
    local player = Player(callingPlayer)
    local craft = player.craft
    if not craft then return end

    local actor = Faction(craft.factionIndex)
    local selected = craft.selectedObject
    if not valid(selected) or not selected.factionIndex then
        player:sendChatMessage("", ChatMessageType.Error, "No object that belongs to an AI faction selected."%_T)
        return
    end

    local faction = Faction(selected.factionIndex)
    if not valid(faction) or not faction.isAIFaction then
        player:sendChatMessage("", ChatMessageType.Error, "No object that belongs to an AI faction selected."%_T)
        return
    end

    local relation = actor:getRelation(faction.index)
    if not relation or relation.isStatic or faction.staticRelationsToPlayers or faction.staticRelationsToAll or
            faction:hasStaticRelationsToFaction(actor.index) or faction.alwaysAtWar then
        player:sendChatMessage("", ChatMessageType.Error, "Relations with this faction can't be changed."%_T)
        return
    end

    return actor, faction
end

function CreativeModeMenu.setRelationStatus(status)
    local actor, faction = CreativeModeMenu.getRelationFactions()
    if not actor or not faction then return end

    setRelationStatus(actor, faction, status, true, true)
end

function CreativeModeMenu.changeRelationLevel(delta)
    local actor, faction = CreativeModeMenu.getRelationFactions()
    if not actor or not faction then return end

    changeRelations(actor, faction, delta)
end

function CreativeModeMenu.onAllyPressed()
    if onClient() then
        invokeServerFunction("onAllyPressed")
        return
    end

    CreativeModeMenu.setRelationStatus(RelationStatus.Allies)
end
callable(CreativeModeMenu, "onAllyPressed")

function CreativeModeMenu.onNeutralPressed()
    if onClient() then
        invokeServerFunction("onNeutralPressed")
        return
    end

    CreativeModeMenu.setRelationStatus(RelationStatus.Neutral)
end
callable(CreativeModeMenu, "onNeutralPressed")

function CreativeModeMenu.onCeasefirePressed()
    if onClient() then
        invokeServerFunction("onCeasefirePressed")
        return
    end

    CreativeModeMenu.setRelationStatus(RelationStatus.Ceasefire)
end
callable(CreativeModeMenu, "onCeasefirePressed")

function CreativeModeMenu.onWarPressed()
    if onClient() then
        invokeServerFunction("onWarPressed")
        return
    end

    CreativeModeMenu.setRelationStatus(RelationStatus.War)
end
callable(CreativeModeMenu, "onWarPressed")

function CreativeModeMenu.onLikePressed()
    if onClient() then
        invokeServerFunction("onLikePressed")
        return
    end

    CreativeModeMenu.changeRelationLevel(10000)
end
callable(CreativeModeMenu, "onLikePressed")

function CreativeModeMenu.onDislikePressed()
    if onClient() then
        invokeServerFunction("onDislikePressed")
        return
    end

    CreativeModeMenu.changeRelationLevel(-10000)
end
callable(CreativeModeMenu, "onDislikePressed")



function CreativeModeMenu.onGoodsButtonPressed(button, stolen, amount)
    if onClient() then
        amount = 1

        local keyboard = Keyboard()
        if keyboard:keyPressed(KeyboardKey.LShift) or keyboard:keyPressed(KeyboardKey.RShift) then
            amount = 10
        elseif keyboard:keyPressed(KeyboardKey.LControl) or keyboard:keyPressed(KeyboardKey.RControl) then
            amount = 100
        end
        invokeServerFunction("onGoodsButtonPressed", button.tooltip, CreativeModeMenu.stolenCargoCheckBox.checked, amount)
        return
    end

    local craft = CreativeModeMenu.getManagedCraft()
    if not craft then return end

    local name = button -- passed from the client
    local good = goods[name]:good()
    good.stolen = stolen

    craft:addCargo(good, amount)
end
callable(CreativeModeMenu, "onGoodsButtonPressed")

function CreativeModeMenu.onClearCargoPressed()
    if onClient() then
        invokeServerFunction("onClearCargoPressed")
        return
    end

    local craft = CreativeModeMenu.getManagedCraft()
    if not craft then return end

    for cargo, amount in pairs(craft:getCargos()) do
        craft:removeCargo(cargo, amount)
    end
end
callable(CreativeModeMenu, "onClearCargoPressed")
