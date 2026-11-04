-- MLZ UI: Keybind map (/mlz keys)
-- A drawing of the left half of the keyboard and the extra mouse buttons with what each key does,
-- one layer at a time (no modifier, SHIFT, CTRL, ALT). Read from the bindings the game has right now,
-- so it is right even after you change keys yourself. Also in the minimap quick menu and on the overview.

local _, ns = ...
local W = ns.W
local T, C = W.T, W.C

local Keys = {}
ns.Keys = Keys

local U, GAP = 56, 4          -- key size and gap
local KEY_H = 48
local PAD = 14

-- Each row: { key, width in keys, label } ; dead = a key that can't hold a binding here
local ROWS = {
    { { "`" }, { "1" }, { "2" }, { "3" }, { "4" }, { "5" }, { "6" } },
    { { "TAB", 1.5, "TAB" }, { "Q" }, { "W" }, { "E" }, { "R" }, { "T" }, { "Y" } },
    { { "CAPSLOCK", 1.75, "CAPS" }, { "A" }, { "S" }, { "D" }, { "F" }, { "G" }, { "H" } },
    { { "SHIFT", 1.75, "SHIFT", dead = true }, { "Z" }, { "X" }, { "C" }, { "V" }, { "B" }, { "N" } },
    { { "CTRL", 1.5, "CTRL", dead = true }, { "ALT", 1.25, "ALT", dead = true }, { "SPACE", 4.5, "SPACE" } },
}
local MOUSE = {
    { "BUTTON3", 1.75, "Middle" }, { "BUTTON4", 1.75, "Mouse 4" }, { "BUTTON5", 1.75, "Mouse 5" },
    { "MOUSEWHEELUP", 1.75, "Wheel up" }, { "MOUSEWHEELDOWN", 1.75, "Wheel down" },
}

local LAYERS = {
    { value = "", text = "No modifier" }, { value = "SHIFT-", text = "SHIFT" },
    { value = "CTRL-", text = "CTRL" }, { value = "ALT-", text = "ALT" },
}

-- Short names for common commands, so they fit on a key
local SHORT = {
    MOVEFORWARD = "Forward", MOVEBACKWARD = "Back", STRAFELEFT = "Strafe left", STRAFERIGHT = "Strafe right",
    TURNLEFT = "Turn left", TURNRIGHT = "Turn right", JUMP = "Jump", TOGGLEAUTORUN = "Autorun",
    SITORSTAND = "Sit", TOGGLERUN = "Walk/run", TARGETNEARESTENEMY = "Next enemy", TARGETNEARESTFRIEND = "Next friend",
    TARGETSELF = "Target me", ASSISTTARGET = "Assist", INTERACTTARGET = "Interact", INTERACTMOUSEOVER = "Interact",
    TOGGLEGAMEMENU = "Menu", OPENALLBAGS = "Bags", TOGGLEBACKPACK = "Backpack", TOGGLECHARACTER0 = "Character",
    TOGGLESPELLBOOK = "Spellbook", TOGGLETALENTS = "Talents", TOGGLEWORLDMAP = "Map", TOGGLEQUESTLOG = "Quests",
    TOGGLESOCIAL = "Social", TOGGLEGUILDTAB = "Guild", REPLY = "Reply", OPENCHAT = "Chat", OPENCHATSLASH = "Chat /",
    TOGGLEMINIMAP = "Minimap", TOGGLEUI = "Hide UI", SCREENSHOT = "Screenshot", PETATTACK = "Pet attack",
    CAMERAZOOMIN = "Zoom in", CAMERAZOOMOUT = "Zoom out", TOGGLEFPS = "FPS", TOGGLEPETBOOK = "Pet book",
    TOGGLEKEYRING = "Keyring", TOGGLEMOUNTJOURNAL = "Mounts", TOGGLECOLLECTIONS = "Collections",
}
local MOVEMENT = { MOVEFORWARD = true, MOVEBACKWARD = true, STRAFELEFT = true, STRAFERIGHT = true,
    TURNLEFT = true, TURNRIGHT = true, JUMP = true }

-- Binding command prefix -> the action button frames that hold its action slot
local BAR_BUTTONS = {
    ACTIONBUTTON = "ActionButton", MULTIACTIONBAR1BUTTON = "MultiBarBottomLeftButton",
    MULTIACTIONBAR2BUTTON = "MultiBarBottomRightButton", MULTIACTIONBAR3BUTTON = "MultiBarRightButton",
    MULTIACTIONBAR4BUTTON = "MultiBarLeftButton", MULTIACTIONBAR5BUTTON = "MultiBar5Button",
    MULTIACTIONBAR6BUTTON = "MultiBar6Button", MULTIACTIONBAR7BUTTON = "MultiBar7Button",
}

