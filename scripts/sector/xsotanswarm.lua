package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
package.path = package.path .. ";?"

include("randomext")
include("galaxy")
local Xsotan = include("story/xsotan")
local AsyncXsotanGenerator = include("asyncxsotangenerator")
local SpawnUtility = include("spawnutility")
local ShipUtility = include("shiputility")
local SectorTurretGenerator = include ("sectorturretgenerator")
local PlanGenerator = include ("plangenerator")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace XsotanSwarm
XsotanSwarm = {}
local self = XsotanSwarm

local data = {}
local maxActiveSectors = 0

if onServer() then

data.countXsotanDestroyed = 0
data.maxBackgroundXsotan = 15
data.level2Spawned = false
data.level3Spawned = false
data.level4Spawned = false
data.level5Spawned = false
data.active = false
data.endBossFightTimer = 10 * 60

function XsotanSwarm.getUpdateInterval()
    return 5
end

function XsotanSwarm.initialize()
    local server = Server()
    if not server then
        eprint("XsotanSwarm.initialize: no server, skipping initialization")
        return
    end

    data.endBossFightTimer = 10 * 60
    maxActiveSectors = Server().xsotanInvasionSectors

    local sector = Sector()
    sector:registerCallback("onDestroyed", "onDestroyed")
    sector:registerCallback("onPlayerEntered", "onPlayerEntered")
    sector:registerCallback("onPlayerLeft", "onPlayerLeft")

    Server():registerCallback("onXsotanSwarmEventFailed", "onXsotanSwarmEventFailed")
    Server():registerCallback("onXsotanSwarmEventWon", "onXsotanSwarmEventWon")
end

function XsotanSwarm.canHappenInThisSector()
    local sector = Sector()

    local players = {sector:getPlayers()}
    if #players == 0 then return false end

    if sector:getValue("neutral_zone") == 1 then
        return false
    end

    if sector:getValue("no_xsotan_swarm") == true then
        return false
    end

    local cx, cy = sector:getCoordinates()
    local galaxy = Galaxy()
    if galaxy:sectorInRift(cx, cy) then return false end

    if maxActiveSectors <= 0 then return true end

    -- find out which sectors in the center are currently occupied by players
    -- sort them by lowest player index
    -- pick one from the start, then from the back, then from the start
    local sectorsWithPlayers = {}
    local onlinePlayers = {Server():getOnlinePlayers()}
    for _, player in pairs(onlinePlayers) do
        local x, y = player:getSectorCoordinates()

        if Balancing_InsideRing(x, y) and not galaxy:sectorInRift(x, y) then

            local added
            for _, entry in pairs(sectorsWithPlayers) do
                if entry.x == x and entry.y == y then
                    entry.player = math.min(entry.player, player.index)
                    added = true
                    break
                end
            end

            if not added then
                table.insert(sectorsWithPlayers, {x = x, y = y, player = player.index})
            end
        end
    end

    -- sort by player indices to get a somewhat random, but still somewhat deterministic selection
    table.sort(sectorsWithPlayers, function(a, b) return a.player < b.player end)

    -- pick one from the front, then from the back, and so on
    local fc = 0 -- start at 0 because we're adding 1 before reading from the table
    local bc = #sectorsWithPlayers + 1 -- start at 1 too many because we're subtracting 1 before reading from the table

    local x, y = sector:getCoordinates()
    for i = 1, maxActiveSectors do

        local active
        if i % 2 == 0 then
            -- pick from the back
            bc = bc - 1
            if bc <= 0 or bc <= fc then break end

            active = sectorsWithPlayers[bc]
        else
            -- pick from the front
            fc = fc + 1
            if fc > #sectorsWithPlayers or fc >= bc then break end

            active = sectorsWithPlayers[fc]
        end

        if active and active.x == x and active.y == y then
            return true
        end
    end

    return false
end

function XsotanSwarm.updateServer()

    if not XsotanSwarm.canHappenInThisSector() then return end

    local server = Server()

    local tmp = data.active
    data.active = server:getValue("xsotan_swarm_active")

    -- on first set to active immediately spawn some Xsotan
    -- and add wrapper missions to players
    if not tmp and data.active then
        XsotanSwarm.spawnWelcomeCommittee()
        XsotanSwarm.addWrapperMissionToPlayers()
    end

    if data.active then
        XsotanSwarm.spawnBackgroundXsotan()

        if not data.level2Spawned and XsotanSwarm.miniBossSlain() and data.countXsotanDestroyed >= 10 then
            XsotanSwarm.spawnLevel2()
        elseif not data.level3Spawned and XsotanSwarm.miniBossSlain() and data.countXsotanDestroyed >= 25 then
            XsotanSwarm.spawnLevel3()
        elseif not data.level4Spawned and XsotanSwarm.miniBossSlain() and data.countXsotanDestroyed >= 45 then
            XsotanSwarm.spawnLevel4()
        elseif not data.level5Spawned and XsotanSwarm.miniBossSlain() and data.countXsotanDestroyed >= 50 then
            XsotanSwarm.spawnLevel5()
        end
    end
