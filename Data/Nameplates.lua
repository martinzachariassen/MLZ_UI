-- MLZ UI: Nameplate data

local _, ns = ...

ns.data.nameplates = {
    -- Settings switched by stance (Defensive = tank, everything else = DPS)
    presets = {
        tank = {
            not_target_alpha = 1,          -- all mobs fully visible so you can see threat
            obscured_combat_alpha = 0.7,   -- mobs behind objects are still easy to see
        },
        dps = {
            not_target_alpha = 0.75,       -- fades non-targets, focus on your target
            obscured_combat_alpha = 0.4,
        },
    },

    -- Design that /mlz np tidy edits (the one assigned to enemies in Platynator)
    enemyDesign = "Enemy Nameplates",

    -- The tidy changes: smaller nameplates and health shown as percentage only
    tidy = {
        scale = 1,                       -- was 1.2
        healthText = { "percentage" },   -- was { "absolute", "percentage" }
    },

    -- /mlz np style: a clean look, built from your current enemy design (so your font, anchors and
    -- colors are kept). Same minimal layout in both modes; only the bar coloring differs.
    style = {
        scale = 1,
        healthText = { "percentage" },
        removeTexts = { quest = true, castTarget = true },     -- text kinds to remove
        removeBars = { energy = true },                        -- bar kinds to remove
        removeSpecialBars = true,                              -- class power circles under the bar
        removeBuffAuras = true,                                -- keep only your own debuffs
        debuffScale = 0.8,
        debuffLimit = 8,
        -- Bar color rules to drop (autoColors kinds). Order of the rest is kept.
        dropColors = {
            tank = { eliteType = true, quest = true },                  -- threat colors stay
            dps  = { eliteType = true, quest = true, threat = true },   -- plain reaction/class colors
        },
    },

    -- Optional: paste a full Platynator profile string (PLATY!1!...) here to keep your setup
    -- inside the addon folder. Get it with /mlz np export. /mlz np load uses this if
    -- no snapshot is saved in-game. Leave as nil if you don't want that.
    profileString = nil,
}
