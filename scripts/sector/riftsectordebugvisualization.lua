package.path = package.path .. ";data/scripts/lib/?.lua"

include("utility")

local riftObjectList
local riftObjectKeysSorted = {}
local riftEntities = {}
local invalidEntities = {}

function initialize()

    Sector():registerCallback("onEntityCreated", "onEntityCreated")
    Sector():registerCallback("onScriptAdded", "onScriptAdded")
    Sector():registerCallback("onDestroyed", "onEntityDestroyed")
    Sector():registerCallback("onPlayerLeft", "onPlayerLeft")

    local standardSphereSize = 20
    riftObjectList = {
        smallRiftTreasure =         {draw = false, color = ColorRGB(1, 1, 0), size = standardSphereSize, script = "", value = "small_treasure"},
        mediumRiftTreasure =        {draw = false, color = ColorRGB(1, 1, 0), size = standardSphereSize * 2, script = "", value = "medium_treasure"},
        -- following names begin with underscore to make sorting easier -> see getSortedKeys-function
        _stash =                    {draw = false, color = ColorRGB(0, 0.5, 0), size = standardSphereSize, script = "stash.lua", value = ""},
        _claimableWreckage =        {draw = false, color = ColorRGB(1, 0.53, 0), size = standardSphereSize * 5, script = "wreckagetoship.lua", value = ""},
        _valuableDetectorBeacon =   {draw = false, color = ColorRGB(0, 1, 0), size = standardSphereSize, script = "valuablesdetectorbeacon.lua", value = ""},
        _cargoStash =               {draw = false, color = ColorRGB(0, 0.5, 0), size = standardSphereSize, script = "cargostash.lua", value = ""},
        _timeDevice =               {draw = false, color = ColorRGB(1, 0, 0.2), size = standardSphereSize, script = "itrstoryresetbeacon.lua", value = ""},
        _scannableObject =          {draw = false, color = ColorRGB(0, 0.7, 1), size = standardSphereSize, script = "scannableobject.lua", value = ""},
        _xsotanLoreObject =         {draw = false, color = ColorRGB(0, 0.7, 1), size = standardSphereSize, script = "xsotanloreobject.lua", value = ""},
        _buoy =                     {draw = false, color = ColorRGB(0, 1, 0), size = standardSphereSize, script = "buoy.lua", value = ""},
        _weaponChamber =            {draw = false, color = ColorRGB(1, 0, 0), size = standardSphereSize, script = "weaponchamber.lua", value = ""},
        _weaponChamberSwitch =      {draw = false, color = ColorRGB(1, 0, 0), size = standardSphereSize, script = "weaponchamberswitch.lua", value = ""},
        _batteryStash =             {draw = false, color = ColorRGB(1, 0, 0.5), size = standardSphereSize, script = "batterystash.lua", value = ""},
        _battery =                  {draw = false, color = ColorRGB(1, 0, 0.5), size = standardSphereSize / 2, script = "battery.lua", value = ""},
        _inactiveGate =             {draw = false, color = ColorRGB(1, 1, 1), size = standardSphereSize * 10, script = "inactivegate.lua", value = ""},
        _inactiveGateActivator =    {draw = false, color = ColorRGB(1, 1, 1), size = standardSphereSize / 2, script = "inactivegateactivator.lua", value = ""},
        _attackPlatform =           {draw = false, color = ColorRGB(1, 0.3, 0), size = standardSphereSize * 3, script = "attackplatform.lua", value = ""},
        _protectionPlatform =       {draw = false, color = ColorRGB(1, 0.3, 0), size = standardSphereSize * 3, script = "protectionplatform.lua", value = ""},
        _repairPlatform =           {draw = false, color = ColorRGB(1, 0.3, 0), size = standardSphereSize * 3, script = "repairplatform.lua", value = ""},
        _escortAnomaly =            {draw = false, color = ColorRGB(0.8, 0, 1), size = standardSphereSize, script = "escortthroughteleportanomaly.lua", value = ""},
        _gravityAnomaly =           {draw = false, color = ColorRGB(0.8, 0, 1), size = standardSphereSize, script = "gravityanomaly.lua", value = ""},
        _shockwaveAnomaly =         {draw = false, color = ColorRGB(0.8, 0, 1), size = standardSphereSize, script = "shockwaveanomaly.lua", value = ""},
        _teleportAnomaly =          {draw = false, color = ColorRGB(0.8, 0, 1), size = standardSphereSize, script = "teleportanomaly.lua", value = ""},
        _mine =                     {draw = false, color = ColorRGB(1, 1, 1), size = standardSphereSize, script = "", value = "rift_mine"},
        _minefieldEmp =             {draw = false, color = ColorRGB(1, 0.7, 0.7), size = standardSphereSize, script = "minefieldemp.lua", value = ""},
        _xsotanBreeder =            {draw = false, color = ColorRGB(1, 0, 1), size = standardSphereSize, script = "", value = "xsotan_breeder"},
        _xsotanBreederMothership =  {draw = false, color = ColorRGB(0.9, 0, 0.9), size = standardSphereSize * 3, script = "", value = "xsotan_breeder_mothership"},
        _radiatingAsteroid =        {draw = false, color = ColorRGB(0.7, 0.7, 0), size = standardSphereSize, script = "radiatingasteroid.lua", value = ""},
        _landmark =                 {draw = false, color = ColorRGB(0.5, 0.5, 0.5), size = standardSphereSize * 10, script = "", value = "riftsector_landmark"},
    }

    findRiftEntities()
    riftObjectKeysSorted = getSortedKeys(riftObjectList)
