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
--   keepVisible  stays in the list even when it is already right (a question the player should see)
--   attention    an unavailable row that still matters (a key that will be lost): shown in the list in amber
--   behaviour    changes how the game plays, not how it looks: label in amber
--   groupNote    (on the first row of a group) one muted line under the group heading
-- A module's Apply may return a short text when part of it failed; the last page then says "PARTLY".
-- A module may set `dependents = { "settings" }`: those steps are previewed again after a choice changes.

local _, ns = ...
local W = ns.W
local C = W.C

local Installer = {}
ns.Installer = Installer

-- Same order as the backup module uses (undo runs it in reverse)
local APPLY_ORDER = ns.Backup.APPLY_ORDER

-- Module pages are numbered automatically ("3. Game settings", "Step 3 of 8"). Titles match the control center.
-- A page can hold several modules (keys): their rows are drawn one after the other, and "Use this step"
-- turns all of them on or off. Modules, their saved choices and backups don't know about pages.
-- groups = heading for a module whose rows have no group of their own.
local PAGES = {
    { kind = "intro", title = "Welcome to MLZ UI" },
    { kind = "module", key = "role", title = "Your character" },
    { kind = "module", keys = { "scale", "layout" }, title = "Scale & layout", groups = { scale = "Scale" },
      text = "A crisp UI scale for your screen, and an Edit Mode layout of its own: bars at bottom center, player and target on the sides, chat at bottom left, minimap and buffs at top right. Fine-tune it in Edit Mode afterwards." },
    { kind = "module", key = "settings", title = "Game settings",
      text = "Good default settings. Rows marked (already) have the right value. Hover over a row for an explanation." },
    { kind = "module", key = "bindings", title = "Keybinds",
      text = "The same 12 keys on 3 layers: no modifier = Bar 1, " .. C.white .. "SHIFT" .. C.r .. " = Bar 2, " .. C.white .. "CTRL" .. C.r .. " = Bar 3. " .. C.red .. "Red" .. C.r .. " = the key does something else today. Panels you lose a key for move to " .. C.white .. "ALT" .. C.r .. "." },
    { kind = "module", key = "fade", title = "Minimalism",
      text = "Things you rarely use stay invisible until you hover over them, and things you only need in combat are dimmed otherwise. Rows that are already on are folded away at the bottom: show them to turn one off." },
    { kind = "module", keys = { "actionbuttons", "tweaks" }, title = "Bars & interface",
      text = "See at a glance why a button isn't working: " .. C.red .. "red" .. C.r .. " = out of range, " .. C.blue .. "blue" .. C.r .. " = low mana, dark grey = can't be used right now. Plus smaller things that declutter the quest tracker, tooltips, chat and minimap." },
    { kind = "module", key = "addons", title = "Other addons",
      text = "Settings for supported addons that are installed and loaded; the rest are skipped. Some addons only pick up the changes after a reload; the last page tells you if that is the case." },
    { kind = "module", key = "nameplates", title = "Nameplates",
      text = "Flat, calm nameplates that follow your role: tank, healer, DPS or solo. If Platynator is loaded, MLZ UI drives it instead. What the plates show and how big they are is on the Nameplates page." },
    { kind = "summary", title = "Review" },
    { kind = "done", title = "All set" },
}

-- Number of each module page, how many there are, and which page each module is on
local NUM_STEPS = 0
local PAGE_OF = {}
for i, page in ipairs(PAGES) do
    if page.kind == "module" then
        page.keys = page.keys or { page.key }
        page.key = page.key or page.keys[1] -- the page's name for PAGE_TEXT and showAlready
        NUM_STEPS = NUM_STEPS + 1
        page.number = NUM_STEPS
        for _, key in ipairs(page.keys) do PAGE_OF[key] = i end
    end
end

-- Shown once, under the list, on every step
local LEGEND = C.blue .. "Blue" .. C.r .. " = click to change     " .. C.green .. "Green" .. C.r .. " = will change     " .. C.red .. "Red" .. C.r
    .. " = replaces what you use today     " .. C.amber .. "Amber" .. C.r .. " = changes how the game plays"

