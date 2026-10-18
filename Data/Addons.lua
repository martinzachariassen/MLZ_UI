-- MLZ UI: Settings for other addons (Prat, Auctionator, AtlasLoot, WhatsTraining, Bagnon, Baganator,
-- RXPGuides, Questie, Deadly Boss Mods, Leatrix Plus, Leatrix Maps, Details!, Clique, TomTom)
-- Edit this file to change what the wizard step "Other addons" sets. MLZ UI never downloads or
-- updates these addons; it only configures the ones that are installed and loaded.
--
-- Each addon has:
--   addon   = folder name, used for the "is it loaded?" check
--   alt     = (optional) a second folder name, for ports that install under another name
--   requires = (optional) folder name of an addon this one needs; rows say why they can't be used without it
--   manual  = (optional) text: rows are shown but never written (the addon overwrites outside changes)
--   nosave  = (optional) key in SlashCmdList of an addon that overwrites its saved file at logout and has a
--             "nosave" command (Leatrix). It is run once before the first write, so the new values stay.
--             Without that command the rows fall back to `manual`.
--   writeNote = (optional) one muted line under the heading in the wizard, when the rows can be written
--   refresh = (optional) function that redraws the addon from its new settings. Return true if it did,
--             and no reload is asked for.
--   tested  = (optional) the newest version of the addon these rows were checked against. A newer installed
--             version is pointed out on the Other addons page (rows still run; missing keys are skipped).
--   title   = heading in the wizard
--   live    = true if the addon reads these settings while it runs, so no reload is asked for
--   root    = function returning the table that `path` starts from (nil = not available yet)
--   rows    = { id, label, desc, path = { "key", "subkey" }, value, enabled }
--             `enabled = false` means the row is listed but off until you tick it.
--             `roles = { HEALER = true }` and `archetypes = { CASTER = true, RANGED = true }` limit a row to
--             the role or archetype you picked (TANK, HEALER, DAMAGER / TANK, HEALER, MELEE, RANGED, CASTER).
--             `minVersion = "x.y"` / `maxVersion = "x.y"` limit a row to versions of the addon that have
--             the setting; other versions show "not in your version".
--             A row can have its own `root`. Instead of path/value a row can set several keys at
--             once: set = { { path = {...}, value = ... }, ... } and show = "%s %s" (format for the
--             wizard, one %s per key in order).
--
-- Keys come from each addon's own SavedVariables / defaults, so they only apply to the version
-- you have installed. Rows whose key doesn't exist are skipped with "not available".

local _, ns = ...

