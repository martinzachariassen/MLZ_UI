-- MLZ UI: Backup og angre
-- Før veiviseren endrer noe, ber den hver modul om å lagre gamle verdier for det som skal endres.
-- Backupene ligger i en stabel i MLZUIDB.backups (maks 5). /mlz undo gjenoppretter den nyeste.

local _, ns = ...

local Backup = {}
ns.Backup = Backup

local MAX_BACKUPS = 5

-- selections = { { mod = <modul>, items = {...} }, ... }
function Backup:Create(selections)
    local entry = { time = date("%Y-%m-%d %H:%M:%S"), data = {} }
    for _, sel in ipairs(selections) do
        if sel.mod.Backup then
            local ok, snap = pcall(sel.mod.Backup, sel.mod, sel.items)
            if ok then
                entry.data[sel.mod.key] = snap
            else
                ns.Print("|cffff4444Backup feilet for|r", sel.mod.title, snap)
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
        ns.Print("Ingen backup å gjenopprette.")
        return
    end
    ns.RunOutOfCombat(function()
        local entry = table.remove(list)
        -- Gjenopprett i motsatt rekkefølge av Apply
        for i = #ns.modules, 1, -1 do
            local mod = ns.modules[i]
            local snap = entry.data[mod.key]
            if snap and mod.Restore then
                local ok, err = pcall(mod.Restore, mod, snap)
                if not ok then ns.Print("|cffff4444Gjenoppretting feilet for|r", mod.title, err) end
            end
        end
        ns.Print("Gjenopprettet backup fra", entry.time .. ". Skriv |cffffff00/reload|r for å fullføre.")
        if #list == 0 then ns.db.installed = false end
    end, "angring")
end

ns.AddCommand("undo", "angrer siste gang veiviseren ble brukt", function() Backup:Undo() end)
ns.AddCommand("backups", "viser lagrede backuper", function()
    local list = ns.db.backups or {}
    if #list == 0 then ns.Print("Ingen backuper.") return end
    for i, e in ipairs(list) do
        local parts = {}
        for k in pairs(e.data) do parts[#parts + 1] = k end
        ns.Print(i .. ".", e.time, "(" .. table.concat(parts, ", ") .. ")")
    end
end)
