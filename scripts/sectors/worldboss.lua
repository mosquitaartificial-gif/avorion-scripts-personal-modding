
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local SectorGenerator = include ("SectorGenerator")
local Placer = include("placer")
include("music")

local SectorTemplate = {}

-- must be defined, will be used to get the probability of this sector
function SectorTemplate.getProbabilityWeight(x, y)
    return 5
end

function SectorTemplate.offgrid(x, y)
    return true
end

-- this function returns whether or not a sector should have space gates
function SectorTemplate.gates(x, y)
    return false
end

-- this function returns what relevant contents there will be in the sector (exact)
function SectorTemplate.contents(x, y)
    local seed = Seed(string.join({GameSeed(), x, y, "worldboss"}, "-"))
    math.randomseed(seed);

    local random = random()

    local contents = {ships = 0, stations = 0, seed = tostring(seed)}

    local generator = SectorGenerator(x, y)
    contents.asteroidEstimation = generator:estimateAsteroidNumbers(3, 8)

    return contents, random
end

function SectorTemplate.musicTracks()
    local good = {
        primary = TrackCollection.Desolate(),
        secondary = combine(TrackCollection.Neutral()),
    }

    local neutral = {
        primary = TrackCollection.Desolate(),
        secondary = TrackCollection.All(),
    }

    local bad = {
        primary = combine(TrackCollection.Middle(), TrackCollection.Desolate()),
        secondary = combine(TrackCollection.Neutral(), TrackCollection.Desolate()),
    }

    return good, neutral, bad
end

local bossScripts =
{
    "data/scripts/sector/worldbosses/ancientsentinel.lua",
    "data/scripts/sector/worldbosses/chemicalaccident.lua",
    "data/scripts/sector/worldbosses/collector.lua",
    "data/scripts/sector/worldbosses/cryocolonyship.lua",
    "data/scripts/sector/worldbosses/cultship.lua",
    "data/scripts/sector/worldbosses/deathmerchant.lua",
    "data/scripts/sector/worldbosses/jester.lua",
    "data/scripts/sector/worldbosses/lostwmd.lua",
    "data/scripts/sector/worldbosses/revoltingprisonship.lua",
    "data/scripts/sector/worldbosses/scrapbot.lua",
}

-- player is the player who triggered the creation of the sector (only set in start sector, otherwise nil)
function SectorTemplate.generate(player, seed, x, y)
    local contents, random = SectorTemplate.contents(x, y)

    local number = random:getInt(1, #bossScripts)
    bossSelection = bossScripts[number]

    local sector = Sector()
    sector:addScriptOnce(bossSelection)
    sector:setValue("no_xsotan_swarm", true)
end

return SectorTemplate