-- The MLZ look, as plain numbers because Data/ loads before UI/Widgets.lua. Mirrors W.T (bg, border).
local THEME = {
    bg = { 0.071, 0.078, 0.094 },
    border = { 0.192, 0.212, 0.251 },
    flat = "Interface\\Buttons\\WHITE8X8",
    font = "Interface\\AddOns\\MLZ_UI\\Media\\Roboto-Bold.ttf",
}
local function Alpha(color, a) return { color[1], color[2], color[3], a } end
local function Named(color, a) return { r = color[1], g = color[2], b = color[3], a = a } end

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
            { id = "ctrl_scroll", label = "CTRL + scroll speed", desc = "Holding CTRL while you scroll jumps 9 lines instead of 3.",
              root = PratModule("Scroll"), path = { "ctrlscrollspeed" }, value = 9 },
            { id = "levels", label = "No levels in player names", desc = "Chat names show [Name] instead of [Name:60].",
              root = PratModule("PlayerNames"), path = { "level" }, value = false },
            { id = "subgroup", label = "No raid group numbers", desc = "Raid chat names don't get the group number added.",
              root = PratModule("PlayerNames"), path = { "subgroup" }, value = false },
            { id = "frame_alpha", label = "Chat background", desc = "A slightly darker chat background (40% instead of 25%), so text is easy to read over the world.",
              root = PratModule("ChatFrames"), path = { "defaultframealpha" }, value = 0.4 },
            { id = "copy_button", label = "Quiet copy chat button", desc = "The copy chat button only shows when you hover the chat.",
              root = PratModule("CopyChat"), path = { "inactivealpha" }, value = 0 },
        },
    },
    {
        addon = "Auctionator", title = "Auctionator",
        live = true, -- reads its settings each time they are used: no reload needed
        -- A per-character profile, when there is one, replaces the account settings
        root = function() return AUCTIONATOR_CHARACTER_CONFIG or AUCTIONATOR_CONFIG end,
        rows = {
            { id = "autonext", label = "Auto-select next item", desc = "After posting, the next item in your bags is selected automatically.",
              path = { "selling_auto_select_next" }, value = true },
            { id = "lastduration", label = "Remember last duration", desc = "Uses the duration you picked last time when posting.",
              path = { "save_last_duration_as_default" }, value = true },
            { id = "chatlog", label = "Quiet posting", desc = "No chat line for every auction you post.",
              path = { "auction_chat_log" }, value = false },
            -- 0 none, 1 shopping, 2 selling, 3 cancelling, 4 Auctionator options
            { id = "default_tab", label = "Open on the Selling tab", desc = "The auction house opens on Auctionator's Selling tab.",
              path = { "default_tab" }, value = 2 },
            { id = "small_tabs", label = "Smaller tabs", desc = "Auctionator's tabs take less room at the bottom of the window.",
              path = { "small_tabs" }, value = true },
            { id = "mail_tooltips", label = "No mailbox tooltips", desc = "Mail item tooltips stay short.",
              path = { "mailbox_tooltips" }, value = false },
        },
    },
    -- AtlasLoot.db IS the active profile table (AtlasLoot.lua: self.db = self.dbRaw.profile). The minimap button
    -- reads `hide`; `shown` only drives the checkbox in its options, so both are written.
    {
        addon = "AtlasLootClassic", title = "AtlasLoot",
        root = function() return AtlasLoot and AtlasLoot.db end,
        rows = {
            { id = "minimap", label = "Hide minimap button", show = "shown: %s  hide: %s", desc = "You can still open it with /al.",
              set = { { path = { "minimap", "shown" }, value = false }, { path = { "minimap", "hide" }, value = true } },
              enabled = false },
            { id = "map_button", label = "No button on the world map", desc = "Removes the AtlasLoot button from the map title bar. Open it with /al.",
              path = { "WorldMap", "showbutton" }, value = false },
            { id = "locked", label = "Lock the window", desc = "The AtlasLoot window can't be dragged by accident.",
              path = { "GUI", "DefaultFrameLocked" }, value = true },
            { id = "scale", label = "Window scale", desc = "90% instead of 100%, so it covers less of the screen. Off by default: tick it if you want it.",
              path = { "GUI", "mainFrame", "scale" }, value = 0.9, enabled = false },
        },
    },
    {
        addon = "WhatsTraining", title = "What's Training?",
        live = true, -- reads its settings when the window opens: no reload needed
        root = function() return _G end,
        rows = {
            { id = "sidebyside", label = "Spells and weapon skills side by side", desc = "In the expanded spellbook, class spells and weapon skills are listed next to each other.",
              path = { "WT_SideBySide" }, value = true },
            { id = "switcher", label = "Hide the weapon skill switcher", desc = "Removes the small switch between spells and weapon skills.",
              path = { "WT_HideWeaponSkillSwitcher" }, value = true },
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
            { id = "inv_color", label = "Bag background", desc = "The MLZ background color, dark and almost solid, so item icons stand out.",
              path = { "inventory", "color" }, value = Alpha(THEME.bg, 0.9) },
            { id = "bank_color", label = "Bank background", desc = "Same darker background for the bank window.",
              path = { "bank", "color" }, value = Alpha(THEME.bg, 0.9) },
            { id = "inv_skin", label = "Flat bag frame", desc = "A 1px border instead of the thick tooltip frame.",
              path = { "inventory", "skin" }, value = "OnePixel" },
            { id = "bank_skin", label = "Flat bank frame", desc = "The same 1px border for the bank.",
              path = { "bank", "skin" }, value = "OnePixel" },
            { id = "inv_border", label = "Quiet bag border", desc = "A dark grey border instead of white.",
              path = { "inventory", "borderColor" }, value = Alpha(THEME.border, 1) },
            { id = "bank_border", label = "Quiet bank border", desc = "A dark grey border instead of yellow.",
              path = { "bank", "borderColor" }, value = Alpha(THEME.border, 1) },
            { id = "color_slots", label = "No tinted empty slots", desc = "Empty slots are not colored by bag type.",
              root = BagnonRoot, path = { "colorSlots" }, value = false },
            { id = "lock", label = "Lock the windows", desc = "Bag and bank windows can't be dragged by accident.",
              root = BagnonRoot, path = { "locked" }, value = true },
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
    -- RestedXP keeps its settings in RXPSettings (AceDB). RXPDB only holds imported guides. The profile key
    -- is the character name, and AceDB adds the realm on some realms, so the key is matched by its start.
    {
        addon = "RXPGuides", title = "RestedXP Guides",
        root = function()
            local db = _G.RXPSettings
            local keys = db and db.profileKeys
            if type(keys) ~= "table" or type(db.profiles) ~= "table" then return nil end
            local name = UnitName("player")
            local profile = keys[name] or keys[name .. " - " .. (GetRealmName() or "")]
            if not profile then
                for key, value in pairs(keys) do
                    if key:sub(1, #name + 1) == name .. " " then profile = value break end
                end
            end
            return profile and db.profiles[profile]
        end,
        rows = {
            { id = "theme", label = "Dark theme", desc = "The guide window uses RestedXP's DarkMode theme, flat and dark like MLZ UI.",
              path = { "activeTheme" }, value = "DarkMode" },
            { id = "scale", label = "Guide window scale", desc = "Scale of the guide window. Off by default: tick it if you want 1.1.",
              path = { "windowScale" }, value = 1.1, enabled = false },
            { id = "font_size", label = "Guide text size", desc = "10 instead of 9, easier to read at a glance.",
              path = { "guideFontSize" }, value = 10 },
            { id = "lock_frames", label = "Lock frames", desc = "Locks the guide window against dragging.",
              path = { "lockFrames" }, value = true },
            { id = "minimap", label = "Hide minimap button", desc = "Keeps the minimap clean. Open the guide from the world map button or /rxp.",
              path = { "enableMinimapButton" }, value = false },
            { id = "raid", label = "Hide in raids", desc = "The guide windows are hidden while you are in a raid group.",
              path = { "hideInRaid" }, value = true },
            { id = "item_bg", label = "Flat item buttons", desc = "The active items bar has no background behind the buttons.",
              path = { "activeItemHideBG" }, value = true },
            { id = "tips", label = "No tip popups", desc = "RestedXP doesn't show its tip frame.",
              path = { "enableTips" }, value = false },
            { id = "drowning", label = "No screen flash when drowning", desc = "The screen doesn't flash while the breath bar runs out.",
              path = { "enableDrowningScreenFlash" }, value = false },
        },
    },
    -- Questie (AceDB). Defaults: Modules/Options/QuestieOptionsDefaults.lua. Questie keeps no private copy,
    -- so changes survive logout. Most options only redraw through Questie's own setters: needs /reload.
    {
        addon = "Questie", title = "Questie (quests)",
        -- Before Questie starts, Questie.db is a small placeholder. The real one has GetNamespace.
        root = function()
            local db = Questie and Questie.db
            return db and db.GetNamespace and db.profile
        end,
        rows = {
            { id = "minimap", label = "Hide minimap button", desc = "Keeps the minimap clean. Open the settings with /questie.",
              path = { "minimap", "hide" }, value = true },
            -- The guide addon already lists the quest steps. The other tracker rows stay harmless when this is on.
            { id = "tracker_off", label = "Hide Questie quest tracker",
              desc = "Turns the Questie tracker off. Map icons and tooltips still work. Needs a reload.",
              path = { "trackerEnabled" }, value = false },
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
            -- The tracker copies the "current" keys back over the saved ones after it is resized, so both are written
            { id = "tracker_bg", label = "Tracker background", show = "%s  %s  %s  %s  %s",
              desc = "A dark MLZ background behind the quest tracker that only shows when you hover it.",
              set = { { path = { "trackerBackdropEnabled" }, value = true }, { path = { "currentBackdropEnabled" }, value = true },
                      { path = { "trackerBackdropFader" }, value = true }, { path = { "currentBackdropFader" }, value = true },
                      { path = { "trackerBackdropColor" }, value = Named(THEME.bg, 0.6) } } },
            { id = "tracker_buttons", label = "Quiet tracker buttons", show = "%s  %s",
              desc = "The minimize button and the quest item buttons only show when you hover the tracker.",
              set = { { path = { "trackerFadeMinMaxButtons" }, value = true }, { path = { "trackerFadeQuestItemButtons" }, value = true } } },
            { id = "map_icon_scale", label = "Smaller minimap icons", desc = "Quest icons on the minimap at 60% instead of 70%.",
              path = { "globalMiniMapScale" }, value = 0.6 },
            { id = "no_announce", label = "No quest progress in party chat", show = "%s  %s",
              desc = "Questie doesn't tell your group about every objective and item you pick up.",
              set = { { path = { "questAnnounceObjectives" }, value = false }, { path = { "questAnnounceItems" }, value = false } } },
        },
    },
    -- Deadly Boss Mods. Positions are in UIParent units (same as the Edit Mode layout, 1200 units tall).
    -- The middle of the screen stays clear: timers on the right above the damage meter, warnings top center.
    -- Each row sets several keys at once (`set`), shown with `show` in the wizard.
    {
        addon = "DBM-Core", title = "Deadly Boss Mods",
        root = function() return DBM and DBM.Options end,
        refresh = function()
            if not (DBM and DBM.UpdateWarningOptions and DBM.UpdateSpecialWarningOptions) then return false end
            DBM:UpdateWarningOptions()
            DBM:UpdateSpecialWarningOptions()
            return true
        end,
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
            -- Both filters are on by default, so there is nothing to set for focus-only interrupts.
            { id = "font", label = "MLZ font on warnings", show = "%s  %s",
              desc = "Warnings and special warnings use Roboto Bold, like the MLZ UI headings. If DBM can't use the font, it goes back to its own and says so in chat.",
              set = { { path = { "WarningFont" }, value = THEME.font }, { path = { "SpecialWarningFont" }, value = THEME.font } } },
            { id = "sw_style", label = "Thinner special warning outline", desc = "Special warnings use a thin outline instead of the thick one.",
              path = { "SpecialWarningFontStyle" }, value = "OUTLINE" },
            { id = "chat_pull", label = "No engage and defeat lines in chat", show = "%s  %s",
              desc = "DBM doesn't print a chat line at the start and end of every boss fight.",
              set = { { path = { "ShowEngageMessage" }, value = false }, { path = { "ShowDefeatMessage" }, value = false } } },
            { id = "victory", label = "No victory fanfare", desc = "No fanfare sound after a boss kill.",
              path = { "EventSoundVictory2" }, value = "None" },
        },
    },
    -- The minimap button has its own saved table. LibDBIcon reads it when DBM loads: needs /reload.
    {
        addon = "DBM-Core", title = "Deadly Boss Mods (minimap)",
        root = function() return type(DBM_MinimapIcon) == "table" and DBM_MinimapIcon or nil end,
        rows = {
            { id = "minimap", label = "Hide minimap button", desc = "Keeps the minimap clean. Open DBM with /dbm.",
              path = { "hide" }, value = true },
        },
    },
    {
        addon = "DBM-StatusBarTimers", title = "Deadly Boss Mods (timer bars)",
        root = function() return DBT and DBT.Options end,
        refresh = function()
            if not (DBT and DBT.ApplyStyle) then return false end
            DBT:ApplyStyle()
            return true
        end,
        rows = {
            { id = "position", label = "Timer position", show = "%s %s,%s  up: %s",
              desc = "Bars hang from the right edge above the damage meter and stack upward.",
              set = { { path = { "TimerPoint" }, value = "BOTTOMRIGHT" }, { path = { "TimerX" }, value = -100 },
                      { path = { "TimerY" }, value = 360 }, { path = { "ExpandUpwards" }, value = true } } },
            { id = "size", label = "Timer size", show = "%sx%s",
              desc = "Slimmer bars: 170x16 instead of 183x20.",
              set = { { path = { "Width" }, value = 170 }, { path = { "Height" }, value = 16 } } },
            { id = "huge", label = "No separate large bars", desc = "Bars stay in one stack instead of jumping to the center of the screen at 10 seconds.",
              path = { "HugeBarsEnabled" }, value = false },
            { id = "flat", label = "Flat bars", show = "%s  spark: %s  alpha %s",
              desc = "Plain flat bars without the gradient texture and the spark, fully solid.",
              set = { { path = { "Texture" }, value = THEME.flat }, { path = { "Spark" }, value = false },
                      { path = { "Alpha" }, value = 1 } } },
            { id = "bg", label = "Dark bar background", show = "%s %s %s  alpha %s",
              desc = "The empty part of each bar uses the MLZ background color.",
              set = { { path = { "BackgroundColorR" }, value = THEME.bg[1] }, { path = { "BackgroundColorG" }, value = THEME.bg[2] },
                      { path = { "BackgroundColorB" }, value = THEME.bg[3] }, { path = { "BackgroundAlpha" }, value = 0.8 } } },
            { id = "border", label = "1px bar border", show = "%s  %spx",
              desc = "A thin black border around each bar.",
              set = { { path = { "BorderEnabled" }, value = true }, { path = { "BorderSize" }, value = 1 } } },
            { id = "font", label = "MLZ font on timers", show = "%s  shadow: %s",
              desc = "Timer text uses Roboto Bold with a soft shadow. If DBM can't use the font, it goes back to its own and says so in chat.",
              set = { { path = { "Font" }, value = THEME.font }, { path = { "FontShadow" }, value = true } } },
        },
    },
    -- Leatrix Plus: only what MLZ UI doesn't already do. Not touched on purpose:
    --   camera zoom, hotkey/macro text (MLZ sets those), chat tweaks (Prat), minimap clutter (already hidden),
    --   junk selling and repair (Modules/Vendor.lua does both).
    -- Values are "On" / "Off" strings, as Leatrix stores them. Needs /reload.
    {
        addon = "Leatrix_Plus", title = "Leatrix Plus",
        -- Leatrix keeps its settings in a private table and writes them over LeaPlusDB at logout. Its
        -- "nosave" command stops that for this session, so what we write stays after the /reload.
        nosave = "Leatrix_Plus",
        manual = "This Leatrix version has no nosave command, so it would overwrite outside changes at logout. Change this in /ltp.",
        writeNote = "Until your next /reload, changes you make in /ltp yourself are not saved.",
        root = function() return LeaPlusDB end,
        rows = {
            { id = "fast_loot", label = "Faster auto loot", desc = "Loots faster when MLZ's auto loot is on.",
              path = { "FasterLooting" }, value = "On" },
            { id = "minimap_icon", label = "Hide Leatrix minimap icon", desc = "Open it with /ltp instead.",
              path = { "ShowMinimapIcon" }, value = "Off" },
            { id = "flight_times", label = "Show flight times", desc = "The flight master map shows how long each flight takes.",
              path = { "ShowFlightTimes" }, value = "On" },
            { id = "rested_emotes", label = "Silence rested emotes", desc = "Your character doesn't chat out loud when it is rested in a city or inn.",
              path = { "NoRestedEmotes" }, value = "On" },
            { id = "auto_quests", label = "Automate quests", desc = "Accepts and turns in quests automatically. Off by default: tick it if you want it, and check it doesn't clash with RestedXP Guides.",
              path = { "AutomateQuests" }, value = "On", enabled = false },
            { id = "confirm_loot", label = "Skip loot confirmations", desc = "Confirms bind-on-pickup popups for you. Off by default, because it also confirms items you did not mean to take.",
              path = { "NoConfirmLoot" }, value = "On", enabled = false },
            { id = "hide_errors", label = "Hide red error text", desc = "No red 'Ability is not ready yet' lines in the middle of the screen. Off by default.",
              path = { "HideErrorMessages" }, value = "On", enabled = false },
            { id = "boss_banner", label = "Hide boss banners", desc = "No big banner when a boss is killed or loot is won. Off by default.",
              path = { "HideBossBanner" }, value = "On", enabled = false },
            { id = "release_pvp", label = "Release in battlegrounds", desc = "Releases your spirit by itself when you die in a battleground. Off by default.",
              path = { "AutoReleasePvP" }, value = "On", enabled = false },
        },
    },
    {
        addon = "Leatrix_Maps", title = "Leatrix Maps",
        nosave = "Leatrix_Maps",
        manual = "This Leatrix version has no nosave command, so it would overwrite outside changes at logout. Change this in /ltm.",
        writeNote = "Until your next /reload, changes you make in /ltm yourself are not saved.",
        root = function() return LeaMapsDB end,
        rows = {
            { id = "minimap_icon", label = "Hide Leatrix Maps minimap icon", desc = "Keeps the minimap clean. Open it with /ltm.",
              path = { "ShowMinimapIcon" }, value = "Off" },
            { id = "unlock", label = "Move the map", desc = "The world map can be dragged, so it doesn't cover what you are looking at.",
              path = { "UnlockMap" }, value = "On" },
            { id = "tint", label = "No tint on revealed areas", desc = "Unexplored areas shown on the map keep their normal colors.",
              path = { "RevTint" }, value = "Off" },
            { id = "scale", label = "Map scale", show = "%s  %s", desc = "The world map at 90% instead of 100%.",
              set = { { path = { "ScaleWorldMap" }, value = "On" }, { path = { "MapScale" }, value = 0.9 } } },
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
            -- The Minimalistic skin already uses class colors and 21 pixel bars
            { id = "bar_height", label = "Bar height", desc = "18 pixels per bar instead of 21, so more players fit in the window.",
              path = { "row_info", "height" }, value = 18 },
            { id = "bar_flat", label = "Flat bars", show = "%s  class bg: %s",
              desc = "Plain flat bars, with a dark MLZ color behind them instead of a class colored one.",
              set = { { path = { "row_info", "texture_custom" }, value = "Buttons\\WHITE8X8" },
                      { path = { "row_info", "texture_background_class_color" }, value = false } } },
            { id = "bar_bg", label = "Dark bar background", desc = "The empty part of each bar uses the MLZ background color.",
              path = { "row_info", "fixed_texture_background_color" }, value = Alpha(THEME.bg, 0.6) },
            { id = "window_bg", label = "Dark window background", show = "%s %s %s  alpha %s",
              desc = "The window behind the bars uses the MLZ background color.",
              set = { { path = { "bg_r" }, value = THEME.bg[1] }, { path = { "bg_g" }, value = THEME.bg[2] },
                      { path = { "bg_b" }, value = THEME.bg[3] }, { path = { "bg_alpha" }, value = 0.85 } } },
            { id = "font", label = "MLZ font on bars", show = "%s  size %s",
              desc = "Bar text uses Roboto Bold at size 11.",
              set = { { path = { "row_info", "font_face_file" }, value = THEME.font }, { path = { "row_info", "font_size" }, value = 11 } } },
            { id = "statusbar", label = "No status bar", desc = "Removes the empty strip at the bottom of the window.",
              path = { "show_statusbar" }, value = false },
            { id = "menu_fade", label = "Fade the toolbar", show = "%s  alpha %s",
              desc = "The icons at the top of the window dim to 30% until you hover them.",
              set = { { path = { "menu_alpha", "enabled" }, value = true }, { path = { "menu_alpha", "onleave" }, value = 0.3 } } },
            -- Details copies live settings over its profile at logout, so writing the live Details table persists
            { id = "segments", label = "Fights kept", desc = "Keeps the last 10 fights instead of 15, so the list stays short.",
              root = function() return Details end, path = { "segments_amount_to_save" }, value = 10 },
            { id = "trash", label = "Remove trash fights", desc = "Old trash fights are dropped from the list when a boss fight is added.",
              root = function() return Details end, path = { "trash_auto_remove" }, value = true },
            { id = "animations", label = "No bar animations", desc = "Bars jump to their new length instead of sliding.",
              root = function() return Details end, path = { "use_row_animations" }, value = false },
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
            { id = "target_menu", label = "No target menu warning", desc = "Clique doesn't warn you about the right-click target menu.",
              path = { "dismissTargetMenuWarning" }, value = true },
        },
    },
    -- TomTom (AceDB). TomTom:ReloadOptions redraws the arrow and the coordinate box at once.
    {
        addon = "TomTom", title = "TomTom (waypoints)",
        root = function() return TomTom and TomTom.db and TomTom.db.profile end,
        refresh = function()
            if not (TomTom and TomTom.ReloadOptions) then return false end
            TomTom:ReloadOptions()
            return true
        end,
        rows = {
            { id = "arrow_lock", label = "Lock the arrow", desc = "The waypoint arrow can't be dragged away by accident.",
              path = { "arrow", "lock" }, value = true },
            { id = "arrow_tta", label = "No arrival time on the arrow", desc = "The arrow shows the distance only, not an estimated time.",
              path = { "arrow", "showtta" }, value = false },
            { id = "arrow_scale", label = "Smaller arrow", show = "scale %s  alpha %s",
              desc = "The waypoint arrow at 90% size and 85% opacity.",
              set = { { path = { "arrow", "scale" }, value = 0.9 }, { path = { "arrow", "alpha" }, value = 0.85 } } },
            { id = "arrow_title", label = "Quieter arrow title", show = "scale %s  alpha %s",
              desc = "The waypoint name under the arrow at 90% size and 80% opacity.",
              set = { { path = { "arrow", "title_scale" }, value = 0.9 }, { path = { "arrow", "title_alpha" }, value = 0.8 } } },
            { id = "minimap_other", label = "No waypoints from other zones on the minimap",
              desc = "The minimap only shows waypoints in the zone you are in.",
              path = { "minimap", "otherzone" }, value = false },
            { id = "map_other", label = "No waypoints from other zones on the world map",
              desc = "The world map only shows waypoints for the zone you are looking at.",
              path = { "worldmap", "otherzone" }, value = false },
            { id = "block", label = "Hide the coordinate box",
              desc = "Removes the small box with your coordinates. The minimap and the world map still show them.",
              path = { "block", "enable" }, value = false },
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
    { addon = "BugSack", title = "BugSack",
      why = "Collects Lua errors quietly, so you can report them instead of seeing popups." },
}
