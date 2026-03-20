
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local OperationExodus = include ("story/operationexodus")
local Placer = include("placer")
include("music")

local SectorTemplate = {}

-- must be defined, will be used to get the probability of this sector
function SectorTemplate.getProbabilityWeight(x, y, seed, factionIndex, innerArea)
    if factionIndex then
        if innerArea then
            return 0
        else
            return 0
        end
    else
        return 50
    end
end

function SectorTemplate.offgrid(x, y)
    return true
end

-- this function returns whether or not a sector should have space gates
function SectorTemplate.gates(x, y)
    return false
end

-- this function returns how many ships there will be in the sector (from, to)
function SectorTemplate.ships(x, y)
    return 0, 0
end

-- this function returns how many stations there will be in the sector (from, to)
function SectorTemplate.stations(x, y)
    return 0, 0
end

function SectorTemplate.musicTracks()
    local good = {
        primary = combine(TrackCollection.Neutral(), TrackCollection.Desolate()),
        secondary = combine(TrackCollection.Happy(), TrackCollection.Neutral()),
    }

    local neutral = {
        primary = combine(TrackCollection.Neutral(), TrackCollection.Desolate()),
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

-- don't actually spawn anything here, player has script that'll spawn the boss if all conditions are met
--    Sector():addScriptOnce("data/scripts/player/events/spawnasteroidboss.lua")

    Placer.resolveIntersections()
end

function SectorTemplate.contents(x, y)
    local seed = Seed(string.join({GameSeed(), x, y, "asteroidshieldboss"}, "-"))
    math.randomseed(seed)

    local random = random()
    local contents = {ships = 0, stations = 0, seed = tostring(seed)}

    return contents, random
end

return SectorTemplate