end

function XsotanSwarm.onPlayerEntered(playerIndex, sectorChangeType)

    if not data.active then return end

    -- add explanation mission to players if event is active
    XsotanSwarm.addWrapperMissionToPlayers()

    -- spawn first few immediately, but only if no other player is in sector
    local players = {Sector():getPlayers()}
    if #players > 1 then return end

    XsotanSwarm.spawnWelcomeCommittee()
end

function XsotanSwarm.onPlayerLeft(playerIndex, sectorChangeType)
    local sector = Sector()
    local players = {sector:getPlayers()}
    if #players > 0 then return end -- clean up only if the last player left

    -- clean up swarm ships
    local entities = XsotanSwarm.getAllSpawnedShips()
    for _, ship in pairs(entities) do
        if ship:getValue("xsotan_destruction_limit") or ship:getValue("xsotan_swarm_boss") then
            Sector():deleteEntity(ship)
        end
    end

    -- reset values to last spawned level
    XsotanSwarm.resetToLevel(XsotanSwarm.getActiveLevel())
end

function XsotanSwarm.addWrapperMissionToPlayers()
    local players = {Sector():getPlayers()}
    for _, player in pairs(players) do
        player:addScriptOnce("data/scripts/sector/xsotanswarmmission.lua")
    end
end

function XsotanSwarm.getActiveLevel()
    if not data.level2Spawned then
        return 1
    elseif not data.level3Spawned then
        return 2
    elseif not data.level4Spawned then
        return 3
    elseif not data.level5Spawned then
        return 4
    else
        return 5
    end
end

function XsotanSwarm.resetValues()
    data.countXsotanDestroyed = 0
    data.maxBackgroundXsotan = 15
    data.level2Spawned = false
    data.level3Spawned = false
    data.level4Spawned = false
    data.level5Spawned = false
    data.endBossFightTimer = 10 * 60
end

function XsotanSwarm.resetToLevel(level)
    if level == 2 then
        data.countXsotanDestroyed = 10
        data.level2Spawned = false
        data.level3Spawned = false
        data.level4Spawned = false
        data.level5Spawned = false

    elseif level == 3 then
        data.countXsotanDestroyed = 25
        data.level2Spawned = true
        data.level3Spawned = false
        data.level4Spawned = false
        data.level5Spawned = false

    elseif level == 4 then
        data.countXsotanDestroyed = 45
        data.level2Spawned = true
        data.level3Spawned = true
        data.level4Spawned = false
        data.level5Spawned = false

    elseif level == 5 then
        data.countXsotanDestroyed = 50
        data.level2Spawned = true
        data.level3Spawned = true
        data.level4Spawned = true
        data.level5Spawned = false

    else -- level 1, and fallback for bad value in "level"
        data.countXsotanDestroyed = 0
        data.level2Spawned = false
        data.level3Spawned = false
        data.level4Spawned = false
        data.level5Spawned = false
    end
end

function XsotanSwarm.getRandomPosition()
    return MatrixLookUpPosition(random():getDirection(), random():getDirection(), random():getDirection() * 8000)
end

function XsotanSwarm.spawnWelcomeCommittee()
    local generator = AsyncXsotanGenerator(XsotanSwarm, function(generated)
        for _, xsotan in pairs(generated) do
            local shipAI = ShipAI(xsotan.id)
            for _, p in pairs({Sector():getPlayers()}) do
                shipAI:registerEnemyFaction(p.index)
            end

            shipAI:setAggressive()
            xsotan:setValue("xsotan_destruction_limit", 1)
            xsotan:setValue("xsotan_spawn_limit", 1)
        end
    end)

    generator:startBatch()
    for i = 1, 7 do
        generator:createShip(XsotanSwarm.getRandomPosition(), 1.0)
    end
    generator:endBatch()
end

