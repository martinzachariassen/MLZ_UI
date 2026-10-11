-- MLZ UI: Installation wizard
-- Shows what each module will change (Preview), lets the user choose, takes a backup and applies (Apply).

local _, ns = ...
local W = ns.W
local C = W.C

local Installer = {}
ns.Installer = Installer

local APPLY_ORDER = { "scale", "settings", "layout", "bindings", "fade", "actionbuttons", "consumables", "tweaks" }

local PAGES = {
    { kind = "intro", title = "Welcome to MLZ UI" },
    { kind = "module", key = "scale", title = "1. Scaling",
      text = "Sets the UI scale so edges are crisp and everything is the same size regardless of resolution. The scale is recalculated automatically if you change resolution." },
    { kind = "module", key = "layout", title = "2. Layout (Edit Mode)",
      text = "Creates a dedicated Edit Mode layout with bars at bottom center, player/target on the sides, chat at bottom left and minimap/buffs at top right. You can fine-tune everything in Edit Mode afterwards. Requires /reload." },
    { kind = "module", key = "settings", title = "3. Settings",
      text = "Good default settings. Grey rows already have the right value. Hover over a row for an explanation." },
    { kind = "module", key = "bindings", title = "4. Keybinds",
      text = "Same 12 keys on three layers: no modifier = Bar 1, " .. C.gold .. "Shift" .. C.r .. " = Bar 2, " .. C.gold .. "Ctrl" .. C.r .. " = Bar 3. " .. C.red .. "Red" .. C.r .. " = the key currently has a different action. Displaced panels are moved to Alt." },
    { kind = "module", key = "fade", title = "5. Minimalism",
      text = "More of the world: things you rarely use stay invisible until you hover over them, and things you only need in combat are dimmed otherwise. Type /mlz fade to turn it off temporarily." },
    { kind = "module", key = "actionbuttons", title = "6. Action buttons",
      text = "See at a glance why a button isn't working: " .. C.red .. "red" .. C.r .. " = out of range, |cff5577ffblue|r = low mana, dark grey = can't be used right now. Short hotkeys and no macro names make for cleaner bars. /mlz buttons toggles the colors on/off." },
    { kind = "module", key = "consumables", title = "7. Bars without hotkeys",
      text = "Above the chat you get two click-only bars: at the bottom an " .. C.gold .. "auto bar" .. C.r .. " that fills itself with the best food, drink, potions, bandages, healthstone etc. from your bags, and above it " .. C.gold .. "bar 6" .. C.r .. ", which you fill yourself (hearthstone, mount, professions). Bar 6 and the placement are set in the layout step." },
    { kind = "module", key = "tweaks", title = "8. Tweaks",
      text = "Smaller things that declutter the screen. Tip: " .. C.gold .. "/mlz map" .. C.r .. " gives a slider for the minimap size, " .. C.gold .. "/mlz tracker" .. C.r .. ' toggles the "All Objectives" line, and ' .. C.gold .. "/mlz quests" .. C.r .. " hides the whole quest tracker." },
    { kind = "summary", title = "Summary" },
    { kind = "done", title = "Done!" },
}

local INTRO = table.concat({
    "This wizard sets up your UI step by step:",
    "",
    "  " .. C.gold .. "1." .. C.r .. " Scaling that fits your screen",
    "  " .. C.gold .. "2." .. C.r .. " Placement of bars and frames (dedicated Edit Mode layout)",
    "  " .. C.gold .. "3." .. C.r .. " Settings such as auto loot and cast on key down",
    "  " .. C.gold .. "4." .. C.r .. " Keybinds (ESDF and three layers of the same keys)",
    "  " .. C.gold .. "5." .. C.r .. " Minimalism: hide what you don't need so you see as much of the world as possible",
    "",
    "For each step you see what it is today and what it will be. You can turn off whole steps or individual rows.",
    "Nothing changes until you press " .. C.gold .. "Apply changes" .. C.r .. " on the last page.",
    "",
    C.green .. "A backup is always taken first." .. C.r .. " Type " .. C.gold .. "/mlz undo" .. C.r .. " to undo, and " .. C.gold .. "/mlz install" .. C.r .. " to open the wizard again.",
}, "\n")

local COL = { check = 4, label = 32, old = 270, arrow = 448, new = 468 }
local ROW_H = 22

