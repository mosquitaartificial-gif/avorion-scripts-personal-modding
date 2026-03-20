package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/encyclopedia/lib/?.lua"
package.path = package.path .. ";data/scripts/encyclopedia/?.lua"
include ("stringutility")
include ("contents")

Categories = Categories or {}
category = {}

table.insert(Categories, category)

category.title = "Combat"%_t
category.chapters =
{
    contents.armedTurrets,
    contents.unarmedTurrets,
    contents.legendaryTurrets,
    contents.fighter,
    contents.torpedos,

    {
        title = "Boarding"%_t,
        id = "Boarding",
        pictures =
            {
                "data/textures/ui/encyclopedia/combat/boarding/boarding_1.jpg",
                "data/textures/ui/encyclopedia/combat/boarding/boarding_1.jpg",
                "data/textures/ui/encyclopedia/combat/boarding/boarding_2.jpg",
                "data/textures/ui/encyclopedia/combat/boarding/boarding_2.jpg",
                "data/textures/ui/encyclopedia/combat/boarding/boarding_3.jpg",
                "data/textures/ui/encyclopedia/combat/boarding/boarding_3.jpg",
            },
        text = "Instead of destroying an enemy craft, it can be boarded."%_t
        .. " " .. "Specially trained personnel, \\c(0d0)Boarders\\c(), can be sent to the other ship with \\c(0d0)Boarding Shuttles\\c()."%_t
        .. " " .. "Boarders will kill anyone resisting and you will be able to use the ship with a new crew."%_t
        .. " " .. "As cargo doesn't tend to resist, boarding a trade ship yields a fine amount of trading goods."%_t
        .. " " .. "Other factions see Boarding as an act of war, so be prepared for declarations of war coming in after a successful boarding attempt."%_t
        .. "\n\n" .. "You can buy \\c(0d0)Boarding Shuttles\\c() at \\c(0d0)Equipment Docks\\c(). Boarders can be hired at various stations."%_t
        .. " " .. "You can also install a \\c(0d0)Scanner Subsystem\\c() to see how many boarders you'll need to successfully board a ship."%_t
        .. "\n\n" .. "\\c(ddd)Note: You can board stations as well, but they're heavily defended and have to be rebuilt afterwards.\\c()"%_t,
    },

}

contents.boarding = category.chapters[4]
