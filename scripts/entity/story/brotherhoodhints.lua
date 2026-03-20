package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("stringutility")
include("randomext")


function initialize()
    Entity():setValue("valuable_object", RarityType.Uncommon)
end

function interactionPossible(player, option)
    local craft = Player().craft
    if craft == nil then return false end

    local dist = craft:getNearestDistance(Entity())
    if dist < 50.0 then
        return true
    end

    return false, "You're not close enough to open the object."%_t
end

function initUI()
    ScriptUI():registerInteraction("Read log fragment"%_t, "onRead")
end

function onRead(entityIndex)
    if entityIndex == nil then
        entityIndex = Entity().index
    end

    if onServer() then return end

    ScriptUI(entityIndex):showDialog(makeDialog())
end

function makeDialog()
    local hint1 = {text = "We will make a fortune with this artifact."%_t}
    local hint2 = {text = "Once the brotherhood gets the artifact, they will pay us very well."%_t}
    local hint3 = {text = "They attacked us instead of paying us!"%_t}
    local hint4 = {text = "But we brought them the artifact...."%_t}
    local hint5 = {text = "STOP! We brought you the artifact. Pay us as promised!"%_t}
    local hint6 = {text = "The Brotherhood is dangerous..."%_t}

    local hints = {
        hint1,
        hint2,
        hint3,
        hint4,
        hint5,
        hint6,
    }

    local hint = hints[random():getInt(1, #hints)]
    return hint
end
