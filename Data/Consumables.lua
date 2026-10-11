-- MLZ UI: Categories for the consumables auto bar
-- Edit freely. The logic lives in Modules/Consumables.lua.
--
-- The bar shows one button per category (the best one in your bags) in the order below.
-- Categories with nothing in your bags are hidden. "Best" = highest required level / item level, and conjured
-- (mage-made) is preferred at equal level, since it disappears when you log out.
--
-- Fields:
--   id, label   = internal id and name in tooltip
--   max         = number of buttons the category can use (default 1, e.g. 2 for elixirs)
--   ids         = fixed item IDs (healthstone, mana gems)
--   class/sub   = item class / subclass (0 = Consumable: 1 Potion, 2 Elixir, 3 Flask, 4 Scroll,
--                 5 Food & Drink, 7 Bandage)
--   match       = function(info) -> true/false. info has name, spell (name of the "Use" spell) and
--                 text (all tooltip text, lowercase)

local _, ns = ...

local HEALTHSTONES = { 5512, 19004, 19005, 5511, 19006, 19007, 5509, 19008, 19009, 5510, 19010, 19011, 9421, 19012, 19013 }
local MANA_GEMS = { 5514, 5513, 8007, 8008 }

local function IsDrink(i)
    return (i.spell and i.spell:find("Drink")) or (i.text:find("mana") and not i.text:find("health"))
end
local function IsWellFed(i) return i.text:find("well fed") ~= nil end

ns.data.consumables = {
    { id = "food", label = "Food (health)", class = 0, sub = 5,
      match = function(i) return not IsDrink(i) and not IsWellFed(i) end },
    { id = "drink", label = "Drink (mana)", class = 0, sub = 5,
      match = function(i) return IsDrink(i) and not IsWellFed(i) end },
    { id = "buffFood", label = "Buff food (Well Fed)", class = 0, sub = 5,
      match = IsWellFed },
    { id = "healthPotion", label = "Healing potion", class = 0, sub = 1,
      match = function(i) return i.text:find("restores %d+ to %d+ health") ~= nil end },
    { id = "manaPotion", label = "Mana potion", class = 0, sub = 1,
      match = function(i) return i.text:find("restores %d+ to %d+ mana") ~= nil and not i.text:find("health") end },
    { id = "healthstone", label = "Healthstone", ids = HEALTHSTONES },
    { id = "manaGem", label = "Mana gem", ids = MANA_GEMS },
    { id = "bandage", label = "Bandage", class = 0, sub = 7,
      altMatch = function(i) return i.name:find("Bandage") ~= nil end },
    { id = "elixir", label = "Elixir / flask / scroll / other potion", max = 3,
      match = function(i)
          if i.classID ~= 0 then return false end
          if i.subID == 2 or i.subID == 3 or i.subID == 4 then return true end
          -- Potions that aren't healing/mana (Swiftness, Free Action, Rage etc.)
          return i.subID == 1 and not i.text:find("restores %d+ to %d+ health")
              and not i.text:find("restores %d+ to %d+ mana")
      end },
}
