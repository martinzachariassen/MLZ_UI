-- MLZ UI: test stub for the WoW API
-- A small fake client so tests/load.lua can load the addon in plain Lua 5.1.
-- Globals the addon only uses behind a feature check stay nil, so the fallbacks run too.
-- When the load test fails on a missing API that the addon calls without a check, add it here.

local stub = {
    chat = {},      -- every line sent to DEFAULT_CHAT_FRAME
    timers = {},    -- queued C_Timer callbacks
    frames = {},    -- frames with registered events: frames[i] = frame
    time = 1000,
}

------------------------------------------------------------------------
-- Lua extensions the client adds (and 5.1 names on newer Lua, for local runs)
------------------------------------------------------------------------
unpack = unpack or table.unpack            -- luacheck: ignore 121
loadstring = loadstring or load            -- luacheck: ignore 121

strlower = string.lower
strupper = string.upper
strsub = string.sub
strfind = string.find
strlen = string.len
strrep = string.rep
format = string.format
tinsert = table.insert
tremove = table.remove
floor = math.floor
ceil = math.ceil
min = math.min
max = math.max
abs = math.abs

function strtrim(s, chars)
    s = tostring(s or "")
    if chars then
        local set = "[" .. chars:gsub("%p", "%%%0") .. "]"
        return (s:gsub("^" .. set .. "+", ""):gsub(set .. "+$", ""))
    end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function strsplit(sep, s, limit)
    local out, pos = {}, 1
    s = tostring(s or "")
    while true do
        if limit and #out == limit - 1 then break end
        local a, b = s:find(sep, pos, true)
        if not a then break end
        out[#out + 1] = s:sub(pos, a - 1)
        pos = b + 1
    end
    out[#out + 1] = s:sub(pos)
    return unpack(out)
end

function strjoin(sep, ...) return table.concat({ ... }, sep) end

function wipe(t)
    for k in pairs(t) do t[k] = nil end
    return t
end

function tContains(t, v)
    for _, x in ipairs(t) do if x == v then return true end end
    return false
end

function hooksecurefunc(a, b, c)
    local t, name, hook = _G, a, b
    if type(a) == "table" then t, name, hook = a, b, c end
    local orig = t[name]
    if type(orig) ~= "function" then return end
    t[name] = function(...)
        local r = { orig(...) }
        hook(...)
        return unpack(r)
    end
end

function issecure() return false end
function issecretvalue() return false end
function securecall(f, ...) return f(...) end
function debugstack() return "" end
function geterrorhandler() return function(e) error(e, 0) end end

date = os.date
time = os.time

bit = bit or {
    band = function(a, b)
        local r, p = 0, 1
        while a > 0 and b > 0 do
            if a % 2 == 1 and b % 2 == 1 then r = r + p end
            a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2
        end
        return r
    end,
}

------------------------------------------------------------------------
-- Frames: every method exists. Setters are no-ops, a few getters return useful values.
------------------------------------------------------------------------
local Frame = {}
local NewObject

local GETTERS = {
    GetWidth = 100, GetHeight = 20, GetScale = 1, GetEffectiveScale = 1, GetAlpha = 1,
    GetLeft = 0, GetRight = 100, GetTop = 20, GetBottom = 0, GetNumPoints = 0, GetFrameLevel = 1,
    GetStringWidth = 50, GetStringHeight = 12, GetUnboundedStringWidth = 50, GetVerticalScroll = 0,
    GetHorizontalScroll = 0, GetVerticalScrollRange = 0, GetValue = 0, GetNumLines = 0,
    GetFrameStrata = "MEDIUM", GetObjectType = "Frame", GetNumRegions = 0, GetNumChildren = 0,
    GetCursorPosition = 0, GetNumLetters = 0, GetID = 0, GetMaxLetters = 0, GetLineHeight = 12,
}

local methods = {}
function methods:Show() self.__shown = true end
function methods:Hide() self.__shown = false end
function methods:SetShown(v) self.__shown = v and true or false end
function methods:IsShown() return self.__shown ~= false end
function methods:IsVisible() return self.__shown ~= false end
function methods:SetScript(name, fn) self.__scripts[name] = fn end
function methods:GetScript(name) return self.__scripts[name] end
function methods:HasScript() return true end
function methods:HookScript(name, fn)
    local old = self.__scripts[name]
    self.__scripts[name] = function(...)
        if old then old(...) end
        return fn(...)
    end
end
function methods:RegisterEvent(event)
    self.__events[event] = true
    stub.frames[self] = true
end
function methods:RegisterUnitEvent(event) return methods.RegisterEvent(self, event) end
function methods:UnregisterEvent(event) self.__events[event] = nil end
function methods:UnregisterAllEvents() self.__events = {} end
function methods:IsEventRegistered(event) return self.__events[event] == true end
function methods:GetName() return self.__name end
function methods:GetParent() return self.__parent end
function methods:SetParent(p) self.__parent = p end
function methods:SetText(t) self.__text = t end
function methods:GetText() return self.__text or "" end
function methods:SetFormattedText(fmt, ...) self.__text = fmt:format(...) end
function methods:SetChecked(v) self.__checked = v and true or false end
function methods:GetChecked() return self.__checked or false end
function methods:SetMinMaxValues(a, b) self.__min, self.__max = a, b end
function methods:GetMinMaxValues() return self.__min or 0, self.__max or 1 end
function methods:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function methods:GetCenter() return 50, 10 end
function methods:GetSize() return 100, 20 end
function methods:GetRect() return 0, 0, 100, 20 end
function methods:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function methods:GetTextColor() return 1, 1, 1, 1 end
function methods:GetVertexColor() return 1, 1, 1, 1 end
function methods:GetShadowOffset() return 0, 0 end
function methods:GetRegions() end
function methods:GetChildren() end
function methods:IsForbidden() return false end
function methods:IsProtected() return false end
function methods:IsMouseOver() return false end
function methods:IsEnabled() return true end
function methods:IsObjectType() return false end
function methods:IsTruncated() return false end
function methods:CanChangeProtectedState() return true end
function methods:GetFontObject() return NewObject("Font") end
function methods:CreateTexture() return NewObject("Texture", nil, self) end
function methods:CreateMaskTexture() return NewObject("MaskTexture", nil, self) end
function methods:CreateLine() return NewObject("Line", nil, self) end
function methods:CreateFontString() return NewObject("FontString", nil, self) end
function methods:CreateAnimationGroup() return NewObject("AnimationGroup", nil, self) end
function methods:CreateAnimation() return NewObject("Animation", nil, self) end
function methods:GetStatusBarTexture() return self.__tex or methods.CreateTexture(self) end
function methods:GetNormalTexture() return methods.CreateTexture(self) end
function methods:GetHighlightTexture() return methods.CreateTexture(self) end
function methods:GetPushedTexture() return methods.CreateTexture(self) end
function methods:GetFontString() return methods.CreateFontString(self) end
function methods:GetScrollChild() return self.__child end
function methods:SetScrollChild(c) self.__child = c end
function methods:NumLines() return 0 end
function methods:GetOwner() return self.__owner end
function methods:SetOwner(o) self.__owner = o end

Frame.__index = function(t, k)
    local m = methods[k]
    if m then return m end
    local g = GETTERS[k]
    if g ~= nil then return function() return g end end
    if type(k) == "string" and k:match("^[A-Z]") then
        return function() end -- setters and anything else: no-op
    end
end

function NewObject(kind, name, parent)
    local o = setmetatable({ __kind = kind, __name = name, __parent = parent, __scripts = {}, __events = {} }, Frame)
    if name then _G[name] = o end
    return o
end
stub.NewObject = NewObject

function CreateFrame(kind, name, parent)
    local f = NewObject(kind or "Frame", name, parent)
    if kind == "ScrollFrame" then f.ScrollBar = NewObject("Slider", nil, f) end
    if kind == "GameTooltip" and name then
        _G[name .. "TextLeft1"] = NewObject("FontString")
    end
    return f
end

function CreateFont(name)
    local f = NewObject("Font", name)
    return f
end

function CreateColor(r, g, b, a)
    return {
        r = r, g = g, b = b, a = a,
        GetRGB = function() return r, g, b end,
        GetRGBA = function() return r, g, b, a end,
        WrapTextInColorCode = function(_, s) return s end,
    }
end

------------------------------------------------------------------------
-- Well-known frames
------------------------------------------------------------------------
UIParent = CreateFrame("Frame", "UIParent")
WorldFrame = CreateFrame("Frame", "WorldFrame")
GameTooltip = CreateFrame("GameTooltip", "GameTooltip")
ItemRefTooltip = CreateFrame("GameTooltip", "ItemRefTooltip")
Minimap = CreateFrame("Minimap", "Minimap")
MinimapCluster = CreateFrame("Frame", "MinimapCluster")
PlayerFrame = CreateFrame("Frame", "PlayerFrame")
TargetFrame = CreateFrame("Frame", "TargetFrame")
ChatFontNormal = CreateFont("ChatFontNormal")
NumberFontNormal = CreateFont("NumberFontNormal")
GameFontNormal = CreateFont("GameFontNormal")
GameFontHighlight = CreateFont("GameFontHighlight")
GameFontNormalSmall = CreateFont("GameFontNormalSmall")
GameFontHighlightSmall = CreateFont("GameFontHighlightSmall")
GameFontDisableSmall = CreateFont("GameFontDisableSmall")

DEFAULT_CHAT_FRAME = CreateFrame("ScrollingMessageFrame", "ChatFrame1")
function DEFAULT_CHAT_FRAME:AddMessage(msg) stub.chat[#stub.chat + 1] = tostring(msg) end
NUM_CHAT_WINDOWS = 10
for i = 2, NUM_CHAT_WINDOWS do CreateFrame("ScrollingMessageFrame", "ChatFrame" .. i) end

UISpecialFrames = {}
SlashCmdList = {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
DAMAGE_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
DEFAULT_CHATFRAME_ALPHA = 0.25
CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA = 0.2
CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA = 0.4
MAX_PLAYER_LEVEL = 60
NUM_BAG_SLOTS = 4
INVSLOT_MAINHAND = 16
INVSLOT_OFFHAND = 17
RAID_CLASS_COLORS = setmetatable({}, {
    __index = function() return { r = 1, g = 1, b = 1, colorStr = "ffffffff" } end,
})

------------------------------------------------------------------------
-- Client and player
------------------------------------------------------------------------
stub.cvars = {}
function GetCVar(name) return stub.cvars[name] or "0" end
function SetCVar(name, value) stub.cvars[name] = tostring(value) end
function GetCVarBool(name) return GetCVar(name) == "1" end
function GetCVarDefault() return "0" end
C_CVar = {
    GetCVar = GetCVar,
    SetCVar = SetCVar,
    GetCVarBool = GetCVarBool,
    GetCVarDefault = GetCVarDefault,
}

function GetBuildInfo() return "1.16.0", "60000", "Oct 1 2026", 16001 end
function GetTime() return stub.time end
function GetFramerate() return 60 end
function GetNetStats() return 0, 0, 20, 20 end
function GetScreenWidth() return 1920 end
function GetScreenHeight() return 1080 end
function GetPhysicalScreenSize() return 2560, 1440 end
function GetCursorPosition() return 0, 0 end
function InCombatLockdown() return false end
function IsShiftKeyDown() return false end
function IsControlKeyDown() return false end
function IsAltKeyDown() return false end
function GetLocale() return "enUS" end
function GetRealmName() return "Test" end
function GetMoney() return 0 end
function GetCoinTextureString(v) return tostring(v) end
function GetMaxPlayerLevel() return 60 end
function ReloadUI() end
function PlaySound() end

function UnitName() return "Tester" end
function UnitClass() return "Warrior", "WARRIOR", 1 end
function UnitLevel() return 60 end
function UnitEffectiveLevel() return 60 end
function UnitExists(u) return u == "player" end
function UnitGUID(u) return u == "player" and "Player-1-0001" or nil end
function UnitIsUnit(a, b) return a == b end
function UnitIsPlayer(u) return u == "player" end
function UnitAffectingCombat() return false end
function UnitIsDeadOrGhost() return false end
function UnitHealth() return 100 end
function UnitHealthMax() return 100 end
function UnitPower() return 100 end
function UnitPowerMax() return 100 end
function UnitPowerType() return 1, "RAGE" end
function UnitXP() return 0 end
function UnitXPMax() return 1 end
function UnitRace() return "Human", "Human" end
function UnitSex() return 2 end
function UnitOnTaxi() return false end
function UnitBuff() end
function UnitAura() end
function IsInGroup() return false end
function IsInRaid() return false end
function IsInGuild() return false end
function IsInInstance() return false, "none" end
function IsResting() return false end
function IsMounted() return false end
function GetNumGroupMembers() return 0 end
function GetShapeshiftForm() return 0 end
function GetNumShapeshiftForms() return 0 end
function GetNumTalentTabs() return 3 end
function GetTalentTabInfo() return "Arms", "", 0 end
function GetXPExhaustion() return nil end
function IsXPUserDisabled() return false end
function IsPlayerAtEffectiveMaxLevel() return true end
function IsSpellKnown() return false end
function IsPlayerSpell() return false end
function GetSpellInfo(id) return "Spell " .. tostring(id), nil, 136243 end
function GetSpellTexture() return 136243 end
function GetItemInfo() end
function GetItemCount() return 0 end
function GetItemIcon() return 136243 end
function GetInventoryItemID() end
function GetInventoryItemTexture() end
function GetInventoryItemDurability() end
function GetInventorySlotInfo() return 1 end
function GetWeaponEnchantInfo() return false end
function GetNumSkillLines() return 0 end

------------------------------------------------------------------------
-- Addons
------------------------------------------------------------------------
function GetAddOnMetadata(_, field)
    if field == "Version" then return "test" end
end
function IsAddOnLoaded(name) return name == "MLZ_UI" end
function GetAddOnInfo(name)
    if name == "MLZ_UI" then return name, "MLZ UI", "", true, "INSECURE" end
    return name, nil, nil, false, "MISSING"
end
C_AddOns = {
    IsAddOnLoaded = IsAddOnLoaded,
    GetAddOnInfo = GetAddOnInfo,
    GetAddOnMetadata = GetAddOnMetadata,
    EnableAddOn = function() end,
}

------------------------------------------------------------------------
-- Bindings and action bars
------------------------------------------------------------------------
stub.bindings = {}
function GetBindingAction(key) return stub.bindings[key] or "" end
function GetBindingKey(action)
    for k, a in pairs(stub.bindings) do if a == action then return k end end
end
function GetBinding() end
function GetNumBindings() return 0 end
function SetBinding(key, action) stub.bindings[key] = action; return true end
function SaveBindings() end
function GetCurrentBindingSet() return 2 end
function GetActionBarToggles() return false, false, false, false end
function SetActionBarToggles() end
function HasAction() return false end
function GetActionInfo() end
function GetActionTexture() end
function GetActionText() end
function GetMacroInfo() end
function IsUsableAction() return true, false end
function IsActionInRange() return nil end

------------------------------------------------------------------------
-- Timers: queued, run by stub.FlushTimers()
------------------------------------------------------------------------
C_Timer = {}
function C_Timer.After(_, fn) stub.timers[#stub.timers + 1] = fn end
function C_Timer.NewTimer(_, fn)
    stub.timers[#stub.timers + 1] = fn
    return { Cancel = function() end, IsCancelled = function() return false end }
end
function C_Timer.NewTicker()
    return { Cancel = function() end, IsCancelled = function() return false end }
end

-- Runs queued timers. Timers that queue new timers run too, up to a limit (tickers loop forever).
function stub.FlushTimers(onError)
    for _ = 1, 20 do
        if #stub.timers == 0 then return end
        local list = stub.timers
        stub.timers = {}
        for _, fn in ipairs(list) do
            local ok, err = pcall(fn)
            if not ok and onError then onError(err) end
        end
        stub.time = stub.time + 1
    end
end

-- Sends an event to every frame that registered it
function stub.Fire(event, ...)
    for f in pairs(stub.frames) do
        local handler = f.__scripts.OnEvent
        if f.__events[event] and handler then handler(f, event, ...) end
    end
end

return stub
