-- MLZ UI: Installation wizard
-- Shows what each module will change (Preview), lets the user choose, takes a backup and applies (Apply).
--
-- Fields a module can put on a preview item (besides id, label, old, new, value, note, group):
--   enabled      ticked or not
--   unavailable  can't be applied (greyed out, no checkbox)
--   alreadySet   already has the right value (no checkbox, shown as "(already)")
--   toggle/isOn  on/off row: ticked = on, unticked = off. A change when it differs from isOn.
--                offText = what "off" is called in the New column.
--   requires     id of another row in the same step that must be applied for this one to apply
--   fixed        always passed to Apply but never a change by itself (e.g. the movement choice)
--   choices/choiceIndex  clickable value; the module may implement OnChoice(item)
--   conflict     the key/value currently does something else (Current shown in red)

local _, ns = ...
local W = ns.W
local C = W.C

local Installer = {}
ns.Installer = Installer

local APPLY_ORDER = { "scale", "settings", "layout", "bindings", "fade", "actionbuttons", "tweaks", "addons", "nameplates" }

-- Module pages are numbered automatically ("3. Settings", "Step 3 of 9"); `blurb` is the line in the intro.
local PAGES = {
    { kind = "intro", title = "Welcome to MLZ UI" },
    { kind = "module", key = "scale", title = "Scaling", blurb = "Scaling that fits your screen",
      text = "Sets the UI scale so edges are crisp and everything is the same size regardless of resolution. The scale is recalculated automatically if you change resolution." },
    { kind = "module", key = "layout", title = "Layout (Edit Mode)", blurb = "Placement of bars and frames (a dedicated Edit Mode layout)",
      text = "Creates a dedicated Edit Mode layout with bars at bottom center, player/target on the sides, chat at bottom left and minimap/buffs at top right. You can fine-tune everything in Edit Mode afterwards. Requires /reload." },
    { kind = "module", key = "settings", title = "Settings", blurb = "Settings such as auto loot and cast on key down",
      text = "Good default settings. Rows marked (already) have the right value. Hover over a row for an explanation." },
    { kind = "module", key = "bindings", title = "Keybinds", blurb = "Keybinds: ESDF or WASD, three layers of the same keys",
      text = "Same 12 keys on three layers: no modifier = Bar 1, " .. C.gold .. "Shift" .. C.r .. " = Bar 2, " .. C.gold .. "Ctrl" .. C.r .. " = Bar 3. " .. C.red .. "Red" .. C.r .. " = the key currently has a different action. Displaced panels are moved to Alt." },
    { kind = "module", key = "fade", title = "Minimalism", blurb = "Minimalism: hide what you rarely need, see more of the world",
      text = "Things you rarely use stay invisible until you hover over them, and things you only need in combat are dimmed otherwise. Untick a row that is on to turn it off. " .. C.gold .. "/mlz fade" .. C.r .. " pauses it until the next reload." },
    { kind = "module", key = "actionbuttons", title = "Action buttons", blurb = "Action buttons that show range, mana and usability",
      text = "See at a glance why a button isn't working: " .. C.red .. "red" .. C.r .. " = out of range, |cff5577ffblue|r = low mana, dark grey = can't be used right now. Short hotkeys and no macro names make for cleaner bars. " .. C.gold .. "/mlz buttons" .. C.r .. " toggles the colors." },
    { kind = "module", key = "tweaks", title = "Tweaks", blurb = "Small tweaks: quest tracker, FPS counter, combat text",
      text = "Smaller things that declutter the screen. Tip: " .. C.gold .. "/mlz map" .. C.r .. " gives a slider for the minimap size, " .. C.gold .. "/mlz tracker" .. C.r .. ' toggles the "All Objectives" line, and ' .. C.gold .. "/mlz quests" .. C.r .. " hides the whole quest tracker." },
    { kind = "module", key = "addons", title = "Other addons", blurb = "Settings for supported addons you already have",
      text = "Settings for supported addons that are installed and loaded; the rest are skipped. The values live in Data/Addons.lua. Some addons need a /reload to pick up the changes." },
    { kind = "module", key = "nameplates", title = "Nameplates", blurb = "Nameplates: Platynator profile and clean style",
      text = "Imports your saved Platynator profile (skipped until a profile string is saved in Data/Nameplates.lua) and/or turns on the clean MLZ style, which follows tank/DPS. " .. C.gold .. "/mlz np auto" .. C.r .. " switches tank/DPS by stance." },
    { kind = "summary", title = "Review" },
    { kind = "done", title = "Done!" },
}

