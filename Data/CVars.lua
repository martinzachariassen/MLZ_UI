-- MLZ UI: CVar table
-- Edit freely. Each row:
--   name    = CVar name (checked with C_CVar.GetCVarInfo before use, unknown ones are skipped)
--   value   = desired value (string or number)
--   label   = short text in the setup wizard
--   desc    = explanation (tooltip)
--   enabled = preselected in the setup wizard? (the user can toggle each row)
--   choices = (optional) list of values to cycle through on click
--   group   = heading in the wizard (rows are listed in the order of this file, so keep a group together)
--   text    = (optional) plain words for the raw values, e.g. { ["0"] = "unlocked", ["1"] = "locked" }.
--             Rows that only switch between 0 and 1 show "off" and "on" by default; set numeric = true to opt out.
--   behaviour = true: changes how the game plays, not how it looks (amber in the wizard)

local _, ns = ...

ns.data.cvars = {
    -- Loot and interaction
    { name = "autoLootDefault", value = "1", label = "Auto loot", enabled = true, group = "Loot and interaction",
      desc = "Picks up all loot automatically without SHIFT-click." },
    { name = "autoSelfCast", value = "1", label = "Auto self-cast", enabled = true, group = "Loot and interaction",
      behaviour = true,
      desc = "Helpful spells are cast on yourself if you have no friendly target." },
    { name = "autoDismountFlying", value = "1", label = "Auto dismount (flying)", enabled = true, group = "Loot and interaction",
      desc = "Dismounts from a flying mount when you cast a spell." },
    { name = "autoClearAFK", value = "1", label = "Clear AFK automatically", enabled = true, group = "Loot and interaction",
      desc = "Removes AFK status when you start playing again." },
    { name = "lootUnderMouse", value = "1", label = "Loot window at the mouse", enabled = true, group = "Loot and interaction",
      desc = "Opens the loot window where your mouse is, so you don't have to move across the screen." },
    { name = "instantQuestText", value = "1", label = "Instant quest text", enabled = true, group = "Loot and interaction",
      desc = "Shows the whole quest text at once instead of letter by letter." },
    { name = "autoQuestWatch", value = "1", label = "Track new quests", enabled = true, group = "Loot and interaction",
      desc = "Adds a quest to the tracker when you accept it, so you can see what is left." },
    { name = "interactOnLeftClick", value = "0", label = "Left click only targets", enabled = false, group = "Loot and interaction",
      text = { ["0"] = "targets only", ["1"] = "interacts" },
      desc = "Left click selects an NPC without talking to it or attacking. Right click still interacts. Personal taste, off by default." },
    { name = "deselectOnClick", value = "0", label = "Sticky targeting", enabled = false, group = "Loot and interaction",
      text = { ["0"] = "keeps target", ["1"] = "clears target" },
      desc = "Clicking empty ground no longer clears your target. Only a new target or ESC does. Personal taste, off by default." },

    -- Combat
    { name = "ActionButtonUseKeyDown", value = "1", label = "Cast on key down", enabled = true, group = "Combat",
      behaviour = true,
      desc = "Spells fire when the key is pressed, not when it is released. Faster response." },
    { name = "SpellQueueWindow", value = "200", label = "Spell queue window (ms)", enabled = false, group = "Combat",
      choices = { "100", "150", "200", "250", "300", "400" },
      desc = "How early you can press the next spell before the previous one finishes. Default 400. Lower = more precise, requires low ping. Click the value to change it." },

    -- Unit frames: read the numbers instead of guessing from the bar
    { name = "statusText", value = "1", label = "Health and mana as text", enabled = true, group = "Unit frames",
      desc = "Shows health and mana as text on your unit frames (older clients)." },
    { name = "statusTextDisplay", value = "NUMERIC", label = "Health and mana text", enabled = true, group = "Unit frames",
      choices = { "NUMERIC", "PERCENT", "BOTH" },
      desc = "Shows health and mana on your unit frames as numbers, percent or both. Click the value to change it." },
    { name = "breakUpLargeNumbers", value = "1", label = "Readable large numbers", enabled = true, group = "Unit frames",
      desc = "Writes 12,345 instead of 12345." },
    { name = "showTargetOfTarget", value = "1", label = "Target of target", enabled = true, group = "Unit frames",
      desc = "Shows who your target is targeting. On an enemy, that is who it is attacking." },
    { name = "showTargetCastbar", value = "1", label = "Target cast bar", enabled = true, group = "Unit frames",
      desc = "Shows what your target is casting under the target frame, so you know when to interrupt." },
    { name = "showVKeyCastbar", value = "1", label = "Cast bar above the target", enabled = true, group = "Unit frames",
      desc = "Shows your target's cast bar above its head as well." },
    { name = "buffDurations", value = "1", label = "Buff durations", enabled = true, group = "Unit frames",
      desc = "Shows the time left under each buff and debuff on your character." },
    { name = "xpBarText", value = "1", label = "XP numbers always visible", enabled = true, group = "Unit frames",
      desc = "Shows XP as numbers on the XP bar without hovering it." },

    -- Action bars
    { name = "lockActionBars", value = "0", label = "Unlock action bars", enabled = false, group = "Action bars",
      behaviour = true, text = { ["0"] = "unlocked", ["1"] = "locked" },
      desc = "Keeps all action bars unlocked so you can drag spells and items around freely, without holding SHIFT." },

    -- Cooldowns
    { name = "countdownForCooldowns", value = "1", label = "Cooldown numbers on buttons", enabled = true, group = "Action bars",
      desc = "Shows the remaining cooldown time as a number on your action buttons, in addition to the sweep animation." },

    -- Camera
    { name = "cameraDistanceMaxZoomFactor", value = "2.6", label = "Max camera zoom", enabled = true, group = "Camera",
      desc = "Lets you zoom further out. The client may cap the value." },

    -- Combat text: small, calm numbers rising above the target
    { name = "floatingCombatTextCombatDamage", value = "1", label = "Damage numbers", enabled = true, group = "Combat text",
      desc = "Floating numbers for damage you deal (and take)." },
    { name = "floatingCombatTextCombatHealing", value = "1", label = "Healing numbers", enabled = true, group = "Combat text",
      desc = "Floating numbers for healing you give and receive." },
    { name = "floatingCombatTextFloatMode", value = "1", label = "Numbers rise upward", enabled = true, group = "Combat text",
      desc = "Numbers float straight up instead of arcing or falling." },
    { name = "floatingCombatTextCombatDamageDirectionalScale", value = "0", label = "No sideways scatter", enabled = true, group = "Combat text",
      text = { ["0"] = "no scatter", ["1"] = "scatter" },
      desc = "Keeps numbers from flying out to the sides, so the middle of the screen stays calm." },
    { name = "WorldTextScale", value = "0.7", label = "Combat text size", enabled = true, group = "Combat text",
      choices = { "0.5", "0.6", "0.7", "0.8", "1" },
      desc = "Size of floating numbers. Default 1. Click the value to change it." },
    { name = "WorldTextGravity", value = "0.5", label = "Combat text gravity", enabled = true, group = "Combat text",
      desc = "How fast numbers move away. Lower = calmer." },
    { name = "floatingCombatTextReactives", value = "1", label = "Reactive ability alerts", enabled = true, group = "Combat text",
      desc = "Short text when a reactive ability becomes usable, like Overpower or Revenge." },

    -- Nameplates (stacking and friendly plates are handled by Platynator, see the Nameplates page)
    { name = "nameplateMaxDistance", value = "41", label = "Nameplate distance", enabled = true, group = "Nameplates",
      desc = "How far away you see nameplates (yards). This client allows at most 41; a higher value is lowered to the client's limit." },
    { name = "nameplateShowEnemies", value = "1", label = "Enemy nameplates", enabled = true, group = "Nameplates",
      desc = "Shows nameplates above enemies." },

    -- Raid and party frames. Rows with `roles` are only ticked by default for that role
    -- (the role comes from your talents, see /mlz heal). Unknown CVars are skipped.
    { name = "raidFramesDisplayOnlyDispellableDebuffs", value = "1", label = "Raid frames: only debuffs you can dispel", enabled = true, group = "Raid and party frames",
      roles = { HEALER = true },
      desc = "Raid frames only show debuffs you can remove, so the ones that matter stand out." },
    { name = "raidFramesDisplayPowerBars", value = "1", label = "Raid frames: power bars", enabled = true, group = "Raid and party frames",
      roles = { HEALER = true },
      desc = "Shows mana, rage or energy under each raid frame, so you can see who is out of mana." },
    { name = "raidFramesDisplayAggroHighlight", value = "1", label = "Raid frames: aggro highlight", enabled = true, group = "Raid and party frames",
      desc = "Red border on raid frames of players who have aggro." },
    { name = "raidFramesDisplayClassColor", value = "1", label = "Raid frames: class colors", enabled = true, group = "Raid and party frames",
      desc = "Colors raid frame health bars by class." },
    { name = "raidFramesDisplayIncomingHeals", value = "1", label = "Raid frames: incoming heals", enabled = true, group = "Raid and party frames",
      roles = { HEALER = true },
      desc = "Shows heals that are on the way, so you don't overheal." },

    -- Threat
    { name = "threatWarning", value = "3", label = "Threat warning", enabled = true, group = "Threat",
      roles = { TANK = true },
      desc = "Warns when you are about to lose (or gain) aggro. 3 = always." },
    { name = "threatShowNumeric", value = "1", label = "Threat percent on target", enabled = true, group = "Threat",
      roles = { TANK = true },
      desc = "Shows your threat as a percent on the target frame." },

    -- Screen effects
    { name = "doNotFlashLowHealthWarning", value = "1", label = "Disable low health flash", enabled = true, group = "Screen effects",
      text = { ["0"] = "flashing", ["1"] = "no flash" },
      desc = "Turns off the pulsing red screen edge when your health is low." },
    { name = "ffxGlow", value = "0", label = "Disable full screen glow", enabled = false, group = "Screen effects",
      text = { ["0"] = "no glow", ["1"] = "glow" },
      desc = "Removes the soft bloom over the whole screen. Sharper image and a little more FPS. Personal taste, off by default." },
    { name = "cameraReduceUnexpectedMovement", value = "1", label = "Calmer camera", enabled = false, group = "Screen effects",
      desc = "Reduces camera movement you didn't cause, like bobbing and shaking." },

    -- Quality of life
    { name = "autoLootRate", value = "0", label = "Instant auto loot", enabled = true, group = "Quality of life", numeric = true,
      desc = "Removes the delay between auto-looted items." },
    { name = "displayFreeBagSlots", value = "1", label = "Free bag slots on bag icon", enabled = true, group = "Quality of life",
      desc = "Shows the number of free bag slots on the backpack icon." },
    { name = "UnitNameFriendlyPlayerName", value = "1", label = "Friendly player names", enabled = false, group = "Quality of life",
      desc = "Shows names above friendly players." },
    { name = "SoftTargetEnemy", value = "2", label = "Soft target enemies", enabled = false, group = "Quality of life",
      choices = { "0", "2", "3" },
      desc = "Automatically targets the enemy you are facing. 0 = off, 2 = keyboard and mouse, 3 = always (1, the default, is gamepad only). Personal taste, off by default. Click the value to change it." },
    { name = "SoftTargetInteract", value = "2", label = "Soft target interact", enabled = false, group = "Quality of life",
      choices = { "0", "2", "3" },
      desc = "Highlights the NPC or object you can interact with in front of you, so the interact key works on it. 0 = off, 2 = keyboard and mouse, 3 = always. Click the value to change it." },

    -- Sound and noise
    { name = "Sound_EnableAmbience", value = "0", label = "Mute ambience", enabled = false, group = "Sound and noise",
      text = { ["0"] = "muted", ["1"] = "playing" },
      desc = "Turns off background ambience sounds." },
    { name = "Sound_EnableMusic", value = "0", label = "Mute music", enabled = false, group = "Sound and noise",
      text = { ["0"] = "muted", ["1"] = "playing" },
      desc = "Turns off game music." },
    { name = "Sound_EnableSoundWhenGameIsInBg", value = "1", label = "Sound in the background", enabled = true, group = "Sound and noise",
      desc = "Keeps game sound on when you tab out, so you still hear ready checks, whispers and queue pops." },
    { name = "Sound_EnableErrorSpeech", value = "0", label = "Disable error speech", enabled = true, group = "Sound and noise",
      text = { ["0"] = "silent", ["1"] = "spoken" },
      desc = "Removes the voice that says 'Not enough mana', 'Out of range' etc." },
    { name = "showTutorials", value = "0", label = "Disable tutorials", enabled = false, group = "Sound and noise",
      text = { ["0"] = "hidden", ["1"] = "shown" },
      behaviour = true,
      desc = "Hides tutorial popups." },

    -- Development
    { name = "scriptErrors", value = "1", label = "Show Lua errors (development)", enabled = false, group = "Development",
      desc = "Shows Lua errors on screen. Useful while testing the addon." },
}

-- One muted line under each group heading in the wizard: why these settings are here
ns.data.cvarGroups = {
    ["Loot and interaction"] = "Faster looting and fewer clicks. None of this changes how fights work.",
    ["Combat"] = "How fast spells respond to your keys.",
    ["Unit frames"] = "Read health, mana and buffs as numbers instead of guessing from the bars.",
    ["Action bars"] = "How your bars behave, and cooldown numbers on the buttons.",
    ["Camera"] = "How far you can zoom out.",
    ["Combat text"] = "Small, calm damage and healing numbers above targets.",
    ["Nameplates"] = "How far away you see the bars above enemies.",
    ["Raid and party frames"] = "Healers get the extra healing info ticked by default.",
    ["Threat"] = "Warnings that help tanks keep aggro. Ticked for tanks.",
    ["Screen effects"] = "Removes screen flashes and glow. Mostly personal taste.",
    ["Quality of life"] = "Small conveniences. Soft targeting is off by default.",
    ["Sound and noise"] = "Mute what you do not want to hear.",
    ["Development"] = "For testing the addon only.",
}
