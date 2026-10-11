-- MLZ UI: Settings for other addons (Prat, Auctionator, AtlasLoot, WhatsTraining, Bagnon, RXPGuides,
-- Deadly Boss Mods, Leatrix Plus, Leatrix Maps)
-- Edit this file to change what the wizard step "Other addons" sets. MLZ UI never downloads or
-- updates these addons; it only configures the ones that are installed and loaded.
--
-- Each addon has:
--   addon   = folder name, used for the "is it loaded?" check
--   title   = heading in the wizard
--   root    = function returning the table that `path` starts from (nil = not available yet)
--   rows    = { id, label, desc, path = { "key", "subkey" }, value, enabled }
--             `enabled = false` means the row is listed but off until you tick it.
--             A row can have its own `root`. Instead of path/value a row can set several keys at
--             once: set = { { path = {...}, value = ... }, ... } and show = "%s %s" (format for the
--             wizard, one %s per key in order).
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
            { id = "lock_frames", label = "Lock frames", desc = "Locks the guide window against dragging.",
              path = { "lockFrames" }, value = true },
            { id = "column", label = "Fixed column on the right", desc = "MLZ UI places the guide, arrow, targets and items in one column on the right edge (see Data/RXP.lua). Needs /reload; when off, the boxes are movable again after /reload.",
              root = function() return ns.db end, path = { "rxpColumn" }, value = true },
        },
    },
    -- Deadly Boss Mods. Positions are in UIParent units (same as the Edit Mode layout, 1200 units tall).
    -- The middle of the screen stays clear: timers on the right above the damage meter, warnings top center.
    -- Each row sets several keys at once (`set`), shown with `show` in the wizard.
    {
        addon = "DBM-Core", title = "Deadly Boss Mods",
        root = function() return DBM and DBM.Options end,
        rows = {
            { id = "warn", label = "Warnings", show = "%s %s,%s  %spt",
              desc = "Normal warnings at the top center, above the cast bar, font 18 instead of 20.",
              set = { { path = { "WarningPoint" }, value = "TOP" }, { path = { "WarningX" }, value = 0 },
                      { path = { "WarningY" }, value = -230 }, { path = { "WarningFontSize" }, value = 18 } } },
            { id = "sw", label = "Special warnings", show = "%s %s,%s  %spt",
              desc = "Big 'move / interrupt' warnings just below the normal ones, font 28 instead of 35.",
              set = { { path = { "SpecialWarningPoint" }, value = "TOP" }, { path = { "SpecialWarningX" }, value = 0 },
                      { path = { "SpecialWarningY" }, value = -290 }, { path = { "SpecialWarningFontSize2" }, value = 28 } } },
            { id = "info", label = "Info frame", show = "%s %s,%s",
              desc = "Debuff lists etc. on the right, left of bars 4-5, away from the middle.",
              set = { { path = { "InfoFramePoint" }, value = "RIGHT" }, { path = { "InfoFrameX" }, value = -330 },
                      { path = { "InfoFrameY" }, value = 160 } } },
            { id = "range", label = "Range frame", show = "%s %s,%s",
              desc = "On the right, above the info frame.",
              set = { { path = { "RangeFramePoint" }, value = "RIGHT" }, { path = { "RangeFrameX" }, value = -330 },
                      { path = { "RangeFrameY" }, value = 300 } } },
            { id = "radar", label = "Range radar", show = "%s %s,%s",
              desc = "Next to the range frame.",
              set = { { path = { "RangeFrameRadarPoint" }, value = "RIGHT" }, { path = { "RangeFrameRadarX" }, value = -330 },
                      { path = { "RangeFrameRadarY" }, value = 300 } } },
        },
    },
    {
        addon = "DBM-StatusBarTimers", title = "Deadly Boss Mods (timer bars)",
        root = function() return DBT and DBT.Options end,
        rows = {
            { id = "position", label = "Timer position", show = "%s %s,%s  up: %s",
              desc = "Bars hang from the right edge above the damage meter and stack upward.",
              set = { { path = { "TimerPoint" }, value = "BOTTOMRIGHT" }, { path = { "TimerX" }, value = -100 },
                      { path = { "TimerY" }, value = 360 }, { path = { "ExpandUpwards" }, value = true } } },
            { id = "size", label = "Timer size", show = "%sx%s  x%s",
              desc = "Slimmer bars: 170x16 instead of 183x20, at 90% scale.",
              set = { { path = { "Width" }, value = 170 }, { path = { "Height" }, value = 16 },
                      { path = { "Scale" }, value = 0.9 } } },
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
