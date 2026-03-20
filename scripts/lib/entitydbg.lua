
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
package.path = package.path .. ";data/scripts/player/background/simulation/?.lua"
package.path = package.path .. ";data/scripts/sector/effects/?.lua"

include ("utility")
include ("faction")
include ("productions")
include ("goodsindex")
include ("stationextensions")
include ("callable")
include ("relations")
include ("reconstructionutility")
include ("randomext")
local SectorSpecifics = include ("sectorspecifics")
local PlanGenerator = include ("plangenerator")
local SectorGenerator = include ("SectorGenerator")
local AsteroidFieldGenerator = include ("asteroidfieldgenerator")
local ShipUtility = include ("shiputility")
local SpawnUtility = include ("spawnutility")
local SectorTurretGenerator = include ("sectorturretgenerator")
local UpgradeGenerator = include ("upgradegenerator")
local PirateGenerator = include ("pirategenerator")
local Rewards = include ("rewards")
local Scientist = include ("story/scientist")
local The4 = include ("story/the4")
local Smuggler = include ("story/smuggler")
local CaptainGenerator = include("captaingenerator")
local Placer = include ("placer")
local Xsotan = include ("story/xsotan")
local AsyncXsotanGenerator = include ("asyncxsotangenerator")
local Swoks = include("story/swoks")
local AdventurerGuide = include("story/adventurerguide")
local OperationExodus = include("story/operationexodus")
local AsyncPirateGenerator = include("asyncpirategenerator")
local AsyncShipGenerator = include("asyncshipgenerator")
local FighterGenerator = include("fightergenerator")
local TorpedoGenerator = include("torpedogenerator")
local Scientist = include ("story/scientist")
local SectorFighterGenerator = include("sectorfightergenerator")
local AsteroidShieldBoss = include("data/scripts/player/events/spawnasteroidboss")
local JumperBoss = include("data/scripts/player/events/spawnjumperboss.lua")
local LaserBoss = include("data/scripts/player/events/spawnlaserboss.lua")
local BigAI = include("data/scripts/player/events/spawnbigai")
local BigAICorrupted = include("data/scripts/player/events/spawnbigaicorrupted")
local RecallDeviceUT = include("recalldeviceutility")
local BlackMarketDbg = include("internal/dlc/blackmarket/public/bmentitydbg.lua")
local IntoTheRiftDbg = include("internal/dlc/rift/public/itrentitydbg.lua")
local SimulationUtility = include ("simulationutility")
local LegendaryTurretGenerator = include("internal/common/lib/legendaryturretgenerator.lua")
local BuildingKnowledgeUT = include("buildingknowledgeutility")
include("weapontype")
include("turretbalancinganalysis")


systemButtons = {}

local FreeUpdateLegendaryWeapons = {}

local window
local scriptsWindow
local scriptList
local scripts
local addScriptButton
local removeScriptButton
local templateButtons
local factoryButtons

local WeaponTypes =
{
    {type = WeaponType.ChainGun, name = "Chain Guns"},
    {type = WeaponType.PointDefenseChainGun, name = "PDCs"},
    {type = WeaponType.PointDefenseLaser, name = "PDLs"},
    {type = WeaponType.Laser, name = "Lasers"},
    {type = WeaponType.MiningLaser, name = "Mining Lasers"},
    {type = WeaponType.RawMiningLaser, name = "Raw Mining Lasers"},
    {type = WeaponType.SalvagingLaser, name = "Salvage Lasers"},
    {type = WeaponType.RawSalvagingLaser, name = "Raw Salvage Lasers"},
    {type = WeaponType.PlasmaGun, name = "Plasma Guns"},
    {type = WeaponType.RocketLauncher, name = "Rocket Launchers"},
    {type = WeaponType.Cannon, name = "Cannons"},
    {type = WeaponType.RailGun, name = "Railguns"},
    {type = WeaponType.RepairBeam, name = "Repair Beams"},
    {type = WeaponType.Bolter, name = "Bolters"},
    {type = WeaponType.LightningGun, name = "Lightning Guns"},
    {type = WeaponType.TeslaGun, name = "Tesla Guns"},
    {type = WeaponType.ForceGun, name = "Force Guns"},
    {type = WeaponType.PulseCannon, name = "Pulse Cannons"},
    {type = WeaponType.AntiFighter, name = "Anti-Fighter Cannons"},
}

local numButtons = 0
function ButtonRect(w, h, p, wh)

    local width = w or 280
    local height = h or 35
    local padding = p or 10
    local wh = wh or window.size.y - 60

    local space = math.floor(wh / (height + padding))

    local row = math.floor(numButtons % space)
    local col = math.floor(numButtons / space)

    local lower = vec2((width + padding) * col, (height + padding) * row)
    local upper = lower + vec2(width, height)

    numButtons = numButtons + 1

    return Rect(lower, upper)
end

local function MakeButton(tab, rect, caption, func)
    local button = tab:createButton(rect, caption, func)
    button.uppercase = false
    return button
end

local function MakeDivider(tab, rect)
    local left = vec2(rect.lower.x, rect.lower.y + (rect.upper.y - rect.lower.y) / 2)
    local right = vec2(rect.upper.x, rect.lower.y + (rect.upper.y - rect.lower.y) / 2)

    local line = tab:createLine(left, right)
    line.color = ColorARGB(1, 0.8, 0.8, 0.8)
    return line
end

local administrators = {}

function interactionPossible(playerIndex)
    if GameSettings().devMode then
        return true, ""
    end

    if administrators[playerIndex] then
        return true, ""
    end

    return false, "Only server admins have access."%_t
end

function initialize()
    if onClient() then
        invokeServerFunction("updateAdminList")
    end
end

function updateAdminList(adminList)
    if onServer() then
        local newAdministrators = {}
        for  _, player in pairs ({Server():getPlayers()}) do
            if player and Server():hasAdminPrivileges(player) then
                newAdministrators[player.index] = true
            end
        end

        if callingPlayer then
            invokeClientFunction(Player(callingPlayer), "updateAdminList", newAdministrators)
        else
            broadcastInvokeClientFunction("updateAdminList", newAdministrators)
        end
    else
        administrators = adminList
    end
end
callable(nil, "updateAdminList")

function updateServer()
    if tablelength(administrators) ~= Server().numAdministrators then
        updateAdminList()
    end
end

function onShowWindow()
    scriptsWindow:hide()
    valuesWindow:hide()
end

function onCloseWindow()
    scriptsWindow:hide()
    valuesWindow:hide()
end

function initUI()

    local res = getResolution()
    local size = vec2(1200, 650)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))

    window.caption = "Debug"
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "~dev");

    -- create a tabbed window inside the main window
    local tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 10), size - 10))


    local topLevelTab = tabbedWindow:createTab("Entity", "data/textures/icons/ship.png", "Ship Commands")
    local window = topLevelTab:createTabbedWindow(Rect(topLevelTab.rect.size))
    local tab = window:createTab("", "data/textures/icons/ship.png", "General")
    numButtons = 0
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "GoTo", "onGoToButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Entity Scripts", "onEntityScriptsButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Entity Values", "onEntityValuesButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Faction Values", "onFactionValuesButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Spawn Ship", "onCreateShipsButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Spawn Ship Copy", "onCreateShipCopyButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Fly", "onFlyButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Delete", "onDeleteButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Delete Jump", "onDeleteJumpButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Toggle Invincible", "onInvincibleButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Partially Invincible", "onPartialInvincibilityButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Toggle Shield Invincible", "onShieldInvincibleButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Destroy", "onDestroyButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Destroy Block", "onDestroyBlockButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Insta-Board", "onInstaBoardButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Damage", "onDamagePressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Heal", "onHealPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Heal Over Time", "onHealOverTimePressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Dock To Me", "onDockToMePressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Assign Plan To Me", "onAssignPlanToMePressed")


    local tab = window:createTab("", "data/textures/icons/fighter.png", "Equipment Commands")
    numButtons = 0
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Add Crew", "onAddCrewButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Add Captain", "onAddCaptainButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Clear Crew", "onClearCrewButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Clear Passengers", "onClearPassengersButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Clear Cargo", "onClearCargoButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Print Cargo Details", "onPrintCargoDetailsButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Add Pilots", "onAddPilotsPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Add Security", "onAddSecurityPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Add Boarders", "onAddBoardersPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Armed Fighters", "onAddArmedFightersButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Repair Fighters", "onAddRepairFightersButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Mining Fighters", "onAddMiningFightersButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Raw Mining Fighters", "onAddRawMiningFightersButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Salvaging Fighters", "onAddSalvagingFightersButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Raw Salvaging Fighters", "onAddRawSalvagingFightersButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Boarding Shuttles", "onAddCrewShuttlesButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Clear Hangar", "onClearHangarButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Add Torpedoes", "onAddTorpedoesButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Clear Torpedoes", "onClearTorpedoesButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Start Fighter", "onStartFighterButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Spawn Fighters", "onSpawnFightersButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Collect Fighters", "onCollectFightersButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Default Shield", "onAddResiDefaultButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Add Physical Resistance", "onAddResiPhysicalButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Add Plasma Resistance", "onAddResiPlasmaButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Add Electric Resistance", "onAddResiElectricButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Add AntiMatter Resistance", "onAddResiAntiMatterButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Reset Weakness", "onResetWeaknessButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Add Energy Weakness", "onAddEnergyWeaknessButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Add Plasma Weakness", "onAddPlasmaWeaknessButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Add Electric Weakness", "onAddElectricWeaknessButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Add AntiMatter Weakness", "onAddAntiMatterWeaknessButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Add Immunity To Player", "onAddImmunityButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Boost Jump Range", "onBoostJumpRangePressed")


    local tab = window:createTab("", "data/textures/icons/shaking-hands.png", "Diplomacy")
    numButtons = 0
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Like", "onLikePressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Dislike", "onDislikePressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Own", "onOwnButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Own Alliance", "onOwnAllianceButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Own Locals", "onOwnLocalsButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "War", "onWarPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Ceasefire", "onCeasefirePressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Neutral", "onNeutralPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Ally", "onAllyPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Personal Friend", "onPersonalFriendPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Personal Faction Friend", "onPersonalFactionFriendPressed")


    local tab = window:createTab("", "data/textures/icons/info.png", "Debug Info")
    numButtons = 0
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Title", "onTitlePressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Entity ID", "onEntityIdPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Faction Index", "onFactionIndexPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Speech Bubble", "onSpeechBubbleButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Speech Bubble Dialog", "onSpeechBubbleDialogButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "CraftStats", "onCraftStatsPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Random Yield", "onYieldPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Register As Boss", "onBossPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Register As Mini-Boss", "onMiniBossPressed")

    local label = tab:createLabel(ButtonRect(nil, buttonHeight, nil, tab.height), "Target Entity By Uuid:", 15)
    label:setBottomLeftAligned()

    local entityIdTextBox = tab:createTextBox(ButtonRect(nil, nil, nil, tab.height), "onIDTextBoxChanged")
    entityIdTextBox.tooltip = "Note: Selecting is client-only and the debug menu script context is still on the entity that was used for selecting despite not being currently targeted."
    entityIdTextBox.clearOnClick = true
    entityIdTextBox.frameColor = ColorRGB(0.3, 0.3, 0.3)

    local tab = window:createTab("Icons", "data/textures/icons/crate.png", "Cargo Commands")
    numButtons = 0
    local sortedGoods = {}
    for name, good in pairs(goods) do
        table.insert(sortedGoods, good)
    end

    stolenCargoCheckBox = tab:createCheckBox(Rect(vec2(150, 25)), "Stolen", "onStolenChecked")
    local organizer = UIOrganizer(Rect(tabbedWindow.size))

    organizer:placeElementTopRight(stolenCargoCheckBox)

    local button = MakeButton(tab, ButtonRect(40, 40, nil, tab.height), "C", "onClearCargoButtonPressed")
    button.tooltip = "Clear Cargo Bay"

    function goodsByName(a, b) return a.name < b.name end
    table.sort(sortedGoods, goodsByName)

    for _, good in pairs(sortedGoods) do
        local rect = ButtonRect(40, 40, nil, tab.height)

        rect.upper = rect.lower + vec2(rect.size.y, rect.size.y)

        local button = MakeButton(tab, rect, "", "onGoodsButtonPressed")
        button.icon = good.icon
        button.tooltip = good.name
    end
    local button = MakeButton(tab, ButtonRect(40, 40, nil, tab.height), "FS", "onFreedSlavesButtonPressed")



    local topLevelTab = tabbedWindow:createTab("", "data/textures/icons/player.png", "Player Commands")
    local window = topLevelTab:createTabbedWindow(Rect(topLevelTab.rect.size))
    local tab = window:createTab("", "data/textures/icons/player.png", "General")

    numButtons = 0
    local devXPButton = MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "DEV XP", "onDevXPButtonPressed")
    devXPButton.tooltip = "Spawns armed ship if in drone" .. "\n" .. "Gives a ton of money and resources for player and alliance" .. "\n" .. "Unlocks all building knowledge" .."\n" .. "Extends deep scan range"

    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Player Scripts", "onPlayerScriptsButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Player Values", "onPlayerValuesButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Cleanup Map", "onClearUnknownSectorsButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Refresh Map", "onRefreshMapButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Disable Events", "onDisableEventsButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Clear Inventory", "onClearInventoryButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Reset Money", "onResetMoneyButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Guns", "onGunsButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Guns Guns Guns", "onGunsGunsGunsButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "CoAx Guns Guns Guns", "onCoaxialGunsButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Gun Blueprints", "onGunBlueprintsButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Gimme Systems", "onSystemsButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Quest Reward", "onQuestRewardButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Chat Greetings", "onLanguageGreetingsButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Owns BlackMarket DLC", "onOwnsBMDLCButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Owns IntoTheRift DLC", "onOwnsITRDLCButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Owns Behemoth DLC", "onOwnsBehemothDLCButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Reset Building Knowledge", "onResetKnowledgePressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Unlock Building Knowledge", "onUnlockKnowledgePressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Reset Milestones", "onResetMilestonesPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Unlock Milestones", "onUnlockAllMilestonesPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Show Encyclopedia", "onShowEncyclopediaPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Clear Encyclopedia Popups", "onClearEncyclopediaPopUpsPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Spawn BGS Appearance", "onSpawnBGSPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Delayed Execute", "onDelayedExecutePressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Boss Camera Animation", "onBossCameraAnimationPressed")

    local tab = window:createTab("Turrets", "data/textures/icons/turret.png", "Turrets")
    numButtons = 0
    MakeButton(tab, ButtonRect(), "Clear Inventory", "onClearInventoryButtonPressed")

    for _, wp in pairs(WeaponTypes) do
        local button = MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), wp.name, "onGiveWeaponsButtonPressed")
        wp.buttonIndex = button.index
    end

    -- no spoilers, sorry :P
    BlackMarketDbg.buildLegendaryTurretsTab(window)
    IntoTheRiftDbg.buildLegendaryTurretsTab(window)

    -- named turrets of free updates
    local tab = window:createTab("Named Turrets", "data/textures/icons/turret.png", "Named Turrets Free Updates")
    numButtons = 0
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Clear Inventory", "onClearInventoryButtonPressed")

    local generator = LegendaryTurretGenerator()
    local functions = generator:getFreeUpdateGenerationFunctions()

    for _, func in pairs(functions) do
        local weapon = {}
        weapon.name = "Unknown"

        for key, value in pairs(getmetatable(generator)) do
            if value == func then
                weapon.func = func
                weapon.name = key

                local reference = "generate"
                if string.sub(key, 1, #reference) == reference then
                    weapon.displayName = string.sub(key, -(#key - #reference))
                end
            end
        end

        local button = MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), weapon.displayName, "onFreeUpdateLegendaryWeaponPressed")
        weapon.buttonIndex = button.index

        table.insert(FreeUpdateLegendaryWeapons, weapon)
    end

    local tab = window:createTab("Subsystems", "data/textures/icons/circuitry.png", "Subsystems")
    numButtons = 0

    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Clear Inventory", "onClearInventoryButtonPressed")

    local sortedScripts = BlackMarketDbg.getUpgrades()

    for script, _ in pairs(UpgradeGenerator().scripts) do
        table.insert(sortedScripts, script)
    end

    table.insert(sortedScripts, "data/scripts/systems/behemothmilitarytcs.lua")
    table.insert(sortedScripts, "data/scripts/systems/behemothcarriersystem.lua")
    table.insert(sortedScripts, "data/scripts/systems/behemothhyperspacesystem.lua")
    table.insert(sortedScripts, "data/scripts/systems/behemothciviltcs.lua")

    table.sort(sortedScripts)

    for _, script in pairs(sortedScripts) do
        local parts = script:split("/")
        local name = parts[#parts]:split(".")[1]
        local button = MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), name, "onSystemUpgradeButtonPressed")
        table.insert(systemButtons, {button = button, script = script});
    end

    local tab = window:createTab("Story Subsystems & Misc", "data/textures/icons/recall-device.png", "Story Subsystems & Misc")
    numButtons = 0

    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Clear Inventory", "onClearInventoryButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Mission Subsystems", "onKeysButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Energy Suppressor", "onEnergySuppressorButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Reconstruction Kit", "onReconstructionKitButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Empty Reconstruction Kit", "onEmptyReconstructionKitButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Reinforcements Transmitter", "onReinforcementsCallerItemButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Merchant Caller", "onMerchantCallerItemButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Renaming Beacon Spawner", "onRenamingBeaconSpawnerButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Message Beacon Spawner", "onMessageBeaconSpawnerButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Jumper Caller", "onJumperCallerItemButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Staff Pager", "onStaffCallerItemButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "AI Map", "onAIMapItemButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Corrupted AI Map", "onCorruptedAIMapItemButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Qadrant Map", "onQuadrantMapButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Faction Map", "onFactionMapButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Recall Device", "onRecallButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Building Knowledge", "onBuildingKnowledgePressed")

    local sortedScripts = {
        "data/scripts/systems/teleporterkey1.lua",
        "data/scripts/systems/teleporterkey2.lua",
        "data/scripts/systems/teleporterkey3.lua",
        "data/scripts/systems/teleporterkey4.lua",
        "data/scripts/systems/teleporterkey5.lua",
        "data/scripts/systems/teleporterkey6.lua",
        "data/scripts/systems/teleporterkey7.lua",
        "data/scripts/systems/teleporterkey8.lua",
    }

    table.sort(sortedScripts)

    for _, script in pairs(sortedScripts) do
        local parts = script:split("/")
        local name = parts[#parts]:split(".")[1]
        local button = MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), name, "onSystemUpgradeButtonPressed")
        table.insert(systemButtons, {button = button, script = script});
    end


    IntoTheRiftDbg.buildItemsTab(window)


    local topLevelTab = tabbedWindow:createTab("Sector", "data/textures/icons/sector.png", "Sector Commands")
    local window = topLevelTab:createTabbedWindow(Rect(topLevelTab.rect.size))
    local tab = window:createTab("Sector", "data/textures/icons/sector.png", "Sector Commands")

    numButtons = 0
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Sector Scripts", "onSectorScriptsButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Sector Values", "onSectorValuesButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Galaxy Scripts", "onGalaxyScriptsButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Server Values", "onServerValuesButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Clear Sector", "onClearButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Clear Asteroids", "onClearAsteroidsButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "XsotanBeGone", "onClearEncountersPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Destroy Enemies", "onDestroyEnemiesPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Clear Fighters", "onClearFightersButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Clear Torpedos", "onClearTorpedosButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Clear Loot", "onClearLootButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Infect Asteroids", "onInfectAsteroidsButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Align", "onAlignButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Condense Entities", "onCondenseSectorButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Resolve Intersections", "onResolveIntersectionsButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Respawn Asteroids", "onRespawnAsteroidsButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Touch all Objects", "onTouchAllObjectsButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Touch all Objects [Client]", "onTouchAllObjectsOnClientButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Custom Sector Name", "onCustomSectorNameButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Change Fog", "onChangeFogButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Reset Fog", "onResetFogButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Create Laser", "onCreateLaserButtonPressed")

    IntoTheRiftDbg.buildEnvironmentalEffectsTab(window)
    IntoTheRiftDbg.buildSectorDebugVisualizationTab(window)

    local topLevelTab = tabbedWindow:createTab("Spawn", "data/textures/icons/slow-blob.png", "Spawn")
    local window = topLevelTab:createTabbedWindow(Rect(topLevelTab.rect.size))
    local tab = window:createTab("Asteroids", "data/textures/icons/rock.png", "Asteroids")

    numButtons = 0
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Clear Sector", "onClearButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Infected Asteroid", "onCreateInfectedAsteroidPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Big Infected Asteroid", "onCreateBigInfectedAsteroidPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Claimable Asteroid", "onCreateOwnableAsteroidPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Big Asteroid", "onCreateBigAsteroidButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Asteroid Field", "onCreateAsteroidFieldButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Empty Asteroid Field", "onCreateEmptyAsteroidFieldButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Rich Asteroid Field", "onCreateRichAsteroidFieldButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Forest Asteroid Field", "onCreateForestAsteroidFieldButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Ball Asteroid Field", "onCreateBallAsteroidFieldButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Iron Asteroid Field", "onCreateIronAsteroidFieldButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Titanium Asteroid Field", "onCreateTitaniumAsteroidFieldButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Naonite Asteroid Field", "onCreateNaoniteAsteroidFieldButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Trinium Asteroid Field", "onCreateTriniumAsteroidFieldButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Xanion Asteroid Field", "onCreateXanionAsteroidFieldButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Ogonite Asteroid Field", "onCreateOgoniteAsteroidFieldButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Avorion Asteroid Field", "onCreateAvorionAsteroidFieldButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Resource Asteroid", "onCreateResourceAsteroidButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Hidden Treasure Asteroid", "onCreateHiddenTreasureAsteroidButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Trading Good Asteroid", "onCreateTradingGoodAsteroidButtonPressed")


    local tab = window:createTab("Pirates", "data/textures/icons/domino-mask.png", "Pirates")
    numButtons = 0

    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Pirate", "onCreatePirateButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Buffed Pirate", "onCreateBuffedPirateButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Raiders", "onPersecutorsButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "LootGoon", "onLootGoonButtonPressed")
    local carrierButton = MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Pirate Carrier", "onPirateCarrierButtonPressed")
    carrierButton.tooltip = "Carriers need hangar space. In regions with Iron, Titanium or Naonite ravagers will spawn instead."
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Trinium Pirate Carrier", "onPirateCarrierTriniumButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Pirate Torpedo Ship", "onPirateTorpedoButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Mothership", "onMotherShipButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Multiple Pirates", "onCreatePiratesButtonPressed")

    local tab = window:createTab("Ships", "data/textures/icons/ship.png", "Ships")
    numButtons = 0

    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Military Ship", "onSpawnMilitaryShipButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Carrier", "onSpawnCarrierButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Flagship", "onSpawnFlagshipButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Persecutor", "onSpawnPersecutorButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Blocker", "onSpawnBlockerButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Disruptor", "onSpawnDisruptorButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "CIWS", "onSpawnCIWSButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Torpedoboat", "onSpawnTorpedoBoatButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Trader", "onSpawnTraderButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Freighter", "onSpawnFreighterButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Miner", "onSpawnMinerButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Xsotan Squad", "onSpawnXsotanSquadButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Xsotan Carrier", "onSpawnXsotanCarrierButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Quantum Xsotan", "onSpawnQuantumXsotanButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Xsotan Summoner", "onSpawnXsotanSummonerButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Xsotan Types (Async)", "onSpawnAllXsotanAsyncButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Defenders", "onSpawnDefendersButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Battle", "onSpawnBattleButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Deferred Battle", "onSpawnDeferredBattleButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Fleet", "onSpawnFleetButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Crew Transport", "onCrewTransportButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Distri Group", "onCreateDistriButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Adventurer", "onCreateAdventurerPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Travelling Merchant", "onCreateMerchantPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Spawn Local Ship", "onCreateLocalShipButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Spawn Weak Local Ship", "onCreateWeakLocalShipButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Spawn Strong Local Ship", "onCreateStrongLocalShipButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Spawn Rare Local Ship", "onCreateRareLocalShipButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Spawn Exceptional Local Ship", "onCreateExceptionalLocalShipButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Spawn Exotic Local Ship", "onCreateExoticLocalShipButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Spawn Legendary Local Ship", "onCreateLegendaryLocalShipButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Spawn Best Local Ship", "onCreateBestLocalShipButtonPressed")

    local tab = window:createTab("Objects", "data/textures/icons/satellite.png", "Objects")
    numButtons = 0

    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Claimable Wreckage", "onCreateClaimableWreckagePressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Beacon", "onCreateBeaconButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Stash", "onCreateStashButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Container Field", "onCreateContainerFieldButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Wreckage", "onCreateWreckagePressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Hackable Container", "onHackableContainerPressed")

    IntoTheRiftDbg.buildSpawnEnemiesTab(window)

    local tab = window:createTab("Station", "data/textures/icons/station.png", "Spawn Station")
    numButtons = 0
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Resistance Outpost", "onCreateResistanceOutpostPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Smuggler's Market", "onCreateSmugglersMarketPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Headquarters", "onCreateHeadQuartersPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Research Station", "onCreateResearchStationPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Consumer", "onCreateConsumerButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Shipyard", "onCreateShipyardButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Repair Dock", "onCreateRepairDockButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Equipment Dock", "onCreateEquipmentDockButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Turret Merchant", "onCreateTurretMerchantButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Turret Factory", "onCreateTurretFactoryButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Turret Factory Supplier", "onCreateTurretFactorySupplierButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Fighter Merchant", "onCreateFighterMerchantButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Fighter Factory", "onCreateFighterFactoryButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Torpedo Merchant", "onCreateTorpedoMerchantButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Trading Post", "onCreateTradingPostButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Planetary Trading Post", "onCreatePlanetaryTradingPostButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Resource Depot", "onCreateResourceDepotButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Scrapyard", "onCreateScrapyardButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Military Outpost", "onCreateMilitaryOutpostPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Travel Hub", "onCreateTravelHubButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Rift Resesarch", "onCreateRiftResearchButtonPressed")


    local tab = window:createTab("Factory Spawn", "data/textures/icons/cog.png", "Spawn Factory")
    numButtons = 0

    factoryButtons = {}
    for i, production in pairs(productions) do
        local button = MakeButton(tab, ButtonRect(190, 20, 3, tab.height), getTranslatedFactoryName(production, ""), "onGenerateFactoryButtonPressed")
        table.insert(factoryButtons, {button = button, production = production});
        button.maxTextSize = 10
    end

    local tab = tabbedWindow:createTab("Generate Sectors", "data/textures/icons/gears.png", "Generator Scripts")
    numButtons = 0

    local specs = SectorSpecifics(0, 0, Seed());
    specs:addTemplates()
    specs:addTemplate("startsector")

    templateButtons = {}
    for i, template in pairs(specs.templates) do
        local parts = template.path:split("/")
        local button = MakeButton(tab, ButtonRect(), parts[2], "onGenerateTemplateButtonPressed")
        table.insert(templateButtons, {button = button, template = template});
    end

    local tab = tabbedWindow:createTab("Music", "data/textures/icons/g-clef.png", "Music")
    numButtons = 0

    MakeButton(tab, ButtonRect(), "Stop Music", "onCancelMusicButtonPressed")

    local specs = SectorSpecifics(0, 0, Seed());
    specs:addTemplates()

    musicButtons = {}
    for i, template in pairs(specs.templates) do
        local parts = template.path:split("/")
        local button = MakeButton(tab, ButtonRect(), parts[2], "onSectorMusicButtonPressed")
        table.insert(musicButtons, {button = button, template = template});
    end


    local topLevelTab = tabbedWindow:createTab("Missions", "data/textures/icons/treasure-map.png", "Missions")
    local window = topLevelTab:createTabbedWindow(Rect(topLevelTab.rect.size))

    local tab = window:createTab("Events & Utility", "data/textures/icons/missions-tab.png", "Events & Utility")
    numButtons = 0
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Distress Call", "onDistressCallButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Fake Distress Call", "onFakeDistressCallButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Pirate Attack", "onPirateAttackButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Faction Attacks Smuggler", "onFactionAttackSmugglerButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Trader Attacked by Pirates", "onTraderAttackedByPiratesButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Xsotan Attack", "onAlienAttackButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Xsotan Swarm", "onXsotanSwarmButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Cancel Xsotan Swarm", "onXsotanSwarmEndButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Headhunter Attack", "onHeadhunterAttackButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Search and Rescue Call", "onSearchAndRescueButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Progress Brakers", "onProgressBrakersButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Smuggler Retaliation", "onSmugglerRetaliationButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Exodus Beacon", "onExodusBeaconButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Exodus Corner Points", "onExodusPointsButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Exodus Final Beacon", "onExodusFinalBeaconButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Research Satellite", "onResearchSatelliteButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Pirate Delivery", "onPirateDeliveryPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "LaserBoss Location","onLaserBossLocationPressed")


    local tab = window:createTab("Bosses", "data/textures/icons/key1.png", "Bosses")
    numButtons = 0
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Swoks", "onSpawnSwoksButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "The AI", "onSpawnTheAIButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Smuggler", "onSpawnSmugglerButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Scientist", "onSpawnScientistButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "The 4", "onSpawnThe4ButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Guardian", "onSpawnGuardianButtonPressed")

    local tab = window:createTab("Tutorials", "data/textures/icons/graduate-cap.png", "Tutorials")
    numButtons = 0
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "R-Mining", "onRMiningButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Torpedoes", "onTorpedoesButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Fighter", "onFighterButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "StrategyCommands", "onStrategyCommandButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Found Station", "onStationTutorialButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Boarding", "onBoardingTutorialButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Trading", "onTradingTutorialButtonPressed")

    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Recall Device Mail", "onRecallDeviceMailButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Pirate Raid Mission", "onPirateRaidMissionButtonPressed")

    MakeDivider(tab, ButtonRect(nil, buttonHeight, nil, tab.height))

    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Building Knowledge Titanium", "onBuildingKnowledgeTitaniumPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Building Knowledge Naonite", "onBuildingKnowledgeNaonitePressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Building Knowledge Trinium", "onBuildingKnowledgeTriniumPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Building Knowledge Xanion", "onBuildingKnowledgeXanionPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Building Knowledge Ogonite", "onBuildingKnowledgeOgonitePressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Building Knowledge Avorion", "onBuildingKnowledgeAvorionPressed")

    -- story missions
    local tab = window:createTab("Base Story", "data/textures/icons/story-mission.png", "Base Story")
    numButtons = 0

    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Full Story", "onStartStoryButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Swoks", "onStorySwoksButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Hermit", "onStoryHermitButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Buy", "onStoryBuyPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Bottan", "onStoryBottanPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "AI", "onStoryAIPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Research", "onStoryResearchPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Scientist", "onStoryScientistPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Exodus", "onStoryExodusPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "The 4", "onStoryBrotherhoodPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Barrier", "onStoryCrossBarrierPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Guardian", "onStoryKillGuardianPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Bottan Goods", "onBottanGoodsPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Roll Credits", "onRollCreditsButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Roll ITR Credits", "onRollDLCCreditsButtonPressed")

    local tab = window:createTab("Bulletin Missions", "data/textures/icons/station.png", "Bulletin Missions")
    numButtons = 0
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Settler Treck", "onSettlertrackPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Free Slaves", "onFreeSlavesPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Bounty Hunt", "onBountyHuntPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Receive Captain (A lost friend)", "onReceiveCaptainPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Hide Evidence", "onHideEvidencePressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Explore Sector", "onExploreSectorPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Clear Pirate Sector", "onClearPirateSectorPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Clear Xsotan Sector", "onClearXsotanSectorPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Transfer Vessel", "onTransferVesselPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Investigate Missing Freighters", "onInvestigateMissingFreightersPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Cover Retreat", "onCoverRetreatPressed")

    MakeDivider(tab, ButtonRect(nil, buttonHeight, nil, tab.height))

    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Goods Delivery", "onGoodsDeliveryPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Organize Goods", "onOrganizeGoodsPressed")

    -- no spoilers, sorry :P
    BlackMarketDbg.buildStoryTab(window)
    IntoTheRiftDbg.buildStoryTab(window)

    local tab = tabbedWindow:createTab("Waveencounters", "data/textures/icons/firing-ship.png", "Wave Encounters")
    numButtons = 0
    MakeButton(tab, ButtonRect(), "Cancel Encounter", "onCancelWavesPressed")
    MakeButton(tab, ButtonRect(), "Fake Stash", "onFakeStashWavesPressed")
    MakeButton(tab, ButtonRect(), "Hidden Treasure", "onHiddenTreasurePressed")
    MakeButton(tab, ButtonRect(), "Mothership", "onMothershipWavesPressed")
    MakeButton(tab, ButtonRect(), "Ambush Preparation", "onAmbushPreperationPressed")
    MakeButton(tab, ButtonRect(), "Pirateasteroid", "onPirateAsteroidWavesPressed")
    MakeButton(tab, ButtonRect(), "Pirate Initiation", "onPirateInitiationPressed")
    MakeButton(tab, ButtonRect(), "Pirate King", "onPirateKingPressed")
    MakeButton(tab, ButtonRect(), "Pirate Meeting", "onPirateMeetingPressed")
    MakeButton(tab, ButtonRect(), "Pirateprovocation", "onPirateProvocationWavesPressed")
    MakeButton(tab, ButtonRect(), "Pirateshidingtreasure", "onPiratesHidingTreasurePressed")
    MakeButton(tab, ButtonRect(), "Piratestation", "onPiratestationWavesPressed")
    MakeButton(tab, ButtonRect(), "Treasure Hunt", "onTreasureHuntPressed")
    MakeButton(tab, ButtonRect(), "Pirate Traitor", "onPirateTraitorPressed")
    MakeButton(tab, ButtonRect(), "Wreckage", "onPiratesWreackagePressed")
    MakeButton(tab, ButtonRect(), "Trader Ambushed", "onTraderAmbushedPressed")

    local tab = tabbedWindow:createTab("World Bosses", "data/textures/icons/laurel-crown.png", "World Bosses")
    numButtons = 0
    MakeButton(tab, ButtonRect(), "Clear Sector", "onClearButtonPressed")
    MakeButton(tab, ButtonRect(), "Reset Cooldown", "onResetWorldBossCooldownPressed")
    MakeButton(tab, ButtonRect(), "Ancient Sentinel", "onAncientSentinelPressed")
    MakeButton(tab, ButtonRect(), "Chemical Accident", "onChemicalAccidentPressed")
    MakeButton(tab, ButtonRect(), "Collector", "onCollectorPressed")
    MakeButton(tab, ButtonRect(), "Cryo Colony Ship", "onCryoColonyShipPressed")
    MakeButton(tab, ButtonRect(), "Cult Ship", "onCultShipPressed")
    MakeButton(tab, ButtonRect(), "Death Merchant", "onDeathMerchantPressed")
    MakeButton(tab, ButtonRect(), "Jester", "onJesterPressed")
    MakeButton(tab, ButtonRect(), "Lost WMD", "onLostWMDPressed")
    MakeButton(tab, ButtonRect(), "Revolting Prison Ship", "onRevoltingPrisonShipPressed")
    MakeButton(tab, ButtonRect(), "ScrapBot", "onScrapBotPressed")
    MakeButton(tab, ButtonRect(), "LaserBoss", "onSpawnLaserBossButtonPressed")
    MakeButton(tab, ButtonRect(), "AsteroidShield", "onAsteroidShieldBossPressed")
    MakeButton(tab, ButtonRect(), "Jumper", "onJumperBossPressed")
    MakeButton(tab, ButtonRect(), "BigAI", "onSpawnBigAIButtonPressed")
    MakeButton(tab, ButtonRect(), "Corrupted AI", "onSpawnBigAICorruptedButtonPressed")
    MakeButton(tab, ButtonRect(), "Behemoth of the North", "onSpawnBehemothOfTheNorth")
    MakeButton(tab, ButtonRect(), "Behemoth of the South", "onSpawnBehemothOfTheSouth")
    MakeButton(tab, ButtonRect(), "Behemoth of the West", "onSpawnBehemothOfTheWest")
    MakeButton(tab, ButtonRect(), "Behemoth of the East", "onSpawnBehemothOfTheEast")


    local tab = tabbedWindow:createTab("Turret Analysis", "data/textures/icons/turret.png", "Turret Analysis")
    BuildTurretAnalysisUI(tab)

    local tab = tabbedWindow:createTab("Orientation", "data/textures/icons/swipe-y-right.png", "Orientation")
    numButtons = 0
    MakeButton(tab, ButtonRect(40), "+x", "onMoveXP")
    MakeButton(tab, ButtonRect(40), "+y", "onMoveYP")
    MakeButton(tab, ButtonRect(40), "+z", "onMoveZP")

    numButtons = 13
    MakeButton(tab, ButtonRect(40), "-x", "onMoveXN")
    MakeButton(tab, ButtonRect(40), "-y", "onMoveYN")
    MakeButton(tab, ButtonRect(40), "-z", "onMoveZN")

    numButtons = 13 * 3
    MakeButton(tab, ButtonRect(40), "-r", "onMoveRN")
    MakeButton(tab, ButtonRect(40), "-u", "onMoveUN")
    MakeButton(tab, ButtonRect(40), "-l", "onMoveLN")

    numButtons = 13 * 4
    MakeButton(tab, ButtonRect(40), "+r", "onMoveRP")
    MakeButton(tab, ButtonRect(40), "+u", "onMoveUP")
    MakeButton(tab, ButtonRect(40), "+l", "onMoveLP")

    numButtons = 4
    MakeButton(tab, ButtonRect(40), "", "onRotateXRight").icon = "data/textures/icons/swipe-x-up.png"
    MakeButton(tab, ButtonRect(40), "", "onRotateYRight").icon = "data/textures/icons/swipe-y-right.png"
    MakeButton(tab, ButtonRect(40), "", "onRotateZRight").icon = "data/textures/icons/swipe-z-right.png"

    numButtons = 4 + 14
    MakeButton(tab, ButtonRect(40), "R", "onResetRotation").tooltip = "Reset Rotation"

    numButtons = 4 + 26
    MakeButton(tab, ButtonRect(40), "", "onRotateXLeft").icon = "data/textures/icons/swipe-x-down.png"
    MakeButton(tab, ButtonRect(40), "", "onRotateYLeft").icon = "data/textures/icons/swipe-y-left.png"
    MakeButton(tab, ButtonRect(40), "", "onRotateZLeft").icon = "data/textures/icons/swipe-z-left.png"



    local tab = tabbedWindow:createTab("System", "data/textures/icons/bypass.png", "System")
    numButtons = 0
    MakeButton(tab, ButtonRect(), "Crash Script", "onCrashButtonPressed")
    MakeButton(tab, ButtonRect(), "Client Log", "onPrintClientLogButtonPressed")
    MakeButton(tab, ButtonRect(), "Server Log", "onPrintServerLogButtonPressed")
    MakeButton(tab, ButtonRect(), "Client Sleep", "onClientSleepButtonPressed")
    MakeButton(tab, ButtonRect(), "Server Sleep", "onServerSleepButtonPressed")
    MakeButton(tab, ButtonRect(), "Hint", "onHintButtonPressed")
    MakeButton(tab, ButtonRect(), "Terminate", "onTerminatePressed")

    BlackMarketDbg.addSystemButtons(tab, 28)

    -- scripts window
    local size = vec2(800, 500)
    scriptsWindow = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    scriptsWindow.visible = false
    scriptsWindow.caption = "Scripts"
    scriptsWindow.showCloseButton = 1
    scriptsWindow.moveable = 1
    scriptsWindow.closeableWithEscape = 1

    local hsplit = UIHorizontalSplitter(Rect(vec2(0, 0), size), 10, 10, 0.5)
    hsplit.bottomSize = 80

    scriptList = scriptsWindow:createListBox(hsplit.top)

    local hsplit = UIHorizontalSplitter(hsplit.bottom, 10, 0, 0.5)
    hsplit.bottomSize = 35

    scriptTextBox = scriptsWindow:createTextBox(hsplit.top, "")

    local vsplit = UIVerticalSplitter(hsplit.bottom, 10, 0, 0.5)

    addScriptButton = scriptsWindow:createButton(vsplit.left, "Add", "")
    removeScriptButton = scriptsWindow:createButton(vsplit.right, "Remove", "")


    -- values window
    local size = vec2(1000, 700)
    valuesWindow = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    valuesWindow.visible = false
    valuesWindow.caption = "Values"
    valuesWindow.showCloseButton = 1
    valuesWindow.moveable = 1
    valuesWindow.closeableWithEscape = 1

    valuesLines = {}

    local horizontal = 2
    local vertical = 19

    local vsplit = UIVerticalMultiSplitter(Rect(size), 5, 0, horizontal - 1)


    local previous = nil
    for x = 1, horizontal do
        local hsplit = UIHorizontalMultiSplitter(vsplit:partition(x - 1), 5, 10, vertical - 1)

        for y = 1, vertical do
            local vsplit = UIVerticalSplitter(hsplit:partition(y - 1), 5, 0, 0.5)

            local vsplit2 = UIVerticalSplitter(vsplit.right, 5, 0, 0.5)
            local vsplit3 = UIVerticalSplitter(vsplit2.right, 5, 0, 0.5)


            local key = valuesWindow:createTextBox(vsplit.left, "")
            local value = valuesWindow:createTextBox(vsplit2.left, "")

            local set = valuesWindow:createButton(vsplit3.left, "set", "onSetValuePressed")
            local delete = valuesWindow:createButton(vsplit3.right, "X", "onDeleteValuePressed")

            key.tabTarget = value

            if previous then previous.tabTarget = key end
            previous = value

            table.insert(valuesLines, {key = key, value = value, set = set, delete = delete})
        end
    end

