-- MLZ UI: Nameplates
-- Four modes (tank / healer / DPS / solo) that follow your role, optional threat colors and an
-- optional PvP tweak. See Data/Nameplates.lua for the values. Two engines draw the plates:
--   mlz         our own nameplates (Modules/Plates.lua), the default
--   platynator  Platynator, driven through its profile import (the rest of this file)
--   off         Blizzard's plates, MLZ UI doesn't touch nameplates
--
-- How changes reach Platynator: MLZ builds a copy of your current Platynator profile with the
-- changes in it and imports that copy into the same profile through Platynator.API.ImportString.
-- Platynator then compares old and new and refreshes every nameplate at once, so nothing needs a
-- /reload. (Importing only a design does NOT refresh the plates until /reload.)
-- In combat only the simple numbers (alpha, target scale) are switched, through /platy config;
-- the rest follows when combat ends.
--
-- Everything the clean style removes is remembered (MLZUIDB.nameplates.stash), so turning the
-- style off puts it back. Settings a mode changes are remembered too (MLZUIDB.nameplates.base),
-- so a mode that doesn't use a setting gives you back your own value.
-- Automatic switching never prints anything; problems are shown in the settings window.

local _, ns = ...

local NP = {}
ns.NP = NP

local function D() return ns.data.nameplates end
NP.MODES = ns.data.nameplates.modes
NP.MODE_TEXT = ns.data.nameplates.modeText

local current        -- mode that is on the plates right now
local currentReason  -- why (for the settings window)
local lastError      -- last problem, shown in the settings window
local pending        -- something to apply when combat ends

local function DB()
    ns.db.nameplates = ns.db.nameplates or { auto = true }
    return ns.db.nameplates
end

local ENGINES = { mlz = true, platynator = true, off = true }
NP.ENGINE_TEXT = { mlz = "MLZ", platynator = "Platynator", off = "Blizzard" }

local function Engine()
    local e = DB().engine
    return ENGINES[e] and e or "off"
end

local SHOW_DEFAULTS = {
    healthText = true, castBar = true, quest = true, debuffs = true, level = true, execute = true, cc = true,
}
NP.SHOW_KEYS = SHOW_DEFAULTS -- read only: Profile.lua validates imported show options against it

local function Show()
    local db = DB()
    local saved = db.show or {} -- read only: undo compares the saved table with what it was
    local out = {}
    for k, v in pairs(SHOW_DEFAULTS) do
        if saved[k] == nil then out[k] = v else out[k] = saved[k] and true or false end
    end
    return out
end

local function PlatyReady()
    if not ns.IsAddOnLoaded("Platynator") then return false end
    if not (Platynator and Platynator.API and Platynator.API.ImportString) then return false end
    local enc = C_EncodingUtil
    if not (enc and enc.SerializeCBOR and enc.CompressString and enc.EncodeBase64) then return false end
    if type(PLATYNATOR_CONFIG) ~= "table" or type(PLATYNATOR_CONFIG.Profiles) ~= "table" then return false end
    return PLATYNATOR_CURRENT_PROFILE ~= nil and type(PLATYNATOR_CONFIG.Profiles[PLATYNATOR_CURRENT_PROFILE]) == "table"
end

local function CurrentProfile()
    return PLATYNATOR_CONFIG.Profiles[PLATYNATOR_CURRENT_PROFILE]
end

-- nil when the chosen engine can work, otherwise the reason (shown in amber in the settings window)
local function NotReady()
    local e = Engine()
    if e == "off" then return "Nameplates are off" end
    if e == "platynator" then
        if not PlatyReady() then return "Platynator is not loaded" end
        return nil
    end
    local ok, why = ns.Plates.Available()
    if not ok then return why end
    if ns.IsAddOnLoaded("Platynator") then return "Platynator is loaded too" end
    return nil
end

local function Ready() return NotReady() == nil end

local function Encode(tbl)
    return "PLATY!1!" .. C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(C_EncodingUtil.SerializeCBOR(tbl)))
