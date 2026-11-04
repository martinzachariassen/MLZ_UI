-- MLZ UI: MLZ nameplates (our own engine)
-- Flat, calm nameplates drawn on our own frames: health bar, name, level when it matters, a cast bar
-- with spell icon, time left and who the spell is aimed at, quest marker, raid marker, your own debuffs,
-- crowd control from anyone, an execute range strip, a mouseover edge and threat colors per role.
-- Modules/Nameplates.lua decides the mode and calls Plates.Configure; this file only draws.
-- Values: Data/Nameplates.lua.
--
-- Taint safety: Blizzard's own plate (nameplate.UnitFrame) is only made invisible with SetAlpha(0)
-- and shown again with SetAlpha(1). We never Hide, move or reparent it. Our frame is a child of the
-- nameplate. Forbidden plates (for example friendly plates in instances) are left alone.
-- When the Platynator engine is picked, nothing here is registered and Blizzard's plates come back.

local _, ns = ...

local Plates = {}
ns.Plates = Plates

local GetTime, UnitExists, UnitIsUnit = GetTime, UnitExists, UnitIsUnit
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local pairs, ipairs, math = pairs, ipairs, math

local TEX = "Interface\\Buttons\\WHITE8X8"
-- Plate colors: a dark 1px edge so bars read on any background, the rest comes from the theme (W.T)
local EDGE = { 0, 0, 0, 0.9 }
local BG_ALPHA = 0.85

local function Theme(key, fallback)
    local T = ns.W and ns.W.T
    return T and T[key] or fallback
end

local function D() return ns.data.nameplates.plates end
local function C() return ns.data.nameplates.plates.colors end

local active = false
local lastError
local cfg = {
    mode = "solo", pvp = false, threat = false, friends = true, size = 1,
    show = { healthText = true, castBar = true, quest = true, debuffs = true, level = true, execute = true, cc = true },
}

local frames = {}    -- [nameplate] = our frame (kept for reuse)
local byUnit = {}    -- [unit token] = our frame while the unit is shown
local casting = {}   -- [our frame] = true while a cast bar runs
local hidden = setmetatable({}, { __mode = "k" }) -- Blizzard UnitFrames we made invisible
local hooked = setmetatable({}, { __mode = "k" })
local questCache = {} -- [guid] = true/false
local execPct        -- health fraction where your execute spell works, nil if your class has none or doesn't know it
local ccNames        -- [spell name] = true for crowd control worth showing (built on first use, every rank matches)
local held = {}      -- [our frame] = true while an interrupted cast is still shown
local hover          -- our frame under the mouse, if any
local warned = {}    -- [our frame] = true once the threat sound played for this mob (reset below threatWarnAt)
local Wake -- starts the OnUpdate (cast bars, debuff timers); set once the event frame exists

------------------------------------------------------------------------
-- Feature detection
------------------------------------------------------------------------
local function PlateForUnit(unit)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit, issecure and issecure() or false)
    if not ok or not plate then return nil end
    if plate.IsForbidden and plate:IsForbidden() then return nil end
    return plate
end

function Plates.Available()
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
        return false, "This client has no nameplate API"
    end
    return true
end

------------------------------------------------------------------------
-- Blizzard's plate: alpha only
------------------------------------------------------------------------
local guard = false
local function HideBlizzard(plate)
    local uf = plate.UnitFrame
    if not uf or (uf.IsForbidden and uf:IsForbidden()) then return end
    hidden[uf] = true
    if not hooked[uf] then
        hooked[uf] = true
        -- if Blizzard code ever sets the alpha back, keep it at 0 while we own the plate
        hooksecurefunc(uf, "SetAlpha", function(self, a)
            if guard or not hidden[self] or not a or a <= 0 then return end
            guard = true
            self:SetAlpha(0)
            guard = false
        end)
    end
    guard = true
    uf:SetAlpha(0)
    guard = false
end

local function ShowBlizzard(plate)
    local uf = plate and plate.UnitFrame
    if not uf or not hidden[uf] then return end
    hidden[uf] = nil
    if not (uf.IsForbidden and uf:IsForbidden()) then uf:SetAlpha(1) end
end

------------------------------------------------------------------------
-- Building our frame
------------------------------------------------------------------------
-- Roboto Bold (the MLZ UI font) reads cleaner than the game font at small sizes. When the file can't
-- be loaded the font string has no font (GetFont returns nil), then the game font is used.
local function Font(fs, size)
    local path = ns.W and ns.W.FONT
    if path then fs:SetFont(path, size, "OUTLINE") end
    if not (path and fs:GetFont()) then
        fs:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
    end
    fs:SetShadowOffset(0, 0)
end

-- A 1px dark edge behind a texture, so it reads on any background
local function Edge(owner, target, layer)
    local e = owner:CreateTexture(nil, layer or "BACKGROUND", nil, -2)
    e:SetTexture(TEX)
    e:SetPoint("TOPLEFT", target, "TOPLEFT", -1, 1)
    e:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 1, -1)
    e:SetVertexColor(unpack(EDGE))
    return e
end

local function Accent()
    local T = ns.W and ns.W.T
    return T and T.accent or C().cast
end