end

function onGenerateFactoryButtonPressed(arg)
    if onClient() then
        local button = arg
        for _, p in pairs(factoryButtons) do
            if button.index == p.button.index then
                invokeServerFunction("onGenerateFactoryButtonPressed", p.production)
                break
            end
        end

        return
    end
    local production = arg
    print (production.index)
    print (production.results[1].name)

    if Entity().isStation then
        Entity():removeScript("merchants/factory.lua")
        Entity():addScript("data/scripts/entity/merchants/factory.lua", production.results[1].name)
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local station = generator:createStation(faction)
    station.position = Matrix()
    station:addScript("data/scripts/entity/merchants/factory.lua", production.results[1].name)

    Placer.resolveIntersections()
end

local function make_set(array)
    array = array or {}
    local set = {}

    for _, element in pairs(array) do
        set[element] = true
    end

    return set
end

function onCancelMusicButtonPressed(arg)
    Music():setAmbientTrackLists({}, {})
end

function onSectorMusicButtonPressed(arg)
    local button = arg
    for _, p in pairs(musicButtons) do
        if button.index == p.button.index then

            local good, neutral, bad = p.template.musicTracks()

            local chosen = good or {}
            local primary = make_set(chosen.primary)
            local secondary = make_set(chosen.secondary)

            -- actually set the tracks for playing
            local ptracks = {}
            local stracks = {}

            for id, _ in pairs(primary) do
                table.insert(ptracks, Tracks[id].path)
            end

            for id, _ in pairs(secondary) do
                table.insert(stracks, Tracks[id].path)
            end

            Music():setAmbientTrackLists(ptracks, stracks)
            Music():setAmbientTrackLists(ptracks, {})
            break
        end
    end
end

function onGenerateTemplateButtonPressed(arg)

    if onClient() then
        local button = arg
        for _, p in pairs(templateButtons) do
            if button.index == p.button.index then
                invokeServerFunction("onGenerateTemplateButtonPressed", p.template.path)
                break
            end
        end

        return
    end

    print("generating sector: " .. arg)

    -- clear sector except for player's entities
    local sector = Sector()
    for _, entity in pairs({sector:getEntities()}) do

        if entity.factionIndex == nil or entity.factionIndex ~= Entity().factionIndex then
            sector:deleteEntity(entity)
        end
    end

    sector:collectGarbage()

    local specs = SectorSpecifics(0, 0, Seed());
    specs:addTemplates()
    specs:addTemplate("startsector")

    local path = arg
    for _, template in pairs(specs.templates) do
        if path == template.path then
            template.generate(Faction(), sector.seed, sector:getCoordinates())
            return
        end
    end

end

function onSmugglerRetaliationButtonPressed()

    if onClient() then
        invokeServerFunction("onSmugglerRetaliationButtonPressed")
        return
    end

    local player = Player(callingPlayer)
    player:setValue("smuggler_letter", nil)

    player:removeScript("story/smugglerretaliation.lua")
    player:removeScript("story/smugglerdelivery.lua")
    player:removeScript("story/smugglerletter.lua")

    player:addScriptOnce("story/smugglerletter.lua")

end

function onExodusBeaconButtonPressed()

    if onClient() then
        invokeServerFunction("onExodusBeaconButtonPressed")
        return
    end

    OperationExodus.generateBeacon(SectorGenerator(Sector():getCoordinates()))
end

function onExodusPointsButtonPressed()
    if onClient() then
        invokeServerFunction("onExodusPointsButtonPressed")
        return
    end

    local str = "Points: "
    for _, point in pairs(OperationExodus.getCornerPoints()) do
        str = str .. "\\s(${x}, ${y})  " % point
    end

    Player(callingPlayer):sendChatMessage("", 0, str)
end

function onExodusFinalBeaconButtonPressed()
    if onClient() then
        invokeServerFunction("onExodusFinalBeaconButtonPressed")
        return
    end

    local beacon = SectorGenerator(Sector():getCoordinates()):createBeacon(nil, nil, "")
    beacon:removeScript("data/scripts/entity/beacon.lua")
    beacon:addScript("story/exodustalkbeacon.lua")
end

function onResearchSatelliteButtonPressed()
    if onClient() then
        invokeServerFunction("onResearchSatelliteButtonPressed")
        return
    end

    -- if not, create a new one
    Scientist.createSatellite(Matrix())
end

function onDistressCallButtonPressed()
    if onClient() then
        invokeServerFunction("onDistressCallButtonPressed")
        return
    end

    local player = Player(callingPlayer)
    player:addScript("events/convoidistresssignal.lua", true)
end

function onFakeDistressCallButtonPressed()
    if onClient() then
        invokeServerFunction("onFakeDistressCallButtonPressed")
        return
    end

    local player = Player(callingPlayer)
    player:addScript("events/fakedistresssignal.lua", true)
end

function onPirateAttackButtonPressed()
    if onClient() then
        invokeServerFunction("onPirateAttackButtonPressed")
        return
    end

    Sector():addScript("pirateattack.lua")
end

function onFactionAttackSmugglerButtonPressed()
    if onClient() then
        invokeServerFunction("onFactionAttackSmugglerButtonPressed")
        return
    end

    Sector():addScript("data/scripts/events/factionattackssmugglers.lua")
end

function onXsotanSwarmButtonPressed()
    if onClient() then
        invokeServerFunction("onXsotanSwarmButtonPressed")
        return
    end

    local server = Server()
    server:setValue("xsotan_swarm_active", true)
    server:setValue("xsotan_swarm_duration", 30 * 60)
    server:setValue("xsotan_swarm_time", nil)
    server:setValue("xsotan_swarm_success", nil)
    server:setValue("xsotan_swarm_end_boss_fight", nil)


    Sector():removeScript("xsotanswarm.lua")
    Sector():addScript("xsotanswarm.lua")
end

function onXsotanSwarmEndButtonPressed()
    if onClient() then
        invokeServerFunction("onXsotanSwarmEndButtonPressed")
        return
    end

    Server():setValue("xsotan_swarm_duration", 0)
end

function onTraderAttackedByPiratesButtonPressed()
    if onClient() then
        invokeServerFunction("onTraderAttackedByPiratesButtonPressed")
        return
    end

    Sector():addScript("traderattackedbypirates.lua")
end

function onAlienAttackButtonPressed()
    if onClient() then
        invokeServerFunction("onAlienAttackButtonPressed")
        return
    end

    Player():addScript("events/alienattack.lua")
end

function onHeadhunterAttackButtonPressed()
    if onClient() then
        invokeServerFunction("onHeadhunterAttackButtonPressed")
        return
    end

    Player():addScriptOnce("events/headhunter.lua")

    local x, y = Sector():getCoordinates()
    local faction = Galaxy():getNearestFaction(x, y)

    Player():invokeFunction("events/headhunter.lua", "createEnemies", faction)

end

function onProgressBrakersButtonPressed()
    if onClient() then
        invokeServerFunction("onProgressBrakersButtonPressed")
        return
    end

    Sector():addScriptOnce("spawnpersecutors.lua")
    Sector():invokeFunction("spawnpersecutors", "update")
end

local transportData

function onCrewTransportButtonPressed()
    if onClient() then
        invokeServerFunction("onCrewTransportButtonPressed")
        return
    end

    local player = Player(callingPlayer)
    local playerShip = player.craft

    if not playerShip then return end

    local generator = AsyncShipGenerator(nil, finalizeCrewTransport)

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())

    local dir = random():getDirection()
    local position = MatrixLookUpPosition(-dir, random():getDirection(), dir * 3000)
    generator:createFreighterShip(faction, position)

    transportData = {}
    transportData.craft = playerShip.index
    transportData.crew = playerShip.idealCrew
end

function finalizeCrewTransport(ship)
    transportData = transportData or {}

    ship:addScriptOnce("crewtransport.lua", transportData.craft or Uuid(), transportData.crew or Crew())

    transportData = nil
end


function onStolenChecked(index, checked)
end

function onAddCrewButtonPressed()
    if onClient() then
        invokeServerFunction("onAddCrewButtonPressed")
        return
    end

    local craft = Entity()

    local crew = craft.idealCrew
    local free = craft.crew.maxSize - crew.size
    if free > 0 then crew:add(free, CrewMan(CrewProfessionType.None, false, 1)) end

    craft.crew = crew
    craft:setCaptain(CaptainGenerator():generate())
end

function onAddCaptainButtonPressed()
    if onClient() then
        invokeServerFunction("onAddCaptainButtonPressed")
        return
    end

    local crew = CrewComponent()
    if crew:getCaptain() then
        crew:addPassenger(CaptainGenerator():generate())
    else
        crew:setCaptain(CaptainGenerator():generate())
    end
end

function onGoodsButtonPressed(button, stolen, amount)
    if onClient() then
        local amount = 1
        if Keyboard():keyPressed(KeyboardKey.LControl) then
            amount = 100
        end

        invokeServerFunction("onGoodsButtonPressed", button.tooltip, stolenCargoCheckBox.checked, amount)
        return
    end

    -- we're using the same argument name for both the button and the
    -- good's name, on client it's a button, on server it's a string
    local name = button

    local craft = Entity()
    local good = goods[name]:good()

    good.stolen = stolen

    for i = 1, 10 do
        craft:addCargo(good, amount)
    end
end

function onClearCargoButtonPressed()
    if onClient() then
        invokeServerFunction("onClearCargoButtonPressed")
        return
    end

    local ship = Entity()

    for cargo, amount in pairs(ship:getCargos()) do
        ship:removeCargo(cargo, amount)
    end
end

function onPrintCargoDetailsButtonPressed()
    local ship = Entity()

    for cargo, amount in pairs(ship:getCargos()) do
        print (tostring(cargo))
        printTable (cargo.tags)
    end
end
rcall(nil, "onPrintCargoDetailsButtonPressed")

function onFreedSlavesButtonPressed()
    local ship = Entity()

    local good = TradingGood("Freed Slave", "Freed Slaves", "A now freed life form that was forced to work for almost no food.", "data/textures/icons/slave.png", 0, 1)
    local amount = 1
    ship:addCargo(good, amount)
end
rcall(nil, "onFreedSlavesButtonPressed")

function onClearCrewButtonPressed()
    if onClient() then
        invokeServerFunction("onClearCrewButtonPressed")
        return
    end

    Entity().crew = Crew()
end

function onClearPassengersButtonPressed()
    if onClient() then
        invokeServerFunction("onClearPassengersButtonPressed")
        return
    end

    local entity = Entity()
    local crew = entity.crew
    crew:clearPassengers()
    entity.crew = crew
end
callable(nil, "onClearPassengersButtonPressed")

function onClearHangarButtonPressed()
    if onClient() then
        invokeServerFunction("onClearHangarButtonPressed")
        return
    end

    Hangar():clear()
end

function onClearTorpedoesButtonPressed()
    if onClient() then
        invokeServerFunction("onClearTorpedoesButtonPressed")
        return
    end

    TorpedoLauncher():clear()
end

function onStartFighterButtonPressed()
    if onClient() then
        invokeServerFunction("onStartFighterButtonPressed")
        return
    end

    local controller = FighterController()
    local fighter, error = controller:startFighter(0, nil);

    if error ~= 0 then
        print ("error starting fighter: " .. error)
        return
    end

    local station = Sector():getEntitiesByType(EntityType.Station)

    local ai = FighterAI(fighter.id)
    ai.ignoreMothershipOrders = true
    ai:setOrders(FighterOrders.FlyToLocation, station.id)

end

function onSpawnFightersButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnFightersButtonPressed")
        return
    end

    local x, y = Sector():getCoordinates()
    local fighter = SectorFighterGenerator():generate(x, y, nil, nil, WeaponType.RailGun)

    local mothership = Entity()
    local hangar = Hangar(mothership)
    hangar:addSquad("1")

    local squadIndex = 0
    local squadId = hangar:getSquadId(squadIndex)

    for i = 1, 1 do
        local desc = fighter:makeDescriptor()
        desc.factionIndex = mothership.factionIndex
        desc.position = mothership.position
        desc.mothership = mothership

        local ai = desc:getComponent(ComponentType.FighterAI)
        ai:setSquad(squadIndex, squadId)

        local fighter = Sector():createEntity(desc)

        local ai = FighterAI(fighter)
        ai:setOrders(FighterOrders.Defend, mothership.id)
    end

end

function onCollectFightersButtonPressed()
    if onClient() then
        invokeServerFunction("onCollectFightersButtonPressed")
        return
    end

    Hangar():collectAllFighters()
end
callable(nil, "onCollectFightersButtonPressed")

