package.path = package.path .. ";data/scripts/lib/?.lua"
include ("stringutility")


function interactionPossible(playerIndex, option)
    return true
end

function initialize()

    if onClient() then
        if EntityIcon().icon == "" then
            EntityIcon().icon = "data/textures/icons/pixel/headquarters.png"
        end
    else
        if Entity().title == "" then
            local faction = Faction(Entity().factionIndex)

            if faction then
                local name = faction.name
                if name:starts("The ") then
                    name = name:sub(5)
                end

                Entity():setTitle("${faction} Headquarters"%_t, {faction = name})
            else
                Entity().title = "Headquarters"%_t
            end
        end
    end

end

function initUI()
    ScriptUI():registerInteraction("Diplomacy"%_t, "onDiplomacyClicked", 10);
end


function onDiplomacyClicked()
    local owner = Player().craftFaction
    local playerWindow = PlayerWindow()
    if owner.isPlayer then
        playerWindow:selectTab("Diplomacy"%_t)
        playerWindow:show()
    elseif owner.isAlliance then
        playerWindow:selectTab("Alliance"%_t)
        AllianceTab():selectTab("Diplomacy"%_t)
        playerWindow:show()
    end
end
