-- MLZ UI: Edit Mode-layout
-- Lager (eller oppdaterer) en egen Edit Mode-layout ut fra Data/Layout.lua.
-- Andre layouts røres ikke. Angre bytter tilbake til layouten som var aktiv før.
--
-- C_EditMode.GetLayouts() returnerer bare lagrede layouts. Blizzard-UI-et legger presets
-- (Modern/Classic) foran, så indeksen til SetActiveLayout = antall presets + indeks i lagrede.
-- Etter endring anbefales /reload, så Edit Mode-UI-et ikke sitter med gammel data.

local _, ns = ...

local Layout = ns.RegisterModule({ key = "layout", title = "Layout" })

local function Presets()
    if EditModePresetLayoutManager and EditModePresetLayoutManager.GetCopyOfPresetLayouts then
        local ok, presets = pcall(EditModePresetLayoutManager.GetCopyOfPresetLayouts, EditModePresetLayoutManager)
        if ok and type(presets) == "table" then return presets end
    end
    return {}
end

local function Available()
    return C_EditMode and C_EditMode.GetLayouts and C_EditMode.SaveLayouts and C_EditMode.SetActiveLayout and Enum and Enum.EditModeSystem
end

-- Henter layout-info. Returnerer raw, presets, aktiv layout-tabell
function Layout:GetInfo()
    local ok, raw = pcall(C_EditMode.GetLayouts)
    if not ok or type(raw) ~= "table" then return nil end
    raw.layouts = raw.layouts or {}
    local presets = Presets()
    local active
    local a = raw.activeLayout or 1
    if a <= #presets then active = presets[a] else active = raw.layouts[a - #presets] end
    return raw, presets, active
end

local function FindSystem(layoutInfo, spec)
    local sys = Enum.EditModeSystem[spec.system]
    if sys == nil then return nil, "systemet " .. spec.system .. " finnes ikke" end
    local idx
    if spec.indexEnum then
        local e = Enum[spec.indexEnum]
        idx = e and e[spec.index]
        if idx == nil then return nil, spec.indexEnum .. "." .. tostring(spec.index) .. " finnes ikke" end
    end
    for _, s in ipairs(layoutInfo.systems or {}) do
        if s.system == sys and (idx == nil or s.systemIndex == idx) then return s end
    end
    return nil, "ikke i layouten"
end

local function AnchorText(a)
    if not a then return "?" end
    local rel = a.relativeTo and a.relativeTo ~= "UIParent" and (" (" .. a.relativeTo .. ")") or ""
    return ("%s %+d,%+d%s"):format(a.point or "?", math.floor((a.offsetX or 0) + 0.5), math.floor((a.offsetY or 0) + 0.5), rel)
end

local function FindByName(layouts, name)
    for i, l in ipairs(layouts) do
        if l.layoutName == name then return i, l end
    end
end

------------------------------------------------------------------------
-- Konvertering fra visningsverdi (det Edit Mode viser, f.eks. 80 %) til lagret verdi
------------------------------------------------------------------------
local function FindDisplayInfo(sysEnum, setting)
    local mgr = EditModeSettingDisplayInfoManager
    local list = mgr and mgr.systemSettingDisplayInfo and mgr.systemSettingDisplayInfo[sysEnum]
    if type(list) ~= "table" then return nil end
    for _, info in ipairs(list) do
        if info.setting == setting then return info end
    end
end

-- currentRaw = verdien som ligger lagret i dag (brukes til å gjenkjenne lagringsformatet)
function Layout:ToRaw(sysEnum, sysIndex, setting, value, currentRaw)
    -- 1) Spør Blizzards egen system-frame om konvertering hvis metoden finnes
    local mgr = EditModeManagerFrame
    if mgr and type(mgr.registeredSystemFrames) == "table" then
        for _, frame in ipairs(mgr.registeredSystemFrames) do
            if frame.system == sysEnum and (sysIndex == nil or frame.systemIndex == sysIndex)
               and type(frame.ConvertSettingDisplayValueToRawValue) == "function" then
                local ok, raw = pcall(frame.ConvertSettingDisplayValueToRawValue, frame, setting, value)
                if ok and type(raw) == "number" then return raw end
            end
        end
    end
    -- 2) Bruk slider-info: lagret verdi = steg fra minimum, med mindre dagens verdi viser at den lagres rått
    local info = FindDisplayInfo(sysEnum, setting)
    if info and info.minValue and info.maxValue then
        local v = math.max(info.minValue, math.min(info.maxValue, value))
        local step = (info.stepSize and info.stepSize > 0) and info.stepSize or 1
        local steps = (info.maxValue - info.minValue) / step
        -- Bare slidere med ConvertValue lagres som steg; resten (antall, padding) lagres rått
        if not info.ConvertValue then return v end
        if type(currentRaw) == "number" and currentRaw >= info.minValue and currentRaw <= info.maxValue and currentRaw > steps then
            return v -- lagres rått
        end
        return math.floor((v - info.minValue) / step + 0.5)
    end
    -- 3) Av/på og nedtrekk lagres rått
    if info then return value end
    -- Ukjent: bare små heltall (av/på, retning) er trygge å sette rått
    if value == 0 or value == 1 then return value end
    return nil