function onAddResiDefaultButtonPressed()

    if onClient() then
        invokeServerFunction("onAddResiDefaultButtonPressed")
        return
    end

    local entity = Entity()
    if not entity then return end

    local shield = Shield(entity.id)
    if not shield then return end

    shield:resetResistance()
end
callable(nil, "onAddResiDefaultButtonPressed")

function onAddResiPhysicalButtonPressed()

    if onClient() then
        invokeServerFunction("onAddResiPhysicalButtonPressed")
        return
    end

    local entity = Entity()
    if not entity then return end

    local shield = Shield(entity.id)
    if not shield then return end

    shield:setResistance(DamageType.Physical, 1)
end
callable(nil, "onAddResiPhysicalButtonPressed")

function onAddResiPlasmaButtonPressed()

    if onClient() then
        invokeServerFunction("onAddResiPlasmaButtonPressed")
        return
    end

    local entity = Entity()
    if not entity then return end

    local shield = Shield(entity.id)
    if not shield then return end

    shield:setResistance(DamageType.Plasma, 1)
end
callable(nil, "onAddResiPlasmaButtonPressed")


function onAddResiElectricButtonPressed()

    if onClient() then
        invokeServerFunction("onAddResiElectricButtonPressed")
        return
    end

    local entity = Entity()
    if not entity then return end

    local shield = Shield(entity.id)
    if not shield then return end

    shield:setResistance(DamageType.Electric, 1)
end
callable(nil, "onAddResiElectricButtonPressed")

function onAddResiAntiMatterButtonPressed()

    if onClient() then
        invokeServerFunction("onAddResiAntiMatterButtonPressed")
        return
    end

    local entity = Entity()
    if not entity then return end

    local shield = Shield(entity.id)
    if not shield then return end

    shield:setResistance(DamageType.AntiMatter, 1)
end
callable(nil, "onAddResiAntiMatterButtonPressed")

function onResetWeaknessButtonPressed()

    if onClient() then
        invokeServerFunction("onResetWeaknessButtonPressed")
        return
    end

    local entity = Entity()
    if not entity then return end

    local durability = Durability(entity.id)
    if not durability then return end

    durability:resetWeakness()
end
callable(nil, "onResetWeaknessButtonPressed")

function onAddEnergyWeaknessButtonPressed()

    if onClient() then
        invokeServerFunction("onAddEnergyWeaknessButtonPressed")
        return
    end

    local entity = Entity()
    if not entity then return end

    local durability = Durability(entity.id)
    if not durability then return end

    durability:setWeakness(DamageType.Energy, 1)
end
callable(nil, "onAddEnergyWeaknessButtonPressed")

function onAddPlasmaWeaknessButtonPressed()

    if onClient() then
        invokeServerFunction("onAddPlasmaWeaknessButtonPressed")
        return
    end

    local entity = Entity()
    if not entity then return end

    local durability = Durability(entity.id)
    if not durability then return end

    durability:setWeakness(DamageType.Plasma, 1)
end
callable(nil, "onAddPlasmaWeaknessButtonPressed")

function onAddElectricWeaknessButtonPressed()

    if onClient() then
        invokeServerFunction("onAddElectricWeaknessButtonPressed")
        return
    end

    local entity = Entity()
    if not entity then return end

    local durability = Durability(entity.id)
    if not durability then return end

    durability:setWeakness(DamageType.Electric, 1)
end
callable(nil, "onAddElectricWeaknessButtonPressed")

function onAddAntiMatterWeaknessButtonPressed()

    if onClient() then
        invokeServerFunction("onAddAntiMatterWeaknessButtonPressed")
        return
    end

    local entity = Entity()
    if not entity then return end

    local durability = Durability(entity.id)
    if not durability then return end

    durability:setWeakness(DamageType.AntiMatter, 1)
end
callable(nil, "onAddAntiMatterWeaknessButtonPressed")

function onAddImmunityButtonPressed()
    if onClient() then
        invokeServerFunction("onAddImmunityButtonPressed")
        return
    end

    local durability = Durability()
    if not durability then return end

    durability:addFactionImmunity(callingPlayer)
end
callable(nil, "onAddImmunityButtonPressed")

function onDestroyButtonPressed(destroyerId)
    if onClient() then
        invokeServerFunction("onDestroyButtonPressed", Player().craft.id)
        return
    end

    local craft = Entity()

    craft:destroy(destroyerId)
end

function onDestroyBlockButtonPressed()
    if onClient() then
        invokeServerFunction("onDestroyBlockButtonPressed")
        return
    end

    local craft = Entity()
    local plan = Plan(entity)
    local leafs = {}

    for i = 0, plan.numBlocks - 1 do
        local block = plan:getNthBlock(i)
        if block.parent and block.parent >= 0 and block.numChildren == 0 then
            table.insert(leafs, block)
        end
    end

    -- destroy a random one
    shuffle(leafs)
    plan:destroy(leafs[1].index)
end
callable(nil, "onDestroyBlockButtonPressed")

function onSpawnDefendersButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnDefendersButtonPressed")
        return
    end

    local x, y = Sector():getCoordinates()

    local faction = Galaxy():getNearestFaction(x, y)

    local right = Entity().right
    local dir = Entity().look
    local up = Entity().up
    local position = Entity().translationf

    local generator = AsyncShipGenerator()
    for i = -2, 2 do
        local pos = position - right * 500 + dir * i * 100
        generator:createDefender(faction, MatrixLookUpPosition(-dir, up, pos))
    end

end

local function getPositionInFrontOfPlayer()

    local right = Entity().right
    local dir = Entity().look
    local up = Entity().up
    local position = Entity().translationf

    local pos = position + dir * 100

    return MatrixLookUpPosition(-dir, up, pos)
end

function makeDefender(craft)
    craft:addScript("ai/patrol")
end

function onSpawnMilitaryShipButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnMilitaryShipButtonPressed")
        return
    end

    local x, y = Sector():getCoordinates()
    local faction = Galaxy():getNearestFaction(x, y)

    local generator = AsyncShipGenerator(nil, makeDefender)
    generator:createMilitaryShip(faction, getPositionInFrontOfPlayer())

end

function onSpawnTorpedoBoatButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnTorpedoBoatButtonPressed")
        return
    end

    local x, y = Sector():getCoordinates()
    local faction = Galaxy():getNearestFaction(x, y)

    local generator = AsyncShipGenerator(nil, makeDefender)
    generator:createTorpedoShip(faction, getPositionInFrontOfPlayer())

end

function onSpawnCIWSButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnCIWSButtonPressed")
        return
    end

    local x, y = Sector():getCoordinates()
    local faction = Galaxy():getNearestFaction(x, y)

    local generator = AsyncShipGenerator(nil, makeDefender)
    generator:createCIWSShip(faction, getPositionInFrontOfPlayer())

end

function onSpawnDisruptorButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnDisruptorButtonPressed")
        return
    end

    local x, y = Sector():getCoordinates()
    local faction = Galaxy():getNearestFaction(x, y)

    local generator = AsyncShipGenerator(nil, makeDefender)
    generator:createDisruptorShip(faction, getPositionInFrontOfPlayer())

end

function onSpawnPersecutorButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnPersecutorButtonPressed")
        return
    end

    local x, y = Sector():getCoordinates()
    local faction = Galaxy():getNearestFaction(x, y)

    local generator = AsyncShipGenerator(nil, makeDefender)
    generator:createPersecutorShip(faction, getPositionInFrontOfPlayer())

end

function onSpawnBlockerButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnBlockerButtonPressed")
        return
    end

    local x, y = Sector():getCoordinates()
    local faction = Galaxy():getNearestFaction(x, y)

    local generator = AsyncShipGenerator(nil, makeDefender)
    generator:createBlockerShip(faction, getPositionInFrontOfPlayer())

end

function onSpawnFlagshipButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnFlagshipButtonPressed")
        return
    end

    local x, y = Sector():getCoordinates()
    local faction = Galaxy():getNearestFaction(x, y)

    local generator = AsyncShipGenerator(nil, makeDefender)
    generator:createFlagShip(faction, getPositionInFrontOfPlayer())

end

function onSpawnCarrierButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnCarrierButtonPressed")
        return
    end

    local x, y = Sector():getCoordinates()

    local faction = Galaxy():getNearestFaction(x, y)

    local right = Entity().right
    local dir = Entity().look
    local up = Entity().up
    local position = Entity().translationf

    local pos = position + dir * 100
    local generator = AsyncShipGenerator(nil, makeDefender)
    generator:createCarrier(faction, MatrixLookUpPosition(-dir, up, pos))

end

function onSpawnTraderButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnTraderButtonPressed")
        return
    end

    local sector = Sector()
    sector:addScriptOnce("traders.lua")

    sector:invokeFunction("traders.lua", "update", 61)

end

function onSpawnFreighterButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnFreighterButtonPressed")
        return
    end

    local x, y = Sector():getCoordinates()

    local faction = Galaxy():getNearestFaction(x, y)

    local right = Entity().right
    local dir = Entity().look
    local up = Entity().up
    local position = Entity().translationf

    local pos = position + dir * 100
    local generator = AsyncShipGenerator()
    generator:createFreighterShip(faction, MatrixLookUpPosition(-dir, up, pos))

end

function onSpawnMinerButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnMinerButtonPressed")
        return
    end

    local x, y = Sector():getCoordinates()

    local faction = Galaxy():getNearestFaction(x, y)

    local right = Entity().right
    local dir = Entity().look
    local up = Entity().up
    local position = Entity().translationf

    local pos = position + dir * 100
    local generator = AsyncShipGenerator()
    generator:createMiningShip(faction, MatrixLookUpPosition(-dir, up, pos))

end

function onSpawnXsotanSquadButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnXsotanSquadButtonPressed")
        return
    end

    local galaxy = Galaxy()

    local faction = Xsotan.getFaction()

    local player = Player()
    local others = Galaxy():getNearestFaction(Sector():getCoordinates())

    -- create the enemies
    local dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
    local up = vec3(0, 1, 0)
    local right = normalize(cross(dir, up))
    local pos = dir * 1500

    local volumes = {
                {size=1, title="Xsotan Scout"%_t},
                {size=1, title="Xsotan Scout"%_t},
                {size=2, title="Xsotan Scout"%_t},
                {size=3, title="Xsotan Ship"%_t},
                {size=3, title="Xsotan Ship"%_t},
                {size=5, title="Big Xsotan Ship"%_t},
                {size=3, title="Xsotan Ship"%_t},
                {size=3, title="Xsotan Ship"%_t},
                {size=2, title="Xsotan Scout"%_t},
                {size=1, title="Xsotan Scout"%_t},
                {size=1, title="Xsotan Scout"%_t},
            }

    for _, p in pairs(volumes) do

        local enemy = Xsotan.createShip(MatrixLookUpPosition(-dir, up, pos), p.size)
        enemy.title = p.title

        local distance = enemy:getBoundingSphere().radius + 20

        pos = pos + right * distance

        enemy.translation = dvec3(pos.x, pos.y, pos.z)

        pos = pos + right * distance + 20

        -- patrol.lua takes care of setting aggressive
    end

end

function onSpawnXsotanCarrierButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnXsotanCarrierButtonPressed")
        return
    end

    local x, y = Sector():getCoordinates()

    local faction = Galaxy():getNearestFaction(x, y)

    local right = Entity().right
    local dir = Entity().look
    local up = Entity().up
    local position = Entity().translationf

    local pos = position + dir * 100
    Xsotan.createCarrier(MatrixLookUpPosition(-dir, up, pos))

end

function onSpawnQuantumXsotanButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnQuantumXsotanButtonPressed")
        return
    end

    local x, y = Sector():getCoordinates()

    local faction = Galaxy():getNearestFaction(x, y)

    local right = Entity().right
    local dir = Entity().look
    local up = Entity().up
    local position = Entity().translationf

    local pos = position + dir * 100
    Xsotan.createQuantum(MatrixLookUpPosition(right, up, pos))
end

function onSpawnXsotanSummonerButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnXsotanSummonerButtonPressed")
        return
    end

    local x, y = Sector():getCoordinates()

    local faction = Galaxy():getNearestFaction(x, y)

    local right = Entity().right
    local dir = Entity().look
    local up = Entity().up
    local position = Entity().translationf

    local pos = position + dir * 100
    Xsotan.createSummoner(MatrixLookUpPosition(right, up, pos))
end

function onSpawnBattleButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnBattleButtonPressed")
        return
    end

    local x, y = Sector():getCoordinates()

    local pirates = Galaxy():getPirateFaction(Balancing_GetPirateLevel(x, y))
    local faction = Galaxy():getNearestFaction(x, y)

    local right = Entity().right
    local dir = Entity().look
    local up = Entity().up
    local position = Entity().translationf

    local onGenerated = function(ships)
        for _, ship in pairs(ships) do
            ship:removeScript("entity/antismuggle.lua")
        end

        Placer.resolveIntersections(ships)
    end

    local generator = AsyncShipGenerator(nil, onGenerated)
    generator:startBatch()

    for i = -5, 5 do
        local pos = position + dir * 1500 + right * i * 100
        local ship
        if i >= -1 and i <= 1 then
            generator:createCarrier(pirates, MatrixLookUpPosition(-dir, up, pos))
        else
            generator:createDefender(pirates, MatrixLookUpPosition(-dir, up, pos))
        end
    end

    for i = -4, 4 do
        local pos = position + dir * 500 + right * i * 100
        local ship
        if i >= -1 and i <= 1 then
            generator:createCarrier(faction, MatrixLookUpPosition(dir, up, pos))
        else
            generator:createDefender(faction, MatrixLookUpPosition(dir, up, pos))
        end
    end

    generator:endBatch()
end

function onSpawnDeferredBattleButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnDeferredBattleButtonPressed")
        return
    end

    deferredCallback(15.0, "onSpawnBattleButtonPressed")
end


function onSpawnFleetButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnFleetButtonPressed")
        return
    end

    local x, y = Sector():getCoordinates()

    local pirates = Galaxy():getPirateFaction(Balancing_GetPirateLevel(x, y))
    local faction = Faction()

    local right = Entity().right
    local dir = Entity().look
    local up = Entity().up
    local position = Entity().translationf

    local onFinished = function(ship)
        local waypoints = {}
        for j = 0, 8 do
            local pos = position + random():getVector(-400, 400)
            table.insert(waypoints, pos)
        end

    end

    local generator = AsyncShipGenerator(nil, onFinished)
    for i = -3, 3 do
        local pos = position - right * 500 + dir * i * 100
        generator:createDefender(faction, MatrixLookUpPosition(-dir, up, pos))
    end

end

function prepareCleanUp()
    local safe =
    {
        cleanUp = cleanUp,
        initialize = initialize,
        interactionPossible = interactionPossible,
        onShowWindow = onShowWindow,
        onCloseWindow = onCloseWindow,
        initUI = initUI,
        update = update,
        updateServer = updateServer,
        updateClient = updateClient,
    }

    return safe
end

function cleanUp(safe)
    cleanUp = safe.cleanUp
    initialize = safe.initialize
    interactionPossible = safe.interactionPossible
    onShowWindow = safe.onShowWindow
    onCloseWindow = safe.onCloseWindow
    initUI = safe.initUI

    update = nil
    updateServer = nil
    updateClient = nil
    getUpdateInterval = nil
    secure = nil
    restore = nil
end

function onResolveIntersectionsButtonPressed()
    if onClient() then
        invokeServerFunction("onResolveIntersectionsButtonPressed")
        return
    end

    Placer.resolveIntersections()
end

function onCondenseSectorButtonPressed()
    if onClient() then
        invokeServerFunction("onCondenseSectorButtonPressed")
        Entity().position = Matrix()
        return
    end

    for _, entity in pairs({Sector():getEntitiesByComponent(ComponentType.Plan)}) do
        entity.position = Matrix()
    end

    Placer.resolveIntersections()
end

function onRespawnAsteroidsButtonPressed()
    if onClient() then
        invokeServerFunction("onRespawnAsteroidsButtonPressed")
        return
    end

    Sector():removeScript("background/respawnresourceasteroids.lua")
    Sector():addScriptOnce("background/respawnresourceasteroids.lua")
end

function onCustomSectorNameButtonPressed()
    if onClient() then
        invokeServerFunction("onCustomSectorNameButtonPressed")
        return
    end

    Sector().name = "Test Sector Name!"
end
callable(nil, "onCustomSectorNameButtonPressed")

function onChangeFogButtonPressed()
    local sector = Sector()
    sector:setFogColor(ColorRGB(random():getFloat(), random():getFloat(), random():getFloat()))
    sector:setFogColorFactor(random():getFloat(0, 2))
    sector:setFogDensity(random():getFloat())
end
callable(nil, "onChangeFogButtonPressed")

function onResetFogButtonPressed()
    local sector = Sector()
    sector:resetFog()
end
callable(nil, "onResetFogButtonPressed")

function onCreateLaserButtonPressed()
    local craft = Player().craft
    local matrix = craft.position

    local laser = Sector():createLaser(matrix.position + matrix.right * 100, matrix.position - matrix.right * 100, ColorRGB(0.2, 0.2, 0.2), 3)
    laser.collision = false
    laser.maxAliveTime = 10
end

function onTouchAllObjectsButtonPressed()
    if onClient() then
        invokeServerFunction("onTouchAllObjectsButtonPressed")
        return
    end

    for _, entity in pairs({Sector():getEntitiesByComponent(ComponentType.Physics)}) do
        local physics = Physics(entity.id)
        physics:applyImpulse(entity.translation, vec3(0, 1, 0), 10000)
    end
end

function onTouchAllObjectsOnClientButtonPressed()

    for _, entity in pairs({Sector():getEntitiesByComponent(ComponentType.Physics)}) do
        local physics = Physics(entity.id)
        physics:applyImpulse(entity.translation, vec3(0, 1, 0), 10000)
    end
end


function onSpawnSwoksButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnSwoksButtonPressed")
        return
    end

    Swoks.spawn(Player(callingPlayer), Sector():getCoordinates())
end

function onSpawnTheAIButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnTheAIButtonPressed")
        return
    end

    local safe = prepareCleanUp()

    dofile("data/scripts/player/story/spawnrandombosses.lua")
    SpawnRandomBosses.spawnAI(Sector():getCoordinates())

    safe.cleanUp(safe)

end

function onSpawnBigAIButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnBigAIButtonPressed")
        return
    end

    local safe = prepareCleanUp()

--    dofile("data/scripts/entity/events/bigai.lua")
    BigAI.spawn(Sector():getCoordinates())

    safe.cleanUp(safe)

end
callable(nil, "onSpawnBigAIButtonPressed")

function onSpawnBigAICorruptedButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnBigAICorruptedButtonPressed")
        return
    end

    local safe = prepareCleanUp()

--    dofile("data/scripts/entity/events/bigai.lua")
    BigAICorrupted.spawn(Sector():getCoordinates())

    safe.cleanUp(safe)

end
callable(nil, "onSpawnBigAICorruptedButtonPressed")

function onSpawnSmugglerButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnSmugglerButtonPressed")
        return
    end

    Smuggler.spawn()
end

function onSpawnScientistButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnScientistButtonPressed")
        return
    end

    Scientist.spawn()
end

function onSpawnGuardianButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnGuardianButtonPressed")
        return
    end

    Xsotan.createGuardian()
    Placer.resolveIntersections()
end

function onSpawnLaserBossButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnLaserBossButtonPressed")
        return
    end

    LaserBoss.spawnBoss()
    Placer.resolveIntersections()
end

function onSpawnBehemothOfTheNorth()
    onSpawnBehemoth(1)
end
function onSpawnBehemothOfTheSouth()
    onSpawnBehemoth(3)
end
function onSpawnBehemothOfTheEast()
    onSpawnBehemoth(2)
end
function onSpawnBehemothOfTheWest()
    onSpawnBehemoth(4)
end

function onSpawnBehemoth(quadrant)
    if onClient() then
        invokeServerFunction("onSpawnBehemoth", quadrant)
        return
    end

    Sector():removeScript("data/scripts/sector/background/spawnbehemoth.lua")
    Sector():addScript("data/scripts/sector/background/spawnbehemoth.lua", quadrant)
end
callable(nil, "onSpawnBehemoth")


function onPirateDeliveryPressed()
    if onClient() then
        invokeServerFunction("onPirateDeliveryPressed")
        return
    end

    local player = Player(callingPlayer)
    player:removeScript("player/missions/piratedelivery.lua")
    player:addScript("player/missions/piratedelivery.lua")
end

function onLaserBossLocationPressed()
    if onClient() then
        invokeServerFunction("onLaserBossLocationPressed")
        return
    end
    Player(callingPlayer):addScriptOnce("data/scripts/player/events/spawnlaserboss.lua")
    LaserBoss.setHintCoordinate()
    return
end
callable(nil, "onLaserBossLocationPressed")

function onRMiningButtonPressed()
    if onClient() then
        invokeServerFunction("onRMiningButtonPressed")
        return
    end
    Player(callingPlayer):removeScript("data/scripts/player/missions/tutorials/rminingtutorial.lua")
    Player(callingPlayer):addScript("data/scripts/player/missions/tutorials/rminingtutorial.lua")
end

function onTorpedoesButtonPressed()
    if onClient() then
        invokeServerFunction("onTorpedoesButtonPressed")
        return
    end
    Player(callingPlayer):removeScript("data/scripts/player/missions/tutorials/torpedoestutorial.lua")
    Player(callingPlayer):addScript("data/scripts/player/missions/tutorials/torpedoestutorial.lua")
end

function onFighterButtonPressed()
    if onClient() then
        invokeServerFunction("onFighterButtonPressed")
        return
    end
    Player(callingPlayer):removeScript("data/scripts/player/missions/tutorials/fightertutorial.lua")
    Player(callingPlayer):addScript("data/scripts/player/missions/tutorials/fightertutorial.lua")
end

function onStrategyCommandButtonPressed()
    if onClient() then
        invokeServerFunction("onStrategyCommandButtonPressed")
        return
    end

    Player(callingPlayer):removeScript("data/scripts/player/missions/tutorials/strategymodetutorial.lua")
    Player(callingPlayer):addScript("data/scripts/player/missions/tutorials/strategymodetutorial.lua")
end
callable(nil, "onStrategyCommandButtonPressed")

function onStationTutorialButtonPressed()
    if onClient() then
        invokeServerFunction("onStationTutorialButtonPressed")
        return
    end
    Player(callingPlayer):removeScript("data/scripts/player/missions/tutorials/foundstationtutorial.lua")
    Player(callingPlayer):addScript("data/scripts/player/missions/tutorials/foundstationtutorial.lua")
end

function onBoardingTutorialButtonPressed()
    if onClient() then
        invokeServerFunction("onBoardingTutorialButtonPressed")
        return
    end
    Player(callingPlayer):removeScript("data/scripts/player/missions/tutorials/boardingtutorial.lua")
    Player(callingPlayer):addScript("data/scripts/player/missions/tutorials/boardingtutorial.lua")
end
callable(nil, "onBoardingTutorialButtonPressed")

function onTradingTutorialButtonPressed()
    if onClient() then
        invokeServerFunction("onTradingTutorialButtonPressed")
        return
    end
    Player(callingPlayer):removeScript("data/scripts/player/missions/tutorials/tradeintroduction.lua")
    Player(callingPlayer):addScript("data/scripts/player/missions/tutorials/tradeintroduction.lua")
end
callable(nil, "onTradingTutorialButtonPressed")

function onRecallDeviceMailButtonPressed()
    if onClient() then
        invokeServerFunction("onRecallDeviceMailButtonPressed")
        return
    end

    local player = Player(callingPlayer)

    if RecallDeviceUT.hasRecallDevice(player) then
        player:sendChatMessage("", ChatMessageType.Error, "You already have a recall device.")
        return
    end

    if not RecallDeviceUT.qualifiesForRecallDevice(player) then
        player:sendChatMessage("", ChatMessageType.Error, "You don't qualify for a recall device. Collect story artifacts or change your reconstruction site.")
        return
    end

    RecallDeviceUT.sendRecallDeviceMail(player)

end
callable(nil, "onRecallDeviceMailButtonPressed")

function onPirateRaidMissionButtonPressed()
    if onClient() then
        invokeServerFunction("onPirateRaidMissionButtonPressed")
        return
    end

    local player = Player(callingPlayer)
    player:removeScript("data/scripts/player/missions/tutorials/pirateraidmission.lua")
    player:addScript("data/scripts/player/missions/tutorials/pirateraidmission.lua")
end
callable(nil, "onPirateRaidMissionButtonPressed")

local buildingknowledgeValues = {
    ["Titanium"] = {["material"] = MaterialType.Titanium, ["maxBuildable"] = MaterialType.Iron},
    ["Naonite"] = {["material"] = MaterialType.Naonite, ["maxBuildable"] = MaterialType.Titanium},
    ["Trinium"] = {["material"] = MaterialType.Trinium, ["maxBuildable"] = MaterialType.Naonite},
    ["Xanion"] = {["material"] = MaterialType.Xanion, ["maxBuildable"] = MaterialType.Trinium},
    ["Ogonite"] = {["material"] = MaterialType.Ogonite, ["maxBuildable"] = MaterialType.Xanion},
    ["Avorion"] = {["material"] = MaterialType.Avorion, ["maxBuildable"] = MaterialType.Ogonite},
}

function startBuildingKnowledgeMission(player, knowledge)
    player:removeScript("data/scripts/player/missions/tutorials/buildingknowledgemission.lua")

    player.maxBuildableMaterial = Material(buildingknowledgeValues[knowledge].maxBuildable)
    local knowledgeMaterial = buildingknowledgeValues[knowledge].material
    local iron, titanium, naonite, trinium, xanion, ogonite, avorion = player:getResources()

    if knowledge == "Titanium" then
        player:setResources(iron, 0, naonite, trinium, xanion, ogonite, avorion)
    elseif knowledge == "Naonite" then
        player:setResources(iron, titanium, 0, trinium, xanion, ogonite, avorion)
    elseif knowledge == "Trinium" then
        player:setResources(iron, titanium, naonite, 0, xanion, ogonite, avorion)
    elseif knowledge == "Xanion" then
        player:setResources(iron, titanium, naonite, trinium, 0, ogonite, avorion)
    elseif knowledge == "Ogonite" then
        player:setResources(iron, titanium, naonite, trinium, xanion, 0, avorion)
    elseif knowledge == "Avorion" then
        player:setResources(iron, titanium, naonite, trinium, xanion, ogonite, 0)
    end

    BuildingKnowledgeUT.addBuildingKnowledgeMission(player, knowledgeMaterial)
end

function onBuildingKnowledgeTitaniumPressed()
    if onClient() then
        invokeServerFunction("onBuildingKnowledgeTitaniumPressed")
        return
    end

    local player = Player(callingPlayer)
    startBuildingKnowledgeMission(player, "Titanium")
end
callable(nil, "onBuildingKnowledgeTitaniumPressed")

function onBuildingKnowledgeNaonitePressed()
    if onClient() then
        invokeServerFunction("onBuildingKnowledgeNaonitePressed")
        return
    end

    local player = Player(callingPlayer)
    startBuildingKnowledgeMission(player, "Naonite")
end
callable(nil, "onBuildingKnowledgeNaonitePressed")

