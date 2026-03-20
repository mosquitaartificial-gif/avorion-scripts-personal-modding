package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/encyclopedia/lib/?.lua"
package.path = package.path .. ";data/scripts/encyclopedia/?.lua"
include ("stringutility")
include ("contents")

Categories = Categories or {}
category = {}

table.insert(Categories, category)

category.title = "Diplomacy"%_t
category.chapters =
{
    {
        title = "General"%_t,
        picture = "data/textures/ui/encyclopedia/diplomacy/general.jpg",
        text = "Most commonly the relation between factions can be categorized as one of the following: \\c(0d0)at War\\c(), in a \\c(0d0)Ceasefire\\c(), \\c(0d0)at Peace\\c() or \\c(0d0)Allied\\c().\n\nFactions at war tend to fight each other at every opportunity, while factions in a ceasefire tolerate each other. But any hostile act can cause another outbreak of war.\nFactions at peace tend to be more relaxed around each other. While hostile acts, like damaging property, are still seen as offensive, they rarely lead to open fights. After signing an alliance treaty, the factions involved should be seen as one. Traditionally allied factions help each other as much as they can, especially in combat. Quite a few faction wars have been won through cleverly choosing allies."%_t,
    },
    {
        title = "Relations"%_t,
        picture = "data/textures/ui/encyclopedia/diplomacy/relations.jpg",
        text = "\\c(0d0)Relations\\c() define the behavior between two factions. The better the relations, the more \\c(0d0)access to technologies and goods\\c() will be granted. Access to all of the supplies, including equipment of the highest rarity, will only be granted to allies.\n\nThe \\c(0d0)Player Menu's Diplomacy Tab\\c() shows an overview over the relation you have to a faction as well as their \\c(0d0)Faction Traits\\c(). For example an aggressive faction will have more combat ships that they'll send out to help their allies. Peaceful factions tend to have less combat ready ships."%_t,
    },
    {
        title = "Negotiation"%_t,
        picture = "data/textures/ui/encyclopedia/diplomacy/negotiate.jpg",
        text = "To improve \\c(0d0)Relations\\c() with another faction, offer to \\c(0d0)pay tribute\\c(). This tribute can be any combination of resources and money and should at least meet the faction's lower limit. A more generous bid will always gladly be taken, while factions might lose patience if they deem the tribute to meager.\n\nWhen negotiating \\c(0d0)treaties\\c() between factions, such as a permanent \\c(0d0)ceasefire\\c() or a motion to \\c(0d0)become allied\\c(), it is expected to bring gifts as well. Just like a normal tribute, a treaty tribute can be any combination of money and resources."%_t,
    },
}

contents.diplomacy = category.chapters[1]