end

-- sort riftObjectList to not draw rift treasure spheres over type spheres
function getSortedKeys(table_in)
    local tableKeys = {}
    for key, _ in pairs(table_in) do
        table.insert(tableKeys, key)
    end

    table.sort(tableKeys)
    return tableKeys
end

function updateClient()
    for id, entity in pairs(riftEntities) do

        if valid(entity) then

            local entityPosition = entity.translationf

            for _, value in pairs(riftObjectKeysSorted) do
                local object = riftObjectList[value]
                if object.draw then
                    if object.value == "" then
                        if entity:hasScript(object.script) then
                            drawSphere(entityPosition, object.size, object.color)
                            break
                        end

                    else
                        if entity:getValue(object.value) and object.script == "" then
                            drawSphere(entityPosition, object.size, object.color)
                            if object.value == "rift_mine" then break end
                            if object.value == "xsotan_breeder_mothership" then break end
                            if object.value == "xsotan_breeder" then break end
                            if object.value == "riftsector_landmark" then break end
                        end
                    end
                end
            end

        else
            table.insert(invalidEntities, id)
        end
    end

    if next(invalidEntities) ~= nil then
        removeEntitiesFromTable()
    end
end

function removeEntitiesFromTable()
    for _, value in pairs(invalidEntities) do
        riftEntities[value] = nil
    end

    invalidEntities = {}
end

function onEntityCreated(entityId)
    findRiftEntities({Entity(entityId)})
end

function onEntityDestroyed(entityId)
    for key, _ in pairs(riftEntities) do
        if key == entityId then
            table.insert(invalidEntities, key)
        end
    end

    removeEntitiesFromTable()
end

function onScriptAdded(entityId, scriptIndex, scriptPath)
    findRiftEntities({Entity(entityId)})
end

function onPlayerLeft()
    terminate()
end

function findRiftEntities(entities_in)

    local entities = nil
    if not entities_in then
        entities = {Sector():getEntities()}
    else
        entities = entities_in
    end

    for _, entity in pairs(entities) do
        for _, object in pairs(riftObjectList) do
            if entity:hasScript(object.script) then
                riftEntities[entity.id] = entity
                break

            elseif entity:getValue(object.value) then
                riftEntities[entity.id] = entity
            end
        end
    end
end

function drawSphere(position, size, color)
    drawDebugSphere(Sphere(position, size), color)
end



function showAll()
    for key, _ in pairs(riftObjectList) do
        riftObjectList[key].draw = true
    end
end

function hideAll()
    for key, _ in pairs(riftObjectList) do
        riftObjectList[key].draw = false
    end
end

function toggle(object)
    riftObjectList[object].draw = not riftObjectList[object].draw
end
