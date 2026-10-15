-- MLZ UI: Control center (/mlz or the minimap button)
-- A sidebar with pages, each page made of cards and rows. Every control applies at once and calls the
-- modules' own functions directly (no slash commands, no chat spam). The window redraws itself when a
-- module reports a change (ns.FireState), and the footer shows whether a /reload is needed.

local _, ns = ...
local W = ns.W
local T, C = W.T, W.C

local S = {}
ns.Settings = S

local WIDTH, HEIGHT = 860, 580
local SIDEBAR_W = 180
local FOOTER_H = 44
local PAGE_W = 628
local PAD = 14

local function M(key) return ns.modules[key] end

local ROLE_TEXT = ns.ROLE_TEXT
local MODE_TEXT = ns.NP.MODE_TEXT
local SOURCE_TEXT = ns.SOURCE_TEXT
local function FadeModeText(mode)
    local t = ns.modules.fade.MODE_TEXT[mode] or tostring(mode)
    return t:sub(1, 1):upper() .. t:sub(2)
end
local AB_SHORT = { range = "range", mana = "mana", unusable = "unusable", hotkeys = "short keys", macroNames = "no macro names" }
local TW_SHORT = { trackerHeader = "no tracker header", trackerHide = "tracker hidden", fps = "FPS counter", cleanCombatFont = "combat font",
    tooltipClass = "class colored tooltips", tooltipTarget = "tooltip target", chatClassNames = "class colors in chat",
    squareMinimap = "square minimap", flatChatInput = "flat chat input", chatFont = "Roboto chat" }

local function OpenWizard(stepKey)
    if InCombatLockdown() then
        S:Notify("The setup wizard can't open in combat. Try again after combat.", "warn")
        return
    end
    if S.frame then S.frame:Hide() end
    if ns.Installer then ns.Installer:Open(stepKey) end
end

local function EditModeAvailable()
    return _G.EditModeManagerFrame ~= nil and C_EditMode ~= nil
end

local function OpenEditMode()
    if not EditModeAvailable() then return end
    if InCombatLockdown() then
        S:Notify("Edit Mode can't open in combat. Try again after combat.", "warn")
        return
    end
    if S.frame then S.frame:Hide() end
    local f = _G.EditModeManagerFrame
    if ShowUIPanel then pcall(ShowUIPanel, f) else pcall(f.Show, f) end
end

-- "My role" choice: used on the overview and the healer page
local ROLE_OPTIONS = {
    { value = "auto", text = "Auto", tip = "Read from your spec, talents or group role. You count as DPS until you have 11 points in one talent tree. Tank also needs Bear Form for druids." },
    { value = "TANK", text = "Tank" }, { value = "HEALER", text = "Healer" }, { value = "DAMAGER", text = "DPS" },
}
local function GetRoleChoice() return ns.GetRoleForce() or "auto" end
local function SetRoleChoice(v) ns.SetRoleForce(v ~= "auto" and v or nil) end
-- "Healer (talents)": your role and where it came from
function S.RoleText()
    local role, source = ns.Role()
    return (ROLE_TEXT[role or ""] or "Unknown") .. " (" .. (SOURCE_TEXT[source] or tostring(source)) .. ")"
end
-- "Druid: Melee DPS (talents)": your class and the kind of player the UI adapts to right now
function S.ClassText()
    local class = UnitClass("player") or "Unknown"
    local arch = ns.LiveArchetype()
    local _, source = ns.Role()
    return class .. ": " .. ns.ArchetypeText(arch) .. " (" .. (SOURCE_TEXT[source] or tostring(source)) .. ")"
end
local function RoleDesc()
    return "Decides the role layouts and the nameplate mode. Detected now: " .. S.RoleText() .. "."
end

