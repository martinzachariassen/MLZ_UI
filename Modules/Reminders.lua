-- MLZ UI: Reminders
-- A small row of icons below the middle of the screen, out of combat only: self buffs you forgot
-- (Inner Fire, aspects, poisons, ...), reagents and ammo that run low, and worn-out gear.
-- Buffs are not nagged about while resting (cities, inns); reagents are, since that is where you buy them.
-- Worn gear also gets one chat line when it drops below the limit. Settings: /mlz > Helpers.
-- What is checked lives in Data/Reminders.lua.

local _, ns = ...

local R = {}
ns.Reminders = R

local DEFAULTS = { buffs = false, reagents = false, durability = true }
local ICON, GAP, MAX_ICONS = 28, 10, 8
local REPAIR_ICON = "Interface\\Icons\\Trade_BlackSmithing"

local function Cfg()
    ns.db.reminders = ns.db.reminders or {}
    local c = ns.db.reminders
    for k, v in pairs(DEFAULTS) do if c[k] == nil then c[k] = v end end
    c.ignore = c.ignore or {} -- ["b:<first spell id>"] or ["r:<item id>"] = true: muted one by one
    return c
end

------------------------------------------------------------------------
-- Game info, feature-detected (Classic clients differ)
------------------------------------------------------------------------
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id))
end

local function SpellIcon(id)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    return GetSpellTexture and GetSpellTexture(id)
end

local function Knows(id)
    if IsSpellKnown and IsSpellKnown(id) then return true end
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    return false
end

-- Names of every helpful aura on the player
local function PlayerBuffs()
    local names = {}
    for i = 1, 40 do
        local name
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            name = aura and aura.name
        elseif UnitBuff then
            name = UnitBuff("player", i)
        end
        if not name then break end
        names[name] = true
    end
    return names
end

local MAIN_HAND, OFF_HAND = INVSLOT_MAINHAND or 16, INVSLOT_OFFHAND or 17
local WEAPON_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or LE_ITEM_CLASS_WEAPON or 2

local function IsWeapon(slot)
    local id = GetInventoryItemID("player", slot)
    if not id then return false end
    local info = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not info then return slot == MAIN_HAND end -- can't tell: only check the main hand
    local _, _, _, _, _, classID = info(id)
    return classID == WEAPON_CLASS
end

-- Returns nil when every weapon you hold has an enchant (poison, imbue), else "main hand" or "off hand"
local function WeaponMissing()
    if not GetWeaponEnchantInfo then return nil end -- can't tell: don't nag
    local hasMain, _, _, _, hasOff = GetWeaponEnchantInfo()
    if IsWeapon(MAIN_HAND) and not hasMain then return "main hand" end
    if IsWeapon(OFF_HAND) and not hasOff then return "off hand" end
end

-- GetInventorySlotInfo errors on clients without an ammo slot
local function AmmoSlot()
    if not GetInventorySlotInfo then return nil end
    local ok, slot = pcall(GetInventorySlotInfo, "AmmoSlot")
    return ok and slot or nil
end

local function ItemCount(item)
    if item == "ammo" then
        local slot = AmmoSlot()
        if not slot then return nil end
        return GetInventoryItemCount("player", slot) or 0
    end
    if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(item) end
    return GetItemCount and GetItemCount(item) or nil
end

local function ItemIcon(item)
    if item == "ammo" then
        local slot = AmmoSlot()
        local tex = slot and GetInventoryItemTexture("player", slot)
        return tex or "Interface\\Icons\\INV_Ammo_Arrow_02"
    end
    if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(item) end
    return GetItemIcon and GetItemIcon(item)
end

-- Lowest durability of all equipped items in percent, or nil when nothing has durability
local function LowestDurability()
    if not GetInventoryItemDurability then return nil end
    local low
    for slot = 1, 19 do
        local cur, max = GetInventoryItemDurability(slot)
        if cur and max and max > 0 then
            local pct = math.floor(cur / max * 100 + 0.5)
            if not low or pct < low then low = pct end
        end
    end
    return low
end

