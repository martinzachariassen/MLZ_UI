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
    return {
        toggles = db.toggles,
        movement = db.movement,
        spellQueueWindow = db.spellQueueWindow,
        scale = db.scale,
        nameplatesAuto = db.nameplates and db.nameplates.auto,
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
    if type(data.movement) == "string" and #data.movement <= 16 then clean.movement = data.movement end
    if type(data.spellQueueWindow) == "number" or type(data.spellQueueWindow) == "string" then
        clean.spellQueueWindow = data.spellQueueWindow
    end
    if type(data.scale) == "table" and type(data.scale.mode) == "string" then
        clean.scale = { mode = data.scale.mode }
    end
    if type(data.nameplatesAuto) == "boolean" then clean.nameplatesAuto = data.nameplatesAuto end
    return clean
end

function Profile:Backup()
    return ns.CopyTable({
        toggles = ns.db.toggles, movement = ns.db.movement, spellQueueWindow = ns.db.spellQueueWindow,
        scale = ns.db.scale, nameplatesAuto = ns.db.nameplates and ns.db.nameplates.auto,
    })
end

function Profile:Restore(snap)
    ns.db.toggles = snap.toggles or {}
    ns.db.movement = snap.movement
    ns.db.spellQueueWindow = snap.spellQueueWindow
    ns.db.scale = snap.scale or ns.db.scale
    ns.db.nameplates = ns.db.nameplates or {}
    ns.db.nameplates.auto = snap.nameplatesAuto
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
    if not ns.Backup:Create({ { mod = Profile, items = {} } }) then
        ns.Print("|cffff4444Aborted because the backup failed. Nothing was changed.|r")
        return
    end
    if clean.toggles then ns.db.toggles = clean.toggles end
    if clean.movement then ns.db.movement = clean.movement end
    if clean.spellQueueWindow then ns.db.spellQueueWindow = clean.spellQueueWindow end
    if clean.scale then ns.db.scale = clean.scale end
    if clean.nameplatesAuto ~= nil then
        ns.db.nameplates = ns.db.nameplates or {}
        ns.db.nameplates.auto = clean.nameplatesAuto
    end
    ns.Print("Imported. Run |cffffff00/mlz install|r to apply the settings, or |cffffff00/mlz undo|r to go back.")
end

ns.AddCommand("export", "shows a string with your MLZ UI choices", function()
    if not (C_EncodingUtil and C_EncodingUtil.SerializeCBOR) then
        ns.Print("This client has no C_EncodingUtil, export is not possible.")
        return
    end
    ns.ShowCopy("MLZ UI: your choices (Ctrl+C to copy)", Encode(Export()))
end)

ns.AddCommand("import", "pastes a string made by /mlz export", function(arg)
    arg = strtrim(arg or "")
    if arg ~= "" then
        Import(arg)
    else
        ns.ShowCopy("MLZ UI: paste a string and press Import", "", Import)
    end
end)
