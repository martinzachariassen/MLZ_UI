-- MLZ UI: Health check
-- Finds addons MLZ UI configures that are installed but switched off (usually by mistake in the addon
-- list). Silent at login: the result shows on the overview and in the minimap tooltip.
-- /mlz health prints the full list, including supported addons that aren't installed.

local _, ns = ...

-- Addons that are expected besides the ones listed in Data/Addons.lua.
-- `when` = only expected while it returns true (Platynator only matters as the nameplate engine).
local EXTRA = {
    { addon = "Platynator", title = "Platynator", when = function() return ns.NP and ns.NP.Engine() == "platynator" end },
    { addon = "!BugGrabber", title = "BugGrabber" },
}

local function Installed(addon)
    if C_AddOns and C_AddOns.DoesAddOnExist then
        local ok, exists = pcall(C_AddOns.DoesAddOnExist, addon)
        if ok then return exists and true or false end
    end
    return ns.IsAddOnInstalled(addon) -- GetAddOnInfo returns a name with reason "MISSING" for missing addons
end

-- onlyInstalled = skip addons that aren't installed at all
-- Returns a list of { title, installed }
local function Problems(onlyInstalled)
    local list, seen = {}, {}
    local function Check(addon, title, alt)
        if seen[title] or ns.IsAddOnLoaded(addon) or (alt and ns.IsAddOnLoaded(alt)) then return end
        local exists = Installed(addon) or (alt ~= nil and Installed(alt))
        if onlyInstalled and not exists then return end
        seen[title] = true
        list[#list + 1] = { title = title, addon = addon, installed = exists }
    end
    for _, entry in ipairs(ns.data.addons) do Check(entry.addon, entry.title, entry.alt) end
    for _, entry in ipairs(EXTRA) do
        if not entry.when or entry.when() then Check(entry.addon, entry.title) end
    end
    return list
end

ns.HealthProblems = Problems

-- Installed but switched off, for the overview and the minimap tooltip. Empty when the warning is off.
function ns.HealthOff()
    if ns.db and ns.db.healthWarn == false then return {} end
    local names = {}
    for _, p in ipairs(Problems(true)) do names[#names + 1] = p.title end
    return names
end

-- Recommended addons from Data/Addons.lua with their state for this character.
-- Returns a list of { title, why, installed, forRole } in data order.
function ns.Recommendations()
    local role = ns.Role and ns.Role() or "DAMAGER"
    local list = {}
    for _, rec in ipairs(ns.data.recommended or {}) do
        list[#list + 1] = {
            title = rec.title, addon = rec.addon, why = rec.why,
            installed = Installed(rec.addon) or (rec.alt ~= nil and Installed(rec.alt)),
            forRole = rec.roles ~= nil and rec.roles[role] == true,
        }
    end
    return list
end

local function Report()
    local list = Problems(false)
    local listed, worth = {}, {}
    for _, p in ipairs(list) do listed[p.addon] = true end
    for _, r in ipairs(ns.Recommendations()) do
        -- supported addons that are missing are already named under "Not installed"
        if not r.installed and not listed[r.addon] then worth[#worth + 1] = r.title end
    end
    if #list == 0 then
        ns.Print("All supported addons are loaded."
            .. (#worth > 0 and (" Worth a look: " .. table.concat(worth, ", ") .. ".") or ""))
        return
    end
    local off, missing = {}, {}
    for _, p in ipairs(list) do
        if p.installed then off[#off + 1] = p.title else missing[#missing + 1] = p.title end
    end
    -- one line, however many groups there are
    local parts = {}
    if #off > 0 then parts[#parts + 1] = "Switched off in the addon list: " .. table.concat(off, ", ") .. "." end
    if #missing > 0 then parts[#parts + 1] = "Not installed: " .. table.concat(missing, ", ") .. "." end
    if #worth > 0 then parts[#parts + 1] = "Worth a look: " .. table.concat(worth, ", ") .. "." end
    ns.Print(table.concat(parts, " "))
end

ns.AddCommand("health", "lists supported addons that are switched off or not installed", Report)