-- Text under the title of some steps depends on your class and role
local PAGE_TEXT = {
    role = function()
        local class = UnitClass("player") or "your class"
        local arch, source = ns.Archetype(true)
        return ("MLZ UI adapts to how you play. For your %s it sees %s%s%s (%s). Tank, healer and DPS get different nameplates, role layouts and a few game settings. Change the role below if that is wrong."):format(
            class, C.white, ns.ArchetypeText(arch), C.r, ns.SOURCE_TEXT[source] or tostring(source))
    end,
    scale = function(base)
        -- a role picked in step 1 is not saved yet, so name it instead of the layout for today's role
        local role = ns.modules.role
        local picked = role and role.pending
        if picked and Installer.stepOn and Installer.stepOn.role and picked ~= "auto" and picked ~= ns.GetRoleForce() then
            return base .. "\n" .. C.grey .. "Role layouts switch by themselves. They follow the role you picked in step 1 ("
                .. (ns.ROLE_TEXT[picked] or picked) .. ")." .. C.r
        end
        local want = ns.Healer and ns.Healer.Wanted and ns.Healer.Wanted()
        if not want then return base end
        return base .. "\n" .. C.grey .. "Role layouts switch by themselves. With your current role: " .. want .. "." .. C.r
    end,
    bindings = function(base)
        local c = ns.data.classes and ns.data.classes[ns.PlayerClass() or ""] or {}
        local parts = {}
        local b = ns.modules.bindings
        local extra = (b and b.ExtraKeyCount and b.ExtraKeyCount()) or 0
        if extra > 0 then
            parts[#parts + 1] = extra .. " extra key" .. (extra == 1 and "" or "s") .. " on bar 5 for your stances or forms"
        end
        if c.pet then parts[#parts + 1] = "the pet bar" end
        if #parts == 0 then return base end
        return base .. "\n" .. C.grey .. (UnitClass("player") or "Your class") .. ": "
            .. table.concat(parts, " and ") .. " get their own keys too." .. C.r
    end,
}

local function PageText(page)
    local fn = PAGE_TEXT[page.key]
    if fn then return fn(page.text) end
    return page.text
end

-- Amber line on the first page when this is not the main supported game version. Never blocks anything.
local function ClientNote()
    local info = ns.ClientInfo and ns.ClientInfo()
    if not info or info.main or not info.toc then return "" end
    return "\n\n" .. C.amber .. ("This is game version %d. MLZ UI is built for %s, so some things may look or work differently here."):format(
        info.toc, info.name) .. C.r
end

local function Intro()
    local names = {}
    for _, page in ipairs(PAGES) do
        if page.number then names[#names + 1] = page.title end
    end
    return "MLZ UI sets up your interface in " .. NUM_STEPS .. " short steps. Each one shows what you have now and what it will become.\n\n"
        .. C.grey .. table.concat(names, "  ·  ") .. C.r .. "\n\n"
        .. "Nothing changes until you press " .. C.white .. "Apply changes" .. C.r .. ", and a backup is taken first. "
        .. C.white .. "/mlz undo" .. C.r .. " puts everything back. You can change each choice later in the settings window ("
        .. C.white .. "/mlz" .. C.r .. ").\n\n"
        .. "Not sure? " .. C.white .. "Use recommended" .. C.r .. " takes every suggestion and jumps to the review. "
        .. C.white .. "Looks only" .. C.r .. " skips everything that changes how the game plays."
        .. ClientNote()
end

local WIDTH, HEIGHT = 760, 620
local PAD = 14
local FOOTER_H = 44 -- same footer as the control center
local CONTENT_W = WIDTH - 2 * PAD
-- Row columns inside the list (about 706 wide): label about 230, then "now" and "will become" share the rest
local COL = { check = 4, label = 32, old = 270, arrow = 480, new = 498 }
local ROW_H = 22
local GROUP_H = 30

------------------------------------------------------------------------
-- Window construction
------------------------------------------------------------------------
function Installer:Build()
    if self.frame then return end
    local f = W.Window("MLZUI_Installer", WIDTH, HEIGHT, "MLZ UI: Setup wizard")
    self.frame = f

    -- Progress strip: one segment per numbered step, so it matches "STEP n OF 8". Click to jump.
    f.progress = {}
    local steps = {}
    for i, page in ipairs(PAGES) do
        if page.number then steps[#steps + 1] = i end
    end
    local segs, gap = #steps, 4
    local segW = (CONTENT_W - gap * (segs - 1)) / segs
    for n = 1, segs do
        local i = steps[n]
        local page = PAGES[i]
        local b = CreateFrame("Button", nil, f)
        b.pageIndex = i
        b:SetSize(segW, 14)
        b:SetPoint("TOPLEFT", PAD + (n - 1) * (segW + gap), -46)
        b.bar = b:CreateTexture(nil, "ARTWORK")
        b.bar:SetPoint("LEFT")
        b.bar:SetPoint("RIGHT")
        b.bar:SetHeight(4)
        b:SetScript("OnClick", function()
            -- opened for one step: the other steps are off, so jumping to them makes no sense
            if self.page ~= #PAGES and not self.singleStep then self:Go(b.pageIndex) end
        end)
        W.Tooltip(b, page.number .. ". " .. page.title, function()
            return not self.singleStep and "Click to go to this step." or nil
        end)
        f.progress[n] = b
    end

    f.title = W.Text(f, "MLZUI_FontTitle")
    f.title:SetPoint("TOPLEFT", PAD, -72)

    f.step = W.Text(f, "MLZUI_FontSmallBold", nil, "RIGHT")
    f.step:SetTextColor(unpack(W.T.muted))
    f.step:SetPoint("TOPRIGHT", -PAD, -78)

    f.desc = W.Text(f, "GameFontHighlight")
    f.desc:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -10)
    f.desc:SetWidth(CONTENT_W)

    f.stepCheck = W.Toggle(f, function(_, on)
        local page = PAGES[self.page]
        if not page.keys then return end
        for _, key in ipairs(page.keys) do
            if ns.modules[key] then
                self.stepOn[key] = on
                self:RefreshDependents(key)
            end
        end
        self:UpdateSelButtons()
        self:RenderList()
    end, "Use this step")
    f.stepCheck:SetPoint("TOPLEFT", f.desc, "BOTTOMLEFT", 0, -10)

    f.selNone = W.Button(f, "Untick all", 90, 22, function() self:SetAll(false) end, "subtle")
    f.selNone:SetPoint("TOPRIGHT", f.desc, "BOTTOMRIGHT", 0, -9)
    f.selAll = W.Button(f, "Tick all", 90, 22, function() self:SetAll(true) end, "subtle")
    f.selAll:SetPoint("RIGHT", f.selNone, "LEFT", -6, 0)

    -- The list sits on a darker panel, with column headers at the top
    f.panel = CreateFrame("Frame", nil, f)
    f.panel:SetPoint("TOPLEFT", f.stepCheck, "BOTTOMLEFT", 0, -10)
    -- the legend line sits between the panel and the footer
    f.panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, FOOTER_H + 1 + PAD + 18)

    f.legend = W.Muted(f, "GameFontHighlightSmall", LEGEND)
    f.legend:SetPoint("TOPLEFT", f.panel, "BOTTOMLEFT", 0, -6)
    W.Fill(f.panel, W.T.panel)
    W.Border(f.panel, W.T.border)

    f.header = CreateFrame("Frame", nil, f.panel)
    f.header:SetHeight(22)
    f.header:SetPoint("TOPLEFT", 8, -4)
    f.header:SetPoint("TOPRIGHT", -8, -4)
    local hline = f.header:CreateTexture(nil, "BORDER")
    hline:SetColorTexture(unpack(W.T.border))
    hline:SetHeight(1)
    hline:SetPoint("BOTTOMLEFT")
    hline:SetPoint("BOTTOMRIGHT")
    local function H(text, x)
        local t = W.Text(f.header, "MLZUI_FontSmallBold", text)
        t:SetTextColor(unpack(W.T.muted))
        t:SetPoint("LEFT", x, 0)
    end
    H("SETTING", COL.label); H("NOW", COL.old); H("WILL BECOME", COL.new)

    f.scroll = W.ScrollArea(f.panel)
    f.scroll:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -2)
    f.scroll:SetPoint("BOTTOMRIGHT", f.panel, "BOTTOMRIGHT", -18, 6)

    -- Welcome and All set: one long text that scrolls, so a long result never runs under the buttons
    f.bigScroll = W.ScrollArea(f)
    f.bigScroll:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -16)
    f.bigScroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(PAD + 11), FOOTER_H + 1 + PAD + W.BUTTON_H_LARGE + PAD)
    f.big = W.Text(f.bigScroll.content, "GameFontHighlight")
    f.big:SetPoint("TOPLEFT")
    f.big:SetWidth(CONTENT_W - 11)
    f.big:SetSpacing(4)
    function f:SetBig(text)
        self.big:SetText(text)
        self.bigScroll.content:SetHeight(math.max(1, self.big:GetStringHeight()))
        self.bigScroll:SetVerticalScroll(0)
        if self.bigScroll.UpdateScroll then self.bigScroll.UpdateScroll() end
    end

    -- Footer: the same 44px strip as the control center, buttons PAD from the edges
    local foot = CreateFrame("Frame", nil, f)
    foot:SetPoint("BOTTOMLEFT", 1, 1)
    foot:SetPoint("BOTTOMRIGHT", -1, 1)
    foot:SetHeight(FOOTER_H)
    foot:SetFrameLevel(f:GetFrameLevel()) -- under the buttons, which are children of the window
    W.Fill(foot, W.T.panel)
    local footLine = foot:CreateTexture(nil, "BORDER")
    footLine:SetColorTexture(unpack(W.T.border))
    footLine:SetHeight(1)
    footLine:SetPoint("TOPLEFT")
    footLine:SetPoint("TOPRIGHT")
    local FOOT_Y = 1 + (FOOTER_H - W.BUTTON_H_LARGE) / 2
    -- the row above the footer on the last page (tour, keybinds, undo)
    local ROW_Y = FOOTER_H + 1 + PAD

    -- Navigation
    f.back = W.Button(f, "Back", 110, 28, function() self:Go(self.page - 1) end)
    f.back:SetPoint("BOTTOMLEFT", PAD, FOOT_Y)
    f.next = W.Button(f, "Next", 150, 28, function() self:Next() end, "primary")
    f.next:SetPoint("BOTTOMRIGHT", -PAD, FOOT_Y)
    -- No "Skip" button: "Use this step" off plus Next does the same, and says what it does.
    -- Welcome page: take the suggestions as they are and go straight to the review
    f.quick = W.Button(f, "Use recommended", 150, 28, function() self:ApplyPreset("recommended") end)
    f.quick:SetPoint("RIGHT", f.next, "LEFT", -8, 0)
    f.quick.tipText = "Takes every suggestion as it is and shows the review. Nothing changes until you press Apply changes there."
    f.looks = W.Button(f, "Looks only", 120, 28, function() self:ApplyPreset("looks") end, "subtle")
    f.looks:SetPoint("RIGHT", f.quick, "LEFT", -8, 0)
    f.looks.tipText = "Your character, scale, layout, minimalism, bars and nameplates. Game settings, keybinds and other addons are left alone. Nothing changes until you press Apply changes."

    f.reload = W.Button(f, "Reload now", 150, 28, function() ReloadUI() end, "primary")
    f.reload:SetPoint("BOTTOMRIGHT", -PAD, FOOT_Y)
    f.close = W.Button(f, "Close", 110, 28, function() f:Hide() end)
    f.footY = FOOT_Y
    f.rowY = ROW_Y
    f.settings = W.Button(f, "Open settings", 130, 28, function()
        f:Hide()
        if ns.Settings then ns.Settings:Open() end
    end)
    f.settings:SetPoint("BOTTOMLEFT", PAD, FOOT_Y)
    -- After a run: point at the frames that are now hidden, so nobody wonders where they went
    f.tour = W.Button(f, "Show me around", 140, 28, function()
        f:Hide()
        if ns.Tour then ns.Tour.Start() end
    end)
    f.tour:SetPoint("BOTTOMLEFT", PAD, ROW_Y)
    f.tour.tipText = "A short tour of the bars and buttons that now stay hidden until you need them."
    f.keys = W.Button(f, "My keybinds", 140, 28, function()
        f:Hide()
        if ns.Keys then ns.Keys.Open() end
    end)
    f.keys:SetPoint("LEFT", f.tour, "RIGHT", 8, 0)
    f.keys.tipText = "A picture of your keyboard with what each key does now."
    -- Undo sits on the last page, so nobody has to remember /mlz undo. Two clicks, like in the control center.
    local UNDO_LABEL = "Undo these changes"
    f.undo = W.Button(f, UNDO_LABEL, 170, 28, function(b)
        if not b.armed then
            local token = {}
            b.armed = token
            b:SetText("Click again to undo")
            C_Timer.After(4, function()
                if b.armed == token then
                    b.armed = nil
                    b:SetText(UNDO_LABEL)
                end
            end)
            return
        end
        b.armed = nil
        b:SetText(UNDO_LABEL)
        self:UndoLast()
    end, "danger")
    -- on its own, at the right: a destructive button never sits next to the harmless ones
    f.undo:SetPoint("BOTTOMRIGHT", -PAD, ROW_Y)
    f.undo.tipText = "Puts everything back the way it was before this run. Click twice to confirm."

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

