-- MLZ UI: Settings for other addons (Prat, Auctionator, AtlasLoot, WhatsTraining, Bagnon, Baganator,
-- RXPGuides, Questie, Deadly Boss Mods, Leatrix Plus, Leatrix Maps, Details!, Clique, TomTom, Postal)
-- Edit this file to change what the wizard step "Other addons" sets. MLZ UI never downloads or
-- updates these addons; it only configures the ones that are installed and loaded.
--
-- Each addon has:
--   addon   = folder name, used for the "is it loaded?" check
--   alt     = (optional) a second folder name, for ports that install under another name
--   requires = (optional) folder name of an addon this one needs; rows say why they can't be used without it
--   manual  = (optional) text: rows are shown but never written (the addon overwrites outside changes)
--   title   = heading in the wizard
--   live    = true if the addon reads these settings while it runs, so no reload is asked for
--   root    = function returning the table that `path` starts from (nil = not available yet)
--   rows    = { id, label, desc, path = { "key", "subkey" }, value, enabled }
--             `enabled = false` means the row is listed but off until you tick it.
--             `roles = { HEALER = true }` and `archetypes = { CASTER = true, RANGED = true }` limit a row to
--             the role or archetype you picked (TANK, HEALER, DAMAGER / TANK, HEALER, MELEE, RANGED, CASTER).
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
            { id = "ctrl_scroll", label = "Ctrl + scroll speed", desc = "Holding CTRL while you scroll jumps 10 lines instead of 3.",
              root = PratModule("Scroll"), path = { "ctrlscrollspeed" }, value = 10 },
            { id = "levels", label = "No levels in player names", desc = "Chat names show [Name] instead of [Name:60].",
              root = PratModule("PlayerNames"), path = { "level" }, value = false },
            { id = "subgroup", label = "No raid group numbers", desc = "Raid chat names don't get the group number added.",
              root = PratModule("PlayerNames"), path = { "subgroup" }, value = false },
        },
    },
    {
        addon = "Auctionator", title = "Auctionator",
        live = true, -- reads its settings each time they are used: no reload needed
        root = function() return AUCTIONATOR_CONFIG end,
        rows = {
            { id = "splash", label = "Hide splash screen", desc = "Skips the what's-new window after updates.",
              path = { "hide_splash_screen" }, value = true },
            { id = "autonext", label = "Auto-select next item", desc = "After posting, the next item in your bags is selected automatically.",
              path = { "selling_auto_select_next" }, value = true },
            { id = "lastduration", label = "Remember last duration", desc = "Uses the duration you picked last time when posting.",
              path = { "save_last_duration_as_default" }, value = true },
            { id = "chatlog", label = "Quiet posting", desc = "No chat line for every auction you post.",
              path = { "auction_chat_log" }, value = false },
        },
    },
    -- AtlasLoot.db IS the active profile table (AtlasLoot.lua: self.db = self.dbRaw.profile). The minimap button
    -- reads `shown` at load and sets `hide` from it, so both have to be written.
    {
        addon = "AtlasLootClassic", title = "AtlasLoot",
        root = function() return AtlasLoot and AtlasLoot.db end,
        rows = {
            { id = "minimap", label = "Hide minimap button", show = "shown: %s  hide: %s", desc = "You can still open it with /al.",
              set = { { path = { "minimap", "shown" }, value = false }, { path = { "minimap", "hide" }, value = true } },
              enabled = false },
        },
    },
    {
        addon = "WhatsTraining", title = "What's Training?",
        live = true, -- reads its settings when the window opens: no reload needed
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
            { id = "open_auction", label = "No auto-open at the auction house", desc = "Bags stay closed when you open the auction house. Off by default.",
              root = BagnonRoot, path = { "display", "auctioneer" }, value = false, enabled = false },
            { id = "count_guild", label = "Hide guild bank counts in tooltips", desc = "Keeps item tooltips shorter. Off by default: tick it if you want it.",
              root = BagnonRoot, path = { "countGuild" }, value = false, enabled = false },
        },
    },
    -- Baganator (needs Syndicator). Settings live in BAGANATOR_CONFIG.Profiles[<current profile>] and are
    -- not rewritten at logout. Baganator only redraws through its private setter: needs /reload.
    {
        addon = "Baganator", requires = "Syndicator", title = "Baganator (bags)",
        root = function()
            local profiles = BAGANATOR_CONFIG and BAGANATOR_CONFIG.Profiles
            return profiles and profiles[BAGANATOR_CURRENT_PROFILE or "DEFAULT"]
        end,
        rows = {
            { id = "grey_junk", label = "Grey out junk", desc = "Junk items are drawn in grey, so the useful ones stand out.",
              path = { "icon_grey_junk" }, value = true },
            { id = "unusable", label = "Mark items you can't use", desc = "Items your class can't use get a red tint.",
              path = { "icon_mark_unusable" }, value = true },
            { id = "open_crafting", label = "No auto-open when crafting", desc = "Bags stay closed when you open a profession window.",
              path = { "auto_open", "tradeskill" }, value = false },
            { id = "open_sockets", label = "No auto-open when socketing", desc = "Bags stay closed when you open the socketing window.",
              path = { "auto_open", "sockets" }, value = false },
            { id = "flashing", label = "No flashing new items", desc = "Newly looted items don't pulse in your bags.",
              path = { "new_items_flashing" }, value = false },
        },
    },
    {
        addon = "RXPGuides", title = "RestedXP Guides",
        root = function()
            -- AceDB keys characters as "Name - Realm"
            local keys = RXPDB and RXPDB.profileKeys
            local name = UnitName("player")
            local profile = keys and (keys[name .. " - " .. (GetRealmName() or "")] or keys[name])
            return profile and RXPDB.profiles and RXPDB.profiles[profile]
        end,
        rows = {
            { id = "scale", label = "Guide window scale", desc = "Scale of the guide window. Off by default: tick it if you want 1.1.",
              path = { "windowScale" }, value = 1.1, enabled = false },
            { id = "lock_frames", label = "Lock frames", desc = "Locks the guide window against dragging.",
              path = { "lockFrames" }, value = true },
            { id = "minimap", label = "Hide minimap button", desc = "Keeps the minimap clean. Open the guide from the world map button or /rxp.",
              path = { "enableMinimapButton" }, value = false },
            { id = "levelup_emote", label = "No level-up emote", desc = "Stops the automatic emote other players see when you level up alone.",
              path = { "enableLevelUpAnnounceSolo" }, value = false },
        },
    },
    -- Questie (AceDB). Defaults: Modules/Options/QuestieOptionsDefaults.lua. Questie keeps no private copy,
    -- so changes survive logout. Most options only redraw through Questie's own setters: needs /reload.
    {
        addon = "Questie", title = "Questie (quests)",
        root = function() return Questie and Questie.db and Questie.db.profile end,
        rows = {
            { id = "minimap", label = "Hide minimap button", desc = "Keeps the minimap clean. Open the settings with /questie.",
              path = { "minimap", "hide" }, value = true },
            -- Questie refuses both at once (hide and minimize exclude each other), so each role gets one of them.
            -- Healers and ranged classes watch the raid or the target, so the list goes away. Tanks and melee
            -- keep the header, so the quest list is one click away in a quiet moment.
            { id = "tracker_combat", label = "Hide quest tracker in combat", show = "hide: %s  minimize: %s",
              archetypes = { HEALER = true, RANGED = true, CASTER = true },
              desc = "Same as the Blizzard quest tracker under Minimalism: the fight gets the space, the list comes back after.",
              set = { { path = { "hideTrackerInCombat" }, value = true }, { path = { "minimizeTrackerInCombat" }, value = false } } },
            { id = "tracker_minimize", label = "Shrink quest tracker in combat", show = "minimize: %s  hide: %s",
              archetypes = { TANK = true, MELEE = true },
              desc = "Only the header stays during a fight, so the tracker doesn't cover the pull. It opens again after.",
              set = { { path = { "minimizeTrackerInCombat" }, value = true }, { path = { "hideTrackerInCombat" }, value = false } } },
            { id = "done_objectives", label = "Hide finished objectives",
              desc = "The tracker only lists what is still left to do in each quest.",
              path = { "hideCompletedQuestObjectives" }, value = true },
            { id = "map_icons_tracked", label = "Map icons only for tracked quests",
              desc = "The map only shows icons for quests in your tracker. Off by default: tick it if the map feels busy.",
              path = { "hideUntrackedQuestsMapIcons" }, value = true, enabled = false },
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
            -- Quiet chat. DBM prints most of these on every pull. Keys checked in DeadlyBossMods CoreOptions.lua.
            { id = "chat_warnings", label = "No warnings in chat", show = "%s  %s",
              desc = "Warnings and special warnings stay on screen and are not repeated as chat lines.",
              set = { { path = { "ShowWarningsInChat" }, value = false }, { path = { "ShowSWarningsInChat" }, value = false } } },
            { id = "chat_noise", label = "Fewer DBM chat lines", show = "%s  %s  %s",
              desc = "No version list, no pizza timer message, no guild kill messages.",
              set = { { path = { "ShowAllVersions" }, value = false }, { path = { "ShowPizzaMessage" }, value = false },
                      { path = { "ShowGuildMessages" }, value = false } } },
            { id = "flash", label = "No screen flash on minor warnings", show = "%s  %s",
              desc = "Special warning levels 1 and 2 don't flash the screen. Higher levels still do.",
              set = { { path = { "SpecialWarningFlash1" }, value = false }, { path = { "SpecialWarningFlash2" }, value = false } } },
            -- DBM has no setting for "only my role". These are the filters that exist, set for the role you picked.
            { id = "interrupt_healer", label = "Hide interrupt warnings", show = "%s  %s", roles = { HEALER = true },
              desc = "Healers don't interrupt, so the boss and trash interrupt warnings are hidden.",
              set = { { path = { "FilterBInterruptHealer" }, value = true }, { path = { "FilterTInterruptHealer" }, value = true } } },
            { id = "interrupt_focus", label = "Interrupt warnings for target and focus only", show = "%s  %s",
              roles = { DAMAGER = true }, enabled = false,
              desc = "Interrupt warnings only show for your target or focus. Off by default: tick it if the warnings feel like noise.",
              set = { { path = { "FilterBTargetFocus" }, value = true }, { path = { "FilterTTargetFocus" }, value = true } } },
            { id = "ranged_frames", label = "Range frame as radar", archetypes = { RANGED = true, CASTER = true },
              desc = "Ranged players use the range frame often, so it shows as a radar instead of a list.",
              path = { "RangeFrameFrames" }, value = "radar", enabled = false },
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
        -- Leatrix keeps its settings in a private table and writes them over LeaPlusDB at logout,
        -- so changes made from outside are lost. MLZ shows what differs; you change it in /ltp.
        manual = "Leatrix overwrites outside changes at logout. Change this in /ltp.",
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
            { id = "hide_errors", label = "Hide red error text", desc = "No red 'Ability is not ready yet' lines in the middle of the screen. Off by default.",
              path = { "HideErrorMessages" }, value = "On", enabled = false },
            { id = "release_pvp", label = "Release in battlegrounds", desc = "Releases your spirit by itself when you die in a battleground. Off by default.",
              path = { "AutoReleasePvP" }, value = "On", enabled = false },
        },
    },
    {
        addon = "Leatrix_Maps", title = "Leatrix Maps",
        manual = "Leatrix overwrites outside changes at logout. Change this in /ltm.",
        root = function() return LeaMapsDB end,
        rows = {
            { id = "minimap_icon", label = "Hide Leatrix Maps minimap icon", desc = "Keeps the minimap clean. The map settings are already set up.",
              path = { "ShowMinimapIcon" }, value = "Off" },
        },
    },
    -- Details! copies its live settings over the saved profile at logout, so we write the live objects:
    -- `Details` for global options and window 1 for per-window options. Needs /reload to redraw.
    {
        addon = "Details", title = "Details! (meter)",
        root = function()
            local d = Details
            if not (d and d.GetInstance and (not d.IsLoaded or d.IsLoaded())) then return nil end
            return d:GetInstance(1)
        end,
        rows = {
            { id = "minimap", label = "Hide minimap button", desc = "Keeps the minimap clean. Open Details with /details.",
              root = function() return Details end, path = { "minimap", "hide" }, value = true },
            -- hide_on_context[3] = "not in a group"; `value` is the alpha in percent while the rule is active
            { id = "solo", label = "Hide when solo", show = "%s  alpha %s%%",
              desc = "Window 1 is hidden when you play alone and shows again in a party or raid. Same idea as the damage meter under Minimalism.",
              set = { { path = { "hide_on_context", 3, "enabled" }, value = true },
                      { path = { "hide_on_context", 3, "value" }, value = 0 } } },
            { id = "class_colors", label = "Class colors on bars", desc = "Bars are colored by class, so you can tell players apart at a glance.",
              path = { "row_info", "texture_class_colors" }, value = true },
            { id = "bar_height", label = "Bar height", desc = "16 pixels per bar instead of 14, easier to read at a glance.",
              path = { "row_info", "height" }, value = 16 },
            -- Details copies live settings over its profile at logout, so writing the live Details table persists
            { id = "segments", label = "Fights kept", desc = "Keeps the last 15 fights instead of 25, so the list stays short.",
              root = function() return Details end, path = { "segments_amount" }, value = 15 },
        },
    },
    -- Clique 5.x: per-character options in Clique.settings (db.char). Bindings are left alone on purpose:
    -- they depend on your spells, so you set them up in Clique itself.
    -- The Forever port of Clique is installed as CliqueForever, but still defines the global `Clique`.
    {
        addon = "Clique", alt = "CliqueForever", title = "Clique (click-casting)",
        root = function() return Clique and Clique.settings end,
        rows = {
            { id = "tooltip", label = "Show bindings in tooltips",
              desc = "Hovering a unit frame lists what each click does, so you don't have to remember your bindings.",
              path = { "showBindingTooltip" }, value = true },
        },
    },
    -- TomTom (AceDB). The arrow position is only read when you enter the world: needs /reload.
    {
        addon = "TomTom", title = "TomTom (waypoints)",
        root = function() return TomTom and TomTom.db and TomTom.db.profile end,
        rows = {
            { id = "arrow_lock", label = "Lock the arrow", desc = "The waypoint arrow can't be dragged away by accident.",
              path = { "arrow", "lock" }, value = true },
            { id = "arrow_tta", label = "No arrival time on the arrow", desc = "The arrow shows the distance only, not an estimated time.",
              path = { "arrow", "showtta" }, value = false },
            { id = "minimap_other", label = "No waypoints from other zones on the minimap",
              desc = "The minimap only shows waypoints in the zone you are in.",
              path = { "minimap", "otherzone" }, value = false },
            { id = "map_other", label = "No waypoints from other zones on the world map",
              desc = "The world map only shows waypoints for the zone you are looking at.",
              path = { "worldmap", "otherzone" }, value = false },
            { id = "block", label = "Hide the coordinate box",
              desc = "Removes the small box with your coordinates. The world map still shows them. Off by default: tick it if you never read it.",
              path = { "block", "enable" }, value = false, enabled = false },
        },
    },
    -- Postal (AceDB). Options are read each time they are used: no reload needed.
    {
        addon = "Postal", title = "Postal (mail)",
        live = true,
        root = function() return Postal and Postal.db and Postal.db.profile end,
        rows = {
            { id = "openall_chat", label = "Quiet open all", desc = "Opening all mail doesn't print a chat line for every letter.",
              path = { "OpenAll", "SpamChat" }, value = false },
            { id = "select_chat", label = "Quiet select", desc = "Opening selected mail doesn't print a chat line for every letter.",
              path = { "Select", "SpamChat" }, value = false },
            { id = "autocomplete", label = "One name suggestion list", desc = "Postal's address book is used when you type a name. Blizzard's own list stays closed, so you don't get two popups.",
              path = { "BlackBook", "DisableBlizzardAutoComplete" }, value = true },
        },
    },
}

