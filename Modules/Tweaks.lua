-- MLZ UI: Tweaks
--   * Hide the "All Objectives" line at the top of the quest tracker, or the whole tracker
--   * Minimap size (slider in the settings window, saved in the Edit Mode layout)
--   * FPS counter, combat text font, unit tooltips, class colored names in chat
--   * Style: square minimap, flat chat input box, Roboto chat font
--
-- Only touches unprotected Blizzard frames (tracker, minimap, chat, tooltip), so it causes no taint.

local _, ns = ...

local Tweaks = ns.RegisterModule({ key = "tweaks", title = "Tweaks" })

local OPTIONS = {
    { id = "trackerHeader", label = 'Hide the "All Objectives" line',
      desc = "Removes the header at the top of the quest tracker. Your quests still show, and each section can still be collapsed." },
    { id = "trackerHide", label = "Hide the entire quest tracker", default = false,
      desc = "No tracked quests on screen. The quest log and the quest markers on the map work as before." },
    { id = "fps", label = "FPS counter in the bottom-right corner", group = "Info",
      desc = "Small text with frame rate and ping. Green is smooth, amber and red are slow. Clicks pass through it." },
    { id = "cleanCombatFont", label = "Clean combat text font", group = "Info",
      desc = "Uses Roboto Bold for floating damage and healing numbers." },
    { id = "tooltipClass", label = "Class colors in unit tooltips", group = "Tooltips",
      desc = "Player names in the mouseover tooltip use their class color, so you see the class at a glance." },
    { id = "tooltipTarget", label = "Show what a unit is targeting", group = "Tooltips",
      desc = 'Adds a "Target:" line to the mouseover tooltip. Shows "you" in amber when it targets you.' },
    { id = "chatClassNames", label = "Class colors on names in chat", group = "Chat",
      desc = "Player names in say, party, raid, guild, whispers and channels use their class color." },
    { id = "flatChatInput", label = "Flat chat input box", group = "Chat",
      desc = "The box you type chat in gets a dark flat background and a thin border instead of the textured frame." },
    { id = "chatFont", label = "Roboto font in chat", group = "Chat", default = false,
      desc = "Chat text uses Roboto Bold, the font of the MLZ UI headings. The size you picked stays the same." },
    { id = "squareMinimap", label = "Square minimap with a thin border", group = "Minimap", default = false,
      desc = "A square map with a 1px border instead of the round ring. Minimap rotation stays off while it is square." },
}

-- Rows that can't be used return the reason (shown in amber in the settings window and the wizard)
local function TooltipsAvailable()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then return true end
    return (_G.GameTooltip and _G.GameTooltip:HasScript("OnTooltipSetUnit")) and true or false
end
Tweaks.TooltipsAvailable = TooltipsAvailable

-- Leatrix Plus has its own minimap styling (square shape, border). Don't fight it.
local function LeatrixMinimap()
    return ns.IsAddOnLoaded("Leatrix_Plus") and type(_G.LeaPlusDB) == "table" and _G.LeaPlusDB.MinimapModder == "On"
end

local AVAIL = {
    tooltipClass = function() if not TooltipsAvailable() then return "Tooltip hooks not available" end end,
    tooltipTarget = function() if not TooltipsAvailable() then return "Tooltip hooks not available" end end,
    chatClassNames = function()
        if type(_G.ChatTypeInfo) ~= "table" then return "Chat colors not found" end
    end,
    squareMinimap = function()
        if not (_G.Minimap and _G.Minimap.SetMaskTexture) then return "Minimap not found" end
        if LeatrixMinimap() then return "Leatrix Plus styles the minimap" end
    end,
}
for _, o in ipairs(OPTIONS) do o.avail = AVAIL[o.id] end

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
-- The tracker is an Edit Mode system, so it is never hidden or moved: it gets alpha 0 and stops
-- catching the mouse. Protected children (quest item buttons) are left alone. Fade reads
-- ns.hiddenFrames so it doesn't fade the tracker back in.
------------------------------------------------------------------------
local TRACKERS = { "ObjectiveTrackerFrame", "QuestWatchFrame" }
local trackerHooked = {}
local mouseOff = {} -- frames whose mouse we turned off, so we can turn it back on
ns.hiddenFrames = ns.hiddenFrames or {}

