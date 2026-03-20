-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace RemoveInvincibilityOnSectorChanged
RemoveInvincibilityOnSectorChanged = {}

if onServer() then
function RemoveInvincibilityOnSectorChanged.onSectorChanged()
    Entity().invincible = false
    terminate()
end
end
