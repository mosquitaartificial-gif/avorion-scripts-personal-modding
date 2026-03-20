package.path = package.path .. ";data/scripts/lib/?.lua"
include("stringutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace MapSectorIcons
MapSectorIcons = {}

-- Stored markers: key = "x:y", value = { x, y, icon }
-- The mapIcon handle is runtime-only and not persisted.
local markers = {}
local markersContainer = nil
local pickerWindow   = nil
local pendingCoords  = nil  -- sector coords of the last RMB click

-- Ship icons available as sector markers (subset of CraftIcons -- crafts only)
local SHIP_ICONS = {
    { path = "data/textures/icons/pixel/civil-ship.png",    label = "Civil Ship"    },
    { path = "data/textures/icons/pixel/military-ship.png", label = "Military Ship" },
    { path = "data/textures/icons/pixel/defender.png",      label = "Defender"      },
    { path = "data/textures/icons/pixel/anti-carrier.png",  label = "Anti-Carrier"  },
    { path = "data/textures/icons/pixel/anti-shield.png",   label = "Anti-Shield"   },
    { path = "data/textures/icons/pixel/artillery.png",     label = "Artillery"     },
    { path = "data/textures/icons/pixel/carrier.png",       label = "Carrier"       },
    { path = "data/textures/icons/pixel/torpedoboat.png",   label = "Torpedo Boat"  },
    { path = "data/textures/icons/pixel/fighter.png",       label = "Fighter"       },
    { path = "data/textures/icons/pixel/persecutor.png",    label = "Persecutor"    },
    { path = "data/textures/icons/pixel/flagship.png",      label = "Flagship"      },

    -- Estaciones
    { path = "data/textures/icons/pixel/blackmarket.png",      label = "Mercado negro"    },
    { path = "data/textures/icons/pixel/biotope.png",          label = "Biotopo"          },
    { path = "data/textures/icons/pixel/crate.png",            label = "Caja"             },
    { path = "data/textures/icons/pixel/factory.png",          label = "Fabrica"          },
    { path = "data/textures/icons/pixel/farm.png",             label = "Granja"           },
    { path = "data/textures/icons/pixel/mine.png",             label = "Mina"             },
    { path = "data/textures/icons/pixel/headquarters.png",     label = "Sede central"     },
    { path = "data/textures/icons/pixel/trade.png",            label = "Comercio"         },
    { path = "data/textures/icons/pixel/casino.png",           label = "Casino"           },
    { path = "data/textures/icons/pixel/buying.png",           label = "Compra"           },
    { path = "data/textures/icons/pixel/habitat.png",          label = "Habitat"          },
    { path = "data/textures/icons/pixel/headquarters.png",     label = "Cuartel general"  },
    { path = "data/textures/icons/pixel/military.png",         label = "Militar"          },
    { path = "data/textures/icons/pixel/ranch.png",            label = "Rancho"           },
    { path = "data/textures/icons/pixel/refine.png",           label = "Refineria"        },
    { path = "data/textures/icons/pixel/resources.png",        label = "Recursos"         },
    { path = "data/textures/icons/pixel/repair.png",           label = "Reparacion"       },
    { path = "data/textures/icons/pixel/research.png",         label = "Investigacion"    },
    { path = "data/textures/icons/pixel/scrapyard_fat.png",    label = "Desguace grande"  },
    { path = "data/textures/icons/pixel/scrapyard_thin.png",   label = "Desguace pequeno" },
    { path = "data/textures/icons/pixel/sdblack.png",          label = "SD negro"         },
    { path = "data/textures/icons/pixel/sdwhite.png",          label = "SD blanco"        },
    { path = "data/textures/icons/pixel/shipyard1.png",        label = "Astillero 1"      },
    { path = "data/textures/icons/pixel/shipyard2.png",        label = "Astillero 2"      },
    { path = "data/textures/icons/pixel/shipyard-repair.png",  label = "Reparacion astillero" },
    { path = "data/textures/icons/pixel/turret.png",           label = "Torreta"          },
}

-- Layout constants
local ICON_SIZE = 40
local PADDING   = 8
local COLS      = 4

-- ─────────────────────────────────────────────────────────────────────────────
-- CLIENT
-- ─────────────────────────────────────────────────────────────────────────────
if onClient() then

function MapSectorIcons.initialize()
    local player = Player()
    player:registerCallback("onShowGalaxyMap",      "onShowGalaxyMap")
    player:registerCallback("onGalaxyMapMouseDown", "onGalaxyMapMouseDown")

    markersContainer = GalaxyMap():createContainer()

    MapSectorIcons.buildPickerUI()

    -- Render any markers that were already restored before initialize ran
    MapSectorIcons.rebuildMapIcons()
end

-- ── UI Construction ──────────────────────────────────────────────────────────

function MapSectorIcons.buildPickerUI()
    local rows  = math.ceil(#SHIP_ICONS / COLS)
    local winW  = COLS * (ICON_SIZE + PADDING) + PADDING
    local winH  = rows * (ICON_SIZE + PADDING) + PADDING
                + 30   -- remove button row
                + 30   -- window title bar height (approximate)

    pickerWindow = GalaxyMap():createWindow(Rect(vec2(winW, winH)))
    pickerWindow.caption          = "Mark Sector"%_t
    pickerWindow.showCloseButton  = true
    pickerWindow.closeableWithEscape = true
    pickerWindow.moveable         = true
    pickerWindow:hide()

    -- Icon grid
    for i, entry in ipairs(SHIP_ICONS) do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)

        local bx = PADDING + col * (ICON_SIZE + PADDING)
        local by = PADDING + row * (ICON_SIZE + PADDING)

        local rect = Rect(vec2(bx, by), vec2(bx + ICON_SIZE, by + ICON_SIZE))
        local btn  = pickerWindow:createButton(rect, "", "onIconPicked_" .. i)
        btn.icon    = entry.path
        btn.tooltip = entry.label
        btn.hasFrame = true

        -- Dynamically register a callback per button in the namespace so the
        -- engine's callback dispatcher can find it by name.
        MapSectorIcons["onIconPicked_" .. i] = function()
            if pendingCoords then
                MapSectorIcons.placeMarker(pendingCoords.x, pendingCoords.y, entry.path)
            end
            pickerWindow:hide()
        end
    end

    -- Remove-marker button at the bottom
    local removeY   = PADDING + rows * (ICON_SIZE + PADDING)
    local removeRect = Rect(vec2(PADDING, removeY), vec2(winW - PADDING, removeY + 26))
    pickerWindow:createButton(removeRect, "Remove Marker"%_t, "onRemoveMarkerPressed")
end

function MapSectorIcons.onRemoveMarkerPressed()
    if pendingCoords then
        MapSectorIcons.clearMarker(pendingCoords.x, pendingCoords.y)
    end
    pickerWindow:hide()
end

-- ── Map Interaction ──────────────────────────────────────────────────────────

-- Called by the engine on every mouse-down event while the galaxy map is open.
-- button: MouseButton enum  |  mx, my: screen position  |  cx, cy: sector coords
function MapSectorIcons.onGalaxyMapMouseDown(button, mx, my, cx, cy)
    if button ~= MouseButton.Middle then return false end

    -- Don't open our picker when MapCommands already consumed this click
    -- (e.g. ship selected → jump order). MapCommands returns true in that case,
    -- but since callbacks are independent we guard by checking if the picker is
    -- already doing something. Simply always open on RMB; MapCommands' handler
    -- already handles its own consumption independently.

    pendingCoords = { x = cx, y = cy }

    -- Position picker near click but clamped to screen
    local res = getResolution()
    local pickerW = COLS * (ICON_SIZE + PADDING) + PADDING
    local pickerH = (math.ceil(#SHIP_ICONS / COLS)) * (ICON_SIZE + PADDING) + PADDING + 60

    local px = math.min(mx + 10, res.x - pickerW  - 10)
    local py = math.min(my + 10, res.y - pickerH  - 10)

    local r = pickerWindow.rect
    local size = r.upper - r.lower
    pickerWindow.rect = Rect(vec2(px, py), vec2(px, py) + size)
    pickerWindow:show()

    return false  -- don't consume; let other handlers (MapCommands) also run
end

-- ── Marker Management ────────────────────────────────────────────────────────

function MapSectorIcons.placeMarker(x, y, iconPath)
    local key = x .. ":" .. y

    -- Replace any existing marker at this sector
    markers[key] = { x = x, y = y, icon = iconPath }

    -- Rebuild so the new icon is visible immediately
    MapSectorIcons.rebuildMapIcons()
end

function MapSectorIcons.clearMarker(x, y)
    local key = x .. ":" .. y
    if not markers[key] then return end

    markers[key] = nil
    MapSectorIcons.rebuildMapIcons()
end

-- Clears the container and redraws all current markers.
-- Called after any change to the markers table, and when the map is reopened.
function MapSectorIcons.rebuildMapIcons()
    if not markersContainer then return end

    markersContainer:clear()

    for _, marker in pairs(markers) do
        markersContainer:createMapIcon(marker.icon, ivec2(marker.x, marker.y))
    end
end

-- ── Galaxy Map Events ────────────────────────────────────────────────────────

function MapSectorIcons.onShowGalaxyMap()
    MapSectorIcons.rebuildMapIcons()
end

end -- onClient()


-- ─────────────────────────────────────────────────────────────────────────────
-- PERSISTENCE  (runs on whichever side loads/saves the script)
-- ─────────────────────────────────────────────────────────────────────────────

function MapSectorIcons.secure()
    local data = {}
    for _, marker in pairs(markers) do
        table.insert(data, { x = marker.x, y = marker.y, icon = marker.icon })
    end
    return data
end

function MapSectorIcons.restore(data)
    if not data then return end

    markers = {}
    for _, entry in ipairs(data) do
        local key = entry.x .. ":" .. entry.y
        markers[key] = { x = entry.x, y = entry.y, icon = entry.icon }
    end

    -- If we're on the client and initialize() already ran, redraw immediately.
    -- If initialize() hasn't run yet it will call rebuildMapIcons() on its own.
    if onClient() and markersContainer then
        MapSectorIcons.rebuildMapIcons()
    end
end
