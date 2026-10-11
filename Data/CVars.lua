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

    -- Action bars
    { name = "lockActionBars", value = "0", label = "Unlock action bars", enabled = true,
      desc = "Keeps all action bars unlocked so you can drag spells and items around freely, without holding Shift." },

    -- Cooldowns
    { name = "countdownForCooldowns", value = "1", label = "Cooldown numbers on buttons", enabled = true,
      desc = "Shows the remaining cooldown time as a number on your action buttons, in addition to the sweep animation." },

    -- Camera
    { name = "cameraDistanceMaxZoomFactor", value = "2.6", label = "Max camera zoom", enabled = true,
      desc = "Lets you zoom further out. The client may cap the value." },

    -- Combat text: small, calm numbers rising above the target
    { name = "floatingCombatTextCombatDamage", value = "1", label = "Damage numbers", enabled = true,
      desc = "Floating numbers for damage you deal (and take)." },
    { name = "floatingCombatTextCombatHealing", value = "1", label = "Healing numbers", enabled = true,
      desc = "Floating numbers for healing you give and receive." },
    { name = "floatingCombatTextFloatMode", value = "1", label = "Numbers rise upward", enabled = true,
      desc = "Numbers float straight up instead of arcing or falling." },
    { name = "floatingCombatTextCombatDamageDirectionalScale", value = "0", label = "No sideways scatter", enabled = true,
      desc = "Keeps numbers from flying out to the sides, so the middle of the screen stays calm." },
    { name = "WorldTextScale", value = "0.7", label = "Combat text size", enabled = true,
      choices = { "0.5", "0.6", "0.7", "0.8", "1" },
      desc = "Size of floating numbers. Default 1. Click the value to change it." },
    { name = "WorldTextGravity", value = "0.5", label = "Combat text gravity", enabled = true,
      desc = "How fast numbers move away. Lower = calmer." },
    { name = "WorldTextRampDuration", value = "0.8", label = "Combat text duration", enabled = true,
      desc = "How long numbers stay visible while rising." },

    -- Nameplates
    { name = "nameplateMotion", value = "1", label = "Stacking nameplates", enabled = true,
      desc = "Nameplates stack instead of overlapping. Useful in big pulls." },
    { name = "nameplateMaxDistance", value = "60", label = "Nameplate distance", enabled = true,
      desc = "How far away you see nameplates (yards)." },
    { name = "nameplateShowEnemies", value = "1", label = "Enemy nameplates", enabled = true,
      desc = "Shows nameplates above enemies." },
    { name = "nameplateShowFriends", value = "0", label = "Hide friendly nameplates", enabled = true,
      desc = "Hides nameplates above friendly players and NPCs." },

    -- Screen effects
    { name = "doNotFlashLowHealthWarning", value = "1", label = "Disable low health flash", enabled = true,
      desc = "Turns off the pulsing red screen edge when your health is low." },

    -- Quality of life
    { name = "autoLootRate", value = "0", label = "Instant auto loot", enabled = true,
      desc = "Removes the delay between auto-looted items." },
    { name = "displayFreeBagSlots", value = "1", label = "Free bag slots on bag icon", enabled = true,
      desc = "Shows the number of free bag slots on the backpack icon." },
    { name = "UnitNameFriendlyPlayerName", value = "1", label = "Friendly player names", enabled = false,
      desc = "Shows names above friendly players." },
    { name = "SoftTargetEnemy", value = "1", label = "Soft target enemies", enabled = false,
      desc = "Automatically targets the enemy you are facing. Personal taste, off by default." },
    { name = "SoftTargetInteract", value = "1", label = "Soft target interact", enabled = false,
      desc = "Highlights the NPC or object you can interact with in front of you." },

    -- Sound and noise
    { name = "Sound_EnableAmbience", value = "0", label = "Mute ambience", enabled = false,
      desc = "Turns off background ambience sounds." },
    { name = "Sound_EnableMusic", value = "0", label = "Mute music", enabled = false,
      desc = "Turns off game music." },
    { name = "Sound_EnableErrorSpeech", value = "0", label = "Disable error speech", enabled = true,
      desc = "Removes the voice that says 'Not enough mana', 'Out of range' etc." },
    { name = "showTutorials", value = "0", label = "Disable tutorials", enabled = true,
      desc = "Hides tutorial popups." },

    -- Development
    { name = "scriptErrors", value = "1", label = "Show Lua errors (development)", enabled = false,
      desc = "Shows Lua errors on screen. Useful while testing the addon." },
}