function onBuildingKnowledgeTriniumPressed()
    if onClient() then
        invokeServerFunction("onBuildingKnowledgeTriniumPressed")
        return
    end

    local player = Player(callingPlayer)
    startBuildingKnowledgeMission(player, "Trinium")
end
callable(nil, "onBuildingKnowledgeTriniumPressed")

function onBuildingKnowledgeXanionPressed()
    if onClient() then
        invokeServerFunction("onBuildingKnowledgeXanionPressed")
        return
    end

    local player = Player(callingPlayer)
    startBuildingKnowledgeMission(player, "Xanion")
end
callable(nil, "onBuildingKnowledgeXanionPressed")

function onBuildingKnowledgeOgonitePressed()
    if onClient() then
        invokeServerFunction("onBuildingKnowledgeOgonitePressed")
        return
    end

    local player = Player(callingPlayer)
    startBuildingKnowledgeMission(player, "Ogonite")
end
callable(nil, "onBuildingKnowledgeOgonitePressed")

function onBuildingKnowledgeAvorionPressed()
    if onClient() then
        invokeServerFunction("onBuildingKnowledgeAvorionPressed")
        return
    end

    local player = Player(callingPlayer)
    startBuildingKnowledgeMission(player, "Avorion")
end
callable(nil, "onBuildingKnowledgeAvorionPressed")

-- story missions
function getStoryQuestUtilityScripts()
    local table = {
        "player/story/swoksmission.lua",
        "player/story/hermitmission.lua",
        "player/story/buymission.lua",
        "player/story/bottanmission.lua",
        "data/scripts/player/story/smugglerdelivery.lua",
        "data/scripts/player/story/smugglerretaliation.lua",
        "data/scripts/player/story/smugglerletter.lua",
        "player/story/aimission.lua",
        "player/story/researchmission.lua",
        "player/story/scientistmission.lua",
        "player/story/exodusmission.lua",
        "player/story/the4mission.lua",
        "data/scripts/player/story/artifactdelivery.lua",
    }
    return table
end

function onStartStoryButtonPressed()
    if onClient() then
        invokeServerFunction("onStartStoryButtonPressed")
        return
    end
    local player = Player(callingPlayer)
    player:removeScript("data/scripts/player/background/storyquestutility.lua")

    -- remove all scripts that are started by framework missions
    for _, path in pairs(getStoryQuestUtilityScripts()) do
        player:removeScript(path)
    end

    -- remove all teleporter keys
    local inventory = player:getInventory()
    local items = inventory:getItemsByType(InventoryItemType.SystemUpgrade)
    for index, slot in pairs(items) do
        if string.match(slot.item.script, "systems/teleporterkey") then
            inventory:removeAll(index)
        end
    end

    player:addScript("data/scripts/player/background/storyquestutility.lua")
end
callable(nil, "onStartStoryButtonPressed")

function onStorySwoksButtonPressed()
    if onClient() then
        invokeServerFunction("onStorySwoksButtonPressed")
        return
    end
    local player = Player(callingPlayer)
    player:removeScript("data/scripts/player/background/storyquestutility.lua")
    player:removeScript("data/scripts/player/story/swoksmission.lua")
    player:addScript("data/scripts/player/story/swoksmission.lua")
end
callable(nil, "onStorySwoksButtonPressed")

function onStoryHermitButtonPressed()
    if onClient() then
        invokeServerFunction("onStoryHermitButtonPressed")
        return
    end
    local player = Player(callingPlayer)
    player:removeScript("data/scripts/player/background/storyquestutility.lua")
    player:removeScript("data/scripts/player/story/hermitmission.lua")
    player:addScript("data/scripts/player/story/hermitmission.lua")
end
callable(nil, "onStoryHermitButtonPressed")

function onStoryBuyPressed()
    if onClient() then
        invokeServerFunction("onStoryBuyPressed")
        return
    end
    local player = Player(callingPlayer)
    player:removeScript("data/scripts/player/background/storyquestutility.lua")
    player:removeScript("data/scripts/player/story/buymission.lua")
    player:addScript("data/scripts/player/story/buymission.lua")
end

function onStoryBottanPressed()
    if onClient() then
        invokeServerFunction("onStoryBottanPressed")
        return
    end
    local player = Player(callingPlayer)
    player:removeScript("data/scripts/player/background/storyquestutility.lua")
    player:removeScript("data/scripts/player/story/bottanmission.lua")
    player:removeScript("data/scripts/player/story/smugglerdelivery.lua")
    player:removeScript("data/scripts/player/story/smugglerretaliation.lua")
    player:removeScript("data/scripts/player/story/smugglerletter.lua")
    player:addScript("data/scripts/player/story/bottanmission.lua")
end
callable(nil, "onStoryBottanPressed")

function onStoryAIPressed()
    if onClient() then
        invokeServerFunction("onStoryAIPressed")
        return
    end
    local player = Player(callingPlayer)
    player:removeScript("data/scripts/player/background/storyquestutility.lua")
    player:removeScript("data/scripts/player/story/aimission.lua")
    player:addScript("data/scripts/player/story/aimission.lua")
end
callable(nil, "onStoryAIPressed")

function onStoryResearchPressed()
    if onClient() then
        invokeServerFunction("onStoryResearchPressed")
        return
    end
    local player = Player(callingPlayer)
    player:removeScript("data/scripts/player/background/storyquestutility.lua")
    player:removeScript("data/scripts/player/story/researchmission.lua")
    player:addScript("data/scripts/player/story/researchmission.lua")
end

function onStoryScientistPressed()
    if onClient() then
        invokeServerFunction("onStoryScientistPressed")
        return
    end
    local player = Player(callingPlayer)
    player:removeScript("data/scripts/player/background/storyquestutility.lua")
    player:removeScript("data/scripts/player/story/scientistmission.lua")
    player:addScript("data/scripts/player/story/scientistmission.lua")
end
callable(nil, "onStoryScientistPressed")

function onStoryExodusPressed()
    if onClient() then
        invokeServerFunction("onStoryExodusPressed")
        return
    end
    local player = Player(callingPlayer)
    player:removeScript("data/scripts/player/background/storyquestutility.lua")
    player:removeScript("data/scripts/player/story/exodusmission.lua")
    player:addScript("data/scripts/player/story/exodusmission.lua")
end
callable(nil, "onStoryExodusPressed")

function onStoryBrotherhoodPressed()
    if onClient() then
        invokeServerFunction("onStoryBrotherhoodPressed")
        return
    end
    local player = Player(callingPlayer)
    player:removeScript("data/scripts/player/background/storyquestutility.lua")
    player:removeScript("data/scripts/player/story/the4mission.lua")
    player:addScript("data/scripts/player/story/the4mission.lua")
end

function onStoryCrossBarrierPressed()
    if onClient() then
        invokeServerFunction("onStoryCrossBarrierPressed")
        return
    end
    local player = Player(callingPlayer)
    player:removeScript("data/scripts/player/background/storyquestutility.lua")
    player:removeScript("data/scripts/player/story/crossthebarriermission.lua")
    player:addScript("data/scripts/player/story/crossthebarriermission.lua")
end
callable(nil, "onStoryCrossBarrierPressed")

function onStoryKillGuardianPressed()
    if onClient() then
        invokeServerFunction("onStoryKillGuardianPressed")
        return
    end
    local player = Player(callingPlayer)
--    player:removeScript("data/scripts/player/background/storyquestutility.lua")
    player:removeScript("data/scripts/player/story/killguardianmission.lua")
    player:addScript("data/scripts/player/story/killguardianmission.lua")
end
callable(nil, "onStoryKillGuardianPressed")

function onBottanGoodsPressed()
    if onClient() then
        invokeServerFunction("onBottanGoodsPressed")
        return
    end

    local entity = Player(callingPlayer).craft

    CargoBay(entity):addCargo(goods["Neutron Accelerator"]:good(), 1)
    CargoBay(entity):addCargo(goods["Electron Accelerator"]:good(), 1)
    CargoBay(entity):addCargo(goods["Fusion Generator"]:good(), 2)
    CargoBay(entity):addCargo(goods["Energy Inverter"]:good(), 5)
    CargoBay(entity):addCargo(goods["Transformator"]:good(), 6)
    CargoBay(entity):addCargo(goods["Semi Conductor"]:good(), 8)
    CargoBay(entity):addCargo(goods["Processor"]:good(), 2)
end
callable(nil, "onBottanGoodsPressed")

-- bosses
function onAsteroidShieldBossPressed()
    if onClient() then
        invokeServerFunction("onAsteroidShieldBossPressed")
        return
    end

    AsteroidShieldBoss.createBoss()
end

function onJumperBossPressed()
    if onClient() then
        invokeServerFunction("onJumperBossPressed")
        return
    end

    JumperBoss.spawnBoss()
end

function onCancelWavesPressed()
    if onClient() then
        invokeServerFunction("onCancelWavesPressed")
        return
    end

    Sector():sendCallback("onCancelWaveEncounter")
end
callable(nil, "onCancelWavesPressed")

function onFakeStashWavesPressed()
    if onClient() then
        invokeServerFunction("onFakeStashWavesPressed")
        return
    end

    Sector():removeScript("data/scripts/events/waveencounters/fakestashwaves.lua")
    Sector():addScript("data/scripts/events/waveencounters/fakestashwaves.lua")
end

function onHiddenTreasurePressed()
    if onClient() then
        invokeServerFunction("onHiddenTreasurePressed")
        return
    end

    Sector():removeScript("data/scripts/events/waveencounters/hiddentreasurewaves.lua")
    Sector():addScript("data/scripts/events/waveencounters/hiddentreasurewaves.lua")
end

function onMothershipWavesPressed()
    if onClient() then
        invokeServerFunction("onMothershipWavesPressed")
        return
    end

    Sector():removeScript("data/scripts/events/waveencounters/mothershipwaves.lua")
    Sector():addScript("data/scripts/events/waveencounters/mothershipwaves.lua")
end

function onAmbushPreperationPressed()
    if onClient() then
        invokeServerFunction("onAmbushPreperationPressed")
        return
    end

    Sector():removeScript("data/scripts/events/waveencounters/pirateambushpreparation.lua")
    Sector():addScript("data/scripts/events/waveencounters/pirateambushpreparation.lua")
end

function onPirateAsteroidWavesPressed()
    if onClient() then
        invokeServerFunction("onPirateAsteroidWavesPressed")
        return
    end

    Sector():removeScript("data/scripts/events/waveencounters/pirateasteroidwaves.lua")
    Sector():addScript("data/scripts/events/waveencounters/pirateasteroidwaves.lua")
end

function onPirateInitiationPressed()
    if onClient() then
        invokeServerFunction("onPirateInitiationPressed")
        return
    end

    Sector():removeScript("data/scripts/events/waveencounters/pirateinitiation.lua")
    Sector():addScript("data/scripts/events/waveencounters/pirateinitiation.lua")
end

function onPirateKingPressed()
    if onClient() then
        invokeServerFunction("onPirateKingPressed")
        return
    end

    Sector():removeScript("data/scripts/events/waveencounters/pirateking.lua")
    Sector():addScript("data/scripts/events/waveencounters/pirateking.lua")
end

function onPirateMeetingPressed()
    if onClient() then
        invokeServerFunction("onPirateMeetingPressed")
        return
    end

    Sector():removeScript("data/scripts/events/waveencounters/piratemeeting.lua")
    Sector():addScript("data/scripts/events/waveencounters/piratemeeting.lua")
end

function onPirateProvocationWavesPressed()
    if onClient() then
        invokeServerFunction("onPirateProvocationWavesPressed")
        return
    end

    Sector():removeScript("data/scripts/events/waveencounters/pirateprovocation.lua")
    Sector():addScript("data/scripts/events/waveencounters/pirateprovocation.lua")
end

function onPiratesHidingTreasurePressed()
    if onClient() then
        invokeServerFunction("onPiratesHidingTreasurePressed")
        return
    end

    Sector():removeScript("data/scripts/events/waveencounters/pirateshidingtreasures.lua")
    Sector():addScript("data/scripts/events/waveencounters/pirateshidingtreasures.lua")
end

function onPiratestationWavesPressed()
    if onClient() then
        invokeServerFunction("onPiratestationWavesPressed")
        return
    end

    Sector():removeScript("data/scripts/events/waveencounters/piratestationwaves.lua")
    Sector():addScript("data/scripts/events/waveencounters/piratestationwaves.lua")
end

function onTreasureHuntPressed()
    if onClient() then
        invokeServerFunction("onTreasureHuntPressed")
        return
    end

    Sector():removeScript("data/scripts/events/waveencounters/piratestreasurehunt.lua")
    Sector():addScript("data/scripts/events/waveencounters/piratestreasurehunt.lua")
end

function onPirateTraitorPressed()
    if onClient() then
        invokeServerFunction("onPirateTraitorPressed")
        return
    end

    Sector():removeScript("data/scripts/events/waveencounters/piratetraitorwaves.lua")
    Sector():addScript("data/scripts/events/waveencounters/piratetraitorwaves.lua")
end

function onPiratesWreackagePressed()
    if onClient() then
        invokeServerFunction("onPiratesWreackagePressed")
        return
    end

    Sector():removeScript("data/scripts/events/waveencounters/piratewreckagewaves.lua")
    Sector():addScript("data/scripts/events/waveencounters/piratewreckagewaves.lua")
end

function onTraderAmbushedPressed()
    if onClient() then
        invokeServerFunction("onTraderAmbushedPressed")
        return
    end

    Sector():removeScript("data/scripts/events/waveencounters/tradersambushedwaves.lua")
    Sector():addScript("data/scripts/events/waveencounters/tradersambushedwaves.lua")
end

function onResetWorldBossCooldownPressed()
    if onClient() then
        invokeServerFunction("onResetWorldBossCooldownPressed")
        return
    end

    Sector():setValue("worldboss_defeated", nil)
end

function removeAllWorldBossScripts()
    local sector = Sector()
    sector:removeScript("data/scripts/sector/worldbosses/ancientsentinel.lua")
    sector:removeScript("data/scripts/sector/worldbosses/chemicalaccident.lua")
    sector:removeScript("data/scripts/sector/worldbosses/chemicalaccident.lua")
    sector:removeScript("data/scripts/sector/worldbosses/collector.lua")
    sector:removeScript("data/scripts/sector/worldbosses/cryocolonyship.lua")
    sector:removeScript("data/scripts/sector/worldbosses/cultship.lua")
    sector:removeScript("data/scripts/sector/worldbosses/deathmerchant.lua")
    sector:removeScript("data/scripts/sector/worldbosses/jester.lua")
    sector:removeScript("data/scripts/sector/worldbosses/lostwmd.lua")
    sector:removeScript("data/scripts/sector/worldbosses/revoltingprisonship.lua")
    sector:removeScript("data/scripts/sector/worldbosses/scrapbot.lua")
end

function onAncientSentinelPressed()
    if onClient() then
        invokeServerFunction("onAncientSentinelPressed")
        return
    end

    Sector():setValue("worldboss_defeated", nil)
    removeAllWorldBossScripts()
    Sector():addScript("data/scripts/sector/worldbosses/ancientsentinel.lua")
end

function onChemicalAccidentPressed()
    if onClient() then
        invokeServerFunction("onChemicalAccidentPressed")
        return
    end

    Sector():setValue("worldboss_defeated", nil)
    removeAllWorldBossScripts()
    Sector():addScript("data/scripts/sector/worldbosses/chemicalaccident.lua")
end

function onCollectorPressed()
    if onClient() then
        invokeServerFunction("onCollectorPressed")
        return
    end

    Sector():setValue("worldboss_defeated", nil)
    removeAllWorldBossScripts()
    Sector():addScript("data/scripts/sector/worldbosses/collector.lua")
end

function onCryoColonyShipPressed()
    if onClient() then
        invokeServerFunction("onCryoColonyShipPressed")
        return
    end

    Sector():setValue("worldboss_defeated", nil)
    removeAllWorldBossScripts()
    Sector():addScript("data/scripts/sector/worldbosses/cryocolonyship.lua")
end

function onCultShipPressed()
    if onClient() then
        invokeServerFunction("onCultShipPressed")
        return
    end

    Sector():setValue("worldboss_defeated", nil)
    removeAllWorldBossScripts()
    Sector():addScript("data/scripts/sector/worldbosses/cultship.lua")
end

function onDeathMerchantPressed()
    if onClient() then
        invokeServerFunction("onDeathMerchantPressed")
        return
    end

    Sector():setValue("worldboss_defeated", nil)
    removeAllWorldBossScripts()
    Sector():addScript("data/scripts/sector/worldbosses/deathmerchant.lua")
end

function onJesterPressed()
    if onClient() then
        invokeServerFunction("onJesterPressed")
        return
    end

    Sector():setValue("worldboss_defeated", nil)
    removeAllWorldBossScripts()
    Sector():addScript("data/scripts/sector/worldbosses/jester.lua")
end

function onLostWMDPressed()
    if onClient() then
        invokeServerFunction("onLostWMDPressed")
        return
    end

    Sector():setValue("worldboss_defeated", nil)
    removeAllWorldBossScripts()
    Sector():addScript("data/scripts/sector/worldbosses/lostwmd.lua")
end

function onRevoltingPrisonShipPressed()
    if onClient() then
        invokeServerFunction("onRevoltingPrisonShipPressed")
        return
    end

    Sector():setValue("worldboss_defeated", nil)
    removeAllWorldBossScripts()
    Sector():addScript("data/scripts/sector/worldbosses/revoltingprisonship.lua")
end

function onScrapBotPressed()
    if onClient() then
        invokeServerFunction("onScrapBotPressed")
        return
    end

    Sector():setValue("worldboss_defeated", nil)
    removeAllWorldBossScripts()
    Sector():addScript("data/scripts/sector/worldbosses/scrapbot.lua")
end

function onSearchAndRescueButtonPressed()
    if onClient() then
        invokeServerFunction("onSearchAndRescueButtonPressed")
        return
    end

    local player = Player(callingPlayer)
    player:addScript("missions/searchandrescue/searchandrescue.lua")
end

function onSpawnThe4ButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnThe4ButtonPressed")
        return
    end

    The4.spawn(Sector():getCoordinates())
end

function onAlignButtonPressed()
    if onClient() then
        invokeServerFunction("onAlignButtonPressed")
        return
    end

    Placer.placeNextToEachOther(vec3(0, 0, 0), vec3(1, 0, 0), vec3(0, 1, 0), Sector():getEntitiesByComponent(ComponentType.Plan))
    Placer.resolveIntersections()
end

function onEntityScriptsButtonPressed()
    scriptList:clear()
    scripts = {}
    scriptsWindow:show()


    addScriptButton.onPressedFunction = "addEntityScript"
    removeScriptButton.onPressedFunction = "removeEntityScript"

    invokeServerFunction("sendEntityScripts", Player().index)
end

function addEntityScript(name)
    if onClient() then
        invokeServerFunction("addEntityScript", scriptTextBox.text)
        invokeServerFunction("sendEntityScripts", Player().index)
        return
    end

    print("add script " .. name )

    Entity():addScript(name)

end

function removeEntityScript(script)

    if onClient() then

        local entry = tonumber(scripts[scriptList.selected])
        if entry ~= nil then
            invokeServerFunction("removeEntityScript", entry)
            invokeServerFunction("sendEntityScripts", Player().index)
        end

        return
    end

    print("remove script " .. script)

    Entity():removeScript(tonumber(script))

    print("remove script done ")
end

function sendEntityScripts(playerIndex)
    invokeClientFunction(Player(playerIndex), "receiveScripts", Entity():getScripts())
end



function onGalaxyScriptsButtonPressed()
    scriptList:clear()
    scripts = {}
    scriptsWindow:show()

    addScriptButton.onPressedFunction = "addGalaxyScript"
    removeScriptButton.onPressedFunction = "removeGalaxyScript"

    invokeServerFunction("sendGalaxyScripts")
end

function addGalaxyScript(name)

    if onClient() then
        invokeServerFunction("addGalaxyScript", scriptTextBox.text)
        invokeServerFunction("sendGalaxyScripts")
        return
    end

    print("add galaxy script " .. name )

    Galaxy():addScript(name)

end
callable(nil, "addGalaxyScript")

function removeGalaxyScript(script)

    if onClient() then

        local entry = tonumber(scripts[scriptList.selected])
        if entry ~= nil then
            invokeServerFunction("removeGalaxyScript", entry)
            invokeServerFunction("sendGalaxyScripts")
        end

        return
    end

    print("remove script " .. script )

    Galaxy():removeScript(tonumber(script))

end
callable(nil, "removeGalaxyScript")

function sendGalaxyScripts()
    invokeClientFunction(Player(callingPlayer), "receiveScripts", Galaxy():getScripts())
end
callable(nil, "sendGalaxyScripts")


function onSectorScriptsButtonPressed()
    scriptList:clear()
    scripts = {}
    scriptsWindow:show()

    addScriptButton.onPressedFunction = "addSectorScript"
    removeScriptButton.onPressedFunction = "removeSectorScript"

    invokeServerFunction("sendSectorScripts", Player().index)
end

function addSectorScript(name)

    if onClient() then
        invokeServerFunction("addSectorScript", scriptTextBox.text)
        invokeServerFunction("sendSectorScripts", Player().index)
        return
    end

    print("add sector script " .. name )

    Sector():addScript(name)

end

function removeSectorScript(script)

    if onClient() then

        local entry = tonumber(scripts[scriptList.selected])
        if entry ~= nil then
            invokeServerFunction("removeSectorScript", entry)
            invokeServerFunction("sendSectorScripts", Player().index)
        end

        return
    end

    print("remove script " .. script )

    Sector():removeScript(tonumber(script))

end

function sendSectorScripts(playerIndex)
    invokeClientFunction(Player(playerIndex), "receiveScripts", Sector():getScripts())
end

function onDevXPButtonPressed()
    if onClient() then
        invokeServerFunction("onDevXPButtonPressed")
        return
    end

    local player = Player() or Player(callingPlayer)

    -- if player has no ship, give him a good one
    if player.craft and player.craft.isDrone then
        local ship = onCreateBestLocalShipButtonPressed()

        -- put player in it
        player.craftIndex = ship.index
    end

    -- give player and his alliance money
    local money = 500000000
    player.money = money
    player:setResources(money, money, money, money, money, money, money, money, money, money, money) -- too much, don't care

    if player.allianceIndex then
        local alliance = Alliance() or Alliance(player.allianceIndex)
        alliance.money = money
        alliance:setResources(money, money, money, money, money, money, money, money, money, money, money) -- too much, don't care
    end

    -- unlock building knowledge
    onUnlockKnowledgePressed()

    -- increase deep scan range
    if player.craft then
        player.craft:addMultiplyableBias(StatsBonuses.HiddenSectorRadarReach, 20)
    end
end
callable(nil, "onDevXPButtonPressed")

function onPlayerScriptsButtonPressed()
    scriptList:clear()
    scripts = {}
    scriptsWindow:show()

    addScriptButton.onPressedFunction = "addPlayerScript"
    removeScriptButton.onPressedFunction = "removePlayerScript"

    invokeServerFunction("sendPlayerScripts")
end

function addPlayerScript(name)

    if onClient() then
        invokeServerFunction("addPlayerScript", scriptTextBox.text)
        invokeServerFunction("sendPlayerScripts")
        return
    end

    print("adding player script " .. name )

    Player(callingPlayer):addScript(name)

end

function removePlayerScript(script)

    if onClient() then

        local entry = tonumber(scripts[scriptList.selected])
        if entry ~= nil then
            invokeServerFunction("removePlayerScript", entry)
            invokeServerFunction("sendPlayerScripts")
        end

        return
    end

    print("removing player script " .. script )

    Player(callingPlayer):removeScript(tonumber(script))

end

function sendPlayerScripts()
    invokeClientFunction(Player(callingPlayer), "receiveScripts", Player(callingPlayer):getScripts())
end





function receiveScripts(scripts_in)

    scriptList:clear()
    scripts = {}

    local c = 0
    for i, name in pairs(scripts_in) do
        scriptList:addEntry(string.format("[%i] %s", i, name))

        scripts[c] = i
        c = c + 1
    end
end

function syncValues(valueType_in, values_in)
    if onClient() then
        if not values_in then
            invokeServerFunction("syncValues", valueType_in)
        else
            valueType = valueType_in
            values = values_in

            fillValues()
        end
    else
        local values

        if valueType_in == 0 then
            values = Entity():getValues()
        elseif valueType_in == 1 then
            values = Sector():getValues()
        elseif valueType_in == 2 then
            values = Faction():getValues()
        elseif valueType_in == 3 then
            values = Player(callingPlayer):getValues()
        elseif valueType_in == 4 then
            values = Server():getValues()
        end

        invokeClientFunction(Player(callingPlayer), "syncValues", valueType_in, values)
    end
end

function setValue(tp, key, value)

    if tp == 0 then
        values = Entity():setValue(key, value)
    elseif tp == 1 then
        values = Sector():setValue(key, value)
    elseif tp == 2 then
        values = Faction():setValue(key, value)
    elseif tp == 3 then
        values = Player(callingPlayer):setValue(key, value)
    elseif tp == 4 then
        values = Server():setValue(key, value)
    end

    syncValues(tp)
end

function onEntityValuesButtonPressed()
    syncValues(0)
    valuesWindow:show()
end

function onSectorValuesButtonPressed()
    syncValues(1)
    valuesWindow:show()
end

function onFactionValuesButtonPressed()
    syncValues(2)
    valuesWindow:show()
end

function onPlayerValuesButtonPressed()
    syncValues(3)
    valuesWindow:show()
end

function onServerValuesButtonPressed()
    syncValues(4)
    valuesWindow:show()
end


function fillValues()
    for _, line in pairs(valuesLines) do
        line.key.text = ""
        line.value.text = ""
    end

    local sorted = {}

    for k, v in pairs(values) do
        table.insert(sorted, {k=k, v=v})
    end

    function comp(a, b) return a.k < b.k end
    table.sort(sorted, comp)


    local c = 1
    for _, p in pairs(sorted) do
        local line = valuesLines[c]
        if not line then
            return
        end

        line.key.text = p.k
        line.value.text = tostring(p.v)

        c = c + 1
    end

end

function onSetValuePressed(button)
    for _, line in pairs(valuesLines) do
        if line.set.index == button.index then
            local str = line.value.text
            local number = tonumber(str)

            if number then
                invokeServerFunction("setValue", valueType, line.key.text, number)
            elseif str == "true" then
                invokeServerFunction("setValue", valueType, line.key.text, true)
            elseif str == "false" then
                invokeServerFunction("setValue", valueType, line.key.text, false)
            else
                invokeServerFunction("setValue", valueType, line.key.text, str)
            end
        end
    end
end

function onDeleteValuePressed(button)
    for _, line in pairs(valuesLines) do
        if line.delete.index == button.index then
            invokeServerFunction("setValue", valueType, line.key.text, nil)
        end
    end
end

function onGiveWeaponsButtonPressed(arg)
    if onClient() then
        local button = arg
        for _, wp in pairs(WeaponTypes) do
            if wp.buttonIndex == button.index then
                invokeServerFunction("onGiveWeaponsButtonPressed", wp.type)
                break
            end
        end
        return
    end

    local player = Faction()
    local x, y = Sector():getCoordinates()
    local dps, tech = Balancing_GetSectorWeaponDPS(x, y)
    local weaponType = arg

    for i = 1, 20 do
        rarityCounter = (rarityCounter or 0) + 1
        if rarityCounter > 5 then rarityCounter = -1 end

        local turret = SectorTurretGenerator():generate(x, y, 0, Rarity(rarityCounter), weaponType)
        for j = 1, 20 do
            player:getInventory():addOrDrop(InventoryTurret(turret))
        end
    end