-- Does the row this one depends on actually change? (A key is only lost when its move is applied.)
function Installer:ParentChanges(modKey, item)
    if not item.requires then return true end
    local parent = FindItem(self.items[modKey], item.requires)
    return parent ~= nil and self:WillChange(modKey, parent)
end

-- Will this row change something on Apply?
function Installer:WillChange(modKey, item)
    if item.unavailable or item.fixed or self:Blocker(modKey, item) then return false end
    if item.toggle then return (item.enabled and true or false) ~= (item.isOn and true or false) end
    return item.enabled and not item.alreadySet and true or false
end

-- Folded away under "N settings are already right": a value that already matches, or a feature that is
-- already on and stays on. Unticking an on-row (expanded view) makes it a change, so it shows again.
local function IsAlreadyRight(item)
    if item.fixed or item.touched or item.keepVisible or item.unavailable then return false end
    if item.toggle then return (item.isOn and item.enabled) and true or false end
    return item.alreadySet and true or false
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
    if not (item.note or r.blocker or truncOld or truncNew) then
        -- nothing to say about this row: don't leave the previous row's tooltip up
        if GameTooltip:IsOwned(r) then GameTooltip:Hide() end
        return
    end
    GameTooltip:SetOwner(r, "ANCHOR_CURSOR")
    local text, muted, warn = W.T.text, W.T.muted, W.T.amber
    GameTooltip:SetText(Plain(item.label), text[1], text[2], text[3])
    if r.blocker then
        GameTooltip:AddLine("Needs: " .. Plain(r.blocker.label), warn[1], warn[2], warn[3], true)
    end
    if item.note then GameTooltip:AddLine(item.note, nil, nil, nil, true) end
    if truncOld then
        GameTooltip:AddDoubleLine("Now", Plain(r.old:GetText()), muted[1], muted[2], muted[3], text[1], text[2], text[3])
    end
    if truncNew then
        GameTooltip:AddDoubleLine("Will become", Plain(r.newText:GetText()), muted[1], muted[2], muted[3], text[1], text[2], text[3])
    end
    GameTooltip:Show()
