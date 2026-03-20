package.path = package.path .. ";data/scripts/lib/?.lua;data/scripts/entity/merchants/?.lua"

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace TurretFactorySeller
TurretFactorySeller = include ("seller")

TurretFactorySeller.customSellPriceFactor = 3.0
