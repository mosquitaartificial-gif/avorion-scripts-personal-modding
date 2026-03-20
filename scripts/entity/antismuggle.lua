package.path = package.path .. ";data/scripts/lib/?.lua"

include ("galaxy")
include ("stringutility")
include ("randomext")
include ("callable")
include ("relations")
local Dialog = include("dialogutility")
local CaptainClass = include("captainclass")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace AntiSmuggle
AntiSmuggle = {}

local suspicion
local suspiciousCargoValue = 0 -- used to determine bribes and fine

local values = {}
values.timeOut = 120

local scannerTicker = 0
local scannerTick = 10

function AntiSmuggle.initialize()
    if onServer() then
        Sector():registerCallback("onDestroyed", "onDestroyed")

        scannerTicker = random():getInt(0, scannerTick)
    end
end

function AntiSmuggle.getUpdateInterval()
    return 1.0
end

function AntiSmuggle.updateServer(timeStep)    
    AntiSmuggle.updateSuspiciousShipDetection(timeStep)
    AntiSmuggle.updateSuspicionDetectedBehaviour(timeStep)
end

function AntiSmuggle.getScannerDistance(faction)
    local scannerDistance = 400.0
    return scannerDistance * (1.0 + 0.5 * math.max(0, faction:getTrait("careful")))
end

function AntiSmuggle.updateSuspiciousShipDetection(timeStep)

    scannerTicker = scannerTicker + timeStep

    -- scan for suspicious ships
    if scannerTicker < scannerTick then return end
    scannerTicker = 0

    if suspicion then return end

    local self = Entity()
    local ownSphere = self:getBoundingSphere()

    local selfFaction = Faction()
    if not selfFaction then return end

    local scannerDistance = AntiSmuggle.getScannerDistance(selfFaction)

    local x, y = Sector():getCoordinates()
    local sectorController = Galaxy():getControllingFaction(x, y)
    if sectorController then
        sectorController = sectorController.index
    else
        sectorController = 0
    end

    local entities = {Sector():getEntitiesByType(EntityType.Ship)}
    for _, ship in pairs(entities) do
        -- skip controls if the controlled object doesn't belong to a faction
        if not ship.factionIndex then goto continue end
        if ship.factionIndex == 0 then goto continue end

        -- don't control the faction that controls the current sector
        if ship.factionIndex == sectorController then goto continue end

        -- controls only make sense when the target has a cargo bay to control
        if not ship:hasComponent(ComponentType.CargoBay) then goto continue end

        -- don't control self
        if ship.index == self.index then goto continue end

        -- is the target's cargo bay scanning range reduced by a badcargowarningsystem?
        local adjustedScannerDistance = scannerDistance
        local ret, detectionRangeFactor = ship:invokeFunction("internal/dlc/blackmarket/systems/badcargowarningsystem.lua", "getDetectionRangeFactor")
        if ret == 0 then
            adjustedScannerDistance = scannerDistance * detectionRangeFactor
        end

        -- make sure the other ship is close enough
        local testDistance = adjustedScannerDistance + ownSphere.radius + ship.radius
        local d2 = distance2(self.translationf, ship.translationf)
        if d2 > testDistance * testDistance then goto continue end

        -- only control ships that belong to a player faction
        local faction = Faction(ship.factionIndex)
        if not valid(faction) or faction.isAIFaction then goto continue end

        -- no controls during War, or Allies
        local relation = selfFaction:getRelation(faction.index)
        if relation.status == RelationStatus.Allies or relation.status == RelationStatus.War then goto continue end

        -- make sure this craft is not yet suspected by another ship
        local suspectedBy = Sector():getValue(string.format("%s_is_under_suspicion", ship.index.string))
        if suspectedBy then goto continue end

        -- check if cargo detection is prevented
        if ship:hasScript("internal/dlc/blackmarket/entity/utility/preventcargodetection.lua") then
            goto continue
        end

        -- look for cargo transport licenses
        local vanillaItems = faction:getInventory():getItemsByType(InventoryItemType.VanillaItem)

        local licenseLevel = -2

        for _, p in pairs(vanillaItems) do
            local item = p.item
            if item:getValue("isCargoLicense") == true then
                if item:getValue("faction") == self.factionIndex then
                    licenseLevel = math.max(licenseLevel, item.rarity.value)
                end
            end
        end

        local captain = ship:getCaptain()
        if captain then
            if captain:hasClass(CaptainClass.Smuggler) then
                licenseLevel = math.max(licenseLevel, 3)
            elseif captain:hasClass(CaptainClass.Merchant) then
                licenseLevel = math.max(licenseLevel, 1)
            end
        end

        if suspicion then
            suspicion.fine = 0
        end

        for good, amount in pairs(ship:getCargos()) do
            local payment = 0.0

            if relation.level < 80000 and good.dangerous and licenseLevel < 0 then
                suspicion = suspicion or {type = 3}
                payment = 0.70
            end

            if good.stolen and licenseLevel < 2 then
                suspicion = suspicion or {type = 2}
                payment = 1.0
            end

            if good.suspicious and licenseLevel < 1 then
                suspicion = suspicion or {type = 0}
                payment = 1.5
            end

            if good.illegal and licenseLevel < 3 then
                suspicion = suspicion or {type = 1}
                payment = 2.0
            end

            if suspicion then
                suspicion.ship = ship
                suspicion.index = ship.index

                local pilots = {ship:getPilotIndices()}
                if #pilots > 0 then
                    suspicion.player = Player(pilots[1])
                end

                suspicion.factionIndex = ship.factionIndex
                suspicion.fine = suspicion.fine or 0
                suspicion.fine = suspicion.fine + good.price * amount * payment -- price for the goods

                suspiciousCargoValue = suspiciousCargoValue + good.price * amount -- sums up offending cargo value

                suspicion.licenseLevel = licenseLevel
            end
        end

        if suspicion and suspicion.fine > 0 then
            suspicion.fine = suspicion.fine + suspicion.fine * 0.05 * Balancing_GetSectorRichnessFactor(Sector():getCoordinates()) -- basic fee
            suspicion.fine = suspicion.fine * (1.0 + 0.5 * selfFaction:getTrait("greedy"))
            suspicion.fine = math.floor(suspicion.fine / 1000) * 1000 + 1000
        end

        if suspicion then break end

        ::continue::
    end

    if suspicion then
        -- register the suspicion
        Sector():setValue(string.format("%s_is_under_suspicion", suspicion.index.string), self.index.string)
    end
