package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/encyclopedia/lib/?.lua"
package.path = package.path .. ";data/scripts/encyclopedia/?.lua"
include ("stringutility")
include ("contents")

Categories = Categories or {}
category = {}

table.insert(Categories, category)

category.title = "Trade"%_t
category.chapters =
{
    {
        title = "Trading"%_t,
        id = "Trading",
        pictures =
        {
            "data/textures/ui/encyclopedia/trade/docking/dock_1.jpg",
            "data/textures/ui/encyclopedia/trade/docking/dock_2.jpg",
            "data/textures/ui/encyclopedia/trade/docking/dock_3.jpg",
            "data/textures/ui/encyclopedia/trade/docking/dock_4.jpg",
            "data/textures/ui/encyclopedia/trade/docking/dock_5.jpg",
            "data/textures/ui/encyclopedia/trade/docking/dock_6.jpg",
            "data/textures/ui/encyclopedia/trade/docking/dock_6.jpg",
        },
        fps = 2,
        text = "Stations trade with a variety of \\c(0d0)Trading Goods\\c()."%_t
        .. " " .. "Depending on the type of station, you can buy and sell various different goods."%_t
        .. " " .. "\\c(0d0)Factories\\c(), for example, usually buy ingredients and then sell the product they produce."%_t
        .."\n\n".."Use the \\c(0d0)Strategy Mode\\c() to see which stations in the sector sell or buy which goods."%_t
        .."\n".."Buy and sell them for a fine profit, or liberate them from other sources."%_t
        .. " " .. "Beware though: Stealing goods is seen as offensive and might lead to massive reputation loss!"%_t
        .."\n\n".."\\c(ddd)Note:\\c() a \\c(0d0)Trading Subsystem\\c() can list all tradeable goods and their price margins in the last visited sectors. "%_t
        .. " " .. "Read the chapter on the \\c(0d0)Trading Subsystem\\c() to learn more."%_t,
    },
    {
        title = "Trading Subsystem"%_t,
        pictures =
        {
            "data/textures/ui/encyclopedia/trade/tradingOverview/tradingOverview_1.jpg",
            "data/textures/ui/encyclopedia/trade/tradingOverview/tradingOverview_1.jpg",
            "data/textures/ui/encyclopedia/trade/tradingOverview/tradingOverview_2.jpg",
            "data/textures/ui/encyclopedia/trade/tradingOverview/tradingOverview_2.jpg",
            "data/textures/ui/encyclopedia/trade/tradingOverview/tradingOverview_3.jpg",
            "data/textures/ui/encyclopedia/trade/tradingOverview/tradingOverview_3.jpg",
            "data/textures/ui/encyclopedia/trade/tradingOverview/tradingOverview_4.jpg",
            "data/textures/ui/encyclopedia/trade/tradingOverview/tradingOverview_4.jpg",
            "data/textures/ui/encyclopedia/trade/tradingOverview/tradingOverview_5.jpg",
            "data/textures/ui/encyclopedia/trade/tradingOverview/tradingOverview_5.jpg",
            "data/textures/ui/encyclopedia/trade/tradingOverview/tradingOverview_5.jpg",
            "data/textures/ui/encyclopedia/trade/tradingOverview/tradingOverview_6.jpg",
            "data/textures/ui/encyclopedia/trade/tradingOverview/tradingOverview_6.jpg",
            "data/textures/ui/encyclopedia/trade/tradingOverview/tradingOverview_6.jpg",
        },
        fps = 2,
        text = "A \\c(0d0)Trading Subsystem\\c() allows you to get information on the economic conditions in an area that will help you make the best deals."%_t
        .."\n".."The higher the \\c(0d0)rarity\\c() of the subsystem you have installed, the more information it will give you."%_t
        .."\n".."Once you have installed it on your ship, open the \\c(0d0)Trading Overview Window\\c() which has appeared in the top right of your screen."%_t
        .."\n\n".."It not only shows you which goods can be bought or sold at which stations but you can also see the supply and demand of certain goods in the area and how this influences prices, and you can look for trade routes between stations producing certain goods."%_t
        .."\n\n".."A Trading System even allows you to look at price differences and supply and demand of certain goods on your \\c(0d0)Galaxy Map\\c()."%_t,
    },
    {
        title = "Goods"%_t,
        articles =
        {
            {
                title = "Trade goods"%_t,
                picture = "data/textures/ui/encyclopedia/trade/cargoTab_small.jpg",
                text = "All goods on your ship are shown in the \\c(0d0)Cargo Tab\\c() of the Ship Menu. There you'll find a drop-down menu where you can set your ship to either pick up or not pick up stolen goods.\n\nSmuggling and scavenging is a big problem, so military ships always scan for dangerous and illegal goods. When they catch someone, they fine them and confiscate the cargo."%_t,
            },
            {
                title = "Normal goods"%_t,
                picture = "data/textures/ui/encyclopedia/trade/goods_small.jpg",
                text = "These trade goods are freely available to everyone. They are not subject to any further restrictions."%_t,
            },
            {
                title = "Special goods"%_t,
                picture = "data/textures/ui/encyclopedia/trade/cargo_license_small.jpg",
                text = "To transport \\c(0d0)special goods\\c(), the corresponding \\c(0d0)license\\c() of the respective faction is required. With a license, special goods can be traded as if they were normal goods. When someone is caught without a license, they will be fined and their cargo confiscated."%_t,
            },
            {
                title = "Stolen goods"%_t,
                picture = "data/textures/ui/encyclopedia/trade/stolenGoods_small.jpg",
                text = "Goods are automatically branded to the faction that buys them by all certified traders found on stations. So, goods obtained by destroying or robbing ships are \\c(0d0)branded as 'stolen'\\c(). No honorable station will accept goods that are branded as 'stolen'.\n\nA special \\c(0d0)license\\c() is required to transport stolen goods. When someone is caught without a license, they will be fined and their cargo confiscated.\n\nSmugglers are said to have means of unbranding stolen cargo, but these are not exactly legal."%_t,
            },
        },
    },
    {
        title = "Supply & Demand"%_t,
        picture = "data/textures/ui/encyclopedia/trade/supply-demand.jpg",
        fps = 2,
        text = "Prices of goods are influenced by \\c(0d0)supply and demand\\c(). Supply and demand of a trading good are influenced by stations that buy or sell that good in the nearby area. High supply means low prices, and high demand means high prices.\n\nIn order to find profitable \\c(0d0)Trading Routes\\c(), you should look for areas with high supply, and transport goods to areas with low supply.\n\nDestroying or building factories will \\c(0d0)influence supply and demand\\c() of nearby areas in the long run.\n\nSupply and demand does not have an incluence on the amount of traders visiting the sector."%_t,
    },
    {
        title = "Zones"%_t,
        picture = "data/textures/ui/encyclopedia/trade/zones.jpg",
        text = "In \\c(0d0)Central Faction Areas\\c(), you'll find more factories and stations that you can trade with, than in the \\c(0d0)Outer Faction Areas\\c()."%_t
        .. "\n\n" .. "If a sector was called out as a \\c(0d0)Hazard Zone\\c(), traders will avoid that sector, making the economy in that sector grind to an almost complete halt."%_t,
    },
    {
        title = "Stations"%_t,
        articles =
        {
            {
                title = "Trading Posts"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/TradingPost.jpg",
                text = "\\c(0d0)Trading Posts\\c() buy and sell a wide variety of goods, and are always worth checking out."%_t
                .. " " .. "The goods they trade are usually the ones that are most in demand or supply, or even both."%_t
                .. "\n\n" .. "Trading Posts do not influence \\c(0d0)supply and demand\\c() rates in nearby sectors."%_t
                .. "\n\n" .. "They attract civil ships that will do business there."%_t,
            },
            {
                title = "Factories"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/Factory.jpg",
                text = "\\c(0d0)Factories\\c() produce a variety of trading goods from lower tier goods."%_t
                .. " " .. "They sell what they produce and they buy the goods they need."%_t
                .. "\n\n" .. "Factories usually have the best prices for goods, but might sometimes be harder to find."%_t
                .. "\n\n" .. "Factories influence \\c(0d0)supply and demand\\c() of their traded goods in nearby sectors."%_t
                .. " " .. "They also attract civil ships that will do business there."%_t,
            },
            {
                title = "Consumers"%_t,
                picture = "data/textures/ui/encyclopedia/exploring/stations/Casino.jpg",
                text = "\\c(0d0)Consumer stations\\c() are stations that only buy a range of products and them use them to go by their day-to-day business."%_t
                .. " " .. "Consumer stations include \\c(0d0)Casinos\\c(), \\c(0d0)Habitats\\c(), \\c(0d0)Biotopes\\c(), \\c(0d0)Military Outposts\\c(), \\c(0d0)Shipyards\\c(), \\c(0d0)Repair Docks\\c(), \\c(0d0)Equipment Docks\\c(), \\c(0d0)Research Stations\\c(), \\c(0d0)Travel Hubs\\c() and more."%_t
                .. "\n\n" .. "Consumer stations influence \\c(0d0)supply and demand\\c() of their traded goods in nearby sectors."%_t
                .. " " .. "They also attract civil ships that will do business there."%_t,
            },
        },
    },
}

contents.trading = category.chapters[1]
contents.goods = category.chapters[2]

