-- MLZ UI: What the reminder row checks
-- Edit freely. The logic lives in Modules/Reminders.lua.
--
-- buffs: shown out of combat when you know one of `spells` but have none of them (or of `also`) on you.
--   class  = class file name ("PRIEST", ...)
--   spells = spell IDs (rank 1 is enough: Classic keeps every rank in the spellbook). The first known one
--            gives the icon and name.
--   also   = extra spell IDs that count as "has it" (group versions cast by someone else)
--   roles  = (optional) only for these roles
--   kind   = "aura" (default), "weapon" (main hand enchant: poisons, imbues) or "pet" (no pet out)
-- reagents: shown when you know `spell` and carry fewer than `min` of `item`.
--   item = item ID, or "ammo" for the equipped ammo (hunters)

local _, ns = ...

ns.data.reminders = {
    durability = 25, -- percent: warn when your most worn item is at or below this

    buffs = {
        { class = "PRIEST", spells = { 588 } },                          -- Inner Fire
        { class = "PRIEST", spells = { 1243 }, also = { 21562 } },       -- Power Word: Fortitude / Prayer of Fortitude
        { class = "MAGE", spells = { 1459 }, also = { 23028 } },         -- Arcane Intellect / Arcane Brilliance
        { class = "MAGE", spells = { 6117, 7302, 168 } },                -- Mage Armor, Ice Armor, Frost Armor
        { class = "DRUID", spells = { 1126 }, also = { 21849 } },        -- Mark of the Wild / Gift of the Wild
        { class = "DRUID", spells = { 16864 } },                         -- Omen of Clarity (talent)
        { class = "WARLOCK", spells = { 706, 687 } },                    -- Demon Armor, Demon Skin
        { class = "SHAMAN", spells = { 324 } },                          -- Lightning Shield
        { class = "SHAMAN", kind = "weapon", spells = { 8232, 8024, 8033, 8017 } }, -- Windfury, Flametongue, Frostbrand, Rockbiter
        { class = "HUNTER", spells = { 13165, 13163, 5118, 13159, 20043, 13161 } }, -- aspects: Hawk, Monkey, Cheetah, Pack, Wild, Beast
        { class = "HUNTER", kind = "pet", spells = { 883 } },            -- Call Pet
        { class = "ROGUE", kind = "weapon", spells = { 2842 } },         -- Poisons
        { class = "PALADIN", spells = { 19740, 19742, 20217, 1038, 19977, 20911 },  -- any Blessing
          also = { 25782, 25894, 25898, 25895, 25890, 25899 } },         -- or a Greater Blessing
        { class = "PALADIN", spells = { 25780 }, roles = { TANK = true } },         -- Righteous Fury
    },

    reagents = {
        { class = "HUNTER", spell = 75, item = "ammo", min = 200, label = "Ammo" },            -- Auto Shot
        { class = "WARLOCK", spell = 1120, item = 6265, min = 2, label = "Soul Shards" },      -- Drain Soul
        { class = "SHAMAN", spell = 20608, item = 17030, min = 1, label = "Ankh" },            -- Reincarnation
        { class = "ROGUE", spell = 1856, item = 5140, min = 1, label = "Flash Powder" },       -- Vanish
        { class = "MAGE", spell = 3561, item = 17031, min = 1, label = "Teleport rune" },      -- Teleport: Stormwind
        { class = "MAGE", spell = 3567, item = 17031, min = 1, label = "Teleport rune" },      -- Teleport: Orgrimmar
        { class = "MAGE", spell = 23028, item = 17020, min = 5, label = "Arcane Powder" },     -- Arcane Brilliance
        { class = "PRIEST", spell = 21562, item = 17029, min = 5, label = "Sacred Candle" },   -- Prayer of Fortitude
        { class = "PALADIN", spell = 25782, item = 21177, min = 10, label = "Symbol of Kings" }, -- Greater Blessing of Might
    },
}