------------------------------------------------------------------------
-- Window construction
------------------------------------------------------------------------
function Installer:Build()
    if self.frame then return end
    local f = CreateFrame("Frame", "MLZUI_Installer", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(760, 540)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    tinsert(UISpecialFrames, "MLZUI_Installer") -- ESC closes
    self.frame = f

    f.windowTitle = W.Text(f, "GameFontHighlight", "MLZ UI - Setup", "CENTER")
    f.windowTitle:SetPoint("TOP", 0, -5)

    f.title = W.Text(f, "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 20, -36)

    f.step = W.Text(f, "GameFontDisableSmall", nil, "RIGHT")
    f.step:SetPoint("TOPRIGHT", -20, -40)

    f.desc = W.Text(f, "GameFontHighlight")
    f.desc:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -10)
    f.desc:SetWidth(720)

    f.stepCheck = W.Check(f, "Use this step", function(_, checked)
        local page = PAGES[self.page]
        if page.key then
            self.stepOn[page.key] = checked
            self:RenderList()
        end
    end)
    f.stepCheck:SetPoint("TOPLEFT", f.desc, "BOTTOMLEFT", -4, -8)

    -- Column headers
    f.header = CreateFrame("Frame", nil, f)
    f.header:SetSize(700, 16)
    f.header:SetPoint("TOPLEFT", f.stepCheck, "BOTTOMLEFT", 4, -6)
    local function H(text, x) local t = W.Text(f.header, "GameFontNormalSmall", text); t:SetPoint("LEFT", x, 0) end
    H("What", COL.label); H("Current", COL.old); H("New", COL.new)

    f.scroll = W.ScrollArea(f)
    f.scroll:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -2)
    f.scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 52)
    f.scroll.content:SetWidth(700)

    f.big = W.Text(f, "GameFontHighlight")
    f.big:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -16)
    f.big:SetWidth(700)
    f.big:SetSpacing(4)

    -- Navigation
    f.back = W.Button(f, "Back", 110, 26, function() self:Go(self.page - 1) end)
    f.back:SetPoint("BOTTOMLEFT", 16, 14)
    f.next = W.Button(f, "Next", 150, 26, function() self:Next() end)
    f.next:SetPoint("BOTTOMRIGHT", -16, 14)
    f.skip = W.Button(f, "Skip", 110, 26, function()
        local page = PAGES[self.page]
        if page.key then self.stepOn[page.key] = false end
        self:Go(self.page + 1)
    end)
    f.skip:SetPoint("RIGHT", f.next, "LEFT", -8, 0)

    f.reload = W.Button(f, "Reload now", 150, 26, function() ReloadUI() end)
    f.reload:SetPoint("BOTTOMRIGHT", -16, 14)
    f.close = W.Button(f, "Close", 110, 26, function() f:Hide() end)
    f.close:SetPoint("RIGHT", f.reload, "LEFT", -8, 0)

    self.rows = {}
end

------------------------------------------------------------------------
-- Rows
------------------------------------------------------------------------
local function CreateRow(parent)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(ROW_H)
    r.hl = r:CreateTexture(nil, "BACKGROUND")
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(1, 1, 1, 0.05)
    r.hl:Hide()
    r.check = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
    r.check:SetSize(20, 20)
    r.check:SetPoint("LEFT", COL.check, 0)
    r.label = W.Text(r, "GameFontHighlightSmall")
    r.label:SetPoint("LEFT", COL.label, 0)
    r.label:SetWidth(COL.old - COL.label - 8)
    r.label:SetWordWrap(false)
    r.old = W.Text(r, "GameFontHighlightSmall")
    r.old:SetPoint("LEFT", COL.old, 0)
    r.old:SetWidth(COL.arrow - COL.old - 4)
    r.old:SetWordWrap(false)
    r.arrow = W.Text(r, "GameFontNormalSmall", ">")
    r.arrow:SetPoint("LEFT", COL.arrow, 0)
    r.new = CreateFrame("Button", nil, r)
    r.new:SetPoint("LEFT", COL.new, 0)
    r.new:SetSize(230, ROW_H)
    r.newText = W.Text(r.new, "GameFontHighlightSmall")
    r.newText:SetAllPoints()
    r.newText:SetWordWrap(false)
    r.groupText = W.Text(r, "GameFontNormal")
    r.groupText:SetPoint("LEFT", 4, -2)
    r:SetScript("OnEnter", function(self)
        self.hl:Show()
        if self.item and self.item.note then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:SetText(self.item.label:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""), 1, 1, 1)
            GameTooltip:AddLine(self.item.note, nil, nil, nil, true)
            GameTooltip:Show()
        end
    end)
    r:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)
    r.new:SetScript("OnEnter", function(self) self:GetParent():GetScript("OnEnter")(self:GetParent()) end)
    r.new:SetScript("OnLeave", function(self) self:GetParent():GetScript("OnLeave")(self:GetParent()) end)
    return r
end

function Installer:AcquireRow(i)
    local r = self.rows[i]
    if not r then
        r = CreateRow(self.frame.scroll.content)
        self.rows[i] = r
    end
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    r:SetPoint("RIGHT", self.frame.scroll.content, "RIGHT")
    r:Show()
    return r