local function MakeBar(parent, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetHeight(height)
    bar:SetStatusBarTexture(TEX)
    bar:SetMinMaxValues(0, 1)
    bar.edge = bar:CreateTexture(nil, "BACKGROUND", nil, -2)
    bar.edge:SetTexture(TEX)
    bar.edge:SetPoint("TOPLEFT", -1, 1)
    bar.edge:SetPoint("BOTTOMRIGHT", 1, -1)
    bar.edge:SetVertexColor(unpack(EDGE))
    bar.bg = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
    bar.bg:SetTexture(TEX)
    bar.bg:SetAllPoints()
    local bg = Theme("input", { 0.06, 0.07, 0.085 })
    bar.bg:SetVertexColor(bg[1], bg[2], bg[3], BG_ALPHA)
    return bar
end

local function MakeAura(parent)
    local s = D().iconSize
    local a = CreateFrame("Frame", nil, parent)
    a:SetSize(s, s * 0.75)
    a.edge = a:CreateTexture(nil, "BACKGROUND")
    a.edge:SetTexture(TEX)
    a.edge:SetPoint("TOPLEFT", -1, 1)
    a.edge:SetPoint("BOTTOMRIGHT", 1, -1)
    a.edge:SetVertexColor(unpack(EDGE))
    a.icon = a:CreateTexture(nil, "ARTWORK")
    a.icon:SetAllPoints()
    a.icon:SetTexCoord(0.08, 0.92, 0.2, 0.8)
    a.time = a:CreateFontString(nil, "OVERLAY")
    Font(a.time, 10)
    a.time:SetPoint("CENTER", a, "BOTTOM", 0, 1)
    a.count = a:CreateFontString(nil, "OVERLAY")
    Font(a.count, 10)
    a.count:SetPoint("TOPRIGHT", 2, 2)
    a:Hide()
    return a
end

local function Build(plate)
    local d = D()
    local f = CreateFrame("Frame", nil, plate)
    f:SetSize(d.width, d.height)
    f:SetPoint("CENTER", plate, "CENTER", 0, 0)
    f:EnableMouse(false)
    f.plate = plate

    f.health = MakeBar(f, d.height)
    f.health:SetAllPoints()
    f.healthText = f.health:CreateFontString(nil, "OVERLAY")
    Font(f.healthText, d.textSize)
    f.healthText:SetPoint("RIGHT", -4, 0)
    -- your threat in % (DPS, healer, solo in combat), left inside the bar, opposite the health
    f.threatText = f.health:CreateFontString(nil, "OVERLAY")
    Font(f.threatText, d.textSize)
    f.threatText:SetPoint("LEFT", 4, 0)
    f.threatText:Hide()

    -- target: accent edge plus a 3px strip on the left
    f.strip = f:CreateTexture(nil, "ARTWORK")
    f.strip:SetTexture(TEX)
    f.strip:SetWidth(3)
    f.strip:SetPoint("TOPRIGHT", f.health, "TOPLEFT", -3, 1)
    f.strip:SetPoint("BOTTOMRIGHT", f.health, "BOTTOMLEFT", -3, -1)
    f.strip:Hide()

    -- execute range: an amber strip on the right, mirroring the target strip
    f.exec = f:CreateTexture(nil, "ARTWORK")
    f.exec:SetTexture(TEX)
    f.exec:SetWidth(3)
    f.exec:SetPoint("TOPLEFT", f.health, "TOPRIGHT", 3, 1)
    f.exec:SetPoint("BOTTOMLEFT", f.health, "BOTTOMRIGHT", 3, -1)
    local amber = Theme("amber", { 1, 0.69, 0.25 })
    f.exec:SetVertexColor(amber[1], amber[2], amber[3])
    f.exec:Hide()

    f.name = f:CreateFontString(nil, "OVERLAY")
    Font(f.name, d.nameSize)
    f.name:SetPoint("BOTTOM", f.health, "TOP", 0, 4)
    f.name:SetWordWrap(false)
    f.name:SetWidth(d.width + 40)

    f.quest = f:CreateFontString(nil, "OVERLAY")
    Font(f.quest, d.nameSize + 3)
    f.quest:SetText("!")
    f.quest:SetTextColor(unpack(C().quest))
    f.quest:SetPoint("LEFT", f.health, "RIGHT", 8, 0)
    f.quest:Hide()

    f.raid = f:CreateTexture(nil, "OVERLAY")
    f.raid:SetSize(16, 16)
    f.raid:SetPoint("RIGHT", f.health, "LEFT", -8, 0)
    f.raid:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    f.raid:Hide()

    -- cast bar: square spell icon on the left, spell name, time left on the right and, under the bar,
    -- who the spell is aimed at. Everything hangs off the bar, so hiding the bar hides it all.
    f.cast = MakeBar(f, d.castHeight)
    f.cast:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", d.castHeight + 3, -3)
    f.cast:SetPoint("TOPRIGHT", f.health, "BOTTOMRIGHT", 0, -3)
    f.castIcon = f.cast:CreateTexture(nil, "ARTWORK")
    f.castIcon:SetSize(d.castHeight, d.castHeight)
    f.castIcon:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, -3)
    f.castIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.castIcon.edge = Edge(f.cast, f.castIcon)
    f.castTime = f.cast:CreateFontString(nil, "OVERLAY")
    Font(f.castTime, d.textSize)
    f.castTime:SetPoint("RIGHT", -4, 0)
    f.castTime:SetJustifyH("RIGHT")
    f.castText = f.cast:CreateFontString(nil, "OVERLAY")
    Font(f.castText, d.textSize)
    f.castText:SetPoint("LEFT", 4, 0)
    f.castText:SetPoint("RIGHT", f.castTime, "LEFT", -4, 0)
    f.castText:SetJustifyH("LEFT")
    f.castText:SetWordWrap(false)
    f.castTarget = f.cast:CreateFontString(nil, "OVERLAY")
    Font(f.castTarget, d.textSize)
    f.castTarget:SetPoint("TOPRIGHT", f.cast, "BOTTOMRIGHT", 0, -3)
    f.castTarget:SetJustifyH("RIGHT")
    f.castTarget:SetWordWrap(false)
    f.cast:Hide()

    f.auras = {}
    for i = 1, d.debuffLimit do
        local a = MakeAura(f)
        if i == 1 then
            a:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", 0, d.nameSize + 9)
        else
            a:SetPoint("LEFT", f.auras[i - 1], "RIGHT", 3, 0)
        end
        f.auras[i] = a
    end

    -- crowd control from anyone, left of the raid mark, so nobody breaks it
    f.cc = MakeAura(f)
    f.cc:SetSize(d.iconSize, d.iconSize)
    f.cc.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.cc:SetPoint("RIGHT", f.health, "LEFT", -28, 0)

    f:Hide()
    frames[plate] = f
    return f
