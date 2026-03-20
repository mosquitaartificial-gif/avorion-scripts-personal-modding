
-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Wormhole
Wormhole = {}

function Wormhole.initialize()
    if onClient() then
        local entity = Entity()

        Wormhole.soundSource = SoundSource("ambiences/wormhole", Entity().translationf, 300)
        Wormhole.soundSource.minRadius = 15
        Wormhole.soundSource.maxRadius = 300
        Wormhole.soundSource.volume = 1.0
        Wormhole.soundSource:play()
    end
end

function Wormhole.onDelete()
    if valid(Wormhole.soundSource) then Wormhole.soundSource:terminate() end
end
