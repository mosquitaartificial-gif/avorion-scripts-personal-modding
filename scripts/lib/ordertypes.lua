package.path = package.path .. ";data/scripts/lib/?.lua"

include ("stringutility")

OrderType =
{
    Jump = 1,
    Mine = 2,
    Salvage = 3,
    Loop = 4,
    Aggressive = 5,
    Patrol = 6,
    -- BuyGoods = 7, -- replaced by procure/sell map commands
    -- SellGoods = 8,

    Escort = 9,
    AttackCraft = 10,
    FlyThroughWormhole = 11,
    FlyToPosition = 12,
    GuardPosition = 13,
    RefineOres = 14,
    Board = 15,
    RepairTarget = 16,
    Repair = 17,
    -- Stop = 18, -- this is not a real command and is only listed for completeness
    DockToStation = 19,

    NumActions = 19,
}

OrderTypes = {}

OrderTypes[OrderType.Jump] = {
    name = "Jump /* short order summary */"%_t,
}
OrderTypes[OrderType.Loop] = {
    name = "Loop /* short order summary */"%_t,
    icon = "data/textures/icons/loop.png",
    pixelIcon = "data/textures/icons/pixel/loop.png",
}
OrderTypes[OrderType.Mine] = {
    name = "Mine /* short order summary */"%_t,
    icon = "data/textures/icons/mining.png",
    pixelIcon = "data/textures/icons/pixel/mining.png",
}
OrderTypes[OrderType.Salvage] = {
    name = "Salvage /* short order summary */"%_t,
    icon = "data/textures/icons/scrap-metal.png",
    pixelIcon = "data/textures/icons/pixel/salvaging.png",
}
OrderTypes[OrderType.Aggressive] = {
    name = "Aggressive /* short order summary */"%_t,
    icon = "data/textures/icons/crossed-rifles.png",
    pixelIcon = "data/textures/icons/pixel/attacking.png",
}
OrderTypes[OrderType.Patrol] = {
    name = "Patrol /* short order summary */"%_t,
    icon = "data/textures/icons/patrol.png",
    pixelIcon = "data/textures/icons/pixel/patrol.png",
}

OrderTypes[OrderType.Escort] = {
    name = "Escort /* short order summary */"%_t,
    icon = "data/textures/icons/escort.png",
    pixelIcon = "data/textures/icons/pixel/escort.png",
    color = {r = 64, g = 192, b = 64}
}
OrderTypes[OrderType.AttackCraft] = {
    name = "Attack /* short order summary */"%_t,
    icon = "data/textures/icons/attack.png",
    pixelIcon = "data/textures/icons/pixel/attacking.png",
    color = {r = 192, g = 64, b = 64}
}
OrderTypes[OrderType.FlyThroughWormhole] = {
    name = "Fly Through /* short order summary */"%_t,
    icon = "data/textures/icons/vortex.png",
    pixelIcon = "data/textures/icons/pixel/gate.png",
    color = {r = 64, g = 64, b = 192}
}
OrderTypes[OrderType.FlyToPosition] = {
    name = "Fly to Position /* short order summary */"%_t,
    icon = "data/textures/icons/position-marker.png",
    pixelIcon = "data/textures/icons/pixel/flytoposition.png",
    color = {r = 64, g = 192, b = 64}
}
OrderTypes[OrderType.GuardPosition] = {
    name = "Guard /* short order summary */"%_t,
    icon = "data/textures/icons/shield.png",
    pixelIcon = "data/textures/icons/pixel/guard.png",
    color = {r = 192, g = 192, b = 64}
}
OrderTypes[OrderType.RefineOres] = {
    name = "Refine Ores /* short order summary */"%_t,
    icon = "data/textures/icons/metal-bar.png",
    pixelIcon = "data/textures/icons/pixel/refine.png",
}
OrderTypes[OrderType.Board] = {
    name = "Board /* short order summary */"%_t,
    icon = "data/textures/icons/bolter-gun.png",
    pixelIcon = "data/textures/icons/pixel/boarding.png",
}
OrderTypes[OrderType.RepairTarget] = {
    name = "Repair Target /* short order summary */"%_t,
    icon = "data/textures/icons/health-normal.png",
    pixelIcon = "data/textures/icons/pixel/repair.png",
    color = {r = 192, g = 192, b = 64}
}
OrderTypes[OrderType.Repair] = {
    name = "Repair /* short order summary */"%_t,
    icon = "data/textures/icons/health-normal.png",
    pixelIcon = "data/textures/icons/pixel/repair.png",
}
OrderTypes[OrderType.DockToStation] = {
    name = "Dock /* short order summary */"%_t,
    icon = "data/textures/icons/position-marker.png",
    pixelIcon = "data/textures/icons/pixel/flytoposition.png",
}

return OrderTypes
