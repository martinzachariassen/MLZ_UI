-- MLZ UI: Layoutspesifikasjon for Edit Mode (minimalistisk)
-- Rediger fritt. Logikken ligger i Modules/Layout.lua.
--
-- Skjermbilde (skala 0.64 => skjermen er 1200 enheter høy):
--
--   [tracker]                                              [buffs][minimap]
--
--   [party]                                                          [bar4][bar5]
--                                [  cast bar  ]                       (mouseover)
--   [focus]           [stance]                    [pet]
--                                [ swing timer]
--          [player]   [ bar 3  (Ctrl)  ]   [target]
--                     [ bar 2  (Shift) ]
--                     [ bar 1          ]
--   [bar 6, egen     ]
--   [food/pots, auto ]
--   [chat]            [ XP / rep, liten]                    [meter][micro/bags]
--
-- Prinsipper (inspirert av ElvUI / Bartender4 / Dominos-oppsett):
--   * Midten av skjermen er fri. Alt du trenger i kamp ligger samlet nederst i midten.
--   * Barene ligger tett stablet (2 enheters mellomrom), uten art, gryphons eller tomme slots.
--   * Player og target flankerer stacken, slik at øynene ikke må lenger enn til kanten av barene.
--   * Hjørner brukes til ting du bare sjekker. Bags, micro menu og bar 4-5 er skjult til mouseover.
--
-- Felter:
--   point    = punktet på framen som ankres
--   relPoint = punktet på relTo (standard: hele skjermen / UIParent) det ankres til
--   relTo    = (valgfri) navnet på en annen frame å ankre til
--   x, y     = offset i UI-enheter
--   settings = { [settingnavn] = verdi } i SAMME enheter som Edit Mode viser (IconSize = 80 betyr 80 %).
--              Modulen konverterer til lagringsformatet. Av/på: 1 = på, 0 = av.
--   rawSettings = settings som lagres direkte uten konvertering (f.eks. chat-størrelse).
--   override = { [settingnavn] = nøkkel i MLZUIDB.overrides } — brukerens eget valg (f.eks. /mlz map) vinner.

local _, ns = ...

local AB = "EditModeActionBarSetting"
local ABI = "EditModeActionBarSystemIndices"
local UF = "EditModeUnitFrameSetting"
local UFI = "EditModeUnitFrameSystemIndices"

-- Mål for stacken (brukes til å regne ut posisjoner, så alt henger sammen hvis du endrer størrelsen)
local ICON = 80                                -- ikonstørrelse i % (100 % = 45 enheter)
local PAD = 2                                  -- mellomrom mellom knapper
local BTN = math.floor(45 * ICON / 100 + 0.5)  -- knappestørrelse i enheter (36)
local ROW = BTN + PAD                          -- avstand mellom barene i stacken (38)
local HALF = math.floor((12 * BTN + 11 * PAD) / 2 + 0.5) -- halv bredde av en bar (227)
local BASE = 30                                -- underkant av bar 1 (gir plass til XP-baren under)
local GAP = 8                                  -- luft mellom stacken og player/target
local UNIT_Y = BASE + 40                       -- underkant av player/target (plass til target of target under)

local STACK_TOP = BASE + 3 * ROW               -- overkant av bar 3 (toppen av stacken)
-- Swing timer: Scale 50 % (minste mulige) og minste høyde => tynn strek, halvparten så bred som stacken.
-- Edit Mode-offset for en skalert frame måles i framens egen skala, derfor deles y på SWING_SCALE.
local SWING_SCALE = 0.5                        -- 50 %
local SWING_H = 15 * SWING_SCALE               -- synlig høyde på skjermen (7,5 enheter)
local SWING_Y = STACK_TOP + 2                  -- main hand rett over toppen av stacken
local SWING_TOP = SWING_Y + 2 * SWING_H + 2    -- overkant av off hand / ranged
local SMALL_Y = SWING_TOP + 3                  -- stance/pet over swing timerne
local SMALL_TOP = SMALL_Y + 27                 -- overkant av stance/pet (60 % ikoner = 27 enheter)
local CAST_Y = SMALL_TOP + 8                   -- cast bar øverst

-- Swing timer-settings lagres rått (bredde/høyde i enheter før skala, Scale i steg: 0 = 50 %, 5 = 100 %)
local SWING = { Scale = 0, Opacity = 100, Width = 213 + 10 * math.floor((2 * HALF - 213) / 10 + 0.5),
                Height = 15, ShowBarTitle = 0, ShowTime = 0, Visibility = 1 }

-- Chat nede til venstre, med to barer uten hotkeys rett over (forbruksvarer + bar 6)
local CHAT_Y = 40                              -- underkant av chat (plass til skrivefeltet under)
local CHAT_H = 170                             -- chat-høyde
local UTIL_Y = CHAT_Y + CHAT_H + 28            -- auto-bar for forbruksvarer (over chat-fanene)
local UTIL_BTN = 32                            -- knappestørrelse i begge barene over chatten
ns.data.utilBarPos = { point = "BOTTOMLEFT", x = 6, y = UTIL_Y, size = UTIL_BTN, spacing = PAD }

