-- MLZ UI: "Show me around" tour (/mlz tour)
-- A few steps that draw a box around each frame Minimalism hides and say how to bring it back.
-- Offered on the last page of the setup wizard, in the minimap quick menu and on the overview.
-- Only reads frame positions and draws its own frames on top. Fading is paused while it runs.

local _, ns = ...
local W = ns.W
local T, C = W.T, W.C

local Tour = {}
ns.Tour = Tour

local PANEL_W, PAD = 320, 14

local MODE_HINT = {
    mouseover = "Hidden until you move the mouse over this spot. Its keybinds keep working.",
    combat = "Dimmed out of combat. Fully visible in combat, with a target, or when you hover it.",
    hideInCombat = "Hidden in combat so you can see the fight. It comes back when combat ends.",
    group = "Hidden when you play solo, shown in a party or raid. Hover this spot to peek.",
}

------------------------------------------------------------------------
-- Steps
------------------------------------------------------------------------
-- The area covered by these frames, in UIParent coordinates (left, bottom, right, top)
local function Rect(frames)
    local ui = UIParent:GetEffectiveScale()
    local l, b, r, t
    for _, f in ipairs(frames) do
        local fl, fb, fw, fh = f:GetRect()
        -- IsVisible, not IsShown: a frame inside a hidden parent has a size but is not on screen
        if fl and fw and fw > 0 and fh > 0 and f:IsVisible() then
            local s = f:GetEffectiveScale() / ui
            local x1, y1, x2, y2 = fl * s, fb * s, (fl + fw) * s, (fb + fh) * s
            l, b = l and math.min(l, x1) or x1, b and math.min(b, y1) or y1
            r, t = r and math.max(r, x2) or x2, t and math.max(t, y2) or y2
        end
    end
    if l then return l, b, r, t end
end

