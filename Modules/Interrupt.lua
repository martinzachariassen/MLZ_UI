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

local bit_band = bit.band
local MINE = COMBATLOG_OBJECT_AFFILIATION_MINE or 0x00000001

local function OnCombatLog()
    local _, sub, _, sourceGUID, _, sourceFlags, _, _, destName, _, _, _, _, _, extraSpellId, extraSpellName =
        CombatLogGetCurrentEventInfo()
    if sub ~= "SPELL_INTERRUPT" then return end
    -- you, or something you control (your pet)
    if sourceGUID ~= UnitGUID("player") and not (sourceFlags and bit_band(sourceFlags, MINE) ~= 0) then return end
    -- a clickable spell link when the client gives spell IDs (Classic often gives 0), else the name
    local spell = extraSpellName or "a spell"
    if GetSpellLink and type(extraSpellId) == "number" and extraSpellId > 0 then
        local ok, link = pcall(GetSpellLink, extraSpellId)
        if ok and link then spell = link end
    end
    Announce(("Interrupted %s's %s"):format(destName or "?", spell))
end

local registered = false
local function Update()
    local on = Channel() ~= "off"
    if on and not registered and CombatLogGetCurrentEventInfo then
        registered = ns.TryOn("COMBAT_LOG_EVENT_UNFILTERED", function()
            if Channel() ~= "off" then OnCombatLog() end
        end)
    end
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
