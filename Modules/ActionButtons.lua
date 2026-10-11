-- MLZ UI: Action buttons
-- Makes it easy to see WHY a button can't be used, like tullaRange / Bartender4 / ElvUI do:
--   red   = target is out of range
--   blue  = not enough mana / energy / rage
--   grey  = can't be used right now (wrong form, missing reagent, etc.)
-- Also short, clear hotkeys (S1 = Shift+1, C1 = Ctrl+1) and hidden macro names.
--
-- Only changes the color of the icon texture and text, never the buttons themselves, so it is safe in combat and causes no taint.

local _, ns = ...

local AB = ns.RegisterModule({ key = "actionbuttons", title = "Action buttons" })

local PREFIXES = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
    "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
}

local COLORS = {
    range    = { 0.95, 0.20, 0.20 },  -- out of range
    mana     = { 0.30, 0.45, 1.00 },  -- not enough resource
    unusable = { 0.30, 0.30, 0.30 },  -- can't be used
    -- Blizzard's own colors, used when a feature is turned off
    bzMana     = { 0.5, 0.5, 1.0 },
    bzUnusable = { 0.4, 0.4, 0.4 },
    normal   = { 1, 1, 1 },
}

local OPTIONS = {
    { id = "range", label = "Red when out of range",
      desc = "The whole icon turns red when the target is too far away, not just the hotkey text." },
    { id = "mana", label = "Blue when low on mana/resource",
      desc = "Clearer blue tint when you lack mana, energy or rage." },
    { id = "unusable", label = "Dark grey when unusable",
      desc = "Wrong form/stance, missing reagent, requires a target, etc." },
    { id = "hotkeys", label = "Short hotkeys",
      desc = "Short, clear key in the top right of every button: 1 on bar 1, S1 (Shift+1) on bar 2, C1 (Ctrl+1) on bar 3. Mouse wheel is shown as SWU/CWU." },
    { id = "macroNames", label = "Hide macro names",
      desc = "Macro names are not shown on the button (the icon is enough)." },
}

------------------------------------------------------------------------
-- API (names have moved between client versions)
------------------------------------------------------------------------
local CAB = C_ActionBar or {}
local HasActionFn = CAB.HasAction or HasAction
local IsUsableFn = CAB.IsUsableAction or IsUsableAction
local InRangeFn = CAB.IsActionInRange or IsActionInRange

local function Cfg() return ns.db and ns.db.actionButtons end

local function Buttons()
    local list = {}
    for _, prefix in ipairs(PREFIXES) do
        for i = 1, 12 do
            local b = _G[prefix .. i]
            if b then list[#list + 1] = b end
        end
    end
    return list
end

------------------------------------------------------------------------
-- Colors
------------------------------------------------------------------------
local function State(cfg, action)
    if not HasActionFn or not HasActionFn(action) then return nil end
    local usable, noMana = IsUsableFn(action)
    if cfg.range and InRangeFn then
        local r = InRangeFn(action)
        if r == false or r == 0 then return "range" end
    end
    if noMana then return cfg.mana and "mana" or "bzMana" end
    if not usable then return cfg.unusable and "unusable" or "bzUnusable" end
    return "normal"
end

local colored = {} -- buttons we have colored, so we can reset them

local function Color(btn, force)
    local cfg = Cfg()
    if not cfg or not (cfg.range or cfg.mana or cfg.unusable) then return end
    local icon = btn.icon or btn.Icon
    local action = btn.action
    if not icon or not action then return end
    local ok, state = pcall(State, cfg, action)
    if not ok or not state then return end
    if force or btn.mlzState ~= state then
        local c = COLORS[state]
        icon:SetVertexColor(c[1], c[2], c[3])
        btn.mlzState = state
        colored[btn] = true
    end
end

------------------------------------------------------------------------
-- Hotkeys and macro names
------------------------------------------------------------------------
-- Binding command per button prefix (used if the button has no commandName of its own)
local COMMANDS = {
    ActionButton = "ACTIONBUTTON", MultiBarBottomLeftButton = "MULTIACTIONBAR1BUTTON",
    MultiBarBottomRightButton = "MULTIACTIONBAR2BUTTON", MultiBarRightButton = "MULTIACTIONBAR3BUTTON",
    MultiBarLeftButton = "MULTIACTIONBAR4BUTTON", MultiBar5Button = "MULTIACTIONBAR5BUTTON",
    MultiBar6Button = "MULTIACTIONBAR6BUTTON", MultiBar7Button = "MULTIACTIONBAR7BUTTON",
}

local KEYNAMES = {
    MOUSEWHEELUP = "WU", MOUSEWHEELDOWN = "WD", BUTTON3 = "M3", BUTTON4 = "M4", BUTTON5 = "M5",
    SPACE = "Spc", BACKSPACE = "Bs", INSERT = "Ins", DELETE = "Del", HOME = "Hm", END = "End",
    PAGEUP = "PU", PAGEDOWN = "PD", TAB = "Tab", ENTER = "Ent", ESCAPE = "Esc",
    UP = "Up", DOWN = "Dn", LEFT = "Lt", RIGHT = "Rt", CAPSLOCK = "Cap",
}
local MODS = { { "ALT%-", "A" }, { "CTRL%-", "C" }, { "SHIFT%-", "S" } }

local function Command(btn)
    if btn.commandName then return btn.commandName end
    local name = btn:GetName()
    if not name then return nil end
    local prefix, num = name:match("^(.-)(%d+)$")
    return prefix and COMMANDS[prefix] and (COMMANDS[prefix] .. num)
end

-- "SHIFT-1" -> "S1", "CTRL-Q" -> "CQ", "ALT-CTRL-2" -> "AC2", "SHIFT-MOUSEWHEELUP" -> "SWU"
local function ShortKey(key)
    local base, mods = key, ""
    for _, m in ipairs(MODS) do
        if base:find(m[1]) then base = base:gsub(m[1], "") mods = mods .. m[2] end
    end
    local num = base:match("^NUMPAD(.+)$")
    if num then base = "N" .. num end
    base = KEYNAMES[base] or base
    return mods .. base
end

local function StyleHotkey(btn, hk)
    if btn.mlzHotkeyStyled then return end
    btn.mlzHotkeyStyled = true
    local font = (NumberFontNormal and NumberFontNormal:GetFont()) or STANDARD_TEXT_FONT
    hk:SetFont(font, 13, "OUTLINE")
    hk:ClearAllPoints()
    hk:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -2, -3)
    hk:SetJustifyH("RIGHT")
    hk:SetWidth(0)
