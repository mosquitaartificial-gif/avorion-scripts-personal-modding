package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("galaxy")
include ("goods")
include ("utility")
include("randomext")
include ("stringutility")
local SectorTurretGenerator = include ("sectorturretgenerator")
local TorpedoGenerator = include ("torpedogenerator")
local TorpedoUtility = include ("torpedoutility")
local SectorFighterGenerator = include("sectorfightergenerator")
include("weapontype")

local ShipUtility = {}

local ArmedWeapons = {WeaponTypes.getArmed()}
ShipUtility.ArmedWeapons = ArmedWeapons

local DefenseWeapons =
{
    WeaponType.PointDefenseChainGun,
    WeaponType.PointDefenseLaser,
    WeaponType.AntiFighter,
}
ShipUtility.DefenseWeapons = DefenseWeapons

local AttackWeapons =
{
    WeaponType.ChainGun,
    WeaponType.Bolter,
    WeaponType.PlasmaGun,
    WeaponType.Laser,
    WeaponType.PulseCannon,
    WeaponType.Cannon,
    WeaponType.RocketLauncher,
    WeaponType.LightningGun,
    WeaponType.TeslaGun,
    WeaponType.RailGun,
}
ShipUtility.AttackWeapons = AttackWeapons

local AntiShieldWeapons =
{
    WeaponType.PlasmaGun,
    WeaponType.PulseCannon,
    WeaponType.LightningGun,
    WeaponType.TeslaGun,
}
ShipUtility.AntiShieldWeapons = AntiShieldWeapons

local AntiHullWeapons =
{
    WeaponType.Bolter,
    WeaponType.RailGun,
}
ShipUtility.AntiHullWeapons = AntiHullWeapons

local ArtilleryWeapons =
{
    WeaponType.Cannon,
    WeaponType.RocketLauncher,
}
ShipUtility.ArtilleryWeapons = ArtilleryWeapons

-- weapons that can have their range increased a lot without looking too strange
local LongRangeWeapons =
{
    WeaponType.ChainGun,
    WeaponType.Bolter,
    WeaponType.PlasmaGun,
    WeaponType.PulseCannon,
    WeaponType.Cannon,
    WeaponType.RocketLauncher,
    WeaponType.LightningGun,
    WeaponType.RailGun,
}
ShipUtility.LongRangeWeapons = LongRangeWeapons


local AllTorpedoes =
{
    TorpedoUtility.WarheadType.Nuclear,
    TorpedoUtility.WarheadType.Neutron,
    TorpedoUtility.WarheadType.Fusion,
    TorpedoUtility.WarheadType.Tandem,
    TorpedoUtility.WarheadType.Kinetic,
    TorpedoUtility.WarheadType.Ion,
    TorpedoUtility.WarheadType.Plasma,
    TorpedoUtility.WarheadType.Sabot,
    TorpedoUtility.WarheadType.EMP,
    TorpedoUtility.WarheadType.AntiMatter,
}
ShipUtility.AllTorpedoes = AllTorpedoes

local NormalTorpedoes =
{
    TorpedoUtility.WarheadType.Nuclear,
    TorpedoUtility.WarheadType.Neutron,
    TorpedoUtility.WarheadType.Fusion,
    TorpedoUtility.WarheadType.Kinetic,
    TorpedoUtility.WarheadType.Plasma,
    TorpedoUtility.WarheadType.AntiMatter,
}
ShipUtility.NormalTorpedoes = NormalTorpedoes

local DisruptorTorpedoes =
{
    TorpedoUtility.WarheadType.Ion,
    TorpedoUtility.WarheadType.Plasma,
    TorpedoUtility.WarheadType.EMP,
    TorpedoUtility.WarheadType.Fusion,
}
ShipUtility.DisruptorTorpedoes = DisruptorTorpedoes

local PersecutorTorpedoes =
{
    TorpedoUtility.WarheadType.Tandem,
    TorpedoUtility.WarheadType.Sabot,
    TorpedoUtility.WarheadType.AntiMatter,
}
ShipUtility.PersecutorTorpedoes = PersecutorTorpedoes


local MilitaryShipTypes =
{
    Scout = 1,
    Sentinel = 2,
    Hunter = 3,
    Corvette = 4,
    Frigate = 5,
    Cruiser = 6,
    Destroyer = 7,
    Dreadnought = 8,
    Battleship = 9,
}
ShipUtility.MilitaryShipTypes = MilitaryShipTypes

