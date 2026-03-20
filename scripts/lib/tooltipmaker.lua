package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("utility")
include ("randomext")
include ("stringutility")
include ("inventoryitemprice")
include ("damagetypeutility")
local FighterUT = include ("fighterutility")


-- modders: this is just a little help to keep this lua code clearer
-- those numbers are predefined via the engine, don't touch this
local TooltipType =
{
    Short = 1,
    Verbose = 2,
}

local WeaponObjectType =
{
    Turret = 1,
    Fighter = 2,
}

local iconColor = ColorRGB(0.5, 0.5, 0.5)

local headLineSize = 25
local headLineFont = 15

local compResult = {}
compResult[-2] = {icon = "data/textures/icons/minus.png", color = ColorRGB(0.0, 0.0, 0.0)}
compResult[-1] = {icon = "data/textures/icons/arrow-down.png", color = ColorRGB(1, 0, 0)}
compResult[0] = {icon = "data/textures/icons/minus.png", color = ColorRGB(1, 1, 0)}
compResult[1] = {icon = "data/textures/icons/arrow-up.png", color = ColorRGB(0, 1, 0)}

local function applyLessBetter(line, a, b, stat, digits, cond)
    if not stat or not line or not a or not b then return end

    local comp = function()
        if cond ~= nil and cond == false then return -2 end

        local va = a[stat] or 0
        local vb = b[stat] or 0

        if digits then
            va = round(va, digits)
            vb = round(vb, digits)
        end

        if va < vb then return 1 end
        if va > vb then return -1 end
        return 0
    end

    local result = compResult[comp()]
    if not result then return end

    line.iconRight = result.icon
    line.iconRightColor = result.color
end

local function applyMoreBetter(line, a, b, stat, digits, cond)
    if not stat or not line or not a or not b then return end

    local comp = function()
        if cond ~= nil and cond == false then return -2 end

        local va = a[stat] or 0
        local vb = b[stat] or 0

        if not va then return nil end
        if not vb then return nil end

        if digits then
            va = round(va, digits)
            vb = round(vb, digits)
        end

        if va > vb then return 1 end
        if va < vb then return -1 end
        return 0
    end

    local result = compResult[comp()]
    if not result then return end

    line.iconRight = result.icon
    line.iconRightColor = result.color
end

local function replaceFactionName(str)
    return str:gsub('($%b{})', function(w)
        local key = w:sub(3, -2)
        local fragments = key:split(":")

        if #fragments == 2 then
            if fragments[1] == "faction" then
                local number = tonumber(fragments[2])
                if number then
                    local faction = Faction(number)
                    if faction then return faction.translatedName end
                end
            end
        end

        return w
    end)
end

function replaceTooltipFactionNames(tooltip)

    local lines = {tooltip:getLines()}
    for i, line in pairs(lines) do
        line.ltext = replaceFactionName(line.ltext)
        line.rtext = replaceFactionName(line.rtext)
        line.ctext = replaceFactionName(line.ctext)

        tooltip:setLine(i-1, line)
    end

end

