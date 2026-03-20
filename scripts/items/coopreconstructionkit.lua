package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
include("randomext")
include("utility")
local NamePool = include ("namepool")

function create(kit, rarity)

    kit.name = "Co-'n-Op Reconstruction Kit"%_t
    kit.price = 50 * 1000

    kit.rarity = rarity
    kit:setValue("subtype", "ReconstructionKit")
    kit.icon = "data/textures/icons/reconstruction-token.png"
    kit.iconColor = rarity.color
    kit.stackable = false
    kit.droppable = false
    kit.depleteOnUse = true

    local tooltip = Tooltip()
    tooltip.icon = kit.icon
    tooltip.rarity = rarity

    local title = kit.name

    local headLineSize = 25
    local headLineFontSize = 15
    local line = TooltipLine(headLineSize, headLineFontSize)
    line.ctext = title
    line.ccolor = kit.rarity.tooltipFontColor
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 14)
    line.ltext = "Craft"%_t
    line.rtext = "Any"%_t
    line.icon = "data/textures/icons/ship.png"
    line.iconColor = ColorRGB(1, 1, 1)
    tooltip:addLine(line)

    local line = TooltipLine(20, 14)
    line.ltext = "Player"%_t
    line.rtext = "Any"%_t
    line.icon = "data/textures/icons/flying-flag.png"
    line.iconColor = ColorRGB(1, 1, 1)
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Use near a wreckage of a destroyed ship"%_t
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "Quickly reassembles a destroyed ship"%_t
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "Prioritizes other players"%_t
    tooltip:addLine(line)


    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 15)
    line.ltext = "Depleted on Use"%_t
    line.lcolor = ColorRGB(1.0, 1.0, 0.3)
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Can be activated by the player"%_t
    tooltip:addLine(line)


    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Disclaimer: Additional Repairs Necessary!"%_t
    line.lcolor = ColorRGB(0.5, 0.5, 0.5)
    tooltip:addLine(line)

    kit:setTooltip(tooltip)

    return kit
end

function activate(item)
    local activator = Player()

    -- can't activate while not in a ship (no self-revive)
    if not activator.craft then return end

    local players = {Sector():getPlayers()}

    local factionsInOrder = {}
    for _, player in pairs(players) do
        if player.index ~= activator.index then
            table.insert(factionsInOrder, player)
        end
    end

    for _, player in pairs(players) do
        local alliance = player.alliance
        if alliance then
            table.insert(factionsInOrder, alliance)
        end
    end

    -- player goes last
    table.insert(factionsInOrder, activator)

    for _, faction in pairs(factionsInOrder) do
        if tryReconstruct(activator, faction) then
            return true
        end
    end

    activator:sendChatMessage("", ChatMessageType.Error, "No wreckage found."%_T)
    return false
end

function tryReconstruct(player, faction)
    local sector = Sector()
    local x, y = sector:getCoordinates()

    local allShips = {faction:getShipNames()}

    for _, shipName in pairs(allShips) do
        local sx, sy = faction:getShipPosition(shipName)
        if sx ~= x or sy ~= y then
            goto continue
        end

        if not faction:getShipDestroyed(shipName) then
            goto continue
        end

        local entry = ShipDatabaseEntry(faction.index, shipName)
        if entry:getScriptValue("lost_in_rift") then
            goto continue
        end

        if entry:getEntityType() ~= EntityType.Ship then
            goto continue
        end

        local maxHp, hpPercentage, hpMalusFactor, hpMalusReason, damaged = entry:getDurabilityProperties()

        local craft = faction:restoreCraft(shipName, entry:getLocalPosition(), true)
        if not craft then
            goto continue
        end

        CargoBay(craft):clear()
        craft:setValue("untransferrable", nil) -- tutorial could have broken this
        craft:setMalusFactor(1, MalusReason.None) -- must reset first

        -- set a new malus that is either 50%, or the malus that was there before reconstruction
        craft:setMalusFactor(math.min(hpMalusFactor, 0.5), MalusReason.Reconstruction)
        craft:addScript("data/scripts/entity/utility/healovertime", 0.4, 60)

        craft:sendCallback("onReconstructed", craft.id, faction.index)

        -- delete all remnants that might still be floating around
        local wreckages = {sector:getEntitiesByScriptValue("reconstruct_faction", faction.index)}
        for _, wreck in pairs(wreckages) do
            local name = wreck:getValue("reconstruct_name")

            if name == shipName then
                sector:deleteEntity(wreck)
            end
        end

        local info = makeCallbackSenderInfo(craft)
        player:sendCallback("onReconstructionKitUsed", info)

        player:sendChatMessage(player.name, ChatMessageType.Normal, "Reconstructed %1% of %2%."%_T, shipName, faction.name)

        -- place player in the new craft
        if faction.isPlayer and not faction.craft then
            faction.craftIndex = craft.id
            faction:sendChatMessage("", ChatMessageType.Normal, "Reconstructed by %1%."%_T, player.name)
        end

        if craft then -- this stupid 'if' is necessary so lua doesn't whine about statements after 'return'
            return true
        end

        ::continue::
    end
end