local TraderShipTypes =
{
    Trader = 1,
    Merchant = 2,
    Salesman = 3,
}
ShipUtility.TraderShipTypes = TraderShipTypes

local FreighterShipTypes =
{
    Transporter = 1,
    Lifter = 2,
    Freighter = 3,
    Loader = 4,
    CargoTransport = 5,
    CargoHauler = 6,
    HeavyCargoHauler = 7,
}
ShipUtility.FreighterShipTypes = FreighterShipTypes

local MinerShipTypes =
{
    LightMiner = 1,
    Miner = 2,
    HeavyMiner = 3,
    MiningMoloch = 4,
}
ShipUtility.MinerShipTypes = MinerShipTypes


function ShipUtility.getMaxVolumes()
    local maxVolumes = {}

    local base = 2000
    local scale = 2.5

    -- base class (explorer)
    maxVolumes[1] = base * math.pow(scale, -3.0)
    maxVolumes[2] = base * math.pow(scale, -2.0)
    maxVolumes[3] = base * math.pow(scale, -1.0)
    maxVolumes[4] = base * math.pow(scale, 0.0)
    maxVolumes[5] = base * math.pow(scale, 1.0)
    maxVolumes[6] = base * math.pow(scale, 2.0)
    maxVolumes[7] = base * math.pow(scale, 2.5)
    maxVolumes[8] = base * math.pow(scale, 3.0)
    maxVolumes[9] = base * math.pow(scale, 3.5)
    maxVolumes[10] = base * math.pow(scale, 4.0)
    maxVolumes[11] = base * math.pow(scale, 4.5)
    maxVolumes[12] = base * math.pow(scale, 5.0)

    return maxVolumes
end

