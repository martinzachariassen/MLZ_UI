-- MLZ UI: UI building blocks (flat, dark theme) for the settings window, the wizard and the minimap menu.
-- Everything is drawn with plain color textures, so it looks the same on every client and does not
-- depend on Blizzard templates that change between versions.

local _, ns = ...

local W = {}
ns.W = W

------------------------------------------------------------------------
-- Theme
------------------------------------------------------------------------
W.T = {
    bg        = { 0.071, 0.078, 0.094, 0.97 },
    panel     = { 0.098, 0.110, 0.133, 1 },
    card      = { 0.125, 0.141, 0.169, 1 },
    hover     = { 0.165, 0.184, 0.220, 1 },
    border    = { 0.192, 0.212, 0.251, 1 },
    accent    = { 0.200, 0.627, 1.000, 1 },
    accentTint = { 0.200, 0.627, 1.000, 0.10 },  -- hover and highlight wash
    green     = { 0.290, 0.820, 0.450, 1 },
    amber     = { 1.000, 0.690, 0.250, 1 },
    red       = { 1.000, 0.360, 0.360, 1 },
    off       = { 0.300, 0.320, 0.360, 1 },
    text      = { 0.930, 0.940, 0.960, 1 },
    muted     = { 0.580, 0.610, 0.660, 1 },
    input     = { 0.060, 0.070, 0.085, 1 },   -- wells: checkboxes, segmented, stepper, slider track
    inputEdge = { 0.320, 0.350, 0.410, 1 },   -- border of an enabled checkbox
    shade     = { 1, 1, 1, 0.04 },             -- soft hover on rows and list items
    press     = { 1, 1, 1, 0.08 },             -- stronger hover on small controls
    -- Controls
    btn          = { 0.170, 0.190, 0.230, 1 },  -- normal button
    btnHover     = { 0.220, 0.250, 0.300, 1 },
    primary      = { 0.130, 0.450, 0.780, 1 },  -- primary button (accent, darkened so white text reads)
    primaryHover = { 0.180, 0.540, 0.900, 1 },
    primaryEdge  = { 0.250, 0.600, 0.950, 1 },
    danger       = { 0.420, 0.140, 0.140, 1 },
    dangerHover  = { 0.550, 0.180, 0.180, 1 },
    dangerEdge   = { 0.650, 0.250, 0.250, 1 },
    dangerText   = { 1.000, 0.900, 0.900, 1 },
    white        = { 1, 1, 1, 1 },              -- text on accent fills (primary, selected segment)
    knob         = { 0.950, 0.960, 0.980, 1 },  -- toggle knob, slider thumb
    onText       = { 0.050, 0.200, 0.100, 1 },  -- "ON" on the green toggle
    offText      = { 0.700, 0.720, 0.760, 1 },  -- "OFF" on the grey toggle
    edge         = { 0, 0, 0, 0.35 },           -- soft edge around the toggle
    thumb        = { 0.400, 0.440, 0.500, 0.9 }, -- scrollbar thumb
    closeHover   = { 1.000, 0.300, 0.300, 0.15 },
}
local T = W.T

-- Color codes for text
W.C = {
    gold = "|cffffd100", grey = "|cff949ba8", red = "|cffff5c5c", green = "|cff4ad173",
    blue = "|cff33a0ff", white = "|cffffffff", amber = "|cffffb040", r = "|r",
}

------------------------------------------------------------------------
-- Fonts: Roboto Bold (ships with MLZ UI) for headings and buttons, the game font for body text
------------------------------------------------------------------------
W.FONT = "Interface\\AddOns\\MLZ_UI\\Media\\Roboto-Bold.ttf"

local function MakeFont(name, size, color)
    local f = CreateFont(name)
    f:SetFont(W.FONT, size, "")
    if not f:GetFont() then f:SetFont(STANDARD_TEXT_FONT, size, "") end
    f:SetTextColor(unpack(color or T.text))
    f:SetShadowOffset(1, -1)
    f:SetShadowColor(0, 0, 0, 0.7)
    return f
end

MakeFont("MLZUI_FontTitle", 20)
MakeFont("MLZUI_FontHead", 14)
MakeFont("MLZUI_FontButton", 12)
MakeFont("MLZUI_FontSmallBold", 11)

