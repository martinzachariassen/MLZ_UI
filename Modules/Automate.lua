-- MLZ UI: Fewer clicks
-- Optional automations for the popups you always answer the same way: accept and turn in quests,
-- accept summons and resurrections, confirm bind-on-pickup loot when solo, decline duels.
-- Everything is off until you turn it on in /mlz > Helpers. Hold SHIFT to skip once.
-- Each option steps aside when Leatrix Plus already does the same thing.

local _, ns = ...

local A = {}
ns.Automate = A

local DEFAULTS = { acceptQuests = false, turnInQuests = false, summon = false, resurrect = false,
    bopSolo = false, declineDuels = false }

local function Cfg()
    ns.db.automate = ns.db.automate or {}
    local c = ns.db.automate
    for k, v in pairs(DEFAULTS) do if c[k] == nil then c[k] = v end end
    return c
end

-- Leatrix Plus keys that cover the same job
local LEATRIX = {
    acceptQuests = "AutomateQuests",
    turnInQuests = "AutomateQuests",
    summon = "AutoAcceptSummon",
    resurrect = "AutoAcceptRes",
    declineDuels = "NoDuelRequests",
}

local function LeatrixDoes(key)
    local lkey = LEATRIX[key]
    if not lkey or not ns.IsAddOnLoaded("Leatrix_Plus") then return false end
    local db = _G.LeaPlusDB
    return type(db) == "table" and db[lkey] == "On"
end

-- On, not skipped with SHIFT, and not already handled by Leatrix Plus
local function Want(key)
    if not ns.db then return false end
    if IsShiftKeyDown() then return false end
    return Cfg()[key] and not LeatrixDoes(key)
end

local function HidePopup(which)
    if StaticPopup_Hide then pcall(StaticPopup_Hide, which) end
end

local Gossip = C_GossipInfo or {}

------------------------------------------------------------------------
-- Quests
------------------------------------------------------------------------
-- Only quests from an NPC in front of you. Quests shared by players (escorts included) and quests
-- started from an item are left to you.
local function FromNpc()
    return UnitExists("npc") and not (UnitIsPlayer and UnitIsPlayer("npc"))
end

ns.TryOn("QUEST_DETAIL", function()
    if not Want("acceptQuests") or not FromNpc() then return end
    if QuestGetAutoAccept and QuestGetAutoAccept() then return end -- the game already took it
    if AcceptQuest then AcceptQuest() end
end)

ns.TryOn("QUEST_PROGRESS", function()
    if not Want("turnInQuests") then return end
    -- Quests that cost gold are never handed in for you
    if GetQuestMoneyToGet and (GetQuestMoneyToGet() or 0) > 0 then return end
    if IsQuestCompletable and IsQuestCompletable() and CompleteQuest then CompleteQuest() end
end)

ns.TryOn("QUEST_COMPLETE", function()
    if not Want("turnInQuests") then return end
    local choices = GetNumQuestChoices and GetNumQuestChoices() or 0
    if choices > 1 then return end -- you pick the reward
    if GetQuestReward then GetQuestReward(choices) end
end)

-- The same quest is never picked twice in a row within a few seconds. If the game refuses it
-- (full quest log), the NPC window would otherwise open the quest again and again.
local lastPick, lastPickAt = nil, 0
local function MayPick(id)
    local now = GetTime()
    if id == lastPick and now - lastPickAt < 3 then return false end
    lastPick, lastPickAt = id, now
    return true
end

-- Gossip NPCs: pick a finished quest first, then a new one (grey quests are skipped)
ns.TryOn("GOSSIP_SHOW", function()
    if not ns.db or IsShiftKeyDown() then return end
    if Want("turnInQuests") and Gossip.GetActiveQuests and Gossip.SelectActiveQuest then
        for _, q in ipairs(Gossip.GetActiveQuests() or {}) do
            if q.isComplete and MayPick("a" .. tostring(q.questID)) then
                Gossip.SelectActiveQuest(q.questID)
                return
            end
        end
    end
    if Want("acceptQuests") and Gossip.GetAvailableQuests and Gossip.SelectAvailableQuest then
        for _, q in ipairs(Gossip.GetAvailableQuests() or {}) do
            if not q.isTrivial and MayPick("n" .. tostring(q.questID)) then
                Gossip.SelectAvailableQuest(q.questID)
                return
            end
        end
    end
end)

