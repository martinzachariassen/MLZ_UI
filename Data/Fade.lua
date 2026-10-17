-- MLZ UI: What gets hidden and when
-- Edit freely. The logic lives in Modules/Fade.lua.
--
-- mode:
--   "mouseover"    = invisible until you hover the mouse over it
--   "combat"       = visible in combat, with a target or on mouseover, otherwise dimmed to `alpha`
--   "hideInCombat" = visible out of combat, hidden in combat (except on mouseover)
--   "group"        = visible in a party or raid (or on mouseover), invisible when solo
-- frames = Blizzard frame names. All that exist in the client are affected (unknown names are ignored).
--          Mousing over one of them shows the whole group.
-- Everything is fully shown while Edit Mode is open.

local _, ns = ...

ns.data.fade = {
    { id = "bar45", label = "Bars 4 and 5", mode = "mouseover", enabled = true,
      frames = { "MultiBarRight", "MultiBarLeft" },
      desc = "Rarely used bars on the right edge, shown on mouseover. Keys bound to them (such as the extra "
          .. "keys for forms and stances on bar 5) still work while they are hidden." },
    { id = "micro", label = "Micro menu", mode = "mouseover", enabled = true,
      frames = { "MicroMenuContainer", "MicroMenu" },
      desc = "The character, spellbook etc. buttons. You still have the keys (C, P, N ... or the Alt variant)." },
    { id = "bags", label = "Bag buttons", mode = "mouseover", enabled = true,
      frames = { "BagsBar" },
      desc = "The bag icons. B opens all bags anyway." },
    { id = "meter", label = "Damage meter (only in a group)", mode = "group", enabled = true,
      frames = { "DamageMeter" },
      desc = "Hidden when you are solo, shown in a party or raid. Hover over where it sits to peek at it solo." },
    { id = "bar23", label = "Bars 2 and 3 (out of combat)", mode = "combat", alpha = 0.25, enabled = true,
      frames = { "MultiBarBottomLeft", "MultiBarBottomRight" },
      desc = "Dimmed when you are out of combat with no target. Fully visible in combat or on mouseover." },
    { id = "tracker", label = "Quest tracker in combat", mode = "hideInCombat", enabled = true,
      frames = { "ObjectiveTrackerFrame", "QuestWatchFrame" },
      desc = "Hides the quest list in combat, so you can see the fight (and boss frames) better." },
    { id = "player", label = "Player frame (out of combat)", mode = "combat", alpha = 0.3, enabled = false,
      frames = { "PlayerFrame" },
      desc = "Dimmed when you are out of combat with no target." },
    { id = "xp", label = "XP/rep bar", mode = "mouseover", enabled = false,
      frames = { "StatusTrackingBarManager", "MainStatusTrackingBarContainer" },
      desc = "The XP bar is only shown on mouseover." },
    { id = "chatbuttons", label = "Chat buttons", mode = "mouseover", enabled = true,
      frames = { "ChatFrameMenuButton", "ChatFrameChannelButton", "QuickJoinToastButton", "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton" },
      desc = "The buttons next to chat are only shown on mouseover." },
}

-- Chat behavior
ns.data.chat = {
    fadeAfter = 20,        -- seconds before old chat lines fade out
    hideTabs = true,       -- chat tabs invisible until mouseover
    hideBackground = true, -- no dark background behind chat
}
