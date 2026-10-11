-- MLZ UI: Fixed column for RestedXP Guides (Modules/RXP.lua)
--
-- All the small RXP boxes are stacked in one column on the right side of the screen, top to bottom:
--   arrow  ->  active steps  ->  party steps  ->  active targets  ->  active items
-- Only the boxes that are visible take up space, so the column closes up by itself and nothing overlaps.
-- Boxes are right-aligned, so they always line up along the same edge.
--
-- Position (UIParent units, same as Data/Layout.lua, the screen is 1200 units tall):
--   Bars 4-5 sit at the right edge (4..72 units in), so the column starts 84 units in.
--   300 units down is below the minimap and the buffs/debuffs, and above the damage meter in the corner.
--   Everything is clear of the middle of the screen and of the bottom center.

local _, ns = ...

ns.data.rxp = {
    point = "TOPRIGHT",   -- the column's anchor on the screen (the top right corner of the column)
    x = -84,
    y = -300,
    width = 240,          -- width of the step boxes (the other boxes size themselves)
    gap = 6,              -- space between the boxes
    arrowExtra = 18,      -- the distance text hangs under the arrow
}
