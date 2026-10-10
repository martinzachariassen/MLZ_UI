-- MLZ UI: Småjusteringer
--   * Skjul "All Objectives"-linjen øverst i quest trackeren, eller hele trackeren
--   * /mlz map: slider for størrelsen på minimap (lagres i Edit Mode-layouten)
--
-- Endrer bare alpha/skala på Blizzard-frames som ikke er beskyttet, så det er trygt og gir ikke taint.

local _, ns = ...

local Tweaks = ns.RegisterModule({ key = "tweaks", title = "Småjusteringer" })

local OPTIONS = {
    { id = "trackerHeader", label = 'Skjul "All Objectives"-linjen',
      desc = "Fjerner overskriften/fanen øverst i quest trackeren. Questene vises fortsatt, og hver seksjon (Quests osv.) kan fortsatt foldes sammen. /mlz tracker slår den av/på." },
    { id = "trackerHide", label = "Skjul hele quest trackeren", default = false,
      desc = "Ingen trackede quests på skjermen i det hele tatt. Questloggen (L) og quest-markeringer på kartet virker som før. /mlz quests slår den av/på når som helst." },    { id = "fps", label = "FPS-teller nede i høyre hjørne", group = "Info",
      desc = "Liten tekst helt nede til høyre: FPS (grønn/gul/rød) og ping i ms. Klikker går gjennom den. /mlz fps slår den av/på." },
}

local function Cfg() return ns.db and ns.db.tweaks end

------------------------------------------------------------------------
-- Quest tracker-overskrift
------------------------------------------------------------------------
local headerHooked = false
local function TrackerHeader()
    local tracker = _G.ObjectiveTrackerFrame
    local header = tracker and tracker.Header
    if not header then return end
    local cfg = Cfg()
    local hide = cfg and cfg.trackerHeader
    header:SetAlpha(hide and 0 or 1)
    header:EnableMouse(not hide)
    if header.MinimizeButton then header.MinimizeButton:EnableMouse(not hide) end
    if not headerHooked then
        headerHooked = true
        -- Blizzard kan sette alpha på nytt (hover/oppdatering); hold den skjult
        local busy = false
        hooksecurefunc(header, "SetAlpha", function(self, a)
            local c = Cfg()
            if busy or not (c and c.trackerHeader) or a == 0 then return end
            busy = true
            self:SetAlpha(0)
            busy = false
        end)
    end
end

------------------------------------------------------------------------
-- Hele quest trackeren
-- Trackeren kan ha beskyttede quest-item-knapper, så Hide() kjøres bare utenfor kamp.
-- Vises den i kamp, gjøres den usynlig med alpha til kampen er over.
------------------------------------------------------------------------
local TRACKERS = { "ObjectiveTrackerFrame", "QuestWatchFrame" }
local trackerHooked = {}

local function HideTracker(frame)
    local c = Cfg()
    if not (c and c.trackerHide) then return end
    if InCombatLockdown() then
        frame:SetAlpha(0)
        ns.RunOutOfCombat(function()
            local c2 = Cfg()
            if c2 and c2.trackerHide then frame:Hide() end
        end, "skjuling av quest tracker")
    else
        frame:Hide()
    end
end

local function TrackerVisibility()
    local c = Cfg()
    local hide = c and c.trackerHide
    for _, name in ipairs(TRACKERS) do
        local frame = _G[name]
        if frame then
            if not trackerHooked[frame] then
                trackerHooked[frame] = true
                frame:HookScript("OnShow", HideTracker)
            end
            if hide then
                HideTracker(frame)
            elseif not frame:IsShown() then
                ns.RunOutOfCombat(function()
                    frame:SetAlpha(1)
                    frame:Show()
                    -- La Blizzard bygge innholdet på nytt
                    if frame.Update then pcall(frame.Update, frame) end
                end, "visning av quest tracker")
            end
        end
    end
end

------------------------------------------------------------------------
-- FPS-teller (nede i høyre hjørne, under bag-knappene)
------------------------------------------------------------------------
local fpsFrame
local function FpsColor(fps)
    if fps >= 60 then return "|cff55ff55" elseif fps >= 30 then return "|cffffd100" end
    return "|cffff5555"
end