-- Number of each module page, and how many there are
local NUM_STEPS = 0
for _, page in ipairs(PAGES) do
    if page.kind == "module" then
        NUM_STEPS = NUM_STEPS + 1
        page.number = NUM_STEPS
    end
end

local function Intro()
    local lines = { "This wizard sets up your UI step by step:", "" }
    for _, page in ipairs(PAGES) do
        if page.number then
            lines[#lines + 1] = ("  %s%d.%s %s"):format(C.gold, page.number, C.r, page.blurb or page.title)
        end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Each step shows what it is today and what it will be. Turn off whole steps or single rows; untick something that is already on to turn it off."
    lines[#lines + 1] = "Nothing changes until you press " .. C.gold .. "Apply changes" .. C.r .. " on the last page."
    lines[#lines + 1] = ""
    lines[#lines + 1] = C.green .. "A backup is always taken first." .. C.r .. " Type " .. C.gold .. "/mlz undo" .. C.r .. " to undo, and " .. C.gold .. "/mlz install" .. C.r .. " to open the wizard again."
    return table.concat(lines, "\n")
end

local WIDTH, HEIGHT = 760, 540
local CONTENT_W = WIDTH - 40
local COL = { check = 4, label = 32, old = 270, arrow = 450, new = 468 }
local ROW_H = 22
local GROUP_H = 30

------------------------------------------------------------------------
-- Window construction
------------------------------------------------------------------------
function Installer:Build()
    if self.frame then return end
    local f = CreateFrame("Frame", "MLZUI_Installer", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(WIDTH, HEIGHT)
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

    W.SetTitle(f, "MLZ UI - Setup")

    f.title = W.Text(f, "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 20, -36)

    f.step = W.Text(f, "GameFontDisableSmall", nil, "RIGHT")
    f.step:SetPoint("TOPRIGHT", -20, -40)

    f.desc = W.Text(f, "GameFontHighlight")
    f.desc:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -10)
    f.desc:SetWidth(CONTENT_W)

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
    f.header:SetSize(CONTENT_W, 16)
    f.header:SetPoint("TOPLEFT", f.stepCheck, "BOTTOMLEFT", 4, -6)
    local function H(text, x) local t = W.Text(f.header, "GameFontNormalSmall", text); t:SetPoint("LEFT", x, 0) end
    H("What", COL.label); H("Current", COL.old); H("New", COL.new)

    f.scroll = W.ScrollArea(f)
    f.scroll:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -2)
    f.scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 52)

    f.big = W.Text(f, "GameFontHighlight")
    f.big:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -16)
    f.big:SetWidth(CONTENT_W)
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

    self.rows = {}
end

------------------------------------------------------------------------
-- Row state
------------------------------------------------------------------------
local function FindItem(items, id)
    for _, it in ipairs(items or {}) do
        if it.id == id then return it end
    end
end

-- item.requires = id of another row in the same step. Returns that row if it is NOT going to be
-- applied (unticked or unavailable), so this row is skipped too.
function Installer:Blocker(modKey, item)
    if not item.requires then return nil end
    local parent = FindItem(self.items[modKey], item.requires)
    if not parent or parent.alreadySet or (parent.enabled and not parent.unavailable) then return nil end
    return parent
end

-- Will this row change something on Apply?
function Installer:WillChange(modKey, item)
    if item.unavailable or item.fixed or self:Blocker(modKey, item) then return false end
    if item.toggle then return (item.enabled and true or false) ~= (item.isOn and true or false) end
    return item.enabled and not item.alreadySet and true or false
end

------------------------------------------------------------------------
-- Rows
------------------------------------------------------------------------
local function Plain(text)
    return (tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function RowTooltip(r)
    local item = r.item
    if not item then return end
    local truncOld = r.old.IsTruncated and r.old:IsTruncated()
    local truncNew = r.newText.IsTruncated and r.newText:IsTruncated()
    if not (item.note or r.blocker or truncOld or truncNew) then return end
    GameTooltip:SetOwner(r, "ANCHOR_CURSOR")
    GameTooltip:SetText(Plain(item.label), 1, 1, 1)
    if r.blocker then
        GameTooltip:AddLine("Requires: " .. Plain(r.blocker.label), 1, 0.4, 0.4, true)
    end
    if item.note then GameTooltip:AddLine(item.note, nil, nil, nil, true) end
    if truncOld then GameTooltip:AddDoubleLine("Current", Plain(r.old:GetText()), 0.6, 0.6, 0.6, 1, 1, 1) end
    if truncNew then GameTooltip:AddDoubleLine("New", Plain(r.newText:GetText()), 0.6, 0.6, 0.6, 1, 1, 1) end
    GameTooltip:Show()
end

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
    r.old:SetWidth(COL.arrow - COL.old - 6)
    r.old:SetWordWrap(false)
    r.arrow = W.Text(r, "GameFontHighlightSmall", C.grey .. ">" .. C.r)
    r.arrow:SetPoint("LEFT", COL.arrow, 0)
    r.new = CreateFrame("Button", nil, r)
    r.new:SetPoint("LEFT", COL.new, 0)
    r.new:SetPoint("RIGHT", r, "RIGHT", -4, 0)
    r.new:SetHeight(ROW_H)
    r.newText = W.Text(r.new, "GameFontHighlightSmall")
    r.newText:SetAllPoints()
    r.newText:SetWordWrap(false)
    -- Group heading: a bit of air above, a thin line below
    r.groupText = W.Text(r, "GameFontNormal")
    r.groupText:SetPoint("BOTTOMLEFT", 4, 5)
    r.divider = r:CreateTexture(nil, "ARTWORK")
    r.divider:SetColorTexture(1, 1, 1, 0.08)
    r.divider:SetHeight(1)
    r.divider:SetPoint("BOTTOMLEFT", 4, 0)
    r.divider:SetPoint("BOTTOMRIGHT", -4, 0)

    -- Clicking anywhere on the row toggles its checkbox
    r:SetScript("OnClick", function(self)
        if self.check:IsShown() and self.check:IsEnabled() then self.check:Click() end
    end)
    r:SetScript("OnEnter", function(self)
        if not self.item then return end
        self.hl:Show()
        RowTooltip(self)
    end)
    r:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)
    r.new:SetScript("OnEnter", function(self) self:GetParent():GetScript("OnEnter")(self:GetParent()) end)
    r.new:SetScript("OnLeave", function(self) self:GetParent():GetScript("OnLeave")(self:GetParent()) end)
    return r
end

function Installer:AcquireRow(i, y, h)
    local r = self.rows[i]
    if not r then
        r = CreateRow(self.frame.scroll.content)
        self.rows[i] = r
    end
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 0, -y)
    r:SetPoint("RIGHT", self.frame.scroll.content, "RIGHT")
    r:SetHeight(h)
    r:Show()
    return r
end

local function SetGroupRow(r, text, divider)
    r.item, r.blocker = nil, nil
    r:EnableMouse(false)
    r.hl:Hide()
    r.check:Hide(); r.label:Hide(); r.old:Hide(); r.arrow:Hide(); r.new:Hide()
    r.groupText:SetText(text)
    r.groupText:Show()
    r.divider:SetShown(divider ~= false)
end

-- readOnly = summary (no checkboxes, no clicks)
function Installer:SetItemRow(r, item, modKey, stepOn, readOnly)
    r.item = item
    r:EnableMouse(true)
    r.groupText:Hide(); r.divider:Hide()
    r.label:Show(); r.old:Show(); r.new:Show()

    local blocker = not readOnly and self:Blocker(modKey, item) or nil
    r.blocker = blocker
    local live = stepOn and not item.unavailable and not blocker -- can be changed here
    local change = stepOn and self:WillChange(modKey, item)
    local turningOff = item.toggle and item.isOn and not item.enabled and not item.unavailable
    local already = not item.unavailable and ((item.toggle and item.isOn and item.enabled) or (not item.toggle and item.alreadySet))

    r.label:SetText(((change or (item.fixed and live)) and C.white or C.grey) .. item.label .. C.r)

    local old = item.old ~= nil and tostring(item.old) or ""
    r.old:SetText(((item.conflict and change) and C.red or C.grey) .. old .. C.r)
    r.arrow:SetShown(old ~= "")

    local new = item.new ~= nil and tostring(item.new) or ""
    if item.unavailable then
        new = C.grey .. new .. C.r
    elseif turningOff and stepOn and not blocker then
        new = C.amber .. (item.offText or "off") .. C.r
    elseif item.choices and not readOnly and live then
        new = C.blue .. "< " .. new .. " >" .. C.r .. (already and (C.grey .. "  (already)" .. C.r) or "")
    elseif already then
        new = C.grey .. new .. "  (already)" .. C.r
    elseif change or (item.fixed and live) then
        new = C.green .. new .. C.r
    else
        new = C.grey .. new .. C.r
    end
    r.newText:SetText(new)

    -- Choice values (< ... >) are clicked separately; other values let the click through to the row
    local canChoose = item.choices and not readOnly and live
    r.new:EnableMouse(canChoose and true or false)
    r.new:SetScript("OnClick", canChoose and function() self:CycleChoice(modKey, item) end or nil)

    -- No checkbox in the summary, on fixed rows, or on rows that are already right (unless they can be turned off)
    if readOnly or item.fixed or (already and not item.toggle) then
        r.check:Hide()
        return
    end
    r.check:Show()
    r.check:SetChecked(item.enabled and not item.unavailable)
    r.check:SetEnabled(live and true or false)
    r.check:SetScript("OnClick", function(btn)
        item.enabled = btn:GetChecked() and true or false
        ns.SetEnabled(modKey, item.id, item.enabled)
        self:RenderList()
        if r:IsMouseOver() then RowTooltip(r) end
    end)
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
    local n, y = 0, 0
    local function Group(text, divider)
        n = n + 1
        SetGroupRow(self:AcquireRow(n, y, GROUP_H), text, divider)
        y = y + GROUP_H
    end
    local function Item(item, modKey, stepOn, readOnly)
        n = n + 1
        self:SetItemRow(self:AcquireRow(n, y, ROW_H), item, modKey, stepOn, readOnly)
        y = y + ROW_H
    end

    if page.kind == "module" then
        local stepOn = self.stepOn[page.key]
        local lastGroup
        for _, item in ipairs(self.items[page.key] or {}) do
            if item.group and item.group ~= lastGroup then
                Group(item.group)
                lastGroup = item.group
            end
            Item(item, page.key, stepOn, false)
        end
    elseif page.kind == "summary" then
        local sels = self:Selections()
        if #sels == 0 then Group(C.grey .. "Nothing to change." .. C.r, false) end
        for _, sel in ipairs(sels) do
            Group(("%s  %s(%d %s)%s"):format(sel.mod.title, C.grey, sel.count, sel.count == 1 and "change" or "changes", C.r))
            for _, item in ipairs(sel.items) do
                -- Fixed rows (the movement choice) only when they differ from today
                if not item.fixed or tostring(item.old) ~= tostring(item.new) then
                    Item(item, sel.mod.key, true, true)
                end
            end
        end
    end
    f.scroll.content:SetHeight(math.max(1, y))
end

function Installer:Go(index)
    if index < 1 or index > #PAGES then return end
    self.page = index
    local f = self.frame
    local page = PAGES[index]

    f.title:SetText(page.number and (page.number .. ". " .. page.title) or page.title)
    f.step:SetText(page.number and ("Step %d of %d"):format(page.number, NUM_STEPS) or "")
    f.desc:SetText(page.text or "")

    local isList = page.kind == "module" or page.kind == "summary"
    f.scroll:SetShown(isList)
    f.header:SetShown(isList)
    f.desc:SetShown(isList)
    f.stepCheck:SetShown(page.kind == "module")
    f.big:SetShown(page.kind == "intro" or page.kind == "done")

    local nothing = false
    if page.kind == "module" then
        f.stepCheck:SetChecked(self.stepOn[page.key])
    elseif page.kind == "summary" then
        nothing = #self:Selections() == 0
        f.desc:SetText(nothing
            and ("Nothing will be changed. Go back to pick something, or press " .. C.gold .. "Finish" .. C.r .. ".")
            or ("This will be changed when you press " .. C.gold .. "Apply changes" .. C.r .. ". A backup is taken first."))
    elseif page.kind == "intro" then
        f.big:SetText(Intro())
    elseif page.kind == "done" then
        f.big:SetText(self.doneText or "")
    end

    local done = page.kind == "done"
    f.back:SetShown(not done)
    f.next:SetShown(not done)
    f.skip:SetShown(page.kind == "module")
    f.reload:SetShown(done and self.appliedAny)
    f.close:SetShown(done)
    f.close:ClearAllPoints()
    if self.appliedAny then
        f.close:SetPoint("RIGHT", f.reload, "LEFT", -8, 0)
    else
        f.close:SetPoint("BOTTOMRIGHT", -16, 14)
    end
    f.back:SetEnabled(index > 1)
    if page.kind == "summary" then
        f.next:SetText(nothing and "Finish" or "Apply changes")
    else
        f.next:SetText("Next")
    end

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
-- Per step: the rows that change something, plus fixed rows (such as the movement choice)
-- that the module needs to see. Steps where nothing changes are left out.
function Installer:Selections()
    local sels = {}
    for _, key in ipairs(APPLY_ORDER) do
        local mod = ns.modules[key]
        if mod and self.stepOn[key] and self.items[key] then
            local chosen, count = {}, 0
            for _, item in ipairs(self.items[key]) do
                if self:WillChange(key, item) then
                    chosen[#chosen + 1] = item
                    count = count + 1
                elseif item.fixed and not item.unavailable then
                    chosen[#chosen + 1] = item
                end
            end
            if count > 0 then sels[#sels + 1] = { mod = mod, items = chosen, count = count } end
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
        self.frame:Hide()
        ns.Print("Nothing was changed. " .. C.gold .. "/mlz install" .. C.r .. " opens the wizard again.")
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
    self.appliedAny = true

    self.doneText = table.concat(lines, "\n") .. "\n\n" ..
        (failed > 0 and (C.red .. "Something failed. Type /mlz undo to undo, and pass on the error message." .. C.r .. "\n\n") or "") ..
        "Press " .. C.gold .. "Reload now" .. C.r .. " to reload the UI (needed for layout, scaling and some addons).\n\n" ..
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
    self.items, self.stepOn, self.appliedAny = {}, {}, false
    for _, page in ipairs(PAGES) do
        if page.key then
            local mod = ns.modules[page.key]
            if mod.BeginWizard then pcall(mod.BeginWizard, mod) end
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