end

function AntiSmuggle.updateSuspicionDetectedBehaviour(timeStep)
    if not suspicion then return end

    local self = Entity()
    local sphere = self:getBoundingSphere()

    --
    if not valid(suspicion.ship) then
        local faction = Faction()
        if faction then
            changeRelations(faction, Faction(suspicion.factionIndex), -25000, RelationChangeType.Smuggling, true, true, self) -- hefty relation penalty on ignore or misbehavior
        end
        AntiSmuggle.resetSuspicion()
        return
    end

    if not suspicion.hailing then
        local stillSuspicious = false
        for good, amount in pairs(suspicion.ship:getCargos()) do
            if (good.dangerous and suspicion.licenseLevel < 0)
                    or (good.suspicious and suspicion.licenseLevel < 1)
                    or (good.stolen and suspicion.licenseLevel < 2)
                    or (good.illegal and suspicion.licenseLevel < 3) then

                stillSuspicious = true
            end
        end

        if not stillSuspicious then
            suspicion = nil
            return
        end
    end


    -- start talking, start timer for response
    if not suspicion.talkedTo then
        suspicion.talkedTo = true
        suspicion.timeOut = values.timeOut

        if valid(suspicion.player) then
            suspicion.hailing = true
            invokeClientFunction(suspicion.player, "startHailing", suspicion.type, suspicion.fine, suspicion.factionIndex)
        else
            -- check if a player entered the craft
            local pilots = {suspicion.ship:getPilotIndices()}
            if #pilots > 0 then
                suspicion.player = Player(pilots[1])
            end
        end
    end

    -- if they don't respond in time, they are considered an enemy
    if not suspicion.responded then
        suspicion.timeOut = suspicion.timeOut - 1

        if valid(suspicion.player) then
            if suspicion.timeOut <= 0 then
                ShipAI():registerEnemyEntity(suspicion.ship.index)
            end

            if suspicion.timeOut == 0 then
                invokeClientFunction(suspicion.player, "startEnemyTalk")
            end

        else
            if suspicion.timeOut == 0 then
                -- automatically comply if there's no player
                suspicion.responded = true

                local faction = Faction(suspicion.factionIndex)
                local ownFaction = Faction()
                if faction and ownFaction then
                    faction:pay("Paid a fine of %1% Credits."%_T, suspicion.fine)
                    changeRelations(faction, ownFaction, -2500, RelationChangeType.Smuggling, true, true, self)
                end
            end
        end
    end

    -- fly towards the suspicious ship if we need to confiscate
    if suspicion.responded or suspicion.timeOut > 0 then

        if suspicion.responded and suspicion.bribeSuccessful then
            AntiSmuggle.resetSuspicion() -- reset
            return
        end

        if self:hasScript("ai/patrol.lua") then
            self:invokeFunction("ai/patrol.lua", "setWaypoints", {suspicion.ship.translationf})
        else
            ShipAI():setFly(suspicion.ship.translationf, sphere.radius + 30.0)
        end

        if suspicion.responded and self:getNearestDistance(suspicion.ship) < 80.0 then
            -- take away the cargo
            if not suspicion.bribeSuccessful then
                for good, amount in pairs(suspicion.ship:getCargos()) do
                    if (good.dangerous and suspicion.licenseLevel < 0)
                            or (good.suspicious and suspicion.licenseLevel < 1)
                            or (good.stolen and suspicion.licenseLevel < 2)
                            or (good.illegal and suspicion.licenseLevel < 3) then

                        suspicion.ship:removeCargo(good, amount)
                    end
                end
            end

            -- case closed, suspicion removed
            AntiSmuggle.resetSuspicion()
        end
    end

