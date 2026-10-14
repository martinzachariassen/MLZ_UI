-- MLZ UI: Tips on the overview page
-- Edit freely. One tip shows at a time; "Next tip" moves on. UI/Settings.lua picks them.
--   text   = the tip (plain English, one or two short sentences)
--   needs  = (optional) only when this is true:
--            "fade:<id>" a Minimalism row is on, "vendor" auto-repair or selling is on,
--            "buttons" an action button option is on, "leveling" you are not at max level,
--            "minimapShown" the minimap button is visible, "remindersOff" reminders are not both on
--   action = (optional) a button next to the tip: "tour", "keys", "fadePause" or "page:<key>"

local _, ns = ...

ns.data.tips = {
    { text = "Bars 4 and 5 are hidden at the bottom right. Move the mouse there to use them.", needs = "fade:bar45",
      action = "tour" },
    { text = "The character, spellbook and other menu buttons appear when you hover them. Their keys (C, P, N) always work.",
      needs = "fade:micro" },
    { text = "See every key you have bound, with the SHIFT, CTRL and ALT layers.", action = "keys" },
    { text = "Red action buttons are out of range, blue ones lack mana, dark grey ones can't be used right now.",
      needs = "buttons" },
    { text = "Hold SHIFT when you talk to a merchant to skip auto-repair and selling once.", needs = "vendor" },
    { text = "Right-click the minimap button for the quick menu: nameplate mode, role, pause fading.",
      needs = "minimapShown" },
    { text = "Lost track of something? Pause fading and every hidden frame shows until you turn it back on.",
      action = "fadePause" },
    { text = "/mlz xp shows your XP per hour and the time to your next level.", needs = "leveling" },
    { text = "Reminder icons for missing buffs, low reagents and worn gear can be turned on in Helpers.",
      action = "page:qol", needs = "remindersOff" },
    { text = "Your role picks the nameplate mode and the layouts. Set it by hand in Your role.",
      action = "page:healer" },
    { text = "Key hints, reminders and stance or pet keys follow your class. Druids, warriors and paladins also follow their form, stance or aura.",
      action = "page:healer" },
    { text = "Every setup wizard run makes a backup first. /mlz undo puts the last one back.", },
}