end

function onQuestRewardButtonPressed(arg)
    if onClient() then
        invokeServerFunction("onQuestRewardButtonPressed")
        return
    end

    local player = Player(callingPlayer)
    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())

    Rewards.standard(player, faction, nil, 12345, 500, true, true)
end

function onLanguageGreetingsButtonPressed(arg)
    displayChatMessage("Hallo", "Boxelware", 0)
    displayChatMessage("Hi", "Boxelware", 0)
    displayChatMessage("Привет", "Boxelware", 0)
    displayChatMessage("你好", "Boxelware", 0)
    displayChatMessage("Bonjour", "Boxelware", 0)
    displayChatMessage("こんにちは", "Boxelware", 0)
    displayChatMessage("Merhaba", "Boxelware", 0)
    displayChatMessage("Witam", "Boxelware", 0)
    displayChatMessage("Hola", "Boxelware", 0)
    displayChatMessage("Ciao", "Boxelware", 0)
    displayChatMessage("Olá", "Boxelware", 0)

end

function onOwnsBMDLCButtonPressed()
    if onClient() then
        displayChatMessage("BlackMarket DLC Installed - Client says: " .. to_yes_no(Player().isBlackMarketDLCInstalled), "", 0)
        displayChatMessage("BlackMarket DLC Ownership - Client says: " .. to_yes_no(Player().ownsBlackMarketDLC), "", 0)

        invokeServerFunction("onOwnsBMDLCButtonPressed")
        return
    end

    local str = "no"
    if Player(callingPlayer).ownsBlackMarketDLC then str = "yes" end

    Player(callingPlayer):sendChatMessage("", 0, "BlackMarket DLC Ownership - Server says: " .. str)
end
callable(nil, "onOwnsBMDLCButtonPressed")

function onOwnsITRDLCButtonPressed()
    if onClient() then
        displayChatMessage("IntoTheRift DLC Installed - Client says: " .. to_yes_no(Player().isIntoTheRiftDLCInstalled), "", 0)
        displayChatMessage("IntoTheRift DLC Ownership - Client says: " .. to_yes_no(Player().ownsIntoTheRiftDLC), "", 0)

        invokeServerFunction("onOwnsITRDLCButtonPressed")
        return
    end

    local str = "no"
    if Player(callingPlayer).ownsIntoTheRiftDLC then str = "yes" end

    Player(callingPlayer):sendChatMessage("", 0, "IntoTheRift DLC Ownership - Server says: " .. str)
end
callable(nil, "onOwnsITRDLCButtonPressed")

function onOwnsBehemothDLCButtonPressed()
    if onClient() then
        displayChatMessage("Behemoth DLC Installed - Client says: " .. to_yes_no(Player().isBehemothDLCInstalled), "", 0)
        displayChatMessage("Behemoth DLC Ownership - Client says: " .. to_yes_no(Player().ownsBehemothDLC), "", 0)

        invokeServerFunction("onOwnsBehemothDLCButtonPressed")
        return
    end

    local str = "no"
    if Player(callingPlayer).ownsBehemothDLC then str = "yes" end

    Player(callingPlayer):sendChatMessage("", 0, "Behemoth DLC Ownership - Server says: " .. str)
end
callable(nil, "onOwnsBehemothDLCButtonPressed")

function onResetKnowledgePressed()
    if onClient() then
        invokeServerFunction("onResetKnowledgePressed")
        return
    end

    local player = Player(callingPlayer)
    player.maxBuildableMaterial = Material(MaterialType.Iron)
    player.maxBuildableSockets = 4

    player:sendChatMessage("", ChatMessageType.Normal, "Knowledge reset to Iron.")
end
callable(nil, "onResetKnowledgePressed")

function onUnlockKnowledgePressed()
    if onClient() then
        invokeServerFunction("onUnlockKnowledgePressed")
        return
    end

    local player = Player(callingPlayer)
    player.maxBuildableMaterial = Material(MaterialType.Avorion)
    player.maxBuildableSockets = 15

    player:sendChatMessage("", ChatMessageType.Normal, "Knowledge unlocked until Avorion.")
end
callable(nil, "onUnlockKnowledgePressed")

function onResetMilestonesPressed()
    if onClient() then
        invokeServerFunction("onResetMilestonesPressed")
        return
    end

    local player = Player(callingPlayer)
    player:invokeFunction("playerprofile.lua", "resetMilestones")
end
callable(nil, "onResetMilestonesPressed")

function onUnlockAllMilestonesPressed()
    if onClient() then
        invokeServerFunction("onUnlockAllMilestonesPressed")
        return
    end

    local player = Player(callingPlayer)
    player:invokeFunction("playerprofile.lua", "unlockAllMilestones")
end
callable(nil, "onUnlockAllMilestonesPressed")

function onShowEncyclopediaPressed()
    local player = Player(callingPlayer)
    player:sendCallback("onShowEncyclopediaArticle", "StrategyMode")
end
callable(nil, "onShowEncyclopediaPressed")

function onClearEncyclopediaPopUpsPressed()
    if onClient() then
        invokeServerFunction("onClearEncyclopediaPopUpsPressed")
        return
    end

    local player = Player(callingPlayer)
    player:invokeFunction("encyclopedia.lua", "clearRememberedPopUps")


    for name, value in pairs(player:getValues()) do
        if string.match(name, "encyclopedia_") then
            player:setValue(name, nil)
        end
    end
end
callable(nil, "onClearEncyclopediaPopUpsPressed")

function onSpawnBGSPressed()
    if onClient() then
        invokeServerFunction("onSpawnBGSPressed")
        return
    end

    local player = Player(callingPlayer)

    for _, name in pairs({player:getShipNames()}) do
        if player:getShipAvailability(name) == ShipAvailability.InBackground then
            SimulationUtility.spawnAppearance(player, name)
            return
        end
    end
end
callable(nil, "onSpawnBGSPressed")

function onDelayedExecutePressed()
    if onClient() then
        invokeServerFunction("onDelayedExecutePressed")
        return
    end

    local player = Player(callingPlayer)

    local code = [[
        function run()
            local mail = Mail()
            mail.sender = "Test Sender"
            mail.header = "Test Header"
            mail.text = Format("Lorem ipsum bla bla bla %1%", "\n\nHave a nice day!")
            mail.money = 5000
            mail:setResources(90, 50, 0, 30)

            Player():addMail(mail)
        end
    ]]

    player:addScript("data/scripts/utility/delayedexecute.lua", 10, code)
end
callable(nil, "onDelayedExecutePressed")

function onBossCameraAnimationPressed()
    deferredCallback(2, "startBossCameraAnimation", Entity().id)
end

function startBossCameraAnimation(bossId)
    bossId = Uuid(bossId)
    local camera = Player().cameraPosition
    local startPosition = camera.translation

    local boss = Entity(bossId)
    local direction = normalize(boss.translationf - startPosition)
    local endPosition = boss.translationf - direction * boss.radius

    local path = endPosition - startPosition

    local bossUp = boss.up
    if dot(camera.up, bossUp) < 0 then
        bossUp = -bossUp -- limit the angle of rotation for the camera
    end

    local keyframes = {}
    table.insert(keyframes, CameraKeyFrame(startPosition, startPosition + camera.look * 1000, camera.up, 0))
    table.insert(keyframes, CameraKeyFrame(startPosition, bossId, camera.up, 1))
    table.insert(keyframes, CameraKeyFrame(startPosition + path * 0.8, bossId, bossUp, 1.8))
    table.insert(keyframes, CameraKeyFrame(startPosition + path, bossId, bossUp, 4))

    DebugInfo():log("Starting dbg camera flight - startBossCameraAnimation")
    Player():setCameraKeyFrames(unpack(keyframes))
end

function onKeysButtonPressed(arg)
    if onClient() then
        invokeServerFunction("onKeysButtonPressed")
        return
    end

    local player = Player(callingPlayer)
    player:getInventory():addOrDrop(SystemUpgradeTemplate("data/scripts/systems/teleporterkey1.lua", Rarity(RarityType.Legendary), Seed(1)))
    player:getInventory():addOrDrop(SystemUpgradeTemplate("data/scripts/systems/teleporterkey2.lua", Rarity(RarityType.Legendary), Seed(1)))
    player:getInventory():addOrDrop(SystemUpgradeTemplate("data/scripts/systems/teleporterkey3.lua", Rarity(RarityType.Legendary), Seed(1)))
    player:getInventory():addOrDrop(SystemUpgradeTemplate("data/scripts/systems/teleporterkey4.lua", Rarity(RarityType.Legendary), Seed(1)))
    player:getInventory():addOrDrop(SystemUpgradeTemplate("data/scripts/systems/teleporterkey5.lua", Rarity(RarityType.Legendary), Seed(1)))
    player:getInventory():addOrDrop(SystemUpgradeTemplate("data/scripts/systems/teleporterkey6.lua", Rarity(RarityType.Legendary), Seed(1)))
    player:getInventory():addOrDrop(SystemUpgradeTemplate("data/scripts/systems/teleporterkey7.lua", Rarity(RarityType.Legendary), Seed(1)))
    player:getInventory():addOrDrop(SystemUpgradeTemplate("data/scripts/systems/teleporterkey8.lua", Rarity(RarityType.Legendary), Seed(1)))

    player:getInventory():addOrDrop(SystemUpgradeTemplate("data/scripts/systems/wormholeopener.lua", Rarity(RarityType.Exotic), Seed(0)))
    player:getInventory():addOrDrop(SystemUpgradeTemplate("data/scripts/systems/wormholeopener.lua", Rarity(RarityType.Exotic), Seed(0)))
    player:getInventory():addOrDrop(SystemUpgradeTemplate("data/scripts/systems/wormholeopener.lua", Rarity(RarityType.Exotic), Seed(0)))
    player:getInventory():addOrDrop(SystemUpgradeTemplate("data/scripts/systems/wormholeopener.lua", Rarity(RarityType.Exotic), Seed(0)))
    player:getInventory():addOrDrop(SystemUpgradeTemplate("data/scripts/systems/wormholeopener.lua", Rarity(RarityType.Exotic), Seed(0)))
    player:getInventory():addOrDrop(SystemUpgradeTemplate("data/scripts/systems/wormholeopener.lua", Rarity(RarityType.Legendary), Seed(0)))
    player:getInventory():addOrDrop(SystemUpgradeTemplate("data/scripts/systems/smugglerblocker.lua", Rarity(RarityType.Exotic), Seed(0)))

    for i = 0, 3 do
        player:getInventory():addOrDrop(SystemUpgradeTemplate("data/scripts/systems/enginebooster.lua", Rarity(RarityType.Legendary), Seed(0)))
    end

end

function onReconstructionKitButtonPressed()
    if onClient() then
        invokeServerFunction("onReconstructionKitButtonPressed")
        return
    end

    local player = Player(callingPlayer)
    local craft = player.craft
    if not craft then return end

    player:getInventory():addOrDrop(createReconstructionKit(craft))
end
callable(nil, "onReconstructionKitButtonPressed")

function onEmptyReconstructionKitButtonPressed()
    if onClient() then
        invokeServerFunction("onEmptyReconstructionKitButtonPressed")
        return
    end

    local player = Player(callingPlayer)

    player:getInventory():addOrDrop(UsableInventoryItem("unbrandedreconstructionkit.lua", Rarity(RarityType.Legendary)))
end
callable(nil, "onEmptyReconstructionKitButtonPressed")

function onMerchantCallerItemButtonPressed()
    if onClient() then
        invokeServerFunction("onMerchantCallerItemButtonPressed")
        return
    end

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local player = Player(callingPlayer)

    player:getInventory():addOrDrop(UsableInventoryItem("equipmentmerchantcaller.lua", Rarity(RarityType.Exotic), faction.index))
end
callable(nil, "onMerchantCallerItemButtonPressed")

function onRenamingBeaconSpawnerButtonPressed()
    if onClient() then
        invokeServerFunction("onRenamingBeaconSpawnerButtonPressed")
        return
    end

    local player = Player(callingPlayer)

    player:getInventory():addOrDrop(UsableInventoryItem("renamingbeaconspawner.lua", Rarity(RarityType.Uncommon)))
end
callable(nil, "onRenamingBeaconSpawnerButtonPressed")

function onMessageBeaconSpawnerButtonPressed()
    if onClient() then
        invokeServerFunction("onMessageBeaconSpawnerButtonPressed")
        return
    end

    local player = Player(callingPlayer)
    player:getInventory():addOrDrop(UsableInventoryItem("messagebeaconspawner.lua", Rarity(RarityType.Uncommon)))
end
callable(nil, "onMessageBeaconSpawnerButtonPressed")

function onJumperCallerItemButtonPressed()
    if onClient() then
        invokeServerFunction("onJumperCallerItemButtonPressed")
        return
    end

    local player = Player(callingPlayer)
    player:getInventory():addOrDrop(UsableInventoryItem("jumperbosscaller.lua", Rarity(RarityType.Legendary)))
end
callable(nil, "onJumperCallerItemButtonPressed")

function onStaffCallerItemButtonPressed()
    if onClient() then
        invokeServerFunction("onStaffCallerItemButtonPressed")
        return
    end

    local player = Player(callingPlayer)
    player:getInventory():addOrDrop(UsableInventoryItem("internal/common/items/staffbosscaller.lua", Rarity(RarityType.Legendary)))
end
callable(nil, "onStaffCallerItemButtonPressed")

function onAIMapItemButtonPressed()
    if onClient() then
        invokeServerFunction("onAIMapItemButtonPressed")
        return
    end

    local player = Player(callingPlayer)
    player:getInventory():addOrDrop(UsableInventoryItem("aimap.lua", Rarity(RarityType.Legendary)))
end
callable(nil, "onAIMapItemButtonPressed")

function onCorruptedAIMapItemButtonPressed()
    if onClient() then
        invokeServerFunction("onCorruptedAIMapItemButtonPressed")
        return
    end

    local player = Player(callingPlayer)
    player:getInventory():addOrDrop(UsableInventoryItem("corruptedaimap.lua", Rarity(RarityType.Legendary)))
end
callable(nil, "onCorruptedAIMapItemButtonPressed")

function onQuadrantMapButtonPressed()
    if onClient() then
        invokeServerFunction("onQuadrantMapButtonPressed")
        return
    end

    rarityCounter = (rarityCounter or 0) + 1
    if rarityCounter > 5 then rarityCounter = -1 end

    local x, y = Sector():getCoordinates()
    local faction = Galaxy():getNearestFaction(x, y)
    local hx, hy = faction:getHomeSectorCoordinates()

    local item = UsableInventoryItem("factionmapsegment.lua", Rarity(math.max(rarityCounter, RarityType.Uncommon)), faction.index, hx, hy, x, y)

    local player = Player(callingPlayer)
    player:getInventory():addOrDrop(item)
end
callable(nil, "onQuadrantMapButtonPressed")

function onFactionMapButtonPressed()
    if onClient() then
        invokeServerFunction("onFactionMapButtonPressed")
        return
    end

    local x, y = Sector():getCoordinates()
    local faction = Galaxy():getNearestFaction(x, y)
    local hx, hy = faction:getHomeSectorCoordinates()

    local item = UsableInventoryItem("factionmapsegment.lua", Rarity(RarityType.Exotic), faction.index, hx, hy, x, y)

    local player = Player(callingPlayer)
    player:getInventory():addOrDrop(item)
end
callable(nil, "onFactionMapButtonPressed")

function onRecallButtonPressed()
    if onClient() then
        invokeServerFunction("onRecallButtonPressed")
        return
    end

    local item = UsableInventoryItem("recalldevice.lua", Rarity(RarityType.Legendary), callingPlayer)

    local player = Player(callingPlayer)
    player:getInventory():addOrDrop(item)
end
callable(nil, "onRecallButtonPressed")

function onBuildingKnowledgePressed()
    if onClient() then
        invokeServerFunction("onBuildingKnowledgePressed")
        return
    end

    buildingKnowledgeCounter = (buildingKnowledgeCounter or 0) + 1
    if buildingKnowledgeCounter > 6 then buildingKnowledgeCounter = 0 end

    local item = UsableInventoryItem("buildingknowledge.lua", Rarity(RarityType.Exotic), Material(buildingKnowledgeCounter), callingPlayer)

    local player = Player(callingPlayer)
    player:getInventory():addOrDrop(item)
end
callable(nil, "onBuildingKnowledgePressed")

function onReinforcementsCallerItemButtonPressed()
    if onClient() then
        invokeServerFunction("onReinforcementsCallerItemButtonPressed")
        return
    end

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local player = Player(callingPlayer)

    player:getInventory():addOrDrop(UsableInventoryItem("reinforcementstransmitter.lua", Rarity(RarityType.Exotic), faction.index))
end
callable(nil, "onReinforcementsCallerItemButtonPressed")

function onDisableEventsButtonPressed(arg)

    if onClient() then
        invokeServerFunction("onDisableEventsButtonPressed")
        return
    end

    Player(callingPlayer):removeScript("events/eventscheduler.lua")
    Player(callingPlayer):removeScript("events/headhunter.lua")
    Player(callingPlayer):removeScript("events/alienattack.lua")

    Sector():removeScript("eventscheduler.lua")
    Sector():removeScript("pirateattack.lua")
end

function onClearUnknownSectorsButtonPressed(arg)

    if onClient() then
        invokeServerFunction("onClearUnknownSectorsButtonPressed")
        return
    end

    local player = Player(callingPlayer)
    local yes = 0
    local no = 0

    for _, view in pairs({player:getKnownSectors()}) do
        local x, y = view:getCoordinates()
        if not view.visited then
            player:removeKnownSector(x, y)
            no = no + 1
        else
            yes = yes + 1
        end
    end

    print ("visited: %i", yes)
    print ("not visited: %i", no)

end
callable(nil, "onClearUnknownSectorsButtonPressed")

function onRefreshMapButtonPressed(arg)

    if onClient() then
        invokeServerFunction("onRefreshMapButtonPressed")
        return
    end

    local player = Player(callingPlayer)
    local yes = 0
    local no = 0

    local specs = SectorSpecifics()
    local seed = GameSeed()

    for _, view in pairs({player:getKnownSectors()}) do
        local x, y = view:getCoordinates()

        if not view.visited then
            specs:initialize(x, y, seed)
            specs:fillSectorView(view, gatesMap, withContent)

            player:updateKnownSectorPreserveNote(view)
        end
    end
end
callable(nil, "onRefreshMapButtonPressed")

function onMoveXP()
    if onClient() then invokeServerFunction("onMoveXP") end

    local t = Entity().translation
    t.x = t.x + 10
    Entity().translation = t
end
callable(nil, "onMoveXP")

function onMoveYP()
    if onClient() then invokeServerFunction("onMoveYP") end

    local t = Entity().translation
    t.y = t.y + 10
    Entity().translation = t
end
callable(nil, "onMoveYP")

function onMoveZP()
    if onClient() then invokeServerFunction("onMoveZP") end

    local t = Entity().translation
    t.z = t.z + 10
    Entity().translation = t
end
callable(nil, "onMoveZP")

function onMoveXN()
    if onClient() then invokeServerFunction("onMoveXN") end

    local t = Entity().translation
    t.x = t.x - 10
    Entity().translation = t
end
callable(nil, "onMoveXN")

function onMoveYN()
    if onClient() then invokeServerFunction("onMoveYN") end

    local t = Entity().translation
    t.y = t.y - 10
    Entity().translation = t
end
callable(nil, "onMoveYN")

function onMoveZN()
    if onClient() then invokeServerFunction("onMoveZN") end

    local t = Entity().translation
    t.z = t.z - 10
    Entity().translation = t
end
callable(nil, "onMoveZN")



function onMoveRP()
    if onClient() then invokeServerFunction("onMoveRP") end

    local p = Entity().position
    local t = Entity().translationf
    t = t + (normalize(p.right) * 10)
    Entity().translation = dvec3(t.x, t.y, t.z)
end
callable(nil, "onMoveRP")

function onMoveRN()
    if onClient() then invokeServerFunction("onMoveRN") end

    local p = Entity().position
    local t = Entity().translationf
    t = t - (normalize(p.right) * 10)
    Entity().translation = dvec3(t.x, t.y, t.z)
end
callable(nil, "onMoveRN")

function onMoveUP()
    if onClient() then invokeServerFunction("onMoveUP") end

    local p = Entity().position
    local t = Entity().translationf
    t = t + (normalize(p.up) * 10)
    Entity().translation = dvec3(t.x, t.y, t.z)
end
callable(nil, "onMoveUP")

function onMoveLP()
    if onClient() then invokeServerFunction("onMoveLP") end

    local p = Entity().position
    local t = Entity().translationf
    t = t + (normalize(p.look) * 10)
    Entity().translation = dvec3(t.x, t.y, t.z)
end
callable(nil, "onMoveLP")


function onMoveUN()
    if onClient() then invokeServerFunction("onMoveUN") end

    local p = Entity().position
    local t = Entity().translationf
    t = t - (normalize(p.up) * 10)
    Entity().translation = dvec3(t.x, t.y, t.z)
end
callable(nil, "onMoveUN")

function onMoveLN()
    if onClient() then invokeServerFunction("onMoveLN") end

    local p = Entity().position
    local t = Entity().translationf
    t = t - (normalize(p.look) * 10)
    Entity().translation = dvec3(t.x, t.y, t.z)
end
callable(nil, "onMoveLN")

function rotateObject(dx, dy, dz)
    local p = Entity().position
    local x = (Entity():getValue("dbg_angle_x") or 0) + dx
    local y = (Entity():getValue("dbg_angle_y") or 0) + dy
    local z = (Entity():getValue("dbg_angle_z") or 0) + dz
    Entity():setValue("dbg_angle_x", x)
    Entity():setValue("dbg_angle_y", y)
    Entity():setValue("dbg_angle_z", z)

    local p2 = MatrixYawPitchRoll(x / 180 * math.pi, y / 180 * math.pi, z / 180 * math.pi)
    p2.position = p.position

    Entity().position = p2
end

function onRotateXLeft()
    if onClient() then
        invokeServerFunction("onRotateXLeft")
    end

    rotateObject(5, 0, 0)
end
callable(nil, "onRotateXLeft")

function onRotateXRight()
    if onClient() then
        invokeServerFunction("onRotateXRight")
    end

    rotateObject(-5, 0, 0)
end
callable(nil, "onRotateXRight")

function onRotateYLeft()
    if onClient() then
        invokeServerFunction("onRotateYLeft")
    end

    rotateObject(0, 5, 0)
end
callable(nil, "onRotateYLeft")

function onRotateYRight()
    if onClient() then
        invokeServerFunction("onRotateYRight")
    end

    rotateObject(0, -5, 0)
end
callable(nil, "onRotateYRight")

function onRotateZLeft()
    if onClient() then
        invokeServerFunction("onRotateZLeft")
    end

    rotateObject(0, 0, 5)
end
callable(nil, "onRotateZLeft")

function onRotateZRight()
    if onClient() then
        invokeServerFunction("onRotateZRight")
    end

    rotateObject(0, 0, -5)
end
callable(nil, "onRotateZRight")

function onResetRotation()
    if onClient() then
        invokeServerFunction("onRotateZRight")
    end

    Entity():setValue("dbg_angle_x", 0)
    Entity():setValue("dbg_angle_y", 0)
    Entity():setValue("dbg_angle_z", 0)

    local p = Entity().position
    local p2 = MatrixYawPitchRoll(0, 0, 0)
    p2.position = p.position
    Entity().position = p2
end
callable(nil, "onResetRotation")


function onCrashButtonPressed(arg)

    if onClient() then
        invokeServerFunction("onCrashButtonPressed")

        local player = nil
        player:removeScript("events/eventscheduler.lua")
        return
    end

    local player = nil
    player:removeScript("events/eventscheduler.lua")
end

function onPrintClientLogButtonPressed(arg)
    print("Client Log: ")

    print(DebugInfo():getStartingLog())
    print("\n...\n")
    print(DebugInfo():getEndingLog())
end

function onHintButtonPressed(arg)
    Hud():displayHint("Debug text of a custom script hint!", Entity())
end

function onTerminatePressed(arg)
    if onClient() then
        invokeServerFunction("onTerminatePressed")
        return
    end

    terminate()
end
callable(nil, "onTerminatePressed")

function onPrintServerLogButtonPressed(arg)
    if onClient() then
        invokeServerFunction("onPrintServerLogButtonPressed", Player().index)
        return
    end

    print(DebugInfo():getStartingLog())
    print("\n...\n")
    print(DebugInfo():getEndingLog())
end

function onClientSleepButtonPressed(arg)
    sleep(1.5)
end

function onServerSleepButtonPressed(arg)
    if onClient() then
        invokeServerFunction("onServerSleepButtonPressed", Player().index)
        return
    end

    sleep(1.5)
end

function onFlyButtonPressed(arg)

    if onClient() then
        invokeServerFunction("onFlyButtonPressed", Player().index)
        return
    end

    local player = Player(arg)
    player.craft = Entity()
end

function onOwnButtonPressed(arg)

    if onClient() then
        invokeServerFunction("onOwnButtonPressed", Player().index)
        return
    end

    Entity().factionIndex = arg
end

function onOwnAllianceButtonPressed(arg)

    if onClient() then
        local allianceIndex = Player().allianceIndex

        if allianceIndex then
            invokeServerFunction("onOwnAllianceButtonPressed", allianceIndex)
        end

        return
    end

    Entity().factionIndex = arg
end

function onOwnLocalsButtonPressed()
    if onClient() then
        invokeServerFunction("onOwnLocalsButtonPressed", allianceIndex)
        return
    end

    local x, y = Sector():getCoordinates()
    local faction = Galaxy():getNearestFaction(x, y)

    Entity().factionIndex = faction.index
end
callable(nil, "onOwnLocalsButtonPressed")

function onCreateShipsButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateShipsButtonPressed")
        return
    end

    local faction = Faction()
    local this = Entity()

    local position = this.position
    local p = this.right * (this:getBoundingBox().size.x + 50.0)
    position.pos = position.pos + vec3(p.x, p.y, p.z)

    local finished = function(ship) ship:addScript("data/scripts/entity/stationfounder.lua") end
    local generator = AsyncShipGenerator(nil, finished)

    generator:createMilitaryShip(faction, position)

end

function onCreateShipCopyButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateShipCopyButtonPressed")
        return
    end

    local faction = Faction()
    local this = Entity()

    local position = this.position
    local p = this.right * (this:getBoundingBox().size.x + 50.0)
    position.pos = position.pos + vec3(p.x, p.y, p.z)

    Sector():copyEntity(this, position)

end

