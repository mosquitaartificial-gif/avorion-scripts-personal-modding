package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local SectorFighterGenerator = include("sectorfightergenerator")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace BehemothBehavior
BehemothBehavior = {}
local self = BehemothBehavior

function BehemothBehavior.initialize()
    if onServer() then
        Entity():addAbsoluteBias(StatsBonuses.Pilots, 1200)
        Entity():addAbsoluteBias(StatsBonuses.FighterCargoPickup, 1)

        local hangar = Hangar(mothership)
        local squadsToAdd = 10 - hangar.numSquads
        for i = 1, squadsToAdd do
            hangar:addSquad("1")
        end
    end

end

function BehemothBehavior.getUpdateInterval()
    return 0.5
end

function BehemothBehavior.update()
    local thrusters = Thrusters()
    thrusters.fixedStats = true
    thrusters.baseYaw = 0.0001
    thrusters.basePitch = 0.0001
    thrusters.baseRoll = 0.0001
    thrusters.thrust = vec3(0.001)

    local engine = Engine()
    engine.maxVelocity = 50

    if onServer() then
        local numWreckages = Sector():getNumEntitiesByType(EntityType.Wreckage)
        local maxFighters = math.min(120, numWreckages * 2)

        local fighters = self.getFighters()

        if #fighters < maxFighters then
            self.spawnSalvagingFighter()
        end

        self.updateFighterTargets()
    else
        for _, fighter in pairs(self.getFighters()) do
            local ai = FighterAI(fighter)
            ai.ignoreMothershipOrders = true
        end
    end
end

function BehemothBehavior.getFighters()
    if not self.fighters then
        self.fighters = {}
        local fighters = {Sector():getEntitiesByComponent(ComponentType.FighterAI)}

        for _, fighter in pairs(fighters) do
            local ai = FighterAI(fighter)
            if ai.mothershipId == Entity().id then
                ai.ignoreMothershipOrders = true

                table.insert(self.fighters, fighter)
            end
        end
    else
        -- remove fighters that are invalid (destroyed)
        local size = #self.fighters
        local i = 1
        while i <= size do
            local fighter = self.fighters[i]

            if not valid(fighter) then
                local lastIndex = #self.fighters
                self.fighters[i] = self.fighters[lastIndex]
                self.fighters[lastIndex] = nil
                size = size - 1
            else
                i = i + 1
            end
        end
    end

    return self.fighters
end

function BehemothBehavior.findNearbyWreckage(fighter, wreckages)

    local fighterPosition = fighter.translationf

    -- find the 5 nearest wreckages
    local candidates = {}
    for _, p in pairs(wreckages) do
        local wreckage = p.wreckage
        local wreckagePosition = p.position

        local d2 = distance2(wreckagePosition, fighterPosition)
        if #candidates == 5 and d2 < candidates[5].d2 then
            table.remove(candidates)
        end

        if #candidates < 5 then
            table.insert(candidates, {wreckage = wreckage, d2 = d2})
            table.sort(candidates, function(a, b) return a.d2 < b.d2 end)
        end
    end

    if #candidates == 0 then return end

    -- choose one at random
    local i = random():getInt(1, #candidates)
    return candidates[i].wreckage
end

function BehemothBehavior.updateFighterTargets()

    local wreckages = {}
    for _, wreckage in pairs({Sector():getEntitiesByType(EntityType.Wreckage)}) do
        table.insert(wreckages, {wreckage = wreckage, position = wreckage.translationf})
    end

    for _, fighter in pairs(self.getFighters()) do
        local ai = FighterAI(fighter)
        if ai then
            local target = ai.target
            local orders = ai.orders

            if not Entity(target) or orders ~= FighterOrders.Attack then
                local wreckage = self.findNearbyWreckage(fighter, wreckages)
                if wreckage then
                    ai:setOrders(FighterOrders.Attack, wreckage.id)
                else
                    ai:setOrders(FighterOrders.Defend, Entity().id)
                end
            end
        end
    end
end

function BehemothBehavior.spawnSalvagingFighter()
    local sector = Sector()
    local mothership = Entity()

    local x, y = sector:getCoordinates()

    if not BehemothBehavior.fighter then
        BehemothBehavior.fighter = SectorFighterGenerator():generate(0, 150, nil, Rarity(RarityType.Exceptional), WeaponType.RawSalvagingLaser, Material(MaterialType.Xanion))
    end

    local hangar = Hangar(mothership)
    local squadIndex = hangar.numSquads - 1
    local squadId = hangar:getSquadId(squadIndex)

    local desc = BehemothBehavior.fighter:makeDescriptor()
    desc.factionIndex = mothership.factionIndex
    desc.mothership = mothership

    local startPosition = hangar:getRandomStartPosition()
    if not startPosition then return end

    desc.position = startPosition

    local ai = desc:getComponent(ComponentType.FighterAI)
    ai:setSquad(squadIndex, squadId)
    ai.ignoreMothershipOrders = true

    local fighter = sector:createEntity(desc)

    if self.fighters then
        table.insert(self.fighters, fighter)
    end

end