end

-- Platynator prints a line on every import and every /platy config. Mute the chat frame while
-- calling it (the override is an instance field, removed again afterwards).
-- luacheck: push ignore 122
local function Quiet(fn, ...)
    local chat = DEFAULT_CHAT_FRAME
    local had = chat and rawget(chat, "AddMessage")
    if chat then chat.AddMessage = function() end end
    local ok, err = pcall(fn, ...)
    if chat then chat.AddMessage = had end
    return ok, err
end
-- luacheck: pop

local function ProfileString()
    local profile = ns.CopyTable(CurrentProfile())
    profile.addon, profile.version, profile.kind = "Platynator", 1, "profile"
    return Encode(profile)
end

local function ImportProfileString(text)
    return Quiet(Platynator.API.ImportString, text, PLATYNATOR_CURRENT_PROFILE)
end

local function InPvP()
    local inInstance, kind = IsInInstance()
    return inInstance and (kind == "pvp" or kind == "arena") or false
end

-- The design Platynator uses for attackable units (the assignment with only "can-attack")
local function EnemyDesignName(profile)
    for _, a in ipairs(profile.design_assignments or {}) do
        local c = a.criteria
        if type(c) == "table" and #c == 1 and c[1] == "can-attack" and type(a.style) == "string" then
            return a.style
        end
    end
    return D().enemyDesign
end

------------------------------------------------------------------------
-- Mode settings ("a.b" = field b of table a)
------------------------------------------------------------------------
local function GetPath(tbl, key)
    local a, b = strsplit(".", key)
    if not b then return tbl[a] end
    if type(tbl[a]) ~= "table" then return nil end
    return tbl[a][b]
end

local function SetPath(tbl, key, value)
    local a, b = strsplit(".", key)
    if not b then
        tbl[a] = value
    elseif type(tbl[a]) == "table" then
        tbl[a][b] = value
    end
end

local function Desired(mode, inPvP)
    local d, want = D(), {}
    for k, v in pairs(d.presets[mode] or {}) do want[k] = v end
    -- Tank and healer modes already say it all; only DPS modes differ by archetype
    if mode == "dps" or mode == "solo" then
        for k, v in pairs(d.archetypePresets[(ns.LiveArchetype())] or {}) do want[k] = v end
    end
    if mode == "healer" and DB().healerFriends ~= false then
        for k, v in pairs(d.healerFriends) do want[k] = v end
    end
    if inPvP then
        for k, v in pairs(d.pvp) do want[k] = v end
    end
    return want
end

local function AllKeys()
    local d, keys = D(), {}
    for _, p in pairs(d.presets) do for k in pairs(p) do keys[k] = true end end
    for _, p in pairs(d.archetypePresets) do for k in pairs(p) do keys[k] = true end end
    for k in pairs(d.healerFriends) do keys[k] = true end
    for k in pairs(d.pvp) do keys[k] = true end
    return keys
end

-- Remembers your own value the first time MLZ changes a key ({ v = value }, v = nil if unset)
local function Base(key)
    local db = DB()
    db.base = db.base or {}
    if db.base[key] == nil then db.base[key] = { v = GetPath(CurrentProfile(), key) } end
    return db.base[key].v
end

local function ApplySettings(profile, mode, inPvP)
    local want = Desired(mode, inPvP)
    for key in pairs(AllKeys()) do
        local v = want[key]
        if v == nil then v = Base(key) else Base(key) end
        SetPath(profile, key, v)
    end
end

------------------------------------------------------------------------
-- Clean style and threat colors (edits the enemy design in the profile copy)
------------------------------------------------------------------------
local function GetStash(name)
    local db = DB()
    db.stash = db.stash or {}
    db.stash[name] = db.stash[name] or {}
    local s = db.stash[name]
    s.texts, s.bars, s.auras, s.colors = s.texts or {}, s.bars or {}, s.auras or {}, s.colors or {}
    return s
