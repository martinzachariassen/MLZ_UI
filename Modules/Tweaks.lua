-- MLZ UI: Tweaks
--   * Hide the "All Objectives" line at the top of the quest tracker, or the whole tracker
--   * Minimap size (slider in the settings window, saved in the Edit Mode layout)
--
-- Only changes alpha/scale on unprotected Blizzard frames, so it is safe and causes no taint.

local _, ns = ...

local Tweaks = ns.RegisterModule({ key = "tweaks", title = "Tweaks" })

local OPTIONS = {
    { id = "trackerHeader", label = 'Hide the "All Objectives" line',
      desc = "Removes the header at the top of the quest tracker. Your quests still show, and each section can still be collapsed." },
    { id = "trackerHide", label = "Hide the entire quest tracker", default = false,
      desc = "No tracked quests on screen. The quest log and the quest markers on the map work as before." },
    { id = "fps", label = "FPS counter in the bottom-right corner", group = "Info",
      desc = "Small FPS and ping text in the bottom-right corner. Clicks pass through it." },
    { id = "cleanCombatFont", label = "Clean combat text font", group = "Combat text",
      desc = "Uses Roboto Bold for floating damage and healing numbers." },
    { id = "tooltipClass", label = "Class colors in unit tooltips", group = "Tooltips",
      desc = "Player names in the mouseover tooltip use their class color, so you see the class at a glance." },
    { id = "tooltipTarget", label = "Show what a unit is targeting", group = "Tooltips",
      desc = 'Adds a "Target:" line to the mouseover tooltip. Shows "you" in amber when it targets you.' },
}

-- The combat font is read once when the game starts, so a change only shows after a restart.
-- fontAtStart remembers what this session started with, so the note stays until then.
local fontAtStart
OPTIONS[4].desc = function()
    local base = "Uses Roboto Bold for floating damage and healing numbers."
    local want = (ns.db and ns.db.tweaks and ns.db.tweaks.cleanCombatFont) and true or false
    if fontAtStart ~= nil and want ~= fontAtStart then
        return base .. " " .. ns.W.C.amber .. "Takes effect after you restart the game." .. ns.W.C.r
    end
    return base .. " Changes take effect after a game restart."
end

Tweaks.options = OPTIONS -- read by the settings window

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
local hiddenByUs = {} -- only frames we hid get shown again (Blizzard hides an empty tracker on purpose)

local function HideTracker(frame)
    local c = Cfg()
    if not (c and c.trackerHide) then return end
    hiddenByUs[frame] = true
    if InCombatLockdown() then
        frame:SetAlpha(0)
        ns.RunOutOfCombat(function()
            local c2 = Cfg()
            if c2 and c2.trackerHide then frame:Hide() end
        end, "hiding quest tracker " .. (frame:GetName() or ""), true)
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
            elseif hiddenByUs[frame] then
                ns.RunOutOfCombat(function()
                    hiddenByUs[frame] = nil
                    frame:SetAlpha(1)
                    frame:Show()
                    -- Let Blizzard rebuild the contents
                    if frame.Update then pcall(frame.Update, frame) end
                end, "showing quest tracker " .. name)
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

------------------------------------------------------------------------
-- Unit tooltips: class colored names and a "Target:" line
-- Hooked once; each call checks the settings, so turning an option off needs no unhook.
-- The tooltip is rebuilt every time it shows, so there is nothing to restore.
------------------------------------------------------------------------
local function ClassColor(unit)
    if not UnitIsPlayer(unit) then return nil end
    local _, class = UnitClass(unit)
    local colors = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS
    return class and colors and colors[class]
end

local function OnTooltipUnit(tooltip)
    local c = Cfg()
    if not (c and (c.tooltipClass or c.tooltipTarget)) or tooltip ~= _G.GameTooltip then return end
    local _, unit = tooltip:GetUnit()
    if not unit then return end
    if c.tooltipClass then
        local color = ClassColor(unit)
        local line = _G.GameTooltipTextLeft1
        if color and line then line:SetTextColor(color.r, color.g, color.b) end
    end
    if c.tooltipTarget and UnitExists(unit .. "target") then
        local target = unit .. "target"
        local text
        if UnitIsUnit(target, "player") then
            text = ns.W.C.amber .. "you" .. ns.W.C.r
        else
            local name = UnitName(target) or "?"
            local color = ClassColor(target)
            text = color and ("|c" .. (color.colorStr or "ffffffff") .. name .. "|r") or name
        end
        tooltip:AddLine(ns.W.C.grey .. "Target:|r " .. text)
        tooltip:Show() -- resize to fit the new line
    end
end

local tooltipHooked = false
local function HookTooltips()
    if tooltipHooked then return end
    local c = Cfg()
    if not (c and (c.tooltipClass or c.tooltipTarget)) then return end -- hook only once it is wanted
    tooltipHooked = true
    local function Safe(tooltip)
        local ok, err = pcall(OnTooltipUnit, tooltip)
        if not ok then ns.Error("tooltip", err) end
    end
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, Safe)
    elseif _G.GameTooltip and _G.GameTooltip:HasScript("OnTooltipSetUnit") then
        _G.GameTooltip:HookScript("OnTooltipSetUnit", Safe)
    else
        tooltipHooked = false
    end
end
Tweaks.TooltipsAvailable = function()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then return true end
    return (_G.GameTooltip and _G.GameTooltip:HasScript("OnTooltipSetUnit")) and true or false
end

