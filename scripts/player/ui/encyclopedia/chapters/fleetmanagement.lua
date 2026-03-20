package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/encyclopedia/lib/?.lua"
package.path = package.path .. ";data/scripts/encyclopedia/?.lua"
include ("stringutility")
include ("contents")

Categories = Categories or {}
category = {}

table.insert(Categories, category)

category.title = "Fleet Management"%_t
category.chapters =
{
    {
        title = "Captains"%_t,
        picture = "data/textures/ui/encyclopedia/fleetmanagement/hireCaptain.jpg",
        text = "You can assign \\c(0d0)Captains\\c() on your ships, either to command a ship of yours while it is in a different sector, or to profit from your captain's experience while you're still in control of your ship yourself."%_t
        .. "\n\n" .. "All captains have different character traits, which they can improve by gaining \\c(0d0)experience\\c() while on commands and thereby \\c(0d0)leveling up\\c()."%_t
        .. " " .. "When captains level up, the impact of their perks will be increased while their quirks will have less of an effect."%_t
        .. " " .. "However, not all captains are equally talented. Each captain can be classified by \\c(0d0)tiers (0 to 3)\\c()."%_t
        .. " " .. "Captains with higher tiers are more experienced and will be more successful when sent to carry out commands, but they do ask for a higher salary."%_t
        .. " " .. "Lower tier captains can be hired at stations while Tier 3 captains have to be found by other means."%_t
        .. " " .. "You might not be the only one looking for them, so keep your eyes open when you are in a civilized sector."%_t,
    },    
    {
        title = "Captain's Classes"%_t,
        articles =
        {
            {
                title = "Tiers"%_t,
                picture = "data/textures/ui/encyclopedia/fleetmanagement/captain.jpg",
                text = "Captains are talented individuals and they can have up to two classes: \\c(0d0)Tier 0\\c() captains don't have a class in the beginning, but they will specialize on a profession once they reach level 5."%_t
                .. "\n\n" .. "\\c(0d0)Tier 1\\c() and \\c(0d0)Tier 2\\c() have one class and \\c(0d0)Tier 3\\c() captains even have two classes."%_t
                .. "\n\n" .. "Read about the individual classes in the next chapters."%_t
            },
            {
                title = "Miners"%_t,
                picture = "data/textures/ui/encyclopedia/fleetmanagement/captainsClasses/miner.jpg",
                text = "\\c(0d0)Miners\\c() are specialists when it comes to the extraction of resources."%_t
                .. " " .. "They can conduct longer mining operations than other captains."%_t
                .. " " .. "They are also more effective at mining resources, which is why they get \\c(0d0)higher yields\\c() from operations."%_t
                .. "\n\n" .. "If they are active on the ship you command, they will \\c(0d0)detect valuable asteroids\\c() from a distance and point them out to you."%_t
                .. " " .. "They can manage two additional \\c(0d0)unarmed turret slots\\c()."%_t
                .. "\n\n" .. "If you're looking to hire Miners check the \\c(0d0)Mines\\c() in the area. Most Miners tend to stick to them."%_t,
            },
            {
                title = "Scavengers"%_t,
                picture = "data/textures/ui/encyclopedia/fleetmanagement/captainsClasses/scavenger.jpg",
                text = "\\c(0d0)Scavengers\\c() specialize in salvaging."%_t
                .. " " .. "They are able to conduct longer salvaging operations than other captains and they achieve \\c(0d0)higher yields\\c() when performing salvaging commands."%_t
                .. "\n\n" .. "If they are active on the ship you command, they will \\c(0d0)spot valuable wrecks\\c() from a distance and point them out to you."%_t
                .. " " .. "They can manage two additional \\c(0d0)unarmed turret slots\\c()."%_t
                .."\n\n" .. "Captains with this specialization are often found at \\c(0d0)Scrapyards\\c(), where they earn their livelihood."%_t,
            },
            {
                title = "Merchants"%_t,
                picture = "data/textures/ui/encyclopedia/fleetmanagement/captainsClasses/merchant.jpg",
                text = "No one knows the intricacies of the market better than a \\c(0d0)merchant\\c()."%_t
                .. " " .. "Through their connections, they are able to handle a wider variety of goods than anyone else."%_t
                .. " " .. "This increases the \\c(0d0)number of goods\\c() they can move on procure and sell operations."%_t
                .. " " .. "They also carry licenses for dangerous and suspicious goods."%_t
                .. "\n\n" .. "If they are active on the ship you command, you will also benefit from their \\c(0d0)licenses."%_t .. "\\c()"
                .."\n\n" .. "While Merchants can be found all over the galaxy, when in doubt try a \\c(0d0)Trading Post\\c(). There might be someone there who is looking for a new job."%_t,
            },
            {
                title = "Smugglers"%_t,
                picture = "data/textures/ui/encyclopedia/fleetmanagement/captainsClasses/smuggler.jpg",
                text = "\\c(0d0)Smugglers\\c() are the best choice for shady deals."%_t
                .. " " .. "They can get rid of goods anywhere, which allows them to move \\c(0d0)more goods\\c() on procure and sell operations."%_t
                .. " " .. "They also have 'licenses' for all goods."%_t
                .. "\n\n" .. "If they are active on the ship you command, you will also benefit from their \\c(0d0)'licenses'\\c()."%_t
                .."\n\n" .. "Smugglers tend to stay away from the more righteous places. So if you want to find one, you should look for \\c(0d0)Smugglers' Markets\\c() and the like."%_t,
            },
            {
                title = "Explorers"%_t,
                picture = "data/textures/ui/encyclopedia/fleetmanagement/captainsClasses/explorer.jpg",
                text = "\\c(0d0)Explorers\\c() always keep their eyes open for unexplored sectors."%_t
                .. " " .. "When they pass \\c(0d0)interesting sectors\\c() while on an operation, they mark them for you."%_t
                .. "\n\n" .. "They can use the latest radar technology, and when active on the ship you command, they reveal sectors with \\c(0d0)hidden mass signatures\\c() (yellow blip) in a bigger radius."%_t
                .."\n\n" .. "Explorers can often be found at \\c(0d0)Research Stations\\c(), where they actively participate in finding new and exiting things. If you want to hire one, you should look there as well."%_t,
            },
            {
                title = "Commodores"%_t,
                picture = "data/textures/ui/encyclopedia/fleetmanagement/captainsClasses/commodore.jpg",
                text = "Because of their military training, \\c(0d0)commodores\\c() have developed a sense for danger."%_t
                .. " " .. "This allows them to better anticipate (and avoid) attacks by pirates or other enemies."%_t
                .. "\n\n" .. "Their combat experience allows them to manage two additional \\c(0d0)armed turret slots\\c() when active on the ship you command."%_t
                .. " " .. "They also increase the number of slots for \\c(0d0)automatic targeting\\c() by four."%_t
                .."\n\n" .. "The best way to find a commodore is to ask at a \\c(0d0)Military Outpost\\c(). Fresh from the academy and all that."%_t,
            },
            {
                title = "Daredevils"%_t,
                picture = "data/textures/ui/encyclopedia/fleetmanagement/captainsClasses/daredevil.jpg",
                text = "\\c(0d0)Daredevils\\c() love a challenge and will find an opportunity to prove themselves everywhere."%_t
                .. " " .. "They often collect trophies in battles, and are happy to \\c(0d0)share their spoils\\c(), such as subsystems or turrets, with their allies."%_t
                .. "\n\n" .. "Their wild nature inspires gunners to shoot faster than usual."%_t
                .. " " .. "The \\c(0d0)fire rate\\c() on your ship increases by 10% while daredevils are active on the ship you command."%_t
                .."\n\n" .. "Daredevils know how to live life. If you're looking for one, look around for \\c(0d0)Casinos\\c() and \\c(0d0)Habitats\\c(), as you'll usually meet them where there are a lot of people."%_t,
            },
            {
                title = "Scientists"%_t,
                picture = "data/textures/ui/encyclopedia/fleetmanagement/captainsClasses/scientist.png",
                text = "\\c(0d0)Scientists\\c() are very interested in researching the \\c(0d0)Rifts\\c()."%_t
                .."\n\n" .. "When they command a ship in a rift, they gather \\c(0d0)Rift Research Data\\c() on their own, up to a certain limit. They also increase the amount of data gathered by destroying Xsotan."%_t
                .. " " .. "An important part of their job is keeping their eyes open for every detail. This allows Scientists to find and highlight Rift Research Data and Scannable Objects in rifts."%_t
                .."\n\n" .. "Scientists value the company of their colleagues. They often stay at \\c(0d0)Rift Research Centers\\c()."%_t,
            },
            {
                title = "Xsotan Hunters"%_t,
                picture = "data/textures/ui/encyclopedia/fleetmanagement/captainsClasses/xsotan-hunter.png",
                text = "\\c(0d0)Xsotan Hunters\\c() are specialists in attracting Xsotan and hunt them with passion."%_t
                .."\n\n" .. "When commanding a ship in \\c(0d0)Rifts\\c(), they attract special, rare Xsotan. It takes some time before the attraction is successful and the hunt can begin."%_t
                .."\n\n" .. "Only those who have many years of experience fighting the Xsotan become Xsotan Hunters. Therefore, they are usually found at \\c(0d0)Resistance Outposts\\c()."%_t,
            },
        },
    },
    {
        title = "Strategy Mode"%_t,
        id = "StrategyMode",
        pictures =
        {
            "data/textures/ui/encyclopedia/fleetmanagement/strategyMode/strategyMode_1.jpg",
            "data/textures/ui/encyclopedia/fleetmanagement/strategyMode/strategyMode_1_red.jpg",
            "data/textures/ui/encyclopedia/fleetmanagement/strategyMode/strategyMode_1_red.jpg",
            "data/textures/ui/encyclopedia/fleetmanagement/strategyMode/strategyMode_2.jpg",
            "data/textures/ui/encyclopedia/fleetmanagement/strategyMode/strategyMode_2.jpg",
        },
        text = "The \\c(0d0)Strategy Mode\\c() allows you to issue commands to ships in your sector."%_t
        .. " " .. "Select a ship or a group of ships and then use the icons at the bottom of the screen to give an order."%_t
        .. "\n\n" .. "All ships and stations in the sector are listed here, and you can see the goods that are being bought and sold, the crew members waiting to be hired and the missions availabe at bulletin boards."%_t
        .. "\n\n" .. "Move the Strategy View by using the \\c(fff)arrow keys\\c() or \\c(fff)[W]\\c(), \\c(fff)[A]\\c(), \\c(fff)[S]\\c(), \\c(fff)[D]\\c(), or by moving \\c(fff)[Left Mouse]\\c() to the edge of your screen (this can be disabled in the settings menu)."%_t
        .. "\n" .. "The Strategy View can be rotated with with \\c(fff)[Right Mouse]\\c(), and you can move through the planes by holding \\c(fff)[Left SHIFT]\\c() and dragging \\c(fff)[Left Mouse]\\c()."%_t,
    },
    {
        title = "Autopilot"%_t,
        picture = "data/textures/ui/encyclopedia/fleetmanagement/autopilot.jpg",
        fps = 2,
        text = "Every ship has an \\c(0d0)Autopilot\\c()."%_t
        .. " " .. "While you are in the same sector as one of your ships, you can tell it to carry out small, single target orders like \\c(fff)attacking\\c() a target, \\c(fff)harvesting\\c() an asteroid, \\c(fff)docking\\c() to a station, \\c(fff)guarding\\c() a spot, or \\c(fff)flying\\c() to a position or through a gate."%_t
        .. "\n\n" .. "You can give those orders by selecting the \\c(0d0)robot icon\\c() at the top right or by opening \\c(0d0)Strategy Mode\\c() and selecting the icons at the bottom of the screen or right clicking a target."%_t
        .. " " .. "You can also interact with the ship by pressing \\c(fff)[${interact}]\\c() and selecting one of the orders there."%_t % {interact=GameInput():getKeyName(ControlAction.Interact)}
        .. "\n" .. "More advanced orders are unavailable if your ship doesn't have a \\c(0d0)Captain\\c().\n\nSee the chapters on \\c(0d0)Galaxy Map Orders\\c() and \\c(0d0)Captain's Commands\\c() for more advanced commands."%_t,
    },
    {
        title = "Galaxy Map Orders"%_t,
        picture = "data/textures/ui/encyclopedia/fleetmanagement/mapCommands.jpg",
        text = "If your ship has a \\c(0d0)Captain\\c() you don't have to stay in the same sector, your captain will carry out commands without you there."%_t
        .. "\n\n" .. "If you want your ship to perform orders that deal with more than one target or that are stretched over multiple sectors, command it via the \\c(0d0)Galaxy Map\\c()."%_t
        .. "\n" .. "Press \\c(fff)[${shift}]\\c() while issuing certain orders to enchain them."%_t % {shift=GameInput():getKeyName(ControlAction.ReleaseMouse)}
        .. " " .. "Here, you can give simple orders like \\c(fff)patrolling\\c() a sector, \\c(fff)attacking\\c() all enemies in a sector, \\c(fff)repairing\\c() all ships in a sector or even just \\c(fff)jumping\\c() to another sector."%_t
        .. "\n\n" .. "To read about even more advanced commands take a look at the chapter on \\c(0d0)Captain's Commands\\c()."%_t,
    },
    {
        title = "Captain's Commands"%_t,
        pictures =
        {
            "data/textures/ui/encyclopedia/fleetmanagement/captainsCommands/commands_1.jpg",
            "data/textures/ui/encyclopedia/fleetmanagement/captainsCommands/commands_1_red.jpg",
            "data/textures/ui/encyclopedia/fleetmanagement/captainsCommands/commands_1_red.jpg",
            "data/textures/ui/encyclopedia/fleetmanagement/captainsCommands/commands_3.jpg",
            "data/textures/ui/encyclopedia/fleetmanagement/captainsCommands/commands_5_red.jpg",
            "data/textures/ui/encyclopedia/fleetmanagement/captainsCommands/commands_5_red.jpg",
            "data/textures/ui/encyclopedia/fleetmanagement/captainsCommands/commands_4.jpg",
            "data/textures/ui/encyclopedia/fleetmanagement/captainsCommands/commands_4_red.jpg",
            "data/textures/ui/encyclopedia/fleetmanagement/captainsCommands/commands_4_red.jpg",
        },
        text = "\\c(0d0)Captains\\c() can carry out very advanced commands on their own."%_t
        .. " " .. "While they are working on a command, they will need full control of the ship and will be unavailable to you."%_t
        .. "\n\n" .. "To assign a command select the ship on the \\c(0d0)Galaxy Map\\c() and choose a command."%_t
        .. "\n" .. "You will be able to specify your orders and tell the captain which area to work in."%_t
        .. "\n\n" .. "The classes, level, tier and character traits of a captain will influence how well the command will be executed."%_t
        .. "\n\n" .. "During most of the commands, the captain acquires money, resources, items or more."%_t
        .. " " .. "Collect those yields in the \\c(0d0)Fleet Tab\\c() of the \\c(0d0)Player Menu\\c()."%_t,
    },
    {
        title = "Founding Stations"%_t,
        pictures =
        {
            "data/textures/ui/encyclopedia/fleetmanagement/foundStation/found1.jpg",
            "data/textures/ui/encyclopedia/fleetmanagement/foundStation/found1.jpg",
            "data/textures/ui/encyclopedia/fleetmanagement/foundStation/found2.jpg",
            "data/textures/ui/encyclopedia/fleetmanagement/foundStation/found2.jpg",
            "data/textures/ui/encyclopedia/fleetmanagement/foundStation/found3_red.jpg",
            "data/textures/ui/encyclopedia/fleetmanagement/foundStation/found3_red.jpg",
            "data/textures/ui/encyclopedia/fleetmanagement/foundStation/found4.jpg",
            "data/textures/ui/encyclopedia/fleetmanagement/foundStation/found4.jpg",
        },
        fps = 2,
        text = "When buying a ship at a \\c(0d0)Shipyard\\c() you can choose to order a \\c(0d0)Station Founder\\c()."%_t
        .. " " .. "With the necessary funds, it can be transformed into a station."%_t
        .. "\n\n" .. "If you build too many stations in a sector controlled by another faction, you will eventually take over the sector and your relations to that faction will suffer."%_t
        .. " " .. "Once transformed, the station will only be able to move if put into \\c(0d0)Transport Mode\\c() and docked to a ship."%_t
        .. "\n\n" .. "Some stations produce, buy and sell trading goods and will make profit over time, so it is important to have those in profitable area where supply and demand are advantageous."%_t
        .. "\n" .. "To find such an area, install a \\c(0d0)Trading Subsystem\\c() on your ship (see section \\c(0d0)Trade\\c() -> \\c(0d0)Trading Subsystem\\c())."%_t,
    },
    {
        title = "Production Chains"%_t,
        picture = "data/textures/ui/encyclopedia/fleetmanagement/cargoShuttle_small.jpg",
        text = "In order to produce goods, most stations need resources."%_t
        .. " " .. "These have to be bought from other stations or traders."%_t
        .. "\n\n" .. "You can also provide goods to your stations by building a production line consisting of multiple stations."%_t
        .. "\n\n" .. "Transport goods between them with \\c(0d0)Cargo Shuttles\\c()!"%_t
        .. " " .. "Configure them in the factory menu to fetch or bring goods to another station in the sector."%_t
        .. "\n\n" .. "You can also \\c(0d0)dock\\c() stations together to speed up goods exchange by 500%!"%_t
        .. " " .. "Docking them together will also make their goods exchange immune to \\c(0d0)Hazard Zones\\c(), since they won't have to rely on shuttles."%_t,
    },
}

contents.outOfSector = category.chapters[1]
contents.Orders = category.chapters[2]
contents.foundingStations = category.chapters[3]
contents.productionChains = category.chapters[4]