end

local function SetGroupRow(r, text)
    r.item = nil
    r.check:Hide(); r.label:Hide(); r.old:Hide(); r.arrow:Hide(); r.new:Hide()
    r.groupText:SetText(text)
    r.groupText:Show()
end

-- readOnly = summary (no checkboxes, no clicks)
function Installer:SetItemRow(r, item, modKey, stepOn, readOnly)
    r.item = item
    r.groupText:Hide()
    r.label:Show(); r.old:Show(); r.arrow:Show(); r.new:Show()

    local active = stepOn and item.enabled and not item.unavailable
    local dim = not stepOn or item.unavailable or item.alreadySet

    r.label:SetText((dim and C.grey or C.white) .. item.label .. C.r)

    local old = item.old ~= nil and tostring(item.old) or ""
    if item.conflict and not dim then old = C.red .. old .. C.r else old = C.grey .. old .. C.r end
    r.old:SetText(old)

    local new = item.new ~= nil and tostring(item.new) or ""
    if item.choices and not readOnly then
        new = C.blue .. "< " .. new .. " >" .. C.r
    elseif item.alreadySet then
        new = C.grey .. new .. "  (already)" .. C.r
    elseif dim or not active then
        new = C.grey .. new .. C.r
    else
        new = C.green .. new .. C.r
    end
    r.newText:SetText(new)

    if readOnly then
        r.check:Hide()
        r.new:SetScript("OnClick", nil)
        return
    end

    r.check:Show()
    r.check:SetChecked(item.enabled and not item.unavailable)
    if item.unavailable or not stepOn then r.check:Disable() else r.check:Enable() end
    r.check:SetScript("OnClick", function(btn)
        item.enabled = btn:GetChecked() and true or false
        ns.SetEnabled(modKey, item.id, item.enabled)
        self:RenderList()
    end)

    if item.choices and stepOn then
        r.new:SetScript("OnClick", function() self:CycleChoice(modKey, item) end)
    else
        r.new:SetScript("OnClick", nil)
    end
end

function Installer:CycleChoice(modKey, item)
    local n = #item.choices
    item.choiceIndex = (item.choiceIndex or 1) % n + 1
    local choice = item.choices[item.choiceIndex]
    item.value, item.new = choice.value, choice.text
    if not item.enabled then
        item.enabled = true
        ns.SetEnabled(modKey, item.id, true)
    end
    local mod = ns.modules[modKey]
    if mod.OnChoice and mod:OnChoice(item) then
        self.items[modKey] = mod:Preview()
    end
    self:RenderList()
end

