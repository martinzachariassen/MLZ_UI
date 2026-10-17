-- MLZ UI: Mana tick / five-second rule bar
-- A thin bar under the player frame.
--   Mana users: after you spend mana the bar fills up over 5 seconds (orange). That is the
--   "five-second rule": spirit regen is off until it is full. After that the bar shows the
--   2-second regen tick (blue), so you can time a cast just after a tick.
--   Energy users (rogues, druids in Cat Form): the bar shows the 2-second energy tick (yellow).
--   Druids in Bear Form: the bar keeps showing mana, so you can time a shift out to heal or cast.
-- Hidden when your mana/energy is full out of combat, and for rage (warriors).
-- Off until you turn it on in /mlz > Helpers. The bar can be moved there too.

local _, ns = ...

local MT = {}
ns.ManaTick = MT

local MANA, RAGE, ENERGY = 0, 1, 3
local FIVE, TICK = 5, 2
local COLORS = {
    five   = { 1.00, 0.55, 0.10 },
    mana   = { 0.30, 0.55, 1.00 },
    energy = { 1.00, 0.85, 0.20 },
    bg     = { 0, 0, 0, 0.55 },
    spark  = { 1, 1, 1, 0.9 },
}

-- In combat the client can hand back "secret" numbers. Addon code may not compare or calculate with them,
-- so Num() gives a plain number or nil and callers skip the maths when it is nil.
local issecretvalue = issecretvalue
local function Num(v)
    if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
    return v
end

local function Full(power)
    local cur, max = Num(UnitPower("player", power)), Num(UnitPowerMax("player", power))
    if not (cur and max) then return false end
    return cur >= max
end

local function Cfg()
    ns.db.manaTick = ns.db.manaTick or {}
    return ns.db.manaTick
end

local bar
local lastPower, lastSpend, lastTick = {}, 0, {}
local testing = false

local function Anchor()
    local cfg = Cfg()
    bar:ClearAllPoints()
    if cfg.point then
        bar:SetPoint(cfg.point, UIParent, cfg.relPoint or cfg.point, cfg.x or 0, cfg.y or 0)
        bar:SetWidth(cfg.w or 120)
        return
    end
    local mana = _G.PlayerFrameManaBar
    if mana and mana.GetWidth and (mana:GetWidth() or 0) > 20 then
        bar:SetPoint("TOPLEFT", mana, "BOTTOMLEFT", 0, -3)
        bar:SetPoint("TOPRIGHT", mana, "BOTTOMRIGHT", 0, -3)
    else
        bar:SetPoint("TOP", PlayerFrame or UIParent, "BOTTOM", 30, 8)
        bar:SetWidth(120)
    end
end

local function Build()
    if bar then return end
    bar = CreateFrame("StatusBar", "MLZUI_ManaTickBar", UIParent)
    bar:SetSize(120, 5)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetMinMaxValues(0, 1)
    bar:SetFrameStrata("MEDIUM")
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(COLORS.bg))
    bar.spark = bar:CreateTexture(nil, "OVERLAY")
    bar.spark:SetColorTexture(unpack(COLORS.spark))
    bar.spark:SetSize(2, 9)
    -- Mana in numbers under the bar, only while a druid is in Bear Form (the bar itself is too thin for text)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("TOP", bar, "BOTTOM", 0, -2)
    bar.text:SetTextColor(unpack(COLORS.mana))
    bar.text:Hide()
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function(self) if testing then self:StartMoving() end end)
    bar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint(1)
        local cfg = Cfg()
        cfg.point, cfg.relPoint, cfg.x, cfg.y = point, relPoint, math.floor(x + 0.5), math.floor(y + 0.5)
        local w = math.floor(self:GetWidth() + 0.5)
        cfg.w = w
        self:ClearAllPoints()
        self:SetPoint(cfg.point, UIParent, cfg.relPoint, cfg.x, cfg.y)
        self:SetWidth(w)
    end)
    bar:Hide()
    Anchor()
end

local function PowerKind()
    local t = UnitPowerType("player")
    if t == MANA then return "mana" end
    if t == ENERGY then return "energy" end
    -- A druid in Bear Form still has mana to protect (shifting out to heal or cast), so the bar keeps showing it.
    -- Mana does not tick while shapeshifted, so the second value tells OnUpdate to show the level, not a tick.
    if t == RAGE and ns.PlayerClass() == "DRUID" then return "mana", true end
end

