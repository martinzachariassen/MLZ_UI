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
    { { "TAB", 1.5, "Tab" }, { "Q" }, { "W" }, { "E" }, { "R" }, { "T" }, { "Y" } },
    { { "CAPSLOCK", 1.75, "Caps" }, { "A" }, { "S" }, { "D" }, { "F" }, { "G" }, { "H" } },
    { { "SHIFT", 1.75, "Shift", dead = true }, { "Z" }, { "X" }, { "C" }, { "V" }, { "B" }, { "N" } },
    { { "CTRL", 1.5, "Ctrl", dead = true }, { "ALT", 1.25, "Alt", dead = true }, { "SPACE", 4.5, "Space" } },
}
local MOUSE = {
    { "BUTTON3", 1.75, "Middle" }, { "BUTTON4", 1.75, "Mouse 4" }, { "BUTTON5", 1.75, "Mouse 5" },
    { "MOUSEWHEELUP", 1.75, "Wheel up" }, { "MOUSEWHEELDOWN", 1.75, "Wheel down" },
}

local LAYERS = {
    { value = "", text = "Base" }, { value = "SHIFT-", text = "SHIFT" },
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
local function Describe(key)
    local cmd = GetBindingAction(key, true)
    if not cmd or cmd == "" then return nil end
    local d = { cmd = cmd, name = _G["BINDING_NAME_" .. cmd] or cmd }
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

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------
local frame, cells, layer = nil, {}, ""

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
    c.key, c.dead = key, entry.dead
    if c.dead then
        c.bg:SetColorTexture(unpack(T.panel))
        return c
    end
    c:EnableMouse(true)
    c:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(layer .. self.key, 1, 1, 1)
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
            c.border:SetColor(T.border)
        else
            c.text:SetText(d.empty and (C.grey .. "empty" .. C.r) or d.short)
            c.bg:SetColorTexture(unpack(T.card))
            c.border:SetColor(MOVEMENT[d.cmd] and T.accent or T.border)
        end
    end
    frame.foot:SetText(("%d of these keys are free on this layer. Blue edge = movement. Hover a key for details.")
        :format(free))
end

local function Build()
    if frame then return end
    local kbW = 7.75 * U + 7 * GAP + 2 * GAP -- widest row (caps lock row)
    local mouseW = 1.75 * U + GAP
    local width = PAD + kbW + PAD + mouseW + PAD
    local height = 36 + PAD + 22 + PAD + #ROWS * (KEY_H + GAP) + PAD + 16 + PAD
    frame = W.Window("MLZUI_Keys", width, height, "My keybinds")

    local seg = W.Segmented(frame, LAYERS, function(v)
        layer = v
        Fill()
    end, 70)
    seg:SetPoint("TOPLEFT", PAD, -(36 + PAD))
    seg:SetValue(layer)
    local hint = W.Muted(frame, "GameFontDisableSmall", "Change keys in the setup wizard (Keybinds step) or in Blizzard's key bindings.")
    hint:SetPoint("LEFT", seg, "RIGHT", PAD, 0)

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
    frame:SetScript("OnEvent", Fill)
    for _, event in ipairs({ "UPDATE_BINDINGS", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED",
        "UPDATE_SHAPESHIFT_FORMS", "PET_BAR_UPDATE" }) do
        pcall(frame.RegisterEvent, frame, event)
    end
end

function Keys.Open()
    Build()
    frame:Show()
    Fill()
end

function Keys.Toggle()
    if frame and frame:IsShown() then frame:Hide() else Keys.Open() end
end

ns.AddCommand("keys", "shows a map of your keybinds", function() Keys.Toggle() end)