function XsotanSwarm.spawnBackgroundXsotan()
    if XsotanSwarm.countAliveXsotan() > data.maxBackgroundXsotan then return end

    local xsotan = Xsotan.createShip(XsotanSwarm.getRandomPosition(), 1.0)
    if not valid(xsotan) then return end

    xsotan:setValue("xsotan_spawn_limit", 1)
    xsotan:setValue("xsotan_destruction_limit", 1)
    for _, p in pairs({Sector():getPlayers()}) do
        ShipAI(xsotan.id):registerEnemyFaction(p.index)
    end
    ShipAI(xsotan.id):setAggressive()
end

function XsotanSwarm.spawnHenchmenXsotan(num)
    local generator = AsyncXsotanGenerator(XsotanSwarm, function(generated)
        for _, xsotan in pairs(generated) do
            local shipAI = ShipAI(xsotan.id)
            for _, p in pairs({Sector():getPlayers()}) do
                shipAI:registerEnemyFaction(p.index)
            end

            shipAI:setAggressive()
            xsotan:setValue("xsotan_destruction_limit", 1)
        end

        SpawnUtility.addEnemyBuffs(generated)
    end)

    generator:startBatch()
    for i = 0, num do
        generator:createShip(XsotanSwarm.getRandomPosition(), 1.0)
    end
    generator:endBatch()
end

function XsotanSwarm.spawnLevel2()
    data.level2Spawned = true

    local xsotan = Xsotan.createShip(XsotanSwarm.getRandomPosition(), 10.0)
    if not valid(xsotan) then return end

    xsotan:setValue("xsotan_swarm_boss", true)
    xsotan.title = "Xsotan Emissary"%_T
    for _, p in pairs({Sector():getPlayers()}) do
        ShipAI(xsotan.id):registerEnemyFaction(p.index)
    end
    ShipAI(xsotan.id):setAggressive()

    broadcastInvokeClientFunction("showBossBar", xsotan, true)

    -- spawn henchmen
    XsotanSwarm.spawnHenchmenXsotan(3)
end

function XsotanSwarm.spawnLevel3()
    data.level3Spawned = true

    local xsotan = Xsotan.createQuantum(XsotanSwarm.getRandomPosition(), 15.0)
    if not valid(xsotan) then return end

    local loot = Loot(xsotan)
    loot:insert(XsotanSwarm.generateUpgrade())
    loot:insert(XsotanSwarm.generateUpgrade())
    WreckageCreator(xsotan.index).active = false

    xsotan:setValue("xsotan_swarm_boss", true)
    for _, p in pairs({Sector():getPlayers()}) do
        ShipAI(xsotan.id):registerEnemyFaction(p.index)
    end
    ShipAI(xsotan.id):setAggressive()

    broadcastInvokeClientFunction("showBossBar", xsotan, true)

    -- spawn henchmen
    XsotanSwarm.spawnHenchmenXsotan(3)
end

function XsotanSwarm.spawnLevel4()
    data.level4Spawned = true

    local xsotan = Xsotan.createSummoner(XsotanSwarm.getRandomPosition(), 15.0)
    if not valid(xsotan) then return end
    WreckageCreator(xsotan.index).active = false

    local x, y = Sector():getCoordinates()
    local loot = Loot(xsotan)
    loot:insert(InventoryTurret(SectorTurretGenerator():generate(x, y, 0, Rarity(RarityType.Exotic))))
    loot:insert(InventoryTurret(SectorTurretGenerator():generate(x, y, 0, Rarity(RarityType.Exotic))))

    -- adds legendary turret drop
    xsotan:addScriptOnce("internal/common/entity/background/legendaryloot.lua", 0.2)

    xsotan:setValue("xsotan_swarm_boss", true)
    for _, p in pairs({Sector():getPlayers()}) do
        ShipAI(xsotan.id):registerEnemyFaction(p.index)
    end
    ShipAI(xsotan.id):setAggressive()

    broadcastInvokeClientFunction("showBossBar", xsotan, true)

    -- spawn henchmen
    XsotanSwarm.spawnHenchmenXsotan(3)
end