local function UpdateFps()
    local fps = math.floor(GetFramerate() + 0.5)
    local text = FpsColor(fps) .. fps .. "|r |cff999999fps|r"
    if GetNetStats then
        local _, _, home, world = GetNetStats()
        local ms = math.max(home or 0, world or 0)
        if ms > 0 then text = text .. "   " .. ms .. " |cff999999ms|r" end
    end
    fpsFrame.text:SetText(text)
end

local function Fps()
    local c = Cfg()
    local on = c and c.fps
    if not on then
        if fpsFrame then fpsFrame:Hide() end
        return
    end
    if not fpsFrame then
        local f = CreateFrame("Frame", "MLZUI_FPS", UIParent)
        f:SetSize(120, 14)
        f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -6, 3)
        f:SetFrameStrata("LOW")
        f:EnableMouse(false)
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.text:SetPoint("BOTTOMRIGHT")
        f.text:SetJustifyH("RIGHT")
        local elapsed = 1
        f:SetScript("OnUpdate", function(_, dt)
            elapsed = elapsed + dt
            if elapsed < 1 then return end
            elapsed = 0
            UpdateFps()
        end)
        fpsFrame = f
    end
    fpsFrame:Show()
    UpdateFps()
end

function Tweaks:Refresh()
    if not Cfg() then return end
    pcall(TrackerHeader)
    pcall(TrackerVisibility)
    pcall(Fps)
end

ns.AddCommand("fps", "viser/skjuler FPS-telleren nede til høyre", function()
    ns.db.tweaks = ns.db.tweaks or {}
    ns.db.tweaks.fps = not ns.db.tweaks.fps
    Tweaks:Refresh()
    ns.Print("FPS-teller:", ns.db.tweaks.fps and "på" or "av")
end)

------------------------------------------------------------------------
-- Minimap-størrelse (/mlz map)
------------------------------------------------------------------------
local MAP_MIN, MAP_MAX, MAP_STEP = 50, 200, 10

local function MapSize()
    local ov = ns.db.overrides
    if ov and ov.minimapSize then return ov.minimapSize end
    local cluster = _G.MinimapCluster
    if cluster then return math.floor(cluster:GetScale() * 100 / MAP_STEP + 0.5) * MAP_STEP end
    return 130
end

local function PreviewMap(size)
    local cluster = _G.MinimapCluster
    if cluster then pcall(cluster.SetScale, cluster, size / 100) end
end

local function SaveMap(size)
    size = math.max(MAP_MIN, math.min(MAP_MAX, math.floor(size / MAP_STEP + 0.5) * MAP_STEP))
    ns.db.overrides = ns.db.overrides or {}
    ns.db.overrides.minimapSize = size
    PreviewMap(size)
    local ok, err = ns.modules.layout:UpdateOne("minimap", "Size", size)
    if ok then
        ns.Print("Minimap-størrelse:", size .. "%. Lagret i Edit Mode-layouten.")
    else
        ns.Print("Minimap satt til", size .. "% nå, men ble ikke lagret i layouten:", tostring(err),
            "(den brukes neste gang du kjører layout-steget i /mlz install)")
    end
end

local mapFrame
local function OpenMapSlider()
    if not mapFrame then
        local f = CreateFrame("Frame", "MLZUI_MapSize", UIParent, "BasicFrameTemplateWithInset")
        f:SetSize(300, 130)
        f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -240, -60)
        f:SetFrameStrata("DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f.title = ns.W.Text(f, "GameFontHighlight", "MLZ UI: Minimap-størrelse", "CENTER")
        f.title:SetPoint("TOP", 0, -5)

        local s = CreateFrame("Slider", nil, f)
        s:SetOrientation("HORIZONTAL")
        s:SetSize(240, 18)
        s:SetPoint("TOP", 0, -50)
        s:SetMinMaxValues(MAP_MIN, MAP_MAX)
        s:SetValueStep(MAP_STEP)
        if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
        s:EnableMouse(true)
        local track = s:CreateTexture(nil, "BACKGROUND")
        track:SetColorTexture(0, 0, 0, 0.6)
        track:SetPoint("LEFT")
        track:SetPoint("RIGHT")
        track:SetHeight(6)
        s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        local low = ns.W.Text(s, "GameFontDisableSmall", MAP_MIN .. "%")
        low:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -2)
        local high = ns.W.Text(s, "GameFontDisableSmall", MAP_MAX .. "%", "RIGHT")
        high:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", 0, -2)
        f.value = ns.W.Text(f, "GameFontNormal", "", "CENTER")
        f.value:SetPoint("BOTTOM", s, "TOP", 0, 4)
        s:SetScript("OnValueChanged", function(_, v)
            v = math.floor(v / MAP_STEP + 0.5) * MAP_STEP
            f.value:SetText(v .. "%")
            f.current = v
            PreviewMap(v)
        end)
        f.slider = s

        local save = ns.W.Button(f, "Lagre", 90, 22, function()
            f.saved = true
            SaveMap(f.current)
            f:Hide()
        end)
        save:SetPoint("BOTTOMRIGHT", -12, 10)
        local reset = ns.W.Button(f, "Standard (130%)", 120, 22, function() s:SetValue(130) end)
        reset:SetPoint("BOTTOMLEFT", 12, 10)

        -- Lukket uten å lagre: tilbake til slik den var
        f:SetScript("OnHide", function()
            if not f.saved and f.original then PreviewMap(f.original) end
        end)
        mapFrame = f
    end
    mapFrame.saved = false
    mapFrame.original = MapSize()
    mapFrame.slider:SetValue(mapFrame.original)
    mapFrame.value:SetText(mapFrame.original .. "%")
    mapFrame.current = mapFrame.original
    mapFrame:Show()
