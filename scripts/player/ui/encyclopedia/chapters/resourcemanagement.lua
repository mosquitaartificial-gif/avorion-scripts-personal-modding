package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/encyclopedia/lib/?.lua"
package.path = package.path .. ";data/scripts/encyclopedia/?.lua"
include ("stringutility")
include ("contents")
local BlackMarketEncyclopedia = include ("internal/dlc/blackmarket/public/encyclopedia.lua")

Categories = Categories or {}
category = {}

table.insert(Categories, category)

local titaniumLastTick = nil


category.title = "Resource Management"%_t
category.chapters =
{
    {
        title = "Credits"%_t,
        picture = "data/textures/ui/encyclopedia/resourcemanagement/credits.jpg",
        text = "\\c(0d0)Credits\\c() are the Galactic currency accepted by everybody. There are a number of ways that you can generate money:"%_t
        .. "\n\n" .. "Selling \\c(0d0)Resources:\\c() Mine asteroids and sell the materials to a \\c(0d0)Resource Depot\\c()"%_t
        .. "\n" .. "Collecting \\c(0d0)Loot\\c(): When enemy ships are defeated they drop loot which you can sell at stations."%_t
        .. "\n" .. "Completing \\c(0d0)Missions\\c(): Accept tasks at stations' bulletin boards. You will be paid on completion."%_t
        .. "\n" .. "\\c(0d0)Trading\\c(): Buy trading goods and sell them again for a higher price to make profit."%_t
        .. "\n" .. "Founding \\c(0d0)Stations\\c(): Most stations produce goods and will automatically sell them, generating income for you."%_t
        .. "\n" .. "Selling \\c(0d0)Asteroids\\c(): Some asteroids in the galaxy are larger than others, and definitely worth having."%_t
        .. " " .. "After claiming one of them you can found a mine on it to extract goods or you can sell it to a nearby faction for a huge sum."%_t,
    },
    {
        title = "Mining"%_t,
        pictures =
        {
            "data/textures/ui/encyclopedia/resourcemanagement/mining/mine_1.jpg",
            "data/textures/ui/encyclopedia/resourcemanagement/mining/mine_2.jpg",
            "data/textures/ui/encyclopedia/resourcemanagement/mining/mine_3.jpg",
            "data/textures/ui/encyclopedia/resourcemanagement/mining/mine_4.jpg",
            "data/textures/ui/encyclopedia/resourcemanagement/mining/mine_5.jpg",
            "data/textures/ui/encyclopedia/resourcemanagement/mining/mine_6.jpg",
            "data/textures/ui/encyclopedia/resourcemanagement/mining/mine_7.jpg",
            "data/textures/ui/encyclopedia/resourcemanagement/mining/mine_8.jpg",
            "data/textures/ui/encyclopedia/resourcemanagement/mining/mine_9.jpg",
            "data/textures/ui/encyclopedia/resourcemanagement/mining/mine_9.jpg",
        },
        fps = 2,
        text = "To mine asteroids, special \\c(0d0)Mining Lasers\\c() are necessary."%_t
        .. " " .. "They will be able to extract materials from asteroids."%_t
        .. " " .. "Most asteroids that are worth mining can be recognized by the colorful material residue on their surface."%_t
        .. " " .. "Only a very small percentage of the bland looking asteroids may have resources hidden inside of them and it is generally not worth mining non-resource asteroids."%_t
        .. " " .. "To find asteroids with hidden resources, install an \\c(0d0)Object Detector Subsystem\\c()."%_t
        .. "\n\n" .. "All \\c(0d0)Mining Lasers\\c() are made for specific materials and are only capable of mining the next higher and all lower materials."%_t
        .. "\n\n" .. "There are \\c(0d0)Refining Mining Lasers\\c() and \\c(0d0)Raw Mining Lasers\\c()."%_t
        .. " " .. "To learn more about them, read the chapter on \\c(0d0)Refining\\c()."%_t,
    },
    {
        title = "R-Mining"%_t,
        id = "RMining",
        pictures =
        {
            "data/textures/ui/encyclopedia/resourcemanagement/r-mining.jpg",
        },
        fps = 2,
        text = "Raw Mining Lasers (or short: \\c(0d0)R-Mining Lasers\\c()) are a special kind of Mining Laser."%_t
                .. " " .. "They deal \\c(0d0)more damage\\c() and have a \\c(0d0)higher efficiency\\c(), but won't refine materials on the spot."%_t
                .. " " .. "Instead, they'll only break down asteroids into bits of \\c(0d0)ore\\c()."%_t
                .. " " .. "It is thanks to their simplicity, that they have a way higher efficiency when it comes to collecting materials."%_t
                .. "\n\n" .. "The ores you collect won't be stored in your bank immediately, but in your \\c(0d0)Cargo Bay\\c(), so to effectively mine with these lasers, \\c(0d0)Cargo Blocks\\c() are required on the ship."%_t
                .. "\n\n" .. "The ores can then later be refined at a \\c(0d0)Resource Depot\\c()'s refinery into normal materials."%_t,
    },
    {
        title = "Salvaging"%_t,
        pictures =
        {
            "data/textures/ui/encyclopedia/resourcemanagement/salvaging/salvaging_1_small.jpg",
            "data/textures/ui/encyclopedia/resourcemanagement/salvaging/salvaging_2_small.jpg",
            "data/textures/ui/encyclopedia/resourcemanagement/salvaging/salvaging_3_small.jpg",
            "data/textures/ui/encyclopedia/resourcemanagement/salvaging/salvaging_4_small.jpg",
            "data/textures/ui/encyclopedia/resourcemanagement/salvaging/salvaging_5_small.jpg",
            "data/textures/ui/encyclopedia/resourcemanagement/salvaging/salvaging_1_small.jpg",
        },
        fps = 2,
        text = "Special \\c(0d0)Salvaging Lasers\\c() allow to extract materials and equipment from wreckages."%_t
        .. "\n\n" .. "All \\c(0d0)Salvaging Lasers\\c() are made for specific materials and are only capable of scrapping the next higher and all lower materials."%_t
        .. "\n\n" .. "There are \\c(0d0)Refining Salvaging Lasers\\c() and \\c(0d0)Raw Salvaging Lasers\\c()."%_t
        .. "\n\n" .. "To learn more about them, read the chapter on \\c(0d0)Refining\\c()."%_t,
    },
    {
        title = "Refining"%_t,
        picture = "data/textures/ui/encyclopedia/resourcemanagement/refining.jpg",
        text = "Some \\c(0d0)Mining Lasers\\c() and \\c(0d0)Salvaging Lasers\\c() are able to directly extract resources from asteroids or wrecks."%_t
        .. "\n\n" .. "These are called \\c(0d0)Refining\\c() because they can refine the materials dropped from the object."%_t
        .. " " .. "However, this requires a lot of energy and makes them significantly less effective than \\c(0d0)Raw\\c() Mining or Salvaging Lasers."%_t
        .. "\n\n" .. "Those can extract the metal ores and scrap metals very quickly, but your ship will have to collect and store the unrefined metals and it will need a \\c(0d0)Cargo Bay\\c() to do so."%_t
        .. " " .. "Scrap metals can be \\c(0d0)refined\\c() at a \\c(0d0)Resource Depot\\c() (for a small fee)."%_t,
    },
    {
        title = "Materials"%_t,
        picture = "data/textures/ui/encyclopedia/resourcemanagement/materials/materials_UI_small.jpg",
        text = "Now that Avorion has been discovered, there are seven known materials. These seven materials can be used to build and repair ships. Collect them by \\c(0d0)Mining\\c(), \\c(0d0)Salvaging\\c() or buy them at a \\c(0d0)Resource Depot\\c()."%_t,
        articles =
        {
            {
                title = "Iron"%_t,
                picture = "data/textures/ui/encyclopedia/resourcemanagement/materials/iron.jpg",
                text = "\\c(0d0)Iron\\c() is the simplest material."%_t
                .. " " .. "It's heavy but very easy to form, so blocks made from Iron don't cost a lot of money, but ships made from Iron are rather weak and heavy and thus won't steer very well."%_t
                .. "\n" .. "Only basic necessities can be built from Iron, but Iron is the only known material that can be used for building \\c(0d0)Inertia Dampeners\\c()."%_t
                .. "\n" .. "Iron can be found in large quantities at the edge of the galaxy."%_t
                .. "\n\n" .. "To build blocks with this material, you need to have \\c(0d0)Building Knowledge\\c() about it."%_t
                .. "\n\n" .. "Check out the block tooltips in \\c(0d0)Building Mode\\c() for more information about the specific blocks!"%_t,

                isUnlocked = function()
                    if Player():getValue("encyclopedia_iron_found") then return true end

                    local res = {Player():getResources()}

                    if res[MaterialType.Iron+1] > 0 then
                        -- RemoteInvocations_Ignore
                        invokeServerFunction("setValue", "iron_found")
                        return true
                    end

                    return false
                end
            },
            {
                title = "Titanium"%_t,
                id = "Titanium",
                picture = "data/textures/ui/encyclopedia/resourcemanagement/materials/titanium.jpg",
                text = "\\c(0d0)Titanium\\c() is a very light material and more durable than Iron."%_t
                .. "\n\n" .. "It has better energy properties than Iron, making it possible to build \\c(0d0)Energy Generators\\c(), \\c(0d0)Batteries\\c() and \\c(0d0)Integrity Field Generators\\c()."%_t
                .. "\n" .. "In the outer regions of the galaxy, Titanium is the preferred material to build ships."%_t
                .. "\n" .. "Titanium can be found nearly anywhere in the galaxy, even in the outermost rim of the galaxy."%_t
                .. "\n\n" .. "To build blocks with this material, you need to have \\c(0d0)Building Knowledge\\c() about it."%_t
                .. " " .. "Maybe your new contact, \\c(0d0)the Adventurer\\c(), can help you out here?"%_t
                .. "\n\n" .. "Check out the block tooltips in \\c(0d0)Building Mode\\c() for more information about the specific blocks!"%_t,

                isUnlocked = function()
                    if Player():getValue("encyclopedia_titanium_found") then return true end

                    local res = {Player():getResources()}
                    local titanium = res[MaterialType.Titanium+1]
                    titaniumLastTick = titaniumLastTick or titanium

                    -- don't let encyclopedia pop up in fight
                    if Encyclopedia.checkIfInFight() or Hud().tutorialActive then
                        titaniumLastTick = titanium
                        return false
                    end

                    if titanium ~= titaniumLastTick then
                        -- RemoteInvocations_Ignore
                        invokeServerFunction("setValue", "titanium_found")

                        Encyclopedia.deferredShowEncyclopediaArticle("Titanium")
                        return true
                    end

                    titaniumLastTick = titanium
                    return false
                end
            },
            {
                title = "Naonite"%_t,
                id = "Naonite",
                picture = "data/textures/ui/encyclopedia/resourcemanagement/materials/naonite.jpg",
                text = "\\c(0d0)Naonite\\c() is a little heavier than Titanium, but it is even more durable."%_t
                .. " " .. "With Naonite you gain access to \\c(0d0)Shield Generators\\c() and \\c(0d0)Hyperspace Cores\\c()."%_t
                .. " " .. "Unfortunately Naonite armor tends to break easily and is no longer available for purchase."%_t
                .. "\n" .. "Naonite starts to appear at a distance of about 350 sectors to the galaxy core, and closer."%_t
                .. "\n\n" .. "To build blocks with this material, you need to have \\c(0d0)Building Knowledge\\c() about it."%_t
                .. "\n\n" .. "Check out the block tooltips in \\c(0d0)Building Mode\\c() for more information about the specific blocks!"%_t,

                isUnlocked = function()
                    if Player():getValue("encyclopedia_naonite_found") then return true end

                    -- don't let encyclopedia pop up in fight
                    if Encyclopedia.checkIfInFight() then return false end
                    if Hud().tutorialActive then return false end

                    local res = {Player():getResources()}

                    if res[MaterialType.Naonite+1] > 0 then
                        -- RemoteInvocations_Ignore
                        invokeServerFunction("setValue", "naonite_found")

                        Encyclopedia.deferredShowEncyclopediaArticle("Naonite")
                        return true
                    end

                    return false
                end
            },
            {
                title = "Trinium"%_t,
                picture = "data/textures/ui/encyclopedia/resourcemanagement/materials/trinium.jpg",
                text = "\\c(0d0)Trinium\\c() has the perfect combination of lightness and durability."%_t
                .. " " .. "Ships built from Trinium tend to be very nimble and \\c(0d0)Hangar Blocks\\c() allow the usage of fighters."%_t
                .. " " .. "Pair the Hangar with an \\c(0d0)Assembly Block\\c() to produce fighters on the ship."%_t
                .. " " .. "To increase ship processing power, and with that the ability to install more subsystems, \\c(0d0)Computer Cores\\c() can be added."%_t
                .. " " .. "And last, but not least, Trinium allows to build an \\c(0d0)Academy\\c() to train your crew members."%_t
                .. "\n" .. "Trinium can be found at about half way between the galaxy’s edge and its core."%_t
                .. "\n\n" .. "To build blocks with this material, you need to have \\c(0d0)Building Knowledge\\c() about it."%_t
                .. "\n\n" .. "Check out the block tooltips in \\c(0d0)Building Mode\\c() for more information about the specific blocks!"%_t,

                isUnlocked = function()
                    if Player():getValue("encyclopedia_trinium_found") then return true end

                    local res = {Player():getResources()}

                    if res[MaterialType.Trinium+1] > 0 then
                        -- RemoteInvocations_Ignore
                        invokeServerFunction("setValue", "trinium_found")
                        return true
                    end

                    return false
                end
            },
            {
                title = "Xanion"%_t,
                picture = "data/textures/ui/encyclopedia/resourcemanagement/materials/xanion.jpg",
                text = "\\c(0d0)Xanion\\c() is the last material that is still known to the civilizations around the Barrier."%_t
                .. " " .. "It's quite a bit more durable than Trinium but has more weight to it."%_t
                .. " " .. "It lacks Armor Blocks, but has very good technical properties and lets you build \\c(0d0)Transporter Blocks\\c() that increase a ship's docking range."%_t
                .. " " .. "The M.A.D. association recently invented \\c(0d0)Cloning Pods\\c()."%_t
                .. " " .. "Research is still ongoing, but the M.A.D. association has successfully shown that cloned crew members are indistinguishable from natural ones."%_t
                .. "\n" .. "Xanion can be found around the Barrier to the galaxy core."%_t
                .. "\n\n" .. "To build blocks with this material, you need to have \\c(0d0)Building Knowledge\\c() about it."%_t
                .. "\n\n" .. "Check out the block tooltips in \\c(0d0)Building Mode\\c() for more information about the specific blocks!"%_t,

                isUnlocked = function()
                    if Player():getValue("encyclopedia_xanion_found") then return true end

                    local res = {Player():getResources()}

                    if res[MaterialType.Xanion+1] > 0 then
                        -- RemoteInvocations_Ignore
                        invokeServerFunction("setValue", "xanion_found")
                        return true
                    end

                    return false
                end
            },
            {
                title = "Ogonite"%_t,
                picture = "data/textures/ui/encyclopedia/resourcemanagement/materials/ogonite.jpg",
                text = "\\c(0d0)Ogonite\\c() is very heavy, but at the same time very durable!"%_t
                .. " " .. "While many of the technical blocks aren't available in Ogonite, it shines in the \\c(0d0)Armor\\c() department."%_t
                .. " " .. "Ships built from Ogonite will be heavy and not at all nimble, but shrug off most attacks with ease."%_t
                .. "\n" .. "Ogonite can be found beyond the Barrier, not far into the center."%_t
                .. "\n\n" .. "To build blocks with this material, you need to have \\c(0d0)Building Knowledge\\c() about it."%_t
                .. "\n\n" .. "Check out the block tooltips in \\c(0d0)Building Mode\\c() for more information about the specific blocks!"%_t,

                isUnlocked = function()
                    if Player():getValue("encyclopedia_ogonite_found") then return true end

                    local res = {Player():getResources()}

                    if res[MaterialType.Ogonite+1] > 0 then
                        -- RemoteInvocations_Ignore
                        invokeServerFunction("setValue", "ogonite_found")
                        return true
                    end

                    return false
                end
            },
            {
                title = "Avorion"%_t,
                picture = "data/textures/ui/encyclopedia/resourcemanagement/materials/avorion.jpg",
                text = "\\c(0d0)Avorion\\c() is a light material with very good energy characteristics, and the material preferred by the Xsotan for building their ships."%_t
                .. " " .. "\\c(0d0)Hyperspace Cores\\c() built from Avorion even let you traverse the Great Barrier!"%_t
                .. "\n" .. "Avorion can be found in the very center of the galaxy."%_t
                .. "\n\n" .. "To build blocks with this material, you need to have \\c(0d0)Building Knowledge\\c() about it."%_t
                .. "\n\n" .. "Check out the block tooltips in \\c(0d0)Building Mode\\c() for more information about the specific blocks!"%_t,

                isUnlocked = function()
                    if Player():getValue("encyclopedia_avorion_found") then return true end

                    local res = {Player():getResources()}

                    if res[MaterialType.Avorion+1] > 0 then
                        -- RemoteInvocations_Ignore
                        invokeServerFunction("setValue", "avorion_found")
                        return true
                    end

                    return false
                end
            },
        },
    },
    {
        title = "Rift Research Data"%_t,
        picture = "data/textures/ui/encyclopedia/resourcemanagement/research-data.jpg",
        text = "Scientists at the \\c(0d0)Rift Research Centers\\c() are always on the lookout for new research data from \\c(0d0)Rifts\\c()."%_t
        .. "\n\n" .. "The data is collected in rifts by destroying Xsotan or scanning special objects. However, the yield can be significantly increased using a \\c(0d0)Scientist Captain\\c()."%_t
        .. " " .. "These captains collect data passively while commanding a ship."%_t
        .. "\n\n" .. "At a Rift Research Center, they can be exchanged for special \\c(0d0)Hybrid\\c() or \\c(0d0)Protective Subsystems\\c()."%_t
        .. " " .. "Rift Research Data can also be sold for credits at Rift Research Centers and Smuggler's Markets."%_t,
    },
}

contents.mining = category.chapters[1]
contents.salvaging = category.chapters[2]
contents.materials = category.chapters[3]