end

------------------------------------------------------------------------
-- Unit facts
------------------------------------------------------------------------
local function IsFriendly(unit)
    return UnitIsFriend and UnitIsFriend("player", unit) and not (UnitCanAttack and UnitCanAttack("player", unit))
end

local function ClassColor(unit)
    local _, class = UnitClass(unit)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return { c.r, c.g, c.b } end
end

local function InGroupUnit(unit)
    if UnitIsUnit(unit, "player") or UnitIsUnit(unit, "pet") then return true end
    if UnitPlayerOrPetInParty and UnitPlayerOrPetInParty(unit) then return true end
    if UnitPlayerOrPetInRaid and UnitPlayerOrPetInRaid(unit) then return true end
    return false
end

-- Threat values can be secret in combat on newer clients; a secret number is treated as unknown
local issecretvalue = issecretvalue
local function Num(v)
    if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
    return v
end

local function InGroup()
    return IsInGroup and IsInGroup() and true or false
end

-- Your threat on a mob: status (0-3) and percent of what pulls aggro (nil when the client doesn't say)
local function ThreatOf(unit)
    if UnitDetailedThreatSituation then
        local tanking, status, pct = UnitDetailedThreatSituation("player", unit)
        status, pct = Num(status), Num(pct)
        if Num(tanking) == true then status = 3 end
        return status, pct
    end
    if UnitThreatSituation then return Num(UnitThreatSituation("player", unit)), nil end
end

-- Threat matters to non-tanks only in combat and outside PvP
local function ThreatRule(unit)
    if not cfg.threat or cfg.pvp then return nil end
    local rule = ns.data.nameplates.threat[cfg.mode]
    if not rule or (rule.tanksOnly and cfg.mode ~= "tank") then return nil end
    if UnitAffectingCombat and not UnitAffectingCombat(unit) then return nil end
    return rule
end

local function ThreatColor(unit)
    local rule = ThreatRule(unit)
    if not rule then return nil end
    local on, col = rule.enabled, C()
    local status, pct = ThreatOf(unit)
    if cfg.mode == "tank" then
        if status == 3 then return on.safe and col.safe or nil end
        if status == 1 or status == 2 then return on.transition and col.transition or nil end
        local tgt = unit .. "target"
        if not UnitExists(tgt) or UnitIsUnit(tgt, "player") then return nil end
        if UnitGroupRolesAssigned and UnitGroupRolesAssigned(tgt) == "TANK" then
            return on.offtank and col.offtank or nil
        end
        if InGroupUnit(tgt) then return on.warning and col.warning or nil end
        return nil
    end
    -- DPS, healer, solo: red = the mob is on you, amber = you are close to pulling it
    if status == 3 or status == 2 then return on.warning and col.warning or nil end
    if status == 1 or (pct and pct >= D().threatWarnAt) then return on.transition and col.transition or nil end
    return nil
end

local function BarColor(unit)
    local col = C()
    if UnitIsTapDenied and UnitIsTapDenied(unit) then return col.tapped end
    if UnitIsPlayer(unit) then
        local cc = ClassColor(unit)
        if cc then return cc end
    end
    local threat = ThreatColor(unit)
    if threat then return threat end
    local r = UnitReaction and UnitReaction(unit, "player")
    if r and r >= 5 then return col.friendly end
    if r == 4 then return col.neutral end
    return col.hostile
end

local CLASSIFICATION = { elite = "+", rareelite = "R+", rare = "R", worldboss = "B" }

local function LevelText(unit)
    local cls = UnitClassification and UnitClassification(unit)
    local mark = CLASSIFICATION[cls or ""]
    local level = UnitEffectiveLevel and UnitEffectiveLevel(unit) or UnitLevel(unit)
    local text
    if cfg.show.level then
        local mine = UnitLevel("player")
        if level == nil or level < 0 then
            text = ns.Paint("red", "??")
        elseif math.abs(level - mine) >= D().levelDiff then
            local c = (GetCreatureDifficultyColor or GetQuestDifficultyColor)
            c = c and c(level)
            text = c and ("|cff%02x%02x%02x%d|r"):format(c.r * 255, c.g * 255, c.b * 255, level) or tostring(level)
        end
    end
    if mark then text = (text or "") .. ns.Paint("amber", mark) end
    return text
end

------------------------------------------------------------------------
-- Quest marker: is this mob part of an active quest objective? Cached per GUID.
------------------------------------------------------------------------
local QUEST_LINE = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestObjective
local scanTip

local function Unfinished(text)
    local a, b = text:match("(%d+)/(%d+)")
    return a and tonumber(a) < tonumber(b)
end

local function IsQuestUnit(unit)
    if UnitIsPlayer(unit) then return false end
    local guid = UnitGUID(unit)
    if not guid then return false end
    if questCache[guid] ~= nil then return questCache[guid] end
    local result = false
    if C_TooltipInfo and C_TooltipInfo.GetUnit then
        local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
        if ok and type(data) == "table" and type(data.lines) == "table" then
            for _, line in ipairs(data.lines) do
                local text = line.leftText
                if QUEST_LINE and line.type == QUEST_LINE then
                    if not line.completed and (not text or not text:find("%d+/%d+") or Unfinished(text)) then
                        result = true
                        break
                    end
                elseif text and Unfinished(text) then
                    result = true
                    break
                end
            end
        end
    else
        -- older clients: read a hidden tooltip
        if not scanTip then
            scanTip = CreateFrame("GameTooltip", "MLZUIScanTooltip", nil, "GameTooltipTemplate")
        end
        scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
        scanTip:SetUnit(unit)
        for i = 2, scanTip:NumLines() do
            local fs = _G["MLZUIScanTooltipTextLeft" .. i]
            local text = fs and fs:GetText()
            if text and Unfinished(text) then
                result = true
                break
            end
        end
        scanTip:Hide()
    end
    questCache[guid] = result
    return result
end

------------------------------------------------------------------------
-- Updates (each takes our frame; f.unit is the nameplate unit)
------------------------------------------------------------------------
local function UpdateName(f)
    local unit = f.unit
    local name = UnitName(unit) or ""
    if f.nameOnly then
        local cc = UnitIsPlayer(unit) and ClassColor(unit) or C().friendly
        f.name:SetText(name)
        f.name:SetTextColor(cc[1], cc[2], cc[3])
        return
    end
    local level = LevelText(unit)
    f.name:SetText(level and (level .. " " .. name) or name)
    local tc = Theme("text", { 0.93, 0.94, 0.96 })
    f.name:SetTextColor(tc[1], tc[2], tc[3])
end

local function UpdateHealth(f)
    local unit = f.unit
    local cur, max = UnitHealth(unit), UnitHealthMax(unit)
    if not max or max <= 0 then max = 1 end
    f.health:SetValue(cur / max)
    if cfg.show.healthText and (f.isTarget or cur < max) and cur > 0 then
        f.healthText:SetText(math.ceil(cur / max * 100) .. "%")
        f.healthText:Show()
    else
        f.healthText:Hide()
    end
    f.exec:SetShown(cfg.show.execute and execPct and cur > 0 and cur / max <= execPct
        and UnitCanAttack and UnitCanAttack("player", unit) and true or false)
end

local THREAT_SOUND = 8959 -- SOUNDKIT.RAID_WARNING, used when the client has no SOUNDKIT table

-- One warning sound per mob as you get close to pulling it, only in a group (solo there is no tank)
local function ThreatSound(f, pct)
    local d = D()
    if pct < d.threatWarnAt then warned[f] = nil return end
    if warned[f] or pct < d.threatSoundAt or not InGroup() or not PlaySound then return end
    warned[f] = true
    ns.Try(PlaySound, SOUNDKIT and SOUNDKIT.RAID_WARNING or THREAT_SOUND, "Master")
end

-- Threat % for DPS, healers and solo: in a group, or solo with a pet that is meant to hold the mob
local function UpdateThreatText(f)
    local unit = f.unit
    local rule = cfg.mode ~= "tank" and ThreatRule(unit)
    local status, pct
    if rule then status, pct = ThreatOf(unit) end
    if not pct then
        f.threatText:Hide()
        return
    end
    ThreatSound(f, pct)
    if pct <= 0 or not (InGroup() or (UnitExists and UnitExists("pet"))) then
        f.threatText:Hide()
        return
    end
    local t
    if status == 3 or status == 2 or pct >= 100 then
        t = Theme("red", { 1, 0.35, 0.35 })
    elseif pct >= D().threatWarnAt then
        t = Theme("amber", { 1, 0.69, 0.25 })
    else
        t = Theme("text", { 0.9, 0.91, 0.93 })
    end
    f.threatText:SetTextColor(t[1], t[2], t[3])
    f.threatText:SetFormattedText("%d%%", math.floor(pct + 0.5))
    f.threatText:Show()
end

local function UpdateColor(f)
    local c = BarColor(f.unit)
    f.health:SetStatusBarColor(c[1], c[2], c[3])
    UpdateThreatText(f)
end

local function UpdateTarget(f)
    local unit = f.unit
    local isTarget = UnitIsUnit(unit, "target")
    f.isTarget = isTarget
    local m = D().modes[cfg.mode] or D().modes.solo
    local a = Accent()
    f.strip:SetVertexColor(a[1], a[2], a[3])
    f.strip:SetShown(isTarget and not f.nameOnly)
    local hovered = f == hover
    if isTarget then
        f.health.edge:SetVertexColor(a[1], a[2], a[3], 1)
    elseif hovered then
        -- the mob under the mouse gets a light edge, so you see what a click will target
        local t = Theme("muted", { 0.58, 0.61, 0.66 })
        f.health.edge:SetVertexColor(t[1], t[2], t[3], 1)
    else
        f.health.edge:SetVertexColor(unpack(EDGE))
    end
    local nonTarget = cfg.pvp and D().pvp.nonTarget or m.nonTarget
    f:SetAlpha((UnitExists("target") and not isTarget and not hovered) and nonTarget or 1)
    f:SetScale(cfg.size * (isTarget and m.targetScale or 1))
end

local function UpdateRaid(f)
    local idx = GetRaidTargetIndex and GetRaidTargetIndex(f.unit)
    if not idx then f.raid:Hide() return end
    if SetRaidTargetIconTexture then
        SetRaidTargetIconTexture(f.raid, idx)
    else
        local col, row = (idx - 1) % 4, math.floor((idx - 1) / 4)
        f.raid:SetTexCoord(col / 4, (col + 1) / 4, row / 4, (row + 1) / 4)
    end
    f.raid:Show()
end

local function UpdateQuest(f)
    f.quest:SetShown(cfg.show.quest and not f.nameOnly and IsQuestUnit(f.unit))
end

-- Returns name, icon, count, duration, expires of aura number i for the filter, or nil
local function AuraAt(unit, i, filter)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local a = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
        if not a then return nil end
        return a.name, a.icon, a.applications, a.duration, a.expirationTime
    end
    if UnitAura then
        local name, icon, count, _, duration, expires = UnitAura(unit, i, filter)
        return name, icon, count, duration, expires
    end
end

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id))
end

