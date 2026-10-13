-- MLZ UI: Minimalism (fading)
-- Makes Blizzard frames invisible/dimmed until you need them, based on Data/Fade.lua.
-- Only uses SetAlpha (allowed in combat too), never Hide/Show on protected frames, so it causes no taint.
-- Keybinds work even when a bar is invisible.

local _, ns = ...

local Fade = ns.RegisterModule({ key = "fade", title = "Minimalism" })

local MODE_TEXT = { -- also used by the control center (UI/Settings.lua)
    mouseover = "hidden until mouseover",
    combat = "dimmed out of combat",
    hideInCombat = "hidden in combat",
    group = "hidden when solo",
}
Fade.MODE_TEXT = MODE_TEXT

local function Frames(row)
    local list = {}
    for _, name in ipairs(row.frames) do
        local f = _G[name]
        if f and f.SetAlpha then list[#list + 1] = f end
    end
    return list
end

------------------------------------------------------------------------
-- Update loop
------------------------------------------------------------------------
local touched = {} -- frames whose alpha we changed, so we can reset them

local function TargetAlpha(row, hovered, inCombat, hasTarget)
    if row.mode == "group" then
        return (hovered or IsInGroup()) and 1 or 0
    elseif row.mode == "mouseover" then
        return hovered and 1 or 0
    elseif row.mode == "combat" then
        return (inCombat or hasTarget or hovered) and 1 or (row.alpha or 0.3)
    elseif row.mode == "hideInCombat" then
        return (inCombat and not hovered) and 0 or 1
    end
    return 1
end

local function Update()
    local db = ns.db and ns.db.fade
    if not db or ns.fadePaused then return end
    local editMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()
    local inCombat = InCombatLockdown()
    local hasTarget = UnitExists("target")
    for _, row in ipairs(ns.data.fade) do
        if db[row.id] then
            local frames = Frames(row)
            local hovered = false
            for _, f in ipairs(frames) do
                if f:IsVisible() and f:IsMouseOver() then hovered = true break end
            end
            local target = editMode and 1 or TargetAlpha(row, hovered, inCombat, hasTarget)
            for _, f in ipairs(frames) do
                local cur = f:GetAlpha()
                if math.abs(cur - target) > 0.01 then
                    -- smooth transition: takes a few tenths of a second
                    local step = (target > cur) and 0.34 or 0.2
                    local new = cur + math.max(-step, math.min(step, target - cur))
                    f:SetAlpha(new)
                    touched[f] = true
                end
            end
        end
    end
end

local ticker
function Fade:Start()
    if not ticker then ticker = C_Timer.NewTicker(0.1, Update) end
end

function Fade:ResetAlpha()
    for f in pairs(touched) do f:SetAlpha(1) end
    wipe(touched)
end

------------------------------------------------------------------------
-- Chat
------------------------------------------------------------------------
local defaultTabAlpha

function Fade:ApplyChat()
    local cfg = ns.data.chat
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local cf = _G["ChatFrame" .. i]
        if cf then
            if cf.SetFading then cf:SetFading(true) end
            if cf.SetTimeVisible then cf:SetTimeVisible(cfg.fadeAfter) end
            if cfg.hideBackground and FCF_SetWindowAlpha then pcall(FCF_SetWindowAlpha, cf, 0) end
        end
    end
    if cfg.hideTabs then
        defaultTabAlpha = defaultTabAlpha or { CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA, CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA }
        CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA = 0
        CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA = 0
        for i = 1, (NUM_CHAT_WINDOWS or 10) do
            local tab = _G["ChatFrame" .. i .. "Tab"]
            if tab and not tab:IsMouseOver() then tab:SetAlpha(0) end
        end
    end
end

-- Undo ApplyChat. `alphas` = window alpha per chat frame (from a backup); without it Blizzard's default is used.
function Fade:ResetChat(alphas)
    if defaultTabAlpha then
        CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA, CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA = defaultTabAlpha[1], defaultTabAlpha[2]
    end
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local cf = _G["ChatFrame" .. i]
        if cf then
            if cf.SetTimeVisible then cf:SetTimeVisible(120) end
            local alpha = alphas and alphas[i] or (not alphas and (DEFAULT_CHATFRAME_ALPHA or 0.25))
            if alpha and FCF_SetWindowAlpha then pcall(FCF_SetWindowAlpha, cf, alpha) end
        end
    end
end

local function ChatWindowAlphas()
    local t = {}
    if GetChatWindowInfo then
        for i = 1, (NUM_CHAT_WINDOWS or 10) do
            local _, _, _, _, _, alpha = GetChatWindowInfo(i)
            t[i] = alpha
        end
    end
    return t
end

------------------------------------------------------------------------
-- Module interface
------------------------------------------------------------------------
function Fade:Preview()
    local items = {}
    local current = ns.db.fade or {}
    for _, row in ipairs(ns.data.fade) do
        local exists = #Frames(row) > 0
        local isOn = current[row.id] and true or false
        local item = {
            id = row.id, label = row.label, group = "Hide until needed", note = row.desc,
            toggle = true, isOn = isOn, offText = "always visible",
            old = isOn and MODE_TEXT[row.mode] or "always visible",
            new = MODE_TEXT[row.mode] .. (row.alpha and (" (" .. math.floor(row.alpha * 100) .. "%)") or ""),
            enabled = exists and (isOn or ns.Enabled("fade", row.id, row.enabled)),
        }
        if not exists then
            item.unavailable, item.new, item.note = true, "does not exist", "Found none of: " .. table.concat(row.frames, ", ")
        end
        items[#items + 1] = item
    end
    local chatOn = ns.db.chatTweaks and true or false
    items[#items + 1] = {
        id = "__chat", label = "Clean chat", group = "Chat",
        toggle = true, isOn = chatOn, offText = "default",
        old = chatOn and "on" or "default",
        new = ("fades after %ds, hidden tabs and background"):format(ns.data.chat.fadeAfter),
        enabled = chatOn or ns.Enabled("fade", "__chat", true),
        note = "Chat lines disappear after a while (scroll or hover to see them again). Tabs and background only show on mouseover.",
    }
    return items
end

function Fade:Backup()
    return {
        fade = ns.CopyTable(ns.db.fade or {}),
        chatTweaks = ns.db.chatTweaks,
        chatAlpha = ChatWindowAlphas(),
    }
end

-- Only the rows that change come in here: ticked = turn on, unticked = turn off.
-- Everything else in ns.db.fade is left as it is.
function Fade:Apply(items)
    ns.db.fade = ns.db.fade or {}
    for _, item in ipairs(items) do
        if item.id == "__chat" then
            local wasOn = ns.db.chatTweaks
            ns.db.chatTweaks = item.enabled and true or false
            if ns.db.chatTweaks then self:ApplyChat() elseif wasOn then self:ResetChat() end
        else
            ns.db.fade[item.id] = item.enabled or nil
        end
    end
    self:ResetAlpha()
    if next(ns.db.fade) then self:Start() end
end

function Fade:Restore(snap)
    ns.db.fade = snap.fade or {}
    ns.db.chatTweaks = snap.chatTweaks
    self:ResetAlpha()
    if snap.chatTweaks then self:ApplyChat() else self:ResetChat(snap.chatAlpha or {}) end
end

------------------------------------------------------------------------
-- On login
------------------------------------------------------------------------
ns.On("PLAYER_ENTERING_WORLD", function()
    if ns.db.chatTweaks then Fade:ApplyChat() end
    if ns.db.fade and next(ns.db.fade) then Fade:Start() end
end)

------------------------------------------------------------------------
-- Public API (settings window, minimap menu)
------------------------------------------------------------------------
function Fade:Exists(row) return #Frames(row) > 0 end

function Fade:IsOn(id) return (ns.db.fade and ns.db.fade[id]) and true or false end

function Fade:SetRow(id, on)
    ns.db.fade = ns.db.fade or {}
    ns.db.fade[id] = on and true or nil
    self:ResetAlpha()
    if next(ns.db.fade) then self:Start() end
    ns.FireState()
end

function Fade:SetPaused(paused)
    paused = paused and true or false
    if (ns.fadePaused and true or false) == paused then return end
    ns.fadePaused = paused
    if paused then self:ResetAlpha() else self:Start() end
    ns.FireState()
end

function Fade:SetChat(on)
    local was = ns.db.chatTweaks
    ns.db.chatTweaks = on and true or false
    if on then self:ApplyChat() elseif was then self:ResetChat() end
    ns.FireState()
end

-- Returns how many rows are on, and how many exist in this client
function Fade:CountOn()
    local on, total = 0, 0
    for _, row in ipairs(ns.data.fade) do
        if #Frames(row) > 0 then
            total = total + 1
            if self:IsOn(row.id) then on = on + 1 end
        end
    end
    return on, total
end

ns.AddCommand("fade", "temporarily toggles all fading on/off (until next /reload)", function()
    Fade:SetPaused(not ns.fadePaused)
    ns.Print(ns.fadePaused and "Fading paused until you reload or turn it back on." or "Fading on.")
end)
