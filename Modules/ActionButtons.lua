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

-- Buttons that use action slots: colors, hotkeys and macro names. BonusActionButton is the
-- stance/form page some older clients use for warriors, druids and rogues.
local PREFIXES = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
    "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button", "BonusActionButton",
}
-- Stance and pet buttons don't use action slots (Blizzard colors them itself): short hotkeys only
local HOTKEY_ONLY = { StanceButton = 10, PetActionButton = 10 }

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
    { id = "mana", label = "Blue when low on mana",
      desc = "Clearer blue tint when you lack mana, energy or rage." },
    { id = "unusable", label = "Dark grey when unusable",
      desc = "For example the wrong form or stance, a missing reagent, or no target." },
    { id = "hotkeys", label = "Short hotkeys",
      desc = "A short key in the top right of every button: 1 on bar 1, S1 for SHIFT-1 on bar 2, C1 for CTRL-1 on bar 3. The mouse wheel shows as WU and WD." },
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

AB.options = OPTIONS -- read by the settings window

local function Cfg() return ns.db and ns.db.actionButtons end

local function Buttons()
    local list = {}
    for _, prefix in ipairs(PREFIXES) do
        for i = 1, 12 do
            local b = _G[prefix .. i]
            if b then list[#list + 1] = b end
        end
    end
    for prefix, n in pairs(HOTKEY_ONLY) do
        for i = 1, n do
            local b = _G[prefix .. i]
            if b then
                b.mlzNoColor = true
                list[#list + 1] = b
            end
        end
    end
    return list
end

------------------------------------------------------------------------
-- Colors
------------------------------------------------------------------------
local function State(cfg, action)
    if not (HasActionFn and IsUsableFn) or not HasActionFn(action) then return nil end
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
    if not cfg or not (cfg.range or cfg.mana or cfg.unusable) or btn.mlzNoColor then return end
    local icon = btn.icon or btn.Icon
    local action = btn.action
    if not icon or not action then return end
    -- the APIs are feature-detected above, so no pcall: this runs for every button several times a second
    local state = State(cfg, action)
    if not state then return end
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
    BonusActionButton = "ACTIONBUTTON", StanceButton = "SHAPESHIFTBUTTON", PetActionButton = "BONUSACTIONBUTTON",
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
    -- remember Blizzard's look, so turning short hotkeys off can put it back without a reload
    local points = {}
    for i = 1, hk:GetNumPoints() do points[i] = { hk:GetPoint(i) } end
    btn.mlzHotkeyStyled = { font = { hk:GetFont() }, points = points, justify = hk:GetJustifyH(), width = hk:GetWidth() }
    local font = (NumberFontNormal and NumberFontNormal:GetFont()) or STANDARD_TEXT_FONT
    local w = btn:GetWidth() or 36
    hk:SetFont(font, (w > 0 and w < 34) and 10 or 13, "OUTLINE") -- stance and pet buttons are smaller
    hk:ClearAllPoints()
    hk:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -2, -3)
    hk:SetJustifyH("RIGHT")
    hk:SetWidth(0)
end

local function UnstyleHotkey(btn)
    local saved, hk = btn.mlzHotkeyStyled, btn.HotKey
    if type(saved) ~= "table" or not hk then return end
    btn.mlzHotkeyStyled = nil
    if saved.font[1] then hk:SetFont(saved.font[1], saved.font[2], saved.font[3]) end
    hk:ClearAllPoints()
    for _, p in ipairs(saved.points) do hk:SetPoint(unpack(p)) end
    if saved.justify then hk:SetJustifyH(saved.justify) end
    hk:SetWidth(saved.width or 0)
    -- let Blizzard write its own text again
    if type(btn.UpdateHotkeys) == "function" then
        pcall(btn.UpdateHotkeys, btn, btn.buttonType)
    elseif type(ActionButton_UpdateHotkeys) == "function" then
        pcall(ActionButton_UpdateHotkeys, btn, btn.buttonType)
    end
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
local UnitExists = UnitExists
-- Usable and mana come from Blizzard's UpdateUsable hook. Only range changes without an event, and
-- range only exists with a target, so the poll does nothing without one (all = run once anyway).
local function Tick(all)
    local cfg = Cfg()
    if not cfg or not buttons or not (cfg.range or cfg.mana or cfg.unusable) then return end
    if all ~= true and not (cfg.range and UnitExists("target")) then return end
    for i = 1, #buttons do
        local b = buttons[i]
        if not b.mlzNoColor and b:IsVisible() then Color(b) end
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
        if cfg.hotkeys then FixHotkey(b) else UnstyleHotkey(b) end
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
    Tick(true)
end

-- A new or no target changes every button's range at once (red must go away when the target does)
ns.TryOn("PLAYER_TARGET_CHANGED", function() Tick(true) end)

------------------------------------------------------------------------
-- Module interface
------------------------------------------------------------------------
function AB:Preview()
    local items = {}
    local cur = ns.db.actionButtons
    local hasButtons = _G.ActionButton1 ~= nil
    for _, o in ipairs(OPTIONS) do
        local isOn = (cur and cur[o.id]) and true or false
        local item = {
            id = o.id, label = o.label, group = "Action bars", note = o.desc,
            toggle = true, isOn = isOn, offText = "default",
            old = isOn and "on" or "default",
            new = "on",
            enabled = hasButtons and (isOn or ns.Enabled("actionbuttons", o.id, true)),
        }
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
    for _, item in ipairs(items) do cfg[item.id] = item.enabled or nil end -- unticked = turn off
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

-- Public API (settings window)
function AB:IsOn(id) return (ns.db.actionButtons and ns.db.actionButtons[id]) and true or false end

function AB:Set(id, on)
    ns.db.actionButtons = ns.db.actionButtons or {}
    ns.db.actionButtons[id] = on and true or nil
    -- Blizzard's hotkey redraw is kept out of combat to stay clear of the action buttons there
    if id == "hotkeys" and not on then
        ns.RunOutOfCombat(function() self:Refresh() end, "hotkey text", true)
    else
        self:Refresh()
    end
    ns.FireState()
end

ns.AddCommand("buttons", "turns action button colors for range, mana and usability on or off", function()
    local cfg = Cfg()
    if not cfg then ns.Print("Not set up. Run /mlz install.") return end
    local on = not (cfg.range or cfg.mana or cfg.unusable)
    cfg.range, cfg.mana, cfg.unusable = on, on, on
    AB:Refresh()
    ns.Print("Action button coloring:", on and "on" or "off")
end)
