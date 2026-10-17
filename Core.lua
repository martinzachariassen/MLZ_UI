-- MLZ UI: Core
-- Shared namespace, SavedVariables, event bus, combat queue and slash commands.

local ADDON, ns = ...
MLZUI = ns -- global for /dump MLZUI during development

ns.name = "MLZ UI"
ns.version = "0.7.0"
ns.modules = {}       -- registered modules, in load order (see MLZ_UI.toc), also indexed by key
ns.data = {}          -- data tables (Data/*.lua)

local DB_VERSION = 6

------------------------------------------------------------------------
-- Output
------------------------------------------------------------------------
-- Text color code from the theme (W.C in UI/Widgets.lua). Widgets loads after Core and the modules,
-- so this is looked up when the text is made. Before that it is just uncolored.
function ns.Color(name)
    local c = ns.W and ns.W.C[name]
    return c or ""
end
local function Col(name) return ns.Color(name) end
local function R() return ns.W and "|r" or "" end

-- A slash command or key name inside a sentence: white, so it stands out from the grey-white text
function ns.Cmd(text) return Col("white") .. text .. R() end
-- A piece of text in a theme color: ns.Paint("red", "Import failed:")
function ns.Paint(name, text) return Col(name) .. text .. R() end

function ns.Print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    DEFAULT_CHAT_FRAME:AddMessage(Col("blue") .. "MLZ UI" .. R() .. ": " .. table.concat(parts, " "))
end

function ns.Debug(...)
    if ns.db and ns.db.debug then ns.Print(Col("grey") .. "[debug]" .. R(), ...) end
end

-- Errors print once per session per message, so a broken handler on a busy event can't flood chat.
-- Repeats still show with /mlz debug.
local seenErrors = {}
function ns.Error(where, err)
    local msg = tostring(where) .. ": " .. tostring(err)
    if seenErrors[msg] then return ns.Debug(Col("red") .. "Error" .. R(), msg) end
    seenErrors[msg] = true
    ns.Print(Col("red") .. "Error in " .. tostring(where) .. ":" .. R(), tostring(err))
end

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
function ns.CopyTable(src)
    if type(src) ~= "table" then return src end
    local t = {}
    for k, v in pairs(src) do t[k] = ns.CopyTable(v) end
    return t
end

-- Remembers on/off choices from the wizard per module and item
function ns.Enabled(modKey, id, default)
    local v = ns.db and ns.db.toggles[modKey .. ":" .. tostring(id)]
    if v == nil then return default end
    return v
end

function ns.SetEnabled(modKey, id, value)
    ns.db.toggles[modKey .. ":" .. tostring(id)] = value and true or false
end

-- Calls f safely and returns ok, result...
function ns.Try(f, ...)
    if type(f) ~= "function" then return false, "not a function" end
    return pcall(f, ...)
end

------------------------------------------------------------------------
-- State changes: modules call ns.FireState() after changing something, so the settings window,
-- its footer and the minimap tooltip can redraw. ns.MarkReload(reason) also flags that a /reload is needed.
------------------------------------------------------------------------
local stateListeners = {}
local firing = false

function ns.OnState(fn)
    stateListeners[#stateListeners + 1] = fn
end

function ns.FireState()
    if firing then return end
    firing = true
    for _, fn in ipairs(stateListeners) do
        local ok, err = pcall(fn)
        if not ok then ns.Debug("state listener:", err) end
    end
    firing = false
end

ns.reloadReasons = {}
function ns.MarkReload(reason)
    ns.needsReload = true
    if reason then
        for _, r in ipairs(ns.reloadReasons) do
            if r == reason then reason = nil break end
        end
        if reason then ns.reloadReasons[#ns.reloadReasons + 1] = reason end
    end
    ns.FireState()
end

-- Edit Mode layouts saved through C_EditMode move the frames at once, but the Edit Mode window keeps
-- its own copy until a reload. Saving in Edit Mode before that would put the old layout back, so we
-- don't ask for a reload right away: Modules/Layout.lua warns only if Edit Mode is opened first.
function ns.MarkEditModeStale()
    ns.editModeStale = true
    ns.FireState()
end

------------------------------------------------------------------------
-- Modules
-- A module is a table with:
--   key, title          -- id and display name
--   :Preview()          -- returns a list of { id, label, old, new, enabled, note, conflict }
--   :Apply(items)       -- applies selected changes (items = those with enabled = true)
------------------------------------------------------------------------
function ns.RegisterModule(mod)
    ns.modules[#ns.modules + 1] = mod
    ns.modules[mod.key] = mod
    return mod
end

------------------------------------------------------------------------
-- Event-bus
------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local handlers = {}

-- Registers first and only then creates the handler list, so an event the client doesn't
-- know (the RegisterEvent error is caught by callers with pcall) doesn't leave a dead entry behind.
function ns.On(event, fn)
    if not handlers[event] then
        eventFrame:RegisterEvent(event)
        handlers[event] = {}
    end
    table.insert(handlers[event], fn)
end

-- Like ns.On, but silently skips events this client doesn't have
function ns.TryOn(event, fn)
    return pcall(ns.On, event, fn)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], event, ...)
        if not ok then ns.Error(event, err) end
    end
end)

------------------------------------------------------------------------
-- Combat queue: things blocked in combat run when combat ends
------------------------------------------------------------------------
-- A job with a label replaces an earlier queued job with the same label (only the newest runs),
-- and the "in combat" line is printed once per label per fight. quiet = never print.
local queue = {}
local told = {}

function ns.RunOutOfCombat(fn, label, quiet)
    if InCombatLockdown() then
        if label then
            for i = #queue, 1, -1 do
                if queue[i].label == label then table.remove(queue, i) end
            end
        end
        table.insert(queue, { fn = fn, label = label })
        if not quiet and not told[label or ""] then
            told[label or ""] = true
            ns.Print("In combat. Running", label or "the change", "when combat ends.")
        end
        return false
    end
    fn()
    return true
end

function ns.QueuedCount() return #queue end

ns.On("PLAYER_REGEN_ENABLED", function()
    wipe(told)
    while #queue > 0 do
        local job = table.remove(queue, 1)
        local ok, err = pcall(job.fn)
        if not ok then ns.Error(job.label or "queued job", err) end
    end
end)

------------------------------------------------------------------------
-- Addon helpers (C_AddOns on newer clients, globals on older ones)
------------------------------------------------------------------------
function ns.IsAddOnLoaded(name)
    local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if not f then return false end
    local ok, loaded = pcall(f, name)
    return ok and loaded and true or false
end

-- true when the addon is installed (loaded or not), false when it's missing
function ns.IsAddOnInstalled(name)
    local f = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
    if not f then return false end
    local ok, title, _, _, _, reason = pcall(f, name)
    if not ok or not title then return false end
    return reason ~= "MISSING"
end

------------------------------------------------------------------------
-- Client: WoW Forever is the main supported game version (## Interface: 16001). Other clients still load,
-- they are just not tested. Used by the About page only, never blocks anything.
------------------------------------------------------------------------
ns.MAIN_CLIENT = "WoW Forever"

-- Returns { main = bool, toc = number|nil, version = string|nil, name = "WoW Forever" }
function ns.ClientInfo()
    local ok, version, build, _, toc = pcall(GetBuildInfo or function() end)
    toc = ok and tonumber(toc) or nil
    return {
        main = toc ~= nil and toc >= 16000 and toc < 16100,
        toc = toc,
        version = ok and version or nil,
        build = ok and build or nil,
        name = ns.MAIN_CLIENT,
    }
end

------------------------------------------------------------------------
-- Role: one answer for every module (healer layouts, nameplates, overview, role profiles).
-- ns.Role()     -> "TANK" | "HEALER" | "DAMAGER"  (what you are: forced choice, spec, talents, group role).
--                  A leveling character with no clear role yet counts as DAMAGER.
-- ns.LiveRole() -> same, but a tank spec that isn't tanking right now (cat form, battle stance on a
--                  protection warrior) counts as DAMAGER, and a Defensive Stance or Righteous Fury counts as TANK.
--                  Used by nameplates, reminders and role-based defaults.
-- ns.Archetype() / ns.LiveArchetype() -> "TANK" | "HEALER" | "MELEE" | "RANGED" | "CASTER" (Data/Classes.lua)
--                  The DPS role split by how you play: swing timers, layouts and keys follow it.
------------------------------------------------------------------------
-- Early points often go into a healer tree while leveling (Divine Strength, Furor, Wand Specialization),
-- so talents only decide the role once one tree has real investment.
local TALENT_MIN_POINTS = 11
ns.ROLE_TEXT = { TANK = "Tank", HEALER = "Healer", DAMAGER = "DPS" }
-- Where a role came from (second value of ns.Role), as short text for the windows
ns.SOURCE_TEXT = {
    forced = "set by you", class = "class", spec = "spec", talents = "talents", group = "group role",
    default = "until your talents decide", unknown = "unknown",
}

local function PlayerClass()
    local _, class = UnitClass("player")
    return class
end
ns.PlayerClass = PlayerClass

local function SpecRole()
    local info = C_SpecializationInfo
    if not (info and info.GetSpecialization and info.GetSpecializationInfo) then return end
    local ok, index = pcall(info.GetSpecialization)
    if not ok or not index or index == 0 then return end
    local ok2, _, _, _, _, role = pcall(info.GetSpecializationInfo, index)
    if ok2 and (role == "TANK" or role == "HEALER" or role == "DAMAGER") then return role end
end

-- Points per talent tab. GetTalentTabInfo returns (name, icon, points, ...) on older clients and
-- (id, name, description, icon, points, ...) on newer ones.
local function TabPoints(tab)
    if not GetTalentTabInfo then return 0 end
    local ok, a, _, c, _, e = pcall(GetTalentTabInfo, tab)
    if not ok then return 0 end
    local points = (type(a) == "string") and c or e
    return tonumber(points) or 0
end

local function ClassData(class)
    return ns.data.classes and ns.data.classes[class]
end

-- The talent tree with the most points, or nil while no tree has real investment yet
local function BestTab()
    if not (GetNumTalentTabs and GetTalentTabInfo) then return end
    local okN, n = pcall(GetNumTalentTabs)
    if not okN or not n or n == 0 then return end
    local best, bestPoints = nil, 0
    for tab = 1, n do
        local p = TabPoints(tab)
        if p > bestPoints then best, bestPoints = tab, p end
    end
    if not best or bestPoints < TALENT_MIN_POINTS then return end -- low level: not decided yet
    return best
end

local function ArchetypeRole(a)
    if a == "TANK" or a == "HEALER" then return a end
    return "DAMAGER"
end

local function TalentRole(class)
    local best = BestTab()
    if not best then return end
    local c = ClassData(class)
    return ArchetypeRole(c and c.tabs and c.tabs[best])
end

local function GroupRole()
    if not (IsInGroup() and UnitGroupRolesAssigned) then return end
    local r = UnitGroupRolesAssigned("player")
    if r == "TANK" or r == "HEALER" or r == "DAMAGER" then return r end
end

-- Per-character part of MLZUIDB (the rest is shared by all characters on the account)
function ns.CharKey()
    return (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?")
end

function ns.CharDB()
    if not ns.db then return {} end
    ns.db.chars = ns.db.chars or {}
    local key = ns.CharKey()
    ns.db.chars[key] = ns.db.chars[key] or {}
    return ns.db.chars[key]
end

-- The role you picked yourself, per character. Older versions kept one for the whole account:
-- the first character that logs in takes it over.
function ns.GetRoleForce()
    if not ns.db then return nil end
    local c = ns.CharDB()
    if ns.db.roleForce ~= nil then
        if c.roleForce == nil then c.roleForce = ns.db.roleForce end
        ns.db.roleForce = nil
    end
    return c.roleForce
end

-- Returns role, source ("forced" | "class" | "spec" | "talents" | "group" | "default"). Never nil.
-- ignoreForce = what the game detects, as if you had not picked a role (the setup wizard shows it)
function ns.Role(ignoreForce)
    local force = not ignoreForce and ns.GetRoleForce()
    if force then return force, "forced" end
    local class = PlayerClass()
    local c = ClassData(class)
    if c and c.pureDps then return "DAMAGER", "class" end
    local r = SpecRole()
    if r then return r, "spec" end
    r = TalentRole(class)
    if r then return r, "talents" end
    r = GroupRole()
    if r then return r, "group" end
    return "DAMAGER", "default" -- no spec, too few talents, no group role: leveling, so DPS
end

local function FormID()
    return GetShapeshiftFormID and GetShapeshiftFormID() or nil
end

local function InBearForm()
    local id = FormID()
    return id == 5 or id == 8
end

-- Defensive Stance is form ID 18 in Classic, and always the second stance on the bar.
-- Both checks, since not every client returns form IDs for warriors (see /mlz probe, "form").
local function InDefensiveStance()
    if FormID() == 18 then return true end
    return GetShapeshiftForm and GetShapeshiftForm() == 2 or false
end

local RIGHTEOUS_FURY = 25780

local function HasPlayerAura(spellId)
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        return C_UnitAuras.GetPlayerAuraBySpellID(spellId) ~= nil
    end
    local name = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellId))
        or (GetSpellInfo and (GetSpellInfo(spellId)))
    if not (name and UnitBuff) then return false end
    for i = 1, 40 do
        local buff = UnitBuff("player", i)
        if not buff then return false end
        if buff == name then return true end
    end
    return false
end

-- Returns role, reason (short text for the settings window)
function ns.LiveRole()
    local role, source = ns.Role()
    if source == "forced" then return role, "set by you" end
    local class = PlayerClass()
    if UnitHasEffectivelyTankAura and UnitHasEffectivelyTankAura("player") then
        return "TANK", "tank aura active"
    end
    if GroupRole() == "TANK" then return "TANK", "assigned tank in the group" end
    -- Stances and forms only turn a tank spec (or a character with no spec yet) into a tank. A Fury warrior
    -- who touches Defensive Stance stays DPS, so nameplates don't flicker.
    local mayTank = role == "TANK" or source == "default"
    if class == "DRUID" then
        if mayTank and InBearForm() then return "TANK", "Bear Form" end
        if role == "TANK" then return "DAMAGER", "Feral, not in Bear Form" end
    elseif class == "WARRIOR" then
        if mayTank and InDefensiveStance() then return "TANK", "Defensive Stance" end
        if role == "TANK" then return "DAMAGER", "Protection, not in Defensive Stance" end
    elseif class == "PALADIN" and role ~= "HEALER" and HasPlayerAura(RIGHTEOUS_FURY) then
        return "TANK", "Righteous Fury active"
    end
    if source == "default" then return "DAMAGER", "no role yet, counts as DPS" end
    if role then return role, "from " .. source end
    return nil, "no role found" -- safety net, ns.Role() always returns a role
end

-- Archetype for a role. Talents refine DPS (a Feral druid out of Bear Form is melee, a Shadow priest a caster).
local function ArchetypeFor(role, class)
    if role == "TANK" or role == "HEALER" then return role end
    local c = ClassData(class)
    if not c then return "MELEE" end
    local tab = BestTab()
    local a = tab and c.tabs and c.tabs[tab]
    if a and a ~= "TANK" and a ~= "HEALER" then return a end
    return (tab and c.dpsTabs and c.dpsTabs[tab]) or c.dps
end

-- Returns archetype, source (same sources as ns.Role)
function ns.Archetype(ignoreForce)
    local role, source = ns.Role(ignoreForce)
    return ArchetypeFor(role, PlayerClass()), source
end

-- Returns archetype, reason (same as ns.LiveRole)
function ns.LiveArchetype()
    local role, reason = ns.LiveRole()
    return ArchetypeFor(role, PlayerClass()), reason
end

function ns.ArchetypeText(a)
    return ns.data.archetypeText and ns.data.archetypeText[a] or ns.ROLE_TEXT[ArchetypeRole(a)]
end

-- v: "TANK" | "HEALER" | "DAMAGER" | nil (auto)
function ns.SetRoleForce(v)
    ns.GetRoleForce() -- takes over an old account-wide choice first
    ns.CharDB().roleForce = (v == "TANK" or v == "HEALER" or v == "DAMAGER") and v or nil
    ns.FireRole()
end

-- Role change notifications (spec/talent/form/group changes come in bursts; this coalesces them)
local roleListeners, lastRole, lastLive, lastArch = {}, nil, nil, nil
function ns.OnRoleChanged(fn) roleListeners[#roleListeners + 1] = fn end

-- Listeners get (role, live, changed). `changed` is also true when only the archetype changed
-- (a Shaman who goes from Elemental to Enhancement is still DPS but a different kind).
function ns.FireRole()
    local role, live = ns.Role(), ns.LiveRole()
    local arch = ns.Archetype()
    local changed = role ~= lastRole or arch ~= lastArch
    local liveChanged = live ~= lastLive
    lastRole, lastLive, lastArch = role, live, arch
    if changed or liveChanged then
        for _, fn in ipairs(roleListeners) do
            local ok, err = pcall(fn, role, live, changed)
            if not ok then ns.Debug("role listener:", err) end
        end
    end
    ns.FireState()
end

local roleScheduled = false
local function ScheduleRole()
    if roleScheduled then return end
    roleScheduled = true
    C_Timer.After(0.5, function()
        roleScheduled = false
        if ns.db then ns.FireRole() end
    end)
end
ns.ScheduleRole = ScheduleRole

for _, event in ipairs({
    "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "UPDATE_SHAPESHIFT_FORM",
    "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED",
    "PLAYER_SPECIALIZATION_CHANGED", "TRAIT_CONFIG_UPDATED",
}) do
    ns.TryOn(event, ScheduleRole)
end
-- Tank aura or Righteous Fury can change the live role. Aura events come in floods during combat,
-- so only react when the state flips.
local lastTankAura
ns.TryOn("UNIT_AURA", function(_, unit)
    if unit ~= "player" then return end
    local state
    if UnitHasEffectivelyTankAura then
        state = UnitHasEffectivelyTankAura("player") and true or false
    elseif PlayerClass() == "PALADIN" then
        state = HasPlayerAura(RIGHTEOUS_FURY)
    end
    if state == nil or state == lastTankAura then return end
    lastTankAura = state
    ScheduleRole()
end)

------------------------------------------------------------------------
-- SavedVariables
------------------------------------------------------------------------
local defaults = {
    dbVersion = DB_VERSION,
    installed = false,     -- has the wizard been completed?
    debug = false,
    scale = { mode = "auto" },   -- see Modules/Scale.lua
    movement = "ESDF",
    spellQueueWindow = nil,      -- nil = don't touch
    toggles = {},                -- ["module:id"] = true/false, remembers wizard choices
    backup = nil,                -- see Modules/Backup.lua
}

local function ApplyDefaults(db, def)
    for k, v in pairs(def) do
        if db[k] == nil then db[k] = ns.CopyTable(v) end
    end
end

-- migrations[n] upgrades a database from version n-1 to n. Add new steps at the end and bump DB_VERSION.
local migrations = {
    -- v3: "count me as healer" (healForce on/off) became "my role" (roleForce)
    [3] = function(db)
        if db.healForce == "on" then db.roleForce = "HEALER"
        elseif db.healForce == "off" then db.roleForce = "DAMAGER" end
        db.healForce = nil
        -- threat colors used to be on unless turned off; they are opt-in now, so keep it on
        -- only for people who had the clean style or threat already written to their design
        if db.nameplates and db.nameplates.threat == nil and db.nameplates.snapshot then
            db.nameplates.threat = true
        end
        if db.installed then db.wizardSeen = true end
    end,
    -- v4: nameplates got an engine (MLZ, Platynator or off). Keep Platynator for everyone who
    -- already had MLZ UI driving it, so nothing changes without asking. New keys: nameplates.show,
    -- nameplates.size, nameplates.friendsBase (all optional).
    [4] = function(db)
        local np = db.nameplates
        if type(np) == "table" and np.engine == nil and (np.lastKey or np.snapshot or np.style) then
            np.engine = "platynator"
        end
    end,
    -- v5: new optional keys, nothing to convert. reminders = { buffs, reagents, durability }
    -- (Modules/Reminders.lua fills in defaults), tweaks.tooltipClass, tooltipTarget, squareMinimap,
    -- flatChatInput, chatFont, minimapRotateWas (the rotation setting from before the square minimap)
    -- tourSeen (the "where did things go?" tour has run once), tweaks.chatClassNames and chatClassWas
    -- (the per chat type "color names" choice from before MLZ UI changed it).
    [5] = function(db)
        if db.reminders ~= nil and type(db.reminders) ~= "table" then db.reminders = nil end
    end,
    -- v6: new optional key, nothing to convert. cooking = { tooltip } (Modules/Cooking.lua fills in defaults)
    [6] = function(db)
        if db.cooking ~= nil and type(db.cooking) ~= "table" then db.cooking = nil end
    end,
}

local function Migrate(db)
    for v = (db.dbVersion or 1) + 1, DB_VERSION do
        local step = migrations[v]
        if step then
            local ok, err = pcall(step, db)
            if not ok then ns.Print(ns.Paint("red", "Migration to v" .. v .. " failed:"), err) end
        end
    end
    db.dbVersion = DB_VERSION
end

ns.On("ADDON_LOADED", function(_, name)
    if name ~= ADDON then return end
    local fresh = MLZUIDB == nil or next(MLZUIDB) == nil
    MLZUIDB = MLZUIDB or {}
    -- Migrate before defaults, otherwise ApplyDefaults stamps the current dbVersion on an old
    -- database and its migrations never run. A brand new database needs no migration.
    if MLZUIDB.dbVersion == nil then MLZUIDB.dbVersion = fresh and DB_VERSION or 1 end
    Migrate(MLZUIDB)
    ApplyDefaults(MLZUIDB, defaults)
    ns.db = MLZUIDB
end)

ns.On("PLAYER_LOGIN", function()
    C_Timer.After(5, function()
        if ns.RunProbe then pcall(ns.RunProbe, true) end
    end)
    if ns.db.installed then
        if ns.db.debug then ns.Print("loaded (v" .. ns.version .. ").") end
        return
    end
    if not ns.db.wizardSeen then
        -- First time: open the wizard once.
        C_Timer.After(2, function()
            if ns.Installer and not InCombatLockdown() then
                ns.db.wizardSeen = true
                ns.Installer:Open()
            end
        end)
        return
    end
    -- After that: one reminder per character, then the minimap button and overview carry it.
    local c = ns.CharDB()
    if not c.setupReminded then
        c.setupReminded = true
        ns.Print("Not set up yet. Click the minimap button or type " .. ns.Cmd("/mlz install") .. " to start.")
    end
end)

------------------------------------------------------------------------
-- Copy / paste window
-- ns.ShowCopy(title, text)               shows text selected, ready for Ctrl+C
-- ns.ShowCopy(title, "", function(s) end) shows an empty box with an Import button
------------------------------------------------------------------------
local copyFrame
function ns.ShowCopy(title, text, onAccept)
    if not copyFrame then
        local W = ns.W
        local f = W.Window("MLZUICopyFrame", 540, 160, "MLZ UI")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        local hint = W.Text(f, "GameFontDisableSmall", "CTRL-A selects everything, CTRL-C copies, CTRL-V pastes.")
        hint:SetPoint("TOPLEFT", 16, -48)
        local holder = CreateFrame("Frame", nil, f)
        holder:SetPoint("TOPLEFT", 16, -68)
        holder:SetPoint("TOPRIGHT", -16, -68)
        holder:SetHeight(28)
        W.Fill(holder, W.T.input)
        W.Border(holder, W.T.border)
        local box = CreateFrame("EditBox", nil, holder)
        box:SetPoint("TOPLEFT", 8, 0)
        box:SetPoint("BOTTOMRIGHT", -8, 0)
        box:SetFontObject(ChatFontNormal)
        box:SetAutoFocus(true)
        box:SetMaxLetters(0)
        box:SetScript("OnEscapePressed", function() f:Hide() end)
        f.box = box
        local function Accept()
            local fn = f.onAccept
            if not fn then return end
            f:Hide()
            fn(strtrim(f.box:GetText()))
        end
        box:SetScript("OnEnterPressed", Accept)
        local btn = W.Button(f, "Import", 110, 26, Accept, "primary")
        btn:SetPoint("BOTTOMRIGHT", -16, 14)
        f.button = btn
        local close = W.Button(f, "Close", 90, 26, function() f:Hide() end)
        close:SetPoint("BOTTOMLEFT", 16, 14)
        copyFrame = f
    end
    copyFrame.TitleText:SetText(title or "MLZ UI")
    copyFrame.onAccept = onAccept
    copyFrame.button:SetShown(onAccept ~= nil)
    copyFrame.box:SetText(text or "")
    copyFrame:Show()
    copyFrame.box:SetFocus()
    if not onAccept then copyFrame.box:HighlightText() end
end

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
local commands = {}

function ns.AddCommand(name, help, fn)
    commands[name] = { help = help, fn = fn }
end

-- Everything else is controlled from the settings window (/mlz); the other commands still
-- work but are not listed.
local LISTED = { install = true, undo = true, debug = true, probe = true, minimap = true, role = true, np = true, keys = true, tour = true }

-- Runs a command from code (used by the settings window)
function ns.RunCommand(name, arg)
    local c = commands[name]
    if c then return c.fn(arg or "") end
end

local function ShowHelp()
    ns.Print("Type " .. ns.Cmd("/mlz") .. " to open the settings window. Commands:")
    local names = {}
    for name in pairs(commands) do
        if LISTED[name] then names[#names + 1] = name end
    end
    table.sort(names)
    for _, name in ipairs(names) do
        DEFAULT_CHAT_FRAME:AddMessage("  " .. ns.Cmd("/mlz " .. name) .. "  " .. commands[name].help)
    end
end

ns.AddCommand("debug", "toggles debug output on/off", function()
    ns.db.debug = not ns.db.debug
    ns.Print("debug:", ns.db.debug and "on" or "off")
end)

SLASH_MLZUI1 = "/mlz"
SlashCmdList.MLZUI = function(msg)
    msg = strtrim(msg or "")
    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd = cmd and cmd:lower()
    if not cmd then
        if ns.Settings then ns.Settings:Toggle() else ShowHelp() end
        return
    end
    if cmd == "help" or not commands[cmd] then
        ShowHelp()
        return
    end
    commands[cmd].fn(rest)
end
