-- MLZ UI: Backup and undo
-- Before the setup wizard changes anything, it asks each module to save the old values of what will change.
-- Backups are kept in a stack in MLZUIDB.backups (max 5). /mlz undo restores the newest one.

local _, ns = ...

local Backup = {}
ns.Backup = Backup

local MAX_BACKUPS = 5

-- Order the wizard applies modules in (UI/Installer.lua); undo goes the other way
Backup.APPLY_ORDER = { "role", "scale", "settings", "layout", "bindings", "fade", "actionbuttons", "tweaks", "addons", "nameplates" }

-- selections = { { mod = <module>, items = {...} }, ... }
-- kind = "import" for profile imports, "preset" for ready-made setups.
-- Returns the entry, or nil plus the title of the module that failed (the caller tells the player).
function Backup:Create(selections, kind)
    local entry = { time = date("%Y-%m-%d %H:%M:%S"), data = {}, kind = kind }
    for _, sel in ipairs(selections) do
        if sel.mod.Backup then
            local ok, snap = pcall(sel.mod.Backup, sel.mod, sel.items)
            if ok then
                entry.data[sel.mod.key] = snap
            else
                ns.Debug("Backup failed for", sel.mod.title, snap)
                return nil, sel.mod.title
            end
        end
    end
    ns.db.backups = ns.db.backups or {}
    table.insert(ns.db.backups, entry)
    -- Drop the oldest, but always keep #1: it holds your settings from before MLZ UI changed anything
    while #ns.db.backups > MAX_BACKUPS do table.remove(ns.db.backups, 2) end
    return entry
end

-- Module order for restoring: reverse apply order, then any module not in that list
local function RestoreOrder()
    local list, seen = {}, {}
    for i = #Backup.APPLY_ORDER, 1, -1 do
        local mod = ns.modules[Backup.APPLY_ORDER[i]]
        if mod then list[#list + 1] = mod seen[mod] = true end
    end
    for i = #ns.modules, 1, -1 do
        local mod = ns.modules[i]
        if not seen[mod] then list[#list + 1] = mod end
    end
    return list
end

-- quiet = the caller shows its own feedback (wizard page, control center footer), so print nothing
function Backup:Undo(quiet)
    local list = ns.db.backups
    if not list or #list == 0 then
        if not quiet then ns.Print("No backup to restore.") end
        return
    end
    local function Say(text) if not quiet then ns.Print(text) end end
    -- Returns true when it ran now, false when it waits for combat to end, "partial" when a part could not be restored
    local partial = false
    local ran = ns.RunOutOfCombat(function()
        local entry = table.remove(list)
        local failed
        for _, mod in ipairs(RestoreOrder()) do
            local snap = entry.data[mod.key]
            if snap and mod.Restore then
                local ok, err = pcall(mod.Restore, mod, snap)
                if not ok then
                    ns.Debug("Restore failed for", mod.title, err)
                    failed = failed or {}
                    failed[mod.key] = snap
                end
            end
        end
        if failed then
            -- Keep what could not be restored, so another /mlz undo can try again
            table.insert(list, { time = entry.time, data = failed, kind = entry.kind })
            Say("Some parts could not be undone. Run /mlz undo again to retry (/mlz debug shows why).")
            partial = true
            ns.FireState()
            return
        end
        -- Undoing an import only gives back your old choices; the setup itself is still in place
        if #list == 0 and entry.kind ~= "import" and entry.kind ~= "preset" then ns.db.installed = false end
        -- Modules that can't restore live (some addon settings) have called ns.MarkReload themselves
        Say("Undone: back to how things were on " .. entry.time .. "."
            .. (ns.needsReload and " Reload to finish." or ""))
        ns.FireState()
    end, "undo", quiet)
    if ran and partial then return "partial" end
    return ran
end

ns.AddCommand("undo", "undoes the last setup wizard run or import", function() Backup:Undo() end)
ns.AddCommand("backups", "lists saved backups", function()
    local list = ns.db.backups or {}
    if #list == 0 then ns.Print("No backups.") return end
    for i, e in ipairs(list) do
        local parts = {}
        for k in pairs(e.data) do parts[#parts + 1] = k end
        ns.Print(i .. ".", e.time, "(" .. table.concat(parts, ", ") .. ")")
    end
end)
