-- MLZ UI: XP per hour
-- Counts the XP you earn since login (or /reload) and works out XP per hour and the time to the next
-- level. Shown on the overview, in the minimap button tooltip and with /mlz xp. Nothing is saved and
-- nothing shows at max level.

local _, ns = ...

local X = {}
ns.XPRate = X

local MIN_SECONDS = 120 -- below this the rate jumps around too much to be useful

local startTime, gained, lastXP, lastMax

local function AtMaxLevel()
    if IsPlayerAtEffectiveMaxLevel then return IsPlayerAtEffectiveMaxLevel() end
    local max = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or MAX_PLAYER_LEVEL
    return max and UnitLevel("player") >= max
end

local function Disabled()
    return AtMaxLevel() or (IsXPUserDisabled and IsXPUserDisabled())
end

local function Reset()
    startTime, gained = GetTime(), 0
    lastXP, lastMax = UnitXP("player"), UnitXPMax("player")
end

ns.On("PLAYER_ENTERING_WORLD", function()
    if not startTime then Reset() end
end)

ns.On("PLAYER_XP_UPDATE", function(_, unit)
    if unit and unit ~= "player" then return end
    if not startTime then Reset() return end
    local xp, max = UnitXP("player"), UnitXPMax("player")
    local delta = xp - lastXP
    -- a level up wraps the bar: the rest of the old level plus what is on the new one
    if delta < 0 then delta = (lastMax - lastXP) + xp end
    gained = gained + math.max(0, delta)
    lastXP, lastMax = xp, max
    ns.FireState()
end)

-- 123456 -> "123k", 12345 -> "12.3k", 950 -> "950"
local function Short(n)
    if n >= 100000 then return ("%.0fk"):format(n / 1000) end
    if n >= 1000 then return ("%.1fk"):format(n / 1000) end
    return tostring(math.floor(n + 0.5))
end

-- 4980 -> "1h 23m", 300 -> "5m"
local function Duration(seconds)
    seconds = math.max(60, math.floor(seconds))
    local h, m = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)
    if h > 0 then return ("%dh %dm"):format(h, m) end
    return ("%dm"):format(m)
end

-- Returns nil at max level. Otherwise a table:
-- { perHour, toLevel (seconds or nil), restedPct, ready (enough data), minutes }
function X.Stats()
    if Disabled() or not startTime then return nil end
    local elapsed = GetTime() - startTime
    local xp, max = UnitXP("player"), UnitXPMax("player")
    local rested = GetXPExhaustion and GetXPExhaustion() or 0
    local s = {
        ready = elapsed >= MIN_SECONDS and gained > 0,
        minutes = math.floor(elapsed / 60),
        restedPct = max > 0 and math.floor((rested or 0) / max * 100 + 0.5) or 0,
    }
    if s.ready then
        s.perHour = gained / elapsed * 3600
        s.toLevel = (max - xp) / s.perHour * 3600
    end
    return s
end

-- One line for the overview and /mlz xp
function X.Text()
    local s = X.Stats()
    if not s then return nil end
    local rested = s.restedPct > 0 and (" Rested " .. s.restedPct .. "% of a level.") or ""
    if not s.ready then
        return "Counting XP since login. Kill a few mobs or turn in a quest." .. rested
    end
    return ("%s XP per hour. Level %d in about %s.%s"):format(Short(s.perHour), UnitLevel("player") + 1,
        Duration(s.toLevel), rested)
end

function X.Badge()
    local s = X.Stats()
    if not (s and s.ready) then return nil end
    return Short(s.perHour) .. "/h"
end

X.Reset = Reset

ns.AddCommand("xp", "shows XP per hour and time to level (/mlz xp reset starts counting again)", function(arg)
    if arg == "reset" then
        Reset()
        ns.FireState()
        ns.Print("XP per hour: counting from now.")
        return
    end
    ns.Print(X.Text() or "You are at max level, so there is no XP to count.")
end)