function ShipUtility.getMilitaryNameByVolume(volume)
    local names =
    {
        {name = "Scout /* ship title */"%_T, type = MilitaryShipTypes.Scout},
        {name = "Sentinel /* ship title */"%_T, type = MilitaryShipTypes.Sentinel},
        {name = "Hunter /* ship title */"%_T, type = MilitaryShipTypes.Hunter},
        {name = "Corvette /* ship title */"%_T, type = MilitaryShipTypes.Corvette},
        {name = "Frigate /* ship title */"%_T, type = MilitaryShipTypes.Frigate},
        {name = "Cruiser /* ship title */"%_T, type = MilitaryShipTypes.Cruiser},
        {name = "Destroyer /* ship title */"%_T, type = MilitaryShipTypes.Destroyer},
        {name = "Dreadnought /* ship title */"%_T, type = MilitaryShipTypes.Dreadnought},
        {name = "Battleship /* ship title */"%_T, type = MilitaryShipTypes.Battleship},
    }

    local volumes = ShipUtility.getMaxVolumes()

    for i = 1, #names do
        if volume < volumes[i] then
            return names[i].name, names[i].type
        end
    end

    return names[#names].name, names[#names].type
end

function ShipUtility.getTraderNameByVolume(volume)
    local names =
    {
        {name = "Trader /* ship title */"%_T, type = TraderShipTypes.Trader},
        {name = "Merchant /* ship title */"%_T, type = TraderShipTypes.Merchant},
        {name = "Salesman /* ship title */"%_T, type = TraderShipTypes.Salesman},
    }

    local volumes = ShipUtility.getMaxVolumes()

    for i = 1, #names do
        if volume < volumes[i] then
            return names[i].name, names[i].type
        end
    end

    return names[#names].name, names[#names].type
end

function ShipUtility.getFreighterNameByVolume(volume)
    local names =
    {
        {name = "Transporter /* ship title */"%_T, type = FreighterShipTypes.Transporter},
        {name = "Lifter /* ship title */"%_T, type = FreighterShipTypes.Lifter},
        {name = "Freighter /* ship title */"%_T, type = FreighterShipTypes.Freighter},
        {name = "Loader /* ship title */"%_T, type = FreighterShipTypes.Loader},
        {name = "Cargo Transport /* ship title */"%_T, type = FreighterShipTypes.CargoTransport},
        {name = "Cargo Hauler /* ship title */"%_T, type = FreighterShipTypes.CargoHauler},
        {name = "Heavy Cargo Hauler /* ship title */"%_T, type = FreighterShipTypes.HeavyCargoHauler},
    }

    local volumes = ShipUtility.getMaxVolumes()

    for i = 1, #names do
        if volume < volumes[i] then
            return names[i].name, names[i].type
        end
    end

    return names[#names].name, names[#names].type
end

function ShipUtility.getMinerNameByVolume(volume)
    local names =
    {
        {name = "Light Miner /* ship title */"%_T, type = MinerShipTypes.LightMiner},
        {name = "Light Miner /* ship title */"%_T, type = MinerShipTypes.LightMiner},
        {name = "Miner /* ship title */"%_T, type = MinerShipTypes.Miner},
        {name = "Miner /* ship title */"%_T, type = MinerShipTypes.Miner},
        {name = "Heavy Miner /* ship title */"%_T, type = MinerShipTypes.HeavyMiner},
        {name = "Heavy Miner /* ship title */"%_T, type = MinerShipTypes.HeavyMiner},
        {name = "Mining Moloch /* ship title */"%_T, type = MinerShipTypes.MiningMoloch},
        {name = "Mining Moloch /* ship title */"%_T, type = MinerShipTypes.MiningMoloch},
    }

    local volumes = ShipUtility.getMaxVolumes()

    for i = 1, #names do
        if volume < volumes[i] then
            return names[i].name, names[i].type
        end
    end

    return names[#names].name, names[#names].type
end

function ShipUtility.getPDCRarity()
    local sector = Sector()
    if not sector then return nil end
    if not Server then return nil end

    local distanceValue = round((500 - length(vec2(sector:getCoordinates()))) / 150)
    local rarityValue = math.min(RarityType.Exotic, math.max(RarityType.Common, distanceValue + Server().difficulty))

    return Rarity(rarityValue)
end

function ShipUtility.addTurretsToCraft(entity, turret, numTurrets, maxNumTurrets)

    local maxNumTurrets = maxNumTurrets or 10
    if maxNumTurrets == 0 then return end

    turret = copy(turret)
    turret.coaxial = false -- this can lead to the turret's name still containing "Coax", so make sure to only pass non-coaxial turrets!

    local wantedTurrets = math.max(1, round(numTurrets / turret.slots))

    local values = {entity:getTurretPositionsLineOfSight(turret, numTurrets)}
    while #values == 0 and turret.size > 0.5 do
        turret.size = turret.size - 0.5
        values = {entity:getTurretPositionsLineOfSight(turret, numTurrets)}
    end

    local c = 1;
    numTurrets = tablelength(values) / 2 -- divide by 2 since getTurretPositions returns 2 values per turret

    -- limit the turrets of the ships to maxNumTurrets
    numTurrets = math.min(numTurrets, maxNumTurrets)

    local strengthFactor = wantedTurrets / numTurrets
    if numTurrets > 0 and strengthFactor > 1.0 then
        entity.damageMultiplier = math.max(entity.damageMultiplier, strengthFactor)
    end

    for i = 1, numTurrets do
        local position = values[c]; c = c + 1;
        local part = values[c]; c = c + 1;

        if part ~= nil then
            entity:addTurret(turret, position, part)
        else
            -- print("no turrets added, no place for turret found")
        end
    end

end


function ShipUtility.addArmedTurretsToCraft(entity, amount)

    local faction = Faction(entity.factionIndex)

    local turrets = {}

    local items = faction:getInventory():getItemsByType(InventoryItemType.TurretTemplate)

    for i, slotItem in pairs(items) do
        local turret = slotItem.item

        if turret.armed then
            table.insert(turrets, turret)
        end
    end

    -- find out what kind of turret to add to the craft
    if #turrets == 0 then return end

    local turret
    if entity.isStation then
        -- stations get turrets with highest reach

        local currentReach = 0.0

        for i, t in pairs(turrets) do
            for j = 0, t.numWeapons - 1 do

                local reach = t.reach
                if reach > currentReach then
                    currentReach = reach
                    turret = t
                end
            end
        end

    else
        -- ships get random turrets
        turret = turrets[math.random(1, #turrets)]
    end

    -- find out how many are possible with the current crew limitations
    local requiredCrew = turret:getCrew()

    if requiredCrew.size > 0 then
        local numTurrets = 0;

        if entity.isStation then
            numTurrets = math.random(40, 60)
        else
            numTurrets = amount
        end

        -- add turrets
        ShipUtility.addTurretsToCraft(entity, turret, numTurrets)

    end

end

function ShipUtility.addUnarmedTurretsToCraft(entity, amount)

    local faction = Faction(entity.factionIndex)

    local turrets = {}

    local items = faction:getInventory():getItemsByType(InventoryItemType.TurretTemplate)
    for i, slotItem in pairs(items) do
        local turret = slotItem.item

        if turret.civil then
            table.insert(turrets, turret)
        end
    end

    if #turrets == 0 then return end

    local turret = turrets[math.random(1, #turrets)]

    -- find out how many are possible with the current crew limitations
    local requiredCrew = turret:getCrew()

    if requiredCrew.size > 0 then
        local numTurrets = 0;

        if entity.isStation then
            numTurrets = math.random(40, 60)
        else
            numTurrets = amount
        end

        -- add turrets
        ShipUtility.addTurretsToCraft(entity, turret, numTurrets)
    end

end

function ShipUtility.addTorpedoesToCraft(craft, torpedo, amount)
    local launcher = TorpedoLauncher(craft)
    for i = 1, amount do
        launcher:addTorpedo(torpedo)
    end
end

function ShipUtility.addSpecializedEquipment(craft, weaponTypes, torpedoTypes, turretfactor, torpedofactor, turretRange)

    turretfactor = turretfactor or 1
    torpedofactor = torpedofactor or 0
    weaponTypes = weaponTypes or {}
    torpedoTypes = torpedoTypes or {}

    local faction = Faction(craft.factionIndex)
    local x, y

    -- let the torpedo and turret generator seeds be based on the home sector of a faction
    -- this makes sure that factions always have the same kinds of weapons
    if faction then
        x, y = faction:getHomeSectorCoordinates()
    else
        x, y = Sector():getCoordinates()
    end

    local seed = SectorSeed(x, y)

    if #weaponTypes > 0 and turretfactor > 0 then
        local turrets = Balancing_GetEnemySectorTurrets(Sector():getCoordinates()) * turretfactor + 2

        -- select a weapon out of the weapon types that can be used in this sector
        local weaponProbabilities = Balancing_GetWeaponProbability(x, y)
        local tmp = weaponTypes
        weaponTypes = {}

        for _, type in pairs(tmp) do
            if weaponProbabilities[type] and weaponProbabilities[type] > 0 then
                table.insert(weaponTypes, type)
            end
        end

        local weaponType = randomEntry(random(), weaponTypes)

        -- equip turrets
        local generator = SectorTurretGenerator(seed)
        generator.maxRarity = Rarity(RarityType.Rare)
        generator.coaxialAllowed = false

        local rarity = nil
        if weaponType == WeaponType.PointDefenseChainGun then
            rarity = ShipUtility.getPDCRarity()
        end

        if weaponType then
            local turret = generator:generate(x, y, 0, rarity, weaponType)

            if turretRange then
                turret:setRange(turretRange)
            end

            ShipUtility.addTurretsToCraft(craft, turret, turrets)
        end
    end

    if #torpedoTypes > 0 and torpedofactor > 0 then
        local torpedoes = Balancing_GetEnemySectorTurrets(Sector():getCoordinates()) * torpedofactor + 1

        -- select a torpedo out of the torpedo types that can be used in this sector
        local generator = TorpedoGenerator(seed)
        local torpedoProbabilities = generator:getWarheadProbability(x, y)
        local tmp = torpedoTypes
        torpedoTypes = {}

        for _, type in pairs(tmp) do
            if torpedoProbabilities[type] and torpedoProbabilities[type] > 0 then
                table.insert(torpedoTypes, type)
            end
        end

        if #torpedoTypes > 0 then
            local torpedoType = randomEntry(random(), torpedoTypes)

            -- equip torpedoes
            local torpedo = generator:generate(x, y, 0, nil, torpedoType, nil)
            ShipUtility.addTorpedoesToCraft(craft, torpedo, torpedoes)
        end
    end
end

function ShipUtility.addDisruptorEquipment(craft)
    local weaponTypes = AntiShieldWeapons
    local torpedoTypes = DisruptorTorpedoes

    ShipUtility.addSpecializedEquipment(craft, weaponTypes, torpedoTypes, 1, 0.5)

    craft:setTitle("${toughness}Disruptor ${class}"%_T, {toughness = "", class = ShipUtility.getMilitaryNameByVolume(craft.volume)})
    craft:setValue("is_armed", true)

    craft:addScript("icon.lua", "data/textures/icons/pixel/anti-shield.png")
end

function ShipUtility.addCIWSEquipment(craft)
    ShipUtility.addSpecializedEquipment(craft, {WeaponType.PointDefenseChainGun}, nil, 0.5)
    ShipUtility.addSpecializedEquipment(craft, {WeaponType.AntiFighter}, nil, 0.5)

    craft:setTitle("${toughness}CIWS ${class}"%_T, {toughness = "", class = ShipUtility.getMilitaryNameByVolume(craft.volume)})
    craft:setValue("is_armed", true)

    craft:addScript("icon.lua", "data/textures/icons/pixel/anti-carrier.png")
end

function ShipUtility.addAntiTorpedoEquipment(craft)
    ShipUtility.addSpecializedEquipment(craft, {WeaponType.PointDefenseChainGun}, nil, 1.0)

    craft:setValue("is_armed", true)
end

function ShipUtility.addBossAntiTorpedoEquipment(craft, numTurrets, color, reach)
    numTurrets = numTurrets or 15

    local x, y = Sector():getCoordinates()
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false
    local turret = generator:generate(x, y, -30, Rarity(RarityType.Exceptional), WeaponType.PointDefenseChainGun)
    local weapons = {turret:getWeapons()}
    turret:clearWeapons()
    for _, weapon in pairs(weapons) do
        weapon.reach = reach or 1000
        weapon.pmaximumTime = weapon.reach / weapon.pvelocity

        if color then weapon.pcolor = color end
        turret:addWeapon(weapon)
    end
    turret.crew = Crew()
    ShipUtility.addTurretsToCraft(craft, turret, numTurrets, numTurrets)
end

function ShipUtility.addBossAntiFighterEquipment(craft, numTurrets, color, reach)
    numTurrets = numTurrets or 15

    local x, y = Sector():getCoordinates()
    local generator = SectorTurretGenerator()
    generator.coaxialAllowed = false
    local turret = generator:generate(x, y, -30, Rarity(RarityType.Exceptional), WeaponType.AntiFighter)
    local weapons = {turret:getWeapons()}
    turret:clearWeapons()
    for _, weapon in pairs(weapons) do
        weapon.reach = reach or 1000
        weapon.pmaximumTime = weapon.reach / weapon.pvelocity

        if color then weapon.pcolor = color end
        turret:addWeapon(weapon)
    end
    turret.crew = Crew()
    ShipUtility.addTurretsToCraft(craft, turret, numTurrets, numTurrets)
end

function ShipUtility.addMilitaryEquipment(craft, turretfactor, torpedofactor)
    local weaponTypes = AttackWeapons
    local torpedoTypes = NormalTorpedoes

    ShipUtility.addSpecializedEquipment(craft, weaponTypes, torpedoTypes, turretfactor, torpedofactor)

    craft:setTitle(ShipUtility.getMilitaryNameByVolume(craft.volume), {})
    craft:setValue("is_armed", true)

    craft:addScript("icon.lua", "data/textures/icons/pixel/military-ship.png")
end

function ShipUtility.addTorpedoBoatEquipment(craft)
    local weaponTypes = AttackWeapons
    local torpedoTypes = NormalTorpedoes

    ShipUtility.addSpecializedEquipment(craft, weaponTypes, torpedoTypes, 0.5, 1.0)
    ShipUtility.addSpecializedEquipment(craft, nil, torpedoTypes, nil, 1.0)

    craft:setTitle("${toughness}Torpedo-${class}"%_T, {toughness = "", class = ShipUtility.getMilitaryNameByVolume(craft.volume)})
    craft:setValue("is_armed", true)

    craft:addScript("icon.lua", "data/textures/icons/pixel/torpedoboat.png")
end

function ShipUtility.addArtilleryEquipment(craft)
    local weaponTypes = ArtilleryWeapons
    local torpedoTypes = NormalTorpedoes

    ShipUtility.addSpecializedEquipment(craft, weaponTypes, torpedoTypes, 1.5, 1.0)

    craft:setTitle("${toughness}Artillery ${class}"%_T, {toughness = "", class = ShipUtility.getMilitaryNameByVolume(craft.volume)})
    craft:setValue("is_armed", true)

    craft:addScript("icon.lua", "data/textures/icons/pixel/artillery.png")
end

function ShipUtility.addPersecutorEquipment(craft)
    local weaponTypes = AttackWeapons
    local torpedoTypes = PersecutorTorpedoes

    ShipUtility.addSpecializedEquipment(craft, weaponTypes, torpedoTypes, 1.5, 1)

    local launcher = TorpedoLauncher(craft)
    if launcher.numTorpedoes == 0 then
        ShipUtility.addSpecializedEquipment(craft, nil, {TorpedoUtility.WarheadType.Nuclear}, 0, 1)
    end

    craft:setTitle("${toughness}Persecutor ${class}"%_T, {toughness = "", class = ShipUtility.getMilitaryNameByVolume(craft.volume)})
    craft:setValue("is_armed", true)

    craft:addScript("icon.lua", "data/textures/icons/pixel/persecutor.png")
end

function ShipUtility.addBlockerEquipment(craft)
    local weaponTypes = AttackWeapons

    ShipUtility.addSpecializedEquipment(craft, weaponTypes, nil, 1, 0)

    craft:setTitle("${toughness}Hyperspace Blocker ${class}"%_T, {toughness = "", class = ShipUtility.getMilitaryNameByVolume(craft.volume)})
    craft:setValue("is_armed", true)

    craft:addScript("icon.lua", "data/textures/icons/pixel/block.png")
    craft:addScript("blocker.lua", 1)
end

function ShipUtility.addFlagShipEquipment(craft)
    local weaponTypes = AttackWeapons
    local torpedoTypes = PersecutorTorpedoes

    ShipUtility.addSpecializedEquipment(craft, {WeaponType.AntiFighter, WeaponType.PointDefenseChainGun}, nil, 0.25, nil)
    ShipUtility.addSpecializedEquipment(craft, weaponTypes, torpedoTypes, 3, 1)

    craft:setTitle("${toughness}Flagship"%_T, {toughness = ""})
    craft:setValue("is_armed", true)

    craft:addScript("icon.lua", "data/textures/icons/pixel/flagship.png")
end

function ShipUtility.addCarrierEquipment(craft, fighters)
    fighters = fighters or 10

    -- add fighters
    local hangar = Hangar(craft.index)
    hangar:addSquad("Alpha")
    hangar:addSquad("Beta")
    hangar:addSquad("Gamma")

    local faction = Faction(craft.factionIndex)

    local generator = SectorFighterGenerator()
    generator.factionIndex = faction.index

    local numFighters = 0
    for squad = 0, 2 do
        local fighter = generator:generateArmed(faction:getHomeSectorCoordinates())
        for i = 1, 7 do
            hangar:addFighter(squad, fighter)

            numFighters = numFighters + 1
            if numFighters >= fighters then break end
        end

        if numFighters >= fighters then break end
    end

    ShipUtility.addCIWSEquipment(craft)

    craft:setTitle("${toughness}Carrier ${class}"%_T, {toughness = "", class = ShipUtility.getMilitaryNameByVolume(craft.volume)})
    craft:setValue("is_armed", true)
    craft:addScript("icon.lua", "data/textures/icons/pixel/carrier.png")

end



function ShipUtility.stripWreckage(wreckage)
    local toRemove = {}
    local toTransform = {}

    local plan = wreckage:getMovePlan()

    for n = 0, plan.numBlocks - 1 do
        local block = plan:getNthBlock(n)

        if block.harvestFactor >= 0.5 then
            table.insert(toRemove, block.index)
        elseif block.harvestFactor >= 0.2 then
            table.insert(toTransform, block.index)
        end

        ::continue::
    end

    for _, index in pairs(toTransform) do
        plan:setBlockType(index, BlockType.Hull)
    end

    for _, index in pairs(toRemove) do
        plan:removeBlock(index)
    end

    wreckage:setMovePlan(plan)
end

function ShipUtility.addCargoToCraft(entity)
    local g = legalSpawnableGoods[getInt(1, #legalSpawnableGoods)]

    local x, y = Sector():getCoordinates()
    local maxValue = Balancing_GetSectorRichnessFactor(x, y, 50) * 750000

    -- still allow some high-value transports
    if math.random() < 0.2 then
        maxValue = maxValue * (1 + math.random() * 4)
    end

    local maxAmount = maxValue / g.price
    local amount = 100 + math.random() * 1000
    amount = math.ceil(math.min(maxAmount, amount))

    entity:addCargo(g:good(), amount)
end

function ShipUtility.addIllegalCargoToCraft(entity)
    local g = illegalSpawnableGoods[getInt(1, #illegalSpawnableGoods)]

    local x, y = Sector():getCoordinates()
    local maxValue = Balancing_GetSectorRichnessFactor(x, y) * 25000

    local maxAmount = maxValue / g.price
    local amount = 1000 + math.random() * 100
    amount = math.ceil(math.min(maxAmount, amount))

    entity:addCargo(g:good(), amount)
end



return ShipUtility

