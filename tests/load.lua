-- MLZ UI: load test
-- Loads the addon in TOC order on a fake client (tests/wowstub.lua), fires the login events, runs
-- every module preview, the wizard and every control center page, and fails on any Lua error.
-- Run from the repo root with Lua 5.1: lua5.1 tests/load.lua [-v]

local ADDON = "MLZ_UI"
local verbose = arg and arg[1] == "-v"

local root = (arg and arg[0] or ""):match("^(.*)[/\\]tests[/\\]") or "."
package.path = root .. "/tests/?.lua;" .. package.path
local stub = require("wowstub")

local failures = {}
local function Fail(where, err)
    failures[#failures + 1] = where .. ": " .. tostring(err)
end

local function Step(where, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then Fail(where, err) end
    return ok
end

------------------------------------------------------------------------
-- Load the files the way the client does: each gets (addonName, namespace)
------------------------------------------------------------------------
local function TocFiles()
    local files = {}
    for raw in io.lines(root .. "/" .. ADDON .. ".toc") do
        local line = raw:gsub("\r$", "")
        if line ~= "" and not line:match("^#") then
            files[#files + 1] = (line:gsub("\\", "/"))
        end
    end
    return files
end

local ns = {}
local function LoadAddon()
    for _, file in ipairs(TocFiles()) do
        if file:match("%.lua$") then
            local chunk, err = loadfile(root .. "/" .. file)
            if not chunk then
                Fail("load " .. file, err)
            else
                Step("run " .. file, chunk, ADDON, ns)
            end
        end
    end
end

-- Errors inside event handlers are caught by Core and go through ns.Error. Count them as failures.
local function WatchErrors()
    local orig = ns.Error
    if not orig then return end
    ns.Error = function(where, err)
        Fail("ns.Error " .. tostring(where), err)
        return orig(where, err)
    end
end

local function Login(db)
    MLZUIDB = db -- luacheck: ignore 111
    Step("ADDON_LOADED", stub.Fire, "ADDON_LOADED", ADDON)
    Step("PLAYER_LOGIN", stub.Fire, "PLAYER_LOGIN")
    Step("PLAYER_ENTERING_WORLD", stub.Fire, "PLAYER_ENTERING_WORLD", true, false)
    stub.FlushTimers(function(err) Fail("timer", err) end)
end

------------------------------------------------------------------------
-- Checks
------------------------------------------------------------------------
local function CheckMigration()
    -- Run the migrations on a database from before v3 and check the result
    local old = { dbVersion = 1, healForce = "on", installed = true, toggles = {} }
    MLZUIDB = old -- luacheck: ignore 111
    Step("migrate ADDON_LOADED", stub.Fire, "ADDON_LOADED", ADDON)
    local db = MLZUIDB
    if type(db) ~= "table" then return Fail("migration", "MLZUIDB is not a table") end
    if db.healForce ~= nil then Fail("migration", "healForce was not removed") end
    if db.roleForce ~= "HEALER" and not (db.chars and next(db.chars)) then
        Fail("migration", "healForce = on did not become roleForce = HEALER")
    end
    if not db.wizardSeen then Fail("migration", "wizardSeen was not set for an installed database") end
    for _, line in ipairs(stub.chat) do
        if line:find("Migration to v", 1, true) then Fail("migration", line) end
    end
    local newest = db.dbVersion
    if type(newest) ~= "number" or newest < 3 then Fail("migration", "dbVersion is " .. tostring(newest)) end
end

local function CheckModules()
    local count = 0
    for _, mod in ipairs(ns.modules or {}) do
        if type(mod.Preview) == "function" then
            count = count + 1
            local ok, items = pcall(mod.Preview, mod)
            if not ok then
                Fail("Preview " .. tostring(mod.key), items)
            elseif items ~= nil and type(items) ~= "table" then
                Fail("Preview " .. tostring(mod.key), "returned " .. type(items) .. ", expected a table")
            end
        end
    end
    if count == 0 then Fail("modules", "no module with :Preview() was registered") end
    return count
end

local function CheckWizard()
    local I = ns.Installer
    if not I then return Fail("wizard", "ns.Installer is missing") end
    if not Step("Installer:Open", I.Open, I) then return end
    for i = 1, 30 do
        local before = I.page
        if not Step("Installer:Go(" .. i .. ")", I.Go, I, i) then break end
        if I.page == before and i > 1 then break end
    end
    stub.FlushTimers(function(err) Fail("wizard timer", err) end)
end

-- Differences between two flat tables, as "key: a -> b" lines. A missing key reads as `default`
-- (an unset CVar reads "0" in the stub, so writing "0" back counts as unchanged).
local function Diff(a, b, default)
    local out, keys = {}, {}
    for k in pairs(a) do keys[k] = true end
    for k in pairs(b) do keys[k] = true end
    for k in pairs(keys) do
        local va, vb = a[k], b[k]
        if va == nil then va = default end
        if vb == nil then vb = default end
        if va ~= vb then out[#out + 1] = tostring(k) .. ": " .. tostring(va) .. " -> " .. tostring(vb) end
    end
    table.sort(out)
    return out
end

local function Copy(t)
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    return c
end

-- Applies the wizard with its suggested rows, then undoes it: CVars and bindings must be back as before
local function CheckApplyUndo()
    local I = ns.Installer
    if not (I and ns.Backup) then return Fail("apply/undo", "ns.Installer or ns.Backup is missing") end
    local cvars, bindings = Copy(stub.cvars), Copy(stub.bindings)
    if not Step("apply Installer:Open", I.Open, I) then return end
    if not Step("Installer:ApplyAll", I.ApplyAll, I) then return end
    stub.FlushTimers(function(err) Fail("apply timer", err) end)
    local plain = (I.doneText or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    for line in plain:gmatch("[^\n]+") do
        if line:match("^FAILED") then Fail("apply", line) end
        if verbose and line:match("^PARTLY") then print("  note: " .. line) end
    end
    local changed = #Diff(cvars, stub.cvars, "0") + #Diff(bindings, stub.bindings, "")
    if changed == 0 then Fail("apply", "the wizard changed no CVars or bindings, so undo was not tested") end
    if not Step("Backup:Undo", ns.Backup.Undo, ns.Backup, true) then return changed end
    stub.FlushTimers(function(err) Fail("undo timer", err) end)
    for _, d in ipairs(Diff(cvars, stub.cvars, "0")) do Fail("undo CVar", d) end
    for _, d in ipairs(Diff(bindings, stub.bindings, "")) do Fail("undo binding", d) end
    return changed
end

local function CheckSettings()
    local S = ns.Settings
    if not S then return Fail("settings", "ns.Settings is missing") end
    if not Step("Settings:Build", S.Build, S) then return end
    local keys = {}
    for key, entry in pairs(S.pages or {}) do
        keys[#keys + 1] = key
        -- Page builders run inside pcall and show the error on the page. Catch it here instead.
        local build = entry.def and entry.def.build
        if build then
            entry.def.build = function(p)
                local ok, err = pcall(build, p)
                if not ok then Fail("page " .. key, err) error(err, 0) end
            end
        end
    end
    table.sort(keys)
    if #keys == 0 then Fail("settings", "no pages registered") end
    Step("Settings:Open", S.Open, S)
    for _, key in ipairs(keys) do Step("Settings:Select " .. key, S.Select, S, key) end
    Step("slash /mlz", SlashCmdList.MLZUI, "")
    Step("slash /mlz help", SlashCmdList.MLZUI, "help")
    stub.FlushTimers(function(err) Fail("settings timer", err) end)
    return #keys
end

------------------------------------------------------------------------
-- Run
------------------------------------------------------------------------
LoadAddon()
WatchErrors()
Login(nil)
local modules = CheckModules()
CheckWizard()
local pages = CheckSettings() or 0
local changed = CheckApplyUndo() or 0
CheckMigration()

if verbose then
    for _, line in ipairs(stub.chat) do print("  chat: " .. line) end
end

if #failures > 0 then
    print("Load test: " .. #failures .. " problem(s)")
    for _, f in ipairs(failures) do print("  " .. f) end
    os.exit(1)
end
print(("Load test: OK (%d modules previewed, %d settings pages built, %d changes applied and undone)")
    :format(modules, pages, changed))
