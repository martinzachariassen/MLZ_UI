-- MLZ UI: Installasjonsveiviser
-- Viser hva hver modul vil endre (Preview), lar brukeren velge, tar backup og utfører (Apply).

local _, ns = ...
local W = ns.W
local C = W.C

local Installer = {}
ns.Installer = Installer

local APPLY_ORDER = { "scale", "settings", "layout", "bindings", "fade", "actionbuttons", "consumables", "tweaks" }

local PAGES = {
    { kind = "intro", title = "Velkommen til MLZ UI" },
    { kind = "module", key = "scale", title = "1. Skalering",
      text = "Setter UI-skalaen slik at kanter blir skarpe og alt får samme størrelse uansett oppløsning. Skalaen regnes ut på nytt automatisk hvis du bytter oppløsning." },
    { kind = "module", key = "layout", title = "2. Layout (Edit Mode)",
      text = "Lager en egen Edit Mode-layout med barer nederst midt, player/target på sidene, chat nede til venstre og minimap/buffs oppe til høyre. Du kan finjustere alt i Edit Mode etterpå. Krever /reload." },
    { kind = "module", key = "settings", title = "3. Innstillinger",
      text = "Gode standardinnstillinger. Grå rader har allerede riktig verdi. Hold musen over en rad for forklaring." },
    { kind = "module", key = "bindings", title = "4. Keybinds",
      text = "Samme 12 taster på tre lag: uten modifier = Bar 1, " .. C.gold .. "Shift" .. C.r .. " = Bar 2, " .. C.gold .. "Ctrl" .. C.r .. " = Bar 3. " .. C.red .. "Rød" .. C.r .. " = tasten har en annen handling i dag. Fortrengte paneler flyttes til Alt." },
    { kind = "module", key = "fade", title = "5. Minimalisme",
      text = "Mer av verden: ting du sjelden bruker blir usynlige til du holder musen over dem, og ting du bare trenger i kamp dempes ellers. Skriv /mlz fade for å slå det av midlertidig." },
    { kind = "module", key = "actionbuttons", title = "6. Action-knapper",
      text = "Se med en gang hvorfor en knapp ikke virker: " .. C.red .. "rød" .. C.r .. " = utenfor rekkevidde, |cff5577ffblå|r = lite mana, mørk grå = kan ikke brukes nå. Korte hotkeys og ingen makronavn gir renere barer. /mlz buttons slår fargene av/på." },
    { kind = "module", key = "consumables", title = "7. Barer uten hotkeys",
      text = "Over chatten kommer to barer du bare klikker på: nederst en " .. C.gold .. "auto-bar" .. C.r .. " som fyller seg selv med beste mat, drikke, potions, bandages, healthstone osv. fra bagen, og over den " .. C.gold .. "bar 6" .. C.r .. " som du fyller selv (hearthstone, mount, profesjoner). Bar 6 og plasseringen settes i layout-steget." },
    { kind = "module", key = "tweaks", title = "8. Småjusteringer",
      text = "Mindre ting som rydder skjermen. Tips: " .. C.gold .. "/mlz map" .. C.r .. " gir en slider for størrelsen på minimap, og " .. C.gold .. "/mlz tracker" .. C.r .. ' slår "All Objectives"-linjen av/på, og ' .. C.gold .. "/mlz quests" .. C.r .. " skjuler hele quest trackeren." },
    { kind = "summary", title = "Oppsummering" },
    { kind = "done", title = "Ferdig!" },
}

