-- MLZ UI: Hva som skjules og når
-- Rediger fritt. Logikken ligger i Modules/Fade.lua.
--
-- mode:
--   "mouseover"    = usynlig til du holder musen over
--   "combat"       = synlig i kamp, med target eller ved mouseover, ellers dempet til `alpha`
--   "hideInCombat" = synlig utenfor kamp, skjult i kamp (unntatt mouseover)
-- frames = Blizzard-framenavn. Alle som finnes i klienten påvirkes (ukjente navn ignoreres).
--          Mouseover over én av dem viser hele gruppen.
-- Alt vises fullt mens Edit Mode er åpen.

local _, ns = ...

ns.data.fade = {
    { id = "bar45", label = "Bar 4 og 5", mode = "mouseover", enabled = true,
      frames = { "MultiBarRight", "MultiBarLeft" },
      desc = "Sjeldent brukte barer. Vises når du holder musen over dem nede til høyre." },
    { id = "micro", label = "Micro menu", mode = "mouseover", enabled = true,
      frames = { "MicroMenuContainer", "MicroMenu" },
      desc = "Knappene for karakter, spellbook osv. Du har tastene uansett (C, P, N ... eller Alt-varianten)." },
    { id = "bags", label = "Bag-knapper", mode = "mouseover", enabled = true,
      frames = { "BagsBar" },
      desc = "Bag-ikonene. B åpner alle bags uansett." },
    { id = "bar23", label = "Bar 2 og 3 (utenfor kamp)", mode = "combat", alpha = 0.25, enabled = true,
      frames = { "MultiBarBottomLeft", "MultiBarBottomRight" },
      desc = "Dempes når du ikke er i kamp og ikke har target. Full synlighet i kamp eller ved mouseover." },
    { id = "tracker", label = "Quest tracker i kamp", mode = "hideInCombat", enabled = true,
      frames = { "ObjectiveTrackerFrame", "QuestWatchFrame" },
      desc = "Skjuler quest-listen i kamp, så du ser kampen (og boss frames) bedre." },
    { id = "player", label = "Player frame (utenfor kamp)", mode = "combat", alpha = 0.3, enabled = false,
      frames = { "PlayerFrame" },
      desc = "Dempes når du ikke er i kamp og ikke har target." },
    { id = "xp", label = "XP/rep-bar", mode = "mouseover", enabled = false,
      frames = { "StatusTrackingBarManager", "MainStatusTrackingBarContainer" },
      desc = "XP-baren vises bare ved mouseover." },
    { id = "chatbuttons", label = "Chat-knapper", mode = "mouseover", enabled = true,
      frames = { "ChatFrameMenuButton", "ChatFrameChannelButton", "QuickJoinToastButton", "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton" },
      desc = "Knappene ved siden av chatten vises bare ved mouseover." },
}

-- Chat-oppførsel
ns.data.chat = {
    fadeAfter = 20,        -- sekunder før gamle chat-linjer fader ut
    hideTabs = true,       -- chat-faner usynlige til mouseover
    hideBackground = true, -- ingen mørk bakgrunn bak chatten
}
