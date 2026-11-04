-- MLZ UI: Cooking data
-- Which dishes each cooking ingredient goes into. Used by Modules/Cooking.lua for the tooltip line
-- ("Cooking: Roasted Boar Meat (1)"). Turn it on or off in /mlz > Helpers.
-- Generated once from the Classic profession data in AtlasLootClassic (all 81 Classic cooking recipes).
--
-- [ingredient item id] = { { spell, skill, yellow, grey }, ... } sorted by skill
--   spell  = the recipe's spell id (its name is the dish name, localized by the client)
--   skill  = Cooking skill needed to learn it (orange from here)
--   yellow = turns yellow at this skill, grey = turns grey (no more skill-ups)
--   green is halfway between yellow and grey, the same rule the game uses

local _, ns = ...

ns.data.cooking = {
    [159] = {
        { spell = 6499, skill = 50, yellow = 90, grey = 130 }, -- Boiled Clams
        { spell = 9513, skill = 60, yellow = 100, grey = 140 }, -- Thistle Tea
        { spell = 13028, skill = 175, yellow = 215, grey = 255 }, -- Goldthorn Tea
        { spell = 15861, skill = 175, yellow = 215, grey = 255 }, -- Jungle Stew
        { spell = 15910, skill = 200, yellow = 240, grey = 280 }, -- Heavy Kodo Stew
        { spell = 18243, skill = 250, yellow = 290, grey = 330 }, -- Nightfin Soup
        { spell = 18245, skill = 275, yellow = 315, grey = 355 }, -- Lobster Stew
    },
    [723] = {
        { spell = 2542, skill = 50, yellow = 90, grey = 130 }, -- Goretusk Liver Pie
    },
    [729] = {
        { spell = 2543, skill = 75, yellow = 115, grey = 155 }, -- Westfall Stew
    },
    [730] = {
        { spell = 2543, skill = 75, yellow = 115, grey = 155 }, -- Westfall Stew
    },
    [731] = {
        { spell = 2543, skill = 75, yellow = 115, grey = 155 }, -- Westfall Stew
    },
    [769] = {
        { spell = 2540, skill = 1, yellow = 45, grey = 85 }, -- Roasted Boar Meat
    },
    [1015] = {
        { spell = 2549, skill = 100, yellow = 140, grey = 180 }, -- Seasoned Wolf Kabob
        { spell = 15853, skill = 125, yellow = 165, grey = 205 }, -- Lean Wolf Steak
    },
    [1080] = {
        { spell = 2547, skill = 100, yellow = 135, grey = 175 }, -- Redridge Goulash
    },
    [1081] = {
        { spell = 2547, skill = 100, yellow = 135, grey = 175 }, -- Redridge Goulash
    },
    [1179] = {
        { spell = 21144, skill = 35, yellow = 75, grey = 115 }, -- Egg Nog
        { spell = 6501, skill = 90, yellow = 130, grey = 170 }, -- Clam Chowder
        { spell = 20626, skill = 225, yellow = 265, grey = 305 }, -- Undermine Clam Chowder
    },
    [1468] = {
        { spell = 3372, skill = 90, yellow = 130, grey = 170 }, -- Murloc Fin Soup
    },
    [2251] = {
        { spell = 3377, skill = 110, yellow = 150, grey = 190 }, -- Gooey Spider Cake
    },
    [2452] = {
        { spell = 9513, skill = 60, yellow = 100, grey = 140 }, -- Thistle Tea
    },
    [2596] = {
        { spell = 15865, skill = 175, yellow = 215, grey = 255 }, -- Mystery Stew
    },
    [2665] = {
        { spell = 2549, skill = 100, yellow = 140, grey = 180 }, -- Seasoned Wolf Kabob
    },
    [2672] = {
        { spell = 2538, skill = 1, yellow = 45, grey = 85 }, -- Charred Wolf Meat
        { spell = 2539, skill = 30, yellow = 50, grey = 90 }, -- Spiced Wolf Meat
    },
    [2673] = {
        { spell = 2541, skill = 65, yellow = 90, grey = 130 }, -- Coyote Steak
    },
    [2674] = {
        { spell = 2544, skill = 75, yellow = 115, grey = 155 }, -- Crab Cake
    },
    [2675] = {
        { spell = 2545, skill = 85, yellow = 125, grey = 165 }, -- Cooked Crab Claw
    },
    [2677] = {
        { spell = 2546, skill = 110, yellow = 120, grey = 160 }, -- Dry Pork Ribs
        { spell = 2548, skill = 110, yellow = 130, grey = 170 }, -- Succulent Pork Ribs
    },
    [2678] = {
        { spell = 8604, skill = 1, yellow = 45, grey = 85 }, -- Herb Baked Egg
        { spell = 15935, skill = 1, yellow = 45, grey = 85 }, -- Crispy Bat Wing
        { spell = 2539, skill = 30, yellow = 50, grey = 90 }, -- Spiced Wolf Meat
        { spell = 6414, skill = 35, yellow = 75, grey = 115 }, -- Roasted Kodo Meat
        { spell = 2542, skill = 50, yellow = 90, grey = 130 }, -- Goretusk Liver Pie
        { spell = 6415, skill = 50, yellow = 90, grey = 130 }, -- Fillet of Frenzy
        { spell = 7754, skill = 50, yellow = 90, grey = 130 }, -- Loch Frenzy Delight
        { spell = 2544, skill = 75, yellow = 115, grey = 155 }, -- Crab Cake
        { spell = 3370, skill = 80, yellow = 120, grey = 160 }, -- Crocolisk Steak
        { spell = 25704, skill = 80, yellow = 120, grey = 160 }, -- Smoked Sagefish
        { spell = 2545, skill = 85, yellow = 125, grey = 165 }, -- Cooked Crab Claw
        { spell = 8238, skill = 85, yellow = 125, grey = 165 }, -- Savory Deviate Delight
        { spell = 6501, skill = 90, yellow = 130, grey = 170 }, -- Clam Chowder
        { spell = 2546, skill = 110, yellow = 120, grey = 160 }, -- Dry Pork Ribs
        { spell = 6419, skill = 110, yellow = 150, grey = 190 }, -- Lean Venison
        { spell = 15853, skill = 125, yellow = 165, grey = 205 }, -- Lean Wolf Steak
    },
    [2692] = {
        { spell = 3372, skill = 90, yellow = 130, grey = 170 }, -- Murloc Fin Soup
        { spell = 6418, skill = 100, yellow = 140, grey = 180 }, -- Crispy Lizard Tail
        { spell = 2548, skill = 110, yellow = 130, grey = 170 }, -- Succulent Pork Ribs
        { spell = 3377, skill = 110, yellow = 150, grey = 190 }, -- Gooey Spider Cake
        { spell = 3397, skill = 110, yellow = 150, grey = 190 }, -- Big Bear Steak
        { spell = 3373, skill = 120, yellow = 160, grey = 200 }, -- Crocolisk Gumbo
        { spell = 3398, skill = 125, yellow = 175, grey = 215 }, -- Hot Lion Chops
        { spell = 6500, skill = 125, yellow = 165, grey = 205 }, -- Goblin Deviled Clams
        { spell = 3376, skill = 130, yellow = 170, grey = 210 }, -- Curiously Tasty Omelet
        { spell = 4094, skill = 175, yellow = 215, grey = 255 }, -- Barbecued Buzzard Wing
        { spell = 7213, skill = 175, yellow = 215, grey = 255 }, -- Giant Clam Scorcho
        { spell = 15855, skill = 175, yellow = 215, grey = 255 }, -- Roast Raptor
        { spell = 15856, skill = 175, yellow = 215, grey = 255 }, -- Hot Wolf Ribs
        { spell = 15863, skill = 175, yellow = 215, grey = 255 }, -- Carrion Surprise
        { spell = 25954, skill = 175, yellow = 215, grey = 255 }, -- Sagefish Delight
        { spell = 15906, skill = 200, yellow = 240, grey = 280 }, -- Dragonbreath Chili
        { spell = 15915, skill = 225, yellow = 265, grey = 305 }, -- Spiced Chili Crab
        { spell = 20626, skill = 225, yellow = 265, grey = 305 }, -- Undermine Clam Chowder
        { spell = 18242, skill = 240, yellow = 280, grey = 320 }, -- Hot Smoked Bass
        { spell = 18246, skill = 275, yellow = 315, grey = 355 }, -- Mightfish Steak
        { spell = 25659, skill = 300, yellow = 325, grey = 365 }, -- Dirge
    },
    [2886] = {
        { spell = 2795, skill = 25, yellow = 60, grey = 100 }, -- Beer Basted Boar Ribs
    },
    [2894] = {
        { spell = 2795, skill = 25, yellow = 60, grey = 100 }, -- Beer Basted Boar Ribs
    },
    [2924] = {
        { spell = 3370, skill = 80, yellow = 120, grey = 160 }, -- Crocolisk Steak
    },
    [3172] = {
        { spell = 3371, skill = 60, yellow = 100, grey = 140 }, -- Blood Sausage
    },
    [3173] = {
        { spell = 8607, skill = 40, yellow = 80, grey = 120 }, -- Smoked Bear Meat
        { spell = 3371, skill = 60, yellow = 100, grey = 140 }, -- Blood Sausage
    },
    [3174] = {
        { spell = 3371, skill = 60, yellow = 100, grey = 140 }, -- Blood Sausage
    },
    [3404] = {
        { spell = 4094, skill = 175, yellow = 215, grey = 255 }, -- Barbecued Buzzard Wing
    },
    [3667] = {
        { spell = 3373, skill = 120, yellow = 160, grey = 200 }, -- Crocolisk Gumbo
        { spell = 24418, skill = 150, yellow = 160, grey = 200 }, -- Heavy Crocolisk Stew
    },
    [3685] = {
        { spell = 3376, skill = 130, yellow = 170, grey = 210 }, -- Curiously Tasty Omelet
    },
    [3712] = {
        { spell = 3400, skill = 175, yellow = 215, grey = 255 }, -- Soothing Turtle Bisque
    },
    [3713] = {
        { spell = 3399, skill = 150, yellow = 190, grey = 230 }, -- Tasty Lion Steak
        { spell = 24418, skill = 150, yellow = 160, grey = 200 }, -- Heavy Crocolisk Stew
        { spell = 3400, skill = 175, yellow = 215, grey = 255 }, -- Soothing Turtle Bisque
        { spell = 15910, skill = 200, yellow = 240, grey = 280 }, -- Heavy Kodo Stew
        { spell = 15933, skill = 225, yellow = 265, grey = 305 }, -- Monster Omelet
        { spell = 18239, skill = 225, yellow = 265, grey = 305 }, -- Cooked Glossy Mightfish
        { spell = 22480, skill = 225, yellow = 265, grey = 305 }, -- Tender Wolf Steak
        { spell = 18240, skill = 240, yellow = 280, grey = 320 }, -- Grilled Squid
        { spell = 18246, skill = 275, yellow = 315, grey = 355 }, -- Mightfish Steak
        { spell = 18247, skill = 275, yellow = 315, grey = 355 }, -- Baked Salmon
        { spell = 22761, skill = 275, yellow = 315, grey = 355 }, -- Runn Tum Tuber Surprise
        { spell = 24801, skill = 285, yellow = 325, grey = 365 }, -- Smoked Desert Dumplings
    },
    [3730] = {
        { spell = 3397, skill = 110, yellow = 150, grey = 190 }, -- Big Bear Steak
    },
    [3731] = {
        { spell = 3398, skill = 125, yellow = 175, grey = 215 }, -- Hot Lion Chops
        { spell = 3399, skill = 150, yellow = 190, grey = 230 }, -- Tasty Lion Steak
    },
    [3821] = {
        { spell = 13028, skill = 175, yellow = 215, grey = 255 }, -- Goldthorn Tea
    },
    [4402] = {
        { spell = 15906, skill = 200, yellow = 240, grey = 280 }, -- Dragonbreath Chili
    },
    [4536] = {
        { spell = 6416, skill = 50, yellow = 90, grey = 130 }, -- Strider Stew
        { spell = 15861, skill = 175, yellow = 215, grey = 255 }, -- Jungle Stew
    },
    [4603] = {
        { spell = 18238, skill = 225, yellow = 265, grey = 305 }, -- Spotted Yellowtail
    },
    [4655] = {
        { spell = 7213, skill = 175, yellow = 215, grey = 255 }, -- Giant Clam Scorcho
    },
    [5051] = {
        { spell = 6417, skill = 90, yellow = 130, grey = 170 }, -- Dig Rat Stew
    },
    [5465] = {
        { spell = 6412, skill = 10, yellow = 50, grey = 90 }, -- Kaldorei Spider Kabob
    },
    [5466] = {
        { spell = 6413, skill = 20, yellow = 60, grey = 100 }, -- Scorpid Surprise
    },
    [5467] = {
        { spell = 6414, skill = 35, yellow = 75, grey = 115 }, -- Roasted Kodo Meat
    },
    [5468] = {
        { spell = 6415, skill = 50, yellow = 90, grey = 130 }, -- Fillet of Frenzy
    },
    [5469] = {
        { spell = 6416, skill = 50, yellow = 90, grey = 130 }, -- Strider Stew
    },
    [5470] = {
        { spell = 6418, skill = 100, yellow = 140, grey = 180 }, -- Crispy Lizard Tail
    },
    [5471] = {
        { spell = 6419, skill = 110, yellow = 150, grey = 190 }, -- Lean Venison
    },
    [5503] = {
        { spell = 6499, skill = 50, yellow = 90, grey = 130 }, -- Boiled Clams
        { spell = 6501, skill = 90, yellow = 130, grey = 170 }, -- Clam Chowder
    },
    [5504] = {
        { spell = 6500, skill = 125, yellow = 165, grey = 205 }, -- Goblin Deviled Clams
    },
    [6289] = {
        { spell = 7753, skill = 50, yellow = 90, grey = 130 }, -- Longjaw Mud Snapper
    },
    [6291] = {
        { spell = 7751, skill = 1, yellow = 45, grey = 85 }, -- Brilliant Smallfish
    },
    [6303] = {
        { spell = 7752, skill = 1, yellow = 45, grey = 85 }, -- Slitherskin Mackerel
    },
    [6308] = {
        { spell = 7755, skill = 100, yellow = 140, grey = 180 }, -- Bristle Whisker Catfish
    },
    [6317] = {
        { spell = 7754, skill = 50, yellow = 90, grey = 130 }, -- Loch Frenzy Delight
    },
    [6361] = {
        { spell = 7827, skill = 50, yellow = 90, grey = 130 }, -- Rainbow Fin Albacore
    },
    [6362] = {
        { spell = 7828, skill = 175, yellow = 190, grey = 230 }, -- Rockscale Cod
    },
    [6522] = {
        { spell = 8238, skill = 85, yellow = 125, grey = 165 }, -- Savory Deviate Delight
    },
    [6889] = {
        { spell = 8604, skill = 1, yellow = 45, grey = 85 }, -- Herb Baked Egg
        { spell = 21143, skill = 1, yellow = 45, grey = 85 }, -- Gingerbread Cookie
        { spell = 21144, skill = 35, yellow = 75, grey = 115 }, -- Egg Nog
    },
    [7974] = {
        { spell = 20626, skill = 225, yellow = 265, grey = 305 }, -- Undermine Clam Chowder
    },
    [8150] = {
        { spell = 25659, skill = 300, yellow = 325, grey = 365 }, -- Dirge
    },
    [8365] = {
        { spell = 20916, skill = 175, yellow = 215, grey = 255 }, -- Mithril Headed Trout
    },
    [9061] = {
        { spell = 25659, skill = 300, yellow = 325, grey = 365 }, -- Dirge
    },
    [12037] = {
        { spell = 15863, skill = 175, yellow = 215, grey = 255 }, -- Carrion Surprise
        { spell = 15865, skill = 175, yellow = 215, grey = 255 }, -- Mystery Stew
        { spell = 15906, skill = 200, yellow = 240, grey = 280 }, -- Dragonbreath Chili
    },
    [12184] = {
        { spell = 15855, skill = 175, yellow = 215, grey = 255 }, -- Roast Raptor
    },
    [12202] = {
        { spell = 15861, skill = 175, yellow = 215, grey = 255 }, -- Jungle Stew
    },
    [12203] = {
        { spell = 15856, skill = 175, yellow = 215, grey = 255 }, -- Hot Wolf Ribs
    },
    [12204] = {
        { spell = 15910, skill = 200, yellow = 240, grey = 280 }, -- Heavy Kodo Stew
    },
    [12205] = {
        { spell = 21175, skill = 200, yellow = 240, grey = 280 }, -- Spider Sausage
    },
    [12206] = {
        { spell = 15915, skill = 225, yellow = 265, grey = 305 }, -- Spiced Chili Crab
    },
    [12207] = {
        { spell = 15933, skill = 225, yellow = 265, grey = 305 }, -- Monster Omelet
    },
    [12208] = {
        { spell = 22480, skill = 225, yellow = 265, grey = 305 }, -- Tender Wolf Steak
    },
    [12223] = {
        { spell = 15935, skill = 1, yellow = 45, grey = 85 }, -- Crispy Bat Wing
    },
    [13754] = {
        { spell = 18239, skill = 225, yellow = 265, grey = 305 }, -- Cooked Glossy Mightfish
    },
    [13755] = {
        { spell = 18240, skill = 240, yellow = 280, grey = 320 }, -- Grilled Squid
    },
    [13756] = {
        { spell = 18242, skill = 240, yellow = 280, grey = 320 }, -- Hot Smoked Bass
    },
    [13758] = {
        { spell = 18241, skill = 225, yellow = 265, grey = 305 }, -- Filet of Redgill
    },
    [13759] = {
        { spell = 18243, skill = 250, yellow = 290, grey = 330 }, -- Nightfin Soup
    },
    [13760] = {
        { spell = 18244, skill = 250, yellow = 290, grey = 330 }, -- Poached Sunscale Salmon
    },
    [13888] = {
        { spell = 18245, skill = 275, yellow = 315, grey = 355 }, -- Lobster Stew
    },
    [13889] = {
        { spell = 18247, skill = 275, yellow = 315, grey = 355 }, -- Baked Salmon
    },
    [13893] = {
        { spell = 18246, skill = 275, yellow = 315, grey = 355 }, -- Mightfish Steak
    },
    [17194] = {
        { spell = 21143, skill = 1, yellow = 45, grey = 85 }, -- Gingerbread Cookie
        { spell = 21144, skill = 35, yellow = 75, grey = 115 }, -- Egg Nog
    },
    [17196] = {
        { spell = 21144, skill = 35, yellow = 75, grey = 115 }, -- Egg Nog
    },
    [18255] = {
        { spell = 22761, skill = 275, yellow = 315, grey = 355 }, -- Runn Tum Tuber Surprise
    },
    [20424] = {
        { spell = 24801, skill = 285, yellow = 325, grey = 365 }, -- Smoked Desert Dumplings
    },
    [21024] = {
        { spell = 25659, skill = 300, yellow = 325, grey = 365 }, -- Dirge
    },
    [21071] = {
        { spell = 25704, skill = 80, yellow = 120, grey = 160 }, -- Smoked Sagefish
    },
    [21153] = {
        { spell = 25954, skill = 175, yellow = 215, grey = 255 }, -- Sagefish Delight
    },
}
