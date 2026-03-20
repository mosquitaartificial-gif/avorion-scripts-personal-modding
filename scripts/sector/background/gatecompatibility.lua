package.path = package.path .. ";data/scripts/lib/?.lua"

local SectorGenerator = include ("SectorGenerator")


-- this script deletes old-style gates and regenerates them so that the gate network doesn't get broken through the 2.0 update
if onServer() then

function update()
    terminate()

    local sector = Sector()
    if sector:getValue("gates2.0") then return end
    -- there is no need to set the value, will be set through createGates()

    -- delete all gates
    local gates = {sector:getEntitiesByScript("data/scripts/entity/gate.lua")}
    for _, gate in pairs(gates) do
        sector:deleteEntity(gate)
    end

    -- recreate gates
    local x, y = sector:getCoordinates()
    local generator = SectorGenerator(x, y)

    generator:createGates() -- sets the "gates2.0" value
end

end
