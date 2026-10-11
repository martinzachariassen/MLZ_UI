-- MLZ UI: Keybind table
-- Edit freely. The logic lives in Modules/Bindings.lua.
-- Key names follow the WoW format: modifiers in the order ALT-CTRL-SHIFT-, e.g. "CTRL-Q", "SHIFT-MOUSEWHEELUP".

local _, ns = ...

local B = {}
ns.data.bindings = B

-- Movement setups. Chosen in the setup wizard.
B.movement = {
    ESDF = {
        { key = "E",     command = "MOVEFORWARD" },
        { key = "D",     command = "MOVEBACKWARD" },
        { key = "S",     command = "STRAFELEFT" },
        { key = "F",     command = "STRAFERIGHT" },
        { key = "SPACE", command = "JUMP" },
    },
    WASD = {
        { key = "W",     command = "MOVEFORWARD" },
        { key = "S",     command = "MOVEBACKWARD" },
        { key = "A",     command = "STRAFELEFT" },
        { key = "D",     command = "STRAFERIGHT" },
        { key = "SPACE", command = "JUMP" },
    },
}

-- 12 base keys per movement setup (left hand). The order = buttons 1-12 on the bar.
-- Sorted by reach: the keys under resting fingers get the most-pressed buttons (rotation).
--   ESDF: pinky rests on A (free), so A/Q are the best keys; R/T/G for the index finger.
--         Numbers are a longer reach than with WASD (hand sits one key to the right), so 1 is left out.
--         A MUST be in this list, otherwise it keeps Blizzard's default turn/strafe binding.
--   WASD: 1-4 and Q/E are closest; 5 is a stretch, so it gets a cooldown instead of rotation.
-- Free keys for later: ESDF = V, B, 5, 1.  WASD = G, V, T.
B.baseKeys = {
    ESDF = { "Q", "W", "R", "T", "A", "G", "3", "4", "2", "Z", "X", "C" },
    WASD = { "1", "2", "3", "4", "Q", "E", "R", "F", "5", "Z", "X", "C" },
}

-- Role per button (shown in the setup wizard as a hint, does not affect the binding).
-- Shared by both movement setups, so keep baseKeys ordered to match.
B.roles = {
    "Rotation", "Rotation", "Rotation", "Rotation", "Rotation", "Rotation",
    "Interrupt", "Defensive", "Main cooldown",
    "Mobility", "CC/utility", "Dispel/utility",
}

-- Layers: modifier + binding command prefix. Button number 1-12 is appended at the end.
-- ACTIONBUTTON = main bar (bar 1), MULTIACTIONBAR1 = bottom left (bar 2), MULTIACTIONBAR2 = bottom right (bar 3)
B.layers = {
    { modifier = "",       prefix = "ACTIONBUTTON",           bar = "Bar 1" },
    { modifier = "SHIFT-", prefix = "MULTIACTIONBAR1BUTTON",  bar = "Bar 2" },
    { modifier = "CTRL-",  prefix = "MULTIACTIONBAR2BUTTON",  bar = "Bar 3" },
}

-- Mouse (no extra mouse buttons): modifier + wheel to bar 4 (MULTIACTIONBAR3 = right bar 1)
B.mouse = {
    { key = "SHIFT-MOUSEWHEELUP",   command = "MULTIACTIONBAR3BUTTON1" },
    { key = "SHIFT-MOUSEWHEELDOWN", command = "MULTIACTIONBAR3BUTTON2" },
    { key = "CTRL-MOUSEWHEELUP",    command = "MULTIACTIONBAR3BUTTON3" },
    { key = "CTRL-MOUSEWHEELDOWN",  command = "MULTIACTIONBAR3BUTTON4" },
}

-- When a key we take over already has an action, the action is moved to this modifier
-- (e.g. C = Character panel becomes ALT-C), as long as the new key is free and the action
-- doesn't already have another key.
B.displaceModifier = "ALT-"

-- Actions that are never moved to ALT (they are unimportant or replaced by our setup)
B.neverDisplace = {
    TURNLEFT = true, TURNRIGHT = true,     -- replaced by strafe
    ACTIONPAGE1 = true, ACTIONPAGE2 = true, ACTIONPAGE3 = true,
    ACTIONPAGE4 = true, ACTIONPAGE5 = true, ACTIONPAGE6 = true,
    CAMERAZOOMIN = true, CAMERAZOOMOUT = true,
}
