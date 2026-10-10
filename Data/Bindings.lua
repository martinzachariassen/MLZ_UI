-- MLZ UI: Keybind-tabell
-- Rediger fritt. Logikken ligger i Modules/Bindings.lua.
-- Tastenavn følger WoW-formatet: modifiers i rekkefølgen ALT-CTRL-SHIFT-, f.eks. "CTRL-Q", "SHIFT-MOUSEWHEELUP".

local _, ns = ...

local B = {}
ns.data.bindings = B

-- Bevegelsesoppsett. Velges i veiviseren.
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

-- 12 basistaster per bevegelsesoppsett (venstre hånd). Rekkefølgen = knapp 1-12 på baren.
B.baseKeys = {
    ESDF = { "1", "2", "3", "4", "5", "Q", "W", "R", "T", "Z", "X", "C" },
    WASD = { "1", "2", "3", "4", "5", "Q", "E", "R", "F", "Z", "X", "C" },
}

-- Rolle per knapp (vises i veiviseren som hjelp, påvirker ikke bindingen)
B.roles = {
    "Rotasjon", "Rotasjon", "Rotasjon", "Rotasjon", "Rotasjon",
    "Interrupt", "Defensive", "Hoved-cooldown", "Sekundær cooldown",
    "Mobilitet", "CC/utility", "Dispel/utility",
}

-- Lag: modifier + binding-kommando-prefix. Knappnummer 1-12 legges til på slutten.
-- ACTIONBUTTON = hovedbar (bar 1), MULTIACTIONBAR1 = bottom left (bar 2), MULTIACTIONBAR2 = bottom right (bar 3)
B.layers = {
    { modifier = "",       prefix = "ACTIONBUTTON",           bar = "Bar 1" },
    { modifier = "SHIFT-", prefix = "MULTIACTIONBAR1BUTTON",  bar = "Bar 2" },
    { modifier = "CTRL-",  prefix = "MULTIACTIONBAR2BUTTON",  bar = "Bar 3" },
}

-- Mus (ingen ekstra museknapper): modifier + hjul mot bar 4 (MULTIACTIONBAR3 = right bar 1)
B.mouse = {
    { key = "SHIFT-MOUSEWHEELUP",   command = "MULTIACTIONBAR3BUTTON1" },
    { key = "SHIFT-MOUSEWHEELDOWN", command = "MULTIACTIONBAR3BUTTON2" },
    { key = "CTRL-MOUSEWHEELUP",    command = "MULTIACTIONBAR3BUTTON3" },
    { key = "CTRL-MOUSEWHEELDOWN",  command = "MULTIACTIONBAR3BUTTON4" },
}

-- Når en tast vi tar i bruk allerede har en handling, flyttes handlingen til denne modifieren
-- (f.eks. C = Character-panel blir ALT-C), så lenge den nye tasten er ledig og handlingen
-- ikke allerede har en annen tast.
B.displaceModifier = "ALT-"

-- Handlinger som aldri flyttes til ALT (de er uviktige eller erstattes av oppsettet vårt)
B.neverDisplace = {
    TURNLEFT = true, TURNRIGHT = true,     -- erstattes av strafe
    ACTIONPAGE1 = true, ACTIONPAGE2 = true, ACTIONPAGE3 = true,
    ACTIONPAGE4 = true, ACTIONPAGE5 = true, ACTIONPAGE6 = true,
    CAMERAZOOMIN = true, CAMERAZOOMOUT = true,
}