-- Quest givers with a plain list of quests (no gossip)
ns.TryOn("QUEST_GREETING", function()
    if not ns.db or IsShiftKeyDown() then return end
    if Want("turnInQuests") and GetNumActiveQuests and GetActiveTitle and SelectActiveQuest then
        for i = 1, GetNumActiveQuests() do
            local title, done = GetActiveTitle(i)
            if done and MayPick("a" .. tostring(title)) then SelectActiveQuest(i) return end
        end
    end
    if Want("acceptQuests") and GetNumAvailableQuests and SelectAvailableQuest and GetNumAvailableQuests() > 0 then
        local title = GetAvailableTitle and GetAvailableTitle(1)
        if MayPick("n" .. tostring(title)) then SelectAvailableQuest(1) end
    end
end)

------------------------------------------------------------------------
-- Summons and resurrections
------------------------------------------------------------------------
local Summon = C_SummonInfo or {}
local ConfirmSummonFn = Summon.ConfirmSummon or ConfirmSummon
local SummonTimeLeft = Summon.GetSummonConfirmTimeLeft or GetSummonConfirmTimeLeft
local SummonerName = Summon.GetSummonConfirmSummoner or GetSummonConfirmSummoner

ns.TryOn("CONFIRM_SUMMON", function()
    if not Want("summon") or not ConfirmSummonFn then return end
    -- A short wait so the summon popup is up, and so you can still see who it was
    C_Timer.After(1, function()
        if InCombatLockdown() or UnitAffectingCombat("player") then return end
        if SummonTimeLeft and (SummonTimeLeft() or 0) <= 0 then return end
        local who = SummonerName and SummonerName()
        ConfirmSummonFn()
        HidePopup("CONFIRM_SUMMON")
        ns.Print("Accepted the summon" .. (who and (" from " .. who) or "") .. ".")
    end)
end)

ns.TryOn("RESURRECT_REQUEST", function(_, name)
    if not Want("resurrect") or not AcceptResurrect then return end
    -- Accepting while the caster is still fighting can put you back in the fight
    if name and UnitAffectingCombat then
        local ok, fighting = pcall(UnitAffectingCombat, name)
        if ok and fighting then return end
    end
    AcceptResurrect()
    HidePopup("RESURRECT")
    HidePopup("RESURRECT_NO_SICKNESS")
    HidePopup("RESURRECT_NO_TIMER")
    ns.Print("Accepted the resurrection" .. (name and (" from " .. name) or "") .. ".")
end)

------------------------------------------------------------------------
-- Loot and duels
------------------------------------------------------------------------
ns.TryOn("LOOT_BIND_CONFIRM", function(_, slot)
    if not Want("bopSolo") or IsInGroup() or not ConfirmLootSlot or not slot then return end
    ConfirmLootSlot(slot)
    HidePopup("LOOT_BIND")
end)

ns.TryOn("DUEL_REQUESTED", function(_, name)
    if not Want("declineDuels") or not CancelDuel then return end
    CancelDuel()
    HidePopup("DUEL_REQUESTED")
    ns.Debug("declined a duel from", name)
end)

------------------------------------------------------------------------
-- Public API (settings window)
------------------------------------------------------------------------
function A.Get(key) return Cfg()[key] and true or false end
function A.Set(key, on)
    Cfg()[key] = on and true or false
    ns.FireState()
end
function A.LeatrixDoes(key) return LeatrixDoes(key) end

-- Names of the options that are on, for the overview
function A.OnNames()
    local names = {}
    local short = { acceptQuests = "accept quests", turnInQuests = "turn in quests", summon = "accept summons",
        resurrect = "accept res", bopSolo = "BoP loot", declineDuels = "decline duels" }
    for _, k in ipairs({ "acceptQuests", "turnInQuests", "summon", "resurrect", "bopSolo", "declineDuels" }) do
        if A.Get(k) then names[#names + 1] = short[k] end
    end
    return names
end
