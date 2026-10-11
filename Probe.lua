-- MLZ UI: Probe
-- /mlz probe collects info about the client (APIs, CVars, Edit Mode, bindings) and stores
-- it in MLZUIDB.probe. After /reload or logout everything is in
-- WTF/Account/<account>/SavedVariables/MLZ_UI.lua, so we can verify instead of guessing.

local _, ns = ...

local function Resolve(path)
    local obj = _G
    for part in path:gmatch("[^%.]+") do
        if type(obj) ~= "table" then return nil end
        obj = obj[part]
    end
    return obj
end

local API_LIST = {
    "GetPhysicalScreenSize", "GetScreenWidth", "GetScreenHeight", "GetBuildInfo",
    "C_CVar.GetCVarInfo", "C_CVar.GetCVar", "C_CVar.SetCVar", "C_CVar.GetCVarDefault", "SetCVar", "GetCVar",
    "SetBinding", "SaveBindings", "LoadBindings", "GetCurrentBindingSet", "GetBindingKey", "GetBindingAction",
    "GetNumBindings", "GetBinding",
    "C_EditMode.GetLayouts", "C_EditMode.SaveLayouts", "C_EditMode.SetActiveLayout",
    "C_EditMode.ConvertLayoutInfoToString", "C_EditMode.ConvertStringToLayoutInfo",
    "EditModeManagerFrame", "EditModePresetLayoutManager",
    "SetActionBarToggles", "GetActionBarToggles", "Settings.GetValue", "Settings.SetValue",
    "GetActionInfo", "PlaceAction", "PickupAction", "PickupSpell", "C_Spell.PickupSpell", "PickupItem",
    "PickupMacro", "C_Item.PickupItem", "ClearCursor",
    "GetSpecialization", "C_SpecializationInfo.GetSpecialization", "GetActiveTalentGroup",
    "C_ClassTalents.GetActiveConfigID",
    "InCombatLockdown", "C_Timer.After", "ReloadUI",
}

local FRAME_LIST = {
    "MainMenuBar", "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
    "MultiBarLeft", "MultiBar5", "PlayerFrame", "TargetFrame", "FocusFrame", "TargetFrameToT",
    "PartyFrame", "CompactRaidFrameContainer", "CompactPartyFrame", "ObjectiveTrackerFrame",
    "QuestWatchFrame", "MinimapCluster", "Minimap", "BuffFrame", "DebuffFrame", "ChatFrame1",
    "BagsBar", "MicroMenuContainer", "MicroMenu", "PlayerCastingBarFrame", "CastingBarFrame",
    "DamageMeter", "BossTargetFrameContainer", "StatusTrackingBarManager",
}

local EXTRA_CVARS = {
    "useUiScale", "uiScale", "SpellQueueWindow", "scriptErrors", "lootUnderMouse",
    "interactOnLeftClick", "autoDismountFlying", "autoClearAFK", "Sound_EnableErrorSpeech",
    "softTargetEnemy", "softTargetInteract", "nameplateShowAll", "nameplateMotion",
    "nameplateMaxDistance", "autoQuestWatch", "ffxGlow", "cameraSmoothStyle",
    "showTargetOfTarget", "enableFloatingCombatText", "alwaysShowActionBars",
    "lockActionBars", "countdownForCooldowns", "chatClassColorOverride", "colorChatNamesByClass",
}

local function SafeCopy(v, depth)
    depth = depth or 0
    if depth > 8 then return "<too deep>" end
    local t = type(v)
    if t == "table" then
        local out = {}
        for k, val in pairs(v) do
            if type(k) == "string" or type(k) == "number" then out[k] = SafeCopy(val, depth + 1) end
        end
        return out
    elseif t == "function" or t == "userdata" or t == "thread" then
        return "<" .. t .. ">"
    end
    return v
end

local function CVarInfo(name)
    local entry = { exists = false }
    if C_CVar and C_CVar.GetCVarInfo then
        local ok, value, default, acc, char, locked, secure, readOnly = pcall(C_CVar.GetCVarInfo, name)
        if ok and value ~= nil then
            entry = { exists = true, value = value, default = default, account = acc, character = char,
                      locked = locked, secure = secure, readOnly = readOnly }
        end
    elseif GetCVar then
        local ok, value = pcall(GetCVar, name)
        if ok and value ~= nil then entry = { exists = true, value = value } end
    end
    return entry
end

