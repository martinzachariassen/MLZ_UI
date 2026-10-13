-- MLZ UI: Core
-- Shared namespace, SavedVariables, event bus, combat queue and slash commands.

local ADDON, ns = ...
MLZUI = ns -- global for /dump MLZUI during development

ns.name = "MLZ UI"
ns.version = "0.6.0"
ns.modules = {}       -- registered modules, in load order (see MLZ_UI.toc), also indexed by key
ns.data = {}          -- data tables (Data/*.lua)

local DB_VERSION = 2

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

function ns.On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        eventFrame:RegisterEvent(event)
    end
    table.insert(handlers[event], fn)
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
local queue = {}

function ns.RunOutOfCombat(fn, label)
    if InCombatLockdown() then
        table.insert(queue, { fn = fn, label = label })
        ns.Print("In combat. Running", label or "the change", "when combat ends.")
        return false
    end
    fn()
    return true
end

ns.On("PLAYER_REGEN_ENABLED", function()
    while #queue > 0 do
        local job = table.remove(queue, 1)
        local ok, err = pcall(job.fn)
        if not ok then ns.Print("|cffff4444Error in queued job|r", job.label or "", err) end
    end
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
    MLZUIDB = MLZUIDB or {}
    ApplyDefaults(MLZUIDB, defaults)
    Migrate(MLZUIDB)
    ns.db = MLZUIDB
end)

ns.On("PLAYER_LOGIN", function()
    if ns.db.debug or not ns.db.installed then
        ns.Print("loaded (v" .. ns.version .. "). Type |cffffff00/mlz|r or click the minimap button to open the settings.")
    end
    C_Timer.After(5, function()
        if ns.RunProbe then pcall(ns.RunProbe, true) end
    end)
    if not ns.db.installed then
        C_Timer.After(2, function()
            if ns.Installer and not InCombatLockdown() then ns.Installer:Open() end
        end)
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
        local btn = W.Button(f, "Import", 110, 26, function()
            local fn = f.onAccept
            f:Hide()
            if fn then fn(strtrim(f.box:GetText())) end
        end, "primary")
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
    if onAccept then copyFrame.box:SetFocus() else copyFrame.box:HighlightText() end
    copyFrame:Show()
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
local LISTED = { install = true, undo = true, debug = true, probe = true }

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