local function fillWeaponTooltipData(obj, tooltip, other, objectType, tooltipType)

    tooltipType = tooltipType or TooltipType.Simple

    -- rarity name
    local line = TooltipLine(5, 12)
    line.ctext = string.upper(tostring(obj.rarity))
    line.ccolor = obj.rarity.tooltipFontColor
    tooltip:addLine(line)

    -- primary stats, one by one
    local fontSize = 13
    local lineHeight = 16

    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Tech"%_t
    line.rtext = round(obj.averageTech, 1)
    line.icon = "data/textures/icons/circuitry.png";
    line.iconColor = iconColor
    tooltip:addLine(line)

    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Material"%_t
    line.rtext = obj.material.name
    line.rcolor = obj.material.color
    line.icon = "data/textures/icons/metal-bar.png";
    line.iconColor = obj.material.color
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(8, 8))

    if obj.damage > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "DPS"%_t
        line.rtext = round(obj.dps, 1)
        line.icon = "data/textures/icons/screen-impact.png";
        line.iconColor = iconColor
        applyMoreBetter(line, obj, other, "dps", 1, (other and other.damage > 0))
        tooltip:addLine(line)

        -- burst damage calculation
        local burst = 0
        for _, weapon in pairs({obj:getWeapons()}) do
            burst = burst + weapon.damage * weapon.shotsPerSecond
        end

        burst = round(burst, 1)

        if burst ~= round(obj.dps, 1) then
            local line = TooltipLine(lineHeight, 12)
            line.ltext = "Burst DPS"%_t
            line.rtext = burst
            line.icon = "data/textures/icons/nothing.png";
            line.iconColor = iconColor
            line.lcolor = ColorRGB(0.7, 0.7, 0.7)
            line.rcolor = ColorRGB(0.7, 0.7, 0.7)
            line.fontType = FontType.Normal
            if other then
                applyMoreBetter(line, {dps_burst = burst}, {dps_burst = round(other.damage * other.shotsPerSecond, 1)}, "dps_burst", 1, other)
            end
            tooltip:addLine(line)
        end

        if objectType == WeaponObjectType.Turret and obj.slots ~= 1 and tooltipType == TooltipType.Verbose then
            local line = TooltipLine(lineHeight, fontSize)
            line.ltext = "DPS / Slot"%_t
            line.rtext = round(obj.dps / obj.slots, 1)
            line.icon = "data/textures/icons/screen-impact.png";
            line.iconColor = iconColor
            if other then
                applyMoreBetter(line, {dps = obj.dps / obj.slots}, {dps = other.dps / other.slots}, "dps", 1, other)
            end
            tooltip:addLine(line)
        end

        tooltip:addLine(TooltipLine(8, 8))

        if not obj.continuousBeam then
            -- damage
            local line = TooltipLine(lineHeight, fontSize)
            line.ltext = "Damage"%_t
            line.rtext = round(obj.damage, 1)

            local shotsPerFiring = obj.shotsPerFiring
            if obj.simultaneousShooting then
                local damagingWeapons = 0
                for _, weapon in pairs({obj:getWeapons()}) do
                    if weapon.damage > 0 then
                        damagingWeapons = damagingWeapons + 1
                    end
                end

                shotsPerFiring = shotsPerFiring * damagingWeapons
            end
            if shotsPerFiring > 1 then
                line.rtext = line.rtext .. " x" .. shotsPerFiring
            end
            line.icon = "data/textures/icons/screen-impact.png";
            line.iconColor = iconColor
            applyMoreBetter(line, obj, other, "damage", 1, (other and other.damage > 0 and not other.continuousBeam))
            tooltip:addLine(line)

            -- fire rate
            local line = TooltipLine(lineHeight, fontSize)
            line.ltext = "Fire Rate"%_t
            if obj.fireRate < 1 then
                line.rtext = round(obj.fireRate, 2)
            else
                line.rtext = round(obj.fireRate, 1)
            end
            line.icon = "data/textures/icons/bullets.png";
            line.iconColor = iconColor
            applyMoreBetter(line, obj, other, "fireRate", 1, (other and other.damage > 0 and not other.continuousBeam))
            tooltip:addLine(line)
        end
    end

    if obj.otherForce > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Push"%_t
        line.rtext = toReadableValue(obj.otherForce, "N /* unit: Newton*/"%_t)
        line.icon = "data/textures/icons/back-forth.png";
        line.iconColor = iconColor
        tooltip:addLine(line)
    elseif obj.otherForce < 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Pull"%_t
        line.rtext = toReadableValue(-obj.otherForce, "N /* unit: Newton*/"%_t)
        line.icon = "data/textures/icons/back-forth.png";
        line.iconColor = iconColor
        tooltip:addLine(line)
    end

    if obj.selfForce > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Self Push"%_t
        line.rtext = toReadableValue(obj.selfForce, "N /* unit: Newton*/"%_t)
        line.icon = "data/textures/icons/back-forth.png";
        line.iconColor = iconColor
        tooltip:addLine(line)
    elseif obj.selfForce < 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Self Pull"%_t
        line.rtext = toReadableValue(-obj.selfForce, "N /* unit: Newton*/"%_t)
        line.icon = "data/textures/icons/back-forth.png";
        line.iconColor = iconColor
        tooltip:addLine(line)
    end

    if obj.holdingForce > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Force Power"%_t
        line.rtext = toReadableValue(obj.holdingForce, "N /* unit: Newton*/"%_t)
        line.icon = "data/textures/icons/back-forth.png";
        line.iconColor = iconColor
        tooltip:addLine(line)
    end

    if obj.stoneRefinedEfficiency > 0 and obj.metalRefinedEfficiency > 0 then

        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Eff. Stone"%_t
        line.rtext = round(obj.stoneRefinedEfficiency * 100, 1)
        line.icon = "data/textures/icons/scrap-metal.png";
        line.iconColor = iconColor
        applyMoreBetter(line, obj, other, "bestEfficiency", 3, (other and other.bestEfficiency > 0))
        tooltip:addLine(line)

        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Eff. Metal"%_t
        line.rtext = round(obj.metalRefinedEfficiency * 100, 1)
        line.icon = "data/textures/icons/scrap-metal.png";
        line.iconColor = iconColor
        applyMoreBetter(line, obj, other, "bestEfficiency", 3, (other and other.bestEfficiency > 0))
        tooltip:addLine(line)

    elseif obj.stoneRefinedEfficiency > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Efficiency"%_t
        line.rtext = round(obj.stoneRefinedEfficiency * 100, 1)
        line.icon = "data/textures/icons/scrap-metal.png";
        line.iconColor = iconColor
        applyMoreBetter(line, obj, other, "bestEfficiency", 3, (other and other.bestEfficiency > 0))
        tooltip:addLine(line)
    elseif obj.metalRefinedEfficiency > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Efficiency"%_t
        line.rtext = round(obj.metalRefinedEfficiency * 100, 1)
        line.icon = "data/textures/icons/scrap-metal.png";
        line.iconColor = iconColor
        applyMoreBetter(line, obj, other, "bestEfficiency", 3, (other and other.bestEfficiency > 0))
        tooltip:addLine(line)
    end

    if obj.stoneRawEfficiency > 0 and obj.metalRawEfficiency > 0 then

        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Eff. Stone"%_t
        line.rtext = round(obj.stoneRawEfficiency * 100, 1)
        line.icon = "data/textures/icons/scrap-metal.png";
        line.iconColor = iconColor
        applyMoreBetter(line, obj, other, "bestEfficiency", 3, (other and other.bestEfficiency > 0))
        tooltip:addLine(line)

        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Eff. Metal"%_t
        line.rtext = round(obj.metalRawEfficiency * 100, 1)
        line.icon = "data/textures/icons/scrap-metal.png";
        line.iconColor = iconColor
        applyMoreBetter(line, obj, other, "bestEfficiency", 3, (other and other.bestEfficiency > 0))
        tooltip:addLine(line)

    elseif obj.stoneRawEfficiency > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Efficiency"%_t
        line.rtext = round(obj.stoneRawEfficiency * 100, 1)
        line.icon = "data/textures/icons/scrap-metal.png";
        line.iconColor = iconColor
        applyMoreBetter(line, obj, other, "bestEfficiency", 3, (other and other.bestEfficiency > 0))
        tooltip:addLine(line)
    elseif obj.metalRawEfficiency > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Efficiency"%_t
        line.rtext = round(obj.metalRawEfficiency * 100, 1)
        line.icon = "data/textures/icons/scrap-metal.png";
        line.iconColor = iconColor
        applyMoreBetter(line, obj, other, "bestEfficiency", 3, (other and other.bestEfficiency > 0))
        tooltip:addLine(line)
    end

    if obj.hullRepairRate > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Hull Repair /s"%_t
        line.rtext = round(obj.hullRepairRate, 1)
        line.icon = "data/textures/icons/health-normal.png";
        line.iconColor = iconColor
        applyMoreBetter(line, obj, other, "hullRepairRate", 1, (other and other.hullRepairRate > 0))
        tooltip:addLine(line)
    end

    if obj.shieldRepairRate > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Shield Repair /s"%_t
        line.rtext = round(obj.shieldRepairRate, 1)
        line.icon = "data/textures/icons/health-normal.png";
        line.iconColor = iconColor
        applyMoreBetter(line, obj, other, "shieldRepairRate", 1, (other and other.shieldRepairRate > 0))
        tooltip:addLine(line)
    end

    if tooltipType == TooltipType.Verbose then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Accuracy"%_t
        line.rtext = round(obj.accuracy * 100, 1)
        line.icon = "data/textures/icons/gunner.png";
        line.iconColor = iconColor
        applyMoreBetter(line, obj, other, "accuracy", 3)
        tooltip:addLine(line)
    end

    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Range"%_t
    line.rtext = round(obj.reach * 10 / 1000, 2)
    line.icon = "data/textures/icons/target-shot.png";
    line.iconColor = iconColor
    applyMoreBetter(line, obj, other, "reach", 3)
    tooltip:addLine(line)

    if tooltipType == TooltipType.Verbose then
        local weapon = obj:getWeapons() -- take first weapon
        if weapon and weapon.blockPenetration > 1 then
            local line = TooltipLine(lineHeight, fontSize)
            line.ltext = "Hull Penetration"%_t
            line.rtext = weapon.blockPenetration .. " blocks"%_t
            line.icon = "data/textures/icons/drill.png";
            line.iconColor = iconColor
            tooltip:addLine(line)
        end
    end

    -- empty line
    tooltip:addLine(TooltipLine(8, 8))

    if tooltipType == TooltipType.Verbose then
        if obj.shotsUntilOverheated > 0 then
            local line = TooltipLine(lineHeight, fontSize)
            line.ltext = "Continuous Shots"%_t
            line.rtext = obj.shotsUntilOverheated
            line.icon = "data/textures/icons/bullets.png";
            line.iconColor = iconColor
            applyMoreBetter(line, obj, other, "shotsUntilOverheated", nil, (other and other.shotsUntilOverheated > 0))
            tooltip:addLine(line)

            local line = TooltipLine(lineHeight, fontSize)
            if obj.coolingType == CoolingType.BatteryCharge then
                line.ltext = "Time Until Depleted"%_t
                line.icon = "data/textures/icons/battery-pack-alt.png";
            else
                line.ltext = "Time Until Overheated"%_t
                line.icon = "data/textures/icons/overheat.png";
            end
            line.rtext = round(obj.shootingTime, 1) .. "s /* Unit for seconds */"%_t
            line.iconColor = iconColor
            applyMoreBetter(line, obj, other, "shootingTime", 1, (other and other.shotsUntilOverheated > 0))
            tooltip:addLine(line)

            local line = TooltipLine(lineHeight, fontSize)
            if obj.coolingType == CoolingType.BatteryCharge then
                line.ltext = "Recharge Time"%_t
                line.icon = "data/textures/icons/anticlockwise-rotation.png";
            else
                line.ltext = "Cooling Time"%_t
                line.icon = "data/textures/icons/weapon-cooldown.png";
            end
            line.rtext = round(obj.coolingTime, 1) .. "s /* Unit for seconds */"%_t
            line.iconColor = iconColor
            applyLessBetter(line, obj, other, "coolingTime", 1, (other and other.shotsUntilOverheated > 0))
            tooltip:addLine(line)

            -- empty line
            tooltip:addLine(TooltipLine(8, 8))
        end

        if obj.coolingType == 1 or obj.coolingType == 2 then

            local line = TooltipLine(lineHeight, fontSize)

            if obj.coolingType == 2 then
                line.ltext = "Energy /s"%_t
            else
                line.ltext = "Energy /shot"%_t
            end
            line.rtext = round(obj.baseEnergyPerSecond)
            line.icon = "data/textures/icons/electric.png";
            line.iconColor = iconColor
            applyLessBetter(line, obj, other, "baseEnergyPerSecond", 0, (other and (other.coolingType == 1 or other.coolingType == 2)))
            tooltip:addLine(line)

            local line = TooltipLine(lineHeight, fontSize)
            line.ltext = "Energy Increase /s"%_t
            line.rtext = round(obj.energyIncreasePerSecond, 1)
            line.icon = "data/textures/icons/electric.png";
            line.iconColor = iconColor
            applyLessBetter(line, obj, other, "energyIncreasePerSecond", 1, (other and (other.coolingType == 1 or other.coolingType == 2)))
            tooltip:addLine(line)

            -- empty line
            tooltip:addLine(TooltipLine(8, 8))
        end
    end


    -- damage type
    if obj.damageType ~= DamageType.None then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Damage Type"%_t
        line.rtext = getDamageTypeName(obj.damageType)
        line.rcolor = getDamageTypeColor(obj.damageType)
        line.lcolor = getDamageTypeColor(obj.damageType)
        line.icon = getDamageTypeIcon(obj.damageType)
        line.iconColor = getDamageTypeColor(obj.damageType)
        tooltip:addLine(line)

        local ltext, rtext
        if obj.damageType == DamageType.AntiMatter then
            ltext = "More damage vs /* Increased damage against Hull */"%_t
            rtext = "Hull /* Increased damage against Hull */"%_t
        elseif obj.damageType == DamageType.Plasma then
            ltext = "More damage vs /* Increased damage against Shields */"%_t
            rtext = "Shields  /* Increased damage against Shields */"%_t
        elseif obj.damageType == DamageType.Fragments then
            ltext = "More damage vs /* Increased damage against Fighters, Torpedoes */"%_t
            rtext = "Fighters, Torpedoes /* Increased damage against Fighters, Torpedoes */"%_t
        elseif obj.damageType == DamageType.Electric then
            ltext = "No damage vs /* No damage to stone */"%_t
            rtext = "Stone /* No damage to stone */"%_t
        end

        if ltext and rtext then
            local line = TooltipLine(lineHeight, fontSize)
            line.ltext = ltext
            line.rtext = rtext
            line.lcolor = getDamageTypeColor(obj.damageType)
            line.rcolor = getDamageTypeColor(obj.damageType)
            line.icon = "data/textures/icons/screen-impact.png"
            line.iconColor = getDamageTypeColor(obj.damageType)
            tooltip:addLine(line)
        end

        if obj.damageType == DamageType.Electric then
            local line = TooltipLine(lineHeight, fontSize)
            line.ltext = "x2 damage vs /* Double damage to Technical Blocks */"%_t
            line.rtext = "Technical Blocks /* Double damage to Technical Blocks */"%_t
            line.lcolor = getDamageTypeColor(obj.damageType)
            line.rcolor = getDamageTypeColor(obj.damageType)
            line.icon = "data/textures/icons/screen-impact.png"
            line.iconColor = getDamageTypeColor(obj.damageType)
            tooltip:addLine(line)
        end

        -- empty line
        tooltip:addLine(TooltipLine(8, 8))
    end

