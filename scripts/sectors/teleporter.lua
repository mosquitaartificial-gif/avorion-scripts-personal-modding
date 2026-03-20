package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local TeleporterGenerator = include ("teleportergenerator")
local Balancing = include ("galaxy")
local Placer = include("placer")
include ("stationextensions")
include ("stringutility")
include ("music")

local SectorTemplate = {}

-- must be defined, will be used to get the probability of this sector
function SectorTemplate.getProbabilityWeight(x, y, serverSeed)

    local d = length(vec2(x, y)) - Balancing.BlockRingMax
    if d > 0 and d < 1.2 then
        if makeFastHash(x, y, serverSeed.int32) % 4 == 1 then
            return 10000000
        end
    end

    return 0
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
    local seed = Seed(string.join({GameSeed(), x, y, "teleporter"}, "-"))
    math.randomseed(seed);
    local random = random()
    local contents = {ships = 0, stations = 0, seed = tostring(seed)}

    return contents, random
end

function SectorTemplate.musicTracks()
    local good = {
        primary = combine(TrackCollection.Desolate()),
        secondary = combine(TrackCollection.Melancholic(), TrackCollection.Neutral()),
    }

    local neutral = {
        primary = combine(TrackCollection.Middle(), TrackCollection.Desolate()),
        secondary = TrackCollection.All(),
    }

    local bad = {
        primary = combine(TrackCollection.Middle(), TrackCollection.Desolate()),
        secondary = TrackCollection.Neutral(),
    }

    return good, neutral, bad
end

-- player is the player who triggered the creation of the sector (only set in start sector, otherwise nil)
function SectorTemplate.generate(player, seed, x, y)
    local contents, random = SectorTemplate.contents(x, y)

    TeleporterGenerator.createTeleporters()

    Sector():addScriptOnce("story/activateteleport")
    Sector():addScriptOnce("sector/background/respawnteleporter.lua")

    Placer.resolveIntersections()
end

return SectorTemplate