end

local function FixHotkey(btn)
    local cfg = Cfg()
    local hk = btn.HotKey
    if not cfg or not cfg.hotkeys or not hk then return end
    local cmd = Command(btn)
    local key = cmd and GetBindingKey(cmd)
    if not key then return end -- no key: let Blizzard show the range dot as before
    StyleHotkey(btn, hk)
    hk:SetText(ShortKey(key))
    hk:SetAlpha(1)
    hk:Show()
end

local function FixName(btn)
    local cfg = Cfg()
    local name = btn.Name
    if not cfg or not name then return end
    name:SetAlpha(cfg.macroNames and 0 or 1)
end

------------------------------------------------------------------------
-- Hooks and update loop
------------------------------------------------------------------------
local hooked = {}

local function HookButton(btn)
    if hooked[btn] then return end
    hooked[btn] = true
    -- Blizzard resets the color in UpdateUsable; we color right after so it doesn't flicker
    if type(btn.UpdateUsable) == "function" then
        hooksecurefunc(btn, "UpdateUsable", function(self) Color(self, true) end)
    end
    if type(btn.UpdateHotkeys) == "function" then
        hooksecurefunc(btn, "UpdateHotkeys", FixHotkey)
    end
    if type(btn.UpdateAction) == "function" then
        hooksecurefunc(btn, "UpdateAction", function(self) self.mlzState = nil; Color(self, true) end)
    end
end

local globalsHooked = false
local function HookGlobals()
    if globalsHooked then return end
    globalsHooked = true
    -- Older clients use global functions instead of methods
    if type(ActionButton_UpdateUsable) == "function" then
        hooksecurefunc("ActionButton_UpdateUsable", function(self) Color(self, true) end)
    end
    if type(ActionButton_UpdateHotkeys) == "function" then
        hooksecurefunc("ActionButton_UpdateHotkeys", FixHotkey)
    end
end

local buttons
local function Tick()
    local cfg = Cfg()
    if not cfg or not (cfg.range or cfg.mana or cfg.unusable) then return end
    for i = 1, #buttons do
        local b = buttons[i]
        if b:IsVisible() then Color(b) end
    end
end

local ticker
function AB:Refresh()
    local cfg = Cfg()
    if not cfg then return end
    buttons = buttons or Buttons()
    HookGlobals()
    for _, b in ipairs(buttons) do
        HookButton(b)
        FixName(b)
        if cfg.hotkeys then FixHotkey(b) end
        b.mlzState = nil
    end
    -- If colors are turned off: reset to normal (Blizzard takes over on the next update)
    if not (cfg.range or cfg.mana or cfg.unusable) then
        for b in pairs(colored) do
            local icon = b.icon or b.Icon
            if icon then icon:SetVertexColor(1, 1, 1) end
            b.mlzState = nil
        end
        wipe(colored)
    end
    if not ticker then ticker = C_Timer.NewTicker(0.2, Tick) end
    Tick()
end

------------------------------------------------------------------------
-- Module interface
------------------------------------------------------------------------
function AB:Preview()
    local items = {}
    local cur = ns.db.actionButtons
    local hasButtons = _G.ActionButton1 ~= nil
    for _, o in ipairs(OPTIONS) do
        local item = {
            id = o.id, label = o.label, group = "Action bars", note = o.desc,
            old = (cur and cur[o.id]) and "on" or "default",
            new = "on",
            enabled = hasButtons and ns.Enabled("actionbuttons", o.id, true),
        }
        if cur and cur[o.id] then item.alreadySet = true end
        if not hasButtons then item.unavailable, item.new = true, "no buttons found" end
        items[#items + 1] = item
    end
    return items
end

function AB:Backup()
    return { cfg = ns.CopyTable(ns.db.actionButtons) }
end

function AB:Apply(items)
    local cfg = ns.CopyTable(ns.db.actionButtons) or {}
    for _, item in ipairs(items) do cfg[item.id] = true end
    ns.db.actionButtons = cfg
    self:Refresh()
end

function AB:Restore(snap)
    ns.db.actionButtons = snap.cfg or { }
    self:Refresh()
    if not snap.cfg then ns.db.actionButtons = nil end
end

ns.On("PLAYER_ENTERING_WORLD", function()
    if Cfg() then AB:Refresh() end
end)

ns.On("UPDATE_BINDINGS", function()
    local cfg = Cfg()
    if not (cfg and cfg.hotkeys and buttons) then return end
    for _, b in ipairs(buttons) do FixHotkey(b) end
end)

ns.AddCommand("buttons", "toggles action button coloring on/off (range/mana/unusable)", function()
    local cfg = Cfg()
    if not cfg then ns.Print("Not set up. Run /mlz install.") return end
    local on = not (cfg.range or cfg.mana or cfg.unusable)
    cfg.range, cfg.mana, cfg.unusable = on, on, on
    AB:Refresh()
    ns.Print("Action button coloring:", on and "on" or "off")
end)
