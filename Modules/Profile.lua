-- MLZ UI: Export / import of your MLZ UI choices
-- /mlz export gives a string with the wizard choices that live in MLZUIDB (which key movement,
-- which rows are ticked, scale mode, spell queue window, nameplate auto switching).
-- /mlz import applies such a string, after taking a backup that /mlz undo can restore.
-- This does not include the settings that live in the game or other addons; run the wizard for those.

local _, ns = ...

local PREFIX = "MLZ!1!"

local Profile = ns.RegisterModule({ key = "profile", title = "MLZ UI choices" })

local function Export()
    local db = ns.db
    local np = db.nameplates or {}
    return {
        toggles = db.toggles,
        movement = db.movement,
        spellQueueWindow = db.spellQueueWindow,
        scale = db.scale and { mode = db.scale.mode } or nil,
        nameplatesAuto = np.auto,
        nameplates = { mode = np.mode, style = np.style, threat = np.threat, pvp = np.pvp, healerFriends = np.healerFriends },
    }
end

local function Encode(tbl)
    return PREFIX .. C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(C_EncodingUtil.SerializeCBOR(tbl)))
end

-- Returns the table, or nil and a reason
local function Decode(text)
    if type(text) ~= "string" or text:sub(1, #PREFIX) ~= PREFIX then
        return nil, "not an MLZ UI string (should start with " .. PREFIX .. ")"
    end
    local ok, data = pcall(function()
        return C_EncodingUtil.DeserializeCBOR(C_EncodingUtil.DecompressString(C_EncodingUtil.DecodeBase64(text:sub(#PREFIX + 1))))
    end)
    if not ok or type(data) ~= "table" then return nil, "could not read the string (damaged or cut off?)" end
    return data
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
    if type(data.nameplates) == "table" then
        local n, out = data.nameplates, {}
        local modes = { tank = true, healer = true, dps = true, solo = true }
        if type(n.mode) == "string" and modes[n.mode] then out.mode = n.mode end
        for _, k in ipairs({ "style", "threat", "pvp", "healerFriends" }) do
            if type(n[k]) == "boolean" then out[k] = n[k] end
        end
        if next(out) then clean.nameplates = out end
    end
    -- roleForce is never imported: your role belongs to this character, not to a shared setup
    return clean
end

local NP_KEYS = { "auto", "mode", "style", "threat", "pvp", "healerFriends" }

function Profile:Backup()
    local np = ns.db.nameplates or {}
    local npCopy = {}
    for _, k in ipairs(NP_KEYS) do npCopy[k] = np[k] end
    return ns.CopyTable({
        toggles = ns.db.toggles, movement = ns.db.movement, spellQueueWindow = ns.db.spellQueueWindow,
        scale = ns.db.scale, nameplates = npCopy, roleForce = ns.GetRoleForce(), hasRoleForce = true,
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
    elseif snap.nameplatesAuto ~= nil then -- backups made by older versions
        ns.db.nameplates.auto = snap.nameplatesAuto
    end
    if ns.db.nameplates.auto == nil then ns.db.nameplates.auto = true end
    if snap.hasRoleForce then ns.GetRoleForce(); ns.CharDB().roleForce = snap.roleForce end
    if ns.FireRole then ns.FireRole() end
    if ns.NP and ns.NP.Apply then ns.NP.Apply() end -- nameplate options may have changed
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
    if not ns.Backup:Create({ { mod = Profile, items = {} } }, "import") then
        ns.Print(ns.Paint("red", "Import stopped because the backup failed. Nothing was changed."))
        return
    end
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
    if ns.FireRole then ns.FireRole() end
    if ns.NP and ns.NP.Apply then ns.NP.Apply() end -- nameplate options may have changed
    ns.Print("Imported. Run " .. ns.Cmd("/mlz install") .. " to apply the settings, or " .. ns.Cmd("/mlz undo")
        .. " to go back.")
    local S = ns.Settings
    if S and S.frame and S.frame:IsShown() then
        S:Notify("Imported. Run the setup wizard to apply movement and scale, or undo it on Profiles & backup.", "warn")
    end
end

ns.AddCommand("export", "shows a string with your MLZ UI choices", function()
    if not (C_EncodingUtil and C_EncodingUtil.SerializeCBOR) then
        ns.Print("This client has no C_EncodingUtil, export is not possible.")
        return
    end
    ns.ShowCopy("MLZ UI: your choices (CTRL-C to copy)", Encode(Export()))
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
        if ns.SituationProfiles then ns.SituationProfiles.Reapply() end
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
        if SP.Current() ~= SP.lastKind then SP.Reapply() end
    end)
end
ns.On("PLAYER_ENTERING_WORLD", OnZone)
ns.TryOn("ZONE_CHANGED_NEW_AREA", OnZone)
