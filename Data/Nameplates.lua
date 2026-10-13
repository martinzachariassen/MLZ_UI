-- MLZ UI: Nameplate data

local _, ns = ...

ns.data.nameplates = {
    -- Settings switched by role. Three modes:
    --   tank = Warrior Defensive Stance or Druid Bear Form
    --   dps  = any other form, while you are in a party or raid
    --   solo = any other form, while you are alone (questing / grinding)
    presets = {
        tank = {
            not_target_alpha = 1,          -- all mobs fully visible so you can see threat
            obscured_combat_alpha = 0.7,   -- mobs behind objects are still easy to see
        },
        dps = {
            not_target_alpha = 0.75,       -- fades non-targets, focus on your target
            obscured_combat_alpha = 0.4,
        },
        solo = {
            not_target_alpha = 0.9,        -- calm: you often fight several mobs at once, keep them all readable
            obscured_combat_alpha = 0.5,
        },
    },

    -- Threat colors on the health bar, per mode. Platynator already knows your role (tank or not) and
    -- flips the meaning itself: for a tank "warning" = a mob is not on you, for everyone else
    -- "warning" = a mob is on you.
    --   warning    = red     transition = orange (aggro is changing hands)
    --   safe       = blue    offtank    = teal (another tank has it)
    -- Applied in every mode, also without the clean style (turn off with /mlz np threat off).
    threat = {
        tank = { enabled = { warning = true, transition = true, safe = true,  offtank = true  }, tanksOnly = false },
        dps  = { enabled = { warning = true, transition = true, safe = false, offtank = false }, tanksOnly = false },
        -- alone: no threat colors for non-tanks, plain reaction colors
        solo = { enabled = { warning = true, transition = true, safe = false, offtank = false }, tanksOnly = true },
    },

    -- Design that /mlz np tidy edits (the one assigned to enemies in Platynator)
    enemyDesign = "Enemy Nameplates",

    -- The tidy changes: smaller nameplates and health shown as percentage only
    tidy = {
        scale = 1,                       -- was 1.2
        healthText = { "percentage" },   -- was { "absolute", "percentage" }
    },

    -- /mlz np style: a clean look, built from your current enemy design (so your font, anchors and
    -- colors are kept). Same minimal layout in all modes; only the threat coloring differs.
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
        -- Threat is never dropped: it is switched per mode through `threat` above.
        dropColors = { eliteType = true, quest = true },
    },

    -- Optional: paste a full Platynator profile string (PLATY!1!...) here to keep your setup
    -- inside the addon folder. Get it with /mlz np export. /mlz np load uses this if
    -- no snapshot is saved in-game. Leave as nil if you don't want that.
    profileString = nil,
}
