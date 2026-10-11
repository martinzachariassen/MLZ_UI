-- MLZ UI: CVar table
-- Edit freely. Each row:
--   name    = CVar name (checked with C_CVar.GetCVarInfo before use, unknown ones are skipped)
--   value   = desired value (string or number)
--   label   = short text in the setup wizard
--   desc    = explanation (tooltip)
--   enabled = preselected in the setup wizard? (the user can toggle each row)
--   choices = (optional) list of values to cycle through on click

local _, ns = ...

ns.data.cvars = {
    -- Loot and interaction
    { name = "autoLootDefault", value = "1", label = "Auto loot", enabled = true,
      desc = "Picks up all loot automatically without Shift-click." },
    { name = "autoSelfCast", value = "1", label = "Auto self-cast", enabled = true,
      desc = "Helpful spells are cast on yourself if you have no friendly target." },
    { name = "autoDismountFlying", value = "1", label = "Auto dismount (flying)", enabled = true,
      desc = "Dismounts from a flying mount when you cast a spell." },
    { name = "autoClearAFK", value = "1", label = "Clear AFK automatically", enabled = true,
      desc = "Removes AFK status when you start playing again." },

    -- Combat
    { name = "ActionButtonUseKeyDown", value = "1", label = "Cast on key down", enabled = true,
      desc = "Spells fire when the key is pressed, not when it is released. Faster response." },
    { name = "SpellQueueWindow", value = "200", label = "Spell queue window (ms)", enabled = false,
      choices = { "100", "150", "200", "250", "300", "400" },
      desc = "How early you can press the next spell before the previous one finishes. Default 400. Lower = more precise, requires low ping. Click the value to change it." },

    -- Camera
    { name = "cameraDistanceMaxZoomFactor", value = "2.6", label = "Max camera zoom", enabled = true,
      desc = "Lets you zoom further out. The client may cap the value." },

    -- Nameplates
    { name = "nameplateShowEnemies", value = "1", label = "Enemy nameplates", enabled = true,
      desc = "Shows nameplates above enemies." },
    { name = "nameplateShowFriends", value = "0", label = "Hide friendly nameplates", enabled = true,
      desc = "Hides nameplates above friendly players and NPCs." },

    -- Sound and noise
    { name = "Sound_EnableErrorSpeech", value = "0", label = "Disable error speech", enabled = true,
      desc = "Removes the voice that says 'Not enough mana', 'Out of range' etc." },
    { name = "showTutorials", value = "0", label = "Disable tutorials", enabled = true,
      desc = "Hides tutorial popups." },

    -- Development
    { name = "scriptErrors", value = "1", label = "Show Lua errors (development)", enabled = false,
      desc = "Shows Lua errors on screen. Useful while testing the addon." },
}