------------------------------------------------------------------------
-- What is missing right now
------------------------------------------------------------------------
-- Returns a list of { icon, text, why }
local function Missing()
    local cfg, data = Cfg(), ns.data.reminders or {}
    local list = {}
    local _, class = UnitClass("player")
    -- What you do right now: a Feral druid in Cat Form is not a tank
    local role = ns.LiveRole and ns.LiveRole() or "DAMAGER"
    local ignore = cfg.ignore or {}

    if cfg.buffs and not IsResting() then
        local have = PlayerBuffs()
        for _, b in ipairs(data.buffs or {}) do
            if b.class == class and (not b.roles or b.roles[role]) and not ignore["b:" .. b.spells[1]] then
                local known
                for _, id in ipairs(b.spells) do
                    if Knows(id) then known = id break end
                end
                if known then
                    local ok, hand
                    if b.kind == "weapon" then
                        hand = WeaponMissing()
                        ok = hand == nil
                    elseif b.kind == "pet" then
                        ok = UnitExists("pet") or (IsMounted and IsMounted())
                        for _, id in ipairs(b.also or {}) do
                            local n = SpellName(id)
                            if n and have[n] then ok = true break end
                        end
                    else
                        for _, id in ipairs(b.spells) do
                            local n = SpellName(id)
                            if n and have[n] then ok = true break end
                        end
                        for _, id in ipairs(b.also or {}) do
                            local n = SpellName(id)
                            if n and have[n] then ok = true break end
                        end
                    end
                    if not ok then
                        local name = SpellName(known) or "?"
                        local why = b.kind == "weapon" and ("Your " .. (hand or "main hand") .. " weapon has no " .. name:lower() .. " on it.")
                            or b.kind == "pet" and "Your pet is not out."
                            or ("You don't have " .. name .. " on you.")
                        list[#list + 1] = { icon = SpellIcon(known), text = name, why = why }
                    end
                end
            end
        end
    end

    if cfg.reagents then
        local seen = {}
        for _, r in ipairs(data.reagents or {}) do
            if r.class == class and not seen[r.item] and not ignore["r:" .. tostring(r.item)] and Knows(r.spell) then
                local count = ItemCount(r.item)
                if count and count < r.min then
                    seen[r.item] = true
                    list[#list + 1] = { icon = ItemIcon(r.item), text = r.label .. " " .. count,
                        why = ("You carry %d %s. Buy more before you leave town."):format(count, r.label:lower()), low = true }
                end
            end
        end
    end

    if cfg.durability then
        local low = LowestDurability()
        if low and low <= (data.durability or 25) then
            list[#list + 1] = { icon = REPAIR_ICON, text = "Repair " .. low .. "%",
                why = "Your most worn item is at " .. low .. "% durability.", low = true }
        end
    end
    return list
end
R.Missing = Missing

------------------------------------------------------------------------
-- Icon row
------------------------------------------------------------------------
local row, icons = nil, {}

local function Build()
    if row then return end
    local W = ns.W
    row = CreateFrame("Frame", "MLZUI_Reminders", UIParent)
    row:SetSize(ICON, ICON + 16)
    row:SetPoint("TOP", UIParent, "CENTER", 0, -170)
    row:SetFrameStrata("LOW")
    row:EnableMouse(false) -- never blocks clicks into the world
    for i = 1, MAX_ICONS do
        local f = CreateFrame("Frame", nil, row)
        f:SetSize(ICON, ICON)
        f.tex = f:CreateTexture(nil, "ARTWORK")
        f.tex:SetPoint("TOPLEFT", 1, -1)
        f.tex:SetPoint("BOTTOMRIGHT", -1, 1)
        f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- crop the round icon edge
        f.border = W.Border(f, W.T.border)
        f.label = W.Text(f, "GameFontHighlightSmall", "", "CENTER")
        f.label:SetPoint("TOP", f, "BOTTOM", 0, -3)
        f.label:SetWordWrap(false)
        f:Hide()
        icons[i] = f
    end
end

local function Hidden()
    return InCombatLockdown() or UnitAffectingCombat("player") or UnitIsDeadOrGhost("player") or (UnitOnTaxi and UnitOnTaxi("player"))
        or (C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle())
end

-- The overview and the minimap tooltip list what is missing too: tell them when that list changes
local lastSig = ""
local function Signature(list)
    local parts = {}
    for i, item in ipairs(list) do parts[i] = item.text end
    return table.concat(parts, "|")
end

local function Update()
    if not ns.db then return end
    local cfg = Cfg()
    if not (cfg.buffs or cfg.reagents or cfg.durability) or Hidden() then
        if row then row:Hide() end
        return
    end
    local list = Missing()
    local sig = Signature(list)
    if sig ~= lastSig then
        lastSig = sig
        ns.FireState()
    end
    if #list == 0 then
        if row then row:Hide() end
        return
    end
    Build()
    local T = ns.W.T
    local n = math.min(#list, MAX_ICONS)
    local width = n * ICON + (n - 1) * (GAP + 40)
    for i, f in ipairs(icons) do
        local item = list[i]
        if item and i <= n then
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", row, "TOPLEFT", (i - 1) * (ICON + GAP + 40), 0)
            f.tex:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            f.label:SetText(item.text)
            f.label:SetTextColor(unpack(item.low and T.amber or T.text))
            f.border:SetColor(item.low and T.amber or T.border)
            f:Show()
        else
            f:Hide()
        end
    end
    row:SetWidth(width)
    row:Show()
end
R.Update = Update

-- Many events can fire at once (looting, buffing a group): update once a moment later
local pending = false
local function Schedule()
    if pending then return end
    pending = true
    C_Timer.After(0.3, function()
        pending = false
        local ok, err = pcall(Update)
        if not ok then ns.Error("reminders", err) end
    end)
end

------------------------------------------------------------------------
-- Worn gear: one chat line when it drops to the limit, again only after a repair
------------------------------------------------------------------------
local warned = false
local function CheckDurability()
    if not (ns.db and Cfg().durability) then return end
    local low, limit = LowestDurability(), (ns.data.reminders or {}).durability or 25
    if not low then return end
    if low <= limit and not warned then
        warned = true
        ns.Print(("Your gear is worn (%d%%). Repair at a merchant before your next fight."):format(low))
        ns.FireState()
    elseif low > limit and warned then
        warned = false
        ns.FireState()
    end
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
ns.TryOn("UNIT_AURA", function(_, unit) if unit == "player" then Schedule() end end)
ns.TryOn("UNIT_INVENTORY_CHANGED", function(_, unit) if unit == "player" then Schedule() end end)
ns.TryOn("UNIT_PET", function(_, unit) if unit == "player" then Schedule() end end)
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_UPDATE_RESTING",
    "SPELLS_CHANGED", "PLAYER_DEAD", "PLAYER_UNGHOST", "PLAYER_ALIVE", "PLAYER_CONTROL_GAINED", "PLAYER_CONTROL_LOST",
    "PLAYER_MOUNT_DISPLAY_CHANGED" }) do
    ns.TryOn(event, Schedule)
