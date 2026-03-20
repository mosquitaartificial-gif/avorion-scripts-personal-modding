
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local SectorSpecifics = include("sectorspecifics")
include("stringutility")
include("galaxy")
include("utility")
include("music")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace MusicCoordinator
MusicCoordinator = {}
local self = MusicCoordinator

local function make_set(array)
    array = array or {}
    local set = {}

    for _, element in pairs(array) do
        set[element] = true
    end

    return set
end

if onClient() then -- purely client sided script

function MusicCoordinator.initialize()
    Player():registerCallback("onSectorChanged", "onSectorChanged")
end

local isInRift = false
function MusicCoordinator.onSectorChanged(x, y)
    -- Override cases:
    -- Empty Sector / No Tracks -> neutral tracks
    -- Home Sector -> particle & happy tracks
    -- Everything destroyed -> desolate tracks
    -- Sector rebuilt -> happy/populated tracks
    -- Inside Ring -> mostly desolate + threatening

    local inside = Balancing_InsideRing(x, y)

    local primary = {}
    local secondary = {}

    local specs = SectorSpecifics()
    specs:initialize(x, y, Seed(GameSettings().seed))

    isInRift = specs.blocked

    -- handle rift sectors
    if specs.blocked then
        MusicCoordinator.startRiftMusic()
        return
    end

    -- check relations to faction controlling this sector
    local relation = 0
    local controllingIndex = Galaxy():getControllingFaction(x, y)

    if controllingIndex then
        local faction = Galaxy():getPlayerCraftFaction()
        relation = faction:getRelations(controllingIndex)
    end

    local expectedStations = 0

    if specs.generationTemplate and specs.generationTemplate.musicTracks then
        local good, neutral, bad = specs.generationTemplate.musicTracks()

--        print ("music of " .. specs.generationTemplate.path)

        if type(good) ~= "table" then good = {} end
        if type(neutral) ~= "table" then neutral = {} end
        if type(bad) ~= "table" then bad = {} end

        -- choose good, neutral, bad based on relations to current faction
        local chosen = nil

        if relation > 30000 then
            chosen = good
--            print ("selected good relations")
        elseif relation < -20000 then
            chosen = bad
--            print ("selected bad relations")
        else
            chosen = neutral
--            print ("selected neutral ")
        end

        primary = chosen.primary
        secondary = chosen.secondary

        -- check if stations/ships are supposed to be there
        local contents = specs.generationTemplate.contents(x, y)
        expectedStations = contents.stations or 0

        -- if yes, check if they're still there
        if expectedStations > 0 then
            local station = Sector():getEntitiesByType(EntityType.Station)

            -- if no longer there, add desolate/melancholic/wreckage field tracks
            if not station then
--                print ("sector was destroyed, play desolate + sad music")
                primary = combine(TrackCollection.Desolate(), TrackCollection.Melancholic())
                secondary = {}
            end
        end
    end

    -- no music specified by template or anything else, play neutral songs
    if tablelength(primary) == 0 and tablelength(secondary) == 0 then
--        print ("nothing specified, playing unknown songs")

        -- if there are tons of wreckages & no stations, play desolate music
        local stations = Sector():getNumEntitiesByType(EntityType.Station)
        local wreckages = Sector():getNumEntitiesByType(EntityType.Wreckage)
        local asteroids = Sector():getNumEntitiesByType(EntityType.Asteroid)
        local ships = Sector():getNumEntitiesByType(EntityType.Ship)

        if stations == 0 and wreckages > asteroids / 10 and wreckages > ships then
            primary = combine(TrackCollection.Desolate(), TrackCollection.Melancholic())
            secondary = {}
        else
            primary = TrackCollection.Neutral()
            secondary = TrackCollection.All()
        end

    end

    primary = make_set(primary)
    secondary = make_set(secondary)

    -- check if it's inside the ring and adjust tracks
    if inside then
