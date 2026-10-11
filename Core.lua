-- MLZ UI: Core
-- Shared namespace, SavedVariables, event bus, combat queue and slash commands.

local ADDON, ns = ...
MLZUI = ns -- global for /dump MLZUI during development

ns.name = "MLZ UI"
ns.version = "0.5.0"
ns.modules = {}       -- registered modules in order (Scale, Settings, Layout, Bindings)
ns.data = {}          -- data tables (Data/*.lua)

local DB_VERSION = 1

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
    -- [2] = function(db) ... end,
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
    ns.Print("loaded (v" .. ns.version .. "). Type |cffffff00/mlz|r for help.")
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
        local f = CreateFrame("Frame", "MLZUICopyFrame", UIParent, "BasicFrameTemplateWithInset")
        f:SetSize(520, 190)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        tinsert(UISpecialFrames, "MLZUICopyFrame")
        local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        box:SetPoint("TOPLEFT", 16, -40)
        box:SetPoint("BOTTOMRIGHT", -16, 48)
        box:SetAutoFocus(true)
        box:SetMaxLetters(0)
        box:SetScript("OnEscapePressed", function() f:Hide() end)
        f.box = box
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetSize(100, 24)
        btn:SetPoint("BOTTOM", 0, 14)
        btn:SetText("Import")
        btn:SetScript("OnClick", function()
            local fn = f.onAccept
            f:Hide()
            if fn then fn(strtrim(f.box:GetText())) end
        end)
        f.button = btn
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

local function ShowHelp()
    ns.Print("commands:")
    local names = {}
    for name in pairs(commands) do names[#names + 1] = name end
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
    if not cmd or not commands[cmd] then
        ShowHelp()
        return
    end
    commands[cmd].fn(rest)
end