-- Names, not ids: every rank of a spell has its own id but the same name
local function CCNames()
    if ccNames then return ccNames end
    ccNames = {}
    for _, id in ipairs(D().cc or {}) do
        local ok, name = pcall(SpellName, id)
        if ok and name then ccNames[name] = true end
    end
    return ccNames
end

-- Returns icon, duration, expires of the first crowd control on the unit, or nil
local function CCAura(unit)
    local names = CCNames()
    if not next(names) then return nil end
    for i = 1, 40 do
        local name, icon, _, duration, expires = AuraAt(unit, i, "HARMFUL")
        if not name then return nil end
        if names[name] then return icon, duration, expires end
    end
end

local function SetTimer(a, duration, expires)
    a.expires = (duration and duration > 0) and expires or nil
    a.time:SetText("")
end

-- Your class's execute spell, if you know it (any rank). Asked again when your spells change.
local function UpdateExecute()
    execPct = nil
    local class = select(2, UnitClass("player"))
    local data = class and ns.data.classes[class]
    local ex = data and data.execute
    if not ex then return end
    local name = SpellName(ex.spell)
    local known = (IsSpellKnown and IsSpellKnown(ex.spell)) or (IsPlayerSpell and IsPlayerSpell(ex.spell))
    -- GetSpellInfo(name) only answers for spells in your spellbook, so every rank counts
    if not known and name and GetSpellInfo then known = GetSpellInfo(name) ~= nil end
    if known then execPct = ex.pct or 0.2 end