end

ns.AddCommand("map", "endrer størrelsen på minimap (slider, eller f.eks. /mlz map 120)", function(arg)
    local n = tonumber(arg)
    if n then SaveMap(n) else OpenMapSlider() end
end)

ns.AddCommand("quests", "skjuler/viser hele quest trackeren", function()
    ns.db.tweaks = ns.db.tweaks or {}
    ns.db.tweaks.trackerHide = not ns.db.tweaks.trackerHide
    Tweaks:Refresh()
    ns.Print("Quest tracker:", ns.db.tweaks.trackerHide and "skjult" or "vises")
end)

ns.AddCommand("tracker", 'skjuler/viser "All Objectives"-linjen i quest trackeren', function()
    ns.db.tweaks = ns.db.tweaks or {}
    ns.db.tweaks.trackerHeader = not ns.db.tweaks.trackerHeader
    Tweaks:Refresh()
    ns.Print('"All Objectives"-linjen:', ns.db.tweaks.trackerHeader and "skjult" or "vises")
end)

------------------------------------------------------------------------
-- Modulgrensesnitt
------------------------------------------------------------------------
function Tweaks:Preview()
    local items = {}
    local cur = Cfg()
    local hasTracker = _G.ObjectiveTrackerFrame and _G.ObjectiveTrackerFrame.Header
    for _, o in ipairs(OPTIONS) do
        local item = {
            id = o.id, label = o.label, group = o.group or "Quest tracker", note = o.desc,
            old = (cur and cur[o.id]) and (o.group and "på" or "skjult") or (o.group and "av" or "vises"),
            new = o.group and "på" or "skjult",
            enabled = ns.Enabled("tweaks", o.id, o.default ~= false),
        }
        if cur and cur[o.id] then item.alreadySet = true end
        if o.id == "trackerHide" and not (_G.ObjectiveTrackerFrame or _G.QuestWatchFrame) then
            item.unavailable, item.new, item.enabled = true, "fant ikke trackeren", false
        end
        if o.id == "trackerHeader" and not hasTracker then
            item.unavailable, item.new, item.enabled = true, "fant ikke overskriften", false
        end
        items[#items + 1] = item
    end
    return items
end

function Tweaks:Backup()
    return { cfg = ns.CopyTable(ns.db.tweaks) }
end

function Tweaks:Apply(items)
    local cfg = ns.CopyTable(ns.db.tweaks) or {}
    for _, item in ipairs(items) do cfg[item.id] = true end
    ns.db.tweaks = cfg
    self:Refresh()
end

function Tweaks:Restore(snap)
    ns.db.tweaks = snap.cfg or {}
    self:Refresh()
    if not snap.cfg then ns.db.tweaks = nil end
end

ns.On("PLAYER_ENTERING_WORLD", function()
    if Cfg() then
        Tweaks:Refresh()
        C_Timer.After(2, function() Tweaks:Refresh() end) -- trackeren bygges litt senere
    end
    local ov = ns.db.overrides
    if ov and ov.minimapSize then PreviewMap(ov.minimapSize) end
end)
