-- MLZ UI: Group and raid helpers
-- Buff check on ready check: one line in your own chat with who misses a buff you can cast
-- (or every class buff when you lead). Nothing is sent to the group.
-- Pull timer: /mlz pull [seconds] or a key in Key Bindings > AddOns > MLZ UI. Uses the game's own
-- countdown when the client has it, otherwise Deadly Boss Mods. Settings: /mlz > Helpers.

local _, ns = ...

local G = {}
ns.Group = G

local DEFAULTS = { buffCheck = false, leaderAll = false }

local function Cfg()
    ns.db.group = ns.db.group or {}
    local c = ns.db.group
    for k, v in pairs(DEFAULTS) do if c[k] == nil then c[k] = v end end
    return c
end

-- Shown in Key Bindings and on the keybind map (these names are read by the game)
BINDING_HEADER_MLZUI = "MLZ UI"
BINDING_NAME_MLZUI_PULL = "Pull timer (10 seconds)"

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id))
end

local function Knows(id)
    if IsSpellKnown and IsSpellKnown(id) then return true end
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    return false
end

------------------------------------------------------------------------
-- Buff check
------------------------------------------------------------------------
local function GroupUnits()
    local units = {}
    if IsInRaid() then
        for i = 1, 40 do units[#units + 1] = "raid" .. i end
    else
        units[1] = "player"
        for i = 1, 4 do units[#units + 1] = "party" .. i end
    end
    return units
end

local function UnitBuffNames(unit)
    local names = {}
    for i = 1, 40 do
        local name
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
            name = aura and aura.name
        elseif UnitBuff then
            name = UnitBuff(unit, i)
        end
        if not name then break end
        names[name] = true
    end
    return names
end

local function Usable(unit)
    if not UnitExists(unit) or UnitIsDeadOrGhost(unit) then return false end
    if UnitIsConnected and not UnitIsConnected(unit) then return false end
    return true
end

-- For each group buff: who in the group could cast it, and who misses it
local function Check(onlyMine)
    local data = (ns.data.reminders or {}).groupBuffs or {}
    local units = GroupUnits()
    local classesHere, members = {}, {}
    for _, unit in ipairs(units) do
        if Usable(unit) then
            local _, class = UnitClass(unit)
            if class then
                classesHere[class] = true
                members[#members + 1] = { unit = unit, class = class, name = UnitName(unit), buffs = UnitBuffNames(unit) }
            end
        end
    end
    local _, myClass = UnitClass("player")
    local out = {}
    for _, b in ipairs(data) do
        local mine = b.class == myClass and Knows(b.spells[1])
        if (onlyMine and mine) or (not onlyMine and classesHere[b.class]) then
            local names = {}
            for _, id in ipairs(b.spells) do local n = SpellName(id) if n then names[n] = true end end
            for _, id in ipairs(b.also or {}) do local n = SpellName(id) if n then names[n] = true end end
            local missing = {}
            for _, m in ipairs(members) do
                if not (b.skip and b.skip[m.class]) then
                    local has = false
                    for n in pairs(names) do if m.buffs[n] then has = true break end end
                    if not has then missing[#missing + 1] = m.name end
                end
            end
            if #missing > 0 then out[#out + 1] = { label = b.label, missing = missing } end
        end
    end
    return out
end

local function Names(list)
    local shown = {}
    for i = 1, math.min(#list, 4) do shown[i] = list[i] end
    local text = table.concat(shown, ", ")
    if #list > 4 then text = text .. (" (+%d)"):format(#list - 4) end
    return text
end

local function IsLeader()
    if UnitIsGroupLeader and UnitIsGroupLeader("player") then return true end
    return IsInRaid() and UnitIsGroupAssistant and UnitIsGroupAssistant("player") or false
end

function G.BuffCheck(force)
    if not IsInGroup() then
        if force then ns.Print("Not in a group.") end
        return
    end
    local cfg = Cfg()
    local all = cfg.leaderAll and IsLeader()
    local list = Check(not all)
    if #list == 0 then
        if force then ns.Print("Buff check: nobody is missing a buff.") end
        return
    end
    local parts = {}
    for _, e in ipairs(list) do
        parts[#parts + 1] = ns.Paint("amber", e.label) .. " missing on " .. Names(e.missing)
    end
    ns.Print("Buff check: " .. table.concat(parts, ". ") .. ".")
end

ns.TryOn("READY_CHECK", function()
    if not (ns.db and Cfg().buffCheck) then return end
    G.BuffCheck(false)
end)

ns.AddCommand("buffs", "lists who in your group misses a buff you can cast", function() G.BuffCheck(true) end)

------------------------------------------------------------------------
-- Pull timer
------------------------------------------------------------------------
local function DbmPull()
    local cmd = SlashCmdList and SlashCmdList["DEADLYBOSSMODS"]
    if ns.IsAddOnLoaded("DBM-Core") and cmd then return cmd end
end

-- Returns nil when a pull timer can be started, else the reason
function G.PullUnavailable()
    if C_PartyInfo and C_PartyInfo.DoCountdown then return nil end
    if DbmPull() then return nil end
    return "Needs Deadly Boss Mods on this client"
end

function G.Pull(seconds)
    seconds = math.floor(tonumber(seconds) or 10)
    if seconds < 1 or seconds > 60 then seconds = 10 end
    -- In a raid the countdown (and DBM's) is ignored without lead or assist, with no message
    if IsInRaid and IsInRaid() and not (UnitIsGroupLeader and UnitIsGroupLeader("player"))
        and not (UnitIsGroupAssistant and UnitIsGroupAssistant("player")) then
        ns.Print("A pull timer in a raid needs raid lead or assist.")
        return false
    end
    if C_PartyInfo and C_PartyInfo.DoCountdown then
        C_PartyInfo.DoCountdown(seconds)
        return true
    end
    local dbm = DbmPull()
    if dbm then
        dbm("pull " .. seconds)
        return true
    end
    ns.Print(G.PullUnavailable() .. ".")
    return false
end

ns.AddCommand("pull", "starts a pull timer: /mlz pull 10", function(arg) G.Pull(arg) end)

------------------------------------------------------------------------
-- Public API (settings window)
------------------------------------------------------------------------
function G.Get(key) return Cfg()[key] and true or false end
function G.Set(key, on)
    Cfg()[key] = on and true or false
    ns.FireState()
end
