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

-- Plain words for a raw value: "0" -> "off", "1" -> "on", or the row's own words ("locked")
local function Plain(row, value)
    if value == nil then return nil end
    local v = tostring(value)
    if row.text and row.text[v] then return row.text[v] end
    return v
end

local function IsSwitch(row, a, b)
    if row.numeric or row.choices or row.text then return false end
    return (a == "0" or a == "1") and (b == "0" or b == "1")
end

function Settings:Preview()
    local items = {}
    local grey = ns.W and ns.W.C.grey or "|cff8a909a"
    local groupNotes = ns.data.cvarGroups or {}
    -- The role picked in the wizard's first step counts at once (the saved role only changes on Apply)
    local role = ns.WizardRole and ns.WizardRole() or (ns.Role and ns.Role()) or "DAMAGER"
    for _, row in ipairs(ns.data.cvars) do
        local item = {
            id = row.name, label = row.label, note = row.desc,
            group = row.group, groupNote = groupNotes[row.group], behaviour = row.behaviour,
        }
        if row.behaviour then
            item.note = (item.note or "") .. "  Changes how the game plays, not how it looks."
        end
        if not CVarExists(row.name) then
            item.old, item.new = "-", "not available"
            item.enabled, item.unavailable = false, true
            item.note = (item.note or "") .. "  Your game version does not have this setting."
        else
            local raw = GetCVar(row.name)
            local target = tostring(row.value)
            if row.name == "SpellQueueWindow" and ns.db.spellQueueWindow then target = ns.db.spellQueueWindow end
            item.rawOld = raw
            item.value = target
            if row.choices then
                item.choices = {}
                for i, v in ipairs(row.choices) do
                    item.choices[i] = { value = v, text = v }
                    if v == target then item.choiceIndex = i end
                end
                item.choiceIndex = item.choiceIndex or 1
            end
            local switch = IsSwitch(row, tostring(raw), target)
            local function Words(v)
                if switch then return v == "1" and "on" or "off" end
                return Plain(row, v)
            end
            item.old, item.new = Words(tostring(raw)), Words(target)
            local default = row.enabled
            if row.roles then
                -- role rows are only preselected for that role
                local names = {}
                for r in pairs(row.roles) do names[#names + 1] = (ns.ROLE_TEXT and ns.ROLE_TEXT[r]) or r end
                table.sort(names)
                item.note = (item.note or "") .. "  " .. grey .. "(Ticked for: " .. table.concat(names, ", ") .. ")|r"
                default = default and row.roles[role] and true or false
            end
            item.enabled = ns.Enabled("settings", row.name, default)
            item.alreadySet = Same(raw, target)
        end
        items[#items + 1] = item
    end
    return items
end

-- Picking another value in the wizard can turn an "already set" row into a change (or back)
function Settings:OnChoice(item)
    item.alreadySet = Same(item.rawOld, item.value)
end

function Settings:Backup(items)
    local snap = {}
    for _, item in ipairs(items) do snap[item.id] = GetCVar(item.id) end
    -- the spell queue value is also kept in our saved variables (re-applied on login)
    snap.__spellQueueWindow = ns.db.spellQueueWindow or false
    return snap
end

function Settings:Apply(items)
    local changed, failed = 0, 0
    for _, item in ipairs(items) do
        if not item.unavailable and item.value ~= nil then
            local ok, err = pcall(SetCVar, item.id, item.value)
            if ok then
                changed = changed + 1
                if item.id == "SpellQueueWindow" then ns.db.spellQueueWindow = item.value end
            else
                failed = failed + 1
                ns.Debug("Could not set", item.id, err)
            end
        end
    end
    ns.Debug("CVars set:", changed)
    if failed > 0 then return ("%d game setting%s could not be changed"):format(failed, failed == 1 and "" or "s") end
end

function Settings:Restore(snap)
    for name, value in pairs(snap) do
        if name ~= "__spellQueueWindow" then pcall(SetCVar, name, value) end
    end
    if snap.__spellQueueWindow ~= nil then ns.db.spellQueueWindow = snap.__spellQueueWindow or nil end
end
