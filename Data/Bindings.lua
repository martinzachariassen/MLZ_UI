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

-- Class hints for the same buttons, by index into B.roles. Text only, they don't change any binding.
-- Missing entries fall back to B.roles.
B.classRoles = {
    WARRIOR = { [7] = "Interrupt (Pummel)", [10] = "Mobility (Charge)", [12] = "Taunt / utility" },
    PALADIN = { [7] = "Interrupt (Hammer of Justice)", [8] = "Defensive (Divine Shield)",
        [10] = "Utility (Freedom)", [12] = "Dispel (Cleanse)" },
    HUNTER  = { [7] = "Interrupt (Concussive Shot)", [9] = "Main cooldown (Rapid Fire)", [10] = "Mobility (Disengage)",
        [11] = "CC (Freezing Trap)", [12] = "Utility (Feign Death)" },
    ROGUE   = { [7] = "Interrupt (Kick)", [8] = "Defensive (Evasion)", [10] = "Mobility (Sprint)",
        [11] = "CC (Gouge, Sap)", [12] = "Utility (Vanish)" },
    PRIEST  = { [7] = "Interrupt (Silence)", [8] = "Defensive (Shield)", [11] = "CC (Psychic Scream)",
        [12] = "Dispel (Dispel Magic)" },
    SHAMAN  = { [7] = "Interrupt (Earth Shock)", [8] = "Defensive (Totem)", [10] = "Mobility (Ghost Wolf)",
        [12] = "Dispel (Purge, Cure)" },
    MAGE    = { [7] = "Interrupt (Counterspell)", [8] = "Defensive (Ice Block)", [10] = "Mobility (Blink)",
        [11] = "CC (Polymorph)", [12] = "Utility (Remove Curse)" },
    WARLOCK = { [7] = "Interrupt (Spell Lock)", [8] = "Defensive (Death Coil)", [11] = "CC (Fear)",
        [12] = "Utility (Healthstone)" },
    DRUID   = { [7] = "Interrupt (Bash)", [8] = "Defensive (Barkskin)", [9] = "Main cooldown (Innervate)",
        [10] = "Mobility (Dash)", [11] = "CC (Roots)", [12] = "Dispel (Remove Curse)" },
}

-- Layers: modifier + binding command prefix. Button number 1-12 is appended at the end.
-- ACTIONBUTTON = main bar (bar 1), MULTIACTIONBAR1 = bottom left (bar 2), MULTIACTIONBAR2 = bottom right (bar 3)
B.layers = {
    { modifier = "",       prefix = "ACTIONBUTTON",           bar = "Bar 1" },
    { modifier = "SHIFT-", prefix = "MULTIACTIONBAR1BUTTON",  bar = "Bar 2" },
    { modifier = "CTRL-",  prefix = "MULTIACTIONBAR2BUTTON",  bar = "Bar 3" },
}

-- Stance / form keys (SHAPESHIFTBUTTON1-10 = Blizzard's stance bar). Per movement setup.
-- Only classes with a stance bar get them (see `stance` in Data/Classes.lua).
-- WASD: SHIFT-1/2/3 become stances, so bar 2 buttons 1-3 move to the keys in B.stanceRelocate.
-- ESDF: the 1 key is free in every layer (it's not a base key), so 1 / SHIFT-1 / CTRL-1 are the stances.
B.stance = {
    WASD = {
        { key = "SHIFT-1", command = "SHAPESHIFTBUTTON1" },
        { key = "SHIFT-2", command = "SHAPESHIFTBUTTON2" },
        { key = "SHIFT-3", command = "SHAPESHIFTBUTTON3" },
    },
    ESDF = {
        { key = "1",       command = "SHAPESHIFTBUTTON1" },
        { key = "SHIFT-1", command = "SHAPESHIFTBUTTON2" },
        { key = "CTRL-1",  command = "SHAPESHIFTBUTTON3" },
    },
}

-- Which classes have a stance/form/aura bar or a pet bar: see `stance` and `pet` in Data/Classes.lua.

-- Pet keys for pet classes (BONUSACTIONBUTTON1-10 = the pet bar: 1 Attack, 2 Follow, 3 Stay)
B.pet = {
    ESDF = {
        { key = "5",       command = "BONUSACTIONBUTTON1", role = "Pet attack" },
        { key = "SHIFT-5", command = "BONUSACTIONBUTTON2", role = "Pet follow" },
        { key = "CTRL-5",  command = "BONUSACTIONBUTTON3", role = "Pet stay" },
    },
    WASD = {
        { key = "T",       command = "BONUSACTIONBUTTON1", role = "Pet attack" },
        { key = "CTRL-T",  command = "BONUSACTIONBUTTON2", role = "Pet follow" },
        { key = "CTRL-G",  command = "BONUSACTIONBUTTON3", role = "Pet stay" },
    },
}

-- Bar buttons that lost their key to a stance key get a new key here (free keys: WASD = G, V, T).
-- Key = the key that was taken, value = replacement key for the same bar button.
B.stanceRelocate = {
    WASD = {
        ["SHIFT-1"] = "SHIFT-G",
        ["SHIFT-2"] = "SHIFT-V",
        ["SHIFT-3"] = "SHIFT-T",
    },
    ESDF = {},
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
