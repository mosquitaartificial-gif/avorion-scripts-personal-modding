
local ConsumerGoods = {}

function ConsumerGoods.Habitat()
    return {
        "Beer",
        "Wine",
        "Liquor",
        "Food",
        "Tea",
        "Leather",
        "Spices",
        "Gem",
        "Fruit",
        "Cocoa",
        "Coffee",
        "Wood",
        "Meat",
        "Water",
        "Fish",
        "Book"
    }
end

function ConsumerGoods.Biotope()
    return {
        "Food",
        "Food Bar",
        "Fungus",
        "Wood",
        "Glass",
        "Sheep",
        "Cattle",
        "Wheat",
        "Corn",
        "Rice",
        "Vegetable",
        "Water",
        "Coal",
        "Plant",
        "Fish"
    }
end

function ConsumerGoods.Casino()
    return {
        "Beer",
        "Wine",
        "Liquor",
        "Food",
        "Luxury Food",
        "Water",
        "Gem",
        "Medical Supplies"
    }
end

function ConsumerGoods.EquipmentDock()
    return {
        "Fuel",
        "Rocket",
        "Tools",
        "Laser Compressor",
        "Laser Head",
        "Fusion Core",
        "Warhead",
        "Satellite",
        "Drone",
        "Antigrav Generator",
        "Ammunition",
        "Ammunition S",
        "Ammunition M",
        "Ammunition L",
    }
end

function ConsumerGoods.Shipyard()
    return {
        "Energy Tube",
        "Aluminum",
        "Display",
        "Metal Plate",
        "Fusion Core",
        "Computation Mainframe",
        "Medical Supplies",
        "Industrial Tesla Coil",
        "Antigrav Generator",
        "Turbine",
        "Energy Container",
    }
end

function ConsumerGoods.RepairDock()
    return {
        "Fuel",
        "Steel",
        "Wire",
        "Metal Plate",
        "Nanobot",
        "Solar Cell",
        "Solar Panel",
        "Oxygen",
        "Force Generator",
        "Medical Supplies",
    }
end

function ConsumerGoods.MilitaryOutpost()
    return {
        "War Robot",
        "Body Armor",
        "Vehicle",
        "Gun",
        "Ammunition",
        "Ammunition S",
        "Ammunition M",
        "Ammunition L",
        "Medical Supplies",
        "Explosive Charge",
        "Electromagnetic Charge",
        "Food Bar",
        "Targeting System",
        "Military Tesla Coil"
    }
end

function ConsumerGoods.ResearchStation()
    return {
        "Turbine",
        "High Capacity Lens",
        "Neutron Accelerator",
        "Electron Accelerator",
        "Proton Accelerator",
        "Fusion Generator",
        "Antigrav Generator",
        "Force Generator",
        "Teleporter",
        "Drill",
        "Satellite"
    }
end

function ConsumerGoods.RiftResearchStation()
    return {
        "Rift Research Data",
        "Turbine",
        "High Capacity Lens",
        "Neutron Accelerator",
        "Electron Accelerator",
        "Proton Accelerator",
        "Fusion Generator",
        "Antigrav Generator",
        "Force Generator",
        "Teleporter",
        "Drill",
        "Satellite"
    }
end

function ConsumerGoods.TravelHub()
    return {
        "Turbine",
        "Neutron Accelerator",
        "Electron Accelerator",
        "Proton Accelerator",
        "Fusion Generator",
        "Force Generator",
        "Plasma Cell",
        "Energy Cell",
        "Fusion Core",
    }
end

function ConsumerGoods.Mine()
    return {
        "Mining Robot",
        "Medical Supplies",
        "Antigrav Unit",
        "Fusion Generator",
        "Acid",
        "Solvent",
        "Drill"
    }
end

function ConsumerGoods.TurretFactory()
    local goods =
    {
        "Servo", "Steel Tube", "Ammunition S", "Steel", "Aluminum", "Lead",
        "Servo", "High Pressure Tube", "Ammunition M", "Explosive Charge", "Steel", "Aluminum",
        "Laser Head", "Laser Compressor", "High Capacity Lens", "Laser Modulator", "Steel", "Crystal",
        "Plasma Cell", "Energy Tube", "Conductor", "Energy Container", "Steel", "Crystal",
        "Servo", "Warhead", "High Pressure Tube", "Explosive Charge", "Steel", "Wire",
        "Servo", "Rocket", "High Pressure Tube", "Fuel", "Targeting Card", "Steel", "Wire",
        "Servo", "Electromagnetic Charge", "Electro Magnet", "Gauss Rail", "High Pressure Tube", "Steel", "Copper",
        "Nanobot", "Transformator", "Laser Modulator", "Conductor", "Gold",  "Steel",
        "Laser Compressor", "Laser Modulator", "High Capacity Lens", "Conductor", "Steel",
        "Laser Compressor", "Laser Modulator", "High Capacity Lens",  "Conductor", "Steel",
        "Force Generator", "Energy Inverter", "Energy Tube", "Conductor", "Steel", "Zinc",
        "Industrial Tesla Coil", "Electromagnetic Charge", "Energy Inverter", "Conductor", "Copper", "Energy Cell",
        "Military Tesla Coil", "High Capacity Lens", "Electromagnetic Charge", "Conductor", "Copper", "Energy Cell",
    }

    local selected = {}
    for i = 1, 25 do
        selected[randomEntry(random(), goods)] = true

        if tablelength(selected) == 15 then break end
    end

    local used = {}

    for good, _ in pairs(selected) do
        table.insert(used, good)
    end

    return used
end


return ConsumerGoods
