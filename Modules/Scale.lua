-- MLZ UI: Skalering
-- Pixel-perfect: én UI-piksel = k fysiske piksler  =>  skala = k * 768 / skjermhøyde.
-- Modusen lagres (ikke selve tallet), så skalaen regnes ut på nytt hvis oppløsningen endres.
-- Blizzard tillater ikke uiScale under 0.64 via CVar, så under det settes UIParent:SetScale direkte.

local _, ns = ...

local Scale = ns.RegisterModule({ key = "scale", title = "Skalering" })

local CVAR_MIN, CVAR_MAX = 0.64, 1.15

local MODES = {
    { value = "auto",    text = "Auto (anbefalt)" },
    { value = "0.71",    text = "Normal 0.71" },
    { value = "0.64",    text = "Kompakt 0.64" },
    { value = "0.57",    text = "Ekstra kompakt 0.57" },
    { value = "0.50",    text = "Minimal 0.50" },
    { value = "pixel1",  text = "Pixel-perfekt (768/høyde)" },
    { value = "1.00",    text = "Blizzard standard 1.00" },
}

local function ScreenHeight()
    local _, h = GetPhysicalScreenSize()
    return (h and h > 0) and h or 768
end

function Scale:Compute(mode)
    local h = ScreenHeight()
    local s
    if mode == "pixel1" then
        s = 768 / h
    elseif mode == "auto" or mode == nil then
        -- Pixel-perfekt hvis det gir en fornuftig størrelse (1080p = 0.71, 1440p = 0.53),
        -- ellers kompakt 0.64. Fast skala = samme andel av skjermen på alle oppløsninger.
        s = 768 / h
        if s < 0.53 or s > 0.72 then s = 0.64 end
    else
        s = tonumber(mode) or 1
    end
    return math.min(s, CVAR_MAX)
end

local function ModeText(mode)
    for _, m in ipairs(MODES) do if m.value == mode then return m.text end end
    return tostring(mode)
end

-- Selve påføringen. Kalles ved Apply og ved login/oppløsningsendring hvis brukeren har godtatt skalering.
local applying = false
function Scale:ApplyScale(mode)
    if applying then return end
    applying = true
    local s = self:Compute(mode)
    local cvarValue = math.max(s, CVAR_MIN)
    if GetCVar("useUiScale") ~= "1" then SetCVar("useUiScale", "1") end
    local current = tonumber(GetCVar("uiScale")) or 0
    if math.abs(current - cvarValue) > 0.0005 then SetCVar("uiScale", ("%.6f"):format(cvarValue)) end
    if s < CVAR_MIN and math.abs(UIParent:GetScale() - s) > 0.0005 then
        UIParent:SetScale(s)
    end
    applying = false
    self:UpdateSafeArea()
    ns.Debug(("skala %.4f (modus %s, høyde %d)"):format(s, tostring(mode), ScreenHeight()))
end

-- MLZ_Safe: en sentrert 16:9-container som egne frames kan ankres til,
-- slik at HUD-en ikke sprer seg på ultrawide.
function Scale:UpdateSafeArea()
    local f = _G.MLZ_Safe
    if not f then
        f = CreateFrame("Frame", "MLZ_Safe", UIParent)
        f:SetPoint("CENTER")
        f:SetFrameStrata("BACKGROUND")
    end
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    f:SetSize(math.min(w, h * 16 / 9), h)
end

------------------------------------------------------------------------
-- Modulgrensesnitt
------------------------------------------------------------------------
function Scale:Preview()
    local pw, ph = GetPhysicalScreenSize()
    local mode = ns.db.scale.mode or "auto"
    local choices = {}
    for i, m in ipairs(MODES) do
        choices[i] = { value = m.value, text = ("%s  =  %.3f"):format(m.text, self:Compute(m.value)) }
    end
    local idx = 1
    for i, m in ipairs(MODES) do if m.value == mode then idx = i end end
    return {
        {
            id = "uiScale",
            label = "UI-skala",
            old = ("%.3f"):format(UIParent:GetScale()),
            new = choices[idx].text, value = mode,
            choices = choices, choiceIndex = idx,
            enabled = true,
            note = ("Skjerm %dx%d. Lavere tall = mindre UI og mer av verden. Samme tall gir samme andel av skjermen på alle oppløsninger. Klikk verdien for å bytte."):format(pw or 0, ph or 0),
        },
    }
end

function Scale:Backup()
    return {
        useUiScale = GetCVar("useUiScale"),
        uiScale = GetCVar("uiScale"),
        mode = ns.db.scale.mode,
        applied = ns.db.scale.applied,
    }
end

function Scale:Apply(items)
    local item = items[1]
    if not item then return end
    ns.db.scale.mode = item.value or "auto"
    ns.db.scale.applied = true
    self:ApplyScale(ns.db.scale.mode)
end

function Scale:Restore(snap)
    ns.db.scale.mode = snap.mode or "auto"
    ns.db.scale.applied = snap.applied
    if snap.useUiScale then SetCVar("useUiScale", snap.useUiScale) end
    if snap.uiScale then SetCVar("uiScale", snap.uiScale) end
    local s = tonumber(snap.uiScale) or 1
    if snap.useUiScale == "1" then UIParent:SetScale(s) end
end

------------------------------------------------------------------------
-- Hold skalaen riktig ved login og når oppløsning/skala endres
------------------------------------------------------------------------
local function Reapply()
    if ns.db and ns.db.scale.applied then
        -- Vent ett frame så Blizzards egen UI_SCALE_CHANGED-håndtering er ferdig først
        C_Timer.After(0, function()
            ns.RunOutOfCombat(function() Scale:ApplyScale(ns.db.scale.mode) end, "skalering")
        end)
    else
        Scale:UpdateSafeArea()
    end
end

ns.On("PLAYER_ENTERING_WORLD", Reapply)
ns.On("DISPLAY_SIZE_CHANGED", Reapply)
ns.On("UI_SCALE_CHANGED", Reapply)

ns.AddCommand("scale", "regner ut og setter skalaen på nytt (valgfritt: auto, 0.64, 0.57, pixel1 ...)", function(arg)
    if arg and arg ~= "" then ns.db.scale.mode = arg:lower() end
    ns.db.scale.applied = true
    ns.RunOutOfCombat(function()
        Scale:ApplyScale(ns.db.scale.mode)
        ns.Print(("Skala satt til %.3f (%s)."):format(Scale:Compute(ns.db.scale.mode), ModeText(ns.db.scale.mode)))
    end, "skalering")
end)
