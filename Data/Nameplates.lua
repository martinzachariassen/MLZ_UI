-- MLZ UI: Nameplate data
-- Edit freely. Modes and threat are shared by both engines: MLZ nameplates (Modules/Plates.lua,
-- see `plates` at the bottom) and Platynator (Modules/Nameplates.lua, `presets` and `style`).

local _, ns = ...

ns.data.nameplates = {
    -- Four modes. With automatic switching on, the mode follows your role (see /mlz heal):
    --   tank   = you are tanking right now (Defensive Stance / Bear Form with tank talents, a tank aura,
    --            or the group made you the tank)
    --   healer = healer talents, in a party or raid
    --   dps    = everyone else in a party or raid (also a leveling character with no role yet)
    --   solo   = not tanking and not in a group (questing / grinding)
    modes = { "tank", "healer", "dps", "solo" },
    modeText = { tank = "Tank", healer = "Healer", dps = "DPS", solo = "Solo" },

    -- Platynator settings per mode. Keys are Platynator option names; "a.b" sets field b of table a.
    -- A key that a mode leaves out gets back the value you had before MLZ UI first changed it.
    presets = {
        tank = {
            not_target_alpha = 1,          -- every mob fully visible, so you can see what is loose
            obscured_combat_alpha = 0.7,   -- mobs behind objects are still easy to see
            target_scale = 1.15,           -- your target stands out in a big pull
        },
        healer = {
            not_target_alpha = 0.6,        -- enemies are dimmed: your eyes belong on the raid frames
            obscured_combat_alpha = 0.4,
        },
        dps = {
            not_target_alpha = 0.8,        -- fades non-targets, focus on your target
            obscured_combat_alpha = 0.4,
        },
        solo = {
            not_target_alpha = 0.9,        -- calm: you often fight several mobs, keep them all readable
            obscured_combat_alpha = 0.5,
        },
    },

    -- Healer extra ("Friendly names for healers"): friendly players get a nameplate (name) so you can
    -- see where people stand, but the plates can't be clicked, so they never steal a click meant for
    -- the world or your raid frames.
    healerFriends = {
        ["show_nameplates.friendlyPlayer"] = true,
        ["clickable_nameplates.friend"] = false,
    },

    -- In battlegrounds and arenas (when the PvP option is on): every enemy fully visible,
    -- no threat colors (they mean nothing against players), and enemy buffs kept on the plate.
    pvp = {
        not_target_alpha = 1,
        obscured_combat_alpha = 0.7,
    },

    -- Threat colors on the enemy health bar, per mode. Only written when "Threat colors" is on
    -- (it's off until you turn it on). Platynator flips the meaning for tanks itself: for a tank
    -- "warning" = a mob is NOT on you, for everyone else "warning" = a mob IS on you.
    --   warning = red   transition = orange (aggro changing hands)   safe = blue   offtank = teal
    -- tanksOnly = true turns the colors off completely unless you are the tank.
    threat = {
        tank   = { enabled = { warning = true, transition = true, safe = true,  offtank = true  }, tanksOnly = false },
        dps    = { enabled = { warning = true, transition = true, safe = false, offtank = false }, tanksOnly = false },
        healer = { enabled = { warning = true, transition = true, safe = false, offtank = false }, tanksOnly = true },
        solo   = { enabled = { warning = true, transition = true, safe = false, offtank = false }, tanksOnly = true },
    },

    -- Design used for enemies when it can't be read from Platynator's design assignments
    enemyDesign = "Enemy Nameplates",

    -- Clean style: built from your own enemy design (so your font, anchors and colors are kept).
    -- What is removed is remembered, so turning the style off puts it back.
    style = {
        scale = 1,
        healthText = { "percentage" },
        removeTexts = { quest = true, castTarget = true },     -- text kinds to remove
        removeBars = { energy = true },                        -- bar kinds to remove
        removeSpecialBars = true,                              -- class power circles under the bar
        removeAuras = { buffs = true },                        -- enemy buffs (kept in PvP); crowd control stays
        debuffScale = 0.8,
        debuffLimit = 8,
        debuffsFromYou = true,                                 -- only your own debuffs
        -- Bar color rules to drop (autoColors kinds). Threat is never dropped: see `threat` above.
        dropColors = { eliteType = true, quest = true },
    },

    -- Optional: paste a full Platynator profile string (PLATY!1!...) here to keep your setup
    -- inside the addon folder. Get it with /mlz np export. The wizard can import it, and
    -- /mlz np load uses it if no copy is saved in-game. Leave as nil if you don't want that.
    profileString = nil,

    -- MLZ nameplates (our own engine, Modules/Plates.lua). Flat and calm, in the MLZ UI palette.
    plates = {
        width = 128,          -- health bar size at size 100%
        height = 10,
        castHeight = 8,
        nameSize = 10,
        iconSize = 18,        -- debuff icons
        debuffLimit = 6,
        levelDiff = 3,        -- show the level only when it differs this much from yours (or is ??)

        -- per mode: alpha of plates you don't target (only while you have a target), target scale,
        -- and whether your debuffs show on every mob or only on your target
        modes = {
            tank   = { nonTarget = 1,   targetScale = 1.15, debuffsAll = true },
            healer = { nonTarget = 0.6, targetScale = 1,    debuffsAll = false },
            dps    = { nonTarget = 0.8, targetScale = 1.1,  debuffsAll = false },
            solo   = { nonTarget = 0.9, targetScale = 1.1,  debuffsAll = false },
        },
        pvp = { nonTarget = 1 },

        colors = {
            hostile  = { 0.85, 0.27, 0.27 },
            neutral  = { 0.95, 0.70, 0.25 },
            friendly = { 0.29, 0.78, 0.45 },
            tapped   = { 0.50, 0.52, 0.56 },
            -- threat (see `threat` above for which colors each mode uses)
            warning    = { 1.00, 0.20, 0.20 },
            transition = { 1.00, 0.55, 0.15 },
            safe       = { 0.20, 0.55, 1.00 },
            offtank    = { 0.20, 0.80, 0.75 },
            cast       = { 0.20, 0.63, 1.00 },   -- interruptible: accent blue
            castLocked = { 0.45, 0.47, 0.52 },   -- can't be interrupted
            quest      = { 1.00, 0.82, 0.00 },
        },
    },
}
