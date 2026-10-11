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

    -- Optional: paste a full Platynator profile string (PLATY!1!...) here to keep your setup
    -- inside the addon folder. Get it with /mlz np export. /mlz np load uses this if
    -- no snapshot is saved in-game. Leave as nil if you don't want that.
    profileString = nil,
}
