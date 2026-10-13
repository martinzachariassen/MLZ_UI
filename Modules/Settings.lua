-- MLZ UI: Settings (CVars)
-- Reads the table in Data/CVars.lua, compares it with the current values and sets the selected ones.
-- CVars that don't exist in the client are skipped.

local _, ns = ...

local Settings = ns.RegisterModule({ key = "settings", title = "Settings" })

local function CVarExists(name)
    if C_CVar and C_CVar.GetCVarInfo then
        local ok, value = pcall(C_CVar.GetCVarInfo, name)
        return ok and value ~= nil
    end
    local ok, value = pcall(GetCVar, name)
    return ok and value ~= nil
end

local function Same(a, b)
    local na, nb = tonumber(a), tonumber(b)
    if na and nb then return math.abs(na - nb) < 0.0001 end
    return tostring(a) == tostring(b)
end

function Settings:Preview()
    local items = {}
    for _, row in ipairs(ns.data.cvars) do
        local item = { id = row.name, label = row.label, note = row.desc }
        if not CVarExists(row.name) then
            item.old, item.new = "-", "not available"
            item.enabled, item.unavailable = false, true
        else
            item.old = GetCVar(row.name)
            local target = tostring(row.value)
            if row.name == "SpellQueueWindow" and ns.db.spellQueueWindow then target = ns.db.spellQueueWindow end
            item.value, item.new = target, target
            if row.choices then
                item.choices = {}
                for i, v in ipairs(row.choices) do
                    item.choices[i] = { value = v, text = v }
                    if v == target then item.choiceIndex = i end
                end
                item.choiceIndex = item.choiceIndex or 1
            end
            local default = row.enabled
            if row.roles then
                -- role rows are only preselected for that role
                local role = ns.Role and ns.Role() or "DAMAGER"
                local names = {}
                for r in pairs(row.roles) do names[#names + 1] = (ns.ROLE_TEXT and ns.ROLE_TEXT[r]) or r end
                table.sort(names)
                item.note = (item.note or "") .. "  |cff888888(Ticked for: " .. table.concat(names, ", ") .. ")|r"
                default = default and row.roles[role] and true or false
            end
            item.enabled = ns.Enabled("settings", row.name, default)
            item.alreadySet = Same(item.old, target)
        end
        items[#items + 1] = item
    end
    return items
end

-- Picking another value in the wizard can turn an "already set" row into a change (or back)
function Settings:OnChoice(item)
    item.alreadySet = Same(item.old, item.value)
end

function Settings:Backup(items)
    local snap = {}
    for _, item in ipairs(items) do snap[item.id] = GetCVar(item.id) end
    return snap
end

function Settings:Apply(items)
    local changed = 0
    for _, item in ipairs(items) do
        if not item.unavailable and item.value ~= nil then
            local ok, err = pcall(SetCVar, item.id, item.value)
            if ok then
                changed = changed + 1
                if item.id == "SpellQueueWindow" then ns.db.spellQueueWindow = item.value end
            else
                ns.Print("|cffff4444Could not set|r", item.id, err)
            end
        end
    end
    ns.Debug("CVars set:", changed)
end

function Settings:Restore(snap)
    for name, value in pairs(snap) do
        pcall(SetCVar, name, value)
    end
end
