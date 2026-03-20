package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua;"

include("defaultscripts")
include("stringutility")
include("callable")

local tx, ty = 0
local name = 0
glowColor = ColorRGB(0.1, 0.3, 0.5)

-- these are the asteroids spawned for the laser boss shield durability

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function interactionPossible(playerIndex)
    return false
end

function getUpdateInterval()
    if onServer() then
        return 5
    end
end

function initialize()
    local entity = Entity()
    entity.invincible = true
    entity.dockable = false
end

function updateClient(timeStep)
    local sector = Sector()
    local asteroid = Entity()
    -- glow - multiple to get a good strong glow that fits lasers
    sector:createGlow(asteroid.translationf, 250, glowColor)
    sector:createGlow(asteroid.translationf, 250, glowColor)
    sector:createGlow(asteroid.translationf, 250, glowColor)
    sector:createGlow(asteroid.translationf, 250, glowColor)
end

function updateServer()
    local sector = Sector()
    local boss = sector:getEntitiesByScript("data/scripts/entity/story/laserbossbehavior.lua")
    if not boss then
        terminate()
    end
end


