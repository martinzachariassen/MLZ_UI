-- MLZ UI: Class data
-- What each class is for the UI. Edit freely. The logic lives in Core.lua (ns.Role, ns.Archetype).
-- WoW Forever has 9 classes with 3 talent trees each.
--
-- Archetypes: TANK, HEALER, MELEE, RANGED (hunter), CASTER. Role is derived from them:
-- TANK -> Tank, HEALER -> Healer, everything else -> DPS.
--
--   tabs     = archetype per talent tree, in the order of the talent window (optional)
--   dpsTabs  = what a tree counts as when you are NOT tanking or healing right now
--              (a Protection paladin who is not tanking, a Feral druid in Cat Form)
--   dps      = archetype when talents don't decide yet (leveling) or when you chose DPS yourself.
--              Hybrids use MELEE here: they melee a lot while leveling, so they keep the swing timers
--   pureDps  = no tank or healer tree at all: always DPS, talents are not checked
--   resource = main resource, only used for text
--   stance   = number of extra keys (bar 5 buttons 1-N, max 5, see B.extra) to drag stances, forms or auras onto
--   stanceNeedsForms = only when the client has forms for it (Priest: Shadowform does not exist on every client)
--   pet      = has a pet bar (keys BONUSACTIONBUTTON1-3)
--   execute  = a finishing spell that only works on low health: first rank id and the health fraction.
--              MLZ nameplates show an amber strip on the right once a mob is in range (if you know the spell)
--   interrupt = spells that stop a cast (first rank ids). MLZ nameplates color a cast bar slate while all of
--              them are on cooldown. pet = true: a pet spell (felhunter), read from the pet bar

local _, ns = ...

ns.data.classes = {
    WARRIOR = {
        tabs = { "MELEE", "MELEE", "TANK" }, dps = "MELEE", resource = "Rage", stance = 3,
        execute = { spell = 5308, pct = 0.2 },  -- Execute
        interrupt = { 6552, 72 },               -- Pummel, Shield Bash
    },
    PALADIN = {
        tabs = { "HEALER", "TANK", "MELEE" }, dpsTabs = { [2] = "MELEE" }, dps = "MELEE", resource = "Mana", stance = 3,
        execute = { spell = 24275, pct = 0.2 }, -- Hammer of Wrath
        -- no interrupt: Hammer of Justice is a stun, it doesn't stop a cast for its lockout
    },
    HUNTER = {
        dps = "RANGED", pureDps = true, resource = "Mana", pet = true,
        -- no interrupt in Classic (Scatter Shot and Intimidation are crowd control, not a kick)
    },
    ROGUE = {
        dps = "MELEE", pureDps = true, resource = "Energy", stance = 1,
        interrupt = { 1766 },                   -- Kick
    },
    PRIEST = {
        tabs = { "HEALER", "HEALER", "CASTER" }, dps = "CASTER", resource = "Mana", stance = 1, stanceNeedsForms = true,
        interrupt = { 15487 },                  -- Silence (talent)
    },
    SHAMAN = {
        tabs = { "CASTER", "MELEE", "HEALER" }, dps = "MELEE", resource = "Mana",
        interrupt = { 8042 },                   -- Earth Shock
    },
    MAGE = {
        dps = "CASTER", pureDps = true, resource = "Mana",
        interrupt = { 2139 },                   -- Counterspell
    },
    WARLOCK = {
        dps = "CASTER", pureDps = true, resource = "Mana", pet = true,
        interrupt = { 19244, pet = true },      -- Spell Lock (felhunter)
    },
    DRUID = {
        tabs = { "CASTER", "TANK", "HEALER" }, dpsTabs = { [2] = "MELEE" }, dps = "MELEE", resource = "Mana", stance = 5,
        interrupt = { 16979 },                  -- Feral Charge (bear form talent)
    },
}

-- Names for the settings window
ns.data.archetypeText = {
    TANK = "Tank", HEALER = "Healer", MELEE = "Melee DPS", RANGED = "Ranged DPS", CASTER = "Caster DPS",
}
