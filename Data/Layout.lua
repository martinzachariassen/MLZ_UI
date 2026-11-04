-- MLZ UI: Layout specification for Edit Mode (minimalist)
-- Edit freely. The logic lives in Modules/Layout.lua.
--
-- Screen layout (the screen is about 1200-1350 units tall, depending on the scale):
--
--   [tracker]                                              [buffs][minimap]
--   [guide (RXP)]
--                                                                    [bar4][bar5]
--          [focus]               [swing ranged]                       (mouseover)
--                                [swing main  ]
--                                [swing off   ]
--                                [  cast bar  ]
--                                [ pet/stance ]
--          [player]   [ bar 3  (Ctrl)  ]   [target]
--                     [ bar 2  (Shift) ]
--                     [ bar 1          ]
--   [party / raid    ]   (5 per row, growing upward from here)            [threat]
--   [bar 6, separate ]                                                    [meter ]
--   [chat]            [ XP / rep, small]                              [micro/bags]
--
-- Ultrawide: frames anchored to the left or right screen edge are moved in by Scale.SafeInset(), so the
-- corners sit at the edges of a centered 16:9 area instead of far out at the sides (see Modules/Layout.lua).
--
-- Principles (inspired by ElvUI / Bartender4 / Dominos setups):
--   * The middle of the screen stays clear. Everything you need in combat is grouped at the bottom center.
--   * The bars are tightly stacked (2 units apart), with no art, gryphons or empty slots.
--   * Player and target flank the stack, so your eyes never travel further than the edge of the bars.
--   * Corners are for things you only glance at. Bags, micro menu and bars 4-5 are hidden until mouseover. The meter only shows in a group.
--
-- Fields:
--   point    = the point on the frame being anchored
--   relPoint = the point on relTo (default: the whole screen / UIParent) it anchors to
--   relTo    = (optional) name of another frame to anchor to
--   x, y     = offset in UI units
--   settings = { [settingName] = value } in the SAME units Edit Mode shows (IconSize = 80 means 80 %).
--              The module converts to the storage format. On/off: 1 = on, 0 = off.
--   rawSettings = settings stored directly without conversion (e.g. chat size).
--   override = { [settingName] = key in MLZUIDB.overrides }: the user's own choice (e.g. /mlz map) wins.

local _, ns = ...

local AB = "EditModeActionBarSetting"
local ABI = "EditModeActionBarSystemIndices"
local UF = "EditModeUnitFrameSetting"
local UFI = "EditModeUnitFrameSystemIndices"

-- Stack dimensions (used to compute positions, so everything stays aligned if you change the size)
local ICON = 80                                -- icon size in % (100 % = 45 units)
local PAD = 2                                  -- spacing between buttons
local BTN = math.floor(45 * ICON / 100 + 0.5)  -- button size in units (36)
local ROW = BTN + PAD                          -- distance between bars in the stack (38)
local HALF = math.floor((12 * BTN + 11 * PAD) / 2 + 0.5) -- half the width of a bar (227)
local BASE = 30                                -- bottom edge of bar 1 (leaves room for the XP bar below)
local GAP = 8                                  -- gap between the stack and player/target
local UNIT_Y = BASE + 40                       -- bottom edge of player/target (room for target of target below)

local STACK_TOP = BASE + 3 * ROW               -- top of the stack: bar 3's top edge (142) plus one PAD of air

-- Above the stack, bottom to top (all centered on the middle of the screen):
--   class bar (pet or stance)  ->  cast bar  ->  swing off hand  ->  swing main hand  ->  swing ranged
-- The pet bar (hunter, warlock) and the stance bar (warrior, druid, rogue, priest) share one slot right
-- above bar 3: no class has both. The swing timers are anchored to each other and to the top of the cast bar,
-- so they never overlap, no matter how tall the frames actually are. Focus lines up with the ranged timer.
local CLASS_ICON = 70                          -- pet / stance icon size in %
local CLASS_H = math.floor(45 * CLASS_ICON / 100 + 0.5) -- 32
local CLASS_Y = STACK_TOP + 2                  -- bottom edge of the pet / stance bar
local CAST_TEXT = 12                           -- the text under the cast bar hangs about 12 units below the frame
local CAST_Y = CLASS_Y + CLASS_H + CAST_TEXT + 6 -- bottom edge of cast bar (6 units of space above the class bar)
local CAST_GAP = 4                             -- gap between cast bar and off hand
local SWING_GAP = 2                            -- gap between the swing timers