end

local function CreateRow(parent)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(ROW_H)
    -- Zebra stripe on every other item row, hover highlight on top of it
    r.zebra = r:CreateTexture(nil, "BACKGROUND", nil, 0)
    r.zebra:SetAllPoints()
    r.zebra:SetColorTexture(unpack(W.T.shade))
    r.zebra:Hide()
    r.hl = r:CreateTexture(nil, "BACKGROUND", nil, 1)
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(W.T.accent[1], W.T.accent[2], W.T.accent[3], 0.10)
    r.hl:Hide()
    r.check = W.Check(r)
    r.check:SetSize(16, 16)
    r.check:SetPoint("LEFT", COL.check + 2, 0)
    r.label = W.Text(r, "GameFontHighlightSmall")
    r.label:SetPoint("LEFT", COL.label, 0)
    r.label:SetWidth(COL.old - COL.label - 8)
    r.label:SetWordWrap(false)
    r.old = W.Text(r, "GameFontHighlightSmall")
    r.old:SetPoint("LEFT", COL.old, 0)
    r.old:SetWidth(COL.arrow - COL.old - 6)
    r.old:SetWordWrap(false)
    r.arrow = W.Text(r, "MLZUI_FontSmallBold", ">")
    r.arrow:SetPoint("LEFT", COL.arrow, 0)
    r.new = CreateFrame("Button", nil, r)
    r.new:SetPoint("LEFT", COL.new, 0)
    r.new:SetPoint("RIGHT", r, "RIGHT", -4, 0)
    r.new:SetHeight(ROW_H)
    r.newText = W.Text(r.new, "GameFontHighlightSmall")
    r.newText:SetAllPoints()
    r.newText:SetWordWrap(false)
    r.new:RegisterForClicks("LeftButtonUp", "RightButtonUp") -- right-click steps a choice backwards
    -- Group heading: a bit of air above, a thin line below
    r.groupText = W.Text(r, "MLZUI_FontHead")
    r.groupText:SetTextColor(unpack(W.T.accent))
    r.groupText:SetPoint("BOTTOMLEFT", COL.check + 2, 5) -- same left edge as the checkboxes
    r.divider = r:CreateTexture(nil, "ARTWORK")
    r.divider:SetColorTexture(unpack(W.T.border))
    r.divider:SetHeight(1)
    r.divider:SetPoint("BOTTOMLEFT", COL.check + 2, 0)
    r.divider:SetPoint("BOTTOMRIGHT", -4, 0)

    -- Clicking anywhere on the row toggles its checkbox
    r:SetScript("OnClick", function(self)
        if self.footerClick then self.footerClick() return end
        if self.check:IsShown() and self.check:IsEnabled() then self.check:Click() end
    end)
    r:SetScript("OnEnter", function(self)
        if self.footerTip then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            self.footerTip(GameTooltip)
            GameTooltip:Show()
            return
        end
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
    r.item, r.blocker, r.footerClick, r.footerTip = nil, nil, nil, nil
    r:EnableMouse(false)
    r.hl:Hide(); r.zebra:Hide()
    r.check:Hide(); r.label:Hide(); r.old:Hide(); r.arrow:Hide(); r.new:Hide()
    r.groupText:SetFontObject("MLZUI_FontHead")
    r.groupText:SetTextColor(unpack(W.T.accent))
    r.groupText:SetText(text)
    r.groupText:Show()
    r.divider:SetShown(divider ~= false)
end

-- A muted line at the bottom of a step ("3 options not available"), optionally clickable / with a tooltip
local function SetFooterRow(r, text, onClick, onTip)
    SetGroupRow(r, text .. (onClick and "  >" or ""), false)
    r.groupText:SetFontObject("GameFontHighlightSmall")
    r.groupText:SetTextColor(unpack(onClick and W.T.accent or W.T.muted))
    r.footerClick, r.footerTip = onClick, onTip
    r:EnableMouse((onClick or onTip) and true or false)
end

-- readOnly = summary (no checkboxes, no clicks)
function Installer:SetItemRow(r, item, modKey, stepOn, readOnly)
    r.item = item
    r.footerClick, r.footerTip = nil, nil
    r:EnableMouse(true)
    r.groupText:Hide(); r.divider:Hide()
    r.label:Show(); r.old:Show(); r.new:Show()

    local blocker = not readOnly and self:Blocker(modKey, item) or nil
    r.blocker = blocker
    local live = stepOn and not item.unavailable and not blocker -- can be changed here
    local change = stepOn and self:WillChange(modKey, item)
    local turningOff = item.toggle and item.isOn and not item.enabled and not item.unavailable
    local already = not item.unavailable and ((item.toggle and item.isOn and item.enabled) or (not item.toggle and item.alreadySet))

    local labelColor = (change or (item.fixed and live)) and C.white or C.grey
    if item.behaviour and change then labelColor = C.amber end
    if item.attention and not blocker then labelColor = C.amber end
    r.label:SetText(labelColor .. item.label .. C.r)

    local old = item.old ~= nil and tostring(item.old) or ""
    r.old:SetText(((item.conflict and change) and C.red or C.grey) .. old .. C.r)
    r.arrow:SetShown(old ~= "")
    if change then
        r.arrow:SetTextColor(unpack(W.T.green))
    else
        r.arrow:SetTextColor(unpack(W.T.muted))
    end

    local new = item.new ~= nil and tostring(item.new) or ""
    if item.unavailable then
        new = (item.attention and C.amber or C.grey) .. new .. C.r
    elseif turningOff and stepOn and not blocker then
        new = C.amber .. (item.offText or "off") .. C.r
    elseif item.choices and not readOnly and live then
        new = C.blue .. "< " .. new .. " >" .. C.r .. (already and (C.grey .. "  (already)" .. C.r) or "")
    elseif blocker then
        new = C.grey .. "needs: " .. Plain(blocker.label) .. C.r
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
    r.new:SetScript("OnClick", canChoose and function(_, button)
        self:CycleChoice(modKey, item, button == "RightButton" and -1 or 1)
    end or nil)

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
        self:RefreshDependents(modKey)
        self:RenderList()
        if r:IsMouseOver() then RowTooltip(r) end
    end)
