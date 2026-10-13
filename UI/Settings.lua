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
local SOURCE_TEXT = { forced = "set by you", class = "class", spec = "spec", talents = "talents", group = "group role", unknown = "unknown" }
local FADE_MODE = {
    mouseover = "Hidden until mouseover",
    combat = "Dimmed out of combat",
    hideInCombat = "Hidden in combat",
    group = "Hidden when solo",
}
local AB_SHORT = { range = "range", mana = "mana", unusable = "unusable", hotkeys = "short keys", macroNames = "no macro names" }
local TW_SHORT = { trackerHeader = "no tracker header", trackerHide = "tracker hidden", fps = "FPS counter", cleanCombatFont = "combat font" }

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
    { value = "auto", text = "Auto", tip = "Read from your talents (or spec / group role). Tank also needs Bear Form for druids." },
    { value = "TANK", text = "Tank" }, { value = "HEALER", text = "Healer" }, { value = "DAMAGER", text = "DPS" },
}
local function GetRoleChoice() return ns.GetRoleForce() or "auto" end
local function SetRoleChoice(v) ns.SetRoleForce(v ~= "auto" and v or nil) end
local function RoleDesc()
    local role, source = ns.Role()
    return ("Decides the healer layouts and the nameplate mode. Detected now: %s (%s)."):format(
        ROLE_TEXT[role or ""] or "unknown", SOURCE_TEXT[source] or tostring(source))
end

