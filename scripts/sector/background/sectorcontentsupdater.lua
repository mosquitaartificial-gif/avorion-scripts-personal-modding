
package.path = package.path .. ";data/scripts/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"

include("relations")
local SectorSpecifics = include("sectorspecifics")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace SCUpdater
SCUpdater = {}

if onServer() then

function SCUpdater.getUpdateInterval()
    return 5 * 60
end

function SCUpdater.secure()
    return {
        initialFactionIndex = SCUpdater.initialFactionIndex,
        factionIndex = SCUpdater.factionIndex
    }
end

function SCUpdater.restore(data)
    SCUpdater.initialFactionIndex = data.initialFactionIndex
    SCUpdater.factionIndex = data.factionIndex
end


function SCUpdater.updateServer()
    SCUpdater.refreshControllingFaction()
end

function SCUpdater.refreshControllingFaction()
    local sector = Sector()
    local x, y = sector:getCoordinates()

    local view = Galaxy():getSectorView(x, y)
    if view then
        if SCUpdater.initialFactionIndex == nil then
            local specs = SectorSpecifics(x, y, GameSeed())
            if specs.regular then
                SCUpdater.initialFactionIndex = specs.factionIndex
            else
                SCUpdater.initialFactionIndex = 0
            end
        end

        if SCUpdater.factionIndex and SCUpdater.factionIndex ~= 0 and view.factionIndex ~= SCUpdater.factionIndex then
--            print("sector controlling faction changed")
            local oldControllingFaction = Faction(SCUpdater.factionIndex)
            local controllingFaction = Faction(view.factionIndex)

            if oldControllingFaction and oldControllingFaction.isAIFaction and
                    controllingFaction and not controllingFaction.isAIFaction then
--                print("sector was taken over, worsen relations")

                if Galaxy():isCentralFactionArea(x, y, oldControllingFaction.index) then
                    changeRelations(controllingFaction, oldControllingFaction, -30000, nil, true, true)
                else
                    changeRelations(controllingFaction, oldControllingFaction, -10000, nil, true, true)
                end

                controllingFaction:sendChatMessage("", ChatMessageType.Economy, "Relations worsened with a faction because you took over control of sector (%1%:%2%)."%_T, x, y)
            end
        end

        SCUpdater.factionIndex = view.factionIndex
    end

    return {factionIndex = SCUpdater.factionIndex}
end

end