local INTRO = table.concat({
    "Denne veiviseren setter opp UI-et ditt steg for steg:",
    "",
    "  " .. C.gold .. "1." .. C.r .. " Skalering som passer skjermen din",
    "  " .. C.gold .. "2." .. C.r .. " Plassering av barer og frames (egen Edit Mode-layout)",
    "  " .. C.gold .. "3." .. C.r .. " Innstillinger som auto loot og cast på tastenedtrykk",
    "  " .. C.gold .. "4." .. C.r .. " Keybinds (ESDF og tre lag med samme taster)",
    "  " .. C.gold .. "5." .. C.r .. " Minimalisme: skjul det du ikke trenger, så du ser mest mulig av verden",
    "",
    "For hvert steg ser du hva som er i dag og hva det blir. Du kan slå av hele steg eller enkeltrader.",
    "Ingenting endres før du trykker " .. C.gold .. "Bruk endringer" .. C.r .. " på siste side.",
    "",
    C.green .. "Det tas alltid backup først." .. C.r .. " Skriv " .. C.gold .. "/mlz undo" .. C.r .. " for å angre, og " .. C.gold .. "/mlz install" .. C.r .. " for å åpne veiviseren igjen.",
}, "\n")

local COL = { check = 4, label = 32, old = 270, arrow = 448, new = 468 }
local ROW_H = 22

------------------------------------------------------------------------
-- Oppbygging av vinduet
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
    tinsert(UISpecialFrames, "MLZUI_Installer") -- ESC lukker
    self.frame = f

    f.windowTitle = W.Text(f, "GameFontHighlight", "MLZ UI - Oppsett", "CENTER")
    f.windowTitle:SetPoint("TOP", 0, -5)

    f.title = W.Text(f, "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 20, -36)

    f.step = W.Text(f, "GameFontDisableSmall", nil, "RIGHT")
    f.step:SetPoint("TOPRIGHT", -20, -40)

    f.desc = W.Text(f, "GameFontHighlight")
    f.desc:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -10)
    f.desc:SetWidth(720)

    f.stepCheck = W.Check(f, "Bruk dette steget", function(_, checked)
        local page = PAGES[self.page]
        if page.key then
            self.stepOn[page.key] = checked
            self:RenderList()
        end
    end)
    f.stepCheck:SetPoint("TOPLEFT", f.desc, "BOTTOMLEFT", -4, -8)

    -- Kolonneoverskrifter
    f.header = CreateFrame("Frame", nil, f)
    f.header:SetSize(700, 16)
    f.header:SetPoint("TOPLEFT", f.stepCheck, "BOTTOMLEFT", 4, -6)
    local function H(text, x) local t = W.Text(f.header, "GameFontNormalSmall", text); t:SetPoint("LEFT", x, 0) end
    H("Hva", COL.label); H("I dag", COL.old); H("Blir", COL.new)

    f.scroll = W.ScrollArea(f)
    f.scroll:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -2)
    f.scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 52)
    f.scroll.content:SetWidth(700)

    f.big = W.Text(f, "GameFontHighlight")
    f.big:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -16)
    f.big:SetWidth(700)
    f.big:SetSpacing(4)

    -- Navigasjon
    f.back = W.Button(f, "Tilbake", 110, 26, function() self:Go(self.page - 1) end)
    f.back:SetPoint("BOTTOMLEFT", 16, 14)
    f.next = W.Button(f, "Neste", 150, 26, function() self:Next() end)
    f.next:SetPoint("BOTTOMRIGHT", -16, 14)
    f.skip = W.Button(f, "Hopp over", 110, 26, function()
        local page = PAGES[self.page]
        if page.key then self.stepOn[page.key] = false end
        self:Go(self.page + 1)
    end)
    f.skip:SetPoint("RIGHT", f.next, "LEFT", -8, 0)

    f.reload = W.Button(f, "Reload nå", 150, 26, function() ReloadUI() end)
    f.reload:SetPoint("BOTTOMRIGHT", -16, 14)
    f.close = W.Button(f, "Lukk", 110, 26, function() f:Hide() end)
    f.close:SetPoint("RIGHT", f.reload, "LEFT", -8, 0)

    self.rows = {}
end

------------------------------------------------------------------------
-- Rader
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

