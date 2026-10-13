-- MLZ UI: Nameplates (Platynator tank/DPS)
-- Switches a few Platynator settings depending on stance: Warrior Defensive Stance / Druid Bear Form = tank,
-- everything else = DPS in a group, SOLO when alone.
-- Platynator has no public profile API, so this goes through its own slash command
-- (/platy config <name> <value>), which only handles simple values (numbers, text, on/off).
-- The threat colors on the enemy health bar are tuned per mode (see ns.data.nameplates.threat).
-- Everything else in your designs stays as you made it.

local _, ns = ...

local DEFENSIVE_FORM = 2 -- Warrior: 1 = Battle, 2 = Defensive, 3 = Berserker

-- Druid: Bear Form (5) and Dire Bear Form (8) = tank; every other form or no form = DPS
local BEAR_FORM_IDS = { [5] = true, [8] = true }

local current -- "tank" | "dps" | "solo" | nil
local ApplyStyle -- defined below

local function PlatynatorReady()
    return C_AddOns.IsAddOnLoaded("Platynator") and SlashCmdList and SlashCmdList.Platynator
end

local function Set(mode, silent)
    if not PlatynatorReady() then
        if not silent then ns.Print("Platynator is not loaded.") end
        return false
    end
    -- Platynator prints a line per setting; mute it while we apply the preset
    local realPrint = print
    print = function() end
    for name, value in pairs(ns.data.nameplates.presets[mode]) do
        pcall(SlashCmdList.Platynator, "config " .. name .. " " .. value)
    end
    print = realPrint
    if current ~= mode and not silent then
        ns.Print("Nameplates:", mode == "tank" and "|cff4da6ffTANK|r" or mode == "solo" and "|cff66dd66SOLO|r" or "|cffffd100DPS|r")
    end
    local changed = current ~= mode
    current = mode
    if changed and ns.db and ns.db.nameplates and (ns.db.nameplates.style or ns.db.nameplates.threat ~= false) then
        ApplyStyle(mode, silent)
    end
    if changed then ns.FireState() end
    return true
end

local function IsTankForm()
    local class = UnitClassBase and UnitClassBase("player")
    if class == "WARRIOR" then return GetShapeshiftForm() == DEFENSIVE_FORM end
    if class == "DRUID" then
        local id = GetShapeshiftFormID and GetShapeshiftFormID()
        return BEAR_FORM_IDS[id] and true or false
    end
    return false
end

local function Auto()
    if not (ns.db and ns.db.nameplates and ns.db.nameplates.auto) then return end
    local mode = IsTankForm() and "tank" or (IsInGroup() and "dps" or "solo")
    if mode ~= current then Set(mode) end
end

-- For the settings window
function ns.NameplateMode() return current end

ns.On("PLAYER_ENTERING_WORLD", function()
    ns.db.nameplates = ns.db.nameplates or { auto = true }
    C_Timer.After(1, Auto)
end)
ns.On("UPDATE_SHAPESHIFT_FORM", Auto)
ns.On("GROUP_ROSTER_UPDATE", Auto)

------------------------------------------------------------------------
-- Design tidy, save/restore and export
-- All writes go through Platynator's own import API (Platynator.API.ImportString),
-- using the same string format as its Export button: PLATY!1! + base64(compress(CBOR)).
------------------------------------------------------------------------
local function Encode(tbl)
    return "PLATY!1!" .. C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(C_EncodingUtil.SerializeCBOR(tbl)))
end

local function CanImport()
    if not (C_AddOns.IsAddOnLoaded("Platynator") and Platynator and Platynator.API and Platynator.API.ImportString
        and C_EncodingUtil and PLATYNATOR_CONFIG and PLATYNATOR_CURRENT_PROFILE) then
        ns.Print("Platynator (or its import API) is not available.")
        return false
    end
    if InCombatLockdown() then
        ns.Print("Not in combat, please.")
        return false
    end
    return true
end

local function CurrentProfile()
    return PLATYNATOR_CONFIG.Profiles[PLATYNATOR_CURRENT_PROFILE]
end

