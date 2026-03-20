package.path = package.path .. ";data/scripts/lib/?.lua"

include ("galaxy")
include ("randomext")
local TorpedoUtility = include ("torpedoutility")


local BodyType = TorpedoUtility.BodyType
local WarheadType = TorpedoUtility.WarheadType
local Bodies = TorpedoUtility.Bodies
local Warheads = TorpedoUtility.Warheads
local DamageTypes = TorpedoUtility.DamageTypes


local TorpedoGenerator =  {}
TorpedoGenerator.__index = TorpedoGenerator


local function new(seed)
    local obj = setmetatable({}, TorpedoGenerator)
    obj:initialize(seed)
    return obj
end

function TorpedoGenerator:initialize(seed)
    self.seed = seed or random():createSeed()
    if type(self.seed) == "number" or type(self.seed) == "string" then
        self.seed = Seed(self.seed)
    end

    self.random = Random(self.seed)
    self.rarities = nil -- initialize this with custom rarities to get custom rarity rates
end

function TorpedoGenerator:getBodyProbability(x, y)
    local distFromCenter = length(vec2(x, y)) / Balancing_GetMaxCoordinates()

    local data = {}

    data[BodyType.Orca] =       {p = 1.0}
    data[BodyType.Hammerhead] = {d = 0.8, p = 1.5}
    data[BodyType.Ocelot] =     {d = 0.8, p = 1.5}
    data[BodyType.Stingray] =   {d = 0.6, p = 2.0}
    data[BodyType.Lynx] =       {d = 0.6, p = 2.0}
    data[BodyType.Osprey] =     {d = 0.6, p = 2.0}
    data[BodyType.Panther] =    {d = 0.45, p = 2.5}
    data[BodyType.Eagle] =      {d = 0.45, p = 2.5}
    data[BodyType.Hawk] =       {d = 0.35, p = 3.0}

    local probabilities = {}

    for t, specs in pairs(data) do
        if not specs.d or distFromCenter < specs.d then
            probabilities[t] = specs.p
        end
    end

    return probabilities
end

function TorpedoGenerator:getWarheadProbability(x, y)
    local distFromCenter = length(vec2(x, y)) / Balancing_GetMaxCoordinates()

    local data = {}

    data[WarheadType.Nuclear] =    {p = 1.0}
    data[WarheadType.Neutron] =    {d = 0.8, p = 1.5}
    data[WarheadType.Fusion] =     {d = 0.8, p = 1.5}
    data[WarheadType.Tandem] =     {d = 0.65, p = 2.0}
    data[WarheadType.Kinetic] =    {d = 0.65, p = 2.0}
    data[WarheadType.Ion] =        {d = 0.5, p = 2.5}
    data[WarheadType.Plasma] =     {d = 0.5, p = 2.5}
    data[WarheadType.Sabot] =      {d = 0.35, p = 3.0}
    data[WarheadType.EMP] =        {d = 0.35, p = 3.0}
    data[WarheadType.AntiMatter] = {d = 0.25, p = 3.5}

    local probabilities = {}

    for t, specs in pairs(data) do
        if not specs.d or distFromCenter < specs.d then
            probabilities[t] = specs.p
        end
    end

    return probabilities
end

function TorpedoGenerator:getDefaultRarityDistribution()

    local rarities = {}
    rarities[5] = 0.1 -- legendary
    rarities[4] = 1 -- exotic
    rarities[3] = 8 -- exceptional
    rarities[2] = 16 -- rare
    rarities[1] = 32 -- uncommon
    rarities[0] = 128 -- common

    return rarities
end

function TorpedoGenerator:generate(x, y, offset_in, rarity_in, warhead_in, body_in) -- server

    local offset = offset_in or 0
    local seed = self.random:createSeed()
    local sector = math.max(0, math.floor(length(vec2(x, y))) + offset)

    local dps, tech = Balancing_GetSectorWeaponDPS(sector, 0)
    dps = dps * Balancing_GetSectorTurretsUnrounded(sector, 0) -- remove turret bias

    local rarities = self.rarities or self:getDefaultRarityDistribution()
    local rarity = rarity_in or Rarity(getValueFromDistribution(rarities, self.random))

    local bodyProbabilities = self:getBodyProbability(sector, 0)
    local body = Bodies[selectByWeight(self.random, bodyProbabilities)]
    if body_in then body = Bodies[body_in] end

    local warheadProbabilities = self:getWarheadProbability(sector, 0)

    local torpedo = TorpedoTemplate()
    torpedo.type = warhead_in or selectByWeight(self.random, warheadProbabilities)
    local warhead = Warheads[torpedo.type]

    -- normal properties
    torpedo.rarity = rarity
    torpedo.tech = tech
    torpedo.size = round(body.size * warhead.size, 2)

    -- body properties
    torpedo.durability = (2 + tech / 10) * (rarity.value + 1) + 4;
    torpedo.turningSpeed = 0.3 + 0.1 * ((body.agility * 2) - 1)
    torpedo.maxVelocity = 250 + 100 * body.velocity
    torpedo.reach = (body.reach * 4 + 3 * rarity.value) * 150

    -- warhead properties
    local damage = dps * (1 + rarity.value * 0.25) * 10

    torpedo.shieldDamage = round(damage * warhead.shield / 100) * 100
    torpedo.hullDamage = round(damage * warhead.hull / 100) * 100
    torpedo.damageType = DamageTypes[torpedo.type].damageType
    torpedo.shieldPenetration = warhead.penetrateShields or false
    torpedo.shieldDeactivation = warhead.deactivateShields or false
    torpedo.shieldAndHullDamage = warhead.shieldAndHullDamage or false
    torpedo.energyDrain = warhead.energyDrain or false
    torpedo.storageEnergyDrain = (warhead.storageEnergyDrain or 0.0) * tech
    torpedo.acceleration = 0.5 * torpedo.maxVelocity * torpedo.maxVelocity / 1000 -- reach max velocity after 10km of travelled way

    if warhead.damageVelocityFactor then
        -- scale to normal dps damage dependent on maxVelocity
        torpedo.damageVelocityFactor = damage * warhead.hull / torpedo.maxVelocity
        torpedo.maxVelocity = torpedo.maxVelocity * 2.0
        torpedo.hullDamage = 0
    end

    -- torpedo visuals
    torpedo.visualSeed = self.random:getInt()
    torpedo.stripes = body.stripes
    torpedo.stripeColor = body.color
    torpedo.headColor = warhead.color
    torpedo.prefix = warhead.name
    torpedo.name = "${speed}-Class ${warhead} Torpedo"%_T
    torpedo.icon = "data/textures/icons/missile-pod.png"
    torpedo.warheadClass = warhead.name
    torpedo.bodyClass = body.name

    -- impact visuals
    torpedo.numShockwaves = 1
    torpedo.shockwaveSize = 60
    torpedo.shockwaveDuration = 0.6
    torpedo.shockwaveColor = ColorRGB(0.9, 0.6, 0.3)
    -- torpedo.shockwaveColor = ColorRGB(0.1, 0.3, 1.2) -- this looks cool :)
    torpedo.explosionSize = 6
    torpedo.flashSize = 25
    torpedo.flashDuration = 1

    return torpedo
end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
