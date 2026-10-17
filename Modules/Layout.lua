-- MLZ UI: Edit Mode layout
-- Creates (or updates) a dedicated Edit Mode layout based on Data/Layout.lua.
-- Other layouts are left alone. Undo switches back to the layout that was active before.
--
-- C_EditMode.GetLayouts() only returns saved layouts. The Blizzard UI puts the presets
-- (Modern/Classic) first, so the SetActiveLayout index = number of presets + index among saved.
-- A /reload is recommended after changes so the Edit Mode UI doesn't hold stale data.

local _, ns = ...

local Layout = ns.RegisterModule({ key = "layout", title = "Layout" })

local function Presets()
    if EditModePresetLayoutManager and EditModePresetLayoutManager.GetCopyOfPresetLayouts then
        local ok, presets = pcall(EditModePresetLayoutManager.GetCopyOfPresetLayouts, EditModePresetLayoutManager)
        if ok and type(presets) == "table" then return presets end
    end
    return {}
end

-- Number of preset layouts in front of the saved ones. If the preset manager is missing the enum
-- tells us, and failing that Blizzard has always had two (Modern, Classic).
local function NumPresets(presets)
    if presets and #presets > 0 then return #presets end
    local meta = Enum and Enum.EditModePresetLayoutsMeta
    return (meta and meta.NumValues) or 2
end

local function Available()
    return C_EditMode and C_EditMode.GetLayouts and C_EditMode.SaveLayouts and C_EditMode.SetActiveLayout and Enum and Enum.EditModeSystem
end
Layout.Available = Available

-- Fetches layout info. Returns raw, presets, active layout table, number of presets
function Layout:GetInfo()
    if not (C_EditMode and C_EditMode.GetLayouts) then return nil end
    local ok, raw = pcall(C_EditMode.GetLayouts)
    if not ok or type(raw) ~= "table" then return nil end
    raw.layouts = raw.layouts or {}
    local presets = Presets()
    local n = NumPresets(presets)
    local active
    local a = raw.activeLayout or 1
    if a <= n then active = presets[a] else active = raw.layouts[a - n] end
    return raw, presets, active, n
end

-- SetActiveLayout index of a saved layout by name (presets by name too), or nil
function Layout:IndexOf(name, raw)
    local presets = Presets()
    local n = NumPresets(presets)
    for i, p in ipairs(presets) do
        if p.layoutName == name then return i end
    end
    if not raw then raw = self:GetInfo() end
    if not raw then return nil end
    for i, l in ipairs(raw.layouts) do
        if l.layoutName == name then return n + i end
    end
end

local function FindSystem(layoutInfo, spec)
    local sys = Enum.EditModeSystem[spec.system]
    if sys == nil then return nil, "system " .. spec.system .. " does not exist" end
    local idx
    if spec.indexEnum then
        local e = Enum[spec.indexEnum]
        idx = e and e[spec.index]
        if idx == nil then return nil, spec.indexEnum .. "." .. tostring(spec.index) .. " does not exist" end
    end
    for _, s in ipairs(layoutInfo.systems or {}) do
        if s.system == sys and (idx == nil or s.systemIndex == idx) then return s end
    end
    return nil, "not in the layout"
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
-- Conversion from display value (what Edit Mode shows, e.g. 80 %) to stored value
------------------------------------------------------------------------
local function FindDisplayInfo(sysEnum, setting)
    local mgr = EditModeSettingDisplayInfoManager
    local list = mgr and mgr.systemSettingDisplayInfo and mgr.systemSettingDisplayInfo[sysEnum]
    if type(list) ~= "table" then return nil end
    for _, info in ipairs(list) do
        if info.setting == setting then return info end
    end
end