-- Platynator prints a thank-you line on every import; mute it
local function QuietImport(text, name)
    local realPrint = print
    print = function() end
    local ok, err = pcall(Platynator.API.ImportString, text, name)
    print = realPrint
    return ok, err
end

local function Tidy()
    if not CanImport() then return end
    local cfg = ns.data.nameplates
    local design = CurrentProfile().designs and CurrentProfile().designs[cfg.enemyDesign]
    if not design then
        ns.Print("Could not find the design", cfg.enemyDesign, "in the current Platynator profile.")
        return
    end
    design = ns.CopyTable(design)
    design.scale = cfg.tidy.scale
    local changed = 0
    for _, text in ipairs(design.texts or {}) do
        if text.kind == "health" then
            text.displayTypes = ns.CopyTable(cfg.tidy.healthText)
            changed = changed + 1
        end
    end
    design.addon, design.kind = "Platynator", "style"
    local ok, err = QuietImport(Encode(design), cfg.enemyDesign)
    if ok then
        ns.Print(("Tidied %s: scale %s, %d health text(s) set to %s."):format(
            cfg.enemyDesign, cfg.tidy.scale, changed, table.concat(cfg.tidy.healthText, "+")))
    else
        ns.Print("|cffff4444Import failed:|r", err)
    end
end

local function ProfileString()
    local profile = ns.CopyTable(CurrentProfile())
    profile.addon, profile.version, profile.kind = "Platynator", 1, "profile"
    return Encode(profile)
end

------------------------------------------------------------------------
-- Clean style (/mlz np style). Edits a copy of the enemy design and imports it under the same name.
------------------------------------------------------------------------
-- Threat colors per mode: edits the "threat" rule of the enemy health bar in place (never removes it).
local function TuneThreat(design, mode)
    local t = ns.data.nameplates.threat and ns.data.nameplates.threat[mode]
    if not t then return end
    for _, b in ipairs(design.bars or {}) do
        if b.kind == "health" then
            for _, c in ipairs(b.autoColors or {}) do
                if c.kind == "threat" then
                    c.enabled = c.enabled or {}
                    for k, v in pairs(t.enabled) do c.enabled[k] = v end
                    c.tanksOnly = t.tanksOnly
                end
            end
        end
    end
end

