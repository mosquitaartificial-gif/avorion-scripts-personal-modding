
function getAmountsOnShip(craft, tag)
    local amountsOnShip = {}
    local totalAmount = 0
    for i = 1, NumMaterials() do
        amountsOnShip[i] = 0
    end

    for good, amount in pairs(craft:getCargos()) do
        if not good.stolen then
            local tags = good.tags

            if tags[tag] and not tags.rich then
                for i = 1, NumMaterials() do
                    local material = Material(i - 1)
                    if tags[material.tag] then
                        amountsOnShip[i] = amount
                        totalAmount = totalAmount + amount
                    end
                end
            end
        end
    end

    return amountsOnShip, totalAmount
end

function getOreAmountsOnShip(craft)
    return getAmountsOnShip(craft, "ore")
end

function getScrapAmountsOnShip(craft)
    return getAmountsOnShip(craft, "scrap")
end

function getRiftOreAmountsOnShip(craft)
    local amountsOnShip = {}
    local totalAmount = 0
    for i = 1, NumMaterials() do
        amountsOnShip[i] = 0
    end

    for good, amount in pairs(craft:getCargos()) do
        if not good.stolen then
            local tags = good.tags

            if tags.ore and tags.rich then
                for i = 1, NumMaterials() do
                    local material = Material(i - 1)
                    if tags[material.tag] then
                        amountsOnShip[i] = amount
                        totalAmount = totalAmount + amount
                    end
                end
            end
        end
    end

    return amountsOnShip, totalAmount
end