function onCreateLocalShipButtonPressed(scaling, rarity)

    if onClient() then
        invokeServerFunction("onCreateLocalShipButtonPressed")
        return
    end
    local rarity = rarity or nil
    local scaling = scaling or 1
    local sector = Sector()
    local x, y = sector:getCoordinates()
    local distance = math.sqrt((x * x) + (y * y))
    local faction = Faction()
    local this = Entity()

    local plan = LoadPlanFromFile("data/plans/localship.xml")

    local durabilityValues = getDurabilityValues()
    local expectedDurability = multilerpGeneric(distance, durabilityValues) * scaling
    -- using squareroot of 3 as scale factor will be used in cubic scale
    local durabilityScaleFactor = math.pow(expectedDurability / plan.durability, 1 / 3)
    plan:scale(vec3(durabilityScaleFactor, durabilityScaleFactor, durabilityScaleFactor))

    local position = this.position
    local p = this.right * (this:getBoundingBox().size.x + 50.0)
    position.pos = position.pos + vec3(p.x, p.y, p.z)

    local ship = sector:createShip(faction, "", plan, position)
    AddDefaultShipScripts(ship)
    SetBoardingDefenseLevel(ship)

    local shieldDurabilityValues = getShieldDurabilityValues()
    local expectedShieldDurability = multilerpGeneric(distance, shieldDurabilityValues) * scaling
    ship.shieldMaxDurability = expectedShieldDurability

    local omicronValues = getOmicronValues()
    local expectedOmicron = multilerpGeneric(distance, omicronValues) * scaling
    local shipOmicron = ship.firePower

    local chaingunTurret = SectorTurretGenerator():generate(x, y, nil, rarity, WeaponType.ChainGun)
    local laserTurret = SectorTurretGenerator():generate(x, y, nil, rarity, WeaponType.Laser)
    local plasmaTurret = SectorTurretGenerator():generate(x, y, nil, rarity, WeaponType.PlasmaGun)
    local railgunTurret = SectorTurretGenerator():generate(x, y, nil, rarity, WeaponType.RailGun)

    while (expectedOmicron > ship.firePower) do
        for i = 1, 2 do
            ShipUtility.addTurretsToCraft(ship, chaingunTurret, 1, 20)
            shipOmicron = ship.firePower
            local weapons = {chaingunTurret:getWeapons()}
            local dps = 0
            for _, weapon in pairs(weapons) do
                dps = dps + weapon.dps
            end

            if expectedOmicron <= ship.firePower then goto continue end
        end

        for i = 1, 2 do
            ShipUtility.addTurretsToCraft(ship, laserTurret, 1, 20)
            shipOmicron = ship.firePower
            if expectedOmicron <= ship.firePower then goto continue end
        end

        ShipUtility.addTurretsToCraft(ship, plasmaTurret, 1, 20)
        shipOmicron = ship.firePower
        if expectedOmicron <= ship.firePower then goto continue end

        ShipUtility.addTurretsToCraft(ship, railgunTurret, 1, 20)
        shipOmicron = ship.firePower
        if expectedOmicron <= ship.firePower then goto continue end
    end

    ::continue::

    ship.crew = ship.idealCrew
    ship:setCaptain(CaptainGenerator():generate())

    local neededSockets = ship:getNumArmedTurrets()

    local turretRarity = rarity or Rarity(RarityType.Rare)
    for i = 2, neededSockets, 4 do
        local turretSubystem = SystemUpgradeTemplate("data/scripts/systems/militarytcs.lua", turretRarity, UpgradeGenerator():getUpgradeSeed(x, y, "data/cripts/systems/militarytcs.lua", turretRarity))
        ShipSystem(ship.id):addUpgrade(turretSubystem, true)
    end
end

function onCreateWeakLocalShipButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateWeakLocalShipButtonPressed")
        return
    end

    onCreateLocalShipButtonPressed(0.5)
end

function onCreateStrongLocalShipButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateStrongLocalShipButtonPressed")
        return
    end
    onCreateLocalShipButtonPressed(1.5)
end

function onCreateRareLocalShipButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateRareLocalShipButtonPressed")
        return
    end
    onCreateLocalShipButtonPressed(1, Rarity(RarityType.Rare))
end

function onCreateExceptionalLocalShipButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateExceptionalLocalShipButtonPressed")
        return
    end
    onCreateLocalShipButtonPressed(1, Rarity(RarityType.Exceptional))
end

function onCreateExoticLocalShipButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateExoticLocalShipButtonPressed")
        return
    end
    onCreateLocalShipButtonPressed(1, Rarity(RarityType.Exotic))
end

function onCreateLegendaryLocalShipButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateLegendaryLocalShipButtonPressed")
        return
    end
    onCreateLocalShipButtonPressed(1, Rarity(RarityType.Legendary))
end

function onCreateBestLocalShipButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateBestLocalShipButtonPressed")
        return
    end

    local rarity = Rarity(RarityType.Legendary)
    local sector = Sector()
    local x, y = sector:getCoordinates()
    local distance = math.sqrt((x * x) + (y * y))
    local faction = Faction()
    local this = Entity()

    local plan = LoadPlanFromFile("data/plans/localship.xml")

    local expectedVolume = 1940
    local sockets = 5
    print("distance", distance)
    if distance <= 75 then
        expectedVolume = 188560
        sockets = 15
    elseif distance <= 146 then
        expectedVolume = 42000
        sockets = 12
    elseif distance <= 217 then
        expectedVolume = 19230
        sockets = 10
    elseif distance <= 290 then
        expectedVolume = 7650
        sockets = 8
    elseif distance <= 360 then
        expectedVolume = 3060
        sockets = 6
    end

    -- using cubicroot as scale factor will be used in cubic scale
    local volumeScaleFactor = math.pow(expectedVolume / plan.volume, 1 / 3)
    plan:scale(vec3(volumeScaleFactor, volumeScaleFactor, volumeScaleFactor))

    local position = this.position
    local p = this.right * (this:getBoundingBox().size.x + 50.0)
    position.pos = position.pos + vec3(p.x, p.y, p.z)

    local ship = sector:createShip(faction, "", plan, position)
    AddDefaultShipScripts(ship)
    SetBoardingDefenseLevel(ship)

    for i = 1, sockets do
        local turretSubystem = SystemUpgradeTemplate("data/scripts/systems/militarytcs.lua", rarity, UpgradeGenerator():getUpgradeSeed(x, y, "data/cripts/systems/militarytcs.lua", rarity))
        ShipSystem(ship.id):addUpgrade(turretSubystem, true)
    end

    local bolterTurret = SectorTurretGenerator():generate(x, y, nil, rarity, WeaponType.Bolter)
    local laserTurret = SectorTurretGenerator():generate(x, y, nil, rarity, WeaponType.Laser)
    local plasmaTurret = SectorTurretGenerator():generate(x, y, nil, rarity, WeaponType.PlasmaGun)
    local railgunTurret = SectorTurretGenerator():generate(x, y, nil, rarity, WeaponType.RailGun)

    local usedTurretSlots = 0
    while (usedTurretSlots < sockets * 9) do
        for i = 1, 2 do
            ShipUtility.addTurretsToCraft(ship, bolterTurret, 1, 20)
            usedTurretSlots = ship:getNumArmedTurrets()
            if usedTurretSlots >= sockets * 9 then goto continue end
        end

        for i = 1, 2 do
            ShipUtility.addTurretsToCraft(ship, laserTurret, 1, 20)
            usedTurretSlots = ship:getNumArmedTurrets()
            if usedTurretSlots >= sockets * 9 then goto continue end
        end

        ShipUtility.addTurretsToCraft(ship, plasmaTurret, 1, 20)
        shipOmicron = ship.firePower
        usedTurretSlots = ship:getNumArmedTurrets()
        if usedTurretSlots >= sockets * 9 then goto continue end

        ShipUtility.addTurretsToCraft(ship, railgunTurret, 1, 20)
        shipOmicron = ship.firePower
        usedTurretSlots = ship:getNumArmedTurrets()
        if usedTurretSlots >= sockets * 9 then goto continue end
    end

    ::continue::

    ship.crew = ship.idealCrew
    ship:setCaptain(CaptainGenerator():generate())

    return ship
end

function getDurabilityValues()
    local durabilityValues = {}

    durabilityValues[1] = {position = 0, value = 1710000}
    durabilityValues[2] = {position = 160, value = 254100}
    durabilityValues[3] = {position = 180, value = 186900}
    durabilityValues[4] = {position = 200, value = 110500}
    durabilityValues[5] = {position = 220, value = 74600}
    durabilityValues[6] = {position = 240, value = 62300}
    durabilityValues[7] = {position = 260, value = 51400}
    durabilityValues[8] = {position = 280, value = 31600}
    durabilityValues[9] = {position = 300, value = 24700}
    durabilityValues[10] = {position = 320, value = 22400}
    durabilityValues[11] = {position = 340, value = 14000}
    durabilityValues[12] = {position = 360, value = 13000}
    durabilityValues[13] = {position = 380, value = 8600}
    durabilityValues[14] = {position = 400, value = 7800}
    durabilityValues[15] = {position = 420, value = 5800}
    durabilityValues[16] = {position = 440, value = 1305}

    return durabilityValues
end

function getShieldDurabilityValues()
    local shieldDurabilityValues = {}

    shieldDurabilityValues[1] = {position = 0, value = 3950000}
    shieldDurabilityValues[2] = {position = 160, value = 244200}
    shieldDurabilityValues[3] = {position = 180, value = 193900}
    shieldDurabilityValues[4] = {position = 200, value = 105600}
    shieldDurabilityValues[5] = {position = 220, value = 73500}
    shieldDurabilityValues[6] = {position = 240, value = 44200}
    shieldDurabilityValues[7] = {position = 260, value = 30300}
    shieldDurabilityValues[8] = {position = 280, value = 15900}
    shieldDurabilityValues[9] = {position = 300, value = 8300}
    shieldDurabilityValues[10] = {position = 320, value = 3800}
    shieldDurabilityValues[11] = {position = 340, value = 0}

    return shieldDurabilityValues
end

function getOmicronValues()
    local omicronValues = {}

    omicronValues[1] = {position = 0, value = 18250}
    omicronValues[2] = {position = 160, value = 4500}
    omicronValues[3] = {position = 180, value = 3600}
    omicronValues[4] = {position = 200, value = 2880}
    omicronValues[5] = {position = 220, value = 2300}
    omicronValues[6] = {position = 240, value = 1840}
    omicronValues[7] = {position = 260, value = 1470}
    omicronValues[8] = {position = 280, value = 1200}
    omicronValues[9] = {position = 300, value = 1070}
    omicronValues[10] = {position = 320, value = 950}
    omicronValues[11] = {position = 340, value = 760}
    omicronValues[12] = {position = 360, value = 610}
    omicronValues[13] = {position = 380, value = 420}
    omicronValues[14] = {position = 400, value = 200}
    omicronValues[15] = {position = 420, value = 90}

    return omicronValues
end

function onSpawnAllXsotanAsyncButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnAllXsotanAsyncButtonPressed")
        return
    end

    local generator = AsyncXsotanGenerator(nil, function(generated)
            Placer.resolveIntersections()
        end)

    generator:startBatch()

    generator:createShip()
    generator:createCarrier()
    generator:createQuantum()
    generator:createDasher()
    generator:createSummoner()
    generator:createShielded()
    generator:createLongRange()
    generator:createShortRange()
    generator:createLootGoon()
    generator:createBuffer()
    generator:createMasterSummoner()

    generator:endBatch()
end
callable(nil, "onSpawnAllXsotanAsyncButtonPressed")

function onCreateBeaconButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateBeaconButtonPressed")
        return
    end

    local faction = Faction()
    local this = Entity()

    local position = this.position
    local p = this.right * (this:getBoundingBox().size.x + 50.0)
    position.pos = position.pos + vec3(p.x, p.y, p.z)

    SectorGenerator(Sector():getCoordinates()):createBeacon(position, faction, "This is the ${text}", {text = "Beacon Text"})

end

function onCreateStashButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateStashButtonPressed")
        return
    end

    local faction = Faction()
    local this = Entity()

    local position = this.position
    local p = this.right * (this:getBoundingBox().size.x + 50.0)
    position.pos = position.pos + vec3(p.x, p.y, p.z)

    SectorGenerator(Sector():getCoordinates()):createStash(position, "This is the ${text}", {text = "Beacon Text"})

end

function onCreateDistriButtonPressed()
    if onClient() then
        invokeServerFunction("onCreateDistriButtonPressed")
        return
    end

    local dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
    local up = vec3(0, 1, 0)
    local right = normalize(cross(dir, up))
    local pos = dir * 1000
    local distance = 50

    local generator = AsyncPirateGenerator(nil, onPiratesGenerated)
    generator:startBatch()

    if attackType == 1 then
        reward = 2.0

        generator:createScaledRaider(MatrixLookUpPosition(-dir, up, pos))
        generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos + right * distance))
        generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos + right * -distance))

    elseif attackType == 2 then
        reward = 1.5

        generator:createScaledPirate(MatrixLookUpPosition(-dir, up, pos))
        generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos + right * distance))
        generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos + right * -distance))

    elseif attackType == 3 then
        reward = 1.5

        generator:createScaledPirate(MatrixLookUpPosition(-dir, up, pos))
        generator:createScaledPirate(MatrixLookUpPosition(-dir, up, pos + right * distance))
        generator:createScaledPirate(MatrixLookUpPosition(-dir, up, pos + right * -distance))
    else
        reward = 1.0

        generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos))
        generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos + right * distance))
        generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos + right * -distance))
        generator:createScaledOutlaw(MatrixLookUpPosition(-dir, up, pos + right * -distance * 2.0))
        generator:createScaledOutlaw(MatrixLookUpPosition(-dir, up, pos + right * distance * 2.0))
    end

    generator:endBatch()
end

function onPiratesGenerated(generated)
    SpawnUtility.addEnemyBuffs(generated)
end

function onGunsButtonPressed()
    if onClient() then
        invokeServerFunction("onGunsButtonPressed")
        return
    end

    local player = Faction()
    local x, y = Sector():getCoordinates()

    for j = 1, 40 do
        local turret = SectorTurretGenerator():generate(x, y)
        player:getInventory():add(InventoryTurret(turret))
    end

end

function onGunBlueprintsButtonPressed()
    if onClient() then
        invokeServerFunction("onGunBlueprintsButtonPressed")
        return
    end

    local player = Faction()
    local x, y = Sector():getCoordinates()

    for j = 1, 40 do
        local turret = SectorTurretGenerator():generate(x, y)
        player:getInventory():add(turret)
    end
end
callable(nil, "onGunBlueprintsButtonPressed")

function onGunsGunsGunsButtonPressed()
    if onClient() then
        invokeServerFunction("onGunsGunsGunsButtonPressed")
        return
    end

    local player = Faction()

    local weaponTypes = {}
    weaponTypes[WeaponType.ChainGun] = 1
    weaponTypes[WeaponType.PointDefenseChainGun] = 1
    weaponTypes[WeaponType.Laser] = 1
    weaponTypes[WeaponType.MiningLaser] = 1
    weaponTypes[WeaponType.RawMiningLaser] = 1
    weaponTypes[WeaponType.SalvagingLaser] = 1
    weaponTypes[WeaponType.RawSalvagingLaser] = 1
    weaponTypes[WeaponType.PlasmaGun] = 1
    weaponTypes[WeaponType.RocketLauncher] = 1
    weaponTypes[WeaponType.Cannon] = 1
    weaponTypes[WeaponType.RailGun] = 1
    weaponTypes[WeaponType.RepairBeam] = 1
    weaponTypes[WeaponType.Bolter] = 1
    weaponTypes[WeaponType.LightningGun] = 1
    weaponTypes[WeaponType.TeslaGun] = 1
    weaponTypes[WeaponType.ForceGun] = 1
    weaponTypes[WeaponType.PulseCannon] = 1
    weaponTypes[WeaponType.AntiFighter] = 1
    weaponTypes[WeaponType.PointDefenseLaser] = 1

    local x, y = Sector():getCoordinates()

    local rarities = SectorTurretGenerator():getSectorRarityDistribution(x, y)
    local sum = 0
    for _, weight in pairs(rarities) do
        sum = sum + weight
    end

    for rarity, weight in pairs(rarities) do
        print ("Likelihood for %s turret: 1 in %d", tostring(Rarity(rarity)), round(sum / weight, 1))
    end

    local materials = {}
    materials[0] = 1
    materials[1] = 1
    materials[2] = 1
    materials[3] = 1
    materials[4] = 1
    materials[5] = 1
    materials[6] = 1

    local dps, tech = Balancing_GetSectorWeaponDPS(Sector():getCoordinates())

    for i = 1, 15 do

--        local material = selectByWeight(random(), materials)
--        local weaponType = selectByWeight(random(), weaponTypes)

        for j = 1, 20 do
            local turret = SectorTurretGenerator():generate(x, y)
            player:getInventory():add(InventoryTurret(turret))
        end
    end

end

function onCoaxialGunsButtonPressed()
    if onClient() then
        invokeServerFunction("onCoaxialGunsButtonPressed")
        return
    end

    local player = Faction()

    local weaponTypes = {}
    weaponTypes[WeaponType.ChainGun] = 1
    weaponTypes[WeaponType.PointDefenseChainGun] = 1
    weaponTypes[WeaponType.Laser] = 1
    weaponTypes[WeaponType.MiningLaser] = 1
    weaponTypes[WeaponType.RawMiningLaser] = 1
    weaponTypes[WeaponType.SalvagingLaser] = 1
    weaponTypes[WeaponType.RawSalvagingLaser] = 1
    weaponTypes[WeaponType.PlasmaGun] = 1
    weaponTypes[WeaponType.RocketLauncher] = 1
    weaponTypes[WeaponType.Cannon] = 1
    weaponTypes[WeaponType.RailGun] = 1
    weaponTypes[WeaponType.RepairBeam] = 1
    weaponTypes[WeaponType.Bolter] = 1
    weaponTypes[WeaponType.LightningGun] = 1
    weaponTypes[WeaponType.TeslaGun] = 1
    weaponTypes[WeaponType.ForceGun] = 1
    weaponTypes[WeaponType.PulseCannon] = 1
    weaponTypes[WeaponType.AntiFighter] = 1
    weaponTypes[WeaponType.PointDefenseLaser] = 1

    local rarities = SectorTurretGenerator():getDefaultRarityDistribution()

    local materials = {}
    materials[0] = 1
    materials[1] = 1
    materials[2] = 1
    materials[3] = 1
    materials[4] = 1
    materials[5] = 1
    materials[6] = 1

    local dps, tech = Balancing_GetSectorWeaponDPS(Sector():getCoordinates())

    local x, y = Sector():getCoordinates()

    for i = 1, 15 do

        local rarity = selectByWeight(random(), rarities)
        local material = selectByWeight(random(), materials)
        local weaponType = selectByWeight(random(), weaponTypes)

        local turret = SectorTurretGenerator():generate(x, y, 0, Rarity(rarity), weaponType, Material(material))
        turret.coaxial = true

        for j = 1, 5 do
            player:getInventory():add(InventoryTurret(turret))
        end
    end

end

function onSystemsButtonPressed()
    if onClient() then
        invokeServerFunction("onSystemsButtonPressed")
        return
    end

    local x, y = Sector():getCoordinates()
    local generator = UpgradeGenerator()

    local player = Player()
    if player and player.ownsBlackMarketDLC then
        generator.blackMarketUpgradesEnabled = true
    end
    if player and player.ownsIntoTheRiftDLC then
        generator.intoTheRiftUpgradesEnabled = true
    end

    for i = 1, 15 do
        local upgrade = generator:generateSectorSystem(x, y)
        Faction():getInventory():add(upgrade)
    end
end

function onFreeUpdateLegendaryWeaponPressed(arg)
    if onClient() then
        local button = arg
        for _, wp in pairs(FreeUpdateLegendaryWeapons) do

            if wp.buttonIndex == button.index then
                invokeServerFunction("onFreeUpdateLegendaryWeaponPressed", wp.name)
                break
            end
        end
        return
    end

    local player = Faction()
    local x, y = Sector():getCoordinates()

    local generator = LegendaryTurretGenerator()
    local func = generator[arg]

    for j = 1, 5 do
        local turret = func(generator, x, y)
        player:getInventory():addOrDrop(InventoryTurret(turret))
    end
end
callable(nil, "onFreeUpdateLegendaryWeaponPressed")

function onSystemUpgradeButtonPressed(arg)
    if onClient() then
        local button = arg
        for _, p in pairs(systemButtons) do
            if button.index == p.button.index then
                invokeServerFunction("onSystemUpgradeButtonPressed", p.script)
                break
            end
        end
        return
    end

    rarityCounter = (rarityCounter or 0) + 1
    if rarityCounter > 5 then rarityCounter = -1 end

    local x, y = Sector():getCoordinates()
    local generator = UpgradeGenerator()

    local rarity = Rarity(rarityCounter)
    local upgrade = SystemUpgradeTemplate(arg, rarity, generator:getUpgradeSeed(x, y, arg, rarity))

    if string.match(arg, "teleporterkey") then
        rarity = Rarity(RarityType.Legendary)
        upgrade = SystemUpgradeTemplate(arg, rarity, Seed(1))
    end

    Faction():getInventory():addOrDrop(upgrade)
end

function onEnergySuppressorButtonPressed()
    if onClient() then
        invokeServerFunction("onEnergySuppressorButtonPressed")
        return
    end

    local item = UsableInventoryItem("energysuppressor.lua", Rarity(RarityType.Exceptional))
    Faction():getInventory():addOrDrop(item)
    Faction():getInventory():addOrDrop(item)
    Faction():getInventory():addOrDrop(item)
    Faction():getInventory():addOrDrop(item)
end

function onClearInventoryButtonPressed()
    if onClient() then
        invokeServerFunction("onClearInventoryButtonPressed")
        return
    end

    Faction():getInventory():clear()

end

function onCreateWreckagePressed()
    if onClient() then
        invokeServerFunction("onCreateWreckagePressed")
        return
    end

    SectorGenerator(Sector():getCoordinates()):createWreckage(Galaxy():getNearestFaction(Sector():getCoordinates()))
end

function onCreateInfectedAsteroidPressed()
    if onClient() then
        invokeServerFunction("onCreateInfectedAsteroidPressed")
        return
    end

    local ship = Entity()
    local asteroid = SectorGenerator(0, 0):createSmallAsteroid(ship.translationf + ship.look * (ship.size.z * 0.5 + 20), 7, true, Material(MaterialType.Iron))
    Xsotan.infect(asteroid)

    Placer.resolveIntersections()
end

function onCreateBigInfectedAsteroidPressed()
    if onClient() then
        invokeServerFunction("onCreateBigInfectedAsteroidPressed")
        return
    end

    local ship = Entity()
    Xsotan.createBigInfectedAsteroid(ship.translationf + ship.look * (ship.size.z * 0.5 + 50))

    Placer.resolveIntersections()
end

function onCreateOwnableAsteroidPressed()
    if onClient() then
        invokeServerFunction("onCreateOwnableAsteroidPressed")
        return
    end

    SectorGenerator(0, 0):createClaimableAsteroid()
    Placer.resolveIntersections()
end

function onCreateClaimableWreckagePressed()
    if onClient() then
        invokeServerFunction("onCreateClaimableWreckagePressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())
    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local wreckage = generator:createWreckage(faction, nil, 0)

    -- find largest wreckage
    wreckage.title = "Abandoned Ship"%_t
    wreckage:addScript("wreckagetoship.lua")

    Placer.resolveIntersections()
end

function onCreateAdventurerPressed()
    if onClient() then
        invokeServerFunction("onCreateAdventurerPressed")
        return
    end

    AdventurerGuide.spawn1(Player(callingPlayer))
end

function onCreateMerchantPressed()
    if onClient() then
        invokeServerFunction("onCreateMerchantPressed")
        return
    end

    Player(callingPlayer):addScript("events/spawntravellingmerchant.lua")
end

function onGoToButtonPressed()

    local ship = Player().craft
    local target = ship.selectedObject

    ship.position = target.position

    Velocity(ship.index).velocity = dvec3(0, 0, 0)
    ship.desiredVelocity = 0

    if target.type == EntityType.Station then
        local docks = DockingPositions(target):getDockingPositions()

        for _, dock in pairs(docks) do
            local pos = vec3(dock.position.x, dock.position.y, dock.position.z)
            local dir = vec3(dock.direction.x, dock.direction.y, dock.direction.z)

            local pos = target.position:transformCoord(pos)
            local dir = target.position:transformNormal(dir)

            pos = pos + dir * (ship:getBoundingSphere().radius + 10)

            local up = target.position.up

            ship.position = MatrixLookUpPosition(-dir, up, pos)
            break
        end
    end

end

function onCreateContainerFieldButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateContainerFieldButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())
    generator:createContainerField()

    Placer.resolveIntersections()
end

function onCreateResourceAsteroidButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateResourceAsteroidButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())
    generator:createSmallAsteroid(vec3(0, 0, 0), 1.0, true, generator:getAsteroidType())

    Placer.resolveIntersections()
end

