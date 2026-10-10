-- MLZ UI: Core
-- Felles namespace, SavedVariables, event-bus, kamp-kø og slash-kommandoer.

local ADDON, ns = ...
MLZUI = ns -- global for /dump MLZUI under utvikling

ns.name = "MLZ UI"
ns.version = "0.5.0"
ns.modules = {}       -- registrerte moduler i rekkefølge (Scale, Settings, Layout, Bindings)
ns.data = {}          -- data-tabeller (Data/*.lua)

local DB_VERSION = 1

------------------------------------------------------------------------
-- Utskrift
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
-- Hjelpefunksjoner
------------------------------------------------------------------------
function ns.CopyTable(src)
    if type(src) ~= "table" then return src end
    local t = {}
    for k, v in pairs(src) do t[k] = ns.CopyTable(v) end
    return t
end

-- Husker av/på-valg fra veiviseren per modul og element
function ns.Enabled(modKey, id, default)
    local v = ns.db and ns.db.toggles[modKey .. ":" .. tostring(id)]
    if v == nil then return default end
    return v
end

function ns.SetEnabled(modKey, id, value)
    ns.db.toggles[modKey .. ":" .. tostring(id)] = value and true or false
end

-- Kaller f trygt og returnerer ok, resultat...
function ns.Try(f, ...)
    if type(f) ~= "function" then return false, "ikke en funksjon" end
    return pcall(f, ...)
end

------------------------------------------------------------------------
-- Moduler
-- En modul er en tabell med:
--   key, title          -- id og visningsnavn
--   :Preview()          -- returnerer liste med { id, label, old, new, enabled, note, conflict }
--   :Apply(items)       -- utfører valgte endringer (items = de som har enabled = true)
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
        if not ok then ns.Print("|cffff4444Feil i", event .. ":|r", err) end
    end
end)

------------------------------------------------------------------------
-- Kamp-kø: ting som er blokkert i kamp kjøres når kampen er over
------------------------------------------------------------------------
local queue = {}

function ns.RunOutOfCombat(fn, label)
    if InCombatLockdown() then
        table.insert(queue, { fn = fn, label = label })
        ns.Print("I kamp. Kjører", label or "endringen", "når kampen er over.")
        return false
    end
    fn()
    return true
end

ns.On("PLAYER_REGEN_ENABLED", function()
    while #queue > 0 do
        local job = table.remove(queue, 1)
        local ok, err = pcall(job.fn)
        if not ok then ns.Print("|cffff4444Feil i kø-jobb|r", job.label or "", err) end
    end
end)

------------------------------------------------------------------------
-- SavedVariables
------------------------------------------------------------------------
local defaults = {
    dbVersion = DB_VERSION,
    installed = false,     -- har veiviseren blitt fullført?
    debug = false,
    scale = { mode = "auto" },   -- se Modules/Scale.lua
    movement = "ESDF",
    spellQueueWindow = nil,      -- nil = ikke rør
    toggles = {},                -- ["modul:id"] = true/false, husker valg i veiviseren
    backup = nil,                -- se Modules/Backup.lua
}

local function ApplyDefaults(db, def)
    for k, v in pairs(def) do
        if db[k] == nil then db[k] = ns.CopyTable(v) end
    end
end

local function Migrate(db)
    -- Fremtidige migreringer: if db.dbVersion < 2 then ... end
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
    ns.Print("lastet (v" .. ns.version .. "). Skriv |cffffff00/mlz|r for hjelp.")
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
-- Slash-kommandoer
------------------------------------------------------------------------
local commands = {}

function ns.AddCommand(name, help, fn)
    commands[name] = { help = help, fn = fn }
end

local function ShowHelp()
    ns.Print("kommandoer:")
    local names = {}
    for name in pairs(commands) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/mlz " .. name .. "|r  " .. commands[name].help)
    end
end

ns.AddCommand("debug", "slår debug-utskrift av/på", function()
    ns.db.debug = not ns.db.debug
    ns.Print("debug:", ns.db.debug and "på" or "av")
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
