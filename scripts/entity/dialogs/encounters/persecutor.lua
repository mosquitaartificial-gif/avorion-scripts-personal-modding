package.path = package.path .. ";data/scripts/lib/?.lua"
include("stringutility")
include("randomext")
include("callable")
Dialog = include ("dialogutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace PersecutorEncounter
PersecutorEncounter = {};
local self = PersecutorEncounter

function PersecutorEncounter.getUpdateInterval()
    return 0.5
end

function PersecutorEncounter.initialize()
    Entity():setValue("persecutor_leader", true)

    if onServer() then
        deferredCallback(30, "onServerHailTimeout")
    end
end

function PersecutorEncounter.updateClient()
    if not self.interacted then
        ScriptUI():startHailing("onHailAccepted", "onHailRejected")
        self.interacted = true
    end
end

function PersecutorEncounter.initialDialog()
    local d0_YoureInAPartOf = {}
    local d1_WiseChoiceSavin = {}
    local d2_ThenWereDoingIt = {}

    d0_YoureInAPartOf.text = "You're in a part of the galaxy where you're in over your head. It's dangerous to fly so close to the galaxy core without a strong ship. You'll learn that soon enough.\n\nBut there's a solution to everything. You can save us some ammunition and your own life at the same time.\n\nPay us ${credits} Credits or we're just going to salvage your little ship, after we blow it up."%_t
    d0_YoureInAPartOf.text = d0_YoureInAPartOf.text % {credits = createMonetaryString(self.getPayAmount(Player()))}
    d0_YoureInAPartOf.answers = {
        {answer = "Pay"%_t, followUp = d1_WiseChoiceSavin, onSelect = "onPaySelected"},
        {answer = "Threaten"%_t, followUp = d2_ThenWereDoingIt, onSelect = "onThreatenSelected"}
    }

    d1_WiseChoiceSavin.text = "Wise choice. Saving us all some trouble."%_t

    d2_ThenWereDoingIt.text = "Then we're doing it the hard way. Excellent, it's been far to long since we had some real fun!"%_t

    return d0_YoureInAPartOf
end

function PersecutorEncounter.payFailedDialog()
    local dialog = {
        text = "There seems to be some trouble with your bank account - you don't have the money.\n\nWe're going to salvage your ship then."%_t,
    }

    return dialog
end

function PersecutorEncounter.onPaySelected()
    if onClient() then
        invokeServerFunction("onPaySelected")
        return
    end

    self.payUp()
end
callable(PersecutorEncounter, "onPaySelected")

function PersecutorEncounter.onThreatenSelected()
    if onClient() then
        invokeServerFunction("onThreatenSelected")
        return
    end

    deferredCallback(3, "startFight")
end
callable(PersecutorEncounter, "onThreatenSelected")

function PersecutorEncounter.onHailAccepted()
    if onClient() then
        ScriptUI():interactShowDialog(self.initialDialog(), false)
        invokeServerFunction("onHailAccepted")
        return
    end

    self.playerResponded = true
end
callable(PersecutorEncounter, "onHailAccepted")

function PersecutorEncounter.onHailRejected()
    self.onCommunicationsRejected()
end

function PersecutorEncounter.onDialogClosed()
    self.onCommunicationsRejected()
end

function PersecutorEncounter.onClientHailTimeout()
    ScriptUI():stopHailing()
end


function PersecutorEncounter.onServerHailTimeout()
    if self.playerResponded then return end

    broadcastInvokeClientFunction("onClientHailTimeout")

    self.onCommunicationsRejected()
end

function PersecutorEncounter.onCommunicationsRejected()
    if onClient() then
        invokeServerFunction("onCommunicationsRejected")
        return
    end

    Sector():broadcastChatMessage(Entity().translatedTitle, 0, "No communication? Then let's do it the hard way!"%_t, Entity().translatedTitle)
    self.startFight()
end
callable(PersecutorEncounter, "onCommunicationsRejected")

function PersecutorEncounter.showPayFailedDialog()
    ScriptUI():interactShowDialog(self.payFailedDialog(), false)
end

function PersecutorEncounter.updateServer()

    if self.flyAway then
        local ship = Entity()
        local persecutors = self.getPersecutors()

        if #persecutors > 1 then
            -- despawn all other persecutors before the boss
            if persecutors[1].index == ship.index then
                Sector():deleteEntityJumped(persecutors[2])
            else
                Sector():deleteEntityJumped(persecutors[1])
            end
        else
            Sector():deleteEntityJumped(persecutors[1])
        end
    end

end

function PersecutorEncounter.payUp()
    if onClient() then
        invokeServerFunction("payUp")
        return
    end

    local player = Player(callingPlayer)
    local sum = self.getPayAmount(player)

    local canPay, msg, args = player:canPayMoney(sum)

    if canPay then
        player:pay("Paid bandits %1% Credits."%_T, sum)
        deferredCallback(5, "leave")
    else
        invokeClientFunction(player, "showPayFailedDialog")
        deferredCallback(10, "startFight")
    end

end
callable(PersecutorEncounter, "payUp")


function PersecutorEncounter.startFight()
    if onClient() then
        invokeServerFunction("startFight")
        return
    end

    if not self.fightStarted then
        Sector():broadcastChatMessage(Entity().translatedTitle, 0, "Blow it up boys, but make sure you don't hit the valuable parts this time!"%_t)
    end

    self.fightStarted = true

    for _, other in pairs(self.getPersecutors()) do
        other:invokeFunction("ai/persecutor.lua", "startAttacking")
    end
end
callable(PersecutorEncounter, "startFight")


function PersecutorEncounter.leave()
    if onClient() then
        invokeServerFunction("leave")
        return
    end

    self.flyAway = true
end
callable(PersecutorEncounter, "leave")

function PersecutorEncounter.getPayAmount(player)
    return math.max(math.ceil(player.money * 0.15 / 1000) * 1000, 10000)
end

function PersecutorEncounter.getPersecutors()
    return {Sector():getEntitiesByScript("ai/persecutor.lua")}
end