local function MouseOff(frame, depth)
    if not frame or (frame.IsProtected and frame:IsProtected()) then return end
    if frame.IsMouseEnabled and frame:IsMouseEnabled() then
        frame:EnableMouse(false)
        mouseOff[frame] = true
    end
    if depth < 4 and frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do MouseOff(child, depth + 1) end
    end
end

local function MouseBack()
    for f in pairs(mouseOff) do
        if not (f.IsProtected and f:IsProtected()) then f:EnableMouse(true) end
    end
    wipe(mouseOff)
end

local function HideTracker(frame)
    local c = Cfg()
    if not (c and c.trackerHide) then return end
    ns.hiddenFrames[frame] = true
    frame:SetAlpha(0)
    -- New quest lines are built with the mouse on; catch them out of combat
    ns.RunOutOfCombat(function()
        local c2 = Cfg()
        if c2 and c2.trackerHide then MouseOff(frame, 0) end
    end, "hiding quest tracker " .. (frame:GetName() or ""), true)
end

local function ShowTracker(frame)
    ns.hiddenFrames[frame] = nil
    frame:SetAlpha(1)
end

local function TrackerVisibility()
    local c = Cfg()
    local hide = c and c.trackerHide
    local wasHidden = false
    for _, name in ipairs(TRACKERS) do
        local frame = _G[name]
        if frame then
            if not trackerHooked[frame] then
                trackerHooked[frame] = true
                frame:HookScript("OnShow", HideTracker)
                if type(frame.Update) == "function" then
                    hooksecurefunc(frame, "Update", function(self) HideTracker(self) end)
                end
            end
            if hide then
                HideTracker(frame)
            elseif ns.hiddenFrames[frame] then
                wasHidden = true
                ShowTracker(frame)
            end
        end
    end
    if wasHidden then ns.RunOutOfCombat(MouseBack, "showing quest tracker", true) end
end

------------------------------------------------------------------------
-- FPS counter (bottom-right corner, below the bag buttons)
------------------------------------------------------------------------
local fpsFrame
-- green = smooth, amber = playable, red = choppy
local function FpsColor(fps)
    if fps >= 60 then return "green" elseif fps >= 30 then return "amber" end
    return "red"
end

local function UpdateFps()
    local fps = math.floor(GetFramerate() + 0.5)
    local text = ns.Paint(FpsColor(fps), fps) .. " " .. ns.Paint("grey", "fps")
    if GetNetStats then
        local _, _, home, world = GetNetStats()
        local ms = math.max(home or 0, world or 0)
        if ms > 0 then text = text .. "   " .. ms .. " " .. ns.Paint("grey", "ms") end
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

------------------------------------------------------------------------
-- Class colored names in chat
-- The game keeps this per chat type (Chat settings > "Color names"), so the player's own choice is
-- saved in ns.db.chatClassWas before we change it and put back when the option is turned off.
------------------------------------------------------------------------
local CHAT_TYPES = { "SAY", "YELL", "EMOTE", "WHISPER", "WHISPER_INFORM", "PARTY", "PARTY_LEADER", "RAID",
    "RAID_LEADER", "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER", "GUILD", "OFFICER" }