-- Addons worth a look that the player doesn't have yet. Shown on the "Other addons" page and in
-- /mlz health, never as a popup. MLZ UI never installs anything.
--   addon = folder name (alt = a second folder name, as in the list above), title = shown name,
--   why = one line on what it does for the player
--   roles = (optional) only highlighted for these roles; without it, it is for everyone
ns.data.recommended = {
    { addon = "Questie", title = "Questie",
      why = "Shows quest givers and objectives on the map, so you spend less time searching." },
    { addon = "Clique", alt = "CliqueForever", title = "Clique", roles = { HEALER = true },
      why = "Heal by clicking party and raid frames, no target switching." },
    { addon = "DBM-Core", title = "Deadly Boss Mods",
      why = "Boss timers and warnings in dungeons and raids, so you don't need to read the boss guide first." },
    { addon = "Details", title = "Details!",
      why = "Shows damage, healing and threat per player after each fight." },
    { addon = "TomTom", title = "TomTom",
      why = "An arrow that points to your next waypoint. RestedXP Guides and Questie can use it." },
    { addon = "Postal", title = "Postal",
      why = "Opens all your mail with one click and remembers who you send to." },
    { addon = "BugSack", title = "BugSack",
      why = "Collects Lua errors quietly, so you can report them instead of seeing popups." },
}
