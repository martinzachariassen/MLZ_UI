-- MLZ UI: Minimap button (no libraries)
--   Left-click   opens/closes the control center
--   Right-click  quick menu (nameplate mode, healer, pause fading, reload ...)
--   Shift-click  reloads the UI, only when a reload is pending
--   Drag         moves the button around the minimap edge (saved in MLZUIDB.minimap.angle)
-- Also hooks into the addon compartment (the TOC lines AddonCompartmentFunc*) on clients that have it.

local _, ns = ...
local W = ns.W
local T, C = W.T, W.C

local MB = {}
ns.MinimapButton = MB

local button, menu

local function Cfg()
    ns.db.minimap = ns.db.minimap or { angle = 200 }
    return ns.db.minimap
end

------------------------------------------------------------------------
-- Position on the minimap edge
------------------------------------------------------------------------
local function Position()
    if not button then return end
    local mm = _G.Minimap
    local angle = math.rad(Cfg().angle or 200)
    local x, y = math.cos(angle), math.sin(angle)
    local r = mm:GetWidth() / 2 + 5
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if shape == "SQUARE" then
        -- stretch the circle out to the square edge
        local m = math.max(math.abs(x), math.abs(y))
        if m > 0 then x, y = x / m, y / m end
        r = mm:GetWidth() / 2
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", mm, "CENTER", x * r, y * r)
end

local function DragUpdate()
    local mm = _G.Minimap
    local mx, my = mm:GetCenter()
    if not mx then return end
    local px, py = GetCursorPosition()
    local s = mm:GetEffectiveScale()
    Cfg().angle = math.deg(math.atan2(py / s - my, px / s - mx))
    Position()
end

------------------------------------------------------------------------
-- Tooltip: live summary of what is on
------------------------------------------------------------------------
local tipOwner