function ns.RunProbe(silent)
    local p = { time = date("%Y-%m-%d %H:%M:%S") }

    local version, build, buildDate, toc = GetBuildInfo()
    p.build = { version = version, build = build, date = buildDate, toc = toc }

    local pw, ph = GetPhysicalScreenSize()
    p.screen = {
        physical = { pw, ph },
        uiParent = { UIParent:GetWidth(), UIParent:GetHeight() },
        uiParentScale = UIParent:GetScale(),
        uiParentEffectiveScale = UIParent:GetEffectiveScale(),
        screen = { GetScreenWidth(), GetScreenHeight() },
    }

    p.api = {}
    for _, name in ipairs(API_LIST) do p.api[name] = Resolve(name) ~= nil end

    p.frames = {}
    for _, name in ipairs(FRAME_LIST) do p.frames[name] = _G[name] ~= nil end

    p.cvars = {}
    for _, row in ipairs(ns.data.cvars or {}) do p.cvars[row.name] = CVarInfo(row.name) end
    for _, name in ipairs(EXTRA_CVARS) do p.cvars[name] = CVarInfo(name) end

    -- All Enum tables related to Edit Mode
    p.enums = {}
    if Enum then
        for k, v in pairs(Enum) do
            if type(k) == "string" and k:find("^EditMode") then p.enums[k] = SafeCopy(v) end
        end
    end
    if Constants and Constants.EditModeConsts then p.enums.EditModeConsts = SafeCopy(Constants.EditModeConsts) end

    -- Edit Mode layouts (raw from C_EditMode, plus the list the Blizzard UI sees incl. presets)
    p.editMode = {}
    if C_EditMode and C_EditMode.GetLayouts then
        local ok, info = pcall(C_EditMode.GetLayouts)
        if ok then p.editMode.raw = SafeCopy(info) end
    end
    if EditModeManagerFrame and EditModeManagerFrame.GetLayouts then
        local ok, layouts = pcall(EditModeManagerFrame.GetLayouts, EditModeManagerFrame)
        if ok and type(layouts) == "table" then
            p.editMode.managerNames = {}
            for i, l in ipairs(layouts) do p.editMode.managerNames[i] = (l.layoutName or "?") .. " (type " .. tostring(l.layoutType) .. ")" end
        end
    end
    if EditModePresetLayoutManager and EditModePresetLayoutManager.GetCopyOfPresetLayouts then
        local ok, presets = pcall(EditModePresetLayoutManager.GetCopyOfPresetLayouts, EditModePresetLayoutManager)
        if ok and type(presets) == "table" then
            p.editMode.presetCount = #presets
            p.editMode.presetFirst = SafeCopy(presets[1])
        end
    end

    -- All bindings
    p.bindings = { set = GetCurrentBindingSet and GetCurrentBindingSet() or nil, list = {} }
    if GetNumBindings and GetBinding then
        for i = 1, GetNumBindings() do
            local command, category, key1, key2 = GetBinding(i)
            if command and (key1 or key2) then
                p.bindings.list[#p.bindings.list + 1] = { command, key1, key2, category }
            end
        end
    end

    -- Action bar visibility
    if GetActionBarToggles then
        p.actionBarToggles = { GetActionBarToggles() }
    end
    if Settings and Settings.GetValue then
        p.actionBarSettings = {}
        for i = 2, 8 do
            local ok, val = pcall(Settings.GetValue, "PROXY_SHOW_ACTIONBAR_" .. i)
            if ok then p.actionBarSettings[i] = val end
        end
    end

    -- Edit Mode slider info (min/max/step) per system, to verify size conversion
    local mgr = EditModeSettingDisplayInfoManager
    if mgr and type(mgr.systemSettingDisplayInfo) == "table" then
        p.editMode.displayInfo = SafeCopy(mgr.systemSettingDisplayInfo)
    end
    if EditModeManagerFrame and type(EditModeManagerFrame.registeredSystemFrames) == "table" then
        local f = EditModeManagerFrame.registeredSystemFrames[1]
        p.editMode.hasConvertMethod = f and type(f.ConvertSettingDisplayValueToRawValue) == "function" or false
        p.editMode.systemFrames = {}
        for i, sf in ipairs(EditModeManagerFrame.registeredSystemFrames) do
            p.editMode.systemFrames[i] = (sf.GetName and sf:GetName() or "?") .. " sys=" .. tostring(sf.system) .. " idx=" .. tostring(sf.systemIndex)
        end
    end

    ns.db.probe = p
    if silent then return end

    -- Short summary in chat
    ns.Print(("Build %s (%s), toc %s. Screen %dx%d, UIParent %.0fx%.0f, scale %.3f"):format(
        tostring(version), tostring(build), tostring(toc), pw or 0, ph or 0,
        UIParent:GetWidth(), UIParent:GetHeight(), UIParent:GetEffectiveScale()))
    local missing = {}
    for _, name in ipairs(API_LIST) do if not p.api[name] then missing[#missing + 1] = name end end
    ns.Print("Missing APIs:", #missing > 0 and table.concat(missing, ", ") or "none")
    local layouts = p.editMode.raw and p.editMode.raw.layouts
    ns.Print("Edit Mode: saved layouts =", layouts and #layouts or "?",
        ", active =", p.editMode.raw and p.editMode.raw.activeLayout or "?",
        ", presets =", p.editMode.presetCount or "?")
    ns.Print("Probe saved. Type |cffffff00/reload|r to write it to SavedVariables/MLZ_UI.lua.")
end

ns.AddCommand("probe", "collects client info for verification (saved in SavedVariables)", function()
    ns.RunProbe()
end)
