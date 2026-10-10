-- MLZ UI: Minimalisme (fading)
-- Gjør Blizzard-frames usynlige/dempede til du trenger dem, ut fra Data/Fade.lua.
-- Bruker bare SetAlpha (lov også i kamp), aldri Hide/Show på beskyttede frames, så det gir ikke taint.
-- Keybinds virker selv om en bar er usynlig.

local _, ns = ...

local Fade = ns.RegisterModule({ key = "fade", title = "Minimalisme" })

local MODE_TEXT = {
    mouseover = "skjult til mouseover",
    combat = "dempet utenfor kamp",
    hideInCombat = "skjult i kamp",
}

local function Frames(row)
    local list = {}
    for _, name in ipairs(row.frames) do
        local f = _G[name]
        if f and f.SetAlpha then list[#list + 1] = f end
    end
    return list
end

------------------------------------------------------------------------
-- Oppdateringsløkke
------------------------------------------------------------------------
local touched = {} -- frames vi har endret alpha på, så vi kan sette dem tilbake

local function TargetAlpha(row, hovered, inCombat, hasTarget)
    if row.mode == "mouseover" then
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
                    -- myk overgang: tar noen tiendedels sekunder
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
-- Modulgrensesnitt
------------------------------------------------------------------------
function Fade:Preview()
    local items = {}
    local current = ns.db.fade or {}
    for _, row in ipairs(ns.data.fade) do
        local exists = #Frames(row) > 0
        local item = {
            id = row.id, label = row.label, group = "Skjul til du trenger det", note = row.desc,
            old = current[row.id] and MODE_TEXT[row.mode] or "alltid synlig",
            new = MODE_TEXT[row.mode] .. (row.alpha and (" (" .. math.floor(row.alpha * 100) .. "%)") or ""),
            enabled = exists and ns.Enabled("fade", row.id, row.enabled),
        }
        if not exists then
            item.unavailable, item.new, item.note = true, "finnes ikke", "Fant ingen av: " .. table.concat(row.frames, ", ")
        end
        items[#items + 1] = item
    end
    items[#items + 1] = {
        id = "__chat", label = "Ren chat", group = "Chat",
        old = ns.db.chatTweaks and "på" or "standard",
        new = ("fader etter %ds, skjulte faner og bakgrunn"):format(ns.data.chat.fadeAfter),
        enabled = ns.Enabled("fade", "__chat", true),
        note = "Chat-linjer forsvinner etter litt tid (scroll eller hold musen over for å se dem igjen). Faner og bakgrunn vises bare ved mouseover.",
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

function Fade:Apply(items)
    ns.db.fade = {}
    ns.db.chatTweaks = false
    for _, item in ipairs(items) do
        if item.id == "__chat" then
            ns.db.chatTweaks = true
        else
            ns.db.fade[item.id] = true
        end
    end
    self:ResetAlpha()
    if ns.db.chatTweaks then self:ApplyChat() end
    self:Start()
end

function Fade:Restore(snap)
    ns.db.fade = snap.fade or {}
    ns.db.chatTweaks = snap.chatTweaks
    self:ResetAlpha()
    if not snap.chatTweaks then
        if defaultTabAlpha then
            CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA, CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA = defaultTabAlpha[1], defaultTabAlpha[2]
        end
        for i, alpha in pairs(snap.chatAlpha or {}) do
            local cf = _G["ChatFrame" .. i]
            if cf and FCF_SetWindowAlpha then pcall(FCF_SetWindowAlpha, cf, alpha) end
        end
    end
end

------------------------------------------------------------------------
-- Ved login
------------------------------------------------------------------------
ns.On("PLAYER_ENTERING_WORLD", function()
    if ns.db.chatTweaks then Fade:ApplyChat() end
    if ns.db.fade and next(ns.db.fade) then Fade:Start() end
end)

ns.AddCommand("fade", "slår all fading av/på midlertidig (til neste /reload)", function()
    ns.fadePaused = not ns.fadePaused
    if ns.fadePaused then
        Fade:ResetAlpha()
        ns.Print("Fading av. Skriv /mlz fade igjen for å slå på.")
    else
        Fade:Start()
        ns.Print("Fading på.")
    end
end)