------------------------------------------------------------------------
-- Page rendering
------------------------------------------------------------------------
function Installer:RenderList()
    local f = self.frame
    local page = PAGES[self.page]
    for _, r in ipairs(self.rows) do r:Hide() end
    local n = 0

    if page.kind == "module" then
        local items = self.items[page.key] or {}
        local stepOn = self.stepOn[page.key]
        local lastGroup
        for _, item in ipairs(items) do
            if item.group and item.group ~= lastGroup then
                n = n + 1
                SetGroupRow(self:AcquireRow(n), item.group)
                lastGroup = item.group
            end
            n = n + 1
            self:SetItemRow(self:AcquireRow(n), item, page.key, stepOn, false)
        end
    elseif page.kind == "summary" then
        local sels = self:Selections()
        if #sels == 0 then
            n = n + 1
            SetGroupRow(self:AcquireRow(n), C.grey .. "Nothing selected." .. C.r)
        end
        for _, sel in ipairs(sels) do
            n = n + 1
            SetGroupRow(self:AcquireRow(n), ("%s  %s(%d changes)%s"):format(sel.mod.title, C.grey, #sel.items, C.r))
            for _, item in ipairs(sel.items) do
                if item.id ~= "__movement" then
                    n = n + 1
                    self:SetItemRow(self:AcquireRow(n), item, sel.mod.key, true, true)
                end
            end
        end
    end
    f.scroll.content:SetHeight(math.max(1, n * ROW_H))
end

function Installer:Go(index)
    if index < 1 or index > #PAGES then return end
    self.page = index
    local f = self.frame
    local page = PAGES[index]

    f.title:SetText(page.title)
    f.step:SetText(page.kind ~= "done" and ("Step %d of %d"):format(index, #PAGES - 1) or "")
    f.desc:SetText(page.text or "")

    local isList = page.kind == "module" or page.kind == "summary"
    f.scroll:SetShown(isList)
    f.header:SetShown(isList)
    f.desc:SetShown(page.kind == "module" or page.kind == "summary")
    f.stepCheck:SetShown(page.kind == "module")
    f.big:SetShown(page.kind == "intro" or page.kind == "done")

    if page.kind == "module" then
        f.stepCheck:SetChecked(self.stepOn[page.key])
    elseif page.kind == "summary" then
        f.desc:SetText("This will be changed when you press " .. C.gold .. "Apply changes" .. C.r .. ". A backup is taken first.")
    elseif page.kind == "intro" then
        f.big:SetText(INTRO)
    elseif page.kind == "done" then
        f.big:SetText(self.doneText or "")
    end

    local done = page.kind == "done"
    f.back:SetShown(not done)
    f.next:SetShown(not done)
    f.skip:SetShown(page.kind == "module")
    f.reload:SetShown(done)
    f.close:SetShown(done)
    f.back:SetEnabled(index > 1)
    f.next:SetText(page.kind == "summary" and "Apply changes" or "Next")

    f.scroll:SetVerticalScroll(0)
    self:RenderList()
end

function Installer:Next()
    local page = PAGES[self.page]
    if page.kind == "summary" then
        self:ApplyAll()
    else
        self:Go(self.page + 1)
    end
end

------------------------------------------------------------------------
-- Execution
------------------------------------------------------------------------
function Installer:Selections()
    local sels = {}
    for _, key in ipairs(APPLY_ORDER) do
        local mod = ns.modules[key]
        if mod and self.stepOn[key] and self.items[key] then
            local chosen = {}
            for _, item in ipairs(self.items[key]) do
                if item.enabled and not item.unavailable and not item.alreadySet then
                    chosen[#chosen + 1] = item
                end
            end
            -- The movement choice alone is not a change
            local real = 0
            for _, item in ipairs(chosen) do if item.id ~= "__movement" then real = real + 1 end end
            if real > 0 then sels[#sels + 1] = { mod = mod, items = chosen } end
        end
    end
    return sels
end

function Installer:ApplyAll()
    if InCombatLockdown() then
        ns.Print(C.red .. "You are in combat. Try again after combat." .. C.r)
        return
    end
    local sels = self:Selections()
    if #sels == 0 then
        ns.db.installed = true
        self.doneText = "Nothing was changed. You can open the wizard again with " .. C.gold .. "/mlz install" .. C.r .. "."
        self:Go(#PAGES)
        return
    end

    local backup = ns.Backup:Create(sels)
    if not backup then
        ns.Print(C.red .. "Aborted because the backup failed. Nothing was changed." .. C.r)
        return
    end

    local lines, failed = {}, 0
    for _, sel in ipairs(sels) do
        local ok, err = pcall(sel.mod.Apply, sel.mod, sel.items)
        if ok then
            lines[#lines + 1] = C.green .. "OK" .. C.r .. "  " .. sel.mod.title
        else
            failed = failed + 1
            lines[#lines + 1] = C.red .. "FAILED" .. C.r .. "  " .. sel.mod.title .. ": " .. tostring(err)
            ns.Print(C.red .. "Error in " .. sel.mod.title .. ":" .. C.r, err)
        end
    end
    ns.db.installed = true

    self.doneText = table.concat(lines, "\n") .. "\n\n" ..
        (failed > 0 and (C.red .. "Something failed. Type /mlz undo to undo, and pass on the error message." .. C.r .. "\n\n") or "") ..
        "Press " .. C.gold .. "Reload now" .. C.r .. " to reload the UI (required for layout and scaling).\n\n" ..
        "Undo: " .. C.gold .. "/mlz undo" .. C.r .. "     Run again: " .. C.gold .. "/mlz install" .. C.r
    self:Go(#PAGES)
end

------------------------------------------------------------------------
-- Opening
------------------------------------------------------------------------
function Installer:Open()
    if InCombatLockdown() then
        ns.Print("Cannot open the wizard in combat.")
        return
    end
    self:Build()
    self.items, self.stepOn = {}, {}
    for _, page in ipairs(PAGES) do
        if page.key then
            local mod = ns.modules[page.key]
            local ok, items = pcall(mod.Preview, mod)
            if ok then
                self.items[page.key] = items
            else
                ns.Print(C.red .. "Could not create preview for " .. mod.title .. ":" .. C.r, items)
                self.items[page.key] = {}
            end
            self.stepOn[page.key] = true
        end
    end
    self.frame:Show()
    self:Go(1)
end

ns.AddCommand("install", "opens the installation wizard", function() Installer:Open() end)

ns.On("PLAYER_REGEN_DISABLED", function()
    if Installer.frame and Installer.frame:IsShown() then
        Installer.frame:Hide()
        ns.Print("The wizard was closed because you entered combat. Reopen with /mlz install.")
    end
end)