end

function AntiSmuggle.onDestroyed(index)
    if suspicion and valid(suspicion.ship) and suspicion.ship.index == index then
        AntiSmuggle.resetSuspicion()
    end
end

function AntiSmuggle.resetSuspicion()
    if suspicion then
        -- remove the suspicion
        Sector():setValue(string.format("%s_is_under_suspicion", suspicion.index.string), nil)
    end

    suspicion = nil
    local self = Entity()
    if self:hasScript("ai/patrol.lua") then
        self:invokeFunction("ai/patrol.lua", "setWaypoints", nil)
    else
        ShipAI():setIdle()
    end
end

function AntiSmuggle.makeSuspiciousDialog(fine)
    values.fine = fine

    local dialog0 = {}
    dialog0.text = "Hello. This is a routine scan. Please remain calm.\n\nYour cargo will be confiscated and we will have to fine you ${fine} Credits.\n\nYou have ${timeOut} seconds to respond."%_t % values

    dialog0.answers = {
        {answer = "[Comply]"%_t, onSelect = "onComply", text = "Thank you for your cooperation.\n\nRemain where you are. You will pay a fine. Dump your cargo or we will approach you and confiscate it."%_t},
        {answer = "[Ignore]"%_t, onSelect = "onIgnore"}
    }

    return dialog0
end

function AntiSmuggle.makeIllegalDialog(fine)
    values.fine = fine

    local dialog0 = {}
    dialog0.text = "Hold on. Our scanners show illegal cargo on your ship.\n\nYour cargo will be confiscated and you are fined ${fine} Credits.\n\nYou have ${timeOut} seconds to respond."%_t % values

    dialog0.answers = {
        {answer = "[Comply]"%_t, onSelect = "onComply", text = "Thank you for your cooperation.\n\nRemain where you are. You will pay a fine. Dump your cargo or we will approach you and confiscate it."%_t},
        {answer = "[Ignore]"%_t, onSelect = "onIgnore"}
    }

    return dialog0
end

