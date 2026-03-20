
package.path = package.path .. ";data/scripts/lib/?.lua"
require ("callable")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace StationAmbientSound
StationAmbientSound = {}
local self = StationAmbientSound
self.data = {}

function StationAmbientSound.getUpdateInterval()
    return 1
end

function StationAmbientSound.initialize(sound)
    if onServer() then
        -- set with no values so it resets
        self.setSound()
    else
        invokeServerFunction("sync")
    end
end

function StationAmbientSound.onDelete()
    if self.source then self.source:terminate() end
end

function StationAmbientSound.sync()
    invokeClientFunction(Player(callingPlayer), "initSound", self.data)
end
callable(StationAmbientSound, "sync")

function StationAmbientSound.setSound(sound, volume, minRange, maxRange)
    self.data = self.data or {}

    self.data.sound = sound or "ambiences/station1"
    self.data.volume = volume or self.data.volume or 1
    self.data.minRange = minRange or self.data.minRange or 10
    self.data.maxRange = maxRange or self.data.maxRange or 200

    broadcastInvokeClientFunction("initSound", self.data)
end

function StationAmbientSound.initSound(data)

    self.data = data

    if self.data.sound then

        self.source = SoundSource(self.data.sound, Entity().translationf, self.data.maxRange)
        self.source.minRadius = self.data.minRange
        self.source.maxRadius = self.data.maxRange
        self.source.volume = self.data.volume
        self.source:play()

    else
        if self.source then self.source:terminate() end

        self.source = nil
    end

end

function StationAmbientSound.updateClient(timeStep)

    if self.source then
        self.source.position = Entity().translationf
    end

end