end

local function fillDescriptions(obj, tooltip, additional)

    -- now count the lines, as there will have to be lines inserted
    -- to make sure that the icon of the weapon won't overlap with the stats
    local extraLines = 0
    local fontSize = 13
    local lineHeight = 18
    additional = additional or {}

    local descriptions = obj:getDescriptions()

    if obj.coolingType == CoolingType.BatteryCharge then
        table.insert(additional, "Battery Charge"%_t)
    else
        if obj.shotsUntilOverheated > 0 then
            if obj.shootingTime > 2 then
                table.insert(additional, "Overheats"%_t)
            else
                table.insert(additional, "Burst Fire"%_t)
            end
        end
    end

    if obj.seeker then
        table.insert(additional, "Seeker Shots"%_t)
    end

    if obj.shieldDamageMultiplier == 0 then
        table.insert(additional, "No Damage to Shields"%_t)
    end
    if obj.shieldDamageMultiplier > 1 then
        table.insert(additional, "${bonus} Damage to Shields"%_t % {bonus = string.format("%+i%%", (obj.shieldDamageMultiplier - 1) * 100)})
    end
    if obj.hullDamageMultiplier > 1 then
        table.insert(additional, "${bonus} Damage to Hull"%_t % {bonus = string.format("%+i%%", (obj.hullDamageMultiplier - 1) * 100)})
    end

    if obj.metalRawEfficiency > 0 then
        table.insert(additional, "Breaks Alloys down into Scrap Metal"%_t)
    end

    if obj.stoneRawEfficiency > 0 then
        table.insert(additional, "Breaks Stone down into Ores"%_t)
    end

    if obj.stoneRefinedEfficiency > 0 then
        table.insert(additional, "Refines Stone into Resources"%_t)
    end
    if obj.metalRefinedEfficiency > 0 then
        table.insert(additional, "Refines Alloys into Resources"%_t)
    end


    for desc, value in pairs(descriptions) do
        local line = TooltipLine(lineHeight, fontSize)

        if value == "" then
            line.ltext = desc % _t
        else
            line.ltext = string.format(desc % _t, value)
        end

        local existsAlready
        for _, desc in pairs(additional) do
            if desc == line.ltext then
                existsAlready = true
            end
        end

        if not existsAlready then
            tooltip:addLine(line)
            extraLines = extraLines + 1
        end
    end

    for _, text in pairs(additional) do
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = text
        tooltip:addLine(line)
        extraLines = extraLines + 1
    end

    -- one line for flavor text
    local flavorText = obj.flavorText or ""
    if atype(flavorText) == "Format" then
        flavorText = flavorText:translated()
    end

    if flavorText ~= "" then
        tooltip:addLine(TooltipLine(15, 15))

        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = flavorText
        line.lcolor = ColorRGB(1.0, 0.5, 0.5)
        tooltip:addLine(line)

        extraLines = extraLines + 1
    end


    for i = 1, 4 - extraLines do
        -- empty line
        tooltip:addLine(TooltipLine(15, 15))
    end

