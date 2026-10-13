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
        roleForce = ns.GetRoleForce(),
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
    local roles = { TANK = true, HEALER = true, DAMAGER = true }
    if type(data.roleForce) == "string" and roles[data.roleForce] then clean.roleForce = data.roleForce end
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
        ns.Print("|cffff4444Import failed:|r", reason)
        return
    end
    local clean = Validate(data)
    if next(clean) == nil then
        ns.Print("|cffff4444Import failed:|r the string has none of the settings MLZ UI knows.")
        return
    end
    if not ns.Backup:Create({ { mod = Profile, items = {} } }, "import") then
        ns.Print("|cffff4444Aborted because the backup failed. Nothing was changed.|r")
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
    if clean.roleForce then ns.GetRoleForce(); ns.CharDB().roleForce = clean.roleForce end
    if ns.FireRole then ns.FireRole() end
    if ns.NP and ns.NP.Apply then ns.NP.Apply() end -- nameplate options may have changed
    ns.Print("Imported. Run |cffffff00/mlz install|r to apply the settings, or |cffffff00/mlz undo|r to go back.")
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

local function Load(snap)
    -- nameplates: set the options, then apply them in one go
    ns.db.nameplates = ns.db.nameplates or {}
    for _, k in ipairs(NP_KEYS) do ns.db.nameplates[k] = snap.nameplates and snap.nameplates[k] end
    if ns.db.nameplates.auto == nil then ns.db.nameplates.auto = true end
    if ns.NP and ns.NP.Apply then ns.NP.Apply() end
    -- fading: only the rows that differ
    local fade = ns.modules.fade
    if fade and snap.fade then
        for _, row in ipairs(ns.data.fade or {}) do
            local want = snap.fade[row.id] and true or false
            if fade:IsOn(row.id) ~= want then fade:SetRow(row.id, want) end
        end
    end
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

-- Returns true if a profile was loaded
function RP.Load(role, quiet)
    local snap = Store()[role]
    if not snap then return false end
    ns.RunOutOfCombat(function()
        Load(snap)
        if quiet then return end
        local text = "Loaded your " .. ns.ROLE_TEXT[role] .. " profile."
        ns.Debug(text)
        local S = ns.Settings
        if S and S.frame and S.frame:IsShown() then S:Notify(text, "info") end
    end, "role profile", true)
    return true
end

ns.OnRoleChanged(function(role, _, roleChanged)
    if not (roleChanged and role and ns.db and ns.db.installed and RP.Auto()) then return end
    -- the first event after login only tells us the role we already had
    if not RP.started then return end
    if RP.Has(role) then RP.Load(role) end
end)
ns.On("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(3, function() RP.started = true end)
end)