function AntiSmuggle.makeStolenDialog(fine)
    values.fine = createMonetaryString(fine)

    local dialog0 = {}
    dialog0.text = "Hold on. Our scanners show stolen cargo on your ship.\n\nYour cargo will be confiscated and you are fined ${fine} Credits.\n\nYou have ${timeOut} seconds to respond."%_t % values

    dialog0.answers = {
        {answer = "[Comply]"%_t, onSelect = "onComply", text = "Thank you for your cooperation.\n\nRemain where you are. You will pay a fine. Dump your cargo or we will approach you and confiscate it."%_t},
        {answer = "[Ignore]"%_t, onSelect = "onIgnore"}
    }

    return dialog0
end

function AntiSmuggle.makeDangerousDialog(fine)
    values.fine = fine

    local dialog0 = {}
    dialog0.text = "Hold on. Our scanners show dangerous cargo on your ship.\n\nAccording to our records, you don't have a transportation permit for dangerous cargo in our area.\n\nYour cargo will be confiscated and you are fined ${fine} Credits.\n\nYou have ${timeOut} seconds to respond."%_t % values

    dialog0.answers = {
        {answer = "[Comply]"%_t, onSelect = "onComply", text = "Thank you for your cooperation.\n\nRemain where you are. You will pay a fine. Dump your cargo or we will approach you and confiscate it."%_t},
        {answer = "[Ignore]"%_t, onSelect = "onIgnore"}
    }

    return dialog0
end

function AntiSmuggle.makeBribingDialog()

    local dialog0 = {}
    dialog0.text = "What do you mean?"%_t

    dialog0.answers = {
        {answer = "I could offer you a small apology of ${bribe} Credits (50% chance of success)"%_t % {bribe = createMonetaryString(suspicion.fine * 1.1)}, onSelect = "onBribe50", followUp = Dialog.empty()},
        {answer = "Maybe this donation of ${bribe} Credits will make you forget about all this (75% chance of success)"%_t % {bribe = createMonetaryString(suspicion.fine * 1.3)}, onSelect = "onBribe75", followUp = Dialog.empty()},
        {answer = "I am sure this generous offer of ${bribe} Credits will help you forget all this (95% chance of success)"%_t % {bribe = createMonetaryString(suspicion.fine * 1.5)}, onSelect = "onBribe95", followUp = Dialog.empty()},
        {answer = "On second thought, I'll comply."%_t, onSelect = "onComply", text = "Thank you for your cooperation.\n\nRemain where you are. You will pay a fine. Dump your cargo or we will approach you and confiscate it."%_t},
        {answer = "[Ignore]"%_t, onSelect = "onIgnore"},
    }

    ScriptUI(Entity().id):interactShowDialog(dialog0)
end

function AntiSmuggle.startHailing(type, fine, factionIndex)
    suspicion = {type = type, fine = fine, factionIndex = factionIndex, hailing = true}

    ScriptUI():startHailing("startTalk", "startEnemyTalk")
end

function AntiSmuggle.startTalk()
    local dialog = nil

    local type = suspicion.type
    local fine = suspicion.fine

    if type == 0 then
        dialog = AntiSmuggle.makeSuspiciousDialog(fine)
    elseif type == 1 then
        dialog = AntiSmuggle.makeIllegalDialog(fine)
    elseif type == 2 then
        dialog = AntiSmuggle.makeStolenDialog(fine)
    elseif type == 3 then
        dialog = AntiSmuggle.makeDangerousDialog(fine)
    end

    AntiSmuggle.addBribingDialog(dialog, fine)
    AntiSmuggle.tryAddScramblerDialog(dialog)

    -- put bribing and scramble options before [ignore]
    local tmp = dialog.answers[2]
    if #dialog.answers == 4 then
        dialog.answers[2] = dialog.answers[3]
        dialog.answers[3] = dialog.answers[4]
        dialog.answers[4] = tmp
    elseif #dialog.answers == 3 then
        dialog.answers[2] = dialog.answers[3]
        dialog.answers[3] = tmp
    end

    dialog.onEnd = function()
        if suspicion then
            suspicion.hailing = nil
        end
    end

    ScriptUI():interactShowDialog(dialog, false)
end


