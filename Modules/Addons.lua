-- MLZ UI: Other addons
-- Configures addons that are already installed (see Data/Addons.lua for the settings).
-- Nothing is downloaded or updated here; addons that aren't loaded are simply skipped.
-- Each change is backed up first, so /mlz undo puts the old values back.

local _, ns = ...

local Addons = ns.RegisterModule({ key = "addons", title = "Other addons" })

local function Loaded(entry)
    return ns.IsAddOnLoaded(entry.addon) or (entry.alt ~= nil and ns.IsAddOnLoaded(entry.alt))
end

-- A row can be limited to roles ({ TANK = true }) and/or archetypes ({ CASTER = true, RANGED = true }).
-- It uses the role you picked in the wizard, not the live one, so a stance change never swaps addon settings.
local function ForMe(row)
    if row.roles and not row.roles[(ns.Role())] then return false end
    if row.archetypes and not row.archetypes[(ns.Archetype())] then return false end
    return true
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

-- Colors and similar tables can sit behind a metatable (Bagnon) or use named keys (Questie), so both
-- helpers walk the keys of the *expected* value instead of using # or ipairs on the current one.
local function Keys(shape)
    local keys = {}
    if #shape > 0 then
        for i = 1, #shape do keys[i] = i end
    else
        for k in pairs(shape) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    end
    return keys
end

local function Show(v, shape)
    if v == nil then return "default" end
    if type(v) ~= "table" then return tostring(v) end
    if type(shape) ~= "table" then shape = v end
    local parts = {}
    for i, k in ipairs(Keys(shape)) do parts[i] = tostring(v[k]) end
    return "{" .. table.concat(parts, ", ") .. "}"
end

-- Equal for plain values and flat tables (e.g. colors)
local function Same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for _, k in ipairs(Keys(b)) do
        if a[k] ~= b[k] then return false end
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
    if not row.set then return Show(get(1, parts[1]), parts[1].value) end
    local shown = {}
    for i, part in ipairs(parts) do
        local v = get(i, part)
        if v == nil then return "default" end
        shown[i] = Show(v, part.value)
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

-- Text when an addon it depends on is missing (entry.requires = folder name), else nil
local function MissingDependency(entry)
    if entry.requires and not ns.IsAddOnLoaded(entry.requires) then
        return entry.requires .. " is not loaded"
    end
end

-- Leatrix keeps its settings in a private table and writes them over its saved file at logout.
-- Its own "nosave" command stops that for this session, so what we write stays. Without the
-- command (an older Leatrix) the rows are shown but never written.
local unlocked = {}

local function Writable(entry)
    if entry.nosave then
        return type(SlashCmdList) == "table" and type(SlashCmdList[entry.nosave]) == "function"
    end
    return not entry.manual
end

local function Unlock(entry)
    if not entry.nosave or unlocked[entry.nosave] then return end
    unlocked[entry.nosave] = true
    ns.Try(SlashCmdList[entry.nosave], "nosave")
end

-- Asks an addon to redraw from its new settings. Returns true if it did, so no /reload is needed.
local function Refresh(entry)
    if not entry.refresh then return false end
    local ok, done = ns.Try(entry.refresh)
    return ok and done == true
end

local function PreviewRow(entry, row)
    local id = entry.addon .. ":" .. row.id
    local item = { id = id, group = entry.title, label = row.label, note = row.desc }
    local missing = MissingDependency(entry)
    if missing then
        item.old, item.new = "-", missing
        item.enabled, item.unavailable, item.attention = false, true, true
        return item
    end
    local values = Read(entry, row)
    if not values then
        item.old, item.new = "-", "not available"
        item.enabled, item.unavailable = false, true
        return item
    end
    item.old = Format(row, function(i) return values[i].v end)
    item.new = Format(row, function(_, part) return part.value end)
    item.enabled = ns.Enabled("addons", id, row.enabled ~= false)
    item.alreadySet = Matches(row, values)
    if not Writable(entry) and not item.alreadySet then
        -- shown so you know what to change, but never written
        item.enabled, item.unavailable = false, true
        item.note = entry.manual .. (row.desc and ("  " .. row.desc) or "")
    end
    return item
end

function Addons:Preview()
    local items = {}
    for _, entry in ipairs(ns.data.addons) do
        if Loaded(entry) then
            for _, row in ipairs(entry.rows) do
                if ForMe(row) then items[#items + 1] = PreviewRow(entry, row) end
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
    local changed, failed = 0, 0
    local touched = {}
    for _, item in ipairs(items) do
        local entry, row = Find(item.id)
        if entry and not item.unavailable and Writable(entry) then
            Unlock(entry)
            for _, part in ipairs(Parts(row)) do
                local parent, key = Resolve(entry, row, part.path, true)
                if parent then
                    parent[key] = type(part.value) == "table" and ns.CopyTable(part.value) or part.value
                    changed = changed + 1
                    touched[entry] = true
                else
                    failed = failed + 1
                end
            end
        end
    end
    ns.Debug("Addon settings set:", changed, "failed:", failed)
    -- Most addons read their saved settings only when they load. Entries marked live, or that redraw
    -- through their own refresh, don't need a reload.
    local needReload = false
    for entry in pairs(touched) do
        if not entry.live and not Refresh(entry) then needReload = true end
    end
    if needReload then ns.MarkReload("addon settings") end
    if failed > 0 then
        return failed == 1 and "1 addon setting could not be written." or (failed .. " addon settings could not be written.")
    end
end

function Addons:Restore(snap)
    local touched = {}
    for id, old in pairs(snap) do
        local entry, row = Find(id)
        if entry and Writable(entry) then
            Unlock(entry)
            -- Older backups stored one { has, value } per row
            local saved = old.parts or { old }
            for i, part in ipairs(Parts(row)) do
                local prev = saved[i]
                if prev then
                    local parent, key = Resolve(entry, row, part.path)
                    if parent then
                        if prev.has then parent[key] = prev.value else parent[key] = nil end
                        touched[entry] = true
                    end
                end
            end
        end
    end
    for entry in pairs(touched) do
        if not entry.live and not Refresh(entry) then ns.MarkReload("addon settings") end
    end
end

-- One entry per addon in Data/Addons.lua:
-- { title, addon, desc, loaded, differ, total, rows = #rows, missing = { "label - reason", ... } }
function Addons:Summary()
    local list = {}
    for _, entry in ipairs(ns.data.addons) do
        local s = { title = entry.title, addon = entry.addon, loaded = Loaded(entry) and true or false,
            differ = 0, total = 0, rows = 0, missing = {}, manual = not Writable(entry) and entry.manual or nil }
        for _, row in ipairs(entry.rows) do
            if ForMe(row) then s.rows = s.rows + 1 end
        end
        local missing = s.loaded and MissingDependency(entry)
        if missing then
            s.missing[1] = entry.title .. " - " .. missing
        elseif s.loaded then
            for _, row in ipairs(entry.rows) do
                if ForMe(row) then
                    local ok, values = pcall(Read, entry, row)
                    if ok and values then
                        s.total = s.total + 1
                        if not Matches(row, values) then s.differ = s.differ + 1 end
                    else
                        s.missing[#s.missing + 1] = row.label .. " - " .. (ok and Reason(entry, row) or tostring(values))
                    end
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