end

function Plates.ExecuteSpell()
    local class = select(2, UnitClass("player"))
    local ex = class and ns.data.classes[class] and ns.data.classes[class].execute
    return ex and SpellName(ex.spell) or nil
end

local function UpdateAuras(f)
    local m = D().modes[cfg.mode] or D().modes.solo
    local want = cfg.show.debuffs and not f.nameOnly and (f.isTarget or m.debuffsAll)
    local n = 0
    if want then
        for i = 1, 40 do
            local name, icon, count, duration, expires = AuraAt(f.unit, i, "HARMFUL|PLAYER")
            if not name then break end
            n = n + 1
            local a = f.auras[n]
            a.icon:SetTexture(icon)
            a.count:SetText((count and count > 1) and count or "")
            SetTimer(a, duration, expires)
            a:Show()
            if n >= #f.auras then break end
        end
    end
    for i = n + 1, #f.auras do f.auras[i]:Hide() end
    -- crowd control shows on every enemy plate, not only your target
    local ccIcon, ccDuration, ccExpires
    if cfg.show.cc and not f.nameOnly then ccIcon, ccDuration, ccExpires = CCAura(f.unit) end
    if ccIcon then
        f.cc.icon:SetTexture(ccIcon)
        SetTimer(f.cc, ccDuration, ccExpires)
        f.cc:Show()
    else
        f.cc:Hide()
    end
    f.hasTimers = n > 0 or ccIcon ~= nil
    if f.hasTimers and Wake then Wake() end