function AntiSmuggle.tryAddScramblerDialog(dialog)
    local playerCraft = Player().craft
    if not playerCraft then return dialog end

    if playerCraft:hasScript("internal/dlc/blackmarket/systems/cargodetectionscrambler.lua") then
        table.insert(dialog.answers, {answer = "[Scramble Cargo Signature]"%_t, onSelect = "onScramble", followUp = Dialog.empty()})
    end

    return dialog
end

function AntiSmuggle.addBribingDialog(dialog, fine)
    local craft = Player().craft
    if not craft then return dialog end

    table.insert(dialog.answers, {answer = "Can’t we find another way to handle this?"%_t, onSelect = "makeBribingDialog", followUp = Dialog.empty()})

    return dialog
end

function AntiSmuggle.onScramble()
    if onClient() then
        invokeServerFunction("onScramble")
        return
    end

    -- find scramble script
    local scramblerIndex = nil
    local player = Player(callingPlayer)
    local playerCraft
    if player then
        playerCraft = player.craft
        if playerCraft then
            for index, path in pairs(playerCraft:getScripts()) do
                if path == "internal/dlc/blackmarket/systems/cargodetectionscrambler.lua" then
                    scramblerIndex = index
                end
            end
        end
    end

    if scramblerIndex ~= nil then
        AntiSmuggle.resetSuspicion()
        local ok, rarity = playerCraft:invokeFunction("cargodetectionscrambler.lua", "getRarity")
        if ok == 0 then
            local ok, survivalProbability = playerCraft:invokeFunction("cargodetectionscrambler.lua", "getSurvivalProbability", rarity)
            -- Multiplied survivalProbability with 1.2 to better match probability expectaions of players
            if ok == 0 and not random():test(survivalProbability * 1.2) then
                playerCraft:removeScript(scramblerIndex)
            end
        end
        AntiSmuggle.onScrambleSuccessful(player, playerCraft)

    else
        invokeClientFunction(suspicion.player, "startHailing", suspicion.type, suspicion.fine, suspicion.factionIndex)
    end
end
callable(AntiSmuggle, "onScramble")

function AntiSmuggle.onScrambleSuccessful(player, playerCraft)
    if onServer() then
        invokeClientFunction(player, "onScrambleSuccessful")
        playerCraft:addScriptOnce("internal/dlc/blackmarket/entity/utility/preventcargodetection.lua", 0) -- 0: scrambled
        return
    end

    local dialog = {text = "Wait, what's..?\n\nWasn't there..?\n\nWell, it seems like there's nothing wrong with your cargo after all.\n\nYou may carry on for now, but we'll have an eye on you."%_t}

    ScriptUI():interactShowDialog(dialog, 1)
end


function AntiSmuggle.startEnemyTalk(type)
    if onClient() then
        invokeServerFunction("startEnemyTalk", type)
        return
    end

    local entity = Entity()
    Player(callingPlayer):sendChatMessage(entity, ChatMessageType.Normal, "Your non-responsiveness is considered a hostile act. Leave the sector or we will shoot."%_t)

    if not suspicion then return end

    local faction = Faction(suspicion.factionIndex)
    local ownFaction = Faction()
    if faction and ownFaction then
        changeRelations(faction, ownFaction, -2500, RelationChangeType.Smuggling, true, true, nil) -- same relation penalty as for complying
    end

    if suspicion then
        suspicion.hailing = nil
    end
end
callable(AntiSmuggle, "startEnemyTalk")


function AntiSmuggle.onComply()
    if onClient() then
        invokeServerFunction("onComply")
        return
    end

    if suspicion and suspicion.factionIndex and suspicion.player and suspicion.player.index == callingPlayer then
        suspicion.responded = true
        local faction = Faction(suspicion.factionIndex)
        local ownFaction = Faction()
        if faction and ownFaction then
            faction:pay("Paid a fine of %1% Credits."%_T, suspicion.fine)
            changeRelations(faction, ownFaction, -2500, RelationChangeType.Smuggling, true, true, Entity()) -- small relation punishment on Comply
        end
    end
end
callable(AntiSmuggle, "onComply")

