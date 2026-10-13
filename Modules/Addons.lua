-- MLZ UI: Other addons
-- Configures addons that are already installed (see Data/Addons.lua for the settings).
-- Nothing is downloaded or updated here; addons that aren't loaded are simply skipped.
-- Each change is backed up first, so /mlz undo puts the old values back.

local _, ns = ...

local Addons = ns.RegisterModule({ key = "addons", title = "Other addons" })

local function Loaded(folder)
    return ns.IsAddOnLoaded(folder)
end

-- A row sets one key (path/value) or several (set = { { path, value }, ... }).
-- Parts() returns the list either way, so the code below only deals with lists.
local function Parts(row)
    if row.set then return row.set end
    row._parts = row._parts or { { path = row.path, value = row.value } }
    return row._parts
end

-- Walks `path` from the addon's root table. Returns the parent table and the last key,
-- or nil if the root or an intermediate table is missing.
local function Resolve(entry, row, path, create)
    local node = (row.root or entry.root)()
    if type(node) ~= "table" then return nil end
    for i = 1, #path - 1 do
        local nextNode = node[path[i]]
        if nextNode == nil and create then
            nextNode = {}
            node[path[i]] = nextNode
        end
        if type(nextNode) ~= "table" then return nil end
        node = nextNode
    end
    return node, path[#path]
end

-- Explains why Resolve() failed, for /mlz addons
local function Reason(entry, row)
    local node = (row.root or entry.root)()
    if type(node) ~= "table" then return "settings table not found (addon not initialised yet?)" end
    for _, part in ipairs(Parts(row)) do
        local n = node
        for i = 1, #part.path - 1 do
            n = n[part.path[i]]
            if type(n) ~= "table" then return 'missing "' .. tostring(part.path[i]) .. '"' end
        end
    end
    return "unknown"
end

local function Show(v)
    if v == nil then return "default" end
    if type(v) == "table" then
        local parts = {}
        for i, x in ipairs(v) do parts[i] = tostring(x) end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(v)
end

-- Equal for plain values and flat arrays (e.g. colors)
local function Same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

-- Reads every part of a row. Returns { current values } or nil if any key can't be reached.
local function Read(entry, row)
    local values = {}
    for i, part in ipairs(Parts(row)) do
        local parent, key = Resolve(entry, row, part.path)
        if not parent then return nil end
        values[i] = { v = parent[key] }
    end
    return values
end

-- Text for the wizard: one value as is, several through row.show
local function Format(row, get)
    local parts = Parts(row)
    if not row.set then return Show(get(1, parts[1])) end
    local shown = {}
    for i, part in ipairs(parts) do
        local v = get(i, part)
        if v == nil then return "default" end
        shown[i] = Show(v)
    end
    if row.show then return row.show:format(unpack(shown)) end
    return table.concat(shown, " ")
end

local function Matches(row, values)
    for i, part in ipairs(Parts(row)) do
        if not Same(values[i].v, part.value) then return false end
    end
    return true
end

local function Find(id)
    for _, entry in ipairs(ns.data.addons) do
        for _, row in ipairs(entry.rows) do
            if entry.addon .. ":" .. row.id == id then return entry, row end
        end
    end
end

function Addons:Preview()
    local items = {}
    for _, entry in ipairs(ns.data.addons) do
        if Loaded(entry.addon) then
            for _, row in ipairs(entry.rows) do
                local id = entry.addon .. ":" .. row.id
                local item = { id = id, group = entry.title, label = row.label, note = row.desc }
                local values = Read(entry, row)
                if not values then
                    item.old, item.new = "-", "not available"
                    item.enabled, item.unavailable = false, true
                else
                    item.old = Format(row, function(i) return values[i].v end)
                    item.new = Format(row, function(_, part) return part.value end)
                    item.enabled = ns.Enabled("addons", id, row.enabled ~= false)
                    item.alreadySet = Matches(row, values)
                    if entry.manual and not item.alreadySet then
                        -- shown so you know what to change, but never written
                        item.enabled, item.unavailable = false, true
                        item.note = entry.manual .. (row.desc and ("  " .. row.desc) or "")
                    end
                end
                items[#items + 1] = item
            end
        end
    end
    if #items == 0 then
        local names = {}
        for _, entry in ipairs(ns.data.addons) do
            local name = entry.title:gsub("%s*%(.-%)", "")
            if names[#names] ~= name then names[#names + 1] = name end
        end
        items[1] = { id = "none", group = "Other addons", label = "No supported addons loaded",
            old = "-", new = "-", enabled = false, unavailable = true,
            note = "Supported: " .. table.concat(names, ", ") .. ". Install one and run this step again." }
    end
    return items
end

function Addons:Backup(items)
    local snap = {}
    for _, item in ipairs(items) do
        local entry, row = Find(item.id)
        if entry then
            local parts = {}
            for i, part in ipairs(Parts(row)) do
                local parent, key = Resolve(entry, row, part.path)
                if parent then
                    local current = parent[key]
                    parts[i] = { has = current ~= nil, value = type(current) == "table" and ns.CopyTable(current) or current }
                end
            end
            snap[item.id] = { parts = parts }
        end
    end
    return snap
end

function Addons:Apply(items)
    local changed, needReload = 0, false
    for _, item in ipairs(items) do
        local entry, row = Find(item.id)
        if entry and not item.unavailable and not entry.manual then
            for _, part in ipairs(Parts(row)) do
                local parent, key = Resolve(entry, row, part.path, true)
                if parent then
                    parent[key] = type(part.value) == "table" and ns.CopyTable(part.value) or part.value
                    changed = changed + 1
                    if not entry.live then needReload = true end
                end
            end
        end
    end
    ns.Debug("Addon settings set:", changed)
    -- Most addons read their saved settings only when they load; entries marked live don't
    if needReload then ns.MarkReload("addon settings") end
end

function Addons:Restore(snap)
    for id, old in pairs(snap) do
        local entry, row = Find(id)
        if entry then
            -- Older backups stored one { has, value } per row
            local saved = old.parts or { old }
            for i, part in ipairs(Parts(row)) do
                local prev = saved[i]
                if prev then
                    local parent, key = Resolve(entry, row, part.path)
                    if parent then
                        if prev.has then parent[key] = prev.value else parent[key] = nil end
                        if not entry.live then ns.MarkReload("addon settings") end
                    end
                end
            end
        end
    end
end

-- One entry per addon in Data/Addons.lua:
-- { title, addon, desc, loaded, differ, total, rows = #rows, missing = { "label - reason", ... } }
function Addons:Summary()
    local list = {}
    for _, entry in ipairs(ns.data.addons) do
        local s = { title = entry.title, addon = entry.addon, loaded = Loaded(entry.addon) and true or false,
            differ = 0, total = 0, rows = #entry.rows, missing = {}, manual = entry.manual }
        if s.loaded then
            for _, row in ipairs(entry.rows) do
                local ok, values = pcall(Read, entry, row)
                if ok and values then
                    s.total = s.total + 1
                    if not Matches(row, values) then s.differ = s.differ + 1 end
                else
                    s.missing[#s.missing + 1] = row.label .. " - " .. (ok and Reason(entry, row) or tostring(values))
                end
            end
        end
        list[#list + 1] = s
    end
    return list
end

ns.AddCommand("addons", "shows which supported addons are loaded and which of their settings differ", function()
    for _, s in ipairs(Addons:Summary()) do
        if not s.loaded then
            ns.Print(s.title .. ": |cff888888not loaded|r")
        else
            for _, m in ipairs(s.missing) do ns.Print("  |cffff8800not available:|r " .. m) end
            ns.Print(("%s: |cff44ff44loaded|r, %d of %d settings differ from MLZ UI"):format(s.title, s.differ, s.total))
        end
    end
    ns.Print("Open the settings (/mlz) or run |cffffff00/mlz install|r to change them.")
end)