function Tweaks:Refresh()
    if not Cfg() then return end
    pcall(TrackerHeader)
    pcall(TrackerVisibility)
    pcall(Fps)
    pcall(HookTooltips)
end

-- Public API (settings window)
function Tweaks:IsOn(id) return (ns.db.tweaks and ns.db.tweaks[id]) and true or false end

function Tweaks:Set(id, on)
    ns.db.tweaks = ns.db.tweaks or {}
    ns.db.tweaks[id] = on and true or nil
    self:Refresh()
    ns.FireState()
end

ns.AddCommand("fps", "shows/hides the FPS counter in the bottom right", function()
    Tweaks:Set("fps", not Tweaks:IsOn("fps"))
    ns.Print("FPS counter:", Tweaks:IsOn("fps") and "on" or "off")
end)

------------------------------------------------------------------------
-- Minimap size (/mlz map)
------------------------------------------------------------------------
local MAP_MIN, MAP_MAX, MAP_STEP = 50, 200, 10
Tweaks.MAP_MIN, Tweaks.MAP_MAX, Tweaks.MAP_STEP, Tweaks.MAP_DEFAULT = MAP_MIN, MAP_MAX, MAP_STEP, 130

local function MapSize()
    local ov = ns.db.overrides
    if ov and ov.minimapSize then return ov.minimapSize end
    local cluster = _G.MinimapCluster
    if cluster then return math.floor(cluster:GetScale() * 100 / MAP_STEP + 0.5) * MAP_STEP end
    return 130
end

-- The minimap cluster is an Edit Mode frame; only touch it out of combat
local function PreviewMap(size)
    local cluster = _G.MinimapCluster
    if not cluster or InCombatLockdown() then return end
    if math.abs(cluster:GetScale() - size / 100) > 0.001 then pcall(cluster.SetScale, cluster, size / 100) end
end

-- Saves the size in MLZUIDB and in the Edit Mode layout. quiet = no chat output (the settings window
-- shows the result itself). In combat it waits until combat ends. Returns ok, error message.
local function SaveMap(size, quiet)
    size = math.max(MAP_MIN, math.min(MAP_MAX, math.floor(size / MAP_STEP + 0.5) * MAP_STEP))
    ns.db.overrides = ns.db.overrides or {}
    ns.db.overrides.minimapSize = size
    if InCombatLockdown() then
        ns.RunOutOfCombat(function() SaveMap(size, true) end, "saving the minimap size", quiet)
        ns.FireState()
        return false, "in combat, saved when combat ends"
    end
    PreviewMap(size)
    local ok, err = ns.modules.layout:UpdateOne("minimap", "Size", size)
    if not quiet then
        if ok then
            ns.Print("Minimap size:", size .. "%. Saved in the Edit Mode layout.")
        else
            ns.Print("Minimap set to", size .. "% for now, but it was not saved in the layout:", tostring(err),
                "(it will be used the next time you run the layout step in the setup wizard)")
        end
    end
    ns.FireState()
    return ok, err
end

Tweaks.MapSize = MapSize
Tweaks.PreviewMap = PreviewMap
Tweaks.SaveMap = SaveMap

ns.AddCommand("map", "changes the minimap size (opens the settings, or e.g. /mlz map 120)", function(arg)
    local n = tonumber(arg)
    if n then SaveMap(n) elseif ns.Settings then ns.Settings:Open("layout") end
end)

ns.AddCommand("quests", "hides/shows the entire quest tracker", function()
    Tweaks:Set("trackerHide", not Tweaks:IsOn("trackerHide"))
    ns.Print("Quest tracker:", Tweaks:IsOn("trackerHide") and "hidden" or "shown")
end)

ns.AddCommand("tracker", 'hides/shows the "All Objectives" line in the quest tracker', function()
    Tweaks:Set("trackerHeader", not Tweaks:IsOn("trackerHeader"))
    ns.Print('"All Objectives" line:', Tweaks:IsOn("trackerHeader") and "hidden" or "shown")
end)

------------------------------------------------------------------------
-- Module interface
------------------------------------------------------------------------
function Tweaks:Preview()
    local items = {}
    local cur = Cfg()
    local hasTracker = _G.ObjectiveTrackerFrame and _G.ObjectiveTrackerFrame.Header
    for _, o in ipairs(OPTIONS) do
        local isOn = (cur and cur[o.id]) and true or false
        local offText = o.group and "off" or "shown"
        local item = {
            id = o.id, label = o.label, group = o.group or "Quest tracker", note = type(o.desc) == "function" and o.desc() or o.desc,
            toggle = true, isOn = isOn, offText = offText,
            old = isOn and (o.group and "on" or "hidden") or offText,
            new = o.group and "on" or "hidden",
            enabled = isOn or ns.Enabled("tweaks", o.id, o.default ~= false),
        }
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
    for _, item in ipairs(items) do cfg[item.id] = item.enabled or nil end -- unticked = turn off
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
    fontAtStart = (c and c.cleanCombatFont) and true or false
    if fontAtStart then _G.DAMAGE_TEXT_FONT = "Interface\\AddOns\\MLZ_UI\\Media\\Roboto-Bold.ttf" end
end)

ns.On("PLAYER_ENTERING_WORLD", function()
    if Cfg() then
        Tweaks:Refresh()
        C_Timer.After(2, function() Tweaks:Refresh() end) -- the tracker is built a bit later
    end
    local ov = ns.db.overrides
    if ov and ov.minimapSize then PreviewMap(ov.minimapSize) end
end)