-- Swing timer size in the units Edit Mode shows (converted to raw on save). Width 453 = the width of the action
-- bars, Height 15 = the game's own height. Title, time and visibility are on/off and dropdown values, stored raw.
local SWING = { Scale = 100, Opacity = 100, Width = 453, Height = 15 }
local SWING_RAW = { ShowBarTitle = 0, ShowTime = 0, Visibility = 1 }

-- Healer layouts: copies of the main layout where the group frames sit in the middle of the screen, right above
-- the cast bar, and the swing timers are hidden (a healer has no use for them; that is also where the room comes from).
-- Player and target keep their place left and right of the bars, so your own character stays in view.
-- The group frames are anchored by their bottom edge in the center (check in game which way extra rows grow).
local HEAL_Y = CAST_Y + 34                     -- bottom edge of the group frames (the cast time text hangs under the cast bar)
local SWING_HIDDEN = { Visibility = 2 }        -- 0 = always, 1 = in combat, 2 = hidden
-- Edit Mode stores group frame sizes in steps of 10. 5 x 90 = 450, the width of the action bars (454).
local HEAL_W = 90

-- Chat at bottom left, with bar 6 (no hotkeys) right above it
local CHAT_Y = 40                              -- bottom edge of chat (room for the input box below)
local CHAT_H = 170                             -- chat height
local BAR6_Y = CHAT_Y + CHAT_H + 28            -- bottom edge of bar 6 (above the chat tabs)
local BAR6_BTN = 32                            -- bar 6 button size in units (70 % icons)

-- Party / raid frames: bottom left, directly above bar 6. 80 x 40 per frame, 5 per row = 400 wide (same as chat).
local GROUP_W, GROUP_H, GROUP_ROW = 80, 40, 5
local GROUP_Y = BAR6_Y + BAR6_BTN + 8

-- Bottom right column (Blizzard meter, Details windows): above bags and micro menu, below bars 4-5
local METER_X = 4                              -- from the right edge (plus the ultrawide inset)
local METER_Y = 90                             -- bottom edge, above the micro menu

local MAIN_BAR = { Orientation = 0, NumRows = 1, NumIcons = 12, IconSize = ICON, IconPadding = PAD,
                   HideBarArt = 1, HideBarScrolling = 1, AlwaysShowButtons = 0 }
local SIDE_BAR = { Orientation = 1, NumRows = 1, IconSize = 70, IconPadding = PAD, AlwaysShowButtons = 0 }
local CLASS_BAR = { Orientation = 0, NumRows = 1, IconSize = CLASS_ICON, IconPadding = PAD }
-- Always shown (0 = always, 1 = in combat, 2 = out of combat, 3 = hidden). The game still hides an empty pet bar.
local CLASS_VIS = { VisibleSetting = 0 }

