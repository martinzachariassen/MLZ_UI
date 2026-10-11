-- MLZ UI: Settings for other addons (Prat, Auctionator, AtlasLoot, WhatsTraining, RXPGuides)
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
        addon = "RXPGuides", title = "RestedXP Guides",
        root = function()
            local profile = RXPDB and RXPDB.profileKeys and RXPDB.profileKeys[UnitName("player")]
            return profile and RXPDB.profiles and RXPDB.profiles[profile]
        end,
        rows = {
            { id = "scale", label = "Guide window scale", desc = "Scale of the guide window. Off by default: tick it if you want 1.1.",
              path = { "windowScale" }, value = 1.1, enabled = false },
        },
    },
}