end

function makeTurretTitle(turret)
    local title = ""
    if turret.title then
        title = turret.title:translated()
    end

    if title == "" then
        local weapon = turret.weaponPrefix .. " /* Weapon Prefix*/"
        weapon = weapon % _t

        local tbl = {material = turret.material.name, weaponPrefix = weapon}

        if turret.stoneRefinedEfficiency > 0 or turret.metalRefinedEfficiency > 0
            or turret.stoneRawEfficiency > 0 or turret.metalRawEfficiency > 0  then

            if turret.itemType == InventoryItemType.Turret then
                -- turret
                if turret.numVisibleWeapons == 1 then
                    title = "${material} ${weaponPrefix} Turret"%_t % tbl
                elseif turret.numVisibleWeapons == 2 then
                    title = "Double ${material} ${weaponPrefix} Turret"%_t % tbl
                elseif turret.numVisibleWeapons == 3 then
                    title = "Triple ${material} ${weaponPrefix} Turret"%_t % tbl
                elseif turret.numVisibleWeapons == 4 then
                    title = "Quad ${material} ${weaponPrefix} Turret"%_t % tbl
                else
                    title = "Multi ${material} ${weaponPrefix} Turret"%_t % tbl
                end

            else
                -- turret template
                if turret.numVisibleWeapons == 1 then
                    title = "${material} ${weaponPrefix} Blueprint"%_t % tbl
                elseif turret.numVisibleWeapons == 2 then
                    title = "Double ${material} ${weaponPrefix} Blueprint"%_t % tbl
                elseif turret.numVisibleWeapons == 3 then
                    title = "Triple ${material} ${weaponPrefix} Blueprint"%_t % tbl
                elseif turret.numVisibleWeapons == 4 then
                    title = "Quad ${material} ${weaponPrefix} Blueprint"%_t % tbl
                else
                    title = "Multi ${material} ${weaponPrefix} Blueprint"%_t % tbl
                end
            end

        elseif turret.coaxial then
            if turret.itemType == InventoryItemType.Turret then
                -- turret
                if turret.numVisibleWeapons == 1 then
                    title = "Coaxial ${weaponPrefix}"%_t % tbl
                elseif turret.numVisibleWeapons == 2 then
                    title = "Double Coaxial ${weaponPrefix}"%_t % tbl
                elseif turret.numVisibleWeapons == 3 then
                    title = "Triple Coaxial ${weaponPrefix}"%_t % tbl
                elseif turret.numVisibleWeapons == 4 then
                    title = "Quad Coaxial ${weaponPrefix}"%_t % tbl
                else
                    title = "Coaxial Multi ${weaponPrefix}"%_t % tbl
                end

            else
                -- turret template
                if turret.numVisibleWeapons == 1 then
                    title = "Coaxial ${weaponPrefix} Blueprint"%_t % tbl
                elseif turret.numVisibleWeapons == 2 then
                    title = "Double Coaxial ${weaponPrefix} Blueprint"%_t % tbl
                elseif turret.numVisibleWeapons == 3 then
                    title = "Triple Coaxial ${weaponPrefix} Blueprint"%_t % tbl
                elseif turret.numVisibleWeapons == 4 then
                    title = "Quad Coaxial ${weaponPrefix} Blueprint"%_t % tbl
                else
                    title = "Coaxial Multi ${weaponPrefix} Blueprint"%_t % tbl
                end
            end

        else
            if turret.itemType == InventoryItemType.Turret then
                -- turret
                if turret.numVisibleWeapons == 1 then
                    title = "${weaponPrefix} Turret"%_t % tbl
                elseif turret.numVisibleWeapons == 2 then
                    title = "Double ${weaponPrefix} Turret"%_t % tbl
                elseif turret.numVisibleWeapons == 3 then
                    title = "Triple ${weaponPrefix} Turret"%_t % tbl
                elseif turret.numVisibleWeapons == 4 then
                    title = "Quad ${weaponPrefix} Turret"%_t % tbl
                else
                    title = "Multi ${weaponPrefix} Turret"%_t % tbl
                end

            else
                -- turret template
                if turret.numVisibleWeapons == 1 then
                    title = "${weaponPrefix} Blueprint"%_t % tbl
                elseif turret.numVisibleWeapons == 2 then
                    title = "Double ${weaponPrefix} Blueprint"%_t % tbl
                elseif turret.numVisibleWeapons == 3 then
                    title = "Triple ${weaponPrefix} Blueprint"%_t % tbl
                elseif turret.numVisibleWeapons == 4 then
                    title = "Quad ${weaponPrefix} Blueprint"%_t % tbl
                else
                    title = "Multi ${weaponPrefix} Blueprint"%_t % tbl
                end
            end
        end
    end

    return title
