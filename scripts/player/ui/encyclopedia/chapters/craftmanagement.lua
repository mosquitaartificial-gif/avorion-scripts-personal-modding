package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/encyclopedia/lib/?.lua"
package.path = package.path .. ";data/scripts/encyclopedia/?.lua"
include ("stringutility")
include ("contents")
local BlackMarketEncyclopedia = include ("internal/dlc/blackmarket/public/encyclopedia.lua")

Categories = Categories or {}
category = {}

table.insert(Categories, category)

category.title = "Craft Management"%_t
category.chapters =
{
    {
        title = "Crew"%_t,
        articles =
        {
            {
                title = "Crew & Professionals"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/crewTab.jpg",
                text = "A \\c(0d0)crew\\c() is what keeps a ship together."%_t
                .. " " .. "Most of the work on a ship can be done by allrounder crew members, but there are some jobs that can only be done by professionals."%_t
                .. " " .. "Professionals can be \\c(0d0)hired at stations\\c()."%_t
                .. " " .. "Professionals take a higher salary, but studies have shown that they can increase productivity by up to 200%."%_t
                .. " " .. "On top of that, they can also gain experience and level up over time, increasing their productivity."%_t
                .. "\n\n" .. "Some jobs on the ship can be \\c(0d0)overassigned\\c() - that means that you can assign more than the minimum amount of crew to get bonuses for your ship."%_t
                .. "\n\n" .. "The crew has to be \\c(0d0)paid every three hours\\c()."%_t
                .. " " .. "How much each crew member earns is listed in the \\c(0d0)Ship Menu\\c()'s crew tab."%_t,
            },
            {
                title = "Officers"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/officers.jpg",
                text = "In order to keep your crew organized, at some point, you will need \\c(0d0)Officers\\c()."%_t
                .. " " .. "Once the crew of a profession reaches a certain threshold - for example, once you have 5 mechanics - they will need an officer to keep things going smoothly."%_t
                .. "\n\n" .. "Your crew will assign officers automatically."%_t
                .. " " .. "Officers have the same workforce as other crewmembers, but earn a \\c(0d0)higher salary\\c()."%_t
                .. "\n\n" .. "You need a \\c(0d0)Sergeant\\c() for every \\c(0d0)5 crewmembers\\c()."%_t
                .. "\n" .. "You need a \\c(0d0)Lieutenant\\c() for every \\c(0d0)4 sergeants\\c()."%_t
                .. "\n" .. "You need a \\c(0d0)Colonel\\c() for every \\c(0d0)3 lieutenants\\c()."%_t,
            },
            {
                title = "Captains"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/crewTab.jpg",
                text = "Assigning a \\c(0d0)Captain\\c() to your ship allows you to command it remotely over the \\c(0d0)Galaxy Map\\c(). Depending on the captain's \\c(0d0)Class\\c(), they will also grant certain bonuses to your ship.\n\nCaptains will be discussed more in-depth in the \\c(0d0)Fleet Management\\c() section of the encyclopedia."%_t,
            },
            {
                title = "Morale"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/crewTab.jpg",
                text = "Your crew has a \\c(0d0)Morale\\c()."%_t
                .. " " .. "If there are issues on the ship, such as \\c(0d0)not enough crew quarters\\c(), or when the crew didn't get \\c(0d0)paid in time\\c(), morale will drop."%_t
                .. "\n\n" .. "Once morale has dropped to zero, the crew will go on \\c(0d0)Strike\\c(), which drops their workforce to \\c(0d0)Zero\\c()."%_t
                .. " " .. "Once all issues have been resolved, morale will go back to normal."%_t
                .. "\n\n" .. "Professionals will only gain levels as long as morale on the ship is good."%_t,
            },
            {
                title = "Academy"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/crewTab.jpg",
                text = "Starting with \\c(0d0)Trinium\\c(), you can build \\c(0d0)Academy Blocks\\c(), which unlock training, so you can train allrounder crew members to become professionals."%_t
                .. "\n\n" .. "While in the academy, these crew members won't be available for other jobs on the ship, but will still require payment."%_t,
            },
            {
                title = "Cloning"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/crewTab.jpg",
                text = "Starting with \\c(0d0)Xanion\\c(), \\c(0d0)Cloning Pods\\c() can be built."%_t
                .. " " .. "After building Cloning Pods, new allrounder crew members can be cloned on ship."%_t
                .. "\n\n" .. "In order to clone crew, you will always need at least one crew member on the ship."%_t,
            },
        }
    },
    {
        title = "Reconstruction"%_t,
        articles =
        {
            {
                title = "Towing"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/towing.jpg",
                text = "\\c(0d0)Repair Docks\\c() have a \\c(0d0)Towing Service\\c()."%_t
                .. "\n\n" .. "For a fee, they will recover your wreck and tow it back to the Repair Dock."%_t
                .. " " .. "This only works if the ship was destroyed less than 50 sectors away. Preliminary fixes will be made, but your ship will have to be properly repaired afterwards."%_t
                .. "\n\n" .. "If the Repair Dock is your \\c(0d0)Reconstruction Site\\c() then it will tow for free and can tow ships from all over the Galaxy. Repairs will be free of charge, too."%_t,
            },
            {
                title = "Reconstruction Kits"%_t,
                id = "ReconstructionKit",
                picture = "data/textures/ui/encyclopedia/craftmanagement/recon_arrow.jpg",
                text = "\\c(0d0)Repair Docks\\c() sell \\c(0d0)Reconstruction Kits\\c()."%_t
                .. " " .. "These kits allow quick on-site reassembly of a destroyed ship or station."%_t
                .. "\n\n" .. "To use them, you have to be in the sector where your ship was destroyed, and then activate them from within the inventory."%_t
                .. " " .. "The ship will be quickly reassembled and ready for flight again, but will definitely need some repairs afterwards though."%_t,
            },
            {
                title = "Reconstruction Site"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/reconstructionSite.jpg",
                text = "If you get destroyed and you don't have another of your ships in the same sector, you will be transported to the last friendly Repair Dock you visited."%_t
                .. " " .. "If relations with that faction have turned sour and returning there would put you in danger, you're moved to your \\c(0d0)Reconstruction Site\\c() instead."%_t
                .. " " .. "Your default Reconstruction Site is in your Home Sector, but you can also make any other friendly Repair Dock your Reconstruction Site, for a fee."%_t
                .. "\n\n" .. "- Your Reconstruction Site will tow and repair your ships for free."%_t
                .. "\n" .. "- Your Reconstruction Site can tow a ship from anywhere in the galaxy, no matter how far away it was destroyed."%_t
                .. "\n" .. "- You can always switch to your Reconstruction Site using the Galaxy Map."%_t,
            },
        },
    },
    {
        title = "Subsystems"%_t,
        articles =
        {
            {
                title = "General Function"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/upgradeTab.jpg",
                text = "\\c(0d0)Subsystems\\c() can improve certain aspects of a ship. This allows the specialization of ships for certain jobs.\n\n\\c(0d0)Permanently installed\\c() subsystems usually give huge bonuses, but can only be removed close to an \\c(0d0)Equipment Dock\\c().\n\n\\c(ddd)Note: Some subsystems HAVE to be installed permanently to work.\\c()"%_t,
            },
            {
                title = "Turret Control Systems"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/upgrades/tcs.jpg",
                text = "Each \\c(0d0)Turret Control System\\c() increases the amount of available \\c(0d0)turret slots\\c(). Depending on the type of the subsystem, it increases the number of slots for military, civil or both turret types."%_t,
            },
            {
                title = "Battery Upgrade"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/upgrades/battery.jpg",
                text = "The \\c(0d0)Battery Upgrade\\c() contains algorithms to allow better management of recharging, meaning batteries have a \\c(0d0)higher capacity\\c() and \\c(0d0)lower recharge\\c() time with it installed."%_t,
            },
            {
                title = "Cargo Upgrade"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/upgrades/cargoupgrade.jpg",
                text = "\\c(0d0)Cargo Upgrades\\c() increase \\c(0d0)cargo capacity\\c() without the need to add more Cargo Blocks. Organization is the key!"%_t,
            },
            {
                title = "Generator Upgrade"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/upgrades/generator.jpg",
                text = "Increasing the generated \\c(0d0)energy output\\c() and battery \\c(0d0)recharge rate\\c() can be achieved with a \\c(0d0)Generator Upgrade\\c()."%_t,
            },
            {
                title = "Engine Upgrade"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/upgrades/engine.jpg",
                text = "The \\c(0d0)Engine Upgrade\\c() improves overall velocity and engine thrust. More \\c(0d0)engine power\\c() without the hassle of adding more Engine Blocks to the ship."%_t,
            },
            {
                title = "Hyperspace Upgrade"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/upgrades/hyperspace.jpg",
                text = "The \\c(0d0)Hyperspace Upgrade\\c() improves the hyperspace \\c(0d0)jump range\\c() of a ship and decreases the necessary \\c(0d0)recharge energy\\c(). If installed permanently it can additionally shorten the recharge time."%_t,
            },
            {
                title = "Radar Upgrade"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/upgrades/radar.jpg",
                text = "\\c(0d0)Radar Upgrades\\c() improve \\c(0d0)radar range\\c() and can add to the \\c(0d0)deep scan range\\c() too. With a deep scanner, hidden mass sectors will be highlighted on the Galaxy Map."%_t,
            },
            {
                title = "Shield Booster"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/upgrades/shieldbooster.jpg",
                text = "A \\c(0d0)Shield Booster\\c() improves \\c(0d0)shield durability\\c() and \\c(0d0)recharge rate\\c()."%_t,
            },
            {
                title = "Tractor Beam Upgrade"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/upgrades/tractor.jpg",
                text = "A \\c(0d0)Tractor Beam Upgrade\\c() will increase the \\c(0d0)loot range\\c() of a ship. They are very handy when collecting free-floating loot."%_t,
            },
            {
                title = "Scanner Upgrade"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/upgrades/scanner.jpg",
                text = "The \\c(0d0)Scanner Upgrade\\c() allows you to detect contents of a ship's or station's cargo from longer distances. They're widely used by sector security to scan for illegal or dangerous goods."%_t,
            },
            {
                title = "Mining System"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/upgrades/miningupgrade.jpg",
                text = "The \\c(0d0)Mining Subsystems\\c() marks resource rich \\c(0d0)asteroids\\c() containing the specified material or lower materials, even if the materials are hidden inside. It adds small marker arrows to the HUD so that finding asteroids with materials is easier."%_t,
            },
            {
                title = "Trading System"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/upgrades/trading.jpg",
                text = "A \\c(0d0)Trading Subsystems\\c() will ease trade and commerce a lot. Depending on the quality of the subsystem, it can show all trading possibilities with \\c(0d0)prices\\c() and \\c(0d0)price margins\\c() in the last visited sectors. It will even detect trade routes over the last few visited sectors.\nAll ships working trade routes should be equipped with one of these."%_t
                .. "\n\n" .. "For more information see section \\c(0d0)Trade\\c() -> \\c(0d0)Trading Subsystem\\c()."%_t,
            },
            {
                title = "Object Detector"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/upgrades/objectdetector.jpg",
                text = "The \\c(0d0)Object Detector\\c() detects and marks all objects worth checking out in the current sector."%_t,
            },
            {
                title = "Shield Reinforcer"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/upgrades/shieldreinforcer.jpg",
                text = "With a \\c(0d0)Shield Reinforcer\\c() shields won't be \\c(0d0)penetrated by torpedoes and shots\\c(). Disadvantages of subsystems like this include a weaker shield overall and a longer recharge time.\n\n\\c(ddd)Note: This subsystem has to be installed permanently to function.\\c()"%_t,
            },
            {
                title = "Energy to Shield Converter"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/upgrades/energytoshield.jpg",
                text = "The \\c(0d0)Energy Converter\\c() reroutes part of the ship's energy into the shield. This means less energy for ship systems but a much \\c(0d0)higher shield durability\\c()."%_t,
            },
            {
                title = "Transporter Software"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/upgrades/transporter.jpg",
                text = "A \\c(0d0)Transporter Block\\c() only works with the corresponding \\c(0d0)Transporter Software Subsystem\\c(). The software increases the \\c(0d0)docking range\\c() and allows fighters to pick up cargo for a ship."%_t,
            },
            {
                title = "Velocity SCB"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/upgrades/velocitybypass.jpg",
                text = "The \\c(0d0)Velocity Security Control Bypass\\c() allows you to ignore a ship's \\c(0d0)maximum speed\\c() limitations.\n\\c(ddd)Please note: Braking without friction takes a while. The Intergalactic Security Agency advises against the use of VSCB subsystems.\\c()"%_t,
            },
            {
                title = "Internal Defense System"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/upgrades/defense_system.jpg",
                text = "If somebody has the audacity to try and board one of your ships, install an \\c(0d0)Internal Defense System\\c(). It constructs specialized weapons that help your crew defend against enemy boarders. And the best thing? If \\c(0d0)Internal Defense Weapons\\c() are overpowered by enemy boarders, they are not destroyed, only disabled until the next attack!"%_t,
            },
            {
                title = "Hull Polarizer"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/upgrades/hull_polarizer.jpg",
                text = "There are several versions of the \\c(0d0)Hull Polarizer\\c(). Each one of them greatly increases hull strength. But be careful: As a side effect, the hull takes more damage from a certain damage type. You can only install one at a time."%_t,
            },
            {
                title = "Shield Ionizer"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/upgrades/shield_ionizer.jpg",
                text = "There are several versions of the \\c(0d0)Shield Ionizer\\c(). Each one of them greatly reduces the amount of damage taken from a certain damage type. You can only install one at a time."%_t,
            },
            {
                title = "Stabilizing Nanobot Routing"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/upgrades/volume-booster.jpg",
                text = "The \\c(0d0)Stabilizing Nanobot Routing\\c() improves your ship's structural stability, allowing you to build bigger ships as if you had more processing power available."%_t,
            },

            -- sorry guys, spoilers ;)
            BlackMarketEncyclopedia.getUpgrades(),
        },
    },

    {
        title = "Integrity Fields"%_t,
        id = "IntegrityFields",
        picture = "data/textures/ui/encyclopedia/craftmanagement/integrity.jpg",
        text = "Starting with \\c(0d0)Titanium\\c(), you can build \\c(0d0)Integrity Field Generator Blocks\\c()."%_t
        .. " " .. "They create a stability field around them that protects other blocks to ensure that they don't break as quickly."%_t
        .. " " .. "Additionally, they massively reduce incoming damage to blocks inside the integrity field."%_t
        .. "\n\n" .. "Integrity Field Generators are an excellent way to ensure that your ship can take a few hits while you don't have \\c(0d0)Shields\\c() yet."%_t,
    },

    {
        title = "Shields"%_t,
        id = "Shields",
        picture = "data/textures/ui/encyclopedia/craftmanagement/shields.jpg",
        text = "Starting with \\c(0d0)Naonite\\c(), you can build \\c(0d0)Shield Generator Blocks\\c()."%_t
        .. " " .. "They project a shield around the entire ship, that protects it from incoming weapon fire."%_t
        .. " " .. "After being damaged, shields will recharge automatically over time."%_t
        .. "\n\n" .. "It is a common misconception in the galaxy, that shields protect from collision damage. They do not."%_t
        .. "\n\n" .. "There is some weaponry that can penetrate shields, though, such as certain kinds of \\c(0d0)Torpedoes\\c() or \\c(0d0)Pulse Cannons\\c() with their ionized projectiles."%_t,
    },

    {
        title = "Armed Turrets"%_t,
        picture = "data/textures/ui/encyclopedia/craftmanagement/inventoryTab.jpg",
        text = "There are many different weapon types with different features."%_t
        .. " " .. "Some weapons do more damage to shields, others do more damage to hull."%_t
        .. " " .. "Others can even bypass shields entirely or damage more than one block at a time."%_t
        .. "\n\n" .. "Some turrets can be set as \\c(0d0)Auto Targeting\\c(), allowing them to function independently from the player's aim."%_t
        .. " " .. "These turrets can be set to attack a target, always attack, defend or to be controlled by the player."%_t
        .. "\n\n" .. "The tooltip shows all traits of a turret."%_t
        .. " " .. "All turrets can be categorized into one of three categories: \\c(0d0)Overheating\\c(), \\c(0d0)Energy Using\\c() or \\c(0d0)Special\\c()."%_t,

        articles =
        {
            {
                title = "Overheating Turrets"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/overheatingWeapons.jpg",
                text = "\\c(0d0)Overheating turrets\\c() build up heat while shooting and regularly need to cool down. Once overheated, they won't be able to fire until they have cooled down for a while.\n\nWeapons in this categorie include \\c(0d0)Railguns\\c(), \\c(0d0)Rocket Launchers\\c(), \\c(0d0)Bolters\\c() and \\c(0d0)Cannons\\c()."%_t,
            },
            {
                title = "Energy Turrets"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/energyWeapons.jpg",
                text = "\\c(0d0)Energy-Using Turrets\\c() have batteries that first need to be charged with your ship's energy. Once this battery is depleted, the turret will stop shooting until its battery has been recharged.\n\nWeapons of this category inlcude \\c(0d0)Lasers\\c(), \\c(0d0)Tesla\\c() and \\c(0d0)Lightning Guns\\c() and \\c(0d0)Plasma Turrets\\c()."%_t,
            },
            {
                title = "Special Turrets"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/defenseWeapons_red.jpg",
                text = "Some turrets don't fit into one of the above categories.\n\n\\c(0d0)Point Defense Weapons\\c(): Those weapons can always fire and need no ammunition. Point Defense Weapons are very good against enemy fighters and torpedoes. Set them to 'Defensive' to have them automatically target torpedoes, fighters and nearby enemies.\n\nUtility Turrets: Those include \\c(0d0)Healing\\c() and \\c(0d0)Force turrets\\c(), which can heal other ships or push or pull them around."%_t,
            },
            {
                title = "Chain Gun"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/turrets/chaingun.jpg",
                text = "A \\c(0d0)Chain Gun\\c() is a very basic, all-purpose weapon."%_t
                .. "\n\n" .. "It doesn't overheat very fast and it is very reliable."%_t,
            },
            {
                title = "Laser"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/turrets/laser.jpg",
                text = "A \\c(0d0)Laser\\c() is an energy-based weapon."%_t
                .. "\n\n" .. "It shoots very precise laser rays that do good damage against \\c(0d0)Shields\\c()."%_t,
            },
            {
                title = "Plasma Gun"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/turrets/plasma-gun.jpg",
                text = "A \\c(0d0)Plasma Gun\\c() is an energy-based weapon."%_t
                .. "\n\n" .. "Its projectiles are exceptionally strong against \\c(0d0)Shields\\c()."%_t,
            },
            {
                title = "Rocket Launcher"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/turrets/rocket-launcher.jpg",
                text = "A \\c(0d0)Rocket Launcher\\c() does physical AOE damage on impact."%_t
                .. "\n\n" .. "It has a very large range and is especially good against stationary targets."%_t
                .. " " .. "Its projectiles are slow, but they can be target-seeking."%_t,
            },
            {
                title = "Cannon"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/turrets/cannon.jpg",
                text = "A \\c(0d0)Cannon\\c() is a physical weapon with a large range."%_t
                .. "\n\n" .. "Its fast projectiles do AOE damage on impact but it doesn't have a very high firing rate."%_t,
            },
            {
                title = "Railgun"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/turrets/rail-gun.jpg",
                text = "A \\c(0d0)Railgun\\c() is a very precise weapon."%_t
                .. "\n\n" .. "Its high range rays can penetrate \\c(0d0)Hull\\c() easily but are not as effective against \\c(0d0)Armor\\c()."%_t,
            },
            {
                title = "Bolter"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/turrets/bolter.jpg",
                text = "A \\c(0d0)Bolter\\c() is an all-purpose weapon."%_t
                .. "\n\n" .. "It does anti-matter damage that is good for penetrating \\c(0d0)Hull\\c()."%_t
                .. " " .. "However, it has a rather slow firing-rate and tends to overheat."%_t,
            },
            {
                title = "Lighting Gun"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/turrets/lightning-gun.jpg",
                text = "A \\c(0d0)Lightning Gun\\c() is an energy based weapon that shoots rays of lightning."%_t
                .. "\n\n" .. "It does electrical damage and is very ineffective against \\c(0d0)Stone\\c()."%_t,
            },
            {
                title = "Tesla Gun"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/turrets/tesla.jpg",
                text = "A \\c(0d0)Tesla Gun\\c() is a low range weapon that deals a lot of damage."%_t
                .. "\n\n" .. "It shoots rays that do electrical damage and that are ineffective against \\c(0d0)Stone\\c()."%_t,
            },
            {
                title = "Pulse Cannon"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/turrets/pulse-cannon.jpg",
                text = "A \\c(0d0)Pulse Cannon\\c() shoots ionized projectiles."%_t
                .. "\n\n" .. "They don't do very high damage but they are capable of penetrating \\c(0d0)Shields\\c()."%_t,
            },
            {
                title = "Anti Fighter"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/turrets/anti-fighter.jpg",
                text = "\\c(0d0)Anti Fighter\\c() weapons have a low range but deal AOE damage and splash damage."%_t
                .. "\n\n" .. "This makes them very effective against \\c(0d0)Fighters\\c()."%_t,
            },
            {
                title = "Force Gun"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/turrets/force-gun.jpg",
                text = "A \\c(0d0)Force Gun\\c() doesn't deal damage."%_t
                .. "\n\n" .. "Instead it can be used to physically move enemies, friends or objects."%_t,
            },
            {
                title = "Point Defense Weapons"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/turrets/pdc.jpg",
                text = "\\c(0d0)Point Defense Weapons\\c(): Those weapons can always fire and need no ammunition."%_t
                .. "\n\n" .. "Point Defense Weapons are very good against enemy \\c(0d0)fighters\\c() and \\c(0d0)torpedoes\\c()."%_t
                .. "Set them to 'Defensive' to have them automatically target torpedoes, fighters and nearby enemies."%_t,
            },
        }
    },
    {
        title = "Unarmed Turrets"%_t,
        articles =
        {
            {
                title = "Mining Lasers"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/turrets/mining.jpg",
                text = "A \\c(0d0)Mining Laser\\c() is a turret that is meant for extracting resources from Stone."%_t
                .. "\n\n" .. "Two types of mining lasers are commonly known: \\c(0d0)Refining\\c() and \\c(0d0)Raw\\c() (short: \\c(0d0)R\\c())."%_t
                .. " " .. "Refining lasers extract and immediately refine ores."%_t
                .. " " .. "R-Mining lasers can't refine ores, which means the ship will need a cargo bay to collect the ores. "%_t
                .. " " .. "But R-Mining lasers usually have a much higher efficiency, making them the best choice for larger mining vessels."%_t,
            },
            {
                title = "Salvaging Lasers"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/turrets/salvage.jpg",
                text = "\\c(0d0)Salvaging Lasers\\c() allow to extract materials and equipment from wreckages."%_t
                .. "\n\n" .. "Depending on the type of laser they'll yield refined materials (\\c(0d0)Refining Lasers\\c()) or scrap metals (\\c(0d0)R-Salvaging Lasers\\c())."%_t
                .. " " .. "Refining lasers are very good for smaller ships without cargo bays, but tend to have lower efficiency than comparable R-Salvaging Lasers."%_t
                .. "\n" .. "To pick up and transport \\c(0d0)scrap metal\\c(), a ship needs to have a \\c(0d0)cargo bay\\c()."%_t
                .. " " .. "Scrap metals can be \\c(0d0)refined\\c() at a \\c(0d0)Resource Depot\\c() (for a small fee)."%_t,
            },
            {
                title = "Repair Beams"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/turrets/repair.jpg",
                text = "\\c(0d0)Repairs Beams\\c() can be used to restore HP to a ship or to regenerate shields."%_t
                .. "\n\n" .. "Some repair beams can be used to repair the \\c(0d0)Hull\\c() of a ship."%_t
                .. " " .. "They will not restore missing blocks but they will fully heal all remaining blocks."%_t
                .. " " .. "Others can be used to regenerate \\c(0d0)Shields\\c()."%_t
                .. " " .. "There are even some repair beams that are able to do both at the same time."%_t,
            },
        }
    },
    {
        title = "Legendary Turrets"%_t,
        picture = "data/textures/ui/encyclopedia/craftmanagement/turrets/legendary.jpg",
        text = "There are a number of \\c(0d0)Legendary Turrets\\c()."%_t
        .. "\n\n" .. "They can be recognized by their unique names. They are very rare and most of them have interesting special effects."%_t,
    },
    {
        title = "Auto Targeting"%_t,
        pictures =
        {
            "data/textures/ui/encyclopedia/craftmanagement/autoTargeting/autoturrets_1.jpg",
            "data/textures/ui/encyclopedia/craftmanagement/autoTargeting/autoturrets_1.jpg",
            "data/textures/ui/encyclopedia/craftmanagement/autoTargeting/autoturrets_2.jpg",
            "data/textures/ui/encyclopedia/craftmanagement/autoTargeting/autoturrets_2.jpg",
            {path = "data/textures/ui/encyclopedia/craftmanagement/autoTargeting/autoturrets_3.jpg", showLabel = true, caption = "[A]"},
            {path = "data/textures/ui/encyclopedia/craftmanagement/autoTargeting/autoturrets_3.jpg", showLabel = false, caption = "[A]"},
            "data/textures/ui/encyclopedia/craftmanagement/autoTargeting/autoturrets_4.jpg",
            "data/textures/ui/encyclopedia/craftmanagement/autoTargeting/autoturrets_4_red.jpg",
            "data/textures/ui/encyclopedia/craftmanagement/autoTargeting/autoturrets_4_red.jpg",
        },
        text = "Each ship has a certain number of \\c(0d0)Auto Targeting Slots\\c(). Turrets set to auto targeting can fire automatically when enemies are within range."%_t
        .. "\n\n" .. "To set a turret to auto targeting, select it in the \\c(0d0)Ship Tab\\c() of the \\c(0d0)Ship Menu\\c() and then press \\c(fff)[A]\\c(), or right click the turret and select \\c(fff)'Auto Targeting'\\c()."%_t
        .. " " .. "You will see a little blue circle appear in the bottom right corner of the turret icon."%_t
        .. "\n\n" .. "You can increase the number of auto targeting slots on your ship by installing \\c(0d0)subsystems\\c()."%_t
        .. "\n\n" .. "To control your turrets, assign a number to the turret slot."%_t
        .. " " .. "You will then see the turret group above your health bar and you will be able to select whether you want it to be controlled manually, only shoot at attackers, shoot at everything or shoot at a certain target."%_t,
    },
    {
        title = "Fighters"%_t,
        id = "Fighters",
        articles =
        {
            {
                title = "Using Fighters"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/fighterTab.jpg",
                text = "\\c(0d0)Fighters\\c() can be bought at \\c(0d0)Equipment Docks\\c(), or be created at a \\c(0d0)Fighter Factory\\c()."%_t
                .. "\n\n" .. "To use fighters you will need \\c(0d0)Hangar\\c() to put them in."%_t
                .. " " .. "As fighter sizes vary, your ship will show a minimum and maximum Hangar capacity in the \\c(0d0)Building Mode\\c()."%_t
                .. " " .. "You will also need \\c(0d0)Pilots\\c(). They will stay on the ship and steer fighters remotely, and you will need one pilot per fighter."%_t
                .. "\n\n" .. "Fighters are organized in \\c(0d0)Squads\\c()."%_t
                .. " " .. "Buttons on the left side of the screen allow to set a command for each squad."%_t
                .. " " .. "Depending on the type of fighter, they can attack or defend, be used for mining or salvaging or shuttle crew to board crafts."%_t,
            },
            {
                title = "Producing Fighters"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/fighter.jpg",
                text = "With an \\c(0d0)Assembly Block\\c(), copies of a fighter can be produced on the ship."%_t
                .. "\n\n" .. "To create a producible blueprint, a fighter has to be placed in the blueprint slot."%_t
                .. " " .. "It'll be disassembled and the ship will use this blueprint to create new fighters for money and resources."%_t
                .. "\n\n" .. "The more Assembly Blocks you have, the faster your fighter production will be."%_t,
            },
        }
    },
    {
        title = "Torpedoes"%_t,
        id = "Torpedoes",
        articles =
        {
            {
                title = "About Torpedoes"%_t,
                picture = "data/textures/ui/encyclopedia/craftmanagement/torpedoTab.jpg",
                text = "\\c(0d0)Torpedoes\\c() are special weapons with \\c(0d0)very high range\\c(). The various types can be distinguished by the color of the warhead. Each kind of torpedo has its advantages and disadvantages. Some are extremely good against shields, others are better against the hull and some damage both.\n\nTorpedoes can be deadly. To defend yourself against them, build \\c(0d0)Point Defense Weapons\\c() that automatically shoot them down before impact."%_t,
            },
            {
                title = "Using Torpedoes"%_t,
                pictures =
                {
                    "data/textures/ui/encyclopedia/craftmanagement/torpedoes/torpedo_1.jpg",
                    "data/textures/ui/encyclopedia/craftmanagement/torpedoes/torpedo_1.jpg",
                    "data/textures/ui/encyclopedia/craftmanagement/torpedoes/torpedo_2.jpg",
                    "data/textures/ui/encyclopedia/craftmanagement/torpedoes/torpedo_2.jpg",
                    "data/textures/ui/encyclopedia/craftmanagement/torpedoes/torpedo_3.jpg",
                    "data/textures/ui/encyclopedia/craftmanagement/torpedoes/torpedo_3.jpg",
                    "data/textures/ui/encyclopedia/craftmanagement/torpedoes/torpedo_4.jpg",
                    "data/textures/ui/encyclopedia/craftmanagement/torpedoes/torpedo_4_red.jpg",
                    "data/textures/ui/encyclopedia/craftmanagement/torpedoes/torpedo_4_red.jpg",
                    {path = "data/textures/ui/encyclopedia/craftmanagement/torpedoes/torpedo_5.jpg", showLabel = false, caption = "[" .. GameInput():getKeyName(ControlAction.FireTorpedoes) .. "]"},
                    {path = "data/textures/ui/encyclopedia/craftmanagement/torpedoes/torpedo_5.jpg", showLabel = true, caption = "[" .. GameInput():getKeyName(ControlAction.FireTorpedoes) .. "]"},
                    {path = "data/textures/ui/encyclopedia/craftmanagement/torpedoes/torpedo_5.jpg", showLabel = true, caption = "[" .. GameInput():getKeyName(ControlAction.FireTorpedoes) .. "]"},
                    "data/textures/ui/encyclopedia/craftmanagement/torpedoes/torpedo_6.jpg",
                    "data/textures/ui/encyclopedia/craftmanagement/torpedoes/torpedo_6.jpg",
                    "data/textures/ui/encyclopedia/craftmanagement/torpedoes/torpedo_7.jpg",
                    "data/textures/ui/encyclopedia/craftmanagement/torpedoes/torpedo_7.jpg",
                },
                text = "To use torpedoes you will need to add \\c(0d0)Torpedo Launchers\\c() (and optional \\c(0d0)Torpedo Storage\\c()) to your ship."%_t
                .. "\n\n" .. "You can buy torpedoes at \\c(0d0)Equipment Docks\\c() or collect them as loot."%_t
                .. " " .. "Load them into the shafts in the \\c(0d0)Torpedoes Tab\\c() of the \\c(0d0)Ship Menu\\c(). Then navigate to the \\c(0d0)Ship Tab\\c() of the \\c(0d0)Ship Menu\\c() and assign a number to your torpedo shafts."%_t
                .. "\n\n" .. "To fire the torpedoes, face your target, press the number of the shaft you want to use and press \\c(fff)[${fire}]\\c()."%_t % {fire = GameInput():getKeyName(ControlAction.FireTorpedoes)},
            },
        },
    },
    {
        title = "Docking Objects"%_t,
        picture = "data/textures/ui/encyclopedia/craftmanagement/docking.jpg",
        text = "If you add \\c(0d0)Dock Blocks\\c() to your ship, you will be able to dock objects or even other ships to it."%_t
        .. "\n\n" .. "Just fly close to what you want to dock and hold \\c(fff)[${dock}]\\c()."%_t % {dock = GameInput():getKeyName(ControlAction.DockObject)}
        .. " " .. "If there is nothing preventing you from docking, such as the captain of an enemy craft disagreeing to it, the object or ship will be attached to your ship."%_t
        .. "\n\n" .. "You can fly and do \\c(0d0)Hyperspace Jumps\\c() with any docked object, as if it was part of your ship."%_t
        .. "\n\n" .. "To undock it again, select it and press \\c(fff)[${dock}]\\c() or press \\c(fff)[CTRL] + [${dock}]\\c() to undock all objects."%_t % {dock = GameInput():getKeyName(ControlAction.DockObject)},
    },
    {
        title = "Transport Mode"%_t,
        pictures =
        {
            "data/textures/ui/encyclopedia/craftmanagement/transportMode/transportMode_1.jpg",
            "data/textures/ui/encyclopedia/craftmanagement/transportMode/transportMode_1.jpg",
            "data/textures/ui/encyclopedia/craftmanagement/transportMode/transportMode_2.jpg",
            "data/textures/ui/encyclopedia/craftmanagement/transportMode/transportMode_2.jpg",
            "data/textures/ui/encyclopedia/craftmanagement/transportMode/transportMode_3.jpg",
            "data/textures/ui/encyclopedia/craftmanagement/transportMode/transportMode_3.jpg",
        },
        text = "Usually, stations can't move. But there is one exception: you can \\c(0d0)dock\\c() a station to your ship and take it with you."%_t
        .. "\n\n" .. "To do that, you will need to press \\c(fff)[${interact}]\\c() to interact with the station and select \\c(fff)'Engage Transport Mode'\\c()."%_t % {interact = GameInput():getKeyName(ControlAction.Interact)}
        .. " " .. "While in \\c(0d0)Transport Mode\\c(), you will not be able to interact with the station and its activities will halt."%_t
        .. "\n\n" .. "After you have moved the station to where you wanted it to be, reengaging station mode will take several minutes."%_t,
    },
}

contents.crew = category.chapters[1]
contents.reconKits = category.chapters[2]
contents.upgrades = category.chapters[3]
contents.armedTurrets = category.chapters[6]
contents.unarmedTurrets = category.chapters[7]
contents.legendaryTurrets = category.chapters[8]
contents.fighter = category.chapters[10]
contents.torpedos = category.chapters[11]
