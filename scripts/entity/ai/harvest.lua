
package.path = package.path .. ";data/scripts/lib/?.lua"

include ("stringutility")
include ("refineutility")

AIHarvest = {}

AIHarvest.objectToHarvest = nil
AIHarvest.stopAfterInitialTarget = false
AIHarvest.harvestLoot = nil
AIHarvest.collectCounter = 0
AIHarvest.harvestMaterial = nil
AIHarvest.hasRawLasers = false
AIHarvest.noCargoSpace = false

AIHarvest.lastHarvestPosition = nil

AIHarvest.noTargetsLeft = false
AIHarvest.noTargetsLeftTimer = 1

AIHarvest.stuckLoot = {}

function AIHarvest:initialize(initialObjectId, stopAfterInitialTarget)
    if initialObjectId then
        self.objectToHarvest = Entity(initialObjectId)
        self.stopAfterInitialTarget = stopAfterInitialTarget
    end
end

function AIHarvest:getUpdateInterval()
    if self.noTargetsLeft or self.noCargoSpace then return 15 end

    return 1
end

function AIHarvest:secure()
    local data = {}
    data.stopAfterInitialTarget = self.stopAfterInitialTarget
    if valid(self.objectToHarvest) then
        data.targetId = self.objectToHarvest.id.string
    end

    return data
end

function AIHarvest:restore(data_in)
    self.stopAfterInitialTarget = data_in.stopAfterInitialTarget

    if data_in.targetId then
        self.objectToHarvest = Entity(data_in.targetId)
    end
end

function AIHarvest:checkIfAbleToHarvest()
    if onServer() then
        local ship = Entity()
        self.hasRawLasers = false

        -- find highest material we can harvest
        for _, turret in pairs({ship:getTurrets()}) do
            if not turret:isManned() then goto continue end

            local weapons = Weapons(turret)

            if self.getHasRawLasers(weapons) then self.hasRawLasers = true end

            local harvestMaterial = self.getHarvestMaterial(weapons)
            if harvestMaterial and (self.harvestMaterial == nil or harvestMaterial > self.harvestMaterial) then
                self.harvestMaterial = harvestMaterial
            end

            ::continue::
        end

        -- check pilots
        local crew = ship.crew
        local pilotWorkforce = 0
        for profession, workforce in pairs(crew:getWorkforce()) do
            if profession.value == CrewProfessionType.Pilot then
                pilotWorkforce = workforce
            end
        end

        -- check fighters
        if pilotWorkforce > 0 then
            local hangar = Hangar()
            local squads = {hangar:getSquads()}

            for _, index in pairs(squads) do
                local category = hangar:getSquadMainWeaponCategory(index)
                if self.weaponCategoryMatches(category) then

                    if self.harvestMaterial == nil or hangar:getHighestMaterialInSquadMainCategory(index).value > self.harvestMaterial then
                        self.harvestMaterial = hangar:getHighestMaterialInSquadMainCategory(index).value
                    end

                    self.hasRawLasers = self.hasRawLasers or hangar:getSquadHasRawMinersOrSalvagers(index)
                end
            end
        end

        -- use armed turrets for salvaging if we have no salvage turrets
        if not self.harvestMaterial then
            self.harvestMaterial = self.getSecondaryHarvestMaterial(ship)
        end

        -- no weapons of correct category
        if not self.harvestMaterial then
            local faction = Faction(Entity().factionIndex)

            if faction then
                faction:sendChatMessage("", ChatMessageType.Error, self.getNoWeaponsError())
            end

            self:finalize()
            return
        end

        -- on reload this may be not set yet
        if not self.objectToHarvest or not valid(self.objectToHarvest) then return end

        -- check whether weapon material is high enough for the user's selected target
        local targetMaterial = self.objectToHarvest:getLowestMineableMaterial()
        if not targetMaterial then
            self.objectToHarvest = nil
            return
        end

        if Material(self.harvestMaterial + 1) < targetMaterial then
            local faction = Faction(Entity().factionIndex)

            if faction then
                faction:sendChatMessage("", ChatMessageType.Error, self.getMaterialTooLowForTargetMessage(), targetMaterial.name)
            end

            self:finalize()
            return
        end
    end
end

-- this function will be executed every frame on the server only
function AIHarvest:updateServer(timeStep)
    local ship = Entity()

    if self.harvestMaterial == nil then
        self:checkIfAbleToHarvest()

        if self.harvestMaterial == nil then
            self:finalize()
            return
        end
    end

    if ship.hasPilot and not ControlUnit().autoPilotEnabled then
        self:finalize()
        return
    end

    -- find an object that can be harvested
    self:updateHarvesting(timeStep)

    if self.updateConcreteHarvest then
        self:updateConcreteHarvest(timeStep)
    end

    if self.noTargetsLeft == true then
        self.noTargetsLeftTimer = self.noTargetsLeftTimer - timeStep
    end