end

-- "Tick all" / "Untick all" for the current step. Rows that are on today stay on when unticking all
-- (unticking those would turn the feature off).
function Installer:SetAll(on)
    local page = PAGES[self.page]
    for _, key in ipairs(page.keys or {}) do
        if self.stepOn[key] then
            for _, item in ipairs(self.items[key] or {}) do
                local eligible = not item.unavailable and not item.fixed and (item.toggle or not item.alreadySet)
                if eligible then
                    item.enabled = on or (item.toggle and item.isOn) or false
                    ns.SetEnabled(key, item.id, item.enabled)
                end
            end
            self:RefreshDependents(key)
        end
    end
    self:RenderList()
end

-- Is any module on this page on? (Opened for one step, only that module is.)
function Installer:PageOn(page)
    for _, key in ipairs(page.keys or {}) do
        if self.stepOn[key] then return true end
    end
    return false
end

-- Tick all / Untick all only make sense while the step is on
function Installer:UpdateSelButtons()
    local on = self:PageOn(PAGES[self.page])
    self.frame.selAll:SetEnabled(on)
    self.frame.selNone:SetEnabled(on)
end

-- dir = 1 for the next value (left-click), -1 for the previous one (right-click)
function Installer:CycleChoice(modKey, item, dir)
    local n = #item.choices
    item.choiceIndex = ((item.choiceIndex or 1) - 1 + (dir or 1)) % n + 1
    local choice = item.choices[item.choiceIndex]
    item.value, item.new = choice.value, choice.text
    item.touched = true -- stays in the list even when the new value is what you have today
    if not item.enabled then
        item.enabled = true
        ns.SetEnabled(modKey, item.id, true)
    end
    local mod = ns.modules[modKey]
    if mod.OnChoice and mod:OnChoice(item) then
        -- pcall and keep the other picks in this step
        self:Repreview(modKey)
    end
    self:RefreshDependents(modKey)
    self:RenderList()
end

-- Previews one step again, keeping the values the player already picked in it
function Installer:Repreview(key)
    local mod = ns.modules[key]
    if not (mod and mod.Preview) then return end
    local ok, items = pcall(mod.Preview, mod)
    if not ok then return end
    local old = {}
    for _, it in ipairs(self.items[key] or {}) do old[it.id] = it end
    for _, it in ipairs(items) do
        local o = old[it.id]
        if o and o.touched and it.choices then
            it.touched, it.value, it.new, it.choiceIndex = true, o.value, o.new, o.choiceIndex
            if mod.OnChoice then mod:OnChoice(it) end
        end
    end
    self.items[key] = items
end

-- Steps that plan around this one (the role step feeds the game settings) are previewed again
function Installer:RefreshDependents(modKey)
    local mod = ns.modules[modKey]
    for _, key in ipairs(mod and mod.dependents or {}) do self:Repreview(key) end
end