-- currentRaw = the currently stored value (used to detect the storage format)
function Layout:ToRaw(sysEnum, sysIndex, setting, value, currentRaw)
    -- 1) Ask Blizzard's own system frame to convert, if the method exists
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
    -- 2) Use slider info: stored value = steps from minimum, unless the current value shows it is stored raw
    local info = FindDisplayInfo(sysEnum, setting)
    if info and info.minValue and info.maxValue then
        local v = math.max(info.minValue, math.min(info.maxValue, value))
        local step = (info.stepSize and info.stepSize > 0) and info.stepSize or 1
        local steps = (info.maxValue - info.minValue) / step
        -- Only sliders with ConvertValue are stored as steps; the rest (counts, padding) are stored raw
        if not info.ConvertValue then return v end
        if type(currentRaw) == "number" and currentRaw >= info.minValue and currentRaw <= info.maxValue and currentRaw > steps then
            return v -- stored raw
        end
        return math.floor((v - info.minValue) / step + 0.5)
    end
    -- 3) Toggles and dropdowns are stored raw
    if info then return value end
    -- Unknown: only small integers (on/off, direction) are safe to set raw
    if value == 0 or value == 1 then return value end
    return nil
end

local function SizeText(spec)
    local s = spec.settings
    if not s then return "" end
    local size = s.IconSize or s.Size or s.FrameSize or s.BarSize
    return size and ("  " .. size .. "%") or ""
end