-- "Reload needed: addon settings", or nil when nothing waits for a reload
function S.ReloadText()
    if not ns.needsReload then return nil end
    local why = ns.reloadReasons or {}
    return "Reload needed" .. (#why > 0 and (": " .. table.concat(why, ", ")) or "")
end

-- Runs fn now, or after combat with a footer note. what = "the minimap size is saved".
function S.QueueOrNotify(fn, label, what)
    if InCombatLockdown() then
        ns.RunOutOfCombat(fn, label, true)
        S:Notify("In combat: " .. what .. " when combat ends.", "warn")
        return false
    end
    return true
end

local NP_OPTIONS = { { value = "auto", text = "Auto", tip = "Follows your role: tank, healer or DPS in a group, solo when alone." } }
for _, m in ipairs(ns.NP.MODES) do NP_OPTIONS[#NP_OPTIONS + 1] = { value = m, text = MODE_TEXT[m] } end
local function GetNPChoice() return ns.NP.Auto() and "auto" or (ns.NP.Mode() or "dps") end
local function SetNPChoice(v) if v == "auto" then ns.NP.SetAuto(true) else ns.NP.SetMode(v) end end
-- row "avail" checks: nil when the row can be used, otherwise the reason
local function NPNotReady() return ns.NP.NotReady() end
local function MLZOnly()
    if ns.NP.Engine() ~= "mlz" then return "Only for MLZ nameplates" end
    return ns.NP.NotReady()
end
local function PlatyOnly()
    if ns.NP.Engine() ~= "platynator" then return "Only for Platynator" end
    return ns.NP.NotReady()
end
local ENGINE_OPTIONS = {
    { value = "mlz", text = "MLZ" }, { value = "platynator", text = "Platynator" }, { value = "off", text = "Off" },
}
local ENGINE_TIP = "MLZ: MLZ UI draws its own flat nameplates.\nPlatynator: Platynator draws the plates and MLZ UI drives its settings.\n"
    .. "Off: Blizzard's own nameplates, left alone.\nMLZ and Platynator can't both draw: pick Platynator while it is loaded."
local SIZE_OPTIONS = {
    { value = 0.8, text = "80%" }, { value = 0.9, text = "90%" }, { value = 1, text = "100%" },
    { value = 1.1, text = "110%" }, { value = 1.2, text = "120%" }, { value = 1.35, text = "135%" },
}

------------------------------------------------------------------------
-- Status summary: one entry per area. Used by the overview page and the minimap tooltip.
-- { page, title, state ("on"|"off"|"warn"|"bad"|"info"|"na"), badge, text }
------------------------------------------------------------------------
local SECTIONS = {}

SECTIONS[#SECTIONS + 1] = function(Add)
    local sc = M("scale")
    if sc:IsApplied() then
        Add("layout", "UI scale", "on", ("%.2f"):format(UIParent:GetScale()), sc:ModeText(sc:Mode()))
    else
        Add("layout", "UI scale", "off", "Blizzard", ("Blizzard's own scale (now %.2f)"):format(UIParent:GetScale()))
    end
end

SECTIONS[#SECTIONS + 1] = function(Add)
    local lay = M("layout")
    local name, ours = lay:ActiveName()
    if ours then
        Add("layout", "Screen layout", "on", "Active", name)
    elseif name then
        Add("layout", "Screen layout", "warn", "Other layout",
            '"' .. name .. '" is active' .. (lay:Exists() and ". The MLZ UI layout is saved." or ". The MLZ UI layout is not made yet."))
    else
        Add("layout", "Screen layout", "na", "Not available", "Edit Mode is not available in this client")
    end
end

SECTIONS[#SECTIONS + 1] = function(Add)
    local H = ns.Healer
    local role = ns.Role()
    Add("healer", "Your role", H.IsHealer() and "on" or "info", ROLE_TEXT[role or ""] or "Unknown",
        S.ClassText() .. ". Layout: " .. tostring(H.Wanted()))
end

SECTIONS[#SECTIONS + 1] = function(Add)
    local NP = ns.NP
    local engine = NP.Engine()
    if engine == "off" then
        Add("nameplates", "Nameplates", "off", "Off", "Blizzard's own nameplates")
        return
    end
    if not NP.Ready() then
        Add("nameplates", "Nameplates", "warn", "Check", NP.NotReady())
        return
    end
    local mode = MODE_TEXT[NP.Mode() or ""]
    local parts = { NP.ENGINE_TEXT[engine], NP.Auto() and ("Auto: " .. (NP.Reason() or "-")) or "Chosen by you" }
    if engine == "platynator" and NP.Style() then parts[#parts + 1] = "clean style" end
    if NP.Threat() then parts[#parts + 1] = "threat colors" end
    if NP.LastError() then
        Add("nameplates", "Nameplates", "warn", mode or "Check", NP.LastError())
        return
    end
    Add("nameplates", "Nameplates", "on", mode or "On", table.concat(parts, ", "))
end

SECTIONS[#SECTIONS + 1] = function(Add)
    local fade = M("fade")
    local on, total = fade:CountOn()
    local chat = ns.db.chatTweaks and ", clean chat" or ""
    if ns.fadePaused then
        Add("fade", "Minimalism", "warn", "Paused", ("%d of %d frames, paused for now%s"):format(on, total, chat))
    else
        Add("fade", "Minimalism", on > 0 and "on" or "off", on > 0 and (on .. " of " .. total) or "Off",
            ("%d of %d frames hidden until needed%s"):format(on, total, chat))
    end
end

SECTIONS[#SECTIONS + 1] = function(Add)
    local ab = M("actionbuttons")
    local names = {}
    for _, o in ipairs(ab.options) do
        if ab:IsOn(o.id) then names[#names + 1] = AB_SHORT[o.id] or o.id end
    end
    Add("buttons", "Action buttons", #names > 0 and "on" or "off", #names .. " of " .. #ab.options,
        #names > 0 and ("On: " .. table.concat(names, ", ")) or "Blizzard default look")
end

SECTIONS[#SECTIONS + 1] = function(Add)
    local tw = M("tweaks")
    local names = {}
    for _, o in ipairs(tw.options) do
        if tw:IsOn(o.id) then names[#names + 1] = TW_SHORT[o.id] or o.id end
    end
    local map = tw.MapSize and tw.MapSize()
    Add("buttons", "Interface", #names > 0 and "on" or "off", #names > 0 and (#names .. " on") or "Off",
        (#names > 0 and ("On: " .. table.concat(names, ", ")) or "Nothing changed") .. (map and (". Minimap " .. map .. "%") or ""))
end

SECTIONS[#SECTIONS + 1] = function(Add)
    local V, MT, IA = ns.Vendor, ns.ManaTick, ns.Interrupt
    local names = {}
    if V.Get("repair") then names[#names + 1] = "auto-repair" end
    if V.Get("sell") then names[#names + 1] = "sell greys" end
    if MT.IsOn() then names[#names + 1] = "mana tick bar" end
    if IA.Get() ~= "off" then names[#names + 1] = "interrupt announce" end
    if ns.RoleProfiles.Auto() then names[#names + 1] = "role profiles" end
    local R = ns.Reminders
    if R and (R.Get("buffs") or R.Get("reagents")) then names[#names + 1] = "reminders" end
    Add("qol", "Helpers", #names > 0 and "on" or "off", #names > 0 and (#names .. " on") or "Off",
        #names > 0 and ("On: " .. table.concat(names, ", ")) or "Nothing turned on")
end

-- Worn gear: only listed when it needs a repair
SECTIONS[#SECTIONS + 1] = function(Add)
    local R = ns.Reminders
    if not (R and R.Get("durability")) then return end
    local low = R.Durability()
    if low and low <= R.DurabilityLimit() then
        Add("qol", "Gear", "warn", low .. "%", "Your most worn item is at " .. low .. "%. Repair at a merchant.")
    end
end

-- Leveling: XP per hour, hidden at max level
SECTIONS[#SECTIONS + 1] = function(Add)
    local X = ns.XPRate
    local text = X and X.Text()
    if not text then return end
    Add("qol", "Leveling", "info", X.Badge() or "Counting", text)
end

SECTIONS[#SECTIONS + 1] = function(Add)
    local list = M("addons"):Summary()
    local loaded, differ = 0, 0
    for _, s in ipairs(list) do
        if s.loaded then
            loaded = loaded + 1
            if s.differ > 0 then differ = differ + 1 end
        end
    end
    local off = ns.HealthOff and ns.HealthOff() or {}
    if #off > 0 then
        Add("addons", "Other addons", "warn", #off .. " switched off",
            "Installed but switched off in the addon list: " .. table.concat(off, ", "))
    elseif loaded == 0 then
        Add("addons", "Other addons", "off", "None loaded", #list .. " supported addons, none of them loaded")
    else
        Add("addons", "Other addons", differ > 0 and "warn" or "on", loaded .. " of " .. #list,
            loaded .. " loaded, " .. (differ > 0 and (differ .. " set up differently than MLZ UI suggests") or "all set up the MLZ UI way"))
    end
end

function S.Summary()
    local list = {}
    local function Add(page, title, state, badge, text)
        list[#list + 1] = { page = page, title = title, state = state, badge = badge, text = text }
    end
    for _, fn in ipairs(SECTIONS) do
        local ok, err = pcall(fn, Add)
        if not ok then ns.Debug("summary:", err) end
    end
    return list
end

------------------------------------------------------------------------
-- Tips for the overview card: things that need you now first, then Data/Tips.lua
------------------------------------------------------------------------
local TIP_NEEDS = {
    vendor = function() return ns.Vendor.Get("repair") or ns.Vendor.Get("sell") end,
    buttons = function()
        local ab = M("actionbuttons")
        for _, o in ipairs(ab.options) do
            if ab:IsOn(o.id) then return true end
        end
    end,
    leveling = function() return ns.XPRate and ns.XPRate.Stats() ~= nil end,
    minimapShown = function() return not (ns.db.minimap and ns.db.minimap.hide) end,
    remindersOff = function()
        local R = ns.Reminders
        return R and not (R.Get("buffs") and R.Get("reagents"))
    end,
}

local function TipNeeds(needs)
    if not needs then return true end
    local id = needs:match("^fade:(.+)$")
    if id then return M("fade"):IsOn(id) end
    local fn = TIP_NEEDS[needs]
    if not fn then return false end
    local ok, r = pcall(fn)
    return ok and r and true or false
end

local function TipAction(action)
    if action == "tour" then
        if not (ns.Tour and ns.Tour.HasSteps()) then return end
        return "Show me around", function()
            if InCombatLockdown() then
                S:Notify("The tour can't run in combat. Try again after combat.", "warn")
                return
            end
            S.frame:Hide()
            ns.Tour.Start()
        end
    elseif action == "keys" then
        if not ns.Keys then return end
        return "Show my keys", function() ns.Keys.Open() end
    elseif action == "fadePause" then
        local fade = M("fade")
        return ns.fadePaused and "Resume fading" or "Pause fading", function() fade:SetPaused(not ns.fadePaused) end
    end
    local key = action and action:match("^page:(.+)$")
    if key then return "Open", function() S:Select(key) end end
end

function S.Tips()
    local list = {}
    for _, t in ipairs(ns.data.tips or {}) do
        if TipNeeds(t.needs) then
            local button, fn = TipAction(t.action)
            list[#list + 1] = { text = t.text, button = button, fn = fn }
        end
    end
    return list
end

-- Up to 3 things that need you now, most urgent first: { text, button, fn }. The overview shows them above the tip.
function S.NextSteps()
    local list = {}
    local function Add(text, button, fn)
        if #list < 3 then list[#list + 1] = { text = text, button = button, fn = fn } end
    end
    local R = ns.Reminders
    local okM, missing = false, nil
    if R and R.Missing then okM, missing = pcall(R.Missing) end
    if okM and type(missing) == "table" and #missing > 0 then
        local names = {}
        for _, m in ipairs(missing) do names[#names + 1] = m.text end
        Add("Before you head out: " .. table.concat(names, ", ") .. ".")
    end
    if ns.db.installed then
        local lay = M("layout")
        if lay:Exists() then
            local names, built = lay:VariantNames(), 0
            for _, name in ipairs(names) do
                if lay:IndexOf(name) then built = built + 1 end
            end
            if built < #names then
                Add("Some role layouts are missing, so you stay on the main layout. Rebuild them to get the one for your role.",
                    "Open", function() S:Select("healer") end)
            end
        end
    end
    local NP = ns.NP
    if NP and NP.Engine() == "platynator" and not NP.Ready() then
        Add("Nameplates: " .. tostring(NP.NotReady()) .. ".", "Open", function() S:Select("nameplates") end)
    end
    if R and ns.db.installed and not (R.Get("buffs") or R.Get("reagents")) then
        Add("Reminders for missing buffs and low reagents are off. They are made for your class.", "Open", function() S:Select("qol") end)
    end
    if ns.db.installed and not ns.db.tourSeen and ns.Tour and ns.Tour.HasSteps() then
        local button, fn = TipAction("tour")
        Add("Some bars and buttons are hidden now. A short tour shows where they went.", button, fn)
    end
    return list
end

------------------------------------------------------------------------
-- Page builder: a scroll area with a title and cards; rows inside cards.
------------------------------------------------------------------------
local Page = {}
Page.__index = Page

local function NewPage(parent)
    local sf = W.ScrollArea(parent)
    sf:SetPoint("TOPLEFT", parent, "TOPLEFT", SIDEBAR_W + 21, -53)
    sf:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -22, FOOTER_H + 9)
    sf:Hide()
    return setmetatable({ scroll = sf, content = sf.content, y = 0, refreshers = {} }, Page)
end

local function Eval(v)
    if type(v) ~= "function" then return v end
    local ok, r = pcall(v)
    return ok and r or ""
end

function Page:OnRefresh(fn) self.refreshers[#self.refreshers + 1] = fn end

function Page:Refresh()
    for _, fn in ipairs(self.refreshers) do
        local ok, err = pcall(fn)
        if not ok then ns.Debug("settings refresh:", err) end
    end
end

function Page:Title(title, subtitle)
    local t = W.Text(self.content, "MLZUI_FontTitle", title)
    t:SetPoint("TOPLEFT", 2, -self.y)
    self.y = self.y + 28
    if subtitle then
        local s = W.Text(self.content, "GameFontHighlight", subtitle)
        s:SetTextColor(unpack(T.muted))
        s:SetPoint("TOPLEFT", 2, -self.y)
        s:SetWidth(PAGE_W - 4)
        self.y = self.y + s:GetStringHeight() + 4
    end
    self.y = self.y + 12
end

function Page:EndCard()
    local c = self.card
    if not c then return end
    c:SetHeight(c.cy + 4)
    self.y = self.y + c.cy + 4 + 12
    self.card = nil
end

function Page:Card(title, subtitle)
    self:EndCard()
    local c = W.Card(self.content)
    c:SetPoint("TOPLEFT", 0, -self.y)
    c:SetWidth(PAGE_W)
    c.cy = 4
    if title then
        local t = W.Text(c, "MLZUI_FontHead", title)
        t:SetPoint("TOPLEFT", PAD, -13)
        c.cy = 36
        if subtitle then
            local s = W.Text(c, "GameFontHighlightSmall", subtitle)
            s:SetTextColor(unpack(T.muted))
            s:SetPoint("TOPLEFT", PAD, -33)
            s:SetWidth(PAGE_W - PAD * 2)
            c.cy = 33 + s:GetStringHeight() + 10
        end
    end
    self.card = c
    return c
end

local function Divider(frame)
    local line = W.Line(frame)
    line:SetPoint("TOPLEFT", PAD - 1, 0)
    line:SetPoint("TOPRIGHT", -(PAD - 1), 0)
    return line
end

-- A setting row: label + grey description on the left, the control on the right.
-- opts: label, desc (text or function), tip (text or function), avail (function returning nil or a reason)
-- build(row) returns the control; refresh(control) keeps it current.
function Page:Row(opts, build, refresh)
    local c = self.card or self:Card()
    local row = CreateFrame("Frame", nil, c)
    row:SetPoint("TOPLEFT", 1, -c.cy)
    row:SetPoint("TOPRIGHT", -1, -c.cy)
    if c.cy > 4 then Divider(row) end
    row.hl = W.Fill(row, T.shade, "BACKGROUND", 1)
    row.hl:Hide()

    local control = build and build(row)
    local cw = control and control:GetWidth() or 0
    if control then control:SetPoint("RIGHT", row, "RIGHT", -(PAD - 1), 0) end
    -- the "not available" reason may be wider than a small control: keep room for whichever is wider
    local rightW = (cw > 0 or opts.avail) and math.max(cw, opts.avail and 170 or 0) or 0
    local textW = PAGE_W - PAD * 2 - (rightW > 0 and (rightW + 24) or 0)

    row.label = W.Text(row, "GameFontHighlight", opts.label)
    row.label:SetPoint("TOPLEFT", PAD - 1, -13)
    row.label:SetWidth(textW)
    local h = 13 + row.label:GetStringHeight()
    if opts.desc then
        row.desc = W.Text(row, "GameFontHighlightSmall", Eval(opts.desc))
        row.desc:SetTextColor(unpack(T.muted))
        row.desc:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -4)
        row.desc:SetWidth(textW)
        local dh = row.desc:GetStringHeight()
        if opts.descLines then
            -- text that changes while the window is open: keep room for its longest version
            local _, size = row.desc:GetFont()
            dh = math.max(dh, opts.descLines * ((size or 11) + 2))
        end
        h = h + 4 + dh
    end
    h = math.max(46, h + 13)
    row:SetHeight(h)

    row.reason = W.Text(row, "GameFontHighlightSmall", "", "RIGHT")
    row.reason:SetTextColor(unpack(T.amber))
    row.reason:SetPoint("RIGHT", -PAD, 0)
    row.reason:SetWidth(math.max(rightW, 170))
    row.reason:Hide()

    row:EnableMouse(true)
    local function ShowTip(self)
        self.hl:Show()
        local tip = Eval(opts.tip)
        if tip and tip ~= "" then
            GameTooltip:SetOwner(self, "ANCHOR_NONE")
            GameTooltip:SetPoint("BOTTOMLEFT", self, "TOPLEFT", PAD, 2)
            GameTooltip:SetText(opts.label, 1, 1, 1)
            GameTooltip:AddLine(tip, nil, nil, nil, true)
            GameTooltip:Show()
        end
    end
    row:SetScript("OnEnter", ShowTip)
    row:SetScript("OnLeave", function(self)
        -- moving onto the control (a child) also fires OnLeave: keep the highlight and tooltip then
        if self:IsMouseOver() then return end
        self.hl:Hide()
        if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
    end)
    -- leaving the row through its control: the control's OnLeave runs, the row's doesn't
    if control and control.HookScript then
        control:HookScript("OnLeave", function()
            if not row:IsMouseOver() then
                row.hl:Hide()
                if GameTooltip:GetOwner() == row then GameTooltip:Hide() end
            end
        end)
    end

    self:OnRefresh(function()
        local why = opts.avail and opts.avail()
        if control then control:SetShown(not why) end
        row.reason:SetText(why or "")
        row.reason:SetShown(why and true or false)
        if row.desc and type(opts.desc) == "function" then row.desc:SetText(Eval(opts.desc)) end
        if not why and refresh and control then refresh(control) end
    end)

    c.cy = c.cy + h
    return row, control
end

local function Opts(opts, label, desc)
    opts = opts or {}
    opts.label, opts.desc = label, desc
    return opts
end

function Page:Toggle(label, desc, get, set, opts)
    return self:Row(Opts(opts, label, desc), function(row)
        return W.Toggle(row, function(_, on)
            set(on)
            S:Refresh()
        end)
    end, function(t) t:SetOn(get()) end)
end

-- Segmented choice: options = { { value, text, tip }, ... }
function Page:Choice(label, desc, options, get, set, segW, opts)
    return self:Row(Opts(opts, label, desc), function(row)
        return W.Segmented(row, options, function(v)
            set(v)
            S:Refresh()
        end, segW)
    end, function(s) s:SetValue(get()) end)
end

function Page:Step(label, desc, options, width, get, set, opts)
    return self:Row(Opts(opts, label, desc), function(row)
        return W.Stepper(row, width, options, function(v)
            set(v)
            S:Refresh()
        end)
    end, function(s) s:SetValue(get()) end)
end

function Page:Slider(label, desc, minV, maxV, step, fmt, get, onChange, onCommit, opts)
    return self:Row(Opts(opts, label, desc), function(row)
        return W.Slider(row, 250, minV, maxV, step, fmt, onChange, function(v)
            onCommit(v)
            S:Refresh()
        end)
    end, function(h)
        local s = h.slider
        if s.IsDraggingThumb and s:IsDraggingThumb() then return end
        h:SetValue(get())
    end)
end

-- Read-only value on the right
function Page:Value(label, desc, fn, opts)
    opts = Opts(opts, label, desc)
    return self:Row(opts, function(row)
        local h = CreateFrame("Frame", nil, row)
        h:SetSize(opts.width or 240, 20)
        h.text = W.Text(h, "MLZUI_FontButton", "", "RIGHT")
        h.text:SetAllPoints()
        h.text:SetWordWrap(false)
        return h
    end, function(h) h.text:SetText(fn() or "") end)
end

-- Colored status badge on the right. fn returns state, text.
function Page:Status(label, desc, fn, opts)
    opts = Opts(opts, label, desc)
    return self:Row(opts, function(row)
        local b = W.Badge(row)
        b:SetWidth(opts.width or 170)
        return b
    end, function(b) b:Set(fn()) end)
end

-- A row of buttons inside the current card: { { text, fn(button), width, style, tip, refresh(button),
-- avail() }, ... }. avail returns nil when the button can be used, else the reason: the button is
-- disabled, its tooltip says why and the first reason shows in amber on the right.
function Page:Buttons(list)
    local c = self.card or self:Card()
    local holder = CreateFrame("Frame", nil, c)
    holder:SetPoint("TOPLEFT", 1, -c.cy)
    holder:SetPoint("TOPRIGHT", -1, -c.cy)
    holder:SetHeight(48)
    if c.cy > 4 then Divider(holder) end
    local x = PAD - 1
    local made, defs = {}, {}
    for _, d in ipairs(list) do
        local w = d.width or 150
        local b = W.Button(holder, d.text, w, 26, function(self)
            d.fn(self)
            S:Refresh()
        end, d.style)
        b:SetPoint("LEFT", x, 0)
        b.tipText = d.tip
        x = x + w + 8
        made[#made + 1] = b
        defs[#defs + 1] = d
    end
    local reason = W.Text(holder, "GameFontHighlightSmall", "", "RIGHT")
    reason:SetTextColor(unpack(T.amber))
    reason:SetPoint("RIGHT", -PAD, 0)
    reason:SetWidth(math.max(60, PAGE_W - x - PAD * 2))
    reason:SetWordWrap(false)
    self:OnRefresh(function()
        local first
        for i, b in ipairs(made) do
            local d = defs[i]
            if d.refresh then d.refresh(b) end
            local why = d.avail and d.avail()
            if why then
                b:SetEnabled(false)
                b.tipText = why .. (d.tip and ("\n" .. d.tip) or "")
                first = first or why
            else
                -- a custom refresh decides the enabled state itself; otherwise the button is simply usable again
                if d.avail and not d.refresh then b:SetEnabled(true) end
                b.tipText = d.tip
            end
        end
        reason:SetText(first or "")
    end)
    c.cy = c.cy + 48
    return made
end

-- Click twice to confirm: returns the button handler. The label comes back after 4 seconds.
local function Confirm(label, fn)
    return function(b)
        if not b.armed then
            -- each click gets its own token, so an old timer can't disarm a newer click
            local token = {}
            b.armed = token
            b:SetText("Click again to confirm")
            C_Timer.After(4, function()
                if b.armed == token then
                    b.armed = nil
                    b:SetText(label)
                end
            end)
            return
        end
        b.armed = nil
        b:SetText(label)
        fn(b)
    end
end

-- Grey paragraph inside the current card. text may be a function; lines reserves room for it.
function Page:Text(text, lines)
    local c = self.card or self:Card()
    local fs = W.Text(c, "GameFontHighlightSmall", "")
    fs:SetTextColor(unpack(T.muted))
    fs:SetPoint("TOPLEFT", PAD, -(c.cy + 6))
    fs:SetWidth(PAGE_W - PAD * 2)
    fs:SetJustifyV("TOP")
    fs:SetText(Eval(text))
    local h = math.max(fs:GetStringHeight(), (lines or 0) * 13)
    fs:SetHeight(h)
    if type(text) == "function" then self:OnRefresh(function() fs:SetText(Eval(text)) end) end
    c.cy = c.cy + h + 16
    return fs
end

function Page:Finish()
    self:EndCard()
    self.content:SetHeight(math.max(1, self.y + 4))
    if self.scroll.UpdateScroll then self.scroll.UpdateScroll() end
end

------------------------------------------------------------------------
-- Overview widgets
------------------------------------------------------------------------
-- One line per area: colored strip, title, short status text, badge and "Open >". Click opens the page.
local STATUS_H = 38
local function StatusLine(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(STATUS_H)
    b.hl = W.Fill(b, T.shade, "HIGHLIGHT")
    b.strip = b:CreateTexture(nil, "ARTWORK")
    b.strip:SetPoint("TOPLEFT", 0, -9)
    b.strip:SetPoint("BOTTOMLEFT", 0, 9)
    b.strip:SetWidth(3)
    b.title = W.Text(b, "MLZUI_FontButton", "")
    b.title:SetPoint("LEFT", PAD, 0)
    b.title:SetWidth(150)
    b.title:SetWordWrap(false)
    b.link = W.Text(b, "MLZUI_FontSmallBold", "Open >", "RIGHT")
    b.link:SetTextColor(unpack(T.accent))
    b.link:SetPoint("RIGHT", -PAD, 0)
    b.link:SetAlpha(0.45)
    b.badge = W.Badge(b)
    b.badge:SetWidth(120)
    b.badge:SetPoint("RIGHT", b.link, "LEFT", -16, 0)
    b.text = W.Muted(b, "GameFontHighlightSmall", "")
    b.text:SetPoint("LEFT", PAD + 156, 0)
    b.text:SetPoint("RIGHT", b.badge, "LEFT", -12, 0)
    b.text:SetWordWrap(false)
    b:SetScript("OnEnter", function(self)
        self.link:SetAlpha(1)
        if self.text:IsTruncated() then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.title:GetText(), 1, 1, 1)
            GameTooltip:AddLine(self.text:GetText(), nil, nil, nil, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        self.link:SetAlpha(0.45)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    b:SetScript("OnClick", function(self) if self.page then S:Select(self.page) end end)
    function b:Fill(st)
        self.page = st.page
        self.title:SetText(st.title)
        self.badge:Set(st.state, st.badge)
        self.text:SetText(st.text or "")
        self.strip:SetColorTexture(unpack((W.BADGE[st.state] or W.BADGE.info)[1]))
    end
    return b
end

local function Banner(parent, y)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", 0, -y)
    f:SetSize(PAGE_W, 50)
    W.Fill(f, T.card)
    W.Border(f, T.border)
    f.bar = f:CreateTexture(nil, "ARTWORK")
    f.bar:SetPoint("TOPLEFT", 1, -1)
    f.bar:SetPoint("BOTTOMLEFT", 1, 1)
    f.bar:SetWidth(3)
    f.text = W.Text(f, "GameFontHighlight", "")
    f.text:SetPoint("LEFT", 16, 0)
    f.text:SetWidth(PAGE_W - 200)
    f.button = W.Button(f, "", 160, 28, function(self) if self.action then self.action() end end, "primary")
    f.button:SetPoint("RIGHT", -11, 0)
    function f:Set(color, text, buttonText, action)
        self.bar:SetColorTexture(unpack(color))
        self.text:SetText(text)
        self.button:SetShown(buttonText ~= nil)
        self.button:SetText(buttonText or "")
        self.button.action = action
    end
    return f
end

------------------------------------------------------------------------
-- Pages
------------------------------------------------------------------------
local PAGES = {}

PAGES[#PAGES + 1] = { key = "overview", title = "Overview", icon = "Interface\\Icons\\INV_Misc_Book_09", build = function(p)
    p:Title("Overview", "Everything MLZ UI looks after. Click a line to change it.")
    local top = p.y

    -- The banner only shows when you need to do something
    local banner = Banner(p.content, top)
    local list = W.Card(p.content)
    list:SetWidth(PAGE_W)
    list:SetHeight(#SECTIONS * STATUS_H + 8)
    local lines = {}
    for i = 1, #SECTIONS do
        local line = StatusLine(list)
        line:SetPoint("TOPLEFT", 1, -(4 + (i - 1) * STATUS_H))
        line:SetPoint("TOPRIGHT", -1, -(4 + (i - 1) * STATUS_H))
        if i > 1 then
            local d = W.Line(line)
            d:SetPoint("TOPLEFT", PAD - 1, 0)
            d:SetPoint("TOPRIGHT", -(PAD - 1), 0)
        end
        lines[i] = line
    end
    p.y = top + 50 + PAD + #SECTIONS * STATUS_H + 8

    -- Up to 3 things to do next. Hidden when there is nothing to do.
    local STEP_H, STEPS_HEAD = 42, 30
    local steps = W.Card(p.content)
    steps:SetWidth(PAGE_W)
    local sstrip = steps:CreateTexture(nil, "ARTWORK")
    sstrip:SetColorTexture(unpack(T.amber))
    sstrip:SetPoint("TOPLEFT", 1, -1)
    sstrip:SetPoint("BOTTOMLEFT", 1, 1)
    sstrip:SetWidth(3)
    local shead = W.Text(steps, "MLZUI_FontSmallBold", "NEXT STEPS")
    shead:SetTextColor(unpack(T.muted))
    shead:SetPoint("TOPLEFT", PAD, -10)
    local stepRows = {}
    for i = 1, 3 do
        local row = CreateFrame("Frame", nil, steps)
        row:SetHeight(STEP_H)
        row:SetPoint("TOPLEFT", 1, -(STEPS_HEAD + (i - 1) * STEP_H))
        row:SetPoint("TOPRIGHT", -1, -(STEPS_HEAD + (i - 1) * STEP_H))
        if i > 1 then
            local d = W.Line(row)
            d:SetPoint("TOPLEFT", PAD - 1, 0)
            d:SetPoint("TOPRIGHT", -(PAD - 1), 0)
        end
        row.text = W.Text(row, "GameFontHighlight", "")
        row.text:SetPoint("LEFT", PAD, 0)
        row.text:SetWidth(PAGE_W - 2 * PAD - 170)
        row.button = W.Button(row, "", 150, 24, function(self) if self.fn then self.fn() end end)
        row.button:SetPoint("RIGHT", -PAD, 0)
        stepRows[i] = row
    end

    -- One tip at a time, below the status list and the next steps
    local TIP_H = 58
    local tip = W.Card(p.content)
    tip:SetWidth(PAGE_W)
    tip:SetHeight(TIP_H)
    tip:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -PAD)
    local strip = tip:CreateTexture(nil, "ARTWORK")
    strip:SetColorTexture(unpack(T.accent))
    strip:SetPoint("TOPLEFT", 1, -1)
    strip:SetPoint("BOTTOMLEFT", 1, 1)
    strip:SetWidth(3)
    local head = W.Text(tip, "MLZUI_FontSmallBold", "TIP")
    head:SetTextColor(unpack(T.muted))
    head:SetPoint("TOPLEFT", PAD, -10)
    tip.text = W.Text(tip, "GameFontHighlight", "")
    tip.text:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -4)
    tip.text:SetWidth(PAGE_W - 2 * PAD - 280)
    tip.text:SetWordWrap(true)
    -- The tip is remembered by its text, so the list changing under you does not swap it
    local tipKey, tipList, tipIdx
    tip.nextBtn = W.Button(tip, "Next tip", 90, 24, function()
        if tipList and #tipList > 0 then tipKey = tipList[(tipIdx % #tipList) + 1].text end
        p:Refresh()
    end, "subtle")
    tip.nextBtn:SetPoint("RIGHT", -PAD, 0)
    tip.action = W.Button(tip, "", 150, 24, function(self) if self.fn then self.fn() end end)
    tip.action:SetPoint("RIGHT", tip.nextBtn, "LEFT", -8, 0)
    p.y = p.y + PAD + TIP_H

    local function FillTip()
        local list = S.Tips()
        if #list == 0 then tip:Hide() return end
        tip:Show()
        local idx
        for i, t in ipairs(list) do
            if t.text == tipKey then idx = i break end
        end
        idx = idx or (tipKey == nil and math.random(#list)) or 1 -- the first tip you see is a random one
        tipList, tipIdx, tipKey = list, idx, list[idx].text
        local t = list[idx]
        tip.text:SetText(t.text)
        tip.action:SetShown(t.button ~= nil)
        tip.action:SetText(t.button or "")
        tip.action.fn = t.fn
        tip.nextBtn:SetShown(#list > 1)
    end

    p:OnRefresh(function()
        FillTip()
        local action = true
        if not ns.db.installed then
            banner:Set(T.amber, "MLZ UI is not set up yet. The setup wizard walks you through it and takes a backup first.",
                "Run setup wizard", function() OpenWizard() end)
        elseif ns.needsReload then
            banner:Set(T.amber, S.ReloadText() .. ".", "Reload UI", function() ReloadUI() end)
        else
            action = false
        end
        banner:SetShown(action)
        list:ClearAllPoints()
        list:SetPoint("TOPLEFT", 0, -(action and (top + 50 + PAD) or top))

        local sum = S.Summary()
        for i, line in ipairs(lines) do
            line:SetShown(sum[i] ~= nil)
            if sum[i] then line:Fill(sum[i]) end
        end
        list:SetHeight(#sum * STATUS_H + 8)

        local todo = S.NextSteps()
        for i, row in ipairs(stepRows) do
            local step = todo[i]
            row:SetShown(step ~= nil)
            if step then
                row.text:SetText(step.text)
                row.button:SetShown(step.button ~= nil)
                row.button:SetText(step.button or "")
                row.button.fn = step.fn
            end
        end
        steps:SetShown(#todo > 0)
        steps:SetHeight(STEPS_HEAD + #todo * STEP_H + 4)
        steps:ClearAllPoints()
        tip:ClearAllPoints()
        if #todo > 0 then
            steps:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -PAD)
            tip:SetPoint("TOPLEFT", steps, "BOTTOMLEFT", 0, -PAD)
        else
            tip:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -PAD)
        end
        local total = list:GetHeight() + (action and (50 + PAD) or 0)
            + (#todo > 0 and (PAD + steps:GetHeight()) or 0) + (tip:IsShown() and (PAD + TIP_H) or 0)
        p.content:SetHeight(top + total + 4)
        if p.scroll.UpdateScroll then p.scroll.UpdateScroll() end
    end)
end }

PAGES[#PAGES + 1] = { key = "layout", title = "Layout & scale", icon = "Interface\\Icons\\INV_Misc_Map_01", build = function(p)
    local sc, lay, tw = M("scale"), M("layout"), M("tweaks")
    p:Title("Layout & scale", "How big the UI is and where everything sits.")

    p:Card("UI scale", "The mode is saved, not the number, so the scale is recalculated if you change resolution.")
    -- the numbers depend on the screen size, so the labels are rebuilt on every refresh
    -- (registered before the stepper, so its label is drawn with the new text)
    local modes = {}
    local function Labels()
        for i, m in ipairs(sc.MODES) do
            modes[i] = modes[i] or { value = m.value }
            modes[i].text = ("%s  (%.2f)"):format(m.text, sc:Compute(m.value))
        end
    end
    Labels()
    p:OnRefresh(Labels)
    p:Step("Scale mode", "Lower number = smaller UI and more of the world. Applies at once (waits for combat to end).",
        modes, 280, function() return sc:Mode() end, function(v) sc:SetMode(v) end)
    p:Value("Right now", nil, function()
        local w, h = GetPhysicalScreenSize()
        return ("%.3f on a %dx%d screen%s"):format(UIParent:GetScale(), w or 0, h or 0, sc:IsApplied() and "" or C.grey .. " (Blizzard's own scale)" .. C.r)
    end, { width = 320 })

    p:Card("Screen layout", "Where bars and frames sit. MLZ UI keeps its own Edit Mode layout and never changes your other layouts.")
    p:Status("Active layout", function()
        return lay:Exists() and "The MLZ UI layout is saved." or "The MLZ UI layout has not been created yet."
    end, function()
        local name, ours = lay:ActiveName()
        if not name then return "na" end
        return ours and "on" or "warn", name
    end, { width = 240, descLines = 1 })
    local function NoEditMode() if not EditModeAvailable() then return "Needs Edit Mode" end end
    p:Buttons({
        { text = "Open Edit Mode", width = 150, fn = OpenEditMode, avail = NoEditMode,
          tip = "Move and resize frames yourself. Remember to save in Edit Mode." },
        { text = "Re-apply layout...", width = 160, fn = function() OpenWizard("layout") end, avail = NoEditMode,
          tip = "Opens the setup wizard at the layout step, so you can see what will change before applying." },
    })

    -- Edit Mode can't be saved in combat: SaveMap keeps the size and saves it when combat ends
    local function SaveMap(v, what)
        local ok, err = tw.SaveMap(v, true)
        if InCombatLockdown() then
            S:Notify("In combat: the minimap size is saved when combat ends.", "warn")
            return
        end
        S:Notify(ok and (what .. ": " .. v .. "%") or ("Minimap not saved in the layout: " .. tostring(err)), ok and "good" or "warn")
    end
    p:Card("Minimap")
    p:Slider("Minimap size", "Drag to preview. Saved in the Edit Mode layout when you let go.",
        tw.MAP_MIN, tw.MAP_MAX, tw.MAP_STEP, "%d%%",
        function() return tw.MapSize() end,
        function(v) tw.PreviewMap(v) end,
        function(v) SaveMap(v, "Minimap size saved") end,
        { avail = function() if not EditModeAvailable() then return "Needs Edit Mode" end end })
    p:Buttons({
        { text = "Reset to " .. tw.MAP_DEFAULT .. "%", width = 140, fn = function() SaveMap(tw.MAP_DEFAULT, "Minimap size reset to") end,
          avail = NoEditMode },
    })

    -- Hunters and warlocks only: other classes have no pet bar to place
    local class = ns.data.classes and ns.data.classes[ns.PlayerClass() or ""]
    if class and class.pet then
        p:Card("Pet bar", "Move the pet bar in Edit Mode and save, then press Remember. Applying the layout later puts it back there.")
        p:Value("Saved position", nil, function()
            local saved = lay:PetSaved()
            return saved and lay.AnchorText(saved) or (C.grey .. "Default (from MLZ UI)" .. C.r)
        end)
        p:Buttons({
            { text = "Remember position", width = 160, fn = function()
                local ok, text = lay:PetSave()
                S:Notify(ok and ("Pet bar position saved: " .. text) or ("Could not save the pet bar: " .. tostring(text)), ok and "good" or "bad")
            end },
            { text = "Use default", width = 120, style = "subtle", fn = function()
                lay:PetReset()
                S:Notify("The pet bar goes back to the default position next time the layout is applied.", "info")
            end },
        })
    end
end }

PAGES[#PAGES + 1] = { key = "nameplates", title = "Nameplates", icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance", build = function(p)
    local NP = ns.NP
    p:Title("Nameplates", "Nameplates that follow your role. Changes show at once.")

    p:Card("Engine", "Who draws your nameplates. Modes, threat colors and the PvP tweak work with both MLZ and Platynator.")
    p:Choice("Nameplates drawn by", "Switching applies at once, no reload.", ENGINE_OPTIONS, NP.Engine, NP.SetEngine, 80, { tip = ENGINE_TIP })
    p:Status("Right now", function()
        local e = NP.Engine()
        if NP.LastError() then return C.amber .. "Something needs a look: hover here." .. C.r end
        if e == "mlz" then return "MLZ UI draws the plates. Blizzard's own plate is only made invisible." end
        if e == "platynator" then return "MLZ UI changes your Platynator profile through Platynator's own import." end
        return "Blizzard's own nameplates. MLZ UI leaves them alone."
    end, function()
        if NP.Engine() == "off" then return "off", "Off" end
        if not NP.Ready() then return "warn", NP.NotReady() end
        if NP.LastError() then return "warn", "Check" end
        return "on", "Working"
    end, { tip = function() return NP.LastError() end, descLines = 2 })
    p:Value("Mode on your nameplates", function()
        if NP.Auto() then return "Picked automatically: " .. (NP.Reason() or "-") .. "." end
        local m, why = NP.Suggested()
        return "Chosen by you. Auto would pick " .. (MODE_TEXT[m] or "?") .. " (" .. (why or "-") .. ")."
    end, function()
        local m = NP.Mode()
        if not m then return C.grey .. (InCombatLockdown() and "waiting for combat to end" or "not applied yet") .. C.r end
        return MODE_TEXT[m] .. ((NP.PvP() and NP.InPvP()) and "  + PvP" or "")
    end, { avail = NPNotReady, width = 180, descLines = 2 })

    p:Card("Mode", "Auto: Tank while you tank (Defensive Stance / Bear Form with tank talents, or the group's tank). "
        .. "Healer or DPS in a group, depending on your role. Solo when you are not in a group.")
    p:Choice("Mode", "Picking a mode turns Auto off.", NP_OPTIONS, GetNPChoice, SetNPChoice, 62, { avail = NPNotReady })
    p:Text(C.blue .. "Tank" .. C.r .. ": every mob fully visible, your target a bit bigger.\n"
        .. C.blue .. "Healer" .. C.r .. ": enemies dimmed to 60% so your eyes stay on the raid frames.\n"
        .. C.blue .. "DPS" .. C.r .. ": mobs you don't target are faded a little.\n"
        .. C.blue .. "Solo" .. C.r .. ": calm, every mob readable (you often fight several).", 4)

    p:Card("Options")
    p:Toggle("Friendly names for healers", "In Healer mode friendly players get a name above their head, but it can't be clicked, so it never steals a click.",
        NP.HealerFriends, NP.SetHealerFriends, { avail = NPNotReady })
    p:Toggle("Threat colors per role", "Tank: red = a mob is not on you. DPS: red = a mob is on you. Off for healers and when solo.",
        NP.Threat, NP.SetThreat, { avail = NPNotReady,
        tip = "Tank: blue = securely on you, orange = aggro is changing hands, red = a mob is on someone else, teal = on the other tank. "
            .. "DPS: orange = you are close to pulling aggro, red = the mob is on you." })
    p:Toggle("PvP tweak", "In battlegrounds and arenas: every enemy fully visible, no threat colors.",
        NP.PvP, NP.SetPvP, { avail = NPNotReady })

    p:Card("What MLZ nameplates show", "Kept calm on purpose: extra details only show when they matter.")
    local function ShowToggle(key, label, desc, tip)
        p:Toggle(label, desc, function() return NP.Show(key) end, function(on) NP.SetShow(key, on) end,
            { avail = MLZOnly, tip = tip })
    end
    ShowToggle("healthText", "Health percent", "Inside the bar, on your target and on mobs that are hurt.")
    ShowToggle("castBar", "Cast bar", "Under the health bar. Blue can be interrupted, grey can't.")
    ShowToggle("quest", "Quest marker", "A yellow ! next to mobs you still need for a quest.",
        "Read from the mob's tooltip and remembered per mob, so it costs nothing in a fight.")
    ShowToggle("debuffs", "Your debuffs", "Only your own, with time left. On your target, or on every mob in Tank mode.")
    ShowToggle("level", "Level", "Only when it is 3 or more levels from yours, or ??. Elite and rare marks always show.")
    p:Step("Size", "Width and text size of the plates. Your target is a bit bigger on top of this.", SIZE_OPTIONS, 140,
        NP.Size, NP.SetSize, { avail = MLZOnly })

    p:Card("Platynator", "MLZ UI saves a copy of your Platynator profile before it changes anything. Restore puts that copy back.")
    p:Toggle("Clean nameplate style", "Minimal enemy nameplates: name and percent in the bar, cast bar, crowd control and only your own debuffs.",
        NP.Style, NP.SetStyle, { avail = PlatyOnly,
        tip = "Built from your own enemy design, so your font and colors stay. Everything it removes is remembered: turning it off puts it back." })
    p:Value("Saved copy", nil, function() return NP.HasSnapshot() and "Yes" or (C.grey .. "None yet" .. C.r) end)
    local function NoPlaty() if not NP.PlatyReady() then return "Platynator is not loaded" end end
    p:Buttons({
        { text = "Save profile", fn = NP.Save, width = 130, avail = NoPlaty,
          tip = "Replaces the saved copy with your profile as it is now." },
        { text = "Restore saved", fn = NP.Load, width = 130,
          avail = function() return NoPlaty() or (not NP.HasSnapshot() and "No saved copy yet") or nil end,
          tip = "Puts the saved copy back and turns the clean style and threat colors off." },
        { text = "Copy profile", fn = NP.Export, width = 110, style = "subtle", avail = NoPlaty,
          tip = "Shows your Platynator profile as text you can copy." },
    })
end }

PAGES[#PAGES + 1] = { key = "healer", title = "Your role", icon = "Interface\\Icons\\Spell_Nature_HealingTouch", build = function(p)
    local H, lay = ns.Healer, M("layout")
    p:Title("Your role", "Your role drives the nameplate mode and the layouts. When you heal, group frames move to the middle of the screen. Casters and hunters lose the melee swing timers.")

    p:Card("My role")
    p:Choice("My role", RoleDesc, ROLE_OPTIONS, GetRoleChoice, SetRoleChoice, 62, { descLines = 2 })

    p:Card("Your class", "MLZ UI adapts to all 9 classes in WoW Forever. Role is tank, healer or DPS. DPS is split into melee, ranged and caster.")
    p:Value("Playing as now", "Follows your talents and your form or stance.", function() return S.ClassText() end, { width = 260 })
    p:Value("Adapted for you", "Key hints and reminders are for your class. Stance keys and pet keys are added when your class has them.", function()
        local c = ns.data.classes and ns.data.classes[ns.PlayerClass() or ""]
        local parts = { "key hints", "reminders" }
        local stances = ns.modules.bindings.StanceCount()
        if stances > 0 then parts[#parts + 1] = stances .. " stance key" .. (stances == 1 and "" or "s") end
        if c and c.pet then parts[#parts + 1] = "pet keys" end
        return table.concat(parts, ", ")
    end, { width = 260 })

    p:Card("Role layouts", "One layout for healing in dungeons, one for raids, and one without melee swing timers for casters and hunters. They switch only while an MLZ UI layout is active, and never in combat.")
    p:Status("Counts as healer", nil, function()
        if H.IsHealer() then return "on", "Yes" end
        return "info", "No"
    end)
    p:Status("Role layouts built", "They are copies of the main layout. A role layout that does not exist is skipped, and you stay on the main layout.", function()
        if not lay:Exists() then return "warn", "No main layout" end
        local names, built = lay:VariantNames(), 0
        for _, name in ipairs(names) do
            if lay:IndexOf(name) then built = built + 1 end
        end
        return built == #names and "on" or "warn", built .. " of " .. #names
    end)
    p:Value("Layout now", nil, function() return lay:ActiveName() or (C.grey .. "unknown" .. C.r) end, { width = 260 })
    p:Value("Layout for your role", nil, function() return H.Wanted() or (C.grey .. "unknown" .. C.r) end, { width = 260 })
    local REBUILD = "Rebuild role layouts"
    p:Buttons({
        { text = REBUILD, width = 190, fn = Confirm(REBUILD, function()
            if InCombatLockdown() then
                ns.RunOutOfCombat(function() H.Rebuild() end, "rebuild role layouts")
                S:Notify("In combat: the role layouts are rebuilt when combat ends.", "warn")
                return
            end
            local ok, msg = H.Rebuild()
            S:Notify(ok and ("Role layouts rebuilt: " .. tostring(msg) .. ".") or ("Rebuild failed: " .. tostring(msg)), ok and "good" or "bad")
        end), avail = function()
            if not EditModeAvailable() then return "Needs Edit Mode" end
            if not lay:Exists() then return "Run the setup wizard first" end
        end, tip = "Copies the main layout (MLZ UI) again with the role changes. Your own changes to the role layouts are replaced. Do this after you have changed the main layout. Reload before you open Edit Mode again. Click twice to confirm." },
    })
end }

PAGES[#PAGES + 1] = { key = "fade", title = "Minimalism", icon = "Interface\\Icons\\Ability_Stealth", build = function(p)
    local fade = M("fade")
    p:Title("Minimalism", "Hide what you rarely need. Faded frames come back on mouseover, and everything shows while Edit Mode is open.")

    p:Card("Pause")
    p:Toggle("Pause all fading", "Shows everything again until you turn this off or reload. Handy for a quick look.",
        function() return ns.fadePaused end, function(on) fade:SetPaused(on) end)
    p:Buttons({
        { text = "Show me around", width = 150, fn = function()
            if InCombatLockdown() then
                S:Notify("The tour can't run in combat. Try again after combat.", "warn")
                return
            end
            S.frame:Hide()
            ns.Tour.Start()
        end, avail = function()
            if not (ns.Tour and ns.Tour.HasSteps()) then return "Nothing is hidden right now" end
        end, tip = "Draws a box around each hidden frame and says how to bring it back." },
    })

    p:Card("Hide until needed", "Keybinds keep working when a bar is invisible.")
    local missing = {}
    for _, row in ipairs(ns.data.fade) do
        if fade:Exists(row) then
            local how = FadeModeText(row.mode)
            if row.alpha then how = how .. " (" .. math.floor(row.alpha * 100) .. "%)" end
            p:Toggle(row.label, C.blue .. how .. C.r .. "  " .. (row.desc or ""),
                function() return fade:IsOn(row.id) end, function(on) fade:SetRow(row.id, on) end)
        else
            missing[#missing + 1] = row.label
        end
    end
    if #missing > 0 then
        p:Text(#missing .. " more are not shown because those frames do not exist in this client: " .. table.concat(missing, ", ") .. ".")
    end

    p:Card("Chat")
    p:Toggle("Clean chat", ("Chat lines fade after %ds (scroll or hover to see them again). Tabs and background only show on mouseover."):format(ns.data.chat.fadeAfter),
        function() return ns.db.chatTweaks end, function(on) fade:SetChat(on) end)
end }

PAGES[#PAGES + 1] = { key = "buttons", title = "Action bars & interface", icon = "Interface\\Icons\\Ability_DualWield", build = function(p)
    local ab, tw = M("actionbuttons"), M("tweaks")
    p:Title("Action bars & interface", "See at a glance why a button doesn't work, plus small tweaks that declutter the screen.")

    p:Card("Action buttons", C.red .. "Red" .. C.r .. " = out of range, " .. C.blue .. "blue" .. C.r .. " = not enough mana, dark grey = can't be used right now.")
    for _, o in ipairs(ab.options) do
        p:Toggle(o.label, o.desc, function() return ab:IsOn(o.id) end, function(on) ab:Set(o.id, on) end)
    end

    local last
    for _, o in ipairs(tw.options) do
        local group = o.group or "Quest tracker"
        if group ~= last then
            p:Card(group)
            last = group
        end
        p:Toggle(o.label, o.desc, function() return tw:IsOn(o.id) end, function(on) tw:Set(o.id, on) end,
            o.avail and { avail = o.avail } or nil)
    end
end }

PAGES[#PAGES + 1] = { key = "qol", title = "Helpers", icon = "Interface\\Icons\\INV_Misc_Coin_01", build = function(p)
    local V, MT, IA = ns.Vendor, ns.ManaTick, ns.Interrupt
    p:Title("Helpers", "Small helpers that save you clicks and give you information Blizzard doesn't show.")

    p:Card("Merchants", "Hold SHIFT while you talk to a merchant to skip this once.")
    p:Toggle("Repair automatically", "Repairs all your gear when you open a merchant who can repair.",
        function() return V.Get("repair") end, function(on) V.Set("repair", on) end)
    p:Toggle("Use guild bank money first", "When your guild lets you repair with guild money, that is used before your own gold.",
        function() return V.Get("guild") end, function(on) V.Set("guild", on) end,
        { avail = function() if not V.Get("repair") then return "Needs auto-repair" end end })
    p:Toggle("Sell grey items", "Sells every grey (poor quality) item in your bags. One line in chat says what you got for them.",
        function() return V.Get("sell") end, function(on) V.Set("sell", on) end,
        { avail = function() if V.LeatrixSells() then return "Leatrix Plus already sells junk" end end })

    -- Warriors only have rage, which does not tick. Druids keep the bar: they still have mana in Bear Form.
    local class = ns.data.classes and ns.data.classes[ns.PlayerClass() or ""] or {}
    local function NoTick() if class.resource == "Rage" and ns.PlayerClass() ~= "DRUID" then return "Warriors use rage, which has no tick" end end
    p:Card("Mana and energy", "A thin bar under your player frame.")
    p:Toggle("Five-second rule and tick bar", "After you spend mana the bar fills in orange over 5 seconds (no spirit regen until it is full), "
        .. "then shows the 2-second regen tick in blue. Rogues and druids in Cat Form see the energy tick in yellow.",
        MT.IsOn, MT.SetOn, { avail = NoTick })
    p:Toggle("Move the bar", "Shows a test bar you can drag with the left mouse button. Turn this off when you are done.",
        MT.IsMoving, MT.SetMoving, { avail = NoTick })
    p:Buttons({
        { text = "Reset position", width = 140, style = "subtle", fn = function()
            MT.ResetPosition()
            S:Notify("The tick bar is back under your player frame.", "info")
        end, avail = NoTick },
    })

    p:Card("Interrupts")
    p:Choice("Announce my interrupts", "\"Interrupted <mob>'s <spell>\" when you or your pet interrupt a cast. Say and Group only post while you are in a group.",
        IA.CHANNELS, IA.Get, IA.Set, 62)

    local R, X = ns.Reminders, ns.XPRate
    p:Card("Reminders", "Small icons below the middle of the screen, out of combat only. They go away once it is fixed.")
    p:Toggle("Missing self buffs", "Inner Fire, Arcane Intellect, aspects, poisons, weapon imbues and similar. "
        .. "Not shown in cities and inns.",
        function() return R.Get("buffs") end, function(on) R.Set("buffs", on) end)
    local entries = R.Entries()
    local function HasKind(kind)
        for _, e in ipairs(entries) do
            if e.kind == kind then return true end
        end
        return false
    end
    p:Toggle("Low reagents and ammo", "Ammo, soul shards, ankhs, powders and candles for the spells you know.",
        function() return R.Get("reagents") end, function(on) R.Set("reagents", on) end,
        { avail = function() if not HasKind("reagent") then return "Nothing to check for your class" end end })
    p:Toggle("Worn gear", ("An icon and one chat line when your most worn item drops to %d%% durability."):format(R.DurabilityLimit()),
        function() return R.Get("durability") end, function(on) R.Set("durability", on) end)

    -- What your class can be reminded about, one switch each. Rows wait until you learn the spell.
    if #entries > 0 then
        p:Card("Reminders for your class", "Turn off the ones you don't want. The two switches above must be on.")
        for _, e in ipairs(entries) do
            local master = e.kind == "buff" and "buffs" or "reagents"
            local desc = e.kind == "buff" and "Shown when you don't have it on you."
                or ("Shown when you carry fewer than %d."):format(e.min or 1)
            if e.roles then
                local names = {}
                for r in pairs(e.roles) do names[#names + 1] = ns.ROLE_TEXT[r] or r end
                table.sort(names)
                desc = desc .. " Only as " .. table.concat(names, " or ") .. "."
            end
            p:Toggle(e.name, desc, function() return not R.IsMuted(e.key) end, function(on) R.SetMuted(e.key, not on) end,
                { avail = function()
                    local known = e.known
                    for _, cur in ipairs(R.Entries()) do
                        if cur.key == e.key then known = cur.known end
                    end
                    if not known then return "Not learned yet" end
                    if not R.Get(master) then return "Needs the switch above" end
                end })
        end
    end

    p:Card("Leveling", "Counted since you logged in or reloaded. Also on the overview and with /mlz xp.")
    p:Value("XP per hour", function() return X.Text() or "You are at max level." end,
        function() return X.Badge() or (C.grey .. (X.Stats() and "counting" or "max level") .. C.r) end, { width = 120, descLines = 2 })
    p:Buttons({
        { text = "Start counting again", width = 170, style = "subtle", fn = function()
            X.Reset()
            ns.FireState()
            S:Notify("XP per hour counts from now.", "info")
        end },
    })
end }

PAGES[#PAGES + 1] = { key = "addons", title = "Other addons", icon = "Interface\\Icons\\INV_Misc_Bag_08", build = function(p)
    local addons = M("addons")
    p:Title("Other addons", "MLZ UI can set up these addons when they are installed and loaded. Nothing is downloaded.")
    p.sum = addons:Summary()
    p:OnRefresh(function() p.sum = addons:Summary() end) -- runs before the rows below

    p:Card("Supported addons", "Hover over a row to see settings that could not be read.")
    for i, entry in ipairs(ns.data.addons) do
        p:Status(entry.title, function()
            local s = p.sum[i]
            if not s or not s.loaded then return "Not loaded" end
            local text = s.differ == 0 and ("All %d settings match MLZ UI"):format(s.total)
                or ("%d of %d settings differ from MLZ UI"):format(s.differ, s.total)
            if #s.missing > 0 then text = text .. ", " .. #s.missing .. " not available" end
            return text
        end, function()
            local s = p.sum[i]
            if not s or not s.loaded then return "off", "Not loaded" end
            if s.differ > 0 then return "warn", "Differs" end
            return "on", "Matches"
        end, { tip = function()
            local s = p.sum[i]
            if s and #s.missing > 0 then return "Not available:\n" .. table.concat(s.missing, "\n") end
        end })
    end
    p:Buttons({
        { text = "Apply addon settings...", width = 190, style = "primary", fn = function() OpenWizard("addons") end,
          tip = "Opens the setup wizard at the addons step, so you can see and pick each change." },
    })

    if ns.Recommendations then
        p.rec = ns.Recommendations()
        p:OnRefresh(function() p.rec = ns.Recommendations() end)
        p:Card("Worth a look", "Addons that make the game easier to read. MLZ UI doesn't install them: get them from "
            .. "CurseForge or Wago if you want them.")
        for i, rec in ipairs(p.rec) do
            p:Status(rec.title, rec.why, function()
                local r = p.rec[i]
                if not r then return "na", "-" end
                if r.installed then return "on", "Installed" end
                if r.forRole then return "info", "For your role" end
                return "na", "Not installed"
            end)
        end
    end

    p:Card("Switched-off addons")
    p:Toggle("Point out switched-off addons", "Shows a note on the overview and the minimap button when a supported addon "
        .. "is installed but switched off. Nothing is printed in chat.",
        function() return ns.db.healthWarn ~= false end, function(on) ns.db.healthWarn = on and true or false; ns.FireState() end,
        { tip = "Turn this off if you switch some of these addons off on purpose." })
end }

-- "2026-10-13 14:02:11" -> "Today 14:02", "Yesterday 09:15" or "2026-10-01 18:40"
function S.BackupLabel(stamp)
    stamp = tostring(stamp or "")
    local day, hm = stamp:match("^(%d+%-%d+%-%d+) (%d+:%d+)")
    if not day then return stamp end
    if day == date("%Y-%m-%d") then return "Today " .. hm end
    if day == date("%Y-%m-%d", time() - 86400) then return "Yesterday " .. hm end
    return day .. " " .. hm
end

PAGES[#PAGES + 1] = { key = "profiles", title = "Profiles & backup", icon = "Interface\\Icons\\INV_Misc_Note_01", gap = true, build = function(p)
    p:Title("Profiles & backup", "Share your choices, or go back to how things were before the setup wizard ran or you imported a setup.")

    local RP = ns.RoleProfiles
    p:Card("Role profiles (this character)", "Save your nameplate options, faded frames, tick bar and interrupt announce once per role. "
        .. "With switching on, the right profile is loaded when your role changes (respec or dual spec).")
    p:Toggle("Switch profile with my role", "Only loads a role that has a saved profile.", RP.Auto, RP.SetAuto)
    for _, role in ipairs({ "TANK", "HEALER", "DAMAGER" }) do
        p:Value(ns.ROLE_TEXT[role] .. " profile", nil, function()
            local t = RP.Time(role)
            return t and ("Saved " .. t) or (C.grey .. "Not saved" .. C.r)
        end)
    end
    local function NoRoleProfile()
        local r = ns.Role()
        if not (r and RP.Has(r)) then return "No saved profile for your role" end
    end
    p:Buttons({
        { text = "Save as my role", width = 150, style = "primary", fn = function()
            local role = ns.Role()
            if not role then S:Notify("Your role is unknown. Pick it on the Your role page first.", "warn") return end
            local replaced = RP.Time(role)
            RP.Save(role)
            S:Notify("Saved as your " .. ns.ROLE_TEXT[role] .. " profile." .. (replaced and (" Replaced the one from " .. replaced .. ".") or ""), "good")
        end, tip = "Saves your current choices as the profile for the role you have right now." },
        { text = "Load my role", width = 130, fn = function()
            local role = ns.Role()
            local ok, ran = false, true
            if role then ok, ran = RP.Load(role, true) end
            if not ok then S:Notify("No saved profile for your role yet.", "warn") return end
            if ran == false then
                S:Notify("In combat: your " .. ns.ROLE_TEXT[role] .. " profile is loaded when combat ends.", "warn")
                return
            end
            S:Notify("Loaded your " .. ns.ROLE_TEXT[role] .. " profile.", "good")
        end, avail = NoRoleProfile, tip = "Loads the saved profile for the role you have right now." },
        { text = "Delete my role", width = 130, style = "subtle", fn = Confirm("Delete my role", function()
            local role = ns.Role()
            if role then
                RP.Delete(role)
                S:Notify("Deleted your " .. ns.ROLE_TEXT[role] .. " profile.", "info")
            end
        end), avail = NoRoleProfile, tip = "Deletes the saved profile for your role. Click twice to confirm." },
    })

    p:Card("Share your setup", "Export gives a string with your MLZ UI choices. Import it on another character or computer.")
    p:Buttons({
        { text = "Export", width = 120, fn = function() ns.RunCommand("export") end },
        { text = "Import...", width = 120, fn = function() ns.RunCommand("import") end },
    })

    p:Card("Backups", "A backup is taken every time the setup wizard applies changes. 5 are kept, and the oldest one (from before MLZ UI changed anything) is never thrown away.")
    p:Text(function()
        local list = ns.db.backups or {}
        if #list == 0 then return "No backups yet." end
        local lines = {}
        for i = #list, 1, -1 do
            local e = list[i]
            local parts = {}
            for k in pairs(e.data or {}) do
                local mod = ns.modules[k]
                parts[#parts + 1] = mod and mod.title or k
            end
            table.sort(parts)
            local what = e.kind == "import" and "import" or (i == 1 and "before MLZ UI" or "setup wizard")
            lines[#lines + 1] = (i == #list and C.green or C.grey) .. S.BackupLabel(e.time) .. ", " .. what .. C.r
                .. "   " .. table.concat(parts, ", ") .. (i == #list and (C.green .. "   (undo restores this)" .. C.r) or "")
        end
        return table.concat(lines, "\n")
    end, 6) -- up to 5 backups, plus room for one wrapped line
    local LABEL = "Undo last change"
    p:Buttons({
        { text = LABEL, width = 170, style = "danger", fn = Confirm(LABEL, function()
            local queued = InCombatLockdown()
            ns.Backup:Undo()
            if queued then
                S:Notify("In combat: parts of the undo are queued until combat ends.", "warn")
            elseif ns.needsReload then
                S:Notify("Backup restored. Reload to finish.", "warn")
            else
                S:Notify("Backup restored.", "good")
            end
        end), avail = function()
            if (ns.db.backups and #ns.db.backups or 0) == 0 then return "No backups yet" end
        end, tip = "Puts back everything the newest backup saved, from the setup wizard or an import. Click twice to confirm." },
    })
end }

PAGES[#PAGES + 1] = { key = "about", title = "About & help", icon = "Interface\\Icons\\INV_Misc_QuestionMark", build = function(p)
    p:Title("About & help", "MLZ UI version " .. ns.version .. ".")

    p:Card("Game version")
    p:Status("Client", "WoW Forever is the main supported game version. All 9 classes are supported.", function()
        local info = ns.ClientInfo()
        if info.main then return "on", info.name end
        return "warn", "Not " .. info.name
    end)
    p:Value("Interface", "MLZ UI is built for Interface 16001. Other clients load, but are not tested.", function()
        local info = ns.ClientInfo()
        return info.toc and tostring(info.toc) or (C.grey .. "unknown" .. C.r)
    end, { width = 260 })

    p:Card("How it works")
    p:Text("The " .. C.gold .. "setup wizard" .. C.r .. " is for the first install and for re-applying the whole setup with a backup. "
        .. "This window is for everyday changes. Everything here applies at once, and hovering a setting tells you more.")

    p:Card("Minimap button")
    p:Toggle("Show the minimap button", "Left-click opens this window, right-click opens a quick menu, SHIFT-click reloads when a reload is needed. Drag it to move it around the minimap.",
        function() return not (ns.db.minimap and ns.db.minimap.hide) end,
        function(on)
            if not ns.MinimapButton then return end
            ns.MinimapButton:SetHidden(not on)
            if not on then S:Notify("Type /mlz to open this window again.", "info") end
        end)

    p:Card("Chat commands")
    p:Text(C.gold .. "/mlz" .. C.r .. "   opens or closes this window\n"
        .. C.gold .. "/mlz install" .. C.r .. "   opens the setup wizard\n"
        .. C.gold .. "/mlz undo" .. C.r .. "   undoes the last setup wizard run or import\n"
        .. C.gold .. "/mlz role" .. C.r .. "   shows your role, or sets it: tank, healer, dps, auto\n"
        .. C.gold .. "/mlz np" .. C.r .. "   nameplate mode and options\n"
        .. C.gold .. "/mlz keys" .. C.r .. "   a map of your keybinds\n"
        .. C.gold .. "/mlz tour" .. C.r .. "   shows where the hidden bars and buttons are\n"
        .. C.gold .. "/mlz xp" .. C.r .. "   XP per hour and time to your next level\n"
        .. C.gold .. "/mlz minimap" .. C.r .. "   shows the minimap button again\n"
        .. C.gold .. "/mlz help" .. C.r .. "   lists the commands in chat")

    p:Card("Troubleshooting")
    p:Toggle("Debug output", "Extra messages in chat. Only useful when something is wrong.",
        function() return ns.db.debug end, function(on) ns.db.debug = on and true or false end)
    p:Buttons({
        { text = "Collect client info", width = 170, fn = function() ns.RunCommand("probe") end,
          tip = "Writes facts about your game client to MLZ UI's saved data after the next reload. Useful for bug reports." },
        { text = "List addon problems", width = 170, fn = function() ns.RunCommand("health") end,
          tip = "Prints supported addons that are switched off or not installed, in chat." },
    })
end }

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------
local function SidebarButton(parent, page, y)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(SIDEBAR_W, 34)
    b:SetPoint("TOPLEFT", 0, -y)
    b.sel = W.Fill(b, T.hover)
    b.sel:Hide()
    b.hl = W.Fill(b, T.shade, "HIGHLIGHT")
    b.bar = b:CreateTexture(nil, "ARTWORK")
    b.bar:SetColorTexture(unpack(T.accent))
    b.bar:SetPoint("TOPLEFT")
    b.bar:SetPoint("BOTTOMLEFT")
    b.bar:SetWidth(3)
    b.bar:Hide()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(18, 18)
    b.icon:SetPoint("LEFT", 14, 0)
    b.icon:SetTexture(page.icon)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.text = W.Text(b, "MLZUI_FontButton", page.title)
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 10, 0)
    b.text:SetWordWrap(false)
    function b:SetSelected(on)
        self.sel:SetShown(on)
        self.bar:SetShown(on)
        self.text:SetTextColor(unpack(on and T.text or T.muted))
        self.icon:SetDesaturated(not on)
        self.icon:SetAlpha(on and 1 or 0.7)
    end
    b:SetSelected(false)
    return b
end

function S:Build()
    if self.frame then return end
    local f = W.Window("MLZUI_Settings", WIDTH, HEIGHT, "MLZ UI")
    self.frame = f

    -- Sidebar
    local side = CreateFrame("Frame", nil, f)
    side:SetPoint("TOPLEFT", 1, -37)
    side:SetPoint("BOTTOMLEFT", 1, FOOTER_H + 1)
    side:SetWidth(SIDEBAR_W)
    W.Fill(side, T.panel)
    local edge = side:CreateTexture(nil, "BORDER")
    edge:SetColorTexture(unpack(T.border))
    edge:SetWidth(1)
    edge:SetPoint("TOPRIGHT")
    edge:SetPoint("BOTTOMRIGHT")

    self.pages = {}
    local y = 10
    for _, page in ipairs(PAGES) do
        if page.gap then
            local line = side:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(unpack(T.border))
            line:SetHeight(1)
            line:SetPoint("TOPLEFT", 14, -(y + 6))
            line:SetPoint("TOPRIGHT", -14, -(y + 6))
            y = y + 13
        end
        local b = SidebarButton(side, page, y)
        b:SetScript("OnClick", function() self:Select(page.key) end)
        self.pages[page.key] = { def = page, button = b }
        y = y + 36
    end

    -- Footer
    local foot = CreateFrame("Frame", nil, f)
    foot:SetPoint("BOTTOMLEFT", 1, 1)
    foot:SetPoint("BOTTOMRIGHT", -1, 1)
    foot:SetHeight(FOOTER_H)
    W.Fill(foot, T.panel)
    local top = foot:CreateTexture(nil, "BORDER")
    top:SetColorTexture(unpack(T.border))
    top:SetHeight(1)
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    foot.dot = foot:CreateTexture(nil, "ARTWORK")
    foot.dot:SetSize(8, 8)
    foot.dot:SetPoint("LEFT", 16, 0)
    foot.text = W.Text(foot, "GameFontHighlight", "")
    foot.text:SetPoint("LEFT", foot.dot, "RIGHT", 10, 0)
    foot.text:SetWidth(WIDTH - 330)
    foot.text:SetWordWrap(false)
    foot.reload = W.Button(foot, "Reload UI", 110, 28, function() ReloadUI() end)
    foot.reload:SetPoint("RIGHT", -10, 0)
    foot.wizard = W.Button(foot, "Setup wizard", 130, 28, function() OpenWizard() end)
    foot.wizard:SetPoint("RIGHT", foot.reload, "LEFT", -8, 0)
    foot.wizard.tipText = "Re-apply the whole setup step by step. A backup is taken first."
    self.footer = foot

    -- Redraw while open: on show, when a module reports a change, on group and layout events,
    -- and every 10 seconds as a fallback (some things change without an event)
    local elapsed = 0
    f:SetScript("OnShow", function() elapsed = 0; self:Refresh() end)
    f:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed > 10 then
            elapsed = 0
            self:Refresh()
        end
    end)
end

local refreshSoon = false
local function RefreshSoon()
    if refreshSoon or not (S.frame and S.frame:IsShown()) then return end
    refreshSoon = true
    C_Timer.After(0.3, function()
        refreshSoon = false
        S:Refresh()
    end)
end
ns.TryOn("GROUP_ROSTER_UPDATE", RefreshSoon)
ns.TryOn("EDIT_MODE_LAYOUTS_UPDATED", RefreshSoon)
ns.TryOn("PLAYER_REGEN_ENABLED", RefreshSoon)
ns.TryOn("DISPLAY_SIZE_CHANGED", RefreshSoon)

local NOTICE_COLOR = { good = T.green, bad = T.red, warn = T.amber, info = T.accent }

-- Short message in the footer (instead of chat)
function S:Notify(text, kind)
    self.notice = { text = text, color = NOTICE_COLOR[kind or "info"] or T.accent, untilT = GetTime() + 6 }
    self:RefreshFooter()
    C_Timer.After(6.1, function() S:RefreshFooter() end)
end

function S:RefreshFooter()
    local foot = self.footer
    if not foot then return end
    local color, text
    local n = self.notice
    if n and GetTime() < n.untilT then
        color, text = n.color, n.text
    elseif ns.needsReload then
        color = T.amber
        text = C.amber .. S.ReloadText() .. C.r
    elseif not ns.db.installed then
        color, text = T.accent, "Not set up yet. Run the setup wizard to get started."
    elseif ns.editModeStale then
        color, text = T.muted, "All changes are applied. Reload before you open Edit Mode."
    else
        color, text = T.green, "All changes are applied."
    end
    foot.dot:SetColorTexture(unpack(color))
    foot.text:SetText(text)
    foot.reload:SetStyle(ns.needsReload and "primary" or "normal")
    foot.wizard:SetStyle(ns.db.installed and "normal" or "primary")
end

function S:Select(key)
    if not self.pages[key] then key = "overview" end
    for k, entry in pairs(self.pages) do
        entry.button:SetSelected(k == key)
        if entry.page then entry.page.scroll:SetShown(k == key) end
    end
    local entry = self.pages[key]
    if not entry.page then
        entry.page = NewPage(self.frame)
        local ok, err = pcall(entry.def.build, entry.page)
        if not ok then
            entry.page:Card("Could not build this page")
            entry.page:Text(C.red .. tostring(err) .. C.r)
        end
        entry.page:Finish()
        entry.page.scroll:Show()
    end
    self.selected = key
    entry.page.scroll:SetVerticalScroll(0)
    self:Refresh(true)
end

-- A control's setter usually fires ns.FireState (which refreshes) and the control refreshes again
-- afterwards: once per frame is enough. force = refresh anyway (page switch).
function S:Refresh(force)
    if not (self.frame and self.frame:IsShown()) then return end
    local now = GetTime()
    if not force and self.lastRefresh == now then return end
    self.lastRefresh = now
    self:RefreshFooter()
    local entry = self.selected and self.pages[self.selected]
    if entry and entry.page then entry.page:Refresh() end
end

function S:Open(key)
    self:Build()
    self.frame:Show()
    self:Select(key or self.selected or "overview")
end

function S:Toggle()
    self:Build()
    if self.frame:IsShown() then self.frame:Hide() else self:Open() end
end

ns.OnState(function() S:Refresh() end)

-- Esc menu / Options > AddOns entry (best effort: not every client has this API)
ns.On("PLAYER_LOGIN", function()
    pcall(function()
        local modern = Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory
        if not (modern or InterfaceOptions_AddCategory) then return end
        local panel = CreateFrame("Frame")
        panel.name = "MLZ UI"
        local text = W.Text(panel, "GameFontHighlight", "MLZ UI settings live in their own window (also on the minimap button).")
        text:SetPoint("TOPLEFT", 16, -16)
        local btn = W.Button(panel, "Open MLZ UI settings", 200, 26, function()
            if HideUIPanel then
                if SettingsPanel then pcall(HideUIPanel, SettingsPanel) end
                if InterfaceOptionsFrame then pcall(HideUIPanel, InterfaceOptionsFrame) end
            end
            S:Open()
        end, "primary")
        btn:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -12)
        if modern then
            local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
            Settings.RegisterAddOnCategory(category)
        else
            InterfaceOptions_AddCategory(panel)
        end
    end)
end)
