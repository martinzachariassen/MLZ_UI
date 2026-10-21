-- MLZ UI: Export / import of your MLZ UI choices
-- /mlz export gives a string with your MLZ UI choices: the wizard choices (key movement, ticked rows,
-- scale mode, spell queue window, nameplates), faded frames, helpers, reminders, and the role and
-- situation profiles of this character. /mlz import applies such a string, after taking a backup that
-- /mlz undo can restore. Settings that live in the game or other addons are not included; run the wizard.

local _, ns = ...

local PREFIX = "MLZ!2!"
local OLD_PREFIXES = { "MLZ!1!" } -- older strings still import (they simply have fewer keys)

local Profile = ns.RegisterModule({ key = "profile", title = "MLZ UI choices" })

local NP_KEYS = { "auto", "mode", "style", "threat", "pvp", "healerFriends" }
local NP_MODES = { tank = true, healer = true, dps = true, solo = true }

-- On/off helpers that travel with the string: db key -> module and the keys it knows
local SWITCHES = {
    { key = "vendor", mod = function() return ns.Vendor end, keys = { "repair", "guild", "sell" } },
    { key = "automate", mod = function() return ns.Automate end,
      keys = { "acceptQuests", "turnInQuests", "summon", "resurrect", "bopSolo", "declineDuels" } },
    { key = "group", mod = function() return ns.Group end, keys = { "buffCheck", "leaderAll" } },
    { key = "reminders", mod = function() return ns.Reminders end, keys = { "buffs", "reagents", "durability", "raidFood", "levelFood" } },
}

-- Fading: only the rows that differ. Returns true when something changed.
local function LoadFade(saved)
    local fade = ns.modules.fade
    if not (fade and saved) then return false end
    local changed = false
    for _, row in ipairs(ns.data.fade or {}) do
        local want = saved[row.id] and true or false
        if fade:IsOn(row.id) ~= want then
            fade:SetRow(row.id, want)
            changed = true
        end
    end
    return changed
end

local function Switches()
    local out = {}
    for _, s in ipairs(SWITCHES) do
        local mod = s.mod()
        if mod then
            out[s.key] = {}
            for _, k in ipairs(s.keys) do out[s.key][k] = mod.Get(k) end
        end
    end
    return out
end

local function SetSwitches(all)
    for _, s in ipairs(SWITCHES) do
        local mod, saved = s.mod(), all[s.key]
        if mod and type(saved) == "table" then
            for _, k in ipairs(s.keys) do
                if saved[k] ~= nil and mod.Get(k) ~= saved[k] then mod.Set(k, saved[k]) end
            end
        end
    end
end

local function Export()
    local db = ns.db
    local np = db.nameplates or {}
    local char = ns.CharDB()
    local data = {
        toggles = db.toggles,
        movement = db.movement,
        spellQueueWindow = db.spellQueueWindow,
        scale = db.scale and { mode = db.scale.mode } or nil,
        nameplatesAuto = np.auto,
        nameplates = { mode = np.mode, style = np.style, threat = np.threat, pvp = np.pvp, healerFriends = np.healerFriends,
                       show = np.show and ns.CopyTable(np.show) or nil },
        fade = ns.CopyTable(db.fade or {}),
        switches = Switches(),
        roleProfiles = char.roleProfiles,
        situationProfiles = char.situationProfiles,
    }
    return data
end

local function Encode(tbl)
    return PREFIX .. C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(C_EncodingUtil.SerializeCBOR(tbl)))
end