-- readOnly = oppsummering (ingen avkrysning, ingen klikk)
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
        new = C.grey .. new .. "  (allerede)" .. C.r
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
-- Visning av sider
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
            SetGroupRow(self:AcquireRow(n), C.grey .. "Ingenting er valgt." .. C.r)
        end
        for _, sel in ipairs(sels) do
            n = n + 1
            SetGroupRow(self:AcquireRow(n), ("%s  %s(%d endringer)%s"):format(sel.mod.title, C.grey, #sel.items, C.r))
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
    f.step:SetText(page.kind ~= "done" and ("Steg %d av %d"):format(index, #PAGES - 1) or "")
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
        f.desc:SetText("Dette blir endret når du trykker " .. C.gold .. "Bruk endringer" .. C.r .. ". Det tas backup først.")
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
    f.next:SetText(page.kind == "summary" and "Bruk endringer" or "Neste")

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
-- Utførelse
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
            -- Bevegelsesvalget alene er ingen endring
            local real = 0
            for _, item in ipairs(chosen) do if item.id ~= "__movement" then real = real + 1 end end
            if real > 0 then sels[#sels + 1] = { mod = mod, items = chosen } end
        end
    end
    return sels
end

function Installer:ApplyAll()
    if InCombatLockdown() then
        ns.Print(C.red .. "Du er i kamp. Prøv igjen etter kampen." .. C.r)
        return
    end
    local sels = self:Selections()
    if #sels == 0 then
        ns.db.installed = true
        self.doneText = "Ingenting ble endret. Du kan åpne veiviseren igjen med " .. C.gold .. "/mlz install" .. C.r .. "."
        self:Go(#PAGES)
        return
    end

    local backup = ns.Backup:Create(sels)
    if not backup then
        ns.Print(C.red .. "Avbrutt fordi backup feilet. Ingenting er endret." .. C.r)
        return
    end

    local lines, failed = {}, 0
    for _, sel in ipairs(sels) do
        local ok, err = pcall(sel.mod.Apply, sel.mod, sel.items)
        if ok then
            lines[#lines + 1] = C.green .. "OK" .. C.r .. "  " .. sel.mod.title
        else
            failed = failed + 1
            lines[#lines + 1] = C.red .. "FEIL" .. C.r .. "  " .. sel.mod.title .. ": " .. tostring(err)
            ns.Print(C.red .. "Feil i " .. sel.mod.title .. ":" .. C.r, err)
        end
    end
    ns.db.installed = true

    self.doneText = table.concat(lines, "\n") .. "\n\n" ..
        (failed > 0 and (C.red .. "Noe feilet. Skriv /mlz undo for å angre, og send feilmeldingen videre." .. C.r .. "\n\n") or "") ..
        "Trykk " .. C.gold .. "Reload nå" .. C.r .. " for å laste UI-et på nytt (nødvendig for layout og skalering).\n\n" ..
        "Angre: " .. C.gold .. "/mlz undo" .. C.r .. "     Kjør på nytt: " .. C.gold .. "/mlz install" .. C.r
    self:Go(#PAGES)
end

------------------------------------------------------------------------
-- Åpning
------------------------------------------------------------------------
function Installer:Open()
    if InCombatLockdown() then
        ns.Print("Kan ikke åpne veiviseren i kamp.")
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
                ns.Print(C.red .. "Kunne ikke lage forhåndsvisning for " .. mod.title .. ":" .. C.r, items)
                self.items[page.key] = {}
            end
            self.stepOn[page.key] = true
        end
    end
    self.frame:Show()
    self:Go(1)
end

ns.AddCommand("install", "åpner installasjonsveiviseren", function() Installer:Open() end)

ns.On("PLAYER_REGEN_DISABLED", function()
    if Installer.frame and Installer.frame:IsShown() then
        Installer.frame:Hide()
        ns.Print("Veiviseren ble lukket fordi du gikk i kamp. Åpne igjen med /mlz install.")
    end
end)
