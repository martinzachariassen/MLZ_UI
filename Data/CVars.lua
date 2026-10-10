-- MLZ UI: CVar-tabell
-- Rediger fritt. Hver rad:
--   name    = CVar-navn (sjekkes med C_CVar.GetCVarInfo før bruk, ukjente hoppes over)
--   value   = ønsket verdi (string eller tall)
--   label   = kort tekst i veiviseren
--   desc    = forklaring (tooltip)
--   enabled = forhåndsvalgt i veiviseren? (brukeren kan slå av/på hver rad)
--   choices = (valgfritt) liste med verdier som kan bla gjennom ved klikk

local _, ns = ...

ns.data.cvars = {
    -- Loot og interaksjon
    { name = "autoLootDefault", value = "1", label = "Auto loot", enabled = true,
      desc = "Plukker opp alt loot automatisk uten Shift-klikk." },
    { name = "autoSelfCast", value = "1", label = "Auto self-cast", enabled = true,
      desc = "Hjelpende spells kastes på deg selv hvis du ikke har et vennlig mål." },
    { name = "autoDismountFlying", value = "1", label = "Auto dismount (flygende)", enabled = true,
      desc = "Hopper av flygende mount når du kaster en spell." },
    { name = "autoClearAFK", value = "1", label = "Fjern AFK automatisk", enabled = true,
      desc = "Fjerner AFK-status når du begynner å spille igjen." },

    -- Kamp
    { name = "ActionButtonUseKeyDown", value = "1", label = "Cast på tastenedtrykk", enabled = true,
      desc = "Spells aktiveres når tasten trykkes ned, ikke når den slippes. Raskere respons." },
    { name = "SpellQueueWindow", value = "200", label = "Spell queue-vindu (ms)", enabled = false,
      choices = { "100", "150", "200", "250", "300", "400" },
      desc = "Hvor tidlig du kan trykke neste spell før forrige er ferdig. Standard 400. Lavere = mer presis, krever lav ping. Klikk verdien for å bytte." },

    -- Kamera
    { name = "cameraDistanceMaxZoomFactor", value = "2.6", label = "Maks kamerazoom", enabled = true,
      desc = "Lar deg zoome lenger ut. Klienten kan begrense verdien." },

    -- Nameplates
    { name = "nameplateShowEnemies", value = "1", label = "Fiende-nameplates", enabled = true,
      desc = "Viser nameplates over fiender." },
    { name = "nameplateShowFriends", value = "0", label = "Skjul venn-nameplates", enabled = true,
      desc = "Skjuler nameplates over vennlige spillere og NPC-er." },

    -- Lyd og støy
    { name = "Sound_EnableErrorSpeech", value = "0", label = "Skru av feil-stemme", enabled = true,
      desc = "Fjerner stemmen som sier 'Not enough mana', 'Out of range' osv." },
    { name = "showTutorials", value = "0", label = "Skru av tutorials", enabled = true,
      desc = "Skjuler tutorial-popups." },

    -- Utvikling
    { name = "scriptErrors", value = "1", label = "Vis Lua-feil (utvikling)", enabled = false,
      desc = "Viser Lua-feil på skjermen. Nyttig mens vi tester addonen." },
}
