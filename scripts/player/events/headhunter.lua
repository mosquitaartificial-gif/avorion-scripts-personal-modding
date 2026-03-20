
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("galaxy")
include ("randomext")
include ("stringutility")
include ("faction")
local AsyncShipGenerator = include ("asyncshipgenerator")
local Placer = include("placer")
local SpawnUtility = include ("spawnutility")
local EventUT = include ("eventutility")
local FactionEradicationUtility = include("factioneradicationutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace HeadHunter
HeadHunter = {}

local attackTimer = 0
local playerAttackThreshold = 45 * 60

if onServer() then

local headhunterMessages =
{
    "This is ${player}! That's the one our client wants!"%_T,
    "Found you, ${player}. Let's shoot them down and get our money. Make it quick."%_T,
    "There they are. Alright, ${player} it's nothing personal, it's just a job."%_T,
}

local factionAtWarMessages =
{
    "Oh look, it's ${player}! Let's make them disappear!"%_T,
    "So you dared to show up in our territory, ${player}? You won't make this mistake again."%_T,
    "Who do we have here? ${player}. Well, say hello to pest control."%_T,
}

local sarcasticMessages =
{
    "Oh, look who's being attacked by bounty hunters. What a surprise."%_T,
    "About time that you left this place."%_T,
    "Oh, too bad, someone's attacking you."%_T,
    "Now that's a nice surprise! Take them down!"%_T,
    "I really hoped that some bounty hunters would show up and make you leave."%_T,
    "Great! I really hoped that this would happen!"%_T,
    "Ha! I think I'm just going to sit back and watch the show."%_T,
    "Too bad nobody will help you here."%_T,
    "It's your own fault for staying around when you're not welcome."%_T,
}

function HeadHunter.initialize()
end

function HeadHunter.getUpdateInterval()
    return 15 * 60
end

-- no need to return from udpate() functions usually, but this is for a unit test
function HeadHunter.update(timeStep)
    -- attack on player can happen every 45 minutes: timer counts 15 minute increments
    attackTimer = attackTimer + timeStep

    if attackTimer < playerAttackThreshold then return false end

    -- attack player directly
    if attackTimer >= playerAttackThreshold then -- player gets attacked by headhunters
        local sector = Sector()
        local x, y = sector:getCoordinates()
        local hx, hy = Player():getHomeSectorCoordinates()

        -- no attacks in home sector
        if x == hx and y == hy then
            attackTimer = attackTimer - timeStep -- try again in 15 minutes
            return false
        end

        if Galaxy():sectorInRift(x, y) then
            attackTimer = attackTimer - timeStep -- try again in 15 minutes
            return false
        end

        if not EventUT.attackEventAllowed() then
            attackTimer = attackTimer - timeStep -- try again in 15 minutes
            return false
        end

        -- find a hopefully evil faction that the player knows already
        local faction, useHeadhunters = HeadHunter.findNearbyEnemyFaction()

        if faction == nil then
            attackTimer = attackTimer - timeStep -- try again in 15 minutes
            return false
        end

        -- create the head hunters
        HeadHunter.createEnemies(faction, useHeadhunters)

        attackTimer = 0
    end

    return true
end

function HeadHunter.getFaction()
    local x, y = Sector():getCoordinates()

    return EventUT.getHeadhunterFaction(x, y)
end

function HeadHunter.findNearbyEnemyFaction()

    -- find a hopefully evil faction that the player knows already
    local player = Player().craftFaction
    if not player then return end

    local x, y = Sector():getCoordinates()

    local locations =
    {
        {x = x, y = y},
        {x = x + math.random(-7, 7), y = y + math.random(-7, 7)},
        {x = x + math.random(-7, 7), y = y + math.random(-7, 7)},
        {x = x + math.random(-7, 7), y = y + math.random(-7, 7)},
        {x = x + math.random(-7, 7), y = y + math.random(-7, 7)},
    }

    local galaxy = Galaxy()
    local faction = nil
    local useHeadhunters = true
    for i, coords in pairs(locations) do
        local f = galaxy:getControllingFaction(coords.x, coords.y)

        if f and galaxy:isMapFaction(f.index) and player:knowsFaction(f.index) then
            local relation = player:getRelation(f.index)

            if relation.level < -80000 or relation.status == RelationStatus.War then
                if relation.status == RelationStatus.War then
                    useHeadhunters = false
                end

                faction = f
                break
            end
        end
    end

    if not faction then
        -- no enemy faction found yet
        -- look in a bigger radius, but only for factions at war
        for i = 1, 4 do
            coords = {x = x + math.random(-10, 10), y = y + math.random(-10, 10)}
            local f = galaxy:getControllingFaction(coords.x, coords.y)

            if f and galaxy:isMapFaction(f.index) and player:knowsFaction(f.index) then
                if player:getRelationStatus(f.index) == RelationStatus.War then
                    useHeadhunters = false

                    faction = f
                    break
                end
            end
        end
    end

    if not faction then
        -- no enemy faction found, check if there is one in the bigger neighborhood
        -- don't check for factions at war, they only use headhunters at that distance
        for i, coords in pairs(locations) do
            local f = Galaxy():getLocalFaction(coords.x, coords.y)

            if f and galaxy:isMapFaction(f.index) and player:knowsFaction(f.index) then
                if player:getRelations(f.index) < -80000 then
                    faction = f
                    break
                end
            end
        end
    end

    if faction then
        -- no head hunters from start ally
        local startAlly = player:getValue("start_ally")
        if startAlly and faction.index == startAlly then return end
    end

    return faction, useHeadhunters
end

function HeadHunter.createEnemies(faction, useHeadhunters)
    local onFinished = function(ships)
        local player = Player()
        local craftFaction = player.craftFaction

        for _, ship in pairs(ships) do
            local ai = ShipAI(ship)
            ai:setAggressive()

            if useHeadhunters then
                ai:registerFriendFaction(faction.index)
                ai:registerEnemyFaction(player.index)
                if player.allianceIndex then
                    ai:registerEnemyFaction(player.allianceIndex)
                end

                ship:setValue("secret_contractor", faction.index)
            end

            ship:addScriptOnce("deleteonplayersleft.lua")
            ship:setValue("is_persecutor", true)

            if string.match(ship.title, "Persecutor") then
                ship.title = "Bounty Hunter"%_T
            end
        end

        local note = HeadHunter.makeNote(player, faction)
        Loot(ships[1]):insert(note)

        Placer.resolveIntersections(ships)

        -- add enemy buffs
        SpawnUtility.addEnemyBuffs(ships)

        if useHeadhunters then
            craftFaction:sendChatMessage(ships[1], ChatMessageType.Chatter, randomEntry(headhunterMessages) % {player = craftFaction.name})
        else
            craftFaction:sendChatMessage(ships[1], ChatMessageType.Chatter, randomEntry(factionAtWarMessages) % {player = craftFaction.name})
        end

        deferredCallback(3, "sarcasticRemark")
    end

    -- create the head hunters
    local dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
    local up = vec3(0, 1, 0)
    local right = normalize(cross(dir, up))
    local pos = dir * 1500

    -- default: use headhunters
    local huntingFaction = HeadHunter.getFaction()
    if not useHeadhunters then
        if FactionEradicationUtility.isFactionEradicated(faction.index) then return end

        huntingFaction = faction
    end

    local generator = AsyncShipGenerator(HeadHunter, onFinished)
    generator:startBatch()

    local x, y = Sector():getCoordinates()
    local volume = Balancing_GetSectorShipVolume(x, y)

    local galaxy = Galaxy()
    if useHeadhunters then
        generator:createPersecutorShip(huntingFaction, MatrixLookUpPosition(dir, up, pos), volume * 4)
        generator:createPersecutorShip(huntingFaction, MatrixLookUpPosition(dir, up, pos), volume * 4)
        generator:createBlockerShip(huntingFaction, MatrixLookUpPosition(dir, up, pos), volume * 2)

    else
        -- determine if we are in empty space, outer or central faction area
        local controllingFaction = galaxy:getControllingFaction(x, y)
        local isCentralArea = galaxy:isCentralFactionArea(x, y, faction.index)

        -- determine the amounts of defenders to send
        local numDefenders
        if controllingFaction and controllingFaction.index == faction.index then
            if isCentralArea then
                numDefenders = math.random(7, 9)
            else
                numDefenders = math.random(4, 5)
            end
        else
            numDefenders = math.random(2, 3)
        end

        local aggressive = faction:getTrait("aggressive")
        local additionalDefenders = 0
        if aggressive <= -0.5 then
            numDefenders = numDefenders - 1
        elseif aggressive > 0.33 then
            numDefenders = numDefenders + math.floor(aggressive * 2.9) -- just below 3, max additional defenders should be 2
        end

        for i = 1, numDefenders do
            generator:createDefender(huntingFaction, MatrixLookUpPosition(dir, up, pos))
        end

    end

    generator:endBatch()

    if useHeadhunters then
        local player = Player().craftFaction
        galaxy:setFactionRelations(huntingFaction, player, 0, false, false)
        galaxy:setFactionRelationStatus(huntingFaction, player, RelationStatus.Neutral, false, false)
    end
end

function HeadHunter.sarcasticRemark()
    local sector = Sector()
    local x, y = sector:getCoordinates()
    local faction = Galaxy():getControllingFaction(x, y)
    if not faction then return end

    local player = Player().craftFaction

    local ships = {sector:getEntitiesByType(EntityType.Ship)}
    for _, ship in pairs(ships) do
        local relation = player:getRelation(ship.factionIndex)
        if relation.level <= -80000 or relation.status == RelationStatus.War then
            player:sendChatMessage(ship, ChatMessageType.Chatter, randomEntry(sarcasticMessages))
            return
        end
    end
end

function HeadHunter.makeNote(player, huntingFaction)

    local x, y = Sector():getCoordinates()
    local money = round(math.max(50000, 500000 * Balancing_GetSectorRichnessFactor(x, y)) / 10000) * 10000
    local reward = "¢${money}" % {money = createMonetaryString(money)}
    local shipName = "Unknown"%_t

    local craft = player.craft
    if valid(craft) then
        if craft.name and craft.name ~= "" then
            shipName = craft.name
        end
    end

    local note = VanillaInventoryItem()
    note.name = "Bounty Chip"%_t
    note.price = 1000

    local rarity = Rarity(RarityType.Common)
    note.rarity = rarity
    note:setValue("subtype", "BountyChip")
    note.icon = "data/textures/icons/bounty-chip.png"
    note.iconColor = rarity.color
    note.stackable = true

    local tooltip = Tooltip()
    tooltip.icon = note.icon
    tooltip.rarity = rarity

    local title = note.name

    local headLineSize = 25
    local headLineFontSize = 15
    local line = TooltipLine(headLineSize, headLineFontSize)
    line.ctext = title
    line.ccolor = note.rarity.tooltipFontColor
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Reward"%_t
    line.icon = "data/textures/icons/cash.png"
    line.iconColor = ColorRGB(1, 1, 1)
    line.rtext = reward
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Target"%_t
    line.rtext = "${faction:"..player.index.."}"
    line.icon = "data/textures/icons/player.png"
    line.iconColor = ColorRGB(1, 1, 1)
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "Ship"%_t
    line.rtext = shipName
    line.icon = "data/textures/icons/ship.png"
    line.iconColor = ColorRGB(1, 1, 1)
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 14)
    line.ltext = "Target is wanted dead."%_t
    tooltip:addLine(line)

    local line = TooltipLine(20, 14)
    line.ltext = "Reward requires proof of ship destruction."%_t
    tooltip:addLine(line)

    local line = TooltipLine(20, 14)
    line.ltext = " - ${faction:"..huntingFaction.index.."}"
    tooltip:addLine(line)


    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 14)
    line.ltext = "Looks like someone made some enemies."%_t
    line.lcolor = ColorRGB(0.4, 0.4, 0.4)
    tooltip:addLine(line)

    note:setTooltip(tooltip)

    return note
end

end
