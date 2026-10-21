-- MLZ UI: Ready-made setups
-- One-click setups on Profiles & backup (and /mlz preset <id>). Each one has the same shape as an export
-- string (see Modules/Profile.lua), so it goes through the same checks and a backup is taken first.
-- Only choices that apply at once are set: faded frames, nameplate options and helpers.
-- Keybinds, scale and wizard rows stay as they are. Fade ids: Data/Fade.lua (a row left out is not faded).

local _, ns = ...

ns.data.presets = {
    {
        id = "minimal", name = "Minimal",
        desc = "As little on screen as possible. Everything that can fade fades, and the nameplates show only "
            .. "what you need in a fight.",
        data = {
            fade = {
                bar45 = true, micro = true, bags = true, meter = true, bar23 = true, tracker = true,
                player = true, xp = true, chatbuttons = true,
            },
            nameplates = {
                threat = true,
                show = { healthText = false, level = false, quest = true, debuffs = true, castBar = true,
                         cc = true, execute = true },
            },
            switches = {
                reminders = { buffs = false, reagents = false, durability = true, raidFood = false, levelFood = false },
            },
        },
    },
    {
        id = "balanced", name = "Balanced",
        desc = "The MLZ UI defaults. Bars, bags and menus fade until you hover, and the nameplates show everything "
            .. "that matters.",
        data = {
            fade = {
                bar45 = true, micro = true, bags = true, meter = true, bar23 = true, tracker = true, chatbuttons = true,
            },
            nameplates = {
                threat = true,
                show = { healthText = true, level = true, quest = true, debuffs = true, castBar = true,
                         cc = true, execute = true },
            },
            switches = {
                reminders = { buffs = false, reagents = false, durability = true, raidFood = false, levelFood = false },
            },
        },
    },
    {
        id = "informative", name = "Informative",
        desc = "Everything stays in view. Only the menus fade, and reminders and the ready check buff check are on.",
        data = {
            fade = { micro = true, bags = true, chatbuttons = true },
            nameplates = {
                threat = true,
                show = { healthText = true, level = true, quest = true, debuffs = true, castBar = true,
                         cc = true, execute = true },
            },
            switches = {
                reminders = { buffs = true, reagents = true, durability = true, raidFood = true, levelFood = true },
                group = { buffCheck = true },
            },
        },
    },
}
