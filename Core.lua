-- MLZ UI: Core
-- Shared namespace, SavedVariables, event bus, combat queue and slash commands.

local ADDON, ns = ...
MLZUI = ns -- global for /dump MLZUI during development

ns.name = "MLZ UI"
ns.version = "0.7.0"
ns.modules = {}       -- registered modules, in load order (see MLZ_UI.toc), also indexed by key
ns.data = {}          -- data tables (Data/*.lua)

local DB_VERSION = 3

------------------------------------------------------------------------
-- Output
------------------------------------------------------------------------
local PREFIX = "|cff33ccffMLZ UI|r: "

function ns.Print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. table.concat(parts, " "))
end

function ns.Debug(...)
    if ns.db and ns.db.debug then ns.Print("|cff888888[debug]|r", ...) end
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
        if not ok then ns.Print("|cffff4444Error in", event .. ":|r", err) end
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
        if not ok then ns.Print("|cffff4444Error in queued job|r", job.label or "", err) end
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
-- Role: one answer for every module (healer layouts, nameplates, overview, role profiles).
-- ns.Role()     -> "TANK" | "HEALER" | "DAMAGER" | nil  (what you are: forced choice, spec, talents, group role)
-- ns.LiveRole() -> same, but a tank spec that isn't tanking right now (cat form, battle stance on a
--                  non-protection warrior) counts as DAMAGER. Used by nameplates.
------------------------------------------------------------------------
local PURE_DPS = { MAGE = true, WARLOCK = true, ROGUE = true, HUNTER = true }
local HEAL_TABS = { DRUID = { [3] = true }, PRIEST = { [1] = true, [2] = true }, PALADIN = { [1] = true }, SHAMAN = { [3] = true } }
local TANK_TABS = { WARRIOR = { [3] = true }, PALADIN = { [2] = true }, DRUID = { [2] = true } }
ns.ROLE_TEXT = { TANK = "Tank", HEALER = "Healer", DAMAGER = "DPS" }

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

local function TalentRole(class)
    if not (GetNumTalentTabs and GetTalentTabInfo) then return end
    local okN, n = pcall(GetNumTalentTabs)
    if not okN or not n or n == 0 then return end
    local best, bestPoints = nil, 0
    for tab = 1, n do
        local p = TabPoints(tab)
        if p > bestPoints then best, bestPoints = tab, p end
    end
    if not best then return end -- no points spent (low level)
    if HEAL_TABS[class] and HEAL_TABS[class][best] then return "HEALER" end
    if TANK_TABS[class] and TANK_TABS[class][best] then return "TANK" end
    return "DAMAGER"
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

-- Returns role, source ("forced" | "spec" | "talents" | "group" | "class")
function ns.Role()
    local force = ns.GetRoleForce()
    if force then return force, "forced" end
    local class = PlayerClass()
    if PURE_DPS[class] then return "DAMAGER", "class" end
    local r = SpecRole()
    if r then return r, "spec" end
    r = TalentRole(class)
    if r then return r, "talents" end
    r = GroupRole()
    if r then return r, "group" end
    return nil, "unknown"
end

local function InBearForm()
    if not GetShapeshiftFormID then return false end
    local id = GetShapeshiftFormID()
    return id == 5 or id == 8
end

-- Returns role, reason (short text for the settings window)
function ns.LiveRole()
    local role, source = ns.Role()
    local class = PlayerClass()
    if UnitHasEffectivelyTankAura and UnitHasEffectivelyTankAura("player") then
        return "TANK", "tank aura active"
    end
    if GroupRole() == "TANK" then return "TANK", "assigned tank in the group" end
    if role == "TANK" and class == "DRUID" and source ~= "forced" then
        if InBearForm() then return "TANK", "Bear Form + Feral talents" end
        return "DAMAGER", "Feral, not in Bear Form"
    end
    if role then return role, (source == "forced" and "set by you") or ("from " .. source) end
    return nil, "no role found"
end

-- v: "TANK" | "HEALER" | "DAMAGER" | nil (auto)
function ns.SetRoleForce(v)
    ns.GetRoleForce() -- takes over an old account-wide choice first
    ns.CharDB().roleForce = (v == "TANK" or v == "HEALER" or v == "DAMAGER") and v or nil
    ns.FireRole()
end

-- Role change notifications (spec/talent/form/group changes come in bursts; this coalesces them)
local roleListeners, lastRole, lastLive = {}, nil, nil
function ns.OnRoleChanged(fn) roleListeners[#roleListeners + 1] = fn end

function ns.FireRole()
    local role, live = ns.Role(), ns.LiveRole()
    local changed = role ~= lastRole
    local liveChanged = live ~= lastLive
    lastRole, lastLive = role, live
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
ns.TryOn("UNIT_AURA", function(_, unit)
    if unit == "player" and UnitHasEffectivelyTankAura then ScheduleRole() end
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
}

local function Migrate(db)
    for v = (db.dbVersion or 1) + 1, DB_VERSION do
        local step = migrations[v]
        if step then
            local ok, err = pcall(step, db)
            if not ok then ns.Print("|cffff4444Migration to v" .. v .. " failed:|r", err) end
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
        -- First time: open the wizard once. After that just a reminder in chat.
        C_Timer.After(2, function()
            if ns.Installer and not InCombatLockdown() then
                ns.db.wizardSeen = true
                ns.Installer:Open()
            end
        end)
    else
        ns.Print("v" .. ns.version .. " is not set up yet. Type |cffffff00/mlz install|r for the setup wizard, or |cffffff00/mlz|r for the settings.")
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
        local hint = W.Text(f, "GameFontDisableSmall", "Ctrl+A selects everything, Ctrl+C copies, Ctrl+V pastes.")
        hint:SetPoint("TOPLEFT", 16, -48)
        local holder = CreateFrame("Frame", nil, f)
        holder:SetPoint("TOPLEFT", 16, -68)
        holder:SetPoint("TOPRIGHT", -16, -68)
        holder:SetHeight(28)
        W.Fill(holder, { 0.05, 0.055, 0.07, 1 })
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
local LISTED = { install = true, undo = true, debug = true, probe = true, minimap = true, role = true, np = true }

-- Runs a command from code (used by the settings window)
function ns.RunCommand(name, arg)
    local c = commands[name]
    if c then return c.fn(arg or "") end
end

local function ShowHelp()
    ns.Print("Type |cffffff00/mlz|r to open the settings window. Commands:")
    local names = {}
    for name in pairs(commands) do
        if LISTED[name] then names[#names + 1] = name end
    end
    table.sort(names)
    for _, name in ipairs(names) do
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/mlz " .. name .. "|r  " .. commands[name].help)
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