end

function makeTurretTooltip(turret, other, tooltipType)
    local tooltip = Tooltip()
    tooltipType = tooltipType or TooltipType.Short

    -- create tooltip
    tooltip.icon = turret.weaponIcon
    tooltip.price = ArmedObjectPrice(turret) * 0.25 -- must be adjusted in shop.lua as well!
    tooltip.rarity = turret.rarity

    -- head line
    local line = TooltipLine(headLineSize, headLineFont)
    line.ctext = makeTurretTitle(turret)
    line.ccolor = turret.rarity.tooltipFontColor
    tooltip:addLine(line)

    local fontSize = 13
    local lineHeight = 16

    fillWeaponTooltipData(turret, tooltip, other, WeaponObjectType.Turret, tooltipType)

    if tooltipType == TooltipType.Verbose then
        -- size
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Size"%_t
        line.rtext = round(turret.size, 1)
        line.icon = "data/textures/icons/shotgun.png";
        line.iconColor = iconColor
        applyLessBetter(line, turret, other, "size", 1)
        tooltip:addLine(line)
    end

    if tooltipType == TooltipType.Verbose or turret.slots ~= 1 then
        -- slots
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Slots"%_t
        line.rtext = round(turret.slots, 1)
        line.icon = "data/textures/icons/small-square.png";
        line.iconColor = iconColor
        applyLessBetter(line, turret, other, "slots", 1)
        tooltip:addLine(line)
    end

    -- slot type
    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Slot Type"%_t
    if turret.slotType == TurretSlotType.Armed then
        line.rtext = "ARMED"%_t
    elseif turret.slotType == TurretSlotType.Unarmed then
        line.rtext = "UNARMED"%_t
    elseif turret.slotType == TurretSlotType.PointDefense then
        line.rtext = "DEFENSIVE"%_t
    else
        line.rtext = "ARMED"%_t
    end
    line.icon = "data/textures/icons/small-square.png";
    line.iconColor = iconColor
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(8, 8))

    -- automatic/independent firing
    if turret.slotType == TurretSlotType.PointDefense then
        local line = TooltipLine(lineHeight, fontSize + 1)
        line.ltext = "Auto-Targeting"%_t
        line.lcolor = ColorRGB(0.4, 0.9, 0.9)
        line.icon = "data/textures/icons/cog.png";
        line.iconColor = iconColor
        tooltip:addLine(line)

        -- empty line
        tooltip:addLine(TooltipLine(8, 8))
    end

    -- Refinement
    if turret.stoneRefinedEfficiency > 0 or turret.metalRefinedEfficiency > 0 then
        local line = TooltipLine(lineHeight, fontSize + 1)
        line.ltext = "Refinement"%_t
        line.lcolor = ColorRGB(0.4, 0.9, 0.9)
        line.icon = "data/textures/icons/metal-bar.png";
        line.iconColor = iconColor
        tooltip:addLine(line)

        -- empty line
        tooltip:addLine(TooltipLine(8, 8))
    end

    -- coaxial weaponry
    if turret.coaxial then
        local line = TooltipLine(lineHeight, fontSize + 1)
        line.ltext = "Coaxial Weapon"%_t
        line.lcolor = ColorRGB(0.4, 0.9, 0.9)
        line.icon = "data/textures/icons/cog.png";
        line.iconColor = iconColor
        tooltip:addLine(line)

        -- empty line
        tooltip:addLine(TooltipLine(8, 8))
    end

    -- crew requirements
    local crew = turret:getCrew()

    for profession, amount in pairs(crew:getNumMembersByProfession()) do
        if amount > 0 then
            local line = TooltipLine(lineHeight, fontSize)
            line.ltext = profession:name()
            line.rtext = round(amount)
            line.icon = profession.icon;
            line.iconColor = profession.color
            tooltip:addLine(line)

        end
    end

    -- empty line
    tooltip:addLine(TooltipLine(8, 8))

    local description = {}
    fillDescriptions(turret, tooltip, description)

    replaceTooltipFactionNames(tooltip)
    return tooltip
