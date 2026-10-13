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

-- Returns "HEALER" | "TANK" | "DAMAGER" | nil (shared role detection, Core.lua)
local function Role()
    return (ns.Role())
end

local function IsHealer()
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
    -- Never swap layouts under the user's hands while Edit Mode is open
    if EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive
        and EditModeManagerFrame:IsEditModeActive() then
        pending = true
        return
    end
    local L = Layout()
    local raw, _, active = L:GetInfo()
    if not raw or not active then return end

    -- Only act when one of our own layouts is active
    local ours = { [ns.data.layout.name] = true }
    for _, name in ipairs(L:VariantNames()) do ours[name] = true end
    if not ours[active.layoutName or ""] then return end

    local want = WantedLayout()
    if want == active.layoutName then return end
    local index = L:IndexOf(want)
    if not index then return end -- the layout hasn't been created yet: stay on the main layout
    local ok, err = pcall(C_EditMode.SetActiveLayout, index)
    if ok then
        if not silent then ns.Print("Layout:", want) end
        ns.FireState()
    else
        ns.Print("|cffff4444Could not switch layout:|r", err)
    end
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

-- Role changes (spec, talents, forced role) come from Core; group size changes from the roster
ns.OnRoleChanged(function(_, _, roleChanged)
    if roleChanged then Schedule() end
end)
ns.TryOn("GROUP_ROSTER_UPDATE", Schedule)
ns.TryOn("PLAYER_ENTERING_WORLD", Schedule)

ns.On("PLAYER_REGEN_ENABLED", function()
    if pending then
        pending = false
        Schedule()
    end
end)

-- Leaving Edit Mode: do a switch that was held back while it was open
if EventRegistry and EventRegistry.RegisterCallback then
    pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Exit", function()
        if pending then
            pending = false
            Schedule()
        end
    end, "MLZUI_Healer")
end

------------------------------------------------------------------------
-- Public API (settings window, minimap menu, /mlz heal)
------------------------------------------------------------------------
local Healer = {}
ns.Healer = Healer

Healer.Role = Role
Healer.IsHealer = IsHealer
Healer.Wanted = WantedLayout
Healer.Switch = Switch

-- Kept for older callers: "auto" | "on" | "off", mapped onto the shared role choice
function Healer.Force()
    local f = ns.GetRoleForce()
    if f == "HEALER" then return "on" end
    if f then return "off" end
    return "auto"
end

function Healer.SetForce(v)
    if v == "on" then ns.SetRoleForce("HEALER")
    elseif v == "off" then ns.SetRoleForce("DAMAGER")
    else ns.SetRoleForce(nil) end
    Switch(true)
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
        local role, source = ns.Role()
        ns.Print("Role:", tostring(role), "(" .. tostring(source) .. ") | healer:", IsHealer() and "yes" or "no",
            "| wanted layout:", WantedLayout())
        ns.Print("Use /mlz heal on, off, auto or build (rebuilds the healer layouts from the main layout).")
    end
end)

local ROLE_ARG = { tank = "TANK", healer = "HEALER", heal = "HEALER", dps = "DAMAGER", damage = "DAMAGER" }
ns.AddCommand("role", "your role: (status) | tank | healer | dps | auto", function(arg)
    arg = strlower(strtrim(arg or ""))
    if ROLE_ARG[arg] then
        ns.SetRoleForce(ROLE_ARG[arg])
        ns.Print("Your role is set to", ns.ROLE_TEXT[ROLE_ARG[arg]] .. ". /mlz role auto reads it from your talents again.")
    elseif arg == "auto" then
        ns.SetRoleForce(nil)
        local role = ns.Role()
        ns.Print("Your role is read automatically:", ns.ROLE_TEXT[role or ""] or "unknown", ".")
    else
        local role, source = ns.Role()
        local live, why = ns.LiveRole()
        ns.Print("Role:", ns.ROLE_TEXT[role or ""] or "unknown", "(" .. tostring(source) .. "), right now:",
            ns.ROLE_TEXT[live or ""] or "unknown", "(" .. tostring(why) .. ")")
        ns.Print("Use /mlz role tank, healer, dps or auto.")
    end
end)
