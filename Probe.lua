-- MLZ UI: Probe
-- /mlz probe collects info about the client (APIs, CVars, Edit Mode, bindings, nameplates) and stores
-- it in MLZUIDB.probe. After /reload or logout everything is in
-- WTF/Account/<account>/SavedVariables/MLZ_UI.lua, so we can verify instead of guessing.
-- At login only a slim version is stored (build, screen, APIs, frames, CVars), so the saved
-- file stays small. The full dump (Edit Mode, all bindings) is only made by /mlz probe.

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
    "C_ClassTalents.GetActiveConfigID", "GetTalentTabInfo", "GetNumTalentTabs",
    "UnitHasEffectivelyTankAura", "UnitGroupRolesAssigned", "GetShapeshiftFormID",
    "C_Container.GetContainerItemInfo", "C_Container.UseContainerItem", "GetContainerItemInfo",
    "CanMerchantRepair", "GetRepairAllCost", "RepairAllItems", "CanGuildBankRepair",
    "CombatLogGetCurrentEventInfo", "C_AddOns.IsAddOnLoaded",
    "TooltipDataProcessor.AddTooltipPostCall", "GetNumSkillLines", "GetSkillLineInfo", "TradeSkillTypeColor",
    "InCombatLockdown", "C_Timer.After", "ReloadUI",
}

local FRAME_LIST = {
    "MainMenuBar", "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
    "MultiBarLeft", "MultiBar5", "PlayerFrame", "TargetFrame", "FocusFrame", "TargetFrameToT",
    "PartyFrame", "CompactRaidFrameContainer", "CompactPartyFrame", "ObjectiveTrackerFrame",
    "QuestWatchFrame", "MinimapCluster", "Minimap", "BuffFrame", "DebuffFrame", "ChatFrame1",
    "BagsBar", "MicroMenuContainer", "MicroMenu", "PlayerCastingBarFrame", "CastingBarFrame",
    "DamageMeter", "BossTargetFrameContainer", "StatusTrackingBarManager",
    "StanceBar", "StanceButton1", "PetActionBar", "PetActionButton1", "BonusActionButton1",
    "TotemFrame", "PlayerFrameManaBar",
}

local EXTRA_CVARS = {
    "useUiScale", "uiScale", "SpellQueueWindow", "scriptErrors", "lootUnderMouse",
    "interactOnLeftClick", "autoDismountFlying", "autoClearAFK", "Sound_EnableErrorSpeech",
    "softTargetEnemy", "softTargetInteract", "nameplateShowAll", "nameplateMotion",
    "nameplateMaxDistance", "autoQuestWatch", "ffxGlow", "cameraSmoothStyle",
    "showTargetOfTarget", "enableFloatingCombatText", "alwaysShowActionBars",
    "lockActionBars", "countdownForCooldowns", "chatClassColorOverride", "colorChatNamesByClass",
    "useCompactPartyFrames", "raidOptionDisplayPets", "raidFramesHealthText",
}

-- Nameplate facts for our own plates (Modules/Plates.lua). Checked before we rely on any of it.
local PLATE_API = {
    "C_NamePlate", "C_NamePlate.GetNamePlates", "C_NamePlate.GetNamePlateForUnit",
    "C_NamePlate.SetNamePlateFriendlyClickThrough", "C_NamePlate.SetNamePlateEnemyClickThrough",
    "C_NamePlate.SetNamePlateFriendlySize", "C_NamePlate.SetNamePlateEnemySize",
    "C_NamePlate.GetNamePlateEnemySize", "C_NamePlate.SetNamePlateSelfClickThrough",
    "C_NamePlateManager", "NamePlateDriverFrame", "issecure",
    "UnitThreatSituation", "UnitDetailedThreatSituation", "GetThreatStatusColor",
    "UnitCastingInfo", "UnitChannelInfo", "UnitIsTapDenied", "UnitClassification", "UnitReaction",
    "UnitIsQuestBoss", "UnitIsPlayer", "UnitEffectiveLevel", "UnitSelectionColor",
    "GetRaidTargetIndex", "SetRaidTargetIconTexture",
    "C_TooltipInfo", "C_TooltipInfo.GetUnit", "TooltipUtil", "C_UnitAuras", "C_UnitAuras.GetAuraDataByIndex",
    "C_UnitAuras.GetAuraDataByAuraInstanceID", "UnitAura", "UnitDebuff", "AuraUtil.ForEachAura",
    "C_QuestLog", "C_QuestLog.GetNumQuestLogEntries", "C_QuestLog.GetQuestObjectives", "GetNumQuestLogEntries",
    "GetQuestLogTitle", "GetQuestLogLeaderBoard", "C_QuestLog.UnitIsRelatedToActiveQuest",
    "CastingBarFrame_SetUnit", "RAID_CLASS_COLORS", "C_ClassColor",
}