end

function makeFighterTooltip(fighter, other, tooltipType)

    -- create tool tip
    local tooltip = Tooltip()
    tooltip.rarity = fighter.rarity

    -- title
    local title

    local tbl = {weaponPrefix = (fighter.weaponPrefix .. " /* Weapon Prefix*/") % _t}

    if fighter.type == FighterType.Fighter then
        title = "${weaponPrefix} Fighter"%_t % tbl
        tooltip.icon = fighter.weaponIcon
    elseif fighter.type == FighterType.CrewShuttle then
        title = "Boarding Shuttle"%_t
        tooltip.icon = "data/textures/icons/crew.png"
    end

    local line = TooltipLine(headLineSize, headLineFont)
    line.ctext = title
    line.ccolor = fighter.rarity.tooltipFontColor
    tooltip:addLine(line)

    -- primary stats, one by one
    local fontSize = 13
    local lineHeight = 16

    if fighter.type == FighterType.Fighter then
        fillWeaponTooltipData(fighter, tooltip, other, WeaponObjectType.Fighter, tooltipType)
    end
    -- empty line
    tooltip:addLine(TooltipLine(8, 8))

    -- size
    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Size"%_t
    line.rtext = round(fighter.volume)
    line.icon = "data/textures/icons/fighter.png";
    line.iconColor = iconColor
    applyLessBetter(line, fighter, other, "volume", 0, (other))
    tooltip:addLine(line)

    -- durability
    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Durability"%_t
    line.rtext = round(fighter.durability)
    line.icon = "data/textures/icons/health-normal.png";
    line.iconColor = iconColor
    applyMoreBetter(line, fighter, other, "durability", 0, (other))
    tooltip:addLine(line)

    if fighter.shield > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Shield"%_t
        line.rtext = round(fighter.shield)
        line.icon = "data/textures/icons/health-normal.png";
        line.iconColor = iconColor
        applyMoreBetter(line, fighter, other, "shield", 0, (other and other.shield > 0))
        tooltip:addLine(line)
    end

    -- maneuverability
    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Maneuverability"%_t
    line.rtext = round(fighter.turningSpeed, 2)
    line.icon = "data/textures/icons/dodge.png";
    line.iconColor = iconColor
    applyMoreBetter(line, fighter, other, "turningSpeed", 2, (other))
    tooltip:addLine(line)

    -- velocity
    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Speed"%_t
    line.rtext = round(fighter.maxVelocity * 10.0)
    line.icon = "data/textures/icons/speedometer.png";
    line.iconColor = iconColor
    applyMoreBetter(line, fighter, other, "maxVelocity", 1, (other))
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(8, 8))

    local time = FighterUT.getProductionTime(fighter.averageTech, fighter.material, fighter.durability)
    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Prod. Time"%_t
    line.rtext = createReadableShortTimeString(time)
    line.icon = "data/textures/icons/cog.png";
    line.iconColor = iconColor

    local a = {time = FighterUT.getProductionTime(fighter.averageTech, fighter.material, fighter.durability)}
    local b = nil
    if other then b = {time = FighterUT.getProductionTime(other.averageTech, other.material, other.durability)} end

    applyLessBetter(line, a, b, "time", nil, (other))
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(8, 8))

    -- crew requirements
    local pilot = CrewProfession(CrewProfessionType.Pilot)

    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = pilot:name()
    line.rtext = 1
    line.icon = pilot.icon
    line.iconColor = iconColor
    tooltip:addLine(line)


    -- empty line
    tooltip:addLine(TooltipLine(8, 8))

    fillDescriptions(fighter, tooltip)

    replaceTooltipFactionNames(tooltip)
    return tooltip
