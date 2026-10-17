-- MLZ UI: Scaling
-- Pixel-perfect: one UI pixel = k physical pixels  =>  scale = k * 768 / screen height.
-- The mode is saved (not the number itself), so the scale is recalculated if the resolution changes.
-- Blizzard does not allow uiScale below 0.64 via CVar, so below that UIParent:SetScale is set directly.

local _, ns = ...

local Scale = ns.RegisterModule({ key = "scale", title = "Scaling" })

local CVAR_MIN, CVAR_MAX = 0.64, 1.15

local MODES = {
    { value = "auto",    text = "Auto (recommended)" },
    { value = "0.71",    text = "Normal 0.71" },
    { value = "0.64",    text = "Compact 0.64" },
    { value = "0.57",    text = "Extra compact 0.57" },
    { value = "0.50",    text = "Minimal 0.50" },
    { value = "pixel1",  text = "Pixel-perfect (768/height)" },
    { value = "1.00",    text = "Blizzard default 1.00" },
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
        -- Pixel-perfect if that gives a sensible size (1080p = 0.71, 1440p = 0.53),
        -- otherwise compact 0.64. Fixed scale = same share of the screen at every resolution.
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

-- The actual application. Called on Apply and on login/resolution change if the user has accepted scaling.
local applying = false
local function DoApply(self, mode)
    local s = self:Compute(mode)
    local cvarValue = math.max(s, CVAR_MIN)
    if GetCVar("useUiScale") ~= "1" then SetCVar("useUiScale", "1") end
    local current = tonumber(GetCVar("uiScale")) or 0
    if math.abs(current - cvarValue) > 0.0005 then SetCVar("uiScale", ("%.6f"):format(cvarValue)) end
    -- Set UIParent directly as well: below 0.64 the CVar can't go that low, and coming back up from
    -- e.g. 0.57 to 0.64 the CVar may already say 0.64, so nothing would change without this.
    if math.abs(UIParent:GetScale() - s) > 0.0005 then
        UIParent:SetScale(s)
    end
    self:UpdateSafeArea()
    ns.Debug(("scale %.4f (mode %s, height %d)"):format(s, tostring(mode), ScreenHeight()))
end

function Scale:ApplyScale(mode)
    if applying then return end
    applying = true
    local ok, err = pcall(DoApply, self, mode)
    applying = false -- always reset, even if something above failed
    if not ok then ns.Print(ns.Paint("red", "Could not change the UI scale:"), err) end
end

-- Accepts the listed modes and plain numbers between 0.4 and 1.15
function Scale:ValidMode(mode)
    for _, m in ipairs(MODES) do if m.value == mode then return true end end
    local n = tonumber(mode)
    return n ~= nil and n >= 0.4 and n <= CVAR_MAX
end

-- MLZ_Safe: a centered 16:9 container that our own frames can anchor to,
-- so the HUD doesn't spread out on ultrawide.
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
-- Module interface
------------------------------------------------------------------------
-- True when this mode is already saved and the screen is already at that scale
function Scale:IsCurrent(mode)
    return ns.db.scale.applied and (ns.db.scale.mode or "auto") == mode
        and math.abs(UIParent:GetScale() - self:Compute(mode)) < 0.001
end

function Scale:Preview()
    local pw, ph = GetPhysicalScreenSize()
    local mode = ns.db.scale.mode or "auto"
    local choices = {}
    for i, m in ipairs(MODES) do
        choices[i] = { value = m.value, text = ("%s  =  %.3f"):format(m.text, self:Compute(m.value)) }
    end
    local idx = 1
    for i, m in ipairs(MODES) do if m.value == mode then idx = i end end
    if idx == 1 and mode ~= "auto" and self:ValidMode(mode) then
        -- a number typed with /mlz scale: keep it in the list so the row shows what is saved
        choices[#choices + 1] = { value = mode, text = ("Your own %s  =  %.3f"):format(tostring(mode), self:Compute(mode)) }
        idx = #choices
    end
    return {
        {
            id = "uiScale",
            label = "UI scale",
            old = ("%.3f"):format(UIParent:GetScale()),
            new = choices[idx].text, value = mode,
            choices = choices, choiceIndex = idx,
            enabled = ns.Enabled("scale", "uiScale", true),
            alreadySet = self:IsCurrent(mode),
            note = ("Screen %dx%d. Lower number = smaller UI and more of the world. The same number gives the same share of the screen at every resolution. Click the value to change it."):format(pw or 0, ph or 0),
        },
    }
end

function Scale:OnChoice(item)
    item.alreadySet = self:IsCurrent(item.value)
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
    -- Go through ApplyScale when a scale was in use before, so the saved mode and the screen agree
    -- (a mode below 0.64 is only reachable through UIParent:SetScale, the CVar says 0.64)
    if snap.applied then
        self:ApplyScale(ns.db.scale.mode)
        return
    end
    local s = tonumber(snap.uiScale) or 1
    if snap.useUiScale == "1" then UIParent:SetScale(s) end
    self:UpdateSafeArea()
end

------------------------------------------------------------------------
-- Keep the scale correct on login and when resolution/scale changes
------------------------------------------------------------------------
local function Reapply()
    if ns.db and ns.db.scale.applied then
        -- Wait one frame so Blizzard's own UI_SCALE_CHANGED handling finishes first
        C_Timer.After(0, function()
            ns.RunOutOfCombat(function() Scale:ApplyScale(ns.db.scale.mode) end, "scaling")
        end)
    else
        Scale:UpdateSafeArea()
    end
end

ns.On("PLAYER_ENTERING_WORLD", Reapply)
ns.On("DISPLAY_SIZE_CHANGED", Reapply)
ns.On("UI_SCALE_CHANGED", Reapply)

------------------------------------------------------------------------
-- Public API (settings window)
------------------------------------------------------------------------
Scale.MODES = MODES

function Scale:ModeText(mode) return ModeText(mode or "auto") end

function Scale:Mode() return ns.db.scale.mode or "auto" end

function Scale:IsApplied() return ns.db.scale.applied and true or false end

-- Saves and applies a mode (waits for combat to end). onDone runs after it is applied.
function Scale:SetMode(mode, onDone)
    ns.db.scale.mode = mode or "auto"
    ns.db.scale.applied = true
    ns.RunOutOfCombat(function()
        Scale:ApplyScale(ns.db.scale.mode)
        ns.FireState()
        if onDone then onDone() end
    end, "scaling")
end

ns.AddCommand("scale", "recalculates and reapplies the scale (optional: auto, 0.64, 0.57, pixel1 ...)", function(arg)
    local mode = (arg and arg ~= "") and arg:lower() or ns.db.scale.mode
    if not Scale:ValidMode(mode) then
        ns.Print("Unknown scale", tostring(mode) .. ". Use auto, pixel1 or a number from 0.4 to 1.15.")
        return
    end
    Scale:SetMode(mode, function()
        ns.Print(("Scale set to %.3f (%s)."):format(Scale:Compute(ns.db.scale.mode), ModeText(ns.db.scale.mode)))
    end)
end)