function XsotanSwarm.spawnLevel5()
    data.level5Spawned = true

    local server = Server()
    local sector = Sector()
    local x, y = sector:getCoordinates()

    if server:getValue("xsotan_swarm_end_boss_fight") then
        -- if we are overseer sector, we need to respawn him if we get here
        if server:getValue("xsotan_swarm_end_boss_fight_x") ~= x
                or server:getValue("xsotan_swarm_end_boss_fight_y") ~= y then
            return
        end
    end

    if not server:getValue("xsotan_swarm_end_boss_fight") then
        -- avoid a race condition as multiple threads can enter this section in different sectors
        local previous = server:setValue("xsotan_swarm_end_boss_fight", true)
        if previous ~= nil then return end

        -- notify players server wide
        server:sendCallback("onXsotanSwarmEndBossSpawned", x, y)
        server:broadcastChatMessage("", ChatMessageType.Information, "A massive Xsotan appeared in sector \\s(%1%:%2%)."%_T, x, y)

        -- only one sector spawns end boss
        server:setValue("xsotan_swarm_end_boss_fight_x", x)
        server:setValue("xsotan_swarm_end_boss_fight_y", y)
    end

    -- spawn end boss
    local endBoss = XsotanSwarm.spawnEndBoss(XsotanSwarm.getRandomPosition(), 0.8)

    -- set enemy factions
    local shipAI = ShipAI(endBoss.id)
    shipAI:setAggressive()
    for _, p in pairs({sector:getPlayers()}) do
        shipAI:registerEnemyFaction(p.index)
    end

    -- add loot
    local loot = Loot(endBoss)
    loot:insert(XsotanSwarm.generateUpgrade())
    loot:insert(XsotanSwarm.generateUpgrade())
    loot:insert(XsotanSwarm.generateUpgrade())
    loot:insert(XsotanSwarm.generateUpgrade())

    -- adds legendary turret drop
    endBoss:addScriptOnce("internal/common/entity/background/legendaryloot.lua")

    -- extend global event time limit if there's not much time anymore
    local server = Server()
    local timer = server:getValue("xsotan_swarm_duration")
    if timer <= (30 * 60) then
        server:setValue("xsotan_swarm_duration", timer + (data.endBossFightTimer or 10 * 60))
    end
end

function XsotanSwarm.spawnEndBoss(position, scale)
    position = position or Matrix()
    local volume = Balancing_GetSectorShipVolume(Sector():getCoordinates())

    volume = volume * (scale or 10)

    local x, y = Sector():getCoordinates()
    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(MaterialType.Avorion)
    local faction = Xsotan.getFaction()

    local plan = PlanGenerator.makeShipPlan(faction, volume, nil, material)
    local front = PlanGenerator.makeShipPlan(faction, volume, nil, material)
    local back = PlanGenerator.makeShipPlan(faction, volume, nil, material)
    local top = PlanGenerator.makeShipPlan(faction, volume, nil, material)
    local bottom = PlanGenerator.makeShipPlan(faction, volume, nil, material)
    local left = PlanGenerator.makeShipPlan(faction, volume, nil, material)
    local right = PlanGenerator.makeShipPlan(faction, volume, nil, material)
    local frontleft= PlanGenerator.makeShipPlan(faction, volume, nil, material)
    local frontright = PlanGenerator.makeShipPlan(faction, volume, nil, material)

    -- build plan
    XsotanSwarm.attachMin(plan, back, "z")
    XsotanSwarm.attachMax(plan, front, "z")
    XsotanSwarm.attachMax(plan, front, "z")

    XsotanSwarm.attachMin(plan, bottom, "y")
    XsotanSwarm.attachMax(plan, top, "y")

    XsotanSwarm.attachMin(plan, left, "x")
    XsotanSwarm.attachMax(plan, right, "x")

    local self = findMaxBlock(plan, "z")
    local other = findMinBlock(frontleft, "x")
    plan:addPlanDisplaced(self.index, frontleft, other.index, self.box.center - other.box.center)

    local other = findMaxBlock(frontright, "x")
    plan:addPlanDisplaced(self.index, frontright, other.index, self.box.center - other.box.center)

    Xsotan.infectPlan(plan)
    local boss = Sector():createShip(faction, "", plan, position)

    -- Xsotan have random turrets
    local numTurrets = math.max(1, Balancing_GetEnemySectorTurrets(x, y) / 2)

    ShipUtility.addTurretsToCraft(boss, Xsotan.createPlasmaTurret(), numTurrets, numTurrets)
    ShipUtility.addTurretsToCraft(boss, Xsotan.createLaserTurret(), numTurrets, numTurrets)
    ShipUtility.addTurretsToCraft(boss, Xsotan.createRailgunTurret(), numTurrets, numTurrets)
    ShipUtility.addBossAntiTorpedoEquipment(boss)

    boss.title = "Xsotan Invasion Overseer"%_t
    boss.crew = boss.idealCrew
    boss.shieldDurability = boss.shieldMaxDurability

    AddDefaultShipScripts(boss)

    ShipAI(boss.id):setAggressive()
    boss:addScriptOnce("story/xsotanbehaviour.lua")
    boss:setValue("is_xsotan", true)
    boss:setValue("xsotan_swarm_boss", true)
    boss:setValue("xsotan_swarm_end_boss", true)
    WreckageCreator(boss.index).active = false

    broadcastInvokeClientFunction("showBossBar", boss)

    Boarding(boss).boardable = false
    boss.dockable = false

    return boss