end

function makeTorpedoTooltip(torpedo, other)
    -- create tool tip
    local tooltip = Tooltip()
    tooltip.icon = torpedo.icon
    tooltip.rarity = torpedo.rarity

    -- title
    local title

    local line = TooltipLine(headLineSize, headLineFont)
    line.ctext = torpedo.name%_t % {warhead = torpedo.warheadClass%_t, speed = torpedo.bodyClass%_t}
    line.ccolor = torpedo.rarity.tooltipFontColor
    tooltip:addLine(line)

    -- primary stats, one by one
    local fontSize = 13
    local lineHeight = 16

    -- rarity name
    local line = TooltipLine(5, 12)
    line.ctext = string.upper(tostring(torpedo.rarity))
    line.ccolor = torpedo.rarity.tooltipFontColor
    tooltip:addLine(line)

    -- primary stats, one by one
    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Tech"%_t
    line.rtext = torpedo.tech
    line.icon = "data/textures/icons/circuitry.png";
    line.iconColor = iconColor
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(8, 8))

    if torpedo.hullDamage > 0 and torpedo.damageVelocityFactor == 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Damage"%_t
        line.rtext = toReadableValue(round(torpedo.hullDamage), "")
        line.icon = "data/textures/icons/screen-impact.png";
        line.iconColor = iconColor
        applyMoreBetter(line, torpedo, other, "hullDamage", 0, (other and other.hullDamage > 0 and other.damageVelocityFactor == 0))
        tooltip:addLine(line)
    elseif torpedo.damageVelocityFactor > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Hull Damage"%_t
        line.rtext = "up to ${damage}"%_t % {damage = toReadableValue(round(torpedo.maxVelocity * torpedo.damageVelocityFactor), "")}
        line.icon = "data/textures/icons/screen-impact.png";
        line.iconColor = iconColor

        local a = {damage = round(torpedo.maxVelocity * torpedo.damageVelocityFactor)}
        local b = {}
        if other then b.damage = round(other.maxVelocity * other.damageVelocityFactor) end

        applyMoreBetter(line, a, b, "damage", nil, (other and not (other.hullDamage > 0 and other.damageVelocityFactor == 0) and other.damageVelocityFactor > 0))
        tooltip:addLine(line)
    end

    if torpedo.shieldDamage > 0 and torpedo.shieldDamage ~= torpedo.hullDamage then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Shield Damage"%_t
        line.rtext = toReadableValue(round(torpedo.shieldDamage), "")
        line.icon = "data/textures/icons/screen-impact.png";
        line.iconColor = iconColor
        applyMoreBetter(line, torpedo, other, "shieldDamage", 0, (other and other.shieldDamage > 0 and other.shieldDamage ~= other.hullDamage))
        tooltip:addLine(line)
    end

    -- empty line
    tooltip:addLine(TooltipLine(8, 8))

    -- damage type
    if torpedo.damageType ~= DamageType.None then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Damage Type"%_t
        line.rtext = getDamageTypeName(torpedo.damageType)
        line.rcolor = getDamageTypeColor(torpedo.damageType)
        line.lcolor = getDamageTypeColor(torpedo.damageType)
        line.icon = getDamageTypeIcon(torpedo.damageType)
        line.iconColor = getDamageTypeColor(torpedo.damageType)
        tooltip:addLine(line)

        -- empty line
        tooltip:addLine(TooltipLine(8, 8))
    end

    -- maneuverability
    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Maneuverability"%_t
    line.rtext = round(torpedo.turningSpeed, 2)
    line.icon = "data/textures/icons/dodge.png";
    line.iconColor = iconColor
    applyMoreBetter(line, torpedo, other, "turningSpeed", 2, (other))
    tooltip:addLine(line)

    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Speed"%_t
    line.rtext = round(torpedo.maxVelocity * 10.0)
    line.icon = "data/textures/icons/speedometer.png";
    line.iconColor = iconColor
    applyMoreBetter(line, torpedo, other, "maxVelocity", 1, (other))
    tooltip:addLine(line)

    if torpedo.acceleration > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Acceleration"%_t
        line.rtext = round(torpedo.acceleration * 10.0)
        line.icon = "data/textures/icons/acceleration.png";
        line.iconColor = iconColor
        applyMoreBetter(line, torpedo, other, "acceleration", 1, (other and other.acceleration > 0))
        tooltip:addLine(line)
    end

    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Range"%_t
    line.rtext = "${range} km" % {range = round(torpedo.reach * 10 / 1000, 2)}
    line.icon = "data/textures/icons/target-shot.png";
    line.iconColor = iconColor
    applyMoreBetter(line, torpedo, other, "reach", 1, (other))
    tooltip:addLine(line)

    if torpedo.storageEnergyDrain > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Storage Energy"%_t
        line.rtext = toReadableValue(round(torpedo.storageEnergyDrain), "W")
        line.icon = "data/textures/icons/electric.png";
        line.iconColor = iconColor
        applyLessBetter(line, torpedo, other, "storageEnergyDrain", 0, (other))
        tooltip:addLine(line)
    end

    -- empty line
    tooltip:addLine(TooltipLine(8, 8))

    -- size
    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Size"%_t
    line.rtext = round(torpedo.size, 1)
    line.icon = "data/textures/icons/missile-pod.png";
    line.iconColor = iconColor
    applyLessBetter(line, torpedo, other, "size", 1, (other))
    tooltip:addLine(line)

    -- durability
    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Durability"%_t
    line.rtext = round(torpedo.durability)
    line.icon = "data/textures/icons/health-normal.png";
    line.iconColor = iconColor
    applyMoreBetter(line, torpedo, other, "durability", 0, (other))
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(8, 8))
    tooltip:addLine(TooltipLine(8, 8))

    -- specialties
    local extraLines = 0

    if torpedo.damageVelocityFactor > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Damage Dependent on Velocity"%_t
        tooltip:addLine(line)

        extraLines = extraLines + 1
    end

    if torpedo.shieldDeactivation then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Briefly Deactivates Shields"%_t
        tooltip:addLine(line)

        extraLines = extraLines + 1
    end

    if torpedo.energyDrain then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Drains Target's Energy"%_t
        tooltip:addLine(line)

        extraLines = extraLines + 1
    end

    if torpedo.shieldPenetration then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Penetrates Shields"%_t
        tooltip:addLine(line)

        extraLines = extraLines + 1
    end

    if torpedo.shieldAndHullDamage then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Damages Both Shield and Hull"%_t
        tooltip:addLine(line)

        extraLines = extraLines + 1
    end

    if torpedo.storageEnergyDrain > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Requires Energy in Storage"%_t
        tooltip:addLine(line)

        extraLines = extraLines + 1
    end

    for i = 1, 3 - extraLines do
        -- empty line
        tooltip:addLine(TooltipLine(8, 8))
    end

    replaceTooltipFactionNames(tooltip)
    return tooltip
end



function makeVanillaItemTooltip(item)
    local tooltip = item:getTooltip()
    replaceTooltipFactionNames(tooltip)
    return tooltip
end

function makeUsableItemTooltip(item)
    local tooltip = item:getTooltip()
    replaceTooltipFactionNames(tooltip)
    return tooltip
end