end

-- check the immediate region around the ship for loot that can be collected
-- and if there is some, assign harvestLoot
function AIHarvest:findHarvestLoot()
    local loots = {Sector():getEntitiesByType(EntityType.Loot)}
    local ship = Entity()

    self.harvestLoot = nil
    for _, loot in pairs(loots) do
        if loot:isCollectable(ship) and distance2(loot.translationf, ship.translationf) < 150 * 150 then
            if self.stuckLoot[loot.index.string] ~= true then
                local goodToCollect = true

                -- don't collect tiny loot amounts
                if loot:hasComponent(ComponentType.MoneyLoot) then
                    if loot:getMoneyLootAmount() < 10 then goodToCollect = false end
                end

                if loot:hasComponent(ComponentType.ResourceLoot) then
                    if loot:getResourceLootAmount() < 10 then goodToCollect = false end
                end

                if goodToCollect then
                    self.harvestLoot = loot
                    return
                end
            end
        end
    end
end

-- check the sector for an object that can be mined
-- if there is one, assign objectToHarvest
function AIHarvest:findObjectToHarvest()
    local ship = Entity()
    local sector = Sector()

    -- check if we're allowed to auto search for next target -> player / alliance ships need a captain for fully automated harvesting
    if not ship.aiOwned and not ship:getCaptain() then
        local faction = Faction(ship.factionIndex)
        if faction then
            faction:sendChatMessage("", ChatMessageType.Error, self.getNoCaptainError(), ship.name)
        end

        self:finalize()
        return
    end

    local higherMaterialPresent
    self.objectToHarvest, higherMaterialPresent = self:findObject(ship, sector, self.harvestMaterial)

    if self.objectToHarvest then
        self.noTargetsLeft = false
        self.noTargetsLeftTimer = 1
        broadcastInvokeClientFunction("setObjectToHarvest", self.objectToHarvest.index)

    else
        if self.noTargetsLeft == false or self.noTargetsLeftTimer <= 0 then
            self.noTargetsLeft = true
            self.noTargetsLeftTimer = 10 * 60 -- ten minutes

            local faction = Faction(Entity().factionIndex)
            if faction then
                local x, y = Sector():getCoordinates()
                local coords = tostring(x) .. ":" .. tostring(y)

                if higherMaterialPresent then
                    local materialName = Material(self.harvestMaterial + 1).name
                    faction:sendChatMessage(ship.name or "", ChatMessageType.Error, self.getMaterialTooLowError(), coords, materialName)
                    faction:sendChatMessage(ship.name or "", ChatMessageType.Normal, self.getMaterialTooLowMessage(), coords, materialName)
                else
                    faction:sendChatMessage(ship.name or "", ChatMessageType.Error, self.getSectorEmptyError(), coords)
                    faction:sendChatMessage(ship.name or "", ChatMessageType.Normal, self.getSectorEmptyMessage(), coords)
                end
            end

            ShipAI():setPassive()
        end
    end

end

function AIHarvest:canContinueHarvesting()
    -- prevent terminating script before it even started
    if not self.harvestMaterial then return true end

    -- fully automated harvesting is only possible with captain
    if Entity():getCaptain() then
        return false
    end

    return valid(self.harvestLoot) or valid(self.objectToHarvest) or not self.noTargetsLeft
end