ns.data.layout = {
    name = "MLZ UI",   -- name of the Edit Mode layout that is created / updated

    -- Shared with Data/Addons.lua, so addon windows line up with the bars (UIParent units)
    metrics = { HALF = HALF, GAP = GAP, UNIT_Y = UNIT_Y, CAST_Y = CAST_Y, METER_X = METER_X, METER_Y = METER_Y },

    -- Action bars to enable (bars 2-6). Bars 4-5 are hidden until mouseover in Fade. Bar 6 = separate bar above chat.
    showBars = { 2, 3, 4, 5, 6 },

    frames = {
        -- Combat cluster: three tightly stacked bars, bar 1 at the bottom
        { label = "Bar 1", system = "ActionBar", indexEnum = ABI, index = "MainBar",
          point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = BASE, settingEnum = AB, settings = MAIN_BAR },
        { label = "Bar 2 (SHIFT)", system = "ActionBar", indexEnum = ABI, index = "Bar2",
          point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = BASE + ROW, settingEnum = AB, settings = MAIN_BAR },
        { label = "Bar 3 (CTRL)", system = "ActionBar", indexEnum = ABI, index = "Bar3",
          point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = BASE + 2 * ROW, settingEnum = AB, settings = MAIN_BAR },

        -- Gryphons / end caps on the main bar
        { label = "Gryphon left (hide)", system = "MainActionBarEndCap",
          indexEnum = "EditModeMainActionBarEndCapSystemIndices", index = "EndCapLeft", keepAnchor = true,
          settingEnum = "EditModeMainActionBarEndCapSetting", rawSettings = { Hidden = 1 } },
        { label = "Gryphon right (hide)", system = "MainActionBarEndCap",
          indexEnum = "EditModeMainActionBarEndCapSystemIndices", index = "EndCapRight", keepAnchor = true,
          settingEnum = "EditModeMainActionBarEndCapSetting", rawSettings = { Hidden = 1 } },

        -- Cast bar right above the stack
        { label = "Cast bar", system = "CastBar",
          point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = CAST_Y,
          settingEnum = "EditModeCastBarSetting", settings = { LockToPlayerFrame = 0, BarSize = 100, ShowCastTime = 1 } },

        -- Swing timers (built into the client) above the cast bar: off hand at the bottom, main hand, ranged on top.
        -- Chained to each other, so they always stay tight and centered. Only shown in combat.
        { label = "Swing timer off hand", system = "SwingTimer",
          indexEnum = "EditModeSwingTimerSystemIndices", index = "OffHand",
          point = "BOTTOM", relPoint = "TOP", relTo = "PlayerCastingBarFrame", x = 0, y = CAST_GAP,
          settingEnum = "EditModeSwingTimerSetting", settings = SWING, rawSettings = SWING_RAW },
        { label = "Swing timer main hand", system = "SwingTimer",
          indexEnum = "EditModeSwingTimerSystemIndices", index = "MainHand",
          point = "BOTTOM", relPoint = "TOP", relTo = "SwingTimerOffHandFrame", x = 0, y = SWING_GAP,
          settingEnum = "EditModeSwingTimerSetting", settings = SWING, rawSettings = SWING_RAW },
        { label = "Swing timer ranged", system = "SwingTimer",
          indexEnum = "EditModeSwingTimerSystemIndices", index = "Ranged",
          point = "BOTTOM", relPoint = "TOP", relTo = "SwingTimerMainHandFrame", x = 0, y = SWING_GAP,
          settingEnum = "EditModeSwingTimerSetting", settings = SWING, rawSettings = SWING_RAW },

        -- Class bar: pet (hunter, warlock: 10 buttons, ~338 wide) or stance, centered right above bar 3,
        -- so pet commands are as close to your eyes as your own spells. Both use the same spot.
        { label = "Stance bar", system = "ActionBar", indexEnum = ABI, index = "StanceBar",
          point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = CLASS_Y,
          settingEnum = AB, settings = CLASS_BAR, rawSettings = CLASS_VIS },
        -- Your own placement wins: drag it in Edit Mode, then /mlz pet save (stored in MLZUIDB.overrides.petBar).
        { id = "petbar", anchorOverride = "petBar", label = "Pet bar", system = "ActionBar", indexEnum = ABI, index = "PetActionBar",
          point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = CLASS_Y,
          settingEnum = AB, settings = CLASS_BAR, rawSettings = CLASS_VIS },

        -- XP / rep: small, at the very bottom below the stack
        { label = "XP bar (small, bottom)", system = "StatusTrackingBar",
          indexEnum = "EditModeStatusTrackingBarSystemIndices", index = "StatusTrackingBar1",
          point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 2,
          settingEnum = "EditModeStatusTrackingBarSetting", settings = { Size = 50 } },
        { label = "Rep bar (above XP)", system = "StatusTrackingBar",
          indexEnum = "EditModeStatusTrackingBarSystemIndices", index = "StatusTrackingBar2",
          point = "BOTTOM", relPoint = "TOP", relTo = "MainStatusTrackingBarContainer", x = 0, y = 1,
          settingEnum = "EditModeStatusTrackingBarSetting", settings = { Size = 50 } },

        -- Player / target flank the stack, raised so target of target (below target) isn't covered
        { label = "Player", system = "UnitFrame", indexEnum = UFI, index = "Player",
          point = "BOTTOMRIGHT", relPoint = "BOTTOM", x = -(HALF + GAP), y = UNIT_Y, settingEnum = UF, settings = { FrameSize = 100 } },
        { label = "Target", system = "UnitFrame", indexEnum = UFI, index = "Target",
          point = "BOTTOMLEFT", relPoint = "BOTTOM", x = HALF + GAP, y = UNIT_Y, settingEnum = UF, settings = { FrameSize = 100 } },
        -- Focus above player (same right edge), with its bottom edge in line with the ranged swing timer
        { label = "Focus", system = "UnitFrame", indexEnum = UFI, index = "Focus",
          point = "BOTTOMRIGHT", relPoint = "BOTTOM", relTo = "SwingTimerRangedFrame", x = -(HALF + GAP), y = 0,
          settingEnum = UF, settings = { FrameSize = 100 } },

        -- Group: bottom left, right above bar 6 (and growing upward), so it sits close to the action but out of the middle.
        -- Raid-style frames for both party and raid, same compact shape: 5 per row, tanks first, then healers, then dps.
        -- A party is one row of 5, a 25-man is 5 rows, a 40-man is 8 rows.
        { label = "Party", system = "UnitFrame", indexEnum = UFI, index = "Party",
          point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = 6, y = GROUP_Y,
          settingEnum = UF, settings = {
              UseRaidStylePartyFrames = 1, ShowPartyFrameBackground = 0, UseHorizontalGroups = 1,
              FrameWidth = GROUP_W, FrameHeight = GROUP_H, DisplayBorder = 0, SortPlayersBy = 0, BuffIconSize = 50 } },
        { label = "Raid", system = "UnitFrame", indexEnum = UFI, index = "Raid",
          point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = 6, y = GROUP_Y,
          settingEnum = UF, settings = {
              RaidGroupDisplayType = 3, RowSize = GROUP_ROW, SortPlayersBy = 0,
              FrameWidth = GROUP_W, FrameHeight = GROUP_H, DisplayBorder = 0, BuffIconSize = 50 } },

        -- Top right: minimap (130 %), small buffs to its left
        -- Size can be changed with /mlz map (stored in MLZUIDB.overrides.minimapSize and overrides 130 here).
        -- Buffs/debuffs are anchored to the left edge of the minimap, so they move when the size changes.
        { id = "minimap", label = "Minimap", system = "Minimap",
          point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -6, y = -6,
          settingEnum = "EditModeMinimapSetting", settings = { Size = 130 }, override = { Size = "minimapSize" } },
        { label = "Buffs", system = "AuraFrame", indexEnum = "EditModeAuraFrameSystemIndices", index = "BuffFrame",
          point = "TOPRIGHT", relPoint = "TOPLEFT", relTo = "MinimapCluster", x = -6, y = -2,
          settingEnum = "EditModeAuraFrameSetting", settings = { IconSize = 70, IconPadding = 5 } },
        -- Debuffs hang under the buffs, so a second row of buffs pushes them down instead of covering them
        { label = "Debuffs", system = "AuraFrame", indexEnum = "EditModeAuraFrameSystemIndices", index = "DebuffFrame",
          point = "TOPRIGHT", relPoint = "BOTTOMRIGHT", relTo = "BuffFrame", x = 0, y = -GAP,
          settingEnum = "EditModeAuraFrameSetting", settings = { IconSize = 80, IconPadding = 5 } },

        -- Quest tracker: top left, short (hidden in combat, see Data/Fade.lua)
        { label = "Quest tracker", system = "ObjectiveTracker",
          point = "TOPLEFT", relPoint = "TOPLEFT", x = 10, y = -10,
          settingEnum = "EditModeObjectiveTrackerSetting", settings = { Height = 400, TextSize = 12 } },
        -- Boss frames under the minimap (they follow /mlz map), and left of bars 4-5 (2 x 32 + gaps from the edge)
        { label = "Boss frames", system = "UnitFrame", indexEnum = UFI, index = "Boss",
          point = "TOPRIGHT", relPoint = "BOTTOMRIGHT", relTo = "MinimapCluster", x = -(4 + 2 * (32 + PAD) + GAP), y = -GAP },

        -- Bottom left: small chat (400 x 170). Raised 40 units so the input box below chat is visible.
        { label = "Chat", system = "ChatFrame",
          point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = 6, y = CHAT_Y,
          settingEnum = "EditModeChatFrameSetting",
          rawSettings = { WidthHundreds = 4, WidthTensAndOnes = 0, HeightHundreds = 1, HeightTensAndOnes = 70 } },

        -- Bar 6 right above the chat tabs. No hotkeys: drag in
        -- hearthstone, mount, professions etc. (70 % icons = 32 units, 12 buttons = about the chat width)
        { label = "Bar 6 (above chat)", system = "ActionBar", indexEnum = ABI, index = "ExtraBar1",
          point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = 6, y = BAR6_Y, settingEnum = AB,
          settings = { Orientation = 0, NumRows = 1, NumIcons = 12, IconSize = 70, IconPadding = PAD, AlwaysShowButtons = 0 } },

        -- Right edge: bars 4-5 vertical (hidden until mouseover). Raised 60 above the middle, so their bottom
        -- (about 263 below their center) stays clear of the meter and threat windows even on a 1080-unit screen.
        { label = "Bar 4 (mouseover)", system = "ActionBar", indexEnum = ABI, index = "RightBar1",
          point = "RIGHT", relPoint = "RIGHT", x = -4, y = 60, settingEnum = AB, settings = SIDE_BAR },
        { label = "Bar 5", system = "ActionBar", indexEnum = ABI, index = "RightBar2",
          point = "RIGHT", relPoint = "RIGHT", x = -(4 + 32 + PAD), y = 60, settingEnum = AB, settings = SIDE_BAR },

        -- Bottom right: the "clutter corner" (hidden until mouseover). Raised 14 units: the FPS counter sits at the very bottom.
        { label = "Bags", system = "Bags",
          point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -4, y = 18,
          settingEnum = "EditModeBagsSetting", settings = { Size = 75 } },
        { label = "Micro menu", system = "MicroMenu",
          point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -4, y = 50,
          settingEnum = "EditModeMicroMenuSetting", settings = { Size = 70 } },
        -- Blizzard's own meter (only shown if it is turned on in the game options) uses the same spot as
        -- the Details window (see Data/Addons.lua), so there is only one meter corner.
        { label = "Damage meter", system = "DamageMeter",
          point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -METER_X, y = METER_Y },
    },

    -- Variants for Modules/Healer.lua. `frames` lists the frames that differ from the main layout, by label
    -- (same labels as in `frames` above); settings are merged over the main layout's settings.
    -- A variant has either `kind` (a healer in a "party" or "raid") or `archetypes` (see Data/Classes.lua).
    healer = {
        variants = {
            -- Dungeon (party of 5): one row as wide as the bars, tall enough to read dispels and debuffs
            {
                name = "MLZ UI Heal Dungeon", kind = "party",
                frames = {
                    ["Party"] = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = HEAL_Y,
                                  settings = { FrameWidth = HEAL_W, FrameHeight = 50, BuffIconSize = 60 } },
                    ["Swing timer off hand"]   = { rawSettings = SWING_HIDDEN },
                    ["Swing timer main hand"]  = { rawSettings = SWING_HIDDEN },
                    ["Swing timer ranged"]     = { rawSettings = SWING_HIDDEN },
                },
            },
            -- Raid: 5 per row = as wide as the action bars (450). 40 high, so 8 rows (40 players) end below the
            -- middle of the screen. Tanks first, then healers, then dps.
            {
                name = "MLZ UI Heal Raid", kind = "raid",
                frames = {
                    ["Raid"] = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = HEAL_Y,
                                 settings = { FrameWidth = HEAL_W, FrameHeight = 40, BuffIconSize = 50 } },
                    ["Swing timer off hand"]   = { rawSettings = SWING_HIDDEN },
                    ["Swing timer main hand"]  = { rawSettings = SWING_HIDDEN },
                    ["Swing timer ranged"]     = { rawSettings = SWING_HIDDEN },
                },
            },
            -- Casters, hunters and healers on their own: no melee swing timers. The ranged timer (wand, bow, gun)
            -- stays and moves down to the cast bar. Only one extra layout, so Edit Mode keeps room for your own.
            {
                name = "MLZ UI Ranged", archetypes = { CASTER = true, RANGED = true, HEALER = true },
                frames = {
                    ["Swing timer off hand"]   = { rawSettings = SWING_HIDDEN },
                    ["Swing timer main hand"]  = { rawSettings = SWING_HIDDEN },
                    -- Focus is anchored to the ranged timer, so it moves down with it (the space left of the
                    -- swing timers is free, the class bar sits below the cast bar).
                    ["Swing timer ranged"]     = { relTo = "PlayerCastingBarFrame", y = CAST_GAP },
                },
            },
        },
    },
}
