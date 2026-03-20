-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace DeleteOnHitByShots
DeleteOnHitByShots = {}

if onServer() then

function DeleteOnHitByShots.initialize()
    Sector():registerCallback("onShotHit", "updateDeletion")
end

function DeleteOnHitByShots.onSectorChanged()
    Sector():registerCallback("onShotHit", "updateDeletion")
end

function DeleteOnHitByShots.updateDeletion()
    Sector():deleteEntityJumped(Entity())
end

end
