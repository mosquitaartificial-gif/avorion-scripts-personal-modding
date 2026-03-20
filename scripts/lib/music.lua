package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

TrackType =
{
    Particle = 1,
    BlindingNebula = 2,
    Exhale = 3,
    Float = 4,
    HappilyLost = 5,
    Beyond = 6,
    InSight = 7,
    Befog = 8,
    LightDance = 9,
    LongForgotten = 10,
    Interim = 11,
    Impact = 12,
    Found = 13,
    BehindStorms = 14,

    -- modders: reserve track numbers 15 - 1000 for additional future music
}

Tracks = {}
Tracks[TrackType.Particle] = {type = TrackType.Particle, path = "data/music/background/particle.ogg"}
Tracks[TrackType.BlindingNebula] = {type = TrackType.BlindingNebula, path = "data/music/background/blinding_nebula.ogg"}
Tracks[TrackType.Exhale] = {type = TrackType.Exhale, path = "data/music/background/exhale.ogg"}
Tracks[TrackType.Float] = {type = TrackType.Float, path = "data/music/background/float.ogg"}
Tracks[TrackType.HappilyLost] = {type = TrackType.HappilyLost, path = "data/music/background/happily_lost.ogg"}
Tracks[TrackType.Beyond] = {type = TrackType.Beyond, path = "data/music/background/beyond.ogg"}
Tracks[TrackType.InSight] = {type = TrackType.InSight, path = "data/music/background/in_sight.ogg"}
Tracks[TrackType.Befog] = {type = TrackType.Befog, path = "data/music/background/befog.ogg"}
Tracks[TrackType.LightDance] = {type = TrackType.LightDance, path = "data/music/background/light_dance.ogg"}
Tracks[TrackType.LongForgotten] = {type = TrackType.LongForgotten, path = "data/music/background/long_forgotten.ogg"}
Tracks[TrackType.Interim] = {type = TrackType.Interim, path = "data/music/background/interim.ogg"}
Tracks[TrackType.Impact] = {type = TrackType.Impact, path = "data/music/background/impact.ogg"}
Tracks[TrackType.Found] = {type = TrackType.Found, path = "data/music/background/found.ogg"}
Tracks[TrackType.BehindStorms] = {type = TrackType.BehindStorms, path = "data/music/background/behind_storms.ogg"}

TrackCollection = {}

-- Happy + Neutral + Middle -> All

function TrackCollection.All()
    return
    {
        TrackType.Particle,
        TrackType.BlindingNebula,
        TrackType.Exhale,
        TrackType.Float,
        TrackType.HappilyLost,
        TrackType.Beyond,
        TrackType.InSight,
        TrackType.Befog,
        TrackType.LightDance,
        TrackType.LongForgotten,
        TrackType.Interim,
        TrackType.Impact,
        TrackType.Found,
        TrackType.BehindStorms,
    }
end

function TrackCollection.Happy()
    return
    {
        TrackType.Particle,
        TrackType.BlindingNebula,
        TrackType.Exhale,
        TrackType.Float,
        TrackType.InSight,
        TrackType.LightDance,
        TrackType.Interim,
    }
end

function TrackCollection.Neutral()
    return
    {
        TrackType.BehindStorms,
        TrackType.HappilyLost,
        TrackType.Beyond,
    }
end

function TrackCollection.Middle()
    return
    {
        TrackType.Befog,
        TrackType.Impact,
        TrackType.Found,
        TrackType.LongForgotten,
    }
end

function TrackCollection.HappyNoParticle()
    return
    {
        TrackType.BlindingNebula,
        TrackType.Exhale,
        TrackType.Float,
        TrackType.InSight,
        TrackType.LightDance,
        TrackType.Interim,
    }
end

function TrackCollection.Cold()
    return
    {
        TrackType.BlindingNebula,
        TrackType.HappilyLost,
        TrackType.Beyond,
        TrackType.Befog,
        TrackType.LongForgotten,
    }
end

function TrackCollection.Desolate()
    return
    {
        TrackType.Beyond,
        TrackType.LongForgotten,
        TrackType.Found,
        TrackType.BehindStorms,
    }
end

function TrackCollection.Melancholic()
    return
    {
        TrackType.Impact,
        TrackType.Found,
    }
end

function TrackCollection.HappyNeutral()
    return
    {
        TrackType.BlindingNebula,
        TrackType.Exhale,
        TrackType.HappilyLost,
        TrackType.BehindStorms,
        TrackType.Interim,
    }
end

local function append(tbl, element)

    if type(element) == "table" then
        for _, other in pairs(element) do
            append(tbl, other)
        end
    else
        table.insert(tbl, element)
    end

end

function combine(...)
    local result = {}

    for _, element in pairs({...}) do
        append(result, element)
    end

    return result
end
