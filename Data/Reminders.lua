-- MLZ UI: What the reminder row checks
-- Edit freely. The logic lives in Modules/Reminders.lua.
--
-- buffs: shown out of combat when you know one of `spells` but have none of them (or of `also`) on you.
--   class  = class file name ("PRIEST", ...)
--   spells = spell IDs (rank 1 is enough: Classic keeps every rank in the spellbook). The first known one
--            gives the icon and name.
--   also   = extra spell IDs that count as "has it" (group versions cast by someone else, Demonic Sacrifice)
--   roles  = (optional) only for these roles
--   kind   = "aura" (default), "weapon" (weapon enchant on each hand that holds a weapon: poisons, imbues)
--            or "pet" (no pet out), or "happiness" (hunter pet out but not happy)
-- reagents: shown when you know `spell` and carry fewer than `min` of `item`.
--   item = item ID, or "ammo" for the equipped ammo (hunters)
-- raid: only inside a raid instance, with its own switch (food and flask in raids).
--   food  = spell IDs whose aura name counts as fed (every "Well Fed" buff shares the name)
--   flasks = { item, buff }: reminded only when you carry the flask but don't have its buff

local _, ns = ...

ns.data.reminders = {
    durability = 25, -- percent: warn when your most worn item is at or below this

    buffs = {
        { class = "PRIEST", spells = { 588 } },                          -- Inner Fire
        { class = "PRIEST", spells = { 1243 }, also = { 21562 } },       -- Power Word: Fortitude / Prayer of Fortitude
        { class = "PRIEST", spells = { 15473 } },                        -- Shadowform (talent)
        { class = "MAGE", spells = { 1459 }, also = { 23028 } },         -- Arcane Intellect / Arcane Brilliance
        { class = "MAGE", spells = { 6117, 7302, 168 } },                -- Mage Armor, Ice Armor, Frost Armor
        { class = "DRUID", spells = { 1126 }, also = { 21849 } },        -- Mark of the Wild / Gift of the Wild
        { class = "DRUID", spells = { 16864 } },                         -- Omen of Clarity (talent)
        { class = "DRUID", spells = { 467 }, roles = { TANK = true } },  -- Thorns
        { class = "WARLOCK", spells = { 706, 687 } },                    -- Demon Armor, Demon Skin
        { class = "WARLOCK", kind = "pet", spells = { 688, 697, 712, 691 },
          also = { 18789, 18790, 18791, 18792 } },                       -- Summon Imp, Voidwalker, Succubus, Felhunter (no pet after Demonic Sacrifice)
        { class = "WARRIOR", spells = { 6673 } },                        -- Battle Shout
        { class = "SHAMAN", spells = { 324 } },                          -- Lightning Shield
        { class = "SHAMAN", kind = "weapon", spells = { 8232, 8024, 8033, 8017 } }, -- Windfury, Flametongue, Frostbrand, Rockbiter
        { class = "HUNTER", spells = { 13165, 13163, 5118, 13159, 20043, 13161 } }, -- aspects: Hawk, Monkey, Cheetah, Pack, Wild, Beast
        { class = "HUNTER", kind = "pet", spells = { 883 } },            -- Call Pet
        { class = "HUNTER", kind = "happiness", spells = { 6991 } },     -- Feed Pet (pet is not happy)
        { class = "ROGUE", kind = "weapon", spells = { 2842 } },         -- Poisons
        { class = "PALADIN", spells = { 19740, 19742, 20217, 1038, 19977, 20911 },  -- any Blessing
          also = { 25782, 25894, 25898, 25895, 25890, 25899 } },         -- or a Greater Blessing
        { class = "PALADIN", spells = { 25780 }, roles = { TANK = true } },         -- Righteous Fury
        { class = "PALADIN", spells = { 465, 7294, 19746, 19876, 19888, 19891, 20218 } }, -- any Aura: Devotion, Retribution, ...
    },

    reagents = {
        { class = "HUNTER", spell = 75, item = "ammo", min = 200, label = "Ammo" },            -- Auto Shot
        { class = "WARLOCK", spell = 1120, item = 6265, min = 2, label = "Soul Shards" },      -- Drain Soul
        { class = "SHAMAN", spell = 20608, item = 17030, min = 1, label = "Ankh" },            -- Reincarnation
        { class = "ROGUE", spell = 1856, item = 5140, min = 1, label = "Flash Powder" },       -- Vanish
        { class = "ROGUE", spell = 2094, item = 5530, min = 1, label = "Blinding Powder" },    -- Blind
        { class = "MAGE", spell = 3561, item = 17031, min = 1, label = "Teleport rune" },      -- Teleport: Stormwind
        { class = "MAGE", spell = 3562, item = 17031, min = 1, label = "Teleport rune" },      -- Teleport: Ironforge
        { class = "MAGE", spell = 3565, item = 17031, min = 1, label = "Teleport rune" },      -- Teleport: Darnassus
        { class = "MAGE", spell = 3567, item = 17031, min = 1, label = "Teleport rune" },      -- Teleport: Orgrimmar
        { class = "MAGE", spell = 3563, item = 17031, min = 1, label = "Teleport rune" },      -- Teleport: Undercity
        { class = "MAGE", spell = 3566, item = 17031, min = 1, label = "Teleport rune" },      -- Teleport: Thunder Bluff
        { class = "MAGE", spell = 10059, item = 17032, min = 1, label = "Portal rune" },       -- Portal: Stormwind
        { class = "MAGE", spell = 11416, item = 17032, min = 1, label = "Portal rune" },       -- Portal: Ironforge
        { class = "MAGE", spell = 11419, item = 17032, min = 1, label = "Portal rune" },       -- Portal: Darnassus
        { class = "MAGE", spell = 11417, item = 17032, min = 1, label = "Portal rune" },       -- Portal: Orgrimmar
        { class = "MAGE", spell = 11418, item = 17032, min = 1, label = "Portal rune" },       -- Portal: Undercity
        { class = "MAGE", spell = 11420, item = 17032, min = 1, label = "Portal rune" },       -- Portal: Thunder Bluff
        { class = "MAGE", spell = 23028, item = 17020, min = 5, label = "Arcane Powder" },     -- Arcane Brilliance
        { class = "PRIEST", spell = 21562, item = 17029, min = 5, label = "Sacred Candle" },   -- Prayer of Fortitude
        { class = "PALADIN", spell = 25782, item = 21177, min = 10, label = "Symbol of Kings" }, -- Greater Blessing of Might
        { class = "PALADIN", spell = 19752, item = 17033, min = 1, label = "Symbol of Divinity" }, -- Divine Intervention
        { class = "DRUID", spell = 21849, item = 17021, min = 5, label = "Wild Thornroot" },   -- Gift of the Wild
    },

    -- Buff check on ready check (Modules/Group.lua): long buffs one class gives the whole group.
    --   class = who casts it, spells = single-target spell (rank 1, also tells if you know it),
    --   also = the group version, skip = classes that don't need it
    groupBuffs = {
        { class = "PRIEST", label = "Fortitude", spells = { 1243 }, also = { 21562 } },
        { class = "MAGE", label = "Arcane Intellect", spells = { 1459 }, also = { 23028 },
          skip = { WARRIOR = true, ROGUE = true } },
        { class = "DRUID", label = "Mark of the Wild", spells = { 1126 }, also = { 21849 } },
    },

    raid = {
        food = { 19705 }, -- Well Fed
        flasks = {
            { item = 13510, buff = 17626 }, -- Flask of the Titans
            { item = 13511, buff = 17627 }, -- Flask of Distilled Wisdom
            { item = 13512, buff = 17628 }, -- Flask of Supreme Power
            { item = 13513, buff = 17629 }, -- Flask of Chromatic Resistance
        },
    },
}