function AIHarvest:updateHarvesting(timeStep)
    local ship = Entity()

    if self.hasRawLasers == true then
        if ship.freeCargoSpace < 1 then
            if self.noCargoSpace == false then
                ShipAI():setPassive()

                local faction = Faction(ship.factionIndex)
                local x, y = Sector():getCoordinates()
                local coords = tostring(x) .. ":" .. tostring(y)

                local ores, totalOres = getOreAmountsOnShip(ship)
                local scraps, totalScraps = getScrapAmountsOnShip(ship)
                local riftOres, totalRiftOres = getRiftOreAmountsOnShip(ship)

                if totalOres + totalScraps + totalRiftOres == 0 then
                    self:setShipStatusMessage(self.getNoSpaceStatus(), {})
                    if faction then faction:sendChatMessage(ship.name or "", ChatMessageType.Normal, self.getNoSpaceMessage(), coords) end
                    self.noCargoSpace = true
                else
                    local ret, moreOrders = ship:invokeFunction("data/scripts/entity/orderchain.lua", "hasMoreOrders")
                    if ret == 0 and moreOrders == true then
                        -- harvest order fulfilled, another order is queued
                        -- don't send a message
                        self:finalize()
                        return
                    end

                    -- harvest order fulfilled, no other order is queued
                    if faction then faction:sendChatMessage(ship.name or "", ChatMessageType.Normal, self.getNoMoreSpaceMessage(), coords) end

                    self:finalize()
                end

                if faction then faction:sendChatMessage(ship.name or "", ChatMessageType.Error, self.getNoMoreSpaceError(), coords) end
            end

            return
        else
            self.noCargoSpace = false
        end
    end

    -- switch away from the current object if it has insignificant amounts of resources left
    if valid(self.objectToHarvest) then
        local resources = 0
        for _, value in pairs({self.objectToHarvest:getMineableResources()}) do
            resources = resources + value
        end

        if resources < 10 then
            self.objectToHarvest = nil
        end
    end

    -- highest priority is collecting the resources
    if not valid(self.objectToHarvest) and not valid(self.harvestLoot) then

        -- first, check if there is loot to collect
        self:findHarvestLoot()

        -- check if we are to stop after the initial target
        if self.stopAfterInitialTarget then
            self:finalize()
            return
        end

        -- then, check if there is another object to mine
        if not valid(self.harvestLoot) then
            self:findObjectToHarvest()
        end

    end

    local ai = ShipAI()

    if valid(self.harvestLoot) then
        self:setShipStatusMessage(self.getCollectLootStatus(), {})

        -- there is loot to collect, fly there
        self.collectCounter = self.collectCounter + timeStep
        if self.collectCounter > 3 then
            self.collectCounter = self.collectCounter - 3

            if ai.isStuck then
                self.stuckLoot[self.harvestLoot.index.string] = true
                self:findHarvestLoot()
                self.collectCounter = self.collectCounter + 2
            end

            if valid(self.harvestLoot) then
                -- set fighters to collect loot
                self:setFighterOrder(ai, FighterOrders.CollectLoot, true)

                -- fly to pick up the loot
                ai:setFly(self.harvestLoot.translationf, 0, nil, nil, false)
            end
        end

    elseif valid(self.objectToHarvest) then
        self:setShipStatusMessage(self.getNormalStatus(), {})

        -- if there is an object, harvest it
        if ship.selectedObject == nil
            or ship.selectedObject.index ~= self.objectToHarvest.index
            or ai.state ~= AIState.Harvest then

            ai:setHarvest(self.objectToHarvest)
            self.stuckLoot = {}
        end

        self.lastHarvestPosition = self.objectToHarvest.translationf
    else
        self:setShipStatusMessage(self.getAllHarvestedStatus(), {})
    end
end

function AIHarvest:setFighterOrder(ai, orderType, ignoreWeaponCategory)
    local hangar = Hangar()
    local fighterController = FighterController()
    local squads = {hangar:getSquads()}

    -- don't interfere with fighter commands while the ship is trying to jump
    if ai.state ~= AIState.Jump then
        for _, index in pairs(squads) do
            local category = hangar:getSquadMainWeaponCategory(index)
            if ignoreWeaponCategory or self.weaponCategoryMatches(category) then
                fighterController:setSquadOrders(index, orderType, Uuid())
            else
                fighterController:setSquadOrders(index, FighterOrders.Return, Uuid())
            end
        end
    end
end

function AIHarvest:setShipStatusMessage(msg, arguments)
    -- only set AI state if auto pilot inactive
    if not ControlUnit().autoPilotEnabled then
        local ai = ShipAI()
        ai:setStatusMessage(msg, arguments)
    end
end

function AIHarvest:setObjectToHarvest(index)
    self.objectToHarvest = Sector():getEntity(index)
end

function AIHarvest:finalize()
    Entity():invokeFunction("orderchain.lua", "sendOrderCompletedMessage")
    ShipAI():setPassive()
    terminate()
end

---- this function will be executed every frame on the client only
--function AIHarvest:updateClient(timeStep)
--    if valid(self.objectToHarvest) then
--        drawDebugSphere(self.objectToHarvest:getBoundingSphere(), ColorRGB(1, 0, 0))
--    end
--end


function AIHarvest:new()
    local object = {}
    setmetatable(object, self)
    self.__index = self

    return object
end

function AIHarvest.CreateNamespace()
    local instance = AIHarvest:new()
    local result = {instance = instance}

    result.initialize = function(...) return instance:initialize(...) end
    result.getUpdateInterval = function(...) return instance:getUpdateInterval(...) end
    result.checkIfAbleToHarvest = function(...) return instance:checkIfAbleToHarvest(...) end
    result.updateServer = function(...) return instance:updateServer(...) end
    result.findHarvestLoot = function(...) return instance:findHarvestLoot(...) end
    result.findObjectToHarvest = function(...) return instance:findObjectToHarvest(...) end
    result.canContinueHarvesting = function(...) return instance:canContinueHarvesting(...) end
    result.updateHarvesting = function(...) return instance:updateHarvesting(...) end
    result.setObjectToHarvest = function(...) return instance:setObjectToHarvest(...) end
    result.finalize = function(...) return instance:finalize(...) end
    result.secure = function(...) return instance:secure(...) end
    result.restore = function(...) return instance:restore(...) end

    return result
end


return AIHarvest
