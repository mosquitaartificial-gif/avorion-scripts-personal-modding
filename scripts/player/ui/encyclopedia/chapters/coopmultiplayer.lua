package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/encyclopedia/lib/?.lua"
package.path = package.path .. ";data/scripts/encyclopedia/?.lua"
include ("stringutility")
include ("contents")

Categories = Categories or {}
category = {}

table.insert(Categories, category)

category.title = "Co-op Multiplayer"%_t
category.chapters =
{
    {   
        title = "Co-op Controls"%_t,
        picture = "data/textures/ui/encyclopedia/coop/coopControls_small.jpg",
        text = "Control alliance ships together with your friends. Define \\c(0d0)additional seats\\c() and their \\c(0d0)roles\\c() in the \\c(0d0)Co-op Control Menu\\c()!\n\nNote: \"Fly Crafts\" permission is necessary. Check your alliance’s rank permissions if you can't enter alliance ships."%_t,
    }, 
    {
        title = "Alliance"%_t,
        picture = "data/textures/ui/encyclopedia/coop/foundAlliance_small.jpg",
        text = "Play together with your friends as an \\c(0d0)Alliance\\c(). If you don't have an alliance yet, you can create one in the \\c(0d0)Player Menu\\c()."%_t,

        articles =
        {
            {
                title = "Members"%_t,
                picture = "data/textures/ui/encyclopedia/coop/memberAlliance_small.jpg",
                text = "Additional members can be invited in the \\c(0d0)Alliance Members Tab\\c(). The tab also contains an overview of all current members and their respective ranks."%_t,
            },
            {
                title = "Alliance Fleet"%_t,
                picture = "data/textures/ui/encyclopedia/coop/allianceFleet_small.jpg",
                text = "Ships and stations can be transferred to the alliance either immediately while founding them or later in the Player Menu. The \\c(0d0)transferred ships\\c() are managed by the alliance, i.e. all loot collected while flying them belongs to the alliance and all fees, including the crew salaries, are paid by the alliance."%_t,
            },
            {
                title = "Alliance Vault"%_t,
                picture = "data/textures/ui/encyclopedia/coop/allianceVault_small.jpg",
                text = "An alliance has its own \\c(0d0)inventory\\c() with materials, money, weapons and subsystems. Players can donate their own items or collect items while flying an alliance ship.\n\n\\c(dd5)Warning: every member with appropriate permissions can take resources and items out of the alliance vault!\\c()"%_t,
            },
        },
    },
    {
        title = "Group"%_t,
        picture = "data/textures/ui/encyclopedia/coop/group.jpg",
        text = "Forming a \\c(0d0)Group\\c() can come in handy while playing with friends. Your friends will be highlighted more visibly while in the same sector and marked with a pale green frame on the map. In the top left corner of the screen their ship health or current sector will be displayed. Found a group by typing \\c(0d0)\"/invite\"\\c() and the player's name into the chat."%_t,
    },
}

contents.coopControls = category.chapters[1]
contents.alliance = category.chapters[2]
contents.group = category.chapters[3]
