-- MLZ UI: Layout specification for Edit Mode (minimalist)
-- Edit freely. The logic lives in Modules/Layout.lua.
--
-- Screen layout (scale 0.64 => the screen is 1200 units tall):
--
--   [tracker]                                              [buffs][minimap]
--
--                                                                    [bar4][bar5]
--          [focus]               [swing ranged]                       (mouseover)
--                                [swing main  ]
--                     [stance]   [swing off   ]   [pet]
--                                [  cast bar  ]
--          [player]   [ bar 3  (Ctrl)  ]   [target]
--                     [ bar 2  (Shift) ]
--                     [ bar 1          ]
--   [party / raid    ]   (5 per row, growing upward from here)
--   [bar 6, separate ]
--   [chat]            [ XP / rep, small]                    [meter][micro/bags]
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
--   override = { [settingName] = key in MLZUIDB.overrides } — the user's own choice (e.g. /mlz map) wins.

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

local STACK_TOP = BASE + 3 * ROW               -- top edge of bar 3 (top of the stack)

-- Above the stack, bottom to top (all centered on the middle of the screen):
--   cast bar  ->  swing off hand  ->  swing main hand  ->  swing ranged
-- The swing timers are anchored to each other and to the top of the cast bar, so they never overlap,
-- no matter how tall the frames actually are. Stance/pet line up with off hand, focus lines up with ranged.
local CAST_TEXT = 12                           -- the text under the cast bar hangs about 12 units below the frame
local CAST_Y = STACK_TOP + CAST_TEXT + 6       -- bottom edge of cast bar (6 units of space above bar 3)
local CAST_GAP = 4                             -- gap between cast bar and off hand
local SWING_GAP = 2                            -- gap between the swing timers

-- Swing timer settings are stored raw (width/height in units before scale, Scale in steps)
-- Width 453 = the same width the game currently shows.
local SWING = { Scale = 0, Opacity = 100, Width = 453, Height = 15, ShowBarTitle = 0, ShowTime = 0, Visibility = 1 }

-- Chat at bottom left, with bar 6 (no hotkeys) right above it
local CHAT_Y = 40                              -- bottom edge of chat (room for the input box below)
local CHAT_H = 170                             -- chat height
local BAR6_Y = CHAT_Y + CHAT_H + 28            -- bottom edge of bar 6 (above the chat tabs)
local BAR6_BTN = 32                            -- bar 6 button size in units (70 % icons)

-- Party / raid frames: bottom left, directly above bar 6. 80 x 40 per frame, 5 per row = 400 wide (same as chat).
local GROUP_W, GROUP_H, GROUP_ROW = 80, 40, 5
local GROUP_Y = BAR6_Y + BAR6_BTN + 8

local MAIN_BAR = { Orientation = 0, NumRows = 1, NumIcons = 12, IconSize = ICON, IconPadding = PAD,
                   HideBarArt = 1, HideBarScrolling = 1, AlwaysShowButtons = 0 }
local SIDE_BAR = { Orientation = 1, NumRows = 1, IconSize = 70, IconPadding = PAD, AlwaysShowButtons = 0 }
local SMALL_BAR = { IconSize = 60, IconPadding = PAD }

ns.data.layout = {
    name = "MLZ UI",   -- name of the Edit Mode layout that is created / updated

    -- Action bars to enable (bars 2-6). Bars 4-5 are hidden until mouseover in Fade. Bar 6 = separate bar above chat.
    showBars = { 2, 3, 4, 5, 6 },

    frames = {
        -- Combat cluster: three tightly stacked bars, bar 1 at the bottom
        { label = "Bar 1", system = "ActionBar", indexEnum = ABI, index = "MainBar",
          point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = BASE, settingEnum = AB, settings = MAIN_BAR },
        { label = "Bar 2 (Shift)", system = "ActionBar", indexEnum = ABI, index = "Bar2",
          point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = BASE + ROW, settingEnum = AB, settings = MAIN_BAR },
        { label = "Bar 3 (Ctrl)", system = "ActionBar", indexEnum = ABI, index = "Bar3",
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
          settingEnum = "EditModeSwingTimerSetting", rawSettings = SWING },
        { label = "Swing timer main hand", system = "SwingTimer",
          indexEnum = "EditModeSwingTimerSystemIndices", index = "MainHand",
          point = "BOTTOM", relPoint = "TOP", relTo = "SwingTimerOffHandFrame", x = 0, y = SWING_GAP,
          settingEnum = "EditModeSwingTimerSetting", rawSettings = SWING },
        { label = "Swing timer ranged", system = "SwingTimer",
          indexEnum = "EditModeSwingTimerSystemIndices", index = "Ranged",
          point = "BOTTOM", relPoint = "TOP", relTo = "SwingTimerMainHandFrame", x = 0, y = SWING_GAP,
          settingEnum = "EditModeSwingTimerSetting", rawSettings = SWING },

        -- Stance on the left and pet on the right, in line with off hand and with the edges of the stack.
        -- Anchored to the center of the off hand bar, so x = half the stack width no matter how wide the bar is.
        { label = "Stance bar", system = "ActionBar", indexEnum = ABI, index = "StanceBar",
          point = "BOTTOMLEFT", relPoint = "BOTTOM", relTo = "SwingTimerOffHandFrame", x = -HALF, y = 0,
          settingEnum = AB, settings = SMALL_BAR },
        { label = "Pet bar", system = "ActionBar", indexEnum = ABI, index = "PetActionBar",
          point = "BOTTOMRIGHT", relPoint = "BOTTOM", relTo = "SwingTimerOffHandFrame", x = HALF, y = 0,
          settingEnum = AB, settings = SMALL_BAR },

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
        { label = "Debuffs", system = "AuraFrame", indexEnum = "EditModeAuraFrameSystemIndices", index = "DebuffFrame",
          point = "TOPRIGHT", relPoint = "TOPLEFT", relTo = "MinimapCluster", x = -6, y = -104,
          settingEnum = "EditModeAuraFrameSetting", settings = { IconSize = 80, IconPadding = 5 } },

        -- Quest tracker: top left, short (hidden in combat, see Data/Fade.lua)
        { label = "Quest tracker", system = "ObjectiveTracker",
          point = "TOPLEFT", relPoint = "TOPLEFT", x = 10, y = -10,
          settingEnum = "EditModeObjectiveTrackerSetting", settings = { Height = 400, TextSize = 12 } },
        { label = "Boss frames", system = "UnitFrame", indexEnum = UFI, index = "Boss",
          point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -60, y = -240 },

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

        -- Right edge: bars 4-5 vertical (hidden until mouseover)
        { label = "Bar 4 (mouseover)", system = "ActionBar", indexEnum = ABI, index = "RightBar1",
          point = "RIGHT", relPoint = "RIGHT", x = -4, y = -60, settingEnum = AB, settings = SIDE_BAR },
        { label = "Bar 5", system = "ActionBar", indexEnum = ABI, index = "RightBar2",
          point = "RIGHT", relPoint = "RIGHT", x = -40, y = -60, settingEnum = AB, settings = SIDE_BAR },

        -- Bottom right: the "clutter corner" (hidden until mouseover). Raised 14 units: the FPS counter sits at the very bottom.
        { label = "Bags", system = "Bags",
          point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -4, y = 18,
          settingEnum = "EditModeBagsSetting", settings = { Size = 75 } },
        { label = "Micro menu", system = "MicroMenu",
          point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -4, y = 50,
          settingEnum = "EditModeMicroMenuSetting", settings = { Size = 70 } },
        { label = "Damage meter", system = "DamageMeter",
          point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -80, y = 80 },
    },
}