--        print ("modifying because we're inside the ring")

        -- remove too happy tracks
        local toRemove = {TrackType.Particle, TrackType.BlindingNebula, TrackType.Exhale, TrackType.InSight, TrackType.LightDance}

        -- add a few desolate ones
        local toAdd = {TrackType.Befog, TrackType.LongForgotten, TrackType.Impact, TrackType.Found, }

        for _, type in pairs(toRemove) do
            primary[type] = nil
            secondary[type] = nil
        end

        for _, type in pairs(toAdd) do
            primary[type] = true
            secondary[type] = true
        end
    end

    -- check if there are stations (ie. if sector was (re)built) and add matching tracks,
    -- remove too desolate/depressing tracks
    if not expectedStations or expectedStations == 0 then
        local actualStations = #{Sector():getEntitiesByType(EntityType.Station)}
        if actualStations >= 2 then

--            print ("modifying because we're in a rebuilt sector")

            -- remove too desolate tracks, but only if no bad relations
            local toRemove = {}
            if relation > -20000 then
                toRemove = {TrackType.Befog, TrackType.LongForgotten, TrackType.Impact, TrackType.Found, }
            end

            -- add a few happy ones
            local toAdd = {TrackType.BlindingNebula, TrackType.InSight, TrackType.LightDance}

            for _, type in pairs(toRemove) do
                primary[type] = nil
                secondary[type] = nil
            end

            for _, type in pairs(toAdd) do
                primary[type] = true
                secondary[type] = true
            end

        end
    end


    -- check if it's the player's home sector and set primary list to particle & light dance only
    local hx, hy = Player():getHomeSectorCoordinates()
    if hx == x and hy == y then
        primary = {}
        primary[TrackType.Particle] = true
        primary[TrackType.LightDance] = true
    end

    -- clean up a little, everything in primary is implicitly in secondary
    for id, _ in pairs(primary) do
        secondary[id] = nil
    end

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

end

---------------------
-- rift specific code
local riftDroneSoundPlayed = true

function MusicCoordinator.getUpdateInterval()
    return 3
end

local silentTime = 0
function MusicCoordinator.updateClient(timeStep)
    if isInRift then
        MusicCoordinator.updateRiftDrones(timeStep)
    end
end

function MusicCoordinator.updateRiftDrones(timeStep)
    -- only play music when the silence duration is too short
    if ClientSettings().silenceDuration < 4 then return end


    if Music().isPlaying then
        silentTime = 0
        return
    end

    silentTime = silentTime + timeStep
    if silentTime >= ClientSettings().silenceDuration * 0.4 then
        -- start the next track
        -- drone sounds are put in between the normal music
        silentTime = 0

        if riftDroneSoundPlayed then
            riftDroneSoundPlayed = false

            MusicCoordinator.playRiftMusic()
        else
            riftDroneSoundPlayed = true

            MusicCoordinator.playRiftDroneSound()
        end
    end
end

function MusicCoordinator.startRiftMusic()
    if ClientSettings().silenceDuration >= 4 then
        MusicCoordinator.playRiftDroneSound()
    else
        -- if the silence duration between tracks is too short we can't detect it in order to interleave drones with music
        -- this is a fallback solution to prevent playing only drone sounds
        -- only play music
        MusicCoordinator.playRiftMusic()
    end
end

function MusicCoordinator.playRiftDroneSound()
    riftDroneSoundPlayed = true

    local primary =
    {
        "data/music/background/drones/drone01.ogg",
        "data/music/background/drones/drone02.ogg",
        "data/music/background/drones/drone03.ogg",
        "data/music/background/drones/drone04.ogg",
        "data/music/background/drones/drone05.ogg",
        "data/music/background/drones/drone06.ogg",
        "data/music/background/drones/drone07.ogg",
        "data/music/background/drones/drone08.ogg",
        "data/music/background/drones/drone09.ogg",
        "data/music/background/drones/drone10.ogg",
        "data/music/background/drones/drone11.ogg",
        "data/music/background/drones/drone12.ogg",
        "data/music/background/drones/drone13.ogg",
        "data/music/background/drones/drone14.ogg",
        "data/music/background/drones/drone15.ogg",
        "data/music/background/drones/drone16.ogg",
    }

    Music():playSilence(2)
    Music():setAmbientTrackLists(primary, {})
end

function MusicCoordinator.playRiftMusic()
    riftDroneSoundPlayed = false

    local primary = {}
    for _, id in pairs(TrackCollection.Desolate()) do
        table.insert(primary, Tracks[id].path)
    end

    Music():playSilence(2)
    Music():setAmbientTrackLists(primary, {})
end

return end