local function ShowTooltip(owner)
    if not owner then return end
    tipOwner = owner
    GameTooltip:SetOwner(owner, owner == button and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
    GameTooltip:SetText("MLZ UI  " .. C.grey .. "v" .. ns.version .. C.r, 1, 1, 1)
    if not ns.db.installed then
        GameTooltip:AddLine("Not set up yet. Left-click to get started.", T.amber[1], T.amber[2], T.amber[3], true)
    end
    if ns.Settings and ns.Settings.Summary then
        for _, s in ipairs(ns.Settings.Summary()) do
            local b = W.BADGE[s.state] or W.BADGE.info
            local col = b[1]
            GameTooltip:AddDoubleLine(s.title, s.badge or b[2], 0.85, 0.86, 0.88, col[1], col[2], col[3])
        end
    end
    local paused = ns.Installer and ns.Installer.hiddenByCombat
    if paused then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Setup is paused. Left-click to continue.", T.amber[1], T.amber[2], T.amber[3], true)
    end
    if ns.needsReload then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(ns.Settings.ReloadText(), T.amber[1], T.amber[2], T.amber[3], true)
    elseif ns.editModeStale then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Reload before you open Edit Mode.", T.muted[1], T.muted[2], T.muted[3], true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(C.gold .. "Left-click" .. C.r .. (paused and " continue setup   " or " settings   ")
        .. C.gold .. "Right-click" .. C.r .. " quick menu", 0.8, 0.8, 0.8)
    GameTooltip:AddLine((ns.needsReload and (C.gold .. "SHIFT-click" .. C.r .. " reload UI   ") or "")
        .. C.gold .. "Drag" .. C.r .. " move", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

local function HideTooltip()
    tipOwner = nil
    GameTooltip:Hide()
end

------------------------------------------------------------------------
-- Quick menu (themed, no dropdown library)
------------------------------------------------------------------------
local items = {}

local function BuildMenu()
    local f = CreateFrame("Frame", "MLZUI_QuickMenu", UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetWidth(230)
    f:Hide()
    W.Fill(f, T.bg)
    W.Border(f, T.border)
    tinsert(UISpecialFrames, "MLZUI_QuickMenu")

    -- A click anywhere else closes the menu. GLOBAL_MOUSE_DOWN only listens; it doesn't eat the
    -- click, so camera turning and targeting keep working while the menu is open.
    -- Clicks on the button that opened the menu are left to that button (it toggles the menu).
    f:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
    f:SetScript("OnHide", function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
    f:SetScript("OnEvent", function(self)
        if self:IsMouseOver() then return end
        if self.owner and self.owner.IsMouseOver and self.owner:IsVisible() and self.owner:IsMouseOver() then return end
        self:Hide()
    end)

    local y = 8
    local function Header(text)
        local fs = W.Text(f, "MLZUI_FontSmallBold", text)
        fs:SetTextColor(unpack(T.muted))
        fs:SetPoint("TOPLEFT", 12, -(y + 4))
        y = y + 22
    end
    local function Divider()
        local line = W.Line(f)
        line:SetPoint("TOPLEFT", 8, -(y + 4))
        line:SetPoint("TOPRIGHT", -8, -(y + 4))
        y = y + 9
    end
    -- check() returns true/false for a marked item, nil for a plain action; enabled() may grey it out
    local function Item(text, fn, check, enabled, close)
        local b = CreateFrame("Button", nil, f)
        b:SetPoint("TOPLEFT", 4, -y)
        b:SetPoint("TOPRIGHT", -4, -y)
        b:SetHeight(22)
        W.Fill(b, W.T.press, "HIGHLIGHT")
        b.mark = b:CreateTexture(nil, "ARTWORK")
        b.mark:SetSize(8, 8)
        b.mark:SetPoint("LEFT", 10, 0)
        b.text = W.Text(b, "GameFontHighlight", text)
        b.text:SetPoint("LEFT", 26, 0)
        b.check, b.enabled = check, enabled
        b:SetScript("OnClick", function()
            if close then f:Hide() end
            fn()
            MB:RefreshMenu()
        end)
        items[#items + 1] = b
        y = y + 22
        return b
    end

    local NP = ns.NP

    Header("NAMEPLATES")
    Item("Auto (follow role)", function() NP.SetAuto(true) end, function() return NP.Auto() end, NP.Ready)
    for _, m in ipairs(NP.MODES) do
        Item(NP.MODE_TEXT[m], function() NP.SetMode(m) end,
            function() return not NP.Auto() and NP.Mode() == m end, NP.Ready)
    end
    Divider()
    Header("MY ROLE")
    Item("Auto (from talents)", function() ns.SetRoleForce(nil) end, function() return ns.GetRoleForce() == nil end)
    for _, r in ipairs({ "TANK", "HEALER", "DAMAGER" }) do
        Item(ns.ROLE_TEXT[r], function() ns.SetRoleForce(r) end, function() return ns.GetRoleForce() == r end)
    end
    Divider()
    Item("Pause fading", function() ns.modules.fade:SetPaused(not ns.fadePaused) end, function() return ns.fadePaused and true or false end)
    Item("FPS counter", function()
        local tw = ns.modules.tweaks
        tw:Set("fps", not tw:IsOn("fps"))
    end, function() return ns.modules.tweaks:IsOn("fps") end)
    Divider()
    Item("Open settings", function() ns.Settings:Open() end, nil, nil, true)
    Item("Setup wizard", function() if ns.Installer then ns.Installer:Open() end end, nil, nil, true)
    Item("My keybinds", function() if ns.Keys then ns.Keys.Open() end end, nil, nil, true)
    Item("Where did things go?", function() if ns.Tour then ns.Tour.Start() end end, nil, nil, true)
    f.reloadItem = Item("Reload UI", function() ReloadUI() end, nil, nil, true)

    f:SetHeight(y + 6)
    return f
end

function MB:RefreshMenu()
    if not (menu and menu:IsShown()) then return end
    for _, b in ipairs(items) do
        local on = b.enabled == nil or b.enabled()
        b:SetEnabled(on and true or false)
        b:SetAlpha(on and 1 or 0.4)
        if b.check then
            local checked = b.check()
            b.mark:Show()
            b.mark:SetColorTexture(unpack(checked and T.accent or T.off))
            b.text:SetTextColor(unpack(checked and T.text or T.muted))
        else
            b.mark:Hide()
            b.text:SetTextColor(unpack(T.text))
        end
    end
    local r = menu.reloadItem
    r.text:SetText(ns.needsReload and (C.amber .. "Reload UI (needed)" .. C.r) or "Reload UI")
end

function MB:ToggleMenu(owner)
    menu = menu or BuildMenu()
    if menu:IsShown() then
        menu:Hide()
        return
    end
    if InCombatLockdown() then return end -- the menu closes itself when combat starts
    HideTooltip()
    menu.owner = owner
    menu:ClearAllPoints()
    if owner == button and owner:GetCenter() then
        menu:SetPoint("TOPRIGHT", owner, "BOTTOMLEFT", 8, 8)
    else
        -- the addon compartment's rows are in a dropdown that closes on click: use the cursor
        local x, y = GetCursorPosition()
        local s = UIParent:GetEffectiveScale()
        menu:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", x / s, y / s)
    end
    menu:Show()
    self:RefreshMenu()
end

------------------------------------------------------------------------
-- The button
------------------------------------------------------------------------
local function Create()
    if button or not _G.Minimap then return end
    local b = CreateFrame("Button", "MLZUI_MinimapButton", _G.Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("AnyUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("TOPLEFT", 7, -6)
    b.icon = icon
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    -- Small amber dot when a reload is needed
    b.dot = b:CreateTexture(nil, "OVERLAY", nil, 2)
    b.dot:SetSize(6, 6)
    b.dot:SetColorTexture(unpack(T.amber))
    b.dot:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    b.dot:Hide()

    b:SetScript("OnClick", function(self, which)
        if which == "RightButton" then
            MB:ToggleMenu(self)
        elseif IsShiftKeyDown() then
            -- only when something is waiting for a reload, so a stray SHIFT-click costs nothing
            if ns.needsReload then ReloadUI() end
        elseif ns.Installer and ns.Installer.Resume and ns.Installer:Resume() then
            if menu then menu:Hide() end -- setup was paused for combat: pick it up again
        elseif ns.Settings then
            if menu then menu:Hide() end
            ns.Settings:Toggle()
        end
    end)
    b:SetScript("OnDragStart", function(self)
        HideTooltip()
        self:SetScript("OnUpdate", DragUpdate)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", function(self) if not (menu and menu:IsShown()) then ShowTooltip(self) end end)
    b:SetScript("OnLeave", HideTooltip)

    button = b
    Position()
    b:SetShown(not Cfg().hide)
end

local function UpdateButton()
    if button then button.dot:SetShown(ns.needsReload and true or false) end
end

function MB:SetHidden(hide)
    Cfg().hide = hide and true or nil
    if not button then Create() end
    if button then button:SetShown(not hide) end
    ns.FireState()
end

function MB:IsHidden() return Cfg().hide and true or false end

-- Called when the minimap shape changes (square minimap in Tweaks)
MB.Position = Position

ns.On("PLAYER_LOGIN", function()
    Create()
    UpdateButton()
end)

ns.On("PLAYER_REGEN_DISABLED", function()
    if menu then menu:Hide() end
end)

-- Keep the tooltip, the menu and the reload dot current
ns.OnState(function()
    UpdateButton()
    MB:RefreshMenu()
    if tipOwner and GameTooltip:IsShown() and GameTooltip:GetOwner() == tipOwner then ShowTooltip(tipOwner) end
end)

ns.AddCommand("minimap", "shows (or hides) the minimap button", function(arg)
    local hide = strlower(strtrim(arg or "")) == "hide"
    MB:SetHidden(hide)
    ns.Print("Minimap button:", hide and "hidden. /mlz minimap shows it again." or "shown.")
end)

------------------------------------------------------------------------
-- Addon compartment (clients that have it call these through the TOC)
------------------------------------------------------------------------
-- Newer clients pass a table ({ buttonName = "RightButton" }) instead of the button name
function MLZUI_OnAddonCompartmentClick(_, mouseButton, menuButtonFrame)
    if type(mouseButton) == "table" then mouseButton = mouseButton.buttonName end
    if mouseButton == "RightButton" then
        MB:ToggleMenu(nil)
    elseif ns.Settings then
        ns.Settings:Toggle()
    end
end

function MLZUI_OnAddonCompartmentEnter(_, menuButtonFrame)
    ShowTooltip(menuButtonFrame)
end

function MLZUI_OnAddonCompartmentLeave()
    HideTooltip()
end