------------------------------------------------------------------------
-- Basic helpers
------------------------------------------------------------------------
function W.Text(parent, font, text, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(true)
    if text then fs:SetText(text) end
    return fs
end

-- A texture filling the frame with one color
function W.Fill(frame, color, layer, sub)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
    t:SetAllPoints()
    t:SetColorTexture(unpack(color))
    return t
end

-- 1px border made of four textures. Returns a table with :SetColor(color).
function W.Border(frame, color)
    local b = {}
    local function Edge(p1, p2, horizontal)
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(unpack(color or T.border))
        t:SetPoint(p1)
        t:SetPoint(p2)
        if horizontal then t:SetHeight(1) else t:SetWidth(1) end
        b[#b + 1] = t
    end
    Edge("TOPLEFT", "TOPRIGHT", true)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
    Edge("TOPLEFT", "BOTTOMLEFT", false)
    Edge("TOPRIGHT", "BOTTOMRIGHT", false)
    function b:SetColor(c)
        for _, t in ipairs(self) do t:SetColorTexture(unpack(c)) end
    end
    return b
end

-- 1px horizontal line in the border color, anchored by the caller
function W.Line(parent, layer)
    local t = parent:CreateTexture(nil, layer or "BORDER")
    t:SetColorTexture(unpack(T.border))
    t:SetHeight(1)
    return t
end

-- Secondary text (muted color)
function W.Muted(parent, font, text, justify)
    local fs = W.Text(parent, font or "GameFontHighlightSmall", text, justify)
    fs:SetTextColor(unpack(T.muted))
    return fs
end

-- Tooltip helper. text may be a function returning the text.
function W.Tooltip(frame, title, text)
    frame:SetScript("OnEnter", function(self)
        local body = type(text) == "function" and text() or text
        if not title and not body then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if title then GameTooltip:SetText(title, unpack(T.white, 1, 3)) end
        if body then GameTooltip:AddLine(body, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

------------------------------------------------------------------------
-- Window: dark frame with its own title bar (icon, title, version, close button)
------------------------------------------------------------------------
function W.Window(name, width, height, title)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetSize(width, height)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:Hide()
    if name then tinsert(UISpecialFrames, name) end -- Esc closes

    f.bg = W.Fill(f, T.bg)
    f.border = W.Border(f, T.border)

    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", -1, -1)
    bar:SetHeight(36)
    W.Fill(bar, T.panel)
    local line = bar:CreateTexture(nil, "BORDER")
    line:SetColorTexture(unpack(T.border))
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() f:StartMoving() end)
    bar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    f.titleBar = bar

    local icon = bar:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", 14, 0) -- on the 14px rhythm, like the page content
    icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    f.TitleText = W.Text(bar, "MLZUI_FontHead", title or "MLZ UI")
    f.TitleText:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    f.TitleText:SetWordWrap(false)

    f.version = W.Text(bar, "GameFontDisableSmall", "v" .. (ns.version or ""))
    f.version:SetPoint("LEFT", f.TitleText, "RIGHT", 8, -1)

    local close = CreateFrame("Button", nil, bar)
    close:SetSize(36, 36)
    close:SetPoint("RIGHT", 0, 0)
    close.hl = W.Fill(close, T.closeHover, "HIGHLIGHT")
    close.x = W.Text(close, "MLZUI_FontHead", "X", "CENTER")
    close.x:SetPoint("CENTER")
    close.x:SetTextColor(unpack(T.muted))
    close:SetScript("OnEnter", function(s) s.x:SetTextColor(unpack(T.red)) end)
    close:SetScript("OnLeave", function(s) s.x:SetTextColor(unpack(T.muted)) end)
    close:SetScript("OnClick", function() f:Hide() end)
    f.closeButton = close

    return f
end

------------------------------------------------------------------------
-- Card: a section box
------------------------------------------------------------------------
function W.Card(parent)
    local c = CreateFrame("Frame", nil, parent)
    c.bg = W.Fill(c, T.card)
    c.border = W.Border(c, T.border)
    return c
end

------------------------------------------------------------------------
-- Button: flat, with styles "normal" | "primary" | "danger" | "subtle"
------------------------------------------------------------------------
local CLEAR = { 0, 0, 0, 0 }
local BUTTON_STYLES = {
    normal  = { bg = T.btn, hover = T.btnHover, border = T.border, text = T.text },
    primary = { bg = T.primary, hover = T.primaryHover, border = T.primaryEdge, text = T.white },
    danger  = { bg = T.danger, hover = T.dangerHover, border = T.dangerEdge, text = T.dangerText },
    subtle  = { bg = CLEAR, hover = T.shade, border = CLEAR, text = T.muted },
}
W.BUTTON_H = 24       -- buttons inside cards and lists
W.BUTTON_H_LARGE = 28 -- footer, banner and wizard navigation

function W.Button(parent, text, width, height, onClick, style)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 120, height or 24)
    b.bg = W.Fill(b, BUTTON_STYLES.normal.bg)
    b.border = W.Border(b, T.border)
    local fs = b:CreateFontString(nil, "OVERLAY", "MLZUI_FontButton")
    fs:SetPoint("CENTER")
    fs:SetWordWrap(false)
    b:SetFontString(fs)
    b.label = fs

    function b:SetStyle(name)
        self.style = BUTTON_STYLES[name] or BUTTON_STYLES.normal
        self.bg:SetColorTexture(unpack(self.hovered and self.style.hover or self.style.bg))
        self.border:SetColor(self.style.border)
        fs:SetTextColor(unpack(self.style.text))
    end
    b:SetScript("OnEnter", function(self)
        self.hovered = true
        if self:IsEnabled() then self.bg:SetColorTexture(unpack(self.style.hover)) end
        if self.tipTitle or self.tipText then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tipTitle or self:GetText() or "", unpack(T.white, 1, 3))
            if self.tipText then GameTooltip:AddLine(self.tipText, nil, nil, nil, true) end
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        self.hovered = false
        self.bg:SetColorTexture(unpack(self.style.bg))
        GameTooltip:Hide()
    end)
    b:SetScript("OnDisable", function(self)
        self:SetAlpha(0.4)
        self.bg:SetColorTexture(unpack(self.style.bg)) -- don't stay "hovered" when disabled under the mouse
    end)
    b:SetScript("OnEnable", function(self)
        self:SetAlpha(1)
        self.bg:SetColorTexture(unpack(self.hovered and self.style.hover or self.style.bg))
    end)
    b:SetStyle(style)
    b:SetText(text or "")
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

------------------------------------------------------------------------
-- Check: flat square checkbox (CheckButton, so SetChecked/GetChecked/Click work as usual)
------------------------------------------------------------------------
function W.Check(parent)
    local c = CreateFrame("CheckButton", nil, parent)
    c:SetSize(18, 18)
    c.bg = W.Fill(c, T.input)
    c.border = W.Border(c, T.inputEdge)
    local mark = c:CreateTexture(nil, "ARTWORK")
    mark:SetPoint("TOPLEFT", 3, -3)
    mark:SetPoint("BOTTOMRIGHT", -3, 3)
    mark:SetColorTexture(unpack(T.accent))
    c:SetCheckedTexture(mark)
    local dis = c:CreateTexture(nil, "ARTWORK")
    dis:SetPoint("TOPLEFT", 3, -3)
    dis:SetPoint("BOTTOMRIGHT", -3, 3)
    dis:SetColorTexture(unpack(T.off))
    c:SetDisabledCheckedTexture(dis)
    local hl = c:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(unpack(T.press))
    c:SetScript("OnDisable", function(self) self.border:SetColor(T.border) end)
    c:SetScript("OnEnable", function(self) self.border:SetColor(T.inputEdge) end)
    return c
end

------------------------------------------------------------------------
-- Toggle: an on/off switch. onChange(self, on). Optional label to the right.
-- SetChecked/GetChecked are aliases, so it can replace a checkbox.
------------------------------------------------------------------------
function W.Toggle(parent, onChange, label)
    local t = CreateFrame("Button", nil, parent)
    t:SetSize(48, 20) -- room for "OFF" next to the knob, with a gap
    t.bg = W.Fill(t, T.off)
    t.border = W.Border(t, T.edge)
    t.knob = t:CreateTexture(nil, "ARTWORK")
    t.knob:SetSize(16, 16)
    t.knob:SetColorTexture(unpack(T.knob))
    t.state = W.Text(t, "MLZUI_FontSmallBold", "", "CENTER")

    function t:SetOn(on)
        self.on = on and true or false
        self.knob:ClearAllPoints()
        self.state:ClearAllPoints()
        if self.on then
            self.bg:SetColorTexture(unpack(T.green))
            self.knob:SetPoint("RIGHT", -2, 0)
            self.state:SetPoint("LEFT", 5, 0)
            self.state:SetText("ON")
            self.state:SetTextColor(unpack(T.onText))
        else
            self.bg:SetColorTexture(unpack(T.off))
            self.knob:SetPoint("LEFT", 2, 0)
            self.state:SetPoint("RIGHT", -4, 0)
            self.state:SetText("OFF")
            self.state:SetTextColor(unpack(T.offText))
        end
    end
    t.SetChecked = t.SetOn
    function t:GetChecked() return self.on end

    t:SetScript("OnClick", function(self)
        self:SetOn(not self.on)
        if onChange then onChange(self, self.on) end
    end)
    t:SetScript("OnEnter", function(self) self.border:SetColor(T.accent) end)
    t:SetScript("OnLeave", function(self) self.border:SetColor(T.edge) end)
    t:SetScript("OnDisable", function(self) self:SetAlpha(0.35) end)
    t:SetScript("OnEnable", function(self) self:SetAlpha(1) end)

    if label then
        t.label = W.Text(t, "GameFontHighlight", label)
        t.label:SetPoint("LEFT", t, "RIGHT", 8, 0)
    end
    t:SetOn(false)
    return t
end

------------------------------------------------------------------------
-- Segmented: a row of joined buttons, one selected. options = { { value = , text = }, ... }
-- onSelect(value). :SetValue(value) marks the selected one.
------------------------------------------------------------------------
function W.Segmented(parent, options, onSelect, segWidth)
    local s = CreateFrame("Frame", nil, parent)
    segWidth = segWidth or 70
    -- Each segment is segWidth wide including one 1px line (outer border or divider), plus the closing border
    s:SetSize(segWidth * #options + 1, 22)
    W.Fill(s, T.input)
    W.Border(s, T.border)
    s.buttons = {}
    for i, o in ipairs(options) do
        local b = CreateFrame("Button", nil, s)
        b:SetSize(segWidth - 1, 20)
        b:SetPoint("LEFT", (i - 1) * segWidth + 1, 0)
        b.sel = W.Fill(b, T.accent)
        b.sel:Hide()
        b.hl = W.Fill(b, T.press, "HIGHLIGHT")
        b.text = W.Text(b, "MLZUI_FontButton", o.text, "CENTER")
        b.text:SetPoint("CENTER")
        b.value = o.value
        b:SetScript("OnClick", function()
            s:SetValue(o.value)
            if onSelect then onSelect(o.value) end
        end)
        if o.tip then W.Tooltip(b, o.text, o.tip) end
        if i > 1 then
            local sep = s:CreateTexture(nil, "BORDER")
            sep:SetColorTexture(unpack(T.border))
            sep:SetSize(1, 22)
            sep:SetPoint("LEFT", (i - 1) * segWidth, 0)
        end
        s.buttons[i] = b
    end
    function s:SetValue(v)
        self.value = v
        for _, b in ipairs(self.buttons) do
            local on = b.value == v
            b.sel:SetShown(on)
            b.text:SetTextColor(unpack(on and T.white or T.muted))
        end
    end
    return s
end

------------------------------------------------------------------------
-- Stepper: "<  value  >" for longer lists. options = { { value = , text = }, ... }
------------------------------------------------------------------------
function W.Stepper(parent, width, options, onSelect)
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(width, 22)
    W.Fill(s, T.input)
    W.Border(s, T.border)
    s.text = W.Text(s, "MLZUI_FontButton", "", "CENTER")
    s.text:SetPoint("LEFT", 24, 0)
    s.text:SetPoint("RIGHT", -24, 0)
    s.text:SetWordWrap(false)
    s.options = options
    local function Arrow(dir)
        local b = CreateFrame("Button", nil, s)
        b:SetSize(22, 20)
        b:SetPoint(dir < 0 and "LEFT" or "RIGHT", dir < 0 and 1 or -1, 0)
        b.hl = W.Fill(b, T.press, "HIGHLIGHT")
        b.t = W.Text(b, "MLZUI_FontHead", dir < 0 and "<" or ">", "CENTER")
        b.t:SetPoint("CENTER")
        b.t:SetTextColor(unpack(T.accent))
        b:SetScript("OnClick", function()
            local idx = 1
            for i, o in ipairs(s.options) do if o.value == s.value then idx = i end end
            idx = (idx - 1 + dir) % #s.options + 1
            s:SetValue(s.options[idx].value)
            if onSelect then onSelect(s.value) end
        end)
        return b
    end
    Arrow(-1)
    Arrow(1)
    function s:SetValue(v)
        self.value = v
        local text = tostring(v)
        for _, o in ipairs(self.options) do if o.value == v then text = o.text end end
        self.text:SetText(text)
    end
    return s
end

------------------------------------------------------------------------
-- Slider: flat horizontal slider with a value label.
-- onChange(value) while dragging (preview), onCommit(value) when the mouse is released.
------------------------------------------------------------------------
function W.Slider(parent, width, minV, maxV, step, fmt, onChange, onCommit)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, 22)
    local s = CreateFrame("Slider", nil, holder)
    s:SetOrientation("HORIZONTAL")
    s:SetPoint("LEFT", 0, 0)
    s:SetPoint("RIGHT", -52, 0)
    s:SetHeight(16)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s:EnableMouse(true)
    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(unpack(T.input))
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(6)
    local fill = s:CreateTexture(nil, "BORDER")
    fill:SetColorTexture(unpack(T.accent))
    fill:SetPoint("LEFT", track, "LEFT")
    fill:SetHeight(6)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(unpack(T.knob))
    thumb:SetSize(10, 16)
    s:SetThumbTexture(thumb)
    holder.value = W.Text(holder, "MLZUI_FontButton", "", "RIGHT")
    holder.value:SetPoint("RIGHT", 0, 0)
    holder.value:SetWidth(46)

    local function Round(v) return math.floor(v / step + 0.5) * step end
    local function Show(v)
        holder.value:SetText(fmt and fmt:format(v) or tostring(v))
        local w = s:GetWidth()
        if w and w > 0 then fill:SetWidth(math.max(1, (v - minV) / (maxV - minV) * w)) end
    end
    s:SetScript("OnValueChanged", function(_, v)
        v = Round(v)
        Show(v)
        if not holder.quiet and onChange then onChange(v) end
    end)
    s:SetScript("OnMouseUp", function()
        if onCommit then onCommit(Round(s:GetValue())) end
    end)
    s:SetScript("OnSizeChanged", function() Show(Round(s:GetValue())) end)
    function holder:SetValue(v)
        self.quiet = true
        s:SetValue(v)
        self.quiet = false
        Show(Round(v))
    end
    function holder:GetValue() return Round(s:GetValue()) end
    holder.slider = s
    return holder
end

------------------------------------------------------------------------
-- SearchBox: a flat one-line text field with a grey placeholder and a clear button.
-- onChange(text) on every change. The caller adds OnEnterPressed / OnArrowPressed as needed.
------------------------------------------------------------------------
function W.SearchBox(parent, width, placeholder, onChange)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(width, 26)
    e:SetAutoFocus(false)
    e:SetFontObject("GameFontHighlight")
    e:SetTextInsets(8, 24, 0, 0)
    e:SetMaxLetters(60)
    if e.SetAltArrowKeyMode then e:SetAltArrowKeyMode(false) end -- plain UP/DOWN reach OnArrowPressed
    e.bg = W.Fill(e, T.input)
    e.border = W.Border(e, T.border)

    e.placeholder = W.Muted(e, "GameFontHighlight", placeholder or "Search")
    e.placeholder:SetPoint("LEFT", 8, 0)
    e.placeholder:SetPoint("RIGHT", -24, 0)
    e.placeholder:SetWordWrap(false)

    local clear = CreateFrame("Button", nil, e)
    clear:SetSize(22, 22)
    clear:SetPoint("RIGHT", -2, 0)
    clear.hl = W.Fill(clear, T.press, "HIGHLIGHT")
    clear.x = W.Text(clear, "MLZUI_FontButton", "X", "CENTER")
    clear.x:SetPoint("CENTER")
    clear.x:SetTextColor(unpack(T.muted))
    clear:SetScript("OnClick", function() e:SetText(""); e:ClearFocus() end)
    clear:Hide()
    e.clear = clear

    local function Update(self)
        local text = self:GetText() or ""
        self.placeholder:SetShown(text == "")
        self.clear:SetShown(text ~= "")
    end
    e:SetScript("OnTextChanged", function(self)
        Update(self)
        if onChange then onChange(self:GetText() or "") end
    end)
    e:SetScript("OnEditFocusGained", function(self) self.border:SetColor(T.accent) end)
    e:SetScript("OnEditFocusLost", function(self) self.border:SetColor(T.border) end)
    -- ESC empties the field first, a second ESC lets go of the keyboard
    e:SetScript("OnEscapePressed", function(self)
        if (self:GetText() or "") ~= "" then self:SetText("") else self:ClearFocus() end
    end)
    e:SetScript("OnEnter", function(self) if not self:HasFocus() then self.border:SetColor(T.inputEdge) end end)
    e:SetScript("OnLeave", function(self) if not self:HasFocus() then self.border:SetColor(T.border) end end)
    return e
end

------------------------------------------------------------------------
-- Badge: colored square + short text. :Set(state, text), state = "on" | "off" | "warn" | "bad" | "info"
------------------------------------------------------------------------
local BADGE = {
    on = { T.green, "On" }, off = { T.off, "Off" }, warn = { T.amber, "Check" },
    bad = { T.red, "Problem" }, info = { T.accent, "" }, na = { T.off, "Not available" },
}
W.BADGE = BADGE

function W.Badge(parent)
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(120, 16)
    b.dot = b:CreateTexture(nil, "ARTWORK")
    b.dot:SetSize(8, 8)
    b.text = W.Text(b, "MLZUI_FontSmallBold", "", "RIGHT")
    b.text:SetPoint("RIGHT", 0, 0)
    b.text:SetWordWrap(false)
    b.dot:SetPoint("RIGHT", b.text, "LEFT", -6, 0)
    function b:Set(state, text)
        local s = BADGE[state] or BADGE.info
        self.dot:SetColorTexture(unpack(s[1]))
        -- natural width, but never wider than the badge (long text is cut with "...")
        self.text:SetWidth(0)
        self.text:SetText(text or s[2])
        local maxW = math.max(20, self:GetWidth() - 14)
        if self.text:GetStringWidth() > maxW then self.text:SetWidth(maxW) end
        self.text:SetTextColor(unpack(state == "off" and T.muted or state == "na" and T.muted or s[1]))
    end
    b:Set("off")
    return b
end

------------------------------------------------------------------------
-- Scroll area: ScrollFrame + content frame + thin scrollbar + mouse wheel
------------------------------------------------------------------------
function W.ScrollArea(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(1, 1)
    sf:SetScrollChild(content)
    sf.content = content

    local bar = CreateFrame("Slider", nil, sf)
    bar:SetWidth(5)
    bar:SetPoint("TOPLEFT", sf, "TOPRIGHT", 6, 0)
    bar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 6, 0)
    bar:SetOrientation("VERTICAL")
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    bar:EnableMouse(true)
    W.Fill(bar, T.shade)
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(unpack(T.thumb))
    thumb:SetSize(5, 40)
    bar:SetThumbTexture(thumb)
    bar:Hide()
    bar:SetScript("OnValueChanged", function(_, v)
        if not sf.syncing then sf:SetVerticalScroll(v) end
    end)
    sf.bar = bar

    local function Update()
        local h, ch = sf:GetHeight() or 0, content:GetHeight() or 0
        local max = math.max(0, ch - h)
        bar:SetMinMaxValues(0, max)
        bar:SetShown(max > 1)
        if h > 0 and ch > 0 then thumb:SetHeight(math.max(24, h * h / math.max(h, ch))) end
        if sf:GetVerticalScroll() > max then sf:SetVerticalScroll(max) end
    end
    sf.UpdateScroll = Update
    sf:SetScript("OnScrollRangeChanged", Update)
    sf:SetScript("OnVerticalScroll", function(self, offset)
        self.syncing = true
        bar:SetValue(offset)
        self.syncing = false
    end)
    sf:SetScript("OnSizeChanged", function(_, w)
        if w and w > 0 then content:SetWidth(w) end
        Update()
    end)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local _, max = bar:GetMinMaxValues()
        self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - delta * 50)))
    end)
    return sf
end
