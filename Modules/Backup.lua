-- MLZ UI: Backup and undo
-- Before the setup wizard changes anything, it asks each module to save the old values of what will change.
-- Backups are kept in a stack in MLZUIDB.backups (max 5). /mlz undo restores the newest one.

local _, ns = ...

local Backup = {}
ns.Backup = Backup

local MAX_BACKUPS = 5

-- selections = { { mod = <module>, items = {...} }, ... }
function Backup:Create(selections)
    local entry = { time = date("%Y-%m-%d %H:%M:%S"), data = {} }
    for _, sel in ipairs(selections) do
        if sel.mod.Backup then
            local ok, snap = pcall(sel.mod.Backup, sel.mod, sel.items)
            if ok then
                entry.data[sel.mod.key] = snap
            else
                ns.Print("|cffff4444Backup failed for|r", sel.mod.title, snap)
                return nil
            end
        end
    end
    ns.db.backups = ns.db.backups or {}
    table.insert(ns.db.backups, entry)
    while #ns.db.backups > MAX_BACKUPS do table.remove(ns.db.backups, 1) end
    return entry
end

function Backup:Undo()
    local list = ns.db.backups
    if not list or #list == 0 then
        ns.Print("No backup to restore.")
        return
    end
    ns.RunOutOfCombat(function()
        local entry = table.remove(list)
        -- Restore in reverse order of Apply
        for i = #ns.modules, 1, -1 do
            local mod = ns.modules[i]
            local snap = entry.data[mod.key]
            if snap and mod.Restore then
                local ok, err = pcall(mod.Restore, mod, snap)
                if not ok then ns.Print("|cffff4444Restore failed for|r", mod.title, err) end
            end
        end
        ns.Print("Restored backup from", entry.time .. ". Type |cffffff00/reload|r to finish.")
        if #list == 0 then ns.db.installed = false end
    end, "undo")
end

ns.AddCommand("undo", "undoes the last run of the setup wizard", function() Backup:Undo() end)
ns.AddCommand("backups", "lists saved backups", function()
    local list = ns.db.backups or {}
    if #list == 0 then ns.Print("No backups.") return end
    for i, e in ipairs(list) do
        local parts = {}
        for k in pairs(e.data) do parts[#parts + 1] = k end
        ns.Print(i .. ".", e.time, "(" .. table.concat(parts, ", ") .. ")")
    end
end)
