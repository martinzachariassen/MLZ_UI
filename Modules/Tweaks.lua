-- MLZ UI: Tweaks
--   * Hide the "All Objectives" line at the top of the quest tracker, or the whole tracker
--   * /mlz map: slider for the minimap size (saved in the Edit Mode layout)
--
-- Only changes alpha/scale on unprotected Blizzard frames, so it is safe and causes no taint.

local _, ns = ...

local Tweaks = ns.RegisterModule({ key = "tweaks", title = "Tweaks" })

local OPTIONS = {
    { id = "trackerHeader", label = 'Hide the "All Objectives" line',
      desc = "Removes the header/tab at the top of the quest tracker. Quests are still shown, and each section (Quests etc.) can still be collapsed. /mlz tracker toggles it." },
    { id = "trackerHide", label = "Hide the entire quest tracker", default = false,
      desc = "No tracked quests on screen at all. The quest log (L) and quest markers on the map work as before. /mlz quests toggles it at any time." },    { id = "fps", label = "FPS counter in the bottom-right corner", group = "Info",
      desc = "Small text in the bottom-right corner: FPS (green/yellow/red) and ping in ms. Clicks pass through it. /mlz fps toggles it." },
    { id = "cleanCombatFont", label = "Clean combat text font", group = "Combat text",
      desc = "Uses Arial Narrow for floating damage and healing numbers. Needs a full game restart (not just /reload) to take effect." },
}

local function Cfg() return ns.db and ns.db.tweaks end

------------------------------------------------------------------------
-- Quest tracker header
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
        -- Blizzard may reset the alpha (hover/update); keep it hidden
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
-- Entire quest tracker
-- The tracker may have protected quest item buttons, so Hide() only runs out of combat.
-- If it is shown in combat, it is made invisible via alpha until combat ends.
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
        end, "hiding quest tracker")
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
                    -- Let Blizzard rebuild the contents
                    if frame.Update then pcall(frame.Update, frame) end
                end, "showing quest tracker")
            end
        end
    end
end

------------------------------------------------------------------------
-- FPS counter (bottom-right corner, below the bag buttons)
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

ns.AddCommand("fps", "shows/hides the FPS counter in the bottom right", function()
    ns.db.tweaks = ns.db.tweaks or {}
    ns.db.tweaks.fps = not ns.db.tweaks.fps
    Tweaks:Refresh()
    ns.Print("FPS counter:", ns.db.tweaks.fps and "on" or "off")
end)

------------------------------------------------------------------------
-- Minimap size (/mlz map)
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
        ns.Print("Minimap size:", size .. "%. Saved in the Edit Mode layout.")
    else
        ns.Print("Minimap set to", size .. "% for now, but it was not saved in the layout:", tostring(err),
            "(it will be used the next time you run the layout step in /mlz install)")
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
        f.title = ns.W.Text(f, "GameFontHighlight", "MLZ UI: Minimap size", "CENTER")
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

        local save = ns.W.Button(f, "Save", 90, 22, function()
            f.saved = true
            SaveMap(f.current)
            f:Hide()
        end)
        save:SetPoint("BOTTOMRIGHT", -12, 10)
        local reset = ns.W.Button(f, "Default (130%)", 120, 22, function() s:SetValue(130) end)
        reset:SetPoint("BOTTOMLEFT", 12, 10)

        -- Closed without saving: revert to how it was
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

ns.AddCommand("map", "changes the minimap size (slider, or e.g. /mlz map 120)", function(arg)
    local n = tonumber(arg)
    if n then SaveMap(n) else OpenMapSlider() end
end)

ns.AddCommand("quests", "hides/shows the entire quest tracker", function()
    ns.db.tweaks = ns.db.tweaks or {}
    ns.db.tweaks.trackerHide = not ns.db.tweaks.trackerHide
    Tweaks:Refresh()
    ns.Print("Quest tracker:", ns.db.tweaks.trackerHide and "hidden" or "shown")
end)

ns.AddCommand("tracker", 'hides/shows the "All Objectives" line in the quest tracker', function()
    ns.db.tweaks = ns.db.tweaks or {}
    ns.db.tweaks.trackerHeader = not ns.db.tweaks.trackerHeader
    Tweaks:Refresh()
    ns.Print('"All Objectives" line:', ns.db.tweaks.trackerHeader and "hidden" or "shown")
end)

------------------------------------------------------------------------
-- Module interface
------------------------------------------------------------------------
function Tweaks:Preview()
    local items = {}
    local cur = Cfg()
    local hasTracker = _G.ObjectiveTrackerFrame and _G.ObjectiveTrackerFrame.Header
    for _, o in ipairs(OPTIONS) do
        local item = {
            id = o.id, label = o.label, group = o.group or "Quest tracker", note = o.desc,
            old = (cur and cur[o.id]) and (o.group and "on" or "hidden") or (o.group and "off" or "shown"),
            new = o.group and "on" or "hidden",
            enabled = ns.Enabled("tweaks", o.id, o.default ~= false),
        }
        if cur and cur[o.id] then item.alreadySet = true end
        if o.id == "trackerHide" and not (_G.ObjectiveTrackerFrame or _G.QuestWatchFrame) then
            item.unavailable, item.new, item.enabled = true, "tracker not found", false
        end
        if o.id == "trackerHeader" and not hasTracker then
            item.unavailable, item.new, item.enabled = true, "header not found", false
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

-- DAMAGE_TEXT_FONT is a global read when the world loads, so set it as early as possible.
ns.On("ADDON_LOADED", function(_, name)
    if name ~= "MLZ_UI" then return end
    local c = Cfg()
    if c and c.cleanCombatFont then _G.DAMAGE_TEXT_FONT = "Fonts\\ARIALN.TTF" end
end)

ns.On("PLAYER_ENTERING_WORLD", function()
    if Cfg() then
        Tweaks:Refresh()
        C_Timer.After(2, function() Tweaks:Refresh() end) -- the tracker is built a bit later
    end
    local ov = ns.db.overrides
    if ov and ov.minimapSize then PreviewMap(ov.minimapSize) end
end)