------------------------------------------------------------------------
-- Page rendering
------------------------------------------------------------------------
function Installer:RenderList()
    local f = self.frame
    local page = PAGES[self.page]
    for _, r in ipairs(self.rows) do r:Hide() end
    local n, y, stripe = 0, 0, 0
    local function Group(text, divider)
        n = n + 1
        SetGroupRow(self:AcquireRow(n, y, GROUP_H), text, divider)
        y = y + GROUP_H
        stripe = 0
    end
    local function Item(item, modKey, stepOn, readOnly)
        n = n + 1
        stripe = stripe + 1
        local r = self:AcquireRow(n, y, ROW_H)
        self:SetItemRow(r, item, modKey, stepOn, readOnly)
        r.zebra:SetShown(stripe % 2 == 0)
        y = y + ROW_H
    end

    if page.kind == "module" then
        -- rows from every module on the page; each row remembers its module (requires, toggles and choices are per module)
        -- Expanded, the rows that are already right stay in their own place, so a group heading never repeats.
        local expanded = self.showAlready[page.key]
        local shown, unavailable, already = {}, {}, {}
        for _, key in ipairs(page.keys) do
            for _, item in ipairs(self.items[key] or {}) do
                local entry = { item = item, key = key, group = item.group or (page.groups and page.groups[key]) }
                if item.unavailable and not item.attention then
                    unavailable[#unavailable + 1] = item
                elseif IsAlreadyRight(item) then
                    already[#already + 1] = entry
                    if expanded then shown[#shown + 1] = entry end
                else
                    shown[#shown + 1] = entry
                end
            end
        end
        local lastGroup
        for _, entry in ipairs(shown) do
            local item = entry.item
            if entry.group and entry.group ~= lastGroup then
                Group(entry.group)
                lastGroup = entry.group
                if item.groupNote then
                    -- why these settings are here, in one muted line
                    n = n + 1
                    SetFooterRow(self:AcquireRow(n, y, ROW_H), item.groupNote)
                    y = y + ROW_H
                    stripe = 0
                end
            end
            Item(item, entry.key, self.stepOn[entry.key], false)
        end
        if #shown == 0 and #unavailable == 0 and #already == 0 then
            n = n + 1
            SetFooterRow(self:AcquireRow(n, y, GROUP_H), "Nothing to set here.")
            y = y + GROUP_H
        end
        if #already > 0 then
            n = n + 1
            local text = expanded and "Hide the settings that are already right"
                or (("%d setting%s already right (click to show)"):format(#already, #already == 1 and " is" or "s are"))
            SetFooterRow(self:AcquireRow(n, y, ROW_H), text, function()
                self.showAlready[page.key] = not self.showAlready[page.key]
                self:RenderList()
            end)
            y = y + ROW_H
        end
        if #unavailable > 0 then
            n = n + 1
            SetFooterRow(self:AcquireRow(n, y, ROW_H),
                ("%d option%s not available on your setup (hover to see which)"):format(#unavailable, #unavailable == 1 and " is" or "s are"),
                nil,
                function(tip)
                    tip:SetText("Not available", unpack(W.T.white, 1, 3))
                    for i, item in ipairs(unavailable) do
                        if i > 14 then tip:AddLine("...and " .. (#unavailable - 14) .. " more", unpack(W.T.muted, 1, 3)) break end
                        local tx, mu = W.T.text, W.T.muted
                        tip:AddDoubleLine(Plain(item.label), Plain(item.new or ""), tx[1], tx[2], tx[3], mu[1], mu[2], mu[3])
                        if item.note then tip:AddLine(item.note, mu[1], mu[2], mu[3], true) end
                    end
                end)
            y = y + ROW_H
        end
    elseif page.kind == "summary" then
        -- applied in APPLY_ORDER, but listed in the order the player went through the steps
        local sels = self:Selections()
        table.sort(sels, function(a, b)
            local pa, pb = PAGE_OF[a.mod.key] or 99, PAGE_OF[b.mod.key] or 99
            if pa ~= pb then return pa < pb end
            return a.order < b.order
        end)
        if #sels == 0 then Group(C.grey .. "Nothing to change." .. C.r, false) end
        for _, sel in ipairs(sels) do
            Group(("%s  %s(%d %s)%s"):format(self:StepTitle(sel.mod.key, true) or sel.mod.title, C.grey, sel.count,
                sel.count == 1 and "change" or "changes", C.r))
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
    f.step:SetText(page.number and ("STEP %d OF %d"):format(page.number, NUM_STEPS)
        or (page.kind == "summary" and "REVIEW") or "")
    f.desc:SetText(PageText(page) or "")

    -- Progress strip: green = behind you, blue = here, amber = skipped, grey = ahead (all green on Review and Done)
    for _, seg in ipairs(f.progress) do
        local i, c = seg.pageIndex
        if i == index then c = W.T.accent
        elseif not self.singleStep and not self:PageOn(PAGES[i]) and i < index then c = W.T.amber
        elseif i < index then c = W.T.green
        else c = W.T.off end
        seg.bar:SetColorTexture(unpack(c))
    end

    local isList = page.kind == "module" or page.kind == "summary"
    f.panel:SetShown(isList)
    f.desc:SetShown(isList)
    f.legend:SetShown(page.kind == "module")
    f.stepCheck:SetShown(page.kind == "module")
    f.selAll:SetShown(page.kind == "module")
    f.selNone:SetShown(page.kind == "module")
    f.bigScroll:SetShown(page.kind == "intro" or page.kind == "done")

    local nothing = false
    if page.kind == "module" then
        f.stepCheck:SetChecked(self:PageOn(page))
        self:UpdateSelButtons()
    elseif page.kind == "summary" then
        local t = self:Totals()
        nothing = t.changes == 0
        local text = nothing
            and ("Nothing will be changed. Go back to pick something, or press " .. C.white .. "Finish" .. C.r .. ".")
            or ("%d change%s in %d step%s%s. They are made when you press %sApply changes%s. A backup is taken first."):format(
                t.changes, t.changes == 1 and "" or "s", t.steps, t.steps == 1 and "" or "s",
                t.already > 0 and (", " .. t.already .. " already right") or "", C.white, C.r)
        if t.skipped > 0 then
            text = text .. "\n" .. C.grey .. t.skipped .. " step" .. (t.skipped == 1 and " is" or "s are")
                .. " turned off and left as they are." .. C.r
        end
        if t.attention > 0 then
            text = text .. "\n" .. C.amber .. t.attention .. " key" .. (t.attention == 1 and "" or "s")
                .. " will lose their action. See the amber rows." .. C.r
        end
        f.desc:SetText(text)
    elseif page.kind == "intro" then
        f:SetBig(Intro())
    elseif page.kind == "done" then
        f:SetBig(self.doneText or "")
    end

    local done = page.kind == "done"
    f.back:SetShown(not done and page.kind ~= "intro")
    f.settings:SetShown(done)
    f.tour:SetShown(done and self.appliedAny and ns.Tour and ns.Tour.HasSteps() or false)
    f.keys:SetShown(done and self.appliedAny and ns.Keys ~= nil)
    f.undo:SetShown(done and self.appliedAny and ns.db.backups ~= nil and #ns.db.backups > 0)
    f.undo.armed = nil
    f.undo:SetText("Undo these changes")
    f.keys:ClearAllPoints()
    if f.tour:IsShown() then
        f.keys:SetPoint("LEFT", f.tour, "RIGHT", 8, 0)
    else
        f.keys:SetPoint("BOTTOMLEFT", PAD, f.rowY)
    end
    f.next:SetShown(not done)
    f.quick:SetShown(page.kind == "intro")
    f.looks:SetShown(page.kind == "intro")
    -- also after an undo (appliedAny is false then), since some addon settings only restore on reload
    local wantReload = done and ns.needsReload and true or false
    f.reload:SetShown(wantReload)
    f.close:SetShown(done)
    f.close:ClearAllPoints()
    if wantReload then
        f.close:SetPoint("RIGHT", f.reload, "LEFT", -8, 0)
    else
        f.close:SetPoint("BOTTOMRIGHT", -PAD, f.footY)
    end
    f.back:SetEnabled(index > 1)
    if page.kind == "summary" then
        f.next:SetText(nothing and "Finish" or "Apply changes")
    elseif page.kind == "intro" then
        f.next:SetText("Step by step")
    elseif page.number == NUM_STEPS or (self.singleStep and page.kind == "module") then
        f.next:SetText("Review")
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
    elseif self.singleStep and page.kind == "module" then
        -- opened for one step: the other steps are off, so go straight to the review
        for i, p in ipairs(PAGES) do
            if p.kind == "summary" then self:Go(i) return end
        end
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
            if count > 0 then sels[#sels + 1] = { mod = mod, items = chosen, count = count, order = #sels + 1 } end
        end
    end
    return sels
end

-- The name of a step as the player sees it in the wizard ("Game settings"), not the module's own title.
-- detail = on a step with several modules, add which part ("Scale & layout: Layout").
function Installer:StepTitle(key, detail)
    local page = PAGES[PAGE_OF[key] or 0]
    if not page then return nil end
    if detail and #page.keys > 1 then
        local mod = ns.modules[key]
        local part = (page.groups and page.groups[key]) or (mod and mod.title) or key
        return page.title .. ": " .. part
    end
    return page.title
end

-- Numbers for the review: changes, steps with changes, settings already right, skipped steps, keys that get lost
function Installer:Totals()
    local t = { changes = 0, steps = 0, already = 0, skipped = 0, attention = 0 }
    for _, sel in ipairs(self:Selections()) do
        t.changes = t.changes + sel.count
        t.steps = t.steps + 1
    end
    for _, key in ipairs(APPLY_ORDER) do
        if self.items[key] and self.stepOn[key] then
            for _, item in ipairs(self.items[key]) do
                if item.attention and self:ParentChanges(key, item) then t.attention = t.attention + 1 end
                if IsAlreadyRight(item) then t.already = t.already + 1 end
            end
        end
    end
    -- skipped counts steps as the player saw them, not modules
    if not self.singleStep then
        for _, page in ipairs(PAGES) do
            if page.keys and not self:PageOn(page) then t.skipped = t.skipped + 1 end
        end
    end
    return t
end

function Installer:ApplyAll()
    if InCombatLockdown() then
        ns.Print(C.red .. "You are in combat. Try again after combat." .. C.r)
        return
    end
    local sels = self:Selections()
    if #sels == 0 then
        -- Nothing was applied, so the wizard is not "done": it can still offer itself on the next login
        self.frame:Hide()
        ns.Print("Nothing was changed. " .. C.white .. "/mlz install" .. C.r .. " opens the wizard again.")
        return
    end

    local backup, failedTitle = ns.Backup:Create(sels)
    if not backup then
        ns.Print(C.red .. "Nothing was changed: the backup of " .. tostring(failedTitle)
            .. " failed. /mlz debug shows why." .. C.r)
        return
    end

    local lines, failed, partly = {}, 0, 0
    for _, sel in ipairs(sels) do
        local title = self:StepTitle(sel.mod.key, true) or sel.mod.title
        local ok, result = pcall(sel.mod.Apply, sel.mod, sel.items)
        if not ok then
            failed = failed + 1
            lines[#lines + 1] = C.red .. "FAILED" .. C.r .. "  " .. title .. ": " .. tostring(result)
            ns.Debug("Error in " .. sel.mod.title .. ":", result)
        elseif type(result) == "string" then
            -- the module did its best but something did not work: say what, in plain words
            partly = partly + 1
            lines[#lines + 1] = C.amber .. "PARTLY" .. C.r .. "  " .. title .. ": " .. result
        else
            lines[#lines + 1] = C.green .. "OK" .. C.r .. "  " .. title
        end
    end
    -- A preset only becomes your saved choice once it is applied
    if self.presetPending then
        for key, items in pairs(self.items) do
            if self.stepOn[key] then
                for _, item in ipairs(items) do
                    if not item.unavailable and not item.fixed then ns.SetEnabled(key, item.id, item.enabled) end
                end
            end
        end
        self.presetPending = nil
    end
    ns.db.installed = true
    self.appliedAny = true
    ns.FireState()

    local text = table.concat(lines, "\n") .. "\n\n"
    if failed > 0 then
        text = text .. C.red .. "Something failed. Type /mlz undo to go back, and pass on the error from /mlz debug." .. C.r .. "\n\n"
    elseif partly > 0 then
        text = text .. C.amber .. "Some parts could not be done. The rest is in place." .. C.r .. "\n\n"
    end
    if ns.needsReload then
        local why = ns.reloadReasons and #ns.reloadReasons > 0 and (" (" .. table.concat(ns.reloadReasons, ", ") .. ")") or ""
        text = text .. "Some addon settings need a reload" .. why .. ". Press " .. C.white .. "Reload now" .. C.r .. " when it suits you.\n\n"
    else
        text = text .. "Everything is already in effect. No reload needed.\n\n"
    end
    if ns.editModeStale then
        text = text .. C.amber .. "Reload before you open Edit Mode, or it may show the old layout." .. C.r .. "\n\n"
    end
    self.doneText = text .. "Settings: " .. C.white .. "/mlz" .. C.r .. "     Undo: " .. C.white .. "/mlz undo" .. C.r
        .. "     Run again: " .. C.white .. "/mlz install" .. C.r
    self:Go(#PAGES)
end

-- The undo button on the last page
function Installer:UndoLast()
    local ran = ns.Backup:Undo(true)
    if ran == "partial" then
        -- keep the button: pressing it again retries what failed
        self.doneText = (self.doneText or "") .. "\n\n" .. C.amber .. "Some parts could not be undone. Press the undo button again to retry." .. C.r
        self:Go(#PAGES)
        return
    end
    self.appliedAny = false
    if ran == false then
        self.doneText = "You are in combat. The undo runs when combat ends."
    else
        self.doneText = "Undone. Everything is back the way it was before this run."
            .. (ns.needsReload and (" Some addon settings need a reload to finish: " .. C.white .. "/reload" .. C.r .. ".") or "")
            .. "\n\nRun the wizard again any time with " .. C.white .. "/mlz install" .. C.r .. "."
    end
    self:Go(#PAGES)
end

------------------------------------------------------------------------
-- Opening
------------------------------------------------------------------------
-- Builds the preview of every step. stepKey = opened for one step only: the others are off.
function Installer:Preview(stepKey)
    self.items, self.stepOn = {}, {}
    local broken = {}
    for key in pairs(PAGE_OF) do
        local mod = ns.modules[key]
        local ok, items = false, nil
        if mod and mod.Preview then ok, items = pcall(mod.Preview, mod) end
        if ok then
            self.items[key] = items
        else
            if mod then
                broken[#broken + 1] = mod.title
                ns.Debug("Preview failed for", mod.title, items)
            end
            self.items[key] = {}
        end
        -- Opened for one module (e.g. "Re-apply layout"): only that module is on, even on a shared step
        self.stepOn[key] = mod ~= nil and ((stepKey == nil) or (key == stepKey))
    end
    self.singleStep = stepKey ~= nil
    self.presetPending = nil
    if #broken > 0 then
        table.sort(broken)
        ns.Print(C.amber .. "Could not read the current state of: " .. table.concat(broken, ", ")
            .. ". Those steps are empty. /mlz debug shows why." .. C.r)
    end
end

function Installer:Open(stepKey)
    if InCombatLockdown() then
        ns.Print("The wizard can't open in combat. Try again after combat.")
        return
    end
    -- Setup paused by combat: carry on where you left off instead of starting over
    if not stepKey and self:Resume() then return end
    self:Build()
    self.hiddenByCombat = nil
    self.appliedAny, self.showAlready = false, {}
    for key in pairs(PAGE_OF) do
        local mod = ns.modules[key]
        if mod and mod.BeginWizard then pcall(mod.BeginWizard, mod) end
    end
    self:Preview(stepKey)
    self.frame:Show()
    self:Go(stepKey and PAGE_OF[stepKey] or 1)
end

-- Steps in "Looks only": how things look, not how the game plays
local LOOKS_ONLY = { role = true, scale = true, layout = true, fade = true, actionbuttons = true, tweaks = true, nameplates = true }

-- "recommended" = every step with the suggested rows. "looks" = only the steps in LOOKS_ONLY.
-- Both start from the suggestions, not from rows you unticked in an earlier run.
function Installer:ApplyPreset(name)
    -- Preview against empty toggles to get the suggestions, then put your saved choices back.
    -- They are only replaced when you press Apply (see ApplyAll), so closing the wizard keeps them.
    local saved = ns.db.toggles
    ns.db.toggles = {}
    local ok, err = pcall(self.Preview, self)
    ns.db.toggles = saved
    if not ok then ns.Debug("Preset preview failed:", err) end
    self.presetPending = true
    for key in pairs(self.stepOn) do
        self.stepOn[key] = (name == "recommended") or LOOKS_ONLY[key] or false
    end
    for i, page in ipairs(PAGES) do
        if page.kind == "summary" then self:Go(i) return end
    end
end

ns.AddCommand("install", "opens the installation wizard", function() Installer:Open() end)

-- Entering combat hides the wizard but keeps your choices. It does not pop back up on its own;
-- Installer:Resume() (minimap button) brings it back where you left off.
ns.On("PLAYER_REGEN_DISABLED", function()
    local f = Installer.frame
    if f and f:IsShown() then
        f:Hide()
        if PAGES[Installer.page] and PAGES[Installer.page].kind ~= "done" then
            if not Installer.hiddenByCombat then
                ns.Print("Setup paused for combat. Open it again from the minimap button.")
            end
            Installer.hiddenByCombat = true
        end
    end
end)

-- Opens the wizard again with the choices kept, if it was paused by combat. Returns true if it did.
function Installer:Resume()
    if not (self.hiddenByCombat and self.frame) or InCombatLockdown() then return false end
    self.hiddenByCombat = nil
    self.frame:Show()
    self:Go(self.page)
    return true
end
