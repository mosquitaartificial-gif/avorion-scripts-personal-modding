-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace StoryStarter
StoryStarter = {}

if onServer() then

function StoryStarter.getUpdateInterval()
    return 10
end

function StoryStarter.updateServer(timestep)
    local player = Player()

    if not GameSettings().storyline then
        return
    end

    if player:getValue("story_completed") then
        terminate()
        return
    end

    if player:getValue("tutorial_pirateraid_accomplished") and player.playtime > 60 * 60 then
        player:addScriptOnce("data/scripts/player/background/storyquestutility.lua")
        terminate()
    end
end

end
