-- MLZ UI: Kategorier for auto-baren med forbruksvarer
-- Rediger fritt. Logikken ligger i Modules/Consumables.lua.
--
-- Baren viser én knapp per kategori (den beste du har i bagen) i rekkefølgen under.
-- Kategorier uten noe i bagen skjules. "Beste" = høyest påkrevd nivå / item level, og conjured
-- (mage-laget) foretrekkes ved likt nivå, siden det forsvinner når du logger ut.
--
-- Felter:
--   id, label   = intern id og navn i tooltip
--   max         = antall knapper kategorien kan bruke (standard 1, f.eks. 2 for elixirs)
--   ids         = faste item-ID-er (healthstone, mana gems)
--   class/sub   = itemklasse / underklasse (0 = Consumable: 1 Potion, 2 Elixir, 3 Flask, 4 Scroll,
--                 5 Food & Drink, 7 Bandage)
--   match       = funksjon(info) -> true/false. info har name, spell (navnet på "Use"-spellen) og
--                 text (all tooltip-tekst, små bokstaver)

local _, ns = ...

local HEALTHSTONES = { 5512, 19004, 19005, 5511, 19006, 19007, 5509, 19008, 19009, 5510, 19010, 19011, 9421, 19012, 19013 }
local MANA_GEMS = { 5514, 5513, 8007, 8008 }

local function IsDrink(i)
    return (i.spell and i.spell:find("Drink")) or (i.text:find("mana") and not i.text:find("health"))
end
local function IsWellFed(i) return i.text:find("well fed") ~= nil end

ns.data.consumables = {
    { id = "food", label = "Mat (health)", class = 0, sub = 5,
      match = function(i) return not IsDrink(i) and not IsWellFed(i) end },
    { id = "drink", label = "Drikke (mana)", class = 0, sub = 5,
      match = function(i) return IsDrink(i) and not IsWellFed(i) end },
    { id = "buffFood", label = "Buff-mat (Well Fed)", class = 0, sub = 5,
      match = IsWellFed },
    { id = "healthPotion", label = "Healing potion", class = 0, sub = 1,
      match = function(i) return i.text:find("restores %d+ to %d+ health") ~= nil end },
    { id = "manaPotion", label = "Mana potion", class = 0, sub = 1,
      match = function(i) return i.text:find("restores %d+ to %d+ mana") ~= nil and not i.text:find("health") end },
    { id = "healthstone", label = "Healthstone", ids = HEALTHSTONES },
    { id = "manaGem", label = "Mana gem", ids = MANA_GEMS },
    { id = "bandage", label = "Bandage", class = 0, sub = 7,
      altMatch = function(i) return i.name:find("Bandage") ~= nil end },
    { id = "elixir", label = "Elixir / flask / scroll / annen potion", max = 3,
      match = function(i)
          if i.classID ~= 0 then return false end
          if i.subID == 2 or i.subID == 3 or i.subID == 4 then return true end
          -- Potions som ikke er healing/mana (Swiftness, Free Action, Rage osv.)
          return i.subID == 1 and not i.text:find("restores %d+ to %d+ health")
              and not i.text:find("restores %d+ to %d+ mana")
      end },
}