for i = 1, 10 do CHAT_TYPES[#CHAT_TYPES + 1] = "CHANNEL" .. i end

local function SetNameColor(chatType, on)
    local info = _G.ChatTypeInfo[chatType]
    if not info then return end
    info.colorNameByClass = on
    -- stores it like the Chat settings checkbox does, where the client has it
    if _G.SetChatColorNameByClass then ns.Try(_G.SetChatColorNameByClass, chatType, on) end
end

local function ChatClassNames()
    if type(_G.ChatTypeInfo) ~= "table" then return end
    local c = Cfg()
    if c and c.chatClassNames then
        local was = ns.db.chatClassWas
        if not was then
            was = {}
            for _, t in ipairs(CHAT_TYPES) do
                local info = _G.ChatTypeInfo[t]
                if info then was[t] = info.colorNameByClass and true or false end
            end
            ns.db.chatClassWas = was
        end
        for _, t in ipairs(CHAT_TYPES) do SetNameColor(t, true) end
        return
    end
    local was = ns.db.chatClassWas
    if not was then return end
    for t, on in pairs(was) do SetNameColor(t, on) end
    ns.db.chatClassWas = nil
end

-- The saved per-type choice arrives from the game after login and can undo ours: set it again
ns.TryOn("UPDATE_CHAT_COLOR_NAME_BY_CLASS", function(_, chatType, on)
    local c = Cfg()
    if not (c and c.chatClassNames) or on or type(chatType) ~= "string" then return end
    for _, t in ipairs(CHAT_TYPES) do
        if t == chatType then SetNameColor(t, true) return end
    end
end)

------------------------------------------------------------------------
-- Style: square minimap, flat chat input box, Roboto chat font
-- Only unprotected frames (Minimap, chat). Turning an option off puts Blizzard's look back.
------------------------------------------------------------------------
local SQUARE_MASK = "Interface\\ChatFrame\\ChatFrameBackground"
local ROUND_MASK = "Interface\\Masks\\CircleMaskScalable" -- the default mask of the Edit Mode minimap
local CHAT_FONT = "Interface\\AddOns\\MLZ_UI\\Media\\Roboto-Bold.ttf"
local RINGS = { "MinimapCompassTexture", "MinimapCompassTextureUnderlay", "MinimapBorder" }

local squareOn, squareBorder, maskHooked, settingMask = false, nil, false, false

local function SetMask(texture)
    settingMask = true
    pcall(_G.Minimap.SetMaskTexture, _G.Minimap, texture)
    settingMask = false
end

local function RingAlpha(a)
    for _, name in ipairs(RINGS) do
        local t = _G[name]
        if t and t.SetAlpha then t:SetAlpha(a) end
    end
end

-- A square mask can't rotate. Remember the player's setting so it comes back with the round map.
local function KeepRotationOff()
    if GetCVar and GetCVar("rotateMinimap") == "1" then
        if ns.db.minimapRotateWas == nil then ns.db.minimapRotateWas = "1" end
        ns.Try(SetCVar, "rotateMinimap", "0")
    end
end

local function SquareMinimap()
    local map = _G.Minimap
    if not (map and map.SetMaskTexture) then return end
    local c = Cfg()
    if c and c.squareMinimap and not LeatrixMinimap() then
        if not maskHooked then
            maskHooked = true
            -- Blizzard sets the mask again on some updates; keep it square while the option is on
            hooksecurefunc(map, "SetMaskTexture", function()
                if squareOn and not settingMask then SetMask(SQUARE_MASK) end
            end)
        end
        squareOn = true
        SetMask(SQUARE_MASK)
        RingAlpha(0)
        KeepRotationOff()
        if not squareBorder then
            squareBorder = CreateFrame("Frame", nil, map)
            squareBorder:SetPoint("TOPLEFT", -1, 1)
            squareBorder:SetPoint("BOTTOMRIGHT", 1, -1)
            squareBorder:EnableMouse(false)
            ns.W.Border(squareBorder, ns.W.T.border)
        end
        squareBorder:Show()
        -- Minimap button libraries ask this to place icons along the edge
        if not _G.GetMinimapShape then
            _G.GetMinimapShape = function() return squareOn and "SQUARE" or "ROUND" end
        end
        return
    end
    if squareOn then
        squareOn = false
        SetMask(ROUND_MASK)
        RingAlpha(1)
        if squareBorder then squareBorder:Hide() end
    end
    if ns.db.minimapRotateWas then
        ns.Try(SetCVar, "rotateMinimap", ns.db.minimapRotateWas)
        ns.db.minimapRotateWas = nil
    end
end

-- Every chat window, including whisper windows opened later
local function EachChatFrame(fn)
    local list = _G.CHAT_FRAMES
    if type(list) ~= "table" or #list == 0 then
        list = {}
        for i = 1, (NUM_CHAT_WINDOWS or 10) do list[i] = "ChatFrame" .. i end
    end
    for _, name in ipairs(list) do
        local f = _G[name]
        if f then fn(f, name) end
    end
end

local EDIT_ART = { "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }
local flatBoxes = {} -- edit box -> our backdrop

local function FlatChatInput()
    local c = Cfg()
    local on = c and c.flatChatInput
    EachChatFrame(function(_, name)
        local boxName = name .. "EditBox"
        local box = _G[boxName]
        if not box or (not on and not flatBoxes[box]) then return end
        for _, part in ipairs(EDIT_ART) do
            local t = _G[boxName .. part]
            if t and t.SetAlpha then t:SetAlpha(on and 0 or 1) end
        end
        local bg = flatBoxes[box]
        if on and not bg then
            -- A lower frame level puts the backdrop under the box's own text
            bg = CreateFrame("Frame", nil, box)
            bg:SetFrameLevel(math.max(0, box:GetFrameLevel() - 1))
            bg:SetPoint("TOPLEFT", 4, -4)
            bg:SetPoint("BOTTOMRIGHT", -4, 4)
            ns.W.Fill(bg, ns.W.T.input)
            ns.W.Border(bg, ns.W.T.border)
            flatBoxes[box] = bg
        end
        if bg then bg:SetShown(on and true or false) end
    end)
end

local fontChanged = false
local function ChatFont()
    local c = Cfg()
    local on = c and c.chatFont
    if not on and not fontChanged then return end
    local base = _G.ChatFontNormal and _G.ChatFontNormal:GetFont()
    local want = on and CHAT_FONT or base
    if not want then return end
    EachChatFrame(function(f)
        local file, size, flags = f:GetFont()
        if size and file ~= want then f:SetFont(want, size, flags or "") end
    end)
    fontChanged = on and true or false
end

local function Style()
    local wasSquare = squareOn
    pcall(SquareMinimap)
    -- our minimap button sits on the edge, which moved
    if wasSquare ~= squareOn and ns.MinimapButton and ns.MinimapButton.Position then pcall(ns.MinimapButton.Position) end
    pcall(FlatChatInput)
    pcall(ChatFont)
end

-- New whisper windows are made after login: style them too
local chatHooked = false
local function HookNewChatWindows()
    if chatHooked or not _G.FCF_OpenTemporaryWindow then return end
    chatHooked = true
    hooksecurefunc("FCF_OpenTemporaryWindow", function()
        local c = Cfg()
        if c and (c.flatChatInput or c.chatFont) then C_Timer.After(0, Style) end
    end)
end

function Tweaks:Refresh()
    if not Cfg() then return end
    pcall(TrackerHeader)
    pcall(TrackerVisibility)
    pcall(Fps)
    pcall(HookTooltips)
    pcall(ChatClassNames)
    Style()
    pcall(HookNewChatWindows)
end

-- Public API (settings window)
function Tweaks:IsOn(id) return (ns.db.tweaks and ns.db.tweaks[id]) and true or false end

function Tweaks:Set(id, on)
    ns.db.tweaks = ns.db.tweaks or {}
    ns.db.tweaks[id] = on and true or nil
    self:Refresh()
    ns.FireState()
end

ns.AddCommand("fps", "shows or hides the FPS counter in the bottom right", function()
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
    if n then SaveMap(n) elseif ns.Settings then ns.Settings:Open("buttons") end
end)

ns.AddCommand("quests", "hides or shows the whole quest tracker", function()
    Tweaks:Set("trackerHide", not Tweaks:IsOn("trackerHide"))
    ns.Print("Quest tracker:", Tweaks:IsOn("trackerHide") and "hidden" or "shown")
end)

ns.AddCommand("tracker", 'hides or shows the "All Objectives" line in the quest tracker', function()
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
        local why = o.avail and o.avail()
        if why then item.unavailable, item.new, item.enabled = true, why:lower(), false end
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
    -- The saved size is part of our layout; with the player's own layout active, leave the minimap alone
    local ov = ns.db.overrides
    local layout = ns.modules.layout
    if ov and ov.minimapSize and layout then
        local _, ours = layout:ActiveName()
        if ours then PreviewMap(ov.minimapSize) end
    end
end)
