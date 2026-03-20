package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/encyclopedia/lib/?.lua"
package.path = package.path .. ";data/scripts/encyclopedia/?.lua"
include ("stringutility")
include ("contents")

Categories = Categories or {}
category = {}

table.insert(Categories, category)

category.title = "Basics"%_t
category.chapters =
{
    {   
        title = "Controls"%_t,
        articles =
        {
            {
                title = "Basic Ship Movement"%_t,
                pictures =
                {
                    "data/textures/ui/encyclopedia/basics/fly/fly1.jpg",
                    {path = "data/textures/ui/encyclopedia/basics/fly/fly1.jpg", showLabel = false, caption = GameInput():getKeyName(ControlAction.Accelerate)},
                    {path = "data/textures/ui/encyclopedia/basics/fly/fly2.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.Accelerate)},
                    {path = "data/textures/ui/encyclopedia/basics/fly/fly3.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.Accelerate)},
                    {path = "data/textures/ui/encyclopedia/basics/fly/fly4.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.Accelerate)},
                    {path = "data/textures/ui/encyclopedia/basics/fly/fly5.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.Accelerate)},
                    {path = "data/textures/ui/encyclopedia/basics/fly/fly6.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.Accelerate)},
                    {path = "data/textures/ui/encyclopedia/basics/fly/fly6.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.Accelerate)},
                    {path = "data/textures/ui/encyclopedia/basics/fly/fly6.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.Accelerate)},
                    {path = "data/textures/ui/encyclopedia/basics/fly/fly5.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.Accelerate)},
                    {path = "data/textures/ui/encyclopedia/basics/fly/fly4.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.Accelerate)},
                    {path = "data/textures/ui/encyclopedia/basics/fly/fly3.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.Accelerate)},
                    {path = "data/textures/ui/encyclopedia/basics/fly/fly2.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.Accelerate)},
                    {path = "data/textures/ui/encyclopedia/basics/fly/fly1.jpg", showLabel = false, caption = GameInput():getKeyName(ControlAction.Accelerate)},
                },
                fps = 2,
                text = "By default you steer your ship with \\c(fff)${W}\\c(), \\c(fff)${A}\\c(), \\c(fff)${S}\\c(), \\c(fff)${D}\\c() and \\c(fff)Mouse\\c().\n\n\\c(dd5)Warning: there is no friction in space. In order to brake sharply you'll have to flip and accelerate or even boost in the opposite direction!\\c()"%_t % {W =GameInput():getKeyName(ControlAction.Accelerate), A=GameInput():getKeyName(ControlAction.StrafeLeft), S=GameInput():getKeyName(ControlAction.Brake), D=GameInput():getKeyName(ControlAction.StrafeRight)},
            },
            {
                title = "Advanced Ship Movement"%_t,
                pictures =
                {
                    {path = "data/textures/ui/encyclopedia/basics/boost/boost_1.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.Accelerate)},
                    {path = "data/textures/ui/encyclopedia/basics/boost/boost_2.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.Accelerate) .. "+" .. GameInput():getKeyName(ControlAction.JumpOrBoost)},
                    {path = "data/textures/ui/encyclopedia/basics/boost/boost_3.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.Accelerate) .. "+" .. GameInput():getKeyName(ControlAction.JumpOrBoost)},
                    {path = "data/textures/ui/encyclopedia/basics/boost/boost_4.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.Accelerate) .. "+" .. GameInput():getKeyName(ControlAction.JumpOrBoost)},
                    {path = "data/textures/ui/encyclopedia/basics/boost/boost_5.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.Accelerate) .. "+" .. GameInput():getKeyName(ControlAction.JumpOrBoost)},
                    {path = "data/textures/ui/encyclopedia/basics/boost/boost_6.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.Accelerate) .. "+" .. GameInput():getKeyName(ControlAction.JumpOrBoost)},
                },
                fps = 2,
                text = "While flying forward you can hold \\c(fff)${space}\\c() to \\c(0d0)boost\\c(). Additionally you can \\c(0d0)roll\\c() with \\c(fff)${rollLeft}\\c() and \\c(fff)${rollRight}\\c(), and move the ship \\c(0d0)up\\c() and \\c(0d0)down\\c() with \\c(fff)${moveUp}\\c() and \\c(fff)${moveDown}\\c(), respectively."%_t % {space = GameInput():getKeyName(ControlAction.JumpOrBoost), rollLeft = GameInput():getKeyName(ControlAction.RollLeft), rollRight = GameInput():getKeyName(ControlAction.RollRight), moveUp = GameInput():getKeyName(ControlAction.StrafeUp), moveDown = GameInput():getKeyName(ControlAction.StrafeDown)},
            },
            {
                title = "Camera Position"%_t,
                pictures =
                {
                    {path = "data/textures/ui/encyclopedia/basics/movecamera/movecamera_1.jpg", showLabel = false, caption = GameInput():getKeyName(ControlAction.DisplaceCamera)},
                    {path = "data/textures/ui/encyclopedia/basics/movecamera/movecamera_2.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.DisplaceCamera)},
                    {path = "data/textures/ui/encyclopedia/basics/movecamera/movecamera_3.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.DisplaceCamera)},
                    {path = "data/textures/ui/encyclopedia/basics/movecamera/movecamera_4.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.DisplaceCamera)},
                    {path = "data/textures/ui/encyclopedia/basics/movecamera/movecamera_5.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.DisplaceCamera)},
                    {path = "data/textures/ui/encyclopedia/basics/movecamera/movecamera_6.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.DisplaceCamera)},
                    {path = "data/textures/ui/encyclopedia/basics/movecamera/movecamera_7.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.DisplaceCamera)},
                    {path = "data/textures/ui/encyclopedia/basics/movecamera/movecamera_8.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.DisplaceCamera)},
                    {path = "data/textures/ui/encyclopedia/basics/movecamera/movecamera_7.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.DisplaceCamera)},
                    {path = "data/textures/ui/encyclopedia/basics/movecamera/movecamera_9.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.DisplaceCamera)},
                    {path = "data/textures/ui/encyclopedia/basics/movecamera/movecamera_10.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.DisplaceCamera)},
                    {path = "data/textures/ui/encyclopedia/basics/movecamera/movecamera_11.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.DisplaceCamera)},
                    {path = "data/textures/ui/encyclopedia/basics/movecamera/movecamera_12.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.DisplaceCamera)},
                    {path = "data/textures/ui/encyclopedia/basics/movecamera/movecamera_13.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.DisplaceCamera)},
                    {path = "data/textures/ui/encyclopedia/basics/movecamera/movecamera_14.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.DisplaceCamera)},
                    {path = "data/textures/ui/encyclopedia/basics/movecamera/movecamera_15.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.DisplaceCamera)},
                    {path = "data/textures/ui/encyclopedia/basics/movecamera/movecamera_16.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.DisplaceCamera)},
                    {path = "data/textures/ui/encyclopedia/basics/movecamera/movecamera_15.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.DisplaceCamera)},
                    {path = "data/textures/ui/encyclopedia/basics/movecamera/movecamera_17.jpg", showLabel = false, caption = GameInput():getKeyName(ControlAction.DisplaceCamera)},
                    {path = "data/textures/ui/encyclopedia/basics/movecamera/movecamera_17.jpg", showLabel = false, caption = GameInput():getKeyName(ControlAction.DisplaceCamera)},
                },
                fps = 1.5,
                text = "You can adjust the \\c(0d0)camera position\\c() by holding \\c(fff)${displaceCam}\\c() and simultaneously moving the \\c(fff)Mouse\\c(). If you hold \\c(fff)${displaceCam}\\c() and don't move the mouse, the camera will snap back to default.\nIf your ship is too close to the camera (or too far off), try \\c(0d0)zooming\\c() in or out with the \\c(fff)Mouse Wheel\\c()!"%_t % {displaceCam=GameInput():getKeyName(ControlAction.DisplaceCamera)},
            },
            {
                title = "Camera Movement"%_t,
                pictures =
                {
                    {path = "data/textures/ui/encyclopedia/basics/camera/turn1.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.FreeLook)},
                    {path = "data/textures/ui/encyclopedia/basics/camera/turn2.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.FreeLook)},
                    {path = "data/textures/ui/encyclopedia/basics/camera/turn3.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.FreeLook)},
                    {path = "data/textures/ui/encyclopedia/basics/camera/turn4.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.FreeLook)},
                    {path = "data/textures/ui/encyclopedia/basics/camera/turn5.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.FreeLook)},
                    {path = "data/textures/ui/encyclopedia/basics/camera/turn6.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.FreeLook)},
                    {path = "data/textures/ui/encyclopedia/basics/camera/turn5.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.FreeLook)},
                    {path = "data/textures/ui/encyclopedia/basics/camera/turn4.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.FreeLook)},
                    {path = "data/textures/ui/encyclopedia/basics/camera/turn3.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.FreeLook)},
                    {path = "data/textures/ui/encyclopedia/basics/camera/turn2.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.FreeLook)},
                    {path = "data/textures/ui/encyclopedia/basics/camera/turn1.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.FreeLook)},
                },
                fps = 2,
                text = "Sometimes you'll want to \\c(0d0)move the camera\\c() without having to turn the ship. Hold \\c(fff)${movCam}\\c() to move the camera independently."%_t % {movCam=GameInput():getKeyName(ControlAction.FreeLook)},
            },
            {
                title = "Mouse Movement"%_t,
                pictures =
                {
                    {path = "data/textures/ui/encyclopedia/basics/freemouse/freemouse_1.jpg", showLabel = false, caption = GameInput():getKeyName(ControlAction.ReleaseMouse)},
                    {path = "data/textures/ui/encyclopedia/basics/freemouse/freemouse_2.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.ReleaseMouse)},
                    {path = "data/textures/ui/encyclopedia/basics/freemouse/freemouse_3.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.ReleaseMouse)},
                    {path = "data/textures/ui/encyclopedia/basics/freemouse/freemouse_4.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.ReleaseMouse)},
                    {path = "data/textures/ui/encyclopedia/basics/freemouse/freemouse_3.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.ReleaseMouse)},
                    {path = "data/textures/ui/encyclopedia/basics/freemouse/freemouse_2.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.ReleaseMouse)},
                },
                fps = 2,
                text = "To move the \\c(0d0)mouse pointer\\c() independently, hold \\c(fff)${freeCam}\\c(). You can use this to click on any icon, or on things you're not directly looking at."%_t % {freeCam=GameInput():getKeyName(ControlAction.ReleaseMouse)},
            },
            {
                title = "Selecting Objects"%_t,
                pictures =
                {
                    {path = "data/textures/ui/encyclopedia/basics/selectobject/selectobject_1.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.ReleaseMouse)},
                    {path = "data/textures/ui/encyclopedia/basics/selectobject/selectobject_2.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.ReleaseMouse)},
                    {path = "data/textures/ui/encyclopedia/basics/selectobject/selectobject_3.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.ReleaseMouse)},
                    {path = "data/textures/ui/encyclopedia/basics/selectobject/selectobject_4.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.SelectTarget)},
                    {path = "data/textures/ui/encyclopedia/basics/selectobject/selectobject_4.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.SelectTarget)},
                },
                fps = 2,
                text = "Select objects by clicking \\c(fff)${selectButton}\\c() in order to get more information about them."%_t % {selectButton=GameInput():getKeyName(ControlAction.SelectTarget)},
            },
            {
                title = "Docking"%_t,
                pictures =
                {
                    "data/textures/ui/encyclopedia/basics/docking/docking_1.jpg",
                    "data/textures/ui/encyclopedia/basics/docking/docking_2.jpg",
                    "data/textures/ui/encyclopedia/basics/docking/docking_3.jpg",
                    "data/textures/ui/encyclopedia/basics/docking/docking_4.jpg",
                    "data/textures/ui/encyclopedia/basics/docking/docking_5.jpg",
                    "data/textures/ui/encyclopedia/basics/docking/docking_6.jpg",
                    "data/textures/ui/encyclopedia/basics/docking/docking_7.jpg",
                },
                fps = 2,
                text = "\\c(0d0)Interact\\c() with stations by selecting them with \\c(fff)${selectButton}\\c() and pressing \\c(fff)${F}\\c(). Some options, however, can only be performed while docked.\nTo \\c(0d0)dock\\c(), get close enough to the station until the docking markers become visible and fly to one of them."%_t % {selectButton=GameInput():getKeyName(ControlAction.SelectTarget), F=GameInput():getKeyName(ControlAction.Interact)},
            },
            {
                title = "Switching Crafts"%_t,
                pictures =
                {
                    {path = "data/textures/ui/encyclopedia/basics/selectobject/selectobject_3.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.ReleaseMouse)},
                    {path = "data/textures/ui/encyclopedia/basics/selectobject/selectobject_3.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.ReleaseMouse)},
                    {path = "data/textures/ui/encyclopedia/basics/selectobject/selectobject_4.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.SelectTarget)},
                    {path = "data/textures/ui/encyclopedia/basics/selectobject/selectobject_4.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.SelectTarget)},
                    {path = "data/textures/ui/encyclopedia/basics/switchcraft/switchcrafts_1.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.TransferPlayer)},
                    {path = "data/textures/ui/encyclopedia/basics/switchcraft/switchcrafts_1.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.TransferPlayer)},
                    {path = "data/textures/ui/encyclopedia/basics/switchcraft/switchcrafts_1.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.TransferPlayer)},
                    "data/textures/ui/encyclopedia/basics/switchcraft/switchcrafts_2.jpg",
                    "data/textures/ui/encyclopedia/basics/switchcraft/switchcrafts_3.jpg",
                    "data/textures/ui/encyclopedia/basics/switchcraft/switchcrafts_3.jpg",
                },
                fps = 2,
                text = "\\c(0d0)Switch\\c() between your ships by selecting them and pressing \\c(fff)${TransferPlayer}\\c(). Switching without having another ship selected will transfer you to your \\c(0d0)Drone\\c()."%_t % {TransferPlayer=GameInput():getKeyName(ControlAction.TransferPlayer)},
            },
            {
                title = "Broadsides"%_t,
                id = "Broadsides",
                pictures =
                {
                    {path = "data/textures/ui/encyclopedia/basics/broadside/00.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.FreeLook)},
                    {path = "data/textures/ui/encyclopedia/basics/broadside/01.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.FreeLook)},
                    {path = "data/textures/ui/encyclopedia/basics/broadside/02.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.FreeLook)},
                    {path = "data/textures/ui/encyclopedia/basics/broadside/03.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.FreeLook)},
                    {path = "data/textures/ui/encyclopedia/basics/broadside/04.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.FreeLook)},
                    {path = "data/textures/ui/encyclopedia/basics/broadside/05.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.FreeLook)},
                    {path = "data/textures/ui/encyclopedia/basics/broadside/06.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.FreeLook)},
                    {path = "data/textures/ui/encyclopedia/basics/broadside/07.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.FreeLook)},
                    {path = "data/textures/ui/encyclopedia/basics/broadside/08.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.FreeLook)},
                    {path = "data/textures/ui/encyclopedia/basics/broadside/09.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.FreeLook)},
                    {path = "data/textures/ui/encyclopedia/basics/broadside/10.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.FreeLook)},
                    {path = "data/textures/ui/encyclopedia/basics/broadside/11.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.FreeLook)},
                    {path = "data/textures/ui/encyclopedia/basics/broadside/12.jpg", showLabel = true, caption = GameInput():getKeyName(ControlAction.FreeLook)},
                },
                fps = 1,
                text = "When steering with the mouse, hold \\c(fff)[${camera}]\\c() to move the camera independently from the ship, \\c(0d0)without\\c() the ship \\c(0d0)changing course\\c(). This way, you can fire a broadside at an enemy that is starboard or portside, while your ship \\c(0d0)stays on course\\c().\n\nWhile holding \\c(fff)[${camera}]\\c(), use the \\c(fff)[Mouse Wheel]\\c() to zoom."%_t
                        % {
                            camera = GameInput():getKeyName(ControlAction.FreeLook)
                        },
            },
            {
                title = "Cruisers & Larger Ships"%_t,
                pictures =
                {
                    "data/textures/ui/encyclopedia/basics/cruisermode/00.jpg",
                    "data/textures/ui/encyclopedia/basics/cruisermode/01.jpg",
                    "data/textures/ui/encyclopedia/basics/cruisermode/02.jpg",
                    "data/textures/ui/encyclopedia/basics/cruisermode/03.jpg",
                    "data/textures/ui/encyclopedia/basics/cruisermode/00.jpg",
                },
                fps = 1,
                text = "The \\c(0d0)Cruiser Control Mode\\c() is a secondary control mode that you can use to steer \\c(0d0)larger vessels\\c(). Once your ships get bigger, they won't be as agile as they used to be when they were smaller corvettes. Large crafts massively profit from \\c(0d0)turrets\\c() that can \\c(0d0)turn in each direction\\c().\n\nWith this mode you can set a fixed velocity with \\c(fff)[${Acc}], [${Brake}], [${ToggleVelocity}]\\c() and steer the ship with \\c(fff)[${W}], [${A}], [${S}], [${D}], [${Q}], [${E}]\\c(), all while being able to move the mouse freely to aim."%_t
                        % {
                            Acc = GameInput():getKeyName(ControlAction.Accelerate),
                            Brake = GameInput():getKeyName(ControlAction.Brake),
                            ToggleVelocity = GameInput():getKeyName(ControlAction.ToggleVelocity, nil, ControlStyle.KeyboardSteering),
                            W = GameInput():getKeyName(ControlAction.TurnDown, nil, ControlStyle.KeyboardSteering),
                            A = GameInput():getKeyName(ControlAction.TurnLeft, nil, ControlStyle.KeyboardSteering),
                            S = GameInput():getKeyName(ControlAction.TurnUp, nil, ControlStyle.KeyboardSteering),
                            D = GameInput():getKeyName(ControlAction.TurnRight, nil, ControlStyle.KeyboardSteering),
                            Q = GameInput():getKeyName(ControlAction.RollLeft, nil, ControlStyle.KeyboardSteering),
                            E = GameInput():getKeyName(ControlAction.RollRight, nil, ControlStyle.KeyboardSteering),
                        },
            },
        },
    }, 

    {
        title = "HUD"%_t,
        articles =
        {
            {
                title = "Speed"%_t,
                picture = "data/textures/ui/encyclopedia/basics/HUDelements/speedbar.jpg",
                text = "Your \\c(0d0)current speed\\c() is shown by the bar at the top of your screen. If your ship is moving forward, the bar turns blue; movement in the opposite direction is shown as yellow."%_t,
            },
            {
                title = "Hyperdrive"%_t,
                picture = "data/textures/ui/encyclopedia/basics/HUDelements/hyperjumpbar.jpg",
                text = "The \\c(0d0)Hyperspace Engine\\c() status is shown below the speed bar. The status bar is only present while your \\c(0d0)Hyperdrive\\c() is charging. A countdown indicates how much charging time remains.\nIf the bar is red, your Hyperspace Engine is blocked. You have to move away before being able to jump."%_t,
            },
            {
                title = "Energy"%_t,
                picture = "data/textures/ui/encyclopedia/basics/HUDelements/energybar.jpg",
                text = "At the bottom of the screen you'll find the \\c(0d0)Energy Bar\\c() and your \\c(0d0)Battery Status\\c() in shades of yellow."%_t
                .. " " .. "The upper of the two is your energy consumption and the lower shows how much energy is currently stored."%_t
                .. " " .. "You can increase your ship's energy levels with \\c(0d0)Solar Panels\\c(), \\c(0d0)Generators\\c() and certain \\c(0d0)Subsystems\\c()."%_t
                .. "\n\n" .. "\\c(ddd)Note: don't let your batteries be depleted for extended periods of time, crew life support needs energy.\\c()"%_t,
            },
            {
                title = "Health and Shield"%_t,
                picture = "data/textures/ui/encyclopedia/basics/HUDelements/healthbar.jpg",
                text = "At the bottom of the screen is your \\c(0d0)Life Bar\\c().\nRight above the life bar your \\c(0d0)Shield Status\\c() is displayed. If your shield is depleted, it takes a while to be functional again.\n\n\\c(ddd)Note: you need energy to charge your shields, so make sure your ship produces more than it needs before going into battle.\\c()"%_t,
            },
            {
                title = "Warnings"%_t,
                picture = "data/textures/ui/encyclopedia/basics/HUDelements/warnings.jpg",
                text = "Below your speed bar, a number of \\c(0d0)Warning Icons\\c() can be displayed. Hover your mouse over them to get more information. Red warnings are more critical and should be addressed immediately, while yellow warnings are less urgent."%_t,
            },
            {
                title = "Menu Buttons"%_t,
                picture = "data/textures/ui/encyclopedia/basics/HUDelements/menubuttons.jpg",
                text = "In the top right corner are icons for many of Avorion's \\c(0d0)features\\c(). You can use them by freeing your mouse. Read the tooltips to find out what the icons do!"%_t,
            },

            {
                title = "Chat"%_t,
                picture = "data/textures/ui/encyclopedia/basics/HUDelements/chatspam.jpg",
                text = "On the bottom left you'll find the \\c(0d0)Chat Window\\c(). Open it by pressing \\c(fff)${showChat}\\c().\nStatus updates for your fleet, radio messages from stations and general information will be displayed here. You can write messages to other players and use chat commands. To see all available chat commands type \\c(0d0)\"/help\"\\c()."%_t % {showChat=GameInput():getKeyName(ControlAction.ShowChatWindow)},
            },
        },
    },
    {
        title = "Menus"%_t,
        articles =
        {
            {
                title = "Ship Menu"%_t,
                picture = "data/textures/ui/encyclopedia/basics/shipMenu_small.jpg",
                text = "The \\c(0d0)Ship Menu\\c() contains overviews for \\c(0d0)Turrets\\c(), \\c(0d0)Crew\\c(), \\c(0d0)Subsystems\\c(), \\c(0d0)Goods\\c(), \\c(0d0)Fighters\\c() and \\c(0d0)Torpedoes\\c() of the ship you are currently flying. You'll also find the ship's \\c(0d0)Co-op Control\\c() settings here. To open this menu press \\c(fff)${shipMenu}\\c()."%_t % {shipMenu=GameInput():getKeyName(ControlAction.ShowShipMenu)},
            },

            {
                title = "Player Menu"%_t,
                picture = "data/textures/ui/encyclopedia/basics/playerMenu_small.jpg",
                text = "The \\c(0d0)Player Menu\\c() contains an overview over your \\c(0d0)Ships\\c(), \\c(0d0)Inventory\\c(), \\c(0d0)Relationships\\c() to NPC factions, \\c(0d0)Missions\\c() and your \\c(0d0)Alliance\\c(). You can open it with \\c(fff)${playerMenu}\\c()."%_t % {playerMenu=GameInput():getKeyName(ControlAction.ShowPlayerMenu)},
            },
        },
    }, 
    {
        title = "Drone"%_t,
        pictures =
        {
            "data/textures/ui/encyclopedia/basics/drone/00.jpg",
            "data/textures/ui/encyclopedia/basics/drone/00.jpg",
            "data/textures/ui/encyclopedia/basics/drone/01.jpg",
            "data/textures/ui/encyclopedia/basics/drone/02.jpg",
            "data/textures/ui/encyclopedia/basics/drone/00.jpg",
        },
        fps = 1,
        text = "The \\c(0d0)Drone\\c() is your very basic starter ship."%_t
        .. " " .. "It's equipped with two \\c(0d0)Iron Mining Lasers\\c() that you can use to \\c(0d0)mine resources\\c() from asteroids."%_t
        .. " " .. "Even when your last ship was destroyed, you will always have the Drone as a fallback."%_t
        .. "\n\n" .. "The Drone can be used to \\c(0d0)scout ahead\\c() into sectors that are potentially dangerous, so you won't have to put your main ship in danger."%_t
        .. "\n\n" .. "To deploy your drone, press the Drone button on the top right of the screen, or press \\c(fff)[${drone}]\\c()."%_t % {drone = GameInput():getKeyName(ControlAction.TransferPlayer)},
    },
}


contents.controls = category.chapters[1]
contents.hud = category.chapters[2]
contents.menus = category.chapters[3]