local function Steps()
    local steps = {}
    local fade = ns.modules.fade
    for _, row in ipairs(ns.data.fade or {}) do
        if fade:IsOn(row.id) then
            local frames = {}
            for _, name in ipairs(row.frames) do
                local f = _G[name]
                if f and f.GetRect then frames[#frames + 1] = f end
            end
            if #frames > 0 and Rect(frames) then
                steps[#steps + 1] = { title = row.label, text = MODE_HINT[row.mode] or row.desc, frames = frames }
            end
        end
    end
    if #steps == 0 then return steps end
    local mb = _G.MLZUI_MinimapButton
    if mb and mb:IsShown() then
        steps[#steps + 1] = { title = "MLZ UI button", frames = { mb },
            text = "Left-click for the settings, right-click for the quick menu. Pause fading there if you lose track of something." }
    end
    steps[#steps + 1] = { title = "That's it",
        text = "Turn any of this off in " .. C.white .. "/mlz" .. C.r .. " > Minimalism. "
            .. C.white .. "/mlz keys" .. C.r .. " shows your keybinds." }
    return steps
end

function Tour.HasSteps() return #Steps() > 0 end

------------------------------------------------------------------------
-- Frames
------------------------------------------------------------------------
local box, panel
local steps, index, wasPaused

local function Build()
    if panel then return end
    -- the highlight never takes clicks
    box = CreateFrame("Frame", nil, UIParent)
    box:SetFrameStrata("FULLSCREEN")
    box:EnableMouse(false)
    W.Fill(box, { T.accent[1], T.accent[2], T.accent[3], 0.10 })
    box.border = W.Border(box, T.accent)
    box:Hide()

    panel = CreateFrame("Frame", "MLZUI_Tour", UIParent)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetWidth(PANEL_W)
    panel:Hide()
    tinsert(UISpecialFrames, "MLZUI_Tour") -- Esc ends the tour
    W.Fill(panel, T.bg)
    W.Border(panel, T.border)
    local strip = panel:CreateTexture(nil, "ARTWORK")
    strip:SetColorTexture(unpack(T.accent))
    strip:SetPoint("TOPLEFT", 1, -1)
    strip:SetPoint("BOTTOMLEFT", 1, 1)
    strip:SetWidth(3)

    panel.title = W.Text(panel, "MLZUI_FontHead", "")
    panel.title:SetPoint("TOPLEFT", PAD + 2, -PAD)
    panel.count = W.Muted(panel, "GameFontDisableSmall", "", "RIGHT")
    panel.count:SetPoint("TOPRIGHT", -PAD, -PAD - 2)
    panel.body = W.Text(panel, "GameFontHighlight", "")
    panel.body:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -6)
    panel.body:SetWidth(PANEL_W - 2 * PAD - 2)

    panel.next = W.Button(panel, "Next", 90, 24, function() Tour.Go(index + 1) end, "primary")
    panel.next:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    panel.back = W.Button(panel, "Back", 80, 24, function() Tour.Go(index - 1) end)
    panel.back:SetPoint("RIGHT", panel.next, "LEFT", -8, 0)
    panel.skip = W.Button(panel, "End tour", 90, 24, function() panel:Hide() end, "subtle")
    panel.skip:SetPoint("BOTTOMLEFT", PAD - 4, PAD)

    panel:SetScript("OnHide", function()
        box:Hide()
        if ns.modules.fade and not wasPaused then ns.modules.fade:SetPaused(false) end
    end)
end

function Tour.Go(i)
    if not steps or i < 1 then return end
    if i > #steps then panel:Hide() return end
    index = i
    local step = steps[i]
    panel.title:SetText(step.title)
    panel.count:SetText(i .. " of " .. #steps)
    panel.body:SetText(step.text or "")
    panel.back:SetEnabled(i > 1)
    panel.next:SetText(i == #steps and "Done" or "Next")
    panel.skip:SetShown(i < #steps)
    panel:SetHeight(PAD + 20 + 6 + panel.body:GetStringHeight() + PAD + 24 + PAD)

    panel:ClearAllPoints()
    local l, b, r, t
    if step.frames then l, b, r, t = Rect(step.frames) end
    if not l then
        box:Hide()
        panel:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
        return
    end
    box:ClearAllPoints()
    box:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l - 4, b - 4)
    box:SetSize(r - l + 8, t - b + 8)
    box:Show()
    -- the panel goes on the side of the box with the most room. A tall box (side bars, raid frames)
    -- leaves no room above or below, so the panel goes left or right of it instead.
    local uiW, uiH = UIParent:GetWidth(), UIParent:GetHeight()
    if t - b > uiH * 0.4 then
        if (l + r) / 2 > uiW / 2 then
            panel:SetPoint("RIGHT", box, "LEFT", -12, 0)
        else
            panel:SetPoint("LEFT", box, "RIGHT", 12, 0)
        end
    elseif (b + t) / 2 < uiH / 2 then
        panel:SetPoint("BOTTOM", box, "TOP", 0, 12)
    else
        panel:SetPoint("TOP", box, "BOTTOM", 0, -12)
    end
end

function Tour.Start()
    if InCombatLockdown() then
        ns.Print("The tour can't run in combat. Try again after combat.")
        return
    end
    Build()
    -- Already running: just restart at the first step. Starting again would remember our own pause as the player's.
    if panel:IsShown() then
        Tour.Go(1)
        return
    end
    -- show every faded frame while the tour runs (paused first, so the positions are read while visible)
    wasPaused = ns.fadePaused and true or false
    if not wasPaused then ns.modules.fade:SetPaused(true) end
    steps = Steps()
    if #steps == 0 then
        if not wasPaused then ns.modules.fade:SetPaused(false) end
        ns.Print("Nothing is hidden right now, so there is nothing to show. Minimalism is in /mlz.")
        return
    end
    ns.db.tourSeen = true
    panel:Show()
    Tour.Go(1)
    ns.FireState()
end

ns.On("PLAYER_REGEN_DISABLED", function()
    if panel and panel:IsShown() then panel:Hide() end
end)

ns.AddCommand("tour", "shows where the hidden bars and buttons are", function() Tour.Start() end)