function AntiSmuggle.onBribe50()
    if onClient() then
        invokeServerFunction("onBribe50")
        return
    end

    if not suspicion then return end

    -- setting actual probability higher than shown for player benefit
    AntiSmuggle.onBribe(0.6, 1.1)
end
callable(AntiSmuggle, "onBribe50")

function AntiSmuggle.onBribe75()
    if onClient() then
        invokeServerFunction("onBribe75")
        return
    end

    if not suspicion then return end

    -- setting actual probability higher than shown for player benefit
    AntiSmuggle.onBribe(0.90, 1.3)
end
callable(AntiSmuggle, "onBribe75")

function AntiSmuggle.onBribe95()
    if onClient() then
        invokeServerFunction("onBribe95")
        return
    end

    if not suspicion then return end

    -- setting actual probability higher than shown for player benefit
    AntiSmuggle.onBribe(0.99, 1.5)
end
callable(AntiSmuggle, "onBribe95")

-- needed for testing
function AntiSmuggle.onBribe100()
    if not suspicion then return end

    AntiSmuggle.onBribe(1, 1)
end

function AntiSmuggle.onBribe(probability, factor)
    if suspicion and suspicion.factionIndex and suspicion.player and suspicion.player.index == callingPlayer then
        suspicion.responded = true
        local success = random():test(probability)
        if success then
            AntiSmuggle.onBribeSuccessful(factor)
        else
            AntiSmuggle.onBribeFailed()
        end
    end
end

-- Player will have to pay fine, but gets to keep cargo
function AntiSmuggle.onBribeSuccessful(factor)
    if onServer() then
        local faction = Faction(suspicion.factionIndex)

        if not faction:canPay(suspicion.fine * factor) then
            AntiSmuggle.onBribeFailed()
            return
        end

        suspicion.bribeSuccessful = true

        faction:pay("Paid a bribe of %1% Credits."%_T, suspicion.fine * factor)
        local player = Player(callingPlayer)
        local craft = player.craft
        if not craft then return end

        craft:addScriptOnce("internal/dlc/blackmarket/entity/utility/preventcargodetection.lua", 1) -- 1: bribed
        invokeClientFunction(player, "onBribeSuccessful")
        return
    end

    local dialog = {}
    local faction = Faction(suspicion.factionIndex)
    if faction then
        dialog = {text = "Oh, look at that, my scanner seems to have malfunctioned. Have a nice trip!"%_t}
    end
    ScriptUI():interactShowDialog(dialog, 1)
end

 -- Player's cargo is confiscated and he has to pay full fine
function AntiSmuggle.onBribeFailed()
    if onServer() then
        if suspicion and suspicion.factionIndex and suspicion.player and suspicion.player.index == callingPlayer then
            suspicion.responded = true -- Needed for testing
            local faction = Faction(suspicion.factionIndex)
            local ownFaction = Faction()
            if faction and ownFaction then
                faction:pay("Paid a fine of %1% Credits."%_T, suspicion.fine)
                changeRelations(faction, ownFaction, -5000, RelationChangeType.Smuggling, true, true, nil) -- slightly bigger relation punishment on failed bribe
            end
        end

        invokeClientFunction(Player(callingPlayer), "onBribeFailed")
        return
    end

    local dialog = {}
    local faction = Faction(suspicion.factionIndex)
    if faction then
        dialog = {text = "This is an insult.\n\nRemain where you are. You will pay the fine. Dump your cargo or we will approach you and confiscate it."%_t}
    end
    ScriptUI():interactShowDialog(dialog, 1)
end

function AntiSmuggle.onIgnore()
    if onClient() then
        invokeServerFunction("onIgnore")
        return
    end

    if not suspicion then return end -- suspicion no longer valid

    local faction = Faction(suspicion.factionIndex)
    local ownFaction = Faction()
    if faction and ownFaction then
        changeRelations(faction, ownFaction, -2500, RelationChangeType.Smuggling, true, true, Entity()) -- same relation penalty as for complying
    end
end
callable(AntiSmuggle, "onIgnore")

-- test helper functions
function AntiSmuggle.getIsSuspicious()
    return suspicion ~= nil
end