-- "Bar 1, 2, 3" for the bars shown today, from the proxy settings (nil when the client has none)
local function ShownBarsText()
    if not (Settings and Settings.GetValue) then return nil end
    local shown, any = { 1 }, false
    for n = 2, 8 do
        local ok, v = pcall(Settings.GetValue, "PROXY_SHOW_ACTIONBAR_" .. n)
        if ok and v ~= nil then
            any = true
            if v then shown[#shown + 1] = n end
        end
    end
    return any and ("Bar " .. table.concat(shown, ", ")) or nil
end

------------------------------------------------------------------------
-- Module interface
------------------------------------------------------------------------
function Layout:Preview()
    local data = ns.data.layout
    if not Available() then
        return { { id = "na", label = "Edit Mode", old = "-", new = "not available", enabled = false, unavailable = true,
                   note = "This game version has no Edit Mode, so the layout step is skipped." } }
    end
    local raw, _, active = self:GetInfo()
    if not raw or not active then
        return { { id = "na", label = "Edit Mode", old = "-", new = "could not read layouts", enabled = false, unavailable = true } }
    end

    local items = {}
    local exists = FindByName(raw.layouts, data.name)
    -- Already in use: running the wizard again must not overwrite the player's own Edit Mode tweaks by surprise
    local _, ours = self:ActiveName() -- the main layout or one of its role layouts
    local inUse = exists and ours
    local fresh = not inUse
    items[#items + 1] = {
        id = "__layout", label = "Layout \"" .. data.name .. "\"", group = "Setup",
        old = "active: " .. tostring(active.layoutName or "?"),
        new = exists and "will be updated and activated" or "will be created and activated",
        enabled = ns.Enabled("layout", "__layout", fresh),
        note = inUse
            and "You already use this layout. Ticking this replaces your own changes to it with the MLZ UI placement. Other layouts are not changed."
            or "Other layouts (e.g. your own) are not changed. You can switch back in Edit Mode or with /mlz undo.",
    }
    items[#items + 1] = {
        id = "__bars", label = "Show action bars", group = "Setup",
        old = ShownBarsText() or "", new = "Bar " .. table.concat(data.showBars, ", "),
        enabled = ns.Enabled("layout", "__bars", fresh),
    }
    items[#items].alreadySet = items[#items].old == items[#items].new
    if data.healer then
        local names = table.concat(self:VariantNames(), ", ")
        items[#items + 1] = {
            id = "__heal", label = "Role layouts", group = "Setup", requires = "__layout",
            old = "", new = names, enabled = ns.Enabled("layout", "__heal", fresh),
            note = "Three extra layouts. Healing in a dungeon or raid: group frames in the middle of the screen and no swing timers. Casters, hunters and solo healers: only the ranged swing timer. They switch by themselves with your role (see /mlz role).",
        }
    end
    for i, spec in ipairs(data.frames) do
        local sys, err = FindSystem(active, spec)
        local item = {
            id = "frame" .. i, spec = spec, label = spec.label, group = "Placement", requires = "__layout",
            old = sys and AnchorText(sys.anchorInfo) or "-",
            new = spec.keepAnchor and "hidden"
                  or (AnchorText({ point = spec.point, relativeTo = spec.relTo, offsetX = spec.x, offsetY = spec.y }) .. SizeText(spec)),
            enabled = sys ~= nil and ns.Enabled("layout", "frame" .. i, fresh),
        }
        if i == 1 and inUse then
            item.groupNote = "Unticked because you already use this layout, so your own Edit Mode changes stay. Tick a frame to move it back."
        end
        local own = spec.anchorOverride and ns.db.overrides and ns.db.overrides[spec.anchorOverride]
        if own then item.new = AnchorText(own) .. SizeText(spec) .. "  (your saved position)" end
        if not sys then
            item.unavailable = true
            item.new = "skipped"
            item.note = err
        end
        items[#items + 1] = item
    end
    return items
end

-- Clients with the new Settings panel keep "show bar n" as a proxy setting as well
local function BarProxies()
    if not (Settings and Settings.GetValue) then return nil end
    local t = {}
    for n = 2, 8 do
        local ok, v = pcall(Settings.GetValue, "PROXY_SHOW_ACTIONBAR_" .. n)
        if ok and v ~= nil then t[n] = v and true or false end
    end
    return next(t) and t or nil
end

function Layout:Backup()
    local snap = { barToggles = GetActionBarToggles and { GetActionBarToggles() } or nil, barProxies = BarProxies() }
    if not Available() then return snap end
    local raw, _, active = self:GetInfo()
    if not raw then return snap end
    snap.activeLayout = raw.activeLayout
    snap.activeName = active and active.layoutName -- restore by name; indexes shift when layouts are removed
    local _, existing = FindByName(raw.layouts, ns.data.layout.name)
    snap.hadLayout = existing ~= nil
    snap.layoutCopy = existing and ns.CopyTable(existing) or nil
    snap.variants = {}
    for _, name in ipairs(self:VariantNames()) do
        local _, l = FindByName(raw.layouts, name)
        snap.variants[name] = l and ns.CopyTable(l) or false
    end
    return snap
end

local function ShowBars(list)
    local want = {}
    for _, n in ipairs(list) do want[n] = true end
    if SetActionBarToggles and GetActionBarToggles then
        local t = { GetActionBarToggles() }
        local count = select("#", GetActionBarToggles())
        -- order: bottomLeft (2), bottomRight (3), right (4), left (5), then bar 6, 7, 8 on clients that
        -- have them. Older clients return 4 bars + "always show"; that 5th value is passed back unchanged.
        local args = { want[2] or t[1], want[3] or t[2], want[4] or t[3], want[5] or t[4] }
        if count >= 7 then
            args[5], args[6], args[7] = want[6] or t[5], want[7] or t[6], want[8] or t[7]
            for i = 8, count do args[i] = t[i] end
        else
            for i = 5, count do args[i] = t[i] end
        end
        pcall(SetActionBarToggles, unpack(args, 1, math.max(4, count)))
    end
    if Settings and Settings.SetValue then
        for n in pairs(want) do pcall(Settings.SetValue, "PROXY_SHOW_ACTIONBAR_" .. n, true) end
    end
end

-- Writes the given frame specs (anchor + settings) into one layout table. Returns number moved, log.
function Layout:WriteSpecs(target, specs)
    local moved = 0
    local log = {}
    local function SetSetting(sys, spec, name, value, convert)
        local setting = Enum[spec.settingEnum][name]
        if setting == nil then
            log[#log + 1] = spec.label .. " " .. name .. ": unknown setting"
            return
        end
        -- Only change settings the system already has (new fields can make SaveLayouts fail)
        for _, st in ipairs(sys.settings or {}) do
            if st.setting == setting then
                local new = value
                if convert then new = self:ToRaw(sys.system, sys.systemIndex, setting, value, st.value) end
                log[#log + 1] = ("%s %s: %s -> %s (%s)"):format(spec.label, name, tostring(st.value), tostring(new), tostring(value))
                if new ~= nil then st.value = new end
                return
            end
        end
        log[#log + 1] = spec.label .. " " .. name .. ": not present on the system"
    end

    for _, spec in ipairs(specs) do
        local sys = FindSystem(target, spec)
        -- Anchoring to a frame this client (or a missing addon) doesn't have would break the layout
        if sys and not spec.keepAnchor and spec.relTo and spec.relTo ~= "UIParent" and not _G[spec.relTo] then
            log[#log + 1] = spec.label .. ": skipped, anchor frame " .. spec.relTo .. " does not exist"
            sys = nil
        end
        if sys then
            if not spec.keepAnchor then
                local own = spec.anchorOverride and ns.db.overrides and ns.db.overrides[spec.anchorOverride]
                sys.anchorInfo = own and {
                    point = own.point, relativeTo = own.relativeTo, relativePoint = own.relativePoint,
                    offsetX = own.offsetX, offsetY = own.offsetY,
                } or {
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
    return moved, log
end

------------------------------------------------------------------------
-- Healer layouts: extra Edit Mode layouts that are copies of the main layout with a few frames changed
-- (see ns.data.layout.healer). Modules/Healer.lua switches between them.
------------------------------------------------------------------------
local function VariantSpecs(variant)
    local list = {}
    for _, base in ipairs(ns.data.layout.frames) do
        local o = variant.frames[base.label]
        if o then
            local spec = ns.CopyTable(base)
            for k, v in pairs(o) do
                if k == "settings" or k == "rawSettings" then
                    spec[k] = spec[k] or {}
                    for kk, vv in pairs(v) do spec[k][kk] = vv end
                else
                    spec[k] = v
                end
            end
            list[#list + 1] = spec
        end
    end
    return list
end

-- baseLayout = the finished main layout table. Adds or refreshes one layout per variant in raw.layouts.
function Layout:BuildVariants(raw, baseLayout)
    local h = ns.data.layout.healer
    if not h then return 0, 0 end
    local max = Constants and Constants.EditModeConsts and Constants.EditModeConsts.EditModeMaxLayoutsPerType
    local built, skipped = 0, 0
    for _, v in ipairs(h.variants) do
        local copy = ns.CopyTable(baseLayout)
        copy.layoutName = v.name
        copy.isPreset, copy.isModified = nil, nil
        local idx = FindByName(raw.layouts, v.name)
        local room = true
        if idx then
            copy.layoutType = raw.layouts[idx].layoutType
            raw.layouts[idx] = copy
        elseif max and #raw.layouts >= max then
            -- Edit Mode is full: the callers say so (wizard review, Rebuild button)
            ns.Debug("Too many Edit Mode layouts (max " .. max .. "), skipped " .. v.name)
            room = false
        else
            table.insert(raw.layouts, copy)
        end
        if room then
            self:WriteSpecs(copy, VariantSpecs(v))
            built = built + 1
        else
            skipped = skipped + 1
        end
    end
    return built, skipped
end

-- Rebuilds the role layouts from the saved main layout. Returns ok, message.
function Layout:RebuildVariants()
    if not Available() then return false, "Edit Mode API missing" end
    if InCombatLockdown() then return false, "not possible in combat" end
    local raw = self:GetInfo()
    if not raw then return false, "could not read layouts" end
    local _, base = FindByName(raw.layouts, ns.data.layout.name)
    if not base then return false, "The MLZ UI layout does not exist yet (run /mlz install)" end
    local n, skipped = self:BuildVariants(raw, base)
    local ok, err = pcall(C_EditMode.SaveLayouts, raw)
    if not ok then return false, tostring(err) end
    local text = n .. " role layout(s) written"
    if skipped > 0 then
        text = text .. ", " .. skipped .. " skipped because Edit Mode is full. Delete a layout in Edit Mode and try again"
    end
    return true, text
end

function Layout:VariantNames()
    local names = {}
    local h = ns.data.layout.healer
    for _, v in ipairs(h and h.variants or {}) do names[#names + 1] = v.name end
    return names
end

-- Returns nil when everything worked, else a short text for the wizard ("PARTLY")
function Layout:Apply(items)
    local data = ns.data.layout
    local doLayout, doBars, doHeal = false, false, false
    local specs = {}
    for _, item in ipairs(items) do
        if item.id == "__layout" then doLayout = true
        elseif item.id == "__bars" then doBars = true
        elseif item.id == "__heal" then doHeal = true
        elseif item.spec then specs[#specs + 1] = item.spec end
    end

    if doBars then ShowBars(data.showBars) end
    if not doLayout or not Available() then return end

    local raw, _, active, numPresets = self:GetInfo()
    if not raw or not active then return "Edit Mode layouts could not be read" end

    local idx, target = FindByName(raw.layouts, data.name)
    if not target then
        local max = Constants and Constants.EditModeConsts and Constants.EditModeConsts.EditModeMaxLayoutsPerType
        if max and #raw.layouts >= max then
            return "Edit Mode is full (max " .. max .. " layouts). Delete one in Edit Mode and run this step again"
        end
        target = ns.CopyTable(active)
        target.layoutName = data.name
        target.layoutType = Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account or target.layoutType
        target.isPreset, target.isModified = nil, nil
        table.insert(raw.layouts, target)
        idx = #raw.layouts
    end

    local problem
    local moved, log = self:WriteSpecs(target, specs)
    if doHeal then
        local built, skipped = self:BuildVariants(raw, target)
        if skipped > 0 then
            problem = ("%d of %d role layouts did not fit in Edit Mode"):format(skipped, built + skipped)
        end
    end
    ns.db.layoutLog = log -- ends up in SavedVariables, so we can check the conversion after /reload

    raw.activeLayout = numPresets + idx
    local ok, err = pcall(C_EditMode.SaveLayouts, raw)
    if not ok then
        ns.Debug("SaveLayouts failed:", err)
        return "Edit Mode did not save the layout"
    end
    ok, err = pcall(C_EditMode.SetActiveLayout, numPresets + idx)
    if not ok then
        ns.Debug("SetActiveLayout failed:", err)
        problem = "The layout was saved but could not be activated. Pick it in Edit Mode"
    end
    ns.Debug("layout saved, frames moved:", moved)
    ns.MarkEditModeStale()
    -- A healer should land on the healer layout straight away, not on the next group change
    if ns.Healer and ns.Healer.Switch then C_Timer.After(1, function() ns.Healer.Switch(true) end) end
    return problem
end

-- Changes a single setting (in display units, e.g. 120 %) in the MLZ UI layout and saves.
-- Used by /mlz map. Returns ok, error message.
-- The role layouts get the same change, so the minimap does not change size when your layout switches.
function Layout:UpdateOne(id, name, value)
    if not Available() then return false, "Edit Mode API missing" end
    if InCombatLockdown() then return false, "not possible in combat" end
    local spec
    for _, sp in ipairs(ns.data.layout.frames) do if sp.id == id then spec = sp end end
    if not spec then return false, "unknown frame " .. tostring(id) end
    local raw = self:GetInfo()
    if not raw then return false, "could not read layouts" end
    local _, target = FindByName(raw.layouts, ns.data.layout.name)
    if not target then return false, "The MLZ UI layout does not exist yet (run /mlz install)" end
    local setting = Enum[spec.settingEnum] and Enum[spec.settingEnum][name]
    if setting == nil then return false, "unknown setting " .. tostring(name) end

    local function Write(layout)
        local sys, why = FindSystem(layout, spec)
        if not sys then return false, why end
        for _, st in ipairs(sys.settings or {}) do
            if st.setting == setting then
                local new = self:ToRaw(sys.system, sys.systemIndex, setting, value, st.value)
                if new == nil then return false, "could not convert the value" end
                st.value = new
                return true
            end
        end
        return false, name .. " is not present on the system"
    end

    local ok, why = Write(target)
    if not ok then return false, why end
    for _, vname in ipairs(self:VariantNames()) do
        local _, v = FindByName(raw.layouts, vname)
        if v then Write(v) end
    end
    local saved, err = pcall(C_EditMode.SaveLayouts, raw)
    if not saved then return false, tostring(err) end
    -- Edit Mode keeps its own copy until a reload; saving there before that would undo this change
    ns.MarkEditModeStale()
    return true
end

-- Pet bar position: remembers where the pet bar sits in the active Edit Mode layout, so installing
-- the layout again puts it back there. Reset goes back to the position in Data/Layout.lua.
local function PetSpec()
    for _, sp in ipairs(ns.data.layout.frames) do if sp.id == "petbar" then return sp end end
end

Layout.AnchorText = AnchorText

-- Returns the anchor table of the pet bar in the active layout, or nil, reason
function Layout:PetNow()
    if not Available() then return nil, "Edit Mode API not available" end
    local spec = PetSpec()
    if not spec then return nil, "no pet bar in the layout data" end
    local _, _, active = self:GetInfo()
    if not active then return nil, "no active layout" end
    local sys, why = FindSystem(active, spec)
    if not sys then return nil, why end
    if not sys.anchorInfo then return nil, "the pet bar has no position yet" end
    return sys.anchorInfo
end

function Layout:PetSaved() return ns.db.overrides and ns.db.overrides.petBar end

-- Returns ok, text (the saved position, or why it failed)
function Layout:PetSave()
    local a, why = self:PetNow()
    if not a then return false, why end
    ns.db.overrides = ns.db.overrides or {}
    ns.db.overrides.petBar = {
        point = a.point, relativeTo = a.relativeTo or "UIParent", relativePoint = a.relativePoint,
        offsetX = a.offsetX, offsetY = a.offsetY,
    }
    ns.FireState()
    return true, AnchorText(a)
end

function Layout:PetReset()
    if ns.db.overrides then ns.db.overrides.petBar = nil end
    ns.FireState()
end

-- Name of the active Edit Mode layout, and whether it is one of the MLZ layouts
function Layout:ActiveName()
    if not Available() then return nil, false end
    local _, _, active = self:GetInfo()
    local name = active and active.layoutName
    if not name then return nil, false end
    if name == ns.data.layout.name then return name, true end
    for _, v in ipairs(self:VariantNames()) do if v == name then return name, true end end
    return name, false
end

-- True when the MLZ UI layout has been created
function Layout:Exists()
    if not Available() then return false end
    local raw = self:GetInfo()
    if not raw then return false end
    return FindByName(raw.layouts, ns.data.layout.name) ~= nil
end

ns.AddCommand("pet", "pet bar position: save (remember where you put it) | reset | show", function(arg)
    arg = strlower(strtrim(arg or ""))
    if arg == "reset" then
        Layout:PetReset()
        ns.Print("Pet bar goes back to the default position next time the layout is applied.")
    elseif arg == "save" then
        local ok, text = Layout:PetSave()
        ns.Print(ok and "Saved the pet bar position:" or "Could not save the pet bar position:", text)
    elseif arg == "show" then
        local a, why = Layout:PetNow()
        local saved = Layout:PetSaved()
        ns.Print("Pet bar now:", a and AnchorText(a) or ("? (" .. tostring(why) .. ")"),
            "| saved:", saved and AnchorText(saved) or "none")
    else
        ns.Print("Use /mlz pet save (after dragging the bar in Edit Mode and saving), /mlz pet show or /mlz pet reset.")
    end
end)

function Layout:Restore(snap)
    if snap.barToggles and SetActionBarToggles then pcall(SetActionBarToggles, unpack(snap.barToggles)) end
    if snap.barProxies and Settings and Settings.SetValue then
        for n, v in pairs(snap.barProxies) do pcall(Settings.SetValue, "PROXY_SHOW_ACTIONBAR_" .. n, v) end
    end
    if not snap.activeLayout or not Available() then return end
    local raw = self:GetInfo()
    if not raw then return end
    for name, copy in pairs(snap.variants or {}) do
        local vi = FindByName(raw.layouts, name)
        if vi and copy then raw.layouts[vi] = copy
        elseif vi then table.remove(raw.layouts, vi) end
    end
    local idx = FindByName(raw.layouts, ns.data.layout.name)
    if snap.hadLayout and snap.layoutCopy then
        if idx then raw.layouts[idx] = snap.layoutCopy end
    elseif idx then
        table.remove(raw.layouts, idx)
    end
    -- Layouts were removed above, so the old index may point at a different layout now: look it up by name
    local index = (snap.activeName and self:IndexOf(snap.activeName, raw)) or snap.activeLayout
    local n = NumPresets(Presets())
    if index > n + #raw.layouts then index = 1 end
    raw.activeLayout = index
    pcall(C_EditMode.SaveLayouts, raw)
    pcall(C_EditMode.SetActiveLayout, index)
    ns.MarkEditModeStale()
end

------------------------------------------------------------------------
-- Edit Mode guard: after MLZ UI saved a layout, Edit Mode still holds the old copy until a reload.
-- Instead of asking for a reload every time, we only speak up if Edit Mode is opened first.
------------------------------------------------------------------------
local guard

local function ShowGuard()
    local W = ns.W
    if not W then return end
    if not guard then
        local T = W.T
        guard = CreateFrame("Frame", "MLZUI_EditModeGuard", UIParent)
        guard:SetSize(460, 92)
        guard:SetPoint("TOP", 0, -120)
        guard:SetFrameStrata("FULLSCREEN_DIALOG")
        guard:EnableMouse(true)
        W.Fill(guard, T.bg)
        W.Border(guard, T.border)
        local strip = guard:CreateTexture(nil, "ARTWORK")
        strip:SetColorTexture(unpack(T.amber))
        strip:SetPoint("TOPLEFT", 1, -1)
        strip:SetPoint("BOTTOMLEFT", 1, 1)
        strip:SetWidth(3)
        local text = W.Text(guard, "GameFontHighlight",
            "MLZ UI changed your layout since the last reload. Reload first, or saving in Edit Mode may undo that change.")
        text:SetPoint("TOPLEFT", 16, -14)
        text:SetWidth(428)
        local reload = W.Button(guard, "Reload now", 120, 26, function() ReloadUI() end, "primary")
        reload:SetPoint("BOTTOMRIGHT", -12, 12)
        local keep = W.Button(guard, "Keep editing", 120, 26, function() guard:Hide() end, "subtle")
        keep:SetPoint("RIGHT", reload, "LEFT", -8, 0)
    end
    guard:Show()
end

ns.On("PLAYER_LOGIN", function()
    local f = _G.EditModeManagerFrame
    if not (f and f.HookScript) then return end
    f:HookScript("OnShow", function() if ns.editModeStale then ShowGuard() end end)
    f:HookScript("OnHide", function() if guard then guard:Hide() end end)
end)
