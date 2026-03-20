
package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")
include("stringutility")

local TradingUtility = include ("tradingutility")
local CaptainUtility = include("captainutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace SectorShipOverview
SectorShipOverview = {}
local self = SectorShipOverview

if onClient() then

function SectorShipOverview.getUpdateInterval()
    return 1
end

function SectorShipOverview.initialize()
    local player = Player()
    player:registerCallback("onStateChanged", "onPlayerStateChanged")

    local res = getResolution()
    local size = vec2(350, 600)
    size.y = math.min(size.y, res.y - 200)
    local position = vec2(res.x - size.x - 20, 180)

    local rect = Rect(position, position + size )

    self.window = Hud():createWindow(rect)
    self.window.caption = "Sector"%_t
    self.window.moveable = true
    self.window.showCloseButton = true

    self.iconColumnWidth = 25
    self.rowHeight = 25
    self.iconsPerRow = 11

    self.tabbedWindow = self.window:createTabbedWindow(Rect(vec2(10, 10), size - 10))
    SectorShipOverview.buildOverviewUI()
    SectorShipOverview.buildGoodsUI()
    SectorShipOverview.buildCrewUI()
    SectorShipOverview.buildMissionUI()

    if GameSettings().devMode then
        SectorShipOverview.buildITRObjectUI()
    end

    self.show()
    self.hide()

    self.lastActiveTab = self.tabbedWindow:getActiveTab().index

    self.refreshOverviewList()
    self.refreshGoodsList()
    self.refreshCrewList()
    self.refreshMissionList()

    if GameSettings().devMode then
        self.refreshITRList()
    end
end

function SectorShipOverview.buildOverviewUI()
    self.overviewTab = self.tabbedWindow:createTab("Overview"%_t, "data/textures/icons/ship.png", "Overview"%_t)
    local hsplit = UIHorizontalSplitter(Rect(self.overviewTab.size), 0, 0, 0.0)
    self.overviewList = self.overviewTab:createListBoxEx(hsplit.bottom)
    self.overviewList.columns = 3
    self.overviewList.rowHeight = self.rowHeight
    self.overviewList:setColumnWidth(0, self.iconColumnWidth)
    self.overviewList:setColumnWidth(1, self.overviewList.width - 2 * self.iconColumnWidth)
    self.overviewList.onSelectFunction = "onEntrySelected"
end

function SectorShipOverview.buildGoodsUI()
    self.goodsTab = self.tabbedWindow:createTab("Goods"%_t, "data/textures/icons/procure-command.png", "Goods"%_t)
    local hsplit = UIHorizontalSplitter(Rect(self.goodsTab.size), 0, 0, 0.045)
    local vsplit = UIVerticalSplitter(hsplit.top, 0, 0, 0.5)
    local supplyLabel = self.goodsTab:createLabel(vsplit.left, "[SUPPLY]"%_t, 12)
    supplyLabel:setTopAligned()
    local demandLabel = self.goodsTab:createLabel(vsplit.right, "[DEMAND]"%_t, 12)
    demandLabel:setTopAligned()

    self.goodsList = self.goodsTab:createListBoxEx(hsplit.bottom)
    local numColumns = self.iconsPerRow + 2 -- the first and the last column don't get icons
    self.goodsList.columns = numColumns
    self.goodsList.rowHeight = self.rowHeight

    for i = 1, numColumns do
        self.goodsList:setColumnWidth(0, self.iconColumnWidth)
    end

    self.goodsList.onSelectFunction = "onEntrySelected"
end

function SectorShipOverview.buildCrewUI()
    self.crewTab = self.tabbedWindow:createTab("Crew"%_t, "data/textures/icons/crew.png", "Crew"%_t)
    local hsplit = UIHorizontalSplitter(Rect(self.crewTab.size), 0, 0, 0.0)
    self.crewList = self.crewTab:createListBoxEx(hsplit.bottom)
    local numColumns = self.iconsPerRow + 2 -- the first and the last column don't get icons
    self.crewList.columns = numColumns
    self.crewList.rowHeight = self.rowHeight

    for i = 1, numColumns do
        self.crewList:setColumnWidth(0, self.iconColumnWidth)
    end

    self.stationsOfferingCrew = 0
    self.crewRowsAdded = 0
    self.crewList.onSelectFunction = "onEntrySelected"
end

function SectorShipOverview.buildMissionUI()
    self.missionTab = self.tabbedWindow:createTab("Bulletin Boards"%_t, "data/textures/icons/wormhole.png", "Bulletin Boards"%_t)
    local hsplit = UIHorizontalSplitter(Rect(self.missionTab.size), 0, 0, 0.0)
    self.missionList = self.missionTab:createListBoxEx(hsplit.bottom)
    local numColumns = self.iconsPerRow + 2 -- the first and the last column don't get icons
    self.missionList.columns = numColumns
    self.missionList.rowHeight = self.rowHeight

    for i = 1, numColumns do
        self.missionList:setColumnWidth(0, self.iconColumnWidth)
    end

    self.missionList.onSelectFunction = "onEntrySelected"
end

function SectorShipOverview.buildITRObjectUI()
    self.itrTab = self.tabbedWindow:createTab("ITR", "data/textures/icons/rift-objective-fightswarm.png", "ITR Objects\nDev Gameplay Only!")
    local hsplit = UIHorizontalSplitter(Rect(self.itrTab.size), 0, 0, 0.0)
    self.itrList = self.itrTab:createListBoxEx(hsplit.bottom)
    self.itrList.columns = 2
    self.itrList.rowHeight = self.rowHeight
    self.itrList:setColumnWidth(0, self.iconColumnWidth)
    self.itrList:setColumnWidth(1, self.itrList.width - 2 * self.iconColumnWidth)
    self.itrList.onSelectFunction = "onEntrySelected"
end

function SectorShipOverview.updateClient(timeStep)
    if not self.window.visible then return end

    local activeTab = self.tabbedWindow:getActiveTab().index

    if activeTab == self.overviewTab.index then -- continously refresh this tab since it shows ships that might jump in our out
        local scrollPosition = self.overviewList.scrollPosition
        self.refreshOverviewList()
        self.overviewList.scrollPosition = scrollPosition

    elseif activeTab == self.goodsTab.index then
        if self.lastActiveTab ~= activeTab then  -- only refresh the other tabs when they are selected (they only show stations)
            self.refreshGoodsList()
        end

    elseif activeTab == self.crewTab.index then
        if self.lastActiveTab ~= activeTab then
            self.refreshCrewList()
        end

        if self.stationsOfferingCrew > self.crewRowsAdded then -- sometimes crewboard takes a while to refresh, so we just try again if we didn't get enough crew
            self.stationsOfferingCrew = 0
            self.crewRowsAdded = 0
            self.refreshCrewList()
        end

    elseif activeTab == self.missionTab.index then
        if self.lastActiveTab ~= activeTab then
            self.refreshMissionList()
        end
    end

    if GameSettings().devMode then
        if activeTab == self.itrTab.index then
            if self.lastActiveTab ~= activeTab then
                self.refreshITRList()
            end
        end
    end

    self.lastActiveTab = activeTab
end

function SectorShipOverview.collectEntities()
    local player = Player()
    local sector = Sector()

    local stationList = {header = "Stations"%_t, entries = {}, iconType = ListBoxEntryType.PixelIcon}
    local shipList = {header = "Ships"%_t, entries = {}, iconType = ListBoxEntryType.PixelIcon}
    local gateList = {header = "Other"%_t, entries = {}, iconType = ListBoxEntryType.PixelIcon}
    local asteroidList = {entries = {}, iconType = ListBoxEntryType.Icon}
    local lists = {stationList, shipList, gateList, asteroidList}

    local selectionGroups = SectorShipOverview.getSelectionGroupTable(player)

    -- collect stations
    local stations = {sector:getEntitiesByType(EntityType.Station)}
    for _, entity in pairs(stations) do
        if entity:getValue("inconspicuous_indicator") then goto continue end

        local name = entity.translatedTitle or ""
        local icon = ""

        local iconComponent = EntityIcon(entity)
        if iconComponent then icon = iconComponent.icon end

        if name == "" then
            name = entity.typename %_t .. " - " .. (entity.name or "<No Name>"%_t)
        else
            name = name %_t .. " - " .. (entity.name or "<No Name>"%_t)
        end

        local group = SectorShipOverview.getGroupString(selectionGroups, entity.factionIndex, entity.name)

        table.insert(stationList.entries, {entity = entity, icon = icon, name = name, faction = entity.factionIndex or 0, group = group})

        ::continue::
    end

    -- collect ships
    local ships = {sector:getEntitiesByType(EntityType.Ship)}
    for _, entity in pairs(ships) do
        if entity:getValue("inconspicuous_indicator") then goto continue end

        local name = entity.translatedTitle or ""
        local icon = ""

        if player.craftIndex == entity.id then
            icon = "data/textures/icons/pixel/player.png"
        else
            local iconComponent = EntityIcon(entity)
            if iconComponent then icon = iconComponent.icon end
        end

        if name == "" then
            name = entity.typename %_t .. " - " .. (entity.name or "<No Name>"%_t)
        else
            name = name %_t .. " - " .. (entity.name or "<No Name>"%_t)
        end

        local group = SectorShipOverview.getGroupString(selectionGroups, entity.factionIndex, entity.name)

        table.insert(shipList.entries, {entity = entity, icon = icon, name = name, faction = entity.factionIndex or 0, group = group})

        ::continue::
    end

    -- collect all other objects
    local gates = {sector:getEntitiesByComponent(ComponentType.WormHole)}
    for _, entity in pairs(gates) do
        if entity:getValue("inconspicuous_indicator") then goto continue end

        local name = ""
        local icon = ""

        if entity:hasComponent(ComponentType.Plan) then
            name = entity.translatedTitle

            local iconComponent = EntityIcon(entity)
            if iconComponent then icon = iconComponent.icon end
        else
            name = "Wormhole"%_t
        end

        local group = SectorShipOverview.getGroupString(selectionGroups, entity.factionIndex, entity.name)

        table.insert(gateList.entries, {entity = entity, icon = icon, name = name, faction = 0, group = group})

        ::continue::
    end

    -- teleporter of rrc
    local otherEntities = {sector:getEntitiesByScriptValue("sector_overview_icon")}
    for _, entity in pairs(otherEntities) do
        local name = entity.translatedTitle

        local icon = entity:getValue("sector_overview_icon")
        local group = SectorShipOverview.getGroupString(selectionGroups, entity.factionIndex, entity.name)

        table.insert(gateList.entries, {entity = entity, icon = icon, name = name, faction = entity.factionIndex or 0, group = group})

        ::continue::
    end


    -- claimed asteroids
    local claimedAsteroids = {sector:getEntitiesByScript("data/scripts/entity/sellobject.lua")}
    for _, entity in pairs(claimedAsteroids) do
        if entity:getValue("inconspicuous_indicator") then goto continue end

        local name = "Claimed Asteroid"%_t

        local group = SectorShipOverview.getGroupString(selectionGroups, entity.factionIndex, entity.name)

        table.insert(gateList.entries, {entity = entity, icon = "data/textures/icons/pixel/flying-flag.png", name = name, faction = entity.factionIndex or 0, group = group})

        ::continue::
    end

    -- marker buoys
    local markerBuoys = {sector:getEntitiesByScript("data/scripts/entity/markerbuoy.lua")}
    for _, entity in pairs(markerBuoys) do
        local _, data = entity:invokeFunction("data/scripts/entity/markerbuoy.lua", "getData")

        -- use the first line with characters if there are multiple lines
        local text
        local _, interactionPossible = entity:invokeFunction("data/scripts/entity/markerbuoy.lua", "interactionPossible")

        if interactionPossible then
            text = data.text:trim():split("\n")[1]
        end

        if text and text ~= "" then
            text = " - " .. text
        else
            text = ""
        end

        local name = entity.title .. text

        local icon = "data/textures/icons/pixel/marker.png"
        if data.icon ~= "" then
            icon = data.icon
        end

        local group = SectorShipOverview.getGroupString(selectionGroups, entity.factionIndex, entity.name)

        table.insert(gateList.entries, {entity = entity, icon = icon, name = name, faction = entity.factionIndex or 0, group = group, iconColor = Color(data.color)})

        ::continue::
    end

    -- message beacons
    local messageBeacons = {sector:getEntitiesByScript("data/scripts/entity/messagebeacon.lua")}
    for _, entity in pairs(messageBeacons) do
        local _, text = entity:invokeFunction("data/scripts/entity/messagebeacon.lua", "getText")

        -- no permission check needed here as all players can see the message
        text = text:trim():split("\n")[1]

        if text and text ~= "" then
            text = " - " .. text
        else
            text = ""
        end

        local name = entity.title .. text

        local icon = "data/textures/icons/pixel/marker.png"

        local group = SectorShipOverview.getGroupString(selectionGroups, entity.factionIndex, entity.name)

        table.insert(gateList.entries, {entity = entity, icon = icon, name = name, faction = entity.factionIndex or 0, group = group})

        ::continue::
    end

    -- sector renaming beacons
    local sectorRenamingBeacons = {sector:getEntitiesByScript("data/scripts/entity/sectorrenamingbeacon.lua")}
    for _, entity in pairs(sectorRenamingBeacons) do
        local _, text = entity:invokeFunction("data/scripts/entity/beacon.lua", "getText")

        -- no permission check needed here as all players can see the message
        text = text:trim():split("\n")[1]

        if text and text ~= "" then
            text = " - " .. text
        else
            text = ""
        end

        local name = entity.title .. text

        local icon = "data/textures/icons/pixel/marker.png"

        local group = SectorShipOverview.getGroupString(selectionGroups, entity.factionIndex, entity.name)

        table.insert(gateList.entries, {entity = entity, icon = icon, name = name, faction = entity.factionIndex or 0, group = group})

        ::continue::
    end

    -- sort to make it easier to read
    for _, list in pairs(lists) do
        table.sort(list.entries, function(a, b)
            if a.faction == b.faction then
                if a.icon == b.icon then
                    if a.name == b.name then
                        return a.entity.id.string < b.entity.id.string
                    end
                    return a.name < b.name
                end
                return a.icon < b.icon
            end
            return a.faction < b.faction
        end)
    end

    local selected = self.overviewList.selectedValue
    local scrollPosition = self.overviewList.scrollPosition

    return lists
end

-- headers are not translated as this is only for debugging
function SectorShipOverview.collectITREntities()
    local renderer = UIRenderer()

    local primaryList = {header = "Primary Objective Items", entries = {}, icon = "data/textures/icons/pixel/mission-white.png"}
    local smallTreasureList = {header = "Small Treasures", entries = {}, icon = "data/textures/icons/pixel/crate.png"}
    local mediumTreasureList = {header = "Medium Treasures", entries = {}, icon = "data/textures/icons/pixel/crate.png"}
    local claimableWreckageList = {header = "Claimable Wreckages", entries = {}, icon = "data/textures/icons/pixel/wreckage.png"}
    local stashList = {header = "Stashes", entries = {}, icon = "data/textures/icons/pixel/container.png"}
    local cargoStashList = {header = "Cargo Stashes", entries = {}, icon = "data/textures/icons/pixel/container.png"}
    local batteryStashList = {header = "Battery Stashes", entries = {}, icon = "data/textures/icons/pixel/container.png"}
    local weaponChamberList = {header = "Weapon Chambers", entries = {}, icon = "data/textures/icons/pixel/attack.png"}
    local weaponChamberSwitchList = {header = "Weapon Chambers Switches", entries = {}, icon = "data/textures/icons/pixel/attack.png"}
    local inactiveGateList = {header = "Inactive Gates", entries = {}, icon = "data/textures/icons/pixel/gate.png"}
    local valuablesDetectorBeaconList = {header = "Valuable Object Detector Beacons", entries = {}, icon = "data/textures/icons/pixel/credits.png"}
    local timeDeviceList = {header = "Time Devices", entries = {}, icon = "data/textures/icons/pixel/loop.png"}
    local scannableObjectList = {header = "Scannable Objects", entries = {}, icon = "data/textures/icons/pixel/civil-ship.png"}
    local xsotanLoreObjectList = {header = "Xsotan Lore Objects", entries = {}, icon = "data/textures/icons/pixel/vortex.png"}
    local landmarkList = {header = "Landmarks", entries = {}, icon = "data/textures/icons/pixel/monolith.png"}
    local platformList = {header = "Platforms", entries = {}, icon = "data/textures/icons/pixel/shipyard1.png"}
    local minefieldEmpList = {header = "Mine Field EMPs", entries = {}, icon = "data/textures/icons/pixel/persecutor.png"}
    local secondaryList = {header = "Secondary Objective Items", entries = {}, icon = "data/textures/icons/pixel/flag.png"}

    for _, entity in pairs({Sector():getEntities()}) do
        local entityColor = entity:getValue("highlight_color") or entity:getValue("valuable_object") or renderer:getEntityTargeterColor(entity)

        if entity:hasScript("wreckagetoship.lua") then
            table.insert(claimableWreckageList.entries, {id = entity.id, color = entityColor})

        elseif entity:hasScript("stash.lua") then
            table.insert(stashList.entries, {id = entity.id, color = entityColor})

        elseif entity:hasScript("cargostash.lua") then
            table.insert(cargoStashList.entries, {id = entity.id, color = entityColor})

        elseif entity:hasScript("valuablesdetectorbeacon.lua") then
            table.insert(valuablesDetectorBeaconList.entries, {id = entity.id, color = entityColor})

        elseif entity:hasScript("itrstoryresetbeacon.lua") then
            table.insert(timeDeviceList.entries, {id = entity.id, color = entityColor})

        elseif entity:hasScript("xsotanloreobject.lua") then
            table.insert(xsotanLoreObjectList.entries, {id = entity.id, color = entityColor})

        elseif entity:hasScript("weaponchamber.lua") then
            table.insert(weaponChamberList.entries, {id = entity.id, color = entityColor})

        elseif entity:hasScript("weaponchamberswitch.lua") then
            table.insert(weaponChamberSwitchList.entries, {id = entity.id, color = entityColor})

        elseif entity:hasScript("batterystash.lua") then
            table.insert(batteryStashList.entries, {id = entity.id, color = entityColor})

        elseif entity:hasScript("battery.lua") then
            table.insert(batteryStashList.entries, {id = entity.id, color = entityColor})

        elseif entity:hasScript("inactivegate.lua")
            or entity:hasScript("inactivegateactivator.lua") then
                table.insert(inactiveGateList.entries, {id = entity.id, color = entityColor})

        elseif entity:hasScript("attackplatform.lua")
            or entity:hasScript("protectionplatform.lua")
            or entity:hasScript("repairplatform.lua") then
                table.insert(platformList.entries, {id = entity.id, color = entityColor})

        elseif entity:getValue("secondary_objective_xsotan_breeder")
            or entity:getValue("secondary_objective_scannable")
            or entity:getValue("secondary_objective_crystal_asteroid")
            or entity:getValue("secondary_objective_wreckage") then
                table.insert(secondaryList.entries, {id = entity.id, color = entityColor})

        elseif entity:hasScript("scannableobject.lua") then
                table.insert(scannableObjectList.entries, {id = entity.id, color = entityColor})

        elseif entity:hasScript("minefieldemp.lua") then
            table.insert(minefieldEmpList.entries, {id = entity.id, color = entityColor})

        elseif entity:getValue("small_treasure") then
            table.insert(smallTreasureList.entries, {id = entity.id, color = entityColor})

        elseif entity:getValue("medium_treasure") then
            table.insert(mediumTreasureList.entries, {id = entity.id, color = entityColor})

        elseif entity:getValue("riftsector_landmark") then
            table.insert(landmarkList.entries, {id = entity.id, color = entityColor})

        elseif entity:getValue("collect_resources_asteroid")
            or entity:getValue("larva_batch")
            or entity:getValue("combat_objective_boss")
            or entity:hasScript("rescueobjectivedialog.lua")
            or entity:hasScript("shelterasteroidbehavior.lua")
            or entity:getValue("rescue_wreckage")
            or entity:getValue("rescue_container")
            or entity:hasScript("salvageobjectivewreckage.lua")
            or entity:hasScript("researchprobe.lua") then
                table.insert(primaryList.entries, {id = entity.id, color = entityColor})
        end
    end

    local itrObjectList = {
        primaryList,
        smallTreasureList,
        mediumTreasureList,
        claimableWreckageList,
        stashList,
        cargoStashList,
        valuablesDetectorBeaconList,
        timeDeviceList,
        scannableObjectList,
        xsotanLoreObjectList,
        weaponChamberList,
        weaponChamberSwitchList,
        batteryStashList,
        minefieldEmpList,
        inactiveGateList,
        platformList,
        landmarkList,
        secondaryList
    }

    return itrObjectList

end

function SectorShipOverview.refreshOverviewList()
    local lists = self.collectEntities()
    local player = Player()

    self.overviewList:clear()

    local white = ColorRGB(1, 1, 1)

    local renderer = UIRenderer()

    for _, list in pairs(lists) do
        if #list.entries > 0 then
            if list.header then
                self.overviewList:addRow(nil, "", "--- " .. list.header .. " ---")
            end

            for _, entry in pairs(list.entries) do

                local entity = entry.entity
                local color

                if entity:getValue("sector_overview_color") then
                    color = Color(entity:getValue("sector_overview_color"))
                else
                    color = renderer:getEntityTargeterColor(entity)
                end

                local iconColor = white
                if entry.iconColor then
                    iconColor = entry.iconColor
                end

                self.overviewList:addRow(entity.id.string)
                self.overviewList:setEntry(0, self.overviewList.rows - 1, entry.icon, false, false, iconColor)
                self.overviewList:setEntry(1, self.overviewList.rows - 1, entry.name, false, false, color)
                self.overviewList:setEntry(2, self.overviewList.rows - 1, entry.group, false, false, white)

                self.overviewList:setEntryType(0, self.overviewList.rows - 1, list.iconType or ListBoxEntryType.PixelIcon)
            end

            self.overviewList:addRow()
        end
    end

    if player.selectedObject then
        self.overviewList:selectValueNoCallback(player.selectedObject.string)
    end

    self.overviewList.scrollPosition = scrollPosition

end

function SectorShipOverview.refreshGoodsList()
    local lists = self.collectEntities()
    local stationList = lists[1]
    local player = Player()

    self.goodsList:clear()

    local white = ColorRGB(1, 1, 1)
    local buyColor = ColorRGB(1, 0.8, 0.7)
    local sellColor = ColorRGB(0.8, 0.8, 1)

    local renderer = UIRenderer()

    for _, entry in pairs(stationList.entries) do

        local entity = entry.entity
        local color = renderer:getEntityTargeterColor(entity)

        local sellable, buyable = TradingUtility.getBuyableAndSellableGoods(entity, nil, nil, player)

        local soldGoods = {}
        for _, good in pairs(buyable) do
            table.insert(soldGoods, good.good)
        end

        local goodsInDemand = {}
        for _, good in pairs(sellable) do
            table.insert(goodsInDemand, good.good)
        end

        -- supply
        if #soldGoods > 0 or #goodsInDemand > 0 then
            self.goodsList:addRow(entity.id.string)
            self.goodsList:setEntry(0, self.goodsList.rows - 1, entry.icon, false, false, white, self.goodsList.width - 2 * self.iconColumnWidth)
            self.goodsList:setEntry(1, self.goodsList.rows - 1, entry.name, false, false, color, self.goodsList.width - 2 * self.iconColumnWidth)
            self.goodsList:setEntry(11, self.goodsList.rows - 1, entry.group, false, false, white, self.goodsList.width - 2 * self.iconColumnWidth)
            self.goodsList:setEntryType(0, self.goodsList.rows - 1, ListBoxEntryType.PixelIcon)
        end

        if #soldGoods > 0 or #goodsInDemand > 0 then
            local supplyIcons = {}
            local supplyTooltips = {}
            for _, good in pairs(soldGoods) do
                table.insert(supplyTooltips, good.name % _t)
                table.insert(supplyIcons, good.icon)
            end

            local demandIcons = {}
            local demandTooltips = {}
            for _, good in pairs(goodsInDemand) do
                table.insert(demandTooltips, good.name % _t)
                table.insert(demandIcons, good.icon)
            end

            self.goodsList:addRow(entity.id.string)

            local length = #supplyIcons
            if #demandIcons > length then
                length = #demandIcons
            end

            local column = 1

            for i = 1, length do
                local demandColumn = column + 6
                if i < #supplyIcons + 1 then
                    self.goodsList:setEntry(column, self.goodsList.rows - 1, supplyIcons[i], false, false, sellColor, 0)
                    self.goodsList:setEntryType(column, self.goodsList.rows - 1, ListBoxEntryType.Icon)
                    self.goodsList:setEntryTooltip(column, self.goodsList.rows - 1, supplyTooltips[i])
                end

                if i < #demandIcons + 1 then
                    self.goodsList:setEntry(demandColumn, self.goodsList.rows - 1, demandIcons[i], false, false, buyColor, 0)
                    self.goodsList:setEntryType(demandColumn, self.goodsList.rows - 1, ListBoxEntryType.Icon)
                    self.goodsList:setEntryTooltip(demandColumn, self.goodsList.rows - 1, demandTooltips[i])
                end

                column = column + 1

                if i % math.floor(self.iconsPerRow/2) == 0 and length > i then -- 5 icons fit into one row
                    self.goodsList:addRow(entity.id.string)
                    column = 1
                end
            end
        end
    end

    if player.selectedObject then
        self.goodsList:selectValueNoCallback(player.selectedObject.string)
    end

    self.goodsList.scrollPosition = scrollPosition
end

function SectorShipOverview.refreshCrewList()
    local lists = self.collectEntities()
    local stationList = lists[1]
    local player = Player()

    self.crewList:clear()

    local white = ColorRGB(1, 1, 1)

    local renderer = UIRenderer()

    local simplifiedIcons = {}
    -- colors are original icon colors
    -- icons themselves have to be white as IconRenderer calculates alpha and darkens colors in the process
    simplifiedIcons[CaptainUtility.ClassType.Commodore] = {path = "data/textures/icons/captain-commodore.png", color = ColorRGB(0, 0.74, 0.74)}
    simplifiedIcons[CaptainUtility.ClassType.Smuggler] = {path = "data/textures/icons/captain-smuggler.png", color = ColorRGB(0.78, 0.03, 0.75)}
    simplifiedIcons[CaptainUtility.ClassType.Merchant] = {path = "data/textures/icons/captain-merchant.png", color = ColorRGB(0.5, 0.8, 0)}
    simplifiedIcons[CaptainUtility.ClassType.Miner] = {path = "data/textures/icons/captain-miner.png", color = ColorRGB(0.5, 0.8, 0)}
    simplifiedIcons[CaptainUtility.ClassType.Scavenger] = {path = "data/textures/icons/captain-scavenger.png", color = ColorRGB(0.1, 0.5, 1)}
    simplifiedIcons[CaptainUtility.ClassType.Explorer] = {path = "data/textures/icons/captain-explorer.png", color = ColorRGB(1, 0.88, 0.04)}
    simplifiedIcons[CaptainUtility.ClassType.Daredevil] = {path = "data/textures/icons/captain-daredevil.png", color = ColorRGB(0.9, 0.1, 0.1)}
    simplifiedIcons[CaptainUtility.ClassType.Scientist] = {path = "data/textures/icons/captain-scientist.png", color = ColorRGB(1, 0.47, 0)}
    simplifiedIcons[CaptainUtility.ClassType.Hunter] = {path = "data/textures/icons/captain-hunter.png", color = ColorRGB(1, 0.43, 0.77)}

    local classProperties = CaptainUtility.ClassProperties()

    for _, entry in pairs(stationList.entries) do

        local entity = entry.entity
        local color = renderer:getEntityTargeterColor(entity)

        if not entity:hasScript("data/scripts/entity/crewboard.lua") then return end

        self.stationsOfferingCrew = self.stationsOfferingCrew + 1

        local ok, crew, captain = entity:invokeFunction("data/scripts/entity/crewboard.lua", "getAvailableCrewAndCaptain")

        if not crew and not captain then return end

        local captainIcons = {}
        local captainTooltip = ""

        if captain then
            if captain.primaryClass == 0 then
                table.insert(captainIcons, {path = "data/textures/icons/captain-noclass.png", color = ColorRGB(1, 1, 1)})
                captainTooltip = "Captain [no class"%_t
            else
                table.insert(captainIcons, simplifiedIcons[captain.primaryClass])
                captainTooltip = "Captain ["%_t .. classProperties[captain.primaryClass].displayName % _t
            end

            if captain.secondaryClass and captain.secondaryClass ~= 0 then
                table.insert(captainIcons, simplifiedIcons[captain.secondaryClass])
                captainTooltip = captainTooltip .. ", " .. classProperties[captain.secondaryClass].displayName % _t
            end

            captainTooltip = captainTooltip .. "]"
        end

        local icons = {}
        local tooltips = {}

        for _, crewMember in pairs(crew) do
            local professionNumber = crewMember.profession
            local profession = CrewProfession(professionNumber)
            table.insert(icons, profession.icon)
            table.insert(tooltips, profession:name(profession) % _t)
        end

        if captain or #icons > 0 then
            self.crewList:addRow(entity.id.string)
            self.crewList:setEntry(0, self.crewList.rows - 1, entry.icon, false, false, white, self.crewList.width - 2 * self.iconColumnWidth)
            self.crewList:setEntryType(0, self.crewList.rows - 1, ListBoxEntryType.PixelIcon)

            self.crewList:setEntry(1, self.crewList.rows - 1, entry.name, false, false, color, self.crewList.width - 2 * self.iconColumnWidth)
            self.crewList:setEntryType(1, self.crewList.rows - 1, ListBoxEntryType.Text)

            self.crewList:setEntry(11, self.crewList.rows - 1, entry.group, false, false, white, self.crewList.width - 2 * self.iconColumnWidth)

            self.crewRowsAdded = self.crewRowsAdded + 1
            self.crewList:addRow(entity.id.string)
            for i = 1, #icons do
                if i == 1 then
                    if captain then
                        self.crewList:setEntry(i, self.crewList.rows - 1, captainIcons[i].path, false, false, captainIcons[i].color, 0)
                    else
                        self.crewList:setEntry(i, self.crewList.rows - 1, "data/textures/icons/nothing.png", false, false, white, 0)
                    end

                    self.crewList:setEntryType(i, self.crewList.rows - 1, ListBoxEntryType.Icon)
                    self.crewList:setEntryTooltip(i, self.crewList.rows - 1, captainTooltip)
                else
                    self.crewList:setEntry(i, self.crewList.rows - 1, icons[i], false, false, white, 0)
                    self.crewList:setEntryType(i, self.crewList.rows - 1, ListBoxEntryType.Icon)
                    self.crewList:setEntryTooltip(i, self.crewList.rows - 1, tooltips[i])
                end
            end
        end
    end

    if player.selectedObject then
        self.crewList:selectValueNoCallback(player.selectedObject.string)
    end

    self.crewList.scrollPosition = scrollPosition
end

function SectorShipOverview.refreshMissionList()
    local lists = self.collectEntities()
    local stationList = lists[1]
    local player = Player()

    self.missionList:clear()

    local white = ColorRGB(1, 1, 1)
    local renderer = UIRenderer()

    for _, entry in pairs(stationList.entries) do

        local entity = entry.entity
        local color = renderer:getEntityTargeterColor(entity)

        local missions = {}

        if entity:hasScript("dlc/rift/entity/riftresearchcenter.lua") and player.ownsIntoTheRiftDLC then
            _, missions = entity:invokeFunction("dlc/rift/entity/riftresearchcenter.lua", "getDisplayedBulletins")
        elseif entity:hasScript("data/scripts/entity/bulletinboard.lua") then
            _, missions = entity:invokeFunction("data/scripts/entity/bulletinboard.lua", "getDisplayedBulletins")
        else
            goto continue
        end

        if not missions then goto continue end

        local icons = {}
        local tooltips = {}
        for _, mission in pairs(missions) do
            if mission.icon then
                table.insert(icons, mission.icon)
            else
                table.insert(icons, "data/textures/icons/basic-mission-marker.png")
            end

            table.insert(tooltips, mission.brief % _t % mission.formatArguments)
        end

        if #tooltips > 0 then
            self.missionList:addRow(entity.id.string)
            self.missionList:setEntry(0, self.missionList.rows - 1, entry.icon, false, false, white, self.missionList.width - 2 * self.iconColumnWidth)
            self.missionList:setEntry(1, self.missionList.rows - 1, entry.name, false, false, color, self.missionList.width - 2 * self.iconColumnWidth)
            self.missionList:setEntry(11, self.missionList.rows - 1, entry.group, false, false, white, self.missionList.width - 2 * self.iconColumnWidth)
            self.missionList:setEntryType(0, self.missionList.rows - 1, ListBoxEntryType.PixelIcon)

            self.missionList:addRow(entity.id.string)
            for i = 1, #icons do
                self.missionList:setEntry(i, self.missionList.rows - 1, icons[i], false, false, missions[i].iconColor or white, 0)
                self.missionList:setEntryType(i, self.missionList.rows - 1, ListBoxEntryType.Icon)
                self.missionList:setEntryTooltip(i, self.missionList.rows - 1, tooltips[i])
            end
        end

        ::continue::
    end

    if player.selectedObject then
        self.missionList:selectValueNoCallback(player.selectedObject.string)
    end

    self.missionList.scrollPosition = scrollPosition
end

function SectorShipOverview.refreshITRList()
    local player = Player()
    local iconType = ListBoxEntryType.PixelIcon
    local entities = self.collectITREntities()

    self.itrList:clear()

    local firstEntry = true
    for _, list in pairs(entities) do
        if #list.entries == 0 then goto continue end

        if not firstEntry then
            self.itrList:addRow()
        else
            firstEntry = false
        end

        self.itrList:addRow(nil, "", "--- " .. list.header .. " ---")

        for _, entry in pairs(list.entries) do
            local entity = Entity(entry.id)

            local color
            if type(entry.color) == "string" then
                color = Color(entry.color)
            elseif type(entry.color) == "number" then
                color = Rarity(entry.color).color
            else
                color = entry.color
            end

            local name = entity.typename
            local title = entity.translatedTitle or entity.title or entity.name or ""
            if title ~= "" then
                name = entity.typename .. ": " .. (entity.translatedTitle or entity.title or entity.name or "")
            end

            self.itrList:addRow(entity.id.string)
            self.itrList:setEntry(0, self.itrList.rows - 1, list.icon, false, false, ColorRGB(1, 1, 1))
            self.itrList:setEntry(1, self.itrList.rows - 1, name, false, false, color)

            self.itrList:setEntryType(0, self.itrList.rows - 1, iconType)
        end

        ::continue::
    end

    if player.selectedObject then
        self.itrList:selectValueNoCallback(player.selectedObject.string)
    end

    self.itrList.scrollPosition = scrollPosition
end

function SectorShipOverview.getSelectionGroupTable(player)
    local selectionGroups = player:getSelectionGroups()

    local result = {}
    for ship, groupIndex in pairs(selectionGroups) do
        local groupByName = result[ship.factionIndex] or {}
        groupByName[ship.name] = groupIndex

        result[ship.factionIndex] = groupByName
    end

    return result
end

function SectorShipOverview.getGroupString(selectionGroups, factionIndex, name)
    local groupByName = selectionGroups[factionIndex]
    if not groupByName then return "" end

    local group = groupByName[name]
    if not group then return "" end
    return tostring(group)
end

function SectorShipOverview.show()
    self.window:show()

    self.refreshOverviewList()
    self.refreshGoodsList()
    self.refreshCrewList()
    self.refreshMissionList()

    if GameSettings().devMode then
        self.refreshITRList()
    end

    Sector():registerCallback("onEntityCreated", "onEntityCreated")
end

function SectorShipOverview.hide()
     self.window:hide()
end

local doubleClick = {}
function SectorShipOverview.onEntrySelected(index, value)
    if not value or value == "" then return end

    local time = appTime()
    if doubleClick.value ~= value then
        doubleClick.value = value
        doubleClick.time = time

    else
        if time - doubleClick.time < 0.5 then
            StrategyState():centerCameraOnSelection()
        else
            doubleClick.time = time
        end
    end

    local player = Player()

    if Keyboard().controlPressed then
        StrategyState():toggleSelect(value)
        return
    end

    StrategyState():clearSelection()
    player.selectedObject = Entity(value)
end

function SectorShipOverview.onPlayerStateChanged(new,  old)

    if new == PlayerStateType.Strategy then
        self.show()
    else
        self.hide()
    end

end

end