local function BuildStyled(design, mode)
    local st = ns.data.nameplates.style
    design = ns.CopyTable(design)
    design.scale = st.scale

    local texts = {}
    for _, t in ipairs(design.texts or {}) do
        if not st.removeTexts[t.kind] then
            if t.kind == "health" then t.displayTypes = ns.CopyTable(st.healthText) end
            texts[#texts + 1] = t
        end
    end
    design.texts = texts

    local bars = {}
    for _, b in ipairs(design.bars or {}) do
        if not st.removeBars[b.kind] then
            if b.kind == "health" and b.autoColors then
                local colors = {}
                for _, c in ipairs(b.autoColors) do
                    if not st.dropColors[c.kind] then colors[#colors + 1] = c end
                end
                b.autoColors = colors
            end
            bars[#bars + 1] = b
        end
    end
    design.bars = bars

    if st.removeSpecialBars then design.specialBars = {} end

    if design.auras then
        local auras = {}
        for _, a in ipairs(design.auras) do
            if a.kind == "debuffs" then
                a.scale, a.limit = st.debuffScale, st.debuffLimit
                auras[#auras + 1] = a
            elseif not st.removeBuffAuras then
                auras[#auras + 1] = a
            end
        end
        design.auras = auras
    end

    TuneThreat(design, mode)

    design.addon, design.kind = "Platynator", "style"
    return design
end

-- Only the threat colors, for people who don't use the clean style
local function BuildThreatOnly(design, mode)
    design = ns.CopyTable(design)
    TuneThreat(design, mode)
    design.addon, design.kind = "Platynator", "style"
    return design
end

local pendingStyle
ApplyStyle = function(mode, silent)
    if InCombatLockdown() then
        pendingStyle = mode -- applied when combat ends
        return false
    end
    if not CanImport() then return false end
    local name = ns.data.nameplates.enemyDesign
    local design = CurrentProfile().designs and CurrentProfile().designs[name]
    if not design then
        if not silent then ns.Print("Could not find the design", name, "in the current Platynator profile.") end
        return false
    end
    -- Keep a way back: save the profile once before the first restyle
    if not ns.db.nameplates.snapshot then ns.db.nameplates.snapshot = ProfileString() end
    local full = ns.db.nameplates.style
    if not full and ns.db.nameplates.threat == false then return false end
    local ok, err = QuietImport(Encode((full and BuildStyled or BuildThreatOnly)(design, mode)), name)
    if not ok then
        ns.Print("|cffff4444Style import failed:|r", err)
        return false
    end
    if not silent then
        ns.Print(full and "Clean nameplate style applied (" or "Threat colors set (", mode .. ").")
    end
    return true
end

ns.On("PLAYER_REGEN_ENABLED", function()
    if pendingStyle then
        local m = pendingStyle
        pendingStyle = nil
        ApplyStyle(m, true)
    end
end)

local function Save()
    if not CanImport() then return end
    ns.db.nameplates.snapshot = ProfileString()
    ns.Print("Saved the current Platynator profile (" .. PLATYNATOR_CURRENT_PROFILE .. ") in MLZ UI.")
end

local function Load()
    if not CanImport() then return end
    local text = ns.db.nameplates.snapshot or ns.data.nameplates.profileString
    if not text then
        ns.Print("Nothing saved yet. Use /mlz np save first.")
        return
    end
    local ok, err = QuietImport(text, PLATYNATOR_CURRENT_PROFILE)
    if ok then
        ns.Print("Restored the saved profile into", PLATYNATOR_CURRENT_PROFILE .. ".")
    else
        ns.Print("|cffff4444Import failed:|r", err)
    end
end

------------------------------------------------------------------------
-- Public API (used by the settings window, the minimap menu and /mlz np). Quiet: no chat output.
------------------------------------------------------------------------
local NP = {}
ns.NP = NP

local function DB()
    ns.db.nameplates = ns.db.nameplates or { auto = true }
    return ns.db.nameplates
end

function NP.Ready() return PlatynatorReady() and true or false end
function NP.Mode() return current end
function NP.Auto() return DB().auto and true or false end
function NP.Style() return DB().style and true or false end
function NP.Threat() return DB().threat ~= false end
function NP.HasSnapshot() return DB().snapshot ~= nil end

function NP.SetAuto(on)
    DB().auto = on and true or false
    if on then
        current = nil
        Auto()
    end
    ns.FireState()
end

function NP.SetMode(mode)
    DB().auto = false
    Set(mode, true)
    ns.FireState()
end

function NP.SetStyle(on)
    DB().style = on and true or false
    if on then ApplyStyle(current or "dps", true) end
    ns.FireState()
end

function NP.SetThreat(on)
    DB().threat = on and true or false
    if on then ApplyStyle(current or "solo", true) end
    ns.FireState()
end

function NP.Save() Save(); ns.FireState() end
function NP.Load() Load() end
function NP.Tidy() Tidy() end
function NP.Export()
    if CanImport() then ns.ShowCopy("MLZ UI: Platynator profile (Ctrl+C to copy)", ProfileString()) end
end

ns.AddCommand("np", "nameplates: tank | dps | solo | auto | off | threat | tidy | style | save | load | export", function(arg)
    arg = strlower(strtrim(arg or ""))
    DB()
    if arg == "style" then
        NP.SetStyle(true)
        ns.Print("Clean style is on and follows tank/DPS/solo.")
    elseif arg == "style off" then
        NP.SetStyle(false)
        ns.Print("Clean style will no longer be applied. Restore your saved profile in the settings (/mlz) if you want the old look back.")
    elseif arg == "tidy" then
        NP.Tidy()
    elseif arg == "save" then
        NP.Save()
    elseif arg == "load" then
        NP.Load()
    elseif arg == "export" then
        NP.Export()
    elseif arg == "threat off" then
        NP.SetThreat(false)
        ns.Print("Threat colors will no longer be changed per mode.")
    elseif arg == "threat" or arg == "threat on" then
        NP.SetThreat(true)
        ns.Print("Threat colors follow the mode (tank / dps / solo).")
    elseif arg == "tank" or arg == "dps" or arg == "solo" then
        NP.SetMode(arg)
        ns.Print("Nameplates:", arg, "(automatic switching is off).")
    elseif arg == "auto" then
        NP.SetAuto(true)
        ns.Print("Nameplates follow your role: Defensive Stance / Bear Form = tank, otherwise DPS in a group and SOLO alone.")
    elseif arg == "off" then
        NP.SetAuto(false)
        ns.Print("Auto stance switching is off.")
    else
        ns.Print("Nameplates:", current or "unknown", "| auto:", ns.db.nameplates.auto and "on" or "off")
        ns.Print("Use /mlz np tank, dps, solo, auto, off, threat, tidy, save, load or export.")
    end
end)

------------------------------------------------------------------------
-- Wizard step: imports the profile string from Data/Nameplates.lua (if one is set)
-- into the current Platynator profile. Without a string the step does nothing.
------------------------------------------------------------------------
local Nameplates = ns.RegisterModule({ key = "nameplates", title = "Nameplates (Platynator)" })

function Nameplates:Preview()
    local text = ns.data.nameplates.profileString
    local items = {}
    local loaded = C_AddOns.IsAddOnLoaded("Platynator")

    local profile = { id = "profile", group = "Platynator", label = "Import MLZ profile" }
    if not loaded then
        profile.old, profile.new, profile.enabled, profile.unavailable = "-", "Platynator not loaded", false, true
    elseif not text then
        profile.old, profile.new, profile.enabled, profile.unavailable = "-", "no profile string saved", false, true
        profile.note = "Run /mlz np export in a game with your setup and paste the string into profileString in Data/Nameplates.lua."
    else
        profile.old, profile.new = "current profile", "MLZ profile"
        profile.value = text
        profile.enabled = ns.Enabled("nameplates", "profile", true)
        profile.note = "Replaces the settings of your current Platynator profile. Undo puts the old profile back."
    end
    items[#items + 1] = profile

    local style = { id = "style", group = "Platynator", label = "Clean nameplate style (tank / DPS / solo)" }
    if not loaded then
        style.old, style.new, style.enabled, style.unavailable = "-", "Platynator not loaded", false, true
    else
        local on = (ns.db.nameplates and ns.db.nameplates.style) and true or false
        style.old, style.new = on and "on" or "off", "on"
        style.toggle, style.isOn, style.offText = true, on, "off"
        style.styleOn = true
        style.enabled = on or ns.Enabled("nameplates", "style", true)
        style.note = "Minimal enemy nameplates: name and percent inside the bar, cast bar, only your debuffs. Follows your role: tank, DPS in a group, solo alone. Undo restores your old profile; /mlz np style off stops it."
    end
    items[#items + 1] = style
    return items
end

function Nameplates:Backup()
    local snap = { style = ns.db.nameplates and ns.db.nameplates.style or false }
    if CanImport() then snap.profile = ProfileString() end
    return snap
end

function Nameplates:Apply(items)
    for _, item in ipairs(items) do
        if item.value and CanImport() then
            local ok, err = QuietImport(item.value, PLATYNATOR_CURRENT_PROFILE)
            if not ok then error("Platynator import failed: " .. tostring(err)) end
        end
    end
    for _, item in ipairs(items) do
        if item.styleOn then
            ns.db.nameplates = ns.db.nameplates or { auto = true }
            ns.db.nameplates.style = item.enabled and true or false -- unticked = stop applying it
            if item.enabled then ApplyStyle(current or "dps") end
        end
    end
end

function Nameplates:Restore(snap)
    ns.db.nameplates = ns.db.nameplates or { auto = true }
    ns.db.nameplates.style = snap.style and true or false
    if snap.profile and CanImport() then
        QuietImport(snap.profile, PLATYNATOR_CURRENT_PROFILE)
    end
end
