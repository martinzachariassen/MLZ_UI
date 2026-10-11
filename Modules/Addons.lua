-- MLZ UI: Other addons
-- Configures addons that are already installed (see Data/Addons.lua for the settings).
-- Nothing is downloaded or updated here; addons that aren't loaded are simply skipped.
-- Each change is backed up first, so /mlz undo puts the old values back.

local _, ns = ...

local Addons = ns.RegisterModule({ key = "addons", title = "Other addons" })

local function Loaded(folder)
    return C_AddOns.IsAddOnLoaded(folder)
end

-- Walks `path` from the addon's root table. Returns the parent table and the last key,
-- or nil if the root or an intermediate table is missing.
local function Resolve(entry, row, create)
    local node = (row.root or entry.root)()
    if type(node) ~= "table" then return nil end
    local path = row.path
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
    for i = 1, #row.path - 1 do
        node = node[row.path[i]]
        if type(node) ~= "table" then return 'missing "' .. tostring(row.path[i]) .. '"' end
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
                local parent, key = Resolve(entry, row)
                if not parent then
                    item.old, item.new = "-", "not available"
                    item.enabled, item.unavailable = false, true
                else
                    local current = parent[key]
                    item.old, item.new = Show(current), Show(row.value)
                    item.value = row.value
                    item.enabled = ns.Enabled("addons", id, row.enabled ~= false)
                    item.alreadySet = Same(current, row.value)
                end
                items[#items + 1] = item
            end
        end
    end
    if #items == 0 then
        items[1] = { id = "none", group = "Other addons", label = "No supported addons loaded",
            old = "-", new = "-", enabled = false, unavailable = true,
            note = "Install Prat, Auctionator, AtlasLoot, What's Training, Bagnon, RestedXP Guides or Deadly Boss Mods and run this step again." }
    end
    return items
end

function Addons:Backup(items)
    local snap = {}
    for _, item in ipairs(items) do
        local entry, row = Find(item.id)
        if entry then
            local parent, key = Resolve(entry, row)
            if parent then
                local current = parent[key]
                snap[item.id] = { has = current ~= nil, value = current }
            end
        end
    end
    return snap
end

function Addons:Apply(items)
    local changed = 0
    for _, item in ipairs(items) do
        local entry, row = Find(item.id)
        if entry and not item.unavailable then
            local parent, key = Resolve(entry, row, true)
            if parent then
                parent[key] = type(row.value) == "table" and CopyTable(row.value) or row.value
                changed = changed + 1
            end
        end
    end
    ns.Debug("Addon settings set:", changed)
end

function Addons:Restore(snap)
    for id, old in pairs(snap) do
        local entry, row = Find(id)
        if entry then
            local parent, key = Resolve(entry, row)
            if parent then
                if old.has then parent[key] = old.value else parent[key] = nil end
            end
        end
    end
end

ns.AddCommand("addons", "shows which supported addons are loaded and which of their settings differ", function()
    for _, entry in ipairs(ns.data.addons) do
        if not Loaded(entry.addon) then
            ns.Print(entry.title .. ": |cff888888not loaded|r")
        else
            local differ, total = 0, 0
            for _, row in ipairs(entry.rows) do
                local parent, key = Resolve(entry, row)
                if parent then
                    total = total + 1
                    if not Same(parent[key], row.value) then differ = differ + 1 end
                else
                    ns.Print("  |cffff8800not available:|r " .. row.label .. " - " .. Reason(entry, row))
                end
            end
            ns.Print(("%s: |cff44ff44loaded|r, %d of %d settings differ from MLZ UI"):format(entry.title, differ, total))
        end
    end
    ns.Print("Run |cffffff00/mlz install|r and go to the last step to change them.")
end)