local PLATE_EVENTS = {
    "NAME_PLATE_CREATED", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "FORBIDDEN_NAME_PLATE_CREATED",
    "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_HEALTH", "UNIT_HEALTH_FREQUENT",
    "UNIT_MAXHEALTH", "UNIT_AURA", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "UNIT_CLASSIFICATION_CHANGED",
    "UNIT_FACTION", "RAID_TARGET_UPDATE", "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED", "QUEST_WATCH_UPDATE",
}

local PLATE_CVARS = {
    "nameplateSelectedScale", "nameplateSelectedAlpha", "nameplateMinAlpha", "nameplateMaxAlpha",
    "nameplateOccludedAlphaMult", "nameplateNotSelectedAlpha", "nameplateShowFriends", "nameplateShowEnemies",
    "nameplateShowFriendlyNPCs", "nameplateShowEnemyMinions", "nameplateShowEnemyMinus", "nameplateOtherAtBase",
    "nameplateMinScale", "nameplateMaxScale", "nameplateGlobalScale", "nameplateLargerScale",
    "nameplateOverlapV", "nameplateOverlapH", "nameplateTargetBehindMaxDistance", "nameplateHorizontalScale",
    "nameplateVerticalScale", "nameplateResourceOnTarget", "nameplateShowSelf", "ShowClassColorInNameplate",
    "ShowClassColorInFriendlyNameplate", "nameplateShowDebuffsOnFriendly", "threatWarning", "nameplateShowOnlyNames",
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

local CVarInfo -- defined below

-- Keys on a Blizzard frame table, with their type (frame object type for widgets)
local function Shape(obj)
    if type(obj) ~= "table" then return type(obj) end
    local out = {}
    for k, v in pairs(obj) do
        if type(k) == "string" and k ~= "0" then
            if type(v) == "table" and v.GetObjectType then
                local ok, kind = pcall(v.GetObjectType, v)
                out[k] = ok and kind or "widget"
            elseif type(v) ~= "function" then
                out[k] = type(v) == "table" and "table" or tostring(v)
            end
        end
    end
    return out
end

local function Call(obj, method, ...)
    if type(obj) ~= "table" or type(obj[method]) ~= "function" then return nil end
    local ok, a, b = pcall(obj[method], obj, ...)
    if ok then return a, b end
    return nil
end

local function ProbePlate(plate)
    local entry = {
        name = Call(plate, "GetName"),
        forbidden = Call(plate, "IsForbidden") or false,
        protected = Call(plate, "IsProtected") or false,
        size = { Call(plate, "GetSize") },
        scale = Call(plate, "GetScale"),
        strata = Call(plate, "GetFrameStrata"),
        unit = plate.namePlateUnitToken,
    }
    if entry.forbidden then return entry end
    local uf = plate.UnitFrame
    entry.hasUnitFrame = uf ~= nil
    if uf then
        entry.unitFrame = {
            type = Call(uf, "GetObjectType"),
            protected = Call(uf, "IsProtected") or false,
            shown = Call(uf, "IsShown"),
            alpha = Call(uf, "GetAlpha"),
            unit = uf.unit or uf.displayedUnit,
            keys = Shape(uf),
            numChildren = Call(uf, "GetNumChildren"),
            numRegions = Call(uf, "GetNumRegions"),
        }
        local hb = uf.healthBar or uf.HealthBar
        if hb then entry.unitFrame.healthBar = { size = { Call(hb, "GetSize") }, texture = Call(hb, "GetStatusBarTexture") and true } end
        local cb = uf.castBar or uf.CastBar
        if cb then entry.unitFrame.castBar = Shape(cb) end
    end
    if entry.unit and UnitExists(entry.unit) then
        local u = entry.unit
        entry.unitInfo = {
            name = UnitName(u), level = UnitLevel(u), classification = UnitClassification and UnitClassification(u),
            reaction = UnitReaction and UnitReaction(u, "player"), player = UnitIsPlayer(u),
            threat = UnitThreatSituation and UnitThreatSituation("player", u),
            tapDenied = UnitIsTapDenied and UnitIsTapDenied(u),
            questBoss = UnitIsQuestBoss and UnitIsQuestBoss(u),
        }
        if C_TooltipInfo and C_TooltipInfo.GetUnit then
            local ok, data = pcall(C_TooltipInfo.GetUnit, u)
            if ok and type(data) == "table" and type(data.lines) == "table" then
                entry.tooltipLines = {}
                for i, line in ipairs(data.lines) do
                    entry.tooltipLines[i] = { text = line.leftText, type = line.type }
                end
            end
        end
    end
    return entry
end

local function ProbeNameplates()
    local np = { api = {}, events = {}, cvars = {}, plates = {} }
    for _, name in ipairs(PLATE_API) do np.api[name] = Resolve(name) ~= nil end
    local f = CreateFrame("Frame")
    for _, ev in ipairs(PLATE_EVENTS) do
        np.events[ev] = pcall(f.RegisterEvent, f, ev) and true or false
    end
    f:UnregisterAllEvents()
    for _, name in ipairs(PLATE_CVARS) do np.cvars[name] = CVarInfo(name) end
    if NamePlateDriverFrame then np.driver = Shape(NamePlateDriverFrame) end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local ok, plates = pcall(C_NamePlate.GetNamePlates, issecure and issecure() or false)
        if ok and type(plates) == "table" then
            np.visible = #plates
            for i = 1, math.min(#plates, 4) do np.plates[i] = ProbePlate(plates[i]) end
        end
    end
    if C_NamePlate and C_NamePlate.GetNamePlateEnemySize then
        local ok, w, h = pcall(C_NamePlate.GetNamePlateEnemySize)
        if ok then np.enemySize = { w, h } end
    end
    return np
end

function CVarInfo(name)
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

    local version, build, buildDate, toc
    if GetBuildInfo then version, build, buildDate, toc = GetBuildInfo() end
    p.build = { version = version, build = build, date = buildDate, toc = toc }

    local pw, ph
    if GetPhysicalScreenSize then pw, ph = GetPhysicalScreenSize() end
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

    p.class = select(2, UnitClass("player"))
    if ns.Role then
        local role, source = ns.Role()
        p.role = { role = role, source = source }
        if ns.LiveArchetype then
            local live, why = ns.LiveRole()
            local arch = ns.LiveArchetype()
            p.role.live, p.role.liveWhy, p.role.archetype = live, why, arch
        end
        if ns.ClientInfo then p.client = ns.ClientInfo() end
        -- stance and form facts, to check Defensive Stance / Bear Form detection on this client
        p.form = {
            id = GetShapeshiftFormID and GetShapeshiftFormID() or nil,
            index = GetShapeshiftForm and GetShapeshiftForm() or nil,
            count = GetNumShapeshiftForms and GetNumShapeshiftForms() or nil,
        }
    end

    if silent then
        -- slim version at login; keep the time of the last full probe so it's clear it's gone
        p.full = false
        p.lastFull = ns.db.probe and (ns.db.probe.full and ns.db.probe.time or ns.db.probe.lastFull) or nil
        ns.db.probe = p
        return
    end
    p.full = true

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

    local okNp, np = pcall(ProbeNameplates)
    p.nameplates = okNp and np or { error = tostring(np) }

    ns.db.probe = p

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
    if okNp then
        local missingEv = {}
        for _, ev in ipairs(PLATE_EVENTS) do if not np.events[ev] then missingEv[#missingEv + 1] = ev end end
        ns.Print(("Nameplates: %s visible, missing events: %s"):format(tostring(np.visible or "?"),
            #missingEv > 0 and table.concat(missingEv, ", ") or "none"))
        if (np.visible or 0) == 0 then
            ns.Print("No nameplates were visible. Stand near a few mobs with nameplates on (V) and run it again.")
        end
    end
    ns.Print("Probe saved. Type " .. ns.Cmd("/reload") .. " to write it to SavedVariables/MLZ_UI.lua.")
end

ns.AddCommand("probe", "collects client info for verification (saved in SavedVariables)", function()
    ns.RunProbe()
end)