end

local function StashEmpty(s)
    return #s.texts == 0 and #s.bars == 0 and #s.auras == 0 and #s.colors == 0 and s.scale == nil
        and s.healthText == nil and s.specialBars == nil and s.debuff == nil and s.threat == nil
end

local function StyleDesign(design, stash, inPvP)
    local st = D().style
    if stash.scale == nil then stash.scale = design.scale or false end
    design.scale = st.scale

    local texts = {}
    for _, t in ipairs(design.texts or {}) do
        if st.removeTexts[t.kind] then
            stash.texts[#stash.texts + 1] = t
        else
            if t.kind == "health" then
                if stash.healthText == nil then stash.healthText = ns.CopyTable(t.displayTypes or {}) end
                t.displayTypes = ns.CopyTable(st.healthText)
            end
            texts[#texts + 1] = t
        end
    end
    design.texts = texts

    local bars = {}
    for _, b in ipairs(design.bars or {}) do
        if st.removeBars[b.kind] then
            stash.bars[#stash.bars + 1] = b
        else
            if b.kind == "health" and b.autoColors then
                local colors = {}
                for i, c in ipairs(b.autoColors) do
                    if st.dropColors[c.kind] then
                        stash.colors[#stash.colors + 1] = { pos = i, rule = c }
                    else
                        colors[#colors + 1] = c
                    end
                end
                b.autoColors = colors
            end
            bars[#bars + 1] = b
        end
    end
    design.bars = bars

    if st.removeSpecialBars and type(design.specialBars) == "table" and #design.specialBars > 0 then
        stash.specialBars = stash.specialBars or {}
        for _, s in ipairs(design.specialBars) do stash.specialBars[#stash.specialBars + 1] = s end
        design.specialBars = {}
    end

    if design.auras then
        local auras = {}
        for _, a in ipairs(design.auras) do
            if st.removeAuras[a.kind] and not (inPvP and a.kind == "buffs") then
                stash.auras[#stash.auras + 1] = a
            else
                if a.kind == "debuffs" then
                    if stash.debuff == nil then
                        stash.debuff = { scale = a.scale, limit = a.limit, fromYou = (a.filters and a.filters.fromYou) and true or false }
                    end
                    a.scale, a.limit = st.debuffScale, st.debuffLimit
                    if st.debuffsFromYou then
                        a.filters = a.filters or {}
                        a.filters.fromYou = true
                    end
                end
                auras[#auras + 1] = a
            end
        end
        if inPvP then
            -- enemy buffs matter against players: put back the ones removed earlier
            local keep = {}
            for _, a in ipairs(stash.auras) do
                if a.kind == "buffs" then auras[#auras + 1] = a else keep[#keep + 1] = a end
            end
            stash.auras = keep
        end
        design.auras = auras
    end
end

-- Puts back everything StyleDesign removed or changed (threat is handled by TuneThreat)
local function UnstyleDesign(design, stash)
    if stash.scale ~= nil then design.scale = stash.scale or nil end
    design.texts = design.texts or {}
    for _, t in ipairs(stash.texts) do design.texts[#design.texts + 1] = t end
    if stash.healthText then
        for _, t in ipairs(design.texts) do
            if t.kind == "health" then t.displayTypes = ns.CopyTable(stash.healthText) end
        end
    end
    design.bars = design.bars or {}
    for _, b in ipairs(stash.bars) do design.bars[#design.bars + 1] = b end
    table.sort(stash.colors, function(x, y) return x.pos < y.pos end)
    for _, b in ipairs(design.bars) do
        if b.kind == "health" then
            b.autoColors = b.autoColors or {}
            for _, c in ipairs(stash.colors) do
                table.insert(b.autoColors, math.min(c.pos, #b.autoColors + 1), c.rule)
            end
            break
        end
    end
    if stash.specialBars then
        design.specialBars = design.specialBars or {}
        for _, s in ipairs(stash.specialBars) do design.specialBars[#design.specialBars + 1] = s end
    end
    if #stash.auras > 0 or stash.debuff then
        design.auras = design.auras or {}
        for _, a in ipairs(stash.auras) do design.auras[#design.auras + 1] = a end
        if stash.debuff then
            for _, a in ipairs(design.auras) do
                if a.kind == "debuffs" then
                    a.scale, a.limit = stash.debuff.scale, stash.debuff.limit
                    a.filters = a.filters or {}
                    a.filters.fromYou = stash.debuff.fromYou
                end
            end
        end
    end
    stash.texts, stash.bars, stash.auras, stash.colors = {}, {}, {}, {}
    stash.scale, stash.healthText, stash.specialBars, stash.debuff = nil, nil, nil, nil
end

-- Threat rule of the enemy health bar: set per mode when on, put back as it was when off
local function TuneThreat(design, mode, stash, on, inPvP)
    local t = D().threat[inPvP and "solo" or mode]
    if not t then return end
    for _, b in ipairs(design.bars or {}) do
        if b.kind == "health" then
            for _, c in ipairs(b.autoColors or {}) do
                if c.kind == "threat" then
                    if on then
                        if stash.threat == nil then
                            stash.threat = { enabled = ns.CopyTable(c.enabled or {}), tanksOnly = c.tanksOnly and true or false }
                        end
                        c.enabled = c.enabled or {}
                        for k, v in pairs(t.enabled) do c.enabled[k] = v end
                        c.tanksOnly = t.tanksOnly
                    elseif stash.threat then
                        c.enabled = ns.CopyTable(stash.threat.enabled)
                        c.tanksOnly = stash.threat.tanksOnly
                    end
                end
            end
        end
    end
    if not on then stash.threat = nil end
end

-- A built-in design (name starts with "_") can't be edited. While one is the profile's style, Platynator keeps
-- a copy of it in designs["_custom"]. Take that copy under our own name and point the enemy assignments at it,
-- so the clean style and threat colors work on a fresh Platynator profile too. Returns the new name, or nil.
local function AdoptBuiltin(profile, name)
    if profile.style ~= name or type(profile.designs) ~= "table" then return nil end
    local copy = profile.designs["_custom"]
    if type(copy) ~= "table" then return nil end
    local own = D().ownDesign
    profile.designs[own] = ns.CopyTable(copy)
    for _, a in ipairs(profile.design_assignments or {}) do
        if a.style == name then a.style = own end
    end
    return own
end

-- Returns the profile copy to import, and a note if the design couldn't be changed
local function Build(mode, inPvP)
    local db = DB()
    local live = CurrentProfile()
    local profile = ns.CopyTable(live)
    ApplySettings(profile, mode, inPvP)

    local name = EnemyDesignName(live)
    local hadStash = db.stash and db.stash[name] ~= nil
    if not (db.style or db.threat or hadStash) then return profile end
    if name:sub(1, 1) == "_" then
        name = AdoptBuiltin(profile, name)
        if not name then return profile, "builtin" end
    end
    local design = type(profile.designs) == "table" and profile.designs[name]
    if type(design) ~= "table" then return profile, "missing" end

    local stash = GetStash(name)
    if db.style then StyleDesign(design, stash, inPvP) else UnstyleDesign(design, stash) end
    TuneThreat(design, mode, stash, db.threat and true or false, inPvP)
    if StashEmpty(stash) then db.stash[name] = nil end
    return profile
end

------------------------------------------------------------------------
-- Deciding and applying the mode
------------------------------------------------------------------------
local function Decide()
    local db = DB()
    if not db.auto then
        local m = D().presets[db.mode] and db.mode or "dps"
        return m, "chosen by you"
    end
    local live, why = ns.LiveRole()
    if live == "TANK" then return "tank", why end
    if not IsInGroup() then return "solo", "not in a group" end
    if live == "HEALER" then return "healer", why end
    return "dps", why
end

local NOTES = {
    builtin = "Your enemy design is one of Platynator's built-in designs and MLZ UI could not copy it. Make a copy of it in /platy and assign it to enemies to use the clean style or threat colors.",
    missing = "The enemy design was not found in the current Platynator profile, so the clean style and threat colors are not applied.",
    conflict = "Platynator is loaded too and draws its own nameplates. Pick Platynator as the engine, or turn Platynator off in the AddOns list.",
}

-- In combat: only the simple top-level numbers, through Platynator's own /platy config
local function ApplyInCombat(mode, inPvP)
    if not (SlashCmdList and SlashCmdList.Platynator) then return end
    for key, v in pairs(Desired(mode, inPvP)) do
        if not key:find(".", 1, true) and type(v) == "number" and GetPath(CurrentProfile(), key) ~= v then
            Base(key)
            Quiet(SlashCmdList.Platynator, "config " .. key .. " " .. v)
        end
    end
end

-- force = apply even if nothing seems to have changed. Returns true when the plates are up to date.
local function Refresh(force)
    if not ns.db then return false end
    local db = DB()
    local mode, why = Decide()
    currentReason = why
    local engine = Engine()
    local inPvP = db.pvp and InPvP() or false

    -- MLZ nameplates: our own frames, safe to change at any time (also in combat)
    local mlzOn = engine == "mlz" and Ready()
    ns.Plates.Configure(mlzOn, {
        mode = mode, pvp = inPvP, threat = db.threat, friends = db.healerFriends ~= false,
        show = Show(), size = db.size or 1,
    })
    if engine == "off" then
        current, lastError = nil, nil
        return true
    end
    if engine == "mlz" then
        if not mlzOn then
            current = nil
            lastError = ns.IsAddOnLoaded("Platynator") and NOTES.conflict or ns.Plates.LastError()
            return false
        end
        current, lastError = mode, ns.Plates.LastError()
        return lastError == nil
    end

    if not PlatyReady() then
        current, lastError = nil, "Platynator is not loaded."
        return false
    end
    if InCombatLockdown() then
        if mode ~= current then
            ApplyInCombat(mode, inPvP)
            current = mode
        end
        pending = true
        return false
    end
    pending = nil
    local key = table.concat({ mode, tostring((ns.LiveArchetype())), tostring(db.style), tostring(db.threat),
        tostring(inPvP), tostring(db.healerFriends ~= false), tostring(PLATYNATOR_CURRENT_PROFILE) }, "|")
    if not force and key == db.lastKey then
        current = mode
        return true
    end
    -- the first time MLZ writes anything, keep a copy of the profile as it was
    if not db.snapshot then
        local ok, text = pcall(ProfileString)
        if ok then db.snapshot = text end
    end
    db.lastKey = key -- also on failure, so a broken setup isn't retried on every event
    local ok, profile, note = pcall(Build, mode, inPvP)
    if not ok then
        lastError = "Could not build the nameplate settings: " .. tostring(profile)
        ns.Debug(lastError)
        return false
    end
    local imported, err = ImportProfileString(Encode((function()
        profile.addon, profile.version, profile.kind = "Platynator", 1, "profile"
        return profile
    end)()))
    if not imported then
        lastError = "Platynator refused the import: " .. tostring(err)
        ns.Debug(lastError)
        return false
    end
    current = mode
    lastError = note and NOTES[note] or nil
    return true
end

local scheduled = false
local function ScheduleRefresh()
    if scheduled then return end
    scheduled = true
    C_Timer.After(0.5, function()
        scheduled = false
        if ns.db and (ns.db.installed or (ns.db.nameplates and ns.db.nameplates.engine)) then
            Refresh()
            ns.FireState()
        end
    end)
end

ns.OnRoleChanged(function() ScheduleRefresh() end)
ns.On("GROUP_ROSTER_UPDATE", ScheduleRefresh)
ns.On("PLAYER_ENTERING_WORLD", function()
    -- give Platynator time to set itself up after login / loading screens
    C_Timer.After(2, ScheduleRefresh)
end)
ns.On("PLAYER_REGEN_ENABLED", function()
    if pending then ScheduleRefresh() end
end)

------------------------------------------------------------------------
-- Save / restore / export
------------------------------------------------------------------------
local function CanImport(quiet)
    if not PlatyReady() then
        if not quiet then ns.Print("Platynator (or its import API) is not available.") end
        return false
    end
    if InCombatLockdown() then
        if not quiet then ns.Print("Platynator can't import in combat. Try again after combat.") end
        return false
    end
    return true
end

local function Save()
    if not CanImport() then return end
    DB().snapshot = ProfileString()
    ns.Print("Saved the current Platynator profile (" .. PLATYNATOR_CURRENT_PROFILE .. ") in MLZ UI.")
end

-- Restoring the saved copy also turns the clean style and threat colors off, otherwise they
-- would be put straight back. The mode settings keep following your role.
local function Load()
    if not CanImport() then return end
    local db = DB()
    local text = db.snapshot or D().profileString
    if not text then
        ns.Print("Nothing saved yet. Use Save profile (or /mlz np save) first.")
        return
    end
    local ok, err = ImportProfileString(text)
    if not ok then
        ns.Print(ns.Paint("red", "Import failed:"), err)
        return
    end
    db.style, db.threat, db.stash, db.lastKey = false, false, nil, nil
    Refresh(true)
    ns.Print("Restored the saved profile into " .. PLATYNATOR_CURRENT_PROFILE .. ". Clean style and threat colors are off.")
end

------------------------------------------------------------------------
-- Public API (settings window, minimap menu, /mlz np). Quiet: no chat output.
------------------------------------------------------------------------
function NP.Ready() return Ready() end
function NP.NotReady() return NotReady() end
function NP.PlatyReady() return PlatyReady() end
function NP.Engine() return Engine() end
function NP.Show(key) return Show()[key] end
function NP.Size() return DB().size or 1 end
function NP.Mode() return current end
function NP.Reason() return currentReason end
function NP.LastError() return lastError end
function NP.InPvP() return InPvP() end
function NP.Auto() return DB().auto and true or false end
function NP.Style() return DB().style and true or false end
function NP.Threat() return DB().threat and true or false end
function NP.PvP() return DB().pvp and true or false end
function NP.HealerFriends() return DB().healerFriends ~= false end
function NP.HasSnapshot() return DB().snapshot ~= nil end
-- The mode automatic switching would pick right now, and why
function NP.Suggested()
    local db = DB()
    local auto = db.auto
    db.auto = true
    local m, why = Decide()
    db.auto = auto
    return m, why
end

local function Changed()
    Refresh()
    ns.FireState()
end

function NP.SetAuto(on)
    DB().auto = on and true or false
    if not on and not DB().mode then DB().mode = current or "dps" end
    Changed()
end

function NP.SetMode(mode)
    if not D().presets[mode] then return end
    local db = DB()
    db.auto, db.mode = false, mode
    Changed()
end

function NP.SetStyle(on) DB().style = on and true or false; Changed() end
function NP.SetThreat(on) DB().threat = on and true or false; Changed() end
function NP.SetPvP(on) DB().pvp = on and true or false; Changed() end
function NP.SetHealerFriends(on) DB().healerFriends = on and true or false; Changed() end
function NP.Apply() Refresh(true); ns.FireState() end

function NP.SetEngine(e)
    if not ENGINES[e] then return end
    local db = DB()
    db.engine = e
    db.lastKey = nil
    Changed()
end
function NP.SetShow(key, on)
    if SHOW_DEFAULTS[key] == nil then return end
    local db = DB()
    db.show = db.show or {}
    db.show[key] = on and true or false
    Changed()
end
function NP.SetSize(v)
    DB().size = tonumber(v) or 1
    Changed()
end

function NP.Save() Save(); ns.FireState() end
function NP.Load() Load(); ns.FireState() end
function NP.Export()
    if CanImport() then ns.ShowCopy("MLZ UI: Platynator profile (CTRL-C to copy)", ProfileString()) end
end

local function OnOff(v) return v and ns.Paint("green", "on") or ns.Paint("grey", "off") end

ns.AddCommand("np", "nameplates: auto | tank | healer | dps | solo | engine mlz/platynator/off | style [off] | threat [off] | pvp [off] | save | load | export", function(arg)
    arg = strlower(strtrim(arg or ""))
    DB()
    local word, rest = arg:match("^(%S*)%s*(.-)$")
    local off = rest == "off"
    if word == "engine" then
        if not ENGINES[rest] then
            ns.Print("Nameplate engine:", NP.ENGINE_TEXT[Engine()], "(use /mlz np engine mlz, platynator or off).")
            return
        end
        NP.SetEngine(rest)
        ns.Print("Nameplate engine:", NP.ENGINE_TEXT[rest] .. ".", NotReady() and ns.Paint("amber", NotReady() .. ".") or "")
    elseif word == "style" then
        NP.SetStyle(not off)
        ns.Print("Clean style:", OnOff(not off))
    elseif word == "threat" then
        NP.SetThreat(not off)
        ns.Print("Threat colors:", OnOff(not off))
    elseif word == "pvp" then
        NP.SetPvP(not off)
        ns.Print("PvP tweak (battlegrounds and arenas):", OnOff(not off))
    elseif word == "friends" then
        NP.SetHealerFriends(not off)
        ns.Print("Friendly names for healers:", OnOff(not off))
    elseif word == "save" then
        NP.Save()
    elseif word == "load" then
        NP.Load()
    elseif word == "export" then
        NP.Export()
    elseif D().presets[word] then
        NP.SetMode(word)
        ns.Print("Nameplates:", NP.MODE_TEXT[word], "(automatic switching is off, /mlz np auto turns it on).")
    elseif word == "auto" then
        NP.SetAuto(true)
        ns.Print("Nameplates follow your role: tank, healer or DPS in a group, solo alone.")
    elseif word == "off" then
        NP.SetAuto(false)
        ns.Print("Automatic switching is off. The mode stays", (NP.MODE_TEXT[DB().mode] or "as it is") .. ".")
    else
        if NotReady() then ns.Print("Nameplates (" .. NP.ENGINE_TEXT[Engine()] .. "):", NotReady() .. ".") return end
        ns.Print(("Nameplates (%s): %s (%s), automatic %s, threat %s, PvP %s"):format(
            NP.ENGINE_TEXT[Engine()], NP.MODE_TEXT[current or ""] or "unknown", currentReason or "-",
            OnOff(NP.Auto()), OnOff(NP.Threat()), OnOff(NP.PvP())))
        if lastError then ns.Print(ns.Paint("amber", "Note:"), lastError) end
        ns.Print("Use /mlz np auto, tank, healer, dps, solo, engine, style, threat, pvp, friends (add 'off' to turn off), save, load or export.")
    end
end)

------------------------------------------------------------------------
-- Wizard step
------------------------------------------------------------------------
local Nameplates = ns.RegisterModule({ key = "nameplates", title = "Nameplates" })

function Nameplates:Preview()
    local items = {}
    local db = DB()
    local engine = Engine()
    local platy = PlatyReady()

    -- Engine: Platynator when it is loaded (two engines would draw two plates), otherwise ours
    local row = { id = "engine", group = "Nameplates", old = NP.ENGINE_TEXT[engine] }
    if platy then
        row.label, row.new, row.engine = "Nameplates drawn by", "Platynator", "platynator"
        row.note = "Platynator is loaded, so MLZ UI drives it: modes per role, clean style and threat colors. "
            .. "To use MLZ nameplates instead, turn Platynator off and pick MLZ in the settings window."
    else
        row.label, row.new, row.engine = "MLZ nameplates", "MLZ", "mlz"
        row.note = "Flat nameplates that follow your role: name, health, cast bar, quest marker and your own debuffs. "
            .. "Blizzard's own plate is only made invisible, so turning this off brings it straight back."
        local ok, why = ns.Plates.Available()
        if not ok then row.new, row.unavailable, row.enabled = why, true, false end
    end
    if not row.unavailable then
        row.alreadySet = engine == row.engine
        row.enabled = ns.Enabled("nameplates", "engine", true)
    end
    items[#items + 1] = row

    if platy then
        -- Only offered when a profile string is pasted into Data/Nameplates.lua. Without one there is nothing to import.
        local text = D().profileString
        if text then
            items[#items + 1] = { id = "profile", group = "Platynator", label = "Import MLZ profile", requires = "engine",
                old = "current profile", new = "MLZ profile", value = text, enabled = ns.Enabled("nameplates", "profile", true),
                note = "Replaces the settings of your current Platynator profile. Undo puts the old profile back." }
        end
        local on = db.style and true or false
        items[#items + 1] = { id = "style", group = "Platynator", label = "Clean nameplate style", flag = "style",
            requires = "engine", old = on and "on" or "off", new = "on", toggle = true, isOn = on, offText = "off",
            enabled = on or ns.Enabled("nameplates", "style", true),
            note = "Minimal enemy nameplates: name and percent inside the bar, cast bar, crowd control and only your own debuffs. Everything removed is remembered, so turning it off puts it back." }
    end

    local threat = db.threat and true or false
    items[#items + 1] = { id = "threat", group = "Nameplates", label = "Threat colors per role", flag = "threat",
        old = threat and "on" or "off", new = "on", toggle = true, isOn = threat, offText = "off",
        enabled = threat or ns.Enabled("nameplates", "threat", false),
        note = "Colors the enemy health bar by threat: as tank, red = a mob is not on you; as DPS, red = a mob is on you. Off for healers and when solo." }
    return items
end

function Nameplates:Backup()
    local db = DB()
    local snap = { style = db.style and true or false, threat = db.threat and true or false,
        stash = db.stash and ns.CopyTable(db.stash) or nil, hasStash = true,
        engine = db.engine, hasEngine = true }
    if CanImport(true) then snap.profile = ProfileString() end
    return snap
end

function Nameplates:Apply(items)
    local db = DB()
    local failed
    for _, item in ipairs(items) do
        if item.engine then db.engine = item.engine end
    end
    for _, item in ipairs(items) do
        if item.value and CanImport() then
            if not db.snapshot then db.snapshot = ProfileString() end -- your profile, before the import
            local ok, err = ImportProfileString(item.value)
            if ok then
                db.stash = nil -- the designs were replaced, nothing left to put back
            else
                failed = "Platynator refused the MLZ profile: " .. tostring(err)
            end
        end
    end
    for _, item in ipairs(items) do
        if item.flag then db[item.flag] = item.enabled and true or false end
    end
    db.lastKey = nil
    Refresh(true)
    return failed
end

function Nameplates:Restore(snap)
    local db = DB()
    db.style = snap.style and true or false
    db.threat = snap.threat and true or false
    if snap.hasStash then db.stash = snap.stash end
    if snap.hasEngine then db.engine = snap.engine end
    local profileErr
    if snap.profile then
        if not CanImport(true) then
            profileErr = "Platynator is not loaded, so its profile was not put back"
        else
            local ok, err = ImportProfileString(snap.profile)
            if not ok then profileErr = "Platynator import failed: " .. tostring(err) end
        end
    end
    -- the restored profile is exactly what these flags produced; apply again on the next change
    db.lastKey = nil
    current = nil
    -- MLZ nameplates follow the restored engine at once (off brings Blizzard's plates back)
    if Engine() ~= "platynator" then Refresh(true) else ns.Plates.Configure(false) end
    -- Backup:Undo keeps this part so another /mlz undo can try again once Platynator is back
    if profileErr then error(profileErr, 0) end
end
