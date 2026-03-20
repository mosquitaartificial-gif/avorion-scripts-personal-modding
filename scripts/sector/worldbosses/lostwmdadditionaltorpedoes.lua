package.path = package.path .. ";data/scripts/lib/?.lua"

local TorpedoUtility = include ("torpedoutility")
local TorpedoGenerator = include("torpedogenerator")
include ("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace LostWMDAdditionalTorpedoes
LostWMDAdditionalTorpedoes = {}

if onServer() then
function LostWMDAdditionalTorpedoes.initialize()
    Entity():registerCallback("onTorpedoLaunched", "onTorpedoLaunched")
end

function LostWMDAdditionalTorpedoes.onTorpedoLaunched(entityId, torpedoId)
    local self = Entity()
    local sector = Sector()
    local x, y = sector:getCoordinates()
    local generator = TorpedoGenerator()

    -- replace shot torpedo so that boss never runs out
    local launcher = TorpedoLauncher(self)
    local torpedoTemplate = generator:generate(x, y, 0, Rarity(RarityType.Petty), TorpedoUtility.WarheadType.Neutron)
    launcher:addTorpedo(torpedoTemplate)

    -- generate 3 additional torpedoes
    local warheadTypes =
    {
        TorpedoUtility.WarheadType.Plasma,
        TorpedoUtility.WarheadType.Sabot,
        TorpedoUtility.WarheadType.Kinetic,
    }

    -- find all potential targets
    local ships = {}
    for _, ship in pairs({sector:getEntitiesByType(EntityType.Ship)}) do
        if ship.playerOwned or ship.allianceOwned then
            table.insert(ships, ship)
        end
    end

    for i = 1, 3 do
        torpedoTemplate = generator:generate(x, y, 0, Rarity(RarityType.Petty), warheadTypes[i])

        -- create torpedo
        local desc = TorpedoDescriptor()
        local torpedoAI = desc:getComponent(ComponentType.TorpedoAI)
        local torpedo = desc:getComponent(ComponentType.Torpedo)
        local velocity = desc:getComponent(ComponentType.Velocity)
        local owner = desc:getComponent(ComponentType.Owner)
        local flight = desc:getComponent(ComponentType.DirectFlightPhysics)
        local durability = desc:getComponent(ComponentType.Durability)

        -- set torpedo properties
        torpedoAI.driftTime = 0.5 -- can't be 0

        torpedo.shootingCraft = self.id
        torpedo.firedByAIControlledPlayerShip = false
        torpedo.collisionWithParentEnabled = false
        torpedo:setTemplate(torpedoTemplate)

        owner.factionIndex = self.factionIndex

        flight.drifting = true
        flight.maxVelocity = torpedoTemplate.maxVelocity
        flight.turningSpeed = torpedoTemplate.turningSpeed

        velocity.velocityf = random():getDirection() * 10 -- "eject speed" that is then used to calculate fly speed

        durability.maximum = torpedoTemplate.durability
        durability.durability = torpedoTemplate.durability

        desc.position = MatrixLookUpPosition(random():getDirection(), random():getDirection(), self.translationf)

        -- select a random target
        local target = randomEntry(ships)

        -- set target
        torpedoAI.target = target.id
        torpedo.intendedTargetFaction = target.factionIndex

        -- create torpedo
        sector:createEntity(desc)
    end
end
end