end
-- Hide right away when combat starts, no delay
ns.TryOn("PLAYER_REGEN_DISABLED", function() if row then row:Hide() end end)
ns.TryOn("UPDATE_INVENTORY_DURABILITY", function()
    CheckDurability()
    Schedule()
end)

-- Weapon enchants run out without an event on some clients: look again every 10 seconds out of combat
local ticker
ns.On("PLAYER_ENTERING_WORLD", function()
    if not ns.db then return end
    Schedule()
    C_Timer.After(5, CheckDurability)
    if not ticker and C_Timer.NewTicker then
        ticker = C_Timer.NewTicker(10, function()
            local c = ns.db and Cfg()
            if c and (c.buffs or c.reagents) and not InCombatLockdown() then Schedule() end
        end)
    end
end)

------------------------------------------------------------------------
-- Public API (settings window, overview)
------------------------------------------------------------------------
function R.Get(key) return Cfg()[key] and true or false end
function R.Set(key, on)
    Cfg()[key] = on and true or false
    Update()
    ns.FireState()
end
function R.Durability() return LowestDurability() end

-- Everything this class can be reminded about, for the settings window:
-- { key, name, kind = "buff" | "reagent", known = bool, min = number (reagents), roles = {...} (buffs) }
-- known = false while you have not learned the spell yet.
function R.Entries()
    local data = ns.data.reminders or {}
    local _, class = UnitClass("player")
    local out, seen = {}, {}
    for _, b in ipairs(data.buffs or {}) do
        if b.class == class then
            local known, name
            for _, id in ipairs(b.spells) do
                if Knows(id) then known = id break end
            end
            name = SpellName(known or b.spells[1])
            if name then
                out[#out + 1] = { key = "b:" .. b.spells[1], name = name, kind = "buff", known = known ~= nil, roles = b.roles }
            end
        end
    end
    for _, r in ipairs(data.reagents or {}) do
        if r.class == class and not seen[r.item] then
            seen[r.item] = true
            out[#out + 1] = { key = "r:" .. tostring(r.item), name = r.label, kind = "reagent", known = Knows(r.spell), min = r.min }
        end
    end
    return out
end

function R.IsMuted(key) return Cfg().ignore[key] and true or false end
function R.SetMuted(key, muted)
    Cfg().ignore[key] = muted and true or nil
    Update()
    ns.FireState()
end
function R.DurabilityLimit() return (ns.data.reminders or {}).durability or 25 end
