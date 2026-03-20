package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/encyclopedia/lib/?.lua"
package.path = package.path .. ";data/scripts/encyclopedia/?.lua"
include ("stringutility")
include ("contents")

Categories = Categories or {}
category = {}

table.insert(Categories, category)

category.title = "Building"%_t
category.chapters =
{
    {
        title = "Founding a Ship"%_t,
        pictures =
        {
            "data/textures/ui/encyclopedia/building/foundingship/screen10.jpg",
            "data/textures/ui/encyclopedia/building/foundingship/screen10_red.jpg",
            "data/textures/ui/encyclopedia/building/foundingship/screen11_red.jpg",
            "data/textures/ui/encyclopedia/building/foundingship/screen12.jpg",
            "data/textures/ui/encyclopedia/building/foundingship/screen13_red.jpg",
            "data/textures/ui/encyclopedia/building/foundingship/screen14.jpg",
            "data/textures/ui/encyclopedia/building/foundingship/screen14.jpg",
        },
        fps = 1,
        text = "Click on the flag icon (\\c(0d0)\"Found Ship\"\\c()) in the upper right corner to found a ship. Founding a ship this way will create a \\c(0d0)base block\\c() and add a \\c(0d0)base crew\\c(). Use this base block to build your ship."%_t,
    },
    {
        title = "Building Mode"%_t,
        id = "BuildingMode",
        articles =
        {
            {
                title = "About the Building Mode"%_t,
                picture = "data/textures/ui/encyclopedia/building/controls/01.jpg",
                fps = 2,
                text = "The \\c(0d0)Building Mode\\c() is the place where you build your ships!"%_t
                .. " " .. "Here you can attach \\c(0d0)turrets\\c(), build it larger or smaller, add some color, or just use a preexisting ship design."%_t
                .. " " .. "The Building Mode is very powerful and can feel a little overwhelming at the start, but this Encyclopedia has got you covered!"%_t
                .. "\n\n" .. "You can also \\c(0d0)repair\\c() your ship in the Building Mode, but that's a lot more expensive than at a \\c(0d0)Repair Dock\\c()."%_t
                .. "\n\n" .. "Keep in mind that you'll need \\c(0d0)Building Knowledge\\c() to build with the different materials."%_t,
            },
            {
                title = "Basic Controls"%_t,
                pictures =
                {
                    "data/textures/ui/encyclopedia/building/controls/01.jpg",
                    "data/textures/ui/encyclopedia/building/controls/02.jpg",
                    "data/textures/ui/encyclopedia/building/controls/03.jpg",
                    "data/textures/ui/encyclopedia/building/controls/04.jpg",
                    "data/textures/ui/encyclopedia/building/controls/05.jpg",
                    "data/textures/ui/encyclopedia/building/controls/06.jpg",
                    "data/textures/ui/encyclopedia/building/controls/07.jpg",
                    "data/textures/ui/encyclopedia/building/controls/08.jpg",
                    "data/textures/ui/encyclopedia/building/controls/09.jpg",
                    "data/textures/ui/encyclopedia/building/controls/10.jpg",
                    "data/textures/ui/encyclopedia/building/controls/11.jpg",
                    "data/textures/ui/encyclopedia/building/controls/12.jpg",
                    "data/textures/ui/encyclopedia/building/controls/13.jpg",
                    "data/textures/ui/encyclopedia/building/controls/14.jpg",
                    "data/textures/ui/encyclopedia/building/controls/14.jpg",
                    "data/textures/ui/encyclopedia/building/controls/14.jpg",
                },
                fps = 2,
                text = "Open \\c(0d0)Building Mode\\c() by pressing \\c(fff)[${openBuild}]\\c() or use the hammer icon in the top right corner.\n\nIf you want to see all available \\c(0d0)blocks\\c(), hold \\c(fff)[${inventory}]\\c(). All blocks can be \\c(0d0)scaled\\c() in any direction by holding \\c(fff)[${W}]\\c(), \\c(fff)[${A}]\\c(), \\c(fff)[${S}]\\c(), \\c(fff)[${D}]\\c() and moving the mouse.\n\nSelect a block that is already on your ship by using \\c(fff)[${select}]\\c() and multiple blocks by holding down \\c(fff)[CTRL]\\c() and using \\c(fff)[${select}]\\c(). To rotate the block you'd like to place, press \\c(fff)[${rotate}]\\c().\n\nIf you don't know how to do something, press \\c(fff)[${short}]\\c() to get an overview of all \\c(0d0)building shortcuts\\c()!"%_t
                        % {
                            openBuild = GameInput():getKeyName(ControlAction.BuildingMode),
                            movCam = GameInput():getKeyName(ControlAction.MoveCamera),
                            inventory = GameInput():getKeyName(ControlAction.ShowInventory),
                            W = GameInput():getKeyName(ControlAction.ScaleBlockLinear),
                            A = GameInput():getKeyName(ControlAction.ScaleBlockX),
                            S = GameInput():getKeyName(ControlAction.ScaleBlockY),
                            D = GameInput():getKeyName(ControlAction.ScaleBlockZ),
                            select = GameInput():getKeyName(ControlAction.SelectTarget),
                            rotate = GameInput():getKeyName(ControlAction.RotateBlocks),
                            short = GameInput():getKeyName(ControlAction.ShowServerInfo)
                        },

            },
            {
                title = "Camera"%_t,
                pictures =
                {
                    "data/textures/ui/encyclopedia/building/camera/camera_2.jpg",
                    "data/textures/ui/encyclopedia/building/camera/camera_2.jpg",
                    "data/textures/ui/encyclopedia/building/camera/camera_3.jpg",
                    {path = "data/textures/ui/encyclopedia/building/camera/camera_3.jpg", showLabel = true, caption = "[" .. GameInput():getKeyName(ControlAction.FocusBlock) .. "]"},
                    "data/textures/ui/encyclopedia/building/camera/camera_4.jpg",
                    "data/textures/ui/encyclopedia/building/camera/camera_4.jpg",
                },
                text = "In \\c(0d0)Building Mode\\c() you can move the camera by pressing \\c(fff)[${movCam}]\\c() and moving the mouse, turning it around the center of your ship."%_t % {movCam=GameInput():getKeyName(ControlAction.MoveCamera)}
                .. "\n\n" .. "If you would like to have a different block as the center, select that block and press \\c(fff)[${focus}]\\c(). If you select more than one block and press \\c(fff)[${focus}]\\c(), the focus will be exactly between those blocks.\nYou can also use the \\c(fff)arrow keys\\c() to move the focus of the camera."%_t % {focus=GameInput():getKeyName(ControlAction.FocusBlock)}
                .. "\n\n" .. "To move the focus back to the center of your ship, deselect everything and press \\c(fff)[${focus}]\\c() again."%_t % {focus=GameInput():getKeyName(ControlAction.FocusBlock)},
            },
            {
                title = "Placing Turrets"%_t,
                pictures =
                {
                    "data/textures/ui/encyclopedia/building/buildTurrets/turrets_1.jpg",
                    "data/textures/ui/encyclopedia/building/buildTurrets/turrets_1_red.jpg",
                    "data/textures/ui/encyclopedia/building/buildTurrets/turrets_1_red.jpg",
                    "data/textures/ui/encyclopedia/building/buildTurrets/turrets_2.jpg",
                    "data/textures/ui/encyclopedia/building/buildTurrets/turrets_3.jpg",
                    "data/textures/ui/encyclopedia/building/buildTurrets/turrets_3.jpg",
                    "data/textures/ui/encyclopedia/building/buildTurrets/turrets_4.jpg",
                    "data/textures/ui/encyclopedia/building/buildTurrets/turrets_4.jpg",
                    "data/textures/ui/encyclopedia/building/buildTurrets/turrets_5.jpg",
                    "data/textures/ui/encyclopedia/building/buildTurrets/turrets_5.jpg",
                },
                text = "To add \\c(0d0)turrets\\c() to your ship, select a turret from the \\c(0d0)Turret Window\\c() on the left."%_t
                .. "\n\n" .. "All turrets you own are listed there. You can only place turrets on blocks made up of a material at least as high as that of the turret."%_t
                .. "\n\n" .. "Every ship only has a certain number of turret slots."%_t
                .. " " .. "You can see that number in the ship stats on the right and you can increase it by installing certain \\c(0d0)subsystems\\c()."%_t
                .. "\n\n" .. "If you want to replace a turret that is already on your ship, hold \\c(fff)[Left SHIFT]\\c() and place the new turret onto the old one."%_t,
            },
            {
                title = "Changing Colors"%_t,
                pictures =
                {
                    "data/textures/ui/encyclopedia/building/colors/coloring_1.jpg",
                    "data/textures/ui/encyclopedia/building/colors/coloring_1_red.jpg",
                    "data/textures/ui/encyclopedia/building/colors/coloring_1_red.jpg",
                    "data/textures/ui/encyclopedia/building/colors/coloring_2_red.jpg",
                    "data/textures/ui/encyclopedia/building/colors/coloring_2_red.jpg",
                    "data/textures/ui/encyclopedia/building/colors/coloring_5.jpg",
                    "data/textures/ui/encyclopedia/building/colors/coloring_5.jpg",
                    "data/textures/ui/encyclopedia/building/colors/coloring_4_red.jpg",
                    "data/textures/ui/encyclopedia/building/colors/coloring_4_red.jpg",
                    "data/textures/ui/encyclopedia/building/colors/coloring_6.jpg",
                    "data/textures/ui/encyclopedia/building/colors/coloring_6.jpg",
                },
                text = "To change colors, select the \\c(0d0)Color Brush\\c() on the left."%_t
                .. "\n\n" .. "It is possible to select all blocks of a certain color by choosing \\c(fff)'Select All Blocks with the Current Color'\\c() and then transform all selected blocks to a different color with \\c(fff)'Apply Current Color to Selection'\\c()."%_t
                .. "\n\n" .. "While using the \\c(0d0)Color Brush\\c(), you can use \\c(fff)[CTRL] + [C]\\c() to select the color of that block and then \\c(fff)[CTRL] + [V]\\c() to use it on another block."%_t,
            },
            {
                title = "Saving Ships"%_t,
                pictures =
                {
                    "data/textures/ui/encyclopedia/building/savedDesigns/building-mode.jpg",
                    "data/textures/ui/encyclopedia/building/savedDesigns/designs-button-highlight.jpg",
                    "data/textures/ui/encyclopedia/building/savedDesigns/saved-design.jpg",
                    "data/textures/ui/encyclopedia/building/savedDesigns/saved-design.jpg",
                    "data/textures/ui/encyclopedia/building/savedDesigns/mergeBlocks.jpg",
                    "data/textures/ui/encyclopedia/building/savedDesigns/mergeBlocks.jpg",
                },
                text = "By default your ship design will automatically be saved if you leave \\c(0d0)Building Mode\\c(). You can find these auto saves in the \\c(0d0)Saved Designs\\c() menu on the left side.\nYou can also save your ship design manually. All saved designs will be available as designs throughout the game."%_t
                .. "\n\n" .. "If you don't want your ship designs to be saved automatically you can turn this off in the \\c(fff)Main Menu\\c() under \\c(fff)Settings\\c() -> \\c(fff)Game\\c()."%_t,
            },
            {
                title = "Repairing"%_t,
                pictures =
                {
                    "data/textures/ui/encyclopedia/building/repairing/repair_1.jpg",
                    "data/textures/ui/encyclopedia/building/repairing/repair_1_red.jpg",
                    "data/textures/ui/encyclopedia/building/repairing/repair_1_red.jpg",
                    "data/textures/ui/encyclopedia/building/repairing/repair_2.jpg",
                    "data/textures/ui/encyclopedia/building/repairing/repair_2_red_1.jpg",
                    "data/textures/ui/encyclopedia/building/repairing/repair_2_red_1.jpg",
                    "data/textures/ui/encyclopedia/building/repairing/repair_2_red_2.jpg",
                    "data/textures/ui/encyclopedia/building/repairing/repair_2_red_2.jpg",
                },
                text = "If your ship gets damaged, you can repair it in \\c(0d0)Building Mode\\c().\nHowever, it is much more expensive than what an \\c(0d0)Repair Dock\\c() would charge you for the same repairs!"%_t
                .. "\n\n" .. "You cannot edit a damaged ship, which means that you may have to repair your ship on site if it doesn't steer properly any more."%_t
                .. " " .. "In this case you can \\c(0d0)repair\\c() only the missing blocks, which is much cheaper."%_t
                .. "\n\n" .. "If you don't have enough money for those preliminary repairs, you can also \\c(0d0)discard\\c() the missing blocks to be able to edit your ship again."%_t
                .. " " .. "They will then be permanently deleted from your ship design."%_t,
            },
        },
    },
    {
        title = "Building Knowledge"%_t,
        id = "BuildingKnowledge",
        pictures =
        {
            "data/textures/ui/encyclopedia/building/building-knowledge/01.jpg",
            "data/textures/ui/encyclopedia/building/building-knowledge/01.jpg",
            "data/textures/ui/encyclopedia/building/building-knowledge/02.jpg",
            "data/textures/ui/encyclopedia/building/building-knowledge/02.jpg",
            "data/textures/ui/encyclopedia/building/building-knowledge/03.jpg",
            "data/textures/ui/encyclopedia/building/building-knowledge/03.jpg",
        },
        text = "To use the various \\c(0d0)Materials\\c() that you can find, you need the appropriate \\c(0d0)Building Knowledge\\c()."%_t
        .. " " .. "In addition to better materials, higher-tier building knowledge also allows you to build ships that support more \\c(0d0)Processing Power\\c() and thus \\c(0d0)Subsystem Sockets\\c()."%_t
        .. "\n\n" .. "One way to get building knowledge is to buy it at a \\c(0d0)Shipyard\\c() that's in the respective material area - if you want \\c(0d0)Naonite\\c() knowledge, you should find a shipyard that's in an area where you can find lots of Naonite."%_t
        .. " " .. "This requires quite good relations to that faction though."%_t
        .. "\n\n" .. "Another way to get the building knowledge is to clear a \\c(0d0)Pirate Sector\\c() in the respective area."%_t
        .. " " .. "They must have built their ships somehow..."%_t,
    },
    {
        title = "Processing Power"%_t,
        id = "ProcessingPower",
        pictures =
        {
            "data/textures/ui/encyclopedia/building/processing-power/01.jpg",
            "data/textures/ui/encyclopedia/building/processing-power/02.jpg",
            "data/textures/ui/encyclopedia/building/processing-power/01.jpg",
        },
        text = "The \\c(0d0)Processing Power\\c() of a ship determines the amount of \\c(0d0)Subsystem Sockets\\c() it supports."%_t
        .. " " .. "To increase the processing power of your ships, add \\c(0d0)Functional Blocks\\c() to your ship."%_t
        .. " " .. "Functional Blocks will contribute to the amount of processing power of your ship."%_t
        .. " " .. "You can see which blocks exactly are Functional Blocks in the \\c(0d0)Building Mode\\c()."%_t
        .. "\n\n" .. "If you reach the maximum limit of processing power on your ship, you can still add \\c(0d0)Non-Functional blocks\\c(), like \\c(0d0)Armor\\c(), \\c(0d0)Hull\\c(), and more."%_t
        .. "\n\n" .. "You can increase the maximum processing power buildable per ship by unlocking higher-tier \\c(0d0)Building Knowledge\\c()."%_t,
    },
    {
        title = "Workshop"%_t,
        pictures =
        {
            "data/textures/ui/encyclopedia/building/savedDesigns/workshop_red.jpg",
            "data/textures/ui/encyclopedia/building/savedDesigns/workshop_red.jpg",
            "data/textures/ui/encyclopedia/building/savedDesigns/workshop_red.jpg",
            "data/textures/ui/encyclopedia/building/savedDesigns/designs-button-highlight.jpg",
            "data/textures/ui/encyclopedia/building/savedDesigns/designs-button-highlight.jpg",
            "data/textures/ui/encyclopedia/building/savedDesigns/workshop-folder-highlight.jpg",
            "data/textures/ui/encyclopedia/building/savedDesigns/workshop-folder-highlight.jpg",
            "data/textures/ui/encyclopedia/building/savedDesigns/workshop-ship-highlight.jpg",
            "data/textures/ui/encyclopedia/building/savedDesigns/workshop-ship-highlight.jpg",
            "data/textures/ui/encyclopedia/building/savedDesigns/workshop-ship-highlight.jpg",
            "data/textures/ui/encyclopedia/building/savedDesigns/workshop-ship-highlight.jpg",
            "data/textures/ui/encyclopedia/building/savedDesigns/workshop_red.jpg",
        },
        fps = 2,
        text = "Avorion has \\c(0d0)Steam Workshop\\c() integration. \\c(0d0)Subscribe\\c() to an item and find it in your \\c(0d0)Saved Designs\\c().\nDownloadable content includes ship, station, fighter and turret designs."%_t,
    },
    {
        title = "Advanced Building"%_t,
        articles =
        {
            {
                title = "Matching Size & Shape"%_t,
                pictures =
                {
                    {path = "data/textures/ui/encyclopedia/building/matchingShape/match_1.jpg", showLabel = false, caption = "[Left SHIFT]"%_t},
                    {path = "data/textures/ui/encyclopedia/building/matchingShape/match_1.jpg", showLabel = true, caption = "[Left SHIFT]"%_t},
                    {path = "data/textures/ui/encyclopedia/building/matchingShape/match_2.jpg", showLabel = true, caption = "[Left SHIFT]"%_t},
                    {path = "data/textures/ui/encyclopedia/building/matchingShape/match_2.jpg", showLabel = false, caption = "[Left SHIFT]"%_t},
                    {path = "data/textures/ui/encyclopedia/building/matchingShape/match_3.jpg", showLabel = false, caption = "[CTRL]"%_t},
                    {path = "data/textures/ui/encyclopedia/building/matchingShape/match_3.jpg", showLabel = true, caption = "[CTRL]"%_t},
                    {path = "data/textures/ui/encyclopedia/building/matchingShape/match_4.jpg", showLabel = true, caption = "[CTRL]"%_t},
                    {path = "data/textures/ui/encyclopedia/building/matchingShape/match_4.jpg", showLabel = false, caption = "[CTRL]"%_t},
                    "data/textures/ui/encyclopedia/building/matchingShape/match_5.jpg",
                    "data/textures/ui/encyclopedia/building/matchingShape/match_5.jpg",
                },
                fps = 2,
                text = "If you would like the block you want to place to match the size of the one you want to place it next to, select \\c(fff)'Match Block'\\c() in the \\c(0d0)Blocks Window\\c() or hold \\c(fff)[Left SHIFT]\\c() while placing the block."%_t
                .. "\n\n" .. "Especially for edge and triangle blocks it is important that their orientation matches the neighboring block."%_t
                .. " " .. "To automatically align them with the block they are getting attached to hold \\c(fff)[CTRL]\\c() or select \\c(fff)'Match Shape'\\c() in the \\c(0d0)Blocks Window\\c()."%_t,
            },
            {
                title = "Transforming Blocks"%_t,
                pictures =
                {
                    "data/textures/ui/encyclopedia/building/transforming/transforming_1.jpg",
                    "data/textures/ui/encyclopedia/building/transforming/transforming_1.jpg",
                    {path = "data/textures/ui/encyclopedia/building/transforming/transforming_2.jpg", showLabel = true, caption = "[ALT]"},
                    {path = "data/textures/ui/encyclopedia/building/transforming/transforming_2.jpg", showLabel = true, caption = "[ALT]"},
                    "data/textures/ui/encyclopedia/building/transforming/transforming_2_1.jpg",
                    "data/textures/ui/encyclopedia/building/transforming/transforming_2_1.jpg",
                    {path = "data/textures/ui/encyclopedia/building/transforming/transforming_3.jpg", showLabel = true, caption = "[" .. GameInput():getKeyName(ControlAction.RotateBlocks) .. "]"},
                    {path = "data/textures/ui/encyclopedia/building/transforming/transforming_3.jpg", showLabel = true, caption = "[" .. GameInput():getKeyName(ControlAction.RotateBlocks) .. "]"},
                    "data/textures/ui/encyclopedia/building/transforming/transforming_4.jpg",
                    "data/textures/ui/encyclopedia/building/transforming/transforming_4.jpg",
                    {path = "data/textures/ui/encyclopedia/building/transforming/transforming_5.jpg", showLabel = true, caption = "[ALT]"},
                    {path = "data/textures/ui/encyclopedia/building/transforming/transforming_5.jpg", showLabel = true, caption = "[ALT]"},
                },
                text = "Hold \\c(fff)[ALT]\\c() to replace a selected block with the block type you have selected in the \\c(0d0)Blocks Window\\c()."%_t
                .. "\n\n" .. "If the block doesn't have the orientation you wanted, you can also use \\c(fff)[${rotate}]\\c() to change it."%_t % {rotate=GameInput():getKeyName(ControlAction.RotateBlocks)},
            },
            {
                title = "Replacing Multiple Blocks"%_t,
                pictures =
                {
                    "data/textures/ui/encyclopedia/building/replacing/replacing_1.jpg",
                    "data/textures/ui/encyclopedia/building/replacing/replacing_1_red.jpg",
                    "data/textures/ui/encyclopedia/building/replacing/replacing_1_red.jpg",
                    "data/textures/ui/encyclopedia/building/replacing/replacing_2.jpg",
                    "data/textures/ui/encyclopedia/building/replacing/replacing_2_red.jpg",
                    "data/textures/ui/encyclopedia/building/replacing/replacing_2_red.jpg",
                    "data/textures/ui/encyclopedia/building/replacing/replacing_4.jpg",
                    "data/textures/ui/encyclopedia/building/replacing/replacing_4_red.jpg",
                    "data/textures/ui/encyclopedia/building/replacing/replacing_4_red.jpg",
                    "data/textures/ui/encyclopedia/building/replacing/replacing_5.jpg",
                    "data/textures/ui/encyclopedia/building/replacing/replacing_5.jpg",
                },
                text = "You can also select multiple blocks, either manually or by selecting the option \\c(fff)'Select All Blocks Of The Current Type'\\c()."%_t
                .. "\n\n" .. "Afterwards, you can transform all of those blocks with one click on \\c(fff)'Transform All Selected Blocks'\\c()."%_t,
            },
            {
                title = "Ship Internals"%_t,
                pictures =
                {
                    "data/textures/ui/encyclopedia/building/view/view_1.jpg",
                    "data/textures/ui/encyclopedia/building/view/view_1_red.jpg",
                    "data/textures/ui/encyclopedia/building/view/view_1_red.jpg",
                    "data/textures/ui/encyclopedia/building/view/view_3_1.jpg",
                    "data/textures/ui/encyclopedia/building/view/view_3_1.jpg",
                    "data/textures/ui/encyclopedia/building/view/view_2.jpg",
                    "data/textures/ui/encyclopedia/building/view/view_2.jpg",
                    "data/textures/ui/encyclopedia/building/view/view_3.jpg",
                    "data/textures/ui/encyclopedia/building/view/view_3.jpg",
                    "data/textures/ui/encyclopedia/building/view/view_4.jpg",
                    "data/textures/ui/encyclopedia/building/view/view_4.jpg",
                },
                text = "You can filter which blocks of your ship you want to be shown. Click on the button \\c(fff)'View'\\c() at the bottom left to select only certain materials or block types to be shown."%_t
                .. "\n\n" .. "You can use this function to edit the insides of your ship."%_t
                .. "\n\n" .. "\\c(fff)Tip\\c(): Build the inside of your ship of a certain block type (f.e. Framework) so that you can easily replace it later!"%_t,
            },
            {
                title = "Turret Designs"%_t,
                pictures =
                {
                    "data/textures/ui/encyclopedia/building/turretDesign/turret_1.jpg",
                    "data/textures/ui/encyclopedia/building/turretDesign/turret_1.jpg",
                    "data/textures/ui/encyclopedia/building/turretDesign/turret_2.jpg",
                    "data/textures/ui/encyclopedia/building/turretDesign/turret_2_red.jpg",
                    "data/textures/ui/encyclopedia/building/turretDesign/turret_2_red.jpg",
                    "data/textures/ui/encyclopedia/building/turretDesign/turret_3.jpg",
                    "data/textures/ui/encyclopedia/building/turretDesign/turret_3.jpg",
                },
                text = "You can also design the looks of your turrets. Select a turret base on your ship and enter the \\c(0d0)Turret Design Mode\\c()."%_t
                .. "\n\n" .. "You can save your designs in the \\c(0d0)Saved Designs\\c() window (see chapter \\c(fff)'Saving Ships'\\c())."%_t,
            },
            {
                title = "Applying Turret Designs"%_t,
                pictures =
                {
                    "data/textures/ui/encyclopedia/building/turretDesigns/turretDesign_1.jpg",
                    "data/textures/ui/encyclopedia/building/turretDesigns/turretDesign_1_red.jpg",
                    "data/textures/ui/encyclopedia/building/turretDesigns/turretDesign_1_red.jpg",
                    "data/textures/ui/encyclopedia/building/turretDesigns/turretDesign_2.jpg",
                    "data/textures/ui/encyclopedia/building/turretDesigns/turretDesign_2_red.jpg",
                    "data/textures/ui/encyclopedia/building/turretDesigns/turretDesign_2_red.jpg",
                    "data/textures/ui/encyclopedia/building/turretDesigns/turretDesign_3.jpg",
                    "data/textures/ui/encyclopedia/building/turretDesigns/turretDesign_3_red.jpg",
                    "data/textures/ui/encyclopedia/building/turretDesigns/turretDesign_3_red.jpg",
                },
                text = "You can apply any turret design saved in the \\c(0d0)Saved Designs\\c() window to turret bases on your ship."%_t
                .. "\n\n" .. "You can even select multiple turret bases and choose a design for all of them."%_t % {shift=GameInput():getKeyName(ControlAction.ReleaseMouse)},
            },
            {
                title = "Saving Designs"%_t,
                pictures =
                {
                    "data/textures/ui/encyclopedia/building/templates/template_1.jpg",
                    "data/textures/ui/encyclopedia/building/templates/template_1.jpg",
                    {path = "data/textures/ui/encyclopedia/building/templates/template_1.jpg", showLabel = true, caption = "[CTRL] + [C]"},
                    {path = "data/textures/ui/encyclopedia/building/templates/template_1.jpg", showLabel = true, caption = "[CTRL] + [C]"},
                    "data/textures/ui/encyclopedia/building/templates/template_1_red.jpg",
                    "data/textures/ui/encyclopedia/building/templates/template_1_red.jpg",
                    "data/textures/ui/encyclopedia/building/templates/template_2.jpg",
                    {path = "data/textures/ui/encyclopedia/building/templates/template_2.jpg", showLabel = true, caption = "[CTRL] + [V]"},
                    {path = "data/textures/ui/encyclopedia/building/templates/template_2.jpg", showLabel = true, caption = "[CTRL] + [V]"},
                    "data/textures/ui/encyclopedia/building/templates/template_2.jpg",
                    "data/textures/ui/encyclopedia/building/templates/template_3_red.jpg",
                    "data/textures/ui/encyclopedia/building/templates/template_3_red.jpg",
                    "data/textures/ui/encyclopedia/building/templates/template_3.jpg",
                },
                text = "It is not only possible to save entire ships, you can also save templates made up of only a few blocks."%_t
                .. "\n\n" .. "To save a template, select all the blocks you want to save and copy them with \\c(fff)[CTRL] + [C]\\c()."%_t
                .. " " .. "Then open the \\c(0d0)Saved Designs\\c() window (see chapter \\c(fff)'Saving Ships'\\c()) and paste your design in a folder of your choosing with \\c(fff)[CTRL] + [V]\\c()."%_t
                .. "\n\n" .. "From there, you can drag and drop your template into the quick access bar at the bottom, or use it again directly with \\c(fff)[CTRL] + [V]\\c()."%_t,
            },
            {
                title = "Anchor Blocks"%_t,
                pictures =
                {
                    "data/textures/ui/encyclopedia/building/templates/template_4.jpg",
                    "data/textures/ui/encyclopedia/building/templates/template_4.jpg",
                    {path = "data/textures/ui/encyclopedia/building/templates/template_4.jpg", showLabel = true, caption = "[ALT]"},
                    {path = "data/textures/ui/encyclopedia/building/templates/template_5.jpg", showLabel = true, caption = "[ALT]"},
                    "data/textures/ui/encyclopedia/building/templates/template_5.jpg",
                    "data/textures/ui/encyclopedia/building/templates/template_6.jpg",
                    "data/textures/ui/encyclopedia/building/templates/template_6.jpg",
                    "data/textures/ui/encyclopedia/building/templates/template_7.jpg",
                    "data/textures/ui/encyclopedia/building/templates/template_7.jpg",
                },
                text = "Templates made up of several blocks can be scaled and rotated just like single blocks."%_t
                .. "\n\n" .. "If you hold \\c(fff)[ALT]\\c() before placing your design on your ship, you will be able to select which of its blocks your template should use to anchor itself to the ship."%_t,
            },
            {
                title = "Merging Blocks"%_t,
                picture = "data/textures/ui/encyclopedia/building/merge.jpg",
                text = "To improve the \\c(0d0)performance\\c() of the game by making sure it doesn't always have to load a huge number of blocks, try to merge neighboring blocks that have the same shape."%_t
                .. "\n\n" .. "You can use the option \\c(fff)'Merge Blocks'\\c() in the bottom left to do that."%_t,
            },
            {
                title = "Ship Stats"%_t,
                pictures =
                {
                    "data/textures/ui/encyclopedia/building/stats/stats_1.jpg",
                    "data/textures/ui/encyclopedia/building/stats/stats_1_red.jpg",
                    "data/textures/ui/encyclopedia/building/stats/stats_1_red.jpg",
                    "data/textures/ui/encyclopedia/building/stats/stats_2.jpg",
                    "data/textures/ui/encyclopedia/building/stats/stats_2_red.jpg",
                    "data/textures/ui/encyclopedia/building/stats/stats_2_red.jpg",
                    "data/textures/ui/encyclopedia/building/stats/stats_3.jpg",
                    "data/textures/ui/encyclopedia/building/stats/stats_3.jpg",
                },
                text = "You can configure which ship stats are shown by clicking on the cog symbol underneath the stats."%_t,
            },
            {
                title = "Silhouettes"%_t,
                pictures =
                {
                    "data/textures/ui/encyclopedia/building/silhouette.jpg",
                },
                text = "To see a size comparison of your ship, select \\c(fff)'View'\\c() and choose from a number of famous landmarks."%_t,
            },
            {
                title = "Grid"%_t,
                pictures =
                {
                    "data/textures/ui/encyclopedia/building/grid.jpg",
                },
                text = "You can change the size of the invisible grid that all blocks align themselves with and you can decide how newly placed blocks snap to it."%_t
                .. "\n\n" .. "If you select \\c(0d0)Voxel Grid\\c(), for example, all corners of your blocks will always end up where the lines of the grid cross, allowing you to build more precisely."%_t
                .. "\n\n" .. "Click the \\c(fff)'? Button'\\c() in the grid window to find out more about each setting."%_t,
            },
            {
                title = "Building Shortcuts"%_t,
                picture = "data/textures/ui/encyclopedia/building/shortcuts.jpg",
                text = "If you don't know how to do something, press \\c(fff)${short}\\c() to get an overview of all \\c(0d0)building shortcuts\\c()."%_t % {short=GameInput():getKeyName(ControlAction.ShowServerInfo)},
            },
        },
    },

}

contents.foundShip = category.chapters[1]
contents.buildingMode = category.chapters[2]
contents.workshop = category.chapters[3]
