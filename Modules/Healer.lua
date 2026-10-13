-- MLZ UI: Healer layouts
-- Switches between the Edit Mode layouts made in Modules/Layout.lua (data: ns.data.layout.healer):
--   healer in a raid           -> "MLZ UI Heal Raid"
--   healer in a party          -> "MLZ UI Heal Dungeon"
--   anything else              -> "MLZ UI" (main layout: tank / dps / solo)
-- Healer = your active spec has the healer role (e.g. Restoration druid). If the client can't tell,
-- the role you have in the group is used, and /mlz heal on|off overrides both.
-- It only switches when one of the MLZ layouts is active, so a layout you chose yourself is never replaced.
-- Edit Mode can't be changed in combat; the switch waits until combat ends.

local _, ns = ...

local function Layout() return ns.modules.layout end

local function SpecRole()
    local info = C_SpecializationInfo
    if info and info.GetSpecialization and info.GetSpecializationInfo then
        local ok, index = pcall(info.GetSpecialization)
        if ok and index then
            local ok2, _, _, _, _, role = pcall(info.GetSpecializationInfo, index)
            if ok2 and role then return role end
        end
    end
end

-- Returns "HEALER" | "TANK" | "DAMAGER" | nil
local function Role()
    return SpecRole() or ((IsInGroup() and UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")) or nil)
end

local function IsHealer()
    local force = ns.db and ns.db.healForce
    if force == "on" then return true end
    if force == "off" then return false end
    return Role() == "HEALER"
end

local function WantedLayout()
    local h = ns.data.layout.healer
    if not h or not IsHealer() then return ns.data.layout.name end
    local kind = IsInRaid() and "raid" or (IsInGroup() and "party" or nil)
    if kind then
        for _, v in ipairs(h.variants) do
            if v.kind == kind then return v.name end
        end
    end
    return ns.data.layout.name
end

local pending = false

local function Switch(silent)
    if not (C_EditMode and C_EditMode.GetLayouts and C_EditMode.SetActiveLayout) then return end
    if not (ns.db and ns.db.installed) then return end
    if InCombatLockdown() then pending = true return end
    local L = Layout()
    local raw, presets, active = L:GetInfo()
    if not raw or not active then return end

    -- Only act when one of our own layouts is active
    local ours = { [ns.data.layout.name] = true }
    for _, name in ipairs(L:VariantNames()) do ours[name] = true end
    if not ours[active.layoutName or ""] then return end

    local want = WantedLayout()
    if want == active.layoutName then return end
    for i, l in ipairs(raw.layouts) do
        if l.layoutName == want then
            local ok, err = pcall(C_EditMode.SetActiveLayout, #presets + i)
            if ok then
                if not silent then ns.Print("Layout:", want) end
                ns.FireState()
            else
                ns.Print("|cffff4444Could not switch layout:|r", err)
            end
            return
        end
    end
    -- the layout hasn't been created yet: stay on the main layout
end

-- Group and spec events come in bursts; wait a moment and do it once
local scheduled = false
local function Schedule()
    if scheduled then return end
    scheduled = true
    C_Timer.After(1, function()
        scheduled = false
        Switch()
    end)
end

for _, event in ipairs({
    "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED",
    "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE",
}) do
    pcall(ns.On, event, Schedule) -- skip events this client doesn't have
end

ns.On("PLAYER_REGEN_ENABLED", function()
    if pending then
        pending = false
        Schedule()
    end
end)

------------------------------------------------------------------------
-- Public API (settings window, minimap menu, /mlz heal)
------------------------------------------------------------------------
local Healer = {}
ns.Healer = Healer

Healer.Role = Role
Healer.IsHealer = IsHealer
Healer.Wanted = WantedLayout

-- "auto" | "on" | "off"
function Healer.Force() return ns.db.healForce or "auto" end

function Healer.SetForce(v)
    ns.db.healForce = (v == "on" or v == "off") and v or nil
    Switch(true)
    ns.FireState()
end

-- Returns ok, message
function Healer.Rebuild()
    local ok, msg = Layout():RebuildVariants()
    if ok then ns.MarkReload("healer layouts rebuilt") end
    return ok, msg
end

function ns.HealerStatus()
    return ("Role: %s   |   Healer: %s   |   Layout now: %s"):format(
        tostring(Role() or "unknown"), IsHealer() and "yes" or "no", WantedLayout())
end

ns.AddCommand("heal","healer layouts: (status) | on | off | auto | build", function(arg)
    arg = strlower(strtrim(arg or ""))
    if arg == "on" or arg == "off" then
        Healer.SetForce(arg)
        ns.Print("Healer layouts: you count as", arg == "on" and "a healer." or "NOT a healer.", "/mlz heal auto goes back to the spec.")
    elseif arg == "auto" then
        Healer.SetForce(nil)
        ns.Print("Healer layouts follow your spec.")
    elseif arg == "build" then
        local ok, msg = Healer.Rebuild()
        ns.Print(ok and "Healer layouts rebuilt:" or "|cffff4444Failed:|r", msg)
    else
        ns.Print("Role:", tostring(Role()), "| healer:", IsHealer() and "yes" or "no",
            "| forced:", ns.db.healForce or "no (auto)", "| wanted layout:", WantedLayout())
        ns.Print("Use /mlz heal on, off, auto or build (rebuilds the healer layouts from the main layout).")
    end
end)