local MAIN_BAR = { Orientation = 0, NumRows = 1, NumIcons = 12, IconSize = ICON, IconPadding = PAD,
                   HideBarArt = 1, HideBarScrolling = 1, AlwaysShowButtons = 0 }
local SIDE_BAR = { Orientation = 1, NumRows = 1, IconSize = 70, IconPadding = PAD, AlwaysShowButtons = 0 }
local SMALL_BAR = { IconSize = 60, IconPadding = PAD }

ns.data.layout = {
    name = "MLZ UI",   -- navnet på Edit Mode-layouten som opprettes / oppdateres

    -- Action bars som skal være aktive (bar 2-6). Bar 4-5 skjules til mouseover i Fade. Bar 6 = egen bar over chat.
    showBars = { 2, 3, 4, 5, 6 },

    frames = {
        -- Kamp-klyngen: tre barer stablet tett, bar 1 nederst
        { label = "Bar 1", system = "ActionBar", indexEnum = ABI, index = "MainBar",
          point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = BASE, settingEnum = AB, settings = MAIN_BAR },
        { label = "Bar 2 (Shift)", system = "ActionBar", indexEnum = ABI, index = "Bar2",
          point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = BASE + ROW, settingEnum = AB, settings = MAIN_BAR },
        { label = "Bar 3 (Ctrl)", system = "ActionBar", indexEnum = ABI, index = "Bar3",
          point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = BASE + 2 * ROW, settingEnum = AB, settings = MAIN_BAR },

        -- Gryphons / endekapper på hovedbaren
        { label = "Gryphon venstre (skjul)", system = "MainActionBarEndCap",
          indexEnum = "EditModeMainActionBarEndCapSystemIndices", index = "EndCapLeft", keepAnchor = true,
          settingEnum = "EditModeMainActionBarEndCapSetting", rawSettings = { Hidden = 1 } },
        { label = "Gryphon høyre (skjul)", system = "MainActionBarEndCap",
          indexEnum = "EditModeMainActionBarEndCapSystemIndices", index = "EndCapRight", keepAnchor = true,
          settingEnum = "EditModeMainActionBarEndCapSetting", rawSettings = { Hidden = 1 } },

        -- Små barer over swing timerne: stance til venstre, pet til høyre, cast bar over midten
        { label = "Stance bar", system = "ActionBar", indexEnum = ABI, index = "StanceBar",
          point = "BOTTOMLEFT", relPoint = "BOTTOM", x = -HALF, y = SMALL_Y, settingEnum = AB, settings = SMALL_BAR },
        { label = "Pet bar", system = "ActionBar", indexEnum = ABI, index = "PetActionBar",
          point = "BOTTOMRIGHT", relPoint = "BOTTOM", x = HALF, y = SMALL_Y, settingEnum = AB, settings = SMALL_BAR },

        -- Swing timers (innebygd i klienten): tynne streker, halvparten så brede som stacken, rett over bar 3.
        -- Off hand og ranged deler plass (få har begge). Vises bare i kamp.
        { label = "Swing timer main hand", system = "SwingTimer",
          indexEnum = "EditModeSwingTimerSystemIndices", index = "MainHand",
          point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = SWING_Y / SWING_SCALE,
          settingEnum = "EditModeSwingTimerSetting", rawSettings = SWING },
        { label = "Swing timer off hand", system = "SwingTimer",
          indexEnum = "EditModeSwingTimerSystemIndices", index = "OffHand",
          point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = (SWING_Y + SWING_H + 2) / SWING_SCALE,
          settingEnum = "EditModeSwingTimerSetting", rawSettings = SWING },
        { label = "Swing timer ranged", system = "SwingTimer",
          indexEnum = "EditModeSwingTimerSystemIndices", index = "Ranged",
          point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = (SWING_Y + SWING_H + 2) / SWING_SCALE,
          settingEnum = "EditModeSwingTimerSetting", rawSettings = SWING },

        { label = "Cast bar", system = "CastBar",
          point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = CAST_Y,
          settingEnum = "EditModeCastBarSetting", settings = { LockToPlayerFrame = 0, BarSize = 100, ShowCastTime = 1 } },

        -- XP / rep: liten, helt nederst under stacken
        { label = "XP-bar (liten, nederst)", system = "StatusTrackingBar",
          indexEnum = "EditModeStatusTrackingBarSystemIndices", index = "StatusTrackingBar1",
          point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 2,
          settingEnum = "EditModeStatusTrackingBarSetting", settings = { Size = 50 } },
        { label = "Rep-bar (over XP)", system = "StatusTrackingBar",
          indexEnum = "EditModeStatusTrackingBarSystemIndices", index = "StatusTrackingBar2",
          point = "BOTTOM", relPoint = "TOP", relTo = "MainStatusTrackingBarContainer", x = 0, y = 1,
          settingEnum = "EditModeStatusTrackingBarSetting", settings = { Size = 50 } },

        -- Player / target flankerer stacken, løftet så target of target (under target) ikke dekkes
        { label = "Player", system = "UnitFrame", indexEnum = UFI, index = "Player",
          point = "BOTTOMRIGHT", relPoint = "BOTTOM", x = -(HALF + GAP), y = UNIT_Y, settingEnum = UF, settings = { FrameSize = 100 } },
        { label = "Target", system = "UnitFrame", indexEnum = UFI, index = "Target",
          point = "BOTTOMLEFT", relPoint = "BOTTOM", x = HALF + GAP, y = UNIT_Y, settingEnum = UF, settings = { FrameSize = 100 } },
        { label = "Focus", system = "UnitFrame", indexEnum = UFI, index = "Focus",
          point = "BOTTOMRIGHT", relPoint = "BOTTOM", x = -(HALF + GAP), y = CAST_Y, settingEnum = UF, settings = { FrameSize = 100 } },

        -- Gruppe: venstre side
        { label = "Party", system = "UnitFrame", indexEnum = UFI, index = "Party",
          point = "LEFT", relPoint = "LEFT", x = 10, y = 60, settingEnum = UF, settings = { UseRaidStylePartyFrames = 1 } },
        { label = "Raid", system = "UnitFrame", indexEnum = UFI, index = "Raid",
          point = "LEFT", relPoint = "LEFT", x = 10, y = 60 },

        -- Øverst til høyre: minimap (130 %), små buffs til venstre for den
        -- Size kan endres med /mlz map (lagres i MLZUIDB.overrides.minimapSize og overstyrer 130 her).
        -- Buffs/debuffs er ankret til venstre kant av minimap, så de flytter seg når størrelsen endres.
        { id = "minimap", label = "Minimap", system = "Minimap",
          point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -6, y = -6,
          settingEnum = "EditModeMinimapSetting", settings = { Size = 130 }, override = { Size = "minimapSize" } },
        { label = "Buffs", system = "AuraFrame", indexEnum = "EditModeAuraFrameSystemIndices", index = "BuffFrame",
          point = "TOPRIGHT", relPoint = "TOPLEFT", relTo = "MinimapCluster", x = -6, y = -2,
          settingEnum = "EditModeAuraFrameSetting", settings = { IconSize = 70, IconPadding = 5 } },
        { label = "Debuffs", system = "AuraFrame", indexEnum = "EditModeAuraFrameSystemIndices", index = "DebuffFrame",
          point = "TOPRIGHT", relPoint = "TOPLEFT", relTo = "MinimapCluster", x = -6, y = -104,
          settingEnum = "EditModeAuraFrameSetting", settings = { IconSize = 80, IconPadding = 5 } },

        -- Quest tracker: øverst til venstre, kort (skjules i kamp, se Data/Fade.lua)
        { label = "Quest tracker", system = "ObjectiveTracker",
          point = "TOPLEFT", relPoint = "TOPLEFT", x = 10, y = -10,
          settingEnum = "EditModeObjectiveTrackerSetting", settings = { Height = 400, TextSize = 12 } },
        { label = "Boss frames", system = "UnitFrame", indexEnum = UFI, index = "Boss",
          point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -60, y = -240 },

        -- Nederst til venstre: liten chat (400 x 170). Løftet 40 enheter så skrivefeltet under chatten synes.
        { label = "Chat", system = "ChatFrame",
          point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = 6, y = CHAT_Y,
          settingEnum = "EditModeChatFrameSetting",
          rawSettings = { WidthHundreds = 4, WidthTensAndOnes = 0, HeightHundreds = 1, HeightTensAndOnes = 70 } },

        -- Bar 6 over chatten, rett over auto-baren for forbruksvarer. Ingen hotkeys: dra inn
        -- hearthstone, mount, profesjoner osv. (70 % ikoner = 32 enheter, 12 knapper = ca. chat-bredden)
        { label = "Bar 6 (over chat)", system = "ActionBar", indexEnum = ABI, index = "ExtraBar1",
          point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = 6, y = UTIL_Y + UTIL_BTN + 4, settingEnum = AB,
          settings = { Orientation = 0, NumRows = 1, NumIcons = 12, IconSize = 70, IconPadding = PAD, AlwaysShowButtons = 0 } },

        -- Høyre kant: bar 4-5 vertikalt (skjult til mouseover)
        { label = "Bar 4 (mus)", system = "ActionBar", indexEnum = ABI, index = "RightBar1",
          point = "RIGHT", relPoint = "RIGHT", x = -4, y = -60, settingEnum = AB, settings = SIDE_BAR },
        { label = "Bar 5", system = "ActionBar", indexEnum = ABI, index = "RightBar2",
          point = "RIGHT", relPoint = "RIGHT", x = -40, y = -60, settingEnum = AB, settings = SIDE_BAR },

        -- Nederst til høyre: "rot-hjørnet" (skjult til mouseover). Løftet 14 enheter: FPS-telleren ligger helt nederst.
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