end

function XsotanSwarm.attachMax(plan, attachment, dimStr)
    local self = findMaxBlock(plan, dimStr)
    local other = findMinBlock(attachment, dimStr)

    plan:addPlanDisplaced(self.index, attachment, other.index, self.box.center - other.box.center)
end

function XsotanSwarm.attachMin(plan, attachment, dimStr)
    local self = findMinBlock(plan, dimStr)
    local other = findMaxBlock(attachment, dimStr)

    plan:addPlanDisplaced(self.index, attachment, other.index, self.box.center - other.box.center)
end


function XsotanSwarm.getAllSpawnedShips()
    local entities = {Sector():getEntitiesByType(EntityType.Ship)}
    local spawnedShips = {}
    for _, ship in pairs(entities) do
        if ship:getValue("xsotan_destruction_limit") or ship:getValue("xsotan_swarm_boss") then
            table.insert(spawnedShips, ship)
        end
    end
    return spawnedShips
end

function XsotanSwarm.generateUpgrade()
    local upgrades = {
        "data/scripts/systems/arbitrarytcs.lua",
        "data/scripts/systems/militarytcs.lua",
        "data/scripts/systems/defensesystem.lua",
        "data/scripts/systems/radarbooster.lua",
        "data/scripts/systems/scannerbooster.lua",
        "data/scripts/systems/weaknesssystem.lua",
        "data/scripts/systems/resistancesystem.lua",
    }
    local randUpgrades = random():getInt(1, #upgrades)
    local upgradeName = upgrades[randUpgrades]

    local rarities = {2, 2, 2, 3, 3, 3, 3, 4}
    local randRarities = random():getInt(1, #rarities)
    local rarity = rarities[randRarities]

    return SystemUpgradeTemplate(upgradeName, Rarity(rarity), random():createSeed())
end

function XsotanSwarm.countAliveXsotan()
    local count = 0
    local entities = {Sector():getEntitiesByType(EntityType.Ship)}
    for _, ship in pairs(entities) do
        if ship:getValue("xsotan_spawn_limit") then
            count = count + 1
        end
    end
    return count
end

function XsotanSwarm.miniBossSlain()
    local entities = {Sector():getEntitiesByType(EntityType.Ship)}
    for _, ship in pairs(entities) do
        if ship:getValue("xsotan_swarm_boss") then
            return false
        end
    end
    return true
end

function XsotanSwarm.onDestroyed(index)
    local entity = Entity(index)
    if valid(entity) and entity:getValue("xsotan_destruction_limit") then
        data.countXsotanDestroyed = data.countXsotanDestroyed + 1
    end

    if valid(entity) and entity:getValue("xsotan_swarm_end_boss") then
        local server = Server()
        -- let server know that fight against end boss was won
        server:setValue("xsotan_swarm_end_boss_fight", nil)
        server:setValue("xsotan_swarm_success", true)

        --  unlock milestone
        for _, player in pairs({Sector():getPlayers()}) do
            player:sendCallback("onXsotanSwarmDefeated")
        end
    end
end

function XsotanSwarm.onXsotanSwarmEventFailed()
    XsotanSwarm.resetValues()
end

function XsotanSwarm.onXsotanSwarmEventWon()
    XsotanSwarm.resetValues()
end

function XsotanSwarm.secure()
    return data
end

function XsotanSwarm.restore(data_in)
    data = data_in
end

end

if onClient() then
function XsotanSwarm.showBossBar(entity, small)
    if not valid(entity) then return end

    -- show boss health bar on the client (mini-boss)
    registerBoss(entity.id, nil, nil, nil, nil, small)
end
end

-- for testing: Make end boss spawn immediately
function XsotanSwarm.setSpawnEndBossImmediately()
    data.countXsotanDestroyed = 50
    data.level2Spawned = true
    data.level3Spawned = true
    data.level4Spawned = true
    data.level5Spawned = false
end
