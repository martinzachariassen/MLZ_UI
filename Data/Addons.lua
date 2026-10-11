-- MLZ UI: Settings for other addons (Prat, Auctionator, AtlasLoot, WhatsTraining, Bagnon, RXPGuides)
-- Edit this file to change what the wizard step "Other addons" sets. MLZ UI never downloads or
-- updates these addons; it only configures the ones that are installed and loaded.
--
-- Each addon has:
--   addon   = folder name, used for the "is it loaded?" check
--   title   = heading in the wizard
--   root    = function returning the table that `path` starts from (nil = not available yet)
--   rows    = { id, label, desc, path = { "key", "subkey" }, value, enabled }
--             `enabled = false` means the row is listed but off until you tick it.
--
-- Keys come from each addon's own SavedVariables / defaults, so they only apply to the version
-- you have installed. Rows whose key doesn't exist are skipped with "not available".

local _, ns = ...

-- Prat is built on AceDB: each module has its own namespace, with a profile table
local function PratModule(name)
    return function()
        local db = Prat and Prat.db
        if not (db and db.GetNamespace) then return nil end
        local space = db:GetNamespace("Prat_" .. name, true) or db:GetNamespace(name, true)
        return space and space.profile
    end
end

-- Bagnon keeps its settings in Bagnon_Sets. Frame settings live under .global.<frame>
-- (inventory, bank, vault, guild); the rest sit directly on Bagnon_Sets.
local function BagnonRoot() return Bagnon_Sets end
local function BagnonGlobal() return Bagnon_Sets and Bagnon_Sets.global end