local NP_OPTIONS = { { value = "auto", text = "Auto", tip = "Follows your role: tank, healer or DPS in a group, solo when alone." } }
for _, m in ipairs(ns.NP.MODES) do NP_OPTIONS[#NP_OPTIONS + 1] = { value = m, text = MODE_TEXT[m] } end
local function GetNPChoice() return ns.NP.Auto() and "auto" or (ns.NP.Mode() or "dps") end
local function SetNPChoice(v) if v == "auto" then ns.NP.SetAuto(true) else ns.NP.SetMode(v) end end
local function NPNotReady() if not ns.NP.Ready() then return "Platynator is not loaded" end end

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
        Add("layout", "UI scale", "off", "Blizzard", ("Not managed by MLZ UI (now %.2f)"):format(UIParent:GetScale()))
    end
end

SECTIONS[#SECTIONS + 1] = function(Add)
    local lay = M("layout")
    local name, ours = lay:ActiveName()
    if ours then
        Add("layout", "Edit Mode layout", "on", "Active", name)
    elseif name then
        Add("layout", "Edit Mode layout", "warn", "Other layout",
            '"' .. name .. '" is active' .. (lay:Exists() and ". The MLZ UI layout is saved." or ". MLZ UI layout not created."))
    else
        Add("layout", "Edit Mode layout", "na", "Not available", "Edit Mode is not available in this client")
    end
end

SECTIONS[#SECTIONS + 1] = function(Add)
    local H = ns.Healer
    local role, source = ns.Role()
    local how = "Role: " .. (ROLE_TEXT[role or ""] or "unknown") .. " (" .. (SOURCE_TEXT[source] or tostring(source)) .. ")"
    local healer = H.IsHealer()
    Add("healer", "Role & healer layouts", healer and "on" or "off", ROLE_TEXT[role or ""] or "Unknown",
        how .. ". Layout: " .. tostring(H.Wanted()))
end

SECTIONS[#SECTIONS + 1] = function(Add)
    local NP = ns.NP
    if not NP.Ready() then
        Add("nameplates", "Nameplates", "na", "Not loaded", "Platynator is not loaded, so modes are not used")
        return
    end
    local mode = MODE_TEXT[NP.Mode() or ""]
    local parts = { NP.Auto() and ("Auto: " .. (NP.Reason() or "-")) or "Chosen by you" }
    if NP.Style() then parts[#parts + 1] = "clean style" end
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
        Add("fade", "Minimalism", "warn", "Paused", ("%d of %d frames faded, paused until reload%s"):format(on, total, chat))
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
    Add("buttons", "Interface tweaks", #names > 0 and "on" or "off", #names > 0 and (#names .. " on") or "Off",
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
    Add("qol", "Quality of life", #names > 0 and "on" or "off", #names > 0 and (#names .. " on") or "Off",
        #names > 0 and ("On: " .. table.concat(names, ", ")) or "Nothing turned on")
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
    if loaded == 0 then
        Add("addons", "Other addons", "off", "None loaded", #list .. " supported addons, none of them loaded")
    else
        Add("addons", "Other addons", differ > 0 and "warn" or "on", loaded .. " of " .. #list,
            loaded .. " loaded, " .. (differ > 0 and (differ .. " with settings that differ from MLZ UI") or "all settings match MLZ UI"))
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
    c.cy, c.rows = 4, 0
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
    local line = frame:CreateTexture(nil, "BORDER")
    line:SetColorTexture(unpack(T.border))
    line:SetHeight(1)
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
    row.hl = W.Fill(row, { 1, 1, 1, 0.03 }, "BACKGROUND", 1)
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
        h = h + 4 + row.desc:GetStringHeight()
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
    c.rows = c.rows + 1
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

-- A row of buttons inside the current card: { { text, fn(button), width, style, tip, refresh(button) }, ... }
function Page:Buttons(list)
    local c = self.card or self:Card()
    local holder = CreateFrame("Frame", nil, c)
    holder:SetPoint("TOPLEFT", 1, -c.cy)
    holder:SetPoint("TOPRIGHT", -1, -c.cy)
    holder:SetHeight(48)
    if c.cy > 4 then Divider(holder) end
    local x = PAD - 1
    local made = {}
    for _, d in ipairs(list) do
        local w = d.width or 150
        local b = W.Button(holder, d.text, w, 26, function(self)
            d.fn(self)
            S:Refresh()
        end, d.style)
        b:SetPoint("LEFT", x, 0)
        b.tipText = d.tip
        if d.refresh then self:OnRefresh(function() d.refresh(b) end) end
        x = x + w + 8
        made[#made + 1] = b
    end
    c.cy = c.cy + 48
    c.rows = c.rows + 1
    return made
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
    c.rows = c.rows + 1
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
local function StatusCard(parent, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    b.bg = W.Fill(b, T.card)
    b.border = W.Border(b, T.border)
    b.strip = b:CreateTexture(nil, "ARTWORK")
    b.strip:SetPoint("TOPLEFT", 1, -1)
    b.strip:SetPoint("BOTTOMLEFT", 1, 1)
    b.strip:SetWidth(3)
    b.title = W.Text(b, "MLZUI_FontHead", "")
    b.title:SetPoint("TOPLEFT", PAD, -12)
    b.title:SetWidth(w - 150)
    b.title:SetWordWrap(false)
    b.badge = W.Badge(b)
    b.badge:SetPoint("TOPRIGHT", -12, -13)
    b.text = W.Text(b, "GameFontHighlightSmall", "")
    b.text:SetTextColor(unpack(T.muted))
    b.text:SetPoint("TOPLEFT", PAD, -34)
    b.text:SetWidth(w - PAD * 2 - 44) -- leave room for "Open >" in the bottom-right corner
    b.text:SetHeight(26)
    b.text:SetJustifyV("TOP")
    b.link = W.Text(b, "MLZUI_FontSmallBold", "Open >", "RIGHT")
    b.link:SetTextColor(unpack(T.accent))
    b.link:SetPoint("BOTTOMRIGHT", -12, 8)
    b.link:SetAlpha(0.6)
    b:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(unpack(T.hover))
        self.border:SetColor(T.accent)
        self.link:SetAlpha(1)
    end)
    b:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(unpack(T.card))
        self.border:SetColor(T.border)
        self.link:SetAlpha(0.6)
    end)
    b:SetScript("OnClick", function(self) if self.page then S:Select(self.page) end end)
    function b:Fill(s)
        self.page = s.page
        self.title:SetText(s.title)
        self.badge:Set(s.state, s.badge)
        self.text:SetText(s.text or "")
        local col = (W.BADGE[s.state] or W.BADGE.info)[1]
        self.strip:SetColorTexture(unpack(col))
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
    p:Title("Overview", "Everything MLZ UI controls, at a glance. Click a card to change it.")

    local banner = Banner(p.content, p.y)
    p.y = p.y + 50 + 14
    p:OnRefresh(function()
        if not ns.db.installed then
            banner:Set(T.amber, "MLZ UI is not set up yet. The setup wizard walks you through everything and takes a backup first.",
                "Run setup wizard", function() OpenWizard() end)
        elseif ns.needsReload then
            banner:Set(T.amber, "Some changes need a reload: " .. table.concat(ns.reloadReasons, ", ") .. ".",
                "Reload UI", function() ReloadUI() end)
        else
            banner:Set(T.green, C.green .. "MLZ UI is set up and running." .. C.r .. "  Hover over any setting to read what it does.")
        end
    end)

    local GAP, CH = 12, 78
    local CW = (PAGE_W - GAP) / 2
    local cards = {}
    for i = 1, #SECTIONS do
        local card = StatusCard(p.content, CW, CH)
        local col, line = (i - 1) % 2, math.floor((i - 1) / 2)
        card:SetPoint("TOPLEFT", col * (CW + GAP), -(p.y + line * (CH + GAP)))
        cards[i] = card
    end
    p.y = p.y + math.ceil(#SECTIONS / 2) * (CH + GAP) + 4
    p:OnRefresh(function()
        local list = S.Summary()
        for i, card in ipairs(cards) do
            local s = list[i]
            card:SetShown(s ~= nil)
            if s then card:Fill(s) end
        end
    end)

    p:Card("Quick actions", "The things you change most often.")
    p:Choice("My role", RoleDesc, ROLE_OPTIONS, GetRoleChoice, SetRoleChoice, 62)
    p:Choice("Nameplate mode", "Auto follows your role and group. Picking a mode turns Auto off.",
        NP_OPTIONS, GetNPChoice, SetNPChoice, 58, { avail = NPNotReady })
    p:Toggle("Pause fading", "Shows every faded frame until you reload or turn this off again.",
        function() return ns.fadePaused end, function(on) M("fade"):SetPaused(on) end)
    p:Toggle("FPS counter", "FPS and ping in the bottom-right corner.",
        function() return M("tweaks"):IsOn("fps") end, function(on) M("tweaks"):Set("fps", on) end)
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
        return ("%.3f on a %dx%d screen%s"):format(UIParent:GetScale(), w or 0, h or 0, sc:IsApplied() and "" or C.grey .. " (not managed)" .. C.r)
    end, { width = 320 })

    p:Card("Edit Mode layout", "MLZ UI keeps its own Edit Mode layout. Your other layouts are never changed.")
    p:Status("Active layout", function()
        return lay:Exists() and "The MLZ UI layout is saved." or "The MLZ UI layout has not been created yet."
    end, function()
        local name, ours = lay:ActiveName()
        if not name then return "na" end
        return ours and "on" or "warn", name
    end, { width = 240 })
    local function EditModeRefresh(b) b:SetEnabled(EditModeAvailable()) end
    p:Buttons({
        { text = "Open Edit Mode", width = 150, fn = OpenEditMode, refresh = EditModeRefresh,
          tip = "Move and resize frames yourself. Remember to save in Edit Mode." },
        { text = "Re-apply layout...", width = 160, fn = function() OpenWizard("layout") end, refresh = EditModeRefresh,
          tip = "Opens the setup wizard at the layout step, so you can see what will change before applying." },
    })

    -- Edit Mode can't be saved in combat: the save waits until combat ends
    local function SaveMap(v, what)
        if InCombatLockdown() then
            ns.RunOutOfCombat(function() tw.SaveMap(v, true) end, "minimap size", true)
            S:Notify("In combat: the minimap size is saved when combat ends.", "warn")
            return
        end
        local ok, err = tw.SaveMap(v, true)
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
          refresh = EditModeRefresh },
    })

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
end }

PAGES[#PAGES + 1] = { key = "nameplates", title = "Nameplates", icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance", build = function(p)
    local NP = ns.NP
    local NotReady = NPNotReady
    p:Title("Nameplates", "Platynator settings that follow your role. Changes show at once, no reload needed.")

    p:Card("Right now")
    p:Status("Platynator", function()
        if NP.Ready() and NP.LastError() then return C.amber .. "Something needs a look: hover here." .. C.r end
        return "MLZ UI changes your Platynator profile through Platynator's own import."
    end, function()
        if not NP.Ready() then return "na", "Not loaded" end
        if NP.LastError() then return "warn", "Check" end
        return "on", "Working"
    end, { tip = function() return NP.Ready() and NP.LastError() or nil end })
    p:Value("Mode on your nameplates", function()
        if NP.Auto() then return "Picked automatically: " .. (NP.Reason() or "-") .. "." end
        local m, why = NP.Suggested()
        return "Chosen by you. Auto would pick " .. (MODE_TEXT[m] or "?") .. " (" .. (why or "-") .. ")."
    end, function()
        local m = NP.Mode()
        if not m then return C.grey .. (InCombatLockdown() and "waiting for combat to end" or "not applied yet") .. C.r end
        return MODE_TEXT[m] .. ((NP.PvP() and NP.InPvP()) and "  + PvP" or "")
    end, { avail = NotReady, width = 180 })

    p:Card("Mode", "Auto: Tank while you tank (Defensive Stance / Bear Form with tank talents, or the group's tank). "
        .. "Healer or DPS in a group, depending on your role. Solo when you are not in a group.")
    p:Choice("Mode", "Picking a mode turns Auto off.", NP_OPTIONS, GetNPChoice, SetNPChoice, 62, { avail = NotReady })
    p:Text(C.blue .. "Tank" .. C.r .. ": every mob fully visible, your target a bit bigger.\n"
        .. C.blue .. "Healer" .. C.r .. ": enemies dimmed to 60% so your eyes stay on the raid frames.\n"
        .. C.blue .. "DPS" .. C.r .. ": mobs you don't target are faded a little.\n"
        .. C.blue .. "Solo" .. C.r .. ": calm, every mob readable (you often fight several).", 4)

    p:Card("Options")
    p:Toggle("Friendly names for healers", "In Healer mode friendly players get a name above their head, but it can't be clicked, so it never steals a click.",
        NP.HealerFriends, NP.SetHealerFriends, { avail = NotReady })
    p:Toggle("Clean nameplate style", "Minimal enemy nameplates: name and percent in the bar, cast bar, crowd control and only your own debuffs.",
        NP.Style, NP.SetStyle, { avail = NotReady,
        tip = "Built from your own enemy design, so your font and colors stay. Everything it removes is remembered: turning it off puts it back." })
    p:Toggle("Threat colors per role", "Tank: red = a mob is not on you. DPS: red = a mob is on you. Off for healers and when solo.",
        NP.Threat, NP.SetThreat, { avail = NotReady,
        tip = "Changes the threat color rule of your enemy design. Turning it off puts your own rule back." })
    p:Toggle("PvP tweak", "In battlegrounds and arenas: every enemy fully visible, enemy buffs shown, no threat colors.",
        NP.PvP, NP.SetPvP, { avail = NotReady })

    p:Card("Your Platynator profile", "MLZ UI saves a copy of your profile before it changes anything. Restore puts that copy back.")
    p:Value("Saved copy", nil, function() return NP.HasSnapshot() and "Yes" or (C.grey .. "None yet" .. C.r) end)
    p:Buttons({
        { text = "Save profile", fn = NP.Save, width = 130, refresh = function(b) b:SetEnabled(NP.Ready()) end,
          tip = "Replaces the saved copy with your profile as it is now." },
        { text = "Restore saved", fn = NP.Load, width = 130, refresh = function(b) b:SetEnabled(NP.Ready() and NP.HasSnapshot()) end,
          tip = "Puts the saved copy back and turns the clean style and threat colors off." },
        { text = "Export", fn = NP.Export, width = 100, style = "subtle", refresh = function(b) b:SetEnabled(NP.Ready()) end },
    })
end }

PAGES[#PAGES + 1] = { key = "healer", title = "Healer", icon = "Interface\\Icons\\Spell_Nature_HealingTouch", build = function(p)
    local H, lay = ns.Healer, M("layout")
    p:Title("Healer layouts", "When you heal, group frames move to the middle of the screen. One layout for dungeons, one for raids.")

    p:Card("Status")
    p:Value("Role", nil, function()
        local role, source = ns.Role()
        if not role then return C.grey .. "unknown" .. C.r end
        return ROLE_TEXT[role] .. C.grey .. "  (" .. (SOURCE_TEXT[source] or tostring(source)) .. ")" .. C.r
    end)
    p:Status("Counts as healer", nil, function()
        if H.IsHealer() then return "on", "Yes" end
        return "off", "No"
    end)
    p:Value("Layout now", nil, function() return lay:ActiveName() or (C.grey .. "unknown" .. C.r) end, { width = 260 })
    p:Value("Layout it wants", "Switches only while an MLZ layout is active, and never in combat.",
        function() return tostring(H.Wanted()) end, { width = 260 })

    p:Card("Settings")
    p:Choice("My role", RoleDesc, ROLE_OPTIONS, GetRoleChoice, SetRoleChoice, 62)
    p:Buttons({
        { text = "Rebuild healer layouts", width = 190, fn = function()
            if InCombatLockdown() then
                ns.RunOutOfCombat(function() H.Rebuild() end, "rebuild healer layouts")
                S:Notify("In combat: the healer layouts are rebuilt when combat ends.", "warn")
                return
            end
            local ok, msg = H.Rebuild()
            S:Notify(ok and ("Healer layouts rebuilt: " .. tostring(msg) .. ". Reload to see them.") or ("Rebuild failed: " .. tostring(msg)), ok and "warn" or "bad")
        end, refresh = function(b) b:SetEnabled(EditModeAvailable()) end,
          tip = "Copies the main layout (MLZ UI) again with the healer changes. Do this after you have changed the main layout. Needs a reload." },
    })
end }

PAGES[#PAGES + 1] = { key = "fade", title = "Minimalism", icon = "Interface\\Icons\\Ability_Stealth", build = function(p)
    local fade = M("fade")
    p:Title("Minimalism", "Hide what you rarely need. Faded frames come back on mouseover, and everything shows while Edit Mode is open.")

    p:Card("Controls")
    p:Toggle("Pause all fading", "Shows everything again until you reload or turn this off. Handy for a quick look.",
        function() return ns.fadePaused end, function(on) fade:SetPaused(on) end)

    p:Card("Hide until needed", "Keybinds keep working when a bar is invisible.")
    local missing = {}
    for _, row in ipairs(ns.data.fade) do
        if fade:Exists(row) then
            local how = FADE_MODE[row.mode] or row.mode
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

PAGES[#PAGES + 1] = { key = "buttons", title = "Action bars & UI", icon = "Interface\\Icons\\Ability_DualWield", build = function(p)
    local ab, tw = M("actionbuttons"), M("tweaks")
    p:Title("Action bars & interface", "See at a glance why a button doesn't work, plus small tweaks that declutter the screen.")

    p:Card("Action buttons", C.red .. "Red" .. C.r .. " = out of range, " .. C.blue .. "blue" .. C.r .. " = not enough mana, dark grey = can't be used right now.")
    for _, o in ipairs(ab.options) do
        p:Toggle(o.label, o.desc, function() return ab:IsOn(o.id) end, function(on) ab:Set(o.id, on) end,
            o.id == "hotkeys" and { tip = "Turning this off needs a reload to bring back Blizzard's hotkey text." } or nil)
    end

    local last
    for _, o in ipairs(tw.options) do
        local group = o.group or "Quest tracker"
        if group ~= last then
            p:Card(group)
            last = group
        end
        p:Toggle(o.label, o.desc, function() return tw:IsOn(o.id) end, function(on) tw:Set(o.id, on) end)
    end
end }

PAGES[#PAGES + 1] = { key = "qol", title = "Quality of life", icon = "Interface\\Icons\\INV_Misc_Coin_01", build = function(p)
    local V, MT, IA = ns.Vendor, ns.ManaTick, ns.Interrupt
    p:Title("Quality of life", "Small helpers that save you clicks and give you information Blizzard doesn't show.")

    p:Card("Merchants", "Hold Shift while you talk to a merchant to skip this once.")
    p:Toggle("Repair automatically", "Repairs all your gear when you open a merchant who can repair.",
        function() return V.Get("repair") end, function(on) V.Set("repair", on) end)
    p:Toggle("Use guild bank money first", "When your guild lets you repair with guild money, that is used before your own gold.",
        function() return V.Get("guild") end, function(on) V.Set("guild", on) end,
        { avail = function() if not V.Get("repair") then return "Needs auto-repair" end end })
    p:Toggle("Sell grey items", "Sells every grey (poor quality) item in your bags. One line in chat says what you got for them.",
        function() return V.Get("sell") end, function(on) V.Set("sell", on) end,
        { avail = function() if V.LeatrixSells() then return "Leatrix Plus already sells junk" end end })

    p:Card("Mana and energy", "A thin bar under your player frame.")
    p:Toggle("Five-second rule and tick bar", "After you spend mana the bar fills in orange over 5 seconds (no spirit regen until it is full), "
        .. "then shows the 2-second regen tick in blue. Rogues and druids in Cat Form see the energy tick in yellow.",
        MT.IsOn, MT.SetOn)
    p:Toggle("Move the bar", "Shows a test bar you can drag with the left mouse button. Turn this off when you are done.",
        MT.IsMoving, MT.SetMoving)
    p:Buttons({
        { text = "Reset position", width = 140, style = "subtle", fn = function()
            MT.ResetPosition()
            S:Notify("The tick bar is back under your player frame.", "info")
        end },
    })

    p:Card("Interrupts")
    p:Choice("Announce my interrupts", "\"Interrupted <mob>'s <spell>\" when you or your pet interrupt a cast. Say and Group only post while you are in a group.",
        IA.CHANNELS, IA.Get, IA.Set, 62)
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
        { text = "Check installed addons", width = 190, fn = function() ns.RunCommand("health") end,
          tip = "Lists supported addons that are missing or switched off, in chat." },
    })
end }

PAGES[#PAGES + 1] = { key = "profiles", title = "Profiles & backup", icon = "Interface\\Icons\\INV_Misc_Note_01", gap = true, build = function(p)
    p:Title("Profiles & backup", "Share your choices, or go back to how things were before the setup wizard ran.")

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
    p:Buttons({
        { text = "Save as my role", width = 150, style = "primary", fn = function()
            local role = ns.Role()
            if not role then S:Notify("Your role is unknown. Pick it under My role first.", "warn") return end
            RP.Save(role)
            S:Notify("Saved as your " .. ns.ROLE_TEXT[role] .. " profile.", "good")
        end, tip = "Saves your current choices as the profile for the role you have right now." },
        { text = "Load my role", width = 130, fn = function()
            local role = ns.Role()
            if not (role and RP.Load(role, true)) then S:Notify("No saved profile for your role yet.", "warn") return end
            S:Notify("Loaded your " .. ns.ROLE_TEXT[role] .. " profile.", "good")
        end, refresh = function(b) local r = ns.Role(); b:SetEnabled(r ~= nil and RP.Has(r)) end },
        { text = "Delete my role", width = 130, style = "subtle", fn = function()
            local role = ns.Role()
            if role then RP.Delete(role) end
        end, refresh = function(b) local r = ns.Role(); b:SetEnabled(r ~= nil and RP.Has(r)) end },
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
            for k in pairs(e.data or {}) do parts[#parts + 1] = k end
            table.sort(parts)
            lines[#lines + 1] = (i == #list and C.green or C.grey) .. tostring(e.time) .. C.r
                .. "   " .. table.concat(parts, ", ") .. (i == #list and (C.green .. "   (undo restores this)" .. C.r) or "")
        end
        return table.concat(lines, "\n")
    end, 6) -- up to 5 backups, plus room for one wrapped line
    local LABEL = "Undo last setup"
    p:Buttons({
        { text = LABEL, width = 170, style = "danger", fn = function(b)
            if not b.armed then
                -- each click gets its own token, so an old timer can't disarm a newer click
                local token = {}
                b.armed = token
                b:SetText("Click again to undo")
                C_Timer.After(4, function()
                    if b.armed == token then
                        b.armed = nil
                        b:SetText(LABEL)
                    end
                end)
                return
            end
            b.armed = nil
            b:SetText(LABEL)
            local queued = InCombatLockdown()
            ns.Backup:Undo()
            S:Notify(queued and "In combat: parts of the undo are queued until combat ends. Reload afterwards."
                or "Backup restored. Reload to finish.", "warn")
        end, refresh = function(b) b:SetEnabled((ns.db.backups and #ns.db.backups or 0) > 0) end,
          tip = "Puts back everything the newest backup saved. Click twice to confirm." },
    })
end }

PAGES[#PAGES + 1] = { key = "about", title = "About & help", icon = "Interface\\Icons\\INV_Misc_QuestionMark", build = function(p)
    p:Title("About & help", "MLZ UI version " .. ns.version .. ".")

    p:Card("How it works")
    p:Text("The " .. C.gold .. "setup wizard" .. C.r .. " is for the first install and for re-applying the whole setup with a backup. "
        .. "This window is for everyday changes: everything here applies at once, and the footer tells you when a reload is needed. "
        .. "Hover over any setting to read more about it.")

    p:Card("Minimap button")
    p:Toggle("Show the minimap button", "Left-click opens this window, right-click opens a quick menu, Shift-click reloads. Drag it to move it around the minimap.",
        function() return not (ns.db.minimap and ns.db.minimap.hide) end,
        function(on) if ns.MinimapButton then ns.MinimapButton:SetHidden(not on) end end)

    p:Card("Chat commands")
    p:Text(C.gold .. "/mlz" .. C.r .. "   opens or closes this window\n"
        .. C.gold .. "/mlz install" .. C.r .. "   opens the setup wizard\n"
        .. C.gold .. "/mlz undo" .. C.r .. "   undoes the last run of the setup wizard\n"
        .. C.gold .. "/mlz role" .. C.r .. "   shows your role, or sets it: tank, healer, dps, auto\n"
        .. C.gold .. "/mlz np" .. C.r .. "   nameplate mode and options\n"
        .. C.gold .. "/mlz minimap" .. C.r .. "   shows the minimap button again\n"
        .. C.gold .. "/mlz help" .. C.r .. "   lists the commands in chat")

    p:Card("Troubleshooting")
    p:Toggle("Debug output", "Extra messages in chat. Only useful when something is wrong.",
        function() return ns.db.debug end, function(on) ns.db.debug = on and true or false end)
    p:Buttons({
        { text = "Collect client info", width = 170, fn = function() ns.RunCommand("probe") end,
          tip = "Saves information about this client in the SavedVariables, for checking that MLZ UI matches it." },
        { text = "Check installed addons", width = 190, fn = function() ns.RunCommand("health") end },
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
    b.hl = W.Fill(b, { 1, 1, 1, 0.04 }, "HIGHLIGHT")
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
        text = C.amber .. "Reload needed" .. C.r .. (#ns.reloadReasons > 0 and (": " .. table.concat(ns.reloadReasons, ", ")) or "")
    elseif not ns.db.installed then
        color, text = T.accent, "Not set up yet. Run the setup wizard to get started."
    else
        color, text = T.green, "All changes are applied. Hover over a setting to learn more."
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