end

-- Cast info works across client versions: the "can't interrupt" flag is the first boolean after
-- the times, if the client sends one at all. Returns name, icon, startMS, endMS, locked, channel.
local function CastInfo(unit)
    if UnitCastingInfo then
        local name, _, icon, startMS, endMS, _, _, a = UnitCastingInfo(unit)
        if name then return name, icon, startMS, endMS, a == true, false end
    end
    if UnitChannelInfo then
        local name, _, icon, startMS, endMS, _, a = UnitChannelInfo(unit)
        if name then return name, icon, startMS, endMS, a == true, true end
    end
end

-- Who the cast is aimed at (the caster's target), in class color for players. Mobs turn to the player
-- they cast on, so a healer sees who is about to take the hit.
local function UpdateCastTarget(f)
    local tgt = f.unit and (f.unit .. "target")
    if not (tgt and casting[f] and UnitExists(tgt)) or UnitIsUnit(tgt, f.unit) then
        f.castTarget:SetText("")
        return
    end
    local c = UnitIsPlayer(tgt) and ClassColor(tgt) or Theme("text", { 0.93, 0.94, 0.96 })
    f.castTarget:SetText(UnitName(tgt) or "")
    f.castTarget:SetTextColor(c[1], c[2], c[3])
end

local function UpdateCast(f)
    local name, icon, startMS, endMS, locked, channel
    if cfg.show.castBar and not f.nameOnly then
        name, icon, startMS, endMS, locked, channel = CastInfo(f.unit)
    end
    if not name or not startMS or not endMS or endMS <= startMS then
        casting[f] = nil
        -- an interrupted cast stays up for a moment: the stop event that follows must not hide it
        if not held[f] then f.cast:Hide() end
        return
    end
    held[f] = nil
    f.castStart, f.castEnd, f.castChannel = startMS / 1000, endMS / 1000, channel
    local c = locked and C().castLocked or C().cast
    f.cast:SetStatusBarColor(c[1], c[2], c[3])
    f.castText:SetText(name)
    f.castTime:SetText("")
    f.castIcon:SetTexture(icon)
    f.castIcon:SetShown(icon ~= nil)
    f.castIcon.edge:SetShown(icon ~= nil)
    f.cast:Show()
    casting[f] = true
    UpdateCastTarget(f)
    if Wake then Wake() end
end

-- Interrupted: the bar fills, turns red and says so for a moment, so you see that the kick landed
local function CastInterrupted(f)
    if not (cfg.show.castBar and not f.nameOnly and f.cast:IsShown()) then return end
    casting[f] = nil
    held[f] = GetTime() + (D().interruptedHold or 0.6)
    local r = Theme("red", { 1, 0.36, 0.36 })
    f.cast:SetStatusBarColor(r[1], r[2], r[3])
    f.cast:SetValue(1)
    f.castText:SetText(INTERRUPTED or "Interrupted")
    f.castTime:SetText("")
    f.castTarget:SetText("")
    if Wake then Wake() end
end

local function UpdateAll(f)
    if not f.unit then return end
    f.nameOnly = IsFriendly(f.unit)
    f.health:SetShown(not f.nameOnly)
    if f.nameOnly then f.exec:Hide() end
    UpdateTarget(f)
    UpdateName(f)
    if not f.nameOnly then
        UpdateHealth(f)
        UpdateColor(f)
    end
    UpdateRaid(f)
    UpdateQuest(f)
    UpdateAuras(f)
    UpdateCast(f)
end

------------------------------------------------------------------------
-- Plates coming and going
------------------------------------------------------------------------
local function UnitAdded(unit)
    local plate = PlateForUnit(unit)
    if not plate then return end
    if UnitNameplateShowsWidgetsOnly and UnitNameplateShowsWidgetsOnly(unit) then
        -- widget-only plates (objects, some quest NPCs) stay Blizzard's
        if frames[plate] then frames[plate]:Hide() end
        ShowBlizzard(plate)
        return
    end
    local f = frames[plate] or Build(plate)
    -- a plate can be reused for another unit without a "removed" in between
    for u, other in pairs(byUnit) do if other == f then byUnit[u] = nil end end
    f.unit = unit
    byUnit[unit] = f
    held[f] = nil
    warned[f] = nil
    if hover == f then hover = nil end
    HideBlizzard(plate)
    UpdateAll(f)
    f:Show()
end

local function UnitRemoved(unit)
    local f = byUnit[unit]
    if not f then return end
    byUnit[unit] = nil
    casting[f] = nil
    held[f] = nil
    warned[f] = nil
    if hover == f then hover = nil end
    f.unit = nil
    f:Hide()
end

local function ForEach(fn)
    for _, f in pairs(byUnit) do fn(f) end
end

------------------------------------------------------------------------
-- Events (registered only while MLZ nameplates are on)
------------------------------------------------------------------------
local events = CreateFrame("Frame")
local handlers = {}

local function OnUnit(fn)
    return function(unit)
        local f = unit and byUnit[unit]
        if f then fn(f) end
    end
end

-- Quest progress changes which mobs you still need. The cache is cleared when the rescan runs (at most
-- once a second), not on every event, so a burst of quest events costs one tooltip scan per plate.
local questScheduled = false
local unitQuestEvents = false -- the client sends UNIT_QUEST_LOG_CHANGED: ignore the noisier QUEST_LOG_UPDATE
local function QuestChanged()
    if questScheduled then return end
    questScheduled = true
    C_Timer.After(1, function()
        questScheduled = false
        wipe(questCache)
        if active then ForEach(UpdateQuest) end
    end)
end

-- Execute range depends on what you know: check at login and whenever your spells change
local function ExecuteChanged()
    UpdateExecute()
    if active then ForEach(function(f) if not f.nameOnly then UpdateHealth(f) end end) end
end
ns.On("PLAYER_LOGIN", ExecuteChanged)
ns.TryOn("SPELLS_CHANGED", ExecuteChanged)
ns.TryOn("LEARNED_SPELL_IN_TAB", ExecuteChanged)

-- A long grind without quest events would keep every mob GUID: start fresh after each loading screen
ns.On("PLAYER_ENTERING_WORLD", function() wipe(questCache) end)

handlers.NAME_PLATE_UNIT_ADDED = UnitAdded
handlers.NAME_PLATE_UNIT_REMOVED = UnitRemoved
handlers.PLAYER_TARGET_CHANGED = function()
    ForEach(function(f)
        UpdateTarget(f)
        if not f.nameOnly then UpdateHealth(f) end
        UpdateAuras(f)
    end)
end
handlers.UNIT_HEALTH = OnUnit(function(f) if not f.nameOnly then UpdateHealth(f) end end)
handlers.UNIT_HEALTH_FREQUENT = handlers.UNIT_HEALTH
handlers.UNIT_MAXHEALTH = handlers.UNIT_HEALTH
handlers.UNIT_NAME_UPDATE = OnUnit(UpdateName)
handlers.UNIT_LEVEL = OnUnit(UpdateName)
handlers.UNIT_CLASSIFICATION_CHANGED = OnUnit(UpdateName)
handlers.UNIT_FACTION = OnUnit(UpdateAll)
handlers.UNIT_FLAGS = OnUnit(function(f) if not f.nameOnly then UpdateColor(f) end end)
handlers.UNIT_TARGET = OnUnit(function(f)
    if f.nameOnly then return end
    UpdateColor(f)
    if casting[f] then UpdateCastTarget(f) end
end)
handlers.UNIT_THREAT_LIST_UPDATE = handlers.UNIT_FLAGS
handlers.UNIT_THREAT_SITUATION_UPDATE = function() ForEach(function(f) if not f.nameOnly then UpdateColor(f) end end) end
handlers.PLAYER_REGEN_ENABLED = handlers.UNIT_THREAT_SITUATION_UPDATE
handlers.PLAYER_REGEN_DISABLED = handlers.UNIT_THREAT_SITUATION_UPDATE
handlers.UNIT_AURA = OnUnit(UpdateAuras)
handlers.RAID_TARGET_UPDATE = function() ForEach(UpdateRaid) end
handlers.PLAYER_LEVEL_UP = function() C_Timer.After(0.2, function() if active then ForEach(UpdateName) end end) end
handlers.QUEST_LOG_UPDATE = function() if not unitQuestEvents then QuestChanged() end end
handlers.UNIT_QUEST_LOG_CHANGED = function(unit)
    unitQuestEvents = true
    if unit == "player" then QuestChanged() end
end
handlers.QUEST_ACCEPTED = QuestChanged
handlers.QUEST_REMOVED = QuestChanged
handlers.QUEST_TURNED_IN = QuestChanged
for _, ev in ipairs({
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}) do
    handlers[ev] = OnUnit(UpdateCast)
end
handlers.UNIT_SPELLCAST_INTERRUPTED = OnUnit(CastInterrupted)

-- The client says when the mouse moves onto a unit, not when it leaves: OnUpdate clears the hover
local function SetHover(f)
    if hover == f then return end
    local old = hover
    hover = f
    if old and old.unit then UpdateTarget(old) end
    if f then
        UpdateTarget(f)
        if Wake then Wake() end
    end
end
handlers.UPDATE_MOUSEOVER_UNIT = function()
    local found
    for unit, f in pairs(byUnit) do
        if not f.nameOnly and UnitIsUnit(unit, "mouseover") then found = f break end
    end
    SetHover(found)
end

events:SetScript("OnEvent", function(_, event, ...)
    local fn = handlers[event]
    if not fn then return end
    local ok, err = pcall(fn, ...)
    if not ok then ns.Error("nameplates", err) end
end)

-- One OnUpdate for cast bars (every frame) and debuff timers (4 times a second).
-- It stops itself when nothing is casting and no plate has a timer; Wake starts it again.
local auraClock = 0
local function TickTimer(a, now)
    if not (a:IsShown() and a.expires) then return end
    local left = a.expires - now
    if left <= 0 then
        a.time:SetText("")
    elseif left < 10 then
        a.time:SetFormattedText("%.0f", math.ceil(left))
    elseif left < 60 then
        a.time:SetFormattedText("%d", left)
    else
        a.time:SetFormattedText("%dm", math.ceil(left / 60))
    end
end

Wake = function()
    if active and not events:IsShown() then events:Show() end
end
events:SetScript("OnUpdate", function(self, elapsed)
    local now = GetTime()
    for f in pairs(casting) do
        local total = f.castEnd - f.castStart
        if now >= f.castEnd then
            f.cast:Hide()
            casting[f] = nil
        else
            if f.castChannel then
                f.cast:SetValue((f.castEnd - now) / total)
            else
                f.cast:SetValue((now - f.castStart) / total)
            end
            f.castTime:SetFormattedText("%.1f", f.castEnd - now)
        end
    end
    for f, untilTime in pairs(held) do
        if now >= untilTime then
            held[f] = nil
            if not casting[f] then f.cast:Hide() end
        end
    end
    auraClock = auraClock + elapsed
    if auraClock < 0.25 then return end
    auraClock = 0
    if hover and not (hover.unit and UnitIsUnit(hover.unit, "mouseover")) then SetHover(nil) end
    local timers = false
    for _, f in pairs(byUnit) do
        if f.hasTimers then
            timers = true
            for _, a in ipairs(f.auras) do TickTimer(a, now) end
            TickTimer(f.cc, now)
        end
    end
    if not timers and not next(casting) and not next(held) and not hover then self:Hide() end
end)
events:Hide() -- OnUpdate only runs while shown, i.e. while active

local function Register(on)
    if on then
        for ev in pairs(handlers) do pcall(events.RegisterEvent, events, ev) end
        -- clients with both health events send each change twice: keep only the frequent one
        if events:IsEventRegistered("UNIT_HEALTH_FREQUENT") then events:UnregisterEvent("UNIT_HEALTH") end
        events:Show()
    else
        events:UnregisterAllEvents()
        events:Hide()
    end
end

------------------------------------------------------------------------
-- Friendly names for healers (a CVar and click-through, put back when you leave Healer mode)
------------------------------------------------------------------------
local function GetClickThrough()
    if C_NamePlate and C_NamePlate.GetNamePlateFriendlyClickThrough then
        local ok, v = pcall(C_NamePlate.GetNamePlateFriendlyClickThrough)
        if ok then return v and true or false end
    end
    return false
end

local function SetClickThrough(on)
    if C_NamePlate and C_NamePlate.SetNamePlateFriendlyClickThrough then
        pcall(C_NamePlate.SetNamePlateFriendlyClickThrough, on)
    end
end

-- Older clients have one CVar for friendly plates; Forever splits it into players and NPCs. Healers only
-- need the players (the group), so the NPC plates stay as they are.
local function FriendsCVar()
    for _, name in ipairs({ "nameplateShowFriends", "nameplateShowFriendlyPlayers" }) do
        if GetCVar(name) ~= nil then return name end
    end
end

local function ApplyFriends()
    local want = active and cfg.friends and cfg.mode == "healer" and not cfg.pvp
    ns.RunOutOfCombat(function()
        local db = ns.db and ns.db.nameplates
        if not db then return end
        if want then
            local cvar = FriendsCVar()
            if not cvar then return end
            if db.friendsBase == nil then
                db.friendsBase = { cvar = cvar, show = GetCVar(cvar), click = GetClickThrough() }
            end
            SetCVar(cvar, "1")
            SetClickThrough(true)
        elseif db.friendsBase then
            -- saved before `cvar` was stored: it was always nameplateShowFriends then
            local cvar = db.friendsBase.cvar or "nameplateShowFriends"
            if db.friendsBase.show ~= nil then pcall(SetCVar, cvar, db.friendsBase.show) end
            SetClickThrough(db.friendsBase.click and true or false)
            db.friendsBase = nil
        end
    end, "nameplate friends", true)
end

------------------------------------------------------------------------
-- Public API (called by Modules/Nameplates.lua)
------------------------------------------------------------------------
local function Enable()
    if active then return end
    active = true
    Register(true)
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) then UnitAdded(unit) end
    end