ns.data.addons = {
    {
        addon = "Prat-3.0", title = "Prat (chat)",
        rows = {
            { id = "timestamps", label = "Timestamp format", desc = "24-hour clock without seconds, e.g. [14:32].",
              root = PratModule("Timestamps"), path = { "formatcode" }, value = "%H:%M" },
            { id = "btn_minimize", label = "Hide minimize button", desc = "Removes the small minimize button on each chat tab.",
              root = PratModule("Buttons"), path = { "showminimize" }, value = false },
            { id = "btn_voice", label = "Hide voice button", desc = "Removes the voice chat buttons.",
              root = PratModule("Buttons"), path = { "showvoice" }, value = false },
            { id = "btn_channel", label = "Hide channel button", desc = "Removes the channel button above the chat.",
              root = PratModule("Buttons"), path = { "showchannel" }, value = false },
            { id = "scroll", label = "Scroll speed", desc = "Mouse wheel scrolls 3 lines per notch instead of 1.",
              root = PratModule("Scroll"), path = { "normscrollspeed" }, value = 3 },
            { id = "fade", label = "Chat fade time (s)", desc = "Chat text fades after 45 seconds instead of 120.",
              root = PratModule("Fading"), path = { "duration" }, value = 45 },
        },
    },
    {
        addon = "Auctionator", title = "Auctionator",
        root = function() return AUCTIONATOR_CONFIG end,
        rows = {
            { id = "splash", label = "Hide splash screen", desc = "Skips the what's-new window after updates.",
              path = { "hide_splash_screen" }, value = true },
            { id = "autonext", label = "Auto-select next item", desc = "After posting, the next item in your bags is selected automatically.",
              path = { "selling_auto_select_next" }, value = true },
            { id = "lastduration", label = "Remember last duration", desc = "Uses the duration you picked last time when posting.",
              path = { "save_last_duration_as_default" }, value = true },
        },
    },
    {
        addon = "AtlasLootClassic", title = "AtlasLoot",
        root = function() return AtlasLoot and AtlasLoot.db and AtlasLoot.db.profile end,
        rows = {
            { id = "minimap", label = "Hide minimap button", desc = "You can still open it with /al.",
              path = { "minimap", "hide" }, value = true, enabled = false },
        },
    },
    {
        addon = "WhatsTraining", title = "What's Training?",
        root = function() return _G end,
        rows = {
            { id = "known", label = "Hide known weapon skills", desc = "Only list weapon skills you can still learn.",
              path = { "WT_ShowKnownWeaponSkills" }, value = false },
            { id = "sidebyside", label = "Show beside the trainer window", desc = "Opens the list next to the trainer window.",
              path = { "WT_SideBySide" }, value = true },
        },
    },
    {
        addon = "Bagnon", title = "Bagnon (bags)",
        root = BagnonGlobal,
        rows = {
            { id = "inv_columns", label = "Bag columns", desc = "12 slots per row in the backpack window, a compact block that fits above the action bars.",
              path = { "inventory", "columns" }, value = 12 },
            { id = "bank_columns", label = "Bank columns", desc = "12 slots per row in the bank, the same width as your bags.",
              path = { "bank", "columns" }, value = 12 },
            { id = "inv_color", label = "Bag background", desc = "Darker, more opaque background so item icons stand out.",
              path = { "inventory", "color" }, value = { 0, 0, 0, 0.75 } },
            { id = "bank_color", label = "Bank background", desc = "Same darker background for the bank window.",
              path = { "bank", "color" }, value = { 0, 0, 0, 0.75 } },
            { id = "glow_new", label = "No glow on new items", desc = "Turns off the highlight on newly looted items.",
              root = BagnonRoot, path = { "glowNew" }, value = false },
            { id = "glow_alpha", label = "Softer item glow", desc = "Item border glow at 40% instead of 50%.",
              root = BagnonRoot, path = { "glowAlpha" }, value = 0.4 },
            { id = "open_crafting", label = "No auto-open when crafting", desc = "Bags stay closed when you open a profession window.",
              root = BagnonRoot, path = { "display", "crafting" }, value = false },
            { id = "open_socketing", label = "No auto-open when socketing", desc = "Bags stay closed when you open the socketing window.",
              root = BagnonRoot, path = { "display", "socketing" }, value = false },
            { id = "open_mail", label = "No auto-open at the mailbox", desc = "Bags stay closed when you open your mail.",
              root = BagnonRoot, path = { "display", "mailInfo" }, value = false, enabled = false },
            { id = "count_guild", label = "Hide guild bank counts in tooltips", desc = "Keeps item tooltips shorter. Off by default: tick it if you want it.",
              root = BagnonRoot, path = { "countGuild" }, value = false, enabled = false },
        },
    },
    {
        addon = "RXPGuides", title = "RestedXP Guides",
        root = function()
            local profile = RXPDB and RXPDB.profileKeys and RXPDB.profileKeys[UnitName("player")]
            return profile and RXPDB.profiles and RXPDB.profiles[profile]
        end,
        rows = {
            { id = "scale", label = "Guide window scale", desc = "Scale of the guide window. Off by default: tick it if you want 1.1.",
              path = { "windowScale" }, value = 1.1, enabled = false },
            { id = "lock_frames", label = "Lock frames", desc = "Locks the guide window against dragging (the arrow, targets and items are fixed in a column on the right by MLZ UI, see Data/RXP.lua).",
              path = { "lockFrames" }, value = true },
        },
    },
    -- Deadly Boss Mods. Positions are in UIParent units (same as the Edit Mode layout, 1200 units tall).
    -- The middle of the screen stays clear: timers on the right above the damage meter, warnings top center.
    {
        addon = "DBM-Core", title = "Deadly Boss Mods (warnings)",
        root = function() return DBM and DBM.Options end,
        rows = {
            { id = "warn_point", label = "Warning anchor", desc = "Normal warnings are anchored to the top center of the screen.",
              path = { "WarningPoint" }, value = "TOP" },
            { id = "warn_x", label = "Warning X", desc = "Centered horizontally.",
              path = { "WarningX" }, value = 0 },
            { id = "warn_y", label = "Warning Y", desc = "Above the swing timers and cast bar, out of the middle.",
              path = { "WarningY" }, value = -230 },
            { id = "warn_size", label = "Warning font size", desc = "18 instead of 20, quieter.",
              path = { "WarningFontSize" }, value = 18 },
            { id = "sw_point", label = "Special warning anchor", desc = "Big 'move / interrupt' warnings are anchored to the top center.",
              path = { "SpecialWarningPoint" }, value = "TOP" },
            { id = "sw_x", label = "Special warning X", desc = "Centered horizontally.",
              path = { "SpecialWarningX" }, value = 0 },
            { id = "sw_y", label = "Special warning Y", desc = "Just below the normal warnings, still in your field of view.",
              path = { "SpecialWarningY" }, value = -290 },
            { id = "sw_size", label = "Special warning font size", desc = "28 instead of 35: still clear, but it doesn't cover the screen.",
              path = { "SpecialWarningFontSize2" }, value = 28 },
            { id = "info_point", label = "Info frame anchor", desc = "Info frame (e.g. debuff lists) sits on the right, away from the middle.",
              path = { "InfoFramePoint" }, value = "RIGHT" },
            { id = "info_x", label = "Info frame X", desc = "Left of bars 4-5.",
              path = { "InfoFrameX" }, value = -330 },
            { id = "info_y", label = "Info frame Y", desc = "Slightly above the middle of the right edge.",
              path = { "InfoFrameY" }, value = 160 },
            { id = "range_point", label = "Range frame anchor", desc = "Range frame sits on the right, above the info frame.",
              path = { "RangeFramePoint" }, value = "RIGHT" },
            { id = "range_x", label = "Range frame X", desc = "Left of bars 4-5.",
              path = { "RangeFrameX" }, value = -330 },
            { id = "range_y", label = "Range frame Y", desc = "Above the info frame.",
              path = { "RangeFrameY" }, value = 300 },
            { id = "range_radar_point", label = "Radar anchor", desc = "Radar sits next to the range frame.",
              path = { "RangeFrameRadarPoint" }, value = "RIGHT" },
            { id = "range_radar_x", label = "Radar X", desc = "Left of bars 4-5.",
              path = { "RangeFrameRadarX" }, value = -330 },
            { id = "range_radar_y", label = "Radar Y", desc = "Above the info frame.",
              path = { "RangeFrameRadarY" }, value = 300 },
        },
    },
    {
        addon = "DBM-StatusBarTimers", title = "Deadly Boss Mods (timer bars)",
        root = function() return DBT and DBT.Options end,
        rows = {
            { id = "bar_point", label = "Timer anchor", desc = "Bars hang from the right edge, above the damage meter.",
              path = { "TimerPoint" }, value = "BOTTOMRIGHT" },
            { id = "bar_x", label = "Timer X", desc = "Left of bars 4-5 (mouseover).",
              path = { "TimerX" }, value = -100 },
            { id = "bar_y", label = "Timer Y", desc = "Above the damage meter.",
              path = { "TimerY" }, value = 360 },
            { id = "bar_up", label = "Grow upward", desc = "New bars stack upward, away from the damage meter.",
              path = { "ExpandUpwards" }, value = true },
            { id = "bar_width", label = "Bar width", desc = "Slimmer bars (170 instead of 183).",
              path = { "Width" }, value = 170 },
            { id = "bar_height", label = "Bar height", desc = "Thin bars (16 instead of 20).",
              path = { "Height" }, value = 16 },
            { id = "bar_scale", label = "Bar scale", desc = "Same size as the default.",
              path = { "Scale" }, value = 0.9 },
            { id = "huge", label = "No separate large bars", desc = "Bars stay in one stack instead of jumping to the center of the screen at 10 seconds.",
              path = { "HugeBarsEnabled" }, value = false },
        },
    },
    -- Leatrix Plus: only what MLZ UI doesn't already do. Not touched on purpose:
    --   camera zoom, hotkey/macro text (MLZ sets those), chat tweaks (Prat), minimap clutter (already hidden).
    -- Values are "On" / "Off" strings, as Leatrix stores them. Needs /reload.
    {
        addon = "Leatrix_Plus", title = "Leatrix Plus",
        root = function() return LeaPlusDB end,
        rows = {
            { id = "sell_junk", label = "Auto-sell grey items", desc = "Sells all grey items when you open a vendor.",
              path = { "AutoSellJunk" }, value = "On" },
            { id = "repair", label = "Auto-repair", desc = "Repairs all your gear at a vendor. Guild funds are used first (already on).",
              path = { "AutoRepairGear" }, value = "On" },
            { id = "fast_loot", label = "Faster auto loot", desc = "Loots faster when MLZ's auto loot is on.",
              path = { "FasterLooting" }, value = "On" },
            { id = "minimap_icon", label = "Hide Leatrix minimap icon", desc = "Open it with /ltp instead.",
              path = { "ShowMinimapIcon" }, value = "Off" },
            { id = "auto_quests", label = "Automate quests", desc = "Accepts and turns in quests automatically. Off by default: tick it if you want it, and check it doesn't clash with RestedXP Guides.",
              path = { "AutomateQuests" }, value = "On", enabled = false },
            { id = "auto_role", label = "Auto-confirm role", desc = "Accepts the role check in group finder. Off by default.",
              path = { "AutoConfirmRole" }, value = "On", enabled = false },
            { id = "no_bag_auto", label = "No bag auto-open", desc = "Bags stay closed at vendors, bank and mail. Off by default.",
              path = { "NoBagAutomation" }, value = "On", enabled = false },
        },
    },
    {
        addon = "Leatrix_Maps", title = "Leatrix Maps",
        root = function() return LeaMapsDB end,
        rows = {
            { id = "minimap_icon", label = "Hide Leatrix Maps minimap icon", desc = "Keeps the minimap clean. The map settings are already set up.",
              path = { "ShowMinimapIcon" }, value = "Off" },
        },
    },
}
