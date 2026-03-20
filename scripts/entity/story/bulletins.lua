package.path = package.path .. ";data/scripts/lib/?.lua"

local The4 = include("story/the4")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace StoryBulletins
StoryBulletins = {}

function StoryBulletins.initialize()
    if onServer() then
        -- if appropriate, post a bulletin for the 4
        local self = Entity()
        The4.tryPostBulletin(self)
    end

end



