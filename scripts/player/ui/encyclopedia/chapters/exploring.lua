package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/encyclopedia/lib/?.lua"
package.path = package.path .. ";data/scripts/encyclopedia/?.lua"
include ("stringutility")
include ("contents")
local BlackMarketEncyclopedia = include ("internal/dlc/blackmarket/public/encyclopedia.lua")

Categories = Categories or {}
category = {}

table.insert(Categories, category)

category.title = "Exploration"%_t
category.chapters =
{
    {
        title = "Galaxy Map"%_t,
        articles =
        {
            {
                title = "Map Markers"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/map/map_blips.jpg",
                text = "The galaxy map has several types of markers: \\c(0d0)Colonized sectors\\c() are shown with a green blip, while sectors with \\c(0d0)Hidden Mass\\c() are marked with a yellow blip. Hidden mass sectors can contain good things, like huge asteroid fields, but also pirates. Be careful when venturing into the unknown!\n\\c(0d0)Visited sectors\\c() are marked with dots. Green dots represent allies, purple ones neutral objects, red ones hostile forces.\n\n\\c(ddd)Note: to see the yellow markers it's necessary to install a \\c(0d0)Radar Upgrade\\c(ddd) with deep scan function.\\c()"%_t,

            },
            {
                title = "Indicators"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/map/indicators.jpg",
                text = "Your \\c(0d0)current sector\\c() is marked with a blinking green frame and the \\c(0d0)selected sector\\c() with a white frame. A non-blinking green frame indicates a \\c(0d0)sector containing crafts\\c() that belong to you. The white dots on the side show how many crafts you have there.\nAlliance ships are marked in the same way, but with a pink frame.\n\nThe blue outline is your hyperspace jump range. Building \\c(0d0)Hyperspace Core Blocks\\c() or using a \\c(0d0)Hyperspace Upgrade\\c() improves your range."%_t,

            },
            {
                title = "Rifts"%_t,
                pictures =
                {
                    "data/textures/ui/encyclopedia/exploring/map/rift1.jpg",
                    "data/textures/ui/encyclopedia/exploring/map/rift2.jpg",
                    "data/textures/ui/encyclopedia/exploring/map/rift2.jpg",
                    "data/textures/ui/encyclopedia/exploring/map/rift1.jpg",
                },
                text = "Some areas in the galaxy are blocked by \\c(0d0)Hyperspace Rifts\\c()."%_t
                        .. " " .. "After a cataclysmic catastrophe several hundred years ago, these rifts suddenly appeared, swallowing entire sectors and civilisations."%_t
                        .. " " .. "They cannot be passed with normal \\c(0d0)Hyperspace Engines\\c() and must be flown around."%_t
                        .. "\n\n" .. "The biggest rift in the galaxy spans around the center of the galaxy, blocking all access to it."%_t
                        .. "\n\n" .. "Thanks to a scientific breakthrough, it is now possible to travel inside rifts for a short amount of time with the help of a \\c(0d0)Rift Research Center\\c()."%_t
                        .. "\n\n" .. "First scouting missions have shown that the environment inside of rifts is extremely dangerous and special precautions must be taken before venturing into rifts."%_t,
            },
            {
                title = "Context Menu"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/map/context_small.jpg",
                text = "The \\c(0d0)Sector Context Menu\\c() is opened when right-clicking on a sector."%_t
                        .. "\n\n" .. "Here you can have your \\c(0d0)Hyperspace Jump Route\\c() calculated, \\c(0d0)post\\c() the sector to chat and \\c(0d0)tag\\c() it."%_t
                        .. " " .. "Once a sector is tagged, you can also add \\c(0d0)notes\\c() for you and your alliance."%_t,

            },
            {
                title = "Search Bar"%_t,
                pictures =
                {
                    "data/textures/ui/encyclopedia/exploring/map/search_1.jpg",
                    "data/textures/ui/encyclopedia/exploring/map/search_1_red.jpg",
                    "data/textures/ui/encyclopedia/exploring/map/search_1_red.jpg",
                    "data/textures/ui/encyclopedia/exploring/map/search_2.jpg",
                    "data/textures/ui/encyclopedia/exploring/map/search_2_red.jpg",
                    "data/textures/ui/encyclopedia/exploring/map/search_2_red.jpg",
                    "data/textures/ui/encyclopedia/exploring/map/search_3.jpg",
                    "data/textures/ui/encyclopedia/exploring/map/search_3_red.jpg",
                    "data/textures/ui/encyclopedia/exploring/map/search_3_red.jpg",

                },
                text = "When hovering over a sector you will see information about ships and stations that were in the sector the last time you visited it."%_t
                .. "\n\n" .. "If you want to search for specific stations or objects that you remember, but you can't recall which sector you saw them in, use the \\c(0d0)Search Bar\\c() at the top left of the Galaxy Map."%_t,

            },
        },
    },
    {
        title = "Hyperspace Jumps"%_t,
        picture = "data/textures/ui/encyclopedia/exploring/jump.jpg",
        text = "You can jump to another sector using your \\c(0d0)Hyperspace Engine\\c()."%_t
        .. "\n\n" .. "Open the \\c(0d0)Galaxy Map\\c() and select reachable target coordinates by right-clicking a sector."%_t
        .. " " .. "Then close the map again, turn your ship until it faces the target sector and start boosting in that direction."%_t
        .. "\n\n" .. "If your ship has enough energy, your Hyperspace Engine will carry you to the new sector."%_t
        .. " " .. "If not, you might want to add \\c(0d0)Energy Generators\\c() or \\c(0d0)Energy Storage\\c() to your ship."%_t,
    },
    {
        title = "Gate Network"%_t,
        id = "Gates",
        picture = "data/textures/ui/encyclopedia/exploring/gate.jpg",
        text = "To move between sectors you can also use the \\c(0d0)Gate Network\\c()."%_t
        .. "\n\n" .. "Factions provide gates that you can travel through for a \\c(0d0)fee\\c()."%_t
        .. " " .. "Select the gate and check how high the fee is at the bottom right of your screen. If you think you can afford it, just fly through the gate, you will pay automatically."%_t
        .. "\n\n" .. "If the gate covers a great distance or if your relations to the gate's owners are bad, the fee will be higher."%_t
        .. "\n\n" .. "Factions that don't like you will not allow you to use their gates at all, and if your ship becomes too big, you won't be able to use small gates any more."%_t,
    },
    {
        title = "Faction Areas"%_t,
        picture = "data/textures/ui/encyclopedia/exploring/factionAreas.jpg",
        text = "Factions have settled in most parts of the Galaxy and have claimed territory."%_t
        .. "\n\n" .. "Each faction controls their \\c(0d0)Central Faction Area\\c()."%_t
        .. " " .. "This is where most of their stations are located. In this area, factions will defend themselves vigorously against attackers."%_t
        .. "\n\n" .. "A faction usually has a lower presence in their \\c(0d0)Outer Faction Area\\c()."%_t
        .. " " .. "There are fewer stations and you may run into more enemies. However, there will be more asteroid fields and general chances for adventure there."%_t,
    },
    {
        title = "No-Man's-Space"%_t,
        picture = "data/textures/ui/encyclopedia/exploring/factionAreas.jpg",
        text = "There are patches of \\c(0d0)No-Man's-Space\\c() in the Galaxy."%_t
        .. "\n\n" .. "No faction has laid claim to them, and pirates and Xsotan roam in large numbers there."%_t
        .. " " .. "But, of course, this is where you will find the most untouched asteroid fields and sectors that might contain things that might prove to be valuable."%_t
        .. "\n\n" .. "Flying through those areas means high risk but high reward."%_t,
    },
    {
        title = "Zones"%_t,
        articles =
        {
            {
                title = "Neutral Zone"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/zones/neutral_zone.jpg",
                text = "The \\c(0d0)Neutral Zone\\c() is a safe zone. Player-vs-player damage is disabled. You cannot damage other players, not even by collision damage, but you can use repair turrets or repair fighters to heal them."%_t,

            },
            {
                title = "Hazard Zone"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/zones/hazard_zone.jpg",
                text = "If someone causes too much trouble and destroys or boards structures of other factions, the faction controlling the sector will call the sector out as a \\c(0d0)Hazard Zone\\c(). Civilian ships, traders and freighters will avoid this sector for a certain amount of time. Instead, military ships will appear and restore peace."%_t,

            },
        },
    },
    {
        title = "Stations"%_t,
        articles =
        {
            {
                title = "Shipyard"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/Shipyard.jpg",
                text = "If you are in need of a new ship, well, then go find a \\c(0d0)Shipyard\\c()!"%_t
                        .. " " .. "They can build you a ship from scratch and have a lot of customization options. For example you can let them organize a full crew to have a ready-to-go miner. Shipyards are also the perfect place to go if you're in need of a crew or need some repairs done."%_t
                        .. "\n\n" .. "With a Shipyard in the sector, you can build blocks with hyperspace-sensitive technology, like \\c(0d0)Generators\\c() or \\c(0d0)Hyperspace Cores\\c(). Those blocks must be built with the help of a Shipyard to safely perform hyperspace jumps."%_t
                        .. " " .. "This kind of careful planning is not necessary when building stations or repairing ships."%_t
                        .. "\n\n" .. "Shipyards are \\c(0d0)Consumer\\c() stations that buy a wide range of \\c(0d0)Trading Goods\\c()."%_t,
            },
            {
                title = "Repair Dock"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/RepairDock.jpg",
                text = "Have a dent in your ship? Go to a \\c(0d0)Repair Dock\\c() and have it fixed right away!"%_t
                        .. " " .. "In addition to repairs, at a \\c(0d0)Repair Dock\\c() you can buy \\c(0d0)Reconstruction Kits\\c(). These handy items allow you to quickly reassemble your ship in case it is destroyed."%_t
                        .. "\n\n" .. "A Repair Dock can also serve as an anchor point to reconstruct your drone, when your ship gets destroyed. Once all your ships were destroyed, you'll be placed in your drone at the last Repair Dock you visited. If relations have turned sour in the meantime, you'll be returned to your \\c(0d0)Reconstruction Site\\c() instead."%_t
                        .. "\n\n" .. "Finally, they provide a \\c(0d0)Towing Service\\c() that can be used to have wrecks brought to the station and reassembled."%_t
                        .. "\n\n" .. "Set a Repair Dock as your \\c(0d0)Reconstruction Site\\c() to have it tow ships from all over the galaxy and repair for free."%_t
                        .. "\n\n" .. "Repair Docks are \\c(0d0)Consumer\\c() stations that buy a wide range of \\c(0d0)Trading Goods\\c()."%_t,
                unlockEncyclopediaMilestone = true,
            },
            {
                title = "Equipment Dock"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/EquipmentDock.jpg",
                text = "\\c(0d0)Equipment Docks\\c() trade all kinds of equipment: \\c(0d0)Turrets\\c(), \\c(0d0)Torpedoes\\c(), \\c(0d0)Fighters\\c() and more. You can sell unused equipment here as well."%_t
                        .. "\n\n" .. "When near an Equipment Dock, you can remove permanently installed subsystems from your ship."%_t
                        .. "\n\n" .. "Equipment Docks are \\c(0d0)Consumer\\c() stations that buy a wide range of \\c(0d0)Trading Goods\\c()."%_t,
            },
            {
                title = "Resource Depot"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/ResourceDepot.jpg",
                text = "Material trade is done at a \\c(0d0)Resource Depot\\c(). You can \\c(0d0)buy and sell\\c() resources for Credits, and \\c(0d0)refine\\c() metal scraps and ores into usable materials."%_t,
            },
            {
                title = "Headquarters"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/Headquarters.jpg",
                text = "The \\c(0d0)Headquarters\\c() is a unique station for every faction. If you need to contact the whole faction, you should talk to their Headquarters."%_t,
            },
            {
                title = "Research Station"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/Research.jpg",
                text = "At the \\c(0d0)Research Station\\c() you can combine items into a better, random new one. The better the items, the better the resulting item will be."%_t
                        .. "\n\n" .. "Research Stations are \\c(0d0)Consumer\\c() stations that buy a wide range of \\c(0d0)Trading Goods\\c()."%_t,
            },
            {
                title = "Fighter Factory"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/FighterFactory.jpg",
                text = "At a \\c(0d0)Fighter Factory\\c(), you can design and build your own \\c(0d0)custom Fighters\\c(). You can combine a block design with 200 blocks or less with a turret of your choice to get a new fighter."%_t,
            },
            {
                title = "Turret Factory"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/TurretFactory.jpg",
                text = "Found the perfect turret, but got only one of them? You can go to a \\c(0d0)Turret Factory\\c() and turn it into a blueprint."%_t
                        .. " " .. "Once you got the blueprint, you can build more of the turret out of trading goods."%_t
                        .. "\n\n" .. "Turret Factories will also have a variety of blueprints already available."%_t
                        .. " " .. "The higher the tech level of a Turret Factory the better the turrets it can build."%_t
                        .. "\n\n" .. "Turret Factories are \\c(0d0)Consumer\\c() stations that buy a wide range of \\c(0d0)Trading Goods\\c()."%_t,

            },
            {
                title = "Trading Post"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/TradingPost.jpg",
                text = "\\c(0d0)Trading Posts\\c() buy and sell a wide variety of goods, and are always worth checking out."%_t
                        .. " " .. "They sell \\c(0d0)Trading Licenses\\c() too if you want to transport special or illegal goods."%_t
                        .. "\n\n" .. "If you're looking to build your own turrets have a look here as well."%_t
                        .. " " .. "Some Trading Posts specialize in trading goods that can be used as ingredients."%_t
                        .. "\n\n" .. "Trading Posts attract trading ships, and can use civilian shuttles to trade with \\c(0d0)Factories\\c(), \\c(0d0)Consumers\\c() (and more) in the sector."%_t
                        .. "\n\n" .. "Trade between stations stops immediately, though, if a sector is called out as a \\c(0d0)Hazard Zone\\c()."%_t,
            },
            {
                title = "Travel Hub"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/TravelHub.jpg",
                text = "\\c(0d0)Travel Hubs\\c() provide a service where they charge your ship with energy to allow you to do longer hyperspace jumps."%_t
                        .. "\n\n" .. "In order to do that, you need several \\c(0d0)trading goods\\c()."%_t
                        .. " " .. "Depending on the distance you want to go, more expensive and rarer goods will be necessary."%_t
                        .. "\n\n" .. "Travel Hubs use very advanced technology that follows specific rules."%_t
                        .. " " .. "If you wish to construct your own Travel Hub, you will need to use \\c(0d0)Glow Blocks\\c() of the color \\c(0d0)Travelhub Blue\\c()."%_t,
            },
            {
                title = "Scrapyard"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/Scrapyard.jpg",
                text = "At \\c(0d0)Scrapyards\\c(), you can sell off old ships and \\c(0d0)dismantle turrets\\c() to get resources. Additionally, Scrapyards sell licenses allowing you to \\c(0d0)salvage wreckages\\c() to get turrets, subsystems and material scraps."%_t,
            },
            {
                title = "Smuggler's Market"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/SmugglersMarket.jpg",
                text = "If you ever find yourself in the possession of \\c(0d0)Stolen Goods\\c() you can sell or have them \\c(0d0)unbranded\\c() here. Unbranded goods can then be traded with any station. Nobody will ask questions at a \\c(0d0)smuggler's market\\c()."%_t,
            },
            {
                title = "Military Outpost"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/MilitaryOutpost.jpg",
                text = "A \\c(0d0)Military Outpost\\c() represents the military force of a faction. Their personnel is well trained, so if you want the best \\c(0d0)Gunners\\c() this is where you look."%_t
                        .. "\n\n" .. "Military Outposts are \\c(0d0)Consumer\\c() stations that buy a wide range of \\c(0d0)Trading Goods\\c()."%_t,
            },
            {
                title = "Factories"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/Factory.jpg",
                text = "\\c(0d0)Factories\\c() produce a variety of trading goods out of lower tier goods."%_t
                        .. " " .. "They sell what they produce and they buy the goods they need."%_t
                        .. "\n\n" .. "Factories attract trading ships, and can use civilian shuttles to trade with other factories, \\c(0d0)Trading Posts\\c(), \\c(0d0)Consumers\\c() (and more) in the sector."%_t
                        .. "\n\n" .. "Trade between stations stops immediately, though, if a sector is called out as a \\c(0d0)Hazard Zone\\c()."%_t,
            },
            {
                title = "Consumers"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/Casino.jpg",
                text = "\\c(0d0)Consumer stations\\c() buy all kinds of goods people need to live. \\c(0d0)Casinos\\c(), \\c(0d0)Habitats\\c() and \\c(0d0)Biotopes\\c() tend to buy different kinds of food, beverages and luxury items."%_t,
            },
            {
                title = "Rift Research Center"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/RiftResearchStation.jpg",
                text = "In \\c(0d0)Rift Research Centers\\c(), scientists have made it their task to elicit the secrets of the rifts and the Xsotan."%_t
                        .. " " .. "Hence, these can be found across the galaxy in sectors \\c(0d0)adjacent to rifts\\c()."%_t
                        .. "\n\n" .. "Thanks to a scientific breakthrough, it's now possible to \\c(0d0)travel into the rifts\\c(). For their research, the scientists always need volunteers who are paid to be sent on \\c(0d0)Rift Expeditions\\c() and carry out tasks there."%_t
                        .. "\n\n" .. "Due to the technical limitations of the \\c(0d0)Teleporter\\c() device used to transport matter into the rift, only a limited amount of mass can be sent into a rift."%_t
                        .. "\n\n" .. "The rifts are a dangerous place, so good preparation is a must for a successful mission."%_t,
            },

            BlackMarketEncyclopedia.getBlackMarket(),
        },
    },
    {
        title = "Objects of Interest"%_t,
        articles =
        {
            {
                title = "Large Asteroids"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/asteroid.jpg",
                text = "Some sectors contain \\c(0d0)large Asteroids\\c()."%_t
                .. " " .. "They are the perfect place to found a mine on, as they usually contain resources such as water, ice or minerals."%_t
                .. "\n\n" .. "If you find a large asteroid and it doesn't already belong to anyone, you can \\c(0d0)claim\\c() it for yourself by flying close and interacting with it."%_t
                .. "\n\n" .. "Once you own, it, you get to decide what to do with it: you can keep it and found a \\c(0d0)mine\\c() on it, which is expensive but which will eventually generate considerable income for you.\nOr you can \\c(0d0)sell\\c() it to a nearby faction for a huge sum."%_t,
            },
            {
                title = "Secured Containers"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/securedContainer.jpg",
                text = "Sometimes, \\c(0d0)Secured Containers\\c() can be hidden within asteroid fields or large container fields."%_t
                .. "\n\n" .. "Many of them contain treasures, and it is definitely worth it to try to open them."%_t
                .. "\n\n" .. "You can dock the container to your ship and transport it to a \\c(0d0)Smuggler's Market\\c()."%_t
                .. " " .. "For a fee, you can have the container opened there."%_t
                .. "\n\n" .. "If you own an \\c(0d0)Injector Subsystem\\c() you can attempt to open them right there on the spot."%_t
                .. " " .. "But very often the containers are equipped with an alarm, and the owners of the containers are not far away."%_t,
            },
        },
    },
    {
        title = "Symbols"%_t,
        entries = {
            {"data/textures/icons/pixel/civil-ship.png", "Civil Ship"%_t},
            {"data/textures/icons/pixel/military-ship.png", "Military Ship"%_t},
            {"data/textures/icons/pixel/defender.png", "Advanced Military Ship"%_t},
            {"data/textures/icons/pixel/artillery.png", "Artillery Ship"%_t},
            {"data/textures/icons/pixel/persecutor.png", "Persecutor"%_t}, -- temporary name
            {"data/textures/icons/pixel/flagship.png", "Flagship"%_t},
            {"data/textures/icons/pixel/anti-carrier.png", "Anti-Fighter Ship"%_t},
            {"data/textures/icons/pixel/anti-shield.png", "Anti-Shield Ship"%_t},
            {"data/textures/icons/pixel/block.png", "Hyperspace Blocker"%_t},
            {"data/textures/icons/pixel/torpedoboat.png", "Torpedo Ship"%_t},
        },
        text = "",
    },
    {
        title = "Characters"%_t,
        articles =
        {
            {
                title = "Pirates"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/characters/pirate1.jpg",
                text = "When civilization took to space, everyone was excited for this opportunity to start new lives. But it wasn't long before problems arose - the economy favored the rich, while the poor became poorer and poorer. Inter-faction disputes and weak governments that weren't able to protect their citizen's rights didn't help the issue.\nSome people decided to take matters into their own hands. The number of pirates has steadily increased since the Event 200 years back, with a drastic increase in raids as well. Many empty sectors are now overrun with pirates that kill anyone who dares to come onto their turf. Neighboring Factions are suffering constant \\c(0d0)pirate attacks\\c() and will pay handsome \\c(0d0)rewards\\c() for anyone willing to help."%_t,
            },
            {
                title = "Bounty Hunters"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/characters/headHunter.jpg",
                text = "The recent rise in crime has led to a sharp decrease in the factions' patience to deal with enemies. It's more and more common to see Factions enlist \\c(0d0)Bounty Hunters\\c() to hunt down unwanted ships. Bounty Hunters are heavily armed and often bring a \\c(0d0)Hyperspace Blocker\\c() to stop ships from escaping into hyperspace."%_t,
            },
            {
                title = "Persecutors"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/characters/persecutors.jpg",
                text = "Beware on your travels to the center of the galaxy. More and more travellers report sightings of marauding ships. These scoundrels attack any \\c(0d0)weak ship\\c() that makes the mistake of coming into their sight. Because they aren't easy to give up, and even follow their prey through hyperspace, they've been aptly named \\c(0d0)'Persecutors'\\c()."%_t,
            },
            {
                title = "Xsotan"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/characters/xsotan1.jpg",
                text = "Ever since the Event ships of unknown origin roam the galaxy. If no weapons are fired they remain peaceful, but one shot is enough to turn them hostile. Many great scientists are puzzled by their unique traits. Research is still ongoing."%_t,
            },
            {
                title = "Adventurer"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/characters/adventurer.jpg",
                text = "The \\c(0d0)Adventurer\\c() is an explorer that knows a lot about what is going on in the galaxy. It is his life goal to find out more about the \\c(0d0)Xsotan\\c() so that the inhabitants of the galaxy might be able to defeat them once and for all!"%_t,

                isUnlocked = function()
                    if Player():getValue("encyclopedia_adventurer_met") then return true end

                    local adventurer = Sector():getEntitiesByScript("adventurer1.lua")
                    if adventurer then
                        -- RemoteInvocations_Ignore
                        invokeServerFunction("setValue", "adventurer_met")
                        return true
                    end

                    return false
                end
            },
            {
                title = "Hermit"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/characters/hermit.jpg",
                text = "\\c(0d0)The Hermit\\c() is one of the most reliable sources of knowledge. Many galaxy dwellers come to his asteroid to gather information and, despite his solitary lifestyle, he is always glad to help people who ask nicely."%_t,

                isUnlocked = function()
                    if Player():getValue("encyclopedia_hermit_met") then return true end

                    local hermit = Sector():getEntitiesByScript("hermit.lua")
                    if hermit then
                        -- RemoteInvocations_Ignore
                        invokeServerFunction("setValue", "hermit_met")
                        return true
                    end

                    return false
                end
            },
            {
                title = "Swoks"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/characters/swoks_fight.jpg",
                text = "\\c(0d0)Swoks III\\c() is the third offspring of a pirate dynasty. After his older brothers were defeated, he became the pirate king!"%_t,

                isUnlocked = function()
                    if Player():getValue("encyclopedia_swoks_met") then return true end

                    local swoks = Sector():getEntitiesByScript("swoks.lua")
                    if swoks then
                        -- RemoteInvocations_Ignore
                        invokeServerFunction("setValue", "swoks_met")
                        return true
                    end

                    return false
                end
            },

            {
                title = "Mobile Energy Lab"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/characters/mobileLab.jpg",
                text = "The \\c(0d0)M.A.D. Science Association\\c() researches \\c(0d0)Xsotan\\c() energy technology. They own multiple satellites all over the galaxy that give off weird vibes."%_t,

                isUnlocked = function()
                    if Player():getValue("encyclopedia_MAD_met") then return true end

                    local scientist = Sector():getEntitiesByScript("scientist.lua")
                    if scientist then
                        -- RemoteInvocations_Ignore
                        invokeServerFunction("setValue", "MAD_met")
                        return true
                    end

                    return false
                end
            },
            {
                title = "The AI"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/characters/ai.jpg",
                text = "Apparently, the \\c(0d0)AI\\c() was once programmed to fend off the Xsotan. Legends say that the manufacturer promised it would never attack non-Xsotan!"%_t,

                isUnlocked = function()
                    if Player():getValue("encyclopedia_AI_met") then return true end

                    local ai = Sector():getEntitiesByScript("aidialog.lua")
                    if ai then
                        -- RemoteInvocations_Ignore
                        invokeServerFunction("setValue", "AI_met")
                        return true
                    end

                    return false
                end
            },
            {
                title = "Bottan"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/characters/smuggler.jpg",
                text = "\\c(0d0)Bottan\\c() is an infamous smuggler, known to screw over friend and foe."%_t,

                isUnlocked = function()
                    if Player():getValue("encyclopedia_bottan_met") then return true end

                    local smuggler = Sector():getEntitiesByScript("smuggler.lua")
                    if smuggler then
                        -- RemoteInvocations_Ignore
                        invokeServerFunction("setValue", "bottan_met")
                        return true
                    end

                    return false
                end
            },
            {
                title = "The Four"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/characters/theFour_posing.jpg",
                text = "The \\c(0d0)Four\\c() are a group of ruthless scientists, trying to be the first over the Barrier. They'll try everything to get their hands on any of the exceedingly rare \\c(0d0)Xsotan Artifacts\\c()."%_t,

                isUnlocked = function()
                    if Player():getValue("encyclopedia_the4_met") then return true end

                    local the4 = Sector():getEntitiesByScript("the4.lua")
                    if the4 then
                        -- RemoteInvocations_Ignore
                        invokeServerFunction("setValue", "the4_met")
                        return true
                    end

                    return false
                end
            },
            {
                title = "The Wormhole Guardian"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/characters/wormhole_guardian.jpg",
                text = "This strange \\c(0d0)Xsotan\\c() ship seems to be guarding the center of the galaxy. It's a Xsotan mothership that can utilize the black hole's energy to open \\c(0d0)Wormholes\\c() to call more and more Xsotan reinforcements."%_t,

                isUnlocked = function()
                    if Player():getValue("encyclopedia_wormhole_met") then return true end

                    local wormholeguardian = Sector():getEntitiesByScript("wormholeguardian.lua")
                    if wormholeguardian then
                        -- RemoteInvocations_Ignore
                        invokeServerFunction("setValue", "wormhole_met")
                        return true
                    end

                    return false
                end
            },
        },
    },

    -- sorry guys, spoilers ;)
    BlackMarketEncyclopedia.getCharacters(),

}

contents.galaxyMap = category.chapters[1]
contents.stations = category.chapters[2]
contents.bulletinBoard = category.chapters[3]
contents.characters = category.chapters[4]