local function OnUpdate(self)
    local now = GetTime()
    if testing then
        self.text:Hide()
        self.spark:Show()
        self:SetMinMaxValues(0, 1)
        self:SetValue((now % TICK) / TICK)
        self:SetStatusBarColor(unpack(COLORS.mana))
        self.spark:SetPoint("CENTER", self, "LEFT", self:GetValue() * self:GetWidth(), 0)
        return
    end
    local kind, shifted = PowerKind()
    local value, color
    if shifted then
        local cur, max = UnitPower("player", MANA), UnitPowerMax("player", MANA)
        color = COLORS.mana
        -- the bar scales the value itself, so this works with secret numbers too
        self:SetMinMaxValues(0, max)
        self:SetValue(cur)
        self.text:SetFormattedText("%s / %s", cur, max)
        self.text:Show()
        self:SetStatusBarColor(unpack(color))
        self.spark:Hide()
        return
    elseif kind == "mana" and now - lastSpend < FIVE then
        value, color = (now - lastSpend) / FIVE, COLORS.five
    elseif kind and lastTick[kind] then
        value, color = ((now - lastTick[kind]) % TICK) / TICK, COLORS[kind]
    else
        value, color = 0, COLORS[kind or "mana"]
    end
    self.text:Hide()
    self:SetMinMaxValues(0, 1)
    self.spark:Show()
    self:SetValue(value)
    self:SetStatusBarColor(unpack(color))
    self.spark:SetPoint("CENTER", self, "LEFT", value * self:GetWidth(), 0)
end

-- Shown when the feature is on, the power is mana or energy, and it isn't full (or you are fighting)
local function UpdateShown()
    if not bar then return end
    local cfg = Cfg()
    if testing then bar:Show() return end
    local kind = cfg.enabled and PowerKind()
    local show = false
    if kind == "mana" and not cfg.noMana then
        show = not Full(MANA) or InCombatLockdown()
    elseif kind == "energy" and not cfg.noEnergy then
        show = not Full(ENERGY) or InCombatLockdown()
    end
    if UnitIsDeadOrGhost("player") then show = false end
    bar:SetShown(show)
end

local function OnPower(_, unit, powerToken)
    if unit ~= "player" then return end
    local now = GetTime()
    for kind, id in pairs({ mana = MANA, energy = ENERGY }) do
        if not powerToken or powerToken == (kind == "mana" and "MANA" or "ENERGY") then
            local p = Num(UnitPower("player", id))
            local old = lastPower[kind]
            if p and old then
                if p < old and kind == "mana" then
                    lastSpend = now
                elseif p > old then
                    -- a regen tick (big jumps such as potions also land here; the next real tick corrects it)
                    lastTick[kind] = now
                end
            end
            if p then lastPower[kind] = p end
        end
    end
    UpdateShown()
end

local function Start()
    Build()
    bar:SetScript("OnUpdate", OnUpdate)
    lastPower.mana = Num(UnitPower("player", MANA))
    lastPower.energy = Num(UnitPower("player", ENERGY))
    UpdateShown()
end

local registered = false
local function Register()
    if registered then return end
    registered = true
    ns.TryOn("UNIT_POWER_FREQUENT", OnPower)
    ns.TryOn("UNIT_POWER_UPDATE", OnPower)
    ns.TryOn("UNIT_DISPLAYPOWER", function(_, unit) if unit == "player" then UpdateShown() end end)
    ns.TryOn("UPDATE_SHAPESHIFT_FORM", UpdateShown)
    ns.TryOn("PLAYER_REGEN_DISABLED", UpdateShown)
    ns.TryOn("PLAYER_REGEN_ENABLED", UpdateShown)
    ns.TryOn("PLAYER_DEAD", UpdateShown)
    ns.TryOn("PLAYER_UNGHOST", UpdateShown)
end

ns.On("PLAYER_ENTERING_WORLD", function()
    if ns.db and Cfg().enabled then
        Register()
        Start()
    end
end)

------------------------------------------------------------------------
-- Public API (settings window)
------------------------------------------------------------------------
function MT.IsOn() return Cfg().enabled and true or false end
function MT.SetOn(on)
    Cfg().enabled = on and true or false
    if on then
        Register()
        Start()
    else
        testing = false
        if bar then bar:Hide() end
    end
    ns.FireState()
end
function MT.Get(key) return Cfg()[key] and true or false end
function MT.Set(key, on) Cfg()[key] = on and true or false; UpdateShown(); ns.FireState() end

-- Move mode: the bar shows a test animation and can be dragged with the left mouse button
function MT.IsMoving() return testing end
function MT.SetMoving(on)
    Build()
    testing = on and true or false
    bar:EnableMouse(testing)
    bar:SetScript("OnUpdate", OnUpdate)
    if not testing and not Cfg().enabled then bar:Hide() else UpdateShown() end
    ns.FireState()
end
function MT.ResetPosition()
    local cfg = Cfg()
    cfg.point, cfg.relPoint, cfg.x, cfg.y, cfg.w = nil, nil, nil, nil, nil
    if bar then Anchor() end
    ns.FireState()
end