function onCreateHiddenTreasureAsteroidButtonPressed()
    if onClient() then
        invokeServerFunction("onCreateHiddenTreasureAsteroidButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())
    generator:createHiddenTreasureAsteroid(random():getDirection() * random():getFloat(0, 500), random():getFloat(5, 25), Material(MaterialType.Iron))

    Placer.resolveIntersections()
end
callable(nil, "onCreateHiddenTreasureAsteroidButtonPressed")

function onCreateTradingGoodAsteroidButtonPressed()
    if onClient() then
        invokeServerFunction("onCreateTradingGoodAsteroidButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())
    local asteroid = generator:createSmallAsteroid(random():getDirection() * random():getFloat(0, 500), random():getFloat(5, 25), false, Material(MaterialType.Iron))
    local good = TradingGood("Powerup", "Powerups", "Dudeldudelduuu", "data/textures/icons/acceleration.png", 0, 100)
    good.mesh = "data/meshes/trading-goods/accelerator.obj"
    asteroid:addScriptOnce("data/scripts/entity/utility/droptradinggoods.lua", good)

    Placer.resolveIntersections()
end
callable(nil, "onCreateTradingGoodAsteroidButtonPressed")

function onCreatePirateButtonPressed()
    if onClient() then
        invokeServerFunction("onCreatePirateButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator()

    local dir = random():getDirection()
    local matrix = MatrixLookUpPosition(-dir, vec3(0,1,0), Entity().translationf + dir * 2000)

    generator:createPirate(matrix)
end
callable(nil, "onCreatePirateButtonPressed")

function onCreateBuffedPirateButtonPressed()
    if onClient() then
        invokeServerFunction("onCreateBuffedPirateButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, function(generated)
            Placer.resolveIntersections()
            SpawnUtility.addToughness(generated, 3)
        end)

    local dir = random():getDirection()
    local matrix = MatrixLookUpPosition(-dir, vec3(0,1,0), Entity().translationf + dir * 2000)

    generator:createPirate(matrix)
end
callable(nil, "onCreateBuffedPirateButtonPressed")

function onPersecutorsButtonPressed()
    if onClient() then
        invokeServerFunction("onPersecutorsButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator()
    for i = 1, 3 do
        local dir = random():getDirection()
        local matrix = MatrixLookUpPosition(-dir, vec3(0,1,0), Entity().translationf + dir * 2000)

        generator:createRaider(matrix)
    end
end
callable(nil, "onPersecutorsButtonPressed")

function onLootGoonButtonPressed()
    if onClient() then
        invokeServerFunction("onLootGoonButtonPressed")
        return
    end

    function onGoonCreated(ship)
        ship:addScriptOnce("data/scripts/entity/enemies/lootgoon.lua")
    end

    local generator = AsyncPirateGenerator(nil, onGoonCreated)

    local dir = random():getDirection()
    local matrix = MatrixLookUpPosition(-dir, vec3(0,1,0), Entity().translationf + dir * 2000)

    generator:createLootGoon(matrix)
end
callable(nil, "onLootGoonButtonPressed")

function onPirateCarrierButtonPressed()
    if onClient() then
        invokeServerFunction("onPirateCarrierButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator()

    local dir = random():getDirection()
    local matrix = MatrixLookUpPosition(-dir, vec3(0,1,0), Entity().translationf + dir * 2000)

    generator:createCarrier(matrix)
end
callable(nil, "onPirateCarrierButtonPressed")

function onPirateCarrierTriniumButtonPressed()
    if onClient() then
        invokeServerFunction("onPirateCarrierTriniumButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator()

    local dir = random():getDirection()
    local matrix = MatrixLookUpPosition(-dir, vec3(0,1,0), Entity().translationf + dir * 2000)

    generator:createCarrier(matrix, Material(MaterialType.Trinium))
end
callable(nil, "onPirateCarrierTriniumButtonPressed")

function onPirateTorpedoButtonPressed()
    if onClient() then
        invokeServerFunction("onPirateTorpedoButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator()

    local dir = random():getDirection()
    local matrix = MatrixLookUpPosition(-dir, vec3(0,1,0), Entity().translationf + dir * 2000)

    generator:createRaider(matrix)
end
callable(nil, "onPirateTorpedoButtonPressed")

function onMotherShipButtonPressed()
    if onClient() then
        invokeServerFunction("onMotherShipButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator()

    local dir = random():getDirection()
    local matrix = MatrixLookUpPosition(-dir, vec3(0,1,0), Entity().translationf + dir * 2000)

    generator:createBoss(matrix)
end
callable(nil, "onMotherShipButtonPressed")

function onCreatePiratesButtonPressed()

    if onClient() then
        invokeServerFunction("onCreatePiratesButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, function(generated)
            Placer.resolveIntersections()
            SpawnUtility.addEnemyBuffs(generated)
        end)

    generator:startBatch()
    generator:createOutlaw()
    generator:createBandit()
    generator:createPirate()
    generator:createMarauder()
    generator:createDisruptor()
    generator:createRaider()
    generator:createCarrier()
    generator:createRavager()
    generator:createBoss()
    generator:endBatch()

end
callable(nil, "onCreatePiratesButtonPressed")

function onCreateTurretFactoryButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateTurretFactoryButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local station = generator:createTurretFactory(faction)
    station:addScript("data/scripts/entity/merchants/turretmerchant.lua")
    station.position = Matrix()

    Placer.resolveIntersections()

end

function onCreateTurretFactorySupplierButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateTurretFactorySupplierButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local station = generator:createStation(faction, "data/scripts/entity/merchants/turretfactorysupplier.lua")
    station.position = Matrix()

    Placer.resolveIntersections()

end
callable(nil, "onCreateTurretFactorySupplierButtonPressed")

function onCreateFighterMerchantButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateFighterMerchantButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local station = generator:createStation(faction, "data/scripts/entity/merchants/fightermerchant.lua")
    station.position = Matrix()

    Placer.resolveIntersections()
end

function onCreateFighterFactoryButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateFighterFactoryButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local station = generator:createFighterFactory(faction)
    station.position = Matrix()

    Placer.resolveIntersections()
end

function onCreateTorpedoMerchantButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateTorpedoMerchantButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local station = generator:createStation(faction, "data/scripts/entity/merchants/torpedomerchant.lua")
    station.position = Matrix()

    Placer.resolveIntersections()
end

function onCreateTradingPostButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateTradingPostButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local station = generator:createStation(faction, "data/scripts/entity/merchants/tradingpost.lua")
    station.position = Matrix()

    Placer.resolveIntersections()

end

function onCreatePlanetaryTradingPostButtonPressed()

    if onClient() then
        invokeServerFunction("onCreatePlanetaryTradingPostButtonPressed")
        return
    end

    local x, y = Sector():getCoordinates()
    local generator = SectorGenerator(x, y)

    local faction = Galaxy():getNearestFaction(x, y)
    local station = generator:createStation(faction)
    local specs = SectorSpecifics(x, y, Server().seed)
    local planets = {specs:generatePlanets()}
    station:addScript("data/scripts/entity/merchants/planetarytradingpost.lua", planets)
    station.position = Matrix()

    Placer.resolveIntersections()

end

function onCreateSmugglersMarketPressed()

    if onClient() then
        invokeServerFunction("onCreateSmugglersMarketPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local station = generator:createStation(faction, "data/scripts/entity/merchants/smugglersmarket.lua")
--    station:addScript("merchants/tradingpost")
    station.position = Matrix()
    station.title = "Smuggler's Market"

    Placer.resolveIntersections()

end

function onCreateResistanceOutpostPressed()

    if onClient() then
        invokeServerFunction("onCreateResistanceOutpostPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local station = generator:createStation(faction, "merchants/resistanceoutpost.lua")

    Placer.resolveIntersections()
end

function onCreateHeadQuartersPressed()

    if onClient() then
        invokeServerFunction("onCreateHeadQuartersPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local station = generator:createStation(faction, "data/scripts/entity/merchants/headquarters.lua")
    station.position = Matrix()

    Placer.resolveIntersections()

end

function onCreateResearchStationPressed()

    if onClient() then
        invokeServerFunction("onCreateResearchStationPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local station = generator:createResearchStation(faction)
    station.position = Matrix()

    Placer.resolveIntersections()

end

function onCreateShipyardButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateShipyardButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local station = generator:createShipyard(faction)
    station.position = Matrix()

    Placer.resolveIntersections()

end

function onCreateTravelHubButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateTravelHubButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local station = generator:createTravelHub(faction)
    station.position = Matrix()

    Placer.resolveIntersections()
end

function onCreateConsumerButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateConsumerButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())

    local station
    local consumerType = math.random(1, 3)
    if consumerType == 1 then
        station = generator:createStation(faction, "data/scripts/entity/merchants/casino.lua");
    elseif consumerType == 2 then
        station = generator:createStation(faction, "data/scripts/entity/merchants/biotope.lua");
    elseif consumerType == 3 then
        station = generator:createStation(faction, "data/scripts/entity/merchants/habitat.lua");
    end

    station.position = Matrix()

    Placer.resolveIntersections()
end

function onCreateRepairDockButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateRepairDockButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local station = generator:createRepairDock(faction)
    station.position = Matrix()

    Placer.resolveIntersections()
end

function onCreateEquipmentDockButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateEquipmentDockButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local station = generator:createEquipmentDock(faction)
    station.position = Matrix()

    Placer.resolveIntersections()
end

function onCreateTurretMerchantButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateTurretMerchantButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local station = generator:createStation(faction, "data/scripts/entity/merchants/turretmerchant.lua")
    station.position = Matrix()

    Placer.resolveIntersections()
end

function onCreateResourceDepotButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateResourceDepotButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local station = generator:createStation(faction, "data/scripts/entity/merchants/resourcetrader.lua")
    station.position = Matrix()

    Placer.resolveIntersections()
end


function onResetMoneyButtonPressed()
    if onClient() then
        invokeServerFunction("onResetMoneyButtonPressed")
        return
    end

    local player = Player() or Alliance()
    if not player then return end

    if player ~= nil then
        local money = 500000000

        if player.money == money then
            money = 0

            player.money = money
            player:setResources(money, money, money, money, money, money, money, money, money, money, money) -- too much, don't care

        elseif player.money == 0 then
            local x, y = Sector():getCoordinates()

            player.money = Balancing_GetSectorRichnessFactor(x, y) * 200000

            local probabilities = Balancing_GetMaterialProbability(x, y)

            for i, p in pairs(probabilities) do
                probabilities[i] = p * Balancing_GetSectorRichnessFactor(x, y) * 5000
            end

            local num = 0
            for i = NumMaterials() - 1, 0, -1 do
                probabilities[i] = probabilities[i] + num
                num = num + probabilities[i] / 2;
            end


            player:setResources(unpack(probabilities))
        else
            player.money = money
            player:setResources(money, money, money, money, money, money, money, money, money, money, money) -- too much, don't care
        end

    end

end

function onWarPressed()
    if onClient() then
        invokeServerFunction("onWarPressed")
        return
    end

    local faction, ship, player = getInteractingFaction(callingPlayer)
    Galaxy():setFactionRelationStatus(faction, Faction(), RelationStatus.War, true, true)
end
callable(nil, "onWarPressed")

function onCeasefirePressed()
    if onClient() then
        invokeServerFunction("onCeasefirePressed")
        return
    end

    local faction, ship, player = getInteractingFaction(callingPlayer)
    Galaxy():setFactionRelationStatus(faction, Faction(), RelationStatus.Ceasefire, true, true)
end
callable(nil, "onCeasefirePressed")

function onNeutralPressed()
    if onClient() then
        invokeServerFunction("onNeutralPressed")
        return
    end

    local faction, ship, player = getInteractingFaction(callingPlayer)
    Galaxy():setFactionRelationStatus(faction, Faction(), RelationStatus.Neutral, true, true)
end
callable(nil, "onNeutralPressed")

function onAllyPressed()
    if onClient() then
        invokeServerFunction("onAllyPressed")
        return
    end

    local faction, ship, player = getInteractingFaction(callingPlayer)
    Galaxy():setFactionRelationStatus(faction, Faction(), RelationStatus.Allies, true, true)
end
callable(nil, "onAllyPressed")

function onLikePressed()
    if onClient() then
        invokeServerFunction("onLikePressed")
        return
    end

    local faction, ship, player = getInteractingFaction(callingPlayer)
    changeRelations(faction, Faction(), 15000)
end

function onDislikePressed()
    if onClient() then
        invokeServerFunction("onDislikePressed")
        return
    end

    local faction, ship, player = getInteractingFaction(callingPlayer)
    changeRelations(faction, Faction(), -7500)

end

function onTitlePressed()

    local entity = Entity()

    local prefix = "args: "
    local str = ""
    for k, v in pairs(entity:getTitleArguments()) do
        str = str .. " k: " .. k .. ", v: " .. v
    end

    if str ~= "" then
        print(entity.title)
        print(prefix .. str)
    else
        local title = entity.title
        if title == "" then
            title = entity.name
        end

        print((title or entity.typename or "None"))
    end
end

function onEntityIdPressed()
    local entity = Entity()
    if not entity then
        print("No entity selected.")
    else
        local title = entity.title
        if title == "" then
            title = entity.name
        end

        print((title or entity.typename or "None") .. " : " .. tostring(entity.id))
    end
end

function onFactionIndexPressed()
    print ("${factionIndex}" % Entity())
end

function onAddPilotsPressed()
    if onClient() then
        invokeServerFunction("onAddPilotsPressed")
        return
    end

    local crew = Entity().crew
    crew:add(10, CrewMan(CrewProfessionType.Pilot, true, 1))
    Entity().crew = crew
end

function onAddSecurityPressed()
    if onClient() then
        invokeServerFunction("onAddSecurityPressed")
        return
    end

    --[[
    local crew = Entity().crew
    crew:add(15, CrewMan(CrewProfessionType.Security, true, 1))
    Entity().crew = crew
    --]]

    local ship = Entity()
    local crew = ship.crew
    local security = math.floor(ship.crew.size * 0.15)
    local defenseWeapons = 0

    local plan = ship:getFullPlanCopy()
    local goodsValue = 0
    --get value of cargo on board
    for good, amount in pairs(CargoBay():getCargos()) do
        local value = good.price * amount
        goodsValue = goodsValue + value
    end

    if Entity().isShip then
        security = security + math.floor(goodsValue * math.random(0.000005, 0.000008))
        defenseWeapons = ship.numTurrets * 10
    elseif Entity().isStation then
        security = security + math.floor (goodsValue * math.random(0.000013, 0.000017))
        defenseWeapons = math.floor(plan:getMoneyValue() * 0.0002)
    end
    local defenders = security + defenseWeapons
    local man = CrewMan(CrewProfessionType.Security)
    crew:add(defenders, man)
    Entity().crew = crew
end

function onAddBoardersPressed()
    if onClient() then
        invokeServerFunction("onAddBoardersPressed")
        return
    end

    local crew = Entity().crew
    crew:add(15, CrewMan(CrewProfessionType.Attacker, true, 1))
    Entity().crew = crew
end

function onAssignPlanToMePressed()
    if onClient() then
        invokeServerFunction("onAssignPlanToMePressed")
        return
    end

    local ship = Player(callingPlayer).craft
    ship:setMovePlan(Entity():getFullPlanCopy())

    local entry = ShipDatabaseEntry(ship.factionIndex, ship.name)
    entry:setPlan(Entity():getFullPlanCopy())
end
callable(nil, "onAssignPlanToMePressed")

function onSpeechBubbleButtonPressed()
    if onClient() then
        displaySpeechBubble(Entity(), "Facts are stubborn things. And whatever may be our wishes, our inclinations, or the dictates of our passions, they cannot alter the state of facts and evidence.")
        invokeServerFunction("onSpeechBubbleButtonPressed")
        return
    end

    Player(callingPlayer):sendChatMessage(Entity(), ChatMessageType.Chatter, "blah blah")
end

function onSpeechBubbleDialogButtonPressed()
    if onClient() then
        invokeServerFunction("onSpeechBubbleDialogButtonPressed")
        return
    end

    local entities = Sector():getEntitiesByType(EntityType.Ship or EntityType.Station)
    local otherIndex = nil
    if entities then
        otherIndex = nil--tostring(entities.index or nil)
    end
    local shipIndex = tostring(Entity().index)
    local lines =
        {
            {
                {id = shipIndex,    text = "Hi"},
                {id = otherIndex,   text = "Hello again"},
                {id = shipIndex,    text = "Nice meeting you, let's go for a drink some time soon, yeah?"}
            },
            {
                {id = shipIndex,    text = "In einem unbekannten Land"},
                {id = otherIndex,   text = "vor gar nicht allzulanger Zeit"},
                {id = shipIndex,    text = "war eine Biene sehr bekannt"},
                {id = otherIndex,   text = "von der sprach alles weit und breit"},
                {id = shipIndex,    text = "Und diese Biene, die ich meine nennt sich Maja"},
                {id = otherIndex,   text = "kleine, freche, schlaue Biene Maja"},
                {id = shipIndex,    text = "Maja fliegt durch ihre Welt"},
                {id = otherIndex,   text = "zeigt uns das was ihr gefällt"},
                {id = shipIndex,    text = "Wir treffen heute uns're Freundin Biene Maja"},
                {id = otherIndex,   text = "diese kleine freche Biene Maja"},
                {id = shipIndex,    text = "Maja, alle lieben Maja"},
                {id = otherIndex,   text = "Maja, Maja, Maja, erzähle uns von dir."},
                {id = shipIndex,    text = "yeah, good times, right? Good old times"},
                {id = otherIndex,   text = "yeah, good times, good times"},
            },

        }
    Entity():addScriptOnce("data/scripts/entity/utility/radiochatterdialog.lua", lines)
end

function onRollCreditsButtonPressed()
    if onClient() then invokeServerFunction("onRollCreditsButtonPressed") end

    if onServer() then
        Player(callingPlayer):removeScript("data/scripts/player/background/playerrollcredits.lua")
        Player(callingPlayer):addScript("data/scripts/player/background/playerrollcredits.lua")
    end
end
callable(nil, "onRollCreditsButtonPressed")

function onRollDLCCreditsButtonPressed()
    if onClient() then invokeServerFunction("onRollDLCCreditsButtonPressed") end

    if onServer() then
        Player(callingPlayer):removeScript("internal/dlc/rift/player/dlccredits.lua")
        Player(callingPlayer):addScript("internal/dlc/rift/player/dlccredits.lua")
    end
end
callable(nil, "onRollDLCCreditsButtonPressed")

function startStandardMission(mission)
    if onClient() then invokeServerFunction("addStandardMission") return end

    local entity = Entity()
    local player = Player(callingPlayer)

    if mission.hasToBeStartedFromStation then
        if not entity.isStation then
            eprint("Start this mission in station context.")
            return
        end
        if mission.name == "investigatemissingfreighters" and not entity.aiOwned then
            eprint("Npc station with AI faction needed. Start this mission in npc station context.")
            return
        end
    end

    -- these stations are required to be able finish the mission
    if mission.name == "exploresector/exploresector" then
        if not entity:hasScript("militaryoutpost.lua")
            and not entity:hasScript("headquarters.lua")
            and not entity:hasScript("researchstation.lua") then
            eprint("Mission has to be started from Military Outpost, Headquarters or Research Station.")
            return
        end
    end

    local ok, bulletin = run("data/scripts/player/missions/" .. mission.name .. ".lua", "getBulletin", entity)
    if ok ~= 0 or not bulletin then
        eprint(mission.errorMessage)
        return
    end

    player:removeScript("data/scripts/player/missions/" .. mission.name .. ".lua")
    local index = player:addScript(bulletin.script, unpack(bulletin.arguments or {}))
    invokeClientFunction(player, "trackMission", index)
end
callable(nil, "startStandardMission", mission)

function onSettlertrackPressed()
    local mission = {}
    mission.name = "settlertreck"
    mission.hasToBeStartedFromStation = true
    mission.errorMessage = "Could not add mission Settler Treck.\nCheck faction traits."
    invokeServerFunction("startStandardMission", mission)
end

function onFreeSlavesPressed()
    local mission = {}
    mission.name = "freeslaves"
    mission.hasToBeStartedFromStation = true
    mission.errorMessage = "Could not add mission Free Slaves."
    invokeServerFunction("startStandardMission", mission)
end

function onBountyHuntPressed()
    local mission = {}
    mission.name = "bountyhuntmission"
    mission.hasToBeStartedFromStation = false
    mission.errorMessage = "Could not add mission Bounty Hunt."
    invokeServerFunction("startStandardMission", mission)
end

function onReceiveCaptainPressed()
    local mission = {}
    mission.name = "receivecaptainmission"
    mission.hasToBeStartedFromStation = false
    mission.errorMessage = "Could not add mission Receive Captain."
    invokeServerFunction("startStandardMission", mission)
end

function onHideEvidencePressed()
    local mission = {}
    mission.name = "hideevidence"
    mission.hasToBeStartedFromStation = false
    mission.errorMessage = "Could not add mission Hide Evidence."
    invokeServerFunction("startStandardMission", mission)
end

function onExploreSectorPressed()
    local mission = {}
    mission.name = "exploresector/exploresector"
    mission.hasToBeStartedFromStation = true
    mission.errorMessage = "Could not add mission Explore Sector"
    invokeServerFunction("startStandardMission", mission)
end

function onClearPirateSectorPressed()
    local mission = {}
    mission.name = "clearpiratesector"
    mission.hasToBeStartedFromStation = true
    mission.errorMessage = "Could not add mission Clear Pirate Sector (no target sector).\nTry starting from another sector."
    invokeServerFunction("startStandardMission", mission)
end

function onClearXsotanSectorPressed()
    local mission = {}
    mission.name = "clearxsotansector"
    mission.hasToBeStartedFromStation = true
    mission.errorMessage = "Could not add mission Clear Xsotan Sector.\nTry starting from inside the barrier."
    invokeServerFunction("startStandardMission", mission)
end

function onTransferVesselPressed()
    local mission = {}
    mission.name = "transfervessel"
    -- not technically necessary but mission (texts) make more sense
    mission.hasToBeStartedFromStation = true
    mission.errorMessage = "Could not add mission Transfer Vessel."
    invokeServerFunction("startStandardMission", mission)
end

function onInvestigateMissingFreightersPressed()
    local mission = {}
    mission.name = "investigatemissingfreighters"
    mission.hasToBeStartedFromStation = true
    mission.errorMessage = "Could not add mission Investigate Missing Freighters."
    invokeServerFunction("startStandardMission", mission)
end

function onCoverRetreatPressed()
    local mission = {}
    mission.name = "coverretreat"
    mission.hasToBeStartedFromStation = true
    mission.errorMessage = "Could not add mission Cover Retreat.\nStation has no enemy faction."
    invokeServerFunction("startStandardMission", mission)
end

function onGoodsDeliveryPressed()
    if onClient() then invokeServerFunction("onGoodsDeliveryPressed") return end

    local entity = Entity()
    local player = Player(callingPlayer)
    local playerShip = player.craft
    local cargoAmount = 20

    if not entity.isStation then
        eprint("Start this mission in station context.")
        return
    end

    local goodTable = goods["Fish"]
    local good = TradingGood(goodTable.name, goodTable.plural, goodTable.description, goodTable.icon, goodTable.price, goodTable.size)

    local currentCargoAmount = playerShip:getCargoAmount(good);
    if currentCargoAmount < cargoAmount then
        local cargoDiff = cargoAmount - currentCargoAmount
        local addedCargo = playerShip:addCargo(good, cargoDiff)

        if addedCargo < cargoDiff then
            eprint("You need more cargo space.")
            return
        end
    end

    player:addScript("data/scripts/player/missions/delivery.lua", "Fish", cargoAmount, entity.index, 1)

end
callable(nil, "onGoodsDeliveryPressed")

function onOrganizeGoodsPressed()
    if onClient() then invokeServerFunction("onOrganizeGoodsPressed") return end

    local entity = Entity()
    local player = Player(callingPlayer)
    local x, y = Sector():getCoordinates()

    if not entity.isStation then
        eprint("Start this mission in station context.")
        return
    end

    player:addScript("data/scripts/player/missions/organizegoods.lua", "Fish", 20, entity.index, x, y, 1)

end
callable(nil, "onOrganizeGoodsPressed")

function onClearEncountersPressed()
    if onClient() then
        invokeServerFunction("onClearEncountersPressed")
        return
    end

    local sector = Sector()
    for _, pirate in pairs({sector:getEntitiesByScriptValue("is_pirate")}) do
        sector:deleteEntityJumped(pirate)
    end

    for _, xsotan in pairs({sector:getEntitiesByScriptValue("is_xsotan")}) do
        sector:deleteEntityJumped(xsotan)
    end

    for index, script in pairs(sector:getScripts()) do
        if string.starts(script, "data/scripts/events/waveencounters") then
            sector:removeScript(index)
            print("removed script: " .. script)
        end
    end

    onDisableEventsButtonPressed()
end
callable(nil, "onClearEncountersPressed")

function onDestroyEnemiesPressed()
    if onClient() then
        invokeServerFunction("onDestroyEnemiesPressed")
        return
    end

    local destroyerId = Entity().id

    local sector = Sector()
    for _, pirate in pairs({sector:getEntitiesByScriptValue("is_pirate")}) do
        pirate:destroy(destroyerId)
    end

    for _, xsotan in pairs({sector:getEntitiesByScriptValue("is_xsotan")}) do
        xsotan:destroy(destroyerId)
    end
end
callable(nil, "onDestroyEnemiesPressed")

function onDockToMePressed()
    if onClient() then
        invokeServerFunction("onDockToMePressed")
        return
    end

    local player = Player(callingPlayer)
    local craft = player.craft
    local clamps = DockingClamps(craft)

    clamps:forceDock(Entity(), nil, nil, "z", "-x")
end
callable(nil, "onDockToMePressed")

function onCraftStatsPressed()
    if onClient() then
        invokeServerFunction("onCraftStatsPressed")
        return
    end

    local stats = CraftStatsOverview(Entity())
    stats:setIncludeImpact(false, false, false)

    stats:update(Entity())
    local value = stats:getValue(CraftStatsOverviewStat.RequiredEnergy)

    print ("Max Velocity: " .. value)

end
callable(nil, "onCraftStatsPressed")

function onYieldPressed()
    if onClient() then
        invokeServerFunction("onYieldPressed")
        return
    end

    local ship = Entity()
    local player = Player(callingPlayer)

    local money = 15000000
    local resources = {200, 300, 50, 1000, 560, 10, 150}
    local items = {
        subsystems =
        {
            { x = 30, y = 120, seed = "jda0asd912", type = "data/scripts/systems/militarytcs.lua", rarity = RarityType.Exceptional, },
        },
        turrets =
        {
            { x = 12, y = -350, seed = "5asd423152", type = WeaponType.ChainGun, rarity = RarityType.Rare, },
            { x = 50, y = -250, seed = "9081u23das", type = WeaponType.ChainGun, rarity = RarityType.Exceptional, },
        },
        blueprints =
        {
            { x = 120, y = -350, seed = "r923slvny783", type = WeaponType.Bolter, rarity = RarityType.Rare, },
        },
    }

    player:invokeFunction("background/simulation/simulation.lua", "addYield", ship.name, "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.", money, resources, items)
end
callable(nil, "onYieldPressed")

function onBossPressed()
    local ship = Entity()
    registerBoss(Entity().id)
end

function onMiniBossPressed()
    local ship = Entity()
    registerBoss(Entity().id, nil, nil, nil, nil, true)
end

function onIDTextBoxChanged(textBox)
   local content = textBox.text
   if not content or content == "" or #content < 36 then return end

   local id = Uuid(content)
   if not id or not valid(id) then return end

   local entity = Sector():getEntity(id)
   if not entity then return end

   Player().selectedObject = entity
end

function onBoostJumpRangePressed()
    if onClient() then
        invokeServerFunction("onBoostJumpRangePressed")
        return
    end

    Entity():addScriptOnce("utility/jumprangeboost.lua", 15)
end
callable(nil, "onBoostJumpRangePressed")

function onPersonalFriendPressed()
    if onClient() then
        invokeServerFunction("onPersonalFriendPressed")
        return
    end

    local player = Player(callingPlayer)
    local craft = player.craft

    ShipAI():registerFriendEntity(craft.id)
end
callable(nil, "onPersonalFriendPressed")

function onPersonalFactionFriendPressed()
    if onClient() then
        invokeServerFunction("onPersonalFactionFriendPressed")
        return
    end

    ShipAI():registerFriendFaction(callingPlayer)
end
callable(nil, "onPersonalFactionFriendPressed")


function addFighterSquad(weaponType, squadName)
    squadName = squadName or "Script Squad"

    local ship = Entity()
    local hangar = Hangar(ship.index)
    if hangar == nil then return end

    local x, y = Sector():getCoordinates()

    local squad = hangar:addSquad(squadName)

    -- fill all present squads
    local fighter = SectorFighterGenerator():generate(x, y, nil, nil, weaponType)
    fighter.diameter = 1
    hangar:setBlueprint(squad, fighter)

    for i = hangar:getSquadFighters(squad), hangar:getSquadMaxFighters(squad) - 1 do
        if hangar.freeSpace < fighter.volume then return end

        hangar:addFighter(squad, fighter)
    end

end

function onAddArmedFightersButtonPressed()
    if onClient() then
        invokeServerFunction("onAddArmedFightersButtonPressed")
        return
    end

    addFighterSquad(WeaponType.RailGun, "Railgun Squad")
end

function onAddMiningFightersButtonPressed()
    if onClient() then
        invokeServerFunction("onAddMiningFightersButtonPressed")
        return
    end

    addFighterSquad(WeaponType.MiningLaser, "Mining Squad")
end

function onAddRepairFightersButtonPressed()
    if onClient() then
        invokeServerFunction("onAddRepairFightersButtonPressed")
        return
    end

    addFighterSquad(WeaponType.RepairBeam, "Repair Squad")
end
callable(nil, "onAddRepairFightersButtonPressed")

function onAddRawMiningFightersButtonPressed()
    if onClient() then
        invokeServerFunction("onAddRawMiningFightersButtonPressed")
        return
    end

    addFighterSquad(WeaponType.RawMiningLaser, "Raw Mining Squad")
end

function onAddSalvagingFightersButtonPressed()
    if onClient() then
        invokeServerFunction("onAddSalvagingFightersButtonPressed")
        return
    end

    addFighterSquad(WeaponType.SalvagingLaser, "Salvaging Squad")
end

function onAddRawSalvagingFightersButtonPressed()
    if onClient() then
        invokeServerFunction("onAddRawSalvagingFightersButtonPressed")
        return
    end

    addFighterSquad(WeaponType.RawSalvagingLaser)
end

function onAddCrewShuttlesButtonPressed()
    if onClient() then
        invokeServerFunction("onAddCrewShuttlesButtonPressed")
        return
    end

    local ship = Entity()
    local hangar = Hangar(ship.index)
    if hangar == nil then return end

    local x, y = Sector():getCoordinates()

    local squad = hangar:addSquad("Boarder Squad")

    local fighter = SectorFighterGenerator():generateCrewShuttle(x, y)
    fighter.diameter = 1
    hangar:setBlueprint(squad, fighter)

    for i = hangar:getSquadFighters(squad), hangar:getSquadMaxFighters(squad) - 1 do
        if hangar.freeSpace < fighter.volume then return end

        hangar:addFighter(squad, fighter)
    end
end

function onAddTorpedoesButtonPressed()
    if onClient() then
        invokeServerFunction("onAddTorpedoesButtonPressed")
        return
    end

    local ship = Entity()
    local launcher = TorpedoLauncher(ship.index)
    if launcher == nil then return end

    local x, y = Sector():getCoordinates()

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

function onDamagePressed()
    if onClient() then
        invokeServerFunction("onDamagePressed")
        return
    end

    local ship = Entity()
    if ship.shieldDurability and ship.shieldDurability > 0 then
        local damage = ship.shieldMaxDurability * 0.2
        ship:damageShield(damage, ship.translationf, Player(callingPlayer).craftIndex)
    else
        local damage = (ship.maxDurability or 0) * 0.2
        ship:inflictDamage(damage, 0, 0, 0, vec3(), Player(callingPlayer).craftIndex)
    end

end

function onHealPressed()
    if onClient() then
        invokeServerFunction("onHealPressed")
        return
    end

    local ship = Entity()

    if ship.shieldDurability and ship.shieldDurability < ship.shieldMaxDurability then
        local damage = ship.shieldMaxDurability * 0.2
        ship:healShield(damage)
    end

    local damage = (ship.maxDurability or 0) * 0.2
    print("damage: " .. damage)
    Durability():healDamage(damage, Player(callingPlayer).craftIndex)
end
callable(nil, "onHealPressed")

function onHealOverTimePressed()
    if onClient() then
        invokeServerFunction("onHealOverTimePressed")
        return
    end

    Entity():addScript("data/scripts/entity/utility/healovertime", 0.4, 30)
end
callable(nil, "onHealOverTimePressed")

function onInvincibleButtonPressed()
    if onClient() then
        invokeServerFunction("onInvincibleButtonPressed")
        return
    end

    local entity = Entity()

    local name = string.format("%s %s", entity.translatedTitle or "", entity.name or "")

    if entity.invincible then
        entity.invincible = false
        Player(callingPlayer):sendChatMessage("", 0, name .. " is no longer invincible")
    else
        entity.invincible = true
        Player(callingPlayer):sendChatMessage("", 0, name .. " is now invincible")
    end
end

function onPartialInvincibilityButtonPressed()
    if onClient() then
        invokeServerFunction("onPartialInvincibilityButtonPressed")
        return
    end

    local entity = Entity()

    local name = string.format("%s %s", entity.translatedTitle or "", entity.name or "")

    local durability = Durability()
    if durability.invincibility > 0.0 then
        durability.invincibility = 0.0
        Player(callingPlayer):sendChatMessage("", 0, name .. " is no longer invincible")
    else
        durability.invincibility = 0.05
        Player(callingPlayer):sendChatMessage("", 0, name .. " is now invincible (5%)")
    end
end
callable(nil, "onPartialInvincibilityButtonPressed")

function onShieldInvincibleButtonPressed()
    if onClient() then
        invokeServerFunction("onShieldInvincibleButtonPressed")
        return
    end

    local entity = Entity()
    if not entity then return end
    local shield = Shield(entity.id)
    if not shield then return end
    local name = string.format("%s %s", entity.translatedTitle or "", entity.name or "")

    if shield.invincible then
        shield.invincible = false
        Player(callingPlayer):sendChatMessage("", 0, name .. " shield is no longer invincible")
    else
        shield.invincible = true
        Player(callingPlayer):sendChatMessage("", 0, name .. " shield is now invincible")
    end
end

function onInstaBoardButtonPressed()
    if onClient() then
        invokeServerFunction("onInstaBoardButtonPressed")
        return
    end

    local player = Player(callingPlayer)
    local entity = Entity()

    if entity.index == player.craftIndex then return end

    local plan = Plan()
    while entity.durability > entity.maxDurability * 0.3 do
        local blocks = plan.size

        local block = plan:getNthBlock(random():getInt(0, blocks - 1))
        entity:inflictDamage(block.durability * 0.7, nil, nil, block.index, block.box.position, Uuid())
    end

    Boarding(entity):applyBoardingSuccessful(player.index)
end

function onDeleteButtonPressed()
    if onClient() then
        invokeServerFunction("onDeleteButtonPressed")
        return
    end

    local entity = Entity()
    local name = entity.name
    local type = entity.type
    local factionIndex = entity.factionIndex
    Sector():deleteEntityJumped(entity)

    -- prevent reconstruction and restoring
    if not factionIndex then return end
    if type ~= EntityType.Ship and type ~= EntityType.Station then return end

    local faction = Faction(factionIndex)
    if not faction then return end

    if faction.isPlayer then
        faction = Player(factionIndex)
    elseif faction.isAlliance then
        faction = Alliance(factionIndex)
    else
        return
    end

    faction:setShipDestroyed(name, true)
    faction:removeDestroyedShipInfo(name)

    removeReconstructionKits(faction, name)
end

function onDeleteJumpButtonPressed()
    if onClient() then
        invokeServerFunction("onDeleteJumpButtonPressed")
        return
    end

    Entity():addScript("deletejumped.lua")
end
callable(nil, "onDeleteJumpButtonPressed")

function onCreateBigAsteroidButtonPressed()
    if onClient() then
        invokeServerFunction("onCreateBigAsteroidButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())
    local asteroid = generator:createBigAsteroid()

    Placer.resolveIntersections()
end

function onCreateAsteroidFieldButtonPressed()
    if onClient() then
        invokeServerFunction("onCreateAsteroidFieldButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())
    local asteroid = generator:createAsteroidField()

    Placer.resolveIntersections()
end

function onCreateEmptyAsteroidFieldButtonPressed()
    if onClient() then
        invokeServerFunction("onCreateEmptyAsteroidFieldButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())
    local asteroid = generator:createEmptyAsteroidField()

    Placer.resolveIntersections()
end

function onCreateRichAsteroidFieldButtonPressed()
    if onClient() then
        invokeServerFunction("onCreateRichAsteroidFieldButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())
    local asteroid = generator:createAsteroidField(0.8)

    Placer.resolveIntersections()
end

function onCreateForestAsteroidFieldButtonPressed()
    if onClient() then
        invokeServerFunction("onCreateForestAsteroidFieldButtonPressed")
        return
    end

    local generator = AsteroidFieldGenerator(Sector():getCoordinates())
    local asteroid = generator:createForestAsteroidField(0.1)

    Placer.resolveIntersections()
end

function onCreateBallAsteroidFieldButtonPressed()
    if onClient() then
        invokeServerFunction("onCreateBallAsteroidFieldButtonPressed")
        return
    end

    local generator = AsteroidFieldGenerator(Sector():getCoordinates())
    local asteroid = generator:createBallAsteroidField(0.1)

    Placer.resolveIntersections()
end

function spawnAsteroidField(materialtype)

    local generator = AsteroidFieldGenerator(Sector():getCoordinates())
    generator.getPositionInSector = function()
        return Entity().position
    end

    local _, asteroids = generator:createAsteroidFieldEx(300, 1800, 5.0, 25.0, true, 0.8);

    for _, asteroid in pairs(asteroids) do
        local size = random():getFloat(5, 10)
        local resources = random():test(0.8)

        if random():test(0.15) then
            size = random():getFloat(5, 25)
            resources = false
        end

        local plan = PlanGenerator.makeSmallAsteroidPlan(size, resources, Material(materialtype))

        asteroid:setMovePlan(plan)
    end

    Placer.resolveIntersections()
end

function onCreateIronAsteroidFieldButtonPressed()
    if onClient() then
        invokeServerFunction("onCreateIronAsteroidFieldButtonPressed")
        return
    end

    spawnAsteroidField(MaterialType.Iron)
end
callable(nil, "onCreateIronAsteroidFieldButtonPressed")

function onCreateTitaniumAsteroidFieldButtonPressed()
    if onClient() then
        invokeServerFunction("onCreateTitaniumAsteroidFieldButtonPressed")
        return
    end

    spawnAsteroidField(MaterialType.Titanium)
end
callable(nil, "onCreateTitaniumAsteroidFieldButtonPressed")

function onCreateNaoniteAsteroidFieldButtonPressed()
    if onClient() then
        invokeServerFunction("onCreateNaoniteAsteroidFieldButtonPressed")
        return
    end

    spawnAsteroidField(MaterialType.Naonite)
end
callable(nil, "onCreateNaoniteAsteroidFieldButtonPressed")

function onCreateTriniumAsteroidFieldButtonPressed()
    if onClient() then
        invokeServerFunction("onCreateTriniumAsteroidFieldButtonPressed")
        return
    end

    spawnAsteroidField(MaterialType.Trinium)
end
callable(nil, "onCreateTriniumAsteroidFieldButtonPressed")

function onCreateXanionAsteroidFieldButtonPressed()
    if onClient() then
        invokeServerFunction("onCreateXanionAsteroidFieldButtonPressed")
        return
    end

    spawnAsteroidField(MaterialType.Xanion)
end
callable(nil, "onCreateXanionAsteroidFieldButtonPressed")

function onCreateOgoniteAsteroidFieldButtonPressed()
    if onClient() then
        invokeServerFunction("onCreateOgoniteAsteroidFieldButtonPressed")
        return
    end

    spawnAsteroidField(MaterialType.Ogonite)
end
callable(nil, "onCreateOgoniteAsteroidFieldButtonPressed")

function onCreateAvorionAsteroidFieldButtonPressed()
    if onClient() then
        invokeServerFunction("onCreateAvorionAsteroidFieldButtonPressed")
        return
    end

    spawnAsteroidField(MaterialType.Avorion)
end
callable(nil, "onCreateAvorionAsteroidFieldButtonPressed")



function onCreateManufacturerButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateManufacturerButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local station = generator:createStation(faction)
    station.position = Matrix()
    station:addScript("data/scripts/entity/merchants/factory.lua", "Rubber")

    Placer.resolveIntersections()
end

function onCreateFarmButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateFarmButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local station = generator:createStation(faction)
    station.position = Matrix()
    station:addScript("data/scripts/entity/merchants/factory.lua", "Wheat")

    Placer.resolveIntersections()
end

function onCreateCollectorButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateCollectorButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local station = generator:createStation(faction)
    station.position = Matrix()
    station:addScript("data/scripts/entity/merchants/factory.lua", "Water")

    Placer.resolveIntersections()
end

function onCreateScrapyardButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateScrapyardButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local station = generator:createStation(faction)
    station.position = Matrix()
    station:addScript("data/scripts/entity/merchants/scrapyard.lua", "Water")

    Placer.resolveIntersections()
end

function onCreateMilitaryOutpostPressed()

    if onClient() then
        invokeServerFunction("onCreateMilitaryOutpostPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local station = generator:createMilitaryBase(faction)
    station.position = Matrix()

    Placer.resolveIntersections()
end

function onCreateSolarPlantButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateSolarPlantButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local station = generator:createStation(faction)
    station.position = Matrix()
    station:addScript("data/scripts/entity/merchants/factory.lua", "Energy Cell")

    Placer.resolveIntersections()
end

function onCreateMineButtonPressed()

    if onClient() then
        invokeServerFunction("onCreateMineButtonPressed")
        return
    end

    local generator = SectorGenerator(Sector():getCoordinates())

    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())
    local station = generator:createStation(faction)
    station.position = Matrix()
    station:addScript("data/scripts/entity/merchants/factory.lua", "Silicon")

    Placer.resolveIntersections()
end

function onClearButtonPressed()
    if onClient() then
        invokeServerFunction("onClearButtonPressed")
        return
    end

    -- portion that is executed on server
    local sector = Sector()
    local self = Entity()

    local entitiesToKeep = {}
    for _, entity in pairs({sector:getEntities()}) do
        -- keep player and alliance entities and entities that belong to the selected faction
        if entity.playerOwned or entity.allianceOwned or entity.factionIndex == self.factionIndex then
            entitiesToKeep[entity.id.string] = true

            -- keep docked entities as well
            local clamps = DockingClamps(entity)
            if clamps then
                for _, id in pairs({clamps:getDockedEntities()}) do
                    local docked = Entity(id)
                    if docked then
                        entitiesToKeep[docked.id.string] = true
                    end
                end
            end
        end
    end

    for _, entity in pairs({sector:getEntities()}) do
        if not entitiesToKeep[entity.id.string] then
            sector:deleteEntity(entity)
        end
    end
end

function onClearAsteroidsButtonPressed()
    if onClient() then
        invokeServerFunction("onClearAsteroidsButtonPressed")
        return
    end

    -- portion that is executed on server
    local sector = Sector()
    local self = Entity()

    local entitiesToKeep = {}
    for _, entity in pairs({sector:getEntities()}) do
        -- keep player and alliance entities and entities that belong to the selected faction
        if entity.playerOwned or entity.allianceOwned or entity.factionIndex == self.factionIndex then
            entitiesToKeep[entity.id.string] = true

            -- keep docked entities as well
            local clamps = DockingClamps(entity)
            if clamps then
                for _, id in pairs({clamps:getDockedEntities()}) do
                    local docked = Entity(id)
                    if docked then
                        entitiesToKeep[docked.id.string] = true
                    end
                end
            end
        end
    end

    for _, entity in pairs({sector:getEntities()}) do
        if not entitiesToKeep[entity.id.string] and entity.isAsteroid then
            sector:deleteEntity(entity)
        end
    end
end

function onClearLootButtonPressed()
    if onClient() then
        invokeServerFunction("onClearLootButtonPressed")
        return
    end

    -- portion that is executed on server
    local sector = Sector()
    local self = Entity()

    for _, entity in pairs({sector:getEntities()}) do
        if entity.type == EntityType.Loot then
            sector:deleteEntity(entity)
        end
    end
end

function onClearFightersButtonPressed()
    if onClient() then
        invokeServerFunction("onClearFightersButtonPressed")
        return
    end

    -- portion that is executed on server
    local sector = Sector()
    local self = Entity()

    for _, entity in pairs({sector:getEntities()}) do
        if entity.type == EntityType.Fighter then
            sector:deleteEntity(entity)
        end
    end

end

function onClearTorpedosButtonPressed()
    if onClient() then
        invokeServerFunction("onClearTorpedosButtonPressed")
        return
    end

    -- portion that is executed on server
    local sector = Sector()
    local self = Entity()

    for _, entity in pairs({sector:getEntities()}) do
        if entity.type == EntityType.Torpedo then
            sector:deleteEntity(entity)
        end
    end
end


function onInfectAsteroidsButtonPressed()
    if onClient() then
        invokeServerFunction("onInfectAsteroidsButtonPressed")
        return
    end

    Xsotan.infectAsteroids()
end

function clearStations()
    local sector = Sector()
    for _, entity in pairs({sector:getEntitiesByType(EntityType.Station)}) do
        sector:deleteEntity(entity)
    end
end




callable(nil, "addEntityScript")
callable(nil, "addPlayerScript")
callable(nil, "addSectorScript")
callable(nil, "onAddCrewShuttlesButtonPressed")
callable(nil, "onAddCrewButtonPressed")
callable(nil, "onAddCaptainButtonPressed")
callable(nil, "onAddArmedFightersButtonPressed")
callable(nil, "onAddMiningFightersButtonPressed")
callable(nil, "onAddRawMiningFightersButtonPressed")
callable(nil, "onAddSalvagingFightersButtonPressed")
callable(nil, "onAddRawSalvagingFightersButtonPressed")
callable(nil, "onAddTorpedoesButtonPressed")
callable(nil, "onAlienAttackButtonPressed")
callable(nil, "onAlignButtonPressed")
callable(nil, "onClearButtonPressed")
callable(nil, "onClearAsteroidsButtonPressed")
callable(nil, "onClearLootButtonPressed")
callable(nil, "onClearCargoButtonPressed")
callable(nil, "onClearCrewButtonPressed")
callable(nil, "onClearFightersButtonPressed")
callable(nil, "onClearHangarButtonPressed")
callable(nil, "onClearInventoryButtonPressed")
callable(nil, "onClearTorpedoesButtonPressed")
callable(nil, "onClearTorpedosButtonPressed")
callable(nil, "onCoaxialGunsButtonPressed")
callable(nil, "onCondenseSectorButtonPressed")
callable(nil, "onCreateAdventurerPressed")
callable(nil, "onCreateAsteroidFieldButtonPressed")
callable(nil, "onCreateBeaconButtonPressed")
callable(nil, "onCreateStashButtonPressed")
callable(nil, "onCreateDistriButtonPressed")
callable(nil, "onCreateBigAsteroidButtonPressed")
callable(nil, "onCreateBigInfectedAsteroidPressed")
callable(nil, "onCreateClaimableWreckagePressed")
callable(nil, "onCreateCollectorButtonPressed")
callable(nil, "onCreateConsumerButtonPressed")
callable(nil, "onCreateContainerFieldButtonPressed")
callable(nil, "onCreateEmptyAsteroidFieldButtonPressed")
callable(nil, "onCreateEquipmentDockButtonPressed")
callable(nil, "onCreateFarmButtonPressed")
callable(nil, "onCreateFighterFactoryButtonPressed")
callable(nil, "onCreateFighterMerchantButtonPressed")
callable(nil, "onCreateHeadQuartersPressed")
callable(nil, "onCreateInfectedAsteroidPressed")
callable(nil, "onCreateManufacturerButtonPressed")
callable(nil, "onCreateMerchantPressed")
callable(nil, "onCreateMilitaryOutpostPressed")
callable(nil, "onCreateMineButtonPressed")
callable(nil, "onCreateOwnableAsteroidPressed")
callable(nil, "onCreatePlanetaryTradingPostButtonPressed")
callable(nil, "onCreateRepairDockButtonPressed")
callable(nil, "onCreateResearchStationPressed")
callable(nil, "onCreateResistanceOutpostPressed")
callable(nil, "onCreateResourceAsteroidButtonPressed")
callable(nil, "onCreateResourceDepotButtonPressed")
callable(nil, "onCreateRichAsteroidFieldButtonPressed")
callable(nil, "onCreateForestAsteroidFieldButtonPressed")
callable(nil, "onCreateBallAsteroidFieldButtonPressed")
callable(nil, "onCreateScrapyardButtonPressed")
callable(nil, "onCreateShipsButtonPressed")
callable(nil, "onCreateShipCopyButtonPressed")
callable(nil, "onCreateLocalShipButtonPressed")
callable(nil, "onCreateWeakLocalShipButtonPressed")
callable(nil, "onCreateStrongLocalShipButtonPressed")
callable(nil, "onCreateRareLocalShipButtonPressed")
callable(nil, "onCreateExceptionalLocalShipButtonPressed")
callable(nil, "onCreateExoticLocalShipButtonPressed")
callable(nil, "onCreateLegendaryLocalShipButtonPressed")
callable(nil, "onCreateBestLocalShipButtonPressed")
callable(nil, "onCreateShipyardButtonPressed")
callable(nil, "onCreateTravelHubButtonPressed")
callable(nil, "onCreateSmugglersMarketPressed")
callable(nil, "onCreateSolarPlantButtonPressed")
callable(nil, "onCreateTorpedoMerchantButtonPressed")
callable(nil, "onCreateTradingPostButtonPressed")
callable(nil, "onCreateTurretFactoryButtonPressed")
callable(nil, "onCreateTurretMerchantButtonPressed")
callable(nil, "onCreateWreckagePressed")
callable(nil, "onCrewTransportButtonPressed")
callable(nil, "onDamagePressed")
callable(nil, "onDeleteButtonPressed")
callable(nil, "onDestroyButtonPressed")
callable(nil, "onCrashButtonPressed")
callable(nil, "onDisableEventsButtonPressed")
callable(nil, "onDislikePressed")
callable(nil, "onDistressCallButtonPressed")
callable(nil, "onExodusBeaconButtonPressed")
callable(nil, "onExodusFinalBeaconButtonPressed")
callable(nil, "onExodusPointsButtonPressed")
callable(nil, "onFakeDistressCallButtonPressed")
callable(nil, "onFlyButtonPressed")
callable(nil, "onGenerateFactoryButtonPressed")
callable(nil, "onGenerateTemplateButtonPressed")
callable(nil, "onGoodsButtonPressed")
callable(nil, "onGunsButtonPressed")
callable(nil, "onGunsGunsGunsButtonPressed")
callable(nil, "onHeadhunterAttackButtonPressed")
callable(nil, "onInfectAsteroidsButtonPressed")
callable(nil, "onInvincibleButtonPressed")
callable(nil, "onShieldInvincibleButtonPressed")
callable(nil, "onInstaBoardButtonPressed")
callable(nil, "onKeysButtonPressed")
callable(nil, "onLikePressed")
callable(nil, "onMiningLasersButtonPressed")
callable(nil, "onOwnAllianceButtonPressed")
callable(nil, "onOwnButtonPressed")
callable(nil, "onPirateAttackButtonPressed")
callable(nil, "onFactionAttackSmugglerButtonPressed")
callable(nil, "onXsotanSwarmButtonPressed")
callable(nil, "onXsotanSwarmEndButtonPressed")
callable(nil, "onPrintServerLogButtonPressed")
callable(nil, "onServerSleepButtonPressed")
callable(nil, "onProgressBrakersButtonPressed")
callable(nil, "onGiveWeaponsButtonPressed")
callable(nil, "onQuestRewardButtonPressed")
callable(nil, "onResearchSatelliteButtonPressed")
callable(nil, "onResetMoneyButtonPressed")
callable(nil, "onResolveIntersectionsButtonPressed")
callable(nil, "onRespawnAsteroidsButtonPressed")
callable(nil, "onSearchAndRescueButtonPressed")
callable(nil, "onSmugglerRetaliationButtonPressed")
callable(nil, "onSpawnBattleButtonPressed")
callable(nil, "onSpawnBlockerButtonPressed")
callable(nil, "onSpawnCIWSButtonPressed")
callable(nil, "onSpawnCarrierButtonPressed")
callable(nil, "onSpawnDefendersButtonPressed")
callable(nil, "onSpawnDeferredBattleButtonPressed")
callable(nil, "onSpawnDisruptorButtonPressed")
callable(nil, "onSpawnFlagshipButtonPressed")
callable(nil, "onSpawnFleetButtonPressed")
callable(nil, "onSpawnFreighterButtonPressed")
callable(nil, "onSpawnGuardianButtonPressed")
callable(nil, "onSpawnLaserBossButtonPressed")
callable(nil, "onPirateDeliveryPressed")
callable(nil, "onSpawnMilitaryShipButtonPressed")
callable(nil, "onSpawnMinerButtonPressed")
callable(nil, "onSpawnPersecutorButtonPressed")
callable(nil, "onSpawnScientistButtonPressed")
callable(nil, "onSpawnSmugglerButtonPressed")
callable(nil, "onSpawnSwoksButtonPressed")
callable(nil, "onSpawnThe4ButtonPressed")
callable(nil, "onSpawnTheAIButtonPressed")
callable(nil, "onSpawnTorpedoBoatButtonPressed")
callable(nil, "onSpawnTraderButtonPressed")
callable(nil, "onSpawnXsotanCarrierButtonPressed")
callable(nil, "onSpawnQuantumXsotanButtonPressed")
callable(nil, "onSpawnXsotanSummonerButtonPressed")
callable(nil, "onSpawnXsotanSquadButtonPressed")
callable(nil, "onStartFighterButtonPressed")
callable(nil, "onSpawnFightersButtonPressed")
callable(nil, "onSystemUpgradeButtonPressed")
callable(nil, "onSystemsButtonPressed")
callable(nil, "onTitlePressed")
callable(nil, "onTouchAllObjectsButtonPressed")
callable(nil, "onTraderAttackedByPiratesButtonPressed")
callable(nil, "removeEntityScript")
callable(nil, "removePlayerScript")
callable(nil, "removeSectorScript")
callable(nil, "sendEntityScripts")
callable(nil, "sendPlayerScripts")
callable(nil, "sendSectorScripts")
callable(nil, "setValue")
callable(nil, "syncDocks")
callable(nil, "syncValues")
callable(nil, "onEnergySuppressorButtonPressed")
callable(nil, "onAddPilotsPressed")
callable(nil, "onAddSecurityPressed")
callable(nil, "onAddBoardersPressed")
callable(nil, "onSpeechBubbleButtonPressed")
callable(nil, "onSpeechBubbleSpamButtonPressed")
callable(nil, "onSpeechBubbleDialogButtonPressed")
callable(nil, "onRMiningButtonPressed")
callable(nil, "onTorpedoesButtonPressed")
callable(nil, "onFighterButtonPressed")
callable(nil, "onStationTutorialButtonPressed")
callable(nil, "onAsteroidShieldBossPressed")
callable(nil, "onJumperBossPressed")
callable(nil, "onFakeStashWavesPressed")
callable(nil, "onHiddenTreasurePressed")
callable(nil, "onMothershipWavesPressed")
callable(nil, "onAmbushPreperationPressed")
callable(nil, "onPirateAsteroidWavesPressed")
callable(nil, "onPirateInitiationPressed")
callable(nil, "onPirateKingPressed")
callable(nil, "onPirateMeetingPressed")
callable(nil, "onPirateProvocationWavesPressed")
callable(nil, "onPiratesHidingTreasurePressed")
callable(nil, "onPiratestationWavesPressed")
callable(nil, "onTreasureHuntPressed")
callable(nil, "onPirateTraitorPressed")
callable(nil, "onPiratesWreackagePressed")
callable(nil, "onTraderAmbushedPressed")
callable(nil, "onResetWorldBossCooldownPressed")
callable(nil, "onAncientSentinelPressed")
callable(nil, "onChemicalAccidentPressed")
callable(nil, "onCollectorPressed")
callable(nil, "onCryoColonyShipPressed")
callable(nil, "onCultShipPressed")
callable(nil, "onDeathMerchantPressed")
callable(nil, "onJesterPressed")
callable(nil, "onLostWMDPressed")
callable(nil, "onRevoltingPrisonShipPressed")
callable(nil, "onScrapBotPressed")
callable(nil, "onStoryBuyPressed")
callable(nil, "onStoryResearchPressed")
callable(nil, "onStoryBrotherhoodPressed")