-- Returns the table, or nil and a reason
local function Decode(text)
    if type(text) ~= "string" then return nil, "not an MLZ UI string" end
    local used
    for _, p in ipairs({ PREFIX, unpack(OLD_PREFIXES) }) do
        if text:sub(1, #p) == p then used = p break end
    end
    if not used then return nil, "not an MLZ UI string (should start with " .. PREFIX .. ")" end
    local ok, data = pcall(function()
        return C_EncodingUtil.DeserializeCBOR(C_EncodingUtil.DecompressString(C_EncodingUtil.DecodeBase64(text:sub(#used + 1))))
    end)
    if not ok or type(data) ~= "table" then return nil, "could not read the string (damaged or cut off?)" end
    return data
end

------------------------------------------------------------------------
-- Validation: only known keys with the right types get in
------------------------------------------------------------------------
local function FadeMap(t)
    if type(t) ~= "table" then return nil end
    local known, out = {}, {}
    for _, row in ipairs(ns.data.fade or {}) do known[row.id] = true end
    for k, v in pairs(t) do
        if known[k] and v == true then out[k] = true end
    end
    return out
end

local function NameplateOpts(n, withAuto)
    if type(n) ~= "table" then return nil end
    local out = {}
    if type(n.mode) == "string" and NP_MODES[n.mode] then out.mode = n.mode end
    for _, k in ipairs({ "style", "threat", "pvp", "healerFriends" }) do
        if type(n[k]) == "boolean" then out[k] = n[k] end
    end
    if withAuto and type(n.auto) == "boolean" then out.auto = n.auto end
    local known = ns.NP and ns.NP.SHOW_KEYS
    if type(n.show) == "table" and known then
        local show = {}
        for k in pairs(known) do
            if type(n.show[k]) == "boolean" then show[k] = n.show[k] end
        end
        if next(show) then out.show = show end
    end
    return out
end

local function Stamp(t)
    return type(t) == "string" and #t <= 20 and t or nil
end

local function RoleSnap(s)
    if type(s) ~= "table" then return nil end
    local out = { nameplates = NameplateOpts(s.nameplates, true) or {}, fade = FadeMap(s.fade) or {}, time = Stamp(s.time) }
    if type(s.manaTick) == "boolean" then out.manaTick = s.manaTick end
    if type(s.interrupt) == "string" and #s.interrupt <= 20 then out.interrupt = s.interrupt end
    return out
end

local function SituationSnap(s)
    if type(s) ~= "table" then return nil end
    local out = { fade = FadeMap(s.fade) or {}, tracker = {}, time = Stamp(s.time) }
    if type(s.tracker) == "table" then
        for _, k in ipairs({ "trackerHide", "trackerHeader" }) do
            if type(s.tracker[k]) == "boolean" then out.tracker[k] = s.tracker[k] end
        end
    end
    if type(s.threat) == "boolean" then out.threat = s.threat end
    return out
end

local function Profiles(t, kinds, snapFn)
    if type(t) ~= "table" then return nil end
    local out = {}
    for _, kind in ipairs(kinds) do out[kind] = snapFn(t[kind]) end
    if type(t.auto) == "boolean" then out.auto = t.auto end
    return next(out) and out or nil
end

-- Only known keys with the right types are accepted
local function Validate(data)
    local clean = {}
    if type(data.toggles) == "table" then
        clean.toggles = {}
        for k, v in pairs(data.toggles) do
            if type(k) == "string" and type(v) == "boolean" then clean.toggles[k] = v end
        end
    end
    local moves = ns.data.bindings and ns.data.bindings.movement or {}
    if type(data.movement) == "string" and moves[data.movement] then clean.movement = data.movement end
    local sqw = tonumber(data.spellQueueWindow)
    if sqw then
        -- stored as a string, the same way the wizard stores it
        clean.spellQueueWindow = tostring(math.floor(math.max(0, math.min(400, sqw)) + 0.5))
    end
    local Scale = ns.modules.scale
    if type(data.scale) == "table" and type(data.scale.mode) == "string" and Scale and Scale:ValidMode(data.scale.mode) then
        clean.scale = { mode = data.scale.mode }
    end
    if type(data.nameplatesAuto) == "boolean" then clean.nameplatesAuto = data.nameplatesAuto end
    local np = NameplateOpts(data.nameplates)
    if np and next(np) then clean.nameplates = np end
    -- MLZ!2! keys
    clean.fade = FadeMap(data.fade)
    if type(data.switches) == "table" then
        local out = {}
        for _, s in ipairs(SWITCHES) do
            local saved = data.switches[s.key]
            if type(saved) == "table" then
                out[s.key] = {}
                for _, k in ipairs(s.keys) do
                    if type(saved[k]) == "boolean" then out[s.key][k] = saved[k] end
                end
            end
        end
        if next(out) then clean.switches = out end
    end
    clean.roleProfiles = Profiles(data.roleProfiles, { "TANK", "HEALER", "DAMAGER" }, RoleSnap)
    clean.situationProfiles = Profiles(data.situationProfiles, { "solo", "party", "raid", "pvp" }, SituationSnap)
    -- roleForce is never imported: your role belongs to this character, not to a shared setup
    return clean
end

function Profile:Backup()
    local np = ns.db.nameplates or {}
    local npCopy = {}
    for _, k in ipairs(NP_KEYS) do npCopy[k] = np[k] end
    npCopy.show = np.show or false -- false: no show options were saved (all defaults)
    local char = ns.CharDB()
    return ns.CopyTable({
        toggles = ns.db.toggles, movement = ns.db.movement, spellQueueWindow = ns.db.spellQueueWindow,
        scale = ns.db.scale, nameplates = npCopy, roleForce = ns.GetRoleForce(), hasRoleForce = true,
        fade = ns.db.fade or {}, switches = Switches(),
        roleProfiles = char.roleProfiles or {}, situationProfiles = char.situationProfiles or {}, hasProfiles = true,
    })
end

function Profile:Restore(snap)
    ns.db.toggles = snap.toggles or {}
    ns.db.movement = snap.movement
    ns.db.spellQueueWindow = snap.spellQueueWindow
    if snap.scale then ns.db.scale = snap.scale end
    ns.db.nameplates = ns.db.nameplates or {}
    if snap.nameplates then
        for _, k in ipairs(NP_KEYS) do ns.db.nameplates[k] = snap.nameplates[k] end
        -- nil: an older backup without show options, so keep what you have
        if snap.nameplates.show == false then
            ns.db.nameplates.show = nil
        elseif type(snap.nameplates.show) == "table" then
            ns.db.nameplates.show = ns.CopyTable(snap.nameplates.show)
        end
    elseif snap.nameplatesAuto ~= nil then -- backups made by older versions
        ns.db.nameplates.auto = snap.nameplatesAuto
    end
    if ns.db.nameplates.auto == nil then ns.db.nameplates.auto = true end
    if snap.hasRoleForce then ns.GetRoleForce(); ns.CharDB().roleForce = snap.roleForce end
    -- backups made before 0.9 have none of these
    if snap.fade then LoadFade(snap.fade) end
    if snap.switches then SetSwitches(snap.switches) end
    if snap.hasProfiles then
        local char = ns.CharDB()
        char.roleProfiles = snap.roleProfiles
        char.situationProfiles = snap.situationProfiles
    end
    if ns.FireRole then ns.FireRole() end
    if ns.NP and ns.NP.Apply then ns.NP.Apply() end -- nameplate options may have changed
    ns.FireState()
end

-- Writes validated choices after taking a backup (kind: "import" or "preset"). Returns false if the backup failed.
local function ApplyClean(clean, kind)
    if not ns.Backup:Create({ { mod = Profile, items = {} } }, kind) then return false end
    if clean.toggles then ns.db.toggles = clean.toggles end
    if clean.movement then ns.db.movement = clean.movement end
    if clean.spellQueueWindow then ns.db.spellQueueWindow = clean.spellQueueWindow end
    if clean.scale then
        -- keep "applied": whether scaling is switched on is not part of the choice
        ns.db.scale = ns.db.scale or {}
        ns.db.scale.mode = clean.scale.mode
    end
    ns.db.nameplates = ns.db.nameplates or {}
    if clean.nameplatesAuto ~= nil then ns.db.nameplates.auto = clean.nameplatesAuto end
    if clean.nameplates then
        for k, v in pairs(clean.nameplates) do ns.db.nameplates[k] = v end
    end
    if clean.fade then LoadFade(clean.fade) end
    if clean.switches then SetSwitches(clean.switches) end
    -- profiles are merged: a role or place the string doesn't have keeps what you saved here
    local char = ns.CharDB()
    for _, key in ipairs({ "roleProfiles", "situationProfiles" }) do
        if clean[key] then
            char[key] = char[key] or {}
            for k, v in pairs(clean[key]) do char[key][k] = v end
        end
    end
    if ns.FireRole then ns.FireRole() end
    if ns.NP and ns.NP.Apply then ns.NP.Apply() end -- nameplate options may have changed
    return true
end

local function Import(text)
    if not (C_EncodingUtil and C_EncodingUtil.DeserializeCBOR) then
        ns.Print("This client has no C_EncodingUtil, import is not possible.")
        return
    end
    local data, reason = Decode(text)
    if not data then
        ns.Print(ns.Paint("red", "Import failed:"), reason)
        return
    end
    local clean = Validate(data)
    if next(clean) == nil then
        ns.Print(ns.Paint("red", "Import failed:"), "the string has none of the settings MLZ UI knows.")
        return
    end
    if not ApplyClean(clean, "import") then
        ns.Print(ns.Paint("red", "Import stopped because the backup failed. Nothing was changed."))
        return
    end
    ns.Print("Imported. Run " .. ns.Cmd("/mlz install") .. " to apply the settings, or " .. ns.Cmd("/mlz undo")
        .. " to go back.")
    local S = ns.Settings
    if S and S.frame and S.frame:IsShown() then
        S:Notify("Imported. Run the setup wizard to apply movement and scale, or undo it on Profiles & backup.", "warn")
    end
end

ns.AddCommand("export", "shows a string with your MLZ UI choices", function()
    local enc = C_EncodingUtil
    if not (enc and enc.SerializeCBOR and enc.CompressString and enc.EncodeBase64) then
        ns.Print("This client has no C_EncodingUtil, export is not possible.")
        return
    end
    local ok, text = pcall(Encode, Export())
    if not ok then
        ns.Error("export", text)
        return
    end
    ns.ShowCopy("MLZ UI: your choices (CTRL-C to copy)", text)
end)

ns.AddCommand("import", "pastes a string made by /mlz export", function(arg)
    arg = strtrim(arg or "")
    if arg ~= "" then
        Import(arg)
    else
        ns.ShowCopy("MLZ UI: paste a string and press Import", "", Import)
    end
end)

------------------------------------------------------------------------
-- Ready-made setups (Data/Presets.lua)
-- Plain tables in the same shape as an export, so they go through the same checks and backup.
------------------------------------------------------------------------
local Presets = {}
ns.Presets = Presets

function Presets.List() return ns.data.presets or {} end

function Presets.Get(id)
    for _, p in ipairs(Presets.List()) do
        if p.id == id then return p end
    end
end

-- True when everything the setup sets already has that value
local function Matches(clean)
    if next(clean) == nil then return false end
    local fade = ns.modules.fade
    if clean.fade and fade then
        for _, row in ipairs(ns.data.fade or {}) do
            if fade:IsOn(row.id) ~= (clean.fade[row.id] or false) then return false end
        end
    end
    local np = ns.db.nameplates or {}
    for k, v in pairs(clean.nameplates or {}) do
        if k == "show" then
            for key, on in pairs(v) do
                if not (ns.NP and ns.NP.Show) or ns.NP.Show(key) ~= on then return false end
            end
        elseif np[k] ~= v then
            return false
        end
    end
    local now = Switches()
    for key, values in pairs(clean.switches or {}) do
        for k, v in pairs(values) do
            if not now[key] or now[key][k] ~= v then return false end
        end
    end
    return true
end

-- The setup your current choices match, or nil (your own mix)
function Presets.Current()
    for _, p in ipairs(Presets.List()) do
        if Matches(Validate(p.data or {})) then return p end
    end
end

-- Returns true, or false, a reason and (when the setup is already in use) true
function Presets.Apply(id)
    local preset = Presets.Get(id)
    if not preset then return false, "There is no setup called " .. tostring(id) .. "." end
    local clean = Validate(preset.data or {})
    if next(clean) == nil then return false, "The " .. preset.name .. " setup has no settings MLZ UI knows." end
    -- no backup for nothing: only 5 are kept, and older ones would be pushed out
    if Matches(clean) then return false, "You already use the " .. preset.name .. " setup.", true end
    if not ApplyClean(clean, "preset") then return false, "The backup failed. Nothing was changed." end
    return true
end

ns.AddCommand("preset", "loads a ready-made setup: minimal | balanced | informative", function(arg)
    local id = strtrim(arg or ""):lower()
    local ids = {}
    for _, p in ipairs(Presets.List()) do ids[#ids + 1] = p.id end
    local list = "Setups: " .. table.concat(ids, ", ") .. "."
    if id == "" then
        ns.Print(list, "Load one with " .. ns.Cmd("/mlz preset <name>") .. ".")
        return
    end
    local ok, why, same = Presets.Apply(id)
    if same then
        ns.Print(why)
        return
    end
    if not ok then
        ns.Print(ns.Paint("red", why), list)
        return
    end
    local text = "Loaded the " .. Presets.Get(id).name .. " setup. " .. ns.Cmd("/mlz undo") .. " puts things back."
    local S = ns.Settings
    if S and S.frame and S.frame:IsShown() then
        S:Notify(text, "good")
    else
        ns.Print(text)
    end
end)

------------------------------------------------------------------------
-- Role profiles (per character)
-- Save your everyday choices once per role: nameplate mode and options, which frames fade,
-- the mana tick bar and the interrupt announce. With automatic switching on, the saved profile
-- for your new role is loaded when your role changes (respec, dual spec, /mlz role).
-- Stored in MLZUIDB.chars["Name - Realm"].roleProfiles.
------------------------------------------------------------------------
local RP = {}
ns.RoleProfiles = RP

local function Store()
    local c = ns.CharDB()
    c.roleProfiles = c.roleProfiles or {}
    return c.roleProfiles
end

local function Capture()
    local np = ns.db.nameplates or {}
    local snap = { nameplates = {}, fade = ns.CopyTable(ns.db.fade or {}), time = date("%Y-%m-%d %H:%M") }
    for _, k in ipairs(NP_KEYS) do snap.nameplates[k] = np[k] end
    if ns.ManaTick then snap.manaTick = ns.ManaTick.IsOn() end
    if ns.Interrupt then snap.interrupt = ns.Interrupt.Get() end
    return snap
end

local function Load(snap)
    -- nameplates: set the options, then apply them in one go
    ns.db.nameplates = ns.db.nameplates or {}
    for _, k in ipairs(NP_KEYS) do ns.db.nameplates[k] = snap.nameplates and snap.nameplates[k] end
    if ns.db.nameplates.auto == nil then ns.db.nameplates.auto = true end
    if ns.NP and ns.NP.Apply then ns.NP.Apply() end
    LoadFade(snap.fade)
    if ns.ManaTick and snap.manaTick ~= nil and ns.ManaTick.IsOn() ~= snap.manaTick then ns.ManaTick.SetOn(snap.manaTick) end
    if ns.Interrupt and snap.interrupt then ns.Interrupt.Set(snap.interrupt) end
    ns.FireState()
end

function RP.Has(role) return Store()[role] ~= nil end
function RP.Time(role) return Store()[role] and Store()[role].time end
function RP.Auto() return Store().auto and true or false end
function RP.SetAuto(on) Store().auto = on and true or false; ns.FireState() end

function RP.Save(role)
    if not ns.ROLE_TEXT[role] then return end
    Store()[role] = Capture()
    ns.FireState()
end

function RP.Delete(role)
    Store()[role] = nil
    ns.FireState()
end

-- Returns true if a profile was found, and a second value: false when it waits for combat to end
function RP.Load(role, quiet)
    local snap = Store()[role]
    if not snap then return false end
    local ran = ns.RunOutOfCombat(function()
        Load(snap)
        if quiet then return end
        local text = "Loaded your " .. ns.ROLE_TEXT[role] .. " profile."
        ns.Debug(text)
        local S = ns.Settings
        if S and S.frame and S.frame:IsShown() then S:Notify(text, "info") end
    end, "role profile", true)
    return true, ran
end

ns.OnRoleChanged(function(role)
    -- compare roles ourselves: the listener flag is also true when only the archetype changed
    local previous = RP.lastRole
    RP.lastRole = role
    if not (previous and role and role ~= previous and ns.db and ns.db.installed and RP.Auto()) then return end
    -- the first event after login only tells us the role we already had
    if not RP.started then return end
    if RP.Has(role) then
        RP.Load(role)
        -- the situation profile sits on top of the role profile
        if ns.SituationProfiles then ns.SituationProfiles.Reapply(true) end
    end
end)
ns.On("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(3, function() RP.started = true end)
end)

------------------------------------------------------------------------
-- Situation profiles (per character)
-- Save what fades, the quest tracker and threat colors once for solo, dungeon, raid and
-- battleground. With switching on, the saved one is loaded when you enter that kind of place,
-- on top of your role profile. Stored in MLZUIDB.chars["Name - Realm"].situationProfiles.
------------------------------------------------------------------------
local SP = {}
ns.SituationProfiles = SP

SP.ORDER = { "solo", "party", "raid", "pvp" }
SP.TEXT = { solo = "Solo", party = "Dungeon", raid = "Raid", pvp = "Battleground" }

local TRACKER_KEYS = { "trackerHide", "trackerHeader" }

local function SStore()
    local c = ns.CharDB()
    c.situationProfiles = c.situationProfiles or {}
    return c.situationProfiles
end

-- Where you are now: solo (open world, cities), party, raid or pvp (battlegrounds and arenas)
function SP.Current()
    if not IsInInstance then return "solo" end
    local _, kind = IsInInstance()
    if kind == "party" or kind == "raid" then return kind end
    if kind == "pvp" or kind == "arena" then return "pvp" end
    return "solo"
end

local function CaptureSituation()
    local tw = ns.modules.tweaks
    local snap = { fade = ns.CopyTable(ns.db.fade or {}), tracker = {}, time = date("%Y-%m-%d %H:%M") }
    for _, k in ipairs(TRACKER_KEYS) do snap.tracker[k] = tw and tw:IsOn(k) or false end
    snap.threat = (ns.db.nameplates or {}).threat and true or false
    return snap
end

-- Returns true when something changed
local function LoadSituation(snap)
    local changed = LoadFade(snap.fade)
    local tw = ns.modules.tweaks
    if tw and snap.tracker then
        for _, k in ipairs(TRACKER_KEYS) do
            local want = snap.tracker[k] and true or false
            if tw:IsOn(k) ~= want then
                tw:Set(k, want)
                changed = true
            end
        end
    end
    ns.db.nameplates = ns.db.nameplates or {}
    if snap.threat ~= nil and (ns.db.nameplates.threat and true or false) ~= snap.threat then
        ns.db.nameplates.threat = snap.threat
        if ns.NP and ns.NP.Apply then ns.NP.Apply() end
        changed = true
    end
    if changed then ns.FireState() end
    return changed
end

function SP.Has(kind) return SStore()[kind] ~= nil end
function SP.Time(kind) return SStore()[kind] and SStore()[kind].time end
function SP.Auto() return SStore().auto and true or false end
function SP.SetAuto(on)
    SStore().auto = on and true or false
    SP.lastKind = nil -- load for the place you are in now
    if on then SP.Reapply() end
    ns.FireState()
end

function SP.Save(kind)
    if not SP.TEXT[kind] then return end
    SStore()[kind] = CaptureSituation()
    SP.lastKind = kind
    ns.FireState()
end

function SP.Delete(kind)
    SStore()[kind] = nil
    ns.FireState()
end

-- Loads one saved situation by hand. Returns ok (a profile exists), ran (false = waits for combat to end).
function SP.Load(kind)
    local snap = SStore()[kind]
    if not snap then return false end
    SP.lastKind = kind
    return true, ns.RunOutOfCombat(function() LoadSituation(snap) end, "situation profile", true)
end

-- Loads the profile for where you are now. quiet = no chat line.
function SP.Reapply(quiet)
    if not (ns.db and ns.db.installed and SP.Auto()) then return end
    local kind = SP.Current()
    local snap = SStore()[kind]
    SP.lastKind = kind
    if not snap then return end
    ns.RunOutOfCombat(function()
        if LoadSituation(snap) and not quiet then
            ns.Print(SP.TEXT[kind] .. " setup loaded.")
        end
    end, "situation profile", true)
end

-- Entering a new zone fires several events: look once, a moment later, and only act on a new kind of place
local pendingZone = false
local function OnZone()
    if pendingZone then return end
    pendingZone = true
    C_Timer.After(1, function()
        pendingZone = false
        if not (ns.db and SP.Auto()) then return end
        -- automatic, like role profiles: no chat line (the overview shows what is loaded)
        if SP.Current() ~= SP.lastKind then SP.Reapply(true) end
    end)
end
ns.On("PLAYER_ENTERING_WORLD", OnZone)
ns.TryOn("ZONE_CHANGED_NEW_AREA", OnZone)