end

local function SizeText(spec)
    local s = spec.settings
    if not s then return "" end
    local size = s.IconSize or s.Size or s.FrameSize or s.BarSize
    return size and ("  " .. size .. "%") or ""
end

------------------------------------------------------------------------
-- Modulgrensesnitt
------------------------------------------------------------------------
function Layout:Preview()
    local data = ns.data.layout
    if not Available() then
        return { { id = "na", label = "Edit Mode", old = "-", new = "ikke tilgjengelig", enabled = false, unavailable = true,
                   note = "Fant ikke C_EditMode i denne klienten. Kjør /mlz probe og send resultatet." } }
    end
    local raw, _, active = self:GetInfo()
    if not raw or not active then
        return { { id = "na", label = "Edit Mode", old = "-", new = "kunne ikke lese layouts", enabled = false, unavailable = true } }
    end

    local items = {}
    local exists = FindByName(raw.layouts, data.name)
    items[#items + 1] = {
        id = "__layout", label = "Layout \"" .. data.name .. "\"", group = "Oppsett",
        old = "aktiv: " .. tostring(active.layoutName or "?"),
        new = exists and "oppdateres og aktiveres" or "opprettes og aktiveres",
        enabled = true,
        note = "Andre layouts (f.eks. dine egne) blir ikke endret. Du kan bytte tilbake i Edit Mode eller med /mlz undo.",
    }
    items[#items + 1] = {
        id = "__bars", label = "Vis action bars", group = "Oppsett",
        old = "", new = "Bar " .. table.concat(data.showBars, ", "), enabled = true,
    }
    for i, spec in ipairs(data.frames) do
        local sys, err = FindSystem(active, spec)
        local item = {
            id = "frame" .. i, spec = spec, label = spec.label, group = "Plassering",
            old = sys and AnchorText(sys.anchorInfo) or "-",
            new = spec.keepAnchor and "skjules"
                  or (AnchorText({ point = spec.point, relativeTo = spec.relTo, offsetX = spec.x, offsetY = spec.y }) .. SizeText(spec)),
            enabled = sys ~= nil and ns.Enabled("layout", "frame" .. i, true),
        }
        if not sys then
            item.unavailable = true
            item.new = "hoppes over"
            item.note = err
        end
        items[#items + 1] = item
    end
    return items
end

function Layout:Backup()
    local snap = { barToggles = GetActionBarToggles and { GetActionBarToggles() } or nil }
    if not Available() then return snap end
    local raw = self:GetInfo()
    if not raw then return snap end
    snap.activeLayout = raw.activeLayout
    local _, existing = FindByName(raw.layouts, ns.data.layout.name)
    snap.hadLayout = existing ~= nil
    snap.layoutCopy = existing and ns.CopyTable(existing) or nil
    return snap
end

local function ShowBars(list)
    local want = {}
    for _, n in ipairs(list) do want[n] = true end
    if SetActionBarToggles and GetActionBarToggles then
        local t = { GetActionBarToggles() }
        -- rekkefølge: bottomLeft (2), bottomRight (3), right (4), left (5), bar 6, 7, 8
        pcall(SetActionBarToggles, want[2] or t[1], want[3] or t[2], want[4] or t[3], want[5] or t[4],
            want[6] or t[5], want[7] or t[6], want[8] or t[7])
    end
    if Settings and Settings.SetValue then
        for n in pairs(want) do pcall(Settings.SetValue, "PROXY_SHOW_ACTIONBAR_" .. n, true) end
    end
end

function Layout:Apply(items)
    local data = ns.data.layout
    local doLayout, doBars = false, false
    local specs = {}
    for _, item in ipairs(items) do
        if item.id == "__layout" then doLayout = true
        elseif item.id == "__bars" then doBars = true
        elseif item.spec then specs[#specs + 1] = item.spec end
    end

    if doBars then ShowBars(data.showBars) end
    if not doLayout or not Available() then return end

    local raw, presets, active = self:GetInfo()
    if not raw or not active then ns.Print("|cffff4444Kunne ikke lese Edit Mode-layouts.|r") return end

    local idx, target = FindByName(raw.layouts, data.name)
    if not target then
        local max = Constants and Constants.EditModeConsts and Constants.EditModeConsts.EditModeMaxLayoutsPerType
        if max and #raw.layouts >= max then
            ns.Print("|cffff4444For mange Edit Mode-layouts (maks " .. max .. "). Slett en i Edit Mode og prøv igjen.|r")
            return
        end
        target = ns.CopyTable(active)
        target.layoutName = data.name
        target.layoutType = Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account or target.layoutType
        target.isPreset, target.isModified = nil, nil
        table.insert(raw.layouts, target)
        idx = #raw.layouts
    end

    local moved = 0
    local log = {}
    local function SetSetting(sys, spec, name, value, convert)
        local setting = Enum[spec.settingEnum][name]
        if setting == nil then
            log[#log + 1] = spec.label .. " " .. name .. ": ukjent setting"
            return
        end
        -- Bare settings systemet allerede har endres (nye felt kan få SaveLayouts til å feile)
        for _, st in ipairs(sys.settings or {}) do
            if st.setting == setting then
                local new = value
                if convert then new = self:ToRaw(sys.system, sys.systemIndex, setting, value, st.value) end
                log[#log + 1] = ("%s %s: %s -> %s (%s)"):format(spec.label, name, tostring(st.value), tostring(new), tostring(value))
                if new ~= nil then st.value = new end
                return
            end
        end
        log[#log + 1] = spec.label .. " " .. name .. ": finnes ikke på systemet"
    end

    for _, spec in ipairs(specs) do
        local sys = FindSystem(target, spec)
        if sys then
            if not spec.keepAnchor then
                sys.anchorInfo = {
                    point = spec.point, relativeTo = spec.relTo or "UIParent", relativePoint = spec.relPoint,
                    offsetX = spec.x, offsetY = spec.y,
                }
                sys.anchorInfo2 = nil
                sys.isInDefaultPosition = false
            end
            if spec.settingEnum and Enum[spec.settingEnum] then
                local ov = ns.db.overrides or {}
                for name, value in pairs(spec.settings or {}) do
                    local key = spec.override and spec.override[name]
                    if key and ov[key] ~= nil then value = ov[key] end
                    SetSetting(sys, spec, name, value, true)
                end
                for name, value in pairs(spec.rawSettings or {}) do SetSetting(sys, spec, name, value, false) end
            end
            moved = moved + 1
        end
    end
    ns.db.layoutLog = log -- havner i SavedVariables, så vi kan sjekke konverteringen etter /reload

    raw.activeLayout = #presets + idx
    local ok, err = pcall(C_EditMode.SaveLayouts, raw)
    if not ok then ns.Print("|cffff4444SaveLayouts feilet:|r", err) return end
    ok, err = pcall(C_EditMode.SetActiveLayout, #presets + idx)
    if not ok then ns.Print("|cffff4444SetActiveLayout feilet:|r", err) end
    ns.Debug("layout lagret, frames flyttet:", moved)
    ns.needsReload = true
end

-- Endrer én setting (i visningsenheter, f.eks. 120 %) i MLZ UI-layouten og lagrer.
-- Brukes av /mlz map. Returnerer ok, feilmelding.
function Layout:UpdateOne(id, name, value)
    if not Available() then return false, "Edit Mode-API mangler" end
    local spec
    for _, sp in ipairs(ns.data.layout.frames) do if sp.id == id then spec = sp end end
    if not spec then return false, "ukjent frame " .. tostring(id) end
    local raw = self:GetInfo()
    if not raw then return false, "kunne ikke lese layouts" end
    local _, target = FindByName(raw.layouts, ns.data.layout.name)
    if not target then return false, "MLZ UI-layouten finnes ikke ennå (kjør /mlz install)" end
    local sys, why = FindSystem(target, spec)
    if not sys then return false, why end
    local setting = Enum[spec.settingEnum] and Enum[spec.settingEnum][name]
    for _, st in ipairs(sys.settings or {}) do
        if st.setting == setting then
            local new = self:ToRaw(sys.system, sys.systemIndex, setting, value, st.value)
            if new == nil then return false, "kunne ikke konvertere verdien" end
            st.value = new
            return pcall(C_EditMode.SaveLayouts, raw)
        end
    end
    return false, name .. " finnes ikke på systemet"
end

function Layout:Restore(snap)
    if snap.barToggles and SetActionBarToggles then pcall(SetActionBarToggles, unpack(snap.barToggles)) end
    if not snap.activeLayout or not Available() then return end
    local raw = self:GetInfo()
    if not raw then return end
    local idx = FindByName(raw.layouts, ns.data.layout.name)
    if snap.hadLayout and snap.layoutCopy then
        if idx then raw.layouts[idx] = snap.layoutCopy end
    elseif idx then
        table.remove(raw.layouts, idx)
    end
    raw.activeLayout = snap.activeLayout
    pcall(C_EditMode.SaveLayouts, raw)
    pcall(C_EditMode.SetActiveLayout, snap.activeLayout)
    ns.needsReload = true
end