------------------------------------------------------------------------
-- What a key does
------------------------------------------------------------------------
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id))
end

local function ActionName(slot)
    local kind, id = GetActionInfo(slot)
    if kind == "spell" then return SpellName(id) end
    if kind == "macro" then return GetActionText(slot) or (GetMacroInfo and (GetMacroInfo(id))) end
    if kind == "item" then
        if C_Item and C_Item.GetItemNameByID then return C_Item.GetItemNameByID(id) end
        return GetItemInfo and (GetItemInfo(id))
    end
    return GetActionText(slot)
end

local function SlotFor(prefix, n)
    local base = BAR_BUTTONS[prefix]
    if not base then return nil end
    local btn = _G[base .. n]
    local slot = btn and (btn.action or (btn.GetAttribute and btn:GetAttribute("action")))
    if not slot and prefix == "ACTIONBUTTON" then slot = tonumber(n) end
    return tonumber(slot)
end

-- Returns { cmd, name (what it is called in Blizzard's key bindings), what (spell, item...), icon, empty }
local function DescribeCommand(cmd)
    local d = { cmd = cmd, name = _G["BINDING_NAME_" .. cmd] or (ns.KeyEdit and ns.KeyEdit.Name(cmd)) or cmd }
    local prefix, n = cmd:match("^(.-BUTTON)(%d+)$")
    if prefix then
        local slot = SlotFor(prefix, n)
        if slot then
            d.icon = GetActionTexture(slot)
            d.what = d.icon and ActionName(slot)
            d.empty = not d.icon
        elseif prefix == "SHAPESHIFTBUTTON" and GetShapeshiftFormInfo then
            local icon, _, _, spellID = GetShapeshiftFormInfo(tonumber(n))
            d.icon, d.what = icon, spellID and SpellName(spellID)
            d.empty = not icon
        elseif prefix == "BONUSACTIONBUTTON" and GetPetActionInfo then
            local name, icon, isToken = GetPetActionInfo(tonumber(n))
            if isToken then name, icon = _G[name] or name, _G[icon] or icon end
            d.icon, d.what = icon, name
            d.empty = not icon
        end
    end
    d.short = d.what or SHORT[cmd] or d.name
    return d
end

local function Describe(key)
    local cmd = GetBindingAction(key, true)
    if not cmd or cmd == "" then return nil end
    return DescribeCommand(cmd)
end

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------
local frame, cells, layer = nil, {}, ""
local editing, picked -- "Change keys" mode, and the cell whose key is being changed
local OpenPicker, ClosePicker

local function Cell(parent, entry, x, y)
    local key, width, label = entry[1], entry[2] or 1, entry[3]
    local c = CreateFrame("Frame", nil, parent)
    c:SetSize(width * U + (width - 1) * GAP, KEY_H)
    c:SetPoint("TOPLEFT", x, -y)
    c.bg = W.Fill(c, T.input)
    c.border = W.Border(c, T.border)
    c.cap = W.Text(c, "MLZUI_FontSmallBold", label or key)
    c.cap:SetPoint("TOPLEFT", 4, -3)
    c.cap:SetTextColor(unpack(T.muted))
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(20, 20)
    c.icon:SetPoint("TOPRIGHT", -3, -3)
    c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    c.text = W.Text(c, "GameFontHighlightSmall", "", "LEFT")
    c.text:SetPoint("BOTTOMLEFT", 4, 4)
    c.text:SetPoint("BOTTOMRIGHT", -3, 4)
    c.text:SetWordWrap(false)
    -- movement keys: a 3px accent strip on the left, the same way selection is shown everywhere else
    c.strip = c:CreateTexture(nil, "ARTWORK")
    c.strip:SetColorTexture(unpack(T.accent))
    c.strip:SetPoint("TOPLEFT", 1, -1)
    c.strip:SetPoint("BOTTOMLEFT", 1, 1)
    c.strip:SetWidth(3)
    c.strip:Hide()
    c.key, c.label, c.dead = key, label or key, entry.dead
    if c.dead then
        c.bg:SetColorTexture(unpack(T.panel))
        return c
    end
    c:EnableMouse(true)
    c:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(layer .. self.label, T.text[1], T.text[2], T.text[3]) -- "SHIFT-CAPS", as on the key
        local d = self.d
        if d then
            GameTooltip:AddLine(d.name, T.text[1], T.text[2], T.text[3], true)
            if d.what then GameTooltip:AddLine(d.what, T.accent[1], T.accent[2], T.accent[3], true) end
            if d.empty then GameTooltip:AddLine("Nothing on this button yet.", T.muted[1], T.muted[2], T.muted[3], true) end
        else
            GameTooltip:AddLine("Not bound. A free key for something new.", T.muted[1], T.muted[2], T.muted[3], true)
        end
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    c:SetScript("OnMouseUp", function(self)
        if editing then OpenPicker(self) end
    end)
    cells[#cells + 1] = c
    return c
end

local function Fill()
    if not (frame and frame:IsShown()) then return end
    local free = 0
    for _, c in ipairs(cells) do
        local d = Describe(layer .. c.key)
        c.d = d
        c.icon:SetShown(d and d.icon and true or false)
        if d and d.icon then c.icon:SetTexture(d.icon) end
        if not d then
            free = free + 1
            c.text:SetText("")
            c.bg:SetColorTexture(unpack(T.input))
            c.strip:Hide()
        else
            c.text:SetText(d.empty and (C.grey .. "empty" .. C.r) or d.short)
            c.bg:SetColorTexture(unpack(T.card))
            c.strip:SetShown(MOVEMENT[d.cmd] and true or false)
        end
        c.border:SetColor(c == picked and T.accent or T.border)
    end
    if frame.message then
        frame.foot:SetText(frame.message)
    elseif editing then
        frame.foot:SetText("Click a key to choose what it does. /mlz undo puts your keys back.")
    else
        frame.foot:SetText(("%d of these keys are free on this layer. Blue strip = movement. Hover a key for details.")
            :format(free))
    end
end

------------------------------------------------------------------------
-- Picker: what the clicked key should do
------------------------------------------------------------------------
local PICK_W, ROW_H = 330, 24

local function Matches(text, query)
    return query == "" or text:lower():find(query, 1, true) ~= nil
end

local function BuildPicker()
    local KE = ns.KeyEdit
    local pk = CreateFrame("Frame", nil, frame)
    pk:SetPoint("TOPLEFT", frame, "TOPRIGHT", 6, 0)
    pk:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 6, 0)
    pk:SetWidth(PICK_W)
    pk:EnableMouse(true)
    W.Fill(pk, T.bg)
    W.Border(pk, T.border)

    pk.title = W.Text(pk, "MLZUI_FontHead", "")
    pk.title:SetPoint("TOPLEFT", PAD, -PAD)
    pk.now = W.Muted(pk, "GameFontHighlightSmall", "", "LEFT")
    pk.now:SetPoint("TOPLEFT", pk.title, "BOTTOMLEFT", 0, -6)
    pk.now:SetWidth(PICK_W - 2 * PAD)
    pk.now:SetWordWrap(false)

    pk.search = W.SearchBox(pk, PICK_W - 2 * PAD, "Find an action", function() pk:Refresh() end)
    pk.search:SetPoint("TOPLEFT", PAD, -(PAD + 44))

    local use = W.Button(pk, "Use this key", 130, W.BUTTON_H, nil, "primary")
    use:SetPoint("BOTTOMLEFT", PAD, PAD)
    local clear = W.Button(pk, "Clear key", 100, W.BUTTON_H, nil, "danger")
    clear:SetPoint("LEFT", use, "RIGHT", 6, 0)
    clear.tipText = "The key does nothing afterwards."
    local close = W.Button(pk, "Close", 64, W.BUTTON_H, function() ClosePicker() Fill() end, "subtle")
    close:SetPoint("BOTTOMRIGHT", -PAD, PAD)

    pk.result = W.Text(pk, "GameFontHighlightSmall", "", "LEFT")
    pk.result:SetPoint("BOTTOMLEFT", use, "TOPLEFT", 0, 10)
    pk.result:SetWidth(PICK_W - 2 * PAD)

    local list = W.ScrollArea(pk)
    list:SetPoint("TOPLEFT", pk.search, "BOTTOMLEFT", 0, -8)
    list:SetPoint("BOTTOMRIGHT", pk, "BOTTOMRIGHT", -(PAD + 8), PAD + W.BUTTON_H + 52)
    pk.list = list
    pk.rows = {}

    local function Row(i)
        local r = pk.rows[i]
        if r then return r end
        r = CreateFrame("Button", nil, list.content)
        r:SetHeight(ROW_H)
        r.hl = W.Fill(r, T.shade, "HIGHLIGHT")
        r.strip = r:CreateTexture(nil, "ARTWORK")
        r.strip:SetColorTexture(unpack(T.accent))
        r.strip:SetPoint("TOPLEFT")
        r.strip:SetPoint("BOTTOMLEFT")
        r.strip:SetWidth(3)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(18, 18)
        r.icon:SetPoint("LEFT", 8, 0)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.text = W.Text(r, "GameFontHighlightSmall", "", "LEFT")
        r.text:SetPoint("LEFT", 32, 0)
        r.text:SetPoint("RIGHT", -52, 0)
        r.text:SetWordWrap(false)
        r.keys = W.Muted(r, "MLZUI_FontSmallBold", "", "RIGHT")
        r.keys:SetPoint("RIGHT", -4, 0)
        r.keys:SetWidth(48)
        r.keys:SetWordWrap(false)
        r.head = W.Muted(r, "MLZUI_FontSmallBold", "", "LEFT")
        r.head:SetPoint("BOTTOMLEFT", 2, 4)
        r:SetScript("OnClick", function(self)
            if not self.cmd then return end
            pk.cmd = self.cmd
            pk:Refresh()
        end)
        pk.rows[i] = r
        return r
    end

    function pk:Plan()
        if not self.key then return nil end
        if self.clearing then return KE.Plan(self.key, nil) end
        return self.cmd and KE.Plan(self.key, self.cmd) or nil
    end

    function pk:Refresh()
        local key = self.key
        if not key then return end
        self.title:SetText(key)
        local cur = Describe(key)
        local nowText = cur and (KE.Name(cur.cmd) .. (cur.what and ("  (" .. cur.what .. ")") or "")) or "not bound"
        self.now:SetText("Now: " .. nowText)

        local query = (self.search:GetText() or ""):lower()
        local n, y, width = 0, 0, list:GetWidth() or (PICK_W - 2 * PAD - 8)
        for _, group in ipairs(KE.Actions()) do
            local shown = {}
            for _, a in ipairs(group.list) do
                local d = DescribeCommand(a[1])
                local label = a[2] .. ((d.what and not d.empty) and ("  " .. C.grey .. d.what .. C.r) or "")
                if Matches(a[2] .. " " .. (d.what or "") .. " " .. group.title, query) then
                    shown[#shown + 1] = { cmd = a[1], label = label, icon = d.icon }
                end
            end
            if #shown > 0 then
                n = n + 1
                local h = Row(n)
                h.cmd = nil
                h:SetPoint("TOPLEFT", 0, -y)
                h:SetWidth(width)
                h.head:SetText(group.title:upper())
                h.head:Show(); h.text:Hide(); h.keys:Hide(); h.icon:Hide(); h.strip:Hide(); h.hl:Hide()
                h:Show()
                y = y + ROW_H
                for _, a in ipairs(shown) do
                    n = n + 1
                    local r = Row(n)
                    r.cmd = a.cmd
                    r:SetPoint("TOPLEFT", 0, -y)
                    r:SetWidth(width)
                    r.head:Hide(); r.text:Show(); r.keys:Show(); r.hl:Show()
                    r.text:SetText(a.label)
                    r.icon:SetShown(a.icon and true or false)
                    if a.icon then r.icon:SetTexture(a.icon) end
                    r.keys:SetText((GetBindingKey(a.cmd)) or "")
                    r.strip:SetShown(a.cmd == self.cmd and not self.clearing)
                    r:Show()
                    y = y + ROW_H
                end
            end
        end
        for i = n + 1, #self.rows do self.rows[i]:Hide() end
        list.content:SetHeight(math.max(1, y))
        list.UpdateScroll()

        local plan = self:Plan()
        self.result:SetText(plan and KE.Describe(plan) or (C.grey .. "Pick an action in the list." .. C.r))
        use:SetEnabled(plan ~= nil and not plan.same and not self.clearing)
        clear:SetEnabled(cur ~= nil)
    end

    local function Run(plan)
        local ok, why = KE.Apply(plan)
        if ok then
            local what = plan.cmd and (" now does: " .. KE.Name(plan.cmd)) or " is free now"
            frame.message = C.green .. plan.key .. C.r .. what .. ". /mlz undo puts it back."
            pk.cmd, pk.clearing = nil, false
        else
            frame.message = C.amber .. (why or "The key was not changed.") .. C.r
        end
        Fill()
        pk:Refresh()
    end
    use:SetScript("OnClick", function()
        local plan = pk:Plan()
        if plan then Run(plan) end
    end)
    clear:SetScript("OnClick", function()
        pk.clearing = true
        local plan = pk:Plan()
        pk.clearing = false
        if plan then Run(plan) end
    end)
    return pk
end

function OpenPicker(cell)
    picked = cell
    frame.picker = frame.picker or BuildPicker()
    local pk = frame.picker
    pk.key, pk.cmd, pk.clearing = layer .. cell.key, nil, false
    pk.search:SetText("")
    frame.message = nil
    pk:Show()
    pk:Refresh()
    Fill()
end

function ClosePicker()
    picked = nil
    if frame and frame.picker then frame.picker:Hide() end
end

-- Width of a key that is n keys wide, and of a whole row (keys plus the gaps between them)
local function KeyW(n) return n * U + (n - 1) * GAP end
local function RowW(row)
    local w = 0
    for _, entry in ipairs(row) do w = w + KeyW(entry[2] or 1) end
    return w + (#row - 1) * GAP
end

local function Build()
    if frame then return end
    local kbW = 0
    for _, row in ipairs(ROWS) do kbW = math.max(kbW, RowW(row)) end
    local mouseW = 0
    for _, entry in ipairs(MOUSE) do mouseW = math.max(mouseW, KeyW(entry[2] or 1)) end
    local keysH = math.max(#ROWS, #MOUSE) * (KEY_H + GAP) - GAP
    local width = PAD + kbW + PAD + mouseW + PAD
    local height = 36 + PAD + 22 + PAD + keysH + PAD + 16 + PAD
    frame = W.Window("MLZUI_Keys", width, height, "My keybinds")

    local seg = W.Segmented(frame, LAYERS, function(v)
        layer = v
        ClosePicker()
        Fill()
    end, 86)
    seg:SetPoint("TOPLEFT", PAD, -(36 + PAD))
    seg:SetValue(layer)
    local wizard = W.Button(frame, "Setup wizard", 120, 22, function()
        if InCombatLockdown() then
            frame.message = C.amber .. "Keys can't be changed in combat. Try again after combat." .. C.r
            Fill()
            return
        end
        frame:Hide()
        if ns.Installer then ns.Installer:Open("bindings") end
    end, "subtle")
    wizard:SetPoint("TOPRIGHT", -PAD, -(36 + PAD))
    wizard.tipText = "Opens the Keybinds step of the setup wizard: ESDF or WASD and every bar key at once."
    local change = W.Button(frame, "Change keys", 120, 22)
    change:SetPoint("RIGHT", wizard, "LEFT", -6, 0)
    change.tipText = "Click a key on the map, then pick what it does. Every change can be undone with /mlz undo."
    change:SetScript("OnClick", function(self)
        editing = not editing
        self:SetText(editing and "Done" or "Change keys")
        self:SetStyle(editing and "primary" or "normal")
        frame.message = nil
        if not editing then ClosePicker() end
        Fill()
    end)
    frame.change = change

    local top = 36 + PAD + 22 + PAD
    for r, row in ipairs(ROWS) do
        local x = PAD
        for _, entry in ipairs(row) do
            local c = Cell(frame, entry, x, top + (r - 1) * (KEY_H + GAP))
            x = x + c:GetWidth() + GAP
        end
    end
    local mx = PAD + kbW + PAD
    for i, entry in ipairs(MOUSE) do
        Cell(frame, entry, mx, top + (i - 1) * (KEY_H + GAP))
    end

    frame.foot = W.Muted(frame, "GameFontDisableSmall", "")
    frame.foot:SetPoint("BOTTOMLEFT", PAD, PAD)

    frame:SetScript("OnShow", Fill)
    frame:SetScript("OnEvent", function()
        Fill()
        if frame.picker and frame.picker:IsShown() then frame.picker:Refresh() end
    end)
    frame:SetScript("OnHide", function()
        editing, frame.message = false, nil
        change:SetText("Change keys")
        change:SetStyle("normal")
        ClosePicker()
        if ns.KeyEdit then ns.KeyEdit.EndSession() end
    end)
    for _, event in ipairs({ "UPDATE_BINDINGS", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED",
        "UPDATE_SHAPESHIFT_FORMS", "PET_BAR_UPDATE" }) do
        pcall(frame.RegisterEvent, frame, event)
    end
end

-- edit = true opens the map in "Change keys" mode (the button on the Your role page)
function Keys.Open(edit)
    Build()
    frame:Show()
    if edit and not editing then frame.change:GetScript("OnClick")(frame.change) end
    Fill()
end

-- Opens the picker for a key on the current layer ("Q"). Returns the picker, or nil for a key not on the map.
function Keys.Pick(key)
    Keys.Open(true)
    for _, c in ipairs(cells) do
        if c.key == key then
            OpenPicker(c)
            return frame.picker
        end
    end
end

function Keys.Toggle()
    if frame and frame:IsShown() then frame:Hide() else Keys.Open() end
end

ns.AddCommand("keys", "shows a map of your keybinds", function() Keys.Toggle() end)