end

local function Disable()
    if not active then return end
    active = false
    Register(false)
    for unit, f in pairs(byUnit) do
        byUnit[unit] = nil
        f.unit = nil
        f:Hide()
    end
    wipe(casting)
    wipe(held)
    wipe(warned)
    hover = nil
    for plate in pairs(frames) do ShowBlizzard(plate) end
end

-- on = MLZ nameplates should draw. opts: mode, pvp, threat, friends, show, size
function Plates.Configure(on, opts)
    lastError = nil
    local okApi, why = Plates.Available()
    if on and not okApi then
        lastError = why
        on = false
    end
    if opts then
        cfg.mode = opts.mode or cfg.mode
        cfg.pvp = opts.pvp and true or false
        cfg.threat = opts.threat and true or false
        cfg.friends = opts.friends ~= false
        cfg.size = opts.size or 1
        for k in pairs(cfg.show) do
            if opts.show and opts.show[k] ~= nil then cfg.show[k] = opts.show[k] and true or false end
        end
    end
    local ok, err = pcall(function()
        if on then Enable() else Disable() end
        if active then ForEach(UpdateAll) end
    end)
    if not ok then
        lastError = "Could not update the nameplates: " .. tostring(err)
        ns.Error("nameplates", err)
    end
    ApplyFriends()
    return active
end

function Plates.LastError() return lastError end
