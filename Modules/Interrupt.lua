-- MLZ UI: Interrupt announce
-- When you (or your pet) interrupt a spell: "Interrupted <mob>'s <spell>".
-- Where it goes: Off / Self (only you see it) / Say / Group (instance, raid or party chat).
-- Say and Group only post while you are in a group, so nothing is said when you are alone
-- (Say only inside instances: the game blocks addon /say in the open world).
-- Off until you choose a channel in /mlz > Helpers.

local _, ns = ...

local IA = {}
ns.Interrupt = IA

IA.CHANNELS = {
    { value = "off", text = "Off" },
    { value = "self", text = "Self", tip = "Only you see it, in your chat window." },
    { value = "say", text = "Say", tip = "Said out loud, only in dungeons and raids while you are in a group (the game blocks addon /say elsewhere)." },
    { value = "group", text = "Group", tip = "Instance, raid or party chat, whichever you are in." },
}

local function Channel() return ns.db and ns.db.interrupt or "off" end

local function GroupChannel()
    if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

local function Announce(text)
    local ch = Channel()
    if ch == "self" then
        ns.Print(text)
    elseif ch == "say" then
        -- addons may only /say inside instances (the game blocks it outside without a key press)
        if IsInGroup() and IsInInstance() then SendChatMessage(text, "SAY") end
    elseif ch == "group" then
        local g = GroupChannel()
        if g then SendChatMessage(text, g) end
    end
end

-- Two ways to see an interrupt:
-- 1. UNIT_SPELLCAST_INTERRUPTED says who interrupted (interruptedBy, a GUID) on newer engines. WoW Forever closes
--    the combat log to addons, so this is the only way there. It fires for every unit that shows the cast
--    (target, focus, nameplates), so one cast is announced once (castGUID).
-- 2. The combat log, on older clients whose spellcast event has no interruptedBy.
local issecretvalue = issecretvalue
local function Hidden(v) return issecretvalue ~= nil and issecretvalue(v) end

local function SpellText(spellID)
    if Hidden(spellID) or type(spellID) ~= "number" or spellID <= 0 then return "a spell" end
    local link = (C_Spell and C_Spell.GetSpellLink) or GetSpellLink
    if link then
        local ok, text = pcall(link, spellID)
        if ok and type(text) == "string" then return text end
    end
    return ns.SpellName(spellID) or "a spell"
end

local function Mine(guid)
    return guid == UnitGUID("player") or (UnitExists("pet") and guid == UnitGUID("pet"))
end

local lastCast
local function OnInterrupted(unit, castGUID, spellID, interruptedBy)
    if interruptedBy == nil then return end
    -- hidden by the game (some instances): nothing can be said about it
    if Hidden(interruptedBy) or Hidden(castGUID) then
        ns.Debug("interrupt announce: hidden by the game")
        return
    end
    if not Mine(interruptedBy) then return end
    if castGUID and castGUID == lastCast then return end
    lastCast = castGUID
    local name = UnitName(unit)
    if Hidden(name) or not name then name = "?" end
    Announce(("Interrupted %s's %s"):format(name, SpellText(spellID)))
end

-- The combat log path (older clients). Engines with hidden values have a closed combat log.
local bit_band = bit and bit.band
local MINE = COMBATLOG_OBJECT_AFFILIATION_MINE or 0x00000001
local GetEventInfo = CombatLogGetCurrentEventInfo or (C_CombatLog and C_CombatLog.GetCurrentEventInfo)
local useLog = GetEventInfo ~= nil and bit_band ~= nil and issecretvalue == nil

local function OnCombatLog()
    local _, sub, _, sourceGUID, _, sourceFlags, _, _, destName, _, _, _, _, _, extraSpellId, extraSpellName =
        GetEventInfo()
    if sub ~= "SPELL_INTERRUPT" then return end
    -- you, or something you control (your pet)
    if sourceGUID ~= UnitGUID("player") and not (sourceFlags and bit_band(sourceFlags, MINE) ~= 0) then return end
    -- a clickable spell link when the client gives spell IDs (Classic often gives 0), else the name
    local spell = SpellText(extraSpellId)
    if spell == "a spell" and extraSpellName then spell = extraSpellName end
    Announce(("Interrupted %s's %s"):format(destName or "?", spell))
end

-- Own frame instead of ns.On: these events fire constantly, so they are only listened to while the
-- announce is on (the shared event bus can't unregister).
local frame
local function Update()
    local on = Channel() ~= "off"
    if on and not frame then
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", function(_, event, ...)
            local ok, err
            if event == "UNIT_SPELLCAST_INTERRUPTED" then
                -- with interruptedBy the spellcast event covers it, so the combat log is not needed
                if useLog and select(4, ...) ~= nil then
                    useLog = false
                    frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
                end
                ok, err = pcall(OnInterrupted, ...)
            else
                ok, err = pcall(OnCombatLog)
            end
            if not ok then ns.Error("interrupt announce", err) end
        end)
    end
    if not frame then return end
    frame:UnregisterAllEvents()
    if not on then return end
    pcall(frame.RegisterEvent, frame, "UNIT_SPELLCAST_INTERRUPTED")
    if useLog then pcall(frame.RegisterEvent, frame, "COMBAT_LOG_EVENT_UNFILTERED") end
end

ns.On("PLAYER_LOGIN", function() if ns.db then Update() end end)

function IA.Get() return Channel() end
function IA.Set(v)
    local ok = false
    for _, c in ipairs(IA.CHANNELS) do if c.value == v then ok = true end end
    if not ok then return end
    ns.db.interrupt = v ~= "off" and v or nil
    Update()
    ns.FireState()
end
